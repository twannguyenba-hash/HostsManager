# Changelog

## v2.0.0 — 2026-05-07

### Breaking changes

- **Min macOS bumped 13.0 → 14.0** để dùng `@Observable` macro và `NavigationSplitView` modern. User trên macOS 13 stay v1.7.7.
- Tag markers trong `/etc/hosts` giờ được render thành Profile metadata (color, ⌘N shortcut). User sửa file thủ công vẫn OK — tag-only phần được bảo toàn round-trip.

### Added

- **Profile system**: groups hosts theo tag-name marker `## [tag:Name]` trong `/etc/hosts`. Mỗi profile có color tự động (Release purple, Production green, Master amber, ...) + ⌘N shortcut (1-9).
- **Profile-first sidebar**: active profile card với gradient bg, color dot glow, click toggle activeProfileID.
- **Window shell mới**: TitleBar 44pt với traffic lights overlay gradient bg, Breadcrumb 32pt, StatusBar 28pt với Apply ⌘S gradient button.
- **Inline detail header**: title + count subtitle + search field + view mode picker + + + ⋯ thay window toolbar.
- **DesignSystem tokens**: Colors (hex initializer), Typography (dsTitle/dsHeading/dsBody/...), Spacing (4-pt scale), Radius (sm/md/lg/xl), ViewModifiers (dsCard/dsRowHover/dsSidebarItem).
- **Settings panel**: General tab (theme picker), Profiles tab (list + delete).
- **Custom DSToggle**: 24×13 switch spring animation, respects accessibilityReduceMotion.
- **Custom HostRowView**: IP color tokens, source badge pill, hover overlay, alternating row tint.
- **Custom EnvRowView**: KEY mono blue + value mono amber, blank/comment lines italic.
- **Tests target**: `HostsManagerTests` với Swift Testing framework. 32 tests covering Profile/ProfileColor models, ProfileStore persistence, HostsParser round-trip, Profile+HostsFileManager integration.

### Changed

- `HostsFileManager` and `EnvFileManager` migrated từ `ObservableObject` + `@Published` sang `@Observable` macro (macOS 14+).
- View bindings update: `@StateObject` → `@State`, `@EnvironmentObject` → `@Environment(_.self)`, `@ObservedObject` → `@Bindable`/`let`.
- Hosts list: SwiftUI `Table` → `LazyVStack` với HostRowView components để control styling pixel-perfect.
- Env list: same pattern (Table → LazyVStack với EnvRowView).
- Sudo strategy: giữ AppleScript pattern v1, không introduce Authorization Services API mới (deprecated).

### Fixed

- Window chrome leak: `.toolbar(.hidden, for: .windowToolbar)` + `NSWindow.fullSizeContentView` để TitleBar gradient extend đến top.
- Picker "Mode" accessibility label leaking → `.labelsHidden()`.
- Duplicate Apply button (system toolbar + StatusBar) → consolidated to StatusBar only.

### Internal

- Branch `refactor/v2-redesign` từ `main`, 12+ commits.
- Plan files: `plans/260507-1022-v2-redesign/{plan,v2.0,v2.1,v2.2}.md` (gitignored, local).
- Skipped v1 → v2 data migration (solo dev).
- v2.1, v2.2 deferred (raw editor with syntax highlight, MenuBarExtra, command palette ⌘K).

## v1.7.7 — 2025-04

Previous releases: see git tags `v1.7.7`, `v1.7.6`, … on GitHub.
