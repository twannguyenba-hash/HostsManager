import SwiftUI

// MARK: - Preset Model

struct PresetItem: Identifiable {
    let id = UUID()
    let name: String
    let hostname: String
    let ip: String
    let icon: String
    let category: String
}

let presetItems: [PresetItem] = [
    PresetItem(name: "Facebook", hostname: "facebook.com", ip: "0.0.0.0", icon: "hand.raised.fill", category: "Chặn"),
    PresetItem(name: "Instagram", hostname: "instagram.com", ip: "0.0.0.0", icon: "hand.raised.fill", category: "Chặn"),
    PresetItem(name: "X (Twitter)", hostname: "x.com", ip: "0.0.0.0", icon: "hand.raised.fill", category: "Chặn"),
    PresetItem(name: "TikTok", hostname: "tiktok.com", ip: "0.0.0.0", icon: "hand.raised.fill", category: "Chặn"),
    PresetItem(name: "YouTube", hostname: "youtube.com", ip: "0.0.0.0", icon: "hand.raised.fill", category: "Chặn"),
    PresetItem(name: "Reddit", hostname: "reddit.com", ip: "0.0.0.0", icon: "hand.raised.fill", category: "Chặn"),
    PresetItem(name: "myapp.local", hostname: "myapp.local", ip: "127.0.0.1", icon: "hammer.fill", category: "Dev"),
    PresetItem(name: "api.local", hostname: "api.local", ip: "127.0.0.1", icon: "hammer.fill", category: "Dev"),
]

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject var hostsManager: HostsFileManager
    @State private var selectedFilter: SidebarFilter = .all
    @State private var searchText = ""
    @State private var showAddSheet = false
    @State private var showImportSheet = false
    @State private var editingEntry: HostEntry?
    @State private var deleteTarget: HostEntry?
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedFilter: $selectedFilter, hostsManager: hostsManager)
        } detail: {
            ZStack {
                if selectedFilter == .presets {
                    PresetsView(hostsManager: hostsManager)
                } else {
                    entriesListView
                }

                // Toast overlay
                if let toast = hostsManager.toast {
                    VStack {
                        Spacer()
                        ToastView(toast: toast)
                            .padding(.bottom, 16)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .animation(.spring(response: 0.4), value: hostsManager.toast)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Tìm kiếm hostname, IP...")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Thêm entry mới")

                Menu {
                    Button {
                        showImportSheet = true
                    } label: {
                        Label("Import từ text", systemImage: "square.and.arrow.down")
                    }
                    Button {
                        hostsManager.exportToClipboard()
                    } label: {
                        Label("Export vào clipboard", systemImage: "doc.on.clipboard")
                    }
                    Divider()
                    Button {
                        hostsManager.createBackup()
                    } label: {
                        Label("Tạo backup", systemImage: "externaldrive.badge.plus")
                    }
                    Button {
                        hostsManager.loadHostsFile()
                    } label: {
                        Label("Tải lại từ file", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }

                Button {
                    hostsManager.applyChanges()
                } label: {
                    if hostsManager.isApplying {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Áp dụng")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(hostsManager.hasUnsavedChanges ? .blue : .gray)
                .disabled(!hostsManager.hasUnsavedChanges || hostsManager.isApplying)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            EntryFormSheet(hostsManager: hostsManager, mode: .add)
        }
        .sheet(item: $editingEntry) { entry in
            EntryFormSheet(hostsManager: hostsManager, mode: .edit(entry))
        }
        .sheet(isPresented: $showImportSheet) {
            ImportSheet(hostsManager: hostsManager)
        }
        .alert("Xác nhận xóa", isPresented: $showDeleteConfirm, presenting: deleteTarget) { entry in
            Button("Xóa", role: .destructive) {
                hostsManager.deleteEntry(id: entry.id)
            }
            Button("Hủy", role: .cancel) {}
        } message: { entry in
            Text("Bạn có chắc muốn xóa entry \"\(entry.hostname)\"?")
        }
    }

    private var entriesListView: some View {
        let filtered = hostsManager.filteredEntries(filter: selectedFilter, searchText: searchText)

        return Group {
            if filtered.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Không có entry nào")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(filtered) {
                    TableColumn("") { entry in
                        Toggle("", isOn: Binding(
                            get: { entry.isEnabled },
                            set: { _ in hostsManager.toggleEntry(id: entry.id) }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }
                    .width(50)

                    TableColumn("IP") { entry in
                        Text(entry.ip)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(entry.ip == "0.0.0.0" ? .red : .green)
                            .opacity(entry.isEnabled ? 1.0 : 0.5)
                    }
                    .width(min: 100, ideal: 140)

                    TableColumn("Hostname") { entry in
                        Text(entry.hostname)
                            .font(.system(.body, design: .monospaced))
                            .opacity(entry.isEnabled ? 1.0 : 0.5)
                    }
                    .width(min: 150, ideal: 250)

                    TableColumn("Comment") { entry in
                        Text(entry.comment)
                            .foregroundColor(.secondary)
                            .opacity(entry.isEnabled ? 1.0 : 0.5)
                    }
                    .width(min: 80, ideal: 150)

                    TableColumn("") { entry in
                        HStack(spacing: 4) {
                            Button {
                                editingEntry = entry
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.borderless)

                            Button {
                                deleteTarget = entry
                                showDeleteConfirm = true
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .width(60)
                }
                .modifier(AlternatingRowsModifier())
            }
        }
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @Binding var selectedFilter: SidebarFilter
    @ObservedObject var hostsManager: HostsFileManager

    var body: some View {
        List(selection: $selectedFilter) {
            Section("Bộ lọc") {
                ForEach(SidebarFilter.allCases.filter { $0 != .presets }) { filter in
                    Label {
                        HStack {
                            Text(filter.rawValue)
                            Spacer()
                            Text("\(hostsManager.entryCount(for: filter))")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    } icon: {
                        Image(systemName: filter.icon)
                    }
                    .tag(filter)
                }
            }

            Section {
                Label {
                    Text(SidebarFilter.presets.rawValue)
                } icon: {
                    Image(systemName: SidebarFilter.presets.icon)
                }
                .tag(SidebarFilter.presets)
            }

            if hostsManager.hasUnsavedChanges {
                Section {
                    Label {
                        Text("Có thay đổi chưa lưu")
                            .foregroundColor(.orange)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 220)
    }
}

// MARK: - Presets View

struct PresetsView: View {
    @ObservedObject var hostsManager: HostsFileManager

    let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Thêm nhanh")
                    .font(.title2.bold())
                    .padding(.horizontal)

                let categories = Dictionary(grouping: presetItems) { $0.category }

                ForEach(Array(categories.keys.sorted()), id: \.self) { category in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(category)
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(categories[category] ?? []) { preset in
                                PresetCard(preset: preset, hostsManager: hostsManager)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }
}

struct PresetCard: View {
    let preset: PresetItem
    @ObservedObject var hostsManager: HostsFileManager

    var exists: Bool {
        hostsManager.hostnameExists(preset.hostname)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: preset.icon)
                    .font(.title3)
                    .foregroundColor(preset.ip == "0.0.0.0" ? .red : .blue)
                Spacer()
                if exists {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }

            Text(preset.name)
                .font(.headline)

            Text(preset.hostname)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(preset.ip)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)

            Button {
                hostsManager.addEntry(ip: preset.ip, hostname: preset.hostname, comment: "Added by HostsManager")
            } label: {
                Text(exists ? "Đã thêm" : "Thêm")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(exists ? .gray : (preset.ip == "0.0.0.0" ? .red : .blue))
            .disabled(exists)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Entry Form

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
    @State private var errorMessage = ""

    var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var title: String {
        isEditing ? "Sửa entry" : "Thêm entry mới"
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.title3.bold())

            VStack(alignment: .leading, spacing: 8) {
                Text("IP Address")
                    .font(.headline)
                TextField("Ví dụ: 127.0.0.1", text: $ip)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                HStack(spacing: 8) {
                    QuickIPButton(label: "127.0.0.1", ip: $ip)
                    QuickIPButton(label: "0.0.0.0", ip: $ip)
                    QuickIPButton(label: "::1", ip: $ip)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Hostname")
                    .font(.headline)
                TextField("Ví dụ: example.com", text: $hostname)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Ghi chú (tuỳ chọn)")
                    .font(.headline)
                TextField("Ghi chú...", text: $comment)
                    .textFieldStyle(.roundedBorder)
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
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
        }
        .padding(24)
        .frame(width: 400)
        .onAppear {
            if case .edit(let entry) = mode {
                ip = entry.ip
                hostname = entry.hostname
                comment = entry.comment
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

        if case .add = mode {
            if hostsManager.hostnameExists(trimmedHostname) {
                errorMessage = "Hostname \"\(trimmedHostname)\" đã tồn tại"
                return
            }
            hostsManager.addEntry(ip: trimmedIP, hostname: trimmedHostname, comment: comment.trimmingCharacters(in: .whitespaces))
        } else if case .edit(let entry) = mode {
            hostsManager.updateEntry(id: entry.id, ip: trimmedIP, hostname: trimmedHostname, comment: comment.trimmingCharacters(in: .whitespaces))
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

// MARK: - Import Sheet

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
                .foregroundColor(.secondary)

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

// MARK: - Toast View

struct ToastView: View {
    let toast: ToastMessage

    var backgroundColor: Color {
        switch toast.type {
        case .success: return .green
        case .error: return .red
        case .info: return .blue
        }
    }

    var icon: String {
        switch toast.type {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(toast.message)
                .font(.callout)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(backgroundColor.opacity(0.9))
        .cornerRadius(8)
        .shadow(radius: 4)
    }
}

struct AlternatingRowsModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.alternatingRowBackgrounds()
        } else {
            content
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(HostsFileManager())
}
