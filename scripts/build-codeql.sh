#!/bin/bash
# Compile the full application for CodeQL without running packaging helpers.
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$TASK_ROOT"
mkdir -p .build/codeql-module-cache
python3 scripts/toolchain-overlay.py
TASK_FILES=()
while IFS= read -r -d '' TASK_FILE; do
  TASK_FILES+=("$TASK_FILE")
done < <(find Sources/FuturesMonitor -name '*.swift' -print0)
swiftc -swift-version 5 -Onone -whole-module-optimization -parse-as-library -target "$(uname -m)-apple-macosx14.0" \
  -vfsoverlay "$TASK_ROOT/.build/toolchain-overlay.json" \
  -module-cache-path "$TASK_ROOT/.build/codeql-module-cache" \
  -framework AppKit -framework SwiftUI \
  "${TASK_FILES[@]}" -o .build/CodeQLFuturesMonitor
