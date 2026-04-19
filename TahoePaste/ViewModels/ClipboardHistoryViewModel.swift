import AppKit
import Foundation

@MainActor
final class ClipboardHistoryViewModel: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []
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

    init(storageManager: StorageManager, settingsManager: SettingsManager) {
        self.storageManager = storageManager
        self.settingsManager = settingsManager
        self.hotkeyStatusMessage = L10n.tr("status.hotkey_unavailable")
        self.storageUsageLabel = storageManager.formattedStorageUsage()
    }

    var currentHistory: [ClipboardItem] {
        items
    }

    var visibleItems: [ClipboardItem] {
        ClipboardSearchEngine.matches(for: filteredItems, query: searchQuery)
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
    }

    func prepend(_ item: ClipboardItem) {
        items.insert(item, at: 0)
        refreshStorageUsage()
    }

    func appendSearchCharacter(_ character: String) {
        guard character.isEmpty == false else {
            return
        }

        isSearchInterfaceVisible = true
        searchQuery.append(contentsOf: character)
    }

    func removeLastSearchCharacter() {
        guard searchQuery.isEmpty == false else {
            return
        }

        searchQuery.removeLast()
    }

    func clearSearch() {
        guard isSearchInterfaceVisible || searchQuery.isEmpty == false else {
            return
        }

        searchQuery.removeAll()
        isSearchInterfaceVisible = false
    }

    func toggleTagFilter(_ tag: ClipboardTag) {
        activeTagFilter = activeTagFilter == tag ? nil : tag
    }

    func isFiltering(by tag: ClipboardTag) -> Bool {
        activeTagFilter == tag
    }

    func clearTransientState() {
        clearSearch()
        activeTagFilter = nil
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

    private var filteredItems: [ClipboardItem] {
        guard let activeTagFilter else {
            return items
        }

        return items.filter { $0.tags.contains(activeTagFilter) }
    }
}
