#!/bin/bash
# Runs the test suite. With only Command Line Tools (no full Xcode), Swift Testing needs
# the framework path and cross-import overlays turned off; the extra flags are skipped otherwise.
set -euo pipefail
cd "$(dirname "$0")/.."

FW=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
if [ -d "$FW/Testing.framework" ]; then
  exec swift test \
    -Xswiftc -F"$FW" \
    -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays \
    -Xlinker -F"$FW" \
    -Xlinker -rpath -Xlinker "$FW" \
    "$@"
fi
exec swift test "$@"
