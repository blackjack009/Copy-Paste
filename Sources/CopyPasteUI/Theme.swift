import CopyPasteKit
import SwiftUI

public enum Theme {
    /// Same blue as the design canvas.
    public static let accent = Color(red: 8 / 255, green: 89 / 255, blue: 208 / 255)
    public static let panelRadius: CGFloat = 18
    public static let rowRadius: CGFloat = 10
    public static let listWidth: CGFloat = 392
    public static let previewWidth: CGFloat = 340
    public static let panelHeight: CGFloat = 520
    public static let gap: CGFloat = 8

    public static var panelShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: panelRadius, style: .continuous)
    }

    public static func width(preview: Bool) -> CGFloat {
        preview ? listWidth + gap + previewWidth : listWidth
    }

    /// Color for a hex item such as `#0859D0`.
    public static func swatch(for item: ClipItem) -> Color {
        guard let rgb = ClipClassifier.rgb(fromHex: item.text) else { return .gray }
        return Color(
            red: Double(rgb.r) / 255,
            green: Double(rgb.g) / 255,
            blue: Double(rgb.b) / 255
        )
    }
}

/// Set by the snapshot tool. Materials do not render offscreen, so it uses a solid fill.
public struct SnapshotModeKey: EnvironmentKey {
    public static let defaultValue = false
}

public extension EnvironmentValues {
    var snapshotMode: Bool {
        get { self[SnapshotModeKey.self] }
        set { self[SnapshotModeKey.self] = newValue }
    }
}

/// The frosted card background used by the list and the preview.
public struct PanelSurface: ViewModifier {
    @Environment(\.snapshotMode) private var snapshotMode

    public func body(content: Content) -> some View {
        content
            .background {
                if snapshotMode {
                    Theme.panelShape.fill(Color(nsColor: .windowBackgroundColor))
                } else {
                    Theme.panelShape.fill(.regularMaterial)
                }
            }
            .overlay(Theme.panelShape.stroke(Color.primary.opacity(0.12), lineWidth: 0.5))
            .clipShape(Theme.panelShape)
    }
}

/// A ScrollView in the app. The snapshot tool skips it, because ImageRenderer does not draw scrolled content.
struct AdaptiveScroll<Content: View>: View {
    @Environment(\.snapshotMode) private var snapshotMode
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if snapshotMode {
            // A flexible spacer takes the room left over; the content is overlaid and clipped,
            // so its full height never pushes the header or footer out of the frame.
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .top) {
                    content
                }
                .clipped()
        } else {
            ScrollView {
                content
            }
        }
    }
}

/// A keyboard key drawn like the footer hints in the design.
public struct KeyCap: View {
    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 5)
            .frame(minWidth: 18, minHeight: 18)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.primary.opacity(0.1)))
    }
}
