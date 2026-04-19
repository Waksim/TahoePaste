import AppKit
import Combine
import Foundation
import ServiceManagement

@MainActor
final class SettingsManager: ObservableObject {
    enum CardSizePreset: String, CaseIterable, Identifiable {
        case compact
        case comfortable
        case large

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .compact:
                return L10n.tr("card.size.compact")
            case .comfortable:
                return L10n.tr("card.size.comfortable")
            case .large:
                return L10n.tr("card.size.large")
            }
        }

        var textCardWidth: CGFloat {
            switch self {
            case .compact:
                return 252
            case .comfortable:
                return 280
            case .large:
                return 320
            }
        }

        var imageCardWidth: CGFloat {
            switch self {
            case .compact:
                return 208
            case .comfortable:
                return 220
            case .large:
                return 248
            }
        }

        var cardHeight: CGFloat {
            switch self {
            case .compact:
                return 148
            case .comfortable:
                return 164
            case .large:
                return 188
            }
        }

        var contentPadding: CGFloat {
            switch self {
            case .compact:
                return 14
            case .comfortable:
                return 16
            case .large:
                return 18
            }
        }

        var imagePreviewHeight: CGFloat {
            switch self {
            case .compact:
                return 84
            case .comfortable:
                return 96
            case .large:
                return 112
            }
        }

        var textFontSize: CGFloat {
            switch self {
            case .compact:
                return 15
            case .comfortable:
                return 17
            case .large:
                return 18
            }
        }
    }

    static let shared = SettingsManager()

    let showMenuBarIconDidChange = PassthroughSubject<Bool, Never>()

    var showMenuBarIcon: Bool {
        get { showMenuBarIconValue }
        set {
            guard showMenuBarIconValue != newValue else {
                return
            }

            objectWillChange.send()
            showMenuBarIconValue = newValue
            persist(newValue, forKey: Keys.showMenuBarIcon)
            showMenuBarIconDidChange.send(newValue)
        }
    }

    @Published var captureText: Bool {
        didSet { persist(captureText, forKey: Keys.captureText) }
    }

    @Published var appLanguage: AppLanguage {
        didSet { persist(appLanguage.rawValue, forKey: Keys.appLanguage) }
    }

    @Published var captureImages: Bool {
        didSet { persist(captureImages, forKey: Keys.captureImages) }
    }

    @Published var isMonitoringPaused: Bool {
        didSet { persist(isMonitoringPaused, forKey: Keys.isMonitoringPaused) }
    }

    @Published var maximumHistoryItems: Int {
        didSet {
            let normalizedValue = Self.normalizedMaximumHistoryItems(maximumHistoryItems)
            guard maximumHistoryItems == normalizedValue else {
                maximumHistoryItems = normalizedValue
                return
            }

            persist(maximumHistoryItems, forKey: Keys.maximumHistoryItems)
            if maximumHistoryItems > 0 {
                lastFiniteHistoryItems = maximumHistoryItems
                persist(lastFiniteHistoryItems, forKey: Keys.lastFiniteHistoryItems)
            }
        }
    }

    @Published private(set) var launchAtLogin: Bool
    @Published private(set) var launchAtLoginStatusMessage: String?

    @Published var autoPasteAfterSelection: Bool {
        didSet { persist(autoPasteAfterSelection, forKey: Keys.autoPasteAfterSelection) }
    }

    @Published var pasteDelay: Double {
        didSet {
            let clampedValue = Self.clamp(pasteDelay, min: 0.05, max: 0.30)
            guard pasteDelay == clampedValue else {
                pasteDelay = clampedValue
                return
            }
            persist(pasteDelay, forKey: Keys.pasteDelay)
        }
    }

    @Published var reactivatePreviousAppBeforePaste: Bool {
        didSet { persist(reactivatePreviousAppBeforePaste, forKey: Keys.reactivatePreviousAppBeforePaste) }
    }

    @Published var overlayHeight: Double {
        didSet {
            let clampedValue = Self.clamp(overlayHeight, min: 220, max: 360)
            guard overlayHeight == clampedValue else {
                overlayHeight = clampedValue
                return
            }
            persist(overlayHeight, forKey: Keys.overlayHeight)
        }
    }

    @Published var cardSizePreset: CardSizePreset {
        didSet { persist(cardSizePreset.rawValue, forKey: Keys.cardSizePreset) }
    }

    @Published var showTimestampsOnCards: Bool {
        didSet { persist(showTimestampsOnCards, forKey: Keys.showTimestampsOnCards) }
    }

    @Published var showMetadataOnCards: Bool {
        didSet { persist(showMetadataOnCards, forKey: Keys.showMetadataOnCards) }
    }

    @Published var cornerRadiusIntensity: Double {
        didSet {
            let clampedValue = Self.clamp(cornerRadiusIntensity, min: 0, max: 28)
            guard cornerRadiusIntensity == clampedValue else {
                cornerRadiusIntensity = clampedValue
                return
            }
            persist(cornerRadiusIntensity, forKey: Keys.cornerRadiusIntensity)
        }
    }

    private var showMenuBarIconValue: Bool
    private var lastFiniteHistoryItems: Int
    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.showMenuBarIconValue = defaults.object(forKey: Keys.showMenuBarIcon) as? Bool ?? true
        self.appLanguage = AppLanguage.initial(defaults: defaults)
        self.captureText = defaults.object(forKey: Keys.captureText) as? Bool ?? true
        self.captureImages = defaults.object(forKey: Keys.captureImages) as? Bool ?? true
        self.isMonitoringPaused = defaults.object(forKey: Keys.isMonitoringPaused) as? Bool ?? false
        self.lastFiniteHistoryItems = Self.normalizedFiniteHistoryItems(
            defaults.object(forKey: Keys.lastFiniteHistoryItems) as? Int ?? 200
        )
        self.maximumHistoryItems = Self.normalizedMaximumHistoryItems(
            defaults.object(forKey: Keys.maximumHistoryItems) as? Int ?? 200
        )
        self.autoPasteAfterSelection = defaults.object(forKey: Keys.autoPasteAfterSelection) as? Bool ?? true
        self.pasteDelay = Self.clamp(
            defaults.object(forKey: Keys.pasteDelay) as? Double ?? 0.12,
            min: 0.05,
            max: 0.30
        )
        self.reactivatePreviousAppBeforePaste = defaults.object(forKey: Keys.reactivatePreviousAppBeforePaste) as? Bool ?? true
        self.overlayHeight = Self.clamp(
            defaults.object(forKey: Keys.overlayHeight) as? Double ?? 260,
            min: 220,
            max: 360
        )
        self.cardSizePreset = CardSizePreset(rawValue: defaults.string(forKey: Keys.cardSizePreset) ?? "") ?? .comfortable
        self.showTimestampsOnCards = defaults.object(forKey: Keys.showTimestampsOnCards) as? Bool ?? true
        self.showMetadataOnCards = defaults.object(forKey: Keys.showMetadataOnCards) as? Bool ?? true
        self.cornerRadiusIntensity = Self.clamp(
            defaults.object(forKey: Keys.cornerRadiusIntensity) as? Double ?? 16,
            min: 0,
            max: 28
        )
        self.launchAtLogin = Self.currentLaunchAtLoginState()
    }

    var monitoringStatusText: String {
        isMonitoringPaused ? L10n.tr("status.monitoring_paused") : L10n.tr("status.monitoring_active")
    }

    var hasUnlimitedHistory: Bool {
        maximumHistoryItems == 0
    }

    var historyLimit: Int? {
        hasUnlimitedHistory ? nil : maximumHistoryItems
    }

    var finiteHistoryItems: Int {
        hasUnlimitedHistory ? lastFiniteHistoryItems : maximumHistoryItems
    }

    func setUnlimitedHistory(_ enabled: Bool) {
        if enabled {
            maximumHistoryItems = 0
        } else if maximumHistoryItems == 0 {
            maximumHistoryItems = lastFiniteHistoryItems
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp

        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }

            launchAtLogin = enabled
            launchAtLoginStatusMessage = nil
        } catch {
            launchAtLogin = Self.currentLaunchAtLoginState()
            launchAtLoginStatusMessage = enabled
                ? L10n.tr("status.launch_at_login_enable_failed")
                : L10n.tr("status.launch_at_login_disable_failed")
        }
    }

    func refreshLaunchAtLoginState() {
        launchAtLogin = Self.currentLaunchAtLoginState()
    }

    private func persist(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    private func persist(_ value: Int, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    private func persist(_ value: Double, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    private func persist(_ value: String, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    private static func currentLaunchAtLoginState() -> Bool {
        switch SMAppService.mainApp.status {
        case .enabled:
            return true
        default:
            return false
        }
    }

    nonisolated static func normalizedFiniteHistoryItems(_ value: Int) -> Int {
        clamp(value, min: 10, max: 1000)
    }

    nonisolated static func normalizedMaximumHistoryItems(_ value: Int) -> Int {
        value <= 0 ? 0 : normalizedFiniteHistoryItems(value)
    }

    nonisolated private static func clamp<T: Comparable>(_ value: T, min lowerBound: T, max upperBound: T) -> T {
        Swift.min(Swift.max(value, lowerBound), upperBound)
    }
}

private enum Keys {
    static let showMenuBarIcon = "TahoePasteShowMenuBarIcon"
    static let appLanguage = "TahoePasteAppLanguage"
    static let captureText = "TahoePasteCaptureText"
    static let captureImages = "TahoePasteCaptureImages"
    static let isMonitoringPaused = "TahoePasteMonitoringPaused"
    static let maximumHistoryItems = "TahoePasteMaximumHistoryItems"
    static let lastFiniteHistoryItems = "TahoePasteLastFiniteHistoryItems"
    static let autoPasteAfterSelection = "TahoePasteAutoPasteAfterSelection"
    static let pasteDelay = "TahoePastePasteDelay"
    static let reactivatePreviousAppBeforePaste = "TahoePasteReactivatePreviousAppBeforePaste"
    static let overlayHeight = "TahoePasteOverlayHeight"
    static let cardSizePreset = "TahoePasteCardSizePreset"
    static let showTimestampsOnCards = "TahoePasteShowTimestampsOnCards"
    static let showMetadataOnCards = "TahoePasteShowMetadataOnCards"
    static let cornerRadiusIntensity = "TahoePasteCornerRadiusIntensity"
}
