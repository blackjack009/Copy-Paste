#!/bin/bash
# Builds build/CopyPaste.app: a release binary, Info.plist and an ad-hoc signature.
# Ad-hoc signing is enough to run on this Mac; it is not notarized for other Macs.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product CopyPaste

APP="build/CopyPaste.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp ".build/release/CopyPaste" "$APP/Contents/MacOS/CopyPaste"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

echo "Dibuat: $APP"
