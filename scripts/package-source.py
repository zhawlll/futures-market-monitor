#!/usr/bin/env python3
"""Export an explicit public-file allowlist without requiring a Git repository."""
from pathlib import Path
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DIRECTORIES = ('Sources', 'Resources', 'Tests', 'scripts', 'doc', '.github')
FILES = ('Package.swift', 'AGENTS.md', 'README.md', 'APP_README.md', 'APP_VERIFICATION.md', 'LICENSE', 'THIRD_PARTY_NOTICES.md',
         'CONTRIBUTING.md', 'SECURITY.md', 'CHANGELOG.md')
SKIP = {'__pycache__', '.DS_Store', 'AppIcon.icns'}


def public_files():
    result = [ROOT / name for name in FILES]
    for name in DIRECTORIES:
        for path in (ROOT / name).rglob('*'):
            if any(part in SKIP for part in path.relative_to(ROOT).parts):
                continue
            if path.is_symlink():
                raise ValueError(f'Symlink is not allowed in public export: {path.relative_to(ROOT)}')
            if path.is_file():
                result.append(path)
    for path in result:
        if path.is_symlink() or not path.resolve().is_relative_to(ROOT):
            raise ValueError(f'Outside-root/symlink file in public allowlist: {path.relative_to(ROOT)}')
        if not path.is_file():
            raise FileNotFoundError(path)
        if path.suffix.lower() in {'.p12', '.p8', '.pem', '.key', '.mobileprovision', '.provisionprofile', '.pyc', '.log'} or path.name.startswith('.env'):
            raise ValueError(f'Private/generated file in public allowlist: {path.relative_to(ROOT)}')
    return sorted(result)


def main():
    paths = public_files()
    prefix = 'futures-monitor-source'
    destination = ROOT / 'dist' / (prefix + '.zip')
    destination.parent.mkdir(exist_ok=True)
    manifest = [{'path': str(path.relative_to(ROOT)), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()} for path in paths]
    with zipfile.ZipFile(destination, 'w', zipfile.ZIP_DEFLATED) as archive:
        for path in paths:
            archive.write(path, prefix + '/' + str(path.relative_to(ROOT)))
        archive.writestr(prefix + '/SOURCE_MANIFEST.json', json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    display = str(destination)
    if destination.is_relative_to(Path.home()):
        display = '~/' + str(destination.relative_to(Path.home()))
    print(f'{display}: {len(paths)} files; no Git operations performed')


if __name__ == '__main__':
    main()
