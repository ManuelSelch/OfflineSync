import Foundation

@available(iOS 16.0, *)
public struct DatabaseChange: Equatable, Codable, Hashable {
    public var id: Int
    public var type: DatabaseChangeType
    public var recordID: Int
    public var tableName: String
    public var timestamp: String
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
}
