import AppKit
import Combine
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let settingsManager: SettingsManager
    private let historyViewModel: ClipboardHistoryViewModel
    private var cancellables = Set<AnyCancellable>()

    init(settingsManager: SettingsManager, historyViewModel: ClipboardHistoryViewModel) {
        self.settingsManager = settingsManager
        self.historyViewModel = historyViewModel

        let rootView = SettingsView(
            settingsManager: settingsManager,
            historyViewModel: historyViewModel
        )

        let hostingView = NSHostingView(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 760),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.contentView = hostingView
        window.title = L10n.tr("settings.window_title")
        window.titlebarAppearsTransparent = false
        window.isReleasedWhenClosed = false
        window.delegate = nil
        window.center()

        super.init(window: window)
        self.window?.delegate = self

        settingsManager.$appLanguage
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.window?.title = L10n.tr("settings.window_title")
            }
            .store(in: &cancellables)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showWindowAndActivate() {
        guard let window else {
            return
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
