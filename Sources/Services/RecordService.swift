import OfflineSyncCore
import Moya

public protocol IRecordService<Model> {
    associatedtype Model: TableProtocol
    
    func get() -> [Model]
    func create(_ model: Model)
    func update(_ model: Model)
    func delete(_ id: Int)
    
    func fetch() async throws -> [Model]
    func sync() async throws -> [Model]
    func getChanges() -> [DatabaseChange]
    
    func setPlugins(_ plugins: [PluginType])
}

open class RecordService<Model: TableProtocol>: IRecordService {
    var repository: DatabaseRepository<Model>
    public var requestService: any RequestServiceProtocol<Model>
    var syncService: SyncService<Model>
    
    public init(
        repository: DatabaseRepository<Model>,
        requestService: any RequestServiceProtocol<Model>
    ) {
        self.repository = repository
        self.requestService = requestService
        self.syncService = .init(
            repository: repository,
            remoteInsert: { try await requestService.insert($0) },
            remoteUpdate: { try await requestService.update($0) },
            remoteDelete: { try await requestService.delete($0) }
        )
    }
    
    public func get() -> [Model] {
        return repository.get()
    }
    
    public func create(_ model: Model) {
        var model = model
        model.id = repository.getLastId() + 1
        repository.insert(model, isTrack: true)
    }
    
    public func update(_ model: Model) {
        repository.update(model, isTrack: true)
    }
    
    public func delete(_ id: Int) {
        repository.delete(id, isTrack: true)
    }
    
    public func fetch() async throws -> [Model] {
        return try await requestService.fetch().map { $0 };
    }
    
    public func sync() async throws -> [Model] {
        let localRecords = repository.get()
        let remoteRecords = try await requestService.fetch().map { $0 };
        let synced = try await syncService.sync(localRecords: localRecords, remoteRecords: remoteRecords)
        return synced
    }
    
    public func getChanges() -> [DatabaseChange] {
        return repository.getChanges()
    }
    
    public func setPlugins(_ plugins: [PluginType]) {
        requestService.setPlugins(plugins)
    }
}
