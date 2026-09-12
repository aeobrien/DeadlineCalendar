// DataStore.swift
// Reads and writes DeadlineCalendar data via the shared iCloud JSON file,
// with fallback to legacy backup files.

import Foundation

// MARK: - Shared Data Container (matches the iOS app's SharedData struct)

struct SharedData: Codable {
    var projects: [Project]
    var templates: [Template]
    var triggers: [Trigger]
    var appSettings: AppSettings
    var lastModified: Date
    var lastModifiedBy: String  // "app" or "cli"
}

// MARK: - Legacy Backup File Format

/// Wrapper matching the iCloud backup file format (DeadlineCalendarBackupData).
/// Used as a fallback when the shared JSON file doesn't exist yet.
struct BackupFileData: Codable {
    let version: String
    let createdDate: Date
    let deviceName: String
    var projects: [Project]
    var templates: [Template]
    var triggers: [Trigger]
    var appSettings: AppSettings
}

// MARK: - Paths

/// The iCloud Drive path where the shared JSON file lives.
let iCloudDocumentsPath = NSHomeDirectory() + "/Library/Mobile Documents/iCloud~AOTondra~Deadline-Calendar/Documents"

/// The shared JSON file path.
let sharedFilePath = iCloudDocumentsPath + "/DeadlineCalendar.json"

/// The legacy backups directory.
let iCloudBackupsPath = iCloudDocumentsPath + "/DeadlineCalendarBackups"

// MARK: - DataStore

struct DataStore {
    let sharedFileURL: URL
    let backupsDirectory: URL?

    init() throws {
        let sharedURL = URL(fileURLWithPath: sharedFilePath)
        self.sharedFileURL = sharedURL

        // Backups directory is optional — only needed for fallback.
        let backupsURL = URL(fileURLWithPath: iCloudBackupsPath)
        if FileManager.default.fileExists(atPath: backupsURL.path) {
            self.backupsDirectory = backupsURL
        } else {
            self.backupsDirectory = nil
        }

        // Verify iCloud Documents directory exists.
        let docsURL = URL(fileURLWithPath: iCloudDocumentsPath)
        guard FileManager.default.fileExists(atPath: docsURL.path) else {
            throw DataStoreError.iCloudNotAvailable(
                """
                Could not find iCloud Documents directory at:
                  \(iCloudDocumentsPath)

                Ensure:
                  1. iCloud Drive is enabled and syncing.
                  2. DeadlineCalendar has been launched at least once.
                """
            )
        }
    }

    // MARK: - Read (Shared File — Primary)

    /// Load data from the shared JSON file.
    /// Returns `nil` if the file doesn't exist.
    func loadSharedFile() throws -> SharedData? {
        guard FileManager.default.fileExists(atPath: sharedFileURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: sharedFileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SharedData.self, from: data)
    }

    // MARK: - Read (Legacy Backup — Fallback)

    /// Find the most recent backup file by filename (which contains a timestamp).
    func latestBackupURL() throws -> URL {
        guard let backupsDir = backupsDirectory else {
            throw DataStoreError.noBackupsFound
        }
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(
            at: backupsDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        let backups = contents
            .filter { $0.pathExtension == "deadlinebackup" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }

        guard let latest = backups.first else {
            throw DataStoreError.noBackupsFound
        }
        return latest
    }

    /// Load the full dataset from the most recent backup.
    func loadLatestBackup() throws -> BackupFileData {
        let url = try latestBackupURL()
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(BackupFileData.self, from: data)
        } catch {
            throw DataStoreError.decodingFailed(file: url.lastPathComponent, underlying: error)
        }
    }

    // MARK: - Unified Load

    /// Load data from the shared file first, falling back to the latest backup.
    /// Returns resolved projects (triggers merged into their projects).
    func loadProjectsResolved() throws -> (projects: [Project], templates: [Template], triggers: [Trigger], appSettings: AppSettings) {
        let projects: [Project]
        let templates: [Template]
        let triggers: [Trigger]
        let appSettings: AppSettings

        if let shared = try loadSharedFile() {
            print("DataStore: Loaded from shared iCloud file (lastModifiedBy: \(shared.lastModifiedBy))")
            projects = shared.projects
            templates = shared.templates
            triggers = shared.triggers
            appSettings = shared.appSettings
        } else {
            print("DataStore: Shared file not found, falling back to latest backup")
            let backup = try loadLatestBackup()
            projects = backup.projects
            templates = backup.templates
            triggers = backup.triggers
            appSettings = backup.appSettings
        }

        // Resolve triggers into their projects
        let triggersByProject = Dictionary(grouping: triggers, by: { $0.projectID })
        let resolvedProjects = projects.map { project -> Project in
            var p = project
            if p.triggers.isEmpty, let projectTriggers = triggersByProject[p.id] {
                p.triggers = projectTriggers
            }
            return p
        }

        return (resolvedProjects, templates, triggers, appSettings)
    }

    // MARK: - Write (Shared File)

    /// Save data to the shared JSON file.
    /// Sets `lastModifiedBy: "cli"`.
    @discardableResult
    func save(projects: [Project], templates: [Template], triggers: [Trigger], appSettings: AppSettings) throws -> URL {
        let sharedData = SharedData(
            projects: projects,
            templates: templates,
            triggers: triggers,
            appSettings: appSettings,
            lastModified: Date(),
            lastModifiedBy: "cli"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let jsonData = try encoder.encode(sharedData)
        try jsonData.write(to: sharedFileURL, options: .atomic)
        print("DataStore: Saved shared file (\(jsonData.count) bytes)")
        return sharedFileURL
    }

    /// Load the current data, apply a mutation, and save to the shared file.
    /// Returns the URL of the written file.
    @discardableResult
    func mutate(_ mutation: (inout [Project], inout [Template], inout [Trigger], inout AppSettings) -> Void) throws -> URL {
        let resolved = try loadProjectsResolved()
        var projects = resolved.projects
        var templates = resolved.templates
        var triggers = resolved.triggers
        var appSettings = resolved.appSettings

        mutation(&projects, &templates, &triggers, &appSettings)
        return try save(projects: projects, templates: templates, triggers: triggers, appSettings: appSettings)
    }
}

enum DataStoreError: Error, CustomStringConvertible {
    case iCloudNotAvailable(String)
    case noBackupsFound
    case decodingFailed(file: String, underlying: Error)

    var description: String {
        switch self {
        case .iCloudNotAvailable(let msg):
            return msg
        case .noBackupsFound:
            return "No .deadlinebackup files found in the iCloud backups directory."
        case .decodingFailed(let file, let err):
            return "Failed to decode '\(file)': \(err)"
        }
    }
}
