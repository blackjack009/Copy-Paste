# CopyPaste

Clipboard history for macOS, similar to Win+V on Windows. The app runs in the menu bar. Its icon is at the top right of the screen, and the app does not appear in the Dock.

## Features

- History of text, links, code, hex colors, images, and files
- Search and filters: All, Text, Links, Images, Files
- Pin items so they are not removed
- Preview item contents
- Delete items with undo
- The panel shortcut can be changed, default ⌃⌘V
- Pause recording; items from password managers are skipped
- Limit the number of items, and delete old items automatically after a number of days
- Launch at login

## Requirements

- macOS 14 or later
- Swift 5.10 or later (tested with Swift 6.2)
- Command Line Tools are enough; Xcode is not needed. If you don't have them, run `xcode-select --install`.

## Building and running

Build the app:

```bash
./scripts/make-app.sh
```

Open the app:

```bash
open build/CopyPaste.app
```

The first time you open it, the **Permissions** window appears. After that, press ⌃⌘V or click the clipboard icon in the menu bar.

## Permissions

| Permission | Used for | If not granted |
|---|---|---|
| Clipboard access from other apps (macOS 15.4 and later) | Reading what you copy | History is not recorded. When macOS asks, choose **Allow**. |
| Accessibility | Automatic paste and placing the panel near the text cursor | Items are still copied; press ⌘V yourself. The panel appears near the mouse pointer. |

The ⌃⌘V shortcut does not need any extra permission.

## Panel shortcuts

| Key | Action |
|---|---|
| ↑ ↓ | Select an item |
| ↵ | Paste |
| ⇧↵ | Paste as plain text |
| → | Open the preview (when the cursor is at the end of the search text) |
| ← | Close the preview |
| ⌘1 … ⌘9 | Paste item 1 to 9 |
| ⌘P | Pin or unpin an item |
| ⌘⌫ | Delete an item |
| ⌘Z | Undo the last deletion |
| Tab / ⇧Tab | Switch filter |
| Esc | Close the preview, then the panel |

Open Settings from the menu bar with **Settings…**, or from the gear button at the bottom of the panel.

## Data and privacy

- History is stored in `~/Library/Application Support/CopyPaste/` (`history.json` and the `blobs/` folder). This data is **not encrypted**.
- Items that a password manager marks as secret are skipped. You can change this in Settings.
- This project does not use the network.

## Project structure

- `Sources/CopyPasteKit`: models, clipboard recorder, storage, and paste. No UI.
- `Sources/CopyPasteUI`: panel, preview, settings, and the permissions window (SwiftUI).
- `Sources/CopyPaste`: menu bar app, global shortcut, and panel control.
- `Sources/CopyPasteSnapshot`: renders panel images from sample data.
- `Tests/CopyPasteKitTests`: unit tests.
- `scripts/`: scripts for running the tests and building the `.app`.

## Development

Run the tests:

```bash
./scripts/test.sh
```

On Command Line Tools without Xcode, Swift Testing needs extra flags. `scripts/test.sh` already sets them.

Render the panel with sample data (this does not read your real clipboard):

```bash
swift run CopyPasteSnapshot build/snapshots
```

## Limitations

- A build from `make-app.sh` is only ad-hoc signed. It is enough to run on the Mac that built it, but it is not notarized for distribution.
- Undo only works for the last deletion.
- History is not encrypted.
- How a shortcut behaves when another app uses the same shortcut depends on macOS.

## License

MIT. See [LICENSE](LICENSE).
