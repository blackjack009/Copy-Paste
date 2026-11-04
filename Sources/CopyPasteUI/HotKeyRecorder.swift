import AppKit
import CopyPasteKit
import Foundation

/// Records the next key press as the panel shortcut. Esc cancels.
@MainActor
final class HotKeyRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var message: String?

    private let onRecord: (HotKeySpec) -> Bool
    private var monitor: Any?

    init(onRecord: @escaping (HotKeySpec) -> Bool) {
        self.onRecord = onRecord
    }

    func start() {
        guard monitor == nil else { return }
        message = nil
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let consumed = MainActor.assumeIsolated {
                self?.handle(event) ?? false
            }
            return consumed ? nil : event
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        isRecording = false
    }

    /// Returns true when the key press was used by the recorder.
    private func handle(_ event: NSEvent) -> Bool {
        guard isRecording else { return false }
        if event.keyCode == 53 { // Esc
            stop()
            return true
        }
        guard let spec = HotKeySpec.from(event: event) else {
            message = "Pakai ⌃, ⌥, atau ⌘ bersama tombol lain."
            return true
        }
        stop()
        message = onRecord(spec) ? nil : "Pintasan itu tidak bisa didaftarkan. Coba kombinasi lain."
        return true
    }
}
