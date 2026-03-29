import AppKit
import Foundation

struct OpenURLAction: Action {
    let id: UUID
    var title: String?
    var urlString: String

    init(id: UUID = UUID(), title: String? = nil, urlString: String) {
        self.id = id
        self.title = title
        self.urlString = urlString
    }

    var name: String {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }

        return urlString
    }

    var iconSystemName: String {
        "link"
    }

    func execute() async throws {
        guard let url = URL(string: urlString), !urlString.isEmpty else {
            throw ActionExecutionError.invalidURL(urlString)
        }

        NSWorkspace.shared.open(url)
    }
}
