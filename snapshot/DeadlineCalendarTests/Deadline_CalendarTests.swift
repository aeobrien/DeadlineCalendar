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
    func testProductionStoreUsesTheDeclaredICloudContainerIdentifier() {
        XCTAssertEqual(SharedDataStore.iCloudContainerIdentifier, "iCloud.AOTondra.Deadline-Calendar")
    }
    func testInitialLoadHydratesUnavailableICloudSnapshotWithoutShowingLoadError() async throws {
        let project = Project(title: "Stored deadline", finalDeadlineDate: Date())
        let document = SharedData(projects: [project], templates: [], triggers: [], appSettings: AppSettings(),
                                  lastModified: Date(), lastModifiedBy: "fixture")
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let original = try encoder.encode(document)
        try original.write(to: url)
        var unavailable = true
        var downloadRequests = 0
        let store = SharedDataStore(fileURL: url,
                                    availabilityCheck: { _ in if unavailable { throw SnapshotError.unavailable } },
                                    downloadRequest: { _ in downloadRequests += 1; unavailable = false })
        let viewModel = DeadlineViewModel(store: store, defaults: defaults, effectsEnabled: false)

        await viewModel.loadInitialData()

        XCTAssertEqual(downloadRequests, 1)
        XCTAssertEqual(viewModel.projects.map { $0.id }, [project.id])
        XCTAssertNil(viewModel.saveError)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.isDownloadingSharedData)
        XCTAssertEqual(try Data(contentsOf: url), original)
    }
    func testInitialLoadUsesCachedDataWithoutShowingAnErrorWhenICloudIsUnavailable() async throws {
        let cached = Project(title: "Cached deadline", finalDeadlineDate: Date())
        defaults.set(try JSONEncoder().encode([cached]), forKey: "projects_v2_key")
        let store = SharedDataStore(fileURL: url, availabilityCheck: { _ in throw SnapshotError.unavailable })
        let viewModel = DeadlineViewModel(store: store, defaults: defaults, effectsEnabled: false)

        await viewModel.loadInitialData()

        XCTAssertEqual(viewModel.projects.map { $0.id }, [cached.id])
        XCTAssertNil(viewModel.saveError)
        XCTAssertFalse(viewModel.isLoading)
    }
    func testInitialLoadUsesCachedDataWhenICloudDownloadDoesNotFinish() async throws {
        let cached = Project(title: "Cached deadline", finalDeadlineDate: Date())
        defaults.set(try JSONEncoder().encode([cached]), forKey: "projects_v2_key")
        let store = SharedDataStore(fileURL: url,
                                    availabilityCheck: { _ in throw SnapshotError.unavailable },
                                    downloadRequest: { _ in })
        let viewModel = DeadlineViewModel(store: store, defaults: defaults, effectsEnabled: false)

        await viewModel.loadInitialData()

        XCTAssertEqual(viewModel.projects.map { $0.id }, [cached.id])
        XCTAssertNil(viewModel.saveError)
        XCTAssertFalse(viewModel.isLoading)
    }
    func testAdminAnchorWalkthroughFixtureUsesOnlyItsOwnJanuaryAndFebruaryProjects() throws {
        let viewModel = DeadlineViewModel.adminAnchorFixture()
        XCTAssertTrue(viewModel.reloadCurrentData())
        XCTAssertEqual(viewModel.projects.map(\.title), ["Admin", "Admin"])
        XCTAssertEqual(Calendar.current.component(.day, from: viewModel.projects[0].subDeadlines[0].date), 31)
        XCTAssertEqual(Calendar.current.component(.day, from: viewModel.projects[1].subDeadlines[0].date), 28)
        XCTAssertEqual(viewModel.projects[1].repetitionSourceID, viewModel.projects[0].id)
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

    func testCompletingRollingAdminPromotesExistingEditedNextMonth() throws {
        let viewModel = model(); XCTAssertTrue(viewModel.reloadCurrentData())
        let pattern = RepetitionPattern(type: .fixedInterval, intervalValue: 1, intervalUnit: .months, maxOccurrences: 2)
        let current = Project(title: "Admin", finalDeadlineDate: Date(), subDeadlines: [SubDeadline(title: "Payments", date: Date())], repetitionPattern: pattern)
        var next = Project(title: "Admin", finalDeadlineDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())!, subDeadlines: [SubDeadline(title: "Payments", date: Date(), subtasks: [Subtask(title: "kept")])], repetitionPattern: pattern, repetitionSourceID: current.id, repetitionOccurrenceNumber: 2)
        XCTAssertTrue(viewModel.addProject(current)); XCTAssertTrue(viewModel.addProject(next))
        XCTAssertTrue(viewModel.toggleSubDeadlineCompletion(current.subDeadlines[0], in: current))
        XCTAssertFalse(viewModel.projects.contains(where: { $0.id == current.id }))
        XCTAssertTrue(viewModel.projects.contains(where: { $0.id == next.id && $0.subDeadlines[0].subtasks.map(\.title) == ["kept"] }))
        XCTAssertTrue(viewModel.toggleSubDeadlineCompletion(current.subDeadlines[0], in: current))
        XCTAssertTrue(viewModel.projects.contains(where: { $0.id == next.id && !$0.subDeadlines[0].isCompleted }))
    }

    func testRollingAdminKeepsLastDayOfMonthWhenNextMonthIsShorter() throws {
        let viewModel = model(); XCTAssertTrue(viewModel.reloadCurrentData())
        let calendar = Calendar.current
        let pattern = RepetitionPattern(type: .fixedInterval, intervalValue: 1, intervalUnit: .months, maxOccurrences: 2)
        let october = calendar.date(from: DateComponents(year: 2026, month: 10, day: 31))!
        let november = calendar.date(from: DateComponents(year: 2026, month: 11, day: 30))!
        let current = Project(title: "Admin", finalDeadlineDate: october,
                              subDeadlines: [SubDeadline(title: "Timesheets", date: october)], repetitionPattern: pattern)
        let next = Project(title: "Admin", finalDeadlineDate: november,
                           subDeadlines: [SubDeadline(title: "Timesheets", date: calendar.date(from: DateComponents(year: 2026, month: 11, day: 28))!)],
                           repetitionPattern: pattern, repetitionSourceID: current.id, repetitionOccurrenceNumber: 2)
        XCTAssertTrue(viewModel.addProject(current)); XCTAssertTrue(viewModel.addProject(next))

        XCTAssertTrue(viewModel.toggleSubDeadlineCompletion(current.subDeadlines[0], in: current))

        let following = try XCTUnwrap(viewModel.projects.first(where: { $0.repetitionSourceID == next.id }))
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: following.finalDeadlineDate), DateComponents(year: 2026, month: 12, day: 31))
        XCTAssertEqual(calendar.component(.day, from: following.subDeadlines[0].date), 28)
    }

    func testRollingAdminTaskReturnsToItsOriginalDayAfterFebruary() throws {
        let viewModel = model(); XCTAssertTrue(viewModel.reloadCurrentData())
        let calendar = Calendar.current
        let pattern = RepetitionPattern(type: .fixedInterval, intervalValue: 1, intervalUnit: .months, maxOccurrences: 2)
        let january = calendar.date(from: DateComponents(year: 2027, month: 1, day: 31))!
        let february = calendar.date(from: DateComponents(year: 2027, month: 2, day: 28))!
        let current = Project(title: "Admin", finalDeadlineDate: january,
                              subDeadlines: [SubDeadline(title: "Month end", date: january)], repetitionPattern: pattern)
        let next = Project(title: "Admin", finalDeadlineDate: february,
                           subDeadlines: [SubDeadline(title: "Month end", date: february)],
                           repetitionPattern: pattern, repetitionSourceID: current.id, repetitionOccurrenceNumber: 2)
        XCTAssertTrue(viewModel.addProject(current)); XCTAssertTrue(viewModel.addProject(next))

        XCTAssertTrue(viewModel.toggleSubDeadlineCompletion(current.subDeadlines[0], in: current))

        let following = try XCTUnwrap(viewModel.projects.first(where: { $0.repetitionSourceID == next.id }))
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: following.finalDeadlineDate), DateComponents(year: 2027, month: 3, day: 31))
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: following.subDeadlines[0].date), DateComponents(year: 2027, month: 3, day: 31))
    }

    func testEditingClampedRollingAdminTaskUpdatesItsFutureDay() throws {
        let viewModel = model(); XCTAssertTrue(viewModel.reloadCurrentData())
        let calendar = Calendar.current
        let pattern = RepetitionPattern(type: .fixedInterval, intervalValue: 1, intervalUnit: .months, maxOccurrences: 2)
        let january = calendar.date(from: DateComponents(year: 2027, month: 1, day: 31))!
        let february = calendar.date(from: DateComponents(year: 2027, month: 2, day: 28))!
        let current = Project(title: "Admin", finalDeadlineDate: january,
                              subDeadlines: [SubDeadline(title: "Month end", date: january)], repetitionPattern: pattern)
        let next = Project(title: "Admin", finalDeadlineDate: february,
                           subDeadlines: [SubDeadline(title: "Month end", date: february, repetitionDayOfMonth: 31)],
                           repetitionPattern: pattern, repetitionSourceID: current.id, repetitionOccurrenceNumber: 2)
        XCTAssertTrue(viewModel.addProject(current)); XCTAssertTrue(viewModel.addProject(next))

        var edited = next.subDeadlines[0]
        edited.date = calendar.date(from: DateComponents(year: 2027, month: 2, day: 20))!
        XCTAssertTrue(viewModel.updateSubDeadline(edited, in: next))
        XCTAssertTrue(viewModel.toggleSubDeadlineCompletion(current.subDeadlines[0], in: current))

        let following = try XCTUnwrap(viewModel.projects.first(where: { $0.repetitionSourceID == next.id }))
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: following.subDeadlines[0].date), DateComponents(year: 2027, month: 3, day: 20))
    }

    func testProjectEditorStyleEditUpdatesClampedRollingAdminTaskFutureDay() throws {
        let viewModel = model(); XCTAssertTrue(viewModel.reloadCurrentData())
        let calendar = Calendar.current
        let pattern = RepetitionPattern(type: .fixedInterval, intervalValue: 1, intervalUnit: .months, maxOccurrences: 2)
        let january = calendar.date(from: DateComponents(year: 2027, month: 1, day: 31))!
        let february = calendar.date(from: DateComponents(year: 2027, month: 2, day: 28))!
        let current = Project(title: "Admin", finalDeadlineDate: january,
                              subDeadlines: [SubDeadline(title: "Month end", date: january)], repetitionPattern: pattern)
        var next = Project(title: "Admin", finalDeadlineDate: february,
                           subDeadlines: [SubDeadline(title: "Month end", date: february, repetitionDayOfMonth: 31)],
                           repetitionPattern: pattern, repetitionSourceID: current.id, repetitionOccurrenceNumber: 2)
        XCTAssertTrue(viewModel.addProject(current)); XCTAssertTrue(viewModel.addProject(next))

        next.subDeadlines[0].date = calendar.date(from: DateComponents(year: 2027, month: 2, day: 20))!
        XCTAssertTrue(viewModel.updateProject(next))
        XCTAssertTrue(viewModel.toggleSubDeadlineCompletion(current.subDeadlines[0], in: current))

        let following = try XCTUnwrap(viewModel.projects.first(where: { $0.repetitionSourceID == next.id }))
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: following.subDeadlines[0].date), DateComponents(year: 2027, month: 3, day: 20))
    }

    // MARK: - Calendar-based repeats keep day-of-month

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d))!
    }
    private func ymd(_ date: Date) -> [Int] {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return [c.year!, c.month!, c.day!]
    }
    private func repeated(_ project: Project, _ viewModel: DeadlineViewModel) -> [Project] {
        XCTAssertTrue(viewModel.addProject(project))
        viewModel.generateProjectRepetitionOccurrences(for: project)
        return viewModel.projects.filter { $0.repetitionSourceID == project.id }
            .sorted { $0.finalDeadlineDate < $1.finalDeadlineDate }
    }

    func testMonthlyRepeatKeepsSubDeadlineDaysInNovemberAndDecember() throws {
        let viewModel = model(); XCTAssertTrue(viewModel.reloadCurrentData())
        let pattern = RepetitionPattern(type: .fixedInterval, intervalValue: 1, intervalUnit: .months, maxOccurrences: 3)
        let october = Project(title: "Admin", finalDeadlineDate: day(2026, 10, 31),
                              subDeadlines: [SubDeadline(title: "A", date: day(2026, 10, 23)),
                                             SubDeadline(title: "B", date: day(2026, 10, 27)),
                                             SubDeadline(title: "C", date: day(2026, 10, 28))],
                              repetitionPattern: pattern)
        let copies = repeated(october, viewModel)
        print("ADMIN-MONTH November final \(ymd(copies[0].finalDeadlineDate)) tasks \(copies[0].subDeadlines.map { ymd($0.date) })")
        XCTAssertEqual(copies.map { ymd($0.finalDeadlineDate) }, [[2026, 11, 30], [2026, 12, 31]])
        XCTAssertEqual(copies[0].subDeadlines.map { ymd($0.date) }, [[2026, 11, 23], [2026, 11, 27], [2026, 11, 28]])
        XCTAssertEqual(copies[1].subDeadlines.map { ymd($0.date) }, [[2026, 12, 23], [2026, 12, 27], [2026, 12, 28]])
    }

    func testMonthlyRepeatClampsToMonthEndAndRecoversAfterShortMonth() throws {
        let viewModel = model(); XCTAssertTrue(viewModel.reloadCurrentData())
        let pattern = RepetitionPattern(type: .fixedInterval, intervalValue: 1, intervalUnit: .months, maxOccurrences: 3)
        let january = Project(title: "Month end", finalDeadlineDate: day(2027, 1, 31),
                              subDeadlines: [SubDeadline(title: "Late", date: day(2027, 1, 30))],
                              repetitionPattern: pattern)
        let copies = repeated(january, viewModel)
        XCTAssertEqual(copies.map { ymd($0.finalDeadlineDate) }, [[2027, 2, 28], [2027, 3, 31]])
        XCTAssertEqual(copies.map { ymd($0.subDeadlines[0].date) }, [[2027, 2, 28], [2027, 3, 30]])
    }

    func testDayOfMonth31ClampsInShortMonths() throws {
        let viewModel = model(); XCTAssertTrue(viewModel.reloadCurrentData())
        var pattern = RepetitionPattern(type: .dayOfMonth, maxOccurrences: 3)
        pattern.dayOfMonthDay = 31
        let january = Project(title: "Day 31", finalDeadlineDate: day(2027, 1, 31),
                              subDeadlines: [SubDeadline(title: "Early", date: day(2027, 1, 20))],
                              repetitionPattern: pattern)
        let copies = repeated(january, viewModel)
        XCTAssertEqual(copies.map { ymd($0.finalDeadlineDate) }, [[2027, 2, 28], [2027, 3, 31]])
        XCTAssertEqual(copies.map { ymd($0.subDeadlines[0].date) }, [[2027, 2, 20], [2027, 3, 20]])
    }

    func testWeeklyRepeatStillShiftsByDays() throws {
        let viewModel = model(); XCTAssertTrue(viewModel.reloadCurrentData())
        let pattern = RepetitionPattern(type: .fixedInterval, intervalValue: 1, intervalUnit: .weeks, maxOccurrences: 3)
        let project = Project(title: "Weekly", finalDeadlineDate: day(2026, 10, 31),
                              subDeadlines: [SubDeadline(title: "Mid", date: day(2026, 10, 24))],
                              repetitionPattern: pattern)
        let copies = repeated(project, viewModel)
        XCTAssertEqual(copies.map { ymd($0.finalDeadlineDate) }, [[2026, 11, 7], [2026, 11, 14]])
        XCTAssertEqual(copies.map { ymd($0.subDeadlines[0].date) }, [[2026, 10, 31], [2026, 11, 7]])
    }
}
