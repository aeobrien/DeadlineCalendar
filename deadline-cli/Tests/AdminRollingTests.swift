import XCTest
@testable import deadline_cli

final class AdminRollingTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(calendar: calendar, year: year, month: month, day: day))!
    }

    private func admin(_ month: Int, completed: Bool = false) -> Project {
        let final = date(2026, month, calendar.range(of: .day, in: .month, for: date(2026, month, 1))!.count)
        return Project(title: "Admin", finalDeadlineDate: final, subDeadlines: [
            SubDeadline(title: "Payments", date: date(2026, month, 23), isCompleted: completed),
            SubDeadline(title: "Expenses", date: date(2026, month, 27), isCompleted: completed),
            SubDeadline(title: "Timesheets", date: date(2026, month, 28), isCompleted: completed)
        ])
    }

    func testPreviewFindsAdminCopiesAndProposesOneCurrentAndOneNextProject() throws {
        let document = SharedData(projects: [admin(9, completed: true), admin(10)], templates: [], triggers: [], appSettings: AppSettings(), lastModified: Date(), lastModifiedBy: "fixture")
        let preview = try AdminRollingConversion.preview(document: document, now: date(2026, 10, 16))
        XCTAssertEqual(preview.removedProjectIDs.count, 2)
        XCTAssertEqual(preview.createdProjects.count, 2)
        XCTAssertEqual(preview.createdProjects[0].title, "Admin")
        XCTAssertEqual(preview.createdProjects[0].repetitionPattern?.intervalUnit, .months)
        XCTAssertEqual(preview.createdProjects[0].repetitionPattern?.maxOccurrences, 2)
        XCTAssertEqual(calendar.component(.month, from: preview.createdProjects[0].finalDeadlineDate), 10)
        XCTAssertEqual(calendar.component(.month, from: preview.createdProjects[1].finalDeadlineDate), 11)
        XCTAssertEqual(preview.createdProjects[1].subDeadlines.map { calendar.component(.day, from: $0.date) }, [23, 27, 28])
    }

    func testApplyPreservesNonAdminProjectsAndRemovesAllAdminCopies() throws {
        let other = Project(title: "Keep me", finalDeadlineDate: date(2026, 12, 1))
        let document = SharedData(projects: [admin(9), admin(10), other], templates: [], triggers: [], appSettings: AppSettings(), lastModified: Date(), lastModifiedBy: "fixture")
        let converted = try AdminRollingConversion.apply(document: document, now: date(2026, 10, 16))
        XCTAssertEqual(converted.projects.filter { $0.title == "Admin" }.count, 2)
        XCTAssertTrue(converted.projects.contains(where: { $0.id == other.id }))
    }

    func testApplyUsesTheExactProjectsShownInPreview() throws {
        let document = SharedData(projects: [admin(9), admin(10)], templates: [], triggers: [], appSettings: AppSettings(), lastModified: Date(), lastModifiedBy: "fixture")
        let preview = try AdminRollingConversion.preview(document: document, now: date(2026, 10, 16))
        let converted = try AdminRollingConversion.apply(document: document, preview: preview)
        XCTAssertEqual(Set(converted.projects.map(\.id)), Set(preview.createdProjects.map(\.id)))
    }

    func testApplyingPreviewRejectsAChangedSetOfProjects() throws {
        let document = SharedData(projects: [admin(9), admin(10)], templates: [], triggers: [], appSettings: AppSettings(), lastModified: Date(), lastModifiedBy: "fixture")
        let preview = try AdminRollingConversion.preview(document: document, now: date(2026, 10, 16))
        var changed = document; changed.projects.removeLast()
        XCTAssertThrowsError(try AdminRollingConversion.apply(document: changed, preview: preview))
    }

    func testPreviewRoundTripsWithTheCLIISODateFormat() throws {
        let document = SharedData(projects: [admin(9)], templates: [], triggers: [], appSettings: AppSettings(), lastModified: Date(), lastModifiedBy: "fixture")
        let preview = try AdminRollingConversion.preview(document: document, now: date(2026, 10, 16))
        let output = AdminRollCommand.Output(revision: "fixture", asOf: "2026-10-16", removedProjectIDs: preview.removedProjectIDs, createdProjects: preview.createdProjects)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        XCTAssertEqual(try decoder.decode(AdminRollCommand.Output.self, from: encoder.encode(output)).createdProjects, output.createdProjects)
    }
}
