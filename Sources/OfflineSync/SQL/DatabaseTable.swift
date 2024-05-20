import Foundation
import SQLite

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
public struct DatabaseTable<T: TableProtocol> {
    public var clear: () -> ()
    
    /// sets record it to lastID+1 and track changes
    public var create: (_ item: T) -> ()
    
    public var insert: (_ item: T, _ isTrack: Bool) -> ()
    
    public var getLastId: () -> Int
    
    public var getTimestamp: (_ item: T) -> String
    
    public var update: (_ item: T, _ isTrack: Bool) -> ()
    
    public var delete: (_ id: Int, _ isTrack: Bool) -> ()
    
    public var getAll: () -> [T]
    
    public var get: (_ id: Int) -> T?
    
    public var getTrack: () -> TrackTable?
    
    public var getName: () -> String
}



public extension DatabaseTable {
    static func live(_ db: Connection?, _ tableName: String, _ track: TrackTable?) -> Self {
        var id = Expression<Int>("id")
        
        let table = Table(tableName)
        createTable(table, db)
        
        func clear() {
            do {
                try db?.run(table.delete())
            } catch {
                
            }
        }
        
        func createTable(_ table: Table, _ db: Connection?) {
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
                try db?.run(createTable)
            } catch {
                
            }
        }
        
        func create(_ item: T){
            var item = item
            item.id = getLastId() + 1
            insert(item, isTrack: true)
            
        }
        
        func insert(_ item: T, isTrack: Bool) {
            let item = item
            do {
                try db?.run(table.insert(or: .replace, encodable: item))
                if(isTrack){
                    track?.insert(item.id, tableName, .insert)
                }
            } catch {
                print("database insert error: \(error.localizedDescription)")
            }
        }
        
        func getLastId() -> Int {
            return getAll().max(by: { $0.id < $1.id })?.id ?? 0
        }
        
        func getTimestamp(_ item: T) -> String {
            return (getBy(by: item.id) as? TableSyncProtocol)?.metaFields["timestamp"] ?? "\(Date.now)"
        }
        
        func update(_ item: T, isTrack: Bool) {
            do {
                try db?.run(table.filter(id == item.id).update(item))
                if(isTrack){
                    track?.insert(item.id, tableName, .update)
                }
            } catch {
                
            }
        }
        
        func delete(_ idNew: Int, isTrack: Bool) {
            do {
                try db?.run(table.filter(id == idNew).delete())
                if(isTrack){
                    track?.insert(idNew, tableName, .delete)
                }
            } catch {
                
            }
        }
        
        func getAll() -> [T] {
            guard let db = db else { print("no connection db..."); return [] }
            
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
        
        func getBy(by idNew: Int) -> T? {
            guard let db = db else { return nil }
            
            do {
                let records: [T] = try db.prepare(table.filter(id == idNew)).map { row in
                    return try row.decode()
                }
                return records.first
               
            } catch {
                return nil
            }
        }
        
        
        return Self(
            clear: clear,
            create: create,
            insert: insert,
            getLastId: getLastId,
            getTimestamp: getTimestamp,
            update: update,
            delete: delete,
            getAll: getAll,
            get: getBy,
            getTrack: { track },
            getName: { tableName }
        )
    }
    
    
}
