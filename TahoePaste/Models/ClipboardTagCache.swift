import Foundation
import os

enum ClipboardTagCache {
    private static let storage = OSAllocatedUnfairLock(initialState: [UUID: [ClipboardTag]]())

    static func tags(for item: ClipboardItem) -> [ClipboardTag] {
        if let cached = storage.withLock({ $0[item.id] }) {
            return cached
        }

        // Items are immutable, so caching by id is safe. Detection runs outside
        // the lock; a duplicate computation on a race is benign.
        let resolved = resolveTags(for: item)
        storage.withLock { $0[item.id] = resolved }

        return resolved
    }

    static func removeTags(forItemIDs ids: [UUID]) {
        storage.withLock { state in
            for id in ids {
                state.removeValue(forKey: id)
            }
        }
    }

    static func removeAll() {
        storage.withLock { $0.removeAll() }
    }

    private static func resolveTags(for item: ClipboardItem) -> [ClipboardTag] {
        var resolvedTags = [item.kind.primaryTag]

        if item.kind != .file, let text = item.text {
            for tag in ClipboardContentClassifier.detectedTags(for: text) where resolvedTags.contains(tag) == false {
                resolvedTags.append(tag)
            }
        }

        if let fileReferences = item.fileReferences {
            for fileReference in fileReferences {
                for tag in fileReference.category.tags where resolvedTags.contains(tag) == false {
                    resolvedTags.append(tag)
                }
            }
        }

        return resolvedTags
    }
}
