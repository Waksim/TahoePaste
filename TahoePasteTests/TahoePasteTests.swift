import AppKit
import ServiceManagement
import XCTest
@testable import TahoePaste

final class TahoePasteTests: XCTestCase {
    func testClipboardItemJSONRoundTripForTextAndImage() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let now = Date()
        let items = [
            ClipboardItem(
                id: UUID(),
                kind: .text,
                createdAt: now,
                text: "Hello from TahoePaste",
                textPreview: ClipboardItem.previewText(from: "Hello from TahoePaste"),
                imageFilename: nil,
                pixelSize: nil,
                fileReferences: nil
            ),
            ClipboardItem(
                id: UUID(),
                kind: .image,
                createdAt: now.addingTimeInterval(-10),
                text: nil,
                textPreview: nil,
                imageFilename: "sample.png",
                pixelSize: ClipboardPixelSize(width: 320, height: 240),
                fileReferences: nil
            )
        ]

        let data = try encoder.encode(items)
        let decoded = try decoder.decode([ClipboardItem].self, from: data)

        XCTAssertEqual(decoded.count, items.count)
        XCTAssertEqual(decoded.map(\.id), items.map(\.id))
        XCTAssertEqual(decoded.map(\.kind), items.map(\.kind))
        XCTAssertEqual(decoded.map(\.text), items.map(\.text))
        XCTAssertEqual(decoded.map(\.textPreview), items.map(\.textPreview))
        XCTAssertEqual(decoded.map(\.imageFilename), items.map(\.imageFilename))
        XCTAssertEqual(decoded.map(\.pixelSize), items.map(\.pixelSize))

        for (restored, original) in zip(decoded, items) {
            XCTAssertLessThan(abs(restored.createdAt.timeIntervalSince(original.createdAt)), 1)
        }
    }

    func testStorageManagerSavesAndLoadsImages() throws {
        let storageManager = StorageManager(rootDirectoryURL: makeTemporaryDirectory())
        let image = makeImage(size: NSSize(width: 160, height: 90), color: .systemOrange)

        let item = try storageManager.store(payload: .image(image))
        try storageManager.saveHistory([item])

        let restoredHistory = try storageManager.loadHistory()
        let restoredImage = storageManager.loadImage(for: restoredHistory[0])

        XCTAssertEqual(restoredHistory.count, 1)
        XCTAssertEqual(restoredHistory[0].pixelSize, ClipboardPixelSize(width: 160, height: 90))
        XCTAssertNotNil(restoredImage)
    }

    func testStorageManagerRestoresHistoryFromDisk() throws {
        let rootDirectory = makeTemporaryDirectory()
        let firstManager = StorageManager(rootDirectoryURL: rootDirectory)

        let textItem = try firstManager.store(payload: .text("A persisted clipboard note"))
        let imageItem = try firstManager.store(payload: .image(makeImage(size: NSSize(width: 48, height: 48), color: .systemBlue)))
        try firstManager.saveHistory([textItem, imageItem])

        let secondManager = StorageManager(rootDirectoryURL: rootDirectory)
        let restored = try secondManager.loadHistory()

        XCTAssertEqual(restored.count, 2)
        XCTAssertTrue(restored.contains(where: { $0.kind == .text && $0.text == "A persisted clipboard note" }))
        XCTAssertTrue(restored.contains(where: { $0.kind == .image && $0.pixelSize == ClipboardPixelSize(width: 48, height: 48) }))
    }

    func testStorageManagerRemovesOrphanedImagesWhenItemIsDeleted() throws {
        let storageManager = StorageManager(rootDirectoryURL: makeTemporaryDirectory())
        let imageItem = try storageManager.store(payload: .image(makeImage(size: NSSize(width: 64, height: 64), color: .systemMint)))
        let imageURL = try XCTUnwrap(storageManager.imageURL(for: imageItem))

        try storageManager.saveHistory([imageItem])
        XCTAssertTrue(FileManager.default.fileExists(atPath: imageURL.path))

        try storageManager.saveHistory([])

        XCTAssertFalse(FileManager.default.fileExists(atPath: imageURL.path))
    }

    func testClipboardSuppressionConsumesMatchingChangeCountOnce() {
        var suppression = ClipboardChangeSuppression()

        suppression.register(changeCount: 42)

        XCTAssertTrue(suppression.shouldSuppress(changeCount: 42))
        XCTAssertFalse(suppression.shouldSuppress(changeCount: 42))
        XCTAssertFalse(suppression.shouldSuppress(changeCount: 43))
    }

    func testKeyboardLayoutMapperConvertsRussianLayoutToEnglish() {
        XCTAssertEqual(KeyboardLayoutMapper.swappedLayout(for: "СрфеПЗЕ"), "chatgpt")
    }

    func testKeyboardLayoutMapperConvertsEnglishLayoutToRussian() {
        XCTAssertEqual(KeyboardLayoutMapper.swappedLayout(for: "Zyltrc"), "яндекс")
    }

    func testClipboardSearchFindsItemsAcrossKeyboardLayouts() {
        let items = [
            ClipboardItem(
                id: UUID(),
                kind: .text,
                createdAt: Date(),
                text: "ChatGPT",
                textPreview: "ChatGPT",
                imageFilename: nil,
                pixelSize: nil,
                fileReferences: nil
            ),
            ClipboardItem(
                id: UUID(),
                kind: .text,
                createdAt: Date().addingTimeInterval(-1),
                text: "Яндекс",
                textPreview: "Яндекс",
                imageFilename: nil,
                pixelSize: nil,
                fileReferences: nil
            )
        ]

        let englishMatches = ClipboardSearchEngine.matches(for: items, query: "СрфеПЗЕ")
        let russianMatches = ClipboardSearchEngine.matches(for: items, query: "Zyltrc")

        XCTAssertEqual(englishMatches.first?.text, "ChatGPT")
        XCTAssertEqual(russianMatches.first?.text, "Яндекс")
    }

    func testClipboardSearchPrefersDirectLayoutMatchesOverMappedOnes() {
        let items = [
            ClipboardItem(
                id: UUID(),
                kind: .text,
                createdAt: Date(),
                text: "zyltrc",
                textPreview: "zyltrc",
                imageFilename: nil,
                pixelSize: nil,
                fileReferences: nil
            ),
            ClipboardItem(
                id: UUID(),
                kind: .text,
                createdAt: Date().addingTimeInterval(-1),
                text: "Яндекс",
                textPreview: "Яндекс",
                imageFilename: nil,
                pixelSize: nil,
                fileReferences: nil
            )
        ]

        let matches = ClipboardSearchEngine.matches(for: items, query: "zyltrc")

        XCTAssertEqual(matches.first?.text, "zyltrc")
        XCTAssertEqual(matches.last?.text, "Яндекс")
    }

    func testAppLanguageBestMatchUsesPreferredLanguages() {
        XCTAssertEqual(AppLanguage.bestMatch(for: ["ru-RU", "en-US"]), .russian)
        XCTAssertEqual(AppLanguage.bestMatch(for: ["zh-Hans-CN", "en-US"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.bestMatch(for: ["en-GB"]), .english)
        XCTAssertEqual(AppLanguage.bestMatch(for: ["fr-FR"]), .english)
    }

    func testMaximumHistoryItemsSupportsUnlimitedAndFiniteBounds() {
        XCTAssertEqual(SettingsManager.normalizedMaximumHistoryItems(0), 0)
        XCTAssertEqual(SettingsManager.normalizedMaximumHistoryItems(-50), 0)
        XCTAssertEqual(SettingsManager.normalizedMaximumHistoryItems(5), 10)
        XCTAssertEqual(SettingsManager.normalizedMaximumHistoryItems(2000), 1000)
    }

    func testLaunchAtLoginStateTreatsApprovalAsEnabled() {
        XCTAssertTrue(SettingsManager.isLaunchAtLoginEnabled(for: .enabled))
        XCTAssertTrue(SettingsManager.isLaunchAtLoginEnabled(for: .requiresApproval))
        XCTAssertFalse(SettingsManager.isLaunchAtLoginEnabled(for: .notRegistered))
    }

    func testLaunchAtLoginStatusMessageAppearsOnlyWhenApprovalIsNeeded() {
        XCTAssertEqual(
            SettingsManager.launchAtLoginStatusMessage(for: .requiresApproval),
            L10n.tr("status.launch_at_login_needs_approval")
        )
        XCTAssertNil(SettingsManager.launchAtLoginStatusMessage(for: .enabled))
    }

    func testLocalizationFilesShareTheSameKeySetAcrossSupportedLanguages() throws {
        let englishEntries = try localizationEntries(for: "en")
        let russianEntries = try localizationEntries(for: "ru")
        let chineseEntries = try localizationEntries(for: "zh-Hans")

        XCTAssertEqual(Set(englishEntries.keys), Set(russianEntries.keys))
        XCTAssertEqual(Set(englishEntries.keys), Set(chineseEntries.keys))
        XCTAssertFalse(russianEntries.values.contains(where: \.isEmpty))
        XCTAssertFalse(chineseEntries.values.contains(where: \.isEmpty))
    }

    func testSystemThemeModeMapsSystemAppearanceToDayAndNightThemes() {
        XCTAssertEqual(
            SettingsManager.resolvedTheme(
                mode: .system,
                systemIsDark: false,
                dayThemeStartMinutes: 8 * 60,
                nightThemeStartMinutes: 20 * 60,
                nowMinutesSinceMidnight: 13 * 60
            ),
            .day
        )

        XCTAssertEqual(
            SettingsManager.resolvedTheme(
                mode: .system,
                systemIsDark: true,
                dayThemeStartMinutes: 8 * 60,
                nightThemeStartMinutes: 20 * 60,
                nowMinutesSinceMidnight: 13 * 60
            ),
            .night
        )
    }

    func testScheduledThemeUsesDayBetweenConfiguredStartTimes() {
        XCTAssertEqual(
            SettingsManager.resolvedTheme(
                mode: .scheduled,
                systemIsDark: false,
                dayThemeStartMinutes: 8 * 60,
                nightThemeStartMinutes: 20 * 60,
                nowMinutesSinceMidnight: 9 * 60
            ),
            .day
        )

        XCTAssertEqual(
            SettingsManager.resolvedTheme(
                mode: .scheduled,
                systemIsDark: false,
                dayThemeStartMinutes: 8 * 60,
                nightThemeStartMinutes: 20 * 60,
                nowMinutesSinceMidnight: 21 * 60
            ),
            .night
        )
    }

    func testScheduledThemeSupportsIntervalsThatWrapPastMidnight() {
        XCTAssertEqual(
            SettingsManager.resolvedTheme(
                mode: .scheduled,
                systemIsDark: false,
                dayThemeStartMinutes: 20 * 60,
                nightThemeStartMinutes: 8 * 60,
                nowMinutesSinceMidnight: 23 * 60
            ),
            .day
        )

        XCTAssertEqual(
            SettingsManager.resolvedTheme(
                mode: .scheduled,
                systemIsDark: false,
                dayThemeStartMinutes: 20 * 60,
                nightThemeStartMinutes: 8 * 60,
                nowMinutesSinceMidnight: 10 * 60
            ),
            .night
        )
    }

    func testClipboardContentClassifierDetectsLinksAndCode() {
        XCTAssertEqual(ClipboardContentClassifier.classify(text: "https://openai.com"), .link)
        XCTAssertEqual(ClipboardContentClassifier.classify(text: "git status"), .code)
        XCTAssertEqual(ClipboardContentClassifier.classify(text: "A regular note"), .text)
    }

    func testClipboardContentClassifierDetectsContactAndScheduleTags() {
        let text = "Write me at hello@example.com or call +1 (415) 555-2671 tomorrow at 10:30."
        let tags = ClipboardContentClassifier.detectedTags(for: text)

        XCTAssertTrue(tags.contains(.email))
        XCTAssertTrue(tags.contains(.phone))
        XCTAssertTrue(tags.contains(.dateTime))
    }

    func testClipboardContentClassifierDetectsPasswordAndTokenTags() {
        let credentialsText = "Password: Str0ng!Pass2026"
        let tokenText = "Authorization: Bearer sk_live_1234567890ABCDEF"

        XCTAssertTrue(ClipboardContentClassifier.detectedTags(for: credentialsText).contains(.password))
        XCTAssertTrue(ClipboardContentClassifier.detectedTags(for: tokenText).contains(.token))
    }

    func testClipboardSearchMatchesTextDerivedTagKeywords() {
        let item = ClipboardItem(
            id: UUID(),
            kind: .text,
            createdAt: Date(),
            text: "Reach me at hello@example.com",
            textPreview: "Reach me at hello@example.com",
            imageFilename: nil,
            pixelSize: nil,
            fileReferences: nil
        )

        let matches = ClipboardSearchEngine.matches(for: [item], query: "email")

        XCTAssertTrue(item.tags.contains(.email))
        XCTAssertEqual(matches.first?.id, item.id)
    }

    func testStorageManagerStoresFilePayloads() throws {
        let storageManager = StorageManager(rootDirectoryURL: makeTemporaryDirectory())
        let fileURL = makeTemporaryDirectory().appendingPathComponent("Readme.txt")
        FileManager.default.createFile(atPath: fileURL.path, contents: Data("hello".utf8))

        let item = try storageManager.store(payload: .fileURLs([fileURL]))

        XCTAssertEqual(item.kind, .file)
        XCTAssertEqual(item.fileReferences?.first?.path, fileURL.path)
        XCTAssertEqual(item.fileReferences?.first?.category, .document)
        XCTAssertEqual(item.fileReferences?.first?.byteSize, 5)
        XCTAssertEqual(item.fileCount, 1)
        XCTAssertTrue(item.tags.contains(.file))
        XCTAssertTrue(item.tags.contains(.document))
        XCTAssertTrue(item.displayPreviewText.contains("Readme.txt"))
    }

    func testStorageManagerCategorizesVideoFilesAndSearchMatchesVideoTag() throws {
        let storageManager = StorageManager(rootDirectoryURL: makeTemporaryDirectory())
        let fileURL = makeTemporaryDirectory().appendingPathComponent("Trailer.mp4")
        FileManager.default.createFile(atPath: fileURL.path, contents: Data(repeating: 0xAB, count: 1_536))

        let item = try storageManager.store(payload: .fileURLs([fileURL]))
        let matches = ClipboardSearchEngine.matches(for: [item], query: "video")

        XCTAssertEqual(item.fileReferences?.first?.category, .video)
        XCTAssertTrue(item.tags.contains(.video))
        XCTAssertEqual(item.metadataText(locale: Locale(identifier: "en_US")), "1.5 KB")
        XCTAssertEqual(matches.first?.id, item.id)
    }

    func testClipboardSearchFallsBackToTypeMatchesAfterContentMatches() {
        let items = [
            ClipboardItem(
                id: UUID(),
                kind: .link,
                createdAt: Date(),
                text: "Text adventure link",
                textPreview: "Text adventure link",
                imageFilename: nil,
                pixelSize: nil,
                fileReferences: nil
            ),
            ClipboardItem(
                id: UUID(),
                kind: .text,
                createdAt: Date().addingTimeInterval(-1),
                text: "Plain note",
                textPreview: "Plain note",
                imageFilename: nil,
                pixelSize: nil,
                fileReferences: nil
            )
        ]

        let matches = ClipboardSearchEngine.matches(for: items, query: "text")

        XCTAssertEqual(matches.first?.kind, .link)
        XCTAssertEqual(matches.last?.kind, .text)
    }

    private func makeTemporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    private func makeImage(size: NSSize, color: NSColor) -> NSImage {
        let pixelWidth = Int(size.width)
        let pixelHeight = Int(size.height)
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!

        let context = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        color.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: size)
        image.addRepresentation(bitmap)

        return image
    }

    private func localizationEntries(for localeIdentifier: String) throws -> [String: String] {
        let projectRootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fileURL = projectRootURL
            .appendingPathComponent("TahoePaste")
            .appendingPathComponent("\(localeIdentifier).lproj")
            .appendingPathComponent("Localizable.strings")
        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        let pattern = try NSRegularExpression(pattern: #"^"([^"]+)"\s*=\s*"((?:[^"\\]|\\.)*)";"#, options: [.anchorsMatchLines])
        let range = NSRange(contents.startIndex..<contents.endIndex, in: contents)
        var entries: [String: String] = [:]

        for match in pattern.matches(in: contents, options: [], range: range) {
            guard let keyRange = Range(match.range(at: 1), in: contents),
                  let valueRange = Range(match.range(at: 2), in: contents) else {
                continue
            }

            entries[String(contents[keyRange])] = String(contents[valueRange])
        }

        return entries
    }
}
