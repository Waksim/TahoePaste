import Foundation

/// Hand-rolled argv parser for the agent CLI (the project deliberately has
/// no SPM dependencies). Pure and synchronous so it is unit tested from the
/// app target.
enum AgentCommand: Equatable {
    case recent(limit: Int, includeSensitive: Bool)
    case search(query: String, kind: ClipboardKind?, tag: ClipboardTag?, sinceRaw: String?, limit: Int, includeSensitive: Bool)
    case get(id: UUID, full: Bool, includeSensitive: Bool)
    case image(id: UUID)
    case copy(id: UUID, includeSensitive: Bool)
    case add(text: String?)
    case delete(id: UUID)
    case help
    case version

    enum ParseError: LocalizedError, Equatable {
        case missingCommand
        case unknownCommand(String)
        case unknownOption(String)
        case missingValue(String)
        case invalidValue(option: String, value: String)
        case missingArgument(String)
        case unexpectedArgument(String)

        var errorDescription: String? {
            switch self {
            case .missingCommand:
                return "No command given. Run with --help for usage."
            case .unknownCommand(let command):
                return "Unknown command '\(command)'. Run with --help for usage."
            case .unknownOption(let option):
                return "Unknown option '\(option)'."
            case .missingValue(let option):
                return "Option '\(option)' requires a value."
            case .invalidValue(let option, let value):
                return "Invalid value '\(value)' for option '\(option)'."
            case .missingArgument(let name):
                return "Missing required argument <\(name)>."
            case .unexpectedArgument(let argument):
                return "Unexpected argument '\(argument)'."
            }
        }
    }

    static let usage = """
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
    """

    static func parse(_ arguments: [String]) throws -> AgentCommand {
        guard let command = arguments.first else {
            throw ParseError.missingCommand
        }

        var rest = Array(arguments.dropFirst())

        switch command {
        case "--help", "help", "-h":
            return .help
        case "--version", "version":
            return .version
        case "recent":
            let options = try Options(consuming: &rest, allowed: ["--limit", "--include-sensitive"])
            try rejectPositionals(rest)
            return .recent(limit: try options.limit(), includeSensitive: options.includeSensitive)
        case "search":
            let options = try Options(
                consuming: &rest,
                allowed: ["--limit", "--include-sensitive", "--kind", "--tag", "--since"]
            )
            guard let query = rest.first else {
                throw ParseError.missingArgument("query")
            }
            try rejectPositionals(Array(rest.dropFirst()))
            return .search(
                query: query,
                kind: try options.kind(),
                tag: try options.tag(),
                sinceRaw: options.values["--since"],
                limit: try options.limit(),
                includeSensitive: options.includeSensitive
            )
        case "get":
            let options = try Options(consuming: &rest, allowed: ["--full", "--include-sensitive"])
            let id = try requiredUUID(from: rest)
            return .get(id: id, full: options.full, includeSensitive: options.includeSensitive)
        case "image":
            let options = try Options(consuming: &rest, allowed: [])
            _ = options
            return .image(id: try requiredUUID(from: rest))
        case "copy":
            let options = try Options(consuming: &rest, allowed: ["--include-sensitive"])
            return .copy(id: try requiredUUID(from: rest), includeSensitive: options.includeSensitive)
        case "add":
            let options = try Options(consuming: &rest, allowed: [])
            _ = options
            try rejectPositionals(Array(rest.dropFirst()))
            return .add(text: rest.first)
        case "delete":
            let options = try Options(consuming: &rest, allowed: [])
            _ = options
            return .delete(id: try requiredUUID(from: rest))
        default:
            throw ParseError.unknownCommand(command)
        }
    }

    // MARK: - Helpers

    private static func requiredUUID(from positionals: [String]) throws -> UUID {
        guard let raw = positionals.first else {
            throw ParseError.missingArgument("uuid")
        }

        guard let id = UUID(uuidString: raw) else {
            throw ParseError.invalidValue(option: "uuid", value: raw)
        }

        try rejectPositionals(Array(positionals.dropFirst()))
        return id
    }

    private static func rejectPositionals(_ positionals: [String]) throws {
        if let extra = positionals.first {
            throw ParseError.unexpectedArgument(extra)
        }
    }

    private struct Options {
        private static let flagOptions: Set<String> = ["--include-sensitive", "--full"]

        var values: [String: String] = [:]
        var flags: Set<String> = []

        var includeSensitive: Bool { flags.contains("--include-sensitive") }
        var full: Bool { flags.contains("--full") }

        /// Extracts known options from the argument list, leaving positionals
        /// behind in their original order.
        init(consuming arguments: inout [String], allowed: Set<String>) throws {
            var positionals: [String] = []
            var index = 0

            while index < arguments.count {
                let argument = arguments[index]

                if argument.hasPrefix("--") {
                    guard allowed.contains(argument) else {
                        throw ParseError.unknownOption(argument)
                    }

                    if Self.flagOptions.contains(argument) {
                        flags.insert(argument)
                    } else {
                        guard index + 1 < arguments.count else {
                            throw ParseError.missingValue(argument)
                        }

                        index += 1
                        values[argument] = arguments[index]
                    }
                } else {
                    positionals.append(argument)
                }

                index += 1
            }

            arguments = positionals
        }

        func limit() throws -> Int {
            guard let raw = values["--limit"] else {
                return AgentQueryService.defaultLimit
            }

            guard let parsed = Int(raw), parsed >= 1 else {
                throw ParseError.invalidValue(option: "--limit", value: raw)
            }

            return min(parsed, AgentQueryService.maxLimit)
        }

        func kind() throws -> ClipboardKind? {
            guard let raw = values["--kind"] else {
                return nil
            }

            guard let kind = ClipboardKind(rawValue: raw.lowercased()) else {
                throw ParseError.invalidValue(option: "--kind", value: raw)
            }

            return kind
        }

        func tag() throws -> ClipboardTag? {
            guard let raw = values["--tag"] else {
                return nil
            }

            guard let tag = ClipboardTag.allCases.first(where: { $0.rawValue.lowercased() == raw.lowercased() }) else {
                throw ParseError.invalidValue(option: "--tag", value: raw)
            }

            return tag
        }
    }
}
