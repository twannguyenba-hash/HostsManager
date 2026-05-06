import SwiftUI

/// Empty/placeholder state dùng chung cho cả app — tự fallback macOS 13 nếu không có ContentUnavailableView.
/// `actionLabel` + `action` optional cho phép thêm CTA button (vd "Thêm repo").
struct EmptyStateView: View {
    let icon: String
    let title: String
    var message: String? = nil
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        Group {
            if #available(macOS 14.0, *) {
                modernView
            } else {
                fallbackView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @available(macOS 14.0, *)
    @ViewBuilder
    private var modernView: some View {
        if let message {
            ContentUnavailableView {
                Label(title, systemImage: icon)
            } description: {
                Text(message)
            } actions: {
                ctaButton
            }
        } else {
            ContentUnavailableView {
                Label(title, systemImage: icon)
            } actions: {
                ctaButton
            }
        }
    }

    private var fallbackView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3)
                .foregroundStyle(.primary)
            if let message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            ctaButton
                .padding(.top, 4)
            Spacer()
        }
    }

    @ViewBuilder
    private var ctaButton: some View {
        if let actionLabel, let action {
            Button(actionLabel, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
        }
    }
}

/// Loading state với progress + label mô tả — đồng bộ ngôn ngữ cho first-load file/repo.
struct LoadingStateView: View {
    let label: String

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .controlSize(.regular)
            Text(label)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Error state — icon cảnh báo + message. Optional retry CTA.
struct ErrorStateView: View {
    let message: String
    var retryLabel: String? = nil
    var onRetry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            if let retryLabel, let onRetry {
                Button(retryLabel, action: onRetry)
                    .buttonStyle(.bordered)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
