import Combine
import Foundation

public struct RetentionPolicy: Sendable, Equatable {
    public var maxItems: Int
    /// 0 keeps unpinned items until they are removed by hand.
    public var keepDays: Int

    public init(maxItems: Int, keepDays: Int) {
        self.maxItems = maxItems
        self.keepDays = keepDays
    }
}

/// A removed item, kept in memory until the next removal so it can be put back.
struct RemovedEntry {
    let index: Int
    let item: ClipItem
    let snapshot: PasteboardSnapshot?
    let thumbnailPNG: Data?
}

/// Clipboard history on disk. Metadata goes in `history.json`; each item's full
/// pasteboard contents and thumbnail go in `blobs/`.
@MainActor
public final class HistoryStore: ObservableObject {
    @Published public private(set) var items: [ClipItem] = []

    public let directory: URL
    private let blobsDirectory: URL
    private let indexURL: URL
    private var lastRemoval: [RemovedEntry] = []

    public init(directory: URL) {
        self.directory = directory
        self.blobsDirectory = directory.appendingPathComponent("blobs", isDirectory: true)
        self.indexURL = directory.appendingPathComponent("history.json")
        try? FileManager.default.createDirectory(at: blobsDirectory, withIntermediateDirectories: true)
        load()
    }

    public static func defaultDirectory() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("CopyPaste", isDirectory: true)
    }

    /// True while the last removal can still be undone.
    public var canUndoRemoval: Bool {
        !lastRemoval.isEmpty
    }

    // MARK: Reading

    public func snapshot(for id: UUID) -> PasteboardSnapshot? {
        guard let data = try? Data(contentsOf: blobURL(id)) else { return nil }
        return try? PropertyListDecoder().decode(PasteboardSnapshot.self, from: data)
    }

    public func thumbnailURL(for id: UUID) -> URL? {
        let url = thumbnailFileURL(id)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: Changing

    public func add(_ clip: CapturedClip, policy: RetentionPolicy, now: Date = Date()) {
        if let index = items.firstIndex(where: { $0.contentHash == clip.item.contentHash }) {
            // Copied again: move the existing entry to the top instead of storing a duplicate.
            var existing = items.remove(at: index)
            existing.createdAt = clip.item.createdAt
            existing.sourceApp = clip.item.sourceApp
            existing.sourceBundleID = clip.item.sourceBundleID
            items.insert(existing, at: 0)
        } else {
            items.insert(clip.item, at: 0)
            writeSnapshot(clip.snapshot, id: clip.item.id)
            if let png = clip.thumbnailPNG {
                try? png.write(to: thumbnailFileURL(clip.item.id), options: .atomic)
            }
        }
        trim(policy: policy, now: now)
        save()
    }

    /// Removes old unpinned items. Pinned items are never removed here.
    public func trim(policy: RetentionPolicy, now: Date = Date()) {
        let cutoff: Date? = policy.keepDays > 0
            ? now.addingTimeInterval(-Double(policy.keepDays) * 86_400)
            : nil
        var kept: [ClipItem] = []
        var unpinnedCount = 0
        for item in items {
            if item.pinned {
                kept.append(item)
                continue
            }
            let expired = cutoff.map { item.createdAt < $0 } ?? false
            if expired || unpinnedCount >= policy.maxItems {
                deleteBlobs(item.id)
                continue
            }
            unpinnedCount += 1
            kept.append(item)
        }
        if kept.count != items.count {
            items = kept
            save()
        }
    }

    /// Moves an item to the top, for example after it was pasted.
    public func touch(_ id: UUID, now: Date = Date()) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        var item = items.remove(at: index)
        item.createdAt = now
        items.insert(item, at: 0)
        save()
    }

    public func togglePin(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].pinned.toggle()
        save()
    }

    public func remove(_ id: UUID) {
        removeItems([id])
    }

    /// Removes items and remembers them, so `undoLastRemoval()` can put them back.
    public func removeItems(_ ids: [UUID]) {
        let wanted = Set(ids)
        var removed: [RemovedEntry] = []
        for (index, item) in items.enumerated() where wanted.contains(item.id) {
            removed.append(RemovedEntry(
                index: index,
                item: item,
                snapshot: snapshot(for: item.id),
                thumbnailPNG: try? Data(contentsOf: thumbnailFileURL(item.id))
            ))
        }
        guard !removed.isEmpty else { return }
        items.removeAll { wanted.contains($0.id) }
        for entry in removed {
            deleteBlobs(entry.item.id)
        }
        lastRemoval = removed
        save()
    }

    /// Deletes everything except pinned items. The removal can be undone.
    public func clearUnpinned() {
        removeItems(items.filter { !$0.pinned }.map(\.id))
    }

    /// Puts back what the last removal took out, at the same positions.
    public func undoLastRemoval() {
        guard !lastRemoval.isEmpty else { return }
        for entry in lastRemoval.sorted(by: { $0.index < $1.index }) {
            items.insert(entry.item, at: min(entry.index, items.count))
            if let snapshot = entry.snapshot {
                writeSnapshot(snapshot, id: entry.item.id)
            }
            if let png = entry.thumbnailPNG {
                try? png.write(to: thumbnailFileURL(entry.item.id), options: .atomic)
            }
        }
        lastRemoval = []
        save()
    }

    // MARK: Files

    private func blobURL(_ id: UUID) -> URL {
        blobsDirectory.appendingPathComponent("\(id.uuidString).snapshot")
    }

    private func thumbnailFileURL(_ id: UUID) -> URL {
        blobsDirectory.appendingPathComponent("\(id.uuidString).png")
    }

    private func writeSnapshot(_ snapshot: PasteboardSnapshot, id: UUID) {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        if let data = try? encoder.encode(snapshot) {
            try? data.write(to: blobURL(id), options: .atomic)
        }
    }

    private func deleteBlobs(_ id: UUID) {
        try? FileManager.default.removeItem(at: blobURL(id))
        try? FileManager.default.removeItem(at: thumbnailFileURL(id))
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([ClipItem].self, from: data) else { return }
        items = decoded
    }

    private func save() {
        do {
            try JSONEncoder().encode(items).write(to: indexURL, options: .atomic)
        } catch {
            NSLog("CopyPaste: gagal menyimpan riwayat: \(error.localizedDescription)")
        }
    }
}
