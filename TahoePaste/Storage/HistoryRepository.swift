import Foundation

/// Serializes every history mutation across processes (GUI app and the
/// bundled CLI) with an exclusive file lock, and offers a side-effect-free
/// read for concurrent readers.
///
/// Disk repair (dropping items whose PNG is gone, pruning orphaned images,
/// recomputing persisted tags) runs only inside locked writer transactions:
/// a plain reader must never delete an image the app captured a moment ago
/// but has not referenced from `history.json` yet.
final class HistoryRepository {
    enum RepositoryError: LocalizedError {
        case lockUnavailable
        case lockTimedOut

        var errorDescription: String? {
            switch self {
            case .lockUnavailable:
                return "Could not open the history lock file."
            case .lockTimedOut:
                return "Timed out waiting for another TahoePaste process to release the history lock."
            }
        }
    }

    struct AppendOutcome {
        let history: [ClipboardItem]
        let item: ClipboardItem
        let wasDeduplicated: Bool
    }

    struct DeleteOutcome {
        let history: [ClipboardItem]
        let removedItem: Bool
    }

    private let storageManager: StorageManager
    private let fileManager: FileManager
    private let lockFileURL: URL
    private let lockTimeout: TimeInterval

    init(
        storageManager: StorageManager,
        fileManager: FileManager = .default,
        lockTimeout: TimeInterval = 5
    ) {
        self.storageManager = storageManager
        self.fileManager = fileManager
        self.lockFileURL = storageManager.rootDirectoryURL.appendingPathComponent("history.lock")
        self.lockTimeout = lockTimeout
    }

    // MARK: - Reading

    /// Pure read: never writes JSON and never deletes files. Items whose
    /// image file is missing are filtered from the returned snapshot but the
    /// on-disk state is left untouched for the next writer transaction.
    func readSnapshot() throws -> [ClipboardItem] {
        dropItemsWithMissingImages(from: try storageManager.decodeHistory())
    }

    // MARK: - Mutations

    /// Stores a captured payload as the newest history item. When the newest
    /// existing item already carries the exact same text payload the append
    /// is skipped, so a pasteboard round-trip (CLI `add`/`copy` re-captured
    /// by the app's clipboard polling) cannot duplicate the entry.
    func append(payload: ClipboardPayload, historyLimit: Int?) throws -> AppendOutcome {
        try withExclusiveLock {
            let current = dropItemsWithMissingImages(from: try storageManager.decodeHistory())

            if let newest = current.first, Self.isDuplicate(payload: payload, of: newest) {
                return AppendOutcome(history: current, item: newest, wasDeduplicated: true)
            }

            let item = try storageManager.store(payload: payload)
            var updated = [item] + current

            if let historyLimit {
                updated = Array(updated.prefix(max(historyLimit, 1)))
            }

            try storageManager.saveHistory(updated)
            return AppendOutcome(history: updated, item: item, wasDeduplicated: false)
        }
    }

    func delete(id: UUID) throws -> DeleteOutcome {
        try withExclusiveLock {
            let current = dropItemsWithMissingImages(from: try storageManager.decodeHistory())
            let updated = current.filter { $0.id != id }

            guard updated.count != current.count else {
                return DeleteOutcome(history: current, removedItem: false)
            }

            try storageManager.saveHistory(updated)
            return DeleteOutcome(history: updated, removedItem: true)
        }
    }

    func clear() throws -> [ClipboardItem] {
        try withExclusiveLock {
            try storageManager.saveHistory([])
            return []
        }
    }

    func trim(to limit: Int) throws -> [ClipboardItem] {
        try withExclusiveLock {
            let current = dropItemsWithMissingImages(from: try storageManager.decodeHistory())
            let trimmed = Array(current.prefix(max(limit, 0)))

            guard trimmed.count != current.count else {
                return current
            }

            try storageManager.saveHistory(trimmed)
            return trimmed
        }
    }

    /// Launch-time writer transaction for the GUI app: drops items whose
    /// image file disappeared, recomputes persisted tags produced by an older
    /// resolver, and prunes orphaned image files.
    func repairAndMigrate() throws -> [ClipboardItem] {
        try withExclusiveLock {
            let decoded = try storageManager.decodeHistory()
            let repaired = dropItemsWithMissingImages(from: decoded).map { item in
                item.needsTagRecompute ? item.withComputedTags() : item
            }

            if repaired != decoded {
                try storageManager.saveHistory(repaired)
            } else {
                try storageManager.removeOrphanedImages(referencedBy: repaired)
            }

            return repaired
        }
    }

    // MARK: - Helpers

    private func dropItemsWithMissingImages(from items: [ClipboardItem]) -> [ClipboardItem] {
        items.filter { item in
            guard item.isImage else {
                return true
            }

            guard let imageURL = storageManager.imageURL(for: item) else {
                return false
            }

            return fileManager.fileExists(atPath: imageURL.path)
        }
    }

    private static func isDuplicate(payload: ClipboardPayload, of newest: ClipboardItem) -> Bool {
        guard case .text(let text) = payload else {
            return false
        }

        return newest.imageFilename == nil
            && newest.fileReferences == nil
            && newest.text == text
    }

    private func withExclusiveLock<T>(_ body: () throws -> T) throws -> T {
        try storageManager.ensureDirectoriesExist()

        let descriptor = open(lockFileURL.path, O_CREAT | O_WRONLY, 0o644)
        guard descriptor >= 0 else {
            throw RepositoryError.lockUnavailable
        }

        defer {
            close(descriptor)
        }

        let deadline = Date().addingTimeInterval(lockTimeout)

        while flock(descriptor, LOCK_EX | LOCK_NB) != 0 {
            guard Date() < deadline else {
                throw RepositoryError.lockTimedOut
            }

            usleep(10_000)
        }

        defer {
            flock(descriptor, LOCK_UN)
        }

        return try body()
    }
}
