using System.Threading;
using TahoePaste.Windows.Models;

namespace TahoePaste.Windows.Services;

/// <summary>
/// Serializes every history mutation across processes (GUI app and the
/// bundled CLI) with a named mutex, and offers a side-effect-free read for
/// concurrent readers.
///
/// Disk repair (dropping items whose PNG is gone, pruning orphaned images,
/// recomputing persisted tags) runs only inside locked writer transactions:
/// a plain reader must never delete an image the app captured a moment ago
/// but has not referenced from history.json yet.
/// </summary>
public sealed class HistoryRepository
{
    public const string MutexName = @"Local\TahoePaste.HistoryLock";

    public sealed record AppendOutcome(IReadOnlyList<ClipboardItem> History, ClipboardItem Item, bool WasDeduplicated);

    public sealed record DeleteOutcome(IReadOnlyList<ClipboardItem> History, bool RemovedItem);

    private readonly StorageService _storageService;
    private readonly TimeSpan _lockTimeout;

    public HistoryRepository(StorageService storageService, TimeSpan? lockTimeout = null)
    {
        _storageService = storageService;
        _lockTimeout = lockTimeout ?? TimeSpan.FromSeconds(5);
    }

    /// <summary>
    /// Pure read: never writes JSON and never deletes files. Items whose
    /// image file is missing are filtered from the returned snapshot but the
    /// on-disk state is left untouched for the next writer transaction.
    /// </summary>
    public IReadOnlyList<ClipboardItem> ReadSnapshot()
    {
        return DropItemsWithMissingImages(_storageService.DecodeHistory());
    }

    /// <summary>
    /// Stores a captured payload as the newest history item. When the newest
    /// existing item already carries the exact same text payload the append
    /// is skipped, so a clipboard round-trip (CLI add/copy re-captured by
    /// the app's clipboard monitor) cannot duplicate the entry.
    /// </summary>
    public AppendOutcome Append(ClipboardPayload payload, int? historyLimit)
    {
        return WithExclusiveLock(() =>
        {
            var current = DropItemsWithMissingImages(_storageService.DecodeHistory());

            if (current.Count > 0 && IsDuplicate(payload, current[0]))
            {
                return new AppendOutcome(current, current[0], WasDeduplicated: true);
            }

            var item = _storageService.Store(payload);
            IReadOnlyList<ClipboardItem> updated = new[] { item }.Concat(current).ToArray();

            if (historyLimit is { } limit)
            {
                updated = updated.Take(Math.Max(limit, 1)).ToArray();
            }

            _storageService.SaveHistory(updated);
            return new AppendOutcome(updated, item, WasDeduplicated: false);
        });
    }

    public DeleteOutcome Delete(Guid id)
    {
        return WithExclusiveLock(() =>
        {
            var current = DropItemsWithMissingImages(_storageService.DecodeHistory());
            var updated = current.Where(item => item.Id != id).ToArray();

            if (updated.Length == current.Count)
            {
                return new DeleteOutcome(current, RemovedItem: false);
            }

            _storageService.SaveHistory(updated);
            return new DeleteOutcome(updated, RemovedItem: true);
        });
    }

    public IReadOnlyList<ClipboardItem> Clear()
    {
        return WithExclusiveLock<IReadOnlyList<ClipboardItem>>(() =>
        {
            _storageService.SaveHistory([]);
            return [];
        });
    }

    public IReadOnlyList<ClipboardItem> Trim(int limit)
    {
        return WithExclusiveLock<IReadOnlyList<ClipboardItem>>(() =>
        {
            var current = DropItemsWithMissingImages(_storageService.DecodeHistory());
            if (current.Count <= Math.Max(limit, 0))
            {
                return current;
            }

            var trimmed = current.Take(Math.Max(limit, 0)).ToArray();
            _storageService.SaveHistory(trimmed);
            return trimmed;
        });
    }

    /// <summary>
    /// Launch-time writer transaction for the GUI app: drops items whose
    /// image file disappeared, recomputes persisted tags produced by an
    /// older resolver, and prunes orphaned image files.
    /// </summary>
    public IReadOnlyList<ClipboardItem> RepairAndMigrate()
    {
        return WithExclusiveLock<IReadOnlyList<ClipboardItem>>(() =>
        {
            var decoded = _storageService.DecodeHistory();
            var repaired = new List<ClipboardItem>(decoded.Count);
            // Record equality on list properties is reference-based, so track
            // changes explicitly instead of comparing decoded vs repaired.
            var changed = false;

            foreach (var item in decoded)
            {
                if (item.IsImage && ImageFileMissing(item))
                {
                    changed = true;
                    continue;
                }

                if (item.NeedsTagRecompute)
                {
                    repaired.Add(item.WithComputedTags());
                    changed = true;
                }
                else
                {
                    repaired.Add(item);
                }
            }

            if (changed)
            {
                _storageService.SaveHistory(repaired);
            }
            else
            {
                _storageService.RemoveOrphanedImages(repaired);
            }

            return repaired;
        });
    }

    private IReadOnlyList<ClipboardItem> DropItemsWithMissingImages(IReadOnlyList<ClipboardItem> items)
    {
        return items.Where(item => item.IsImage == false || ImageFileMissing(item) == false).ToArray();
    }

    private bool ImageFileMissing(ClipboardItem item)
    {
        return _storageService.ImagePath(item) is not { } path || File.Exists(path) == false;
    }

    private static bool IsDuplicate(ClipboardPayload payload, ClipboardItem newest)
    {
        return payload.PayloadKind == ClipboardPayloadKind.Text
            && newest.ImageFilename is null
            && newest.FileReferences is null
            && newest.Text == payload.Text;
    }

    private T WithExclusiveLock<T>(Func<T> body)
    {
        using var mutex = new Mutex(initiallyOwned: false, MutexName);
        var acquired = false;

        try
        {
            try
            {
                acquired = mutex.WaitOne(_lockTimeout);
            }
            catch (AbandonedMutexException)
            {
                // The previous holder died mid-transaction. On-disk state is
                // still consistent because saves are atomic moves.
                acquired = true;
            }

            if (acquired == false)
            {
                throw new TimeoutException("Timed out waiting for another TahoePaste process to release the history lock.");
            }

            return body();
        }
        finally
        {
            if (acquired)
            {
                mutex.ReleaseMutex();
            }
        }
    }
}
