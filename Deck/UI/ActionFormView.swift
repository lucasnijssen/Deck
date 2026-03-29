import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum ActionKind: String, CaseIterable, Identifiable {
    case launchApp
    case keystroke
    case shellScript
    case openURL
    case media
    case previousPage
    case nextPage
    case goToPage
    case pageIndicator

    var id: String { rawValue }

    var title: String {
        switch self {
        case .launchApp:
            "Launch App"
        case .keystroke:
            "Keystroke"
        case .shellScript:
            "Shell Script"
        case .openURL:
            "Open URL"
        case .media:
            "Media"
        case .previousPage:
            "Previous Page"
        case .nextPage:
            "Next Page"
        case .goToPage:
            "Go to Page"
        case .pageIndicator:
            "Page Indicator"
        }
    }

    var iconSystemName: String {
        switch self {
        case .launchApp:
            "app.badge"
        case .keystroke:
            "keyboard"
        case .shellScript:
            "terminal"
        case .openURL:
            "link"
        case .media:
            "playpause.fill"
        case .previousPage:
            "arrow.left"
        case .nextPage:
            "arrow.right"
        case .goToPage:
            "number.square"
        case .pageIndicator:
            "number.square.fill"
        }
    }

    var category: ActionLibraryCategory {
        switch self {
        case .launchApp, .openURL, .previousPage, .nextPage, .goToPage, .pageIndicator:
            .navigation
        case .keystroke, .shellScript:
            .automation
        case .media:
            .media
        }
    }

    var detail: String {
        switch self {
        case .launchApp:
            "Open any installed Mac app."
        case .keystroke:
            "Send a keyboard shortcut."
        case .shellScript:
            "Run a zsh command or script."
        case .openURL:
            "Open a website or deep link."
        case .media:
            "Control system media playback."
        case .previousPage:
            "Move to the previous page."
        case .nextPage:
            "Move to the next page."
        case .goToPage:
            "Jump to a specific page."
        case .pageIndicator:
            "Show the current page number."
        }
    }

    func makeDefaultAction() -> DeckAction {
        switch self {
        case .launchApp:
            .launchApp(
                LaunchAppAction(
                    title: nil,
                    bundleIdentifier: "",
                    appName: ""
                )
            )
        case .keystroke:
            .keystroke(
                KeystrokeAction(
                    title: "Cmd+A",
                    key: "A",
                    modifiers: KeyboardModifiers(command: true)
                )
            )
        case .shellScript:
            .shellScript(
                ShellScriptAction(
                    title: "Shell Script",
                    script: "echo Deck"
                )
            )
        case .openURL:
            .openURL(
                OpenURLAction(
                    title: "Open URL",
                    urlString: "https://example.com"
                )
            )
        case .media:
            .media(
                MediaAction(
                    title: "Play/Pause",
                    command: .playPause
                )
            )
        case .previousPage:
            .previousPage(PreviousPageAction(title: nil))
        case .nextPage:
            .nextPage(NextPageAction(title: nil))
        case .goToPage:
            .goToPage(GoToPageAction(title: "Page"))
        case .pageIndicator:
            .pageIndicator(PageIndicatorAction(title: nil))
        }
    }
}

enum ActionLibraryCategory: String, CaseIterable, Identifiable {
    case all
    case navigation
    case automation
    case media

    static let sidebarCases: [ActionLibraryCategory] = [
        .navigation,
        .automation,
        .media
    ]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            "All"
        case .navigation:
            "Navigation"
        case .automation:
            "Automation"
        case .media:
            "Media"
        }
    }

    var iconSystemName: String {
        switch self {
        case .all:
            "square.grid.2x2"
        case .navigation:
            "arrow.left.arrow.right.square"
        case .automation:
            "terminal"
        case .media:
            "speaker.wave.2"
        }
    }

    func includes(_ kind: ActionKind) -> Bool {
        self == .all || kind.category == self
    }
}

struct ActionPageOption: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
}

struct ActionDraft {
    var kind: ActionKind
    var title: String
    var bundleIdentifier: String
    var appName: String
    var key: String
    var modifiers: KeyboardModifiers
    var script: String
    var urlString: String
    var mediaCommand: MediaAction.Command
    var targetPageID: UUID?

    init(action: DeckAction?) {
        kind = .launchApp; title = ""
        bundleIdentifier = ""; appName = ""; key = ""
        modifiers = KeyboardModifiers(); script = ""
        urlString = ""; mediaCommand = .playPause; targetPageID = nil

        switch action {
        case .launchApp(let a):      kind = .launchApp;      title = a.title ?? ""; bundleIdentifier = a.bundleIdentifier; appName = a.appName
        case .keystroke(let a):      kind = .keystroke;      title = a.title ?? ""; key = a.key; modifiers = a.modifiers
        case .shellScript(let a):    kind = .shellScript;    title = a.title ?? ""; script = a.script
        case .openURL(let a):        kind = .openURL;        title = a.title ?? ""; urlString = a.urlString
        case .media(let a):          kind = .media;          title = a.title ?? ""; mediaCommand = a.command
        case .previousPage(let a):   kind = .previousPage;   title = a.title ?? ""
        case .nextPage(let a):       kind = .nextPage;       title = a.title ?? ""
        case .goToPage(let a):       kind = .goToPage;       title = a.title ?? ""; targetPageID = a.targetPageID
        case .pageIndicator(let a):  kind = .pageIndicator;  title = a.title ?? ""
        case .none: break
        }
    }

    func makeAction(existingID: UUID?) -> DeckAction? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let storedTitle = trimmedTitle.isEmpty ? nil : trimmedTitle

        switch kind {
        case .launchApp:
            guard !bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return .launchApp(
                LaunchAppAction(
                    id: existingID ?? UUID(),
                    title: storedTitle,
                    bundleIdentifier: bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines),
                    appName: appName.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
        case .keystroke:
            guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return .keystroke(
                KeystrokeAction(
                    id: existingID ?? UUID(),
                    title: storedTitle,
                    key: key.trimmingCharacters(in: .whitespacesAndNewlines),
                    modifiers: modifiers
                )
            )
        case .shellScript:
            guard !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return .shellScript(
                ShellScriptAction(
                    id: existingID ?? UUID(),
                    title: storedTitle,
                    script: script
                )
            )
        case .openURL:
            guard !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return .openURL(
                OpenURLAction(
                    id: existingID ?? UUID(),
                    title: storedTitle,
                    urlString: urlString.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
        case .media:
            return .media(
                MediaAction(
                    id: existingID ?? UUID(),
                    title: storedTitle,
                    command: mediaCommand
                )
            )
        case .previousPage:
            return .previousPage(
                PreviousPageAction(
                    id: existingID ?? UUID(),
                    title: storedTitle
                )
            )
        case .nextPage:
            return .nextPage(
                NextPageAction(
                    id: existingID ?? UUID(),
                    title: storedTitle
                )
            )
        case .goToPage:
            guard targetPageID != nil else { return nil }
            return .goToPage(
                GoToPageAction(
                    id: existingID ?? UUID(),
                    title: storedTitle,
                    targetPageID: targetPageID
                )
            )
        case .pageIndicator:
            return .pageIndicator(
                PageIndicatorAction(
                    id: existingID ?? UUID(),
                    title: storedTitle
                )
            )
        }
    }
}

extension ActionDraft {
    var autosaveFingerprint: String {
        [
            kind.rawValue,
            title,
            bundleIdentifier,
            appName,
            key,
            modifiers.command.description,
            modifiers.option.description,
            modifiers.control.description,
            modifiers.shift.description,
            script,
            urlString,
            mediaCommand.rawValue,
            targetPageID?.uuidString ?? ""
        ].joined(separator: "\u{1F}")
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var previewSystemName: String? {
        switch kind {
        case .launchApp:
            nil
        case .keystroke:
            "keyboard"
        case .shellScript:
            "terminal"
        case .openURL:
            "link"
        case .media:
            switch mediaCommand {
            case .playPause:
                "playpause.fill"
            case .nextTrack:
                "forward.fill"
            case .previousTrack:
                "backward.fill"
            }
        case .previousPage:
            "arrow.left"
        case .nextPage:
            "arrow.right"
        case .goToPage:
            "number.square"
        case .pageIndicator:
            nil
        }
    }

    var previewBackgroundStyle: StreamDeckButtonBackgroundStyle {
        switch kind {
        case .launchApp where previewAppIconBundleIdentifier != nil:
            .black
        case .previousPage, .nextPage, .goToPage, .pageIndicator:
            .black
        default:
            .standard
        }
    }

    var previewAppIconBundleIdentifier: String? {
        let trimmedBundleIdentifier = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedBundleIdentifier.isEmpty ? nil : trimmedBundleIdentifier
    }

    var previewAppIconStyle: StreamDeckButtonAppIconStyle {
        kind == .launchApp && previewAppIconBundleIdentifier != nil ? .fullKey : .inline
    }
}

struct ActionFormView: View {
    @Binding var draft: ActionDraft
    let pageOptions: [ActionPageOption]
    let currentPageNumber: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            previewSection
            displaySection
            configurationSection
        }
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        let bundle = Bundle(url: url)
        draft.bundleIdentifier = bundle?.bundleIdentifier ?? ""
        draft.appName = FileManager.default.displayName(atPath: url.path)
    }

    private var previewSection: some View {
        GroupBox {
            HStack(alignment: .top, spacing: 16) {
                StreamDeckButtonFaceView(
                    systemName: draft.previewSystemName,
                    appIconBundleIdentifier: draft.previewAppIconBundleIdentifier,
                    appIconStyle: draft.previewAppIconStyle,
                    label: previewLabel,
                    secondaryLabel: previewSecondaryLabel,
                    backgroundStyle: draft.previewBackgroundStyle,
                    isPressed: false,
                    style: .editor
                )
                .frame(width: 88, height: 88)

                VStack(alignment: .leading, spacing: 6) {
                    Label(draft.kind.title, systemImage: draft.kind.iconSystemName)
                        .font(.headline)

                    Text(previewSummaryText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let helperText = titleHelperText {
                        Text(helperText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var displaySection: some View {
        GroupBox("Display") {
            VStack(alignment: .leading, spacing: 10) {
                DeckTextField("Title", text: $draft.title, prompt: Text(titlePrompt))

                if let helperText = titleHelperText {
                    Text(helperText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var configurationSection: some View {
        switch draft.kind {
        case .launchApp:
            GroupBox("App") {
                VStack(alignment: .leading, spacing: 12) {
                    if !draft.appName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Selected App")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                                Text(draft.appName)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                            }
                            Spacer()
                            Button("Change…") { chooseApp() }
                                .buttonStyle(.borderless)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                    } else {
                        Button { chooseApp() } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "app.badge.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.accentColor)
                                Text("Choose App…")
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Text("Choose the app this key should open.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .keystroke:
            GroupBox("Keystroke") {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Key")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        DeckTextField("e.g. A, Return, Space", text: $draft.key)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Modifiers")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            ModifierChip(symbol: "⌘", label: "Cmd", isOn: $draft.modifiers.command)
                            ModifierChip(symbol: "⌥", label: "Opt", isOn: $draft.modifiers.option)
                            ModifierChip(symbol: "⌃", label: "Ctrl", isOn: $draft.modifiers.control)
                            ModifierChip(symbol: "⇧", label: "Shift", isOn: $draft.modifiers.shift)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .shellScript:
            GroupBox("Script") {
                TextEditor(text: $draft.script)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 180)
            }
        case .openURL:
            GroupBox("URL") {
                DeckTextField("https://example.com", text: $draft.urlString)
            }
        case .media:
            GroupBox("Media") {
                Picker("Command", selection: $draft.mediaCommand) {
                    ForEach(MediaAction.Command.allCases) { command in
                        Text(command.title).tag(command)
                    }
                }
            }
        case .previousPage:
            GroupBox("Behavior") {
                Text("Moves to the previous page when released.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .nextPage:
            GroupBox("Behavior") {
                Text("Moves to the next page when released.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .goToPage:
            GroupBox("Page") {
                Picker("Destination", selection: $draft.targetPageID) {
                    Text("Choose a page").tag(Optional<UUID>.none)
                    ForEach(pageOptions) { option in
                        Text(option.title).tag(Optional(option.id))
                    }
                }
            }
        case .pageIndicator:
            GroupBox("Behavior") {
                Text("Shows the current page number on the key.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var previewLabel: String? {
        if draft.kind != .pageIndicator && !draft.trimmedTitle.isEmpty {
            return draft.trimmedTitle
        }

        switch draft.kind {
        case .launchApp:
            let fallback = draft.appName.trimmingCharacters(in: .whitespacesAndNewlines)
            return fallback.isEmpty ? "Launch App" : fallback
        case .keystroke:
            let normalizedKey = draft.key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let prefix = draft.modifiers.labels.joined(separator: "+")
            let composed = prefix.isEmpty ? normalizedKey : "\(prefix)+\(normalizedKey)"
            return composed.isEmpty ? "Keystroke" : composed
        case .shellScript:
            let firstLine = draft.script.split(separator: "\n").first.map(String.init) ?? ""
            return firstLine.isEmpty ? "Shell Script" : firstLine
        case .openURL:
            let url = draft.urlString.trimmingCharacters(in: .whitespacesAndNewlines)
            return url.isEmpty ? "Open URL" : url
        case .media:
            return draft.mediaCommand.title
        case .previousPage, .nextPage:
            return nil
        case .goToPage:
            if let targetPageID = draft.targetPageID,
               let option = pageOptions.first(where: { $0.id == targetPageID }) {
                return option.title.replacingOccurrences(of: "Page ", with: "")
            }
            return "Page"
        case .pageIndicator:
            return "\(currentPageNumber)"
        }
    }

    private var previewSecondaryLabel: String? {
        switch draft.kind {
        case .pageIndicator:
            return draft.trimmedTitle.isEmpty ? nil : draft.trimmedTitle
        default:
            return nil
        }
    }

    private var titlePrompt: String {
        switch draft.kind {
        case .previousPage, .nextPage:
            return "Leave empty for icon only"
        case .pageIndicator:
            return "Optional small caption below the page number"
        default:
            return "Use default title"
        }
    }

    private var titleHelperText: String? {
        if !draft.trimmedTitle.isEmpty {
            return "Shown on the key as “\(draft.trimmedTitle)”."
        }

        switch draft.kind {
        case .previousPage, .nextPage:
            return "This key stays icon-only until you enter a title."
        case .pageIndicator:
            return draft.trimmedTitle.isEmpty
                ? "Leaving this empty shows only the live page number."
                : "This title appears as the small caption below the page number."
        default:
            if let previewLabel, !previewLabel.isEmpty {
                return "Leaving this empty uses “\(previewLabel)” from the action."
            }

            return nil
        }
    }

    private var previewSummaryText: String {
        switch draft.kind {
        case .launchApp:
            let appName = draft.appName.trimmingCharacters(in: .whitespacesAndNewlines)
            return appName.isEmpty ? "Choose an installed app to open." : appName
        case .keystroke:
            return "Send a keyboard shortcut when the key is released."
        case .shellScript:
            return "Run a zsh command or script."
        case .openURL:
            return "Open a website or deep link."
        case .media:
            return "Control the active media app."
        case .previousPage:
            return "Navigate to the previous page."
        case .nextPage:
            return "Navigate to the next page."
        case .goToPage:
            return "Jump directly to a selected page."
        case .pageIndicator:
            return "Display the current page number on the key."
        }
    }
}

// MARK: - Modifier Chip

private struct ModifierChip: View {
    let symbol: String
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 4) {
                Text(symbol)
                    .font(.system(size: 14, weight: .medium))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isOn ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
            )
            .foregroundStyle(isOn ? Color.white : Color.primary)
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(
                        isOn ? Color.clear : Color(nsColor: .separatorColor),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Deck Text Field

private struct DeckTextField: View {
    let placeholder: String
    @Binding var text: String
    var prompt: Text? = nil

    @FocusState private var isFocused: Bool

    init(_ placeholder: String, text: Binding<String>, prompt: Text? = nil) {
        self.placeholder = placeholder
        self._text = text
        self.prompt = prompt
    }

    var body: some View {
        TextField(placeholder, text: $text, prompt: prompt)
            .textFieldStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(
                        isFocused ? Color.accentColor.opacity(0.7) : Color(nsColor: .separatorColor),
                        lineWidth: isFocused ? 1.5 : 0.5
                    )
            )
            .focused($isFocused)
            .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}
