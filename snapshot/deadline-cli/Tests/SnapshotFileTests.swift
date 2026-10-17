import XCTest
@testable import deadline_cli
import Foundation

final class SnapshotFileTests: XCTestCase {
    var directory: URL!
    var url: URL!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        url = directory.appendingPathComponent("synthetic.json")
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }
    func testMissingReadDoesNotCreateAnything() throws {
        XCTAssertNil(try SnapshotFile(url: url).read())
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), [])
    }
    func testExpectedBytesRejectStaleSave() throws {
        let store = SnapshotFile(url: url)
        try Data("A".utf8).write(to: url)
        let old = try store.read()
        _ = try store.update { _ in Data("B".utf8) }
        XCTAssertThrowsError(try store.update(expected: .bytes(old)) { _ in Data("C".utf8) })
        XCTAssertEqual(try store.read(), Data("B".utf8))
    }
    func testThrowingMutationPreservesBytesAndReleasesLock() throws {
        let store = SnapshotFile(url: url)
        try Data("A".utf8).write(to: url)
        XCTAssertThrowsError(try store.update { _ in throw NSError(domain: "fixture", code: 1) })
        XCTAssertEqual(try store.read(), Data("A".utf8))
        _ = try store.update { _ in Data("B".utf8) }
        XCTAssertEqual(try store.read(), Data("B".utf8))
    }
    func testNoopPreservesModificationTime() throws {
        let store = SnapshotFile(url: url)
        try Data("A".utf8).write(to: url)
        let before = try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        _ = try store.update { $0 }
        XCTAssertEqual(try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate, before)
    }
    func testSymlinkCannotRedirectReadOrWrite() throws {
        let target = directory.appendingPathComponent("target")
        try Data("private".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: url, withDestinationURL: target)
        let store = SnapshotFile(url: url)
        XCTAssertThrowsError(try store.read())
        XCTAssertThrowsError(try store.update { _ in Data("changed".utf8) })
        XCTAssertEqual(try Data(contentsOf: target), Data("private".utf8))
    }
    func testUnavailableMetadataRefusesBeforeMutationAndPreservesFile() throws {
        try Data("original".utf8).write(to: url)
        let store = SnapshotFile(url: url, availabilityCheck: { _ in throw SnapshotError.unavailable })
        XCTAssertThrowsError(try store.read())
        var called = false
        XCTAssertThrowsError(try store.update { _ in called = true; return Data() })
        XCTAssertFalse(called)
        XCTAssertEqual(try Data(contentsOf: url), Data("original".utf8))
    }
    func testFailedWriteAndLockSymlinkPreserveCurrentData() throws {
        try Data("original".utf8).write(to: url)
        let lock = URL(fileURLWithPath: url.path + ".lock")
        let destination = directory.appendingPathComponent("other")
        try Data("untouched".utf8).write(to: destination)
        try FileManager.default.createSymbolicLink(at: lock, withDestinationURL: destination)
        XCTAssertThrowsError(try SnapshotFile(url: url).update { _ in Data("wrong".utf8) })
        XCTAssertEqual(try Data(contentsOf: url), Data("original".utf8))
        XCTAssertEqual(try Data(contentsOf: destination), Data("untouched".utf8))
    }
}
