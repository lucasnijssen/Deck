import Foundation

struct DeckPage: Codable, Identifiable, Sendable {
    let id: UUID
    var assignments: [Int: DeckAction]

    init(id: UUID = UUID(), assignments: [Int: DeckAction] = [:]) {
        self.id = id
        self.assignments = assignments
    }
}

struct DeckLayout: Codable, Sendable {
    var pages: [DeckPage]
    var selectedPageIndex: Int
    var brightness: Int

    init(pages: [DeckPage] = [DeckPage()], selectedPageIndex: Int = 0, brightness: Int = 100) {
        self.pages = pages.isEmpty ? [DeckPage()] : pages
        self.selectedPageIndex = min(max(0, selectedPageIndex), self.pages.count - 1)
        self.brightness = brightness
    }

    var pageCount: Int {
        pages.count
    }

    var currentPage: DeckPage {
        get {
            pages[selectedPageIndex]
        }
        set {
            pages[selectedPageIndex] = newValue
        }
    }

    var currentAssignments: [Int: DeckAction] {
        get {
            currentPage.assignments
        }
        set {
            var page = currentPage
            page.assignments = newValue
            currentPage = page
        }
    }

    private enum CodingKeys: String, CodingKey {
        case pages
        case selectedPageIndex
        case assignments
        case brightness
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let decodedPages = try container.decodeIfPresent([DeckPage].self, forKey: .pages), !decodedPages.isEmpty {
            pages = decodedPages
            selectedPageIndex = try container.decodeIfPresent(Int.self, forKey: .selectedPageIndex) ?? 0
        } else {
            let legacyAssignments = try container.decodeIfPresent([Int: DeckAction].self, forKey: .assignments) ?? [:]
            pages = [DeckPage(assignments: legacyAssignments)]
            selectedPageIndex = 0
        }

        selectedPageIndex = min(max(0, selectedPageIndex), pages.count - 1)
        brightness = try container.decodeIfPresent(Int.self, forKey: .brightness) ?? 100
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pages, forKey: .pages)
        try container.encode(selectedPageIndex, forKey: .selectedPageIndex)
        try container.encode(brightness, forKey: .brightness)
    }
}

actor DeckLayoutStore {
    private let fileManager = FileManager.default
    private let fileURL: URL

    init() {
        let appSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = appSupportDirectory.appendingPathComponent("Deck", isDirectory: true)
        fileURL = directory.appendingPathComponent("layout.json", isDirectory: false)
    }

    func load() throws -> DeckLayout {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return DeckLayout()
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(DeckLayout.self, from: data)
    }

    func save(_ layout: DeckLayout) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(layout)
        try data.write(to: fileURL, options: [.atomic])
    }

    func path() -> String {
        fileURL.path
    }
}
