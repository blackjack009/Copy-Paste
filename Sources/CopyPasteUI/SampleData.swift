import CopyPasteKit
import Foundation

/// Sample history that matches the design canvas. Used by the snapshot tool and previews.
public enum SampleData {
    public static func items(now: Date = Date()) -> [ClipItem] {
        func ago(_ seconds: TimeInterval) -> Date {
            now.addingTimeInterval(-seconds)
        }
        return [
            ClipItem(kind: .text, text: "Jl. Contoh Raya No. 12, Jakarta Selatan 12345",
                     sourceApp: "Catatan", createdAt: ago(3 * 86_400), pinned: true, contentHash: "sample-1"),
            ClipItem(kind: .code, text: "git log --oneline --graph -20",
                     sourceApp: "Terminal", createdAt: ago(7 * 86_400), pinned: true, contentHash: "sample-2"),
            ClipItem(kind: .url, text: "https://developer.apple.com/documentation/appkit/nspasteboard",
                     sourceApp: "Safari", createdAt: ago(120), contentHash: "sample-3"),
            ClipItem(kind: .text, text: "Demo dipindah ke Kamis jam 10. Tolong siapkan build terbaru dan catatan rilisnya sebelum rapat, supaya tim QA bisa cek dulu.",
                     sourceApp: "Slack", createdAt: ago(300), contentHash: "sample-4"),
            ClipItem(kind: .image, text: "Gambar PNG, 1440 × 900", detail: "1440 × 900, PNG",
                     sourceApp: "Tangkapan Layar", createdAt: ago(720), contentHash: "sample-5"),
            ClipItem(kind: .color, text: "#0859D0", detail: "rgb(8, 89, 208)",
                     sourceApp: "Figma", createdAt: ago(1_080), contentHash: "sample-6"),
            ClipItem(kind: .code, text: "npm run build -- --watch",
                     sourceApp: "Terminal", createdAt: ago(1_560), contentHash: "sample-7"),
            ClipItem(kind: .file, text: "brief-desain-v2.pdf", detail: "1,2 MB, PDF",
                     sourceApp: "Finder", createdAt: ago(2_400), contentHash: "sample-8"),
            ClipItem(kind: .text, text: "Invoice sudah dikirim ke tim finance, tinggal tunggu konfirmasi pembayaran.",
                     sourceApp: "Mail", createdAt: ago(3_600), contentHash: "sample-9"),
        ]
    }
}
