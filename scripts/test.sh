#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$TASK_ROOT"
python3 scripts/toolchain-overlay.py
export CLANG_MODULE_CACHE_PATH="$TASK_ROOT/.build/swift-testing/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$TASK_ROOT/.build/swift-testing/vfs-module-cache"
# SwiftPM does not pass -Xswiftc flags to the manifest compiler. Use the same
# local overlay for both the manifest and the targets.
export FUTURES_TEST_SWIFTC="$(xcrun --find swiftc)"
export FUTURES_TEST_OVERLAY="$TASK_ROOT/.build/toolchain-overlay.json"
TASK_DEVELOPER_DIR="$(xcode-select -p)"
TASK_TEST_FRAMEWORKS="$TASK_DEVELOPER_DIR/Library/Developer/Frameworks"
if [[ ! -d "$TASK_TEST_FRAMEWORKS/Testing.framework" ]]; then
  TASK_TEST_FRAMEWORKS="$TASK_DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/Library/Frameworks"
fi
export FUTURES_TEST_MANIFEST_API="$TASK_ROOT/.build/test-manifest-api"
TASK_MANIFEST_INTERFACE="$TASK_ROOT/.build/PackageDescription-$(uname -m).private.swiftinterface"
if [[ -f "$TASK_MANIFEST_INTERFACE" ]]; then
  mkdir -p "$FUTURES_TEST_MANIFEST_API"
  "$FUTURES_TEST_SWIFTC" -frontend -compile-module-from-interface "$TASK_MANIFEST_INTERFACE" \
    -o "$FUTURES_TEST_MANIFEST_API/PackageDescription.swiftmodule" -module-name PackageDescription \
    -target "$(uname -m)-apple-macosx13.0" -sdk "$(xcrun --show-sdk-path)" \
    -vfsoverlay "$FUTURES_TEST_OVERLAY" -module-cache-path "$SWIFTPM_MODULECACHE_OVERRIDE"
else
  rm -f "$FUTURES_TEST_MANIFEST_API/PackageDescription.swiftmodule"
fi
cat > "$TASK_ROOT/.build/test-swiftc" <<'SH'
#!/bin/bash
exec "$FUTURES_TEST_SWIFTC" -I "$FUTURES_TEST_MANIFEST_API" -vfsoverlay "$FUTURES_TEST_OVERLAY" "$@"
SH
chmod +x "$TASK_ROOT/.build/test-swiftc"
export SWIFT_EXEC="$TASK_ROOT/.build/test-swiftc"
swift test --scratch-path "$TASK_ROOT/.build/swift-testing" \
  --cache-path "$TASK_ROOT/.build/swift-testing/cache" \
  --config-path "$TASK_ROOT/.build/swift-testing/configuration" \
  --security-path "$TASK_ROOT/.build/swift-testing/security" \
  -Xswiftc -F -Xswiftc "$TASK_TEST_FRAMEWORKS" \
  -Xlinker -rpath -Xlinker "$TASK_TEST_FRAMEWORKS" \
  "$@"
