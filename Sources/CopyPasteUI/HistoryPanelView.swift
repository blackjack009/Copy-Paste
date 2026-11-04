import CopyPasteKit
import SwiftUI

/// The clipboard history panel. The list is 392 pt wide; the preview card sits to its right.
public struct HistoryPanelView: View {
    @ObservedObject var model: PanelModel
    @FocusState private var searchFocused: Bool
    @Environment(\.snapshotMode) private var snapshotMode

    public init(model: PanelModel) {
        self.model = model
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Theme.gap) {
            listCard
            if model.showPreview, let item = model.selected {
                PreviewCard(item: item, imageURL: model.thumbnailURL?(item.id))
                    .frame(width: Theme.previewWidth, height: Theme.panelHeight)
            }
        }
        .frame(
            width: Theme.width(preview: model.showPreview && model.selected != nil),
            height: Theme.panelHeight,
            alignment: .topLeading
        )
        .onAppear { searchFocused = true }
        .onChange(of: model.focusToken) { _, _ in searchFocused = true }
    }

    // MARK: List card

    private var listCard: some View {
        VStack(spacing: 0) {
            header
            filterBar
            if model.isPaused {
                pausedBanner
            }
            content
            footer
        }
        .frame(width: Theme.listWidth, height: Theme.panelHeight)
        .modifier(PanelSurface())
        .overlay(alignment: .bottom) { toast }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            if snapshotMode {
                Text(model.query.isEmpty ? "Cari riwayat…" : model.query)
                    .font(.system(size: 15))
                    .foregroundStyle(model.query.isEmpty ? Color.secondary : Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextField("Cari riwayat…", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .focused($searchFocused)
                    .accessibilityLabel("Cari riwayat clipboard")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
    }

    private var filterBar: some View {
        HStack(spacing: 4) {
            ForEach(ClipFilter.allCases) { filter in
                let selected = model.filter == filter
                Button {
                    model.filter = filter
                } label: {
                    Text(filter.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(selected ? Color(nsColor: .windowBackgroundColor) : Color.secondary)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(Capsule().fill(selected ? Color.primary : Color.clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? AccessibilityTraits.isSelected : [])
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var pausedBanner: some View {
        Text("Pencatatan dijeda. Yang kamu salin sekarang tidak disimpan.")
            .font(.system(size: 12))
            .foregroundStyle(Color(red: 0.48, green: 0.18, blue: 0.04))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(red: 0.98, green: 0.91, blue: 0.87)))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
    }

    @ViewBuilder
    private var content: some View {
        if model.items.isEmpty {
            emptyState(
                icon: "doc.on.clipboard",
                title: "Belum ada riwayat",
                subtitle: "Salin apa saja dengan ⌘C, nanti muncul di sini."
            )
        } else if model.visible.isEmpty {
            emptyState(
                icon: "magnifyingglass",
                title: "Tidak ada hasil",
                subtitle: "Coba kata lain atau ganti filter."
            )
        } else {
            historyList
        }
    }

    private var historyList: some View {
        ScrollViewReader { proxy in
            AdaptiveScroll {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if !model.pinnedVisible.isEmpty {
                        sectionHeader("Disematkan", clearable: false)
                        ForEach(model.pinnedVisible) { item in
                            row(for: item)
                        }
                    }
                    if !model.recentVisible.isEmpty {
                        sectionHeader("Terbaru", clearable: model.canClearRecent)
                        ForEach(model.recentVisible) { item in
                            row(for: item)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .onChange(of: model.selectedID) { _, id in
                if let id {
                    proxy.scrollTo(id)
                }
            }
        }
    }

    private func sectionHeader(_ title: String, clearable: Bool) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if clearable {
                Button("Hapus semua") {
                    model.clearUnpinned()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
    }

    private func row(for item: ClipItem) -> some View {
        HistoryRowView(
            item: item,
            isSelected: item.id == model.selectedID,
            query: model.query,
            thumbnailURL: model.thumbnailURL?(item.id),
            shortcut: model.shortcutNumbers[item.id],
            onHover: { model.selectedID = item.id },
            onPaste: { model.onPaste?(item, false) },
            onTogglePin: { model.onTogglePin?(item) },
            onRemove: { model.onRemove?(item) }
        )
        .id(item.id)
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            hint("↵", "Tempel")
            hint("⇧↵", "Teks polos")
            hint("→", "Pratinjau")
            Spacer(minLength: 0)
            Button {
                model.onOpenSettings?()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Pengaturan")
            .help("Pengaturan")
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .frame(height: 38)
        .overlay(alignment: .top) { Divider() }
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 5) {
            KeyCap(key)
            Text(label)
        }
    }

    @ViewBuilder
    private var toast: some View {
        if let message = model.toast {
            HStack(spacing: 10) {
                Text(message.text)
                if let actionTitle = message.actionTitle {
                    Button(actionTitle) {
                        model.runToastAction()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 0.55, green: 0.75, blue: 1.0))
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(Capsule().fill(Color(white: 0.11)))
            .padding(.bottom, 52)
        }
    }
}
