import AppKit

/// Everything on the pasteboard when an item was copied, so pasting it later
/// gives the target app the same formats.
public struct PasteboardSnapshot: Codable, Equatable, Sendable {
    /// One dictionary per pasteboard item: type identifier → raw data.
    public var items: [[String: Data]]

    public init(items: [[String: Data]]) {
        self.items = items
    }

    public static let plainTextType = "public.utf8-plain-text"
    public static let fileURLType = "public.file-url"
    public static let imageTypes = ["public.png", "public.jpeg", "public.tiff", "com.compuserve.gif", "public.heic"]

    public static func plain(_ text: String) -> PasteboardSnapshot {
        PasteboardSnapshot(items: [[plainTextType: Data(text.utf8)]])
    }

    public static func capture(
        from pasteboard: NSPasteboard,
        perTypeLimit: Int = 32 * 1024 * 1024,
        perClipLimit: Int = 64 * 1024 * 1024
    ) -> PasteboardSnapshot {
        var total = 0
        var captured: [[String: Data]] = []
        for item in pasteboard.pasteboardItems ?? [] {
            var entry: [String: Data] = [:]
            for type in item.types where !isVolatile(type.rawValue) {
                guard let data = item.data(forType: type),
                      data.count <= perTypeLimit,
                      total + data.count <= perClipLimit else { continue }
                entry[type.rawValue] = data
                total += data.count
            }
            if !entry.isEmpty { captured.append(entry) }
        }
        return PasteboardSnapshot(items: captured)
    }

    /// Types that only make sense for the app that wrote them at that moment.
    private static func isVolatile(_ type: String) -> Bool {
        type.hasPrefix("dyn.") || type.localizedCaseInsensitiveContains("promise")
    }

    public func write(to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        let objects: [NSPasteboardItem] = items.map { entry in
            let item = NSPasteboardItem()
            for (type, data) in entry {
                item.setData(data, forType: NSPasteboard.PasteboardType(type))
            }
            return item
        }
        pasteboard.writeObjects(objects)
    }

    public var plainText: String? {
        for entry in items {
            if let data = entry[Self.plainTextType], let text = String(data: data, encoding: .utf8) {
                return text
            }
        }
        return nil
    }
}
