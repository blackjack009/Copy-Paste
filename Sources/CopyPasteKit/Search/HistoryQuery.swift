import Foundation

public enum HistoryQuery {
    /// Applies the kind filter and the search text, then lists pinned items first.
    public static func apply(_ items: [ClipItem], filter: ClipFilter, query: String) -> [ClipItem] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = items.filter { item in
            guard filter.matches(item.kind) else { return false }
            return needle.isEmpty || item.searchableText.localizedCaseInsensitiveContains(needle)
        }
        return matches.filter(\.pinned) + matches.filter { !$0.pinned }
    }
}
