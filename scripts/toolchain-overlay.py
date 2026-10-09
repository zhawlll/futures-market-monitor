"""Work around stale toolchain declarations using a build-local VFS overlay."""
import json
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
directory = root / ".build"
directory.mkdir(exist_ok=True)
compiler = Path(subprocess.check_output(["xcrun", "--find", "swiftc"], text=True).strip())
toolchain_usr = compiler.parent.parent
legacy = toolchain_usr / "include/swift/module.modulemap"
current = legacy.with_name("bridging.modulemap")
roots = []
if legacy.exists() and current.exists() and "module SwiftBridging" in legacy.read_text() and "module SwiftBridging" in current.read_text():
    empty = directory / "empty.modulemap"
    empty.write_text("// Duplicate legacy SwiftBridging module map hidden for this build only.\n")
    roots.append({"type": "file", "name": str(legacy), "external-contents": str(empty)})

# Some CLT installations retain pre-Swift-6 private manifest interfaces next
# to the matching Swift 6 public interfaces and dynamic library. For manifest
# compilation use that architecture's public declarations through a local VFS.
manifest = toolchain_usr / "lib/swift/pm/ManifestAPI/PackageDescription.swiftmodule"
for architecture in ("arm64", "x86_64"):
    public = manifest / (architecture + "-apple-macos.swiftinterface")
    private = manifest / (architecture + "-apple-macos.private.swiftinterface")
    replacement = directory / ("PackageDescription-" + architecture + ".private.swiftinterface")
    if public.exists() and private.exists() and "swiftLanguageModes" in public.read_text() and "swiftLanguageModes" not in private.read_text():
        replacement.write_text(public.read_text())
        roots.append({"type": "file", "name": str(private), "external-contents": str(replacement)})
    else:
        replacement.unlink(missing_ok=True)
(directory / "toolchain-overlay.json").write_text(json.dumps({"version": 0, "roots": roots}))
