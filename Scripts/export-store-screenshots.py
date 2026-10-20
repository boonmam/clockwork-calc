#!/usr/bin/env python3
"""Export native XCTest captures as opaque, unresized App Store JPEGs."""
import json
from pathlib import Path
import subprocess
import sys
base, out = map(Path, sys.argv[1:3])
out.mkdir(parents=True, exist_ok=True)
names = {'CAS matrix':'02-matrix', 'CAS integral':'03-integral',
         'Symbolic engineering':'04-engineering', 'Improper integral':'05-improper-integral'}
for test in json.loads((base / 'manifest.json').read_text()):
    for attachment in test['attachments']:
        name = attachment.get('suggestedHumanReadableName', '')
        target = next((v for k,v in names.items() if name.startswith(k)), None)
        if 'testFractionEntryAndResult' in test['testIdentifier']:
            target = '01-fractions'
        if target:
            subprocess.run(['sips','-s','format','jpeg','-s','formatOptions','90',
                            str(base / attachment['exportedFileName']), '--out',
                            str(out / (target + '.jpg'))], check=True, stdout=subprocess.DEVNULL)
assert len(list(out.glob('*.jpg'))) == 5
print(f'Exported five native-resolution screenshots to {out}')
