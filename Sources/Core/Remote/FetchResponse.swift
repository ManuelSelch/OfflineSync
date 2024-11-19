import Foundation
import Combine
import Moya

public struct FetchResponse<Response> {
    public var response: Response
    public var headers: [AnyHashable: Any]
    
    public init(_ response: Response, _ headers: [AnyHashable: Any]){
        self.response = response
        self.headers = headers
    }
}
