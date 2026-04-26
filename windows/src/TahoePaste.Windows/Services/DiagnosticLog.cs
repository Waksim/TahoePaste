namespace TahoePaste.Windows.Services;

public static class DiagnosticLog
{
    private static readonly object Sync = new();

    public static void Write(string message)
    {
        try
        {
            var root = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "TahoePaste");
            Directory.CreateDirectory(root);

            var line = $"{DateTimeOffset.Now:O} pid={Environment.ProcessId} {message}{Environment.NewLine}";
            lock (Sync)
            {
                File.AppendAllText(Path.Combine(root, "diagnostic.log"), line);
            }
        }
        catch
        {
        }
    }
}
