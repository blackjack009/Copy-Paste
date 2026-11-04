import CopyPasteKit
import SwiftUI

/// One row in the list: thumbnail, text with the search match in bold, and a meta line.
struct HistoryRowView: View {
    let item: ClipItem
    let isSelected: Bool
    let query: String
    let thumbnailURL: URL?
    let shortcut: Int?
    let onHover: () -> Void
    let onPaste: () -> Void
    let onTogglePin: () -> Void
    let onRemove: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onPaste) {
                HStack(spacing: 10) {
                    thumbnail
                    VStack(alignment: .leading, spacing: 2) {
                        titleText
                        Text(meta)
                            .font(.system(size: 11))
                            .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 7)
            .padding(.vertical, 7)

            trailing
                .padding(.trailing, 8)
        }
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background(
            RoundedRectangle(cornerRadius: Theme.rowRadius, style: .continuous)
                .fill(isSelected ? Theme.accent : Color.clear)
        )
        .onHover { inside in
            hovering = inside
            if inside { onHover() }
        }
    }

    // MARK: Text

    /// One line of text for the list; line breaks become spaces.
    private var rowText: String {
        String(item.text.prefix(300))
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private var titleText: some View {
        highlighted(rowText)
            .font(titleFont)
            .lineLimit(item.kind == .text || item.kind == .code ? 2 : 1)
            .multilineTextAlignment(.leading)
    }

    private var titleFont: Font {
        switch item.kind {
        case .code, .url: return .system(size: 12, design: .monospaced)
        default: return .system(size: 13)
        }
    }

    /// The search match is shown bold and underlined.
    private func highlighted(_ text: String) -> Text {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty,
              let range = text.range(of: needle, options: .caseInsensitive) else {
            return Text(text)
        }
        return Text(text[..<range.lowerBound])
            + Text(text[range]).bold().underline()
            + Text(text[range.upperBound...])
    }

    private var meta: String {
        let app = item.sourceApp ?? "Tidak diketahui"
        return "\(app) · \(RelativeTime.short(from: item.createdAt))"
    }

    // MARK: Thumbnail

    @ViewBuilder
    private var thumbnail: some View {
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        switch item.kind {
        case .image:
            if let thumbnailURL, let image = NSImage(contentsOf: thumbnailURL) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(shape)
            } else {
                iconTile("photo", shape: shape)
            }
        case .color:
            shape
                .fill(Theme.swatch(for: item))
                .frame(width: 36, height: 36)
                .overlay(shape.stroke(Color.primary.opacity(0.14), lineWidth: 0.5))
        default:
            iconTile(symbol, shape: shape)
        }
    }

    private func iconTile(_ name: String, shape: RoundedRectangle) -> some View {
        Image(systemName: name)
            .font(.system(size: 15))
            .frame(width: 36, height: 36)
            .background(shape.fill(isSelected ? Color.white.opacity(0.22) : Color.primary.opacity(0.07)))
            .foregroundStyle(isSelected ? Color.white : Color.secondary)
    }

    private var symbol: String {
        switch item.kind {
        case .url: return "link"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .file: return "doc"
        case .image: return "photo"
        case .color: return "paintpalette"
        case .text: return "text.alignleft"
        }
    }

    // MARK: Trailing

    private var trailing: some View {
        ZStack {
            if isSelected || hovering {
                HStack(spacing: 2) {
                    iconButton(
                        item.pinned ? "pin.fill" : "pin",
                        label: item.pinned ? "Lepas sematan" : "Sematkan",
                        action: onTogglePin
                    )
                    iconButton("trash", label: "Hapus item", action: onRemove)
                }
            } else if let shortcut {
                Text("⌘\(shortcut)")
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
            }
        }
        .frame(minWidth: 56, alignment: .trailing)
    }

    private func iconButton(_ name: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 13))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
    }
}
