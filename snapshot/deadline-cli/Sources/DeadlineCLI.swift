import ArgumentParser
import Foundation

@main
struct DeadlineCLI: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "deadline-cli", abstract: "Read and manage DeadlineCalendar's shared data.", subcommands: [ListCommand.self, StatusCommand.self, ExportCommand.self, AddCommand.self, UpdateCommand.self, CompleteCommand.self, AdjustCommand.self, TriggerCommand.self, DeleteCommand.self])
}

struct StoreOptions: ParsableArguments {
    @Option(name: .long, help: "Explicit JSON file; never falls back to iCloud or backups.") var dataFile: String?
    func store() throws -> DataStore { try DataStore(dataFileURL: dataFile.map { URL(fileURLWithPath: $0) }) }
}
func emit<T: Encodable>(_ value: T) throws {
    let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    print(String(decoding: try encoder.encode(value), as: UTF8.self))
}
func parseDate(_ text: String) throws -> Date {
    let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.calendar = Calendar(identifier: .gregorian)
    f.dateFormat = "yyyy-MM-dd"; f.isLenient = false
    guard let date = f.date(from: text), f.string(from: date) == text else { throw ValidationError("Use a valid calendar date in YYYY-MM-DD format.") }
    return date
}
func identifier(_ value: String) throws -> UUID {
    guard let id = UUID(uuidString: value) else { throw ValidationError("Expected an exact UUID.") }; return id
}
func projectIndex(_ projects: [Project], id: String? = nil, title: String? = nil) throws -> Int {
    let matches: [Int]
    if let id { let uuid = try identifier(id); matches = projects.indices.filter { projects[$0].id == uuid } }
    else if let title, !title.isEmpty { matches = projects.indices.filter { projects[$0].title.localizedCaseInsensitiveContains(title) } }
    else { throw ValidationError("Select a project by ID or unique title.") }
    guard matches.count == 1 else { throw ValidationError(matches.isEmpty ? "Project not found." : "Project selection is ambiguous or has duplicate IDs.") }
    return matches[0]
}
func deadlineIndex(_ project: Project, id: String? = nil, title: String? = nil) throws -> Int {
    let matches: [Int]
    if let id { let uuid = try identifier(id); matches = project.subDeadlines.indices.filter { project.subDeadlines[$0].id == uuid } }
    else if let title, !title.isEmpty { matches = project.subDeadlines.indices.filter { project.subDeadlines[$0].title.localizedCaseInsensitiveContains(title) } }
    else { throw ValidationError("Select a deadline by ID or unique title.") }
    guard matches.count == 1 else { throw ValidationError(matches.isEmpty ? "Deadline not found in this project." : "Deadline selection is ambiguous or has duplicate IDs.") }
    return matches[0]
}
func nonempty(_ value: String) throws -> String {
    guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ValidationError("Title must not be empty.") }; return value
}

let displayDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .none
    return f
}()

func daysUntil(_ date: Date) -> Int {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let target = calendar.startOfDay(for: date)
    return calendar.dateComponents([.day], from: today, to: target).day ?? 0
}

func urgencyIndicator(_ days: Int) -> String {
    if days < 0 { return "OVERDUE" }
    if days == 0 { return "TODAY" }
    if days == 1 { return "TOMORROW" }
    return "in \(days)d"
}

struct ListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all projects sorted by deadline."
    )

    @OptionGroup var storage: StoreOptions
    @Flag(name: .long) var json = false

    func run() throws {
        let store = try storage.store()
        let (projects, _, _, _) = try store.loadProjectsResolved()
        if json { try emit(projects); return }

        if projects.isEmpty {
            print("No projects found.")
            return
        }

        let sorted = projects.sorted { $0.finalDeadlineDate < $1.finalDeadlineDate }

        for project in sorted {
            let days = daysUntil(project.finalDeadlineDate)
            let completedCount = project.subDeadlines.filter { $0.isCompleted }.count
            let totalCount = project.subDeadlines.count
            let templateStr = project.templateName.map { " [\($0)]" } ?? ""
            let statusIcon = project.isFullyCompleted ? "[DONE]" : "[\(completedCount)/\(totalCount)]"
            let deadline = displayDateFormatter.string(from: project.finalDeadlineDate)
            let urgency = urgencyIndicator(days)

            print("\(statusIcon) \(project.title)\(templateStr) [\(project.id.uuidString)]")
            print("    Deadline: \(deadline) (\(urgency))")

            if !project.subDeadlines.isEmpty {
                for sd in project.subDeadlines.sorted(by: { $0.date < $1.date }) {
                    let check = sd.isCompleted ? "x" : " "
                    let sdDays = daysUntil(sd.date)
                    let sdDate = displayDateFormatter.string(from: sd.date)
                    print("    [\(check)] \(sd.title) - \(sdDate) (\(urgencyIndicator(sdDays))) [\(sd.id.uuidString)]")
                }
            }
            print()
        }

    }
}
struct StatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show active/overdue items — the quick-glance command."
    )

    @OptionGroup var storage: StoreOptions
    @Flag(name: .long) var json = false

    func run() throws {
        let store = try storage.store()
        let (projects, _, _, _) = try store.loadProjectsResolved()
        let today = Calendar.current.startOfDay(for: Date())
        let fourteenDaysFromNow = Calendar.current.date(byAdding: .day, value: 14, to: today)!

        if json {
            let visible = projects.map { project -> Project in
                var project = project
                project.subDeadlines = project.subDeadlines.filter {
                    !$0.isCompleted && Calendar.current.startOfDay(for: $0.date) <= fourteenDaysFromNow
                }
                return project
            }.filter { !$0.subDeadlines.isEmpty }
            try emit(visible); return
        }

        var hasOutput = false

        let sorted = projects.sorted { $0.finalDeadlineDate < $1.finalDeadlineDate }

        for project in sorted {
            let incomplete = project.subDeadlines.filter { !$0.isCompleted }
            if incomplete.isEmpty { continue }

            let overdue = incomplete.filter { Calendar.current.startOfDay(for: $0.date) < today }
            let upcoming = incomplete.filter {
                let d = Calendar.current.startOfDay(for: $0.date)
                return d >= today && d <= fourteenDaysFromNow
            }

            if overdue.isEmpty && upcoming.isEmpty { continue }

            hasOutput = true
            let days = daysUntil(project.finalDeadlineDate)
            let completedCount = project.subDeadlines.filter { $0.isCompleted }.count
            let totalCount = project.subDeadlines.count
            let deadline = displayDateFormatter.string(from: project.finalDeadlineDate)

            print("[\(completedCount)/\(totalCount)] \(project.title) — deadline \(deadline) (\(urgencyIndicator(days)))")

            if !overdue.isEmpty {
                print("  OVERDUE:")
                for sd in overdue.sorted(by: { $0.date < $1.date }) {
                    let sdDays = daysUntil(sd.date)
                    let sdDate = displayDateFormatter.string(from: sd.date)
                    print("    ! \(sd.title) — was due \(sdDate) (\(abs(sdDays))d ago)")
                }
            }

            if !upcoming.isEmpty {
                print("  UPCOMING (next 14 days):")
                for sd in upcoming.sorted(by: { $0.date < $1.date }) {
                    let sdDays = daysUntil(sd.date)
                    let sdDate = displayDateFormatter.string(from: sd.date)
                    print("    - \(sd.title) — \(sdDate) (\(urgencyIndicator(sdDays)))")
                }
            }

            // Show inactive triggers
            let inactiveTriggers = project.triggers.filter { !$0.isActive }
            if !inactiveTriggers.isEmpty {
                print("  PENDING TRIGGERS:")
                for trigger in inactiveTriggers {
                    print("    ~ \(trigger.name)")
                }
            }

            print()
        }

        if !hasOutput {
            print("All clear — no overdue or upcoming items in the next 14 days.")
        }

    }
}
struct ExportCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "export", abstract: "Read the complete saved data as JSON; diagnostics use stderr.")
    @OptionGroup var storage: StoreOptions
    func run() throws { try emit(storage.store().readDocument()) }
}

struct AddCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "add", abstract: "Add a deadline after user approval. Supply --id for safe repeat readback.")
    @OptionGroup var storage: StoreOptions
    @Argument var title: String
    @Option(name: .long) var date: String
    @Option(name: .long) var project: String?
    @Option(name: .long) var projectId: String?
    @Option(name: .long) var id: String?
    @Flag(name: .long, help: "Acknowledge the user approved this addition; this flag does not obtain consent.") var approved = false
    func run() throws {
        guard approved else { throw ValidationError("Obtain user approval before adding; then pass --approved.") }
        let title = try nonempty(title); let due = try parseDate(date); let uuid = try id.map(identifier) ?? UUID()
        let record = SubDeadline(id: uuid, title: title, date: due)
        let store = try storage.store()
        try store.mutate { projects,_,_,_ in
            let standaloneID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
            if projectId == nil && project == nil && !projects.contains(where: { $0.id == standaloneID }) {
                projects.append(Project(id: standaloneID, title: "Standalone Deadlines", finalDeadlineDate: due))
            }
            let pi = try projectIndex(projects, id: projectId ?? (project == nil ? "00000000-0000-0000-0000-000000000001" : nil), title: project)
            let all = projects.flatMap { p in p.subDeadlines.filter { $0.id == uuid }.map { (p.id, $0) } }
            if !all.isEmpty {
                guard all.count == 1, all[0].0 == projects[pi].id, all[0].1 == record else { throw ValidationError("This deadline ID already exists with different data. Read it before retrying.") }
                return
            }
            projects[pi].subDeadlines.append(record)
        }
        try emit(record)
    }
}
struct UpdateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "update", abstract: "Edit title, date or completion of one exact deadline.")
    @OptionGroup var storage: StoreOptions
    @Option(name: .long) var projectId: String
    @Option(name: .long) var deadlineId: String
    @Option(name: .long) var title: String?
    @Option(name: .long) var date: String?
    @Option(name: .long) var completed: Bool?
    func run() throws {
        guard title != nil || date != nil || completed != nil else { throw ValidationError("Specify at least one change.") }
        let name = try title.map(nonempty); let due = try date.map(parseDate); var saved: SubDeadline?
        try storage.store().mutate { projects,_,_,_ in
            let pi = try projectIndex(projects,id:projectId); let di = try deadlineIndex(projects[pi],id:deadlineId)
            if let name { projects[pi].subDeadlines[di].title = name }; if let due { projects[pi].subDeadlines[di].date = due }; if let completed { projects[pi].subDeadlines[di].isCompleted = completed }
            saved=projects[pi].subDeadlines[di]
        }
        try emit(saved)
    }
}
struct CompleteCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "complete", abstract: "Complete a uniquely named deadline; resolution happens within the transaction.")
    @OptionGroup var storage: StoreOptions
    @Argument var projectTitle: String
    @Argument var subDeadlineTitle: String
    func run() throws {
        try storage.store().mutate { projects,_,_,_ in let pi=try projectIndex(projects,title:projectTitle);let di=try deadlineIndex(projects[pi],title:subDeadlineTitle);projects[pi].subDeadlines[di].isCompleted=true }
        print("Deadline completed.")
    }
}
struct AdjustCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "adjust", abstract: "Change the date of a uniquely named deadline.")
    @OptionGroup var storage: StoreOptions
    @Argument var projectTitle: String
    @Argument var subDeadlineTitle: String
    @Option(name:.long) var date: String
    func run() throws {
        let due=try parseDate(date)
        try storage.store().mutate { projects,_,_,_ in let pi=try projectIndex(projects,title:projectTitle);let di=try deadlineIndex(projects[pi],title:subDeadlineTitle);projects[pi].subDeadlines[di].date=due }
        print("Deadline date updated.")
    }
}
struct TriggerCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName:"trigger",abstract:"Activate one uniquely named trigger within its project.")
    @OptionGroup var storage:StoreOptions
    @Argument var projectTitle:String
    @Argument var triggerName:String
    func run() throws {
        try storage.store().mutate { projects,_,triggers,_ in
            let pi=try projectIndex(projects,title:projectTitle);let pid=projects[pi].id
            let entries=projects[pi].triggers + triggers.filter{$0.projectID==pid}
            let matches=entries.filter{$0.name.localizedCaseInsensitiveContains(triggerName)}
            let ids=Set(matches.map(\.id));guard ids.count==1,let id=ids.first else {throw ValidationError("Trigger not found or ambiguous.")}
            let time=Date()
            for i in projects[pi].triggers.indices where projects[pi].triggers[i].id==id { if !projects[pi].triggers[i].isActive {projects[pi].triggers[i].isActive=true;projects[pi].triggers[i].activationDate=time} }
            for i in triggers.indices where triggers[i].id==id && triggers[i].projectID==pid { if !triggers[i].isActive {triggers[i].isActive=true;triggers[i].activationDate=time} }
        }
        print("Trigger activated.")
    }
}
struct DeleteCommand: ParsableCommand {
    static let configuration=CommandConfiguration(commandName:"delete",abstract:"Preview and remove exactly one deadline and its nested subtasks after approval.")
    @OptionGroup var storage:StoreOptions
    @Option(name:.long) var projectId:String
    @Option(name:.long) var deadlineId:String
    @Flag(name:.long) var preview=false
    @Flag(name:.long,help:"Acknowledge actual user approval of the previewed removal.") var approved=false
    @Option(name:.long,help:"Exact revision returned by --preview.") var revision:String?
    struct Preview:Encodable { let revision:String;let projectId:UUID;let deadline:SubDeadline;let removesRecurrenceSiblings:Bool }
    func run() throws {
        let store=try storage.store();let (doc,currentRevision)=try store.currentWithRevision();let pi=try projectIndex(doc.projects,id:projectId);let did=try identifier(deadlineId)
        if !preview && approved && revision != nil && !doc.projects[pi].subDeadlines.contains(where:{$0.id==did}) {print("Deadline is already absent; nothing changed.");return}
        let di=try deadlineIndex(doc.projects[pi],id:deadlineId)
        if preview {try emit(Preview(revision:currentRevision,projectId:doc.projects[pi].id,deadline:doc.projects[pi].subDeadlines[di],removesRecurrenceSiblings:false));return}
        guard approved,let revision else {throw ValidationError("Preview removal, obtain user approval, then pass --approved and --revision.")}
        try store.mutate(expectedRevision:revision) { projects,_,_,_ in let pi=try projectIndex(projects,id:projectId);let di=try deadlineIndex(projects[pi],id:deadlineId);projects[pi].subDeadlines.remove(at:di) }
        print("Deadline removed.")
    }
}
