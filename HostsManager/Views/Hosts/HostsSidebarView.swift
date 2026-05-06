import SwiftUI

enum SidebarSelection: Hashable {
    case filter(SidebarFilter)
    case tag(String)
}

struct SidebarView: View {
    @Binding var selection: SidebarSelection?
    @ObservedObject var hostsManager: HostsFileManager

    @State private var showCreateTagAlert = false
    @State private var newTagName = ""
    @State private var showRenameTagAlert = false
    @State private var renameTagOldName = ""
    @State private var renameTagNewName = ""
    @State private var showDeleteTagConfirm = false
    @State private var deleteTagTarget = ""

    var body: some View {
        List(selection: $selection) {
            Section("Bộ lọc") {
                ForEach(SidebarFilter.allCases) { filter in
                    let count = hostsManager.entryCount(for: filter)
                    Label {
                        HStack {
                            Text(filter.rawValue)
                            Spacer()
                            Text("\(count)")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                                .modifier(NumericTransitionModifier())
                                .animation(.default, value: count)
                        }
                    } icon: {
                        Image(systemName: filter.icon)
                    }
                    .tag(SidebarSelection.filter(filter))
                }
            }

            Section("Tags") {
                ForEach(hostsManager.tags) { tag in
                    let tagCount = hostsManager.tagEntryCount(name: tag.name)
                    HStack {
                        Label {
                            HStack {
                                Text(tag.name)
                                Spacer()
                                Text("\(tagCount)")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                                    .modifier(NumericTransitionModifier())
                                    .animation(.default, value: tagCount)
                            }
                        } icon: {
                            Image(systemName: "tag.fill")
                                .foregroundStyle(.tint)
                        }

                        TagToggleButton(state: hostsManager.tagState(name: tag.name)) {
                            hostsManager.toggleTag(name: tag.name)
                        }
                    }
                    .tag(SidebarSelection.tag(tag.name))
                    .contextMenu {
                        Button {
                            renameTagOldName = tag.name
                            renameTagNewName = tag.name
                            showRenameTagAlert = true
                        } label: {
                            Label("Đổi tên", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            deleteTagTarget = tag.name
                            showDeleteTagConfirm = true
                        } label: {
                            Label("Xóa tag", systemImage: "trash")
                        }
                    }
                }

                Button {
                    newTagName = ""
                    showCreateTagAlert = true
                } label: {
                    Label("Tạo tag mới...", systemImage: "plus.circle")
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
            }

            if hostsManager.hasUnsavedChanges {
                Section {
                    Label {
                        Text("Có thay đổi chưa lưu")
                            .foregroundStyle(.orange)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .modifier(PulseEffectModifier(isActive: true))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .listStyle(.sidebar)
        .animation(.easeInOut(duration: 0.25), value: hostsManager.hasUnsavedChanges)
        .navigationSplitViewColumnWidth(min: 180, ideal: 240)
        .alert("Tạo tag mới", isPresented: $showCreateTagAlert) {
            TextField("Tên tag", text: $newTagName)
            Button("Tạo") {
                hostsManager.createTag(name: newTagName)
                newTagName = ""
            }
            Button("Hủy", role: .cancel) {
                newTagName = ""
            }
        }
        .alert("Đổi tên tag", isPresented: $showRenameTagAlert) {
            TextField("Tên mới", text: $renameTagNewName)
            Button("Đổi tên") {
                hostsManager.renameTag(oldName: renameTagOldName, newName: renameTagNewName)
                if case .tag(renameTagOldName) = selection {
                    selection = .tag(renameTagNewName)
                }
                renameTagOldName = ""
                renameTagNewName = ""
            }
            Button("Hủy", role: .cancel) {
                renameTagOldName = ""
                renameTagNewName = ""
            }
        }
        .alert("Xác nhận xóa tag", isPresented: $showDeleteTagConfirm) {
            Button("Xóa", role: .destructive) {
                if case .tag(deleteTagTarget) = selection {
                    selection = .filter(.all)
                }
                hostsManager.deleteTag(name: deleteTagTarget)
                deleteTagTarget = ""
            }
            Button("Hủy", role: .cancel) {
                deleteTagTarget = ""
            }
        } message: {
            Text("Xóa tag \"\(deleteTagTarget)\"? Các entry trong tag sẽ trở thành không có tag.")
        }
    }
}
