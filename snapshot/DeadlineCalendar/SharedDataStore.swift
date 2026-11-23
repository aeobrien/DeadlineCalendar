// Deadline Calendar/DeadlineCalendar/SharedDataStore.swift
// Provides read/write access to the shared iCloud JSON file for cross-platform sync.

import Foundation
import Combine
import Darwin

// MARK: - Shared Data Container

/// The canonical data format stored in iCloud Drive at
/// `iCloud~AOTondra~Deadline-Calendar/Documents/DeadlineCalendar.json`.
/// Both the iOS app and the macOS CLI read/write this file.
struct SharedData: Codable, Equatable {
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
        if let explicitURL { return explicitURL }
        guard let containerURL = containerProvider() else {
            print("SharedDataStore: iCloud container not available")
            return nil
        }
        let documentsURL = containerURL.appendingPathComponent("Documents")

        return documentsURL.appendingPathComponent(sharedFileName)
    }

    // MARK: - Init

    private let explicitURL: URL?
    private var baseline: Data?
    private var loadedURL: URL?
    private let containerProvider: () -> URL?
    private var hasLoaded = false
    private let availabilityCheck: ((URL) throws -> Void)?

    init(fileURL: URL? = nil, availabilityCheck: ((URL) throws -> Void)? = nil,
         containerProvider: @escaping () -> URL? = { FileManager.default.url(forUbiquityContainerIdentifier: nil) }) {
        self.explicitURL = fileURL
        self.containerProvider = containerProvider
        self.availabilityCheck = availabilityCheck
        super.init()
    }

    // MARK: - Monitoring

    /// Begin watching for iCloud-driven file changes via `NSMetadataQuery`.
    func startMonitoring() {
        guard explicitURL == nil, metadataQuery == nil else { return }

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

    // A failed load invalidates write permission. Only a successful read of absence
    // permits first-launch initialization; unavailable or corrupt is never absence.
    func loadSnapshot() throws -> SharedData? {
        hasLoaded = false
        guard let url = sharedFileURL else { throw SnapshotError.unavailable }
        let bytes = try SnapshotFile(url: url, availabilityCheck: availabilityCheck).read()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try bytes.map { try decoder.decode(SharedData.self, from: $0) }
        baseline = bytes
        loadedURL = url
        hasLoaded = true
        return document
    }

    @discardableResult
    func saveSnapshot(projects: [Project], templates: [Template], triggers: [Trigger], appSettings: AppSettings) throws -> SharedData {
        guard hasLoaded else { throw SnapshotError.unavailable }
        guard let url = loadedURL else { throw SnapshotError.unavailable }
        if baseline == nil && explicitURL == nil { try prepareInitialDocumentsDirectory(for: url) }
        let document = SharedData(projects: projects, templates: templates, triggers: triggers,
                                  appSettings: appSettings, lastModified: Date(), lastModifiedBy: "app")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let bytes = try encoder.encode(document)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let canonical = try decoder.decode(SharedData.self, from: bytes)
        let savedBytes = try SnapshotFile(url: url, availabilityCheck: availabilityCheck).update(expected: .bytes(baseline)) { current in
            if let current {
                let previous = try decoder.decode(SharedData.self, from: current)
                if previous.projects == canonical.projects && previous.templates == canonical.templates &&
                    previous.triggers == canonical.triggers && previous.appSettings == canonical.appSettings {
                    return current
                }
            }
            return bytes
        }
        guard let savedBytes else { throw SnapshotError.coordination }
        baseline = savedBytes
        lastKnownModificationDate = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
        return try decoder.decode(SharedData.self, from: savedBytes)
    }
    /// Only the normal default store may create its Documents directory, and only
    /// after a successful missing-file read. Selected-file paths are never created.
    private func prepareInitialDocumentsDirectory(for url: URL) throws {
        let documents = url.deletingLastPathComponent()
        let container = documents.deletingLastPathComponent()
        func checkDirectory(_ directory: URL, missingAllowed: Bool) throws -> Bool {
            var info = stat()
            guard lstat(directory.path, &info) == 0 else {
                if errno == ENOENT && missingAllowed { return false }
                throw SnapshotError.unavailable
            }
            guard (info.st_mode & S_IFMT) == S_IFDIR, (info.st_flags & UInt32(SF_DATALESS)) == 0 else {
                throw SnapshotError.unavailable
            }
            let values = try directory.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey])
            if values.isUbiquitousItem == true && values.ubiquitousItemDownloadingStatus == .notDownloaded {
                throw SnapshotError.unavailable
            }
            return true
        }
        _ = try checkDirectory(container, missingAllowed: false)
        if try checkDirectory(documents, missingAllowed: true) { return }
        var error: NSError?
        var result: Result<Void, Error>?
        NSFileCoordinator().coordinate(writingItemAt: documents, options: .forMerging, error: &error) { path in
            result = Result {
                _ = try checkDirectory(container, missingAllowed: false)
                if try !checkDirectory(path, missingAllowed: true) {
                    try FileManager.default.createDirectory(at: path, withIntermediateDirectories: false)
                }
            }
        }
        if let error { throw error }
        guard let result else { throw SnapshotError.coordination }
        try result.get()
    }
}
