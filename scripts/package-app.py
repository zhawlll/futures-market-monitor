#!/usr/bin/env python3
"""Package a verified local app with UTF-8 names and Unix permissions."""
from pathlib import Path
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'dist' / '期货行情监控.app'


def main():
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(APP)], check=True)
    subprocess.run(['plutil', '-lint', str(APP / 'Contents/Info.plist')], check=True)
    architectures = subprocess.check_output(
        ['lipo', '-archs', str(APP / 'Contents/MacOS/FuturesMonitor')], text=True
    ).split()
    if architectures == ['arm64']:
        label = 'arm64'
    elif architectures == ['x86_64']:
        label = 'x86_64'
    elif set(architectures) == {'arm64', 'x86_64'}:
        label = 'universal'
    else:
        raise ValueError(f'Unsupported architectures: {architectures}')
    paths = sorted(APP.rglob('*'))
    for path in paths:
        if path.is_symlink():
            raise ValueError(f'Symlink is not supported in app export: {path.relative_to(APP)}')
    destination = APP.parent / f'期货行情监控-macOS-{label}.zip'
    with zipfile.ZipFile(destination, 'w', zipfile.ZIP_DEFLATED) as archive:
        archive.write(APP, APP.name + '/')
        for path in paths:
            archive.write(path, path.relative_to(APP.parent).as_posix())
    print(f'{destination.name}: {sum(path.is_file() for path in paths)} files; architecture {label}')


if __name__ == '__main__':
    main()
