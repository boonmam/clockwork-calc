# Release candidate 1.0.0 (6)

Prepared October 19, 2026 with Xcode 26.6 / iOS 26.5.

- iPhone 17 Pro Max: full 50-test rerun passed. The first run during concurrent
  simulator startup timed out in the CAS history test (both assertions in that
  test failed); the complete rerun passed with fewer simulators running.
- iPad Pro 13-inch (M5): full 50-test suite passed.
- Ten native-size App Store JPEG screenshots exported and visually inspected.
  The first iPad matrix capture preceded WebKit's composited frame; it was
  recaptured after adding a presentation delay to the UI test.
- Clean staged-source unsigned device archive passed dependency, privacy-manifest,
  icon, license, and pinned asset audits. Icon is opaque 1024 × 1024 RGB.
- Listing field lengths and screenshot sizes/alpha checks pass locally.

Evidence: `.build/Release-iPhone-final.xcresult`, `.build/Release-iPad.xcresult`,
`.build/Release-iPad-capture.xcresult`, and `.build/release-archive-final.log`.
The archive is `.build/clean-release/.build/Release/FractionLab.xcarchive`.

No signed distribution archive, App Store Connect validation/upload, TestFlight
installation, physical-device testing, or public release is claimed. See
`Release/RELEASE-CHECKLIST.md` for the account, hosting, and owner-selection steps.
The source tree was unchanged in calculation behavior for this release preparation.

# Version 0.5 validation — engineering notation

Validated 2026-10-19 with Xcode 26.6 and the iOS 26.5 runtime.

- Full 48-test suites passed on iPhone 17 Pro and iPad Pro 11-inch (M5).
- After final formatting refinements, all 8 notation tests and the engineering
  UI test passed on both devices: 50 distinct tests covered across these runs.
- Clean-export unsigned arm64 device Release build and packaged dependency/license
  audit passed. No third-party dependencies changed.

Notation checks cover powers of three, zero, negative numbers, boundary scales,
very small/large values, preservation of decimal digits without Double conversion,
SI prefixes and fallback outside their range, scientific TeX conversion, identifier
and subscript preservation, expression precedence, complex values, units, CAS
matrices and symbolic coefficients, canonical result reuse, old history decoding,
notation recall, and migration of the old Exact/Decimal preference.

UI tests select both new options and inspect the formatted values. Exported
screenshots were visually checked, including the micro symbol and the longer
format menu label on iPhone. Copy/Ans/Use result intentionally retain canonical
numeric expressions rather than display-only SI symbols.

Evidence in ignored `.build/`:

- `Engineering-iPhone.xcresult` and `Engineering-iPad.xcresult`: full suites.
- `Engineering-iPhone-final.xcresult` and `Engineering-iPad-final.xcresult`:
  final notation and UI checks.
- `engineering-device.log` and `EngineeringDevice/Build/Products/Release-iphoneos/Qalculate.app`.

Physical-device execution and App Store/TestFlight distribution remain untested.

## Previous version 0.4 validation — improper-integral analysis

Validated 2026-10-19 with Xcode 26.6 and the iOS 26.5 SDK/runtime.

| Check | Result |
| --- | --- |
| iPhone 17 Pro simulator | 41 tests passed: 14 CAS, 19 native engine/licensing, 3 model, 5 UI |
| iPad Pro 11-inch (M5) simulator | Same 41 tests passed |
| Offline CAS adapter checks under Node | 77 checks passed |
| Clean-export arm64 device Release build (unsigned) | Passed |
| Packaged-app dependency, license, and asset audit | Passed |

The CAS tests use the actual WebKit worker and packaged Nerdamer bundle plus the
original MIT improper-integral module. New checks cover exponential tails,
singular endpoints, separately convergent interior components, both infinite
bounds, reversed bounds, numeric results, divergence without principal-value
cancellation, and unsupported convergence analysis. Symbolic failures are
reported as unresolved rather than mistaken for divergence or convergence.

The adapter checks also cover logarithmic endpoints, polynomial-times-exponential
tails, absolute-value branches, removable holes preserved before simplification,
and a pole at an irrational quadratic root whose limit analysis remains unresolved.
The module deliberately avoids Nerdamer's general limit routine: exploratory
checks found incorrect answers for transformed square-root endpoint expressions.
It uses explicit elementary limit rules and verifies each primitive by differentiation.

Existing tests retain coverage of symbolic algebra, matrix operations, systems,
finite quadrature, input bounds, history, worker cancellation/deadline/recovery,
fraction typesetting, matrix entry, and landscape controls. The new UI test enters
an infinite-bound integral, checks the result, and opens its full calculation notes.
Screenshots verify the infinity symbol and readable result in dark mode.

Evidence stays in ignored `.build/` paths:

- `Improper-iPhone.xcresult` and `Improper-iPad.xcresult` — full suites.
- `Improper-iPhone-guard.xcresult` and `Improper-iPad-guard.xcresult` — CAS rechecks
  after wrapping unclassified symbolic failures as unresolved.
- `Improper-iPhone-UI.xcresult` and `Improper-iPad-UI.xcresult` — UI rechecks after
  making all calculation notes accessible by tapping the information label.
- `improper-device.log` and `ImproperDevice/Build/Products/Release-iphoneos/Qalculate.app`.

Physical device execution and App Store/TestFlight deployment have not been
tested. The deployment target is iOS 17+, while runtime validation used 26.5.
These tests establish the listed cases, not general CAS correctness. Improper
integration supports a bounded elementary class; e.g. the Gaussian integral over
an infinite interval remains unresolved. Finite quadrature's samples are not a
universal continuity proof or error guarantee. General solving can be incomplete.

The device build used a clean export of staged source, excluding ignored legacy
libraries and prior build products. The payload audit verified exact pinned
Nerdamer/decimal.js/KaTeX assets and notices and found no legacy calculation
library linkage or datasets. No additional third-party dependency was introduced.
