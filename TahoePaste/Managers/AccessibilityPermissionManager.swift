import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
final class AccessibilityPermissionManager {
    private let hasPromptedKey = "TahoePasteHasPromptedForAccessibility"
    private let accessibilityPromptOptionKey = "AXTrustedCheckOptionPrompt"

    @discardableResult
    func refreshTrustStatus() -> Bool {
        let accessibilityTrusted = AXIsProcessTrusted()
            || AXIsProcessTrustedWithOptions(nil)
            || AXIsProcessTrustedWithOptions(axTrustOptions(prompt: false))
        let postEventTrusted = CGPreflightPostEventAccess()
        let accessibilityAPIResponding = probeAccessibilityAPI()
        return accessibilityTrusted || postEventTrusted || accessibilityAPIResponding
    }

    func requestAccessibilityIfNeededOnFirstLaunch() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: hasPromptedKey) == false else {
            return
        }

        defaults.set(true, forKey: hasPromptedKey)
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

    private func probeAccessibilityAPI() -> Bool {
        let systemWideElement = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedApplicationAttribute as CFString,
            &value
        )

        switch result {
        case .success, .cannotComplete:
            return true
        default:
            return false
        }
    }
}
