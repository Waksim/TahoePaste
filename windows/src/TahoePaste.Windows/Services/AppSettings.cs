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
    private AppLanguage _appLanguage = AppLanguage.BestMatch();
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
    private double _overlayHeight = 260;
    private CardSizePreset _cardSizePreset = CardSizePreset.Comfortable;
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

    public double OverlayHeight
    {
        get => _overlayHeight;
        set => Set(ref _overlayHeight, Clamp(value, 220, 360));
    }

    public CardSizePreset CardSizePreset
    {
        get => _cardSizePreset;
        set => Set(ref _cardSizePreset, value);
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
