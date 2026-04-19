import AppKit
import Carbon

@MainActor
final class PasteActionController {
    enum PasteError: Error {
        case missingTextPayload
        case missingImagePayload
        case missingFilePayload
        case failedToWritePasteboard
    }

    private let storageManager: StorageManager
    private let clipboardManager: ClipboardManager
    private let accessibilityPermissionManager: AccessibilityPermissionManager
    private let settingsManager: SettingsManager
    private var previousFrontmostApplication: NSRunningApplication?

    init(
        storageManager: StorageManager,
        clipboardManager: ClipboardManager,
        accessibilityPermissionManager: AccessibilityPermissionManager,
        settingsManager: SettingsManager
    ) {
        self.storageManager = storageManager
        self.clipboardManager = clipboardManager
        self.accessibilityPermissionManager = accessibilityPermissionManager
        self.settingsManager = settingsManager
    }

    func captureFrontmostApplication(excludingBundleIdentifier bundleIdentifier: String?) {
        let frontmost = NSWorkspace.shared.frontmostApplication

        guard frontmost?.bundleIdentifier != bundleIdentifier else {
            return
        }

        previousFrontmostApplication = frontmost
    }

    func restoreClipboardAndPaste(
        item: ClipboardItem,
        hideOverlay: @escaping () -> Void,
        onPermissionFallback: @escaping (String) -> Void
    ) throws {
        try writeItemToPasteboard(item)

        hideOverlay()
        if settingsManager.reactivatePreviousAppBeforePaste {
            reactivatePreviousApplicationIfNeeded()
        }

        guard settingsManager.autoPasteAfterSelection else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + settingsManager.pasteDelay) {
            self.postCommandV()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if self.accessibilityPermissionManager.refreshTrustStatus() == false {
                    onPermissionFallback(L10n.tr("status.accessibility_manual_paste"))
                }
            }
        }
    }

    private func writeItemToPasteboard(_ item: ClipboardItem) throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let writeSucceeded: Bool

        switch item.kind {
        case .text, .link, .code:
            guard let text = item.text else {
                throw PasteError.missingTextPayload
            }

            writeSucceeded = pasteboard.setString(text, forType: .string)
        case .image:
            guard let image = storageManager.loadImage(for: item) else {
                throw PasteError.missingImagePayload
            }

            writeSucceeded = pasteboard.writeObjects([image])
        case .file:
            guard let fileReferences = item.fileReferences, fileReferences.isEmpty == false else {
                throw PasteError.missingFilePayload
            }

            let existingURLs = fileReferences
                .map(\.url)
                .filter { FileManager.default.fileExists(atPath: $0.path) }

            guard existingURLs.isEmpty == false else {
                throw PasteError.missingFilePayload
            }

            writeSucceeded = pasteboard.writeObjects(existingURLs as [NSURL])
        }

        guard writeSucceeded else {
            throw PasteError.failedToWritePasteboard
        }

        clipboardManager.suppressNextObservedChangeCount(pasteboard.changeCount)
    }

    private func postCommandV() {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return
        }

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func reactivatePreviousApplicationIfNeeded() {
        guard let previousFrontmostApplication else {
            return
        }

        previousFrontmostApplication.unhide()

        if #available(macOS 14.0, *) {
            NSApp.yieldActivation(to: previousFrontmostApplication)
        }

        previousFrontmostApplication.activate(options: [])
    }
}
