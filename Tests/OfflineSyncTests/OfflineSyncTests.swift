import XCTest
import Moya

@testable import OfflineSync

struct TestTable: TableProtocol {
    var id: Int
    var name: String
    
    init(){
        id = 0
        name = ""
    }
    
    init(_ id: Int, _ name: String){
        self.id = id
        self.name = name
    }
}

enum TestTarget: TargetType {
    case fetch
    case insert(TestTable)
    case update(TestTable)
    case delete(Int)
}

extension TestTarget {
    var baseURL: URL {
        URL(string: "https://test.manuelselch.de")!
    }
    var path: String {
        "/test"
    }
    var method: Moya.Method {
        .get
    }
    var task: Task {
        .requestPlain
    }
    var headers: [String: String]? {
        [:]
    }
    
    var sampleData: Data {
        return """
        {"id":0, "name":"0"}
        """.data(using: .utf8)!
    }
}

final class OfflineSyncTests: XCTestCase {
    var service: RequestService<TestTable, TestTarget>!
    
    override func setUp() {
        let db = Database.mock
        let track = TrackTable(db.connection)
        let table = DatabaseTable<TestTable>(db.connection, "testSync", track)
        let provider = MoyaProvider<TestTarget>(stubClosure: MoyaProvider.immediatelyStub)
        
        service = .init(
            table, provider, .simple(.fetch)
            // TestTarget.insert, TestTarget.update, TestTarget.delete
        )
    }
    
    func testSync_Insert() async throws {
        
        let local: TestTable = .init(1, "1")
        service.create(local)
        
        let synced01 = try await service.sync([])
        XCTAssertEqual(synced01, [local])
        
        let remote: [TestTable] = [
            .init(2, "2"),
            .init(3, "3"),
            .init(4, "4")
        ]
        
        let synced02 = try await service.sync(remote)
        let expect02: [TestTable] = [
            .init(1, "1"),
            .init(2, "2"),
            .init(3, "3"),
            .init(4, "4")
        ]
        XCTAssertEqual(synced02, expect02)
        
    }
    
    func testSync_Update() async throws {
        print("changes -- nil00:")
        
        // create local record
        let local: TestTable = .init(1, "1_local")
        service.create(local)
        let synced01 = try await service.sync([])
        XCTAssertEqual(synced01, [local])
        
        // track table needs to be cleared manually
        // because no remote api is provided
        // -> TODO: mock sync to remote server
        service.table.getTrack()?.clear()
        
        // update by remote record
        let remote: TestTable = .init(1, "1_remote")
        let synced02 = try await service.sync([remote])
        XCTAssertEqual(synced02, [remote])
        
        // update by local record
        let update: TestTable = .init(1, "1_update")
        service.update(update)
        
        let synced03 = try await service.sync([remote])
        XCTAssertEqual(synced03, [update])
            
     
    }
}
