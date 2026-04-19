import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let storageManager: StorageManager
    let settingsManager: SettingsManager
    let accessibilityPermissionManager: AccessibilityPermissionManager
    let clipboardManager: ClipboardManager
    let hotkeyController: HotkeyController
    let historyViewModel: ClipboardHistoryViewModel
    let menuBarController: MenuBarController

    lazy var overlayWindowController = OverlayWindowController(
        viewModel: historyViewModel,
        settingsManager: settingsManager
    )
    lazy var settingsWindowController = SettingsWindowController(
        settingsManager: settingsManager,
        historyViewModel: historyViewModel
    )
    lazy var pasteActionController = PasteActionController(
        storageManager: storageManager,
        clipboardManager: clipboardManager,
        accessibilityPermissionManager: accessibilityPermissionManager,
        settingsManager: settingsManager
    )

    private var cancellables = Set<AnyCancellable>()
    private var hotkeyRegistrationSucceeded = false
    private var hotkeyRegistrationErrorKey: String?

    override init() {
        let storageManager = StorageManager()
        self.storageManager = storageManager
        self.settingsManager = SettingsManager.shared
        self.accessibilityPermissionManager = AccessibilityPermissionManager()
        self.clipboardManager = ClipboardManager()
        self.hotkeyController = HotkeyController()
        self.historyViewModel = ClipboardHistoryViewModel(
            storageManager: storageManager,
            settingsManager: settingsManager
        )
        self.menuBarController = MenuBarController(
            viewModel: historyViewModel,
            settingsManager: settingsManager
        )
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        bindViewModelActions()
        restorePersistedHistory()
        refreshAccessibilityStatus()
        accessibilityPermissionManager.requestAccessibilityIfNeededOnFirstLaunch()
        refreshAccessibilityStatus()
        configureSettingsBindings()
        configureClipboardManager()
        configureHotkeyController()
        configureMenuBarController()
        applyClipboardSettings()
        applyHistoryLimitIfNeeded()

        clipboardManager.startListening()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.refreshAccessibilityStatus()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardManager.stopListening()
        hotkeyController.unregister()
    }

    func openSettingsWindow() {
        hideOverlay()
        settingsWindowController.showWindowAndActivate()
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            self.settingsManager.refreshLaunchAtLoginState()
            self.refreshAccessibilityStatus()
            self.historyViewModel.refreshStorageUsage()
        }
    }

    private func bindViewModelActions() {
        historyViewModel.onShowOverlay = { [weak self] in
            self?.showOverlay()
        }
        historyViewModel.onHideOverlay = { [weak self] in
            self?.hideOverlay()
        }
        historyViewModel.onOpenSettings = { [weak self] in
            self?.openSettingsWindow()
        }
        historyViewModel.onSelectItem = { [weak self] item in
            self?.selectItem(item)
        }
        historyViewModel.onDeleteItem = { [weak self] item in
            self?.deleteItem(item)
        }
        historyViewModel.onOpenAccessibilitySettings = { [weak self] in
            self?.accessibilityPermissionManager.openAccessibilitySettings()
        }
        historyViewModel.onRequestAccessibilityPermission = { [weak self] in
            self?.accessibilityPermissionManager.requestAccessibilityAccess()
            DispatchQueue.main.async { [weak self] in
                self?.refreshAccessibilityStatus()
            }
        }
        historyViewModel.onClearHistory = { [weak self] in
            self?.clearHistory()
        }
        historyViewModel.onRevealStorageInFinder = { [weak self] in
            self?.storageManager.revealInFinder()
        }
        historyViewModel.onQuit = {
            NSApplication.shared.terminate(nil)
        }
    }

    private func configureMenuBarController() {
        menuBarController.onShowClipboard = { [weak self] in
            self?.showOverlay()
        }
        menuBarController.onOpenSettings = { [weak self] in
            self?.openSettingsWindow()
        }
        menuBarController.onQuit = {
            NSApplication.shared.terminate(nil)
        }
        menuBarController.setVisible(settingsManager.showMenuBarIcon)
    }

    private func restorePersistedHistory() {
        do {
            let items = try storageManager.loadHistory()
            historyViewModel.replaceHistory(with: items)
        } catch {
            historyViewModel.setStatusMessage(L10n.tr("status.load_history_failed"))
        }
    }

    private func configureClipboardManager() {
        clipboardManager.onCapture = { [weak self] payload in
            self?.handleClipboardPayload(payload)
        }
    }

    private func configureSettingsBindings() {
        settingsManager.$captureText
            .dropFirst()
            .sink { [weak self] _ in
                self?.applyClipboardSettings()
            }
            .store(in: &cancellables)

        settingsManager.$captureImages
            .dropFirst()
            .sink { [weak self] _ in
                self?.applyClipboardSettings()
            }
            .store(in: &cancellables)

        settingsManager.$isMonitoringPaused
            .dropFirst()
            .sink { [weak self] _ in
                self?.applyClipboardSettings()
            }
            .store(in: &cancellables)

        settingsManager.$maximumHistoryItems
            .dropFirst()
            .sink { [weak self] _ in
                self?.applyHistoryLimitIfNeeded()
            }
            .store(in: &cancellables)

        settingsManager.$overlayHeight
            .dropFirst()
            .sink { [weak self] _ in
                self?.overlayWindowController.refreshLayoutIfVisible()
            }
            .store(in: &cancellables)

        settingsManager.$appLanguage
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshLocalizedRuntimeState()
            }
            .store(in: &cancellables)

        settingsManager.showMenuBarIconDidChange
            .receive(on: RunLoop.main)
            .sink { [weak self] isVisible in
                self?.menuBarController.setVisible(isVisible)
            }
            .store(in: &cancellables)
    }

    private func configureHotkeyController() {
        hotkeyController.onHotKeyPressed = { [weak self] in
            self?.toggleOverlay()
        }

        do {
            try hotkeyController.registerToggleShortcut()
            hotkeyRegistrationSucceeded = true
            hotkeyRegistrationErrorKey = nil
            historyViewModel.setHotkeyAvailability(L10n.tr("status.hotkey_ready"))
        } catch {
            hotkeyRegistrationSucceeded = false
            hotkeyRegistrationErrorKey = hotkeyErrorKey(for: error)
            historyViewModel.setHotkeyAvailability(
                error.localizedDescription.isEmpty
                    ? L10n.tr("status.hotkey_unavailable_mac")
                    : error.localizedDescription
            )
        }
    }

    private func refreshAccessibilityStatus() {
        let trusted = accessibilityPermissionManager.refreshTrustStatus()
        historyViewModel.setAccessibilityTrusted(trusted)
    }

    private func handleClipboardPayload(_ payload: ClipboardPayload) {
        do {
            let item = try storageManager.store(payload: payload)
            let updatedHistory = trimmedHistory(withNewestItem: item)
            historyViewModel.replaceHistory(with: updatedHistory)
            try storageManager.saveHistory(updatedHistory)
        } catch {
            historyViewModel.setStatusMessage(L10n.tr("status.save_latest_failed"))
        }
    }

    private func toggleOverlay() {
        if overlayWindowController.isVisible {
            hideOverlay()
            return
        }

        showOverlay()
    }

    private func showOverlay() {
        pasteActionController.captureFrontmostApplication(excludingBundleIdentifier: Bundle.main.bundleIdentifier)
        overlayWindowController.show(on: OverlayWindowController.activeScreen())
    }

    private func hideOverlay() {
        overlayWindowController.hide()
    }

    private func selectItem(_ item: ClipboardItem) {
        do {
            try pasteActionController.restoreClipboardAndPaste(item: item) { [weak self] in
                self?.hideOverlay()
            } onPermissionFallback: { [weak self] message in
                self?.historyViewModel.setStatusMessage(message)
            }
        } catch {
            historyViewModel.setStatusMessage(L10n.tr("status.restore_item_failed"))
        }
    }

    private func clearHistory() {
        do {
            try storageManager.clearHistory()
            historyViewModel.replaceHistory(with: [])
            historyViewModel.setStatusMessage(L10n.tr("status.history_cleared"))
        } catch {
            historyViewModel.setStatusMessage(L10n.tr("status.clear_history_failed"))
        }
    }

    private func deleteItem(_ item: ClipboardItem) {
        let updatedHistory = historyViewModel.currentHistory.filter { $0.id != item.id }
        guard updatedHistory.count != historyViewModel.currentHistory.count else {
            return
        }

        do {
            historyViewModel.replaceHistory(with: updatedHistory)
            try storageManager.saveHistory(updatedHistory)
        } catch {
            historyViewModel.setStatusMessage(L10n.tr("status.delete_item_failed"))
        }
    }

    private func applyClipboardSettings() {
        clipboardManager.capturesText = settingsManager.captureText
        clipboardManager.capturesImages = settingsManager.captureImages
        clipboardManager.isMonitoringPaused = settingsManager.isMonitoringPaused
    }

    private func applyHistoryLimitIfNeeded() {
        guard let historyLimit = settingsManager.historyLimit else {
            return
        }

        let trimmedHistory = Array(historyViewModel.currentHistory.prefix(historyLimit))
        guard trimmedHistory.count != historyViewModel.currentHistory.count else {
            return
        }

        do {
            historyViewModel.replaceHistory(with: trimmedHistory)
            try storageManager.saveHistory(trimmedHistory)
        } catch {
            historyViewModel.setStatusMessage(L10n.tr("status.trim_history_failed"))
        }
    }

    private func refreshLocalizedRuntimeState() {
        historyViewModel.refreshStorageUsage()

        if hotkeyRegistrationSucceeded {
            historyViewModel.setHotkeyAvailability(L10n.tr("status.hotkey_ready"))
        } else {
            historyViewModel.setHotkeyAvailability(
                hotkeyRegistrationErrorKey.map { L10n.tr($0) } ?? L10n.tr("status.hotkey_unavailable_mac")
            )
        }
    }

    private func hotkeyErrorKey(for error: Error) -> String? {
        guard let registrationError = error as? HotkeyController.RegistrationError else {
            return nil
        }

        switch registrationError {
        case .installHandler:
            return "status.hotkey_listen_failed"
        case .registerHotkey:
            return "status.hotkey_already_used"
        }
    }

    private func trimmedHistory(withNewestItem item: ClipboardItem) -> [ClipboardItem] {
        let updatedHistory = [item] + historyViewModel.currentHistory
        guard let historyLimit = settingsManager.historyLimit else {
            return updatedHistory
        }

        return Array(updatedHistory.prefix(historyLimit))
    }
}
