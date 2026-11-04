import AppKit
import CopyPasteKit
import CopyPasteUI
import SwiftUI

/// Renders the panel states to PNG using sample data only. It never touches the real clipboard.
/// Usage: swift run CopyPasteSnapshot [output-folder]
@MainActor
func renderAll(into directory: URL) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let items = SampleData.items()
    let urlItem = items.first { $0.kind == .url }?.id
    let codeItem = items.first { $0.kind == .code }?.id

    try render(panel(items: items), named: "panel-daftar", size: CGSize(width: 392, height: 520), into: directory)

    try render(panel(items: items, query: "git"), named: "panel-cari", size: CGSize(width: 392, height: 520), into: directory)

    try render(
        panel(items: items, selected: urlItem, preview: true),
        named: "panel-pratinjau",
        size: CGSize(width: 740, height: 520),
        into: directory
    )

    try render(
        panel(items: items, selected: codeItem, filter: .link),
        named: "panel-filter-tautan",
        size: CGSize(width: 392, height: 520),
        into: directory
    )

    try render(panel(items: [], paused: true), named: "panel-kosong", size: CGSize(width: 392, height: 520), into: directory)

    try render(
        OnboardingView(
            currentAccessibility: { false },
            currentClipboard: { .notAskedYet },
            onOpenAccessibility: {},
            onOpenPrivacy: {},
            onDone: {}
        ),
        named: "izin",
        size: CGSize(width: 560, height: 420),
        into: directory
    )

    try render(
        panel(items: items, toast: ToastMessage(text: "Item dihapus", actionTitle: "Urungkan")),
        named: "panel-urungkan",
        size: CGSize(width: 392, height: 520),
        into: directory
    )

    // Form-based windows do not draw through ImageRenderer, so this one uses a real hosting view.
    let settingsDefaults = UserDefaults(suiteName: "copypaste-snapshot") ?? .standard
    try renderWindow(
        SettingsView(
            settings: AppSettings(defaults: settingsDefaults),
            onClearHistory: {},
            onChangeHotKey: { _ in true }
        ),
        named: "pengaturan",
        size: CGSize(width: 520, height: 640),
        into: directory
    )

    print("Tersimpan di \(directory.path)")
}

@MainActor
func panel(
    items: [ClipItem],
    query: String = "",
    selected: UUID? = nil,
    preview: Bool = false,
    filter: ClipFilter = .all,
    paused: Bool = false,
    toast: ToastMessage? = nil
) -> some View {
    let model = PanelModel()
    model.items = items
    model.isPaused = paused
    model.toast = toast
    model.query = query
    model.filter = filter
    model.showPreview = preview
    if let selected {
        model.selectedID = selected
    }
    return HistoryPanelView(model: model)
        .environment(\.snapshotMode, true)
}

@MainActor
func renderWindow<V: View>(_ view: V, named name: String, size: CGSize, into directory: URL) throws {
    let host = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
    host.frame = NSRect(origin: .zero, size: size)
    host.layoutSubtreeIfNeeded()
    guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
        throw CocoaError(.fileWriteUnknown)
    }
    host.cacheDisplay(in: host.bounds, to: bitmap)
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try png.write(to: directory.appendingPathComponent("\(name).png"))
}

@MainActor
func render<V: View>(_ view: V, named name: String, size: CGSize, into directory: URL) throws {
    let backdrop = Color(red: 0.66, green: 0.72, blue: 0.75)
    let scene = view
        .frame(width: size.width, height: size.height)
        .background(backdrop)
    let renderer = ImageRenderer(content: scene)
    renderer.scale = 2
    guard let cgImage = renderer.cgImage else {
        throw CocoaError(.fileWriteUnknown)
    }
    let bitmap = NSBitmapImageRep(cgImage: cgImage)
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try png.write(to: directory.appendingPathComponent("\(name).png"))
}

let outputPath = CommandLine.arguments.dropFirst().first ?? "build/snapshots"
let outputURL = URL(fileURLWithPath: outputPath, isDirectory: true)

MainActor.assumeIsolated {
    do {
        try renderAll(into: outputURL)
    } catch {
        print("Gagal membuat gambar: \(error)")
        exit(1)
    }
}
