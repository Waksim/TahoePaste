import AppKit
import Foundation

final class StorageManager {
    enum StorageError: LocalizedError {
        case invalidImageData

        var errorDescription: String? {
            switch self {
            case .invalidImageData:
                return L10n.tr("status.invalid_png")
            }
        }
    }

    let rootDirectoryURL: URL

    private let fileManager: FileManager
    private let historyFileURL: URL
    private let imagesDirectoryURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default, rootDirectoryURL: URL? = nil) {
        self.fileManager = fileManager

        let defaultRoot = (
            try? fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        )?.appendingPathComponent("TahoePaste", isDirectory: true)

        self.rootDirectoryURL = rootDirectoryURL
            ?? defaultRoot
            ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("TahoePaste", isDirectory: true)
        self.historyFileURL = self.rootDirectoryURL.appendingPathComponent("history.json")
        self.imagesDirectoryURL = self.rootDirectoryURL.appendingPathComponent("Images", isDirectory: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func loadHistory() throws -> [ClipboardItem] {
        try ensureDirectoriesExist()

        guard fileManager.fileExists(atPath: historyFileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: historyFileURL)
        let decodedItems = try decoder.decode([ClipboardItem].self, from: data)

        let cleanedItems = decodedItems
            .filter { item in
                if item.isImage == false {
                    return true
                }

                guard let imageURL = imageURL(for: item) else {
                    return false
                }

                return fileManager.fileExists(atPath: imageURL.path)
            }
            .sorted(by: { $0.createdAt > $1.createdAt })

        try removeOrphanedImages(referencedBy: cleanedItems)

        if cleanedItems != decodedItems {
            try saveHistory(cleanedItems)
        }

        return cleanedItems
    }

    func saveHistory(_ items: [ClipboardItem]) throws {
        try ensureDirectoriesExist()

        let data = try encoder.encode(items)
        try data.write(to: historyFileURL, options: [.atomic])
        try removeOrphanedImages(referencedBy: items)
    }

    func store(payload: ClipboardPayload) throws -> ClipboardItem {
        try ensureDirectoriesExist()

        switch payload {
        case .text(let text):
            let kind = ClipboardContentClassifier.classify(text: text)
            return ClipboardItem(
                id: UUID(),
                kind: kind,
                createdAt: .now,
                text: text,
                textPreview: ClipboardItem.previewText(from: text),
                imageFilename: nil,
                pixelSize: nil,
                fileReferences: nil
            )
        case .image(let image):
            let filename = "\(UUID().uuidString).png"
            let fileURL = imagesDirectoryURL.appendingPathComponent(filename)
            let pngData = try Self.pngData(from: image)

            try pngData.write(to: fileURL, options: [.atomic])

            return ClipboardItem(
                id: UUID(),
                kind: .image,
                createdAt: .now,
                text: nil,
                textPreview: nil,
                imageFilename: filename,
                pixelSize: Self.pixelSize(from: image),
                fileReferences: nil
            )
        case .fileURLs(let fileURLs):
            let fileReferences = fileURLs.map(fileReference(for:))
            let imagePreview = imageFilePreview(for: fileReferences)

            return ClipboardItem(
                id: UUID(),
                kind: .file,
                createdAt: .now,
                text: fileReferences.map(\.path).joined(separator: "\n"),
                textPreview: nil,
                imageFilename: imagePreview?.filename,
                pixelSize: imagePreview?.pixelSize,
                fileReferences: fileReferences
            )
        }
    }

    // A single copied image file gets a stored preview so its card can keep
    // showing the picture even after the original file moves or is deleted.
    private func imageFilePreview(
        for fileReferences: [ClipboardFileReference]
    ) -> (filename: String, pixelSize: ClipboardPixelSize)? {
        guard
            fileReferences.count == 1,
            let reference = fileReferences.first,
            reference.isDirectory == false,
            reference.category == .image,
            let image = NSImage(contentsOf: reference.url)
        else {
            return nil
        }

        let pixelSize = Self.pixelSize(from: image)
        let downscaledImage = Self.downscaledImage(image, maxPixelDimension: Self.previewMaxPixelDimension)

        guard let pngData = try? Self.pngData(from: downscaledImage) else {
            return nil
        }

        let filename = "\(UUID().uuidString).png"

        do {
            try pngData.write(to: imagesDirectoryURL.appendingPathComponent(filename), options: [.atomic])
        } catch {
            return nil
        }

        return (filename, pixelSize)
    }

    func loadImage(for item: ClipboardItem) -> NSImage? {
        guard let imageURL = imageURL(for: item) else {
            return nil
        }

        return NSImage(contentsOf: imageURL)
    }

    func imageURL(for item: ClipboardItem) -> URL? {
        guard let imageFilename = item.imageFilename else {
            return nil
        }

        return imagesDirectoryURL.appendingPathComponent(imageFilename)
    }

    func clearHistory() throws {
        try saveHistory([])
    }

    func formattedStorageUsage() -> String {
        let bytes = Double(storageUsageBytes())
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
        formatter.locale = AppLanguage.initial(defaults: .standard).locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = unit == "B" ? 0 : 1

        let formattedValue = formatter.string(from: NSNumber(value: value))
            ?? String(format: unit == "B" ? "%.0f" : "%.1f", value)

        return "\(formattedValue) \(unit)"
    }

    func storageUsageBytes() -> Int64 {
        try? ensureDirectoriesExist()

        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey,
            .totalFileSizeKey,
            .fileSizeKey
        ]

        guard let enumerator = fileManager.enumerator(
            at: rootDirectoryURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var totalBytes: Int64 = 0

        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: keys), values.isRegularFile == true else {
                continue
            }

            let fileSize = values.totalFileAllocatedSize
                ?? values.fileAllocatedSize
                ?? values.totalFileSize
                ?? values.fileSize
                ?? 0
            totalBytes += Int64(fileSize)
        }

        return totalBytes
    }

    func revealInFinder() {
        try? ensureDirectoriesExist()
        NSWorkspace.shared.activateFileViewerSelecting([rootDirectoryURL])
    }

    private func ensureDirectoriesExist() throws {
        try fileManager.createDirectory(at: rootDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: imagesDirectoryURL, withIntermediateDirectories: true)
    }

    private func removeOrphanedImages(referencedBy items: [ClipboardItem]) throws {
        let referencedFilenames = Set(items.compactMap(\.imageFilename))
        let storedFiles = try fileManager.contentsOfDirectory(at: imagesDirectoryURL, includingPropertiesForKeys: nil)

        for fileURL in storedFiles where referencedFilenames.contains(fileURL.lastPathComponent) == false {
            try? fileManager.removeItem(at: fileURL)
        }
    }

    static func pngData(from image: NSImage) throws -> Data {
        if
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let pngData = bitmap.representation(using: .png, properties: [:])
        {
            return pngData
        }

        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let representation = NSBitmapImageRep(cgImage: cgImage)
            if let pngData = representation.representation(using: .png, properties: [:]) {
                return pngData
            }
        }

        throw StorageError.invalidImageData
    }

    private static let previewMaxPixelDimension = 800.0

    static func downscaledImage(_ image: NSImage, maxPixelDimension: Double) -> NSImage {
        let originalSize = pixelSize(from: image)
        let largestSide = max(originalSize.width, originalSize.height)

        guard largestSide > maxPixelDimension, originalSize.width > 0, originalSize.height > 0 else {
            return image
        }

        let scale = maxPixelDimension / largestSide
        let targetWidth = max(Int((originalSize.width * scale).rounded()), 1)
        let targetHeight = max(Int((originalSize.height * scale).rounded()), 1)

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: targetWidth,
            pixelsHigh: targetHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return image
        }

        bitmap.size = NSSize(width: targetWidth, height: targetHeight)

        NSGraphicsContext.saveGraphicsState()
        defer {
            NSGraphicsContext.restoreGraphicsState()
        }

        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            return image
        }

        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        image.draw(
            in: NSRect(x: 0, y: 0, width: targetWidth, height: targetHeight),
            from: .zero,
            operation: .copy,
            fraction: 1
        )
        context.flushGraphics()

        let downscaled = NSImage(size: bitmap.size)
        downscaled.addRepresentation(bitmap)
        return downscaled
    }

    static func pixelSize(from image: NSImage) -> ClipboardPixelSize {
        if let bitmap = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first {
            return ClipboardPixelSize(width: Double(bitmap.pixelsWide), height: Double(bitmap.pixelsHigh))
        }

        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return ClipboardPixelSize(width: Double(cgImage.width), height: Double(cgImage.height))
        }

        return ClipboardPixelSize(width: image.size.width, height: image.size.height)
    }

    private func fileReference(for fileURL: URL) -> ClipboardFileReference {
        let keys: Set<URLResourceKey> = [
            .fileAllocatedSizeKey,
            .fileSizeKey,
            .isDirectoryKey,
            .nameKey,
            .totalFileAllocatedSizeKey,
            .totalFileSizeKey
        ]

        let values = try? fileURL.resourceValues(forKeys: keys)
        let isDirectory = values?.isDirectory ?? Self.directoryHint(for: fileURL)
        let byteSize = isDirectory
            ? nil
            : values?.totalFileSize
                ?? values?.fileSize
                ?? values?.totalFileAllocatedSize
                ?? values?.fileAllocatedSize

        return ClipboardFileReference(
            path: fileURL.path,
            displayName: values?.name ?? fileURL.lastPathComponent,
            isDirectory: isDirectory,
            category: ClipboardFileCategory.detect(for: fileURL, isDirectory: isDirectory),
            byteSize: byteSize.map(Int64.init)
        )
    }

    private static func directoryHint(for url: URL) -> Bool {
        if let values = try? url.resourceValues(forKeys: [.isDirectoryKey]), let isDirectory = values.isDirectory {
            return isDirectory
        }

        return false
    }
}
