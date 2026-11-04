import CopyPasteKit
import SwiftUI

/// Everything the history panel shows and does. The app fills `items` from the
/// store and answers the `on…` callbacks; the snapshot tool fills it with sample data.
/// A short message above the list, with an optional button such as "Urungkan".
public struct ToastMessage: Identifiable, Equatable {
    public let id = UUID()
    public let text: String
    public let actionTitle: String?

    public init(text: String, actionTitle: String?) {
        self.text = text
        self.actionTitle = actionTitle
    }
}

@MainActor
public final class PanelModel: ObservableObject {
    @Published public var items: [ClipItem] = [] { didSet { ensureSelection() } }
    @Published public var query: String = "" { didSet { ensureSelection() } }
    @Published public var filter: ClipFilter = .all { didSet { ensureSelection() } }
    @Published public var selectedID: UUID?
    @Published public var showPreview = false
    @Published public var toast: ToastMessage?
    @Published public var isPaused = false
    /// Changing this asks the search field to take focus again.
    @Published public var focusToken = 0

    public var onPaste: ((ClipItem, Bool) -> Void)?
    public var onTogglePin: ((ClipItem) -> Void)?
    public var onRemove: ((ClipItem) -> Void)?
    public var onClearUnpinned: (() -> Void)?
    public var onOpenSettings: (() -> Void)?
    public var thumbnailURL: ((UUID) -> URL?)?
    /// Undoes the last removal. Returns false when there was nothing to undo.
    public var onUndo: (() -> Bool)?

    private var toastAction: (() -> Void)?

    public init() {}

    // MARK: Derived lists

    public var visible: [ClipItem] {
        HistoryQuery.apply(items, filter: filter, query: query)
    }

    public var pinnedVisible: [ClipItem] {
        visible.filter(\.pinned)
    }

    public var recentVisible: [ClipItem] {
        visible.filter { !$0.pinned }
    }

    public var canClearRecent: Bool {
        query.isEmpty && filter == .all && !recentVisible.isEmpty
    }

    public var selected: ClipItem? {
        guard let selectedID else { return nil }
        return visible.first { $0.id == selectedID }
    }

    /// ⌘1 to ⌘9 for the first nine visible items.
    public var shortcutNumbers: [UUID: Int] {
        var numbers: [UUID: Int] = [:]
        for (offset, item) in visible.prefix(9).enumerated() {
            numbers[item.id] = offset + 1
        }
        return numbers
    }

    // MARK: Actions

    public func reset(paused: Bool) {
        isPaused = paused
        showPreview = false
        query = ""
        filter = .all
        ensureSelection()
        focusToken += 1
    }

    public func move(_ delta: Int) {
        let list = visible
        guard !list.isEmpty else { return }
        let current = list.firstIndex(where: { $0.id == selectedID }) ?? 0
        let next = min(max(current + delta, 0), list.count - 1)
        selectedID = list[next].id
    }

    public func pasteSelected(plain: Bool) {
        if let selected {
            onPaste?(selected, plain)
        }
    }

    public func pasteIndex(_ index: Int) {
        let list = visible
        guard list.indices.contains(index) else { return }
        onPaste?(list[index], false)
    }

    public func togglePinSelected() {
        if let selected {
            onTogglePin?(selected)
        }
    }

    public func removeSelected() {
        if let selected {
            onRemove?(selected)
        }
    }

    public func cycleFilter(_ delta: Int) {
        let all = ClipFilter.allCases
        let index = all.firstIndex(of: filter) ?? 0
        filter = all[(index + delta + all.count) % all.count]
    }

    public func clearUnpinned() {
        onClearUnpinned?()
    }

    /// Shows a short message above the list. With `actionTitle`, the message stays longer
    /// and its button runs `action`.
    public func flash(_ text: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        let message = ToastMessage(text: text, actionTitle: actionTitle)
        toast = message
        toastAction = action
        let seconds: UInt64 = actionTitle == nil ? 2 : 6
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            if self?.toast?.id == message.id {
                self?.dismissToast()
            }
        }
    }

    public func runToastAction() {
        let action = toastAction
        dismissToast()
        action?()
    }

    public func dismissToast() {
        toast = nil
        toastAction = nil
    }

    /// Undoes the last removal. Returns false when there is nothing to undo, so ⌘Z still
    /// reaches the search field.
    public func performUndo() -> Bool {
        onUndo?() ?? false
    }

    private func ensureSelection() {
        let list = visible
        if let selectedID, list.contains(where: { $0.id == selectedID }) {
            return
        }
        selectedID = list.first?.id
    }
}
