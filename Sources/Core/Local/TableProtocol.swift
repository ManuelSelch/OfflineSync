import Foundation
import SQLite
import Dependencies

/*
 sync system:
 - fetch remote data
 - update old local data by timestamp
 - update old remote data
 */
public protocol TableSyncProtocol: Encodable {
    var metaFields: [String: String] { get set }
}

public protocol TableProtocol: Codable, Equatable, Identifiable {
    var id: Int { get set }
    /// Mirror(reflecting: T())
    init()
}



public extension Array where Element: TableProtocol {
    func get(_ id: Int?) -> Element? {
        return self.first(where: {$0.id == id})
    }
}


