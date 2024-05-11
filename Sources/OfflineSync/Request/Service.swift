import Foundation
import Combine
import Moya


protocol IService {
     
}

public struct FetchResponse<Response> {
    public var response: Response
    public var headers: [AnyHashable: Any]
    
    init(_ response: Response, _ headers: [AnyHashable: Any]){
        self.response = response
        self.headers = headers
    }
}

extension IService {
    func just<T>(_ event: T) -> AnyPublisher<T, Error> {
        return Just(event)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func request<Response: Decodable, TargetType>(_ provider: MoyaProvider<TargetType>, _ method: TargetType) async throws -> FetchResponse<Response> {
        return try await withCheckedThrowingContinuation { continuation in
            provider.request(method){ result in
                switch result {
                case .success(let response):
                    if let data = try? JSONDecoder().decode(Response.self, from: response.data) {
                        let headers = response.response?.allHeaderFields ?? [:]
                        let fetchResponse: FetchResponse<Response> = FetchResponse(data, headers)
                        continuation.resume(returning: fetchResponse)
                    }else {
                        if let string = String(data: response.data, encoding: .utf8) {
                            continuation.resume(throwing: OfflineSyncError.unknown(method.path + " -> " + string))
                        }else{
                            continuation.resume(throwing: OfflineSyncError.decodeFailed)
                        }
                    }
                case .failure(let error):
                    continuation.resume(throwing: OfflineSyncError.unknown(method.path + " -> " + error.localizedDescription))
                }
            }
        }
    }
}
