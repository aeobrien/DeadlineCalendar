// DataStore.swift
// Reads and writes DeadlineCalendar data via the shared iCloud JSON file,
// with fallback to legacy backup files.

import Foundation
import CryptoKit

// MARK: - Shared Data Container (matches the iOS app's SharedData struct)

struct SharedData: Codable, Equatable {
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

    let explicitFile: Bool

    init(dataFileURL: URL? = nil) throws {
        explicitFile = dataFileURL != nil
        sharedFileURL = dataFileURL ?? URL(fileURLWithPath: sharedFilePath)
        // Explicit stores never reach the default iCloud path or backup folder.
        backupsDirectory = dataFileURL == nil ? URL(fileURLWithPath: iCloudBackupsPath) : nil
    }

    private func decode(_ data: Data) throws -> SharedData {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SharedData.self, from: data)
    }

    func loadCurrent() throws -> SharedData {
        guard let data = try SnapshotFile(url: sharedFileURL).read() else { throw SnapshotError.missing }
        return try decode(data)
    }

    // MARK: - Read (Shared File — Primary)

    /// Load data from the shared JSON file.
    /// Returns `nil` if the file doesn't exist.
    func loadSharedFile() throws -> SharedData? {
        guard let data = try SnapshotFile(url: sharedFileURL).read() else { return nil }
        return try decode(data)
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
        guard let data = try SnapshotFile(url: url).read() else { throw SnapshotError.missing }
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

            projects = shared.projects
            templates = shared.templates
            triggers = shared.triggers
            appSettings = shared.appSettings
        } else {
            guard !explicitFile else { throw SnapshotError.missing }
            FileHandle.standardError.write(Data("Reading legacy backup; this is not the current shared file.\n".utf8))
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

    func readDocument() throws -> SharedData {
        if let shared = try loadSharedFile() { return shared }
        guard !explicitFile else { throw SnapshotError.missing }
        let backup = try loadLatestBackup()
        FileHandle.standardError.write(Data("Reading legacy backup; mutations require an available shared file.\n".utf8))
        return SharedData(projects: backup.projects, templates: backup.templates, triggers: backup.triggers,
                          appSettings: backup.appSettings, lastModified: backup.createdDate, lastModifiedBy: "legacy-backup")
    }

    func currentRevision() throws -> String {
        guard let bytes = try SnapshotFile(url: sharedFileURL).read() else { throw SnapshotError.missing }
        return Self.revision(bytes)
    }

    static func revision(_ bytes: Data) -> String { SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() }

    func currentWithRevision() throws -> (SharedData, String) {
        guard let bytes = try SnapshotFile(url: sharedFileURL).read() else { throw SnapshotError.missing }
        return (try decode(bytes), Self.revision(bytes))
    }

    // Whole read/validate/mutate/replace transaction. Never promotes a backup.
    @discardableResult
    func mutate(expectedRevision: String? = nil, _ mutation: (inout [Project], inout [Template], inout [Trigger], inout AppSettings) throws -> Void) throws -> URL {
        _ = try SnapshotFile(url: sharedFileURL).update { bytes in
            guard let bytes else { throw SnapshotError.missing }
            if let expectedRevision, Self.revision(bytes) != expectedRevision { throw SnapshotError.conflict }
            var current = try decode(bytes)
            let original = current
            try mutation(&current.projects, &current.templates, &current.triggers, &current.appSettings)
            guard current != original else { return bytes }
            current.lastModified = Date()
            current.lastModifiedBy = "cli"
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(current)
        }
        return sharedFileURL
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
