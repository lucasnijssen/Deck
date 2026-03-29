import SwiftUI

private enum GridDragPayload {
    static let actionPrefix = "action:"
    static let kindPrefix = "kind:"
}

struct GridView: View {
    let model: StreamDeckModel
    let assignments: [Int: DeckAction]
    let latestEvent: ButtonEvent?
    let selectedIndex: Int?
    let buttonDisplay: (Int) -> DeckRuntime.ButtonDisplay
    let onSelect: (Int) -> Void
    let onDropActionKind: (Int, ActionKind) -> Void
    let onMoveAction: (Int, Int) -> Void
    let onDeleteAction: (Int) -> Void

    private let buttonSpacing: CGFloat = 12

    private var buttonSize: CGFloat {
        switch model {
        case .mini, .mk2:
            92
        case .xl:
            84
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(buttonSize), spacing: buttonSpacing), count: model.grid.columns)
    }

    private var gridWidth: CGFloat {
        let columnCount = CGFloat(model.grid.columns)
        return (columnCount * buttonSize) + (CGFloat(model.grid.columns - 1) * buttonSpacing)
    }

    var contentWidth: CGFloat {
        gridWidth
    }

    var contentHeight: CGFloat {
        let rowCount = CGFloat(model.grid.rows)
        return (rowCount * buttonSize) + (CGFloat(model.grid.rows - 1) * buttonSpacing)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(0..<model.buttonCount, id: \.self) { index in
                GridButtonCell(
                    index: index,
                    size: buttonSize,
                    action: assignments[index],
                    buttonDisplay: buttonDisplay(index),
                    isPressed: latestEvent?.index == index ? latestEvent?.pressed == true : false,
                    isSelected: selectedIndex == index,
                    onSelect: onSelect,
                    onDropActionKind: onDropActionKind,
                    onMoveAction: onMoveAction
                    ,
                    onDeleteAction: onDeleteAction
                )
            }
        }
        .frame(width: gridWidth, alignment: .leading)
    }
}

private struct GridButtonCell: View {
    let index: Int
    let size: CGFloat
    let action: DeckAction?
    let buttonDisplay: DeckRuntime.ButtonDisplay
    let isPressed: Bool
    let isSelected: Bool
    let onSelect: (Int) -> Void
    let onDropActionKind: (Int, ActionKind) -> Void
    let onMoveAction: (Int, Int) -> Void
    let onDeleteAction: (Int) -> Void

    @State private var isDropTarget = false

    var body: some View {
        Button {
            onSelect(index)
        } label: {
            StreamDeckButtonFaceView(
                systemName: buttonDisplay.systemName,
                appIconBundleIdentifier: buttonDisplay.appIconBundleIdentifier,
                appIconStyle: buttonDisplay.appIconStyle,
                label: buttonDisplay.label.isEmpty ? nil : buttonDisplay.label,
                secondaryLabel: buttonDisplay.secondaryLabel.isEmpty ? nil : buttonDisplay.secondaryLabel,
                backgroundStyle: action == nil ? .empty : buttonDisplay.backgroundStyle,
                isPressed: isPressed,
                style: .editor
            )
            .frame(width: size, height: size)
            .overlay(alignment: .center) {
                RoundedRectangle(cornerRadius: StreamDeckButtonFaceView.cornerRadius, style: .continuous)
                    .strokeBorder(overlayColor, lineWidth: overlayColor == .clear ? 0 : 3)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Edit") {
                onSelect(index)
            }

            if action != nil {
                Button("Delete", role: .destructive) {
                    onDeleteAction(index)
                }
            }
        }
        .draggable(actionDragPayload) {
            StreamDeckButtonFaceView(
                systemName: buttonDisplay.systemName,
                appIconBundleIdentifier: buttonDisplay.appIconBundleIdentifier,
                appIconStyle: buttonDisplay.appIconStyle,
                label: buttonDisplay.label.isEmpty ? nil : buttonDisplay.label,
                secondaryLabel: buttonDisplay.secondaryLabel.isEmpty ? nil : buttonDisplay.secondaryLabel,
                backgroundStyle: action == nil ? .empty : buttonDisplay.backgroundStyle,
                isPressed: false,
                style: .editor
            )
            .frame(width: size, height: size)
        }
        .dropDestination(for: String.self) { items, _ in
            for item in items {
                if let sourceIndex = parseActionSourceIndex(from: item) {
                    onMoveAction(sourceIndex, index)
                    return true
                }

                if let kind = parseActionKind(from: item) {
                    onDropActionKind(index, kind)
                    return true
                }
            }

            return false
        } isTargeted: { isTargeted in
            isDropTarget = isTargeted
        }
    }

    private var actionDragPayload: String {
        "\(GridDragPayload.actionPrefix)\(index)"
    }

    private func parseActionSourceIndex(from payload: String) -> Int? {
        guard payload.hasPrefix(GridDragPayload.actionPrefix) else {
            return nil
        }

        return Int(payload.dropFirst(GridDragPayload.actionPrefix.count))
    }

    private func parseActionKind(from payload: String) -> ActionKind? {
        if payload.hasPrefix(GridDragPayload.kindPrefix) {
            return ActionKind(rawValue: String(payload.dropFirst(GridDragPayload.kindPrefix.count)))
        }

        return ActionKind(rawValue: payload)
    }

    private var overlayColor: Color {
        if isDropTarget {
            return .accentColor
        }

        if isSelected {
            return .secondary.opacity(0.45)
        }

        return .clear
    }
}
