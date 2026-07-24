import AppKit

enum ClipboardPayload {
    case text(String)
    case image(NSImage)
    case fileURLs([URL])
}
