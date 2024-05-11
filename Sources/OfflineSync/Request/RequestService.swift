import Foundation
import Combine
import Moya

public enum FetchType<Target> {
    case page((_ page: Int) -> Target)
    case simple(Target)
}

public class RequestService<Table: TableProtocol, Target: TargetType>: IService {
    var table: DatabaseTable<Table>
    var provider: MoyaProvider<Target>
    
    var fetchMethod: FetchType<Target>
    var insertMethod: ((Table) -> Target)?
    var updateMethod: ((Table) -> Target)?
    var deleteMethod: ((Table) -> Target)?
    
    public init(
        _ table: DatabaseTable<Table>,
        _ provider: MoyaProvider<Target>,
        
        _ loadMethod: FetchType<Target>,
        _ insertMethod: ((Table) -> Target)? = nil,
        _ updateMethod: ((Table) -> Target)? = nil,
        _ deleteMethod: ((Table) -> Target)? = nil
    ) {
        self.table = table
        self.provider = provider
        
        self.fetchMethod = loadMethod
        self.insertMethod = insertMethod
        self.updateMethod = updateMethod
        self.deleteMethod = deleteMethod
    }
    
    public func get() -> [Table] {
        return table.get()
    }
    
    public func get(by id: Int) -> Table? {
        return table.get(by: id)
    }
    
    
    public func create(_ item: Table){
        table.create(item)
    }
    
    public func update(_ item: Table) {
        table.update(item, isTrack: true)
    }
    
    public func fetch(_ page: Int = 1) async throws -> FetchResponse<[Table]> {
        switch(fetchMethod){
        case .page(let method):
            return try await request(provider, method(page))
        case .simple(let method):
            return try await request(provider, method)
        }
        
    }
    
    public func sync(_ remoteRecords: [Table]) async throws -> [Table]{
        // 1. get remote data
        // 2. get local changes
        
        // insert       -> remote insert
        // update       -> remote update
        // delete       -> remote delete
        
        
        // no insert    -> local insert
        // no update    -> local update
        // no delete    -> local delete
        
        // ------------------------------
        
        let localRecords = table.get()
        
        for localRecord in localRecords {
            if (
                remoteRecords.first(where: { $0.id == localRecord.id }) == nil &&
                table.getTrack()?.getChange(localRecord.id, table.getName())?.type != .insert
            )
            {
                // local was not inserted and no remote record -> delete local
                table.delete(localRecord.id, isTrack: false)
            }
            
            else if let change = table.getTrack()?.getChange(localRecord.id, table.getName()) {
                switch(change.type){
                    case .insert:
                        if let insertMethod = insertMethod {
                            let r: Table = try await request(provider, insertMethod(localRecord)).response
                            hasSynced(
                                SyncResponse(change: change, result: r)
                            )
                        }
                    case .update:
                        if let updateMethod = updateMethod {
                            let r: Table = try await request(provider, updateMethod(localRecord)).response
                            hasSynced(
                                SyncResponse(change: change, result: r)
                            )
                        }
                    
                    case .delete:
                        if let deleteMethod = deleteMethod {
                            let r: Table = try await request(provider, deleteMethod(localRecord)).response
                            hasSynced(
                                SyncResponse(change: change, result: r)
                            )
                        }
                }
                
            }
        }
        
        for remoteRecord in remoteRecords {
            if let localRecord = localRecords.first(where: { $0.id == remoteRecord.id }) {
                if let change = table.getTrack()?.getChange(localRecord.id, table.getName()) {
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
                if table.getTrack()?.getChange(remoteRecord.id, table.getName()) == nil {
                    // local record not found and was not deleted -> insert local
                    table.insert(remoteRecord, isTrack: false)
                } 
                // else: already local deleted
            }
        }
        
        return table.get()
    }
    
    func hasSynced(_ response: SyncResponse<Table>){
        table.getTrack()?.delete(by: response.change.recordID)
        if(response.change.recordID != response.result.id){
            // id has changed -> delete and reinsert record
            table.delete(response.change.recordID, isTrack: false)
            table.insert(response.result, isTrack: false)
        }else {
            table.update(response.result, isTrack: false)
        }
    }
    
    
}
