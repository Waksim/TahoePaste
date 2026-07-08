import AppKit
import Combine
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    var onWindowWillClose: (() -> Void)?

    private let settingsManager: SettingsManager
    private let historyViewModel: ClipboardHistoryViewModel
    private var cancellables = Set<AnyCancellable>()
    private var lastOverlayFootprint: CGFloat?

    init(settingsManager: SettingsManager, historyViewModel: ClipboardHistoryViewModel) {
        self.settingsManager = settingsManager
        self.historyViewModel = historyViewModel

        let rootView = SettingsView(
            settingsManager: settingsManager,
            historyViewModel: historyViewModel
        )

        let hostingView = NSHostingView(rootView: rootView)
        // The window frame is managed here (top of the screen, shortened to
        // leave room for the overlay preview); SwiftUI must not drive it.
        hostingView.sizingOptions = []
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
        applyTheme()

        settingsManager.$appLanguage
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.window?.title = L10n.tr("settings.window_title")
            }
            .store(in: &cancellables)

        settingsManager.$themeMode
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyTheme()
            }
            .store(in: &cancellables)

        settingsManager.$activeTheme
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyTheme()
            }
            .store(in: &cancellables)

        settingsManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.repositionIfOverlayFootprintChanged()
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

        positionAtTopCenter(window)
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        onWindowWillClose?()
    }

    private var overlayFootprint: CGFloat {
        let overlayLayout = settingsManager.overlayLayout
        return overlayLayout.overlayHeight + overlayLayout.overlayScreenBottomInset
    }

    // Overlay geometry changes live while its sliders are dragged; keep the
    // settings window clear of the preview, but only move it when the
    // footprint actually changed so unrelated settings don't fight a
    // manually placed window.
    private func repositionIfOverlayFootprintChanged() {
        guard let window, window.isVisible, overlayFootprint != lastOverlayFootprint else {
            return
        }

        positionAtTopCenter(window)
    }

    private func positionAtTopCenter(_ window: NSWindow) {
        guard let screen = OverlayWindowController.activeScreen() ?? NSScreen.main else {
            return
        }

        let visibleFrame = screen.visibleFrame
        let occupiedByOverlay = overlayFootprint
        lastOverlayFootprint = occupiedByOverlay
        // Extreme overlay sliders can eat the whole screen; never collapse
        // below a usable height — overlapping the preview beats vanishing.
        let height = max(420, min(760, visibleFrame.height - occupiedByOverlay - 24))
        let width = window.frame.width
        let frame = NSRect(
            x: visibleFrame.midX - width / 2,
            y: visibleFrame.maxY - height,
            width: width,
            height: height
        )

        window.setFrame(frame, display: true)
    }

    private func applyTheme() {
        window?.appearance = settingsManager.nsAppearance
    }
}
