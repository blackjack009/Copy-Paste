import AppKit
import Combine
import CopyPasteKit
import CopyPasteUI
import SwiftUI

/// A floating panel that can take keyboard focus without making the app's other windows key.
final class HistoryPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Shows and hides the history panel, places it near the caret, and pastes the chosen item.
@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private let model: PanelModel
    private let store: HistoryStore
    private let monitor: ClipboardMonitor
    private let settings: AppSettings

    private var panel: HistoryPanel?
    private var keyMonitor: Any?
    private var previousApp: NSRunningApplication?
    private var isHiding = false
    private var cancellables = Set<AnyCancellable>()

    init(model: PanelModel, store: HistoryStore, monitor: ClipboardMonitor, settings: AppSettings) {
        self.model = model
        self.store = store
        self.monitor = monitor
        self.settings = settings
        super.init()
        model.$showPreview
            .dropFirst()
            .sink { [weak self] _ in self?.resizeForPreview() }
            .store(in: &cancellables)
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        let frontmost = NSWorkspace.shared.frontmostApplication
        previousApp = frontmost?.bundleIdentifier == Bundle.main.bundleIdentifier ? nil : frontmost

        store.trim(policy: settings.retention)
        model.reset(paused: settings.isPaused)

        let panel = makePanelIfNeeded()
        let size = NSSize(width: Theme.width(preview: false), height: Theme.panelHeight)
        panel.setContentSize(size)
        panel.setFrameOrigin(origin(for: size))
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()
    }

    func hide() {
        guard let panel, panel.isVisible, !isHiding else { return }
        isHiding = true
        panel.orderOut(nil)
        isHiding = false
        removeKeyMonitor()
        model.showPreview = false
    }

    /// Puts the item on the clipboard, returns focus to the app that was active, and sends ⌘V
    /// when Accessibility permission allows it.
    func paste(_ item: ClipItem, plain: Bool) {
        let snapshot = store.snapshot(for: item.id) ?? PasteboardSnapshot.plain(item.text)
        hide()
        PasteService.place(snapshot, plainText: plain)
        monitor.noteOwnWrite()
        store.touch(item.id)

        guard let target = previousApp else { return }
        target.activate()
        guard PasteService.accessibilityTrusted() else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            PasteService.sendCommandV()
        }
    }

    // MARK: Window

    private func makePanelIfNeeded() -> HistoryPanel {
        if let panel { return panel }
        let created = HistoryPanel(
            contentRect: NSRect(x: 0, y: 0, width: Theme.width(preview: false), height: Theme.panelHeight),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        created.isFloatingPanel = true
        created.level = .floating
        created.backgroundColor = .clear
        created.isOpaque = false
        created.hasShadow = true
        created.hidesOnDeactivate = false
        created.isReleasedWhenClosed = false
        created.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        created.delegate = self
        created.contentView = NSHostingView(rootView: HistoryPanelView(model: model))
        panel = created
        return created
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    /// Below the caret when there is room, otherwise above it. Falls back to the mouse pointer.
    private func origin(for size: NSSize) -> NSPoint {
        if settings.panelNearCaret, let caret = CaretLocator.caretRect() {
            let area = visibleArea(containing: NSPoint(x: caret.minX, y: caret.minY))
            var y = caret.minY - size.height - 8
            if y < area.minY + 8 {
                y = caret.maxY + 8
            }
            return clamp(NSPoint(x: caret.minX, y: y), size: size, in: area)
        }
        let mouse = NSEvent.mouseLocation
        let area = visibleArea(containing: mouse)
        return clamp(NSPoint(x: mouse.x, y: mouse.y - size.height), size: size, in: area)
    }

    private func visibleArea(containing point: NSPoint) -> NSRect {
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main ?? NSScreen.screens[0]
        return screen.visibleFrame
    }

    private func clamp(_ origin: NSPoint, size: NSSize, in area: NSRect) -> NSPoint {
        NSPoint(
            x: min(max(origin.x, area.minX + 8), area.maxX - size.width - 8),
            y: min(max(origin.y, area.minY + 8), area.maxY - size.height - 8)
        )
    }

    /// Grows the panel to the right for the preview card, and keeps it on screen.
    private func resizeForPreview() {
        guard let panel, panel.isVisible else { return }
        let width = Theme.width(preview: model.showPreview && model.selected != nil)
        var frame = panel.frame
        frame.size = NSSize(width: width, height: Theme.panelHeight)
        let area = visibleArea(containing: NSPoint(x: frame.minX, y: frame.minY))
        if frame.maxX > area.maxX - 8 {
            frame.origin.x = area.maxX - width - 8
        }
        panel.setFrame(frame, display: true, animate: false)
    }

    // MARK: Keys

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let consumed = MainActor.assumeIsolated {
                self?.handleKey(event) ?? false
            }
            return consumed ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
    }

    /// Returns true when the key was used by the panel. Other keys go to the search field.
    private func handleKey(_ event: NSEvent) -> Bool {
        guard let window = panel, event.window === window else { return false }
        let command = event.modifierFlags.contains(.command)
        let shift = event.modifierFlags.contains(.shift)

        switch event.keyCode {
        case 53: // Esc
            if model.showPreview {
                model.showPreview = false
            } else {
                hide()
            }
            return true
        case 125: // ↓
            model.move(1)
            return true
        case 126: // ↑
            model.move(-1)
            return true
        case 36, 76: // Return, keypad Enter
            model.pasteSelected(plain: shift)
            return true
        case 48: // Tab cycles the filter
            model.cycleFilter(shift ? -1 : 1)
            return true
        case 124: // → opens the preview, only when the caret is at the end of the search text
            guard !model.showPreview, model.selected != nil, caretAtEnd(in: window) else { return false }
            model.showPreview = true
            return true
        case 123: // ← closes the preview
            guard model.showPreview else { return false }
            model.showPreview = false
            return true
        case 51 where command: // ⌘⌫ removes the selected item
            model.removeSelected()
            return true
        default:
            break
        }

        if command, let characters = event.charactersIgnoringModifiers {
            if let digit = Int(characters), (1...9).contains(digit) {
                model.pasteIndex(digit - 1)
                return true
            }
            if characters.lowercased() == "p" {
                model.togglePinSelected()
                return true
            }
            if characters.lowercased() == "z", model.performUndo() {
                return true
            }
        }
        return false
    }

    private func caretAtEnd(in window: NSWindow) -> Bool {
        guard let editor = window.firstResponder as? NSTextView else { return true }
        return editor.selectedRange().location == editor.string.utf16.count
    }
}
