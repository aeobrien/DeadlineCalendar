// Shared by the macOS CLI and iOS app. No data-model or UI dependencies.
import Foundation
import Darwin

enum SnapshotExpectation {
    case latest
    case bytes(Data?)
}

enum SnapshotError: Error, LocalizedError {
    case unavailable, unsafePath, conflict, busy, missing, coordination
    var errorDescription: String? {
        switch self {
        case .unavailable: return "Deadline data is not available locally. No data was changed."
        case .unsafePath: return "The selected deadline path is not a regular file. No data was changed."
        case .conflict: return "Deadline data changed since it was loaded. Reload before applying this edit."
        case .busy: return "Deadline data is busy. Read its current state before trying again."
        case .missing: return "The selected deadline file does not exist. No empty data was created."
        case .coordination: return "Deadline file coordination did not complete. No success was recorded."
        }
    }
}

struct SnapshotFile {
    let url: URL
    private let availabilityCheck: ((URL) throws -> Void)?
    init(url: URL, availabilityCheck: ((URL) throws -> Void)? = nil) {
        // Canonical parent gives aliases the same lock, while retaining the leaf
        // so a redirected data file is rejected instead of followed.
        self.url = url.deletingLastPathComponent().resolvingSymlinksInPath()
            .appendingPathComponent(url.lastPathComponent)
        self.availabilityCheck = availabilityCheck
    }

    private func checkAvailability(_ path: URL) throws {
        try availabilityCheck?(path)
        var info = stat()
        guard lstat(path.path, &info) == 0 else {
            if errno == ENOENT { return }
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        guard (info.st_mode & S_IFMT) == S_IFREG else { throw SnapshotError.unsafePath }
        // SF_DATALESS is metadata: refuse before any content read/download.
        guard (info.st_flags & UInt32(SF_DATALESS)) == 0 else { throw SnapshotError.unavailable }
        let values = try path.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey])
        if values.isUbiquitousItem == true && values.ubiquitousItemDownloadingStatus == .notDownloaded {
            throw SnapshotError.unavailable
        }
        if !(NSFileVersion.unresolvedConflictVersionsOfItem(at: path) ?? []).isEmpty {
            throw SnapshotError.conflict
        }
    }

    private func readUncoordinated(_ path: URL) throws -> Data? {
        try checkAvailability(path)
        let fd = open(path.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
        guard fd >= 0 else {
            if errno == ENOENT { return nil }
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        var info = stat()
        guard fstat(fd, &info) == 0 else { throw POSIXError(.EIO) }
        guard (info.st_mode & S_IFMT) == S_IFREG else { throw SnapshotError.unsafePath }
        guard (info.st_flags & UInt32(SF_DATALESS)) == 0 else { throw SnapshotError.unavailable }
        return try handle.readToEnd() ?? Data()
    }

    func read() throws -> Data? {
        try checkAvailability(url)
        var result: Result<Data?, Error>?
        var error: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &error) { path in
            result = Result { try readUncoordinated(path) }
        }
        if let error { throw error }
        guard let result else { throw SnapshotError.coordination }
        return try result.get()
    }

    @discardableResult
    func update(expected: SnapshotExpectation = .latest, _ transform: (Data?) throws -> Data?) throws -> Data? {
        try checkAvailability(url)
        let lockURL = url.appendingPathExtension("lock")
        let fd = open(lockURL.path, O_CREAT | O_RDWR | O_NOFOLLOW, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        defer { close(fd) }
        var info = stat()
        guard fstat(fd, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG, info.st_nlink == 1 else {
            throw SnapshotError.unsafePath
        }
        let deadline = ProcessInfo.processInfo.systemUptime + 5
        while flock(fd, LOCK_EX | LOCK_NB) != 0 {
            guard errno == EWOULDBLOCK || errno == EAGAIN else {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
            guard ProcessInfo.processInfo.systemUptime < deadline else { throw SnapshotError.busy }
            Thread.sleep(forTimeInterval: 0.01)
        }
        defer { flock(fd, LOCK_UN) }
        // Keep the stable sibling lock file; deleting it would split contenders.
        var result: Result<Data?, Error>?
        var error: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &error) { path in
            result = Result {
                let current = try readUncoordinated(path)
                if case .bytes(let original) = expected, current != original { throw SnapshotError.conflict }
                let updated = try transform(current)
                guard updated != current else { return current }
                guard let updated else { throw SnapshotError.missing } // never delete via storage primitive
                try checkAvailability(path)
                try updated.write(to: path, options: .atomic)
                return updated
            }
        }
        if let error { throw error }
        guard let result else { throw SnapshotError.coordination }
        return try result.get()
    }
}
