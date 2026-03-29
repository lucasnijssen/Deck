import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class DeckRuntime: ObservableObject {
    struct ButtonDisplay: Sendable {
        let systemName: String?
        let appIconBundleIdentifier: String?
        let appIconStyle: StreamDeckButtonAppIconStyle
        let label: String
        let secondaryLabel: String
        let backgroundStyle: StreamDeckButtonBackgroundStyle
    }

    @Published private(set) var devices: [StreamDeckDeviceSnapshot]
    @Published private var latestEvents: [String: ButtonEvent]
    @Published private(set) var layout = DeckLayout()
    @Published var previewModel: StreamDeckModel = .mk2
    @Published private(set) var lastExecutionError: String?

    private let manager: StreamDeckManager?
    private let imageRenderer: ButtonImageRenderer
    private let layoutStore: DeckLayoutStore
    private(set) var layoutPath: String?

    init(previewDevices: [StreamDeckDeviceSnapshot] = []) {
        devices = previewDevices
        latestEvents = [:]
        imageRenderer = ButtonImageRenderer()
        layoutStore = DeckLayoutStore()
        layoutPath = nil

        if previewDevices.isEmpty {
            let manager = StreamDeckManager()
            self.manager = manager

            manager.onDeviceConnected = { [weak self] snapshot in
                Task { @MainActor in
                    self?.handleConnectedDevice(snapshot)
                }
            }

            manager.onDeviceDisconnected = { [weak self] deviceID in
                Task { @MainActor in
                    self?.handleDisconnectedDevice(deviceID)
                }
            }

            manager.onButtonEvent = { [weak self] deviceID, event in
                print("[HID] \(deviceID) button \(event.index) \(event.pressed ? "pressed" : "released")")

                Task { @MainActor in
                    await self?.handleButtonEvent(deviceID: deviceID, event: event)
                }
            }

            manager.start()
        } else {
            manager = nil
        }

        Task {
            await restoreLayout()
        }
    }

    var activeDevice: StreamDeckDeviceSnapshot? {
        devices.first
    }

    var editorModel: StreamDeckModel {
        activeDevice?.model ?? previewModel
    }

    var brightnessValue: Double {
        Double(layout.brightness)
    }

    var currentPageIndex: Int {
        layout.selectedPageIndex
    }

    var pageCount: Int {
        layout.pageCount
    }

    var pageIDs: [UUID] {
        layout.pages.map(\.id)
    }

    var pageOptions: [ActionPageOption] {
        layout.pages.enumerated().map { index, page in
            ActionPageOption(id: page.id, title: "Page \(index + 1)")
        }
    }

    var currentAssignments: [Int: DeckAction] {
        layout.currentAssignments
    }

    var supportsBrightness: Bool {
        editorModel.supportsBrightness
    }

    func latestEvent(for deviceID: String) -> ButtonEvent? {
        latestEvents[deviceID]
    }

    func setBrightness(_ brightness: Double) {
        let clampedBrightness = max(0, min(100, Int(brightness.rounded())))
        guard layout.brightness != clampedBrightness else {
            return
        }

        layout.brightness = clampedBrightness
        persistLayout()
        Task {
            await applyBrightnessToConnectedDecks()
        }
    }

    func assignAction(_ action: DeckAction, to index: Int) {
        var assignments = layout.currentAssignments
        assignments[index] = action
        layout.currentAssignments = assignments
        persistLayout()
        Task {
            await rerenderConnectedDecks()
        }
    }

    func removeAction(at index: Int) {
        var assignments = layout.currentAssignments
        assignments.removeValue(forKey: index)
        layout.currentAssignments = assignments
        persistLayout()
        Task {
            await rerenderConnectedDecks()
        }
    }

    func moveAction(from sourceIndex: Int, to targetIndex: Int) {
        guard sourceIndex != targetIndex else {
            return
        }

        var assignments = layout.currentAssignments
        guard let sourceAction = assignments[sourceIndex] else {
            return
        }

        let targetAction = assignments[targetIndex]
        assignments[targetIndex] = sourceAction

        if let targetAction {
            assignments[sourceIndex] = targetAction
        } else {
            assignments.removeValue(forKey: sourceIndex)
        }

        layout.currentAssignments = assignments
        persistLayout()
        Task {
            await rerenderConnectedDecks()
        }
    }

    func selectPage(_ index: Int) {
        guard layout.pages.indices.contains(index), layout.selectedPageIndex != index else {
            return
        }

        layout.selectedPageIndex = index
        persistLayout()
        Task {
            await rerenderConnectedDecks()
        }
    }

    func addPage() {
        layout.pages.append(DeckPage())
        ensureDefaultPageActions(for: editorModel)
        layout.selectedPageIndex = layout.pages.count - 1
        persistLayout()
        Task {
            await rerenderConnectedDecks()
        }
    }

    func deleteCurrentPage() {
        guard layout.pages.count > 1 else {
            return
        }

        layout.pages.remove(at: layout.selectedPageIndex)
        layout.selectedPageIndex = min(layout.selectedPageIndex, layout.pages.count - 1)
        persistLayout()
        Task {
            await rerenderConnectedDecks()
        }
    }

    func deletePage(id: UUID) {
        guard
            layout.pages.count > 1,
            let pageIndex = layout.pages.firstIndex(where: { $0.id == id })
        else {
            return
        }

        let selectedPageID = layout.pages[layout.selectedPageIndex].id
        layout.pages.remove(at: pageIndex)

        if let updatedSelectedIndex = layout.pages.firstIndex(where: { $0.id == selectedPageID }) {
            layout.selectedPageIndex = updatedSelectedIndex
        } else {
            layout.selectedPageIndex = min(pageIndex, layout.pages.count - 1)
        }

        sanitizePageActionsAfterPageDeletion(deletedPageID: id)

        persistLayout()
        Task {
            await rerenderConnectedDecks()
        }
    }

    func movePage(id sourceID: UUID, before targetID: UUID) {
        guard
            sourceID != targetID,
            let sourceIndex = layout.pages.firstIndex(where: { $0.id == sourceID }),
            let targetIndex = layout.pages.firstIndex(where: { $0.id == targetID })
        else {
            return
        }

        let selectedPageID = layout.pages[layout.selectedPageIndex].id
        let movingPage = layout.pages.remove(at: sourceIndex)

        guard let updatedTargetIndex = layout.pages.firstIndex(where: { $0.id == targetID }) else {
            layout.pages.insert(movingPage, at: min(targetIndex, layout.pages.count))
            return
        }

        layout.pages.insert(movingPage, at: updatedTargetIndex)

        if let updatedSelectedIndex = layout.pages.firstIndex(where: { $0.id == selectedPageID }) {
            layout.selectedPageIndex = updatedSelectedIndex
        }

        persistLayout()
        Task {
            await rerenderConnectedDecks()
        }
    }

    func movePage(id sourceID: UUID, to targetIndex: Int) {
        guard
            let sourceIndex = layout.pages.firstIndex(where: { $0.id == sourceID })
        else {
            return
        }

        let clampedTargetIndex = min(max(targetIndex, 0), layout.pages.count - 1)
        guard sourceIndex != clampedTargetIndex else {
            return
        }

        let selectedPageID = layout.pages[layout.selectedPageIndex].id
        let movingPage = layout.pages.remove(at: sourceIndex)
        layout.pages.insert(movingPage, at: clampedTargetIndex)

        if let updatedSelectedIndex = layout.pages.firstIndex(where: { $0.id == selectedPageID }) {
            layout.selectedPageIndex = updatedSelectedIndex
        }

        persistLayout()
        Task {
            await rerenderConnectedDecks()
        }
    }

    private func handleButtonEvent(deviceID: String, event: ButtonEvent) async {
        latestEvents[deviceID] = event

        guard devices.contains(where: { $0.id == deviceID }) else {
            return
        }

        await renderButtonState(for: deviceID, event: event)

        if !event.pressed {
            await executeAction(for: event.index)
        }
    }

    private func handleConnectedDevice(_ snapshot: StreamDeckDeviceSnapshot) {
        print("[HID] Connected \(snapshot.model.displayName) (\(snapshot.id))")
        devices.removeAll { $0.id == snapshot.id }
        devices.append(snapshot)
        devices.sort { $0.model.displayName < $1.model.displayName }

        Task {
            await applyBrightness(to: snapshot)
            await renderInitialImages(for: snapshot)
        }
    }

    private func handleDisconnectedDevice(_ deviceID: String) {
        print("[HID] Disconnected \(deviceID)")
        devices.removeAll { $0.id == deviceID }
        latestEvents.removeValue(forKey: deviceID)
    }

    private func restoreLayout() async {
        do {
            layout = try await layoutStore.load()
            layoutPath = await layoutStore.path()
            ensureDefaultPageActions(for: editorModel)
            await rerenderConnectedDecks()
        } catch {
            print("[Layout] Failed to load layout: \(error)")
        }
    }

    private func persistLayout() {
        let currentLayout = layout
        Task {
            do {
                try await layoutStore.save(currentLayout)
                let path = await layoutStore.path()
                await MainActor.run {
                    self.layoutPath = path
                }
            } catch {
                print("[Layout] Failed to save layout: \(error)")
            }
        }
    }

    private func renderInitialImages(for snapshot: StreamDeckDeviceSnapshot) async {
        guard let manager else {
            return
        }

        for index in 0..<snapshot.model.buttonCount {
            do {
                let imageData = try imageData(for: snapshot.model, index: index, isPressed: false)
                try await manager.sendButtonImage(imageData, to: index, on: snapshot.id)
            } catch {
                print("[HID] Failed to render initial image for \(snapshot.id) button \(index): \(error)")
            }
        }
    }

    private func renderButtonState(for deviceID: String, event: ButtonEvent) async {
        guard
            let manager,
            let snapshot = devices.first(where: { $0.id == deviceID })
        else {
            return
        }

        do {
            let imageData = try imageData(for: snapshot.model, index: event.index, isPressed: event.pressed)
            try await manager.sendButtonImage(imageData, to: event.index, on: deviceID)
        } catch {
            print("[HID] Failed to render state image for \(deviceID) button \(event.index): \(error)")
        }
    }

    private func executeAction(for index: Int) async {
        guard let action = layout.currentAssignments[index] else {
            lastExecutionError = nil
            return
        }

        do {
            switch action {
            case .previousPage:
                await goToRelativePage(offset: -1)
            case .nextPage:
                await goToRelativePage(offset: 1)
            case .goToPage(let action):
                await goToPage(id: action.targetPageID)
            case .pageIndicator:
                lastExecutionError = nil
            default:
                try await action.execute()
                lastExecutionError = nil
            }
            lastExecutionError = nil
        } catch {
            lastExecutionError = error.localizedDescription
            print("[Action] Failed to execute button \(index): \(error)")
        }
    }

    private func rerenderConnectedDecks() async {
        for device in devices {
            await renderInitialImages(for: device)
        }
    }

    private func applyBrightnessToConnectedDecks() async {
        for device in devices {
            await applyBrightness(to: device)
        }
    }

    private func applyBrightness(to snapshot: StreamDeckDeviceSnapshot) async {
        guard snapshot.model.supportsBrightness, let manager else {
            return
        }

        do {
            try await manager.setBrightness(layout.brightness, on: snapshot.id)
        } catch {
            print("[HID] Failed to set brightness for \(snapshot.id): \(error)")
        }
    }

    private func imageData(for model: StreamDeckModel, index: Int, isPressed: Bool) throws -> Data {
        let buttonDisplay = buttonDisplay(for: index)

        if buttonDisplay.systemName != nil || buttonDisplay.appIconBundleIdentifier != nil || !buttonDisplay.label.isEmpty {
            return try imageRenderer.renderButton(
                systemName: buttonDisplay.systemName,
                appIconBundleIdentifier: buttonDisplay.appIconBundleIdentifier,
                appIconStyle: buttonDisplay.appIconStyle,
                label: buttonDisplay.label,
                secondaryLabel: buttonDisplay.secondaryLabel,
                backgroundStyle: buttonDisplay.backgroundStyle,
                for: model,
                isPressed: isPressed
            )
        }

        return try imageRenderer.renderEmptyButton(for: model, isPressed: isPressed)
    }

    func buttonDisplay(for index: Int) -> ButtonDisplay {
        guard let action = layout.currentAssignments[index] else {
            return ButtonDisplay(systemName: nil, appIconBundleIdentifier: nil, appIconStyle: .inline, label: "", secondaryLabel: "", backgroundStyle: .empty)
        }

        switch action {
        case .previousPage:
            return ButtonDisplay(
                systemName: "arrow.left",
                appIconBundleIdentifier: nil,
                appIconStyle: .inline,
                label: action.shortLabel,
                secondaryLabel: "",
                backgroundStyle: .black
            )
        case .nextPage:
            return ButtonDisplay(
                systemName: "arrow.right",
                appIconBundleIdentifier: nil,
                appIconStyle: .inline,
                label: action.shortLabel,
                secondaryLabel: "",
                backgroundStyle: .black
            )
        case .goToPage(let action):
            let label = DeckAction.goToPage(action).shortLabel.isEmpty
                ? goToPageLabel(for: action)
                : DeckAction.goToPage(action).shortLabel
            return ButtonDisplay(systemName: "number.square", appIconBundleIdentifier: nil, appIconStyle: .inline, label: label, secondaryLabel: "", backgroundStyle: .black)
        case .pageIndicator:
            let indicatorTitle = action.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return ButtonDisplay(
                systemName: nil,
                appIconBundleIdentifier: nil,
                appIconStyle: .inline,
                label: "\(layout.selectedPageIndex + 1)",
                secondaryLabel: indicatorTitle,
                backgroundStyle: .black
            )
        case .launchApp(let action):
            return ButtonDisplay(
                systemName: nil,
                appIconBundleIdentifier: action.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines),
                appIconStyle: .fullKey,
                label: "",
                secondaryLabel: "",
                backgroundStyle: .black
            )
        default:
            return ButtonDisplay(
                systemName: action.iconSystemName,
                appIconBundleIdentifier: nil,
                appIconStyle: .inline,
                label: action.shortLabel,
                secondaryLabel: "",
                backgroundStyle: action.buttonBackgroundStyle
            )
        }
    }

    private func goToRelativePage(offset: Int) async {
        guard layout.pageCount > 1 else {
            return
        }

        let targetIndex = min(max(layout.selectedPageIndex + offset, 0), layout.pageCount - 1)
        guard targetIndex != layout.selectedPageIndex else {
            return
        }

        layout.selectedPageIndex = targetIndex
        persistLayout()
        await rerenderConnectedDecks()
    }

    private func goToPage(id targetPageID: UUID?) async {
        guard
            let targetPageID,
            let targetIndex = layout.pages.firstIndex(where: { $0.id == targetPageID }),
            targetIndex != layout.selectedPageIndex
        else {
            return
        }

        layout.selectedPageIndex = targetIndex
        persistLayout()
        await rerenderConnectedDecks()
    }

    private func goToPageLabel(for action: GoToPageAction) -> String {
        guard
            let targetPageID = action.targetPageID,
            let targetIndex = layout.pages.firstIndex(where: { $0.id == targetPageID })
        else {
            return "Page"
        }

        return "\(targetIndex + 1)"
    }

    private func ensureDefaultPageActions(for model: StreamDeckModel) {
        guard layout.pageCount > 1 else {
            return
        }

        for pageIndex in layout.pages.indices {
            var assignments = layout.pages[pageIndex].assignments

            if pageIndex > 0, !assignments.values.contains(where: \.isPreviousPageAction) {
                if let insertionIndex = preferredPageActionIndex(
                    preferredIndex: model.buttonCount - model.grid.columns,
                    assignments: assignments,
                    model: model
                ) {
                    assignments[insertionIndex] = .previousPage(PreviousPageAction())
                }
            }

            if pageIndex < layout.pageCount - 1, !assignments.values.contains(where: \.isNextPageAction) {
                if let insertionIndex = preferredPageActionIndex(
                    preferredIndex: model.buttonCount - 1,
                    assignments: assignments,
                    model: model
                ) {
                    assignments[insertionIndex] = .nextPage(NextPageAction())
                }
            }

            layout.pages[pageIndex].assignments = assignments
        }
    }

    private func preferredPageActionIndex(
        preferredIndex: Int,
        assignments: [Int: DeckAction],
        model: StreamDeckModel
    ) -> Int? {
        if assignments[preferredIndex] == nil {
            return preferredIndex
        }

        return (0..<model.buttonCount).first { assignments[$0] == nil }
    }

    private func sanitizePageActionsAfterPageDeletion(deletedPageID: UUID) {
        for pageIndex in layout.pages.indices {
            var assignments = layout.pages[pageIndex].assignments
            assignments = assignments.filter { _, action in
                if case .goToPage(let goToPageAction) = action {
                    return goToPageAction.targetPageID != deletedPageID
                }

                return true
            }
            layout.pages[pageIndex].assignments = assignments
        }
    }
}
