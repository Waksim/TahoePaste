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

        let restoredHistory = try HistoryRepository(storageManager: storageManager).readSnapshot()
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
        let restored = try HistoryRepository(storageManager: secondManager).readSnapshot()

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

    func testAutomaticOverlayLayoutFollowsCardSizePreset() {
        for preset in SettingsManager.CardSizePreset.allCases {
            let layout = SettingsManager.OverlayLayout.automatic(for: preset)

            XCTAssertEqual(layout.topBarHeight, 31)
            XCTAssertEqual(layout.bottomInset, 31)
            XCTAssertEqual(layout.cardSpacing, 16)
            XCTAssertEqual(layout.toolbarIconSize, 10)
            XCTAssertEqual(layout.toolbarIconPadding, 4)
            XCTAssertEqual(layout.toolbarIconSpacing, 8)
            XCTAssertEqual(layout.toolbarVerticalOffset, 0)
            XCTAssertEqual(layout.searchBubbleWidth, 480)
            XCTAssertEqual(layout.searchBubbleHeight, 30)
            XCTAssertEqual(layout.searchBubbleHorizontalOffset, 0)
            XCTAssertEqual(layout.searchBubbleVerticalOffset, 0)
            XCTAssertEqual(layout.contentPadding, preset.contentPadding)
            XCTAssertEqual(layout.totalCardHeight, preset.cardHeight + preset.contentPadding * 2)
            XCTAssertEqual(layout.overlayHeight, 31 + preset.cardHeight + preset.contentPadding * 2 + 31)
            XCTAssertEqual(layout.overlayScreenHorizontalInset, 0)
            XCTAssertEqual(layout.overlayScreenBottomInset, 0)
        }
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

    func testStorageManagerStoresDownscaledPreviewForSingleImageFilePayload() throws {
        let storageManager = StorageManager(rootDirectoryURL: makeTemporaryDirectory())
        let image = makeImage(size: NSSize(width: 1600, height: 800), color: .systemTeal)
        let fileURL = makeTemporaryDirectory().appendingPathComponent("Photo.png")
        try StorageManager.pngData(from: image).write(to: fileURL)

        let item = try storageManager.store(payload: .fileURLs([fileURL]))
        let preview = try XCTUnwrap(storageManager.loadImage(for: item))

        XCTAssertEqual(item.kind, .file)
        XCTAssertNotNil(item.imageFilename)
        XCTAssertEqual(item.pixelSize, ClipboardPixelSize(width: 1600, height: 800))
        XCTAssertFalse(item.usesTextCardLayout)
        XCTAssertEqual(StorageManager.pixelSize(from: preview), ClipboardPixelSize(width: 800, height: 400))
        XCTAssertTrue(item.tags.contains(.image))
    }

    func testStorageManagerSkipsImagePreviewForMultipleFilePayloads() throws {
        let storageManager = StorageManager(rootDirectoryURL: makeTemporaryDirectory())
        let directory = makeTemporaryDirectory()
        let imageFileURL = directory.appendingPathComponent("Photo.png")
        let textFileURL = directory.appendingPathComponent("Readme.txt")
        try StorageManager.pngData(from: makeImage(size: NSSize(width: 40, height: 40), color: .systemPink)).write(to: imageFileURL)
        FileManager.default.createFile(atPath: textFileURL.path, contents: Data("hello".utf8))

        let item = try storageManager.store(payload: .fileURLs([imageFileURL, textFileURL]))

        XCTAssertNil(item.imageFilename)
        XCTAssertNil(item.pixelSize)
        XCTAssertTrue(item.usesTextCardLayout)
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

    func testSearchDocumentIndexesHeadAndTailOfLargeText() {
        let headPadding = String(repeating: "a", count: ClipboardSearchEngine.indexedHeadCharacterCount)
        let tailPadding = String(repeating: "b", count: ClipboardSearchEngine.indexedTailCharacterCount + 1_000)

        let headItem = makeTextItem("zebrafish " + headPadding + tailPadding)
        let headDocument = ClipboardSearchEngine.makeDocument(for: headItem)
        XCTAssertEqual(ClipboardSearchEngine.matches(documents: [headDocument], query: "zebrafish"), [headItem.id])

        let tailItem = makeTextItem(headPadding + tailPadding + " zebrafish")
        let tailDocument = ClipboardSearchEngine.makeDocument(for: tailItem)
        XCTAssertEqual(ClipboardSearchEngine.matches(documents: [tailDocument], query: "zebrafish"), [tailItem.id])

        let middleItem = makeTextItem(headPadding + " zebrafish " + tailPadding)
        let middleDocument = ClipboardSearchEngine.makeDocument(for: middleItem)
        XCTAssertTrue(ClipboardSearchEngine.matches(documents: [middleDocument], query: "zebrafish").isEmpty)
    }

    func testSearchRanksWordBoundaryMatchesAboveSubstringMatches() {
        let boundaryItem = makeTextItem("rebar bar fittings")
        let substringItem = makeTextItem("crowbars", age: -1)

        let matches = ClipboardSearchEngine.matches(for: [substringItem, boundaryItem], query: "bar")

        XCTAssertEqual(matches.map(\.id), [boundaryItem.id, substringItem.id])
    }

    func testClipboardTagCacheMatchesDirectClassification() {
        let item = makeTextItem("Contact me at user@example.com")

        var expectedTags = [item.kind.primaryTag]
        for tag in ClipboardContentClassifier.detectedTags(for: item.text ?? "") where expectedTags.contains(tag) == false {
            expectedTags.append(tag)
        }

        XCTAssertEqual(item.tags, expectedTags)
        XCTAssertEqual(item.tags, expectedTags)

        ClipboardTagCache.removeTags(forItemIDs: [item.id])
        XCTAssertEqual(item.tags, expectedTags)
    }

    @MainActor
    func testViewModelSearchPipelinePublishesFilteredResults() async {
        let viewModel = ClipboardHistoryViewModel(
            storageManager: StorageManager(rootDirectoryURL: makeTemporaryDirectory()),
            settingsManager: SettingsManager.shared
        )
        viewModel.searchDebounceInterval = .zero

        let apple = makeTextItem("Apple pie recipe")
        let banana = makeTextItem("Banana split", age: -1)
        let cherry = makeTextItem("Cherry cake", age: -2)

        viewModel.replaceHistory(with: [apple, banana, cherry])
        XCTAssertEqual(viewModel.visibleItems.map(\.id), [apple.id, banana.id, cherry.id])

        viewModel.appendSearchCharacter("banana")
        await viewModel.waitForPendingSearchWork()
        XCTAssertEqual(viewModel.visibleItems.map(\.id), [banana.id])

        viewModel.replaceHistory(with: [apple, cherry])
        await viewModel.waitForPendingSearchWork()
        XCTAssertTrue(viewModel.visibleItems.isEmpty)

        viewModel.clearSearch()
        await viewModel.waitForPendingSearchWork()
        XCTAssertEqual(viewModel.visibleItems.map(\.id), [apple.id, cherry.id])
    }

    @MainActor
    func testOverlaySessionAnchorSurvivesPresentationReset() {
        let viewModel = ClipboardHistoryViewModel(
            storageManager: StorageManager(rootDirectoryURL: makeTemporaryDirectory()),
            settingsManager: SettingsManager.shared
        )

        let apple = makeTextItem("Apple pie recipe")
        let banana = makeTextItem("Banana split", age: -1)
        let cherry = makeTextItem("Cherry cake", age: -2)
        viewModel.replaceHistory(with: [apple, banana, cherry])

        viewModel.currentScrollAnchorID = cherry.id
        viewModel.captureSessionAnchor()

        let previousPresentationID = viewModel.overlayPresentationID
        viewModel.prepareForOverlayPresentation()
        XCTAssertNotEqual(viewModel.overlayPresentationID, previousPresentationID)
        XCTAssertEqual(viewModel.sessionReturnTargetID, cherry.id)

        viewModel.currentScrollAnchorID = apple.id
        viewModel.captureSessionAnchor()
        XCTAssertNil(viewModel.sessionReturnTargetID)

        viewModel.currentScrollAnchorID = cherry.id
        viewModel.captureSessionAnchor()
        viewModel.replaceHistory(with: [apple, banana])
        XCTAssertNil(viewModel.sessionReturnTargetID)
    }

    @MainActor
    func testOverlayWindowControllerResetsOnShowAndCapturesAnchorOnHide() {
        let viewModel = ClipboardHistoryViewModel(
            storageManager: StorageManager(rootDirectoryURL: makeTemporaryDirectory()),
            settingsManager: SettingsManager.shared
        )
        let controller = OverlayWindowController(
            viewModel: viewModel,
            settingsManager: SettingsManager.shared
        )

        let apple = makeTextItem("Apple pie recipe")
        let banana = makeTextItem("Banana split", age: -1)
        viewModel.replaceHistory(with: [apple, banana])

        let previousPresentationID = viewModel.overlayPresentationID
        controller.show(on: nil)
        XCTAssertNotEqual(viewModel.overlayPresentationID, previousPresentationID)

        viewModel.currentScrollAnchorID = banana.id
        controller.hide()
        XCTAssertEqual(viewModel.lastSessionAnchorID, banana.id)

        controller.showPreview(on: nil)
        viewModel.currentScrollAnchorID = apple.id
        controller.hide()
        XCTAssertEqual(viewModel.lastSessionAnchorID, banana.id)
    }

    func testSingleCharacterSearchOverLargeHistoryStaysFast() {
        var items: [ClipboardItem] = []
        items.reserveCapacity(3_001)

        for index in 0..<3_000 {
            let text: String
            switch index % 5 {
            case 0:
                text = "Meeting with the team on 12.03.2026 14:30 about release \(index)"
            case 1:
                text = "Contact: user\(index)@example.com, phone +1 (415) 555-0\(String(format: "%03d", index % 1_000))"
            case 2:
                text = "https://example.com/articles/\(index)/how-to-optimize-search"
            case 3:
                text = "func compute\(index)() { return value * \(index) } // sample snippet"
            default:
                text = "Random note number \(index) with some plain content to search through"
            }

            items.append(makeTextItem(text, age: -TimeInterval(index)))
        }

        items.append(makeTextItem(String(repeating: "log line with assorted details to scan ", count: 40_000)))

        let clock = ContinuousClock()

        var documents: [ClipboardSearchEngine.SearchDocument] = []
        let buildDuration = clock.measure {
            documents = items.map(ClipboardSearchEngine.makeDocument)
        }

        var matchedIDs: [UUID] = []
        let searchDuration = clock.measure {
            matchedIDs = ClipboardSearchEngine.matches(documents: documents, query: "e")
        }

        print("Search index build for \(items.count) items took \(buildDuration); single-character search took \(searchDuration)")

        XCTAssertFalse(matchedIDs.isEmpty)
        XCTAssertLessThan(searchDuration, .seconds(1))
    }

    private func makeTextItem(_ text: String, age: TimeInterval = 0) -> ClipboardItem {
        ClipboardItem(
            id: UUID(),
            kind: .text,
            createdAt: Date().addingTimeInterval(age),
            text: text,
            textPreview: ClipboardItem.previewText(from: text),
            imageFilename: nil,
            pixelSize: nil,
            fileReferences: nil
        )
    }

    // MARK: - HistoryRepository

    func testReadSnapshotDoesNotDeleteUnreferencedImagesOrRewriteHistory() throws {
        let rootDirectory = makeTemporaryDirectory()
        let storageManager = StorageManager(rootDirectoryURL: rootDirectory)
        let repository = HistoryRepository(storageManager: storageManager)

        let textItem = try storageManager.store(payload: .text("existing note"))
        try storageManager.saveHistory([textItem])

        // Simulates the capture window: the app already wrote the PNG but has
        // not referenced it from history.json yet.
        let freshImageItem = try storageManager.store(payload: .image(makeImage(size: NSSize(width: 32, height: 32), color: .systemRed)))
        let freshImageURL = try XCTUnwrap(storageManager.imageURL(for: freshImageItem))
        XCTAssertTrue(FileManager.default.fileExists(atPath: freshImageURL.path))

        let historyFileURL = rootDirectory.appendingPathComponent("history.json")
        let historyBeforeRead = try Data(contentsOf: historyFileURL)

        let snapshot = try repository.readSnapshot()

        XCTAssertEqual(snapshot.map(\.id), [textItem.id])
        XCTAssertTrue(FileManager.default.fileExists(atPath: freshImageURL.path))
        XCTAssertEqual(try Data(contentsOf: historyFileURL), historyBeforeRead)
    }

    func testRepositoryInterleavedMutationsDoNotLoseItems() throws {
        let rootDirectory = makeTemporaryDirectory()
        let firstRepository = HistoryRepository(storageManager: StorageManager(rootDirectoryURL: rootDirectory))
        let secondRepository = HistoryRepository(storageManager: StorageManager(rootDirectoryURL: rootDirectory))

        let first = try firstRepository.append(payload: .text("item A"), historyLimit: nil)
        _ = try secondRepository.append(payload: .text("item B"), historyLimit: nil)

        let outcome = try firstRepository.delete(id: first.item.id)

        XCTAssertTrue(outcome.removedItem)
        XCTAssertEqual(outcome.history.compactMap(\.text), ["item B"])
        XCTAssertEqual(try secondRepository.readSnapshot().compactMap(\.text), ["item B"])
    }

    func testAppendDeduplicatesIdenticalNewestText() throws {
        let repository = HistoryRepository(storageManager: StorageManager(rootDirectoryURL: makeTemporaryDirectory()))

        let first = try repository.append(payload: .text("same text"), historyLimit: nil)
        let second = try repository.append(payload: .text("same text"), historyLimit: nil)

        XCTAssertFalse(first.wasDeduplicated)
        XCTAssertTrue(second.wasDeduplicated)
        XCTAssertEqual(second.item.id, first.item.id)
        XCTAssertEqual(try repository.readSnapshot().count, 1)
    }

    func testAppendAppliesHistoryLimit() throws {
        let repository = HistoryRepository(storageManager: StorageManager(rootDirectoryURL: makeTemporaryDirectory()))

        for index in 0..<5 {
            _ = try repository.append(payload: .text("note \(index)"), historyLimit: 3)
        }

        let snapshot = try repository.readSnapshot()
        XCTAssertEqual(snapshot.count, 3)
        XCTAssertEqual(snapshot.first?.text, "note 4")
    }

    func testRepositoryDeleteRemovesOrphanedImage() throws {
        let rootDirectory = makeTemporaryDirectory()
        let storageManager = StorageManager(rootDirectoryURL: rootDirectory)
        let repository = HistoryRepository(storageManager: storageManager)

        let outcome = try repository.append(
            payload: .image(makeImage(size: NSSize(width: 24, height: 24), color: .systemTeal)),
            historyLimit: nil
        )
        let imageURL = try XCTUnwrap(storageManager.imageURL(for: outcome.item))
        XCTAssertTrue(FileManager.default.fileExists(atPath: imageURL.path))

        _ = try repository.delete(id: outcome.item.id)

        XCTAssertFalse(FileManager.default.fileExists(atPath: imageURL.path))
        XCTAssertTrue(try repository.readSnapshot().isEmpty)
    }

    // MARK: - Persisted tags

    func testStoreComputesAndPersistsTags() throws {
        let rootDirectory = makeTemporaryDirectory()
        let storageManager = StorageManager(rootDirectoryURL: rootDirectory)

        let item = try storageManager.store(payload: .text("password: hunter2!Aa"))
        try storageManager.saveHistory([item])

        XCTAssertEqual(item.tagsVersion, ClipboardTagCache.currentVersion)
        XCTAssertEqual(item.storedTags?.contains(.password), true)

        let rawHistory = try String(contentsOf: rootDirectory.appendingPathComponent("history.json"), encoding: .utf8)
        XCTAssertTrue(rawHistory.contains("\"tags\""))
        XCTAssertTrue(rawHistory.contains("\"tagsVersion\""))
    }

    func testRepairAndMigrateAddsTagsToLegacyItems() throws {
        let rootDirectory = makeTemporaryDirectory()
        let storageManager = StorageManager(rootDirectoryURL: rootDirectory)
        let repository = HistoryRepository(storageManager: storageManager)

        let legacyItem = ClipboardItem(
            id: UUID(),
            kind: .link,
            createdAt: .now,
            text: "https://example.com",
            textPreview: "https://example.com",
            imageFilename: nil,
            pixelSize: nil,
            fileReferences: nil
        )
        try storageManager.saveHistory([legacyItem])

        let migrated = try repository.repairAndMigrate()

        XCTAssertEqual(migrated.first?.storedTags?.first, .link)
        XCTAssertEqual(migrated.first?.tagsVersion, ClipboardTagCache.currentVersion)

        let reloaded = try storageManager.decodeHistory()
        XCTAssertEqual(reloaded.first?.storedTags?.first, .link)
    }

    func testRepairAndMigrateRecomputesOutdatedTagsVersion() throws {
        let rootDirectory = makeTemporaryDirectory()
        let storageManager = StorageManager(rootDirectoryURL: rootDirectory)
        let repository = HistoryRepository(storageManager: storageManager)

        let outdatedItem = ClipboardItem(
            id: UUID(),
            kind: .link,
            createdAt: .now,
            text: "https://example.com",
            textPreview: "https://example.com",
            imageFilename: nil,
            pixelSize: nil,
            fileReferences: nil,
            storedTags: [.text],
            tagsVersion: 0
        )
        try storageManager.saveHistory([outdatedItem])

        let migrated = try repository.repairAndMigrate()

        XCTAssertEqual(migrated.first?.storedTags?.first, .link)
        XCTAssertEqual(migrated.first?.tagsVersion, ClipboardTagCache.currentVersion)
    }

    func testClipboardItemTagsFallBackToResolverWhenStoredTagsAreNil() {
        let item = ClipboardItem(
            id: UUID(),
            kind: .text,
            createdAt: .now,
            text: "mail me at someone@example.com",
            textPreview: nil,
            imageFilename: nil,
            pixelSize: nil,
            fileReferences: nil
        )

        XCTAssertNil(item.storedTags)
        XCTAssertTrue(item.tags.contains(.email))
    }

    // MARK: - AgentQueryService

    private func makeAgentService() throws -> (AgentQueryService, HistoryRepository) {
        let storageManager = StorageManager(rootDirectoryURL: makeTemporaryDirectory())
        let repository = HistoryRepository(storageManager: storageManager)
        return (AgentQueryService(repository: repository, storageManager: storageManager), repository)
    }

    func testAgentQueryServiceExcludesSensitiveItemsByDefault() throws {
        let (service, repository) = try makeAgentService()
        _ = try repository.append(payload: .text("plain note"), historyLimit: nil)
        _ = try repository.append(payload: .text("Password: Str0ng!Pass2026"), historyLimit: nil)

        let hidden = try service.recent(limit: 10, includeSensitive: false)
        XCTAssertEqual(hidden.items.count, 1)
        XCTAssertEqual(hidden.totalItems, 1)
        XCTAssertEqual(hidden.sensitiveExcluded, 1)
        XCTAssertEqual(hidden.items.first?.preview, "plain note")

        let revealed = try service.recent(limit: 10, includeSensitive: true)
        XCTAssertEqual(revealed.items.count, 2)
        XCTAssertEqual(revealed.sensitiveExcluded, 0)
        XCTAssertTrue(revealed.items.contains(where: { $0.isSensitive }))
    }

    func testAgentDetailBlocksSecretBeyondClassifierAnalysisCap() throws {
        let (service, repository) = try makeAgentService()
        let padding = String(repeating: "lorem ipsum dolor sit amet ", count: 200)
        let outcome = try repository.append(
            payload: .text(padding + "\nAuthorization: Bearer sk_live_1234567890ABCDEF"),
            historyLimit: nil
        )

        // The persisted tags miss the secret (it sits past the 4000-char cap),
        // so the item is visible in listings...
        XCTAssertFalse(AgentQueryService.isSensitive(outcome.item))

        // ...but the single-item full-text re-check refuses to hand it out.
        XCTAssertThrowsError(try service.detail(id: outcome.item.id, full: true, includeSensitive: false)) { error in
            guard case AgentQueryService.QueryError.sensitiveItem = error else {
                return XCTFail("Expected sensitiveItem, got \(error)")
            }
        }

        let revealed = try service.detail(id: outcome.item.id, full: true, includeSensitive: true)
        XCTAssertEqual(revealed.text?.contains("sk_live_"), true)
    }

    func testAgentSearchAppliesKindTagSinceAndLimitFilters() throws {
        let (service, repository) = try makeAgentService()
        _ = try repository.append(payload: .text("meeting notes about lorem"), historyLimit: nil)
        _ = try repository.append(payload: .text("https://lorem.example.com"), historyLimit: nil)

        let linksOnly = try service.search(
            query: "lorem",
            kind: .link,
            tag: nil,
            since: nil,
            limit: 10,
            includeSensitive: false
        )
        XCTAssertEqual(linksOnly.items.map(\.kind), ["link"])

        let tagged = try service.search(
            query: "",
            kind: nil,
            tag: .link,
            since: nil,
            limit: 10,
            includeSensitive: false
        )
        XCTAssertEqual(tagged.items.count, 1)

        let futureOnly = try service.search(
            query: "",
            kind: nil,
            tag: nil,
            since: Date().addingTimeInterval(3_600),
            limit: 10,
            includeSensitive: false
        )
        XCTAssertTrue(futureOnly.items.isEmpty)

        let limited = try service.search(
            query: "",
            kind: nil,
            tag: nil,
            since: nil,
            limit: 1,
            includeSensitive: false
        )
        XCTAssertEqual(limited.items.count, 1)
        XCTAssertEqual(limited.totalItems, 2)
    }

    func testAgentDetailReturnsFullTextOnlyWhenRequestedAndTruncatesHugeText() throws {
        let (service, repository) = try makeAgentService()
        let hugeText = String(repeating: "x", count: AgentQueryService.maxFullTextCharacters + 5)
        let outcome = try repository.append(payload: .text(hugeText), historyLimit: nil)

        let preview = try service.detail(id: outcome.item.id, full: false, includeSensitive: false)
        XCTAssertNil(preview.text)
        XCTAssertNotNil(preview.preview)

        let full = try service.detail(id: outcome.item.id, full: true, includeSensitive: false)
        XCTAssertEqual(full.text?.count, AgentQueryService.maxFullTextCharacters)
        XCTAssertEqual(full.truncated, true)
        XCTAssertEqual(full.totalChars, hugeText.count)
    }

    func testAgentSinceParsingAcceptsRelativeAndISOFormats() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(AgentQueryService.parseSince("30m", now: now), now.addingTimeInterval(-1_800))
        XCTAssertEqual(AgentQueryService.parseSince("2h", now: now), now.addingTimeInterval(-7_200))
        XCTAssertEqual(AgentQueryService.parseSince("7d", now: now), now.addingTimeInterval(-604_800))
        XCTAssertNotNil(AgentQueryService.parseSince("2026-07-01T00:00:00Z"))
        XCTAssertNil(AgentQueryService.parseSince("tomorrow"))
    }

    // MARK: - AgentCommand parsing

    func testAgentCommandParsesAllCommands() throws {
        let id = UUID()

        XCTAssertEqual(
            try AgentCommand.parse(["recent", "--limit", "5", "--include-sensitive"]),
            .recent(limit: 5, includeSensitive: true)
        )
        XCTAssertEqual(
            try AgentCommand.parse(["search", "invoice", "--kind", "link", "--tag", "pdf", "--since", "7d"]),
            .search(query: "invoice", kind: .link, tag: .pdf, sinceRaw: "7d", limit: 10, includeSensitive: false)
        )
        XCTAssertEqual(
            try AgentCommand.parse(["get", id.uuidString, "--full"]),
            .get(id: id, full: true, includeSensitive: false)
        )
        XCTAssertEqual(try AgentCommand.parse(["image", id.uuidString]), .image(id: id))
        XCTAssertEqual(try AgentCommand.parse(["copy", id.uuidString]), .copy(id: id, includeSensitive: false))
        XCTAssertEqual(try AgentCommand.parse(["add", "hello"]), .add(text: "hello"))
        XCTAssertEqual(try AgentCommand.parse(["add"]), .add(text: nil))
        XCTAssertEqual(try AgentCommand.parse(["delete", id.uuidString]), .delete(id: id))
        XCTAssertEqual(try AgentCommand.parse(["--help"]), .help)
        XCTAssertEqual(try AgentCommand.parse(["--version"]), .version)
    }

    func testAgentCommandRejectsInvalidInput() {
        XCTAssertThrowsError(try AgentCommand.parse([]))
        XCTAssertThrowsError(try AgentCommand.parse(["frobnicate"]))
        XCTAssertThrowsError(try AgentCommand.parse(["recent", "--limit", "0"]))
        XCTAssertThrowsError(try AgentCommand.parse(["recent", "--limit", "abc"]))
        XCTAssertThrowsError(try AgentCommand.parse(["recent", "--frobnicate"]))
        XCTAssertThrowsError(try AgentCommand.parse(["search"]))
        XCTAssertThrowsError(try AgentCommand.parse(["get", "not-a-uuid"]))
        XCTAssertThrowsError(try AgentCommand.parse(["delete"]))
    }

    func testAgentCommandClampsOversizedLimit() throws {
        XCTAssertEqual(
            try AgentCommand.parse(["recent", "--limit", "1000000000"]),
            .recent(limit: AgentQueryService.maxLimit, includeSensitive: false)
        )
    }

    // MARK: - AgentManifest

    func testAgentManifestRoundTripsAndFailsClosed() throws {
        let rootDirectory = makeTemporaryDirectory()

        XCTAssertNil(AgentManifest.read(from: rootDirectory))

        let manifest = AgentManifest(
            schemaVersion: AgentManifest.currentSchemaVersion,
            appVersion: "0.3.0",
            platform: "macos",
            cliPath: "/Applications/TahoePaste.app/Contents/MacOS/tahoepaste-cli",
            enabled: false,
            updatedAt: .now
        )
        try manifest.write(to: rootDirectory)

        let restored = try XCTUnwrap(AgentManifest.read(from: rootDirectory))
        XCTAssertFalse(restored.enabled)
        XCTAssertEqual(restored.cliPath, manifest.cliPath)

        try Data("not json".utf8).write(to: AgentManifest.fileURL(in: rootDirectory))
        XCTAssertNil(AgentManifest.read(from: rootDirectory))
    }

    // MARK: - PasteboardItemWriter

    func testPasteboardItemWriterWritesTextAndImage() throws {
        let storageManager = StorageManager(rootDirectoryURL: makeTemporaryDirectory())
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("tahoepaste-tests-\(UUID().uuidString)"))

        let textItem = try storageManager.store(payload: .text("restored text"))
        _ = try PasteboardItemWriter.write(textItem, storageManager: storageManager, pasteboard: pasteboard)
        XCTAssertEqual(pasteboard.string(forType: .string), "restored text")

        let imageItem = try storageManager.store(payload: .image(makeImage(size: NSSize(width: 20, height: 20), color: .systemPink)))
        _ = try PasteboardItemWriter.write(imageItem, storageManager: storageManager, pasteboard: pasteboard)
        XCTAssertTrue(pasteboard.canReadObject(forClasses: [NSImage.self], options: nil))
    }

    func testPasteboardItemWriterFailurePreservesExistingClipboard() throws {
        let storageManager = StorageManager(rootDirectoryURL: makeTemporaryDirectory())
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("tahoepaste-tests-\(UUID().uuidString)"))

        pasteboard.clearContents()
        pasteboard.setString("precious clipboard", forType: .string)

        let imageItem = try storageManager.store(payload: .image(makeImage(size: NSSize(width: 20, height: 20), color: .systemBrown)))
        let imageURL = try XCTUnwrap(storageManager.imageURL(for: imageItem))
        try FileManager.default.removeItem(at: imageURL)

        XCTAssertThrowsError(
            try PasteboardItemWriter.write(imageItem, storageManager: storageManager, pasteboard: pasteboard)
        )
        XCTAssertEqual(pasteboard.string(forType: .string), "precious clipboard")
    }

    func testPasteboardItemWriterRestoresExistingFilesAndReportsMissingOnes() throws {
        let storageManager = StorageManager(rootDirectoryURL: makeTemporaryDirectory())
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("tahoepaste-tests-\(UUID().uuidString)"))

        let scratchDirectory = makeTemporaryDirectory()
        let existingFileURL = scratchDirectory.appendingPathComponent("kept.txt")
        let missingFileURL = scratchDirectory.appendingPathComponent("gone.txt")
        try Data("kept".utf8).write(to: existingFileURL)
        try Data("gone".utf8).write(to: missingFileURL)

        let item = try storageManager.store(payload: .fileURLs([existingFileURL, missingFileURL]))
        try FileManager.default.removeItem(at: missingFileURL)

        let result = try PasteboardItemWriter.write(item, storageManager: storageManager, pasteboard: pasteboard)

        XCTAssertEqual(result.restoredFilePaths, [existingFileURL.path])
        XCTAssertEqual(result.missingFilePaths, [missingFileURL.path])
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
