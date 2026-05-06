import SwiftUI

struct ImportSheet: View {
    @ObservedObject var hostsManager: HostsFileManager
    @Environment(\.dismiss) private var dismiss
    @State private var importText = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Import Entries")
                .font(.title3.bold())

            Text("Paste nội dung file hosts vào đây. Chỉ các entry chưa tồn tại mới được thêm.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $importText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 200)
                .border(Color.secondary.opacity(0.3))

            HStack {
                Button("Hủy") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Import") {
                    hostsManager.importEntries(from: importText)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 500, height: 380)
    }
}
