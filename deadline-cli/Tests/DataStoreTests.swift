import XCTest
@testable import deadline_cli
import Foundation
final class DataStoreTests: XCTestCase {
    func testExplicitMissingNeverFallsBackOrCreates() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("missing.json")
        let store = try DataStore(dataFileURL: url)
        XCTAssertThrowsError(try store.loadProjectsResolved())
        XCTAssertThrowsError(try store.mutate { _,_,_,_ in })
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
    func testThrowingTargetFailureDoesNotRewrite() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("data.json")
        let doc = SharedData(projects: [], templates: [], triggers: [], appSettings: AppSettings(), lastModified: Date(), lastModifiedBy: "fixture")
        let encoder=JSONEncoder();encoder.dateEncodingStrategy = .iso8601
        let original=try encoder.encode(doc);try original.write(to:url)
        let store=try DataStore(dataFileURL:url)
        XCTAssertThrowsError(try store.mutate { _,_,_,_ in throw SnapshotError.missing })
        XCTAssertEqual(try Data(contentsOf:url),original)
    }
}
