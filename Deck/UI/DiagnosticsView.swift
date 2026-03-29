import SwiftUI

struct DiagnosticsView: View {
    @ObservedObject var runtime: DeckRuntime

    var body: some View {
        NavigationStack {
            Group {
                if runtime.devices.isEmpty {
                    ContentUnavailableView(
                        "No Stream Deck Connected",
                        systemImage: "square.grid.3x3",
                        description: Text("Connect a Stream Deck Mini, MK.2, or XL to start receiving button events.")
                    )
                } else {
                    List(runtime.devices) { device in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(device.model.displayName)
                                    .font(.headline)
                                Spacer()
                                Text("\(device.grid.rows)×\(device.grid.columns)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text("Button image: \(device.buttonImageResolution.width)×\(device.buttonImageResolution.height)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if let event = runtime.latestEvent(for: device.id) {
                                Text("Last event: #\(event.index) \(event.pressed ? "pressed" : "released")")
                                    .font(.callout)
                            } else {
                                Text("Waiting for input…")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Deck HID Diagnostics")
        }
        .padding()
    }
}

#Preview {
    DiagnosticsView(runtime: DeckRuntime(previewDevices: [.previewMK2]))
}
