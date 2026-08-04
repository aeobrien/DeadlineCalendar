// Deadline Calendar/DeadlineCalendar/SharedDataStore.swift
// Provides read/write access to the shared iCloud JSON file for cross-platform sync.

import Foundation

// MARK: - Shared Data Container

/// The canonical data format stored in iCloud Drive at
/// `iCloud~AOTondra~Deadline-Calendar/Documents/DeadlineCalendar.json`.
/// Both the iOS app and the macOS CLI read/write this file.
struct SharedData: Codable {
    var projects: [Project]
    var templates: [Template]
    var triggers: [Trigger]
    var appSettings: AppSettings
    var lastModified: Date
    var lastModifiedBy: String  // "app" or "cli"
}

// MARK: - Shared Data Store

/// Manages reading and writing the shared iCloud JSON file.
/// Uses `NSFileCoordinator` for safe concurrent access and
/// `NSMetadataQuery` to detect iCloud-driven changes.
class SharedDataStore: NSObject, ObservableObject {
    static let shared = SharedDataStore()

    /// Posted when external changes are detected in the shared file.
    static let didDetectExternalChange = Notification.Name("SharedDataStoreDidDetectExternalChange")

    /// The filename within the iCloud Documents folder.
    private let sharedFileName = "DeadlineCalendar.json"

    /// Metadata query that watches for iCloud file changes.
    private var metadataQuery: NSMetadataQuery?

    /// Tracks the last-known modification date so we can skip our own writes.
    private var lastKnownModificationDate: Date?

    // MARK: - File URL

    /// Returns the URL for the shared JSON file inside iCloud Drive,
    /// or `nil` if iCloud is not available.
    var sharedFileURL: URL? {
        guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            print("SharedDataStore: iCloud container not available")
            return nil
        }
        let documentsURL = containerURL.appendingPathComponent("Documents")

        // Ensure the Documents directory exists.
        if !FileManager.default.fileExists(atPath: documentsURL.path) {
            do {
                try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
                print("SharedDataStore: Created iCloud Documents directory")
            } catch {
                print("SharedDataStore: Failed to create Documents directory: \(error)")
                return nil
            }
        }

        return documentsURL.appendingPathComponent(sharedFileName)
    }

    // MARK: - Init

    private override init() {
        super.init()
    }

    // MARK: - Monitoring

    /// Begin watching for iCloud-driven file changes via `NSMetadataQuery`.
    func startMonitoring() {
        guard metadataQuery == nil else { return }

        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K == %@", NSMetadataItemFSNameKey, sharedFileName)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(metadataQueryDidUpdate(_:)),
            name: .NSMetadataQueryDidUpdate,
            object: query
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(metadataQueryDidFinishGathering(_:)),
            name: .NSMetadataQueryDidFinishGathering,
            object: query
        )

        query.start()
        metadataQuery = query
        print("SharedDataStore: Started iCloud metadata monitoring")
    }

    /// Stop watching for changes.
    func stopMonitoring() {
        metadataQuery?.stop()
        metadataQuery = nil
        NotificationCenter.default.removeObserver(self)
        print("SharedDataStore: Stopped iCloud metadata monitoring")
    }

    @objc private func metadataQueryDidFinishGathering(_ notification: Notification) {
        metadataQuery?.disableUpdates()
        checkForExternalChanges()
        metadataQuery?.enableUpdates()
    }

    @objc private func metadataQueryDidUpdate(_ notification: Notification) {
        metadataQuery?.disableUpdates()
        checkForExternalChanges()
        metadataQuery?.enableUpdates()
    }

    private func checkForExternalChanges() {
        guard let fileURL = sharedFileURL else { return }

        // Check the file's modification date.
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let modDate = attrs[.modificationDate] as? Date else {
            return
        }

        // Skip if this is the same modification date we last wrote.
        if let lastKnown = lastKnownModificationDate, modDate <= lastKnown {
            return
        }

        lastKnownModificationDate = modDate
        print("SharedDataStore: External change detected (mod date: \(modDate))")

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: SharedDataStore.didDetectExternalChange, object: nil)
        }
    }

    // MARK: - Read

    /// Load data from the shared JSON file using coordinated file access.
    /// Returns `nil` if the file doesn't exist or can't be read.
    func load() -> SharedData? {
        guard let fileURL = sharedFileURL else { return nil }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("SharedDataStore: Shared file does not exist yet")
            return nil
        }

        var coordinatorError: NSError?
        var result: SharedData?

        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: fileURL, options: [], error: &coordinatorError) { readURL in
            do {
                let data = try Data(contentsOf: readURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                result = try decoder.decode(SharedData.self, from: data)
                print("SharedDataStore: Loaded shared data (lastModifiedBy: \(result?.lastModifiedBy ?? "unknown"))")
            } catch {
                print("SharedDataStore: Failed to read/decode shared file: \(error)")
            }
        }

        if let error = coordinatorError {
            print("SharedDataStore: File coordination error on read: \(error)")
        }

        return result
    }

    // MARK: - Write

    /// Write data to the shared JSON file using coordinated file access.
    /// Returns `true` on success.
    @discardableResult
    func save(projects: [Project], templates: [Template], triggers: [Trigger], appSettings: AppSettings) -> Bool {
        guard let fileURL = sharedFileURL else {
            print("SharedDataStore: Cannot save — iCloud not available")
            return false
        }

        let sharedData = SharedData(
            projects: projects,
            templates: templates,
            triggers: triggers,
            appSettings: appSettings,
            lastModified: Date(),
            lastModifiedBy: "app"
        )

        var coordinatorError: NSError?
        var success = false

        let coordinator = NSFileCoordinator()
        coordinator.coordinate(writingItemAt: fileURL, options: .forReplacing, error: &coordinatorError) { writeURL in
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                let jsonData = try encoder.encode(sharedData)
                try jsonData.write(to: writeURL, options: .atomic)

                // Record the modification date so we can ignore our own write
                // in the metadata query callback.
                if let attrs = try? FileManager.default.attributesOfItem(atPath: writeURL.path),
                   let modDate = attrs[.modificationDate] as? Date {
                    self.lastKnownModificationDate = modDate
                }

                success = true
                print("SharedDataStore: Saved shared data to iCloud (\(jsonData.count) bytes)")
            } catch {
                print("SharedDataStore: Failed to write shared file: \(error)")
            }
        }

        if let error = coordinatorError {
            print("SharedDataStore: File coordination error on write: \(error)")
        }

        return success
    }

    // MARK: - Migration

    /// Check whether the shared file exists. Used for first-launch migration.
    var sharedFileExists: Bool {
        guard let fileURL = sharedFileURL else { return false }
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
}
