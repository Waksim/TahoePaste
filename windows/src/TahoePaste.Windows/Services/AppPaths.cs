namespace TahoePaste.Windows.Services;

public sealed class AppPaths
{
    public AppPaths(string? rootDirectory = null)
    {
        RootDirectory = rootDirectory
            ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "TahoePaste");
        ImagesDirectory = Path.Combine(RootDirectory, "Images");
        HistoryPath = Path.Combine(RootDirectory, "history.json");
    }

    public string RootDirectory { get; }
    public string ImagesDirectory { get; }
    public string HistoryPath { get; }

    public void Ensure()
    {
        Directory.CreateDirectory(RootDirectory);
        Directory.CreateDirectory(ImagesDirectory);
    }
}
