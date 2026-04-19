import AppKit

enum ClipboardPayload {
    case text(String)
    case image(NSImage)
    case fileURLs([URL])
}

struct ClipboardChangeSuppression {
    private var ignoredChangeCount: Int?

    mutating func register(changeCount: Int) {
        ignoredChangeCount = changeCount
    }

    mutating func shouldSuppress(changeCount: Int) -> Bool {
        guard ignoredChangeCount == changeCount else {
            return false
        }

        ignoredChangeCount = nil
        return true
    }
}

@MainActor
final class ClipboardManager {
    var onCapture: ((ClipboardPayload) -> Void)?

    var capturesText = true
    var capturesImages = true
    var isMonitoringPaused = false

    private let pasteboard: NSPasteboard
    private var timer: Timer?
    private var lastObservedChangeCount: Int
    private var suppression = ClipboardChangeSuppression()

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        self.lastObservedChangeCount = pasteboard.changeCount
    }

    func startListening() {
        guard timer == nil else {
            return
        }

        let timer = Timer(timeInterval: 0.35, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollPasteboard()
            }
        }

        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stopListening() {
        timer?.invalidate()
        timer = nil
    }

    func suppressNextObservedChangeCount(_ changeCount: Int) {
        suppression.register(changeCount: changeCount)
    }

    private func pollPasteboard() {
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastObservedChangeCount else {
            return
        }

        lastObservedChangeCount = currentChangeCount

        if suppression.shouldSuppress(changeCount: currentChangeCount) {
            return
        }

        guard isMonitoringPaused == false else {
            return
        }

        guard let payload = readSupportedPayload() else {
            return
        }

        onCapture?(payload)
    }

    private func readSupportedPayload() -> ClipboardPayload? {
        let fileURLReadOptions: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]

        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: fileURLReadOptions) as? [URL] {
            let validFileURLs = fileURLs.filter(\.isFileURL)
            if validFileURLs.isEmpty == false {
                return .fileURLs(validFileURLs)
            }
        }

        if
            capturesImages,
            let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage
        {
            return .image(image)
        }

        if
            capturesText,
            let string = pasteboard.string(forType: .string),
            string.isEmpty == false
        {
            return .text(string)
        }

        return nil
    }
}
