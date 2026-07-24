import Foundation

/// Read-side of the agent CLI: querying, filtering, sensitivity gating, and
/// the JSON DTOs agents consume. Lives in the app target so it is unit
/// tested there; the CLI is a thin dispatcher around it.
struct AgentQueryService {
    enum QueryError: LocalizedError {
        case itemNotFound(UUID)
        case sensitiveItem(UUID)
        case noImage(UUID)

        var errorDescription: String? {
            switch self {
            case .itemNotFound(let id):
                return "No history item with id \(id.uuidString)."
            case .sensitiveItem(let id):
                return "Item \(id.uuidString) looks like a password or token. Re-run with --include-sensitive to access it."
            case .noImage(let id):
                return "Item \(id.uuidString) has no stored image."
            }
        }
    }

    struct ItemSummary: Codable {
        let id: UUID
        let kind: String
        let tags: [String]
        let createdAt: Date
        let preview: String?
        let charCount: Int?
        let pixelSize: ClipboardPixelSize?
        let fileCount: Int?
        let isSensitive: Bool
    }

    struct ListResponse: Codable {
        let items: [ItemSummary]
        let totalItems: Int
        let sensitiveExcluded: Int
    }

    struct FileInfo: Codable {
        let path: String
        let displayName: String
        let isDirectory: Bool
        let category: String
        let byteSize: Int64?
    }

    struct ItemDetail: Codable {
        let id: UUID
        let kind: String
        let tags: [String]
        let createdAt: Date
        let preview: String?
        let charCount: Int?
        let pixelSize: ClipboardPixelSize?
        let fileCount: Int?
        let isSensitive: Bool
        let text: String?
        let truncated: Bool?
        let totalChars: Int?
        let imagePath: String?
        let files: [FileInfo]?
    }

    struct ImageInfo: Codable {
        let id: UUID
        let imagePath: String
        let pixelSize: ClipboardPixelSize?
    }

    static let defaultLimit = 10
    static let maxLimit = 100
    static let maxFullTextCharacters = 200_000

    let repository: HistoryRepository
    let storageManager: StorageManager

    // MARK: - Queries

    func recent(limit: Int, includeSensitive: Bool) throws -> ListResponse {
        try search(
            query: "",
            kind: nil,
            tag: nil,
            since: nil,
            limit: limit,
            includeSensitive: includeSensitive
        )
    }

    func search(
        query: String,
        kind: ClipboardKind?,
        tag: ClipboardTag?,
        since: Date?,
        limit: Int,
        includeSensitive: Bool
    ) throws -> ListResponse {
        var candidates = try repository.readSnapshot()

        if let since {
            candidates = candidates.filter { $0.createdAt >= since }
        }

        if let kind {
            candidates = candidates.filter { $0.kind == kind }
        }

        if let tag {
            candidates = candidates.filter { $0.tags.contains(tag) }
        }

        let matched = query.isEmpty
            ? candidates
            : ClipboardSearchEngine.matches(for: candidates, query: query)

        let visible = includeSensitive ? matched : matched.filter { Self.isSensitive($0) == false }
        let clampedLimit = min(max(limit, 1), Self.maxLimit)

        return ListResponse(
            items: visible.prefix(clampedLimit).map(Self.summary(for:)),
            totalItems: visible.count,
            sensitiveExcluded: matched.count - visible.count
        )
    }

    func detail(id: UUID, full: Bool, includeSensitive: Bool) throws -> ItemDetail {
        let item = try item(id: id)
        try ensureAccessible(item, includeSensitive: includeSensitive)

        var text: String?
        var truncated: Bool?
        var totalChars: Int?
        var imagePath: String?
        var files: [FileInfo]?

        if full {
            if let fullText = item.text {
                if fullText.count > Self.maxFullTextCharacters {
                    text = String(fullText.prefix(Self.maxFullTextCharacters))
                    truncated = true
                    totalChars = fullText.count
                } else {
                    text = fullText
                }
            }

            imagePath = storageManager.imageURL(for: item)?.path
            files = item.fileReferences?.map(Self.fileInfo(for:))
        }

        let summary = Self.summary(for: item)
        return ItemDetail(
            id: summary.id,
            kind: summary.kind,
            tags: summary.tags,
            createdAt: summary.createdAt,
            preview: summary.preview,
            charCount: summary.charCount,
            pixelSize: summary.pixelSize,
            fileCount: summary.fileCount,
            isSensitive: summary.isSensitive,
            text: text,
            truncated: truncated,
            totalChars: totalChars,
            imagePath: imagePath,
            files: files
        )
    }

    func imageInfo(id: UUID) throws -> ImageInfo {
        let item = try item(id: id)

        guard let imageURL = storageManager.imageURL(for: item) else {
            throw QueryError.noImage(id)
        }

        return ImageInfo(id: item.id, imagePath: imageURL.path, pixelSize: item.pixelSize)
    }

    func item(id: UUID) throws -> ClipboardItem {
        guard let item = try repository.readSnapshot().first(where: { $0.id == id }) else {
            throw QueryError.itemNotFound(id)
        }

        return item
    }

    /// Single-item access gate for `get`/`copy`. Persisted tags only cover
    /// the first 4000 characters, so the full text is re-scanned here.
    func ensureAccessible(_ item: ClipboardItem, includeSensitive: Bool) throws {
        guard includeSensitive == false else {
            return
        }

        if Self.isSensitive(item) {
            throw QueryError.sensitiveItem(item.id)
        }

        if let text = item.text, ClipboardContentClassifier.containsSensitiveContent(inFullText: text) {
            throw QueryError.sensitiveItem(item.id)
        }
    }

    // MARK: - Mapping

    static func isSensitive(_ item: ClipboardItem) -> Bool {
        let tags = item.tags
        return tags.contains(.password) || tags.contains(.token)
    }

    static func summary(for item: ClipboardItem) -> ItemSummary {
        let isTextLike = item.kind == .text || item.kind == .link || item.kind == .code

        let preview: String?
        switch item.kind {
        case .text, .link, .code:
            preview = item.textPreview ?? item.text.map { ClipboardItem.previewText(from: $0) }
        case .file:
            preview = item.fileReferences.map { ClipboardItem.filePreview(from: $0) }
        case .image:
            preview = nil
        }

        return ItemSummary(
            id: item.id,
            kind: item.kind.rawValue,
            tags: item.tags.map(\.rawValue),
            createdAt: item.createdAt,
            preview: preview,
            charCount: isTextLike ? item.characterCount : nil,
            pixelSize: item.pixelSize,
            fileCount: item.isFile ? item.fileCount : nil,
            isSensitive: isSensitive(item)
        )
    }

    static func fileInfo(for reference: ClipboardFileReference) -> FileInfo {
        FileInfo(
            path: reference.path,
            displayName: reference.displayName,
            isDirectory: reference.isDirectory,
            category: reference.category.rawValue,
            byteSize: reference.byteSize
        )
    }

    // MARK: - Encoding and parsing

    /// Compact deterministic JSON for agent consumption.
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    /// Accepts ISO8601 timestamps or relative offsets like `30m`, `2h`, `7d`.
    static func parseSince(_ raw: String, now: Date = .now) -> Date? {
        if let date = ISO8601DateFormatter().date(from: raw) {
            return date
        }

        guard raw.count >= 2, let value = Double(raw.dropLast()) else {
            return nil
        }

        switch raw.last {
        case "m":
            return now.addingTimeInterval(-value * 60)
        case "h":
            return now.addingTimeInterval(-value * 3_600)
        case "d":
            return now.addingTimeInterval(-value * 86_400)
        default:
            return nil
        }
    }
}
