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
            return JsonSerializer.Deserialize<AppSettings>(json, _jsonOptions) ?? new AppSettings();
        }
        catch
        {
            return new AppSettings();
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
