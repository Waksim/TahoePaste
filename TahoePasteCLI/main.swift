import AppKit
import Foundation

// tahoepaste-cli — agent-facing interface to the TahoePaste clipboard
// history. Thin dispatcher: parsing, querying, sensitivity gating, and
// storage transactions all live in the shared app sources so they are unit
// tested from the app target.
//
// Contract: stdout carries exactly one JSON object (or the plain-text help),
// diagnostics go to stderr. Exit codes: 0 ok, 1 usage/IO error, 2 agent
// access disabled, 3 not found, 4 sensitive item blocked.

private struct ErrorResponse: Codable {
    let error: String
    let code: String
}

private struct VersionResponse: Codable {
    let version: String
    let schemaVersion: Int
}

private struct CopyResponse: Codable {
    let id: UUID
    let copied: Bool
    let kind: String
    let restoredFiles: [String]?
    let missingFiles: [String]?
}

private struct AddResponse: Codable {
    let id: UUID
    let added: Bool
    let deduplicated: Bool
}

private struct DeleteResponse: Codable {
    let id: UUID
    let deleted: Bool
}

private func emit(_ value: some Encodable) {
    let encoder = AgentQueryService.makeEncoder()

    guard let data = try? encoder.encode(value), let json = String(data: data, encoding: .utf8) else {
        FileHandle.standardError.write(Data("Failed to encode response.\n".utf8))
        exit(1)
    }

    print(json)
}

private func fail(_ message: String, code: String, exitCode: Int32) -> Never {
    emit(ErrorResponse(error: message, code: code))
    exit(exitCode)
}

private func postHistoryChangedNotification() {
    DistributedNotificationCenter.default().postNotificationName(
        Notification.Name(AgentManifest.historyDidChangeNotificationName),
        object: nil,
        userInfo: nil,
        deliverImmediately: true
    )
}

/// The user's history limit, read from the app's preferences domain.
/// 0 or missing means unlimited — mirrors `SettingsManager.historyLimit`.
private func configuredHistoryLimit() -> Int? {
    let value = CFPreferencesCopyAppValue(
        "TahoePasteMaximumHistoryItems" as CFString,
        "com.mk.TahoePaste" as CFString
    ) as? Int

    guard let value, value > 0 else {
        return nil
    }

    return value
}

private func appVersion() -> String {
    // The CLI sits in TahoePaste.app/Contents/MacOS/, so the app bundle is
    // two directories up. Falls back to the manifest for out-of-bundle runs.
    if
        let executableURL = Bundle.main.executableURL,
        let bundle = Bundle(
            url: executableURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
        ),
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String
    {
        return version
    }

    return AgentManifest.read(from: StorageManager().rootDirectoryURL)?.appVersion ?? "unknown"
}

private func readStdinText() -> String {
    let data = FileHandle.standardInput.readDataToEndOfFile()
    let text = String(data: data, encoding: .utf8) ?? ""
    return text.hasSuffix("\n") ? String(text.dropLast()) : text
}

// MARK: - Entry point

let command: AgentCommand
do {
    command = try AgentCommand.parse(Array(CommandLine.arguments.dropFirst()))
} catch {
    fail(error.localizedDescription, code: "usage", exitCode: 1)
}

switch command {
case .help:
    print(AgentCommand.usage)
    exit(0)
case .version:
    emit(VersionResponse(version: appVersion(), schemaVersion: AgentManifest.currentSchemaVersion))
    exit(0)
default:
    break
}

let storageManager = StorageManager()
let repository = HistoryRepository(storageManager: storageManager)
let service = AgentQueryService(repository: repository, storageManager: storageManager)

// Fail-closed: no readable manifest means no access. The app rewrites the
// manifest on every launch, so a fresh install only needs one app start.
guard
    let manifest = AgentManifest.read(from: storageManager.rootDirectoryURL),
    manifest.enabled
else {
    fail(
        "Agent access is disabled. Launch TahoePaste and enable \"Agent access\" in Settings.",
        code: "disabled",
        exitCode: 2
    )
}

do {
    switch command {
    case .help, .version:
        break
    case .recent(let limit, let includeSensitive):
        emit(try service.recent(limit: limit, includeSensitive: includeSensitive))
    case .search(let query, let kind, let tag, let sinceRaw, let limit, let includeSensitive):
        var since: Date?

        if let sinceRaw {
            guard let parsed = AgentQueryService.parseSince(sinceRaw) else {
                fail("Invalid --since value '\(sinceRaw)'. Use ISO8601 or 30m/2h/7d.", code: "usage", exitCode: 1)
            }

            since = parsed
        }

        emit(try service.search(
            query: query,
            kind: kind,
            tag: tag,
            since: since,
            limit: limit,
            includeSensitive: includeSensitive
        ))
    case .get(let id, let full, let includeSensitive):
        emit(try service.detail(id: id, full: full, includeSensitive: includeSensitive))
    case .image(let id):
        emit(try service.imageInfo(id: id))
    case .copy(let id, let includeSensitive):
        let item = try service.item(id: id)
        try service.ensureAccessible(item, includeSensitive: includeSensitive)

        let result = try PasteboardItemWriter.write(item, storageManager: storageManager)
        emit(CopyResponse(
            id: item.id,
            copied: true,
            kind: item.kind.rawValue,
            restoredFiles: result.restoredFilePaths.isEmpty ? nil : result.restoredFilePaths,
            missingFiles: result.missingFilePaths.isEmpty ? nil : result.missingFilePaths
        ))
    case .add(let argumentText):
        let text = argumentText ?? readStdinText()

        guard text.isEmpty == false else {
            fail("Nothing to add: pass a text argument or pipe it via stdin.", code: "usage", exitCode: 1)
        }

        // History first (transactional), then the pasteboard. The running
        // app is told to reload; its own capture of the pasteboard change is
        // absorbed by the append dedupe inside the repository transaction.
        let outcome = try repository.append(payload: .text(text), historyLimit: configuredHistoryLimit())

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        guard pasteboard.setString(text, forType: .string) else {
            fail("Stored to history, but writing the pasteboard failed.", code: "io", exitCode: 1)
        }

        postHistoryChangedNotification()
        emit(AddResponse(id: outcome.item.id, added: true, deduplicated: outcome.wasDeduplicated))
    case .delete(let id):
        let outcome = try repository.delete(id: id)

        guard outcome.removedItem else {
            fail("No history item with id \(id.uuidString).", code: "not_found", exitCode: 3)
        }

        postHistoryChangedNotification()
        emit(DeleteResponse(id: id, deleted: true))
    }
} catch let error as AgentQueryService.QueryError {
    switch error {
    case .itemNotFound:
        fail(error.localizedDescription, code: "not_found", exitCode: 3)
    case .sensitiveItem:
        fail(error.localizedDescription, code: "sensitive", exitCode: 4)
    case .noImage:
        fail(error.localizedDescription, code: "not_found", exitCode: 3)
    }
} catch let error as PasteboardItemWriter.PasteError {
    fail(error.localizedDescription, code: "io", exitCode: 1)
} catch {
    fail(error.localizedDescription, code: "io", exitCode: 1)
}
