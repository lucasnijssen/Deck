import Foundation

struct TimeAction: Action {
    enum Style: String, CaseIterable, Codable, Identifiable, Sendable {
        case digital
        case analog

        var id: String { rawValue }

        var title: String {
            switch self {
            case .digital:
                "Digital"
            case .analog:
                "Analog"
            }
        }
    }

    let id: UUID
    var title: String?
    var style: Style

    init(id: UUID = UUID(), title: String? = nil, style: Style = .digital) {
        self.id = id
        self.title = title
        self.style = style
    }

    var name: String {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedTitle.isEmpty ? "Time" : trimmedTitle
    }

    var iconSystemName: String { "clock" }

    func execute() async throws {}
}
