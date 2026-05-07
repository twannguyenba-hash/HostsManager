import SwiftUI

/// 32-pt context strip below TitleBar. Shows file path → active profile → status indicators.
/// Reference: docs/mockup-reference.md → "Breadcrumb".
struct BreadcrumbView: View {
    let activeTab: AppTab
    let activeProfile: Profile?
    let pendingChanges: Int
    var sudoOK: Bool = false
    var externalChangeDetected: Bool = false
    var onReloadFromDisk: () -> Void = {}

    var body: some View {
        HStack(spacing: DSSpacing.p2) {
            leftZone
            Spacer()
            rightZone
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(height: 32)
        .background(Color.dsBackgroundBreadcrumb)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.dsBorderTertiary)
                .frame(height: 0.5)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var leftZone: some View {
        switch activeTab {
        case .hosts: hostsBreadcrumb
        case .env:   envBreadcrumb
        }
    }

    private var hostsBreadcrumb: some View {
        HStack(spacing: DSSpacing.p2) {
            HStack(spacing: 4) {
                Image(systemName: "doc.text")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.dsTextSecondary)
                Text("/etc/hosts")
                    .font(.dsMonoSmall)
                    .foregroundStyle(Color.dsTextSecondary)
            }

            chevron

            if let profile = activeProfile {
                profileDropdownBadge(profile)
            } else {
                Text("Tất cả profiles")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.dsTextTertiary)
            }
        }
    }

    /// Breadcrumb-style profile badge with dropdown chevron (mockup: "Release ▾").
    private func profileDropdownBadge(_ profile: Profile) -> some View {
        HStack(spacing: 6) {
            StatusDot(color: .ds(profile.color), size: 6, glow: true)
            Text(profile.name)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Color(hex: "#CECBF6"))
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.45))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: DSRadius.sm)
                .fill(Color.ds(profile.color).opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.sm)
                .strokeBorder(Color.ds(profile.color).opacity(0.3), lineWidth: 0.5)
        )
    }

    private var envBreadcrumb: some View {
        HStack(spacing: DSSpacing.p2) {
            HStack(spacing: 4) {
                Image(systemName: "folder")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.dsProfilePurple)
                Text(".env")
                    .font(.dsMonoSmall)
                    .foregroundStyle(Color.dsTextSecondary)
            }

            chevron

            if let profile = activeProfile {
                ProfileBadge(profile: profile, glow: true)
            }
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.2))
    }

    @ViewBuilder
    private var rightZone: some View {
        HStack(spacing: DSSpacing.p3) {
            if activeTab == .hosts && externalChangeDetected {
                externalChangeBadge
            }

            if activeTab == .hosts {
                HStack(spacing: 4) {
                    Image(systemName: sudoOK ? "checkmark.shield.fill" : "shield")
                        .font(.system(size: 10))
                        .foregroundStyle(sudoOK ? Color.dsResolvedGreen : Color.dsTextTertiary)
                    Text(sudoOK ? "sudo OK" : "chưa có quyền")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.dsTextSecondary)
                }
            }

            if pendingChanges > 0 {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.dsProfileAmber)
                        .frame(width: 6, height: 6)
                    Text("\(pendingChanges) thay đổi")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.dsTextSecondary)
                }
            }
        }
    }

    /// Amber warning chip + Reload button, shown when an external tool modified
    /// `/etc/hosts` while the app was running. Click to reload from disk.
    private var externalChangeBadge: some View {
        Button(action: onReloadFromDisk) {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.dsProfileAmber)
                Text("File thay đổi từ bên ngoài")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.dsTextPrimary)
                Text("· Tải lại")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Color(hex: "#78b4ff"))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: DSRadius.sm)
                    .fill(Color.dsProfileAmber.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.sm)
                    .strokeBorder(Color.dsProfileAmber.opacity(0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .help("File /etc/hosts đã bị tool khác sửa. Click để tải lại từ disk.")
    }
}

#Preview("Hosts mode") {
    VStack(spacing: 0) {
        BreadcrumbView(
            activeTab: .hosts,
            activeProfile: .release,
            pendingChanges: 2,
            sudoOK: true
        )
        BreadcrumbView(
            activeTab: .hosts,
            activeProfile: nil,
            pendingChanges: 0,
            sudoOK: false
        )
        BreadcrumbView(
            activeTab: .env,
            activeProfile: .production,
            pendingChanges: 1
        )
    }
    .frame(width: 980)
    .background(Color.dsBackground)
}
