import AppKit
import ApplicationServices

/// Finds the text caret in the focused app through Accessibility, so the panel can open next to it.
/// Needs Accessibility permission; returns nil when it is missing or the app does not expose the caret.
enum CaretLocator {
    /// The caret rectangle in AppKit screen coordinates (origin at bottom-left).
    static func caretRect() -> NSRect? {
        let system = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focusedValue) == .success,
              let focused = focusedValue else { return nil }
        let element = focused as! AXUIElement

        var rangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
              let range = rangeValue else { return nil }

        var boundsValue: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            range,
            &boundsValue
        ) == .success, let bounds = boundsValue else { return nil }

        var rect = CGRect.zero
        guard AXValueGetValue(bounds as! AXValue, .cgRect, &rect) else { return nil }

        // Accessibility uses a top-left origin across the primary screen; AppKit uses bottom-left.
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let converted = NSRect(
            x: rect.minX,
            y: primaryHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
        guard converted.width.isFinite, converted.height.isFinite, converted.height > 0 else { return nil }
        return converted
    }
}
