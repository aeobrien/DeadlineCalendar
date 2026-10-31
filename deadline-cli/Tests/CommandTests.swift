import XCTest
@testable import deadline_cli

final class CommandTests: XCTestCase {
    private var directory: URL!
    private var dataFile: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("deadline-cli-command-tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        dataFile = directory.appendingPathComponent("DeadlineCalendar.json")
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    private func write(_ projects: [Project]) throws {
        let document = SharedData(projects: projects, templates: [], triggers: [], appSettings: AppSettings(), lastModified: Date(), lastModifiedBy: "fixture")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(document).write(to: dataFile)
    }

    private func read() throws -> SharedData {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SharedData.self, from: Data(contentsOf: dataFile))
    }

    private func run(_ arguments: [String]) throws {
        var command = try DeadlineCLI.parseAsRoot(arguments)
        try command.run()
    }

    func testAddWithIDIsIdempotentAgainstAnExplicitTemporaryDataFile() throws {
        try write([Project(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, title: "Standalone Deadlines", finalDeadlineDate: Date())])
        let id = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let arguments = ["add", "Pay rent", "--date", "2030-01-15", "--id", id.uuidString, "--approved", "--data-file", dataFile.path]

        XCTAssertNoThrow(try run(arguments))
        XCTAssertNoThrow(try run(arguments))

        let document = try read()
        XCTAssertEqual(document.projects.flatMap(\.subDeadlines).filter { $0.id == id }.count, 1)
        XCTAssertEqual(document.projects.flatMap(\.subDeadlines).first { $0.id == id }?.title, "Pay rent")
    }

    func testUpdateThenCompletePersistsTheSameExplicitTemporaryDocument() throws {
        let deadline = SubDeadline(title: "Draft", date: try parseDate("2030-01-15"))
        let project = Project(title: "Client", finalDeadlineDate: try parseDate("2030-02-01"), subDeadlines: [deadline])
        try write([project])

        XCTAssertNoThrow(try run(["update", "--project-id", project.id.uuidString, "--deadline-id", deadline.id.uuidString, "--title", "Submitted", "--date", "2030-01-16", "--data-file", dataFile.path]))
        XCTAssertNoThrow(try run(["complete", "Client", "Submitted", "--data-file", dataFile.path]))

        let saved = try XCTUnwrap(try read().projects.first?.subDeadlines.first)
        XCTAssertEqual(saved.title, "Submitted")
        XCTAssertTrue(saved.isCompleted)
        XCTAssertEqual(Calendar(identifier: .gregorian).component(.day, from: saved.date), 16)
    }

    func testDeleteRefusesAStaleRevisionAndADeadlineFromTheWrongTarget() throws {
        let deadline = SubDeadline(title: "Remove", date: try parseDate("2030-01-15"))
        let project = Project(title: "Client", finalDeadlineDate: try parseDate("2030-02-01"), subDeadlines: [deadline])
        try write([project])

        let store = try DataStore(dataFileURL: dataFile)
        let staleRevision = try store.currentWithRevision().1
        XCTAssertNoThrow(try run(["update", "--project-id", project.id.uuidString, "--deadline-id", deadline.id.uuidString, "--title", "Changed", "--data-file", dataFile.path]))

        XCTAssertThrowsError(try run(["delete", "--project-id", project.id.uuidString, "--deadline-id", deadline.id.uuidString, "--approved", "--revision", staleRevision, "--data-file", dataFile.path]))
        XCTAssertThrowsError(try run(["delete", "--project-id", project.id.uuidString, "--deadline-id", UUID().uuidString, "--preview", "--data-file", dataFile.path]))

        XCTAssertEqual(try read().projects.first?.subDeadlines.map(\.title), ["Changed"])
    }

    func testCompleteRefusesAnAmbiguousDeadlineTitle() throws {
        let project = Project(title: "Client", finalDeadlineDate: try parseDate("2030-02-01"), subDeadlines: [
            SubDeadline(title: "Review design", date: try parseDate("2030-01-15")),
            SubDeadline(title: "Review copy", date: try parseDate("2030-01-16"))
        ])
        try write([project])

        XCTAssertThrowsError(try run(["complete", "Client", "Review", "--data-file", dataFile.path]))
        XCTAssertTrue(try read().projects[0].subDeadlines.allSatisfy { !$0.isCompleted })
    }
}
