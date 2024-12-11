import Foundation
import Dependencies
import SQLite

import OfflineSyncCore

public class DatabaseRepository<Model: TableProtocol> {
    @Dependency(\.database) var database
    @Dependency(\.track) var track
    
    private let table: Table
    private let tableName: String
    private var dbPath: String?
    
    private var id = SQLite.Expression<Int>("id")
    private var fields: [String: SQLite.Expression<Any>] = [:]
    
    public init(_ tableName: String) {
        self.tableName = tableName
        
        table = Table(tableName)
        createTable()
    }
    
    public func clear() {
        do {
            try database.connection?.run(table.delete())
        } catch {
            
        }
    }
    
    public func clearChanges(of recordID: Int) {
        track.clear(recordID, tableName)
    }
    
    /// sets record it to lastID+1 and track changes
    public func create(_ item: Model){
        var item = item
        item.id = getLastId() + 1
        insert(item, isTrack: true)
        
    }
    
    public func insert(_ item: Model, isTrack: Bool) {
        let item = item
        do {
            try database.connection?.run(table.insert(or: .replace, encodable: item))
            if(isTrack){
                track.insert(item.id, tableName, .insert)
            }
        } catch {
            print("database insert error: \(error.localizedDescription)")
        }
    }
    
    public func getLastId() -> Int {
        return get().max(by: { $0.id < $1.id })?.id ?? 0
    }
    
    public func getTimestamp(_ item: Model) -> String {
        return (get(by: item.id) as? TableSyncProtocol)?.metaFields["timestamp"] ?? "\(Date.now)"
    }
    
    public func update(_ item: Model, isTrack: Bool) {
        do {
            try database.connection?.run(table.filter(id == item.id).update(item))
            if(isTrack){
                track.insert(item.id, tableName, .update)
            }
        } catch {
            
        }
    }
    
    public func delete(_ id: Int, isTrack: Bool) {
        do {
            try database.connection?.run(table.filter(self.id == id).delete())
            if(isTrack){
                track.insert(id, tableName, .delete)
            }
        } catch {
            
        }
    }
    
    public func get() -> [Model] {
        guard let db = database.connection else { print("no connection db..."); return [] }
        
        createTable()
        
        do {
            let records: [Model] = try db.prepare(table).map { row in
                return try row.decode()
            }
            return records
            
        } catch {
            print("error db...: \(error.localizedDescription)")
            return []
        }
    }
    
    public func get(by id: Int) -> Model? {
        guard let db = database.connection else { return nil }
        
        do {
            let records: [Model] = try db.prepare(table.filter(self.id == id)).map { row in
                return try row.decode()
            }
            return records.first
           
        } catch {
            return nil
        }
    }
    
    private func createTable() {
        track.createTable()
        
        let createTable = table.create(ifNotExists: true) { (table) in
            
            let mirror = Mirror(reflecting: Model())
            
            for (name, value) in mirror.children {
                guard let name = name else { continue }
                
                let type = type(of: value)
                
                if(name == "id"){
                    table.column(id, primaryKey: .default)
                }else{
                    switch type {
                    case is String.Type:
                        table.column(SQLite.Expression<String>(name))
                    case is Int.Type:
                        table.column(SQLite.Expression<Int>(name))
                    case is Bool.Type:
                        table.column(SQLite.Expression<Bool>(name))
                    case is Double.Type:
                        table.column(SQLite.Expression<Double>(name))
                        
                    case is String?.Type:
                        table.column(SQLite.Expression<String?>(name))
                    case is Int?.Type:
                        table.column(SQLite.Expression<Int?>(name))
                    case is Bool?.Type:
                        table.column(SQLite.Expression<Bool?>(name))
                    case is Double?.Type:
                        table.column(SQLite.Expression<Double?>(name))
                        
                    default:
                        table.column(SQLite.Expression<String>(name))
                    }
                }
                
                
                
                
            }
        }
        
        do {
            try database.connection?.run(createTable)
        } catch {
            
        }
    }
    
    public func getName() -> String {
        return tableName
    }
    
    public func getChanges() -> [DatabaseChange] {
        return track.getChanges(tableName) ?? []
    }
}
