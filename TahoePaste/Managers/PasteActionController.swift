import AppKit
import Carbon

@MainActor
final class PasteActionController {
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

        guard accessibilityPermissionManager.refreshTrustStatus() else {
            onPermissionFallback(L10n.tr("status.accessibility_manual_paste"))
            accessibilityPermissionManager.requestAccessibilityAccess()
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
        let result = try PasteboardItemWriter.write(item, storageManager: storageManager)
        clipboardManager.suppressNextObservedChangeCount(result.changeCount)
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
