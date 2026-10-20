#!/usr/bin/env python3
"""Validate local listing limits; --submission also rejects unresolved owner fields."""
import json
from pathlib import Path
import sys
import subprocess
root = Path(__file__).resolve().parent.parent
metadata = json.loads((root / 'Release/app-store-metadata.json').read_text())
for key, limit in [('name',30), ('subtitle',30), ('keywords',100), ('promotional_text',170)]:
    assert 0 < len(metadata[key]) <= limit, f'{key} exceeds {limit} characters'
assert len((root / 'Release/description.txt').read_text()) <= 4000
assert metadata['version'] in (root / 'project.yml').read_text()
assert (root / 'Release/web/privacy/index.html').exists()
assert (root / 'Release/web/support/index.html').exists()
for folder, dimensions in [('iphone-large',(1320,2868)), ('ipad-13',(2064,2752))]:
    files = list((root / 'Release/screenshots' / folder).glob('*.jpg'))
    assert len(files) == 5, f'Missing screenshot set: {folder}'
    for file in files:
        details = subprocess.check_output(['sips','-g','pixelWidth','-g','pixelHeight','-g','hasAlpha',str(file)], text=True)
        assert f'pixelWidth: {dimensions[0]}' in details and f'pixelHeight: {dimensions[1]}' in details, f'Unexpected screenshot size: {file}'
        assert 'hasAlpha: no' in details, f'Alpha channel in {file}'
if '--submission' in sys.argv:
    assert metadata['contact_status'] == 'VERIFIED', 'Mailbox/public URLs are not verified'
    assert metadata['price'] != 'OWNER_SELECTION_REQUIRED', 'Price must be selected'
    assert metadata['availability'] != 'OWNER_SELECTION_REQUIRED', 'Territories must be selected'
print('PASS: local listing lengths and prepared pages; account/publication items remain in RELEASE-CHECKLIST.md')
