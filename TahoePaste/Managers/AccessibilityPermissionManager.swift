import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
final class AccessibilityPermissionManager {
    private let hasPromptedKey = "TahoePasteHasPromptedForAccessibility"
    private let promptedExecutableIdentityKey = "TahoePasteAccessibilityPromptedExecutableIdentity"
    private let accessibilityPromptOptionKey = "AXTrustedCheckOptionPrompt"

    @discardableResult
    func refreshTrustStatus() -> Bool {
        let accessibilityTrusted = AXIsProcessTrusted()
            || AXIsProcessTrustedWithOptions(nil)
            || AXIsProcessTrustedWithOptions(axTrustOptions(prompt: false))
        let postEventTrusted = CGPreflightPostEventAccess()
        return accessibilityTrusted || postEventTrusted
    }

    func requestAccessibilityIfNeededOnFirstLaunch() {
        let defaults = UserDefaults.standard
        guard refreshTrustStatus() == false else {
            return
        }

        let executableIdentity = currentExecutableIdentity()
        let promptedIdentity = defaults.string(forKey: promptedExecutableIdentityKey)
        let shouldPrompt = defaults.bool(forKey: hasPromptedKey) == false
            || executableIdentity != promptedIdentity

        guard shouldPrompt else {
            return
        }

        defaults.set(true, forKey: hasPromptedKey)
        if let executableIdentity {
            defaults.set(executableIdentity, forKey: promptedExecutableIdentityKey)
        }
        requestAccessibilityAccess()
    }

    func requestAccessibilityAccess() {
        _ = AXIsProcessTrustedWithOptions(axTrustOptions(prompt: true))
        _ = CGRequestPostEventAccess()
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private func axTrustOptions(prompt: Bool) -> CFDictionary {
        [accessibilityPromptOptionKey: prompt] as CFDictionary
    }

    private func currentExecutableIdentity() -> String? {
        guard let executableURL = Bundle.main.executableURL else {
            return nil
        }

        let modificationDate = try? executableURL.resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate?
            .timeIntervalSince1970
        return "\(executableURL.path)#\(modificationDate ?? 0)"
    }
}
