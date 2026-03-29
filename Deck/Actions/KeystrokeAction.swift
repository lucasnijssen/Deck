import Carbon.HIToolbox
import CoreGraphics
import Foundation

struct KeyboardModifiers: Codable, Hashable, Sendable {
    var command = false
    var option = false
    var control = false
    var shift = false

    var eventFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if command { flags.insert(.maskCommand) }
        if option { flags.insert(.maskAlternate) }
        if control { flags.insert(.maskControl) }
        if shift { flags.insert(.maskShift) }
        return flags
    }

    var labels: [String] {
        var parts: [String] = []
        if command { parts.append("Cmd") }
        if option { parts.append("Opt") }
        if control { parts.append("Ctrl") }
        if shift { parts.append("Shift") }
        return parts
    }
}

struct KeystrokeAction: Action {
    let id: UUID
    var title: String?
    var key: String
    var modifiers: KeyboardModifiers

    init(id: UUID = UUID(), title: String? = nil, key: String, modifiers: KeyboardModifiers = KeyboardModifiers()) {
        self.id = id
        self.title = title
        self.key = key
        self.modifiers = modifiers
    }

    var name: String {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }

        let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let prefix = modifiers.labels.joined(separator: "+")
        return prefix.isEmpty ? normalizedKey : "\(prefix)+\(normalizedKey)"
    }

    var iconSystemName: String {
        "keyboard"
    }

    func execute() async throws {
        let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let keyCode = KeyCodeMapper.keyCode(for: normalizedKey) else {
            throw ActionExecutionError.invalidKeystroke(key)
        }

        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw ActionExecutionError.invalidKeystroke(key)
        }

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyDown?.flags = modifiers.eventFlags
        keyUp?.flags = modifiers.eventFlags
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

private enum KeyCodeMapper {
    static func keyCode(for key: String) -> CGKeyCode? {
        switch key {
        case "a": CGKeyCode(kVK_ANSI_A)
        case "b": CGKeyCode(kVK_ANSI_B)
        case "c": CGKeyCode(kVK_ANSI_C)
        case "d": CGKeyCode(kVK_ANSI_D)
        case "e": CGKeyCode(kVK_ANSI_E)
        case "f": CGKeyCode(kVK_ANSI_F)
        case "g": CGKeyCode(kVK_ANSI_G)
        case "h": CGKeyCode(kVK_ANSI_H)
        case "i": CGKeyCode(kVK_ANSI_I)
        case "j": CGKeyCode(kVK_ANSI_J)
        case "k": CGKeyCode(kVK_ANSI_K)
        case "l": CGKeyCode(kVK_ANSI_L)
        case "m": CGKeyCode(kVK_ANSI_M)
        case "n": CGKeyCode(kVK_ANSI_N)
        case "o": CGKeyCode(kVK_ANSI_O)
        case "p": CGKeyCode(kVK_ANSI_P)
        case "q": CGKeyCode(kVK_ANSI_Q)
        case "r": CGKeyCode(kVK_ANSI_R)
        case "s": CGKeyCode(kVK_ANSI_S)
        case "t": CGKeyCode(kVK_ANSI_T)
        case "u": CGKeyCode(kVK_ANSI_U)
        case "v": CGKeyCode(kVK_ANSI_V)
        case "w": CGKeyCode(kVK_ANSI_W)
        case "x": CGKeyCode(kVK_ANSI_X)
        case "y": CGKeyCode(kVK_ANSI_Y)
        case "z": CGKeyCode(kVK_ANSI_Z)
        case "0": CGKeyCode(kVK_ANSI_0)
        case "1": CGKeyCode(kVK_ANSI_1)
        case "2": CGKeyCode(kVK_ANSI_2)
        case "3": CGKeyCode(kVK_ANSI_3)
        case "4": CGKeyCode(kVK_ANSI_4)
        case "5": CGKeyCode(kVK_ANSI_5)
        case "6": CGKeyCode(kVK_ANSI_6)
        case "7": CGKeyCode(kVK_ANSI_7)
        case "8": CGKeyCode(kVK_ANSI_8)
        case "9": CGKeyCode(kVK_ANSI_9)
        case "space": CGKeyCode(kVK_Space)
        case "return", "enter": CGKeyCode(kVK_Return)
        case "tab": CGKeyCode(kVK_Tab)
        case "escape", "esc": CGKeyCode(kVK_Escape)
        case "delete", "backspace": CGKeyCode(kVK_Delete)
        case "left": CGKeyCode(kVK_LeftArrow)
        case "right": CGKeyCode(kVK_RightArrow)
        case "up": CGKeyCode(kVK_UpArrow)
        case "down": CGKeyCode(kVK_DownArrow)
        case ".", "period": CGKeyCode(kVK_ANSI_Period)
        case ",", "comma": CGKeyCode(kVK_ANSI_Comma)
        case "/", "slash": CGKeyCode(kVK_ANSI_Slash)
        case "-", "minus": CGKeyCode(kVK_ANSI_Minus)
        case "=", "equal": CGKeyCode(kVK_ANSI_Equal)
        default: nil
        }
    }
}
