import XCTest
@testable import Deadline_Calendar

@MainActor final class Deadline_CalendarTests: XCTestCase {
    var folder: URL!
    var url: URL!
    var defaults: UserDefaults!
    var suite: String!
    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        url = folder.appendingPathComponent("fixture.json")
        suite = "deadline-fixture-" + UUID().uuidString
        defaults = UserDefaults(suiteName: suite)!
    }
    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suite)
        try FileManager.default.removeItem(at: folder)
    }
    func model(_ effects: @escaping () -> Void = {}) -> DeadlineViewModel {
        DeadlineViewModel(store: SharedDataStore(fileURL: url), defaults: defaults, effectsEnabled: false, onCommit: effects)
    }
    func testStaleAppSavePreservesOtherWriterWithoutCacheOrEffects() throws {
        var effects = 0
        let first = model { effects += 1 }
        XCTAssertTrue(first.reloadCurrentData())
        let second = model()
        XCTAssertTrue(second.reloadCurrentData())
        let other = Project(title: "Other writer", finalDeadlineDate: Date())
        XCTAssertTrue(second.addProject(other))
        let bytes = try Data(contentsOf: url)
        let cached = defaults.data(forKey: "projects_v2_key")
        let count = effects
        XCTAssertFalse(first.addProject(Project(title: "Stale edit", finalDeadlineDate: Date())))
        XCTAssertEqual(try Data(contentsOf: url), bytes)
        XCTAssertEqual(defaults.data(forKey: "projects_v2_key"), cached)
        XCTAssertEqual(effects, count)
        XCTAssertNotNil(first.pendingSnapshot)
        XCTAssertNotNil(first.saveError)
        let generation = first.editorGeneration
        XCTAssertTrue(first.reloadCurrentData())
        XCTAssertNotEqual(first.editorGeneration, generation)
        XCTAssertEqual(first.projects.first?.id, other.id)
        XCTAssertTrue(first.addProject(Project(title: "Fresh edit", finalDeadlineDate: Date())))
        XCTAssertEqual(first.projects.count, 2)
    }
    func testExternalNoticeDoesNotAdvanceBaselineOrReplaceDraft() throws {
        let first = model(); XCTAssertTrue(first.reloadCurrentData())
        let second = model(); XCTAssertTrue(second.reloadCurrentData())
        XCTAssertTrue(second.addProject(Project(title: "Current", finalDeadlineDate: Date())))
        let generation = first.editorGeneration
        first.handleExternalSharedDataChange()
        XCTAssertEqual(first.editorGeneration, generation)
        XCTAssertTrue(first.projects.isEmpty)
        XCTAssertTrue(first.newerDataAvailable)
        XCTAssertFalse(first.addProject(Project(title: "Old", finalDeadlineDate: Date())))
    }
    func testCorruptSharedOrLocalDataNeverInitializesEmptyFile() throws {
        let backup = Data("bad local cache".utf8)
        defaults.set(backup, forKey: "projects_v2_key")
        let first = model()
        XCTAssertFalse(first.reloadCurrentData())
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(defaults.data(forKey: "projects_v2_key"), backup)
        try Data("bad shared data".utf8).write(to: url)
        XCTAssertFalse(first.reloadCurrentData())
        XCTAssertFalse(first.addProject(Project(title: "Forbidden", finalDeadlineDate: Date())))
        XCTAssertEqual(try Data(contentsOf: url), Data("bad shared data".utf8))
        XCTAssertEqual(defaults.data(forKey: "projects_v2_key"), backup)
    }
    func testUnavailableStoreDoesNotWriteOrSignalSuccess() throws {
        var effects = 0
        let store = SharedDataStore(fileURL: url, availabilityCheck: { _ in throw SnapshotError.unavailable })
        let first = DeadlineViewModel(store: store, defaults: defaults, effectsEnabled: false, onCommit: { effects += 1 })
        XCTAssertFalse(first.reloadCurrentData())
        XCTAssertFalse(first.addProject(Project(title: "Forbidden", finalDeadlineDate: Date())))
        XCTAssertEqual(effects, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
    func testGroupedChangesCommitOnceAndFailedGroupRetainsWholeAttempt() throws {
        var effects = 0
        let first = model { effects += 1 }; XCTAssertTrue(first.reloadCurrentData())
        let count = effects
        XCTAssertTrue(first.performChanges {
            first.addProject(Project(title: "One", finalDeadlineDate: Date()))
            first.addProject(Project(title: "Two", finalDeadlineDate: Date()))
        })
        XCTAssertEqual(effects, count + 1)
        let second = model(); XCTAssertTrue(second.reloadCurrentData())
        XCTAssertTrue(second.addProject(Project(title: "Concurrent", finalDeadlineDate: Date())))
        let bytes = try Data(contentsOf: url)
        XCTAssertFalse(first.performChanges {
            first.addProject(Project(title: "Three", finalDeadlineDate: Date()))
            first.addProject(Project(title: "Four", finalDeadlineDate: Date()))
        })
        XCTAssertEqual(try Data(contentsOf: url), bytes)
        XCTAssertEqual(first.projects.count, 2)
        XCTAssertEqual(first.pendingSnapshot?.projects.count, 4)
    }
    func testNonDataOrConflictingLegacyCacheCannotInitializeEmptyStore() throws {
        defaults.set("not encoded data", forKey: "projects_v2_key")
        let first = model()
        XCTAssertFalse(first.reloadCurrentData())
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        defaults.set(try JSONEncoder().encode([Project]()), forKey: "projects_v2_key")
        defaults.set(try JSONEncoder().encode([Project(title: "Legacy", finalDeadlineDate: Date())]), forKey: "projects")
        XCTAssertFalse(first.reloadCurrentData())
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertNotNil(defaults.data(forKey: "projects"))
    }
    func testStaleGroupedStandaloneRecurrenceLeavesNoPartialAddition() throws {
        let first = model(); XCTAssertTrue(first.reloadCurrentData())
        let second = model(); XCTAssertTrue(second.reloadCurrentData())
        XCTAssertTrue(second.addProject(Project(title: "Other", finalDeadlineDate: Date())))
        let bytes = try Data(contentsOf: url)
        let deadline = SubDeadline(title: "Repeating", date: Date(), repetitionPattern: RepetitionPattern(type: .fixedInterval, intervalValue: 1, intervalUnit: .days, maxOccurrences: 3))
        XCTAssertFalse(first.performChanges {
            first.addStandaloneDeadline(deadline)
            first.generateRepetitionOccurrences(for: deadline)
        })
        XCTAssertEqual(try Data(contentsOf: url), bytes)
        XCTAssertTrue(first.projects.isEmpty)
        XCTAssertEqual(first.pendingSnapshot?.projects.first?.subDeadlines.count, 3)
    }
    func testUnchangedAppSaveDoesNotRewriteOrInvalidateAnotherWindow() throws {
        var effects = 0
        let first = model { effects += 1 }; XCTAssertTrue(first.reloadCurrentData())
        let second = model(); XCTAssertTrue(second.reloadCurrentData())
        let before = try Data(contentsOf: url); let count = effects
        XCTAssertTrue(first.saveAll())
        XCTAssertEqual(try Data(contentsOf: url), before)
        XCTAssertEqual(effects, count)
        XCTAssertTrue(second.addProject(Project(title: "Still current", finalDeadlineDate: Date())))
    }
    func testDefaultInitialSaveCreatesDocumentsOnlyAfterSuccessfulRead() throws {
        let store = SharedDataStore(containerProvider: { self.folder })
        XCTAssertNil(try store.loadSnapshot())
        let documents = folder.appendingPathComponent("Documents")
        XCTAssertFalse(FileManager.default.fileExists(atPath: documents.path))
        try store.saveSnapshot(projects: [], templates: [], triggers: [], appSettings: AppSettings())
        XCTAssertTrue(FileManager.default.fileExists(atPath: documents.appendingPathComponent("DeadlineCalendar.json").path))
    }
    func testLegacyTemplateWithoutTriggerFieldIsPreserved() throws {
        let id = UUID()
        let old = try JSONSerialization.data(withJSONObject: [["id": id.uuidString, "name": "Legacy template", "subDeadlines": []]])
        defaults.set(old, forKey: "templates_key")
        let first = model()
        XCTAssertTrue(first.reloadCurrentData())
        XCTAssertEqual(first.templates.first?.id, id)
        XCTAssertEqual(first.templates.first?.templateTriggers, [])
    }
    func testSavedProjectsAliasIsPreservedWithoutRemovingKey() throws {
        let project = Project(title: "Old project", finalDeadlineDate: Date())
        let old = try JSONEncoder().encode([project])
        defaults.set(old, forKey: "SavedProjects")
        let first = model()
        XCTAssertTrue(first.reloadCurrentData())
        XCTAssertEqual(first.projects.first?.id, project.id)
        XCTAssertEqual(defaults.data(forKey: "SavedProjects"), old)
    }
    func testMissingLegacyTriggerDateStillMigratesOnSuccessfulLoad() throws {
        let project = Project(title: "Project", finalDeadlineDate: Date(timeIntervalSince1970: 1900000000))
        let trigger = Trigger(name: "Legacy trigger", projectID: project.id)
        defaults.set(try JSONEncoder().encode([project]), forKey: "projects_v2_key")
        defaults.set(try JSONEncoder().encode([trigger]), forKey: "triggers_v1_key")
        let first = model()
        XCTAssertTrue(first.reloadCurrentData())
        XCTAssertEqual(first.triggers.first?.date, Calendar.current.date(byAdding: .day, value: -7, to: project.finalDeadlineDate))
    }
    func testNotificationRequestsAfterFailedLoadOrConflictHaveNoEffects() throws {
        var requested = 0
        let first = DeadlineViewModel(store: SharedDataStore(fileURL: url), defaults: defaults,
            effectsEnabled: false, onNotifications: { requested += 1 })
        try Data("broken".utf8).write(to: url)
        XCTAssertFalse(first.reloadCurrentData())
        first.updateNotifications()
        XCTAssertEqual(requested, 0)
        try FileManager.default.removeItem(at: url)
        XCTAssertTrue(first.reloadCurrentData())
        let count = requested
        let other = model(); XCTAssertTrue(other.reloadCurrentData())
        XCTAssertTrue(other.addProject(Project(title: "Concurrent", finalDeadlineDate: Date())))
        XCTAssertFalse(first.addProject(Project(title: "Stale", finalDeadlineDate: Date())))
        first.updateNotifications()
        XCTAssertEqual(requested, count)
        XCTAssertTrue(first.reloadCurrentData())
        XCTAssertGreaterThan(requested, count)
        let afterReload = requested
        first.handleExternalSharedDataChange()
        first.updateNotifications()
        XCTAssertEqual(requested, afterReload)
    }
    func testMalformedPresentTemplateTriggersAreNotDroppedAsLegacy() throws {
        let bytes = try JSONSerialization.data(withJSONObject: [["id": UUID().uuidString,
            "name": "Malformed", "subDeadlines": [], "templateTriggers": "wrong type"]])
        defaults.set(bytes, forKey: "templates_key")
        let first = model()
        XCTAssertFalse(first.reloadCurrentData())
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(defaults.data(forKey: "templates_key"), bytes)
    }
}
