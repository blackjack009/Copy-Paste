import AppKit

/// Watches the general pasteboard and reports new copies. It only reads the
/// pasteboard when `changeCount` moves, so an idle app stays quiet.
@MainActor
public final class ClipboardMonitor {
    public var onCapture: ((CapturedClip) -> Void)?

    private let pasteboard: NSPasteboard
    private let settings: AppSettings
    private var lastChangeCount: Int
    private var timer: Timer?

    public init(settings: AppSettings, pasteboard: NSPasteboard = .general) {
        self.settings = settings
        self.pasteboard = pasteboard
        self.lastChangeCount = pasteboard.changeCount
    }

    public func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
    }

    /// Call after writing to the pasteboard ourselves, so that write is not recorded again.
    public func noteOwnWrite() {
        lastChangeCount = pasteboard.changeCount
    }

    private func poll() {
        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count
        guard !settings.isPaused else { return }

        let frontmost = NSWorkspace.shared.frontmostApplication
        let options = CaptureOptions(
            saveImagesAndFiles: settings.saveImagesAndFiles,
            skipSecrets: settings.skipSecrets
        )
        guard let clip = ClipCapture.capture(
            from: pasteboard,
            options: options,
            sourceApp: frontmost?.localizedName,
            sourceBundleID: frontmost?.bundleIdentifier
        ) else { return }
        onCapture?(clip)
    }
}
