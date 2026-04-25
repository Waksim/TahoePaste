using System.Drawing;
using System.Windows;
using Forms = System.Windows.Forms;
using TahoePaste.Windows.Localization;
using TahoePaste.Windows.ViewModels;

namespace TahoePaste.Windows.Services;

public sealed class TrayIconService : IDisposable
{
    private readonly ClipboardHistoryViewModel _viewModel;
    private readonly AppSettings _settings;
    private readonly Forms.NotifyIcon _notifyIcon;
    private readonly Forms.ContextMenuStrip _menu = new();
    private readonly Forms.ToolStripMenuItem _monitoringItem = new();
    private readonly Forms.ToolStripMenuItem _savedItemsItem = new();
    private readonly Forms.ToolStripMenuItem _showClipboardItem = new();
    private readonly Forms.ToolStripMenuItem _settingsItem = new();
    private readonly Forms.ToolStripMenuItem _quitItem = new();

    public TrayIconService(ClipboardHistoryViewModel viewModel, AppSettings settings)
    {
        _viewModel = viewModel;
        _settings = settings;
        _notifyIcon = new Forms.NotifyIcon
        {
            Icon = LoadTrayIcon(),
            Text = L10n.Tr("common.tahoepaste"),
            ContextMenuStrip = _menu
        };

        ConfigureMenu();
        BindState();
    }

    public void Start()
    {
        RefreshLocalizedText();
        RefreshLabels();
        RefreshVisibility();
    }

    public void RefreshVisibility()
    {
        _notifyIcon.Visible = _settings.ShowTrayIcon;
    }

    private void ConfigureMenu()
    {
        _monitoringItem.Enabled = false;
        _savedItemsItem.Enabled = false;

        _showClipboardItem.Click += (_, _) => Dispatch(_viewModel.ShowOverlay);
        _settingsItem.Click += (_, _) => Dispatch(_viewModel.OpenSettings);
        _quitItem.Click += (_, _) => Dispatch(_viewModel.Quit);
        _notifyIcon.DoubleClick += (_, _) => Dispatch(_viewModel.ShowOverlay);

        _menu.Items.Add(_monitoringItem);
        _menu.Items.Add(_savedItemsItem);
        _menu.Items.Add(new Forms.ToolStripSeparator());
        _menu.Items.Add(_showClipboardItem);
        _menu.Items.Add(_settingsItem);
        _menu.Items.Add(new Forms.ToolStripSeparator());
        _menu.Items.Add(_quitItem);
    }

    private void BindState()
    {
        _viewModel.PropertyChanged += (_, args) =>
        {
            if (args.PropertyName is nameof(ClipboardHistoryViewModel.SavedItemsStatusLabel)
                or nameof(ClipboardHistoryViewModel.MonitoringStatusLabel))
            {
                RefreshLabels();
            }
        };

        _settings.PropertyChanged += (_, args) =>
        {
            if (args.PropertyName == nameof(AppSettings.IsMonitoringPaused))
            {
                RefreshLabels();
            }
        };

        L10n.LanguageChanged += (_, _) =>
        {
            RefreshLocalizedText();
            RefreshLabels();
        };
    }

    private void RefreshLabels()
    {
        _monitoringItem.Text = _viewModel.MonitoringStatusLabel;
        _savedItemsItem.Text = _viewModel.SavedItemsStatusLabel;
    }

    private void RefreshLocalizedText()
    {
        _notifyIcon.Text = L10n.Tr("common.tahoepaste");
        _showClipboardItem.Text = L10n.Tr("common.show_clipboard");
        _settingsItem.Text = L10n.Tr("common.settings");
        _quitItem.Text = L10n.Tr("common.quit_tahoepaste");
    }

    private static void Dispatch(Action action)
    {
        var application = Application.Current;
        if (application?.Dispatcher.CheckAccess() == true)
        {
            action();
        }
        else
        {
            application?.Dispatcher.Invoke(action);
        }
    }

    private static Icon LoadTrayIcon()
    {
        try
        {
            var executablePath = Environment.ProcessPath;
            return string.IsNullOrWhiteSpace(executablePath)
                ? SystemIcons.Application
                : Icon.ExtractAssociatedIcon(executablePath) ?? SystemIcons.Application;
        }
        catch
        {
            return SystemIcons.Application;
        }
    }

    public void Dispose()
    {
        _notifyIcon.Visible = false;
        _notifyIcon.Dispose();
        _menu.Dispose();
    }
}
