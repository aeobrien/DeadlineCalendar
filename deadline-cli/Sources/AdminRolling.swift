import Foundation

/// Pure conversion for the one monthly Admin project. File reads and writes stay in DataStore,
/// which means callers can show this result before any mutation is authorised.
enum AdminRollingConversion {
    struct Preview: Codable {
        let removedProjectIDs: [UUID]
        let createdProjects: [Project]
    }

    enum ConversionError: Error, LocalizedError {
        case noAdminProjects
        var errorDescription: String? { "No projects titled Admin were found." }
    }

    static func preview(document: SharedData, now: Date = Date(), calendar: Calendar = .current) throws -> Preview {
        let copies = document.projects.filter { $0.title.caseInsensitiveCompare("Admin") == .orderedSame }
        guard let template = copies.min(by: { abs($0.finalDeadlineDate.timeIntervalSince(now)) < abs($1.finalDeadlineDate.timeIntervalSince(now)) }) else {
            throw ConversionError.noAdminProjects
        }
        let current = occurrence(from: template, monthContaining: now, calendar: calendar, isSource: true)
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: now)!
        let next = occurrence(from: template, monthContaining: nextMonth, calendar: calendar, isSource: false, sourceID: current.id)
        return Preview(removedProjectIDs: copies.map(\.id), createdProjects: [current, next])
    }

    static func apply(document: SharedData, now: Date = Date(), calendar: Calendar = .current) throws -> SharedData {
        let plan = try preview(document: document, now: now, calendar: calendar)
        var converted = document
        let removed = Set(plan.removedProjectIDs)
        converted.projects.removeAll { removed.contains($0.id) }
        converted.triggers.removeAll { removed.contains($0.projectID) }
        converted.projects.append(contentsOf: plan.createdProjects)
        return converted
    }

    private static func occurrence(from template: Project, monthContaining date: Date, calendar: Calendar, isSource: Bool, sourceID: UUID? = nil) -> Project {
        let month = calendar.dateComponents([.year, .month], from: date)
        let start = calendar.date(from: month)!
        let lastDay = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start)!
        let delta = calendar.dateComponents([.day], from: template.finalDeadlineDate, to: lastDay).day ?? 0
        let subDeadlines = template.subDeadlines.map { deadline in
            SubDeadline(title: deadline.title,
                        date: calendar.date(byAdding: .day, value: delta, to: deadline.date) ?? deadline.date,
                        isCompleted: false,
                        subtasks: deadline.subtasks.map { Subtask(title: $0.title) },
                        templateSubDeadlineID: deadline.templateSubDeadlineID)
        }
        let pattern = RepetitionPattern(type: .fixedInterval, intervalValue: 1, intervalUnit: .months,
                                        maxOccurrences: 2)
        return Project(title: "Admin", finalDeadlineDate: lastDay,
                       subDeadlines: subDeadlines.sorted { $0.date < $1.date },
                       templateID: template.templateID, templateName: template.templateName,
                       repetitionPattern: pattern,
                       repetitionSourceID: isSource ? nil : sourceID,
                       repetitionOccurrenceNumber: isSource ? 1 : 2)
    }
}
