using System.Diagnostics;
using Microsoft.Win32;

namespace TahoePaste.Windows.Services;

public sealed class StartupService
{
    private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string ValueName = "TahoePaste";

    public bool IsEnabled()
    {
        using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath, writable: false);
        return key?.GetValue(ValueName) is string value && string.IsNullOrWhiteSpace(value) == false;
    }

    public void SetEnabled(bool enabled)
    {
        using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath, writable: true)
            ?? Registry.CurrentUser.CreateSubKey(RunKeyPath, writable: true);

        if (enabled)
        {
            var executablePath = Environment.ProcessPath
                ?? Process.GetCurrentProcess().MainModule?.FileName
                ?? Path.Combine(AppContext.BaseDirectory, "TahoePaste.exe");
            key.SetValue(ValueName, $"\"{executablePath}\"");
        }
        else
        {
            key.DeleteValue(ValueName, throwOnMissingValue: false);
        }
    }

    public void OpenStartupAppsSettings()
    {
        Process.Start(new ProcessStartInfo
        {
            FileName = "ms-settings:startupapps",
            UseShellExecute = true
        });
    }
}
