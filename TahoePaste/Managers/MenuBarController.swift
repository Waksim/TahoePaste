import AppKit
import Combine

@MainActor
final class MenuBarController: NSObject {
    var onShowClipboard: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onQuit: (() -> Void)?

    private let viewModel: ClipboardHistoryViewModel
    private let settingsManager: SettingsManager
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

    private let menu = NSMenu()
    private let monitoringItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let savedItemsItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private lazy var showClipboardItem = NSMenuItem(
        title: L10n.tr("common.show_clipboard"),
        action: #selector(showClipboard),
        keyEquivalent: ""
    )
    private lazy var settingsItem = NSMenuItem(
        title: L10n.tr("common.settings"),
        action: #selector(openSettings),
        keyEquivalent: ","
    )
    private lazy var quitItem = NSMenuItem(
        title: L10n.tr("common.quit_tahoepaste"),
        action: #selector(quit),
        keyEquivalent: "q"
    )

    init(viewModel: ClipboardHistoryViewModel, settingsManager: SettingsManager) {
        self.viewModel = viewModel
        self.settingsManager = settingsManager
        super.init()

        configureMenu()
        bindState()
        refreshLocalizedText()
        refreshLabels()
    }

    func setVisible(_ isVisible: Bool) {
        if isVisible {
            installStatusItemIfNeeded()
        } else {
            removeStatusItem()
        }
    }

    private func configureMenu() {
        monitoringItem.isEnabled = false
        savedItemsItem.isEnabled = false

        showClipboardItem.target = self
        settingsItem.target = self
        quitItem.target = self

        menu.autoenablesItems = false
        menu.items = [
            monitoringItem,
            savedItemsItem,
            .separator(),
            showClipboardItem,
            settingsItem,
            .separator(),
            quitItem
        ]
    }

    private func bindState() {
        viewModel.$items
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshLabels()
            }
            .store(in: &cancellables)

        settingsManager.$isMonitoringPaused
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshLabels()
            }
            .store(in: &cancellables)

        settingsManager.$appLanguage
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshLocalizedText()
                self?.refreshLabels()
                self?.refreshStatusButtonAppearance()
            }
            .store(in: &cancellables)

        settingsManager.$themeMode
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshMenuAppearance()
            }
            .store(in: &cancellables)

        settingsManager.$activeTheme
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshMenuAppearance()
            }
            .store(in: &cancellables)
    }

    private func installStatusItemIfNeeded() {
        guard statusItem == nil else {
            refreshStatusButtonAppearance()
            return
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.menu = menu

        if let button = item.button {
            button.image = menuBarImage()
            button.imagePosition = .imageOnly
            button.toolTip = L10n.tr("common.tahoepaste")
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.appearance = settingsManager.nsAppearance
        }

        statusItem = item
        refreshMenuAppearance()
        refreshStatusButtonAppearance()
    }

    private func removeStatusItem() {
        guard let statusItem else {
            return
        }

        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
    }

    private func refreshLabels() {
        monitoringItem.title = settingsManager.monitoringStatusText
        savedItemsItem.title = viewModel.savedItemsStatusLabel
    }

    private func refreshLocalizedText() {
        showClipboardItem.title = L10n.tr("common.show_clipboard")
        settingsItem.title = L10n.tr("common.settings")
        quitItem.title = L10n.tr("common.quit_tahoepaste")
        statusItem?.button?.toolTip = L10n.tr("common.tahoepaste")
    }

    private func refreshStatusButtonAppearance() {
        statusItem?.button?.image = menuBarImage()
    }

    private func refreshMenuAppearance() {
        menu.appearance = settingsManager.nsAppearance
        statusItem?.button?.appearance = settingsManager.nsAppearance
    }

    private func menuBarImage() -> NSImage? {
        let image = NSImage(named: "MenuBarIcon")
            ?? NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: L10n.tr("common.tahoepaste"))
        image?.isTemplate = true
        image?.size = NSSize(width: 18, height: 14)
        return image
    }

    @objc
    private func showClipboard() {
        onShowClipboard?()
    }

    @objc
    private func openSettings() {
        onOpenSettings?()
    }

    @objc
    private func quit() {
        onQuit?()
    }
}
