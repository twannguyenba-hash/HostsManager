import SwiftUI

enum EntryFormMode: Identifiable {
    case add
    case edit(HostEntry)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let entry): return entry.id.uuidString
        }
    }
}

struct EntryFormSheet: View {
    @ObservedObject var hostsManager: HostsFileManager
    let mode: EntryFormMode
    @Environment(\.dismiss) private var dismiss

    @State private var ip = ""
    @State private var hostname = ""
    @State private var comment = ""
    @State private var selectedTag: String = ""
    @State private var errorMessage = ""

    var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var title: String {
        isEditing ? "Sửa entry" : "Thêm entry mới"
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.title3.bold())
                .padding(.top, 20)
                .padding(.bottom, 12)

            Form {
                Section {
                    TextField("IP Address", text: $ip, prompt: Text("Ví dụ: 127.0.0.1"))
                        .font(.system(.body, design: .monospaced))

                    HStack(spacing: 8) {
                        Text("Chọn nhanh")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        QuickIPButton(label: "127.0.0.1", ip: $ip)
                        QuickIPButton(label: "0.0.0.0", ip: $ip)
                        QuickIPButton(label: "::1", ip: $ip)
                    }

                    TextField("Hostname", text: $hostname, prompt: Text("Ví dụ: example.com"))
                        .font(.system(.body, design: .monospaced))

                    TextField("Ghi chú", text: $comment, prompt: Text("Tuỳ chọn"))
                }

                if !hostsManager.tags.isEmpty {
                    Section {
                        Picker("Tag", selection: $selectedTag) {
                            Text("Không có tag")
                                .frame(minWidth: 180, alignment: .leading)
                                .tag("")
                            ForEach(hostsManager.tags) { tag in
                                Text(tag.name)
                                    .frame(minWidth: 180, alignment: .leading)
                                    .tag(tag.name)
                            }
                        }
                    }
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
                Button("Hủy") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button(isEditing ? "Cập nhật" : "Thêm") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(width: 420, height: 360)
        .onAppear {
            if case .edit(let entry) = mode {
                ip = entry.ip
                hostname = entry.hostname
                comment = entry.comment
                selectedTag = entry.tag ?? ""
            }
        }
    }

    private func save() {
        errorMessage = ""

        guard !ip.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "IP không được để trống"
            return
        }
        guard !hostname.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Hostname không được để trống"
            return
        }

        let trimmedHostname = hostname.trimmingCharacters(in: .whitespaces)
        let trimmedIP = ip.trimmingCharacters(in: .whitespaces)
        let tagValue = selectedTag.isEmpty ? nil : selectedTag

        if case .add = mode {
            if hostsManager.hostnameExists(trimmedHostname) {
                errorMessage = "Hostname \"\(trimmedHostname)\" đã tồn tại"
                return
            }
            hostsManager.addEntry(
                ip: trimmedIP,
                hostname: trimmedHostname,
                comment: comment.trimmingCharacters(in: .whitespaces),
                tag: tagValue
            )
        } else if case .edit(let entry) = mode {
            hostsManager.updateEntry(
                id: entry.id,
                ip: trimmedIP,
                hostname: trimmedHostname,
                comment: comment.trimmingCharacters(in: .whitespaces),
                tag: tagValue
            )
        }

        dismiss()
    }
}

struct QuickIPButton: View {
    let label: String
    @Binding var ip: String

    var body: some View {
        Button(label) {
            ip = label
        }
        .buttonStyle(.bordered)
        .font(.system(.caption, design: .monospaced))
    }
}
