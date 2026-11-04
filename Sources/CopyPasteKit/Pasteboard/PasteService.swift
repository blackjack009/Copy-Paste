import AppKit
import ApplicationServices

/// Puts history items back on the pasteboard and, when allowed, sends ⌘V to the frontmost app.
public enum PasteService {
    /// Sending keystrokes needs Accessibility permission. `prompt: true` shows the system prompt.
    public static func accessibilityTrusted(prompt: Bool = false) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    public static func place(_ snapshot: PasteboardSnapshot, plainText: Bool, on pasteboard: NSPasteboard = .general) {
        if plainText, let text = snapshot.plainText {
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        } else {
            snapshot.write(to: pasteboard)
        }
    }

    public static func sendCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyCode: CGKeyCode = 9 // ANSI V
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}

public enum PasteboardAccessState: Sendable {
    case allowed, notAskedYet, askEachTime, denied, unknown
}

public enum PasteboardAccess {
    /// Whether macOS lets this app read the clipboard in the background (macOS 15.4+).
    public static func current() -> PasteboardAccessState {
        if #available(macOS 15.4, *) {
            switch NSPasteboard.general.accessBehavior {
            case .alwaysAllow: return .allowed
            case .default: return .notAskedYet
            case .ask: return .askEachTime
            case .alwaysDeny: return .denied
            @unknown default: return .unknown
            }
        }
        return .allowed
    }
}
