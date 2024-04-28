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
public class Database: IDatabase {
    public var connection: Connection?
    private var dbPath: String?
    private var databaseName: String
    
    
    public init(_ databaseName: String) {
        self.databaseName = databaseName
        create()
    }
    
    public func create(){
        if let dirPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            dbPath = dirPath.appendingPathComponent(databaseName).path
            
            do {
                connection = try Connection(dbPath!)
            } catch {
                connection = nil
            }
        }else{
            dbPath = nil
            connection = nil
        }
    }
    
    
    public func reset()
    {
        if let dbPath = dbPath {
            let filemManager = FileManager.default
            do {
                let fileURL = NSURL(fileURLWithPath: dbPath)
                try filemManager.removeItem(at: fileURL as URL)
                print("Database Deleted!")
            } catch {
                print("Error on Delete Database!!!")
            }
        }
        
        create()
    }
    
    public static let mock = DatabaseMock()
}

@available(iOS 16.0, *)
public class DatabaseMock: IDatabase {
    public var connection: Connection?
    
    
    public init() {
        create()
    }
    
    public func create(){
        do {
            connection = try Connection(.inMemory)
        }catch {
            
        }
    }
    
    
    public func reset()
    {
        create()
    }
    
}



