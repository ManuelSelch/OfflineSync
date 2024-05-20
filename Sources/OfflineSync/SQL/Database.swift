import Foundation
import SQLite
import Combine

@available(iOS 16.0, *)
public protocol IDatabase {
    var connection: Connection? { get }
    func create()
    func reset()
}

@available(iOS 16.0, *)
public struct Database {
    public var connection: () -> (Connection?)
    public var reset: () -> ()
}

extension Database {
    public static func live(_ databaseName: String) -> Self {
        var dbPath: String?
        var connection: Connection?
        
        if let dirPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            dbPath = dirPath.appendingPathComponent(databaseName).path
            
            do {
                connection = try Connection(dbPath!)
            } catch {
                connection = nil
            }
        }
        
        return Self(
            connection: {connection},
            reset: {
                if let dbPath = dbPath {
                    let filemManager = FileManager.default
                    do {
                        let fileURL = NSURL(fileURLWithPath: dbPath)
                        try filemManager.removeItem(at: fileURL as URL)
                        print("Database Deleted!")
                    } catch {
                        print("Error on Delete Database!!!")
                    }
                } else {
                    print("Database path not found")
                }
            }
        )
    }
    
    public static var mock: Self {
        var connection = try? Connection(.inMemory)
        
        return Self(
            connection: {connection},
            reset: { connection = nil }
        )
    }
}




