import Foundation

public extension Array where Element == DatabaseChange {
    func get(_ recordID: Int?) -> Element? {
        return self.first(where: {$0.recordID == recordID})
    }
}

@available(iOS 16.0, *)
public struct DatabaseChange: Equatable, Codable, Hashable {
    public var id: Int
    public var type: DatabaseChangeType
    public var recordID: Int
    public var tableName: String
    public var timestamp: String
    
    public init(id: Int, type: DatabaseChangeType, recordID: Int, tableName: String, timestamp: String) {
        self.id = id
        self.type = type
        self.recordID = recordID
        self.tableName = tableName
        self.timestamp = timestamp
    }
}

@available(iOS 16.0, *)
public enum DatabaseChangeType: Int, Codable {
    /// locally updated record
    case update = 0
    /// locally inserted record
    case insert = 1
    /// locally deleted record
    case delete = 2
}

@available(iOS 16.0, *)
public struct SyncResponse<Target> {
    public var change: DatabaseChange
    public var result: Target?
    
    public init(change: DatabaseChange, result: Target? = nil) {
        self.change = change
        self.result = result
    }
}
