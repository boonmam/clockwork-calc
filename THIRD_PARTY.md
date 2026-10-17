# Third-party components

This independent iOS/iPadOS port uses the real Qalculate! calculation engine.
It is not an official Qalculate! release. The combined application is licensed
under GPL-3.0-or-later, selecting the later-version option where applicable.

| Component | Version | License | Source |
|---|---|---|---|
| libqalculate | 5.13.1 | GPL-2.0-or-later | https://github.com/Qalculate/libqalculate |
| GMP | 6.3.0 | LGPL-3.0-or-later or GPL-2.0-or-later | https://gmplib.org/ |
| MPFR | 4.2.2 | LGPL-3.0-or-later | https://www.mpfr.org/ |
| KaTeX | 0.16.22 | MIT | https://github.com/KaTeX/KaTeX |

Original copyright notices and complete license texts are retained in the source
archives and `App/Resources/Licenses`. Qalculate definition XML files are copied
unchanged from libqalculate's English templates. KaTeX's JavaScript, stylesheet,
and fonts are included locally with its MIT license; no CDN is contacted.

`Scripts/build-engine.sh` downloads checksum-pinned upstream source archives and
builds static libraries for arm64 iOS and arm64 Simulator. The engine sources are
unmodified; configuration disables external commands and shell-based plotting.
The `Scripts/vendor-math.sh` script verifies and refreshes the KaTeX assets.

The bundled scientific datasets have separate Wikipedia-derived data notices
(CC BY-SA and GFDL) preserved verbatim in `datasets.xml` and `planets.xml`.
Their listed source-article URLs and attribution remain intact; the application's
GPL license does not replace those data licenses.
