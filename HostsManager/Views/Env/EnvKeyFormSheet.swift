import SwiftUI

enum EnvKeyFormMode: Identifiable {
    case add
    case edit(EnvEntry)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let e): return "edit-\(e.id.uuidString)"
        }
    }
}

struct EnvKeyFormSheet: View {
    let mode: EnvKeyFormMode
    let onSave: (String, String, String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var key: String = ""
    @State private var value: String = ""
    @State private var comment: String = ""
    @State private var errorMessage: String = ""

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var title: String {
        isEditing ? "Sửa key" : "Thêm key mới"
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.title3.bold())
                .padding(.top, 20)
                .padding(.bottom, 12)

            Form {
                Section {
                    TextField("KEY", text: $key, prompt: Text("VITE_API_URL"))
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                    TextField("Value", text: $value, prompt: Text("https://api.example.com"))
                        .font(.system(.body, design: .monospaced))
                    TextField("Ghi chú", text: $comment, prompt: Text("Tuỳ chọn"))
                }
            }
            .formStyle(.grouped)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.horizontal, 20)
            }

            HStack {
                Button("Hủy") { dismiss() }
                    .keyboardShortcut(.escape)
                Spacer()
                Button(isEditing ? "Cập nhật" : "Thêm") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(width: 440, height: 300)
        .onAppear { populate() }
    }

    private func populate() {
        if case .edit(let entry) = mode {
            key = entry.key
            value = entry.value
            comment = entry.comment
        }
    }

    private func save() {
        errorMessage = ""
        let trimmedKey = key.trimmingCharacters(in: .whitespaces)
        guard !trimmedKey.isEmpty else {
            errorMessage = "Key không được để trống"
            return
        }
        guard isValidKey(trimmedKey) else {
            errorMessage = "Key chỉ chứa A-Z, 0-9, và _ (không bắt đầu bằng số)"
            return
        }
        onSave(trimmedKey, value, comment.trimmingCharacters(in: .whitespaces))
        dismiss()
    }

    private func isValidKey(_ s: String) -> Bool {
        guard let first = s.first, first.isLetter || first == "_" else { return false }
        return s.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }
}
