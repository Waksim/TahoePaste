using System.ComponentModel;
using System.Diagnostics;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using TahoePaste.Windows.Localization;
using TahoePaste.Windows.Services;
using TahoePaste.Windows.ViewModels;
using TahoeTheme = TahoePaste.Windows.Services.Theme;
using TahoeThemeMode = TahoePaste.Windows.Services.ThemeMode;

namespace TahoePaste.Windows.Views;

public partial class SettingsWindow : Window
{
    private readonly ClipboardHistoryViewModel _viewModel;
    private readonly AppSettings _settings;
    private readonly StartupService _startupService;
    private bool _isRefreshing;

    public SettingsWindow(ClipboardHistoryViewModel viewModel, AppSettings settings, StartupService startupService)
    {
        _viewModel = viewModel;
        _settings = settings;
        _startupService = startupService;

        _isRefreshing = true;
        InitializeComponent();
        _isRefreshing = false;

        _viewModel.PropertyChanged += OnViewModelChanged;
        _settings.PropertyChanged += OnSettingsChanged;
        L10n.LanguageChanged += (_, _) => RefreshAll();
    }

    private void OnLoaded(object sender, RoutedEventArgs e)
    {
        PopulateOptions();
        RefreshAll();
    }

    private void PopulateOptions()
    {
        if (LanguageCombo.Items.Count > 0)
        {
            return;
        }

        LanguageCombo.ItemsSource = Enum.GetValues<AppLanguage>().Select(language => new Option<AppLanguage>(language, language.DisplayName())).ToArray();
        ThemeModeCombo.ItemsSource = Enum.GetValues<TahoeThemeMode>().Select(mode => new Option<TahoeThemeMode>(mode, ThemeModeTitle(mode))).ToArray();
        CardSizeCombo.ItemsSource = Enum.GetValues<CardSizePreset>().Select(preset => new Option<CardSizePreset>(preset, CardSizeTitle(preset))).ToArray();
    }

    private void RefreshAll()
    {
        _isRefreshing = true;
        try
        {
            RefreshText();
            RefreshValues();
        }
        finally
        {
            _isRefreshing = false;
        }
    }

    private void RefreshText()
    {
        Title = L10n.Tr("settings.title");
        HeaderTitle.Text = L10n.Tr("settings.title");
        HeaderSubtitle.Text = L10n.Tr("settings.subtitle");
        GeneralGroup.Header = L10n.Tr("settings.section.general");
        ClipboardGroup.Header = L10n.Tr("settings.section.clipboard");
        PasteGroup.Header = L10n.Tr("settings.section.paste");
        AppearanceGroup.Header = L10n.Tr("settings.section.appearance");
        StorageGroup.Header = L10n.Tr("settings.section.storage_permissions");
        LanguageLabel.Text = L10n.Tr("settings.language");
        LaunchAtLoginCheck.Content = L10n.Tr("settings.launch_at_login");
        LaunchAtLoginHelp.Text = L10n.Tr("settings.launch_at_login_help");
        OpenStartupButton.Content = L10n.Tr("settings.open_login_items_settings");
        ShowTrayIconCheck.Content = L10n.Tr("settings.show_menu_bar");
        ShowTrayIconHelp.Text = L10n.Tr("settings.show_menu_bar_help");
        ShortcutLabel.Text = L10n.Tr("settings.shortcut");
        HotkeyStatusLabel.Text = L10n.Tr("settings.hotkey_status");
        CaptureTextCheck.Content = L10n.Tr("settings.capture_text");
        CaptureImagesCheck.Content = L10n.Tr("settings.capture_images");
        PauseMonitoringCheck.Content = L10n.Tr("settings.pause_monitoring");
        UnlimitedHistoryCheck.Content = L10n.Tr("settings.unlimited_history");
        MaximumHistoryItemsLabel.Text = L10n.Tr("settings.maximum_history_items");
        CurrentStatusLabel.Text = L10n.Tr("settings.current_status");
        SavedItemsLabel.Text = L10n.Tr("settings.saved_items");
        ClearHistoryButton.Content = L10n.Tr("settings.clear_history");
        AutoPasteCheck.Content = L10n.Tr("settings.auto_paste");
        ReactivateCheck.Content = L10n.Tr("settings.reactivate_previous_app");
        PasteDelayLabel.Text = L10n.Tr("settings.paste_delay");
        ThemeModeLabel.Text = L10n.Tr("settings.theme_mode");
        ThemeModeHelp.Text = L10n.Tr("settings.theme_mode_help");
        ActiveThemeLabel.Text = L10n.Tr("settings.active_theme");
        DayThemeStartsLabel.Text = L10n.Tr("settings.day_theme_starts");
        NightThemeStartsLabel.Text = L10n.Tr("settings.night_theme_starts");
        ThemeScheduleHelp.Text = L10n.Tr("settings.theme_schedule_help");
        OverlayHeightLabel.Text = L10n.Tr("settings.overlay_height");
        CardSizeLabel.Text = L10n.Tr("settings.card_size");
        ShowTimestampsCheck.Content = L10n.Tr("settings.show_timestamps");
        ShowMetadataCheck.Content = L10n.Tr("settings.show_metadata");
        CornerRadiusLabel.Text = L10n.Tr("settings.corner_radius");
        InputAutomationLabel.Text = L10n.Tr("settings.input_automation");
        StorageUsedLabel.Text = L10n.Tr("settings.storage_used");
        StoragePathLabel.Text = L10n.Tr("settings.storage_path");
        TestInputButton.Content = L10n.Tr("settings.request_accessibility");
        OpenPrivacyButton.Content = L10n.Tr("settings.open_accessibility_settings");
        RevealStorageButton.Content = L10n.Tr("settings.reveal_application_support");
        DeleteAllButton.Content = L10n.Tr("settings.delete_all_saved_data");

        ThemeModeCombo.ItemsSource = Enum.GetValues<TahoeThemeMode>().Select(mode => new Option<TahoeThemeMode>(mode, ThemeModeTitle(mode))).ToArray();
        CardSizeCombo.ItemsSource = Enum.GetValues<CardSizePreset>().Select(preset => new Option<CardSizePreset>(preset, CardSizeTitle(preset))).ToArray();
    }

    private void RefreshValues()
    {
        SelectOption(LanguageCombo, _settings.AppLanguage);
        SelectOption(ThemeModeCombo, _settings.ThemeMode);
        SelectOption(CardSizeCombo, _settings.CardSizePreset);

        LaunchAtLoginCheck.IsChecked = _settings.LaunchAtLogin;
        ShowTrayIconCheck.IsChecked = _settings.ShowTrayIcon;
        HotkeyStatusValue.Text = _viewModel.HotkeyStatusMessage;
        CaptureTextCheck.IsChecked = _settings.CaptureText;
        CaptureImagesCheck.IsChecked = _settings.CaptureImages;
        PauseMonitoringCheck.IsChecked = _settings.IsMonitoringPaused;
        UnlimitedHistoryCheck.IsChecked = _settings.HasUnlimitedHistory;
        MaximumHistoryItemsSlider.Value = _settings.FiniteHistoryItems;
        MaximumHistoryItemsSlider.IsEnabled = _settings.HasUnlimitedHistory == false;
        MaximumHistoryItemsValue.Text = _settings.HasUnlimitedHistory ? L10n.Tr("common.unlimited") : L10n.Tr("unit.items", _settings.MaximumHistoryItems);
        CurrentStatusValue.Text = _viewModel.MonitoringStatusLabel;
        SavedItemsValue.Text = _viewModel.SavedItemsStatusLabel;
        AutoPasteCheck.IsChecked = _settings.AutoPasteAfterSelection;
        ReactivateCheck.IsChecked = _settings.ReactivatePreviousAppBeforePaste;
        PasteDelaySlider.Value = _settings.PasteDelay;
        PasteDelayValue.Text = L10n.Tr("unit.seconds", _settings.PasteDelay);
        ActiveThemeValue.Text = _settings.ActiveTheme == TahoeTheme.Night ? L10n.Tr("settings.theme_mode.night") : L10n.Tr("settings.theme_mode.day");
        DayThemeStartText.Text = AppSettings.TimeText(_settings.DayThemeStartMinutes);
        NightThemeStartText.Text = AppSettings.TimeText(_settings.NightThemeStartMinutes);
        DayThemeStartText.IsEnabled = _settings.ThemeMode == TahoeThemeMode.Scheduled;
        NightThemeStartText.IsEnabled = _settings.ThemeMode == TahoeThemeMode.Scheduled;
        OverlayHeightSlider.Value = _settings.OverlayHeight;
        OverlayHeightValue.Text = L10n.Tr("unit.points", (int)Math.Round(_settings.OverlayHeight));
        ShowTimestampsCheck.IsChecked = _settings.ShowTimestampsOnCards;
        ShowMetadataCheck.IsChecked = _settings.ShowMetadataOnCards;
        CornerRadiusSlider.Value = _settings.CornerRadiusIntensity;
        CornerRadiusValue.Text = L10n.Tr("unit.points", (int)Math.Round(_settings.CornerRadiusIntensity));
        InputAutomationValue.Text = L10n.Tr("settings.not_granted");
        StorageUsedValue.Text = _viewModel.StorageUsageLabel;
        StoragePathValue.Text = _viewModel.ApplicationSupportPath;
        StatusFooter.Text = _viewModel.StatusMessage ?? string.Empty;
    }

    private void OnSettingsChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (_isRefreshing == false)
        {
            RefreshAll();
        }
    }

    private void OnViewModelChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName is nameof(ClipboardHistoryViewModel.SavedItemsStatusLabel)
            or nameof(ClipboardHistoryViewModel.MonitoringStatusLabel)
            or nameof(ClipboardHistoryViewModel.StorageUsageLabel)
            or nameof(ClipboardHistoryViewModel.HotkeyStatusMessage)
            or nameof(ClipboardHistoryViewModel.StatusMessage))
        {
            RefreshValues();
        }
    }

    private void OnLanguageChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_isRefreshing == false && LanguageCombo.SelectedItem is Option<AppLanguage> option)
        {
            _settings.AppLanguage = option.Value;
        }
    }

    private void OnLaunchAtLoginChanged(object sender, RoutedEventArgs e)
    {
        if (_isRefreshing == false)
        {
            _settings.LaunchAtLogin = LaunchAtLoginCheck.IsChecked == true;
        }
    }

    private void OnShowTrayIconChanged(object sender, RoutedEventArgs e)
    {
        if (_isRefreshing == false)
        {
            _settings.ShowTrayIcon = ShowTrayIconCheck.IsChecked == true;
        }
    }

    private void OnCaptureTextChanged(object sender, RoutedEventArgs e)
    {
        if (_isRefreshing == false)
        {
            _settings.CaptureText = CaptureTextCheck.IsChecked == true;
        }
    }

    private void OnCaptureImagesChanged(object sender, RoutedEventArgs e)
    {
        if (_isRefreshing == false)
        {
            _settings.CaptureImages = CaptureImagesCheck.IsChecked == true;
        }
    }

    private void OnPauseMonitoringChanged(object sender, RoutedEventArgs e)
    {
        if (_isRefreshing == false)
        {
            _settings.IsMonitoringPaused = PauseMonitoringCheck.IsChecked == true;
        }
    }

    private void OnUnlimitedHistoryChanged(object sender, RoutedEventArgs e)
    {
        if (_isRefreshing == false)
        {
            _settings.SetUnlimitedHistory(UnlimitedHistoryCheck.IsChecked == true);
        }
    }

    private void OnMaximumHistoryItemsChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
    {
        if (_isRefreshing == false && _settings.HasUnlimitedHistory == false)
        {
            _settings.MaximumHistoryItems = (int)Math.Round(MaximumHistoryItemsSlider.Value);
        }
    }

    private void OnAutoPasteChanged(object sender, RoutedEventArgs e)
    {
        if (_isRefreshing == false)
        {
            _settings.AutoPasteAfterSelection = AutoPasteCheck.IsChecked == true;
        }
    }

    private void OnReactivateChanged(object sender, RoutedEventArgs e)
    {
        if (_isRefreshing == false)
        {
            _settings.ReactivatePreviousAppBeforePaste = ReactivateCheck.IsChecked == true;
        }
    }

    private void OnPasteDelayChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
    {
        if (_isRefreshing == false)
        {
            _settings.PasteDelay = PasteDelaySlider.Value;
        }
    }

    private void OnThemeModeChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_isRefreshing == false && ThemeModeCombo.SelectedItem is Option<TahoeThemeMode> option)
        {
            _settings.ThemeMode = option.Value;
        }
    }

    private void OnThemeTimeLostFocus(object sender, RoutedEventArgs e)
    {
        CommitThemeTimes();
    }

    private void OnThemeTimeKeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter)
        {
            CommitThemeTimes();
            e.Handled = true;
        }
    }

    private void OnOverlayHeightChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
    {
        if (_isRefreshing == false)
        {
            _settings.OverlayHeight = OverlayHeightSlider.Value;
        }
    }

    private void OnCardSizeChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_isRefreshing == false && CardSizeCombo.SelectedItem is Option<CardSizePreset> option)
        {
            _settings.CardSizePreset = option.Value;
        }
    }

    private void OnShowTimestampsChanged(object sender, RoutedEventArgs e)
    {
        if (_isRefreshing == false)
        {
            _settings.ShowTimestampsOnCards = ShowTimestampsCheck.IsChecked == true;
        }
    }

    private void OnShowMetadataChanged(object sender, RoutedEventArgs e)
    {
        if (_isRefreshing == false)
        {
            _settings.ShowMetadataOnCards = ShowMetadataCheck.IsChecked == true;
        }
    }

    private void OnCornerRadiusChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
    {
        if (_isRefreshing == false)
        {
            _settings.CornerRadiusIntensity = CornerRadiusSlider.Value;
        }
    }

    private void OnOpenStartupClick(object sender, RoutedEventArgs e)
    {
        _startupService.OpenStartupAppsSettings();
    }

    private void OnClearHistoryClick(object sender, RoutedEventArgs e)
    {
        var result = MessageBox.Show(
            L10n.Tr("dialog.delete_history_message"),
            L10n.Tr("dialog.delete_history_title"),
            MessageBoxButton.YesNo,
            MessageBoxImage.Warning);

        if (result == MessageBoxResult.Yes)
        {
            _viewModel.ClearHistory();
        }
    }

    private void OnTestInputClick(object sender, RoutedEventArgs e)
    {
        _viewModel.SetStatusMessage(L10n.Tr("status.input_automation_ready"));
    }

    private void OnOpenPrivacyClick(object sender, RoutedEventArgs e)
    {
        Process.Start(new ProcessStartInfo
        {
            FileName = "ms-settings:privacy",
            UseShellExecute = true
        });
    }

    private void OnRevealStorageClick(object sender, RoutedEventArgs e)
    {
        _viewModel.RevealStorage();
    }

    private void CommitThemeTimes()
    {
        if (_isRefreshing)
        {
            return;
        }

        if (AppSettings.TryParseTimeText(DayThemeStartText.Text, out var dayMinutes))
        {
            _settings.DayThemeStartMinutes = dayMinutes;
        }

        if (AppSettings.TryParseTimeText(NightThemeStartText.Text, out var nightMinutes))
        {
            _settings.NightThemeStartMinutes = nightMinutes;
        }
    }

    private static void SelectOption<T>(ComboBox comboBox, T value)
    {
        foreach (var item in comboBox.Items.OfType<Option<T>>())
        {
            if (EqualityComparer<T>.Default.Equals(item.Value, value))
            {
                comboBox.SelectedItem = item;
                return;
            }
        }
    }

    private static string ThemeModeTitle(TahoeThemeMode mode) => mode switch
    {
        TahoeThemeMode.System => L10n.Tr("settings.theme_mode.system"),
        TahoeThemeMode.Day => L10n.Tr("settings.theme_mode.day"),
        TahoeThemeMode.Night => L10n.Tr("settings.theme_mode.night"),
        TahoeThemeMode.Scheduled => L10n.Tr("settings.theme_mode.schedule"),
        _ => mode.ToString()
    };

    private static string CardSizeTitle(CardSizePreset preset) => preset switch
    {
        CardSizePreset.Compact => L10n.Tr("card.size.compact"),
        CardSizePreset.Large => L10n.Tr("card.size.large"),
        _ => L10n.Tr("card.size.comfortable")
    };

    private sealed record Option<T>(T Value, string Label)
    {
        public override string ToString() => Label;
    }
}
