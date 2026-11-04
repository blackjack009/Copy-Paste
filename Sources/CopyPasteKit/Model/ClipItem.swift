import Foundation

public enum ClipKind: String, Codable, Sendable {
    case text, url, code, color, image, file
}

public enum ClipFilter: String, CaseIterable, Identifiable, Sendable {
    case all, text, link, image, file

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all: return "Semua"
        case .text: return "Teks"
        case .link: return "Tautan"
        case .image: return "Gambar"
        case .file: return "File"
        }
    }

    public func matches(_ kind: ClipKind) -> Bool {
        switch self {
        case .all: return true
        case .text: return kind == .text || kind == .code || kind == .color
        case .link: return kind == .url
        case .image: return kind == .image
        case .file: return kind == .file
        }
    }
}

/// One history entry. The index keeps only text and metadata; the full
/// pasteboard contents are stored separately by `HistoryStore`.
public struct ClipItem: Codable, Identifiable, Equatable, Sendable {
    /// Longest text kept in the index. Pasting still uses the full snapshot.
    public static let maxStoredTextLength = 4_000

    public let id: UUID
    public var kind: ClipKind
    public var text: String
    /// Length of the original text, which can be longer than `text`.
    public var charCount: Int
    /// Extra fact for the preview, such as "1440 × 900, PNG".
    public var detail: String?
    public var sourceApp: String?
    public var sourceBundleID: String?
    public var createdAt: Date
    public var pinned: Bool
    public var contentHash: String

    public init(
        id: UUID = UUID(),
        kind: ClipKind,
        text: String,
        charCount: Int? = nil,
        detail: String? = nil,
        sourceApp: String? = nil,
        sourceBundleID: String? = nil,
        createdAt: Date = Date(),
        pinned: Bool = false,
        contentHash: String
    ) {
        self.id = id
        self.kind = kind
        self.text = String(text.prefix(Self.maxStoredTextLength))
        self.charCount = charCount ?? text.count
        self.detail = detail
        self.sourceApp = sourceApp
        self.sourceBundleID = sourceBundleID
        self.createdAt = createdAt
        self.pinned = pinned
        self.contentHash = contentHash
    }

    public var isTruncated: Bool { charCount > text.count }

    /// Everything the search box matches against.
    public var searchableText: String {
        [text, sourceApp, detail].compactMap { $0 }.joined(separator: " ")
    }
}
