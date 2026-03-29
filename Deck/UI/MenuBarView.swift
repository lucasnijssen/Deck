import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var runtime: DeckRuntime
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            deviceStatusRow
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()
                .padding(.vertical, 4)

            MenuBarButton(icon: "slider.horizontal.3", title: "Open Configurator") {
                openWindow(id: DeckApp.settingsWindowID)
            }

            Divider()
                .padding(.vertical, 4)

            MenuBarButton(icon: "power", title: "Quit Deck", isDestructive: true) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.vertical, 4)
        .frame(width: 280)
    }

    private var deviceStatusRow: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(runtime.activeDevice != nil
                        ? Color.green.opacity(0.15)
                        : Color(nsColor: .secondaryLabelColor).opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: "rectangle.grid.3x2")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(runtime.activeDevice != nil ? Color.green : Color(nsColor: .secondaryLabelColor))
            }

            VStack(alignment: .leading, spacing: 1) {
                if let device = runtime.activeDevice {
                    Text(device.model.displayName)
                        .font(.subheadline.weight(.semibold))
                    Text("\(device.grid.rows)×\(device.grid.columns) buttons · Connected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No Stream Deck")
                        .font(.subheadline.weight(.semibold))
                    Text("Connect a device to get started")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct MenuBarButton: View {
    let icon: String
    let title: String
    var isDestructive: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 16)
                Text(title)
                    .font(.subheadline)
                Spacer()
            }
            .foregroundStyle(isDestructive ? Color.red : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered
                        ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.12)
                        : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .padding(.horizontal, 4)
    }
}
