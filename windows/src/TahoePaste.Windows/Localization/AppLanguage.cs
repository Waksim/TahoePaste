using System.Globalization;

namespace TahoePaste.Windows.Localization;

public enum AppLanguage
{
    English,
    Russian,
    SimplifiedChinese
}

public static class AppLanguageExtensions
{
    public static CultureInfo Culture(this AppLanguage language) => language switch
    {
        AppLanguage.Russian => CultureInfo.GetCultureInfo("ru-RU"),
        AppLanguage.SimplifiedChinese => CultureInfo.GetCultureInfo("zh-Hans-CN"),
        _ => CultureInfo.GetCultureInfo("en-US")
    };

    public static string DisplayName(this AppLanguage language) => language switch
    {
        AppLanguage.Russian => "Русский",
        AppLanguage.SimplifiedChinese => "简体中文",
        _ => "English"
    };

    public static AppLanguage BestMatch()
    {
        foreach (var cultureName in CultureInfo.CurrentUICulture.Name.Split(',', StringSplitOptions.RemoveEmptyEntries).Append(CultureInfo.CurrentUICulture.Name))
        {
            if (cultureName.StartsWith("ru", StringComparison.OrdinalIgnoreCase))
            {
                return AppLanguage.Russian;
            }

            if (cultureName.StartsWith("zh", StringComparison.OrdinalIgnoreCase))
            {
                return AppLanguage.SimplifiedChinese;
            }
        }

        return AppLanguage.English;
    }
}
