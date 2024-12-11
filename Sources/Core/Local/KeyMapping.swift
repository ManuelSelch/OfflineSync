import Foundation

public extension Array where Element == KeyMapping {
    /*
     func get(_ recordID: Int?) -> Element? {
        return self.first(where: {$0.recordID == recordID})
    }
     */
}

public struct KeyMapping: Equatable, Codable, Hashable {
    public var id: Int
    public var tableName: String
    public var localID: Int
    public var remoteID: Int
    
    public init(_ id: Int, _ tableName: String, _ localID: Int, _ remoteID: Int) {
        self.id = id
        self.tableName = tableName
        self.localID = localID
        self.remoteID = remoteID
    }
}


