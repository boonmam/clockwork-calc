# Third-party components — version 0.2

The current app uses an original Swift calculation engine and MIT-licensed
KaTeX for offline mathematical display. It contains no libqalculate, GMP, MPFR,
Qalculate definition XML, or Wikipedia-derived scientific datasets.

| Component | Version | License | Origin |
| --- | --- | --- | --- |
| Original app, engine, unit table, icon, tests and build scripts | 0.2 | MIT | This repository; copyright 2026 boonmam |
| KaTeX JavaScript, CSS and fonts | 0.16.22 | MIT | https://github.com/KaTeX/KaTeX/tree/v0.16.22 |
| Foundation, SwiftUI, UIKit, WebKit, system math/runtime | iOS SDK | Apple platform SDK terms | Provided by iOS; no third-party copies bundled |

The KaTeX copyright and full MIT license are retained verbatim in
`App/Resources/Math/LICENSE-KaTeX` and `App/Resources/Licenses/KaTeX-MIT.txt`.
The original app's license is in `LICENSE` and the bundled `App-MIT.txt`.
Both notices are accessible inside the app under About → License notices.
`Scripts/vendor-math.sh` verifies the upstream npm archive with a pinned SHA-512
before refreshing the renderer. No npm development dependencies are bundled.

## Replacement provenance

`App/Engine/NativeMath.swift` was written for this project from ordinary
mathematical identities and parsing techniques. It does not translate or copy
libqalculate/GMP/MPFR implementations. The small unit table was independently
written from conventional SI and international unit definitions. No upstream
function descriptions, definitions, datasets, or graphics were retained.
The existing original SwiftUI shell and newly written engine are MIT-licensed.
The display name is now Fraction Lab to distinguish it from Qalculate.

## Historical versions

Commits through `bdb3e05` describe the earlier GPL-based prototype and retain
their original licensing. This change does not relicense third-party code or
rewrite Git history. Do not ship builds, dependency archives, or resources from
those historical versions as part of version 0.2. The old ignored `Vendor/Engine`
and `.build/engine` folders, if present in a developer's checkout, are unused.
Build from a clean export/clone to verify there is no dependency on those files.

## Distribution scope

The replacement removes the identified copyleft dependencies from the current
application. Retain the MIT notices when distributing it. This is a technical
inventory and provenance record, not an Apple approval or a legal opinion.
Apple signing, privacy disclosures, branding availability, and App Review remain
separate release requirements. Repository and build-target identifiers retain
`qalculate-ios` / `Qalculate` for continuity; they do not imply upstream affiliation.
