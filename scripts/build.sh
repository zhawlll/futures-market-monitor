#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$TASK_ROOT"
TASK_ARCH="${FUTURES_ARCH:-$(uname -m)}"
case "$TASK_ARCH" in arm64|x86_64) ;; *) echo "Unsupported architecture: $TASK_ARCH" >&2; exit 1 ;; esac
TASK_OUTPUT="${FUTURES_OUTPUT_DIR:-$TASK_ROOT/dist}"
TASK_APP="$TASK_OUTPUT/期货行情监控.app"
mkdir -p .build/module-cache "$TASK_APP/Contents/MacOS" "$TASK_APP/Contents/Resources"
python3 scripts/toolchain-overlay.py
TASK_SWIFT_FLAGS=(-vfsoverlay "$TASK_ROOT/.build/toolchain-overlay.json" -module-cache-path "$TASK_ROOT/.build/vfs-module-cache")
swiftc "${TASK_SWIFT_FLAGS[@]}" scripts/make-icon.swift -o .build/MakeIcon
.build/MakeIcon "$TASK_ROOT"
# Package the generated PNG sizes as ICNS without relying on iconutil.
python3 - <<'PYICON'
from pathlib import Path
import struct
folder = Path('.build/AppIcon.iconset')
entries = [('icp4', 'icon_16x16.png'), ('icp5', 'icon_32x32.png'),
           ('icp6', 'icon_32x32@2x.png'), ('ic07', 'icon_128x128.png'),
           ('ic08', 'icon_256x256.png'), ('ic09', 'icon_512x512.png'),
           ('ic10', 'icon_512x512@2x.png')]
chunks = []
for kind, name in entries:
    data = (folder / name).read_bytes()
    chunks.append(kind.encode('ascii') + struct.pack('>I', len(data) + 8) + data)
body = b''.join(chunks)
Path('.build/AppIcon.icns').write_bytes(b'icns' + struct.pack('>I', len(body) + 8) + body)
PYICON
TASK_FILES=()
while IFS= read -r -d '' TASK_FILE; do
  TASK_FILES+=("$TASK_FILE")
done < <(find Sources/FuturesMonitor -name '*.swift' -print0)
swiftc -swift-version 5 -O -whole-module-optimization -parse-as-library -target "$TASK_ARCH-apple-macosx14.0" \
  "${TASK_SWIFT_FLAGS[@]}" \
  -framework AppKit -framework SwiftUI \
  "${TASK_FILES[@]}" -o "$TASK_APP/Contents/MacOS/FuturesMonitor"
cp Resources/Info.plist "$TASK_APP/Contents/Info.plist"
cp Resources/catalog.json Resources/catalog-eastmoney.json "$TASK_APP/Contents/Resources/"
mkdir -p "$TASK_APP/Contents/Resources/test-fixtures"
cp Tests/Fixtures/* "$TASK_APP/Contents/Resources/test-fixtures/"
cp .build/AppIcon.icns "$TASK_APP/Contents/Resources/"
codesign --force --sign - "$TASK_APP"
TASK_DISPLAY="$TASK_APP"
if [[ "$TASK_APP" == "$HOME/"* ]]; then
  TASK_DISPLAY="~/${TASK_APP#"$HOME/"}"
fi
echo "$TASK_DISPLAY"
