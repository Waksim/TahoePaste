using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Globalization;
using System.Runtime.CompilerServices;
using System.Windows.Media.Imaging;
using TahoePaste.Windows.Localization;
using TahoePaste.Windows.Models;
using TahoePaste.Windows.Services;

namespace TahoePaste.Windows.ViewModels;

public sealed class ClipboardHistoryViewModel : INotifyPropertyChanged
{
    private readonly StorageService _storageService;
    private readonly AppSettings _settings;
    private string _searchQuery = string.Empty;
    private bool _isSearchInterfaceVisible;
    private ClipboardTag? _activeTagFilter;
    private string _hotkeyStatusMessage = L10n.Tr("status.hotkey_unavailable");
    private string? _statusMessage;
    private string _storageUsageLabel;
    private Guid _overlayPresentationId = Guid.NewGuid();

    public ClipboardHistoryViewModel(StorageService storageService, AppSettings settings)
    {
        _storageService = storageService;
        _settings = settings;
        _storageUsageLabel = storageService.FormattedStorageUsage();

        _settings.PropertyChanged += (_, _) => RefreshDerivedState();
        L10n.LanguageChanged += (_, _) => RefreshLocalizedState();
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    public ObservableCollection<ClipboardItem> Items { get; } = [];

    public Action<ClipboardItem>? SelectRequested { get; set; }
    public Action<ClipboardItem>? DeleteRequested { get; set; }
    public Action? ShowOverlayRequested { get; set; }
    public Action? HideOverlayRequested { get; set; }
    public Action? OpenSettingsRequested { get; set; }
    public Action? ClearHistoryRequested { get; set; }
    public Action? RevealStorageRequested { get; set; }
    public Action? QuitRequested { get; set; }

    public string SearchQuery
    {
        get => _searchQuery;
        private set
        {
            if (Set(ref _searchQuery, value))
            {
                OnPropertyChanged(nameof(IsSearching));
                OnPropertyChanged(nameof(IsSearchUiVisible));
                OnPropertyChanged(nameof(IsSearchBubbleVisible));
                OnPropertyChanged(nameof(SearchDisplayText));
                OnPropertyChanged(nameof(VisibleItems));
            }
        }
    }

    public bool IsSearchInterfaceVisible
    {
        get => _isSearchInterfaceVisible;
        private set
        {
            if (Set(ref _isSearchInterfaceVisible, value))
            {
                OnPropertyChanged(nameof(IsSearchUiVisible));
                OnPropertyChanged(nameof(IsSearchBubbleVisible));
            }
        }
    }

    public ClipboardTag? ActiveTagFilter
    {
        get => _activeTagFilter;
        private set
        {
            if (Set(ref _activeTagFilter, value))
            {
                OnPropertyChanged(nameof(IsSearchBubbleVisible));
                OnPropertyChanged(nameof(SearchDisplayText));
                OnPropertyChanged(nameof(VisibleItems));
            }
        }
    }

    public string HotkeyStatusMessage
    {
        get => _hotkeyStatusMessage;
        private set => Set(ref _hotkeyStatusMessage, value);
    }

    public string? StatusMessage
    {
        get => _statusMessage;
        private set => Set(ref _statusMessage, value);
    }

    public string StorageUsageLabel
    {
        get => _storageUsageLabel;
        private set => Set(ref _storageUsageLabel, value);
    }

    public Guid OverlayPresentationId
    {
        get => _overlayPresentationId;
        private set => Set(ref _overlayPresentationId, value);
    }

    public IReadOnlyList<ClipboardItem> CurrentHistory => Items.ToArray();

    public IReadOnlyList<ClipboardItem> VisibleItems => ClipboardSearchEngine.Matches(FilteredItems, SearchQuery);

    public bool IsSearching => string.IsNullOrEmpty(SearchQuery) == false;

    public bool IsSearchUiVisible => IsSearchInterfaceVisible || IsSearching;

    public bool IsSearchBubbleVisible => IsSearchUiVisible || ActiveTagFilter is not null;

    public string SearchDisplayText
    {
        get
        {
            var parts = new List<string>();
            if (ActiveTagFilter is { } tag)
            {
                parts.Add(L10n.Tr(tag.TitleKey()));
            }

            if (string.IsNullOrEmpty(SearchQuery) == false)
            {
                parts.Add(SearchQuery);
            }

            return parts.Count == 0 ? L10n.Tr("overlay.search_placeholder") : string.Join(" · ", parts);
        }
    }

    public string SavedItemsStatusLabel => L10n.Tr("unit.items_saved", Items.Count);
    public string HistoryCountLabel => L10n.Tr("unit.items", Items.Count);
    public string MonitoringStatusLabel => _settings.IsMonitoringPaused ? L10n.Tr("status.monitoring_paused") : L10n.Tr("status.monitoring_active");
    public string MaximumHistoryItemsLabel => _settings.HasUnlimitedHistory ? L10n.Tr("common.unlimited") : L10n.Tr("unit.items", _settings.MaximumHistoryItems);
    public string ApplicationSupportPath => _storageService.RootDirectory;
    public CultureInfo Culture => _settings.AppLanguage.Culture();

    public BitmapImage? ImageFor(ClipboardItem item) => _storageService.LoadImage(item);

    public void ReplaceHistory(IEnumerable<ClipboardItem> items)
    {
        Items.Clear();

        foreach (var item in items.OrderByDescending(item => item.CreatedAt))
        {
            Items.Add(item);
        }

        RefreshAfterHistoryChange();
    }

    public void AppendSearchCharacter(string character)
    {
        if (string.IsNullOrEmpty(character))
        {
            return;
        }

        IsSearchInterfaceVisible = true;
        SearchQuery += character;
    }

    public void RemoveLastSearchCharacter()
    {
        if (SearchQuery.Length == 0)
        {
            return;
        }

        SearchQuery = SearchQuery[..^1];
    }

    public void ClearSearch()
    {
        SearchQuery = string.Empty;
        IsSearchInterfaceVisible = false;
    }

    public void ToggleTagFilter(ClipboardTag tag)
    {
        ActiveTagFilter = ActiveTagFilter == tag ? null : tag;
    }

    public bool IsFilteringBy(ClipboardTag tag) => ActiveTagFilter == tag;

    public void ClearTransientState()
    {
        ClearSearch();
        ActiveTagFilter = null;
    }

    public void BeginSearch()
    {
        IsSearchInterfaceVisible = true;
    }

    public void DismissSearchInterface()
    {
        IsSearchInterfaceVisible = false;
    }

    public void Select(ClipboardItem item) => SelectRequested?.Invoke(item);
    public void Delete(ClipboardItem item) => DeleteRequested?.Invoke(item);
    public void ShowOverlay()
    {
        ClearTransientState();
        OverlayPresentationId = Guid.NewGuid();
        ShowOverlayRequested?.Invoke();
    }
    public void HideOverlay()
    {
        ClearTransientState();
        HideOverlayRequested?.Invoke();
    }

    public void OpenSettings() => OpenSettingsRequested?.Invoke();
    public void ClearHistory() => ClearHistoryRequested?.Invoke();
    public void RevealStorage() => RevealStorageRequested?.Invoke();
    public void Quit() => QuitRequested?.Invoke();
    public void SetHotkeyAvailability(string message) => HotkeyStatusMessage = message;
    public void SetStatusMessage(string? message) => StatusMessage = message;
    public void RefreshStorageUsage() => StorageUsageLabel = _storageService.FormattedStorageUsage();

    private IEnumerable<ClipboardItem> FilteredItems => ActiveTagFilter is null
        ? Items
        : Items.Where(item => item.Tags.Contains(ActiveTagFilter.Value));

    private void RefreshAfterHistoryChange()
    {
        RefreshStorageUsage();
        OnPropertyChanged(nameof(VisibleItems));
        OnPropertyChanged(nameof(SavedItemsStatusLabel));
        OnPropertyChanged(nameof(HistoryCountLabel));
    }

    private void RefreshDerivedState()
    {
        OnPropertyChanged(nameof(MonitoringStatusLabel));
        OnPropertyChanged(nameof(MaximumHistoryItemsLabel));
        OnPropertyChanged(nameof(VisibleItems));
    }

    private void RefreshLocalizedState()
    {
        RefreshStorageUsage();
        RefreshDerivedState();
        OnPropertyChanged(nameof(SearchDisplayText));
        OnPropertyChanged(nameof(SavedItemsStatusLabel));
        OnPropertyChanged(nameof(HistoryCountLabel));
    }

    private bool Set<T>(ref T field, T value, [CallerMemberName] string? propertyName = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value))
        {
            return false;
        }

        field = value;
        OnPropertyChanged(propertyName);
        return true;
    }

    private void OnPropertyChanged([CallerMemberName] string? propertyName = null)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }
}
