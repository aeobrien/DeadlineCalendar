// Deadline Calendar/Deadline Calendar/ContentView.swift

import SwiftUI
import Combine
import UserNotifications
// Removed unused imports like SwiftSoup, UIKit if not needed by new views yet
import WidgetKit // Keep for ViewModel's reloadWidgets()

// MARK: - ViewModel (Updated Version)
// Manages Projects and Templates, handles data persistence and logic.
class DeadlineViewModel: ObservableObject {
    // --- NEW PROPERTIES ---
    // Published arrays for projects and templates. Changes trigger UI updates.
    @Published var projects: [Project] = []
    @Published var templates: [Template] = []
    @Published var triggers: [Trigger] = []
    @Published var isLoading = true // <-- Add loading state flag
    @Published var appSettings: AppSettings = AppSettings() // <-- Add app settings

    // --- ADDED for Standalone Deadlines ---
    // Define a static ID for the standalone project to ensure it's always the same.
    static let standaloneProjectID: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    // --- UPDATED STORAGE KEYS ---
    // Unique keys for storing projects and templates in UserDefaults.
    private let projectsKey = "projects_v2_key" // Use a new key to avoid conflicts with old data structure
    private let templatesKey = "templates_key"
    private let triggersKey = "triggers_v1_key"
    private let appSettingsKey = "app_settings_key"

    // UserDefaults instance, potentially using a shared app group for widgets.
    private let userDefaults: UserDefaults

    // Shared iCloud data store for cross-platform sync.
    private let sharedStore: SharedDataStore
    private let effectsEnabled: Bool
    private let commitObserver: (() -> Void)?
    private let notificationObserver: (() -> Void)?
    private var currentLoadAvailable = false
    private var committedSnapshot: SharedData?
    private var batchDepth = 0
    @Published var saveError: String?
    @Published var newerDataAvailable = false
    @Published var editorGeneration = UUID()
    @Published private(set) var pendingSnapshot: SharedData?
    var pendingChangeJSON: String? {
        guard let pendingSnapshot else { return nil }
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(pendingSnapshot)).flatMap { String(data: $0, encoding: .utf8) }
    }


    // Observer token for external change notifications.
    private var externalChangeObserver: NSObjectProtocol?

    // Initializer: Sets up UserDefaults and shared store monitoring.
    init(store: SharedDataStore? = nil, defaults: UserDefaults? = nil,
         effectsEnabled: Bool = true, onCommit: (() -> Void)? = nil, onNotifications: (() -> Void)? = nil) {
        self.sharedStore = store ?? SharedDataStore()
        self.userDefaults = defaults ?? UserDefaults(suiteName: "group.com.yourapp.deadlines") ?? .standard
        self.effectsEnabled = effectsEnabled
        self.commitObserver = onCommit
        self.notificationObserver = onNotifications
        if effectsEnabled {
            sharedStore.startMonitoring()
            externalChangeObserver = NotificationCenter.default.addObserver(
                forName: SharedDataStore.didDetectExternalChange, object: nil, queue: .main
            ) { [weak self] _ in self?.handleExternalSharedDataChange() }
        }
    }

    deinit {
        if let observer = externalChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        sharedStore.stopMonitoring()
    }

    /// Keep the editing baseline until the user explicitly reloads. Advancing it
    /// behind an open sheet would authorize stale form contents against new data.
    func handleExternalSharedDataChange() {
        currentLoadAvailable = false
        newerDataAvailable = true
        saveError = "Deadlines changed elsewhere. Reload to see the current data before editing."
    }

    private func install(_ document: SharedData) {
        projects = document.projects; templates = document.templates
        triggers = document.triggers; appSettings = document.appSettings
    }

    private var currentSnapshot: SharedData {
        SharedData(projects: projects, templates: templates, triggers: triggers,
                   appSettings: appSettings, lastModified: Date(), lastModifiedBy: "app")
    }

    /// Reads legacy local caches without removing keys or replacing bad data.
    /// An existing undecodable cache stops migration instead of becoming empty.
    private func localSnapshot() throws -> SharedData {
        func read<T: Decodable & Equatable>(_ type: T.Type, keys: [String], fallback: T, decode: ((Data) throws -> T)? = nil) throws -> T {
            let sources = effectsEnabled ? [userDefaults, UserDefaults.standard] : [userDefaults]
            var decoded: T?
            for source in sources {
                for key in keys {
                    guard let existing = source.object(forKey: key) else { continue }
                    guard let bytes = existing as? Data else { throw SnapshotError.unavailable }
                    let value: T
                    if let decode { value = try decode(bytes) }
                    else { value = try JSONDecoder().decode(type, from: bytes) }
                    if let previous = decoded, previous != value { throw SnapshotError.conflict }
                    decoded = value
                }
            }
            return decoded ?? fallback
        }
        struct LegacyCompatibleTemplate: Decodable {
            let value: Template
            enum Keys: String, CodingKey { case id, name, subDeadlines, templateTriggers }
            init(from decoder: Decoder) throws {
                let fields = try decoder.container(keyedBy: Keys.self)
                if fields.contains(.templateTriggers) {
                    // Present but malformed is corruption, not an old format.
                    value = try Template(from: decoder)
                } else {
                    value = Template(id: try fields.decode(UUID.self, forKey: .id),
                        name: try fields.decode(String.self, forKey: .name),
                        subDeadlines: try fields.decode([TemplateSubDeadline].self, forKey: .subDeadlines),
                        templateTriggers: [])
                }
            }
        }
        return try SharedData(
            projects: read([Project].self, keys: [projectsKey, "projects_key", "projects", "SavedProjects"], fallback: []),
            templates: read([Template].self, keys: [templatesKey, "templates"], fallback: [], decode: {
                try JSONDecoder().decode([LegacyCompatibleTemplate].self, from: $0).map(\.value)
            }),
            triggers: read([Trigger].self, keys: [triggersKey, "triggers_key"], fallback: []),
            appSettings: read(AppSettings.self, keys: [appSettingsKey], fallback: AppSettings()),
            lastModified: Date(), lastModifiedBy: "app")
    }

    /// Preserve the existing trigger-date migration, but stage it before a single
    /// coordinated commit instead of publishing caches or deleting legacy keys.
    private func migratingTriggerDates(_ source: SharedData) -> SharedData {
        var document = source
        for i in document.triggers.indices where document.triggers[i].date == nil {
            guard let project = document.projects.first(where: { $0.id == document.triggers[i].projectID }) else { continue }
            var calculated: Date?
            if let templateID = project.templateID,
               let template = document.templates.first(where: { $0.id == templateID }),
               let originatingID = document.triggers[i].originatingTemplateTriggerID,
               let trigger = template.templateTriggers.first(where: { $0.id == originatingID }) {
                calculated = try? trigger.offset.calculateDate(from: project.finalDeadlineDate)
            }
            document.triggers[i].date = calculated ?? Calendar.current.date(byAdding: .day, value: -7, to: project.finalDeadlineDate) ?? Date()
        }
        return document
    }

    @discardableResult
    func reloadCurrentData() -> Bool {
        currentLoadAvailable = false
        do {
            if let loaded = try sharedStore.loadSnapshot() {
                var document = migratingTriggerDates(loaded)
                if document != loaded {
                    document = try sharedStore.saveSnapshot(projects: document.projects, templates: document.templates,
                        triggers: document.triggers, appSettings: document.appSettings)
                }
                install(document); committedSnapshot = document
                currentLoadAvailable = true
                try cacheCommitted(document)
            } else {
                let local = migratingTriggerDates(try localSnapshot())
                let document = try sharedStore.saveSnapshot(projects: local.projects, templates: local.templates,
                    triggers: local.triggers, appSettings: local.appSettings)
                install(document); committedSnapshot = document
                currentLoadAvailable = true
                try cacheCommitted(document)
            }
            newerDataAvailable = false
            saveError = nil
            // Old sheets are dismissed; pendingSnapshot remains available for review,
            // but is never automatically written over the newly loaded document.
            editorGeneration = UUID()
            return true
        } catch {
            currentLoadAvailable = false
            saveError = "Could not load deadlines. Existing data was preserved. " + error.localizedDescription
            return false
        }
    }

    @MainActor
    func loadInitialData() async {
        isLoading = true
        guard reloadCurrentData() else { isLoading = false; return }
        isLoading = false
        if effectsEnabled {
            requestNotificationPermissions()
            scheduleDailyNotifications()
            await checkForAutomaticBackup()
        }
    }

    // Shared persistence succeeds before caches, notifications or success signals.
    private func cacheCommitted(_ document: SharedData) throws {
        let encoder = JSONEncoder()
        let encoded = try [encoder.encode(document.projects), encoder.encode(document.templates),
                           encoder.encode(document.triggers), encoder.encode(document.appSettings)]
        for (key, bytes) in zip([projectsKey, templatesKey, triggersKey, appSettingsKey], encoded) {
            userDefaults.set(bytes, forKey: key)
        }
        commitObserver?()
        if effectsEnabled { reloadWidgets() }
        updateNotifications()
    }

    @discardableResult
    func saveAll() -> Bool {
        if batchDepth > 0 { return true }
        let candidate = currentSnapshot
        do {
            let saved = try sharedStore.saveSnapshot(projects: candidate.projects, templates: candidate.templates,
                triggers: candidate.triggers, appSettings: candidate.appSettings)
            let changed = saved != committedSnapshot
            install(saved)
            committedSnapshot = saved
            currentLoadAvailable = true
            if changed { try cacheCommitted(saved) }
            pendingSnapshot = nil; saveError = nil
            return true
        } catch {
            currentLoadAvailable = false
            pendingSnapshot = candidate
            if let committedSnapshot { install(committedSnapshot) }
            saveError = "Could not save deadlines. Your attempted change is retained in this session. " + error.localizedDescription
            return false
        }
    }

    /// All nested changes (including recurrence and linked triggers) commit once.
    @discardableResult
    func performChanges(_ changes: () -> Void) -> Bool {
        guard committedSnapshot != nil else {
            saveError = "Load the current deadlines successfully before editing."
            return false
        }
        batchDepth += 1
        changes()
        batchDepth -= 1
        return batchDepth > 0 ? true : saveAll()
    }

    @discardableResult func saveProjects() -> Bool { saveAll() }
    @discardableResult func saveTemplates() -> Bool { saveAll() }
    @discardableResult func saveTriggers() -> Bool { saveAll() }
    @discardableResult func saveAppSettings() -> Bool { saveAll() }

    func reloadWidgets() {
        guard effectsEnabled else { return }
        WidgetCenter.shared.reloadAllTimelines()
    }

    // --- PROJECT CRUD OPERATIONS ---

    // Adds a new project to the list and saves.
    @discardableResult
    func addProject(_ project: Project) -> Bool {
        performChanges {

        // Optional: Add validation to prevent duplicate projects if needed.
        // e.g., if !projects.contains(where: { $0.title == project.title }) { ... }
        projects.append(project)
        saveProjects() // Save changes immediately.

        }
    }

    // Updates an existing project in the list and saves.
    @discardableResult
    func updateProject(_ project: Project) -> Bool {
        performChanges {

        // Find the index of the project with the matching ID.
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project // Replace the old project with the updated one.
            saveProjects() // Save changes.
        } else {
            // Log if the project to update wasn't found.
        }

        }
    }

    // Deletes a project from the list and saves.
    @discardableResult
    func deleteProject(_ project: Project) -> Bool {
        performChanges {

        // Remove the project with the matching ID.
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            let deletedTitle = projects[index].title
            projects.remove(at: index)
            saveProjects() // Save changes.
        } else {
        }

        }
    }


    // --- SUB-DEADLINE OPERATIONS ---

    // Adds a new standalone sub-deadline by finding or creating a special project to house it.
    @discardableResult
    func addStandaloneDeadline(_ deadline: SubDeadline) -> Bool {
        performChanges {

        let standaloneProjectName = "Standalone Deadlines"
        
        // Check if the standalone project already exists.
        if let projectIndex = projects.firstIndex(where: { $0.id == DeadlineViewModel.standaloneProjectID }) {
            // Project exists, add the deadline to it.
            projects[projectIndex].subDeadlines.append(deadline)
            projects[projectIndex].subDeadlines.sort { $0.date < $1.date }
            saveProjects() // Save the updated projects list.
        } else {
            // Project doesn't exist, create a new one with this deadline.
            let newProject = Project(
                id: DeadlineViewModel.standaloneProjectID,
                title: standaloneProjectName,
                finalDeadlineDate: Date.distantFuture, // A sensible default for a container project.
                subDeadlines: [deadline] // Start with the new deadline.
            )
            addProject(newProject) // addProject handles appending and saving.
        }

        }
    }
    
    // MARK: - Repetition Management
    
    /// Generates future occurrences of a deadline based on its repetition pattern
    @discardableResult
    func generateRepetitionOccurrences(for deadline: SubDeadline) -> Bool {
        performChanges {

        guard let pattern = deadline.repetitionPattern, pattern.type != .none else {
            return
        }
        
        
        var currentDate = deadline.date
        var occurrenceCount = 1 // The original is occurrence #1
        var generatedDeadlines: [SubDeadline] = []
        
        // Determine the limit for generation
        let maxDate = pattern.endDate ?? Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Date()
        let maxOccurrences = pattern.maxOccurrences ?? 100 // Safety limit
        
        while occurrenceCount < maxOccurrences {
            // Calculate the next occurrence date
            guard let nextDate = pattern.nextOccurrence(after: currentDate) else {
                break
            }
            
            // Check if we've exceeded the end date
            if let endDate = pattern.endDate, nextDate > endDate {
                break
            }
            
            // Check if we've gone too far into the future (safety check)
            if nextDate > maxDate {
                break
            }
            
            occurrenceCount += 1
            
            // Create the new occurrence
            let newDeadline = SubDeadline(
                title: deadline.title,
                date: nextDate,
                isCompleted: false,
                subtasks: deadline.subtasks.map { Subtask(title: $0.title, isCompleted: false) }, // Copy subtasks as uncompleted
                templateSubDeadlineID: deadline.templateSubDeadlineID,
                triggerID: deadline.triggerID,
                repetitionPattern: pattern, // Keep the same pattern for future regeneration
                repetitionSourceID: deadline.id, // Link back to the original
                repetitionOccurrenceNumber: occurrenceCount
            )
            
            generatedDeadlines.append(newDeadline)
            currentDate = nextDate
        }
        
        
        // Add all generated deadlines to the standalone project
        if !generatedDeadlines.isEmpty {
            if let projectIndex = projects.firstIndex(where: { $0.id == DeadlineViewModel.standaloneProjectID }) {
                projects[projectIndex].subDeadlines.append(contentsOf: generatedDeadlines)
                projects[projectIndex].subDeadlines.sort { $0.date < $1.date }
                saveProjects()
            }
        }

        }
    }
    
    /// Removes all future occurrences of a repeating deadline
    @discardableResult
    func removeRepetitionOccurrences(for deadline: SubDeadline) -> Bool {
        performChanges {

        guard let projectIndex = projects.firstIndex(where: { $0.id == DeadlineViewModel.standaloneProjectID }) else {
            return
        }
        
        // Remove all deadlines that have this deadline as their repetition source
        projects[projectIndex].subDeadlines.removeAll { $0.repetitionSourceID == deadline.id }
        
        saveProjects()

        }
    }
    
    /// Updates repetition occurrences when the pattern changes
    @discardableResult
    func updateRepetitionOccurrences(for deadline: SubDeadline) -> Bool {
        performChanges {

        // First remove old occurrences
        removeRepetitionOccurrences(for: deadline)
        
        // Then generate new ones if pattern is still active
        if let pattern = deadline.repetitionPattern, pattern.type != .none {
            generateRepetitionOccurrences(for: deadline)
        }

        }
    }
    
    // MARK: - Project Repetition Management
    
    /// Generates future occurrences of a project based on its repetition pattern
    @discardableResult
    func generateProjectRepetitionOccurrences(for project: Project) -> Bool {
        performChanges {

        guard let pattern = project.repetitionPattern, pattern.type != .none else {
            return
        }
        
        
        var currentDate = project.finalDeadlineDate
        var occurrenceCount = 1 // The original is occurrence #1
        var generatedProjects: [Project] = []
        
        // Determine the limit for generation
        let maxDate = pattern.endDate ?? Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Date()
        let maxOccurrences = pattern.maxOccurrences ?? 100 // Safety limit
        
        while occurrenceCount < maxOccurrences {
            // Calculate the next occurrence date
            guard let nextDate = pattern.nextOccurrence(after: currentDate) else {
                break
            }
            
            // Check if we've exceeded the end date
            if let endDate = pattern.endDate, nextDate > endDate {
                break
            }
            
            // Check if we've gone too far into the future (safety check)
            if nextDate > maxDate {
                break
            }
            
            occurrenceCount += 1
            
            // Calculate the time difference for sub-deadlines
            let daysDifference = Calendar.current.dateComponents([.day], from: project.finalDeadlineDate, to: nextDate).day ?? 0
            
            // Create new sub-deadlines with adjusted dates
            let newSubDeadlines = project.subDeadlines.map { original -> SubDeadline in
                let newDate = Calendar.current.date(byAdding: .day, value: daysDifference, to: original.date) ?? original.date
                return SubDeadline(
                    title: original.title,
                    date: newDate,
                    isCompleted: false,
                    subtasks: original.subtasks.map { Subtask(title: $0.title, isCompleted: false) },
                    templateSubDeadlineID: original.templateSubDeadlineID,
                    triggerID: nil, // Don't copy trigger IDs as they're project-specific
                    repetitionPattern: original.repetitionPattern // Keep sub-deadline repetition if any
                )
            }
            
            // Create new triggers with adjusted dates if the project has triggers
            let originalTriggers = triggers(for: project.id)
            var newTriggers: [Trigger] = []
            if !originalTriggers.isEmpty {
                for trigger in originalTriggers {
                    if let triggerDate = trigger.date {
                        let newTriggerDate = Calendar.current.date(byAdding: .day, value: daysDifference, to: triggerDate) ?? triggerDate
                        let newTrigger = Trigger(
                            name: trigger.name,
                            projectID: UUID(), // Will be updated when project is created
                            date: newTriggerDate,
                            isActive: false,
                            originatingTemplateTriggerID: trigger.originatingTemplateTriggerID
                        )
                        newTriggers.append(newTrigger)
                    }
                }
            }
            
            // Create the new project occurrence
            let newProject = Project(
                title: project.title,
                finalDeadlineDate: nextDate,
                subDeadlines: newSubDeadlines.sorted { $0.date < $1.date },
                triggers: newTriggers,
                templateID: project.templateID,
                templateName: project.templateName,
                repetitionPattern: pattern, // Keep the same pattern for future regeneration
                repetitionSourceID: project.id, // Link back to the original
                repetitionOccurrenceNumber: occurrenceCount
            )
            
            generatedProjects.append(newProject)
            currentDate = nextDate
        }
        
        
        // Add all generated projects
        for generatedProject in generatedProjects {
            // Update trigger project IDs to match the new project
            var projectWithCorrectTriggers = generatedProject
            projectWithCorrectTriggers.triggers = generatedProject.triggers.map { trigger in
                var updatedTrigger = trigger
                updatedTrigger = Trigger(
                    id: trigger.id,
                    name: trigger.name,
                    projectID: generatedProject.id, // Use the actual project ID
                    date: trigger.date,
                    isActive: trigger.isActive,
                    originatingTemplateTriggerID: trigger.originatingTemplateTriggerID
                )
                return updatedTrigger
            }
            
            // Add the project
            addProject(projectWithCorrectTriggers)
            
            // Add the triggers separately
            for trigger in projectWithCorrectTriggers.triggers {
                addTrigger(trigger)
            }
        }

        }
    }
    
    /// Removes all future occurrences of a repeating project
    @discardableResult
    func removeProjectRepetitionOccurrences(for project: Project) -> Bool {
        performChanges {

        // Remove all projects that have this project as their repetition source
        projects.removeAll { $0.repetitionSourceID == project.id }
        
        // Also remove associated triggers
        triggers.removeAll { trigger in
            projects.contains { $0.repetitionSourceID == project.id && $0.id == trigger.projectID }
        }
        
        saveProjects()
        saveTriggers()

        }
    }
    
    /// Updates project repetition occurrences when the pattern changes
    @discardableResult
    func updateProjectRepetitionOccurrences(for project: Project) -> Bool {
        performChanges {

        // First remove old occurrences
        removeProjectRepetitionOccurrences(for: project)
        
        // Then generate new ones if pattern is still active
        if let pattern = project.repetitionPattern, pattern.type != .none {
            generateProjectRepetitionOccurrences(for: project)
        }

        }
    }

    // Updates a specific sub-deadline within a project.
    @discardableResult
    func updateSubDeadline(_ subDeadline: SubDeadline, in project: Project) -> Bool {
        performChanges {

        // Find the project index.
        guard let projectIndex = projects.firstIndex(where: { $0.id == project.id }) else {
            return
        }
        // Find the sub-deadline index within that project.
        guard let subDeadlineIndex = projects[projectIndex].subDeadlines.firstIndex(where: { $0.id == subDeadline.id }) else {
            return
        }

        // Update the specific sub-deadline.
        projects[projectIndex].subDeadlines[subDeadlineIndex] = subDeadline
        // Ensure subdeadlines within the project remain sorted after update
        projects[projectIndex].subDeadlines.sort { $0.date < $1.date }
        saveProjects() // Save changes.

        }
    }

    // Toggles the completion status of a sub-deadline.
    @discardableResult
    func toggleSubDeadlineCompletion(_ subDeadline: SubDeadline, in project: Project) -> Bool {
        performChanges {

        var mutableSubDeadline = subDeadline
        mutableSubDeadline.isCompleted.toggle() // Flip the completion status
        // Call the update function to modify the project and save.
        updateSubDeadline(mutableSubDeadline, in: project)

        }
    }

    // Deletes a specific sub-deadline from a specific project.
    @discardableResult
    func deleteSubDeadline(subDeadlineID: UUID, fromProjectID: UUID) -> Bool {
        performChanges {

        // Find the index of the project.
        guard let projectIndex = projects.firstIndex(where: { $0.id == fromProjectID }) else {
            return
        }
        
        // Find the index of the sub-deadline within that project.
        guard let subDeadlineIndex = projects[projectIndex].subDeadlines.firstIndex(where: { $0.id == subDeadlineID }) else {
            return
        }
        
        // Remove the sub-deadline from the project's array.
        let deletedTitle = projects[projectIndex].subDeadlines[subDeadlineIndex].title
        projects[projectIndex].subDeadlines.remove(at: subDeadlineIndex)
        
        // Save the updated projects array.
        saveProjects()

        }
    }


    // --- TEMPLATE CRUD OPERATIONS ---
    
    // Creates a template from an existing project
    private func createTemplateFromProjectInternal(_ project: Project) -> Template {
        print("ViewModel: Creating template from project '\(project.title)'")
        print("  Project has \(project.subDeadlines.count) sub-deadlines")
        print("  Project has \(triggers(for: project.id).count) triggers")
        
        // Calculate template sub-deadlines from project sub-deadlines
        var templateSubDeadlines: [TemplateSubDeadline] = []
        for subDeadline in project.subDeadlines {
            // Calculate the offset from the final deadline
            let daysDifference = Calendar.current.dateComponents([.day], from: subDeadline.date, to: project.finalDeadlineDate).day ?? 0
            
            // Create offset based on the difference
            let offset = TimeOffset(
                value: abs(daysDifference),
                unit: .days,
                before: daysDifference > 0 // If positive, subdeadline is before final deadline
            )
            
            // Create template sub-deadline
            let templateSubDeadline = TemplateSubDeadline(
                title: subDeadline.title,
                offset: offset,
                templateTriggerID: nil // We'll map these after creating triggers
            )
            templateSubDeadlines.append(templateSubDeadline)
        }
        
        // Get triggers for this project and create template triggers
        let projectTriggers = triggers(for: project.id)
        var templateTriggers: [TemplateTrigger] = []
        var triggerIDMap: [UUID: UUID] = [:] // Map from real trigger ID to template trigger ID
        
        for trigger in projectTriggers {
            // Calculate offset if trigger has a date
            let offset: TimeOffset
            if let triggerDate = trigger.date {
                let daysDifference = Calendar.current.dateComponents([.day], from: triggerDate, to: project.finalDeadlineDate).day ?? 0
                offset = TimeOffset(
                    value: abs(daysDifference),
                    unit: .days,
                    before: daysDifference > 0
                )
            } else {
                // Default offset if no date
                offset = TimeOffset(value: 7, unit: .days, before: true)
            }
            
            let templateTrigger = TemplateTrigger(
                name: trigger.name,
                offset: offset
            )
            templateTriggers.append(templateTrigger)
            
            // Map the IDs for linking sub-deadlines
            triggerIDMap[trigger.id] = templateTrigger.id
        }
        
        // Now update template sub-deadlines with trigger links
        for i in templateSubDeadlines.indices {
            if let originalSubDeadline = project.subDeadlines.first(where: { $0.title == templateSubDeadlines[i].title }),
               let triggerID = originalSubDeadline.triggerID,
               let templateTriggerID = triggerIDMap[triggerID] {
                templateSubDeadlines[i].templateTriggerID = templateTriggerID
            }
        }
        
        // Create the template
        let templateName = project.templateName ?? "\(project.title) Template"
        let newTemplate = Template(
            name: templateName,
            subDeadlines: templateSubDeadlines,
            templateTriggers: templateTriggers
        )
        
        print("ViewModel: Created template '\(newTemplate.name)' with \(templateSubDeadlines.count) sub-deadlines and \(templateTriggers.count) triggers")
        
        return newTemplate
    }
    
    // Wrapper function that creates a template from a project and adds it to the templates list
    func createTemplateFromProject(_ project: Project) -> String? {
        let template = createTemplateFromProjectInternal(project)
        guard addTemplate(template) else { return nil }
        return template.name
    }

    // Adds a new template and saves.
    @discardableResult
    func addTemplate(_ template: Template) -> Bool {
        performChanges {

        // Optional: Add validation, e.g., prevent duplicate template names.
         if !templates.contains(where: { $0.name == template.name }) {
            templates.append(template)
            saveTemplates() // Save changes.
         } else {
         }

        }
    }

    // Updates an existing template and saves.
    // Consider implications for existing projects using this template.
    // Currently, this only updates the template definition itself.
    @discardableResult
    func updateTemplate(_ template: Template) -> Bool {
        performChanges {

        // Find the index of the template with the matching ID.
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template // Replace the old template.
            saveTemplates() // Save changes.
            // Add logic here if template updates should optionally update existing projects.
        } else {
        }

        }
    }

    // Deletes a template.
    @discardableResult
    func deleteTemplate(_ template: Template) -> Bool {
        performChanges {

        // Find the index and remove the template.
         if let index = templates.firstIndex(where: { $0.id == template.id }) {
             let deletedName = templates[index].name
             templates.remove(at: index)
             saveTemplates() // Save changes.
             // Consider what happens to projects linked to this template ID.
             // Maybe clear the templateID field in associated projects?
             // For now, just deleting the template definition.
         } else {
         }

        }
    }



    // --- PROJECT CREATION FROM TEMPLATE (MODIFIED) ---
    func createProjectFromTemplate(template: Template, title: String, finalDeadline: Date) -> Project {
        print("ViewModel: Creating project '\(title)' from template '\(template.name)'")
        print("  Template has \(template.subDeadlines.count) sub-deadlines")
        print("  Template has \(template.templateTriggers.count) triggers")
        
        // Generate the final Project ID *before* creating triggers
        let newProjectID = UUID()

        // --- Create Triggers for this Project Instance ---     
        var createdTriggers: [Trigger] = []
        var templateTriggerToRealTriggerMap: [UUID: UUID] = [:] // Map TemplateTrigger.id -> Trigger.id

        for templateTrigger in template.templateTriggers {
            do {
                // Calculate the date for this trigger based on the project's final deadline
                let triggerDate = try templateTrigger.offset.calculateDate(from: finalDeadline)
                
                // Create a new Trigger instance for the project using the final project ID
                let newRealTrigger = Trigger(
                    name: templateTrigger.name, // Use name from template
                    projectID: newProjectID, // <-- Use the final project ID directly
                    date: triggerDate, // Set the calculated date
                    originatingTemplateTriggerID: templateTrigger.id // Link back to template definition
                )
                createdTriggers.append(newRealTrigger)
                templateTriggerToRealTriggerMap[templateTrigger.id] = newRealTrigger.id
                print("ViewModel (create): Prepared trigger '\(newRealTrigger.name)' for project (ID: \(newProjectID)) with date \(triggerDate) from template trigger ID \(templateTrigger.id)")
            } catch {
                print("ViewModel Error (create): Failed to calculate date for trigger '\(templateTrigger.name)'. Error: \(error.localizedDescription)")
            }
        }

        // --- Create SubDeadlines, linking to newly created Triggers ---
        var calculatedSubDeadlines: [SubDeadline] = []
        for templateSub in template.subDeadlines {
            do {
                // Find the ID of the real trigger corresponding to the template trigger ID
                let realTriggerID = templateSub.templateTriggerID.flatMap { templateTriggerToRealTriggerMap[$0] }

                let newSubDeadline = SubDeadline(
                    title: templateSub.title, // Use the template title initially
                    date: try templateSub.offset.calculateDate(from: finalDeadline),
                    templateSubDeadlineID: templateSub.id,
                    triggerID: realTriggerID // Use the mapped real Trigger ID
                )
                calculatedSubDeadlines.append(newSubDeadline)
                print("ViewModel (create): Calculated sub-deadline '\(newSubDeadline.title)', linked trigger: \(realTriggerID != nil)")
            } catch {
                print("ViewModel Error (create): Failed to calculate date for sub-deadline '\(templateSub.title)'. Error: \(error.localizedDescription)")
            }
        }

        // --- Create the Project ---
        // Use the same Project ID generated earlier
        let newProject = Project(
            id: newProjectID, // Use the generated ID
            title: title,
            finalDeadlineDate: finalDeadline,
            subDeadlines: calculatedSubDeadlines.sorted { $0.date < $1.date }, // Sort sub-deadlines chronologically
            triggers: createdTriggers, // <-- Directly use the created triggers (they now have the correct projectID)
            templateID: template.id, // Store the ID of the template used
            templateName: template.name // Store the name for display
        )

        // --- Add Created Triggers to ViewModel --- 
        // The triggers in `createdTriggers` already have the correct projectID.
        // `self.addTrigger` handles persistence (saving).
        for triggerToAdd in createdTriggers {
            // No need to create an `updatedTrigger` anymore.
            self.addTrigger(triggerToAdd) // Add the correctly initialized trigger to the main list and save
        }

        print("ViewModel: Prepared project '\(newProject.title)' from template '\(template.name)' with \(newProject.subDeadlines.count) sub-deadlines and \(newProject.triggers.count) triggers.")
        return newProject
        // Note: The calling view (e.g., AddProjectView) will typically call `addProject(newProject)` after this function returns.
    }

    // --- PROJECT TEMPLATE UPDATE LOGIC (MODIFIED) ---

    // Updates projects based on the *differences* between an old and new template version.
    // Handles changes in sub-deadline defs (title, offset, trigger link) and trigger defs (add, delete, rename).
    @discardableResult
    func updateProjects(from oldTemplate: Template, to updatedTemplate: Template) -> Bool {
        performChanges {


        // --- Calculate Template SubDeadline Differences ---
        let oldSubDefs = Dictionary(uniqueKeysWithValues: oldTemplate.subDeadlines.map { ($0.id, $0) })
        let newSubDefs = Dictionary(uniqueKeysWithValues: updatedTemplate.subDeadlines.map { ($0.id, $0) })
        let oldSubDefIDs = Set(oldSubDefs.keys)
        let newSubDefIDs = Set(newSubDefs.keys)
        let addedSubDefIDs = newSubDefIDs.subtracting(oldSubDefIDs)
        // let deletedSubDefIDs = oldSubDefIDs.subtracting(newSubDefIDs) // Not needed for project update?
        let commonSubDefIDs = oldSubDefIDs.intersection(newSubDefIDs)

        var subDefTitleChanges: [UUID: String] = [:]
        var subDefOffsetChanges: [UUID: TimeOffset] = [:]
        var subDefTriggerLinkChanges: [UUID: UUID?] = [:] // Map templateSubDeadlineID -> new templateTriggerID?

        for id in commonSubDefIDs {
            let oldSubDef = oldSubDefs[id]!
            let newSubDef = newSubDefs[id]!
            if oldSubDef.title != newSubDef.title { subDefTitleChanges[id] = newSubDef.title }
            if oldSubDef.offset != newSubDef.offset { subDefOffsetChanges[id] = newSubDef.offset }
            if oldSubDef.templateTriggerID != newSubDef.templateTriggerID { subDefTriggerLinkChanges[id] = newSubDef.templateTriggerID }
        }
        let addedSubDeadlineDefs = addedSubDefIDs.compactMap { newSubDefs[$0] }

        // --- Calculate Template Trigger Differences ---
        let oldTrigDefs = Dictionary(uniqueKeysWithValues: oldTemplate.templateTriggers.map { ($0.id, $0) })
        let newTrigDefs = Dictionary(uniqueKeysWithValues: updatedTemplate.templateTriggers.map { ($0.id, $0) })
        let oldTrigDefIDs = Set(oldTrigDefs.keys)
        let newTrigDefIDs = Set(newTrigDefs.keys)

        let addedTrigDefIDs = newTrigDefIDs.subtracting(oldTrigDefIDs)
        let deletedTrigDefIDs = oldTrigDefIDs.subtracting(newTrigDefIDs)
        let commonTrigDefIDs = oldTrigDefIDs.intersection(newTrigDefIDs)

        var trigDefNameChanges: [UUID: String] = [:] // Map templateTriggerID -> new name
        var trigDefOffsetChanges: [UUID: TimeOffset] = [:] // Map templateTriggerID -> new offset
        for id in commonTrigDefIDs {
            if oldTrigDefs[id]!.name != newTrigDefs[id]!.name {
                trigDefNameChanges[id] = newTrigDefs[id]!.name
            }
            if oldTrigDefs[id]!.offset != newTrigDefs[id]!.offset {
                trigDefOffsetChanges[id] = newTrigDefs[id]!.offset
            }
        }
        let addedTriggerDefs = addedTrigDefIDs.compactMap { newTrigDefs[$0] }

        // --- Apply Changes to Projects ---
        var updatedProjectCount = 0

        // Iterate through all projects with mutable access
        for i in projects.indices {
            guard projects[i].templateID == updatedTemplate.id else { continue } // Match project to template

            var projectDidChange = false
            let project = projects[i] // Immutable copy for reading ID/Date

            // Maps templateTriggerID -> actual Trigger.id *for this specific project*
            var currentProjectTriggerMap: [UUID: UUID] = [:]
            // Create map from *existing* triggers in this project
            self.triggers(for: project.id).forEach { trigger in
                if let originID = trigger.originatingTemplateTriggerID {
                     currentProjectTriggerMap[originID] = trigger.id
                }
            }

            // Handle Added Template Triggers: Create real Triggers for this project
            if !addedTriggerDefs.isEmpty {
                for trigDefToAdd in addedTriggerDefs {
                    // Avoid duplicates if sync runs multiple times (shouldn't happen ideally)
                     if !self.triggers(for: project.id).contains(where: {$0.originatingTemplateTriggerID == trigDefToAdd.id}) {
                        do {
                            let triggerDate = try trigDefToAdd.offset.calculateDate(from: project.finalDeadlineDate)
                            let newRealTrigger = Trigger(
                                name: trigDefToAdd.name,
                                projectID: project.id,
                                date: triggerDate,
                                originatingTemplateTriggerID: trigDefToAdd.id
                            )
                            self.addTrigger(newRealTrigger) // Add to main list & save
                            currentProjectTriggerMap[trigDefToAdd.id] = newRealTrigger.id // Update map
                            projectDidChange = true // Indicate change might have happened indirectly
                        } catch {
                        }
                     }
                }
            }

            // Handle Deleted Template Triggers: Delete real Triggers in this project
            if !deletedTrigDefIDs.isEmpty {
                 for deletedTrigDefID in deletedTrigDefIDs {
                     // Find the real trigger in this project that originated from the deleted template trigger
                     if let realTriggerToDelete = self.triggers(for: project.id).first(where: { $0.originatingTemplateTriggerID == deletedTrigDefID }) {
                         self.deleteTrigger(triggerID: realTriggerToDelete.id) // Deletes & saves triggers/projects
                         projectDidChange = true // Indicate change
                         // Remove from map if needed, though deletion handles this
                         currentProjectTriggerMap.removeValue(forKey: deletedTrigDefID)
                     }
                 }
            }

            // Handle Renamed Template Triggers: Update real Triggers in this project
            if !trigDefNameChanges.isEmpty || !trigDefOffsetChanges.isEmpty {
                 for trigDefID in commonTrigDefIDs {
                     if let realTriggerToUpdate = self.triggers(for: project.id).first(where: { $0.originatingTemplateTriggerID == trigDefID }) {
                         var needsUpdate = false
                         var mutableTrigger = realTriggerToUpdate // Create mutable copy
                         
                         // Check for name change
                         if let newName = trigDefNameChanges[trigDefID], realTriggerToUpdate.name != newName {
                             mutableTrigger.name = newName
                             needsUpdate = true
                         }
                         
                         // Check for offset change
                         if let newOffset = trigDefOffsetChanges[trigDefID] {
                             do {
                                 let newDate = try newOffset.calculateDate(from: project.finalDeadlineDate)
                                 if mutableTrigger.date != newDate {
                                     mutableTrigger.date = newDate
                                     needsUpdate = true
                                 }
                             } catch {
                             }
                         }
                         
                         if needsUpdate {
                             self.updateTrigger(mutableTrigger) // Updates & saves triggers
                             projectDidChange = true // Indicate change
                         }
                     }
                 }
            }

            // --- Handle SubDeadline Definition Changes ---
            var subDeadlinesToAdd: [SubDeadline] = []

            // Apply changes to existing sub-deadlines
            for j in projects[i].subDeadlines.indices {
                guard let templateSubDeadlineID = projects[i].subDeadlines[j].templateSubDeadlineID else {
                    continue // Skip sub-deadlines not linked to the template
                }

                var subDeadlineNeedsSave = false

                // Apply title change if needed
                if let newTitle = subDefTitleChanges[templateSubDeadlineID], projects[i].subDeadlines[j].title != newTitle {
                    if projects[i].subDeadlines[j].title != newTitle {
                        projects[i].subDeadlines[j].title = newTitle
                        subDeadlineNeedsSave = true
                    }
                }

                // Apply offset change (recalculate date) if needed
                if let newOffset = subDefOffsetChanges[templateSubDeadlineID] {
                    do {
                        let newDate = try newOffset.calculateDate(from: projects[i].finalDeadlineDate)
                        if projects[i].subDeadlines[j].date != newDate {
                            projects[i].subDeadlines[j].date = newDate
                            subDeadlineNeedsSave = true
                        }
                    } catch {
                    }
                }

                // Update Trigger Link?
                if let newTemplateTriggerID = subDefTriggerLinkChanges[templateSubDeadlineID] { // Note: newTemplateTriggerID can be nil
                   let newRealTriggerID = newTemplateTriggerID.flatMap { currentProjectTriggerMap[$0] }
                    if projects[i].subDeadlines[j].triggerID != newRealTriggerID {
                        projects[i].subDeadlines[j].triggerID = newRealTriggerID
                        subDeadlineNeedsSave = true
                    }
                }

                if subDeadlineNeedsSave {
                    projectDidChange = true
                }
            }

            // Add newly defined SubDeadlines
            if !addedSubDeadlineDefs.isEmpty {
                for subDefToAdd in addedSubDeadlineDefs {
                    // Check if already added (e.g., if sync runs twice)
                    if !projects[i].subDeadlines.contains(where: {$0.templateSubDeadlineID == subDefToAdd.id}) {
                        do {
                            let newDate = try subDefToAdd.offset.calculateDate(from: project.finalDeadlineDate)
                            let realTriggerID = subDefToAdd.templateTriggerID.flatMap { currentProjectTriggerMap[$0] }
                            let newSub = SubDeadline(title: subDefToAdd.title,
                                                   date: newDate,
                                                   templateSubDeadlineID: subDefToAdd.id,
                                                   triggerID: realTriggerID)
                            subDeadlinesToAdd.append(newSub)
                            projectDidChange = true
                        } catch { print("ViewModel Error (sync): Could not calc date for new sub-deadline '\(subDefToAdd.title)': \(error)") }
                    }
                }
                // Append all new sub-deadlines at once
                if !subDeadlinesToAdd.isEmpty {
                    projects[i].subDeadlines.append(contentsOf: subDeadlinesToAdd)
                }
            }

            // --- Finalize Project Update ---
            if projectDidChange {
                projects[i].subDeadlines.sort { $0.date < $1.date } // Re-sort
                updatedProjectCount += 1
                // Save projects at the end, outside the loop
            }
        }

        // Save projects array if any changes were made across all projects
        if updatedProjectCount > 0 {
            saveProjects()
        } else {
        }

        }
    }

    // New function to handle updating template definition AND syncing projects based on changes
    @discardableResult
    func updateTemplateAndSyncProjects(original oldTemplate: Template, updated newTemplate: Template) -> Bool {
        performChanges {

        // 1. Update the template definition in the main array
        if let index = templates.firstIndex(where: { $0.id == newTemplate.id }) {
            templates[index] = newTemplate
            saveTemplates() // Save the updated templates list
            // 2. Trigger the project update logic, passing both old and new versions
            updateProjects(from: oldTemplate, to: newTemplate)
        } else {
            // If the template wasn't found, we probably shouldn't try to update projects either.
        }

        }
    }

    // --- TRIGGER CRUD OPERATIONS ---

    // Adds a new trigger for a specific project.
    @discardableResult
    func addTrigger(_ trigger: Trigger) -> Bool {
        performChanges {

        // Make sure trigger with same ID doesn't already exist
        if !triggers.contains(where: { $0.id == trigger.id }) {
            triggers.append(trigger)
            saveTriggers()
        } else {
        }

        }
    }

    // Activates a specific trigger.
    @discardableResult
    func activateTrigger(triggerID: UUID) -> Bool {
        performChanges {

        if let index = triggers.firstIndex(where: { $0.id == triggerID }) {
            if !triggers[index].isActive { // Only activate if not already active
                triggers[index].isActive = true
                triggers[index].activationDate = Date() // Record activation time
                let triggerName = triggers[index].name
                saveTriggers()
                // Notify observers things have changed
                objectWillChange.send()
            } else {
            }
        } else {
        }

        }
    }
    
    // Deactivates a trigger (allows re-activation later)
    @discardableResult
    func deactivateTrigger(triggerID: UUID) -> Bool {
        performChanges {

        if let index = triggers.firstIndex(where: { $0.id == triggerID }) {
            if triggers[index].isActive { // Only deactivate if currently active
                triggers[index].isActive = false
                // Keep activationDate for history
                let triggerName = triggers[index].name
                saveTriggers()
                // Notify observers things have changed
                objectWillChange.send()
            } else {
            }
        } else {
        }

        }
    }

    // Deletes a trigger and unlinks associated sub-deadlines.
    @discardableResult
    func deleteTrigger(triggerID: UUID) -> Bool {
        performChanges {

        if let index = triggers.firstIndex(where: { $0.id == triggerID }) {
            let deletedName = triggers[index].name
            let deletedProjectID = triggers[index].projectID
            triggers.remove(at: index)
            saveTriggers()

            // Unlink sub-deadlines in the associated project
            if let projectIndex = projects.firstIndex(where: { $0.id == deletedProjectID }) {
                var projectDidChange = false
                for subIndex in projects[projectIndex].subDeadlines.indices {
                    if projects[projectIndex].subDeadlines[subIndex].triggerID == triggerID {
                        projects[projectIndex].subDeadlines[subIndex].triggerID = nil
                        projectDidChange = true
                    }
                }
                if projectDidChange {
                    saveProjects() // Save project changes if sub-deadlines were unlinked
                }
            }
        } else {
        }

        }
    }

    // Updates trigger details (e.g., name)
    @discardableResult
    func updateTrigger(_ trigger: Trigger) -> Bool {
        performChanges {

         if let index = triggers.firstIndex(where: { $0.id == trigger.id }) {
             triggers[index] = trigger
             saveTriggers()
         } else {
         }

        }
    }

    // --- HELPER FUNCTIONS ---

    // Gets all triggers for a specific project.
    func triggers(for projectID: UUID) -> [Trigger] {
        triggers.filter { $0.projectID == projectID }
    }

    // Checks if a sub-deadline is active based on its trigger status.
    // Returns true if triggerID is nil OR the trigger is active.
    func isSubDeadlineActive(_ subDeadline: SubDeadline) -> Bool {
        guard let triggerID = subDeadline.triggerID else {
            return true // No trigger needed, always active
        }
        // Find the trigger and check its status
        if let trigger = triggers.first(where: { $0.id == triggerID }) {
            return trigger.isActive
        }
        // If trigger exists but wasn't found (shouldn't happen), treat as inactive.
        print("ViewModel Warning: Trigger ID \(triggerID) linked to sub-deadline '\(subDeadline.title)' not found. Treating as inactive.")
        return false
    }
    
    // MARK: - Notification Functions
    
    // Request notification permissions from the user
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("ViewModel: Notification permissions granted")
            } else if let error = error {
                print("ViewModel: Notification permission error: \(error.localizedDescription)")
            } else {
                print("ViewModel: Notification permissions denied")
            }
        }
    }
    
    // Schedule notifications based on user preferences
    private func scheduleDailyNotifications() {
        let center = UNUserNotificationCenter.current()
        
        // Remove any existing notifications for this identifier
        center.removePendingNotificationRequests(withIdentifiers: ["daily-deadline-reminder"])
        
        // Get user preferences
        let frequency = UserDefaults.standard.integer(forKey: "notificationFrequency")
        let deadlineCount = UserDefaults.standard.integer(forKey: "notificationDeadlineCount")
        let timeData = UserDefaults.standard.object(forKey: "notificationTime") as? Date
        
        // Use defaults if not set
        let notificationFrequency = frequency > 0 ? frequency : 1
        let notificationDeadlineCount = deadlineCount > 0 ? deadlineCount : 3
        
        // Get time components from saved time or default to 9:30 AM
        var dateComponents = DateComponents()
        if let savedTime = timeData {
            let calendar = Calendar.current
            dateComponents.hour = calendar.component(.hour, from: savedTime)
            dateComponents.minute = calendar.component(.minute, from: savedTime)
        } else {
            dateComponents.hour = 9
            dateComponents.minute = 30
        }
        
        // Create the notification content using the formatted settings
        let content = UNMutableNotificationContent()
        content.sound = .default
        
        // Get upcoming deadlines based on user preference
        let upcomingDeadlines = getUpcomingDeadlines(limit: notificationDeadlineCount)
        
        if upcomingDeadlines.isEmpty {
            content.title = appSettings.notificationFormatSettings.titleFormat
            content.body = "No upcoming deadlines"
        } else {
            // Use the formatted notification content
            let formattedContent = formatNotificationContent(for: upcomingDeadlines)
            content.title = formattedContent.title
            content.body = formattedContent.body
        }
        
        // Create the trigger based on frequency
        let trigger: UNNotificationTrigger
        if notificationFrequency == 1 {
            // Daily notifications
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        } else {
            // For multi-day frequencies, use time interval
            let interval = TimeInterval(notificationFrequency * 24 * 60 * 60) // Days to seconds
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: true)
        }
        
        // Create the request
        let request = UNNotificationRequest(identifier: "daily-deadline-reminder", content: content, trigger: trigger)
        
        // Schedule the notification
        center.add(request) { error in
            if let error = error {
                print("ViewModel: Error scheduling daily notification: \(error.localizedDescription)")
            } else {
                let frequencyText = notificationFrequency == 1 ? "daily" : "every \(notificationFrequency) days"
                print("ViewModel: Notification scheduled \(frequencyText) at \(dateComponents.hour ?? 9):\(String(format: "%02d", dateComponents.minute ?? 30))")
            }
        }
    }
    
    // Get upcoming deadlines sorted by date
    private func getUpcomingDeadlines(limit: Int) -> [(title: String, date: Date, projectTitle: String)] {
        let today = Date()
        var upcomingDeadlines: [(title: String, date: Date, projectTitle: String)] = []
        
        // Get all active projects
        let activeProjects = projects.filter { !$0.isFullyCompleted }
        
        // Collect all upcoming sub-deadlines
        for project in activeProjects {
            for subDeadline in project.subDeadlines {
                // Only include active sub-deadlines that are not completed
                if !subDeadline.isCompleted && 
                   isSubDeadlineActive(subDeadline) {
                    upcomingDeadlines.append((
                        title: subDeadline.title,
                        date: subDeadline.date,
                        projectTitle: project.title
                    ))
                }
            }
        }
        
        // Sort by date and limit results
        return upcomingDeadlines
            .sorted { $0.date < $1.date }
            .prefix(limit)
            .map { $0 }
    }
    
    // Update notifications when projects are modified
    func updateNotifications() {
        guard currentLoadAvailable, committedSnapshot != nil, batchDepth == 0 else { return }
        if let notificationObserver { notificationObserver(); return }
        guard effectsEnabled else { return }
        scheduleDailyNotifications()
    }
    
    // Public method to get upcoming deadlines for notification preview
    func getUpcomingDeadlinesForNotification(limit: Int) -> [(title: String, date: Date, projectTitle: String)] {
        return getUpcomingDeadlines(limit: limit)
    }
    
    // --- APP SETTINGS OPERATIONS ---
    
    // Updates color settings and saves
    @discardableResult
    func updateColorSettings(_ colorSettings: ColorSettings) -> Bool {
        performChanges {

        guard colorSettings.isValid else {
            return
        }
        self.appSettings.colorSettings = colorSettings
        saveAppSettings()

        }
    }
    
    // Updates notification format settings and saves
    @discardableResult
    func updateNotificationFormatSettings(_ notificationFormatSettings: NotificationFormatSettings) -> Bool {
        performChanges {

        self.appSettings.notificationFormatSettings = notificationFormatSettings
        saveAppSettings()

        }
    }
    
    // MARK: - iCloud Backup Methods
    
    /// Check if automatic backup should be performed
    @MainActor
    private func checkForAutomaticBackup() async {
        let backupManager = iCloudBackupManager.shared
        
        // Only proceed if iCloud is available
        guard backupManager.iCloudAvailable else {
            print("ViewModel: iCloud not available, skipping automatic backup check")
            return
        }
        
        // Check if we need to create an automatic backup
        if let lastBackupDate = backupManager.lastBackupDate {
            let hoursSinceLastBackup = Date().timeIntervalSince(lastBackupDate) / 3600
            if hoursSinceLastBackup >= 24 {
                print("ViewModel: Last backup was \(Int(hoursSinceLastBackup)) hours ago, creating automatic backup")
                await createAutomaticBackup()
            } else {
                print("ViewModel: Last backup was \(Int(hoursSinceLastBackup)) hours ago, no automatic backup needed")
            }
        } else {
            print("ViewModel: No previous backup found, creating first automatic backup")
            await createAutomaticBackup()
        }
    }
    
    /// Create an automatic backup
    @MainActor
    private func createAutomaticBackup() async {
        do {
            try await iCloudBackupManager.shared.createBackup(
                projects: projects,
                templates: templates,
                triggers: triggers,
                appSettings: appSettings
            )
            print("ViewModel: Automatic backup created successfully")
        } catch {
            print("ViewModel: Failed to create automatic backup: \(error)")
        }
    }
    
    // Get the current color for a date based on user settings
    func getColorForDate(_ date: Date) -> Color {
        let daysRemaining = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: date)).day ?? 0
        let colorSettings = appSettings.colorSettings
        
        switch daysRemaining {
        case ..<0:
            return .red // Overdue
        case 0..<colorSettings.orangeThreshold:
            return .red
        case colorSettings.orangeThreshold..<colorSettings.greenThreshold:
            return .orange
        default:
            return .green
        }
    }
    
    // Format a notification using the current settings
    func formatNotificationContent(for deadlines: [(title: String, date: Date, projectTitle: String)]) -> (title: String, body: String) {
        let settings = appSettings.notificationFormatSettings
        let title = settings.titleFormat
        
        var body = ""
        for (index, deadline) in deadlines.enumerated() {
            let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: deadline.date).day ?? 0
            let timeRemaining = daysUntil == 0 ? "Today" : daysUntil == 1 ? "Tomorrow" : "\(daysUntil) days"
            
            let formattedItem = settings.formatItem(
                index: index + 1,
                title: deadline.title,
                projectName: settings.showProjectName ? deadline.projectTitle : nil,
                date: deadline.date,
                timeRemaining: timeRemaining,
                daysLeft: daysUntil
            )
            
            body += formattedItem + "\n"
        }
        
        return (title: title, body: body.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

// MARK: - ShakeEffect (Generic Animation)
// A reusable geometry effect for adding a shaking animation.
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10 // How far to shake
    var shakesPerUnit = 3 // How many shakes within the animation duration
    var animatableData: CGFloat // The progress of the animation (0 to 1)

    // Calculates the horizontal translation for the shake effect.
    func effectValue(size: CGSize) -> ProjectionTransform {
        // Apply a sinusoidal translation based on the animation progress.
        ProjectionTransform(CGAffineTransform(translationX:
            amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
            y: 0)) // Only shake horizontally
    }
}


// MARK: - ContentView (Main Tabbed View)
// Contains the TabView for switching between All Deadlines and Projects.
struct ContentView: View {
    // Inject the shared ViewModel instance.
    @StateObject private var viewModel = DeadlineViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var lastActiveTime = Date()

    var body: some View {
        TabView {
            // --- Tab 1: All Deadlines View ---
            AllDeadlinesViewRedesigned(viewModel: viewModel)
                .tabItem {
                    Label("Deadlines", systemImage: "calendar.badge.clock") // Updated icon
                }
            
            // --- Tab 2: Projects View ---
            ProjectsListViewRedesigned(viewModel: viewModel) // Use the redesigned view
                .tabItem {
                    Label("Projects", systemImage: "folder")
                }
            
            // --- Tab 3: Templates View ---
            TemplateManagerViewRedesigned(viewModel: viewModel)
                .tabItem {
                    Label("Templates", systemImage: "doc.plaintext")
                }
            
            // --- Tab 4: Settings ---
            BackupRestoreViewRedesigned(viewModel: viewModel)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill") // Icon for settings
                }
        }
        .id(viewModel.editorGeneration)
        .safeAreaInset(edge: .bottom) { DeadlineSaveNotice(viewModel: viewModel) }
        .alert("Deadline data needs attention", isPresented: Binding(
            get: { viewModel.saveError != nil }, set: { if !$0 { viewModel.saveError = nil } }
        )) {
            Button("Reload current data", role: .destructive) { viewModel.reloadCurrentData() }
            Button("Keep editing", role: .cancel) { }
        } message: {
            Text((viewModel.saveError ?? "") + " Reload closes open editors. A failed attempted change remains retained until a later save.")
        }
        // --- ADDED .task MODIFIER --- 
        .task {
            // Load initial data when the TabView first appears
            if viewModel.isLoading { await viewModel.loadInitialData() }
        }
        // --- END ADDED MODIFIER --- 
        // Apply design system styling
        .appStyle()
        .accentColor(DesignSystem.Colors.primary)
        // Monitor scene phase changes to refresh dates
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                // App became active, check if dates need refreshing
                let timeSinceLastActive = Date().timeIntervalSince(lastActiveTime)
                // If more than 1 hour has passed, or it's a new day, force a refresh
                if timeSinceLastActive > 3600 || !Calendar.current.isDateInToday(lastActiveTime) {
                    print("ContentView: App became active after \(Int(timeSinceLastActive))s. Forcing date refresh.")
                    viewModel.objectWillChange.send()
                }
                lastActiveTime = Date()
            case .inactive, .background:
                break
            @unknown default:
                break
            }
        }
    }
}

// MARK: - ProjectsListView (Extracted from original ContentView)
// Displays the list of projects, header, and bottom buttons.
private struct ProjectsListView: View {
    // Observe the shared ViewModel
    @ObservedObject var viewModel: DeadlineViewModel

    // State variables to control sheet presentation (kept within this view)
    @State private var showingAddProjectSheet = false
    @State private var showingCompletedProjectsSheet = false
    @State private var showingTemplateManagerSheet = false
    @State private var selectedProjectID: UUID? = nil

    // Computed property to get sorted active (non-completed) projects.
    private var sortedActiveProjects: [Project] {
        viewModel.projects
            .filter { !$0.isFullyCompleted } // Filter out completed projects
            .sorted { $0.finalDeadlineDate < $1.finalDeadlineDate } // Sort by final deadline
    }

    // Computed property for the current date string.
    private var currentDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full // e.g., "Tuesday, June 18, 2024"
        return formatter.string(from: Date())
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) { // Use zero spacing for seamless components
                // --- Header ---
                VStack(spacing: 4) { // Reduced spacing in header
                    Text("Projects")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text(currentDate) // Display current date
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 10) // Adjust vertical padding
                .frame(maxWidth: .infinity) // Ensure header spans width
                .background(Color.black.edgesIgnoringSafeArea(.top)) // Extend background to top edge

                // --- Project List ---
                List {
                    // Check if there are any active projects to display.
                    if sortedActiveProjects.isEmpty {
                         Text("No active projects.\nTap '+' to add a new project.")
                             .font(.headline)
                             .foregroundColor(.gray)
                             .multilineTextAlignment(.center)
                             .padding(.vertical, 50)
                             .frame(maxWidth: .infinity)
                             .listRowBackground(Color.black)
                     } else {
                         Section(header: Text("Active Projects").foregroundColor(.gray).font(.headline).padding(.leading, -8)) {
                             ForEach(sortedActiveProjects) { project in
                                 NavigationLink(destination: ProjectDetailView(project: project, viewModel: viewModel),
                                               tag: project.id,
                                               selection: $selectedProjectID)
                                 {
                                     ProjectRow(project: project)
                                 }
                                     .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                         Button(role: .destructive) {
                                             deleteProjectAction(project: project)
                                         } label: {
                                             Label("Delete", systemImage: "trash")
                                         }
                                     }
                             }
                             .listRowBackground(Color.black)
                         }
                     }
                }
                .listStyle(PlainListStyle())
                .background(Color.black)

                // --- Bottom Button Bar ---
                HStack {
                    // Button to show completed projects (left)
                    Button {
                        showingCompletedProjectsSheet = true
                    } label: {
                        Label("Completed", systemImage: "checkmark.circle.fill")
                            .labelStyle(.iconOnly)
                    }
                    .frame(width: 60)
                    .sheet(isPresented: $showingCompletedProjectsSheet) {
                         CompletedProjectsView(viewModel: viewModel)
                    }
                    
                    Spacer()

                    // Button to add a new project (center)
                    Button {
                        showingAddProjectSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .resizable()
                            .frame(width: 44, height: 44) // Larger central button
                    }
                    .frame(maxWidth: .infinity)
                    .sheet(isPresented: $showingAddProjectSheet) {
                        AddProjectView(viewModel: viewModel)
                    }
                    
                    Spacer()

                    // Button to manage templates (right)
                    Button {
                        showingTemplateManagerSheet = true
                    } label: {
                        Label("Templates", systemImage: "doc.plaintext")
                            .labelStyle(.iconOnly)
                    }
                    .frame(width: 60)
                    .sheet(isPresented: $showingTemplateManagerSheet) {
                        TemplateManagerView(viewModel: viewModel)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.9))
                
            }
            .navigationBarHidden(true) // Hide the navigation bar as we have a custom header
            .background(Color.black.edgesIgnoringSafeArea(.all)) // Extend black background
            .preferredColorScheme(.dark)
        }
        .navigationViewStyle(.stack) // Use stack style appropriate for tabs
    }

    // Action to delete a project.
    private func deleteProjectAction(project: Project) {
        print("ContentView: Attempting to delete project '\(project.title)'.")
        viewModel.deleteProject(project)
    }
}

// MARK: - Preview Provider
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
             // You might want to inject a preview ViewModel here if needed
             // .environmentObject(DeadlineViewModel.preview)
            .preferredColorScheme(.dark)
    }
}

// Remove the old ContentView body, keep the ViewModel and helper structs/extensions if they were outside the old ContentView body.


/// Visible inside presented editors as well as the main tabs; no failed save
/// relies on a parent alert hidden behind its still-open sheet.
struct DeadlineSaveNotice: View {
    @ObservedObject var viewModel: DeadlineViewModel
    var body: some View {
        if viewModel.saveError != nil || viewModel.pendingSnapshot != nil {
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.saveError ?? "A copy of the unsuccessful change is still available. Review it before making a new edit.").font(.callout)
                if let attempted = viewModel.pendingChangeJSON {
                    ShareLink("Save a copy of the attempted changes", item: attempted)
                }
                Button("Reload current data and close editors") { viewModel.reloadCurrentData() }
            }
            .padding().background(.regularMaterial)
        }
    }
}
