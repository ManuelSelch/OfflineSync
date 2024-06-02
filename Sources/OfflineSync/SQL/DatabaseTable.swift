import Foundation
import SQLite
import Redux

/*
 sync system:
 - fetch remote data
 - update old local data by timestamp
 - update old remote data
 */
@available(iOS 16.0, *)
public protocol TableSyncProtocol: Encodable {
    var metaFields: [String: String] { get set }
}

@available(iOS 16.0, *)
public protocol TableProtocol: Codable, Equatable, Identifiable {
    var id: Int { get set }
    /// Mirror(reflecting: T())
    init()
}

@available(iOS 16.0, *)
public class DatabaseTable<T: TableProtocol> {
    @Dependency(\.database) var database
    @Dependency(\.track) var track
    
    private let table: Table
    private let tableName: String
    private var dbPath: String?
    
    private var id = Expression<Int>("id")
    private var fields: [String: Expression<Any>] = [:]
    
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
    
    /// sets record it to lastID+1 and track changes
    public func create(_ item: T){
        var item = item
        item.id = getLastId() + 1
        insert(item, isTrack: true)
        
    }
    
    public func insert(_ item: T, isTrack: Bool) {
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
    
    public func getTimestamp(_ item: T) -> String {
        return (get(by: item.id) as? TableSyncProtocol)?.metaFields["timestamp"] ?? "\(Date.now)"
    }
    
    public func update(_ item: T, isTrack: Bool) {
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
    
    public func get() -> [T] {
        guard let db = database.connection else { print("no connection db..."); return [] }
        
        createTable()
        
        do {
            let records: [T] = try db.prepare(table).map { row in
                return try row.decode()
            }
            return records
            
        } catch {
            print("error db...: \(error.localizedDescription)")
            return []
        }
    }
    
    public func get(by id: Int) -> T? {
        guard let db = database.connection else { return nil }
        
        do {
            let records: [T] = try db.prepare(table.filter(self.id == id)).map { row in
                return try row.decode()
            }
            return records.first
           
        } catch {
            return nil
        }
    }
    
    private func createTable() {
        let createTable = table.create(ifNotExists: true) { (table) in
            
            let mirror = Mirror(reflecting: T())
            
            for (name, value) in mirror.children {
                guard let name = name else { continue }
                
                let type = type(of: value)
                
                if(name == "id"){
                    table.column(id, primaryKey: .default)
                }else{
                    switch type {
                    case is String.Type:
                        table.column(Expression<String>(name))
                    case is Int.Type:
                        table.column(Expression<Int>(name))
                    case is Bool.Type:
                        table.column(Expression<Bool>(name))
                    case is Double.Type:
                        table.column(Expression<Double>(name))
                        
                    case is String?.Type:
                        table.column(Expression<String?>(name))
                    case is Int?.Type:
                        table.column(Expression<Int?>(name))
                    case is Bool?.Type:
                        table.column(Expression<Bool?>(name))
                    case is Double?.Type:
                        table.column(Expression<Double?>(name))
                        
                    default:
                        table.column(Expression<String>(name))
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
}
