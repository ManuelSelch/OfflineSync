import SQLite
import Dependencies

import OfflineSyncCore

public class KeyMappingTable {
    @Dependency(\.database) var database
    
    private let mappingTable: Table
    private var dbPath: String?
    
    private var id = SQLite.Expression<Int>("id")
    private var tableName = SQLite.Expression<String>("tableName")
    private var localID = SQLite.Expression<Int>("localID")
    private var remoteID = SQLite.Expression<Int>("remoteID")
    
    private let relationships: [String: [(foreignKey: String, parentTable: String)]]
    
    
    public init(
        relationships: [String: [(foreignKey: String, parentTable: String)]]
    ) {
        self.relationships = relationships
        self.mappingTable = Table("keyMapping")
        createTable()
    }
    
    public func updateAllForeignKeys() {
        createTable()
        
        for (childTableName, relations) in relationships {
            updateForeignKeys(for: childTableName, relations)
        }
        clear()
    }
    
    private func updateForeignKeys(for childTableName: String, _ relations: [(foreignKey: String, parentTable: String)])  {
        let childTable = Table(childTableName)
        
    
        for relation in relations {
            let parentTable = Table(relation.parentTable)
            let foreignKey = Expression<Int>(relation.foreignKey)
            
            guard let rows = try? database.connection?.prepare(childTable)
            else { return }

            // Fetch all rows that need updating
            for childRow in rows {
                let localFKValue = childRow[foreignKey]

                let fetchRemoteID = mappingTable
                    .select(remoteID)
                    .filter(tableName == relation.parentTable && localID == localFKValue)

                // Extract the remote ID
                if let remoteIDValue = try? database.connection?.pluck(fetchRemoteID)?.get(remoteID) {
                    // Update the child's foreign key with the remote ID
                    let updateQuery = childTable.filter(foreignKey == localFKValue)
                        .update(foreignKey <- remoteIDValue)
                    _ = try? database.connection?.run(updateQuery)
                }
            }
        }
    }


    
    public func get(of tableName: String) -> [KeyMapping] {
        guard let db = database.connection else { print("no connection db..."); return [] }
        
        createTable()
        
        do {
            let records: [KeyMapping] = try db.prepare(mappingTable.filter(self.tableName == tableName)).map { row in
                return try row.decode()
            }
            return records
            
        } catch {
            print("error db...: \(error.localizedDescription)")
            return []
        }
    }
    
    public func getLastId() -> Int {
        return get().max(by: { $0.id < $1.id })?.id ?? 0
    }
    
    public func get() -> [KeyMapping] {
        guard let db = database.connection else { print("no connection db..."); return [] }
        
        createTable()
        
        do {
            let records: [KeyMapping] = try db.prepare(mappingTable).map { row in
                return try row.decode()
            }
            return records
            
        } catch {
            print("error db...: \(error.localizedDescription)")
            return []
        }
    }
    
    
    public func clear() {
        do {
            try database.connection?.run(mappingTable.delete())
        } catch {
            
        }
    }
    
    
    public func insert(_ item: KeyMapping) {
        createTable()
        
        var item = item
        item.id = getLastId() + 1
        do {
            try database.connection?.run(mappingTable.insert(or: .replace, encodable: item))
        } catch {
            print("database insert error: \(error.localizedDescription)")
        }
    }
    
 
    
    public func createTable() {
        // will fail if table exists
        let createTable = mappingTable.create(ifNotExists: false) { (table) in
            table.column(id, primaryKey: .default)
            table.column(tableName)
            table.column(localID)
            table.column(remoteID)
        }
        
        do {
            _ = try database.connection?.run(createTable)
        } catch {
            // table already exists
        }
        
    }
}
