using System.Reflection;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace TahoePaste.Windows.Services;

/// <summary>
/// Discovery contract between the app and agent tooling. The app writes
/// agent.json into its data directory at every launch and whenever the
/// "Agent access" toggle changes; the skill reads it to find the CLI, and
/// the CLI reads it to enforce the toggle.
///
/// Fail-closed: a missing or unreadable manifest counts as disabled, so
/// deleting the file can never silently re-enable agent access. The app
/// re-creates it (default: enabled) on next launch.
/// </summary>
public sealed record AgentManifest(
    int SchemaVersion,
    string AppVersion,
    string Platform,
    string CliPath,
    bool Enabled,
    DateTimeOffset UpdatedAt)
{
    public const int CurrentSchemaVersion = 1;
    public const string FileName = "agent.json";

    /// <summary>
    /// Cross-process "history changed on disk, re-read it" signal set by the
    /// CLI after a mutation. Notification only — the named mutex in
    /// HistoryRepository is what makes the mutation itself safe.
    /// </summary>
    public const string HistoryChangedEventName = @"Local\TahoePaste.HistoryChangedExternally";

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        Converters = { new JsonStringEnumConverter() }
    };

    public static string FilePath(AppPaths paths) => Path.Combine(paths.RootDirectory, FileName);

    public static AgentManifest Current(bool enabled)
    {
        return new AgentManifest(
            CurrentSchemaVersion,
            Assembly.GetEntryAssembly()?.GetName().Version?.ToString(3) ?? "unknown",
            "windows",
            Path.Combine(AppContext.BaseDirectory, "tahoepaste-cli.exe"),
            enabled,
            DateTimeOffset.UtcNow);
    }

    public void Write(AppPaths paths)
    {
        paths.Ensure();

        var tempPath = $"{FilePath(paths)}.{Guid.NewGuid():N}.tmp";
        File.WriteAllText(tempPath, JsonSerializer.Serialize(this, JsonOptions));
        File.Move(tempPath, FilePath(paths), overwrite: true);
    }

    public static AgentManifest? Read(AppPaths paths)
    {
        try
        {
            var path = FilePath(paths);
            if (File.Exists(path) == false)
            {
                return null;
            }

            return JsonSerializer.Deserialize<AgentManifest>(File.ReadAllText(path), JsonOptions);
        }
        catch
        {
            return null;
        }
    }
}
