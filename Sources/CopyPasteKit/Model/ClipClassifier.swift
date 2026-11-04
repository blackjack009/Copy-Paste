import Foundation

/// Decides how copied text should be shown.
public enum ClipClassifier {
    /// Terminals and editors, where multi-line text is almost always code.
    private static let developerApps: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.apple.dt.Xcode",
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "dev.zed.Zed",
        "com.sublimetext.4",
        "com.jetbrains.intellij",
        "com.jetbrains.pycharm",
        "com.jetbrains.WebStorm",
        "com.mitchellh.ghostty",
        "dev.warp.Warp-Stable",
        "net.kovidgoyal.kitty",
    ]

    public static func kind(forText text: String, sourceBundleID: String?) -> ClipKind {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if isURL(trimmed) { return .url }
        if rgb(fromHex: trimmed) != nil { return .color }
        if let sourceBundleID, developerApps.contains(sourceBundleID), trimmed.contains("\n") {
            return .code
        }
        if looksLikeCode(trimmed) { return .code }
        return .text
    }

    public static func isURL(_ text: String) -> Bool {
        text.range(of: #"^https?://\S+$"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// Parses `#RGB`, `#RRGGBB` and `#RRGGBBAA` (alpha is ignored).
    public static func rgb(fromHex text: String) -> (r: Int, g: Int, b: Int)? {
        let pattern = #"^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$"#
        guard text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil else {
            return nil
        }
        var hex = String(text.dropFirst())
        if hex.count == 3 {
            hex = hex.map { "\($0)\($0)" }.joined()
        }
        guard let value = Int(hex.prefix(6), radix: 16) else { return nil }
        return ((value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF)
    }

    private static func looksLikeCode(_ text: String) -> Bool {
        if text.hasPrefix("#!") { return true }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        guard lines.count >= 2 else { return false }
        let hasBlock = text.contains("{") && text.contains("}")
        let endingWithSemicolon = lines.filter { $0.trimmingCharacters(in: .whitespaces).hasSuffix(";") }.count
        let indented = lines.filter { $0.hasPrefix("    ") || $0.hasPrefix("\t") }.count
        return (hasBlock && (endingWithSemicolon > 0 || indented > 0))
            || endingWithSemicolon * 2 >= lines.count
    }
}

/// Short relative times for the list, such as "2 mnt" or "3 hari".
public enum RelativeTime {
    public static let justNow = "baru saja"

    public static func short(from date: Date, to now: Date = Date()) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        if seconds < 60 { return justNow }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) mnt" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) jam" }
        let days = hours / 24
        if days < 7 { return "\(days) hari" }
        if days < 30 { return "\(days / 7) minggu" }
        if days < 365 { return "\(days / 30) bulan" }
        return "\(days / 365) tahun"
    }

    /// Same value as a phrase for the preview, such as "12 mnt lalu".
    public static func phrase(from date: Date, to now: Date = Date()) -> String {
        let value = short(from: date, to: now)
        return value == justNow ? value : "\(value) lalu"
    }
}
