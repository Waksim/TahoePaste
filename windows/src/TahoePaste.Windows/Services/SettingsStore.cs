using System.Text.Json;
using System.Text.Json.Serialization;

namespace TahoePaste.Windows.Services;

public sealed class SettingsStore
{
    private readonly string _settingsPath;
    private readonly JsonSerializerOptions _jsonOptions;

    public SettingsStore(AppPaths paths)
    {
        _settingsPath = Path.Combine(paths.RootDirectory, "settings.json");
        _jsonOptions = new JsonSerializerOptions
        {
            WriteIndented = true,
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            Converters = { new JsonStringEnumConverter() }
        };
    }

    public AppSettings Load()
    {
        Directory.CreateDirectory(Path.GetDirectoryName(_settingsPath)!);

        if (File.Exists(_settingsPath) == false)
        {
            return new AppSettings();
        }

        try
        {
            var json = File.ReadAllText(_settingsPath);
            var settings = JsonSerializer.Deserialize<AppSettings>(json, _jsonOptions) ?? new AppSettings();
            MigrateLegacySettings(settings);
            return settings;
        }
        catch
        {
            return new AppSettings();
        }
    }

    // Pre-layout builds persisted a single overlay height; carry it into the
    // manual layout so a user-tuned value survives the upgrade.
    private static void MigrateLegacySettings(AppSettings settings)
    {
        if (settings.OverlayHeight > 0)
        {
            settings.ManualOverlayHeight = settings.OverlayHeight;
            settings.OverlayHeight = 0;
        }
    }

    public void Save(AppSettings settings)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(_settingsPath)!);

        var tempPath = _settingsPath + ".tmp";
        var json = JsonSerializer.Serialize(settings, _jsonOptions);
        File.WriteAllText(tempPath, json);
        File.Move(tempPath, _settingsPath, overwrite: true);
    }
}
