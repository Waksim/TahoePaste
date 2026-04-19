import Carbon
import Foundation

@MainActor
final class HotkeyController {
    enum RegistrationError: LocalizedError {
        case installHandler(OSStatus)
        case registerHotkey(OSStatus)

        var errorDescription: String? {
            switch self {
            case .installHandler:
                return L10n.tr("status.hotkey_listen_failed")
            case .registerHotkey:
                return L10n.tr("status.hotkey_already_used")
            }
        }
    }

    var onHotKeyPressed: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let hotKeyID = EventHotKeyID(signature: fourCharCode("THPC"), id: 1)

    func registerToggleShortcut() throws {
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let callback: EventHandlerUPP = { _, event, userData in
            guard
                let event,
                let userData
            else {
                return noErr
            }

            let controller = Unmanaged<HotkeyController>.fromOpaque(userData).takeUnretainedValue()
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            guard status == noErr else {
                return status
            }

            guard hotKeyID.signature == controller.hotKeyID.signature, hotKeyID.id == controller.hotKeyID.id else {
                return noErr
            }

            MainActor.assumeIsolated {
                controller.onHotKeyPressed?()
            }

            return noErr
        }

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandlerRef
        )

        guard installStatus == noErr else {
            throw RegistrationError.installHandler(installStatus)
        }

        let hotKeyID = hotKeyID
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_C),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            OptionBits(0),
            &hotKeyRef
        )

        guard registerStatus == noErr else {
            unregister()
            throw RegistrationError.registerHotkey(registerStatus)
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }
}

private func fourCharCode(_ string: String) -> OSType {
    string.utf8.prefix(4).reduce(0) { partial, value in
        (partial << 8) + OSType(value)
    }
}
