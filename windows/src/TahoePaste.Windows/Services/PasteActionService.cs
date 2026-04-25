using TahoePaste.Windows.Localization;
using TahoePaste.Windows.Models;

namespace TahoePaste.Windows.Services;

public sealed class PasteActionService
{
    private readonly ClipboardService _clipboardService;
    private readonly ClipboardMonitor _clipboardMonitor;
    private readonly StorageService _storageService;
    private readonly ForegroundWindowService _foregroundWindowService;
    private readonly AppSettings _settings;

    public PasteActionService(
        ClipboardService clipboardService,
        ClipboardMonitor clipboardMonitor,
        StorageService storageService,
        ForegroundWindowService foregroundWindowService,
        AppSettings settings)
    {
        _clipboardService = clipboardService;
        _clipboardMonitor = clipboardMonitor;
        _storageService = storageService;
        _foregroundWindowService = foregroundWindowService;
        _settings = settings;
    }

    public void CaptureForegroundWindow()
    {
        _foregroundWindowService.CaptureCurrentForegroundWindow();
    }

    public async Task RestoreClipboardAndPasteAsync(
        ClipboardItem item,
        Action hideOverlay,
        Action<string> onPermissionFallback)
    {
        _clipboardMonitor.SuppressNextChange();
        _clipboardService.WriteItem(item, _storageService);

        hideOverlay();

        if (_settings.ReactivatePreviousAppBeforePaste)
        {
            _foregroundWindowService.ReactivatePreviousWindow();
        }

        if (_settings.AutoPasteAfterSelection == false)
        {
            return;
        }

        await Task.Delay(TimeSpan.FromSeconds(_settings.PasteDelay));
        _foregroundWindowService.SendCtrlV();

        await Task.Delay(TimeSpan.FromMilliseconds(200));
        onPermissionFallback(L10n.Tr("status.input_automation_manual_paste"));
    }
}
