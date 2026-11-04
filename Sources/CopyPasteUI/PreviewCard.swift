import CopyPasteKit
import SwiftUI

/// The card to the right of the list, shown with →. Full content plus where and when it was copied.
struct PreviewCard: View {
    let item: ClipItem
    let imageURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            facts
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .modifier(PanelSurface())
    }

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .image:
            if let imageURL, let image = NSImage(contentsOf: imageURL) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Text(item.text)
                    .font(.system(size: 13))
            }
        case .color:
            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.swatch(for: item))
                    .frame(height: 120)
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.primary.opacity(0.14), lineWidth: 0.5))
                Text(item.text)
                    .font(.system(size: 13, design: .monospaced))
                    .textSelection(.enabled)
            }
        case .file:
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "doc")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text(item.text)
                    .font(.system(size: 13))
                    .textSelection(.enabled)
            }
        case .code, .url, .text:
            AdaptiveScroll {
                Text(item.text)
                    .font(item.kind == .text ? .system(size: 13) : .system(size: 12, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
    }

    private var facts: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
                .padding(.bottom, 6)
            fact("Sumber", item.sourceApp ?? "–")
            fact("Disalin", RelativeTime.phrase(from: item.createdAt))
            fact(detail.label, detail.value)
        }
        .font(.system(size: 12))
    }

    private func fact(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }

    private var detail: (label: String, value: String) {
        switch item.kind {
        case .url:
            let host = URL(string: item.text)?.host ?? item.text
            return ("Domain", host)
        case .color:
            return ("RGB", item.detail ?? item.text)
        case .image, .file:
            return ("Ukuran", item.detail ?? "–")
        case .text, .code:
            return ("Panjang", "\(item.charCount) karakter")
        }
    }
}
