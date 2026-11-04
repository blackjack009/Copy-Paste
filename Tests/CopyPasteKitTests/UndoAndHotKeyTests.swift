import AppKit
import Foundation
import Testing
@testable import CopyPasteKit

@Suite("Pintasan yang bisa diubah")
struct HotKeySpecTests {
    @Test func controlCommandVIsTheDefault() {
        #expect(HotKeySpec.defaultOpen.keyCode == 9)
        #expect(HotKeySpec.defaultOpen.modifiers == (HotKeySpec.controlBit | HotKeySpec.commandBit))
        #expect(HotKeySpec.defaultOpen.label == "⌃⌘V")
    }

    @Test func buildsLabelAndBitsFromPress() {
        let spec = HotKeySpec.make(keyCode: 9, flags: [.control, .command], character: "v")
        #expect(spec?.label == "⌃⌘V")
        #expect(spec?.modifiers == 0x1100)
    }

    @Test func rejectsPressWithoutCoreModifier() {
        #expect(HotKeySpec.make(keyCode: 9, flags: [], character: "v") == nil)
        #expect(HotKeySpec.make(keyCode: 9, flags: [.shift], character: "V") == nil)
    }

    @Test func namesSpecialKeys() {
        let spec = HotKeySpec.make(keyCode: 49, flags: [.option], character: " ")
        #expect(spec?.label == "⌥Space")
    }

    @Test func rejectsControlCharacters() {
        #expect(HotKeySpec.make(keyCode: 53, flags: [.command], character: "\u{1B}") == nil)
    }
}

@MainActor
@Suite("Urungkan hapus")
struct UndoTests {
    private func makeStore() -> (HistoryStore, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("copypaste-undo-\(UUID().uuidString)", isDirectory: true)
        return (HistoryStore(directory: dir), dir)
    }

    private func clip(_ text: String) -> CapturedClip {
        let item = ClipItem(kind: .text, text: text, contentHash: ClipCapture.hash(Data(text.utf8)))
        return CapturedClip(item: item, snapshot: .plain(text), thumbnailPNG: nil)
    }

    private let policy = RetentionPolicy(maxItems: 500, keepDays: 30)

    @Test func undoPutsRemovedItemBackAtSamePosition() {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        store.add(clip("c"), policy: policy)
        store.add(clip("b"), policy: policy)
        store.add(clip("a"), policy: policy)
        let middle = store.items[1].id

        store.remove(middle)
        #expect(store.items.map(\.text) == ["a", "c"])
        #expect(store.canUndoRemoval)

        store.undoLastRemoval()
        #expect(store.items.map(\.text) == ["a", "b", "c"])
        #expect(store.snapshot(for: middle)?.plainText == "b")
        #expect(!store.canUndoRemoval)
    }

    @Test func undoAfterClearKeepsPinnedItemsAndRestoresTheRest() {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        store.add(clip("c"), policy: policy)
        store.add(clip("b"), policy: policy)
        store.add(clip("a"), policy: policy)
        store.togglePin(store.items[1].id)

        store.clearUnpinned()
        #expect(store.items.map(\.text) == ["b"])

        store.undoLastRemoval()
        #expect(store.items.map(\.text) == ["a", "b", "c"])
    }

    @Test func secondRemovalReplacesWhatCanBeUndone() {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        store.add(clip("b"), policy: policy)
        store.add(clip("a"), policy: policy)

        store.remove(store.items[1].id) // removes "b"
        store.remove(store.items[0].id) // removes "a"
        store.undoLastRemoval()

        // Only the most recent removal ("a") comes back; "b" stays removed.
        #expect(store.items.map(\.text) == ["a"])
        #expect(!store.canUndoRemoval)
    }

    @Test func undoWithNothingToUndoChangesNothing() {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        store.add(clip("tetap"), policy: policy)

        store.undoLastRemoval()

        #expect(store.items.map(\.text) == ["tetap"])
    }
}

@MainActor
@Suite("Pengaturan pintasan")
struct ShortcutSettingsTests {
    @Test func shortcutIsSavedAndLoadedAgain() {
        let suite = "copypaste-tests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("UserDefaults tidak bisa dibuat")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = AppSettings(defaults: defaults)
        #expect(settings.hotKey == .defaultOpen)

        settings.hotKey = HotKeySpec(keyCode: 11, modifiers: HotKeySpec.optionBit | HotKeySpec.commandBit, label: "⌥⌘B")
        let reloaded = AppSettings(defaults: defaults)

        #expect(reloaded.hotKey.keyCode == 11)
        #expect(reloaded.hotKey.label == "⌥⌘B")
    }
}
