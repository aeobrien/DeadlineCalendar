// DataStore.swift
// Reads and writes DeadlineCalendar data via iCloud backup files.

import Foundation

/// Wrapper matching the iCloud backup file format (DeadlineCalendarBackupData).
/// The backup stores version/date/device metadata alongside the actual data.
struct BackupFileData: Codable {
    let version: String
    let createdDate: Date
    let deviceName: String
    var projects: [Project]
    var templates: [Template]
    var triggers: [Trigger]
    var appSettings: AppSettings
}

/// The iCloud Drive path where DeadlineCalendar stores its backups.
let iCloudBackupsPath = NSHomeDirectory() + "/Library/Mobile Documents/iCloud~AOTondra~Deadline-Calendar/Documents/DeadlineCalendarBackups"

struct DataStore {
    let backupsDirectory: URL

    init() throws {
        let url = URL(fileURLWithPath: iCloudBackupsPath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw DataStoreError.iCloudNotAvailable(
                """
                Could not find iCloud backups directory at:
                  \(iCloudBackupsPath)

                Ensure:
                  1. iCloud Drive is enabled and syncing.
                  2. DeadlineCalendar has created at least one backup.
                """
            )
        }
        self.backupsDirectory = url
    }

    // MARK: - Read

    /// Find the most recent backup file by filename (which contains a timestamp).
    func latestBackupURL() throws -> URL {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(
            at: backupsDirectory,
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
    func loadLatest() throws -> BackupFileData {
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

    /// Load projects with their triggers resolved from the top-level triggers array.
    /// In the backup format, project.triggers is often empty — triggers live at the top level
    /// with a projectID field linking them back.
    func loadProjectsResolved() throws -> (projects: [Project], templates: [Template], triggers: [Trigger], appSettings: AppSettings) {
        let backup = try loadLatest()

        // Resolve triggers into their projects
        let triggersByProject = Dictionary(grouping: backup.triggers, by: { $0.projectID })
        let resolvedProjects = backup.projects.map { project -> Project in
            var p = project
            if p.triggers.isEmpty, let projectTriggers = triggersByProject[p.id] {
                p.triggers = projectTriggers
            }
            return p
        }

        return (resolvedProjects, backup.templates, backup.triggers, backup.appSettings)
    }

    // MARK: - Write

    /// Save modified data as a new backup file. The app can then restore from it.
    /// Returns the URL of the created file.
    @discardableResult
    func saveNewBackup(_ data: BackupFileData) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let jsonData = try encoder.encode(data)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let filename = "DeadlineCalendar_\(timestamp).deadlinebackup"
        let fileURL = backupsDirectory.appendingPathComponent(filename)

        try jsonData.write(to: fileURL)
        return fileURL
    }

    /// Load the latest backup, apply a mutation, and save as a new backup.
    /// Returns the URL of the created file.
    @discardableResult
    func mutate(_ mutation: (inout BackupFileData) -> Void) throws -> URL {
        var data = try loadLatest()
        mutation(&data)
        // Update metadata
        let updated = BackupFileData(
            version: data.version,
            createdDate: Date(),
            deviceName: "Claude Code CLI",
            projects: data.projects,
            templates: data.templates,
            triggers: data.triggers,
            appSettings: data.appSettings
        )
        return try saveNewBackup(updated)
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
