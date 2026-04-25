using Microsoft.Win32;

namespace TahoePaste.Windows.Services;

public sealed class WindowsThemeService
{
    private const string PersonalizeKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize";

    public bool SystemIsDark()
    {
        using var key = Registry.CurrentUser.OpenSubKey(PersonalizeKeyPath, writable: false);
        var value = key?.GetValue("AppsUseLightTheme");
        return value is int intValue && intValue == 0;
    }
}
