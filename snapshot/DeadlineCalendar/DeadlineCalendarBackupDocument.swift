// Deadline Calendar/DeadlineCalendar/DeadlineCalendarBackupDocument.swift

import UIKit

/// UIDocument subclass for managing Deadline Calendar backup files in iCloud
class DeadlineCalendarBackupDocument: UIDocument, Identifiable {
    
    var backupData: DeadlineCalendarBackupData?
    
    override func contents(forType typeName: String) throws -> Any {
        guard let backupData = backupData else {
            print("DeadlineCalendarBackupDocument: No backup data to save")
            return Data()
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(backupData)
            print("DeadlineCalendarBackupDocument: Encoded backup data (\(data.count) bytes)")
            return data
        } catch {
            print("DeadlineCalendarBackupDocument: Failed to encode backup data: \(error)")
            throw error
        }
    }
    
    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        guard let data = contents as? Data else {
            print("DeadlineCalendarBackupDocument: Invalid contents type")
            return
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            backupData = try decoder.decode(DeadlineCalendarBackupData.self, from: data)
            print("DeadlineCalendarBackupDocument: Successfully decoded backup data")
            print("  - Version: \(backupData?.version ?? "unknown")")
            print("  - Created: \(backupData?.createdDate ?? Date())")
            print("  - Device: \(backupData?.deviceName ?? "unknown")")
            print("  - Projects: \(backupData?.projects.count ?? 0)")
            print("  - Templates: \(backupData?.templates.count ?? 0)")
            print("  - Triggers: \(backupData?.triggers.count ?? 0)")
        } catch {
            print("DeadlineCalendarBackupDocument: Failed to decode backup data: \(error)")
            throw error
        }
    }
    
    // MARK: - Metadata Helpers
    
    /// Extract metadata without fully loading the document
    func getMetadata() async throws -> BackupMetadata {
        // Extract basic info from the filename first
        let filename = fileURL.lastPathComponent
        let deviceName = UIDevice.current.name // Default device name
        
        // Try to extract date from filename
        // Filename format: DeadlineCalendar_yyyy-MM-dd_HH-mm-ss.deadlinebackup
        var creationDate = Date()
        if let dateString = extractDateFromFilename(filename) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            if let date = formatter.date(from: dateString) {
                creationDate = date
            }
        }
        
        // Try to get file size if possible
        var fileSize: Int64 = 0
        if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path) {
            fileSize = attributes[.size] as? Int64 ?? 0
        }
        
        return BackupMetadata(
            filename: filename,
            creationDate: creationDate,
            deviceName: deviceName,
            fileSize: fileSize,
            fileURL: fileURL
        )
    }
    
    private func extractDateFromFilename(_ filename: String) -> String? {
        // Extract date from filename like "DeadlineCalendar_2025-07-07_14-37-06.deadlinebackup"
        let components = filename.components(separatedBy: "_")
        if components.count >= 3 {
            // Get the date and time parts
            let datePart = components[1]
            let timePart = components[2].replacingOccurrences(of: ".deadlinebackup", with: "")
            return "\(datePart)_\(timePart)"
        }
        return nil
    }
    
    private func parseDeviceName(from filename: String) -> String? {
        // Filename format: DeadlineCalendar_yyyy-MM-dd_HH-mm-ss.deadlinebackup
        // In the future, we might include device name in the filename
        return nil
    }
}

// MARK: - Backup Metadata

struct BackupMetadata {
    let filename: String
    let creationDate: Date
    let deviceName: String
    let fileSize: Int64
    let fileURL: URL
    
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    var formattedCreationDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: creationDate, relativeTo: Date())
    }
}
