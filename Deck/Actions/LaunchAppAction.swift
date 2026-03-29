import AppKit
import Foundation

struct LaunchAppAction: Action {
    let id: UUID
    var title: String?
    var bundleIdentifier: String
    var appName: String

    init(id: UUID = UUID(), title: String? = nil, bundleIdentifier: String, appName: String) {
        self.id = id
        self.title = title
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
    }

    var name: String {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }

        return appName.isEmpty ? bundleIdentifier : appName
    }

    var iconSystemName: String {
        "app.badge"
    }

    func execute() async throws {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            throw ActionExecutionError.appNotFound(bundleIdentifier)
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}
