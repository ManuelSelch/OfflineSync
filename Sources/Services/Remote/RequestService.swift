import Foundation
import Combine
import Moya
import Dependencies

import OfflineSyncCore

public protocol RequestServiceProtocol<Model> {
    associatedtype Model: TableProtocol
    
    func setPlugins(_ plugins: [PluginType])
    
    func fetch() async throws -> [Model]
    func insert(_ model: Model) async throws -> Model
    func update(_ model: Model) async throws -> Model
    func delete(_ id: Int) async throws
}

public class RequestService<Model: TableProtocol, API: TargetType>: RequestServiceProtocol {
    private var fetchMethod:  () -> API
    private var insertMethod: ((Model) -> API)? = nil
    private var updateMethod: ((Model) -> API)? = nil
    private var deleteMethod: ((Int) -> API)? = nil
    
    private var provider: MoyaProvider<API>
    
    var _setPlugins: ([PluginType]) -> (MoyaProvider<API>)
    
    init(
        fetchMethod: @escaping () -> API,
        insertMethod: ((Model) -> API)? = nil,
        updateMethod: ((Model) -> API)? = nil,
        deleteMethod: ((Int) -> API)? = nil,
        
        provider: MoyaProvider<API>,
        _setPlugins: @escaping ([PluginType]) -> MoyaProvider<API>
    ) {
        self.fetchMethod = fetchMethod
        self.insertMethod = insertMethod
        self.updateMethod = updateMethod
        self.deleteMethod = deleteMethod
        self.provider = provider
        self._setPlugins = _setPlugins
    }
    
    public func setPlugins(_ plugins: [PluginType]) {
        self.provider = _setPlugins(plugins)
    }
    
    public func fetch() async throws -> [Model] {
        if let response: [Model] = try await request(provider, fetchMethod()) {
            return response
        }
        throw ServiceError.decodeFailed
    }
    
    public func insert(_ model: Model) async throws -> Model {
        guard let insertMethod = insertMethod else {
            throw ServiceError.remoteMethodNotDefined
        }
        
        if let response: Model = try await request(provider, insertMethod(model)) {
            return response
        }
        throw ServiceError.decodeFailed
    }
    
    public func update(_ model: Model) async throws -> Model {
        guard let updateMethod = updateMethod else {
            throw ServiceError.remoteMethodNotDefined
        }
        
        if let response: Model = try await request(provider, updateMethod(model)) {
            return response
        }
        throw ServiceError.decodeFailed
    }
    
    public func delete(_ id: Int) async throws {
        guard let deleteMethod = deleteMethod else {
            throw ServiceError.remoteMethodNotDefined
        }
        
        let _: Model? = try await request(provider, deleteMethod(id))
    }
    
    private func request<Response: Decodable, TargetType>(_ provider: MoyaProvider<TargetType>, _ method: TargetType) async throws -> Response? {
        return try await withCheckedThrowingContinuation { continuation in
            provider.request(method){ result in
                switch result {
                case .success(let response):
                    if (response.statusCode == 204){ // no content
                        continuation.resume(returning: nil)
                    } else if let data = try? JSONDecoder().decode(Response.self, from: response.data) {
                        continuation.resume(returning: data)
                    }else {
                        if let string = String(data: response.data, encoding: .utf8) {
                            continuation.resume(throwing: ServiceError.unknown(method.path + " -> " + string))
                        }else{
                            continuation.resume(throwing: ServiceError.decodeFailed)
                        }
                    }
                case .failure(let error):
                    continuation.resume(throwing: ServiceError.unknown(method.path + " -> " + error.localizedDescription))
                }
            }
        }
    }
}

extension RequestService {
    public static func live(
        fetchMethod:  @escaping () -> API,
        insertMethod: ((Model) -> API)? = nil,
        updateMethod: ((Model) -> API)? = nil,
        deleteMethod: ((Int) -> API)? = nil
    ) -> RequestService
    {
        return .init(
            fetchMethod: fetchMethod,
            insertMethod: insertMethod,
            updateMethod: updateMethod,
            deleteMethod: deleteMethod,
            provider: MoyaProvider<API>(),
            _setPlugins: { plugins in
                return MoyaProvider<API>(plugins: plugins)
            }
        )
    }
    
    public static func mock(
        fetchMethod:  @escaping () -> API,
        insertMethod: ((Model) -> API)? = nil,
        updateMethod: ((Model) -> API)? = nil,
        deleteMethod: ((Int) -> API)? = nil
    ) -> RequestService
    {
        return .init(
            fetchMethod: fetchMethod,
            insertMethod: insertMethod,
            updateMethod: updateMethod,
            deleteMethod: deleteMethod,
            provider: MoyaProvider<API>(stubClosure: MoyaProvider.immediatelyStub),
            _setPlugins: { plugins in
                return MoyaProvider<API>(stubClosure: MoyaProvider.immediatelyStub, plugins: plugins)
            }
        )
    }
}
