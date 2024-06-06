import Foundation
import Combine
import Moya
import Dependencies

public enum FetchType<Target> {
    case page((_ page: Int) -> Target)
    case simple(Target)
}

public struct RequestService<Table: TableProtocol, Target: TargetType> {
    public var _get: () -> [Table]
    public var _getBy: (Int) -> Table?
    public var _create: (Table) -> ()
    public var _update: (Table) -> ()
    public var _delete: (Table) -> ()
    public var _fetch: (_ page: Int) async throws -> FetchResponse<[Table]>
    public var _clear: () -> ()
    public var _sync: ([Table]) async throws -> [Table]
    public var _getName: () -> String
    
    public func get() -> [Table] {
        return self._get()
    }
    public func get(by id: Int) -> Table? {
        return self._getBy(id)
    }
    public func create(_ item: Table) {
        self._create(item)
    }
    public func update(_ item: Table){
        self._update(item)
    }
    public func delete(_ item: Table) {
        self._delete(item)
    }
    public func fetch() async throws -> FetchResponse<[Table]> {
        return try await _fetch(1)
    }
    public func fetch(page: Int) async throws -> FetchResponse<[Table]> {
        return try await _fetch(page)
    }
    public func clear() {
        self._clear()
    }
    public func sync(_ remoteRecords: [Table]) async throws -> [Table] {
        return try await self._sync(remoteRecords)
    }
    public func getName() -> String {
        return self._getName()
    }
}

public extension RequestService {
    static func live(
        table: DatabaseTable<Table>,
        
        provider: MoyaProvider<Target>,
        
        fetchMethod: FetchType<Target>,
        insertMethod: ((Table) -> Target)? = nil,
        updateMethod: ((Table) -> Target)? = nil,
        deleteMethod: ((Int) -> Target)? = nil
    ) -> Self
    {
        @Dependency(\.track) var track
        
        return Self(
            _get: { table.get() },
            _getBy: { table.get(by: $0) },
            _create: { table.create($0) },
            _update: { table.update($0, isTrack: true) },
            _delete: { table.delete($0.id, isTrack: true) },
            _fetch: { page in
                switch(fetchMethod){
                case .page(let method):
                    let result: FetchResponse<[Table]?> = try await request(provider, method(page))
                    return FetchResponse(result.response!, result.headers)
                case .simple(let method):
                    let result: FetchResponse<[Table]?> = try await request(provider, method)
                    return FetchResponse(result.response!, result.headers)
                }
            },
            _clear: { table.clear() },
            _sync: { remoteRecords in
                // 1. get remote data
                // 2. get local changes
                
                // no track     -> local delete
                
                // insert       -> remote insert
                // update       -> remote update
                // delete       -> remote delete
                
                // no insert    -> local insert
                // no update    -> local update
                
                // ------------------------------
                
                let localRecords = table.get()
                var synced: [SyncResponse<Table>] = []
                let changes = track.getChanges(table.getName()) ?? []
                
                for localRecord in localRecords {
                    if (
                        remoteRecords.first(where: { $0.id == localRecord.id }) == nil &&
                        track.getChange(localRecord.id, table.getName())?.type != .insert
                    )
                    {
                        // local was not inserted and no remote record -> delete local
                        table.delete(localRecord.id, isTrack: false)
                    }
                }
                
                for change in changes {
                    switch(change.type){
                        case .insert:
                            guard let localRecord = localRecords.first(where: {$0.id == change.recordID}) else { continue }
                            if let insertMethod = insertMethod {
                                let r: Table = try await request(provider, insertMethod(localRecord)).response!
                                synced.append(
                                    SyncResponse(change: change, result: r)
                                )
                            }
                        case .update:
                            guard let localRecord = localRecords.first(where: {$0.id == change.recordID}) else { continue }
                            if let updateMethod = updateMethod {
                                let r: Table = try await request(provider, updateMethod(localRecord)).response!
                                synced.append(
                                    SyncResponse(change: change, result: r)
                                )
                            }
                        
                        case .delete:
                            if let deleteMethod = deleteMethod {
                                let _: Table? = try await request(provider, deleteMethod(change.recordID)).response
                                synced.append(
                                    SyncResponse(change: change)
                                )
                            }
                    }
                }
                
                for remoteRecord in remoteRecords {
                    if let localRecord = localRecords.first(where: { $0.id == remoteRecord.id }) {
                        if let change = track.getChange(localRecord.id, table.getName()) {
                            if change.type == .insert {
                                // remote and local id are new records -> insert local too
                                table.insert(remoteRecord, isTrack: false) // local record will be overwritten but later fetched again
                            }
                            // else: remoteRecord old
                        } else if localRecord != remoteRecord {
                            // remote data changed -> update local
                            table.update(remoteRecord, isTrack: false)
                        }
                    } else {
                        if track.getChange(remoteRecord.id, table.getName()) == nil {
                            // local record not found and was not deleted -> insert local
                            table.insert(remoteRecord, isTrack: false)
                        }
                        // else: already local deleted
                    }
                }
                
                for response in synced {
                    track.clear(response.change.recordID, response.change.tableName)
                    
                    if let result = response.result {
                        if(response.change.recordID != result.id){
                            // id has changed -> delete and reinsert record
                            table.delete(response.change.recordID, isTrack: false)
                            table.insert(result, isTrack: false)
                        }else {
                            table.update(result, isTrack: false)
                        }
                    }
                }
                
                return table.get()
            },
            _getName: { table.getName() }
        )
        
        func request<Response: Decodable, TargetType>(_ provider: MoyaProvider<TargetType>, _ method: TargetType) async throws -> FetchResponse<Response?> {
            return try await withCheckedThrowingContinuation { continuation in
                provider.request(method){ result in
                    switch result {
                    case .success(let response):
                        let headers = response.response?.allHeaderFields ?? [:]
                        
                        if (response.statusCode == 204){ // no content
                            continuation.resume(returning: FetchResponse(nil, headers))
                        } else if let data = try? JSONDecoder().decode(Response.self, from: response.data) {
                            continuation.resume(returning: FetchResponse(data, headers))
                        }else {
                            if let string = String(data: response.data, encoding: .utf8) {
                                continuation.resume(throwing: OfflineSyncError.unknown(method.path + " -> " + string))
                            }else{
                                continuation.resume(throwing: OfflineSyncError.decodeFailed)
                            }
                        }
                    case .failure(let error):
                        continuation.resume(throwing: OfflineSyncError.unknown(method.path + " -> " + error.localizedDescription))
                    }
                }
            }
        }
    }
    
    static func mock(
        table: DatabaseTable<Table>
    ) -> Self
    {
        @Dependency(\.track) var track
        
        return Self(
            _get: { table.get() },
            _getBy: { table.get(by: $0) },
            _create: { table.create($0) },
            _update: { table.update($0, isTrack: true) },
            _delete: { table.delete($0.id, isTrack: true) },
            _fetch: { _ in
                return FetchResponse([.init()], [:])
            },
            _clear: { table.clear() },
            _sync: { remoteRecords in
                // 1. get remote data
                // 2. get local changes
                
                // no track     -> local delete
                
                // insert       -> remote insert
                // update       -> remote update
                // delete       -> remote delete
                
                // no insert    -> local insert
                // no update    -> local update
                
                // ------------------------------
                
                let localRecords = table.get()
                
                for localRecord in localRecords {
                    if (
                        remoteRecords.first(where: { $0.id == localRecord.id }) == nil &&
                        track.getChange(localRecord.id, table.getName())?.type != .insert
                    )
                    {
                        // local was not inserted and no remote record -> delete local
                        table.delete(localRecord.id, isTrack: false)
                    }
                }
                
                for remoteRecord in remoteRecords {
                    if let localRecord = localRecords.first(where: { $0.id == remoteRecord.id }) {
                        if let change = track.getChange(localRecord.id, table.getName()) {
                            if change.type == .insert {
                                // remote and local id are new records -> insert local too
                                table.insert(remoteRecord, isTrack: false) // local record will be overwritten but later fetched again
                            }
                            // else: remoteRecord old
                        } else if localRecord != remoteRecord {
                            // remote data changed -> update local
                            table.update(remoteRecord, isTrack: false)
                        }
                    } else {
                        if track.getChange(remoteRecord.id, table.getName()) == nil {
                            // local record not found and was not deleted -> insert local
                            table.insert(remoteRecord, isTrack: false)
                        }
                        // else: already local deleted
                    }
                }
                
                
                return table.get()
            },
            _getName: { table.getName() }
        )
    }
}

