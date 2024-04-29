import Foundation
import Combine
import Moya


public class IRequestService<Table: TableProtocol, Target: TargetType> { // todo: use protocol
    /// get local records
    public func get() -> [Table] {
        return []
    }
    
    /// get local record by id
    public func get(by id: Int) -> Table? {
        return nil
    }
    /// load remote records
    public func fetch() -> AnyPublisher<[Table], Error> {
        return Empty().eraseToAnyPublisher()
    }
    
    /// create local record
    public func create(_ item: Table){
        
    }
    
    /// update local record
    public func update(_ item: Table){
        
    }
    
    ///  sync remote with local records
    public func sync(_ remoteRecords: [Table]) -> AnyPublisher<SyncResponse<Table>, Error>{
        return Empty().eraseToAnyPublisher()
    }
    
    /// this change has been synced -> delete change history
    public func hasSynced(_ response: SyncResponse<Table>) {
        
    }
    
    public init(){}
}
