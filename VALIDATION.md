# Version 0.4 validation — improper-integral analysis

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
