using System.ComponentModel;
using System.Windows;
using System.Windows.Threading;
using TahoePaste.Windows.Localization;
using TahoePaste.Windows.Models;
using TahoePaste.Windows.ViewModels;
using TahoePaste.Windows.Views;

namespace TahoePaste.Windows.Services;

public sealed class AppHost : IDisposable
{
    private readonly AppPaths _paths = new();
    private readonly SettingsStore _settingsStore;
    private readonly StorageService _storageService;
    private readonly ClipboardService _clipboardService = new();
    private readonly ClipboardMonitor _clipboardMonitor = new();
    private readonly HotkeyManager _hotkeyManager = new();
    private readonly StartupService _startupService = new();
    private readonly WindowsThemeService _themeService = new();
    private readonly ForegroundWindowService _foregroundWindowService = new();
    private readonly DispatcherTimer _settingsSaveTimer;
    private readonly DispatcherTimer _themeTimer;
    private readonly AppSettings _settings;
    private readonly ClipboardHistoryViewModel _viewModel;
    private readonly PasteActionService _pasteActionService;
    private readonly TrayIconService _trayIconService;
    private OverlayWindow? _overlayWindow;
    private SettingsWindow? _settingsWindow;
    private bool _disposed;

    public AppHost()
    {
        _settingsStore = new SettingsStore(_paths);
        _storageService = new StorageService(_paths);
        _settings = _settingsStore.Load();
        _settings.LaunchAtLogin = _startupService.IsEnabled();
        L10n.Language = _settings.AppLanguage;

        _viewModel = new ClipboardHistoryViewModel(_storageService, _settings);
        _pasteActionService = new PasteActionService(
            _clipboardService,
            _clipboardMonitor,
            _storageService,
            _foregroundWindowService,
            _settings);
        _trayIconService = new TrayIconService(_viewModel, _settings);

        _settingsSaveTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(350) };
        _settingsSaveTimer.Tick += (_, _) =>
        {
            _settingsSaveTimer.Stop();
            _settingsStore.Save(_settings);
        };

        _themeTimer = new DispatcherTimer { Interval = TimeSpan.FromMinutes(1) };
        _themeTimer.Tick += (_, _) => RefreshTheme();
    }

    public void Start()
    {
        DiagnosticLog.Write("AppHost.Start");
        BindActions();
        RestoreHistory();
        RefreshTheme();
        ConfigureSettingsPersistence();

        _clipboardMonitor.ClipboardChanged += OnClipboardChanged;
        _clipboardMonitor.Start();

        try
        {
            _hotkeyManager.TogglePressed += (_, _) => _viewModel.ShowOverlay();
            _hotkeyManager.Register();
            _viewModel.SetHotkeyAvailability(L10n.Tr("status.hotkey_ready"));
        }
        catch (Win32Exception ex)
        {
            DiagnosticLog.Write($"Hotkey registration Win32Exception native={ex.NativeErrorCode} message={ex.Message}");
            _viewModel.SetHotkeyAvailability(L10n.Tr("status.hotkey_already_used"));
        }
        catch (Exception ex)
        {
            DiagnosticLog.Write($"Hotkey registration failed {ex}");
            _viewModel.SetHotkeyAvailability(L10n.Tr("status.hotkey_listen_failed"));
        }

        _trayIconService.Start();
        _themeTimer.Start();
    }

    private void BindActions()
    {
        _viewModel.ShowOverlayRequested = ShowOverlay;
        _viewModel.HideOverlayRequested = HideOverlay;
        _viewModel.OpenSettingsRequested = OpenSettings;
        _viewModel.SelectRequested = SelectItem;
        _viewModel.DeleteRequested = DeleteItem;
        _viewModel.ClearHistoryRequested = ClearHistory;
        _viewModel.RevealStorageRequested = _storageService.RevealInExplorer;
        _viewModel.QuitRequested = () => Application.Current.Shutdown();
    }

    private void RestoreHistory()
    {
        try
        {
            _viewModel.ReplaceHistory(_storageService.LoadHistory());
        }
        catch
        {
            _viewModel.SetStatusMessage(L10n.Tr("status.load_history_failed"));
        }
    }

    private void ConfigureSettingsPersistence()
    {
        _settings.PropertyChanged += (_, args) =>
        {
            if (args.PropertyName == nameof(AppSettings.AppLanguage))
            {
                L10n.Language = _settings.AppLanguage;
            }

            if (args.PropertyName is nameof(AppSettings.ThemeMode)
                or nameof(AppSettings.DayThemeStartMinutes)
                or nameof(AppSettings.NightThemeStartMinutes))
            {
                RefreshTheme();
            }

            if (args.PropertyName == nameof(AppSettings.LaunchAtLogin))
            {
                try
                {
                    _startupService.SetEnabled(_settings.LaunchAtLogin);
                }
                catch
                {
                    _viewModel.SetStatusMessage(_settings.LaunchAtLogin
                        ? L10n.Tr("status.launch_at_login_enable_failed")
                        : L10n.Tr("status.launch_at_login_disable_failed"));
                }
            }

            if (args.PropertyName == nameof(AppSettings.ShowTrayIcon))
            {
                _trayIconService.RefreshVisibility();
            }

            if (args.PropertyName == nameof(AppSettings.MaximumHistoryItems))
            {
                ApplyHistoryLimitIfNeeded();
            }

            ScheduleSettingsSave();
        };
    }

    private void ScheduleSettingsSave()
    {
        _settingsSaveTimer.Stop();
        _settingsSaveTimer.Start();
    }

    private void RefreshTheme()
    {
        _settings.RefreshActiveTheme(_themeService.SystemIsDark(), DateTime.Now);
    }

    private void OnClipboardChanged(object? sender, EventArgs e)
    {
        if (_settings.IsMonitoringPaused)
        {
            return;
        }

        var payload = _clipboardService.ReadSupportedPayload(_settings);
        if (payload is null)
        {
            return;
        }

        try
        {
            var item = _storageService.Store(payload);
            var updatedHistory = TrimmedHistoryWithNewestItem(item);
            _viewModel.ReplaceHistory(updatedHistory);
            _storageService.SaveHistory(updatedHistory);
        }
        catch
        {
            _viewModel.SetStatusMessage(L10n.Tr("status.save_latest_failed"));
        }
    }

    private IReadOnlyList<ClipboardItem> TrimmedHistoryWithNewestItem(ClipboardItem item)
    {
        var history = new[] { item }.Concat(_viewModel.CurrentHistory).ToArray();
        return _settings.HistoryLimit is { } limit ? history.Take(limit).ToArray() : history;
    }

    private void ShowOverlay()
    {
        try
        {
            DiagnosticLog.Write($"AppHost.ShowOverlay start items={_viewModel.CurrentHistory.Count}");
            _pasteActionService.CaptureForegroundWindow();
            _overlayWindow ??= new OverlayWindow(_viewModel, _settings);
            _overlayWindow.ShowOverlay();
            DiagnosticLog.Write("AppHost.ShowOverlay complete");
        }
        catch (Exception ex)
        {
            DiagnosticLog.Write($"AppHost.ShowOverlay failed {ex}");
            _viewModel.SetStatusMessage(L10n.Tr("status.hotkey_listen_failed"));
        }
    }

    private void HideOverlay()
    {
        _overlayWindow?.HideOverlay();
    }

    private void OpenSettings()
    {
        HideOverlay();

        if (_settingsWindow is null || _settingsWindow.IsLoaded == false)
        {
            _settingsWindow = new SettingsWindow(_viewModel, _settings, _startupService);
            _settingsWindow.Closed += (_, _) => _settingsWindow = null;
        }

        _viewModel.RefreshStorageUsage();
        _settingsWindow.Show();
        _settingsWindow.Activate();
    }

    private async void SelectItem(ClipboardItem item)
    {
        try
        {
            await _pasteActionService.RestoreClipboardAndPasteAsync(
                item,
                HideOverlay,
                message => _viewModel.SetStatusMessage(message));
        }
        catch
        {
            _viewModel.SetStatusMessage(L10n.Tr("status.restore_item_failed"));
        }
    }

    private void DeleteItem(ClipboardItem item)
    {
        var updatedHistory = _viewModel.CurrentHistory.Where(entry => entry.Id != item.Id).ToArray();

        try
        {
            _viewModel.ReplaceHistory(updatedHistory);
            _storageService.SaveHistory(updatedHistory);
        }
        catch
        {
            _viewModel.SetStatusMessage(L10n.Tr("status.delete_item_failed"));
        }
    }

    private void ClearHistory()
    {
        try
        {
            _storageService.ClearHistory();
            _viewModel.ReplaceHistory([]);
            _viewModel.SetStatusMessage(L10n.Tr("status.history_cleared"));
        }
        catch
        {
            _viewModel.SetStatusMessage(L10n.Tr("status.clear_history_failed"));
        }
    }

    private void ApplyHistoryLimitIfNeeded()
    {
        if (_settings.HistoryLimit is not { } limit)
        {
            return;
        }

        var trimmed = _viewModel.CurrentHistory.Take(limit).ToArray();
        if (trimmed.Length == _viewModel.CurrentHistory.Count)
        {
            return;
        }

        try
        {
            _viewModel.ReplaceHistory(trimmed);
            _storageService.SaveHistory(trimmed);
        }
        catch
        {
            _viewModel.SetStatusMessage(L10n.Tr("status.trim_history_failed"));
        }
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;
        _settingsSaveTimer.Stop();
        _themeTimer.Stop();
        _settingsStore.Save(_settings);
        _clipboardMonitor.Dispose();
        _hotkeyManager.Dispose();
        _trayIconService.Dispose();
        _overlayWindow?.Close();
        _settingsWindow?.Close();
    }
}
