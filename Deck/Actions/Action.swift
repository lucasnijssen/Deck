import Foundation

protocol Action: Codable, Identifiable, Sendable {
    var name: String { get }
    var iconSystemName: String { get }
    func execute() async throws
}

struct PreviousPageAction: Action {
    let id: UUID
    var title: String?

    init(id: UUID = UUID(), title: String? = nil) {
        self.id = id
        self.title = title
    }

    var name: String {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedTitle.isEmpty ? "Previous Page" : trimmedTitle
    }
    var iconSystemName: String { "arrow.left" }

    func execute() async throws {}
}

struct NextPageAction: Action {
    let id: UUID
    var title: String?

    init(id: UUID = UUID(), title: String? = nil) {
        self.id = id
        self.title = title
    }

    var name: String {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedTitle.isEmpty ? "Next Page" : trimmedTitle
    }
    var iconSystemName: String { "arrow.right" }

    func execute() async throws {}
}

struct GoToPageAction: Action {
    let id: UUID
    var title: String?
    var targetPageID: UUID?

    init(id: UUID = UUID(), title: String? = nil, targetPageID: UUID? = nil) {
        self.id = id
        self.title = title
        self.targetPageID = targetPageID
    }

    var name: String {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedTitle.isEmpty ? "Go to Page" : trimmedTitle
    }
    var iconSystemName: String { "number.square" }

    func execute() async throws {}
}

struct PageIndicatorAction: Action {
    let id: UUID
    var title: String?

    init(id: UUID = UUID(), title: String? = nil) {
        self.id = id
        self.title = title
    }

    var name: String {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedTitle.isEmpty ? "Page Indicator" : trimmedTitle
    }
    var iconSystemName: String { "number.square.fill" }

    func execute() async throws {}
}

enum ActionExecutionError: LocalizedError {
    case appNotFound(String)
    case invalidKeystroke(String)
    case invalidURL(String)
    case shellCommandFailed(Int32)
    case mediaCommandFailed(String)

    var errorDescription: String? {
        switch self {
        case .appNotFound(let bundleIdentifier):
            "Could not find app with bundle identifier \(bundleIdentifier)."
        case .invalidKeystroke(let key):
            "Unsupported keystroke key: \(key)."
        case .invalidURL(let value):
            "Invalid URL: \(value)."
        case .shellCommandFailed(let code):
            "Shell command exited with status \(code)."
        case .mediaCommandFailed(let command):
            "Media command failed: \(command)."
        }
    }
}

enum DeckAction: Action {
    case launchApp(LaunchAppAction)
    case keystroke(KeystrokeAction)
    case shellScript(ShellScriptAction)
    case openURL(OpenURLAction)
    case media(MediaAction)
    case time(TimeAction)
    case previousPage(PreviousPageAction)
    case nextPage(NextPageAction)
    case goToPage(GoToPageAction)
    case pageIndicator(PageIndicatorAction)

    var id: UUID {
        switch self {
        case .launchApp(let action):
            action.id
        case .keystroke(let action):
            action.id
        case .shellScript(let action):
            action.id
        case .openURL(let action):
            action.id
        case .media(let action):
            action.id
        case .time(let action):
            action.id
        case .previousPage(let action):
            action.id
        case .nextPage(let action):
            action.id
        case .goToPage(let action):
            action.id
        case .pageIndicator(let action):
            action.id
        }
    }

    var name: String {
        switch self {
        case .launchApp(let action):
            action.name
        case .keystroke(let action):
            action.name
        case .shellScript(let action):
            action.name
        case .openURL(let action):
            action.name
        case .media(let action):
            action.name
        case .time(let action):
            action.name
        case .previousPage(let action):
            action.name
        case .nextPage(let action):
            action.name
        case .goToPage(let action):
            action.name
        case .pageIndicator(let action):
            action.name
        }
    }

    var iconSystemName: String {
        switch self {
        case .launchApp(let action):
            action.iconSystemName
        case .keystroke(let action):
            action.iconSystemName
        case .shellScript(let action):
            action.iconSystemName
        case .openURL(let action):
            action.iconSystemName
        case .media(let action):
            action.iconSystemName
        case .time(let action):
            action.iconSystemName
        case .previousPage(let action):
            action.iconSystemName
        case .nextPage(let action):
            action.iconSystemName
        case .goToPage(let action):
            action.iconSystemName
        case .pageIndicator(let action):
            action.iconSystemName
        }
    }

    var kindTitle: String {
        switch self {
        case .launchApp:
            "Launch App"
        case .keystroke:
            "Keystroke"
        case .shellScript:
            "Shell Script"
        case .openURL:
            "Open URL"
        case .media:
            "Media"
        case .time:
            "Time"
        case .previousPage:
            "Previous Page"
        case .nextPage:
            "Next Page"
        case .goToPage:
            "Go to Page"
        case .pageIndicator:
            "Page Indicator"
        }
    }

    var title: String? {
        switch self {
        case .launchApp(let action):
            action.title
        case .keystroke(let action):
            action.title
        case .shellScript(let action):
            action.title
        case .openURL(let action):
            action.title
        case .media(let action):
            action.title
        case .time(let action):
            action.title
        case .previousPage(let action):
            action.title
        case .nextPage(let action):
            action.title
        case .goToPage(let action):
            action.title
        case .pageIndicator(let action):
            action.title
        }
    }

    var suggestedTitle: String {
        switch self {
        case .launchApp(let action):
            let label = action.appName.isEmpty ? action.bundleIdentifier : action.appName
            return label.isEmpty ? "Launch App" : label
        case .keystroke(let action):
            let normalizedKey = action.key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let prefix = action.modifiers.labels.joined(separator: "+")
            let title = prefix.isEmpty ? normalizedKey : "\(prefix)+\(normalizedKey)"
            return title.isEmpty ? "Keystroke" : title
        case .shellScript(let action):
            let firstLine = action.script.split(separator: "\n").first.map(String.init) ?? ""
            return firstLine.isEmpty ? "Shell Script" : firstLine
        case .openURL(let action):
            return action.urlString.isEmpty ? "Open URL" : action.urlString
        case .media(let action):
            return action.command.title
        case .time:
            return ""
        case .previousPage:
            return ""
        case .nextPage:
            return ""
        case .goToPage:
            return "Page"
        case .pageIndicator:
            return ""
        }
    }

    var configuredOrSuggestedTitle: String {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedTitle.isEmpty ? suggestedTitle : trimmedTitle
    }

    var buttonTitle: String {
        switch self {
        case .previousPage, .nextPage:
            return title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        default:
            return configuredOrSuggestedTitle
        }
    }

    var buttonBackgroundStyle: StreamDeckButtonBackgroundStyle {
        switch self {
        case .time, .previousPage, .nextPage, .goToPage, .pageIndicator:
            .black
        default:
            .standard
        }
    }

    var isTimeAction: Bool {
        if case .time = self {
            return true
        }

        return false
    }

    var isPreviousPageAction: Bool {
        if case .previousPage = self {
            return true
        }

        return false
    }

    var isNextPageAction: Bool {
        if case .nextPage = self {
            return true
        }

        return false
    }

    var shortLabel: String {
        let trimmed = buttonTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ""
        }

        if trimmed.count <= 12 {
            return trimmed
        }

        return String(trimmed.prefix(12))
    }

    func execute() async throws {
        switch self {
        case .launchApp(let action):
            try await action.execute()
        case .keystroke(let action):
            try await action.execute()
        case .shellScript(let action):
            try await action.execute()
        case .openURL(let action):
            try await action.execute()
        case .media(let action):
            try await action.execute()
        case .time(let action):
            try await action.execute()
        case .previousPage(let action):
            try await action.execute()
        case .nextPage(let action):
            try await action.execute()
        case .goToPage(let action):
            try await action.execute()
        case .pageIndicator(let action):
            try await action.execute()
        }
    }
}
