import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var runtime: DeckRuntime
    @Environment(\.openWindow) private var openWindow
    @State private var selectedButtonIndex: Int?
    @State private var draft = ActionDraft(action: nil)
    @State private var validationMessage: String?
    @State private var autosaveTask: Task<Void, Never>?

    private var gridView: GridView {
        GridView(
            model: runtime.editorModel,
            assignments: runtime.currentAssignments,
            latestEvent: runtime.latestEvent(for: runtime.activeDevice?.id ?? ""),
            selectedIndex: selectedButtonIndex,
            buttonDisplay: { runtime.buttonDisplay(for: $0) },
            onSelect: selectButton(_:),
            onDropActionKind: { index, kind in handleDroppedAction(kind, on: index) },
            onMoveAction: { sourceIndex, targetIndex in moveActionOnCanvas(from: sourceIndex, to: targetIndex) },
            onDeleteAction: { index in deleteActionFromCanvas(at: index) }
        )
    }

    var body: some View {
        NavigationStack { mainContent }
            .alert("Invalid Action", isPresented: Binding(
                get: { validationMessage != nil },
                set: { if !$0 { validationMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationMessage ?? "")
            }
            .onChange(of: runtime.previewModel) { _, _ in validateSelection() }
            .onChange(of: runtime.devices.map(\.id)) { _, _ in validateSelection() }
            .onChange(of: runtime.currentPageIndex) { _, _ in validateSelection() }
            .onChange(of: runtime.pageCount) { _, _ in validateSelection() }
            .onChange(of: draft.autosaveFingerprint) { _, _ in scheduleAutosave() }
            .onDisappear { autosaveTask?.cancel() }
    }

    private var mainContent: some View {
        HSplitView {
            editorPane
            SidebarPanel()
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 360, maxHeight: .infinity)
        }
        .navigationTitle("DECK")
        .background(WindowConfigurator(minSize: minimumWindowSize))
    }

    private var gridContentSize: CGSize {
        let model = runtime.editorModel
        let cols = CGFloat(model.grid.columns)
        let rows = CGFloat(model.grid.rows)
        let buttonSize: CGFloat = model == .xl ? 84 : 92
        let spacing: CGFloat = 12
        return CGSize(
            width:  cols * buttonSize + (cols - 1) * spacing,
            height: rows * buttonSize + (rows - 1) * spacing
        )
    }

    private var canvasMinWidth: CGFloat  { gridContentSize.width + 96 }
    private var canvasMinHeight: CGFloat { gridContentSize.height + 208 }

    private var minimumWindowSize: NSSize {
        NSSize(width: canvasMinWidth + 281, height: canvasMinHeight + 290)
    }

    private var editorPane: some View {
        VSplitView {
            canvasPane
            inspectorDrawer
                .frame(minHeight: 260, idealHeight: 330, maxHeight: 440)
        }
        .frame(minWidth: canvasMinWidth, maxWidth: .infinity, minHeight: canvasMinHeight + 261, maxHeight: .infinity, alignment: .top)
    }

    private var canvasPane: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            centeredGridSection
            pageControls

            if let errorMessage = runtime.lastExecutionError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(errorMessage)
                }
                .font(.footnote)
                .foregroundStyle(.red)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(minWidth: canvasMinWidth, maxWidth: .infinity, minHeight: canvasMinHeight, maxHeight: .infinity, alignment: .top)
    }

    private var centeredGridSection: some View {
        gridView
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(runtime.activeDevice?.model.displayName ?? "Preview Layout")
                    .font(.title3.weight(.semibold))
                Text(runtime.activeDevice?.name ?? "No hardware connected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                openWindow(id: DeckApp.configuratorSettingsWindowID)
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color(nsColor: .controlBackgroundColor)))
            }
            .buttonStyle(.plain)
            .help("Open configurator settings")
        }
    }

    // MARK: - Page Controls

    private var pageControls: some View {
        HStack {
            Spacer(minLength: 0)
            PageSwitcherControl(
                pageIDs: runtime.pageIDs,
                pageCount: runtime.pageCount,
                selectedPageIndex: runtime.currentPageIndex,
                onSelectPage: { runtime.selectPage($0) },
                onAddPage: {
                    runtime.addPage()
                    validateSelection()
                },
                onDeletePage: { pageID in
                    runtime.deletePage(id: pageID)
                    validateSelection()
                },
                onMovePage: { sourceID, targetIndex in
                    runtime.movePage(id: sourceID, to: targetIndex)
                    validateSelection()
                }
            )
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Inspector Drawer

    @ViewBuilder
    private var inspectorDrawer: some View {
        VStack(spacing: 0) {
            inspectorHeader
            Divider()
            ScrollView {
                inspectorBody
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var inspectorHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                if let idx = selectedButtonIndex {
                    Text("Button \(idx + 1)")
                        .font(.headline)
                    Text(inspectorSubtitle(for: idx))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Inspector")
                        .font(.headline)
                    Text("Select a button to configure")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if let idx = selectedButtonIndex,
               runtime.currentAssignments[idx] != nil {
                Button(role: .destructive) {
                    clearSelection()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.red)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.red.opacity(0.09)))
                }
                .buttonStyle(.plain)
                .help("Delete action")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var inspectorBody: some View {
        if let selectedButtonIndex {
            if runtime.currentAssignments[selectedButtonIndex] != nil {
                ActionFormView(
                    draft: $draft,
                    pageOptions: runtime.pageOptions,
                    currentPageNumber: runtime.currentPageIndex + 1
                )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "square.dashed")
                            .font(.system(size: 15))
                            .foregroundStyle(.tertiary)
                        Text("No Action Assigned")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    Text("Drag an action from the sidebar onto this button to assign it.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            }
        } else {
            VStack(spacing: 10) {
                Image(systemName: "cursorarrow.click")
                    .font(.system(size: 28))
                    .foregroundStyle(.tertiary)
                Text("No Button Selected")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("Click a button on the grid above to configure its action.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 200)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
        }
    }

    // MARK: - Logic

    private func handleDroppedAction(_ kind: ActionKind, on index: Int) {
        let action = kind.makeDefaultAction()
        runtime.assignAction(action, to: index)
        selectButton(index)
    }

    private func moveActionOnCanvas(from sourceIndex: Int, to targetIndex: Int) {
        guard sourceIndex != targetIndex else { return }
        let selectedIndexBeforeMove = selectedButtonIndex
        runtime.moveAction(from: sourceIndex, to: targetIndex)
        if selectedIndexBeforeMove == sourceIndex {
            selectedButtonIndex = targetIndex
        } else if selectedIndexBeforeMove == targetIndex {
            selectedButtonIndex = sourceIndex
        }
        validateSelection()
    }

    private func deleteActionFromCanvas(at index: Int) {
        runtime.removeAction(at: index)
        if selectedButtonIndex == index {
            draft = ActionDraft(action: nil)
        }
        validateSelection()
    }

    private func selectButton(_ index: Int) {
        selectedButtonIndex = index
        draft = ActionDraft(action: runtime.currentAssignments[index])
    }

    private func autosaveSelectionIfPossible() {
        guard let selectedButtonIndex else { return }
        let currentAction = runtime.currentAssignments[selectedButtonIndex]
        guard let action = draft.makeAction(existingID: currentAction?.id) else { return }
        if ActionDraft(action: currentAction).autosaveFingerprint == ActionDraft(action: action).autosaveFingerprint {
            return
        }
        runtime.assignAction(action, to: selectedButtonIndex)
        draft = ActionDraft(action: action)
    }

    private func clearSelection() {
        guard let selectedButtonIndex else { return }
        autosaveTask?.cancel()
        runtime.removeAction(at: selectedButtonIndex)
        draft = ActionDraft(action: nil)
    }

    private func validateSelection() {
        guard let selectedButtonIndex else { return }
        guard selectedButtonIndex < runtime.editorModel.buttonCount else {
            self.selectedButtonIndex = nil
            draft = ActionDraft(action: nil)
            return
        }
        draft = ActionDraft(action: runtime.currentAssignments[selectedButtonIndex])
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        guard selectedButtonIndex != nil else { return }
        autosaveTask = Task {
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            await MainActor.run { autosaveSelectionIfPossible() }
        }
    }

    private func inspectorSubtitle(for index: Int) -> String {
        if let action = runtime.currentAssignments[index] {
            return action.kindTitle
        }
        return "No action assigned"
    }
}

// MARK: - Sidebar Panel

private struct SidebarPanel: View {
    @State private var expandedCategories = Set(ActionLibraryCategory.sidebarCases)

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Actions")
                        .font(.title3.weight(.semibold))
                    Text("Drag onto a button to assign")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(ActionLibraryCategory.sidebarCases) { category in
                        ActionCategorySection(
                            category: category,
                            isExpanded: binding(for: category)
                        )
                    }
                }
                .padding(.top, 6)
                .padding(.bottom, 16)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func binding(for category: ActionLibraryCategory) -> Binding<Bool> {
        Binding(
            get: { expandedCategories.contains(category) },
            set: { isExpanded in
                if isExpanded { expandedCategories.insert(category) }
                else { expandedCategories.remove(category) }
            }
        )
    }
}

private struct ActionCategorySection: View {
    let category: ActionLibraryCategory
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: category.iconSystemName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 14)
                    Text(category.title.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.8)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 2) {
                    ForEach(ActionKind.allCases.filter { category.includes($0) }) { kind in
                        ActionLibraryRow(kind: kind)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }
        }
    }
}

private struct ActionLibraryRow: View {
    let kind: ActionKind
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(kind.badgeColor.gradient)
                    .frame(width: 34, height: 34)
                Image(systemName: kind.iconSystemName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(kind.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text(kind.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovered ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.07) : .clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { isHovered = $0 }
        .draggable("kind:\(kind.rawValue)") {
            HStack(spacing: 8) {
                Image(systemName: kind.iconSystemName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(kind.badgeColor, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                Text(kind.title)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

// MARK: - Page Switcher

private struct PageSwitcherControl: View {
    private let chipWidth: CGFloat = 44
    private let chipHeight: CGFloat = 24
    private let chipSpacing: CGFloat = 4

    let pageIDs: [UUID]
    let pageCount: Int
    let selectedPageIndex: Int
    let onSelectPage: (Int) -> Void
    let onAddPage: () -> Void
    let onDeletePage: (UUID) -> Void
    let onMovePage: (UUID, Int) -> Void

    @State private var draggedPageID: UUID?
    @State private var dragOriginIndex: Int?
    @State private var dragTranslation: CGFloat = 0

    var body: some View {
        HStack(spacing: chipSpacing) {
            ForEach(Array(pageIDs.enumerated()), id: \.element) { index, pageID in
                pageChip(index: index, pageID: pageID)
                    .buttonStyle(PageSwitcherButtonStyle(isSelected: selectedPageIndex == index))
                    .help("Page \(index + 1)")
                    .contextMenu {
                        Button("Delete Page", role: .destructive) { onDeletePage(pageID) }
                            .disabled(pageCount <= 1)
                    }
                    .offset(x: draggedPageID == pageID ? dragTranslation : 0)
                    .zIndex(draggedPageID == pageID ? 1 : 0)
                    .highPriorityGesture(reorderGesture(for: pageID))
            }

            Button { onAddPage() } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: chipWidth, height: chipHeight)
            }
            .buttonStyle(PageSwitcherButtonStyle(isSelected: false))
            .help("Add page")
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        )
    }

    private func pageChip(index: Int, pageID: UUID) -> some View {
        Button { onSelectPage(index) } label: {
            Text("\(index + 1)")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: chipWidth, height: chipHeight)
        }
    }

    private func reorderGesture(for pageID: UUID) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard let currentIndex = pageIDs.firstIndex(of: pageID) else { return }
                if draggedPageID != pageID {
                    draggedPageID = pageID
                    dragOriginIndex = currentIndex
                }
                dragTranslation = value.translation.width
            }
            .onEnded { _ in
                if let dragOriginIndex, let draggedPageID {
                    let targetIndex = targetIndex(for: dragTranslation, originIndex: dragOriginIndex)
                    onMovePage(draggedPageID, targetIndex)
                }
                draggedPageID = nil
                dragOriginIndex = nil
                dragTranslation = 0
            }
    }

    private func targetIndex(for translation: CGFloat, originIndex: Int) -> Int {
        let stride = chipWidth + chipSpacing
        let rawIndex = CGFloat(originIndex) + (translation / stride)
        return min(max(Int(rawIndex.rounded()), 0), pageIDs.count - 1)
    }
}

private struct PageSwitcherButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor(isPressed: configuration.isPressed))
            .background(backgroundColor(isPressed: configuration.isPressed), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isSelected { return isPressed ? Color.white.opacity(0.88) : Color.white }
        return isPressed ? Color.white.opacity(0.08) : .clear
    }

    private func foregroundColor(isPressed: Bool) -> Color {
        if isSelected { return .black.opacity(isPressed ? 0.78 : 0.9) }
        return isPressed ? Color.white.opacity(0.82) : Color.white.opacity(0.65)
    }
}

// MARK: - Configurator Settings

struct ConfiguratorSettingsView: View {
    @ObservedObject var runtime: DeckRuntime

    var body: some View {
        Form {
            if runtime.activeDevice == nil {
                Picker("Preview Model", selection: Binding(
                    get: { runtime.previewModel },
                    set: { runtime.previewModel = $0 }
                )) {
                    ForEach(StreamDeckModel.allCases) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                .pickerStyle(.menu)
            }

            LabeledContent("Brightness") {
                Text("\(Int(runtime.brightnessValue))%")
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: Binding(
                    get: { runtime.brightnessValue },
                    set: { runtime.setBrightness($0) }
                ),
                in: 0...100,
                step: 1
            )
            .disabled(!runtime.supportsBrightness)

            if !runtime.supportsBrightness {
                Text("Brightness is available for Stream Deck MK.2 and XL.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Configurator Settings")
        .background(WindowConfigurator(minSize: NSSize(width: 420, height: 280)))
    }
}

// MARK: - Window Configurator

private struct WindowConfigurator: NSViewRepresentable {
    let minSize: NSSize

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configureWindow(for: view, coordinator: context.coordinator) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { configureWindow(for: nsView, coordinator: context.coordinator) }
    }

    private func configureWindow(for view: NSView, coordinator: Coordinator) {
        guard let window = view.window else { return }
        window.styleMask.insert(.resizable)
        window.minSize = minSize

        // Grow the window if it is currently smaller than the new minimum
        let current = window.frame.size
        let newWidth  = max(current.width,  minSize.width)
        let newHeight = max(current.height, minSize.height)
        if newWidth != current.width || newHeight != current.height {
            window.setContentSize(NSSize(width: newWidth, height: newHeight))
        }

        if coordinator.window == nil {
            window.delegate = coordinator
            coordinator.window = window
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    final class Coordinator: NSObject, NSWindowDelegate {
        weak var window: NSWindow?
        func windowWillClose(_ notification: Notification) {
            guard notification.object as? NSWindow === window else { return }
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

// MARK: - ActionKind Badge Colors

private extension ActionKind {
    var badgeColor: Color {
        switch self {
        case .launchApp:     .blue
        case .keystroke:     .purple
        case .shellScript:   .orange
        case .openURL:       .teal
        case .media:         Color(red: 0.88, green: 0.18, blue: 0.38)
        case .previousPage:  Color(nsColor: .systemGray)
        case .nextPage:      Color(nsColor: .systemGray)
        case .goToPage:      .indigo
        case .pageIndicator: .mint
        }
    }
}
