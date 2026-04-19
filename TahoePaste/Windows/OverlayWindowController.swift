import AppKit
import Combine
import SwiftUI

@MainActor
final class OverlayWindowController {
    private let viewModel: ClipboardHistoryViewModel
    private let settingsManager: SettingsManager
    private lazy var panel: OverlayPanel = makePanel()

    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private var resignObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: ClipboardHistoryViewModel, settingsManager: SettingsManager) {
        self.viewModel = viewModel
        self.settingsManager = settingsManager
        bindThemeUpdates()
    }

    var isVisible: Bool {
        panel.isVisible
    }

    func show(on screen: NSScreen?) {
        let targetScreen = screen ?? Self.activeScreen() ?? NSScreen.main
        updateFrame(for: targetScreen)
        installEventMonitors()

        NSApplication.shared.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        guard panel.isVisible else {
            return
        }

        panel.orderOut(nil)
        removeEventMonitors()
    }

    func refreshLayoutIfVisible() {
        guard panel.isVisible else {
            return
        }

        updateFrame(for: Self.activeScreen())
    }

    static func activeScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { screen in
            NSMouseInRect(mouseLocation, screen.frame, false)
        } ?? NSScreen.main
    }

    private func makePanel() -> OverlayPanel {
        let panel = OverlayPanel(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        panel.contentView = NSHostingView(rootView: OverlayView(viewModel: viewModel, settingsManager: settingsManager))
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovable = false
        panel.appearance = settingsManager.nsAppearance
        panel.onEscape = { [weak self] in
            guard let self else {
                return
            }

            if self.viewModel.isSearchBubbleVisible {
                self.viewModel.clearTransientState()
            } else {
                self.hide()
            }
        }

        return panel
    }

    private func bindThemeUpdates() {
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
    }

    private func applyTheme() {
        panel.appearance = settingsManager.nsAppearance
    }

    private func updateFrame(for screen: NSScreen?) {
        guard let visibleFrame = screen?.visibleFrame else {
            return
        }

        let height = CGFloat(settingsManager.overlayHeight)
        let frame = CGRect(
            x: visibleFrame.minX,
            y: visibleFrame.minY,
            width: visibleFrame.width,
            height: height
        )

        panel.setFrame(frame, display: false)
    }

    private func installEventMonitors() {
        if resignObserver == nil {
            resignObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.hide()
                }
            }
        }

        if localEventMonitor == nil {
            localEventMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.keyDown, .leftMouseDown, .rightMouseDown]
            ) { [weak self] event in
                guard let self else {
                    return event
                }

                switch event.type {
                case .leftMouseDown, .rightMouseDown:
                    let mouseLocation = NSEvent.mouseLocation
                    if self.panel.frame.contains(mouseLocation) == false {
                        self.hide()
                    }
                    return event
                case .keyDown:
                    return self.handleKeyDown(event)
                default:
                    return event
                }
            }
        }

        if globalEventMonitor == nil {
            globalEventMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] _ in
                Task { @MainActor in
                    guard let self else {
                        return
                    }

                    let mouseLocation = NSEvent.mouseLocation
                    if self.panel.frame.contains(mouseLocation) == false {
                        self.hide()
                    }
                }
            }
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        if event.modifierFlags.intersection([.command, .option, .control]) == [.command],
           event.charactersIgnoringModifiers == ","
        {
            viewModel.openSettings()
            return nil
        }

        switch event.keyCode {
        case 53:
            if viewModel.isSearchBubbleVisible {
                viewModel.clearTransientState()
            } else {
                hide()
            }
            return nil
        case 51, 117:
            if viewModel.isSearching {
                viewModel.removeLastSearchCharacter()
                return nil
            } else if viewModel.isSearchInterfaceVisible {
                viewModel.dismissSearchInterface()
                return nil
            }
        default:
            break
        }

        let disallowedModifiers = event.modifierFlags.intersection([.command, .control, .option, .function])
        guard disallowedModifiers.isEmpty else {
            return event
        }

        guard let characters = event.characters, characters.isEmpty == false else {
            return event
        }

        let searchableInput = characters.filter { character in
            character.isNewline == false &&
            character.unicodeScalars.allSatisfy { CharacterSet.controlCharacters.contains($0) == false }
        }

        guard searchableInput.isEmpty == false else {
            return nil
        }

        viewModel.appendSearchCharacter(searchableInput)
        return nil
    }

    private func removeEventMonitors() {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }

        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
            self.globalEventMonitor = nil
        }

        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
            self.resignObserver = nil
        }
    }
}

private final class OverlayPanel: NSPanel {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }
}
