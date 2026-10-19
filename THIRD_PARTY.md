# Third-party components — version 0.4

| Component | Version | License | Origin |
| --- | --- | --- | --- |
| Original Swift app/engine, CAS adapter, quadrature and improper-limit analysis, icon and scripts | 0.4 | MIT | This repository; copyright 2026 boonmam |
| Nerdamer complete browser bundle | 2.0.0 | Apache-2.0 | https://github.com/jiggzson/nerdamer / https://www.npmjs.com/package/nerdamer/v/2.0.0 |
| decimal.js embedded in Nerdamer's browser bundle | 10.6.0 | MIT | https://github.com/MikeMcl/decimal.js |
| KaTeX JavaScript, stylesheet and fonts | 0.16.22 | MIT | https://github.com/KaTeX/KaTeX/tree/v0.16.22 |
| Apple system frameworks and Swift runtime | iOS SDK | Apple platform SDK terms | Provided by iOS |

The Nerdamer browser bundle is **unmodified** from the checksum-pinned npm
archive. The bundle's extracted `bundle.js.LICENSE.txt` identifies decimal.js
10.6.0 and retains its copyright notice. Complete Apache-2.0 and decimal.js MIT
license texts are in `App/Resources/Licenses`; no separate NOTICE file was
present in the upstream Nerdamer 2.0.0 npm package. The app's MIT license does
not replace the licenses of these third-party files.

The original `adapter.js` and `host.html` files are separate from the vendor
bundle. `Scripts/vendor-cas.py` verifies both upstream tarballs using pinned
SHA-512 hashes and records SHA-256 hashes for vendored files and notices in
`ThirdParty/CAS.sha256.json`. Only the complete browser bundle and notices ship;
Node packages, development dependencies, and build tools do not ship in the app.

KaTeX notices remain in `Math/LICENSE-KaTeX` and `Licenses/KaTeX-MIT.txt`.
`Scripts/vendor-math.sh` verifies its upstream archive's pinned SHA-512. The
original app license is also bundled. All four full license texts can be read
inside the app under About → License notices.

CAS uses local WebKit workers with network access blocked by Content Security
Policy. A fresh worker is created per calculation, and the app terminates it on
completion, cancellation, or deadline. No remote service or downloaded runtime
code is used. Apple system frameworks are linked through the SDK.

## Earlier engines and historical licenses

The current app contains no libqalculate, GMP, MPFR, Qalculate definition XML,
or Wikipedia-derived scientific datasets. The original Swift engine was written
from ordinary mathematical identities and parsing techniques, independently of
those implementations. Its small unit table contains conventional conversion
factors, not a copied Qalculate dataset.

Commits through `bdb3e05` retain the GPL-based prototype and its original notices.
Version 0.2's original code is MIT. Version 0.3 adds the permissively licensed CAS
above; it does not relicense any upstream code or rewrite Git history. Old ignored
`Vendor/Engine` and `.build/engine` files are unused and not part of current builds.
The build script cleans old products to prevent stale resources from being shipped.

The inventory and packaged-payload audit identify known dependencies and notices;
they are not an Apple approval or a legal opinion. Signing, branding availability,
privacy disclosures, and App Review remain separate release steps.

Version 0.4 adds original MIT-licensed improper-integral analysis in
`App/Resources/CAS/improper.js`. No new third-party dependency or vendor changes
were introduced.
