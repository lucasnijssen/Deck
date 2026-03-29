import AppKit
import Foundation
import IOKit.hidsystem

struct MediaAction: Action {
    enum Command: String, CaseIterable, Codable, Identifiable, Sendable {
        case playPause
        case nextTrack
        case previousTrack

        var id: String { rawValue }

        var title: String {
            switch self {
            case .playPause:
                "Play/Pause"
            case .nextTrack:
                "Next Track"
            case .previousTrack:
                "Previous Track"
            }
        }
    }

    let id: UUID
    var title: String?
    var command: Command

    init(id: UUID = UUID(), title: String? = nil, command: Command) {
        self.id = id
        self.title = title
        self.command = command
    }

    var name: String {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }

        return command.title
    }

    var iconSystemName: String {
        switch command {
        case .playPause:
            "playpause.fill"
        case .nextTrack:
            "forward.fill"
        case .previousTrack:
            "backward.fill"
        }
    }

    func execute() async throws {
        try await Task.detached(priority: .userInitiated) {
            let keyCode: Int32

            switch command {
            case .playPause:
                keyCode = NX_KEYTYPE_PLAY
            case .nextTrack:
                keyCode = NX_KEYTYPE_NEXT
            case .previousTrack:
                keyCode = NX_KEYTYPE_PREVIOUS
            }

            guard postMediaKeyEvent(keyCode, state: 0xA), postMediaKeyEvent(keyCode, state: 0xB) else {
                throw ActionExecutionError.mediaCommandFailed(command.title)
            }
        }.value
    }

    private func postMediaKeyEvent(_ keyCode: Int32, state: Int32) -> Bool {
        guard
            let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: 0xA00),
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: Int((keyCode << 16) | (state << 8)),
                data2: -1
            ),
            let cgEvent = event.cgEvent
        else {
            return false
        }

        cgEvent.post(tap: .cghidEventTap)
        return true
    }
}
