import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var historyViewModel: ClipboardHistoryViewModel

    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                generalSection
                clipboardSection
                pasteSection
                appearanceSection
                storageAndPermissionsSection

                if let statusMessage = historyViewModel.statusMessage {
                    statusFooter(statusMessage)
                }
            }
            .padding(24)
        }
        .frame(width: 700, height: 760)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(settingsManager.preferredColorScheme)
        .confirmationDialog(
            L10n.tr("dialog.delete_history_title"),
            isPresented: $isShowingDeleteConfirmation
        ) {
            Button(L10n.tr("dialog.delete_history_confirm"), role: .destructive) {
                historyViewModel.clearHistory()
            }
        } message: {
            Text(L10n.tr("dialog.delete_history_message"))
        }
        .environment(\.locale, settingsManager.appLanguage.locale)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.tr("settings.title"))
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text(L10n.tr("settings.subtitle"))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private var generalSection: some View {
        settingsCard(L10n.tr("settings.section.general"), systemImage: "gearshape") {
            Picker(L10n.tr("settings.language"), selection: $settingsManager.appLanguage) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .pickerStyle(.segmented)

            Toggle(
                L10n.tr("settings.launch_at_login"),
                isOn: Binding(
                    get: { settingsManager.launchAtLogin },
                    set: { settingsManager.setLaunchAtLogin($0) }
                )
            )

            Text(L10n.tr("settings.launch_at_login_help"))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if settingsManager.launchAtLoginRequiresApproval {
                Button {
                    settingsManager.openLoginItemsSettings()
                } label: {
                    Label(L10n.tr("settings.open_login_items_settings"), systemImage: "arrow.up.forward.app")
                }
            }

            Toggle(L10n.tr("settings.show_menu_bar"), isOn: showMenuBarIconBinding)

            Text(L10n.tr("settings.show_menu_bar_help"))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            LabeledContent(L10n.tr("settings.shortcut")) {
                Text("Cmd + Shift + C")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospaced()
            }

            LabeledContent(L10n.tr("settings.hotkey_status")) {
                Text(historyViewModel.hotkeyStatusMessage)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
            }

            if let message = settingsManager.launchAtLoginStatusMessage {
                Text(message)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(settingsManager.launchAtLoginRequiresApproval ? Color.orange : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var showMenuBarIconBinding: Binding<Bool> {
        Binding(
            get: { settingsManager.showMenuBarIcon },
            set: { settingsManager.showMenuBarIcon = $0 }
        )
    }

    private var unlimitedHistoryBinding: Binding<Bool> {
        Binding(
            get: { settingsManager.hasUnlimitedHistory },
            set: { settingsManager.setUnlimitedHistory($0) }
        )
    }

    private var finiteHistoryItemsBinding: Binding<Int> {
        Binding(
            get: { settingsManager.finiteHistoryItems },
            set: { settingsManager.maximumHistoryItems = $0 }
        )
    }

    private var dayThemeStartBinding: Binding<Date> {
        Binding(
            get: { SettingsManager.dateForTimePicker(minutesSinceMidnight: settingsManager.dayThemeStartMinutes) },
            set: { settingsManager.dayThemeStartMinutes = SettingsManager.minutesSinceMidnight(from: $0) }
        )
    }

    private var nightThemeStartBinding: Binding<Date> {
        Binding(
            get: { SettingsManager.dateForTimePicker(minutesSinceMidnight: settingsManager.nightThemeStartMinutes) },
            set: { settingsManager.nightThemeStartMinutes = SettingsManager.minutesSinceMidnight(from: $0) }
        )
    }

    private var clipboardSection: some View {
        settingsCard(L10n.tr("settings.section.clipboard"), systemImage: "doc.on.clipboard") {
            Toggle(L10n.tr("settings.capture_text"), isOn: $settingsManager.captureText)
            Toggle(L10n.tr("settings.capture_images"), isOn: $settingsManager.captureImages)
            Toggle(L10n.tr("settings.pause_monitoring"), isOn: $settingsManager.isMonitoringPaused)

            Divider()

            Toggle(L10n.tr("settings.unlimited_history"), isOn: unlimitedHistoryBinding)

            Stepper(value: finiteHistoryItemsBinding, in: 10...1000, step: 10) {
                LabeledContent(L10n.tr("settings.maximum_history_items")) {
                    Text(settingsManager.hasUnlimitedHistory ? L10n.tr("common.unlimited") : settingsManager.maximumHistoryItems.formatted())
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(settingsManager.hasUnlimitedHistory)

            LabeledContent(L10n.tr("settings.current_status")) {
                Text(historyViewModel.monitoringStatusLabel)
                    .foregroundStyle(.secondary)
            }

            LabeledContent(L10n.tr("settings.saved_items")) {
                Text(historyViewModel.savedItemsStatusLabel)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button(role: .destructive) {
                isShowingDeleteConfirmation = true
            } label: {
                Label(L10n.tr("settings.clear_history"), systemImage: "trash")
            }
        }
    }

    private var pasteSection: some View {
        settingsCard(L10n.tr("settings.section.paste"), systemImage: "arrow.down.doc") {
            Toggle(L10n.tr("settings.auto_paste"), isOn: $settingsManager.autoPasteAfterSelection)
            Toggle(L10n.tr("settings.reactivate_previous_app"), isOn: $settingsManager.reactivatePreviousAppBeforePaste)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L10n.tr("settings.paste_delay"))
                    Spacer()
                    Text(L10n.tr("unit.seconds", settingsManager.pasteDelay))
                        .foregroundStyle(.secondary)
                }

                Slider(value: $settingsManager.pasteDelay, in: 0.05...0.30, step: 0.01)
            }
        }
    }

    private var appearanceSection: some View {
        settingsCard(L10n.tr("settings.section.appearance"), systemImage: "rectangle.3.group") {
            Picker(L10n.tr("settings.theme_mode"), selection: $settingsManager.themeMode) {
                ForEach(SettingsManager.ThemeMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            Text(L10n.tr("settings.theme_mode_help"))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            LabeledContent(L10n.tr("settings.active_theme")) {
                Text(settingsManager.activeTheme.title)
                    .foregroundStyle(.secondary)
            }

            if settingsManager.themeMode == .scheduled {
                DatePicker(
                    L10n.tr("settings.day_theme_starts"),
                    selection: dayThemeStartBinding,
                    displayedComponents: [.hourAndMinute]
                )

                DatePicker(
                    L10n.tr("settings.night_theme_starts"),
                    selection: nightThemeStartBinding,
                    displayedComponents: [.hourAndMinute]
                )

                Text(L10n.tr("settings.theme_schedule_help"))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L10n.tr("settings.overlay_height"))
                    Spacer()
                    Text(L10n.tr("unit.points", Int(settingsManager.overlayHeight.rounded())))
                        .foregroundStyle(.secondary)
                }

                Slider(value: $settingsManager.overlayHeight, in: 220...360, step: 2)
            }

            Picker(L10n.tr("settings.card_size"), selection: $settingsManager.cardSizePreset) {
                ForEach(SettingsManager.CardSizePreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .pickerStyle(.segmented)

            Toggle(L10n.tr("settings.show_timestamps"), isOn: $settingsManager.showTimestampsOnCards)
            Toggle(L10n.tr("settings.show_metadata"), isOn: $settingsManager.showMetadataOnCards)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L10n.tr("settings.corner_radius"))
                    Spacer()
                    Text(L10n.tr("unit.points", Int(settingsManager.cornerRadiusIntensity.rounded())))
                        .foregroundStyle(.secondary)
                }

                Slider(value: $settingsManager.cornerRadiusIntensity, in: 0...28, step: 1)
            }
        }
    }

    private var storageAndPermissionsSection: some View {
        settingsCard(L10n.tr("settings.section.storage_permissions"), systemImage: "externaldrive") {
            LabeledContent(L10n.tr("settings.accessibility")) {
                Text(historyViewModel.isAccessibilityTrusted ? L10n.tr("settings.enabled") : L10n.tr("settings.not_granted"))
                    .foregroundStyle(historyViewModel.isAccessibilityTrusted ? .green : .secondary)
            }

            LabeledContent(L10n.tr("settings.storage_used")) {
                Text(historyViewModel.storageUsageLabel)
                    .foregroundStyle(.secondary)
            }

            LabeledContent(L10n.tr("settings.storage_path")) {
                Text(historyViewModel.applicationSupportPath)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }

            HStack(spacing: 12) {
                Button {
                    historyViewModel.requestAccessibilityAccess()
                } label: {
                    Label(L10n.tr("settings.request_accessibility"), systemImage: "hand.raised")
                }

                Button {
                    historyViewModel.openAccessibilitySettings()
                } label: {
                    Label(L10n.tr("settings.open_accessibility_settings"), systemImage: "gearshape")
                }
            }

            HStack(spacing: 12) {
                Button {
                    historyViewModel.revealStorageInFinder()
                } label: {
                    Label(L10n.tr("settings.reveal_application_support"), systemImage: "folder")
                }

                Button(role: .destructive) {
                    isShowingDeleteConfirmation = true
                } label: {
                    Label(L10n.tr("settings.delete_all_saved_data"), systemImage: "trash")
                }
            }
        }
    }

    private func settingsCard<Content: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        } label: {
            Label(title, systemImage: systemImage)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
        }
    }

    private func statusFooter(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
