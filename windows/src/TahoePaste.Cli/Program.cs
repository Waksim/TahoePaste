using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading;
using System.Windows;
using TahoePaste.Windows.Models;
using TahoePaste.Windows.Services;

namespace TahoePaste.Cli;

/// <summary>
/// tahoepaste-cli — agent-facing interface to the TahoePaste clipboard
/// history. Mirrors the macOS CLI: stdout carries exactly one JSON object
/// (or the plain-text help), diagnostics go to stderr. Exit codes: 0 ok,
/// 1 usage/IO error, 2 agent access disabled, 3 not found, 4 sensitive item
/// blocked.
/// </summary>
public static class Program
{
    private const string Usage = """
        tahoepaste-cli — query and mutate the TahoePaste clipboard history.

        USAGE:
          tahoepaste-cli recent [--limit N] [--include-sensitive]
          tahoepaste-cli search <query> [--kind K] [--tag T] [--since S] [--limit N] [--include-sensitive]
          tahoepaste-cli get <uuid> [--full] [--include-sensitive]
          tahoepaste-cli image <uuid>
          tahoepaste-cli copy <uuid> [--include-sensitive]
          tahoepaste-cli add [text]           (reads stdin when no text argument)
          tahoepaste-cli delete <uuid>
          tahoepaste-cli --help | --version

        OPTIONS:
          --limit N              1...100, default 10
          --kind K               text | image | link | code | file
          --tag T                e.g. link, code, email, password, pdf, folder
          --since S              ISO8601 timestamp or relative: 30m, 2h, 7d
          --full                 include the full text / image path / file list
          --include-sensitive    also return items recognized as password/token

        All output is a single JSON object on stdout. Items recognized by the
        content classifier as passwords or tokens are hidden unless
        --include-sensitive is passed. Exit codes: 0 ok, 1 usage or I/O error,
        2 agent access disabled, 3 not found, 4 sensitive item blocked.
        """;

    private static readonly JsonSerializerOptions OutputOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
        Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping
    };

    [STAThread]
    public static int Main(string[] args)
    {
        Console.OutputEncoding = Encoding.UTF8;

        try
        {
            return Run(args);
        }
        catch (AgentQueryService.QueryException error)
        {
            return Fail(error.Message, error.Code, error.ExitCode);
        }
        catch (Exception error)
        {
            return Fail(error.Message, "io", 1);
        }
    }

    private static int Run(string[] args)
    {
        if (args.Length == 0)
        {
            return Fail("No command given. Run with --help for usage.", "usage", 1);
        }

        var command = args[0];
        var rest = args.Skip(1).ToArray();

        switch (command)
        {
            case "--help" or "help" or "-h":
                Console.WriteLine(Usage);
                return 0;
            case "--version" or "version":
                Emit(new
                {
                    version = typeof(Program).Assembly.GetName().Version?.ToString(3) ?? "unknown",
                    schemaVersion = AgentManifest.CurrentSchemaVersion
                });
                return 0;
        }

        var paths = new AppPaths();
        var storageService = new StorageService(paths);
        var repository = new HistoryRepository(storageService);
        var service = new AgentQueryService(repository, storageService);

        // Fail-closed: no readable manifest means no access. The app rewrites
        // the manifest on every launch, so a fresh install only needs one app
        // start.
        var manifest = AgentManifest.Read(paths);
        if (manifest is null || manifest.Enabled == false)
        {
            return Fail(
                "Agent access is disabled. Launch TahoePaste and enable \"Agent access\" in Settings.",
                "disabled",
                2);
        }

        var options = ParseOptions(rest, out var positionals);

        switch (command)
        {
            case "recent":
            {
                RejectPositionals(positionals);
                Emit(service.Recent(ParseLimit(options), HasFlag(options, "--include-sensitive")));
                return 0;
            }
            case "search":
            {
                if (positionals.Count == 0)
                {
                    return Fail("Missing required argument <query>.", "usage", 1);
                }

                RejectPositionals(positionals.Skip(1).ToList());

                ClipboardKind? kind = null;
                if (options.TryGetValue("--kind", out var rawKind))
                {
                    if (TagWireNames.TryParseKind(rawKind, out var parsedKind) == false)
                    {
                        return Fail($"Invalid value '{rawKind}' for option '--kind'.", "usage", 1);
                    }

                    kind = parsedKind;
                }

                ClipboardTag? tag = null;
                if (options.TryGetValue("--tag", out var rawTag))
                {
                    if (TagWireNames.TryParseTag(rawTag, out var parsedTag) == false)
                    {
                        return Fail($"Invalid value '{rawTag}' for option '--tag'.", "usage", 1);
                    }

                    tag = parsedTag;
                }

                DateTimeOffset? since = null;
                if (options.TryGetValue("--since", out var rawSince))
                {
                    since = AgentQueryService.ParseSince(rawSince);
                    if (since is null)
                    {
                        return Fail($"Invalid --since value '{rawSince}'. Use ISO8601 or 30m/2h/7d.", "usage", 1);
                    }
                }

                Emit(service.Search(
                    positionals[0],
                    kind,
                    tag,
                    since,
                    ParseLimit(options),
                    HasFlag(options, "--include-sensitive")));
                return 0;
            }
            case "get":
            {
                var id = RequireGuid(positionals);
                Emit(service.Detail(id, HasFlag(options, "--full"), HasFlag(options, "--include-sensitive")));
                return 0;
            }
            case "image":
            {
                Emit(service.GetImageInfo(RequireGuid(positionals)));
                return 0;
            }
            case "copy":
            {
                var id = RequireGuid(positionals);
                var item = service.Item(id);
                service.EnsureAccessible(item, HasFlag(options, "--include-sensitive"));

                // ClipboardService validates the payload before touching the
                // clipboard, so a failed copy keeps the previous contents.
                new ClipboardService().WriteItem(item, storageService);
                Emit(new { id = item.Id, copied = true, kind = TagWireNames.ToWire(item.Kind) });
                return 0;
            }
            case "add":
            {
                var text = positionals.Count > 0 ? positionals[0] : ReadStdinText();
                RejectPositionals(positionals.Skip(1).ToList());

                if (string.IsNullOrEmpty(text))
                {
                    return Fail("Nothing to add: pass a text argument or pipe it via stdin.", "usage", 1);
                }

                // History first (transactional), then the clipboard. The
                // running app is told to reload; its own capture of the
                // clipboard change is absorbed by the append dedupe inside
                // the repository transaction.
                var settings = new SettingsStore(paths).Load();
                var outcome = repository.Append(ClipboardPayload.FromText(text), settings.HistoryLimit);

                var data = new DataObject();
                data.SetText(text);
                Clipboard.SetDataObject(data, true);

                SignalHistoryChanged();
                Emit(new { id = outcome.Item.Id, added = true, deduplicated = outcome.WasDeduplicated });
                return 0;
            }
            case "delete":
            {
                var id = RequireGuid(positionals);
                var outcome = repository.Delete(id);

                if (outcome.RemovedItem == false)
                {
                    return Fail($"No history item with id {id}.", "not_found", 3);
                }

                SignalHistoryChanged();
                Emit(new { id, deleted = true });
                return 0;
            }
            default:
                return Fail($"Unknown command '{command}'. Run with --help for usage.", "usage", 1);
        }
    }

    private static Dictionary<string, string?> ParseOptions(string[] arguments, out List<string> positionals)
    {
        var flagOptions = new HashSet<string> { "--include-sensitive", "--full" };
        var valueOptions = new HashSet<string> { "--limit", "--kind", "--tag", "--since" };
        var options = new Dictionary<string, string?>();
        positionals = [];

        for (var index = 0; index < arguments.Length; index++)
        {
            var argument = arguments[index];

            if (argument.StartsWith("--", StringComparison.Ordinal))
            {
                if (flagOptions.Contains(argument))
                {
                    options[argument] = null;
                }
                else if (valueOptions.Contains(argument))
                {
                    if (index + 1 >= arguments.Length)
                    {
                        throw new AgentQueryService.QueryException("usage", 1, $"Option '{argument}' requires a value.");
                    }

                    options[argument] = arguments[++index];
                }
                else
                {
                    throw new AgentQueryService.QueryException("usage", 1, $"Unknown option '{argument}'.");
                }
            }
            else
            {
                positionals.Add(argument);
            }
        }

        return options;
    }

    private static bool HasFlag(Dictionary<string, string?> options, string flag) => options.ContainsKey(flag);

    private static int ParseLimit(Dictionary<string, string?> options)
    {
        if (options.TryGetValue("--limit", out var raw) == false || raw is null)
        {
            return AgentQueryService.DefaultLimit;
        }

        if (int.TryParse(raw, out var parsed) == false || parsed < 1)
        {
            throw new AgentQueryService.QueryException("usage", 1, $"Invalid value '{raw}' for option '--limit'.");
        }

        return Math.Min(parsed, AgentQueryService.MaxLimit);
    }

    private static Guid RequireGuid(List<string> positionals)
    {
        if (positionals.Count == 0)
        {
            throw new AgentQueryService.QueryException("usage", 1, "Missing required argument <uuid>.");
        }

        if (Guid.TryParse(positionals[0], out var id) == false)
        {
            throw new AgentQueryService.QueryException("usage", 1, $"Invalid value '{positionals[0]}' for <uuid>.");
        }

        RejectPositionals(positionals.Skip(1).ToList());
        return id;
    }

    private static void RejectPositionals(IReadOnlyCollection<string> positionals)
    {
        if (positionals.Count > 0)
        {
            throw new AgentQueryService.QueryException("usage", 1, $"Unexpected argument '{positionals.First()}'.");
        }
    }

    private static string ReadStdinText()
    {
        var text = Console.In.ReadToEnd();
        return text.EndsWith('\n') ? text.TrimEnd('\r', '\n') : text;
    }

    private static void SignalHistoryChanged()
    {
        using var historyChangedEvent = new EventWaitHandle(
            false,
            EventResetMode.AutoReset,
            AgentManifest.HistoryChangedEventName);
        historyChangedEvent.Set();
    }

    private static void Emit(object value)
    {
        Console.WriteLine(JsonSerializer.Serialize(value, OutputOptions));
    }

    private static int Fail(string message, string code, int exitCode)
    {
        Emit(new { error = message, code });
        return exitCode;
    }
}
