
import Dependencies
import SQLite

import OfflineSyncCore

public struct SyncService<Model: TableProtocol> {
    private var keyMapping: KeyMappingTable
    
    private var repository: DatabaseRepository<Model>
    
    private var remoteInsert: (Model) async throws -> (Model)
    private var remoteUpdate: ((Model) async throws -> (Model))?
    private var remoteDelete: ((Int) async throws -> ())?
    
    public init(
        repository: DatabaseRepository<Model>,
        remoteInsert: @escaping (Model) async throws -> Model,
        remoteUpdate: ((Model) async throws -> Model)?,
        remoteDelete: ((Int) async throws -> Void)?,
        keyMapping: KeyMappingTable
    ) {
        self.repository = repository
        self.remoteInsert = remoteInsert
        self.remoteUpdate = remoteUpdate
        self.remoteDelete = remoteDelete
        self.keyMapping = keyMapping
    }
    
    
   
  
    public func sync(localRecords: [Model], remoteRecords: [Model]) async throws -> [Model] {
        // 1. delete old local records
        // no track     -> local delete
        
        // 2. upload local changes
        // insert       -> remote insert
        // update       -> remote update
        // delete       -> remote delete
        
        // 3. merge remote changes
        // no insert    -> local insert
        // no update    -> local update
        
        // ------------------------------
        
        var synced: [SyncResponse<Model>] = []
        let changes = repository.getChanges()
        
        // MARK: - 1. delete old local records
        for localRecord in localRecords {
            if (
                remoteRecords.get(localRecord.id) == nil &&
                changes.get(localRecord.id)?.type != .insert
            )
            {
                // local was not inserted and no remote record -> delete local
                repository.delete(localRecord.id, isTrack: false)
            }
        }
        
        
        // MARK: - 2. upload local changes
        for change in changes {
            switch(change.type){
            case .insert:
                guard let localRecord = localRecords.get(change.recordID) else { continue }
                let result = try await remoteInsert(localRecord)
            
                synced.append(
                    SyncResponse(change: change, result: result)
                )
            case .update:
                guard let localRecord = localRecords.first(where: {$0.id == change.recordID}) else { continue }
                if let remoteUpdate = remoteUpdate {
                    let result = try await remoteUpdate(localRecord)
                    synced.append(
                        SyncResponse(change: change, result: result)
                    )
                }
            
            case .delete:
                if let remoteDelete = remoteDelete {
                    try await remoteDelete(change.recordID)
                    synced.append(
                        SyncResponse(change: change)
                    )
                }
            }
        }
        
        // MARK: - 3. merge remote changes
        for remoteRecord in remoteRecords {
            
            guard let localRecord = localRecords.get(remoteRecord.id) else {
                // local record not found and was not deleted -> insert local
                if changes.get(remoteRecord.id) == nil {
                    repository.insert(remoteRecord, isTrack: false)
                    
                }
                continue
            }
            
            guard let change = changes.get(localRecord.id) else {
                // remote data changed -> update local
                if localRecord != remoteRecord {
                    repository.update(remoteRecord, isTrack: false)
                }
                continue
            }
                    
                    
            if change.type == .insert {
                // remote and local id are new records -> insert local too
                repository.insert(remoteRecord, isTrack: false) // local record will be overwritten but later fetched again
            }
            // else: remoteRecord old
            

        }
        
        for response in synced {
            repository.clearChanges(of: response.change.recordID)
            
            guard let result = response.result else { continue }
            
            
            if(response.change.recordID != result.id){
                // id has changed -> delete and reinsert record
                addMapping(repository.getName(), response.change.recordID, result.id)
                repository.delete(response.change.recordID, isTrack: false)
                repository.insert(result, isTrack: false)
            }else {
                repository.update(result, isTrack: false)
            }
            
        }
        
        keyMapping.updateAllForeignKeys()
        return repository.get()
    }
    
    private func addMapping(_ tableName: String, _ localID: Int, _ remoteID: Int) {
        keyMapping.insert(KeyMapping(-1, tableName, localID, remoteID))
    }
}
