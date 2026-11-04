// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "CopyPaste",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CopyPaste", targets: ["CopyPaste"]),
    ],
    targets: [
        // Models, storage, clipboard capture and paste. No UI.
        .target(name: "CopyPasteKit"),
        // SwiftUI views shared by the app and the snapshot tool.
        .target(name: "CopyPasteUI", dependencies: ["CopyPasteKit"]),
        // The menu bar app.
        .executableTarget(name: "CopyPaste", dependencies: ["CopyPasteKit", "CopyPasteUI"]),
        // Renders the panel states to PNG with sample data. Never reads the real clipboard.
        .executableTarget(name: "CopyPasteSnapshot", dependencies: ["CopyPasteKit", "CopyPasteUI"]),
        .testTarget(name: "CopyPasteKitTests", dependencies: ["CopyPasteKit"]),
    ]
)
