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


    // Initializer: ONLY sets up UserDefaults now.
    init() {
        // Check both shared and standard UserDefaults
        if let sharedDefaults = UserDefaults(suiteName: "group.com.yourapp.deadlines") {
            self.userDefaults = sharedDefaults
            print("ViewModel Init: Using shared UserDefaults (group.com.yourapp.deadlines).")
        } else {
            print("ViewModel Init: Failed to get shared UserDefaults. Using standard.")
            self.userDefaults = UserDefaults.standard
        }
        
        // Request notification permissions (but don't schedule yet - data isn't loaded)
        requestNotificationPermissions()
    }

    // New function to load data asynchronously
    @MainActor // Ensure UI updates happen on the main thread
    func loadInitialData() async {
        print("ViewModel: Starting initial data load...")
        isLoading = true
        
        // Try to recover data from standard UserDefaults if shared is empty
        attemptDataRecovery()
        
        // Perform loading (these are synchronous for now)
        loadProjects()
        loadTemplates()
        loadTriggers()
        loadAppSettings()
        
        // Migrate existing triggers to have dates
        migrateTriggersWithoutDates()

        // Removed default template creation - templates are now user-created only
        
        isLoading = false
        print("ViewModel: Initial data load complete.")
        
        // Print summary of loaded data
        print("\n=== DATA LOAD SUMMARY ===")
        print("Projects: \(projects.count)")
        print("Templates: \(templates.count)")
        for template in templates {
            print("  - '\(template.name)' (ID: \(template.id))")
        }
        print("Triggers: \(triggers.count)")
        print("========================\n")
        
        // Schedule notifications now that data is loaded
        scheduleDailyNotifications()
    }
    
    // Attempt to recover data from various sources
    private func attemptDataRecovery() {
        print("\n--- Attempting Data Recovery ---")
        
        // First, let's see what's in the shared container
        print("Current data in shared container:")
        if let sharedData = userDefaults.data(forKey: "templates_key") {
            print("  - templates_key in shared: \(sharedData.count) bytes")
            if let templates = try? JSONDecoder().decode([Template].self, from: sharedData) {
                print("    Contains \(templates.count) templates:")
                for template in templates {
                    print("      * '\(template.name)' (ID: \(template.id))")
                }
            }
        }
        
        // Check standard UserDefaults
        let standardDefaults = UserDefaults.standard
        let possibleKeys = ["projects_v2_key", "projects_key", "projects", "templates_key", "templates", "triggers_v1_key", "triggers_key"]
        
        print("\nChecking standard UserDefaults for data...")
        for key in possibleKeys {
            if let data = standardDefaults.data(forKey: key) {
                print("Found data in standard UserDefaults for key: \(key) (size: \(data.count) bytes)")
                
                // Special handling for templates since they might need migration
                if key == "templates_key" || key == "templates" {
                    print("Attempting to decode and migrate templates from standard UserDefaults...")
                    print("Current templates count before recovery: \(self.templates.count)")
                    
                    // Try new format first
                    do {
                        let templates = try JSONDecoder().decode([Template].self, from: data)
                        print("Successfully decoded \(templates.count) templates in new format from standard UserDefaults")
                        for template in templates {
                            print("  - Template: '\(template.name)' (ID: \(template.id))")
                        }
                        // Only update if we got more templates than we already have
                        if templates.count > self.templates.count {
                            self.templates = templates
                            saveTemplates() // This will save to shared container
                            standardDefaults.removeObject(forKey: key)
                        }
                        continue
                    } catch {
                        print("Failed to decode templates as new format: \(error)")
                    
                    // Try old format
                    struct OldTemplate: Codable {
                        let id: UUID
                        var name: String
                        var subDeadlines: [TemplateSubDeadline]
                    }
                    
                    do {
                        let oldTemplates = try JSONDecoder().decode([OldTemplate].self, from: data)
                        print("Successfully decoded \(oldTemplates.count) templates in old format from standard UserDefaults")
                        let convertedTemplates = oldTemplates.map { oldTemplate in
                            Template(
                                id: oldTemplate.id,
                                name: oldTemplate.name,
                                subDeadlines: oldTemplate.subDeadlines,
                                templateTriggers: []
                            )
                        }
                        for template in convertedTemplates {
                            print("  - Template: '\(template.name)' (ID: \(template.id))")
                        }
                        // Only update if we got more templates
                        if convertedTemplates.count > self.templates.count {
                            self.templates = convertedTemplates
                            saveTemplates() // This will save to shared container
                            standardDefaults.removeObject(forKey: key)
                        }
                        continue
                    } catch {
                        print("Failed to decode templates as old format: \(error)")
                    }
                    
                    print("Failed to decode templates from standard UserDefaults in any format")
                }
                
                // For other keys, try direct copy (but the CFPrefs error might prevent this)
                if userDefaults.data(forKey: key) == nil {
                    // Instead of direct copy which might fail, we'll handle this in the load functions
                    print("Will attempt to load \(key) from standard UserDefaults in load function")
                }
            }
        }
        
        print("--- End Data Recovery ---\n")
    }
    }
    
    // Migrate existing triggers to have dates if they don't have them
    private func migrateTriggersWithoutDates() {
        print("\n--- Migrating Triggers Without Dates ---")
        var migratedCount = 0
        
        for i in triggers.indices {
            if triggers[i].date == nil {
                // Find the project this trigger belongs to
                if let project = projects.first(where: { $0.id == triggers[i].projectID }) {
                    // Check if this trigger came from a template
                    if let templateID = project.templateID,
                       let template = templates.first(where: { $0.id == templateID }),
                       let originatingID = triggers[i].originatingTemplateTriggerID,
                       let templateTrigger = template.templateTriggers.first(where: { $0.id == originatingID }) {
                        // Use the template's offset to calculate the date
                        do {
                            let triggerDate = try templateTrigger.offset.calculateDate(from: project.finalDeadlineDate)
                            triggers[i].date = triggerDate
                            print("  - Migrated trigger '\(triggers[i].name)' with template-based date: \(triggerDate)")
                            migratedCount += 1
                        } catch {
                            // Fallback to default date
                            let defaultDate = Calendar.current.date(byAdding: .day, value: -7, to: project.finalDeadlineDate) ?? Date()
                            triggers[i].date = defaultDate
                            print("  - Migrated trigger '\(triggers[i].name)' with default date (7 days before): \(defaultDate)")
                            migratedCount += 1
                        }
                    } else {
                        // No template info, use a default date (7 days before project deadline)
                        let defaultDate = Calendar.current.date(byAdding: .day, value: -7, to: project.finalDeadlineDate) ?? Date()
                        triggers[i].date = defaultDate
                        print("  - Migrated trigger '\(triggers[i].name)' with default date (7 days before): \(defaultDate)")
                        migratedCount += 1
                    }
                }
            }
        }
        
        if migratedCount > 0 {
            saveTriggers()
            print("Migrated \(migratedCount) triggers with dates.")
        } else {
            print("No triggers needed migration.")
        }
        
        print("--- End Trigger Migration ---\n")
    }

    // --- DATA LOADING ---

    // Loads projects from UserDefaults.
    func loadProjects() {
        print("ViewModel Load: Attempting to load projects using key '\(projectsKey)'.") // Log key
        
        // Debug: Print all keys in UserDefaults
        print("\n--- DEBUG: All UserDefaults keys ---")
        let allKeys = userDefaults.dictionaryRepresentation().keys.sorted()
        for key in allKeys {
            print("  Key: \(key)")
        }
        print("--- END UserDefaults keys ---\n")
        
        // First, try to load from the current key
        if let data = userDefaults.data(forKey: projectsKey) {
            print("ViewModel Load: Found data for projects key. Attempting to decode...") // Log data found
            do {
                let decodedProjects = try JSONDecoder().decode([Project].self, from: data)
                self.projects = decodedProjects
                print("ViewModel Load: Projects loaded successfully (\(projects.count) projects).")
                return
            } catch {
                print("ViewModel Load: Failed to decode projects from v2 key. Error: \(error)")
                // Try to decode with old structure if needed
            }
        }
        
        // If no data found with v2 key, try to migrate from old keys
        let possibleOldKeys = ["projects_key", "projects", "SavedProjects"]
        for oldKey in possibleOldKeys {
            if let oldData = userDefaults.data(forKey: oldKey) {
                print("ViewModel Load: Found data with old key '\(oldKey)'. Attempting migration...")
                do {
                    let decodedProjects = try JSONDecoder().decode([Project].self, from: oldData)
                    self.projects = decodedProjects
                    print("ViewModel Load: Successfully migrated \(projects.count) projects from old key '\(oldKey)'.")
                    // Save to new key
                    saveProjects()
                    // Remove old key to prevent future confusion
                    userDefaults.removeObject(forKey: oldKey)
                    return
                } catch {
                    print("ViewModel Load: Failed to decode from key '\(oldKey)': \(error)")
                }
            }
        }
        
        print("ViewModel Load: No data found for projects. Initializing empty array.")
        self.projects = []
    }

    // Loads templates from UserDefaults.
    func loadTemplates() {
        print("ViewModel Load: Attempting to load templates using key '\(templatesKey)'.") // Log key
        
        // If we already have templates from recovery, don't overwrite them
        if !templates.isEmpty {
            print("ViewModel Load: Templates already loaded from recovery (\(templates.count) templates). Skipping load.")
            return
        }
        
        // First try the shared container
        if let data = userDefaults.data(forKey: templatesKey) {
            print("ViewModel Load: Found data for templates key. Attempting to decode...") // Log data found
            do {
                let decodedTemplates = try JSONDecoder().decode([Template].self, from: data)
                self.templates = decodedTemplates
                print("ViewModel Load: Templates loaded successfully (\(templates.count) templates).")
                // Print template names for debugging
                for template in templates {
                    print("  - Template: '\(template.name)' (ID: \(template.id))")
                }
                return
            } catch {
                print("ViewModel Load: Failed to decode templates. Error: \(error)")
                // Try to decode with old template structure (without templateTriggers field)
                do {
                    // Define old template structure
                    struct OldTemplate: Codable {
                        let id: UUID
                        var name: String
                        var subDeadlines: [TemplateSubDeadline]
                    }
                    
                    let oldTemplates = try JSONDecoder().decode([OldTemplate].self, from: data)
                    print("ViewModel Load: Detected old template format. Migrating \(oldTemplates.count) templates...")
                    
                    // Convert to new format
                    self.templates = oldTemplates.map { oldTemplate in
                        Template(
                            id: oldTemplate.id,
                            name: oldTemplate.name,
                            subDeadlines: oldTemplate.subDeadlines,
                            templateTriggers: [] // Old templates had no triggers
                        )
                    }
                    
                    print("ViewModel Load: Successfully migrated \(templates.count) templates from old format.")
                    // Save in new format
                    saveTemplates()
                    return
                } catch {
                    print("ViewModel Load: Failed to decode as old template format. Error: \(error)")
                }
            }
        }
        
        // If not found in shared, check standard UserDefaults
        let standardDefaults = UserDefaults.standard
        if let standardData = standardDefaults.data(forKey: templatesKey) {
            print("ViewModel Load: Found templates in standard UserDefaults. Attempting migration...")
            do {
                let decodedTemplates = try JSONDecoder().decode([Template].self, from: standardData)
                self.templates = decodedTemplates
                print("ViewModel Load: Successfully loaded \(templates.count) templates from standard UserDefaults.")
                // Print template names for debugging
                for template in templates {
                    print("  - Template: '\(template.name)' (ID: \(template.id))")
                }
                // Save to shared container
                saveTemplates()
                // Remove from standard to avoid confusion
                standardDefaults.removeObject(forKey: templatesKey)
                return
            } catch {
                print("ViewModel Load: Failed to decode templates from standard UserDefaults. Error: \(error)")
                
                // Try old format from standard UserDefaults
                struct OldTemplate: Codable {
                    let id: UUID
                    var name: String
                    var subDeadlines: [TemplateSubDeadline]
                }
                
                if let oldTemplates = try? JSONDecoder().decode([OldTemplate].self, from: standardData) {
                    print("ViewModel Load: Detected old template format in standard UserDefaults. Migrating \(oldTemplates.count) templates...")
                    self.templates = oldTemplates.map { oldTemplate in
                        Template(
                            id: oldTemplate.id,
                            name: oldTemplate.name,
                            subDeadlines: oldTemplate.subDeadlines,
                            templateTriggers: []
                        )
                    }
                    print("ViewModel Load: Successfully migrated \(templates.count) templates from old format.")
                    for template in templates {
                        print("  - Template: '\(template.name)' (ID: \(template.id))")
                    }
                    saveTemplates()
                    standardDefaults.removeObject(forKey: templatesKey)
                    return
                }
            }
        }
        
        print("ViewModel Load: No templates found. Initializing empty array.")
        self.templates = []
    }

    // Loads triggers from UserDefaults.
    func loadTriggers() {
        print("ViewModel Load: Attempting to load triggers using key '\(triggersKey)'.") // Log key
        guard let data = userDefaults.data(forKey: triggersKey) else {
            print("ViewModel Load: No data found for triggers key '\(triggersKey)'. Initializing empty array.")
            self.triggers = []
            return
        }
        print("ViewModel Load: Found data for triggers key. Attempting to decode...") // Log data found
        
        let decoder = JSONDecoder()
        do {
            self.triggers = try decoder.decode([Trigger].self, from: data)
            print("ViewModel Load: Triggers loaded successfully (\(triggers.count) triggers).")
        } catch {
            // --- Enhanced Error Logging --- 
            print("\n--- ViewModel FATAL ERROR: Failed to decode TRIGGERS from UserDefaults --- ")
            print("Error Description: \(error.localizedDescription)")
            print("Full Error: \(error)")
            if let decodingError = error as? DecodingError {
                print("Decoding Error Type: \(decodingError)")
                switch decodingError {
                case .typeMismatch(let type, let context): print("  Type Mismatch: '\(type)' at path \(context.codingPath.map { $0.stringValue }.joined(separator: ".")). Context: \(context.debugDescription)")
                case .valueNotFound(let type, let context): print("  Value Not Found: '\(type)' at path \(context.codingPath.map { $0.stringValue }.joined(separator: ".")). Context: \(context.debugDescription)")
                case .keyNotFound(let key, let context): print("  Key Not Found: '\(key.stringValue)' at path \(context.codingPath.map { $0.stringValue }.joined(separator: ".")). Context: \(context.debugDescription)")
                case .dataCorrupted(let context): print("  Data Corrupted at path \(context.codingPath.map { $0.stringValue }.joined(separator: ".")). Context: \(context.debugDescription)")
                @unknown default: print("  Unknown DecodingError occurred.")
                }
            }
            print("--- END TRIGGER DECODING ERROR ---\n")
            
            // Resetting to empty array.
            print("ViewModel Load: Resetting triggers to empty array due to decoding failure.")
            self.triggers = []
        }
    }

    // Loads app settings from UserDefaults.
    func loadAppSettings() {
        print("ViewModel Load: Attempting to load app settings using key '\(appSettingsKey)'.") 
        guard let data = userDefaults.data(forKey: appSettingsKey) else {
            print("ViewModel Load: No data found for app settings key '\(appSettingsKey)'. Using default settings.")
            self.appSettings = AppSettings()
            return
        }
        print("ViewModel Load: Found data for app settings key. Attempting to decode...") 
        
        let decoder = JSONDecoder()
        do {
            self.appSettings = try decoder.decode(AppSettings.self, from: data)
            print("ViewModel Load: App settings loaded successfully.")
        } catch {
            print("ViewModel Load: Failed to decode app settings from UserDefaults. Error: \(error)")
            print("ViewModel Load: Using default settings.")
            self.appSettings = AppSettings()
        }
    }

    // --- DATA SAVING ---

    // Saves the current state of projects to UserDefaults.
    func saveProjects() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(projects) {
            userDefaults.set(encoded, forKey: projectsKey)
            print("ViewModel: saveProjects() completed. (\(projects.count) projects)")
            reloadWidgets()
            updateNotifications()
        } else {
            print("ViewModel Error: Failed to encode projects for saving.")
        }
    }

    // Saves the current state of templates to UserDefaults.
    func saveTemplates() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(templates) {
            userDefaults.set(encoded, forKey: templatesKey)
            print("ViewModel: saveTemplates() completed. (\(templates.count) templates)")
            // Widgets might not directly use templates, but reloading ensures consistency if needed.
            // reloadWidgets() // Decide if widgets need template updates.
        } else {
            print("ViewModel Error: Failed to encode templates for saving.")
        }
    }

    // Saves the current state of triggers to UserDefaults.
    func saveTriggers() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(triggers) {
            userDefaults.set(encoded, forKey: triggersKey)
            print("ViewModel: saveTriggers() completed. (\(triggers.count) triggers)")
            // Trigger widget reload since trigger changes affect widget content
            reloadWidgets()
        } else {
            print("ViewModel Error: Failed to encode triggers for saving.")
        }
    }

    // Saves the current state of app settings to UserDefaults.
    func saveAppSettings() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(appSettings) {
            userDefaults.set(encoded, forKey: appSettingsKey)
            print("ViewModel: saveAppSettings() completed.")
        } else {
            print("ViewModel Error: Failed to encode app settings for saving.")
        }
    }

    // Utility function to reload widget timelines.
    func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
        print("ViewModel: Widget timelines reloaded.")
    }


    // --- PROJECT CRUD OPERATIONS ---

    // Adds a new project to the list and saves.
    func addProject(_ project: Project) {
        // Optional: Add validation to prevent duplicate projects if needed.
        // e.g., if !projects.contains(where: { $0.title == project.title }) { ... }
        projects.append(project)
        print("ViewModel: Added project '\(project.title)' (ID: \(project.id)).")
        saveProjects() // Save changes immediately.
    }

    // Updates an existing project in the list and saves.
    func updateProject(_ project: Project) {
        // Find the index of the project with the matching ID.
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project // Replace the old project with the updated one.
            print("ViewModel: Updated project '\(project.title)' (ID: \(project.id)).")
            saveProjects() // Save changes.
        } else {
            // Log if the project to update wasn't found.
            print("ViewModel Warning: Attempted to update a project (ID: \(project.id)) that does not exist.")
        }
    }

    // Deletes a project from the list and saves.
    func deleteProject(_ project: Project) {
        // Remove the project with the matching ID.
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            let deletedTitle = projects[index].title
            projects.remove(at: index)
            print("ViewModel: Deleted project '\(deletedTitle)' (ID: \(project.id)).")
            saveProjects() // Save changes.
        } else {
             print("ViewModel Warning: Attempted to delete a project (ID: \(project.id)) that does not exist.")
        }
    }


    // --- SUB-DEADLINE OPERATIONS ---

    // Adds a new standalone sub-deadline by finding or creating a special project to house it.
    func addStandaloneDeadline(_ deadline: SubDeadline) {
        let standaloneProjectName = "Standalone Deadlines"
        
        // Check if the standalone project already exists.
        if let projectIndex = projects.firstIndex(where: { $0.id == DeadlineViewModel.standaloneProjectID }) {
            // Project exists, add the deadline to it.
            projects[projectIndex].subDeadlines.append(deadline)
            projects[projectIndex].subDeadlines.sort { $0.date < $1.date }
            print("ViewModel: Added standalone deadline '\(deadline.title)' to existing project '\(standaloneProjectName)'.")
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
            print("ViewModel: Created new project '\(standaloneProjectName)' for standalone deadline '\(deadline.title)'.")
        }
    }

    // Updates a specific sub-deadline within a project.
    func updateSubDeadline(_ subDeadline: SubDeadline, in project: Project) {
        // Find the project index.
        guard let projectIndex = projects.firstIndex(where: { $0.id == project.id }) else {
            print("ViewModel Error: Project not found for updating sub-deadline (Project ID: \(project.id)).")
            return
        }
        // Find the sub-deadline index within that project.
        guard let subDeadlineIndex = projects[projectIndex].subDeadlines.firstIndex(where: { $0.id == subDeadline.id }) else {
            print("ViewModel Error: Sub-deadline not found within project '\(project.title)' (SubDeadline ID: \(subDeadline.id)).")
            return
        }

        // Update the specific sub-deadline.
        projects[projectIndex].subDeadlines[subDeadlineIndex] = subDeadline
        // Ensure subdeadlines within the project remain sorted after update
        projects[projectIndex].subDeadlines.sort { $0.date < $1.date }
        print("ViewModel: Updated sub-deadline '\(subDeadline.title)' in project '\(project.title)'.")
        saveProjects() // Save changes.
    }

    // Toggles the completion status of a sub-deadline.
    func toggleSubDeadlineCompletion(_ subDeadline: SubDeadline, in project: Project) {
        var mutableSubDeadline = subDeadline
        mutableSubDeadline.isCompleted.toggle() // Flip the completion status
        print("ViewModel: Toggled completion for sub-deadline '\(mutableSubDeadline.title)' to \(mutableSubDeadline.isCompleted).")
        // Call the update function to modify the project and save.
        updateSubDeadline(mutableSubDeadline, in: project)
    }

    // Deletes a specific sub-deadline from a specific project.
    func deleteSubDeadline(subDeadlineID: UUID, fromProjectID: UUID) {
        // Find the index of the project.
        guard let projectIndex = projects.firstIndex(where: { $0.id == fromProjectID }) else {
            print("ViewModel Error: Project not found for deleting sub-deadline (Project ID: \(fromProjectID)).")
            return
        }
        
        // Find the index of the sub-deadline within that project.
        guard let subDeadlineIndex = projects[projectIndex].subDeadlines.firstIndex(where: { $0.id == subDeadlineID }) else {
            print("ViewModel Error: Sub-deadline not found for deletion within project '\(projects[projectIndex].title)' (SubDeadline ID: \(subDeadlineID)).")
            return
        }
        
        // Remove the sub-deadline from the project's array.
        let deletedTitle = projects[projectIndex].subDeadlines[subDeadlineIndex].title
        projects[projectIndex].subDeadlines.remove(at: subDeadlineIndex)
        print("ViewModel: Deleted sub-deadline '\(deletedTitle)' from project '\(projects[projectIndex].title)'.")
        
        // Save the updated projects array.
        saveProjects()
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
    func createTemplateFromProject(_ project: Project) -> String {
        let template = createTemplateFromProjectInternal(project)
        addTemplate(template)
        return template.name
    }

    // Adds a new template and saves.
    func addTemplate(_ template: Template) {
        // Optional: Add validation, e.g., prevent duplicate template names.
         if !templates.contains(where: { $0.name == template.name }) {
            templates.append(template)
            print("ViewModel: Added template '\(template.name)' (ID: \(template.id)).")
            saveTemplates() // Save changes.
         } else {
             print("ViewModel Warning: Attempted to add a template with a duplicate name '\(template.name)'.")
         }
    }

    // Updates an existing template and saves.
    // Consider implications for existing projects using this template.
    // Currently, this only updates the template definition itself.
    func updateTemplate(_ template: Template) {
        // Find the index of the template with the matching ID.
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template // Replace the old template.
            print("ViewModel: Updated template '\(template.name)' (ID: \(template.id)).")
            saveTemplates() // Save changes.
            // Add logic here if template updates should optionally update existing projects.
        } else {
            print("ViewModel Warning: Attempted to update a template (ID: \(template.id)) that does not exist.")
        }
    }

    // Deletes a template.
    func deleteTemplate(_ template: Template) {
        // Find the index and remove the template.
         if let index = templates.firstIndex(where: { $0.id == template.id }) {
             let deletedName = templates[index].name
             templates.remove(at: index)
             print("ViewModel: Deleted template '\(deletedName)' (ID: \(template.id)).")
             saveTemplates() // Save changes.
             // Consider what happens to projects linked to this template ID.
             // Maybe clear the templateID field in associated projects?
             // For now, just deleting the template definition.
         } else {
             print("ViewModel Warning: Attempted to delete a template (ID: \(template.id)) that does not exist.")
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
    func updateProjects(from oldTemplate: Template, to updatedTemplate: Template) {
        print("ViewModel: Comparing template versions ('\(oldTemplate.name)' -> '\(updatedTemplate.name)') to update projects.")

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
            print("  - Syncing Project: '\(project.title)' (ID: \(project.id))")

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
                print("    - Handling added template triggers for project '\(project.title)'...")
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
                            print("      - Created real trigger '\(newRealTrigger.name)' with date \(triggerDate) from added template trigger.")
                        } catch {
                            print("      - Error calculating date for trigger '\(trigDefToAdd.name)': \(error)")
                        }
                     }
                }
            }

            // Handle Deleted Template Triggers: Delete real Triggers in this project
            if !deletedTrigDefIDs.isEmpty {
                 print("    - Handling deleted template triggers for project '\(project.title)'...")
                 for deletedTrigDefID in deletedTrigDefIDs {
                     // Find the real trigger in this project that originated from the deleted template trigger
                     if let realTriggerToDelete = self.triggers(for: project.id).first(where: { $0.originatingTemplateTriggerID == deletedTrigDefID }) {
                         print("      - Deleting real trigger '\(realTriggerToDelete.name)' (and unlinking sub-deadlines) due to template trigger deletion.")
                         self.deleteTrigger(triggerID: realTriggerToDelete.id) // Deletes & saves triggers/projects
                         projectDidChange = true // Indicate change
                         // Remove from map if needed, though deletion handles this
                         currentProjectTriggerMap.removeValue(forKey: deletedTrigDefID)
                     }
                 }
            }

            // Handle Renamed Template Triggers: Update real Triggers in this project
            if !trigDefNameChanges.isEmpty || !trigDefOffsetChanges.isEmpty {
                 print("    - Handling updated template triggers for project '\(project.title)'...")
                 for trigDefID in commonTrigDefIDs {
                     if let realTriggerToUpdate = self.triggers(for: project.id).first(where: { $0.originatingTemplateTriggerID == trigDefID }) {
                         var needsUpdate = false
                         var mutableTrigger = realTriggerToUpdate // Create mutable copy
                         
                         // Check for name change
                         if let newName = trigDefNameChanges[trigDefID], realTriggerToUpdate.name != newName {
                             print("      - Renaming real trigger '\(realTriggerToUpdate.name)' to '\(newName)'.")
                             mutableTrigger.name = newName
                             needsUpdate = true
                         }
                         
                         // Check for offset change
                         if let newOffset = trigDefOffsetChanges[trigDefID] {
                             do {
                                 let newDate = try newOffset.calculateDate(from: project.finalDeadlineDate)
                                 if mutableTrigger.date != newDate {
                                     print("      - Updating trigger date for '\(mutableTrigger.name)': \(mutableTrigger.date) -> \(newDate)")
                                     mutableTrigger.date = newDate
                                     needsUpdate = true
                                 }
                             } catch {
                                 print("      - Error calculating new date for trigger '\(mutableTrigger.name)': \(error)")
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
            print("    - Handling sub-deadline definition changes for project '\(project.title)'...")
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
                        print("      - Updating sub-deadline title: '\(projects[i].subDeadlines[j].title)' -> '\(newTitle)'")
                        projects[i].subDeadlines[j].title = newTitle
                        subDeadlineNeedsSave = true
                    }
                }

                // Apply offset change (recalculate date) if needed
                if let newOffset = subDefOffsetChanges[templateSubDeadlineID] {
                    do {
                        let newDate = try newOffset.calculateDate(from: projects[i].finalDeadlineDate)
                        if projects[i].subDeadlines[j].date != newDate {
                            print("      - Updating sub-deadline date for '\(projects[i].subDeadlines[j].title)': \(projects[i].subDeadlines[j].date) -> \(newDate)")
                            projects[i].subDeadlines[j].date = newDate
                            subDeadlineNeedsSave = true
                        }
                    } catch {
                        print("ViewModel Error (sync): Could not recalc date for '\(projects[i].subDeadlines[j].title)': \(error)")
                    }
                }

                // Update Trigger Link?
                if let newTemplateTriggerID = subDefTriggerLinkChanges[templateSubDeadlineID] { // Note: newTemplateTriggerID can be nil
                   let newRealTriggerID = newTemplateTriggerID.flatMap { currentProjectTriggerMap[$0] }
                    if projects[i].subDeadlines[j].triggerID != newRealTriggerID {
                        print("      - Updating trigger link for '\(projects[i].subDeadlines[j].title)' to trigger ID: \(newRealTriggerID?.uuidString ?? "None")")
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
                print("    - Adding new sub-deadlines based on template changes...")
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
                            print("      - Added new sub-deadline: '\(newSub.title)', Trigger: \(realTriggerID != nil)")
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
                print("    - Project '\(project.title)' was modified.")
                // Save projects at the end, outside the loop
            }
        }

        // Save projects array if any changes were made across all projects
        if updatedProjectCount > 0 {
            print("ViewModel: Finished syncing projects. \(updatedProjectCount) project(s) modified. Saving projects...")
            saveProjects()
        } else {
            print("ViewModel: Finished syncing projects. No projects required updates based on template diff.")
        }
    }

    // New function to handle updating template definition AND syncing projects based on changes
    func updateTemplateAndSyncProjects(original oldTemplate: Template, updated newTemplate: Template) {
        print("ViewModel: Updating template '\(newTemplate.name)' AND syncing projects.")
        // 1. Update the template definition in the main array
        if let index = templates.firstIndex(where: { $0.id == newTemplate.id }) {
            templates[index] = newTemplate
            saveTemplates() // Save the updated templates list
            print("  - Template definition updated successfully.")
            // 2. Trigger the project update logic, passing both old and new versions
            updateProjects(from: oldTemplate, to: newTemplate)
        } else {
            print("ViewModel Warning: Could not find template with ID \(newTemplate.id) to update.")
            // If the template wasn't found, we probably shouldn't try to update projects either.
        }
    }

    // --- TRIGGER CRUD OPERATIONS ---

    // Adds a new trigger for a specific project.
    func addTrigger(_ trigger: Trigger) {
        // Make sure trigger with same ID doesn't already exist
        if !triggers.contains(where: { $0.id == trigger.id }) {
            triggers.append(trigger)
            print("ViewModel: Added trigger '\(trigger.name)' for project ID \(trigger.projectID).")
            saveTriggers()
        } else {
            print("ViewModel Warning: Attempted to add trigger with duplicate ID \(trigger.id).")
        }
    }

    // Activates a specific trigger.
    func activateTrigger(triggerID: UUID) {
        if let index = triggers.firstIndex(where: { $0.id == triggerID }) {
            if !triggers[index].isActive { // Only activate if not already active
                triggers[index].isActive = true
                triggers[index].activationDate = Date() // Record activation time
                let triggerName = triggers[index].name
                print("ViewModel: Activated trigger '\(triggerName)' (ID: \(triggerID)).")
                saveTriggers()
                // Notify observers things have changed
                objectWillChange.send()
            } else {
                print("ViewModel Info: Trigger ID \(triggerID) was already active.")
            }
        } else {
            print("ViewModel Warning: Attempted to activate a trigger (ID: \(triggerID)) that does not exist.")
        }
    }
    
    // Deactivates a trigger (allows re-activation later)
    func deactivateTrigger(triggerID: UUID) {
        if let index = triggers.firstIndex(where: { $0.id == triggerID }) {
            if triggers[index].isActive { // Only deactivate if currently active
                triggers[index].isActive = false
                // Keep activationDate for history
                let triggerName = triggers[index].name
                print("ViewModel: Deactivated trigger '\(triggerName)' (ID: \(triggerID)).")
                saveTriggers()
                // Notify observers things have changed
                objectWillChange.send()
            } else {
                print("ViewModel Info: Trigger ID \(triggerID) was already inactive.")
            }
        } else {
            print("ViewModel Warning: Attempted to deactivate a trigger (ID: \(triggerID)) that does not exist.")
        }
    }

    // Deletes a trigger and unlinks associated sub-deadlines.
    func deleteTrigger(triggerID: UUID) {
        if let index = triggers.firstIndex(where: { $0.id == triggerID }) {
            let deletedName = triggers[index].name
            let deletedProjectID = triggers[index].projectID
            triggers.remove(at: index)
            print("ViewModel: Deleted trigger '\(deletedName)' (ID: \(triggerID)).")
            saveTriggers()

            // Unlink sub-deadlines in the associated project
            if let projectIndex = projects.firstIndex(where: { $0.id == deletedProjectID }) {
                var projectDidChange = false
                for subIndex in projects[projectIndex].subDeadlines.indices {
                    if projects[projectIndex].subDeadlines[subIndex].triggerID == triggerID {
                        projects[projectIndex].subDeadlines[subIndex].triggerID = nil
                        projectDidChange = true
                        print("  - Unlinked sub-deadline '\(projects[projectIndex].subDeadlines[subIndex].title)' in project '\(projects[projectIndex].title)'.")
                    }
                }
                if projectDidChange {
                    saveProjects() // Save project changes if sub-deadlines were unlinked
                }
            }
        } else {
            print("ViewModel Warning: Attempted to delete a trigger (ID: \(triggerID)) that does not exist.")
        }
    }

    // Updates trigger details (e.g., name)
    func updateTrigger(_ trigger: Trigger) {
         if let index = triggers.firstIndex(where: { $0.id == trigger.id }) {
             triggers[index] = trigger
             print("ViewModel: Updated trigger '\(trigger.name)' (ID: \(trigger.id)).")
             saveTriggers()
         } else {
             print("ViewModel Warning: Attempted to update trigger (ID: \(trigger.id)) that does not exist.")
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
        scheduleDailyNotifications()
    }
    
    // Public method to get upcoming deadlines for notification preview
    func getUpcomingDeadlinesForNotification(limit: Int) -> [(title: String, date: Date, projectTitle: String)] {
        return getUpcomingDeadlines(limit: limit)
    }
    
    // --- APP SETTINGS OPERATIONS ---
    
    // Updates color settings and saves
    func updateColorSettings(_ colorSettings: ColorSettings) {
        guard colorSettings.isValid else {
            print("ViewModel Error: Invalid color settings provided")
            return
        }
        self.appSettings.colorSettings = colorSettings
        saveAppSettings()
        print("ViewModel: Color settings updated")
    }
    
    // Updates notification format settings and saves
    func updateNotificationFormatSettings(_ notificationFormatSettings: NotificationFormatSettings) {
        self.appSettings.notificationFormatSettings = notificationFormatSettings
        saveAppSettings()
        print("ViewModel: Notification format settings updated")
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
        // --- ADDED .task MODIFIER --- 
        .task {
            // Load initial data when the TabView first appears
            await viewModel.loadInitialData()
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

