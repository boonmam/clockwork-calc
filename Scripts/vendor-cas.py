#!/usr/bin/env python3
"""Vendor pinned, unmodified Nerdamer browser bundle and complete dependency notices."""
import base64
import hashlib
import json
from pathlib import Path
import tarfile
import urllib.request

root=Path(__file__).resolve().parent.parent
cache=root/'.build/cas-vendor'
cache.mkdir(parents=True,exist_ok=True)
packages={
    'nerdamer': ('2.0.0','DNzv0SHM/OgzKxtA1VWHaySBnoSms2fQeuzULkqr/PkUn5kYXWb1cUD5Djmdgdk/CJtNKii8pPYccT8gvJif1g=='),
    'decimal.js': ('10.6.0','YpgQiITW3JXGntzdUmyUR1V812Hn8T1YVXhCu+wO3OpS4eU9l4YdD3qjyiKdV6mvV29zapkMeD390UVEf2lkUg==')
}
contents={}
for name,(version,digest) in packages.items():
    data=urllib.request.urlopen(f'https://registry.npmjs.org/{name}/-/{name}-{version}.tgz').read()
    if base64.b64encode(hashlib.sha512(data).digest()).decode()!=digest:
        raise RuntimeError(f'{name} integrity mismatch')
    path=cache/(name+'.tgz');path.write_bytes(data)
    with tarfile.open(path) as archive:
        contents[name]={item.name:archive.extractfile(item).read() for item in archive.getmembers() if item.isfile()}
cas=root/'App/Resources/CAS';licenses=root/'App/Resources/Licenses'
cas.mkdir(parents=True,exist_ok=True)
(cas/'nerdamer.js').write_bytes(contents['nerdamer']['package/dist/bundle.js'])
(cas/'bundle.js.LICENSE.txt').write_bytes(contents['nerdamer']['package/dist/bundle.js.LICENSE.txt'])
(licenses/'Nerdamer-Apache-2.0.txt').write_bytes(contents['nerdamer']['package/LICENSE.md'])
(licenses/'Decimal-MIT.txt').write_bytes(contents['decimal.js']['package/LICENCE.md'])
paths=[cas/'nerdamer.js',cas/'bundle.js.LICENSE.txt',licenses/'Nerdamer-Apache-2.0.txt',licenses/'Decimal-MIT.txt']
manifest={str(p.relative_to(root/'App/Resources')):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
(root/'ThirdParty/CAS.sha256.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Verified Nerdamer 2.0.0 (Apache-2.0) and embedded decimal.js 10.6.0 (MIT).')
