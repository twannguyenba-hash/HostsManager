import SwiftUI

enum SidebarSelection: Hashable {
    case filter(SidebarFilter)
    case tag(String)
}

/// Profile-first sidebar redesigned in v2: Profiles section on top, filters below, tools at bottom.
/// Reference: docs/mockup-reference.md → "Sidebar".
struct SidebarView: View {
    @Binding var selection: SidebarSelection?
    @Bindable var hostsManager: HostsFileManager

    @State private var showCreateProfileSheet = false
    @State private var newProfileName = ""
    @State private var newProfileColor: ProfileColor = .purple
    @State private var renameTarget: Profile?
    @State private var renameBuffer = ""
    @State private var deleteTarget: Profile?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Profiles list scrolls; everything below is pinned so the user always
            // sees the filter counts + tools without needing to scroll past profiles.
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.p4) {
                    profilesSection
                }
                .padding(.horizontal, DSSpacing.p2)
                .padding(.top, DSSpacing.p3)
                .padding(.bottom, DSSpacing.p2)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: DSSpacing.p4) {
                filterSection
            }
            .padding(.horizontal, DSSpacing.p2)
            .padding(.top, DSSpacing.p2)
            .padding(.bottom, DSSpacing.p2)
            .background(Color.dsBackgroundSidebar)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.dsBorderTertiary).frame(height: 0.5)
            }

            // Pinned at bottom: add-profile button (matches EnvSidebarView footer).
            addProfileButton
                .padding(.horizontal, DSSpacing.p2)
                .padding(.bottom, DSSpacing.p3)
                .padding(.top, DSSpacing.p2)
                .background(Color.dsBackgroundSidebar)
        }
        .background(Color.dsBackgroundSidebar)
        .sheet(isPresented: $showCreateProfileSheet) { createProfileSheet }
        .alert(
            "Đổi tên profile",
            isPresented: Binding(get: { renameTarget != nil }, set: { if !$0 { renameTarget = nil } })
        ) {
            TextField("Tên mới", text: $renameBuffer)
            Button("Đổi tên") {
                if let target = renameTarget {
                    hostsManager.renameProfile(id: target.id, to: renameBuffer)
                    if case .tag(target.name) = selection {
                        selection = .tag(renameBuffer)
                    }
                }
                renameTarget = nil
            }
            Button("Huỷ", role: .cancel) { renameTarget = nil }
        }
        .alert(
            "Xoá profile?",
            isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }),
            presenting: deleteTarget
        ) { target in
            Button("Xoá", role: .destructive) {
                if case .tag(target.name) = selection { selection = .filter(.all) }
                hostsManager.removeProfile(id: target.id)
            }
            Button("Huỷ", role: .cancel) { deleteTarget = nil }
        } message: { target in
            Text("Xoá metadata profile \"\(target.name)\"? Entries trong /etc/hosts không bị xoá.")
        }
    }

    // MARK: - Profiles section

    private var profilesSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.p2) {
            sectionHeader("Profiles")

            ForEach(hostsManager.profiles, id: \.id) { profile in
                profileRow(profile)
            }
        }
    }

    /// Pinned top "Thêm profile" button — same visual pattern as EnvSidebarView's
    /// addRepoButton so both tabs feel consistent.
    private var addProfileButton: some View {
        Button {
            newProfileName = ""
            newProfileColor = .purple
            showCreateProfileSheet = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 12))
                Text("Thêm profile")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#378ADD"), Color(hex: "#185FA5")],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.md)
                    .strokeBorder(Color(hex: "#78b4ff").opacity(0.4), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func profileRow(_ profile: Profile) -> some View {
        let isActive = hostsManager.activeProfileID == profile.id
        let count = hostsManager.tagEntryCount(name: profile.name)

        Button {
            if isActive {
                hostsManager.switchProfile(to: nil)
                selection = .filter(.all)
            } else {
                hostsManager.switchProfile(to: profile.id)
                selection = .tag(profile.name)
            }
        } label: {
            HStack(spacing: 8) {
                StatusDot(color: .ds(profile.color), size: 8, glow: isActive)
                VStack(alignment: .leading, spacing: 1) {
                    Text(profile.name)
                        .font(.system(size: 11.5, weight: isActive ? .medium : .regular))
                        .foregroundStyle(Color.dsTextPrimary)
                    Text("\(count) host\(count == 1 ? "" : "s")\(isActive ? " active" : "")")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Color.dsTextTertiary)
                }
                Spacer(minLength: 0)
                if isActive {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.ds(profile.color))
                } else if let n = profile.shortcutNumber, n <= 9 {
                    Text("⌘\(n)")
                        .font(.dsMonoTiny)
                        .foregroundStyle(Color.dsTextTertiary)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(profileRowBackground(profile, isActive: isActive))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(
                        isActive ? Color.ds(profile.color).opacity(0.35) : Color.clear,
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: isActive)
        .accessibilityIdentifier("profile-row-\(profile.name)")
        .contextMenu {
            Button {
                renameTarget = profile
                renameBuffer = profile.name
            } label: { Label("Đổi tên", systemImage: "pencil") }
            Button(role: .destructive) {
                deleteTarget = profile
            } label: { Label("Xoá profile", systemImage: "trash") }
        }
    }

    @ViewBuilder
    private func profileRowBackground(_ profile: Profile, isActive: Bool) -> some View {
        if isActive {
            // Stronger filled bg for active profile (matches mockup):
            // base dark color tinted with profile color overlay.
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(LinearGradient(
                            colors: [
                                Color.ds(profile.color).opacity(0.22),
                                Color.ds(profile.color).opacity(0.10),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                )
        } else {
            RoundedRectangle(cornerRadius: 7).fill(Color.clear)
        }
    }

    // MARK: - Filter section

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            sectionHeader("Bộ lọc")
            ForEach(SidebarFilter.allCases) { filter in
                filterRow(filter)
            }
        }
    }

    private func filterRow(_ filter: SidebarFilter) -> some View {
        let count = hostsManager.entryCount(for: filter)
        let isSelected = isFilterSelected(filter)
        return Button {
            selection = .filter(filter)
            hostsManager.switchProfile(to: nil)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: filter.icon)
                    .font(.system(size: 11))
                    .frame(width: 14)
                Text(filter.rawValue)
                    .font(.system(size: 11.5))
                Spacer()
                Text("\(count)")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.dsTextTertiary)
            }
            .foregroundStyle(Color.dsTextPrimary)
            .dsSidebarItem(isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func isFilterSelected(_ filter: SidebarFilter) -> Bool {
        if case .filter(let f) = selection, f == filter { return true }
        return false
    }

    // MARK: - Header + banner

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9.5, weight: .medium))
            .tracking(0.6)
            .foregroundStyle(Color.dsTextTertiary)
            .padding(.horizontal, 6)
            .padding(.bottom, 4)
    }

    // MARK: - Sheets

    private var createProfileSheet: some View {
        VStack(alignment: .leading, spacing: DSSpacing.p3) {
            Text("Tạo profile mới")
                .font(.dsHeading)
            TextField("Tên profile", text: $newProfileName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Text("Màu").font(.dsCaption)
                Picker("", selection: $newProfileColor) {
                    ForEach(ProfileColor.allCases) { color in
                        Text(color.displayName).tag(color)
                    }
                }
                .labelsHidden()
            }
            HStack {
                Spacer()
                Button("Huỷ") { showCreateProfileSheet = false }
                Button("Tạo") {
                    _ = hostsManager.addProfile(name: newProfileName, color: newProfileColor)
                    showCreateProfileSheet = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newProfileName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(DSSpacing.p4)
        .frame(width: 320)
    }
}
