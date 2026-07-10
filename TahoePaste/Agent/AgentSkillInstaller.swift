import Foundation

/// Copies the bundled agent skill into the user's Claude Code skills
/// directory, so "install the skill" is one button in Settings.
enum AgentSkillInstaller {
    enum InstallError: LocalizedError {
        case skillResourceMissing

        var errorDescription: String? {
            "The bundled SKILL.md resource is missing from the app."
        }
    }

    static func skillDestinationURL(fileManager: FileManager = .default) -> URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("skills", isDirectory: true)
            .appendingPathComponent("tahoepaste", isDirectory: true)
            .appendingPathComponent("SKILL.md")
    }

    @discardableResult
    static func install(fileManager: FileManager = .default) throws -> URL {
        guard let sourceURL = Bundle.main.url(forResource: "SKILL", withExtension: "md") else {
            throw InstallError.skillResourceMissing
        }

        let destinationURL = skillDestinationURL(fileManager: fileManager)
        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }
}
