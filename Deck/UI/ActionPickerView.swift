import SwiftUI

struct ActionPickerView: View {
    let buttonIndex: Int
    let existingAction: DeckAction?
    let pageOptions: [ActionPageOption]
    let onSave: (DeckAction) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: ActionDraft
    @State private var validationMessage: String?

    init(
        buttonIndex: Int,
        existingAction: DeckAction?,
        pageOptions: [ActionPageOption] = [],
        onSave: @escaping (DeckAction) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.buttonIndex = buttonIndex
        self.existingAction = existingAction
        self.pageOptions = pageOptions
        self.onSave = onSave
        self.onDelete = onDelete
        _draft = State(initialValue: ActionDraft(action: existingAction))
    }

    var body: some View {
        VStack(spacing: 0) {
            ActionFormView(draft: $draft, pageOptions: pageOptions, currentPageNumber: 1)

            Divider()

            HStack {
                if existingAction != nil {
                    Button("Clear", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button("Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 460, minHeight: 420)
        .navigationTitle("Button \(buttonIndex + 1)")
        .alert("Invalid Action", isPresented: Binding(
            get: { validationMessage != nil },
            set: { if !$0 { validationMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationMessage ?? "")
        }
    }

    private func save() {
        guard let action = draft.makeAction(existingID: existingAction?.id) else {
            validationMessage = "Complete the required fields for this action type."
            return
        }

        onSave(action)
        dismiss()
    }
}
