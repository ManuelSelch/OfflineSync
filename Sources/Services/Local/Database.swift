import Foundation
import SQLite
import Combine
import Dependencies

public protocol IDatabase {
    var connection: Connection? { get }
    func create()
    func reset()
}

public struct Database {
    public var connection: Connection? {
        getConnection()
    }
    public var getConnection: () -> (Connection?)
    
    public var reset: () -> ()
    
    public var switchDB: (String) -> ()
    
    static public let liveValue = Database.live(name: nil)
    static public let testValue: Database = .mock
}

extension Database {
    public static func live(name: String?) -> Self {
        var dbPath: String?
        var connection: Connection?
        
        func createDB(_ name: String?){
            if let databaseName = name,
               let dirPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            {
                dbPath = dirPath.appendingPathComponent(databaseName).path
                
                do {
                    connection = try Connection(dbPath!)
                    print("connected")
                } catch {
                    connection = nil
                    print("connection error")
                }
            }else {
                print("no db path")
            }
        }
        
        createDB(name)
        
        return Self(
            getConnection: {connection},
            reset: {
                print("start delete database")
                if let dbPath = dbPath {
                    let filemManager = FileManager.default
                    do {
                        let fileURL = NSURL(fileURLWithPath: dbPath)
                        try filemManager.removeItem(at: fileURL as URL)
                        print("Database Deleted")
                    } catch {
                        print("Error on Delete Database")
                    }
                } else {
                    print("Database path not found")
                }
            },
            switchDB: { name in
                print("switch database to: \(name)")
                createDB(name)
            }
        )
    }
    
    public static var mock: Self {
        var connection = try? Connection(.inMemory)
        
        return Self(
            getConnection: {connection},
            reset: { connection = nil },
            switchDB: { _ in
                connection = try? Connection(.inMemory)
            }
        )
    }
    
}


struct DatabaseKey: DependencyKey {
    static var liveValue = Database.live(name: nil)
    static var mockValue = Database.mock
}


public extension DependencyValues {
    var database: Database {
        get { Self[DatabaseKey.self] }
        set { Self[DatabaseKey.self] = newValue }
    }
}


