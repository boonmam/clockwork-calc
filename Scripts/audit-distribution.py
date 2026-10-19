#!/usr/bin/env python3
"""Check this project's known dependency boundary, including an optional built .app."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
errors = []

def check(condition, message):
    if not condition:
        errors.append(message)

project = (root / 'project.yml').read_text() + (root / 'Qalculate.xcodeproj/project.pbxproj').read_text()
for marker in ['-lqalculate', '-lgmp', '-lmpfr', 'Vendor/Engine', 'QalculateBridge', 'Resources/Definitions', 'SWIFT_OBJC_BRIDGING_HEADER']:
    check(marker not in project, f'Legacy build dependency: {marker}')
check(not (root / 'Scripts/build-engine.sh').exists(), 'Legacy dependency downloader remains')
check(not list((root / 'App').rglob('*.mm')), 'Unexpected Objective-C++ source')
check(not list((root / 'App').rglob('*.a')), 'Unexpected static library in app source')
check((root / 'LICENSE').read_bytes() == (root / 'App/Resources/Licenses/App-MIT.txt').read_bytes(), 'App license is out of sync')
manifest = json.loads((root / 'ThirdParty/KaTeX.sha256.json').read_text())

def resources(base):
    check(not (base / 'Definitions').exists(), f'Legacy datasets present: {base}')
    notices = base / 'Licenses'
    check(notices.exists(), f'Missing license directory: {base}')
    if notices.exists():
        check({p.name for p in notices.iterdir()} == {'App-MIT.txt', 'KaTeX-MIT.txt', 'Nerdamer-Apache-2.0.txt', 'Decimal-MIT.txt'}, f'Unexpected license inventory: {base}')
        for name in ['App-MIT.txt', 'KaTeX-MIT.txt', 'Decimal-MIT.txt']:
            file = notices / name
            check(file.exists() and 'Permission is hereby granted' in file.read_text(), f'Missing MIT notice: {file}')
    cas_manifest = json.loads((root / 'ThirdParty/CAS.sha256.json').read_text())
    for name, digest in cas_manifest.items():
        path = base / name
        check(path.exists() and hashlib.sha256(path.read_bytes()).hexdigest() == digest, f'Modified/missing CAS dependency or license: {path}')
    cas = base / 'CAS'
    check(cas.exists(), f'Missing CAS resources: {base}')
    if cas.exists():
        check({p.name for p in cas.iterdir()} == {'nerdamer.js', 'bundle.js.LICENSE.txt', 'adapter.js', 'improper.js', 'host.html'}, f'Unexpected CAS asset inventory: {base}')
    math = base / 'Math'
    check(math.exists(), f'Missing renderer: {base}')
    if math.exists():
        actual = {str(p.relative_to(math)) for p in math.rglob('*') if p.is_file()}
        check(actual == set(manifest) | {'index.html'}, f'Unexpected renderer asset inventory: {base}')
        for name, digest in manifest.items():
            path = math / name
            check(path.exists() and hashlib.sha256(path.read_bytes()).hexdigest() == digest, f'Modified/missing KaTeX asset: {path}')
        license_file = notices / 'KaTeX-MIT.txt'
        check(license_file.exists() and license_file.read_bytes() == (math / 'LICENSE-KaTeX').read_bytes(), 'KaTeX notice mismatch')

resources(root / 'App/Resources')
if len(sys.argv) > 1:
    app = Path(sys.argv[1]).resolve()
    check(app.is_dir(), f'App not found: {app}')
    if app.is_dir():
        resources(app)
        import plistlib
        with (app / 'Info.plist').open('rb') as stream:
            info = plistlib.load(stream)
        check(info['CFBundleDisplayName'] == 'Fraction Lab', 'Outdated app branding')
        binary = app / info['CFBundleExecutable']
        executables = [binary, *app.rglob('*.dylib')]
        for executable in executables:
            linkage = subprocess.check_output(['otool', '-L', str(executable)], text=True)
            symbols = subprocess.check_output(['nm', '-a', str(executable)], text=True, stderr=subprocess.DEVNULL)
            check(not re.search(r'lib(qalculate|gmp|mpfr)', linkage, re.I), f'Legacy dynamic library linked: {executable}')
            check(not re.search(r'(__gmp|_mpfr_|_ZN\d*Calculator|_ZN\d*MathStructure)', symbols), f'Legacy engine symbols found: {executable}')
        print(f'Checked {len(executables)} executable/dylib payload(s)')
        check(not list(app.rglob('*.a')), 'Static library unexpectedly packaged as a resource')
if errors:
    for error in errors:
        print('FAIL:', error, file=sys.stderr)
    sys.exit(1)
print('PASS: known dependency boundary, license notices, and pinned CAS/renderer assets' + ('; built payload/linkage' if len(sys.argv) > 1 else ''))
