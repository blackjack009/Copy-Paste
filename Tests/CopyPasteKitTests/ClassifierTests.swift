import Foundation
import Testing
@testable import CopyPasteKit

@Suite("Klasifikasi teks")
struct ClassifierTests {
    @Test func detectsURL() {
        #expect(ClipClassifier.kind(forText: "https://example.com/a?b=1", sourceBundleID: nil) == .url)
    }

    @Test func detectsHexColor() {
        #expect(ClipClassifier.kind(forText: "#0859D0", sourceBundleID: nil) == .color)
    }

    @Test func parsesHexColorChannels() {
        let rgb = ClipClassifier.rgb(fromHex: "#0859D0")
        #expect(rgb?.r == 8)
        #expect(rgb?.g == 89)
        #expect(rgb?.b == 208)
    }

    @Test func parsesShortHexColor() {
        let rgb = ClipClassifier.rgb(fromHex: "#fa0")
        #expect(rgb?.r == 255)
        #expect(rgb?.g == 170)
        #expect(rgb?.b == 0)
    }

    @Test func plainSentenceStaysText() {
        #expect(ClipClassifier.kind(forText: "Demo dipindah ke Kamis jam 10.", sourceBundleID: nil) == .text)
    }

    @Test func multilineCodeIsCode() {
        let source = "func a() {\n    return 1;\n}"
        #expect(ClipClassifier.kind(forText: source, sourceBundleID: nil) == .code)
    }

    @Test func multilineTextFromTerminalIsCode() {
        #expect(ClipClassifier.kind(forText: "ls\npwd", sourceBundleID: "com.apple.Terminal") == .code)
    }

    @Test func singleLineFromTerminalStaysText() {
        #expect(ClipClassifier.kind(forText: "hari ini", sourceBundleID: "com.apple.Terminal") == .text)
    }
}

@Suite("Waktu relatif")
struct RelativeTimeTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test func justNowUnderOneMinute() {
        #expect(RelativeTime.short(from: now.addingTimeInterval(-30), to: now) == "baru saja")
    }

    @Test func minutesHoursDaysWeeks() {
        #expect(RelativeTime.short(from: now.addingTimeInterval(-300), to: now) == "5 mnt")
        #expect(RelativeTime.short(from: now.addingTimeInterval(-7_200), to: now) == "2 jam")
        #expect(RelativeTime.short(from: now.addingTimeInterval(-3 * 86_400), to: now) == "3 hari")
        #expect(RelativeTime.short(from: now.addingTimeInterval(-10 * 86_400), to: now) == "1 minggu")
    }

    @Test func phraseAddsLalu() {
        #expect(RelativeTime.phrase(from: now.addingTimeInterval(-720), to: now) == "12 mnt lalu")
        #expect(RelativeTime.phrase(from: now, to: now) == "baru saja")
    }
}

@Suite("Pencarian dan filter")
struct HistoryQueryTests {
    private func item(_ text: String, kind: ClipKind = .text, pinned: Bool = false, app: String? = nil) -> ClipItem {
        ClipItem(kind: kind, text: text, sourceApp: app, pinned: pinned, contentHash: text)
    }

    @Test func searchIgnoresCase() {
        let items = [item("Git log"), item("npm run build")]
        let result = HistoryQuery.apply(items, filter: .all, query: "GIT")
        #expect(result.map(\.text) == ["Git log"])
    }

    @Test func searchMatchesSourceApp() {
        let items = [item("catatan biasa", app: "Slack"), item("lain")]
        let result = HistoryQuery.apply(items, filter: .all, query: "slack")
        #expect(result.count == 1)
    }

    @Test func filterByKind() {
        let items = [item("https://a.dev", kind: .url), item("halo")]
        #expect(HistoryQuery.apply(items, filter: .link, query: "").count == 1)
        #expect(HistoryQuery.apply(items, filter: .text, query: "").count == 1)
        #expect(HistoryQuery.apply(items, filter: .image, query: "").isEmpty)
    }

    @Test func pinnedItemsComeFirst() {
        let items = [item("baru"), item("disematkan", pinned: true)]
        let result = HistoryQuery.apply(items, filter: .all, query: "")
        #expect(result.map(\.text) == ["disematkan", "baru"])
    }
}
