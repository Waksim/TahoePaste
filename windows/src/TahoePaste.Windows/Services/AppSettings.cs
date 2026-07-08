using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Text.Json.Serialization;
using TahoePaste.Windows.Localization;

namespace TahoePaste.Windows.Services;

public enum CardSizePreset
{
    Compact,
    Comfortable,
    Large
}

public enum ThemeMode
{
    System,
    Day,
    Night,
    Scheduled
}

public enum Theme
{
    Day,
    Night
}

public sealed class AppSettings : INotifyPropertyChanged
{
    private static readonly OverlayLayout DefaultLayout = OverlayLayout.Automatic(CardSizePreset.Comfortable);

    private AppLanguage _appLanguage = AppLanguageExtensions.BestMatch();
    private bool _showTrayIcon = true;
    private bool _launchAtLogin;
    private bool _captureText = true;
    private bool _captureImages = true;
    private bool _isMonitoringPaused;
    private int _maximumHistoryItems = 200;
    private int _lastFiniteHistoryItems = 200;
    private bool _autoPasteAfterSelection = true;
    private double _pasteDelay = 0.12;
    private bool _reactivatePreviousAppBeforePaste = true;
    private CardSizePreset _cardSizePreset = CardSizePreset.Comfortable;
    private bool _useAutomaticOverlayLayout = true;
    private double _manualTopBarHeight = DefaultLayout.TopBarHeight;
    private double _manualBottomInset = DefaultLayout.BottomInset;
    private double _manualCardSpacing = DefaultLayout.CardSpacing;
    private double _manualCardContentPadding = DefaultLayout.ContentPadding;
    private double _manualCardHeight = DefaultLayout.CardHeight;
    private double _manualTextCardWidth = DefaultLayout.TextCardWidth;
    private double _manualImageCardWidth = DefaultLayout.ImageCardWidth;
    private double _manualToolbarIconSize = DefaultLayout.ToolbarIconSize;
    private double _manualToolbarIconPadding = DefaultLayout.ToolbarIconPadding;
    private double _manualToolbarIconSpacing = DefaultLayout.ToolbarIconSpacing;
    private double _manualToolbarVerticalOffset = DefaultLayout.ToolbarVerticalOffset;
    private double _manualSearchBubbleWidth = DefaultLayout.SearchBubbleWidth;
    private double _manualSearchBubbleHeight = DefaultLayout.SearchBubbleHeight;
    private double _manualSearchBubbleHorizontalOffset = DefaultLayout.SearchBubbleHorizontalOffset;
    private double _manualSearchBubbleVerticalOffset = DefaultLayout.SearchBubbleVerticalOffset;
    private double _manualOverlayHeight = DefaultLayout.OverlayHeight;
    private double _manualOverlayScreenHorizontalInset = DefaultLayout.OverlayScreenHorizontalInset;
    private double _manualOverlayScreenBottomInset = DefaultLayout.OverlayScreenBottomInset;
    private bool _showTimestampsOnCards = true;
    private bool _showMetadataOnCards = true;
    private double _cornerRadiusIntensity = 16;
    private ThemeMode _themeMode = ThemeMode.System;
    private int _dayThemeStartMinutes = 8 * 60;
    private int _nightThemeStartMinutes = 20 * 60;
    private Theme _activeTheme = Theme.Day;

    public event PropertyChangedEventHandler? PropertyChanged;

    public AppLanguage AppLanguage
    {
        get => _appLanguage;
        set => Set(ref _appLanguage, value);
    }

    public bool ShowTrayIcon
    {
        get => _showTrayIcon;
        set => Set(ref _showTrayIcon, value);
    }

    public bool LaunchAtLogin
    {
        get => _launchAtLogin;
        set => Set(ref _launchAtLogin, value);
    }

    public bool CaptureText
    {
        get => _captureText;
        set => Set(ref _captureText, value);
    }

    public bool CaptureImages
    {
        get => _captureImages;
        set => Set(ref _captureImages, value);
    }

    public bool IsMonitoringPaused
    {
        get => _isMonitoringPaused;
        set => Set(ref _isMonitoringPaused, value);
    }

    public int MaximumHistoryItems
    {
        get => _maximumHistoryItems;
        set
        {
            var normalized = NormalizeMaximumHistoryItems(value);
            if (Set(ref _maximumHistoryItems, normalized) && normalized > 0)
            {
                LastFiniteHistoryItems = normalized;
            }
        }
    }

    public int LastFiniteHistoryItems
    {
        get => _lastFiniteHistoryItems;
        set => Set(ref _lastFiniteHistoryItems, NormalizeFiniteHistoryItems(value));
    }

    public bool AutoPasteAfterSelection
    {
        get => _autoPasteAfterSelection;
        set => Set(ref _autoPasteAfterSelection, value);
    }

    public double PasteDelay
    {
        get => _pasteDelay;
        set => Set(ref _pasteDelay, Clamp(value, 0.05, 0.30));
    }

    public bool ReactivatePreviousAppBeforePaste
    {
        get => _reactivatePreviousAppBeforePaste;
        set => Set(ref _reactivatePreviousAppBeforePaste, value);
    }

    // Legacy pre-layout overlay height. Kept only so values from old
    // settings.json files migrate into ManualOverlayHeight (SettingsStore.Load);
    // 0 means "absent" and is what fresh saves write back.
    public double OverlayHeight { get; set; }

    public CardSizePreset CardSizePreset
    {
        get => _cardSizePreset;
        set => Set(ref _cardSizePreset, value);
    }

    public bool UseAutomaticOverlayLayout
    {
        get => _useAutomaticOverlayLayout;
        set
        {
            var wasAutomatic = _useAutomaticOverlayLayout;
            if (Set(ref _useAutomaticOverlayLayout, value) && wasAutomatic && value == false)
            {
                // Manual sliders pick up from the layout the user currently sees.
                SeedManualLayout(OverlayLayout.Automatic(CardSizePreset));
            }
        }
    }

    public double ManualTopBarHeight
    {
        get => _manualTopBarHeight;
        set => Set(ref _manualTopBarHeight, Clamp(value, 20, 56));
    }

    public double ManualBottomInset
    {
        get => _manualBottomInset;
        set => Set(ref _manualBottomInset, Clamp(value, 0, 56));
    }

    public double ManualCardSpacing
    {
        get => _manualCardSpacing;
        set => Set(ref _manualCardSpacing, Clamp(value, 4, 40));
    }

    public double ManualCardContentPadding
    {
        get => _manualCardContentPadding;
        set => Set(ref _manualCardContentPadding, Clamp(value, 8, 32));
    }

    public double ManualCardHeight
    {
        get => _manualCardHeight;
        set => Set(ref _manualCardHeight, Clamp(value, 120, 280));
    }

    public double ManualTextCardWidth
    {
        get => _manualTextCardWidth;
        set => Set(ref _manualTextCardWidth, Clamp(value, 200, 420));
    }

    public double ManualImageCardWidth
    {
        get => _manualImageCardWidth;
        set => Set(ref _manualImageCardWidth, Clamp(value, 160, 340));
    }

    public double ManualToolbarIconSize
    {
        get => _manualToolbarIconSize;
        set => Set(ref _manualToolbarIconSize, Clamp(value, 8, 20));
    }

    public double ManualToolbarIconPadding
    {
        get => _manualToolbarIconPadding;
        set => Set(ref _manualToolbarIconPadding, Clamp(value, 0, 12));
    }

    public double ManualToolbarIconSpacing
    {
        get => _manualToolbarIconSpacing;
        set => Set(ref _manualToolbarIconSpacing, Clamp(value, 0, 24));
    }

    public double ManualToolbarVerticalOffset
    {
        get => _manualToolbarVerticalOffset;
        set => Set(ref _manualToolbarVerticalOffset, Clamp(value, -16, 24));
    }

    public double ManualSearchBubbleWidth
    {
        get => _manualSearchBubbleWidth;
        set => Set(ref _manualSearchBubbleWidth, Clamp(value, 240, 800));
    }

    public double ManualSearchBubbleHeight
    {
        get => _manualSearchBubbleHeight;
        set => Set(ref _manualSearchBubbleHeight, Clamp(value, 22, 48));
    }

    public double ManualSearchBubbleHorizontalOffset
    {
        get => _manualSearchBubbleHorizontalOffset;
        set => Set(ref _manualSearchBubbleHorizontalOffset, Clamp(value, -200, 200));
    }

    public double ManualSearchBubbleVerticalOffset
    {
        get => _manualSearchBubbleVerticalOffset;
        set => Set(ref _manualSearchBubbleVerticalOffset, Clamp(value, -16, 24));
    }

    public double ManualOverlayHeight
    {
        get => _manualOverlayHeight;
        set => Set(ref _manualOverlayHeight, Clamp(value, 160, 600));
    }

    public double ManualOverlayScreenHorizontalInset
    {
        get => _manualOverlayScreenHorizontalInset;
        set => Set(ref _manualOverlayScreenHorizontalInset, Clamp(value, 0, 400));
    }

    public double ManualOverlayScreenBottomInset
    {
        get => _manualOverlayScreenBottomInset;
        set => Set(ref _manualOverlayScreenBottomInset, Clamp(value, 0, 300));
    }

    public bool ShowTimestampsOnCards
    {
        get => _showTimestampsOnCards;
        set => Set(ref _showTimestampsOnCards, value);
    }

    public bool ShowMetadataOnCards
    {
        get => _showMetadataOnCards;
        set => Set(ref _showMetadataOnCards, value);
    }

    public double CornerRadiusIntensity
    {
        get => _cornerRadiusIntensity;
        set => Set(ref _cornerRadiusIntensity, Clamp(value, 0, 28));
    }

    public ThemeMode ThemeMode
    {
        get => _themeMode;
        set => Set(ref _themeMode, value);
    }

    public int DayThemeStartMinutes
    {
        get => _dayThemeStartMinutes;
        set => Set(ref _dayThemeStartMinutes, NormalizeMinutesSinceMidnight(value));
    }

    public int NightThemeStartMinutes
    {
        get => _nightThemeStartMinutes;
        set => Set(ref _nightThemeStartMinutes, NormalizeMinutesSinceMidnight(value));
    }

    public Theme ActiveTheme
    {
        get => _activeTheme;
        set => Set(ref _activeTheme, value);
    }

    [JsonIgnore]
    public OverlayLayout OverlayLayout => UseAutomaticOverlayLayout
        ? OverlayLayout.Automatic(CardSizePreset)
        : new OverlayLayout(
            TopBarHeight: ManualTopBarHeight,
            BottomInset: ManualBottomInset,
            CardSpacing: ManualCardSpacing,
            ContentPadding: ManualCardContentPadding,
            CardHeight: ManualCardHeight,
            TextCardWidth: ManualTextCardWidth,
            ImageCardWidth: ManualImageCardWidth,
            ToolbarIconSize: ManualToolbarIconSize,
            ToolbarIconPadding: ManualToolbarIconPadding,
            ToolbarIconSpacing: ManualToolbarIconSpacing,
            ToolbarVerticalOffset: ManualToolbarVerticalOffset,
            SearchBubbleWidth: ManualSearchBubbleWidth,
            SearchBubbleHeight: ManualSearchBubbleHeight,
            SearchBubbleHorizontalOffset: ManualSearchBubbleHorizontalOffset,
            SearchBubbleVerticalOffset: ManualSearchBubbleVerticalOffset,
            OverlayHeight: ManualOverlayHeight,
            OverlayScreenHorizontalInset: ManualOverlayScreenHorizontalInset,
            OverlayScreenBottomInset: ManualOverlayScreenBottomInset);

    public void SeedManualLayout(OverlayLayout layout)
    {
        ManualTopBarHeight = layout.TopBarHeight;
        ManualBottomInset = layout.BottomInset;
        ManualCardSpacing = layout.CardSpacing;
        ManualCardContentPadding = layout.ContentPadding;
        ManualCardHeight = layout.CardHeight;
        ManualTextCardWidth = layout.TextCardWidth;
        ManualImageCardWidth = layout.ImageCardWidth;
        ManualToolbarIconSize = layout.ToolbarIconSize;
        ManualToolbarIconPadding = layout.ToolbarIconPadding;
        ManualToolbarIconSpacing = layout.ToolbarIconSpacing;
        ManualToolbarVerticalOffset = layout.ToolbarVerticalOffset;
        ManualSearchBubbleWidth = layout.SearchBubbleWidth;
        ManualSearchBubbleHeight = layout.SearchBubbleHeight;
        ManualSearchBubbleHorizontalOffset = layout.SearchBubbleHorizontalOffset;
        ManualSearchBubbleVerticalOffset = layout.SearchBubbleVerticalOffset;
        ManualOverlayHeight = layout.OverlayHeight;
        ManualOverlayScreenHorizontalInset = layout.OverlayScreenHorizontalInset;
        ManualOverlayScreenBottomInset = layout.OverlayScreenBottomInset;
    }

    [JsonIgnore]
    public bool HasUnlimitedHistory => MaximumHistoryItems == 0;

    [JsonIgnore]
    public int? HistoryLimit => HasUnlimitedHistory ? null : MaximumHistoryItems;

    [JsonIgnore]
    public int FiniteHistoryItems => HasUnlimitedHistory ? LastFiniteHistoryItems : MaximumHistoryItems;

    public void SetUnlimitedHistory(bool enabled)
    {
        MaximumHistoryItems = enabled ? 0 : LastFiniteHistoryItems;
        OnPropertyChanged(nameof(HasUnlimitedHistory));
        OnPropertyChanged(nameof(HistoryLimit));
        OnPropertyChanged(nameof(FiniteHistoryItems));
    }

    public static int NormalizeFiniteHistoryItems(int value) => Math.Clamp(value, 10, 1000);
    public static int NormalizeMaximumHistoryItems(int value) => value <= 0 ? 0 : NormalizeFiniteHistoryItems(value);
    public static int NormalizeMinutesSinceMidnight(int value)
    {
        const int totalMinutes = 24 * 60;
        var remainder = value % totalMinutes;
        return remainder >= 0 ? remainder : remainder + totalMinutes;
    }

    public static int MinutesSinceMidnight(DateTime dateTime) => dateTime.Hour * 60 + dateTime.Minute;

    public static string TimeText(int minutes)
    {
        var normalized = NormalizeMinutesSinceMidnight(minutes);
        return $"{normalized / 60:00}:{normalized % 60:00}";
    }

    public static bool TryParseTimeText(string value, out int minutes)
    {
        minutes = 0;
        var parts = value.Split(':', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length != 2 ||
            int.TryParse(parts[0], out var hour) == false ||
            int.TryParse(parts[1], out var minute) == false ||
            hour is < 0 or > 23 ||
            minute is < 0 or > 59)
        {
            return false;
        }

        minutes = hour * 60 + minute;
        return true;
    }

    public void RefreshActiveTheme(bool systemIsDark, DateTime now)
    {
        ActiveTheme = ResolveTheme(
            ThemeMode,
            systemIsDark,
            DayThemeStartMinutes,
            NightThemeStartMinutes,
            MinutesSinceMidnight(now));
    }

    public static Theme ResolveTheme(
        ThemeMode mode,
        bool systemIsDark,
        int dayThemeStartMinutes,
        int nightThemeStartMinutes,
        int nowMinutesSinceMidnight)
    {
        return mode switch
        {
            ThemeMode.System => systemIsDark ? Theme.Night : Theme.Day,
            ThemeMode.Day => Theme.Day,
            ThemeMode.Night => Theme.Night,
            ThemeMode.Scheduled => ResolveScheduledTheme(dayThemeStartMinutes, nightThemeStartMinutes, nowMinutesSinceMidnight),
            _ => Theme.Day
        };
    }

    private static Theme ResolveScheduledTheme(int dayThemeStartMinutes, int nightThemeStartMinutes, int nowMinutesSinceMidnight)
    {
        var day = NormalizeMinutesSinceMidnight(dayThemeStartMinutes);
        var night = NormalizeMinutesSinceMidnight(nightThemeStartMinutes);
        var now = NormalizeMinutesSinceMidnight(nowMinutesSinceMidnight);

        if (day == night)
        {
            return Theme.Day;
        }

        if (day < night)
        {
            return now >= day && now < night ? Theme.Day : Theme.Night;
        }

        return now >= day || now < night ? Theme.Day : Theme.Night;
    }

    private bool Set<T>(ref T field, T value, [CallerMemberName] string? propertyName = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value))
        {
            return false;
        }

        field = value;
        OnPropertyChanged(propertyName);

        if (propertyName is nameof(MaximumHistoryItems))
        {
            OnPropertyChanged(nameof(HasUnlimitedHistory));
            OnPropertyChanged(nameof(HistoryLimit));
            OnPropertyChanged(nameof(FiniteHistoryItems));
        }

        return true;
    }

    private void OnPropertyChanged([CallerMemberName] string? propertyName = null)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }

    private static double Clamp(double value, double min, double max) => Math.Min(Math.Max(value, min), max);
}
