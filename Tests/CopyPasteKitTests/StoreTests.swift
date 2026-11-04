import AppKit
import Foundation
import Testing
@testable import CopyPasteKit

@MainActor
@Suite("Penyimpanan riwayat")
struct StoreTests {
    private func makeDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("copypaste-tests-\(UUID().uuidString)", isDirectory: true)
    }

    private func clip(_ text: String, createdAt: Date = Date()) -> CapturedClip {
        let item = ClipItem(
            kind: .text,
            text: text,
            createdAt: createdAt,
            contentHash: ClipCapture.hash(Data(text.utf8))
        )
        return CapturedClip(item: item, snapshot: .plain(text), thumbnailPNG: nil)
    }

    private let policy = RetentionPolicy(maxItems: 500, keepDays: 30)

    @Test func copyingSameTextMovesItToTop() {
        let dir = makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = HistoryStore(directory: dir)

        store.add(clip("a"), policy: policy)
        store.add(clip("b"), policy: policy)
        store.add(clip("a"), policy: policy)

        #expect(store.items.count == 2)
        #expect(store.items.first?.text == "a")
    }

    @Test func trimKeepsPinnedItems() {
        let dir = makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = HistoryStore(directory: dir)
        let small = RetentionPolicy(maxItems: 2, keepDays: 0)

        store.add(clip("tertua"), policy: policy)
        let oldest = store.items[0].id
        store.togglePin(oldest)
        store.add(clip("b"), policy: small)
        store.add(clip("c"), policy: small)
        store.add(clip("d"), policy: small)

        #expect(store.items.contains { $0.id == oldest })
        #expect(store.items.filter { !$0.pinned }.count == 2)
        #expect(store.items.count == 3)
    }

    @Test func expiredItemsAreRemoved() {
        let dir = makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = HistoryStore(directory: dir)
        let now = Date()
        let twoDaysAgo = now.addingTimeInterval(-2 * 86_400)

        store.add(clip("lama", createdAt: twoDaysAgo), policy: policy, now: now)
        store.trim(policy: RetentionPolicy(maxItems: 500, keepDays: 1), now: now)

        #expect(store.items.isEmpty)
    }

    @Test func historySurvivesReload() {
        let dir = makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let first = HistoryStore(directory: dir)
        first.add(clip("tersimpan"), policy: policy)

        let second = HistoryStore(directory: dir)
        #expect(second.items.map(\.text) == ["tersimpan"])
        #expect(second.snapshot(for: second.items[0].id)?.plainText == "tersimpan")
    }

    @Test func removingItemDeletesItsSnapshot() {
        let dir = makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = HistoryStore(directory: dir)
        store.add(clip("hapus saya"), policy: policy)
        let id = store.items[0].id

        store.remove(id)

        #expect(store.items.isEmpty)
        #expect(store.snapshot(for: id) == nil)
    }
}

@Suite("Snapshot pasteboard")
struct PasteboardSnapshotTests {
    @Test func plainTextSurvivesPrivatePasteboard() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("copypaste-test-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }

        PasteboardSnapshot.plain("halo dunia").write(to: pasteboard)
        let read = PasteboardSnapshot.capture(from: pasteboard)

        #expect(read.plainText == "halo dunia")
    }
}
