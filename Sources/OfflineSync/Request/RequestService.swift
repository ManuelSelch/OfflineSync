import Foundation
import Combine
import Moya

public enum FetchType<Target> {
    case page((_ page: Int) -> Target)
    case simple(Target)
}


public struct RequestService<Table: TableProtocol, Target: TargetType>: IService {
    var table: DatabaseTable<Table>
    
    var getProvider: () -> (MoyaProvider<Target>)
    
    var fetchMethod: FetchType<Target>
    var insertMethod: ((Table) -> Target)?
    var updateMethod: ((Table) -> Target)?
    var deleteMethod: ((Int) -> Target)?
    
    
    
    public init(
        _ table: DatabaseTable<Table>,
        
        _ getProvider: @escaping () -> (MoyaProvider<Target>),
        
        _ loadMethod: FetchType<Target>,
        _ insertMethod: ((Table) -> Target)? = nil,
        _ updateMethod: ((Table) -> Target)? = nil,
        _ deleteMethod: ((Int) -> Target)? = nil
    ) {
        self.table = table
        
        self.getProvider = getProvider
        
        self.fetchMethod = loadMethod
        self.insertMethod = insertMethod
        self.updateMethod = updateMethod
        self.deleteMethod = deleteMethod
    }
    
    public func get() -> [Table] {
        return table.getAll()
    }
    
    public func get(by id: Int) -> Table? {
        return table.get(id)
    }
    
    
    public func create(_ item: Table){
        table.create(item)
    }
    
    public func update(_ item: Table) {
        table.update(item, true)
    }
    
    public func delete(_ item: Table) {
        table.delete(item.id, true)
    }
    
    public func fetch(_ page: Int = 1) async throws -> FetchResponse<[Table]> {
        switch(fetchMethod){
        case .page(let method):
            let result: FetchResponse<[Table]?> = try await request(getProvider(), method(page))
            return FetchResponse(result.response!, result.headers)
        case .simple(let method):
            let result: FetchResponse<[Table]?> = try await request(getProvider(), method)
            return FetchResponse(result.response!, result.headers)
        }
        
    }
    
    public func clear(){
        table.clear()
    }
    
    public func sync(_ remoteRecords: [Table]) async throws -> [Table]{
        // 1. get remote data
        // 2. get local changes
        
        // no track     -> local delete
        
        // insert       -> remote insert
        // update       -> remote update
        // delete       -> remote delete
        
        // no insert    -> local insert
        // no update    -> local update
        
        // ------------------------------
        
        let localRecords = table.getAll()
        var synced: [SyncResponse<Table>] = []
        let changes = table.getTrack()?.getChanges(table.getName()) ?? []
        
        for localRecord in localRecords {
            if (
                remoteRecords.first(where: { $0.id == localRecord.id }) == nil &&
                table.getTrack()?.getChange(localRecord.id, table.getName())?.type != .insert
            )
            {
                // local was not inserted and no remote record -> delete local
                table.delete(localRecord.id, false)
            }
        }
        
        for change in changes {
            switch(change.type){
                case .insert:
                    guard let localRecord = localRecords.first(where: {$0.id == change.recordID}) else { continue }
                    if let insertMethod = insertMethod {
                        let r: Table = try await request(getProvider(), insertMethod(localRecord)).response!
                        synced.append(
                            SyncResponse(change: change, result: r)
                        )
                    }
                case .update:
                    guard let localRecord = localRecords.first(where: {$0.id == change.recordID}) else { continue }
                    if let updateMethod = updateMethod {
                        let r: Table = try await request(getProvider(), updateMethod(localRecord)).response!
                        synced.append(
                            SyncResponse(change: change, result: r)
                        )
                    }
                
                case .delete:
                    if let deleteMethod = deleteMethod {
                        let r: Table? = try await request(getProvider(), deleteMethod(change.recordID)).response
                        synced.append(
                            SyncResponse(change: change)
                        )
                    }
            }
        }
        
        for remoteRecord in remoteRecords {
            if let localRecord = localRecords.first(where: { $0.id == remoteRecord.id }) {
                if let change = table.getTrack()?.getChange(localRecord.id, table.getName()) {
                    if change.type == .insert {
                        // remote and local id are new records -> insert local too
                        table.insert(remoteRecord, false) // local record will be overwritten but later fetched again
                    }
                    // else: remoteRecord old
                } else if localRecord != remoteRecord {
                    // remote data changed -> update local
                    table.update(remoteRecord, false)
                }
            } else {
                if table.getTrack()?.getChange(remoteRecord.id, table.getName()) == nil {
                    // local record not found and was not deleted -> insert local
                    table.insert(remoteRecord, false)
                } 
                // else: already local deleted
            }
        }
        
        hasSynced(synced)
        return table.getAll()
    }
    
    func hasSynced(_ responses: [SyncResponse<Table>]){
        for response in responses {
            table.getTrack()?.clear(response.change.recordID, response.change.tableName)
            
            if let result = response.result {
                if(response.change.recordID != result.id){
                    // id has changed -> delete and reinsert record
                    table.delete(response.change.recordID, false)
                    table.insert(result, false)
                }else {
                    table.update(result, false)
                }
            }
        }
    }
    
    public func getName() -> String {
        return table.getName()
    }
    
    
}
