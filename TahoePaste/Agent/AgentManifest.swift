import Foundation

/// Discovery contract between the app and agent tooling. The app writes
/// `agent.json` into its data directory at every launch and whenever the
/// "Agent access" toggle changes; the skill reads it to find the CLI, and
/// the CLI reads it to enforce the toggle.
///
/// Fail-closed: a missing or unreadable manifest counts as disabled, so
/// deleting the file can never silently re-enable agent access. The app
/// re-creates it (default: enabled) on next launch.
struct AgentManifest: Codable {
    static let currentSchemaVersion = 1
    static let fileName = "agent.json"

    /// Cross-process "history changed on disk, re-read it" signal posted by
    /// the CLI after a mutation. Notification only — the interprocess file
    /// lock in `HistoryRepository` is what makes the mutation itself safe.
    static let historyDidChangeNotificationName = "com.mk.TahoePaste.historyDidChangeExternally"

    let schemaVersion: Int
    let appVersion: String
    let platform: String
    let cliPath: String
    let enabled: Bool
    let updatedAt: Date

    static func fileURL(in rootDirectoryURL: URL) -> URL {
        rootDirectoryURL.appendingPathComponent(fileName)
    }

    /// The CLI is embedded next to the app's executable. Never use
    /// `Bundle.main.executableURL` itself — in the GUI process that is the
    /// `TahoePaste` binary, not the CLI.
    static func bundledCLIURL() -> URL? {
        Bundle.main.executableURL?
            .deletingLastPathComponent()
            .appendingPathComponent("tahoepaste-cli")
    }

    static func current(enabled: Bool) -> AgentManifest {
        AgentManifest(
            schemaVersion: currentSchemaVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            platform: "macos",
            cliPath: bundledCLIURL()?.path ?? "",
            enabled: enabled,
            updatedAt: .now
        )
    }

    func write(to rootDirectoryURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(self)
        try data.write(to: Self.fileURL(in: rootDirectoryURL), options: [.atomic])
    }

    static func read(from rootDirectoryURL: URL) -> AgentManifest? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard
            let data = try? Data(contentsOf: fileURL(in: rootDirectoryURL)),
            let manifest = try? decoder.decode(AgentManifest.self, from: data)
        else {
            return nil
        }

        return manifest
    }
}
