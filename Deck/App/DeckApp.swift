import SwiftUI

@main
struct DeckApp: App {
    static let settingsWindowID = "deck-settings"
    static let configuratorSettingsWindowID = "deck-configurator-settings"

    @StateObject private var runtime = DeckRuntime()

    var body: some Scene {
        MenuBarExtra("Deck", systemImage: "square.grid.3x3.fill") {
            MenuBarView(runtime: runtime)
        }

        Window("Deck Settings", id: Self.settingsWindowID) {
            SettingsView(runtime: runtime)
        }
        .defaultSize(width: 960, height: 720)
        .windowResizability(.contentMinSize)

        Window("Configurator Settings", id: Self.configuratorSettingsWindowID) {
            ConfiguratorSettingsView(runtime: runtime)
                .frame(minWidth: 420, minHeight: 280)
        }
        .defaultSize(width: 460, height: 320)
        .windowResizability(.contentSize)
    }
}
