// Deadline Calendar/Models.swift

import Foundation

// MARK: - Time Offset Unit Enum
// Defines the units for time offsets (days, weeks, months).
enum TimeOffsetUnit: String, Codable, CaseIterable, Identifiable {
    case days, weeks, months
    var id: String { self.rawValue } // Conformance to Identifiable for use in Pickers etc.
}

// MARK: - Time Offset Struct
// Represents a time duration relative to a deadline date.
// For example, '7 days before' or '2 weeks before'.
struct TimeOffset: Codable, Equatable, Hashable {
    var value: Int // The number of units (e.g., 7)
    var unit: TimeOffsetUnit // The unit (e.g., .days)
    var before: Bool = true // True if the offset is *before* the reference date, false if *after*.

    // Calculates the actual date based on a reference date and the offset.
    // Throws an error if calendar calculations fail.
    func calculateDate(from referenceDate: Date) throws -> Date {
        let calendar = Calendar.current
        var dateComponent: Calendar.Component
        
        // Determine the calendar component based on the unit.
        switch unit {
        case .days:
            dateComponent = .day
        case .weeks:
            dateComponent = .weekOfYear // Use weekOfYear for week calculations
        case .months:
            dateComponent = .month
        }
        
        // Adjust value based on whether the offset is before or after the reference date.
        let adjustedValue = before ? -value : value
        
        // Attempt to calculate the new date.
        guard let calculatedDate = calendar.date(byAdding: dateComponent, value: adjustedValue, to: referenceDate) else {
            // Throw a custom error if date calculation fails.
            throw CalculationError.dateCalculationFailed("Could not calculate date for offset: \(value) \(unit.rawValue) \(before ? "before" : "after") \(referenceDate)")
        }
        
        // Return the successfully calculated date.
        return calculatedDate
    }

    // Custom error type for date calculation issues.
    enum CalculationError: Error, LocalizedError {
        case dateCalculationFailed(String)
        var errorDescription: String? {
            switch self {
            case .dateCalculationFailed(let description):
                return "Date Calculation Error: \(description)"
            }
        }
    }
    
    // Default initializer
    init(value: Int = 7, unit: TimeOffsetUnit = .days, before: Bool = true) {
        self.value = value
        self.unit = unit
        self.before = before
    }
}

// MARK: - Template Trigger Model
// Defines a trigger within a template. Doesn't have state like isActive.
struct TemplateTrigger: Identifiable, Codable, Equatable, Hashable {
    let id: UUID // Unique ID *within the template*
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

// MARK: - Trigger Model
// Modify Trigger Model - Add link back to template definition
struct Trigger: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var isActive: Bool = false // Triggers start as inactive
    let projectID: UUID       // Which project this trigger belongs to
    var activationDate: Date? // Optional: Record when it was activated
    var originatingTemplateTriggerID: UUID? // <-- ADDED: Link to TemplateTrigger.id

    // Update Initializer
    init(id: UUID = UUID(), name: String, projectID: UUID, isActive: Bool = false, activationDate: Date? = nil, originatingTemplateTriggerID: UUID? = nil) {
        self.id = id
        self.name = name
        self.projectID = projectID
        self.isActive = isActive
        self.activationDate = activationDate
        self.originatingTemplateTriggerID = originatingTemplateTriggerID // <-- Assign param
    }
}

// MARK: - Subtask Model (Kept from original)
// Represents a smaller task within a SubDeadline.
struct Subtask: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var title: String
    var isCompleted: Bool = false
    
    // Default initializer with optional completion status.
    init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
    }
}

// MARK: - Template SubDeadline Model
// Modify TemplateSubDeadline Model - Add link to TemplateTrigger
struct TemplateSubDeadline: Identifiable, Codable, Equatable, Hashable {
    let id: UUID // Unique ID for each template sub-deadline definition
    var title: String // Default title for this sub-deadline (e.g., "Script Delivery")
    var offset: TimeOffset // The time offset relative to the project's final deadline
    var templateTriggerID: UUID? // <-- ADDED

    // Update Initializer
    init(id: UUID = UUID(), title: String = "New Sub-Deadline", offset: TimeOffset = TimeOffset(), templateTriggerID: UUID? = nil) {
        self.id = id
        self.title = title
        self.offset = offset
        self.templateTriggerID = templateTriggerID // <-- Assign param
    }
}

// MARK: - Template Model
// Modify Template Model - Add array of trigger definitions
struct Template: Identifiable, Codable, Equatable {
    let id: UUID // Unique ID for the template
    var name: String // Name of the template (e.g., "Video Project")
    var subDeadlines: [TemplateSubDeadline] // List of sub-deadline definitions
    var templateTriggers: [TemplateTrigger] // <-- ADDED

    // Update Initializer
    init(id: UUID = UUID(), name: String = "New Template", subDeadlines: [TemplateSubDeadline] = [], templateTriggers: [TemplateTrigger] = []) {
        self.id = id
        self.name = name
        self.subDeadlines = subDeadlines
        self.templateTriggers = templateTriggers // <-- Assign param
    }
    
    // Static example for previewing or default data
    static var example = Template(
        name: "Monthly Video",
        subDeadlines: [
            // Example: Script not triggered
            TemplateSubDeadline(id: UUID(), title: "Script Due", offset: TimeOffset(value: 4, unit: .weeks, before: true)),
            // Example: Storyboard requires Animation Complete trigger
            TemplateSubDeadline(id: UUID(), title: "Storyboard Review", offset: TimeOffset(value: 3, unit: .weeks, before: true), templateTriggerID: exampleTrigger1ID), // Link using ID
            // Example: Animation Review requires Animation Complete trigger
            TemplateSubDeadline(id: UUID(), title: "Animation Review", offset: TimeOffset(value: 2, unit: .weeks, before: true), templateTriggerID: exampleTrigger1ID),
             // Example: Final Delivery requires Client Feedback trigger
            TemplateSubDeadline(id: UUID(), title: "Final Delivery", offset: TimeOffset(value: 1, unit: .weeks, before: true), templateTriggerID: exampleTrigger2ID)
        ],
        templateTriggers: [ // <-- Add example triggers
            TemplateTrigger(id: exampleTrigger1ID, name: "Animation Complete"), // Assign ID for linking
            TemplateTrigger(id: exampleTrigger2ID, name: "Client Feedback Received")
        ]
    )
}

// Define IDs used in the static example above for clarity
private let exampleTrigger1ID = UUID()
private let exampleTrigger2ID = UUID()

// MARK: - SubDeadline Model (Instance)
// Represents an actual sub-deadline instance within a specific project.
struct SubDeadline: Identifiable, Codable, Equatable, Hashable {
    let id: UUID // Unique ID for this specific sub-deadline instance
    var title: String // Title (can be customized from the template)
    var date: Date // The calculated, specific date for this sub-deadline
    var isCompleted: Bool = false // Completion status
    var subtasks: [Subtask] // Associated subtasks (if any)
    let templateSubDeadlineID: UUID? // Optional link back to the template definition it came from
    var triggerID: UUID? // <-- ADDED: Optional link to a Trigger

    // Initializer - Updated
    init(id: UUID = UUID(), title: String, date: Date, isCompleted: Bool = false, subtasks: [Subtask] = [], templateSubDeadlineID: UUID? = nil, triggerID: UUID? = nil) {
        self.id = id
        self.title = title
        self.date = date
        self.isCompleted = isCompleted
        self.subtasks = subtasks
        self.templateSubDeadlineID = templateSubDeadlineID // Store the link
        self.triggerID = triggerID // <-- ADDED Assignment
    }
}

// MARK: - Project Model
// Represents a specific project with a final deadline and multiple sub-deadlines.
struct Project: Identifiable, Codable, Equatable {
    let id: UUID // Unique ID for the project
    var title: String // Project title (e.g., "October Video")
    var finalDeadlineDate: Date // The final reference date for calculating sub-deadlines
    var subDeadlines: [SubDeadline] // List of actual sub-deadlines for this project
    var triggers: [Trigger] // <-- ADDED: List of triggers associated with this project
    var templateID: UUID? // Optional ID of the template used to create this project
    var templateName: String? // Store template name for display purposes

    // Computed property to check if all sub-deadlines are completed
    var isFullyCompleted: Bool {
        subDeadlines.allSatisfy { $0.isCompleted }
    }

    // Initializer
    init(id: UUID = UUID(), title: String, finalDeadlineDate: Date, subDeadlines: [SubDeadline] = [], triggers: [Trigger] = [], templateID: UUID? = nil, templateName: String? = nil) {
        self.id = id
        self.title = title
        self.finalDeadlineDate = finalDeadlineDate
        self.subDeadlines = subDeadlines
        self.triggers = triggers
        self.templateID = templateID
        self.templateName = templateName
    }
}

// MARK: - Deprecated Models (Consider removing later)
// Keeping original models temporarily if needed during transition,
// but they should eventually be removed or fully replaced.

/*
 // Original Subtask Model (Now potentially part of SubDeadline)
 struct Subtask_Original: Identifiable, Codable, Equatable {
     let id: UUID
     var title: String
     var isCompleted: Bool = false
     
     init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
         self.id = id
         self.title = title
         self.isCompleted = isCompleted
     }
     
     static func == (lhs: Subtask_Original, rhs: Subtask_Original) -> Bool {
         return lhs.id == rhs.id
     }
 }
 */

/*
 // Original Deadline Model (Replaced by Project/SubDeadline)
 struct Deadline: Identifiable, Codable, Equatable {
     let id: UUID
     var title: String
     var date: Date
     var subtasks: [Subtask_Original] // Reference the original if keeping separate
     var isCompleted: Bool = false
     
     init(id: UUID = UUID(), title: String, date: Date, subtasks: [Subtask_Original] = [], isCompleted: Bool = false) {
         self.id = id
         self.title = title
         self.date = date
         self.subtasks = subtasks
         self.isCompleted = isCompleted
     }
     
     static func == (lhs: Deadline, rhs: Deadline) -> Bool {
         return lhs.id == rhs.id
     }
 }
*/

// MARK: - Backup Data Container
// Struct to hold all data for export/import purposes.
struct BackupData: Codable {
    var projects: [Project]
    var templates: [Template]
    // Add other top-level data arrays if needed (e.g., if Triggers exist outside Projects)
    // var triggers: [Trigger] // Only if triggers are stored independently

    // Add an initializer if you need default values or specific setup
    init(projects: [Project] = [], templates: [Template] = []) {
        self.projects = projects
        self.templates = templates
    }
}
