// Models.swift
// Byte-compatible replica of DeadlineCalendar's Codable models.
// These MUST stay in sync with the app's Models.swift.

import Foundation

// MARK: - Time Offset Unit Enum
enum TimeOffsetUnit: String, Codable, CaseIterable {
    case days, weeks, months
}

// MARK: - Time Offset Struct
struct TimeOffset: Codable, Equatable, Hashable {
    var value: Int
    var unit: TimeOffsetUnit
    var before: Bool = true

    init(value: Int = 7, unit: TimeOffsetUnit = .days, before: Bool = true) {
        self.value = value
        self.unit = unit
        self.before = before
    }
}

// MARK: - Template Trigger Model
struct TemplateTrigger: Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var offset: TimeOffset

    init(id: UUID = UUID(), name: String, offset: TimeOffset = TimeOffset()) {
        self.id = id
        self.name = name
        self.offset = offset
    }
}

// MARK: - Trigger Model
struct Trigger: Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var isActive: Bool = false
    let projectID: UUID
    var activationDate: Date?
    var originatingTemplateTriggerID: UUID?
    var date: Date?

    init(id: UUID = UUID(), name: String, projectID: UUID, date: Date? = nil, isActive: Bool = false, activationDate: Date? = nil, originatingTemplateTriggerID: UUID? = nil) {
        self.id = id
        self.name = name
        self.projectID = projectID
        self.date = date
        self.isActive = isActive
        self.activationDate = activationDate
        self.originatingTemplateTriggerID = originatingTemplateTriggerID
    }
}

// MARK: - Subtask Model
struct Subtask: Codable, Equatable, Hashable {
    let id: UUID
    var title: String
    var isCompleted: Bool = false

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
    }
}

// MARK: - Template SubDeadline Model
struct TemplateSubDeadline: Codable, Equatable, Hashable {
    let id: UUID
    var title: String
    var offset: TimeOffset
    var templateTriggerID: UUID?

    init(id: UUID = UUID(), title: String = "New Sub-Deadline", offset: TimeOffset = TimeOffset(), templateTriggerID: UUID? = nil) {
        self.id = id
        self.title = title
        self.offset = offset
        self.templateTriggerID = templateTriggerID
    }
}

// MARK: - Template Model
struct Template: Codable, Equatable {
    let id: UUID
    var name: String
    var subDeadlines: [TemplateSubDeadline]
    var templateTriggers: [TemplateTrigger]

    init(id: UUID = UUID(), name: String = "New Template", subDeadlines: [TemplateSubDeadline] = [], templateTriggers: [TemplateTrigger] = []) {
        self.id = id
        self.name = name
        self.subDeadlines = subDeadlines
        self.templateTriggers = templateTriggers
    }
}

// MARK: - Repetition Pattern Types
enum RepetitionType: String, Codable, CaseIterable {
    case fixedInterval = "Fixed Interval"
    case dayOfMonth = "Day of Month"
    case none = "None"
}

// MARK: - Day of Month Position
enum DayOfMonthPosition: String, Codable, CaseIterable {
    case first = "First"
    case second = "Second"
    case third = "Third"
    case fourth = "Fourth"
    case last = "Last"
}

// MARK: - Weekday for monthly repetition
enum RepetitionWeekday: Int, Codable, CaseIterable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
}

// MARK: - Repetition Pattern
struct RepetitionPattern: Codable, Equatable, Hashable {
    var type: RepetitionType = .none
    var intervalValue: Int = 1
    var intervalUnit: TimeOffsetUnit = .weeks
    var dayOfMonthPosition: DayOfMonthPosition = .first
    var dayOfMonthWeekday: RepetitionWeekday = .monday
    var dayOfMonthDay: Int? = nil
    var maxOccurrences: Int? = nil
    var endDate: Date? = nil
}

// MARK: - SubDeadline Model (Instance)
struct SubDeadline: Codable, Equatable, Hashable {
    let id: UUID
    var title: String
    var date: Date
    var isCompleted: Bool = false
    var subtasks: [Subtask]
    let templateSubDeadlineID: UUID?
    var triggerID: UUID?
    var repetitionPattern: RepetitionPattern?
    var repetitionSourceID: UUID?
    var repetitionOccurrenceNumber: Int?

    init(id: UUID = UUID(), title: String, date: Date, isCompleted: Bool = false, subtasks: [Subtask] = [], templateSubDeadlineID: UUID? = nil, triggerID: UUID? = nil, repetitionPattern: RepetitionPattern? = nil, repetitionSourceID: UUID? = nil, repetitionOccurrenceNumber: Int? = nil) {
        self.id = id
        self.title = title
        self.date = date
        self.isCompleted = isCompleted
        self.subtasks = subtasks
        self.templateSubDeadlineID = templateSubDeadlineID
        self.triggerID = triggerID
        self.repetitionPattern = repetitionPattern
        self.repetitionSourceID = repetitionSourceID
        self.repetitionOccurrenceNumber = repetitionOccurrenceNumber
    }
}

// MARK: - Project Model
struct Project: Codable, Equatable {
    let id: UUID
    var title: String
    var finalDeadlineDate: Date
    var subDeadlines: [SubDeadline]
    var triggers: [Trigger]
    var templateID: UUID?
    var templateName: String?
    var repetitionPattern: RepetitionPattern?
    var repetitionSourceID: UUID?
    var repetitionOccurrenceNumber: Int?

    var isFullyCompleted: Bool {
        subDeadlines.allSatisfy { $0.isCompleted }
    }

    init(id: UUID = UUID(), title: String, finalDeadlineDate: Date, subDeadlines: [SubDeadline] = [], triggers: [Trigger] = [], templateID: UUID? = nil, templateName: String? = nil, repetitionPattern: RepetitionPattern? = nil, repetitionSourceID: UUID? = nil, repetitionOccurrenceNumber: Int? = nil) {
        self.id = id
        self.title = title
        self.finalDeadlineDate = finalDeadlineDate
        self.subDeadlines = subDeadlines
        self.triggers = triggers
        self.templateID = templateID
        self.templateName = templateName
        self.repetitionPattern = repetitionPattern
        self.repetitionSourceID = repetitionSourceID
        self.repetitionOccurrenceNumber = repetitionOccurrenceNumber
    }
}

// MARK: - Color Settings Model
struct ColorSettings: Codable, Equatable {
    var greenThreshold: Int = 21
    var orangeThreshold: Int = 7
    var redThreshold: Int = 0

    init() {}

    init(greenThreshold: Int, orangeThreshold: Int, redThreshold: Int = 0) {
        self.greenThreshold = greenThreshold
        self.orangeThreshold = orangeThreshold
        self.redThreshold = redThreshold
    }
}

// MARK: - Notification Format Settings Model
struct NotificationFormatSettings: Codable, Equatable {
    var titleFormat: String = "Upcoming Deadlines"
    var itemFormat: String = "{index}. {title} - {timeRemaining}"
    var showProjectName: Bool = true
    var showDate: Bool = false
    var dateFormat: String = "MMM d"
    var maxItems: Int = 3

    init() {}

    init(titleFormat: String, itemFormat: String, showProjectName: Bool = true, showDate: Bool = false, dateFormat: String = "MMM d", maxItems: Int = 3) {
        self.titleFormat = titleFormat
        self.itemFormat = itemFormat
        self.showProjectName = showProjectName
        self.showDate = showDate
        self.dateFormat = dateFormat
        self.maxItems = maxItems
    }
}

// MARK: - App Settings Container
struct AppSettings: Codable, Equatable {
    var colorSettings: ColorSettings = ColorSettings()
    var notificationFormatSettings: NotificationFormatSettings = NotificationFormatSettings()

    init() {}

    init(colorSettings: ColorSettings, notificationFormatSettings: NotificationFormatSettings) {
        self.colorSettings = colorSettings
        self.notificationFormatSettings = notificationFormatSettings
    }
}

// MARK: - Backup Data Container
struct BackupData: Codable {
    var projects: [Project]
    var templates: [Template]
    var triggers: [Trigger]
    var appSettings: AppSettings

    init(projects: [Project] = [], templates: [Template] = [], triggers: [Trigger] = [], appSettings: AppSettings = AppSettings()) {
        self.projects = projects
        self.templates = templates
        self.triggers = triggers
        self.appSettings = appSettings
    }
}
