import CopyPasteKit
import SwiftUI

/// First-run permissions. Status is re-read every second, so the rows update after the user
/// changes something in System Settings.
public struct OnboardingView: View {
    let currentAccessibility: () -> Bool
    let currentClipboard: () -> PasteboardAccessState
    let onOpenAccessibility: () -> Void
    let onOpenPrivacy: () -> Void
    let onDone: () -> Void

    public init(
        currentAccessibility: @escaping () -> Bool,
        currentClipboard: @escaping () -> PasteboardAccessState,
        onOpenAccessibility: @escaping () -> Void,
        onOpenPrivacy: @escaping () -> Void,
        onDone: @escaping () -> Void
    ) {
        self.currentAccessibility = currentAccessibility
        self.currentClipboard = currentClipboard
        self.onOpenAccessibility = onOpenAccessibility
        self.onOpenPrivacy = onOpenPrivacy
        self.onDone = onDone
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let accessibility = currentAccessibility()
            let clipboard = currentClipboard()
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Dua izin supaya bisa jalan")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Riwayat disimpan di Mac ini saja, tidak dikirim ke mana pun.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 0) {
                    permissionRow(
                        icon: "doc.on.clipboard",
                        title: "Akses clipboard",
                        detail: clipboardDetail(clipboard),
                        granted: clipboard == .allowed,
                        actionTitle: "Buka Pengaturan Privasi",
                        action: onOpenPrivacy
                    )
                    Divider()
                    permissionRow(
                        icon: "figure.stand",
                        title: "Aksesibilitas",
                        detail: "Untuk menempelkan item langsung ke aplikasi yang sedang aktif. Di Pengaturan Sistem, buka Privasi & Keamanan, Aksesibilitas, lalu nyalakan CopyPaste.",
                        granted: accessibility,
                        actionTitle: "Buka Pengaturan Aksesibilitas",
                        action: onOpenAccessibility
                    )
                }
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.04)))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.primary.opacity(0.1), lineWidth: 0.5))

                HStack(alignment: .center, spacing: 16) {
                    Text("Kalau dilewati, item tetap disalin dan kamu bisa menempelkannya sendiri dengan ⌘V.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button("Selesai", action: onDone)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(28)
            .frame(width: 560)
        }
    }

    private func clipboardDetail(_ state: PasteboardAccessState) -> String {
        switch state {
        case .allowed:
            return "Diizinkan. CopyPaste bisa mencatat apa yang kamu salin."
        default:
            return "Saat macOS menanyakan izin untuk membaca clipboard dari aplikasi lain, pilih Izinkan. Kalau terlanjur menolak, cari bagian tempel dari aplikasi lain di Pengaturan Privasi."
        }
    }

    private func permissionRow(
        icon: String,
        title: String,
        detail: String,
        granted: Bool,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.primary.opacity(0.07)))
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    statusLabel(granted)
                }
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !granted {
                    Button(actionTitle, action: action)
                        .padding(.top, 4)
                }
            }
        }
        .padding(14)
    }

    private func statusLabel(_ granted: Bool) -> some View {
        Label(granted ? "Diizinkan" : "Perlu izin", systemImage: granted ? "checkmark.circle.fill" : "exclamationmark.circle")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(granted ? Color.green : Color.orange)
            .labelStyle(.titleAndIcon)
    }
}
