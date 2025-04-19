// Deadline Calendar/BackupManager.swift

import Foundation
import SwiftUI // Needed for UIPasteboard access

// MARK: - Backup Error Enum
// Defines potential errors during the backup/restore process.
enum BackupError: Error, LocalizedError {
    case encodingFailed(Error)
    case decodingFailed(Error)
    case stringConversionFailed
    case noStringOnClipboard
    case invalidDataFormat

    // Provides user-friendly descriptions for errors.
    var errorDescription: String? {
        switch self {
        case .encodingFailed(let underlyingError):
            return "Error encoding data: \(underlyingError.localizedDescription)"
        case .decodingFailed(let underlyingError):
            return "Error decoding data: \(underlyingError.localizedDescription)"
        case .stringConversionFailed:
            return "Failed to convert backup data to text."
        case .noStringOnClipboard:
            return "Could not find text on the clipboard to restore from."
        case .invalidDataFormat:
            return "The text on the clipboard is not a valid backup format."
        }
    }
}

// MARK: - Backup Manager
// Handles exporting and importing application data (Projects, Templates, Triggers)
// using the clipboard.
struct BackupManager {

    // Internal struct representing the full data package, including triggers.
    // Used for EXPORTING the current state.
    struct BackupData: Codable {
        var projects: [Project]
        var templates: [Template]
        var triggers: [Trigger] // <-- ADDED for export
    }

    // MARK: - Export Function (Updated)
    /// Encodes the provided projects, templates, and triggers into a JSON string
    /// and copies it to the system clipboard.
    /// - Parameters:
    ///   - projects: An array of `Project` objects to be backed up.
    ///   - templates: An array of `Template` objects to be backed up.
    ///   - triggers: An array of `Trigger` objects to be backed up.
    /// - Throws: A `BackupError` if encoding or clipboard operation fails.
    static func exportData(projects: [Project], templates: [Template], triggers: [Trigger]) throws { // <-- Added triggers parameter
        print("Starting export process...")
        // 1. Create BackupData object with all current data
        let backupData = BackupData(projects: projects, templates: templates, triggers: triggers)
        print("BackupData object created with \(projects.count) projects, \(templates.count) templates, and \(triggers.count) triggers.")

        // 2. Encode to JSON Data
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        let jsonData: Data
        do {
            jsonData = try encoder.encode(backupData)
            print("Successfully encoded data to JSON format. Size: \(jsonData.count) bytes.")
        } catch {
            print("Error encoding data: \(error)")
            throw BackupError.encodingFailed(error)
        }

        // 3. Convert JSON Data to String
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("Error converting JSON data to String.")
            throw BackupError.stringConversionFailed
        }
        print("Successfully converted JSON data to String.")

        // 4. Copy to Clipboard
        #if os(iOS) || os(watchOS) || os(tvOS)
        UIPasteboard.general.string = jsonString
        print("JSON string copied to UIPasteboard.")
        #elseif os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(jsonString, forType: .string)
        print("JSON string copied to NSPasteboard.")
        #else
        print("Warning: Clipboard functionality not implemented for this platform.")
        #endif
        
        print("Export process completed successfully.")
    }

    // MARK: - Import Function (Rewritten for Compatibility)
    /// Attempts to read a JSON string from the system clipboard,
    /// decode it (handling older formats lacking triggers), reconstruct trigger data,
    /// and return the complete data set.
    /// - Returns: A tuple containing the reconstructed `projects`, `templates`, and `triggers`.
    /// - Throws: A `BackupError` if clipboard reading, string conversion, or decoding fails.
    static func importData() throws -> (projects: [Project], templates: [Template], triggers: [Trigger]) {
        print("Starting import process...")
        
        // --- Define Temporary Structs for Decoding --- 
        // Struct matching the OLD project format in the backup JSON (no 'triggers' field)
        struct Project_OldFormat: Codable {
            let id: UUID
            var title: String
            var finalDeadlineDate: Date
            var subDeadlines: [SubDeadline] // SubDeadline struct itself might be compatible, or need an old version too?
                                            // Assuming current SubDeadline is okay for now, but might need adjustment
                                            // if its structure also changed significantly in backup.
            var templateID: UUID?
            var templateName: String?
            // NOTE: Missing 'triggers: [Trigger]' field compared to current Project model
        }

        // Struct matching the overall OLD backup format (no top-level 'triggers')
        struct BackupData_OldFormat: Codable {
            var projects: [Project_OldFormat]
            var templates: [Template] // Assuming Template structure is compatible
        }
        
        // --- Read and Decode --- 
        // 1. Read from Clipboard (Same as before)
        let pasteboardString: String?
        #if os(iOS) || os(watchOS) || os(tvOS)
        pasteboardString = UIPasteboard.general.string
        #elseif os(macOS)
        pasteboardString = NSPasteboard.general.string(forType: .string)
        #else
        pasteboardString = nil
        #endif

        guard let jsonString = pasteboardString else {
            print("Error: No string found on the clipboard.")
            throw BackupError.noStringOnClipboard
        }
        print("Retrieved string from clipboard.")

        // 2. Convert String to JSON Data (Same as before)
        guard let jsonData = jsonString.data(using: .utf8) else {
            print("Error converting clipboard string back to Data.")
            throw BackupError.invalidDataFormat
        }
        print("Converted clipboard string to Data. Size: \(jsonData.count) bytes.")

        // 3. Decode JSON Data using the OLD format struct
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decodedOldData: BackupData_OldFormat
        do {
            decodedOldData = try decoder.decode(BackupData_OldFormat.self, from: jsonData)
            print("Successfully decoded JSON data using BackupData_OldFormat.")
            print("Decoded \(decodedOldData.projects.count) projects (old format) and \(decodedOldData.templates.count) templates.")
        } catch {
            print("Error decoding JSON data: \(error)")
            if let decodingError = error as? DecodingError {
                 print("Decoding error details: \(decodingError)")
            }
            throw BackupError.decodingFailed(error)
        }
        
        // --- Reconstruct Full Data Model --- 
        print("Reconstructing full data model including triggers...")
        var allImportedTriggers: [Trigger] = []
        var reconstructedProjects: [Project] = []
        
        // Build lookup for templates and their subdeadlines
        let templatesByID = Dictionary(uniqueKeysWithValues: decodedOldData.templates.map { ($0.id, $0) })
        let templateSubDeadlinesByID = Dictionary(uniqueKeysWithValues: decodedOldData.templates.flatMap { $0.subDeadlines }.map { ($0.id, $0) })

        // Process each project from the old format
        for oldProject in decodedOldData.projects {
            print("  Processing project: '\(oldProject.title)' (ID: \(oldProject.id))")
            var projectTriggers: [Trigger] = []
            var projectTriggerMap: [UUID: UUID] = [:] // Map templateTriggerID -> real TriggerID for this project
            
            // Find the template used by this project
            if let templateID = oldProject.templateID, let template = templatesByID[templateID] {
                // Create actual Trigger instances for this project based on the template
                for templateTrigger in template.templateTriggers {
                    let newRealTrigger = Trigger(
                        id: UUID(), // Generate a new ID for the project-specific trigger instance
                        name: templateTrigger.name, 
                        projectID: oldProject.id, // Link to this project
                        isActive: false, // Imported triggers start inactive
                        activationDate: nil,
                        originatingTemplateTriggerID: templateTrigger.id // Link back to template def
                    )
                    projectTriggers.append(newRealTrigger)
                    projectTriggerMap[templateTrigger.id] = newRealTrigger.id
                }
                print("    Created \(projectTriggers.count) triggers for this project based on template '\(template.name)'.")
            } else {
                 print("    Warning: Template ID \(oldProject.templateID?.uuidString ?? "nil") not found for this project. No triggers created.")
            }
            
            // Add the created triggers for this project to the main list
            allImportedTriggers.append(contentsOf: projectTriggers)
            
            // Reconstruct subdeadlines, linking triggers
            var reconstructedSubDeadlines: [SubDeadline] = []
            for oldSubDeadline in oldProject.subDeadlines {
                var reconstructedSub = oldSubDeadline // Start with the old data
                
                // Attempt to find the original TemplateSubDeadline to get the templateTriggerID
                if let templateSubDeadlineID = oldSubDeadline.templateSubDeadlineID,
                   let templateSubDeadline = templateSubDeadlinesByID[templateSubDeadlineID],
                   let templateTriggerID = templateSubDeadline.templateTriggerID,
                   let realTriggerID = projectTriggerMap[templateTriggerID] {
                    // Found a link! Set the triggerID on the reconstructed subdeadline.
                    reconstructedSub.triggerID = realTriggerID
                     print("    Linked sub-deadline '\(reconstructedSub.title)' to trigger ID \(realTriggerID).")
                } else {
                    // Ensure triggerID is nil if no link was found or defined
                    reconstructedSub.triggerID = nil
                }
                reconstructedSubDeadlines.append(reconstructedSub)
            }
            
            // Create the final, modern Project object
            let reconstructedProject = Project(
                id: oldProject.id,
                title: oldProject.title,
                finalDeadlineDate: oldProject.finalDeadlineDate,
                subDeadlines: reconstructedSubDeadlines.sorted { $0.date < $1.date }, // Ensure sorted
                triggers: projectTriggers, // Assign the reconstructed triggers
                templateID: oldProject.templateID,
                templateName: oldProject.templateName
            )
            reconstructedProjects.append(reconstructedProject)
        }
        
        print("Reconstruction complete. Final counts: Projects=\(reconstructedProjects.count), Templates=\(decodedOldData.templates.count), Triggers=\(allImportedTriggers.count)")
        
        // 4. Return the fully reconstructed data
        return (projects: reconstructedProjects, templates: decodedOldData.templates, triggers: allImportedTriggers)
    }
}

// Make sure the main Project, Template, SubDeadline, Trigger structs are defined elsewhere
// and are Codable as expected by the NEW format (used in export and internal ViewModel state). 