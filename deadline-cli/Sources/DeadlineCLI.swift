// DeadlineCLI.swift
// Main entry point and command definitions for the deadline-cli tool.

import ArgumentParser
import Foundation

@main
struct DeadlineCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "deadline-cli",
        abstract: "Read and write DeadlineCalendar data via iCloud backups.",
        subcommands: [
            ListCommand.self,
            StatusCommand.self,
            CompleteCommand.self,
            TriggerCommand.self,
            AdjustCommand.self,
            ExportCommand.self,
        ]
    )
}

// MARK: - Shared Helpers

let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f
}()

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

/// Find projects matching a partial, case-insensitive title.
func findProjects(_ projects: [Project], matching query: String) -> [Project] {
    let lower = query.lowercased()
    return projects.filter { $0.title.lowercased().contains(lower) }
}

/// Find sub-deadlines matching a partial, case-insensitive title within a project.
func findSubDeadlines(in project: Project, matching query: String) -> [(index: Int, subDeadline: SubDeadline)] {
    let lower = query.lowercased()
    return project.subDeadlines.enumerated().compactMap { (i, sd) in
        sd.title.lowercased().contains(lower) ? (i, sd) : nil
    }
}

// MARK: - List Command

struct ListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all projects sorted by deadline."
    )

    func run() throws {
        let store = try DataStore()
        let (projects, _, _, _) = try store.loadProjectsResolved()

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

            print("\(statusIcon) \(project.title)\(templateStr)")
            print("    Deadline: \(deadline) (\(urgency))")

            if !project.subDeadlines.isEmpty {
                for sd in project.subDeadlines.sorted(by: { $0.date < $1.date }) {
                    let check = sd.isCompleted ? "x" : " "
                    let sdDays = daysUntil(sd.date)
                    let sdDate = displayDateFormatter.string(from: sd.date)
                    print("    [\(check)] \(sd.title) - \(sdDate) (\(urgencyIndicator(sdDays)))")
                }
            }
            print()
        }

        // Show which backup was read
        if let url = try? store.latestBackupURL() {
            print("(Source: \(url.lastPathComponent))")
        }
    }
}

// MARK: - Status Command

struct StatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show active/overdue items — the quick-glance command."
    )

    func run() throws {
        let store = try DataStore()
        let (projects, _, _, _) = try store.loadProjectsResolved()
        let today = Calendar.current.startOfDay(for: Date())
        let fourteenDaysFromNow = Calendar.current.date(byAdding: .day, value: 14, to: today)!

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

        // Show source
        if let url = try? store.latestBackupURL() {
            print("(Source: \(url.lastPathComponent))")
        }
    }
}

// MARK: - Complete Command

struct CompleteCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "complete",
        abstract: "Mark a sub-deadline as completed."
    )

    @Argument(help: "Partial project title to match (case-insensitive).")
    var projectTitle: String

    @Argument(help: "Partial sub-deadline title to match (case-insensitive).")
    var subDeadlineTitle: String

    func run() throws {
        let store = try DataStore()
        let backup = try store.loadLatest()

        let matchedProjects = findProjects(backup.projects, matching: projectTitle)

        guard !matchedProjects.isEmpty else {
            print("No projects matching '\(projectTitle)'.")
            return
        }
        guard matchedProjects.count == 1 else {
            print("Ambiguous project match for '\(projectTitle)':")
            for p in matchedProjects { print("  - \(p.title)") }
            return
        }

        let projectIndex = backup.projects.firstIndex { $0.id == matchedProjects[0].id }!
        let matches = findSubDeadlines(in: backup.projects[projectIndex], matching: subDeadlineTitle)

        guard !matches.isEmpty else {
            print("No sub-deadlines matching '\(subDeadlineTitle)' in '\(backup.projects[projectIndex].title)'.")
            return
        }
        guard matches.count == 1 else {
            print("Ambiguous sub-deadline match for '\(subDeadlineTitle)':")
            for m in matches {
                let check = m.subDeadline.isCompleted ? "x" : " "
                print("  [\(check)] \(m.subDeadline.title)")
            }
            return
        }

        let sdIndex = matches[0].index
        if backup.projects[projectIndex].subDeadlines[sdIndex].isCompleted {
            print("'\(matches[0].subDeadline.title)' is already completed.")
            return
        }

        let url = try store.mutate { data in
            let pi = data.projects.firstIndex { $0.id == matchedProjects[0].id }!
            data.projects[pi].subDeadlines[sdIndex].isCompleted = true
        }
        print("Marked '\(matches[0].subDeadline.title)' as completed in '\(backup.projects[projectIndex].title)'.")
        print("Saved to: \(url.lastPathComponent)")
        print("Restore this backup in the app to sync the change.")
    }
}

// MARK: - Trigger Command

struct TriggerCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "trigger",
        abstract: "Activate a trigger on a project."
    )

    @Argument(help: "Partial project title to match (case-insensitive).")
    var projectTitle: String

    @Argument(help: "Partial trigger name to match (case-insensitive).")
    var triggerName: String

    func run() throws {
        let store = try DataStore()
        let (projects, _, _, _) = try store.loadProjectsResolved()

        let matchedProjects = findProjects(projects, matching: projectTitle)

        guard !matchedProjects.isEmpty else {
            print("No projects matching '\(projectTitle)'.")
            return
        }
        guard matchedProjects.count == 1 else {
            print("Ambiguous project match for '\(projectTitle)':")
            for p in matchedProjects { print("  - \(p.title)") }
            return
        }

        let project = matchedProjects[0]
        let lower = triggerName.lowercased()
        let matchedTriggers = project.triggers.filter {
            $0.name.lowercased().contains(lower)
        }

        guard !matchedTriggers.isEmpty else {
            print("No triggers matching '\(triggerName)' in '\(project.title)'.")
            if !project.triggers.isEmpty {
                print("Available triggers:")
                for t in project.triggers {
                    let status = t.isActive ? "active" : "inactive"
                    print("  - \(t.name) (\(status))")
                }
            }
            return
        }
        guard matchedTriggers.count == 1 else {
            print("Ambiguous trigger match for '\(triggerName)':")
            for t in matchedTriggers {
                let status = t.isActive ? "active" : "inactive"
                print("  - \(t.name) (\(status))")
            }
            return
        }

        let trigger = matchedTriggers[0]
        if trigger.isActive {
            print("Trigger '\(trigger.name)' is already active.")
            return
        }

        let url = try store.mutate { data in
            // Update in the top-level triggers array
            if let ti = data.triggers.firstIndex(where: { $0.id == trigger.id }) {
                data.triggers[ti].isActive = true
                data.triggers[ti].activationDate = Date()
            }
            // Also update if embedded in the project
            if let pi = data.projects.firstIndex(where: { $0.id == project.id }) {
                if let ti = data.projects[pi].triggers.firstIndex(where: { $0.id == trigger.id }) {
                    data.projects[pi].triggers[ti].isActive = true
                    data.projects[pi].triggers[ti].activationDate = Date()
                }
            }
        }
        print("Activated trigger '\(trigger.name)' on '\(project.title)'.")
        print("Saved to: \(url.lastPathComponent)")
        print("Restore this backup in the app to sync the change.")
    }
}

// MARK: - Adjust Command

struct AdjustCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "adjust",
        abstract: "Change the date of a sub-deadline."
    )

    @Argument(help: "Partial project title to match (case-insensitive).")
    var projectTitle: String

    @Argument(help: "Partial sub-deadline title to match (case-insensitive).")
    var subDeadlineTitle: String

    @Option(name: .long, help: "New date in YYYY-MM-DD format.")
    var date: String

    func run() throws {
        let store = try DataStore()
        let backup = try store.loadLatest()

        guard let newDate = dateFormatter.date(from: date) else {
            print("Invalid date format '\(date)'. Expected YYYY-MM-DD.")
            return
        }

        let matchedProjects = findProjects(backup.projects, matching: projectTitle)

        guard !matchedProjects.isEmpty else {
            print("No projects matching '\(projectTitle)'.")
            return
        }
        guard matchedProjects.count == 1 else {
            print("Ambiguous project match for '\(projectTitle)':")
            for p in matchedProjects { print("  - \(p.title)") }
            return
        }

        let project = matchedProjects[0]
        let matches = findSubDeadlines(in: project, matching: subDeadlineTitle)

        guard !matches.isEmpty else {
            print("No sub-deadlines matching '\(subDeadlineTitle)' in '\(project.title)'.")
            return
        }
        guard matches.count == 1 else {
            print("Ambiguous sub-deadline match for '\(subDeadlineTitle)':")
            for m in matches { print("  - \(m.subDeadline.title)") }
            return
        }

        let sdIndex = matches[0].index
        let oldDate = displayDateFormatter.string(from: project.subDeadlines[sdIndex].date)

        let url = try store.mutate { data in
            let pi = data.projects.firstIndex { $0.id == project.id }!
            data.projects[pi].subDeadlines[sdIndex].date = newDate
        }
        let newDateStr = displayDateFormatter.string(from: newDate)
        print("Adjusted '\(matches[0].subDeadline.title)' in '\(project.title)': \(oldDate) -> \(newDateStr)")
        print("Saved to: \(url.lastPathComponent)")
        print("Restore this backup in the app to sync the change.")
    }
}

// MARK: - Export Command

struct ExportCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "export",
        abstract: "Dump the full data as formatted JSON to stdout."
    )

    func run() throws {
        let store = try DataStore()
        let backup = try store.loadLatest()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(backup)
        if let json = String(data: data, encoding: .utf8) {
            print(json)
        }
    }
}
