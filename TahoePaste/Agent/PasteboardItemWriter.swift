import AppKit

/// Writes a history item back to a pasteboard. The payload is fully prepared
/// and validated BEFORE the pasteboard is cleared, so a failed restore never
/// destroys whatever the user currently has in the clipboard.
enum PasteboardItemWriter {
    enum PasteError: LocalizedError {
        case missingTextPayload
        case missingImagePayload
        case missingFilePayload
        case failedToWritePasteboard

        var errorDescription: String? {
            switch self {
            case .missingTextPayload:
                return "The item has no text payload."
            case .missingImagePayload:
                return "The stored image for this item is missing."
            case .missingFilePayload:
                return "None of the item's files exist anymore."
            case .failedToWritePasteboard:
                return "Writing to the pasteboard failed."
            }
        }
    }

    struct WriteResult {
        let changeCount: Int
        /// Only meaningful for file items: paths that were actually restored
        /// and paths that no longer exist on disk.
        let restoredFilePaths: [String]
        let missingFilePaths: [String]
    }

    private enum PreparedPayload {
        case text(String)
        case image(NSImage)
        case files(existing: [URL], missing: [String])
    }

    @discardableResult
    static func write(
        _ item: ClipboardItem,
        storageManager: StorageManager,
        pasteboard: NSPasteboard = .general
    ) throws -> WriteResult {
        let prepared = try prepare(item, storageManager: storageManager)

        pasteboard.clearContents()

        let writeSucceeded: Bool
        var restoredFilePaths: [String] = []
        var missingFilePaths: [String] = []

        switch prepared {
        case .text(let text):
            writeSucceeded = pasteboard.setString(text, forType: .string)
        case .image(let image):
            writeSucceeded = pasteboard.writeObjects([image])
        case .files(let existing, let missing):
            writeSucceeded = pasteboard.writeObjects(existing as [NSURL])
            restoredFilePaths = existing.map(\.path)
            missingFilePaths = missing
        }

        guard writeSucceeded else {
            throw PasteError.failedToWritePasteboard
        }

        return WriteResult(
            changeCount: pasteboard.changeCount,
            restoredFilePaths: restoredFilePaths,
            missingFilePaths: missingFilePaths
        )
    }

    private static func prepare(
        _ item: ClipboardItem,
        storageManager: StorageManager
    ) throws -> PreparedPayload {
        switch item.kind {
        case .text, .link, .code:
            guard let text = item.text else {
                throw PasteError.missingTextPayload
            }

            return .text(text)
        case .image:
            guard let image = storageManager.loadImage(for: item) else {
                throw PasteError.missingImagePayload
            }

            return .image(image)
        case .file:
            guard let fileReferences = item.fileReferences, fileReferences.isEmpty == false else {
                throw PasteError.missingFilePayload
            }

            var existing: [URL] = []
            var missing: [String] = []

            for reference in fileReferences {
                if FileManager.default.fileExists(atPath: reference.path) {
                    existing.append(reference.url)
                } else {
                    missing.append(reference.path)
                }
            }

            guard existing.isEmpty == false else {
                throw PasteError.missingFilePayload
            }

            return .files(existing: existing, missing: missing)
        }
    }
}
