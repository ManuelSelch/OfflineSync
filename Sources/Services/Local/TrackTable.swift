import Foundation
import SQLite
import Dependencies

import OfflineSyncCore

public class TrackTable {
    @Dependency(\.database) var database
    
    private let table: Table
    private var dbPath: String?
    
    private var id = SQLite.Expression<Int>("id")
    private var type = SQLite.Expression<Int>("type")
    private var recordID = SQLite.Expression<Int>("recordID")
    private var tableName = SQLite.Expression<String>("tableName")
    private var timestamp = SQLite.Expression<String>("timestamp")
    
    public init() {
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
            try database.connection?.run(table.delete())
        } catch {
            
        }
    }
    public func clear(_ tableName: String) {
        do {
            try database.connection?.run(table.filter(self.tableName == tableName).delete())
        } catch {
            
        }
    }
    
    public func clear(_ recordID: Int, _ tableName: String) {
        do {
            try database.connection?.run(table.filter(self.recordID == recordID && self.tableName == tableName).delete())
        } catch {
            
        }
    }
    
    public func insert(_ recordID: Int, _ tableName: String, _ type: DatabaseChangeType){
        do {
            if(type == .update){
                let old = getChange(recordID, tableName)
                if(old != nil && old?.type != .update){
                    return
                }
            } else if(type == .delete) {
                let old = getChange(recordID, tableName)
                if(old?.type == .insert) {
                    clear(recordID, tableName)
                    return
                }
            }
            
            clear(recordID, tableName)
            try database.connection?.run(table.insert(
                self.type <- type.rawValue,
                self.recordID <- recordID,
                self.tableName <- tableName,
                self.timestamp <- "\(Date.now)"
            ))
        } catch {
            
        }
    }
    
    public func getChange(_ recordID: Int, _ tableName: String) -> DatabaseChange? {
        guard let db = database.connection else { return nil }
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
        guard let db = database.connection else { return nil }
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
    
    
    public func createTable() {
        let createTable = table.create(ifNotExists: true) { (table) in
            table.column(id, primaryKey: .default)
            table.column(type)
            table.column(recordID)
            table.column(tableName)
            table.column(timestamp)
        }
        
        _ = try? database.connection?.run(createTable)
    }
}

struct TrackTableKey: DependencyKey {
    static var liveValue = TrackTable()
    static var mockValue = TrackTable()
}

public extension DependencyValues {
    var track: TrackTable {
        get { Self[TrackTableKey.self] }
        set { Self[TrackTableKey.self] = newValue }
    }
}
