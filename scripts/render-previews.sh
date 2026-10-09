#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$TASK_ROOT"
mkdir -p .build
python3 scripts/toolchain-overlay.py
TASK_FILES=()
while IFS= read -r -d '' TASK_FILE; do
  if [[ "$TASK_FILE" != "Sources/FuturesMonitor/Application/FuturesMonitorMain.swift" ]]; then TASK_FILES+=("$TASK_FILE"); fi
done < <(find Sources/FuturesMonitor -name '*.swift' -print0)
swiftc -swift-version 5 -parse-as-library -vfsoverlay "$TASK_ROOT/.build/toolchain-overlay.json" \
  -module-cache-path "$TASK_ROOT/.build/vfs-module-cache" -framework AppKit -framework SwiftUI \
  "${TASK_FILES[@]}" scripts/render-previews.swift -o .build/RenderPreviews
.build/RenderPreviews
