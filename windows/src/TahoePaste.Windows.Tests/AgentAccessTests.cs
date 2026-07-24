using System;
using System.IO;
using System.Linq;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using TahoePaste.Cli;
using TahoePaste.Windows.Models;
using TahoePaste.Windows.Services;
using Xunit;

namespace TahoePaste.Windows.Tests;

public sealed class AgentAccessTests
{
    private static (StorageService Storage, HistoryRepository Repository, AppPaths Paths) MakeStorage()
    {
        var root = Path.Combine(Path.GetTempPath(), "TahoePasteTests", Guid.NewGuid().ToString("N"));
        var paths = new AppPaths(root);
        var storage = new StorageService(paths);
        return (storage, new HistoryRepository(storage), paths);
    }

    private static BitmapSource MakeImage()
    {
        var pixels = new byte[] { 255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 255, 255 };
        var image = BitmapSource.Create(2, 2, 96, 96, PixelFormats.Bgra32, null, pixels, 8);
        image.Freeze();
        return image;
    }

    [Fact]
    public void AppendPersistsTagsAndRoundTrips()
    {
        var (storage, repository, _) = MakeStorage();

        var outcome = repository.Append(ClipboardPayload.FromText("Password: Str0ng!Pass2026"), historyLimit: null);

        Assert.NotNull(outcome.Item.StoredTags);
        Assert.Contains(ClipboardTag.Password, outcome.Item.StoredTags!);
        Assert.Equal(ClipboardItem.CurrentTagsVersion, outcome.Item.TagsVersion);

        var reloaded = storage.DecodeHistory();
        Assert.Contains(ClipboardTag.Password, reloaded[0].StoredTags!);
    }

    [Fact]
    public void ReadSnapshotDoesNotDeleteFreshImageOrRewriteHistory()
    {
        var (storage, repository, paths) = MakeStorage();
        _ = repository.Append(ClipboardPayload.FromText("existing note"), historyLimit: null);

        // Simulates the capture window: PNG written, history.json not yet
        // updated to reference it.
        var freshItem = storage.Store(ClipboardPayload.FromImage(MakeImage()));
        var freshImagePath = storage.ImagePath(freshItem)!;
        Assert.True(File.Exists(freshImagePath));

        var historyBefore = File.ReadAllText(paths.HistoryPath);
        var snapshot = repository.ReadSnapshot();

        Assert.Single(snapshot);
        Assert.True(File.Exists(freshImagePath));
        Assert.Equal(historyBefore, File.ReadAllText(paths.HistoryPath));
    }

    [Fact]
    public void InterleavedMutationsDoNotLoseItems()
    {
        var (_, firstRepository, paths) = MakeStorage();
        var secondRepository = new HistoryRepository(new StorageService(paths));

        var first = firstRepository.Append(ClipboardPayload.FromText("item A"), historyLimit: null);
        _ = secondRepository.Append(ClipboardPayload.FromText("item B"), historyLimit: null);

        var outcome = firstRepository.Delete(first.Item.Id);

        Assert.True(outcome.RemovedItem);
        Assert.Single(outcome.History);
        Assert.Equal("item B", outcome.History[0].Text);
    }

    [Fact]
    public void AppendDeduplicatesIdenticalNewestText()
    {
        var (_, repository, _) = MakeStorage();

        var first = repository.Append(ClipboardPayload.FromText("same text"), historyLimit: null);
        var second = repository.Append(ClipboardPayload.FromText("same text"), historyLimit: null);

        Assert.False(first.WasDeduplicated);
        Assert.True(second.WasDeduplicated);
        Assert.Equal(first.Item.Id, second.Item.Id);
        Assert.Single(repository.ReadSnapshot());
    }

    [Fact]
    public void AppendAppliesHistoryLimit()
    {
        var (_, repository, _) = MakeStorage();

        for (var index = 0; index < 5; index++)
        {
            _ = repository.Append(ClipboardPayload.FromText($"note {index}"), historyLimit: 3);
        }

        var snapshot = repository.ReadSnapshot();
        Assert.Equal(3, snapshot.Count);
        Assert.Equal("note 4", snapshot[0].Text);
    }

    [Fact]
    public void RepairAndMigrateAddsTagsToLegacyItems()
    {
        var (storage, repository, _) = MakeStorage();

        var legacyItem = new ClipboardItem(
            Guid.NewGuid(),
            ClipboardKind.Link,
            DateTimeOffset.Now,
            "https://example.com",
            "https://example.com",
            null,
            null,
            null);
        storage.SaveHistory([legacyItem]);

        var migrated = repository.RepairAndMigrate();

        Assert.NotNull(migrated[0].StoredTags);
        Assert.Equal(ClipboardTag.Link, migrated[0].StoredTags![0]);
        Assert.Equal(ClipboardItem.CurrentTagsVersion, migrated[0].TagsVersion);
        Assert.NotNull(storage.DecodeHistory()[0].StoredTags);
    }

    [Fact]
    public void FullTextScanCatchesSecretBeyondClassifierCap()
    {
        var padding = string.Concat(Enumerable.Repeat("lorem ipsum dolor sit amet ", 200));
        var text = padding + "\nAuthorization: Bearer sk_live_1234567890ABCDEF";

        Assert.DoesNotContain(ClipboardTag.Token, ClipboardContentClassifier.DetectedTags(text));
        Assert.True(ClipboardContentClassifier.ContainsSensitiveContentInFullText(text));
    }

    [Fact]
    public void AgentQueryServiceExcludesSensitiveItemsByDefault()
    {
        var (storage, repository, _) = MakeStorage();
        var service = new AgentQueryService(repository, storage);

        _ = repository.Append(ClipboardPayload.FromText("plain note"), historyLimit: null);
        _ = repository.Append(ClipboardPayload.FromText("Password: Str0ng!Pass2026"), historyLimit: null);

        var hidden = service.Recent(limit: 10, includeSensitive: false);
        Assert.Single(hidden.Items);
        Assert.Equal(1, hidden.TotalItems);
        Assert.Equal(1, hidden.SensitiveExcluded);

        var revealed = service.Recent(limit: 10, includeSensitive: true);
        Assert.Equal(2, revealed.Items.Count);
        Assert.Equal(0, revealed.SensitiveExcluded);
    }

    [Fact]
    public void AgentQueryServiceDetailBlocksSensitiveWithoutOverride()
    {
        var (storage, repository, _) = MakeStorage();
        var service = new AgentQueryService(repository, storage);

        var outcome = repository.Append(ClipboardPayload.FromText("Password: Str0ng!Pass2026"), historyLimit: null);

        var error = Assert.Throws<AgentQueryService.QueryException>(
            () => service.Detail(outcome.Item.Id, full: true, includeSensitive: false));
        Assert.Equal("sensitive", error.Code);

        var revealed = service.Detail(outcome.Item.Id, full: true, includeSensitive: true);
        Assert.Contains("Str0ng!Pass2026", revealed.Text);
    }

    [Fact]
    public void ParseSinceAcceptsRelativeAndAbsoluteFormats()
    {
        var now = new DateTimeOffset(2026, 7, 10, 12, 0, 0, TimeSpan.Zero);

        Assert.Equal(now.AddMinutes(-30), AgentQueryService.ParseSince("30m", now));
        Assert.Equal(now.AddHours(-2), AgentQueryService.ParseSince("2h", now));
        Assert.Equal(now.AddDays(-7), AgentQueryService.ParseSince("7d", now));
        Assert.NotNull(AgentQueryService.ParseSince("2026-07-01T00:00:00Z", now));
        Assert.Null(AgentQueryService.ParseSince("tomorrow", now));
    }

    [Fact]
    public void TagWireNamesUseSwiftRawValueFormat()
    {
        Assert.Equal("dateTime", TagWireNames.ToWire(ClipboardTag.DateTime));
        Assert.Equal("pdf", TagWireNames.ToWire(ClipboardTag.Pdf));
        Assert.Equal("text", TagWireNames.ToWire(ClipboardKind.Text));

        Assert.True(TagWireNames.TryParseTag("datetime", out var tag));
        Assert.Equal(ClipboardTag.DateTime, tag);
        Assert.False(TagWireNames.TryParseTag("frobnicate", out _));
    }
}
