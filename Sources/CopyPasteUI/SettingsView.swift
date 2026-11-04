import AppKit
import CopyPasteKit
import SwiftUI

public struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    let onClearHistory: () -> Void
    @StateObject private var recorder: HotKeyRecorder

    @State private var launchAtLogin: Bool
    @State private var loginState: LaunchAtLoginState
    @State private var launchError: String?
    @State private var clearArmed = false
    @State private var cleared = false

    /// `onChangeHotKey` registers the new shortcut and returns false when the system refuses it.
    public init(
        settings: AppSettings,
        onClearHistory: @escaping () -> Void,
        onChangeHotKey: @escaping (HotKeySpec) -> Bool
    ) {
        self.settings = settings
        self.onClearHistory = onClearHistory
        _recorder = StateObject(wrappedValue: HotKeyRecorder(onRecord: onChangeHotKey))
        let state = LaunchAtLogin.state
        _loginState = State(initialValue: state)
        _launchAtLogin = State(initialValue: state == .enabled)
    }

    public var body: some View {
        Form {
            Section("Umum") {
                LabeledContent("Pintasan buka panel") {
                    HStack(spacing: 8) {
                        KeyCap(settings.hotKey.label)
                        Button(recorder.isRecording ? "Batal" : "Ubah") {
                            if recorder.isRecording {
                                recorder.stop()
                            } else {
                                recorder.start()
                            }
                        }
                    }
                }
                if let message = recorder.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if recorder.isRecording {
                    Text("Tekan kombinasi tombol. Esc untuk batal.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Toggle("Buka saat login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        apply(enabled)
                    }
                if loginState == .needsApproval {
                    Text("Perlu persetujuan. Buka Pengaturan Sistem, Umum, Item Login, lalu nyalakan CopyPaste.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Buka Item Login", action: openLoginItems)
                }
                if let launchError {
                    Text(launchError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Picker("Posisi panel", selection: $settings.panelNearCaret) {
                    Text("Dekat kursor teks").tag(true)
                    Text("Dekat kursor mouse").tag(false)
                }
                .pickerStyle(.segmented)
            }

            Section("Riwayat") {
                Picker("Simpan paling banyak", selection: $settings.maxItems) {
                    Text("100 item").tag(100)
                    Text("200 item").tag(200)
                    Text("500 item").tag(500)
                    Text("1.000 item").tag(1000)
                }
                Picker("Hapus otomatis setelah", selection: $settings.keepDays) {
                    Text("1 hari").tag(1)
                    Text("7 hari").tag(7)
                    Text("30 hari").tag(30)
                    Text("Tidak pernah").tag(0)
                }
                Toggle("Simpan gambar dan file", isOn: $settings.saveImagesAndFiles)
            }

            Section("Privasi") {
                Toggle("Lewati item rahasia dari password manager", isOn: $settings.skipSecrets)
                Toggle("Jeda pencatatan", isOn: $settings.isPaused)
                Button(buttonTitle, role: .destructive, action: clearTapped)
                    .disabled(cleared)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 640)
        .onDisappear {
            recorder.stop()
        }
    }

    private var buttonTitle: String {
        if cleared { return "Riwayat sudah dihapus" }
        return clearArmed ? "Klik sekali lagi untuk menghapus" : "Hapus semua riwayat…"
    }

    /// Two clicks, so a stray click cannot wipe the history. The clear can be undone from the panel.
    private func clearTapped() {
        if clearArmed {
            onClearHistory()
            cleared = true
        } else {
            clearArmed = true
        }
    }

    private func apply(_ enabled: Bool) {
        do {
            try LaunchAtLogin.setEnabled(enabled)
            launchError = nil
        } catch {
            launchError = "Tidak bisa mengubah pengaturan login: \(error.localizedDescription)"
        }
        loginState = LaunchAtLogin.state
    }

    private func openLoginItems() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
