import Foundation
import SQLite

@available(iOS 16.0, *)
public class TrackTable {
    private var db: Connection?
    private let table: Table
    private var dbPath: String?
    
    private var id = Expression<Int>("id")
    private var type = Expression<Int>("type")
    private var recordID = Expression<Int>("recordID")
    private var tableName = Expression<String>("tableName")
    private var timestamp = Expression<String>("timestamp")
    
    public init(_ db: Connection?) {
        self.db = db
        self.table = Table("track")
        createTable()
    }
    
    public func getAll(_ records: [any TableProtocol], _ tableName: String) -> [DatabaseChange] {
        var changes: [DatabaseChange] = []
        
        for record in records {
            if let change = getChange(record.id, tableName) {
                changes.append(change)
            }
        }
        
        return changes
    }
    
    public func clear(){
        do {
            try db?.run(table.delete())
        } catch {
            
        }
    }
    public func clear(_ tableName: String) {
        do {
            try db?.run(table.filter(self.tableName == tableName).delete())
        } catch {
            
        }
    }
    
    public func clear(_ recordID: Int, _ tableName: String) {
        do {
            try db?.run(table.filter(self.recordID == recordID && self.tableName == tableName).delete())
        } catch {
            
        }
    }
    
    public func insert(_ recordID: Int, _ tableName: String, _ type: DatabaseChangeType){
        do {
            if(type == .update){
                var old = getChange(recordID, tableName)
                if(old?.type != .update){
                    return
                }
            }
            
            clear(recordID, tableName)
            try db?.run(table.insert(
                self.type <- type.rawValue,
                self.recordID <- recordID,
                self.tableName <- tableName,
                self.timestamp <- "\(Date.now)"
            ))
        } catch {
            
        }
    }
    
    public func getChange(_ recordID: Int, _ tableName: String) -> DatabaseChange? {
        guard let db = db else { return nil }
        do {
            if let row = try db.pluck(table.filter(self.recordID == recordID && self.tableName == tableName)) {
                return DatabaseChange(
                    id: row[self.id],
                    type: DatabaseChangeType(rawValue: row[type])!,
                    recordID: row[self.recordID],
                    tableName: row[self.tableName],
                    timestamp: row[self.timestamp]
                )
            }
            
            return nil
            
        } catch {
            return nil
        }
    }
    
    public func getChanges(_ tableName: String) -> [DatabaseChange]? {
        guard let db = db else { return nil }
        do {
            var changes: [DatabaseChange] = []
            
            for row in try db.prepare(table.filter(self.tableName == tableName)) {
                changes.append(DatabaseChange(
                    id: row[self.id],
                    type: DatabaseChangeType(rawValue: row[type])!,
                    recordID: row[self.recordID],
                    tableName: row[self.tableName],
                    timestamp: row[self.timestamp]
                ))
            }
            
            return changes
            
        } catch {
            return nil
        }
    }
    
    
    private func createTable() {
        let createTable = table.create(ifNotExists: true) { (table) in
            table.column(id, primaryKey: .default)
            table.column(type)
            table.column(recordID)
            table.column(tableName)
            table.column(timestamp)
        }
        
        do {
            try db?.run(createTable)
        } catch {
           
        }
    }
}
