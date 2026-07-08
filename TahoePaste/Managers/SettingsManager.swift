import AppKit
import Combine
import Foundation
import ServiceManagement
import SwiftUI

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

    struct OverlayLayout {
        let topBarHeight: CGFloat
        let bottomInset: CGFloat
        let cardSpacing: CGFloat
        let contentPadding: CGFloat
        let cardHeight: CGFloat
        let textCardWidth: CGFloat
        let imageCardWidth: CGFloat
        let toolbarIconSize: CGFloat
        let toolbarIconPadding: CGFloat
        let toolbarIconSpacing: CGFloat
        // Positive values push the toolbar icons down (towards the cards),
        // negative values lift them; 0 keeps them centered in the top bar.
        let toolbarVerticalOffset: CGFloat
        let searchBubbleWidth: CGFloat
        let searchBubbleHeight: CGFloat
        // Offsets from the centered position: positive x moves the bubble
        // right, positive y moves it down.
        let searchBubbleHorizontalOffset: CGFloat
        let searchBubbleVerticalOffset: CGFloat
        // Window geometry: total overlay height and its distances from the
        // screen edges (cards stay anchored bottomInset above the window
        // bottom, so extra height opens up below the top bar).
        let overlayHeight: CGFloat
        let overlayScreenHorizontalInset: CGFloat
        let overlayScreenBottomInset: CGFloat

        var totalCardHeight: CGFloat {
            cardHeight + contentPadding * 2
        }

        static func automatic(for preset: CardSizePreset) -> OverlayLayout {
            let topBarHeight: CGFloat = 31
            let bottomInset: CGFloat = 31
            let totalCardHeight = preset.cardHeight + preset.contentPadding * 2

            return OverlayLayout(
                topBarHeight: topBarHeight,
                bottomInset: bottomInset,
                cardSpacing: 16,
                contentPadding: preset.contentPadding,
                cardHeight: preset.cardHeight,
                textCardWidth: preset.textCardWidth,
                imageCardWidth: preset.imageCardWidth,
                toolbarIconSize: 10,
                toolbarIconPadding: 4,
                toolbarIconSpacing: 8,
                toolbarVerticalOffset: 0,
                searchBubbleWidth: 480,
                searchBubbleHeight: 30,
                searchBubbleHorizontalOffset: 0,
                searchBubbleVerticalOffset: 0,
                overlayHeight: topBarHeight + totalCardHeight + bottomInset,
                overlayScreenHorizontalInset: 0,
                overlayScreenBottomInset: 0
            )
        }
    }

    enum ThemeMode: String, CaseIterable, Identifiable {
        case system
        case day
        case night
        case scheduled

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .system:
                return L10n.tr("settings.theme_mode.system")
            case .day:
                return L10n.tr("settings.theme_mode.day")
            case .night:
                return L10n.tr("settings.theme_mode.night")
            case .scheduled:
                return L10n.tr("settings.theme_mode.schedule")
            }
        }
    }

    enum Theme: String, CaseIterable, Identifiable {
        case day
        case night

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .day:
                return L10n.tr("settings.theme_mode.day")
            case .night:
                return L10n.tr("settings.theme_mode.night")
            }
        }

        var colorScheme: ColorScheme {
            switch self {
            case .day:
                return .light
            case .night:
                return .dark
            }
        }

        var nsAppearance: NSAppearance? {
            switch self {
            case .day:
                return NSAppearance(named: .aqua)
            case .night:
                return NSAppearance(named: .darkAqua)
            }
        }
    }

    struct ThemePalette {
        let overlayGradientTop: Color
        let overlayGradientBottom: Color
        let overlayEdgeHighlight: Color
        let overlayPrimaryText: Color
        let overlaySecondaryText: Color
        let overlayBubbleFill: Color
        let overlayBubbleBorder: Color
        let overlayToolbarIcon: Color
        let cardGradientTop: Color
        let cardGradientBottom: Color
        let cardBorder: Color
        let cardPrimaryText: Color
        let cardSecondaryText: Color
        let cardTextMetadata: Color
        let cardTextTag: Color
        let cardDeleteIcon: Color
        let cardLinkText: Color
        let imageMetadataText: Color
        let imageTagText: Color
        let imageFallbackText: Color

        static func palette(for theme: Theme) -> ThemePalette {
            switch theme {
            case .day:
                return ThemePalette(
                    overlayGradientTop: Color(red: 0.95, green: 0.97, blue: 1.00).opacity(0.96),
                    overlayGradientBottom: Color(red: 0.86, green: 0.91, blue: 0.98).opacity(0.99),
                    overlayEdgeHighlight: Color.white.opacity(0.78),
                    overlayPrimaryText: Color(red: 0.15, green: 0.20, blue: 0.28),
                    overlaySecondaryText: Color(red: 0.30, green: 0.37, blue: 0.48),
                    overlayBubbleFill: Color(red: 0.98, green: 0.99, blue: 1.00).opacity(0.96),
                    overlayBubbleBorder: Color(red: 0.67, green: 0.76, blue: 0.89).opacity(0.55),
                    overlayToolbarIcon: Color(red: 0.31, green: 0.40, blue: 0.54),
                    cardGradientTop: Color(red: 1.00, green: 1.00, blue: 1.00),
                    cardGradientBottom: Color(red: 0.92, green: 0.96, blue: 1.00),
                    cardBorder: Color(red: 0.67, green: 0.76, blue: 0.89).opacity(0.65),
                    cardPrimaryText: Color(red: 0.18, green: 0.22, blue: 0.30),
                    cardSecondaryText: Color(red: 0.39, green: 0.48, blue: 0.61),
                    cardTextMetadata: Color(red: 0.43, green: 0.52, blue: 0.64),
                    cardTextTag: Color(red: 0.25, green: 0.38, blue: 0.56),
                    cardDeleteIcon: Color(red: 0.34, green: 0.44, blue: 0.58),
                    cardLinkText: Color(red: 0.11, green: 0.40, blue: 0.74),
                    imageMetadataText: .white,
                    imageTagText: .white,
                    imageFallbackText: Color(red: 0.34, green: 0.44, blue: 0.58)
                )
            case .night:
                return ThemePalette(
                    overlayGradientTop: Color(red: 0.08, green: 0.10, blue: 0.13).opacity(0.94),
                    overlayGradientBottom: Color(red: 0.13, green: 0.15, blue: 0.19).opacity(0.98),
                    overlayEdgeHighlight: Color.white.opacity(0.05),
                    overlayPrimaryText: .white,
                    overlaySecondaryText: Color.white.opacity(0.68),
                    overlayBubbleFill: Color(red: 0.16, green: 0.18, blue: 0.22).opacity(0.98),
                    overlayBubbleBorder: Color.white.opacity(0.08),
                    overlayToolbarIcon: Color(red: 0.72, green: 0.75, blue: 0.80),
                    cardGradientTop: Color(red: 0.20, green: 0.23, blue: 0.29),
                    cardGradientBottom: Color(red: 0.10, green: 0.12, blue: 0.16),
                    cardBorder: Color.white.opacity(0.10),
                    cardPrimaryText: .white,
                    cardSecondaryText: Color(red: 0.72, green: 0.75, blue: 0.80),
                    cardTextMetadata: Color(red: 0.72, green: 0.75, blue: 0.80),
                    cardTextTag: Color(red: 0.90, green: 0.93, blue: 0.98),
                    cardDeleteIcon: Color(red: 0.72, green: 0.75, blue: 0.80),
                    cardLinkText: Color(red: 0.84, green: 0.92, blue: 1.00),
                    imageMetadataText: .white,
                    imageTagText: .white,
                    imageFallbackText: Color.white.opacity(0.66)
                )
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
    @Published private(set) var launchAtLoginRequiresApproval: Bool

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

    @Published var cardSizePreset: CardSizePreset {
        didSet { persist(cardSizePreset.rawValue, forKey: Keys.cardSizePreset) }
    }

    @Published var useAutomaticOverlayLayout: Bool {
        didSet {
            persist(useAutomaticOverlayLayout, forKey: Keys.useAutomaticOverlayLayout)

            // Manual sliders pick up from the layout the user currently sees.
            if oldValue, useAutomaticOverlayLayout == false {
                seedManualLayout(from: .automatic(for: cardSizePreset))
            }
        }
    }

    @Published var manualTopBarHeight: Double {
        didSet {
            let clampedValue = Self.clamp(manualTopBarHeight, min: 20, max: 56)
            guard manualTopBarHeight == clampedValue else {
                manualTopBarHeight = clampedValue
                return
            }
            persist(manualTopBarHeight, forKey: Keys.manualTopBarHeight)
        }
    }

    @Published var manualBottomInset: Double {
        didSet {
            let clampedValue = Self.clamp(manualBottomInset, min: 0, max: 56)
            guard manualBottomInset == clampedValue else {
                manualBottomInset = clampedValue
                return
            }
            persist(manualBottomInset, forKey: Keys.manualBottomInset)
        }
    }

    @Published var manualCardSpacing: Double {
        didSet {
            let clampedValue = Self.clamp(manualCardSpacing, min: 4, max: 40)
            guard manualCardSpacing == clampedValue else {
                manualCardSpacing = clampedValue
                return
            }
            persist(manualCardSpacing, forKey: Keys.manualCardSpacing)
        }
    }

    @Published var manualCardContentPadding: Double {
        didSet {
            let clampedValue = Self.clamp(manualCardContentPadding, min: 8, max: 32)
            guard manualCardContentPadding == clampedValue else {
                manualCardContentPadding = clampedValue
                return
            }
            persist(manualCardContentPadding, forKey: Keys.manualCardContentPadding)
        }
    }

    @Published var manualCardHeight: Double {
        didSet {
            let clampedValue = Self.clamp(manualCardHeight, min: 120, max: 280)
            guard manualCardHeight == clampedValue else {
                manualCardHeight = clampedValue
                return
            }
            persist(manualCardHeight, forKey: Keys.manualCardHeight)
        }
    }

    @Published var manualTextCardWidth: Double {
        didSet {
            let clampedValue = Self.clamp(manualTextCardWidth, min: 200, max: 420)
            guard manualTextCardWidth == clampedValue else {
                manualTextCardWidth = clampedValue
                return
            }
            persist(manualTextCardWidth, forKey: Keys.manualTextCardWidth)
        }
    }

    @Published var manualImageCardWidth: Double {
        didSet {
            let clampedValue = Self.clamp(manualImageCardWidth, min: 160, max: 340)
            guard manualImageCardWidth == clampedValue else {
                manualImageCardWidth = clampedValue
                return
            }
            persist(manualImageCardWidth, forKey: Keys.manualImageCardWidth)
        }
    }

    @Published var manualToolbarIconSize: Double {
        didSet {
            let clampedValue = Self.clamp(manualToolbarIconSize, min: 8, max: 20)
            guard manualToolbarIconSize == clampedValue else {
                manualToolbarIconSize = clampedValue
                return
            }
            persist(manualToolbarIconSize, forKey: Keys.manualToolbarIconSize)
        }
    }

    @Published var manualToolbarIconPadding: Double {
        didSet {
            let clampedValue = Self.clamp(manualToolbarIconPadding, min: 0, max: 12)
            guard manualToolbarIconPadding == clampedValue else {
                manualToolbarIconPadding = clampedValue
                return
            }
            persist(manualToolbarIconPadding, forKey: Keys.manualToolbarIconPadding)
        }
    }

    @Published var manualToolbarIconSpacing: Double {
        didSet {
            let clampedValue = Self.clamp(manualToolbarIconSpacing, min: 0, max: 24)
            guard manualToolbarIconSpacing == clampedValue else {
                manualToolbarIconSpacing = clampedValue
                return
            }
            persist(manualToolbarIconSpacing, forKey: Keys.manualToolbarIconSpacing)
        }
    }

    @Published var manualToolbarVerticalOffset: Double {
        didSet {
            let clampedValue = Self.clamp(manualToolbarVerticalOffset, min: -16, max: 24)
            guard manualToolbarVerticalOffset == clampedValue else {
                manualToolbarVerticalOffset = clampedValue
                return
            }
            persist(manualToolbarVerticalOffset, forKey: Keys.manualToolbarVerticalOffset)
        }
    }

    @Published var manualSearchBubbleWidth: Double {
        didSet {
            let clampedValue = Self.clamp(manualSearchBubbleWidth, min: 240, max: 800)
            guard manualSearchBubbleWidth == clampedValue else {
                manualSearchBubbleWidth = clampedValue
                return
            }
            persist(manualSearchBubbleWidth, forKey: Keys.manualSearchBubbleWidth)
        }
    }

    @Published var manualSearchBubbleHeight: Double {
        didSet {
            let clampedValue = Self.clamp(manualSearchBubbleHeight, min: 22, max: 48)
            guard manualSearchBubbleHeight == clampedValue else {
                manualSearchBubbleHeight = clampedValue
                return
            }
            persist(manualSearchBubbleHeight, forKey: Keys.manualSearchBubbleHeight)
        }
    }

    @Published var manualSearchBubbleHorizontalOffset: Double {
        didSet {
            let clampedValue = Self.clamp(manualSearchBubbleHorizontalOffset, min: -200, max: 200)
            guard manualSearchBubbleHorizontalOffset == clampedValue else {
                manualSearchBubbleHorizontalOffset = clampedValue
                return
            }
            persist(manualSearchBubbleHorizontalOffset, forKey: Keys.manualSearchBubbleHorizontalOffset)
        }
    }

    @Published var manualSearchBubbleVerticalOffset: Double {
        didSet {
            let clampedValue = Self.clamp(manualSearchBubbleVerticalOffset, min: -16, max: 24)
            guard manualSearchBubbleVerticalOffset == clampedValue else {
                manualSearchBubbleVerticalOffset = clampedValue
                return
            }
            persist(manualSearchBubbleVerticalOffset, forKey: Keys.manualSearchBubbleVerticalOffset)
        }
    }

    @Published var manualOverlayHeight: Double {
        didSet {
            let clampedValue = Self.clamp(manualOverlayHeight, min: 160, max: 600)
            guard manualOverlayHeight == clampedValue else {
                manualOverlayHeight = clampedValue
                return
            }
            persist(manualOverlayHeight, forKey: Keys.manualOverlayHeight)
        }
    }

    @Published var manualOverlayScreenHorizontalInset: Double {
        didSet {
            let clampedValue = Self.clamp(manualOverlayScreenHorizontalInset, min: 0, max: 400)
            guard manualOverlayScreenHorizontalInset == clampedValue else {
                manualOverlayScreenHorizontalInset = clampedValue
                return
            }
            persist(manualOverlayScreenHorizontalInset, forKey: Keys.manualOverlayScreenHorizontalInset)
        }
    }

    @Published var manualOverlayScreenBottomInset: Double {
        didSet {
            let clampedValue = Self.clamp(manualOverlayScreenBottomInset, min: 0, max: 300)
            guard manualOverlayScreenBottomInset == clampedValue else {
                manualOverlayScreenBottomInset = clampedValue
                return
            }
            persist(manualOverlayScreenBottomInset, forKey: Keys.manualOverlayScreenBottomInset)
        }
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

    @Published var themeMode: ThemeMode {
        didSet {
            persist(themeMode.rawValue, forKey: Keys.themeMode)
            refreshThemeState()
        }
    }

    @Published var dayThemeStartMinutes: Int {
        didSet {
            let normalizedValue = Self.normalizedMinutesSinceMidnight(dayThemeStartMinutes)
            guard dayThemeStartMinutes == normalizedValue else {
                dayThemeStartMinutes = normalizedValue
                return
            }

            persist(dayThemeStartMinutes, forKey: Keys.dayThemeStartMinutes)
            refreshThemeState()
        }
    }

    @Published var nightThemeStartMinutes: Int {
        didSet {
            let normalizedValue = Self.normalizedMinutesSinceMidnight(nightThemeStartMinutes)
            guard nightThemeStartMinutes == normalizedValue else {
                nightThemeStartMinutes = normalizedValue
                return
            }

            persist(nightThemeStartMinutes, forKey: Keys.nightThemeStartMinutes)
            refreshThemeState()
        }
    }

    @Published private(set) var activeTheme: Theme

    private var showMenuBarIconValue: Bool
    private var lastFiniteHistoryItems: Int
    private let defaults: UserDefaults
    private var themeTransitionTimer: Timer?

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
        self.cardSizePreset = CardSizePreset(rawValue: defaults.string(forKey: Keys.cardSizePreset) ?? "") ?? .comfortable
        let defaultLayout = OverlayLayout.automatic(for: .comfortable)
        self.useAutomaticOverlayLayout = defaults.object(forKey: Keys.useAutomaticOverlayLayout) as? Bool ?? true
        self.manualTopBarHeight = Self.clamp(
            defaults.object(forKey: Keys.manualTopBarHeight) as? Double ?? Double(defaultLayout.topBarHeight),
            min: 20,
            max: 56
        )
        self.manualBottomInset = Self.clamp(
            defaults.object(forKey: Keys.manualBottomInset) as? Double ?? Double(defaultLayout.bottomInset),
            min: 0,
            max: 56
        )
        self.manualCardSpacing = Self.clamp(
            defaults.object(forKey: Keys.manualCardSpacing) as? Double ?? Double(defaultLayout.cardSpacing),
            min: 4,
            max: 40
        )
        self.manualCardContentPadding = Self.clamp(
            defaults.object(forKey: Keys.manualCardContentPadding) as? Double ?? Double(defaultLayout.contentPadding),
            min: 8,
            max: 32
        )
        self.manualCardHeight = Self.clamp(
            defaults.object(forKey: Keys.manualCardHeight) as? Double ?? Double(defaultLayout.cardHeight),
            min: 120,
            max: 280
        )
        self.manualTextCardWidth = Self.clamp(
            defaults.object(forKey: Keys.manualTextCardWidth) as? Double ?? Double(defaultLayout.textCardWidth),
            min: 200,
            max: 420
        )
        self.manualImageCardWidth = Self.clamp(
            defaults.object(forKey: Keys.manualImageCardWidth) as? Double ?? Double(defaultLayout.imageCardWidth),
            min: 160,
            max: 340
        )
        self.manualToolbarIconSize = Self.clamp(
            defaults.object(forKey: Keys.manualToolbarIconSize) as? Double ?? Double(defaultLayout.toolbarIconSize),
            min: 8,
            max: 20
        )
        self.manualToolbarIconPadding = Self.clamp(
            defaults.object(forKey: Keys.manualToolbarIconPadding) as? Double ?? Double(defaultLayout.toolbarIconPadding),
            min: 0,
            max: 12
        )
        self.manualToolbarIconSpacing = Self.clamp(
            defaults.object(forKey: Keys.manualToolbarIconSpacing) as? Double ?? Double(defaultLayout.toolbarIconSpacing),
            min: 0,
            max: 24
        )
        self.manualToolbarVerticalOffset = Self.clamp(
            defaults.object(forKey: Keys.manualToolbarVerticalOffset) as? Double ?? Double(defaultLayout.toolbarVerticalOffset),
            min: -16,
            max: 24
        )
        self.manualSearchBubbleWidth = Self.clamp(
            defaults.object(forKey: Keys.manualSearchBubbleWidth) as? Double ?? Double(defaultLayout.searchBubbleWidth),
            min: 240,
            max: 800
        )
        self.manualSearchBubbleHeight = Self.clamp(
            defaults.object(forKey: Keys.manualSearchBubbleHeight) as? Double ?? Double(defaultLayout.searchBubbleHeight),
            min: 22,
            max: 48
        )
        self.manualSearchBubbleHorizontalOffset = Self.clamp(
            defaults.object(forKey: Keys.manualSearchBubbleHorizontalOffset) as? Double ?? Double(defaultLayout.searchBubbleHorizontalOffset),
            min: -200,
            max: 200
        )
        self.manualSearchBubbleVerticalOffset = Self.clamp(
            defaults.object(forKey: Keys.manualSearchBubbleVerticalOffset) as? Double ?? Double(defaultLayout.searchBubbleVerticalOffset),
            min: -16,
            max: 24
        )
        self.manualOverlayHeight = Self.clamp(
            defaults.object(forKey: Keys.manualOverlayHeight) as? Double ?? Double(defaultLayout.overlayHeight),
            min: 160,
            max: 600
        )
        self.manualOverlayScreenHorizontalInset = Self.clamp(
            defaults.object(forKey: Keys.manualOverlayScreenHorizontalInset) as? Double ?? Double(defaultLayout.overlayScreenHorizontalInset),
            min: 0,
            max: 400
        )
        self.manualOverlayScreenBottomInset = Self.clamp(
            defaults.object(forKey: Keys.manualOverlayScreenBottomInset) as? Double ?? Double(defaultLayout.overlayScreenBottomInset),
            min: 0,
            max: 300
        )
        self.showTimestampsOnCards = defaults.object(forKey: Keys.showTimestampsOnCards) as? Bool ?? true
        self.showMetadataOnCards = defaults.object(forKey: Keys.showMetadataOnCards) as? Bool ?? true
        self.cornerRadiusIntensity = Self.clamp(
            defaults.object(forKey: Keys.cornerRadiusIntensity) as? Double ?? 16,
            min: 0,
            max: 28
        )
        let initialThemeMode = ThemeMode(rawValue: defaults.string(forKey: Keys.themeMode) ?? "") ?? .system
        let initialDayThemeStartMinutes = Self.normalizedMinutesSinceMidnight(
            defaults.object(forKey: Keys.dayThemeStartMinutes) as? Int ?? 8 * 60
        )
        let initialNightThemeStartMinutes = Self.normalizedMinutesSinceMidnight(
            defaults.object(forKey: Keys.nightThemeStartMinutes) as? Int ?? 20 * 60
        )
        self.themeMode = initialThemeMode
        self.dayThemeStartMinutes = initialDayThemeStartMinutes
        self.nightThemeStartMinutes = initialNightThemeStartMinutes
        self.activeTheme = Self.resolvedTheme(
            mode: initialThemeMode,
            systemIsDark: Self.currentSystemIsDark(),
            dayThemeStartMinutes: initialDayThemeStartMinutes,
            nightThemeStartMinutes: initialNightThemeStartMinutes,
            nowMinutesSinceMidnight: Self.minutesSinceMidnight(from: Date())
        )
        let launchAtLoginStatus = Self.currentLaunchAtLoginStatus()
        self.launchAtLogin = Self.isLaunchAtLoginEnabled(for: launchAtLoginStatus)
        self.launchAtLoginStatusMessage = Self.launchAtLoginStatusMessage(for: launchAtLoginStatus)
        self.launchAtLoginRequiresApproval = Self.launchAtLoginRequiresApproval(for: launchAtLoginStatus)
        refreshThemeState()
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

    var themePalette: ThemePalette {
        ThemePalette.palette(for: activeTheme)
    }

    var overlayLayout: OverlayLayout {
        guard useAutomaticOverlayLayout == false else {
            return .automatic(for: cardSizePreset)
        }

        return OverlayLayout(
            topBarHeight: CGFloat(manualTopBarHeight),
            bottomInset: CGFloat(manualBottomInset),
            cardSpacing: CGFloat(manualCardSpacing),
            contentPadding: CGFloat(manualCardContentPadding),
            cardHeight: CGFloat(manualCardHeight),
            textCardWidth: CGFloat(manualTextCardWidth),
            imageCardWidth: CGFloat(manualImageCardWidth),
            toolbarIconSize: CGFloat(manualToolbarIconSize),
            toolbarIconPadding: CGFloat(manualToolbarIconPadding),
            toolbarIconSpacing: CGFloat(manualToolbarIconSpacing),
            toolbarVerticalOffset: CGFloat(manualToolbarVerticalOffset),
            searchBubbleWidth: CGFloat(manualSearchBubbleWidth),
            searchBubbleHeight: CGFloat(manualSearchBubbleHeight),
            searchBubbleHorizontalOffset: CGFloat(manualSearchBubbleHorizontalOffset),
            searchBubbleVerticalOffset: CGFloat(manualSearchBubbleVerticalOffset),
            overlayHeight: CGFloat(manualOverlayHeight),
            overlayScreenHorizontalInset: CGFloat(manualOverlayScreenHorizontalInset),
            overlayScreenBottomInset: CGFloat(manualOverlayScreenBottomInset)
        )
    }

    private func seedManualLayout(from layout: OverlayLayout) {
        manualTopBarHeight = Double(layout.topBarHeight)
        manualBottomInset = Double(layout.bottomInset)
        manualCardSpacing = Double(layout.cardSpacing)
        manualCardContentPadding = Double(layout.contentPadding)
        manualCardHeight = Double(layout.cardHeight)
        manualTextCardWidth = Double(layout.textCardWidth)
        manualImageCardWidth = Double(layout.imageCardWidth)
        manualToolbarIconSize = Double(layout.toolbarIconSize)
        manualToolbarIconPadding = Double(layout.toolbarIconPadding)
        manualToolbarIconSpacing = Double(layout.toolbarIconSpacing)
        manualToolbarVerticalOffset = Double(layout.toolbarVerticalOffset)
        manualSearchBubbleWidth = Double(layout.searchBubbleWidth)
        manualSearchBubbleHeight = Double(layout.searchBubbleHeight)
        manualSearchBubbleHorizontalOffset = Double(layout.searchBubbleHorizontalOffset)
        manualSearchBubbleVerticalOffset = Double(layout.searchBubbleVerticalOffset)
        manualOverlayHeight = Double(layout.overlayHeight)
        manualOverlayScreenHorizontalInset = Double(layout.overlayScreenHorizontalInset)
        manualOverlayScreenBottomInset = Double(layout.overlayScreenBottomInset)
    }

    var preferredColorScheme: ColorScheme? {
        themeMode == .system ? nil : activeTheme.colorScheme
    }

    var nsAppearance: NSAppearance? {
        themeMode == .system ? nil : activeTheme.nsAppearance
    }

    func setUnlimitedHistory(_ enabled: Bool) {
        if enabled {
            maximumHistoryItems = 0
        } else if maximumHistoryItems == 0 {
            maximumHistoryItems = lastFiniteHistoryItems
        }
    }

    func refreshThemeState(systemAppearance: NSAppearance? = nil, now: Date = Date()) {
        let resolvedTheme = Self.resolvedTheme(
            mode: themeMode,
            systemIsDark: Self.isDarkAppearance(systemAppearance),
            dayThemeStartMinutes: dayThemeStartMinutes,
            nightThemeStartMinutes: nightThemeStartMinutes,
            nowMinutesSinceMidnight: Self.minutesSinceMidnight(from: now)
        )

        if activeTheme != resolvedTheme {
            activeTheme = resolvedTheme
        }

        rescheduleThemeTransition(after: now)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp

        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }

            syncLaunchAtLoginState(with: service.status)
        } catch {
            syncLaunchAtLoginState()
            launchAtLoginStatusMessage = enabled
                ? L10n.tr("status.launch_at_login_enable_failed")
                : L10n.tr("status.launch_at_login_disable_failed")
        }
    }

    func refreshLaunchAtLoginState() {
        syncLaunchAtLoginState()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
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

    private func syncLaunchAtLoginState(with status: SMAppService.Status? = nil) {
        let resolvedStatus = status ?? Self.currentLaunchAtLoginStatus()
        launchAtLogin = Self.isLaunchAtLoginEnabled(for: resolvedStatus)
        launchAtLoginStatusMessage = Self.launchAtLoginStatusMessage(for: resolvedStatus)
        launchAtLoginRequiresApproval = Self.launchAtLoginRequiresApproval(for: resolvedStatus)
    }

    nonisolated static func isLaunchAtLoginEnabled(for status: SMAppService.Status) -> Bool {
        switch status {
        case .enabled, .requiresApproval:
            return true
        default:
            return false
        }
    }

    nonisolated static func launchAtLoginStatusMessage(for status: SMAppService.Status) -> String? {
        switch status {
        case .requiresApproval:
            return L10n.tr("status.launch_at_login_needs_approval")
        default:
            return nil
        }
    }

    nonisolated static func launchAtLoginRequiresApproval(for status: SMAppService.Status) -> Bool {
        status == .requiresApproval
    }

    nonisolated static func resolvedTheme(
        mode: ThemeMode,
        systemIsDark: Bool,
        dayThemeStartMinutes: Int,
        nightThemeStartMinutes: Int,
        nowMinutesSinceMidnight: Int
    ) -> Theme {
        switch mode {
        case .system:
            return systemIsDark ? .night : .day
        case .day:
            return .day
        case .night:
            return .night
        case .scheduled:
            let normalizedNow = normalizedMinutesSinceMidnight(nowMinutesSinceMidnight)
            let normalizedDay = normalizedMinutesSinceMidnight(dayThemeStartMinutes)
            let normalizedNight = normalizedMinutesSinceMidnight(nightThemeStartMinutes)

            guard normalizedDay != normalizedNight else {
                return .day
            }

            if normalizedDay < normalizedNight {
                return (normalizedDay..<normalizedNight).contains(normalizedNow) ? .day : .night
            }

            return normalizedNow >= normalizedDay || normalizedNow < normalizedNight ? .day : .night
        }
    }

    nonisolated static func minutesSinceMidnight(from date: Date, calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    nonisolated static func dateForTimePicker(minutesSinceMidnight: Int, calendar: Calendar = .current) -> Date {
        let normalizedMinutes = normalizedMinutesSinceMidnight(minutesSinceMidnight)
        let startOfDay = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .minute, value: normalizedMinutes, to: startOfDay) ?? startOfDay
    }

    nonisolated static func normalizedMinutesSinceMidnight(_ value: Int) -> Int {
        let totalMinutes = 24 * 60
        let remainder = value % totalMinutes
        return remainder >= 0 ? remainder : remainder + totalMinutes
    }

    private static func currentLaunchAtLoginStatus() -> SMAppService.Status {
        SMAppService.mainApp.status
    }

    private func rescheduleThemeTransition(after now: Date) {
        themeTransitionTimer?.invalidate()
        themeTransitionTimer = nil

        guard themeMode == .scheduled,
              let nextTransitionDate = Self.nextScheduledThemeTransitionDate(
                  after: now,
                  dayThemeStartMinutes: dayThemeStartMinutes,
                  nightThemeStartMinutes: nightThemeStartMinutes
              )
        else {
            return
        }

        let interval = max(nextTransitionDate.timeIntervalSince(now), 1)
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.refreshThemeState()
            }
        }
        timer.tolerance = min(60, interval * 0.05)
        themeTransitionTimer = timer
    }

    nonisolated private static func nextScheduledThemeTransitionDate(
        after date: Date,
        dayThemeStartMinutes: Int,
        nightThemeStartMinutes: Int,
        calendar: Calendar = .current
    ) -> Date? {
        let dayStart = normalizedMinutesSinceMidnight(dayThemeStartMinutes)
        let nightStart = normalizedMinutesSinceMidnight(nightThemeStartMinutes)

        guard dayStart != nightStart else {
            return nil
        }

        return [dayStart, nightStart]
            .compactMap { minutes in
                let startOfDay = calendar.startOfDay(for: date)
                let candidate = calendar.date(byAdding: .minute, value: minutes, to: startOfDay)

                guard let candidate else {
                    return nil
                }

                if candidate > date {
                    return candidate
                }

                return calendar.date(byAdding: .day, value: 1, to: candidate)
            }
            .min()
    }

    private static func isDarkAppearance(_ appearance: NSAppearance? = nil) -> Bool {
        let resolvedAppearance = appearance ?? NSApp?.effectiveAppearance
        return resolvedAppearance?.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private static func currentSystemIsDark() -> Bool {
        isDarkAppearance()
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
    static let cardSizePreset = "TahoePasteCardSizePreset"
    static let useAutomaticOverlayLayout = "TahoePasteUseAutomaticOverlayLayout"
    static let manualTopBarHeight = "TahoePasteManualTopBarHeight"
    static let manualBottomInset = "TahoePasteManualBottomInset"
    static let manualCardSpacing = "TahoePasteManualCardSpacing"
    static let manualCardContentPadding = "TahoePasteManualCardContentPadding"
    static let manualCardHeight = "TahoePasteManualCardHeight"
    static let manualTextCardWidth = "TahoePasteManualTextCardWidth"
    static let manualImageCardWidth = "TahoePasteManualImageCardWidth"
    static let manualToolbarIconSize = "TahoePasteManualToolbarIconSize"
    static let manualToolbarIconPadding = "TahoePasteManualToolbarIconPadding"
    static let manualToolbarIconSpacing = "TahoePasteManualToolbarIconSpacing"
    static let manualToolbarVerticalOffset = "TahoePasteManualToolbarVerticalOffset"
    static let manualSearchBubbleWidth = "TahoePasteManualSearchBubbleWidth"
    static let manualSearchBubbleHeight = "TahoePasteManualSearchBubbleHeight"
    static let manualSearchBubbleHorizontalOffset = "TahoePasteManualSearchBubbleHorizontalOffset"
    static let manualSearchBubbleVerticalOffset = "TahoePasteManualSearchBubbleVerticalOffset"
    static let manualOverlayHeight = "TahoePasteManualOverlayHeight"
    static let manualOverlayScreenHorizontalInset = "TahoePasteManualOverlayScreenHorizontalInset"
    static let manualOverlayScreenBottomInset = "TahoePasteManualOverlayScreenBottomInset"
    static let showTimestampsOnCards = "TahoePasteShowTimestampsOnCards"
    static let showMetadataOnCards = "TahoePasteShowMetadataOnCards"
    static let cornerRadiusIntensity = "TahoePasteCornerRadiusIntensity"
    static let themeMode = "TahoePasteThemeMode"
    static let dayThemeStartMinutes = "TahoePasteDayThemeStartMinutes"
    static let nightThemeStartMinutes = "TahoePasteNightThemeStartMinutes"
}
