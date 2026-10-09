#!/bin/bash
# Compile the full application for CodeQL without running packaging helpers.
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$TASK_ROOT"
mkdir -p .build/codeql-module-cache
if [[ ! -f .build/toolchain-overlay.json ]]; then
  python3 scripts/toolchain-overlay.py
fi
TASK_ARCH="${FUTURES_ARCH:-$(uname -m)}"
case "$TASK_ARCH" in arm64|x86_64) ;; *) echo "Unsupported architecture: $TASK_ARCH" >&2; exit 1 ;; esac
TASK_FILES=()
while IFS= read -r -d '' TASK_FILE; do
  TASK_FILES+=("$TASK_FILE")
done < <(find Sources/FuturesMonitor -name '*.swift' -print0)
swiftc -swift-version 5 -Onone -whole-module-optimization -parse-as-library -target "$TASK_ARCH-apple-macosx14.0" \
  -vfsoverlay "$TASK_ROOT/.build/toolchain-overlay.json" \
  -module-cache-path "$TASK_ROOT/.build/codeql-module-cache" \
  -framework AppKit -framework SwiftUI \
  "${TASK_FILES[@]}" -o .build/CodeQLFuturesMonitor
