#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/.build/katex"
curl --fail --location --retry 3 https://registry.npmjs.org/katex/-/katex-0.16.22.tgz -o "$ROOT/.build/katex/package.tgz"
python3 - "$ROOT/.build/katex/package.tgz" <<'PY'
import sys, hashlib, base64
assert base64.b64encode(hashlib.sha512(open(sys.argv[1], 'rb').read()).digest()).decode() == 'XCHRdUw4lf3SKBaJe4EvgqIuWwkPSo9XoeO8GjQW94Bp7TWv9hNhzZjZ+OH9yf1UmLygb7DIT5GSFQiyt16zYg=='
PY
tar -xf "$ROOT/.build/katex/package.tgz" -C "$ROOT/.build/katex"
cp "$ROOT/.build/katex/package/dist/katex.min.js" "$ROOT/.build/katex/package/dist/katex.min.css" "$ROOT/App/Resources/Math/"
cp -R "$ROOT/.build/katex/package/dist/fonts" "$ROOT/App/Resources/Math/"
cp "$ROOT/.build/katex/package/LICENSE" "$ROOT/App/Resources/Math/LICENSE-KaTeX"
