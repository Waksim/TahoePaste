import Foundation

enum ClipboardTag: String, Codable, Hashable, CaseIterable, Identifiable {
    case text
    case image
    case link
    case code
    case file
    case video
    case audio
    case document
    case pdf
    case spreadsheet
    case presentation
    case archive
    case folder

    var id: String {
        rawValue
    }

    var titleKey: String {
        switch self {
        case .text:
            return "card.text"
        case .image:
            return "card.image"
        case .link:
            return "card.link"
        case .code:
            return "card.code"
        case .file:
            return "card.file"
        case .video:
            return "card.video"
        case .audio:
            return "card.audio"
        case .document:
            return "card.document"
        case .pdf:
            return "card.pdf"
        case .spreadsheet:
            return "card.spreadsheet"
        case .presentation:
            return "card.presentation"
        case .archive:
            return "card.archive"
        case .folder:
            return "card.folder"
        }
    }

    var systemImageName: String {
        switch self {
        case .text:
            return "text.alignleft"
        case .image:
            return "photo"
        case .link:
            return "link"
        case .code:
            return "chevron.left.forwardslash.chevron.right"
        case .file:
            return "doc"
        case .video:
            return "video"
        case .audio:
            return "waveform"
        case .document:
            return "doc.text"
        case .pdf:
            return "doc.richtext"
        case .spreadsheet:
            return "tablecells"
        case .presentation:
            return "rectangle.on.rectangle"
        case .archive:
            return "archivebox"
        case .folder:
            return "folder"
        }
    }

    var searchKeywords: [String] {
        switch self {
        case .text:
            return ["text", "texts", "текст", "тексты", "文本", "文字"]
        case .image:
            return ["image", "images", "picture", "pictures", "изображение", "изображения", "картинка", "картинки", "图片", "图像"]
        case .link:
            return ["link", "links", "url", "urls", "ссылка", "ссылки", "链接", "网址"]
        case .code:
            return ["code", "codes", "snippet", "snippets", "код", "коды", "代码", "代码片段"]
        case .file:
            return ["file", "files", "файл", "файлы", "文件", "文件"]
        case .video:
            return ["video", "videos", "movie", "movies", "clip", "clips", "видео", "ролик", "视频", "影片"]
        case .audio:
            return ["audio", "music", "sound", "voice", "аудио", "звук", "музыка", "音频", "声音"]
        case .document:
            return ["document", "documents", "doc", "docs", "документ", "документы", "文档", "文件资料"]
        case .pdf:
            return ["pdf", "пдф", "pdf文档"]
        case .spreadsheet:
            return ["spreadsheet", "sheet", "table", "excel", "csv", "таблица", "excel", "表格", "电子表格"]
        case .presentation:
            return ["presentation", "slides", "keynote", "powerpoint", "презентация", "слайды", "演示", "幻灯片"]
        case .archive:
            return ["archive", "zip", "rar", "compressed", "архив", "zip", "压缩包", "归档"]
        case .folder:
            return ["folder", "directory", "папка", "директория", "文件夹", "目录"]
        }
    }
}

enum ClipboardKind: String, Codable, Hashable {
    case text
    case image
    case link
    case code
    case file

    var primaryTag: ClipboardTag {
        switch self {
        case .text:
            return .text
        case .image:
            return .image
        case .link:
            return .link
        case .code:
            return .code
        case .file:
            return .file
        }
    }

    var titleKey: String {
        primaryTag.titleKey
    }

    var systemImageName: String {
        primaryTag.systemImageName
    }

    var searchKeywords: [String] {
        primaryTag.searchKeywords
    }
}

enum ClipboardFileCategory: String, Codable, Hashable {
    case folder
    case video
    case audio
    case document
    case pdf
    case spreadsheet
    case presentation
    case archive
    case code
    case image
    case other

    var tags: [ClipboardTag] {
        switch self {
        case .folder:
            return [.file, .folder]
        case .video:
            return [.file, .video]
        case .audio:
            return [.file, .audio]
        case .document:
            return [.file, .document]
        case .pdf:
            return [.file, .document, .pdf]
        case .spreadsheet:
            return [.file, .document, .spreadsheet]
        case .presentation:
            return [.file, .document, .presentation]
        case .archive:
            return [.file, .archive]
        case .code:
            return [.file, .code]
        case .image:
            return [.file, .image]
        case .other:
            return [.file]
        }
    }

    static func detect(for fileURL: URL, isDirectory: Bool) -> ClipboardFileCategory {
        if isDirectory {
            return .folder
        }

        let fileExtension = fileURL.pathExtension.lowercased()

        if videoExtensions.contains(fileExtension) {
            return .video
        }

        if audioExtensions.contains(fileExtension) {
            return .audio
        }

        if archiveExtensions.contains(fileExtension) {
            return .archive
        }

        if pdfExtensions.contains(fileExtension) {
            return .pdf
        }

        if spreadsheetExtensions.contains(fileExtension) {
            return .spreadsheet
        }

        if presentationExtensions.contains(fileExtension) {
            return .presentation
        }

        if codeExtensions.contains(fileExtension) {
            return .code
        }

        if imageExtensions.contains(fileExtension) {
            return .image
        }

        if documentExtensions.contains(fileExtension) {
            return .document
        }

        return .other
    }

    private static let videoExtensions: Set<String> = [
        "avi", "m4v", "mkv", "mov", "mp4", "mpeg", "mpg", "webm"
    ]

    private static let audioExtensions: Set<String> = [
        "aac", "aiff", "flac", "m4a", "mp3", "ogg", "wav"
    ]

    private static let archiveExtensions: Set<String> = [
        "7z", "bz2", "dmg", "gz", "rar", "tar", "tgz", "xz", "zip"
    ]

    private static let pdfExtensions: Set<String> = ["pdf"]

    private static let spreadsheetExtensions: Set<String> = [
        "csv", "numbers", "ods", "tsv", "xls", "xlsx"
    ]

    private static let presentationExtensions: Set<String> = [
        "key", "odp", "ppt", "pptx"
    ]

    private static let codeExtensions: Set<String> = [
        "c", "cc", "cpp", "cs", "css", "go", "h", "hpp", "html", "java", "js", "json", "kt",
        "md", "php", "py", "rb", "rs", "sh", "sql", "swift", "toml", "ts", "tsx", "xml", "yaml", "yml", "zsh"
    ]

    private static let imageExtensions: Set<String> = [
        "bmp", "gif", "heic", "icns", "jpeg", "jpg", "png", "svg", "tif", "tiff", "webp"
    ]

    private static let documentExtensions: Set<String> = [
        "doc", "docx", "odt", "pages", "rtf", "txt"
    ]
}

struct ClipboardPixelSize: Codable, Hashable {
    let width: Double
    let height: Double

    var displayText: String {
        "\(Int(width.rounded())) × \(Int(height.rounded()))"
    }
}

struct ClipboardFileReference: Codable, Hashable {
    let path: String
    let displayName: String
    let isDirectory: Bool
    let category: ClipboardFileCategory
    let byteSize: Int64?

    enum CodingKeys: String, CodingKey {
        case path
        case displayName
        case isDirectory
        case category
        case byteSize
    }

    init(path: String, displayName: String, isDirectory: Bool, category: ClipboardFileCategory, byteSize: Int64?) {
        self.path = path
        self.displayName = displayName
        self.isDirectory = isDirectory
        self.category = category
        self.byteSize = byteSize
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        path = try container.decode(String.self, forKey: .path)
        displayName = try container.decode(String.self, forKey: .displayName)
        isDirectory = try container.decode(Bool.self, forKey: .isDirectory)
        category = try container.decodeIfPresent(ClipboardFileCategory.self, forKey: .category) ?? .other
        byteSize = try container.decodeIfPresent(Int64.self, forKey: .byteSize)
    }

    var url: URL {
        URL(fileURLWithPath: path, isDirectory: isDirectory)
    }
}

struct ClipboardItem: Identifiable, Codable, Hashable {
    let id: UUID
    let kind: ClipboardKind
    let createdAt: Date
    let text: String?
    let textPreview: String?
    let imageFilename: String?
    let pixelSize: ClipboardPixelSize?
    let fileReferences: [ClipboardFileReference]?

    var isText: Bool {
        kind == .text
    }

    var isImage: Bool {
        kind == .image
    }

    var isLink: Bool {
        kind == .link
    }

    var isCode: Bool {
        kind == .code
    }

    var isFile: Bool {
        kind == .file
    }

    var usesTextCardLayout: Bool {
        isImage == false
    }

    var characterCount: Int {
        text?.count ?? 0
    }

    var fileCount: Int {
        fileReferences?.count ?? 0
    }

    var tags: [ClipboardTag] {
        var resolvedTags = [kind.primaryTag]

        if let fileReferences {
            for fileReference in fileReferences {
                for tag in fileReference.category.tags where resolvedTags.contains(tag) == false {
                    resolvedTags.append(tag)
                }
            }
        }

        return resolvedTags
    }

    var displayTags: [ClipboardTag] {
        if tags.count <= 3 {
            return tags
        }

        guard let firstTag = tags.first else {
            return []
        }

        return [firstTag] + Array(tags.dropFirst().prefix(2))
    }

    var displayPreviewText: String {
        if isFile, let fileReferences, fileReferences.isEmpty == false {
            return Self.filePreview(from: fileReferences)
        }

        return textPreview ?? text ?? L10n.tr("card.no_text_preview")
    }

    func metadataText(locale: Locale) -> String? {
        switch kind {
        case .file:
            return fileMetadataText(locale: locale)
        case .text, .link, .code:
            return L10n.tr("unit.characters", characterCount)
        case .image:
            return pixelSize?.displayText ?? L10n.tr("card.image")
        }
    }

    func timestampText(locale: Locale) -> String {
        createdAt.formatted(.dateTime.hour().minute().locale(locale))
    }

    static func previewText(from text: String, maxLength: Int = 180) -> String {
        let collapsed = text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard collapsed.count > maxLength else {
            return collapsed
        }

        let index = collapsed.index(collapsed.startIndex, offsetBy: maxLength)
        return String(collapsed[..<index]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    static func filePreview(from fileReferences: [ClipboardFileReference], maxVisibleNames: Int = 3) -> String {
        let visibleNames = Array(fileReferences.prefix(maxVisibleNames)).map(\.displayName)
        let remainingCount = fileReferences.count - visibleNames.count
        var lines = visibleNames

        if remainingCount > 0 {
            lines.append(L10n.tr("card.more_files", remainingCount))
        }

        return lines.joined(separator: "\n")
    }

    static func formatByteCount(_ byteCount: Int64, locale: Locale) -> String {
        let bytes = Double(max(byteCount, 0))
        let kilobyte = 1024.0
        let megabyte = kilobyte * 1024.0
        let gigabyte = megabyte * 1024.0

        let value: Double
        let unit: String

        switch bytes {
        case gigabyte...:
            value = bytes / gigabyte
            unit = "GB"
        case megabyte...:
            value = bytes / megabyte
            unit = "MB"
        case kilobyte...:
            value = bytes / kilobyte
            unit = "KB"
        default:
            value = bytes
            unit = "B"
        }

        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = unit == "B" ? 0 : 1

        let formattedValue = formatter.string(from: NSNumber(value: value))
            ?? String(format: unit == "B" ? "%.0f" : "%.1f", value)

        return "\(formattedValue) \(unit)"
    }

    private func fileMetadataText(locale: Locale) -> String? {
        guard let fileReferences, fileReferences.isEmpty == false else {
            return nil
        }

        let knownByteSizes = fileReferences.compactMap(\.byteSize)
        let totalByteSize = knownByteSizes.reduce(0, +)

        if fileReferences.count == 1 {
            if let byteSize = fileReferences.first?.byteSize {
                return Self.formatByteCount(byteSize, locale: locale)
            }

            return fileReferences.first?.isDirectory == true
                ? L10n.tr("card.folder")
                : L10n.tr("card.file")
        }

        let countText = L10n.tr("unit.files", fileReferences.count)

        guard totalByteSize > 0 else {
            return countText
        }

        return "\(countText) · \(Self.formatByteCount(totalByteSize, locale: locale))"
    }
}
