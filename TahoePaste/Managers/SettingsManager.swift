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
    static let overlayHeight = "TahoePasteOverlayHeight"
    static let cardSizePreset = "TahoePasteCardSizePreset"
    static let showTimestampsOnCards = "TahoePasteShowTimestampsOnCards"
    static let showMetadataOnCards = "TahoePasteShowMetadataOnCards"
    static let cornerRadiusIntensity = "TahoePasteCornerRadiusIntensity"
    static let themeMode = "TahoePasteThemeMode"
    static let dayThemeStartMinutes = "TahoePasteDayThemeStartMinutes"
    static let nightThemeStartMinutes = "TahoePasteNightThemeStartMinutes"
}
