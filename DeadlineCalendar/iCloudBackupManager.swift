// Deadline Calendar/DeadlineCalendar/iCloudBackupManager.swift

import Foundation
import SwiftUI
import UIKit

// MARK: - Backup Data Structures

/// Represents a backed up project for storage
struct BackupProject: Codable {
    let id: UUID
    var title: String
    var finalDeadlineDate: Date
    var subDeadlines: [BackupSubDeadline]
    var triggers: [BackupTrigger]
    var templateID: UUID?
    var templateName: String?
}

/// Represents a backed up sub-deadline
struct BackupSubDeadline: Codable {
    let id: UUID
    var title: String
    var date: Date
    var isCompleted: Bool
    var subtasks: [BackupSubtask]
    let templateSubDeadlineID: UUID?
    var triggerID: UUID?
}

/// Represents a backed up subtask
struct BackupSubtask: Codable {
    let id: UUID
    var title: String
    var isCompleted: Bool
}

/// Represents a backed up trigger
struct BackupTrigger: Codable {
    let id: UUID
    var name: String
    var isActive: Bool
    let projectID: UUID
    var activationDate: Date?
    var originatingTemplateTriggerID: UUID?
    var date: Date?
}

/// Represents a backed up template
struct BackupTemplate: Codable {
    let id: UUID
    var name: String
    var subDeadlines: [BackupTemplateSubDeadline]
    var templateTriggers: [BackupTemplateTrigger]
}

/// Represents a backed up template sub-deadline
struct BackupTemplateSubDeadline: Codable {
    let id: UUID
    var title: String
    var offset: TimeOffset
    var templateTriggerID: UUID?
}

/// Represents a backed up template trigger
struct BackupTemplateTrigger: Codable {
    let id: UUID
    var name: String
    var offset: TimeOffset
}

/// Container for all backup data
struct DeadlineCalendarBackupData: Codable {
    let version: String
    let createdDate: Date
    let deviceName: String
    var projects: [BackupProject]
    var templates: [BackupTemplate]
    var triggers: [BackupTrigger]
    var appSettings: AppSettings
}

// MARK: - Backup Error

enum iCloudBackupError: LocalizedError {
    case iCloudNotAvailable
    case documentsFolderNotFound
    case backupCreationFailed(String)
    case backupRestorationFailed(String)
    case noBackupsFound
    case dataEncodingFailed
    case dataDecodingFailed
    
    var errorDescription: String? {
        switch self {
        case .iCloudNotAvailable:
            return "iCloud is not available. Please ensure you're signed into iCloud and iCloud Drive is enabled."
        case .documentsFolderNotFound:
            return "Could not access iCloud documents folder."
        case .backupCreationFailed(let reason):
            return "Failed to create backup: \(reason)"
        case .backupRestorationFailed(let reason):
            return "Failed to restore backup: \(reason)"
        case .noBackupsFound:
            return "No backups found in iCloud."
        case .dataEncodingFailed:
            return "Failed to encode backup data."
        case .dataDecodingFailed:
            return "Failed to decode backup data."
        }
    }
}

// MARK: - iCloud Backup Manager

@MainActor
class iCloudBackupManager: ObservableObject {
    static let shared = iCloudBackupManager()
    
    @Published var availableBackups: [DeadlineCalendarBackupDocument] = []
    @Published var isCreatingBackup = false
    @Published var isLoadingBackups = false
    @Published var lastBackupDate: Date?
    @Published var iCloudAvailable = false
    
    private let backupsFolderName = "DeadlineCalendarBackups"
    private let fileExtension = "deadlinebackup"
    private let lastBackupDateKey = "lastDeadlineCalendarBackupDate"
    
    init() {
        checkiCloudAvailability()
        loadLastBackupDate()
    }
    
    // MARK: - Public Methods
    
    /// Check if iCloud is available
    func checkiCloudAvailability() {
        if FileManager.default.ubiquityIdentityToken != nil {
            iCloudAvailable = true
            print("iCloudBackupManager: iCloud is available")
        } else {
            iCloudAvailable = false
            print("iCloudBackupManager: iCloud is not available")
        }
    }
    
    /// Create a backup of the current data
    func createBackup(projects: [Project], templates: [Template], triggers: [Trigger], appSettings: AppSettings) async throws {
        guard iCloudAvailable else {
            throw iCloudBackupError.iCloudNotAvailable
        }
        
        isCreatingBackup = true
        defer { isCreatingBackup = false }
        
        print("iCloudBackupManager: Starting backup creation...")
        
        // Create backup data structure
        let backupData = createBackupData(
            projects: projects,
            templates: templates,
            triggers: triggers,
            appSettings: appSettings
        )
        
        // Get backups folder
        let backupsFolder = try await getOrCreateBackupsFolder()
        
        // Generate filename with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "DeadlineCalendar_\(timestamp).\(fileExtension)"
        let fileURL = backupsFolder.appendingPathComponent(filename)
        
        // Create and save document
        let document = DeadlineCalendarBackupDocument(fileURL: fileURL)
        document.backupData = backupData
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            document.save(to: fileURL, for: .forCreating) { success in
                if success {
                    print("iCloudBackupManager: Backup created successfully at \(fileURL.path)")
                    self.lastBackupDate = Date()
                    self.saveLastBackupDate()
                    continuation.resume()
                } else {
                    continuation.resume(throwing: iCloudBackupError.backupCreationFailed("Failed to save document"))
                }
            }
        }
        
        // Wait a moment for iCloud to sync
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Reload backups list
        await loadAvailableBackups()
        
        // Schedule automatic backup
        scheduleAutomaticBackup()
    }
    
    /// Load available backups from iCloud
    func loadAvailableBackups() async {
        guard iCloudAvailable else {
            availableBackups = []
            return
        }
        
        isLoadingBackups = true
        defer { isLoadingBackups = false }
        
        do {
            let backupsFolder = try await getOrCreateBackupsFolder()
            let fileManager = FileManager.default
            
            // Start metadata query for iCloud files
            let query = NSMetadataQuery()
            query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
            query.predicate = NSPredicate(format: "%K LIKE '*.deadlinebackup'", NSMetadataItemFSNameKey)
            
            // Get all backup files using traditional file manager approach
            let contents = try fileManager.contentsOfDirectory(
                at: backupsFolder,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey, .ubiquitousItemDownloadingStatusKey],
                options: [.skipsHiddenFiles]
            )
            
            print("iCloudBackupManager: Found \(contents.count) items in backups folder")
            
            // Filter for backup files and create documents
            var backupDocuments: [DeadlineCalendarBackupDocument] = []
            
            for url in contents where url.pathExtension == fileExtension {
                print("iCloudBackupManager: Processing backup file: \(url.lastPathComponent)")
                
                // Check if file needs to be downloaded from iCloud
                do {
                    let resourceValues = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                    
                    if let status = resourceValues.ubiquitousItemDownloadingStatus {
                        print("iCloudBackupManager: File download status: \(status.rawValue)")
                        
                        if status == .notDownloaded {
                            print("iCloudBackupManager: Starting download for: \(url.lastPathComponent)")
                            try fileManager.startDownloadingUbiquitousItem(at: url)
                        }
                    }
                } catch {
                    print("iCloudBackupManager: Could not check download status: \(error)")
                }
                
                let document = DeadlineCalendarBackupDocument(fileURL: url)
                backupDocuments.append(document)
            }
            
            // Sort by filename (which contains timestamp) in descending order
            backupDocuments.sort { doc1, doc2 in
                doc1.fileURL.lastPathComponent > doc2.fileURL.lastPathComponent
            }
            
            availableBackups = backupDocuments
            print("iCloudBackupManager: Loaded \(backupDocuments.count) backup documents")
            
        } catch {
            print("iCloudBackupManager: Error loading backups: \(error)")
            availableBackups = []
        }
    }
    
    /// Restore from a backup
    func restoreFromBackup(_ document: DeadlineCalendarBackupDocument, to viewModel: DeadlineViewModel) async throws {
        print("iCloudBackupManager: Starting restore from \(document.fileURL.lastPathComponent)...")
        
        // Open the document
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            document.open { success in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: iCloudBackupError.backupRestorationFailed("Failed to open backup document"))
                }
            }
        }
        
        guard let backupData = document.backupData else {
            throw iCloudBackupError.backupRestorationFailed("No data found in backup")
        }
        
        // Convert backup data to app models
        let restoredProjects = backupData.projects.map { convertBackupProject($0) }
        let restoredTemplates = backupData.templates.map { convertBackupTemplate($0) }
        let restoredTriggers = backupData.triggers.map { convertBackupTrigger($0) }
        
        // Update view model
        viewModel.projects = restoredProjects
        viewModel.templates = restoredTemplates
        viewModel.triggers = restoredTriggers
        viewModel.appSettings = backupData.appSettings
        
        // Save to UserDefaults
        viewModel.saveProjects()
        viewModel.saveTemplates()
        viewModel.saveTriggers()
        viewModel.saveAppSettings()
        
        print("iCloudBackupManager: Restore completed successfully")
        print("  - Projects: \(restoredProjects.count)")
        print("  - Templates: \(restoredTemplates.count)")
        print("  - Triggers: \(restoredTriggers.count)")
    }
    
    /// Delete a backup
    func deleteBackup(_ document: DeadlineCalendarBackupDocument) async throws {
        let fileManager = FileManager.default
        
        do {
            try fileManager.removeItem(at: document.fileURL)
            print("iCloudBackupManager: Deleted backup at \(document.fileURL.path)")
            
            // Reload backups list
            await loadAvailableBackups()
        } catch {
            throw iCloudBackupError.backupRestorationFailed("Failed to delete backup: \(error.localizedDescription)")
        }
    }
    
    /// Schedule automatic backup if needed
    func scheduleAutomaticBackup() {
        guard let lastBackup = lastBackupDate else {
            print("iCloudBackupManager: No previous backup found, skipping automatic backup")
            return
        }
        
        let hoursSinceLastBackup = Date().timeIntervalSince(lastBackup) / 3600
        if hoursSinceLastBackup >= 24 {
            print("iCloudBackupManager: Last backup was \(Int(hoursSinceLastBackup)) hours ago, automatic backup needed")
            // Automatic backup would be triggered here if implemented
        }
    }
    
    // MARK: - Private Methods
    
    private func getOrCreateBackupsFolder() async throws -> URL {
        // Use nil to get the default container, or specify the exact container ID if needed
        guard let iCloudContainer = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            print("iCloudBackupManager: Failed to get iCloud container URL")
            throw iCloudBackupError.iCloudNotAvailable
        }
        
        print("iCloudBackupManager: iCloud container URL: \(iCloudContainer.path)")
        
        let documentsURL = iCloudContainer.appendingPathComponent("Documents")
        let backupsURL = documentsURL.appendingPathComponent(backupsFolderName)
        
        // Create folders if they don't exist
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: documentsURL.path) {
            print("iCloudBackupManager: Creating Documents directory")
            try fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        if !fileManager.fileExists(atPath: backupsURL.path) {
            print("iCloudBackupManager: Creating backups directory")
            try fileManager.createDirectory(at: backupsURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        print("iCloudBackupManager: Backups folder URL: \(backupsURL.path)")
        return backupsURL
    }
    
    private func createBackupData(projects: [Project], templates: [Template], triggers: [Trigger], appSettings: AppSettings) -> DeadlineCalendarBackupData {
        // Convert app models to backup models
        let backupProjects = projects.map { project in
            BackupProject(
                id: project.id,
                title: project.title,
                finalDeadlineDate: project.finalDeadlineDate,
                subDeadlines: project.subDeadlines.map { subDeadline in
                    BackupSubDeadline(
                        id: subDeadline.id,
                        title: subDeadline.title,
                        date: subDeadline.date,
                        isCompleted: subDeadline.isCompleted,
                        subtasks: subDeadline.subtasks.map { subtask in
                            BackupSubtask(
                                id: subtask.id,
                                title: subtask.title,
                                isCompleted: subtask.isCompleted
                            )
                        },
                        templateSubDeadlineID: subDeadline.templateSubDeadlineID,
                        triggerID: subDeadline.triggerID
                    )
                },
                triggers: [], // Triggers are stored separately at the top level
                templateID: project.templateID,
                templateName: project.templateName
            )
        }
        
        let backupTemplates = templates.map { template in
            BackupTemplate(
                id: template.id,
                name: template.name,
                subDeadlines: template.subDeadlines.map { subDeadline in
                    BackupTemplateSubDeadline(
                        id: subDeadline.id,
                        title: subDeadline.title,
                        offset: subDeadline.offset,
                        templateTriggerID: subDeadline.templateTriggerID
                    )
                },
                templateTriggers: template.templateTriggers.map { trigger in
                    BackupTemplateTrigger(
                        id: trigger.id,
                        name: trigger.name,
                        offset: trigger.offset
                    )
                }
            )
        }
        
        let backupTriggers = triggers.map { trigger in
            BackupTrigger(
                id: trigger.id,
                name: trigger.name,
                isActive: trigger.isActive,
                projectID: trigger.projectID,
                activationDate: trigger.activationDate,
                originatingTemplateTriggerID: trigger.originatingTemplateTriggerID,
                date: trigger.date
            )
        }
        
        return DeadlineCalendarBackupData(
            version: "1.0",
            createdDate: Date(),
            deviceName: UIDevice.current.name,
            projects: backupProjects,
            templates: backupTemplates,
            triggers: backupTriggers,
            appSettings: appSettings
        )
    }
    
    // Convert backup models back to app models
    private func convertBackupProject(_ backup: BackupProject) -> Project {
        Project(
            id: backup.id,
            title: backup.title,
            finalDeadlineDate: backup.finalDeadlineDate,
            subDeadlines: backup.subDeadlines.map { convertBackupSubDeadline($0) },
            triggers: [], // Triggers are restored separately
            templateID: backup.templateID,
            templateName: backup.templateName
        )
    }
    
    private func convertBackupSubDeadline(_ backup: BackupSubDeadline) -> SubDeadline {
        SubDeadline(
            id: backup.id,
            title: backup.title,
            date: backup.date,
            isCompleted: backup.isCompleted,
            subtasks: backup.subtasks.map { convertBackupSubtask($0) },
            templateSubDeadlineID: backup.templateSubDeadlineID,
            triggerID: backup.triggerID
        )
    }
    
    private func convertBackupSubtask(_ backup: BackupSubtask) -> Subtask {
        Subtask(
            id: backup.id,
            title: backup.title,
            isCompleted: backup.isCompleted
        )
    }
    
    private func convertBackupTemplate(_ backup: BackupTemplate) -> Template {
        Template(
            id: backup.id,
            name: backup.name,
            subDeadlines: backup.subDeadlines.map { convertBackupTemplateSubDeadline($0) },
            templateTriggers: backup.templateTriggers.map { convertBackupTemplateTrigger($0) }
        )
    }
    
    private func convertBackupTemplateSubDeadline(_ backup: BackupTemplateSubDeadline) -> TemplateSubDeadline {
        TemplateSubDeadline(
            id: backup.id,
            title: backup.title,
            offset: backup.offset,
            templateTriggerID: backup.templateTriggerID
        )
    }
    
    private func convertBackupTemplateTrigger(_ backup: BackupTemplateTrigger) -> TemplateTrigger {
        TemplateTrigger(
            id: backup.id,
            name: backup.name,
            offset: backup.offset
        )
    }
    
    private func convertBackupTrigger(_ backup: BackupTrigger) -> Trigger {
        Trigger(
            id: backup.id,
            name: backup.name,
            projectID: backup.projectID,
            date: backup.date,
            isActive: backup.isActive,
            activationDate: backup.activationDate,
            originatingTemplateTriggerID: backup.originatingTemplateTriggerID
        )
    }
    
    private func loadLastBackupDate() {
        if let date = UserDefaults.standard.object(forKey: lastBackupDateKey) as? Date {
            lastBackupDate = date
        }
    }
    
    private func saveLastBackupDate() {
        if let date = lastBackupDate {
            UserDefaults.standard.set(date, forKey: lastBackupDateKey)
        }
    }
}