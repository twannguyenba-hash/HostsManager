import SwiftUI

/// Top-level window chrome wrapping the existing Hosts/Env content views.
/// Layout (top→bottom): TitleBar → Breadcrumb → content → StatusBar.
/// Reference: docs/mockup-reference.md → "Layout hierarchy".
struct MainWindowView: View {
    @Environment(HostsFileManager.self) private var hostsManager
    @Environment(EnvFileManager.self) private var envManager
    @State private var selectedTab: AppTab = .hosts
    @State private var showCommandPalette: Bool = false
    @AppStorage("appearanceMode") private var appearanceRaw: String = AppearanceMode.system.rawValue

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    var body: some View {
        VStack(spacing: 0) {
            TitleBarView(
                selectedTab: $selectedTab,
                hostsCount: hostsManager.entries.count,
                envCount: envEntryCount,
                onSearch: { hostsManager.isSearchFocused = true },
                onSettings: openSettings
            )

            BreadcrumbView(
                activeTab: selectedTab,
                activeProfile: activeProfile,
                pendingChanges: pendingChanges,
                sudoOK: false,  // wired in v2.1 with SudoCoordinator
                externalChangeDetected: hostsManager.externalChangeDetected,
                onReloadFromDisk: { hostsManager.loadHostsFile() }
            )

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            StatusBarView(
                activeTab: selectedTab,
                pendingChanges: pendingChanges,
                isApplying: hostsManager.isApplying,
                sudoOK: false,  // wired in v2.1 with SudoCoordinator session cache
                canUndo: canUndoForTab,
                canRedo: canRedoForTab,
                onUndo: handleUndo,
                onRedo: handleRedo,
                onApply: handleApply
            )
        }
        .background(Color.dsBackground)
        .preferredColorScheme(appearance.colorScheme)
        .environment(\.isActiveTab, true)
        .background(WindowChromeConfigurator())
        .background(commandPaletteShortcut)
        .overlay(alignment: .top) {
            if showCommandPalette {
                CommandPaletteView(
                    isPresented: $showCommandPalette,
                    switchTab: { selectedTab = $0 }
                )
                .zIndex(100)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: showCommandPalette)
    }

    /// Invisible button hosting the ⌘K shortcut. Placed in `.background` so
    /// it captures the keystroke without affecting layout.
    private var commandPaletteShortcut: some View {
        Button {
            showCommandPalette.toggle()
        } label: { EmptyView() }
        .buttonStyle(.plain)
        .frame(width: 0, height: 0)
        .opacity(0)
        .keyboardShortcut("k", modifiers: .command)
        .accessibilityHidden(true)
    }

    // MARK: - Content routing

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    private var content: some View {
        ZStack {
            switch selectedTab {
            case .hosts: HostsView().transition(.opacity)
            case .env:   EnvView().transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: selectedTab)
    }

    // MARK: - Derived state

    private var envEntryCount: Int {
        guard let repoId = envManager.selectedRepoId else { return 0 }
        return envManager.loadedFiles[repoId]?.flatMap(\.entries).count ?? 0
    }

    private var activeProfile: Profile? {
        guard let id = hostsManager.activeProfileID else { return nil }
        return hostsManager.profiles.first { $0.id == id }
    }

    private var pendingChanges: Int {
        switch selectedTab {
        case .hosts:
            return hostsManager.hasUnsavedChanges ? 1 : 0
        case .env:
            guard let repoId = envManager.selectedRepoId else { return 0 }
            return envManager.loadedFiles[repoId]?.filter(\.hasUnsavedChanges).count ?? 0
        }
    }

    // MARK: - Actions

    private var canUndoForTab: Bool {
        selectedTab == .hosts && hostsManager.canUndo
    }

    private var canRedoForTab: Bool {
        selectedTab == .hosts && hostsManager.canRedo
    }

    private func handleUndo() {
        switch selectedTab {
        case .hosts: hostsManager.undo()
        case .env:   break  // env undo wired in v2.2
        }
    }

    private func handleRedo() {
        switch selectedTab {
        case .hosts: hostsManager.redo()
        case .env:   break
        }
    }

    private func handleApply() {
        switch selectedTab {
        case .hosts: hostsManager.applyChanges()
        case .env:   envManager.applyCurrentSelection()
        }
    }

    private func openSettings() {
        if #available(macOS 14, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }
}

