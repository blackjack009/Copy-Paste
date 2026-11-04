import AppKit
import Combine
import CopyPasteKit
import CopyPasteUI
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings()
    private let store = HistoryStore(directory: HistoryStore.defaultDirectory())
    private let model = PanelModel()
    private lazy var monitor = ClipboardMonitor(settings: settings)
    private lazy var panel = PanelController(model: model, store: store, monitor: monitor, settings: settings)

    private var hotKey: GlobalHotKey?
    private var statusItem: NSStatusItem?
    private var openMenuItem: NSMenuItem?
    private var pauseMenuItem: NSMenuItem?
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        wireModel()

        monitor.onCapture = { [store, settings] clip in
            store.add(clip, policy: settings.retention)
        }
        monitor.start()

        hotKey = makeHotKey(settings.hotKey) ?? makeHotKey(.defaultOpen)

        settings.$isPaused
            .sink { [weak self] paused in
                self?.pauseMenuItem?.state = paused ? .on : .off
            }
            .store(in: &cancellables)

        installStatusItem()

        if !settings.onboardingDone {
            showOnboarding()
        }
    }

    /// Keeps the panel's list in step with the store, and connects the panel's buttons to the app.
    private func wireModel() {
        store.$items
            .sink { [weak self] items in
                self?.model.items = items
            }
            .store(in: &cancellables)

        model.isPaused = settings.isPaused
        model.onPaste = { [weak self] item, plain in
            self?.panel.paste(item, plain: plain)
        }
        model.onTogglePin = { [store] item in
            store.togglePin(item.id)
        }
        model.onRemove = { [weak self] item in
            self?.removeWithUndo([item.id], message: "Item dihapus")
        }
        model.onClearUnpinned = { [weak self] in
            self?.clearUnpinnedWithUndo()
        }
        model.onUndo = { [weak self] in
            self?.undoRemoval() ?? false
        }
        model.onOpenSettings = { [weak self] in
            self?.openSettings()
        }
        model.thumbnailURL = { [store] id in
            store.thumbnailURL(for: id)
        }
    }

    // MARK: Removing with undo

    /// Removes items and offers "Urungkan" above the list.
    private func removeWithUndo(_ ids: [UUID], message: String) {
        let before = store.items.count
        store.removeItems(ids)
        guard store.items.count < before else { return }
        model.flash(message, actionTitle: "Urungkan") { [weak self] in
            _ = self?.undoRemoval()
        }
    }

    private func clearUnpinnedWithUndo() {
        let ids = store.items.filter { !$0.pinned }.map(\.id)
        removeWithUndo(ids, message: "Riwayat dihapus, item tersemat tetap ada")
    }

    @discardableResult
    private func undoRemoval() -> Bool {
        guard store.canUndoRemoval else { return false }
        store.undoLastRemoval()
        model.dismissToast()
        return true
    }

    // MARK: Shortcut

    private func makeHotKey(_ spec: HotKeySpec) -> GlobalHotKey? {
        let candidate = GlobalHotKey(spec: spec) { [weak self] in
            self?.panel.toggle()
        }
        return candidate.isRegistered ? candidate : nil
    }

    /// Registers a new panel shortcut and saves it. If the system refuses it, the old one stays.
    private func applyHotKey(_ spec: HotKeySpec) -> Bool {
        let previous = settings.hotKey
        hotKey = nil // release the old shortcut first, so the same key combination can be claimed again
        if let candidate = makeHotKey(spec) {
            hotKey = candidate
            settings.hotKey = spec
            openMenuItem?.title = openTitle()
            return true
        }
        hotKey = makeHotKey(previous)
        return false
    }

    private func openTitle() -> String {
        "Buka riwayat clipboard  \(settings.hotKey.label)"
    }

    // MARK: Menu bar

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Riwayat clipboard")
        item.menu = buildMenu()
        statusItem = item
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let open = NSMenuItem(title: openTitle(), action: #selector(openPanel), keyEquivalent: "")
        open.target = self
        openMenuItem = open
        menu.addItem(open)
        menu.addItem(.separator())

        let pause = NSMenuItem(title: "Jeda pencatatan", action: #selector(togglePause), keyEquivalent: "")
        pause.target = self
        pause.state = settings.isPaused ? .on : .off
        pauseMenuItem = pause
        menu.addItem(pause)

        let clear = menu.addItem(withTitle: "Hapus riwayat (kecuali yang disematkan)", action: #selector(clearHistory), keyEquivalent: "")
        clear.target = self
        menu.addItem(.separator())

        let permissions = menu.addItem(withTitle: "Izin…", action: #selector(showOnboardingFromMenu), keyEquivalent: "")
        permissions.target = self
        let preferences = menu.addItem(withTitle: "Pengaturan…", action: #selector(showSettingsFromMenu), keyEquivalent: ",")
        preferences.target = self
        menu.addItem(.separator())

        menu.addItem(withTitle: "Keluar CopyPaste", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    @objc private func openPanel() {
        panel.show()
    }

    @objc private func togglePause() {
        settings.isPaused.toggle()
    }

    @objc private func clearHistory() {
        clearUnpinnedWithUndo()
    }

    @objc private func showSettingsFromMenu() {
        openSettings()
    }

    @objc private func showOnboardingFromMenu() {
        showOnboarding()
    }

    // MARK: Windows

    private func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(
                settings: settings,
                onClearHistory: { [weak self] in
                    self?.clearUnpinnedWithUndo()
                },
                onChangeHotKey: { [weak self] spec in
                    self?.applyHotKey(spec) ?? false
                }
            )
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 640),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Pengaturan CopyPaste"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: view)
            window.center()
            settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func showOnboarding() {
        if onboardingWindow == nil {
            let view = OnboardingView(
                currentAccessibility: { PasteService.accessibilityTrusted() },
                currentClipboard: { PasteboardAccess.current() },
                onOpenAccessibility: { [weak self] in
                    _ = PasteService.accessibilityTrusted(prompt: true)
                    self?.openSystemSettings("Privacy_Accessibility")
                },
                onOpenPrivacy: { [weak self] in
                    self?.openSystemSettings(nil)
                },
                onDone: { [weak self] in
                    self?.finishOnboarding()
                }
            )
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Izin CopyPaste"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: view)
            window.center()
            onboardingWindow = window
        }
        NSApp.activate()
        onboardingWindow?.makeKeyAndOrderFront(nil)
    }

    private func finishOnboarding() {
        settings.onboardingDone = true
        onboardingWindow?.close()
    }

    /// Opens a Privacy & Security pane in System Settings. `anchor` selects one list, such as Accessibility.
    private func openSystemSettings(_ anchor: String?) {
        var address = "x-apple.systempreferences:com.apple.preference.security"
        if let anchor {
            address += "?\(anchor)"
        }
        if let url = URL(string: address) {
            NSWorkspace.shared.open(url)
        }
    }
}
