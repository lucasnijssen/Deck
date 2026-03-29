import Foundation

struct ShellScriptAction: Action {
    let id: UUID
    var title: String?
    var script: String

    init(id: UUID = UUID(), title: String? = nil, script: String) {
        self.id = id
        self.title = title
        self.script = script
    }

    var name: String {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }

        let firstLine = script.split(separator: "\n").first.map(String.init) ?? "Shell Script"
        return firstLine.isEmpty ? "Shell Script" : firstLine
    }

    var iconSystemName: String {
        "terminal"
    }

    func execute() async throws {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", script]

            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                throw ActionExecutionError.shellCommandFailed(process.terminationStatus)
            }
        }.value
    }
}
