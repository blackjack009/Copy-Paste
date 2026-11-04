import AppKit
import Foundation

/// A global keyboard shortcut: a virtual key code, Carbon modifier bits, and the text shown in the UI.
public struct HotKeySpec: Codable, Equatable, Sendable {
    // Carbon modifier bits (HIToolbox/Events.h), written out so this module does not import Carbon.
    public static let commandBit: UInt32 = 0x0100
    public static let shiftBit: UInt32 = 0x0200
    public static let optionBit: UInt32 = 0x0800
    public static let controlBit: UInt32 = 0x1000

    /// ⌃⌘V, the Mac counterpart of Win+V.
    public static let defaultOpen = HotKeySpec(
        keyCode: 9,
        modifiers: HotKeySpec.controlBit | HotKeySpec.commandBit,
        label: "⌃⌘V"
    )

    public var keyCode: UInt32
    public var modifiers: UInt32
    public var label: String

    public init(keyCode: UInt32, modifiers: UInt32, label: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.label = label
    }

    private static let specialKeyLabels: [UInt16: String] = [
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 117: "⌦",
        115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    /// Builds a shortcut from a key press. A shortcut needs ⌃, ⌥ or ⌘, because ⇧ alone
    /// would clash with typing. Returns nil for presses that cannot be a shortcut.
    public static func make(keyCode: UInt16, flags: NSEvent.ModifierFlags, character: String?) -> HotKeySpec? {
        guard flags.contains(.control) || flags.contains(.option) || flags.contains(.command) else {
            return nil
        }

        let key: String
        if let special = specialKeyLabels[keyCode] {
            key = special
        } else if let first = character?.first, first.isLetter || first.isNumber || first.isPunctuation || first.isSymbol {
            key = String(first).uppercased()
        } else {
            return nil
        }

        var bits: UInt32 = 0
        var symbols = ""
        if flags.contains(.control) {
            bits |= controlBit
            symbols += "⌃"
        }
        if flags.contains(.option) {
            bits |= optionBit
            symbols += "⌥"
        }
        if flags.contains(.shift) {
            bits |= shiftBit
            symbols += "⇧"
        }
        if flags.contains(.command) {
            bits |= commandBit
            symbols += "⌘"
        }
        return HotKeySpec(keyCode: UInt32(keyCode), modifiers: bits, label: symbols + key)
    }

    public static func from(event: NSEvent) -> HotKeySpec? {
        make(keyCode: event.keyCode, flags: event.modifierFlags, character: event.charactersIgnoringModifiers)
    }
}
