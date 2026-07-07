import AppKit
import Foundation

@MainActor
final class ClipboardHistoryViewModel: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []
    @Published private(set) var visibleItems: [ClipboardItem] = []
    @Published private(set) var searchQuery = ""
    @Published private(set) var isSearchInterfaceVisible = false
    @Published private(set) var activeTagFilter: ClipboardTag?
    @Published private(set) var isAccessibilityTrusted = false
    @Published private(set) var hotkeyStatusMessage: String
    @Published private(set) var statusMessage: String?
    @Published private(set) var storageUsageLabel: String
    @Published private(set) var overlayPresentationID = UUID()

    var onSelectItem: ((ClipboardItem) -> Void)?
    var onDeleteItem: ((ClipboardItem) -> Void)?
    var onShowOverlay: (() -> Void)?
    var onHideOverlay: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onOpenAccessibilitySettings: (() -> Void)?
    var onRequestAccessibilityPermission: (() -> Void)?
    var onClearHistory: (() -> Void)?
    var onRevealStorageInFinder: (() -> Void)?
    var onQuit: (() -> Void)?

    private let storageManager: StorageManager
    private let settingsManager: SettingsManager
    private let imageCache = NSCache<NSString, NSImage>()
    private var searchDocuments: [UUID: ClipboardSearchEngine.SearchDocument] = [:]
    private var indexBuildTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?

    var searchDebounceInterval: Duration = .milliseconds(150)

    init(storageManager: StorageManager, settingsManager: SettingsManager) {
        self.storageManager = storageManager
        self.settingsManager = settingsManager
        self.hotkeyStatusMessage = L10n.tr("status.hotkey_unavailable")
        self.storageUsageLabel = storageManager.formattedStorageUsage()
    }

    var currentHistory: [ClipboardItem] {
        items
    }

    var isSearching: Bool {
        searchQuery.isEmpty == false
    }

    var isSearchUIVisible: Bool {
        isSearchInterfaceVisible || isSearching
    }

    var isSearchBubbleVisible: Bool {
        isSearchUIVisible || activeTagFilter != nil
    }

    var searchDisplayText: String {
        let parts = [
            activeTagFilter.map { L10n.tr($0.titleKey) },
            searchQuery.isEmpty ? nil : searchQuery
        ].compactMap { $0 }

        guard parts.isEmpty == false else {
            return L10n.tr("overlay.search_placeholder")
        }

        return parts.joined(separator: " · ")
    }

    var historyCountLabel: String {
        L10n.tr("unit.items", items.count)
    }

    var savedItemsStatusLabel: String {
        L10n.tr("unit.items_saved", items.count)
    }

    var monitoringStatusLabel: String {
        settingsManager.monitoringStatusText
    }

    var maximumHistoryItemsLabel: String {
        settingsManager.hasUnlimitedHistory
            ? L10n.tr("common.unlimited")
            : L10n.tr("unit.items", settingsManager.maximumHistoryItems)
    }

    var applicationSupportPath: String {
        storageManager.rootDirectoryURL.path
    }

    var accessibilityBannerText: String {
        if isAccessibilityTrusted {
            return L10n.tr("accessibility.enabled_banner")
        }

        return L10n.tr("accessibility.disabled_banner")
    }

    func replaceHistory(with newItems: [ClipboardItem]) {
        items = newItems.sorted(by: { $0.createdAt > $1.createdAt })
        refreshStorageUsage()
        updateSearchIndex()
        refreshVisibleItems(debounced: false)
    }

    func prepend(_ item: ClipboardItem) {
        items.insert(item, at: 0)
        refreshStorageUsage()
        updateSearchIndex()
        refreshVisibleItems(debounced: false)
    }

    func appendSearchCharacter(_ character: String) {
        guard character.isEmpty == false else {
            return
        }

        isSearchInterfaceVisible = true
        searchQuery.append(contentsOf: character)
        refreshVisibleItems(debounced: true)
    }

    func removeLastSearchCharacter() {
        guard searchQuery.isEmpty == false else {
            return
        }

        searchQuery.removeLast()

        if searchQuery.isEmpty {
            isSearchInterfaceVisible = false
        }

        refreshVisibleItems(debounced: true)
    }

    func clearSearch() {
        guard isSearchInterfaceVisible || searchQuery.isEmpty == false else {
            return
        }

        searchQuery.removeAll()
        isSearchInterfaceVisible = false
        refreshVisibleItems(debounced: false)
    }

    func toggleTagFilter(_ tag: ClipboardTag) {
        activeTagFilter = activeTagFilter == tag ? nil : tag
        refreshVisibleItems(debounced: false)
    }

    func isFiltering(by tag: ClipboardTag) -> Bool {
        activeTagFilter == tag
    }

    func clearTransientState() {
        clearSearch()

        if activeTagFilter != nil {
            activeTagFilter = nil
            refreshVisibleItems(debounced: false)
        }
    }

    func beginSearch() {
        guard isSearchInterfaceVisible == false else {
            return
        }

        isSearchInterfaceVisible = true
    }

    func dismissSearchInterface() {
        guard isSearchInterfaceVisible else {
            return
        }

        isSearchInterfaceVisible = false
    }

    func image(for item: ClipboardItem) -> NSImage? {
        guard let filename = item.imageFilename as NSString? else {
            return nil
        }

        if let cachedImage = imageCache.object(forKey: filename) {
            return cachedImage
        }

        guard let image = storageManager.loadImage(for: item) else {
            return nil
        }

        imageCache.setObject(image, forKey: filename)
        return image
    }

    func select(_ item: ClipboardItem) {
        onSelectItem?(item)
    }

    func delete(_ item: ClipboardItem) {
        onDeleteItem?(item)
    }

    func showOverlay() {
        clearTransientState()
        overlayPresentationID = UUID()
        onShowOverlay?()
    }

    func hideOverlay() {
        clearTransientState()
        onHideOverlay?()
    }

    func openSettings() {
        onOpenSettings?()
    }

    func openAccessibilitySettings() {
        onOpenAccessibilitySettings?()
    }

    func requestAccessibilityAccess() {
        onRequestAccessibilityPermission?()
    }

    func clearHistory() {
        onClearHistory?()
    }

    func revealStorageInFinder() {
        onRevealStorageInFinder?()
    }

    func quit() {
        onQuit?()
    }

    func setAccessibilityTrusted(_ trusted: Bool) {
        guard isAccessibilityTrusted != trusted else {
            return
        }

        isAccessibilityTrusted = trusted
    }

    func setHotkeyAvailability(_ message: String) {
        guard hotkeyStatusMessage != message else {
            return
        }

        hotkeyStatusMessage = message
    }

    func setStatusMessage(_ message: String?) {
        guard statusMessage != message else {
            return
        }

        statusMessage = message
    }

    func refreshStorageUsage() {
        let updatedLabel = storageManager.formattedStorageUsage()
        guard storageUsageLabel != updatedLabel else {
            return
        }

        storageUsageLabel = updatedLabel
    }

    func waitForPendingSearchWork() async {
        await indexBuildTask?.value
        await searchTask?.value
    }

    private func updateSearchIndex() {
        let currentIDs = Set(items.map(\.id))
        let removedIDs = searchDocuments.keys.filter { currentIDs.contains($0) == false }

        for removedID in removedIDs {
            searchDocuments.removeValue(forKey: removedID)
        }
        ClipboardTagCache.removeTags(forItemIDs: removedIDs)

        let unindexedItems = items.filter { searchDocuments[$0.id] == nil }
        guard unindexedItems.isEmpty == false else {
            return
        }

        indexBuildTask?.cancel()
        indexBuildTask = Task { [weak self] in
            guard let documents = await Self.buildDocuments(for: unindexedItems) else {
                return
            }

            guard let self, Task.isCancelled == false else {
                return
            }

            let liveIDs = Set(self.items.map(\.id))
            for document in documents where liveIDs.contains(document.itemID) {
                self.searchDocuments[document.itemID] = document
            }
        }
    }

    private func refreshVisibleItems(debounced: Bool) {
        searchTask?.cancel()

        let query = searchQuery
        let tagFilter = activeTagFilter
        let snapshotItems = items

        // Empty query without a tag filter is the whole history — publish
        // immediately so opening the overlay never waits on the pipeline.
        if query.isEmpty, tagFilter == nil {
            searchTask = nil
            visibleItems = snapshotItems
            return
        }

        let documents = searchDocuments
        let debounceInterval = debounced ? searchDebounceInterval : Duration.zero

        searchTask = Task { [weak self] in
            if debounceInterval > .zero {
                try? await Task.sleep(for: debounceInterval)

                guard Task.isCancelled == false else {
                    return
                }
            }

            let result = await Self.computeVisibleItems(
                items: snapshotItems,
                documents: documents,
                query: query,
                tagFilter: tagFilter
            )

            guard let self, Task.isCancelled == false else {
                return
            }

            self.visibleItems = result
        }
    }

    nonisolated private static func buildDocuments(
        for items: [ClipboardItem]
    ) async -> [ClipboardSearchEngine.SearchDocument]? {
        var documents: [ClipboardSearchEngine.SearchDocument] = []
        documents.reserveCapacity(items.count)

        for item in items {
            guard Task.isCancelled == false else {
                return nil
            }

            documents.append(ClipboardSearchEngine.makeDocument(for: item))
        }

        return documents
    }

    nonisolated private static func computeVisibleItems(
        items: [ClipboardItem],
        documents: [UUID: ClipboardSearchEngine.SearchDocument],
        query: String,
        tagFilter: ClipboardTag?
    ) async -> [ClipboardItem] {
        var candidates = items

        if let tagFilter {
            candidates = candidates.filter { $0.tags.contains(tagFilter) }
        }

        guard query.isEmpty == false else {
            return candidates
        }

        // Items copied after the last index build are indexed on the fly; their
        // detected tags stay in ClipboardTagCache, so the work isn't repeated.
        let candidateDocuments = candidates.map { item in
            documents[item.id] ?? ClipboardSearchEngine.makeDocument(for: item)
        }

        let orderedIDs = ClipboardSearchEngine.matches(documents: candidateDocuments, query: query)
        let itemsByID = Dictionary(candidates.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return orderedIDs.compactMap { itemsByID[$0] }
    }
}
