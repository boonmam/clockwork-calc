# Version 0.3 validation — offline CAS and matrices

Validated 2026-10-17/18 with Xcode 26.6 and the iOS 26.5 SDK/runtime.

| Check | Result |
| --- | --- |
| iPhone 17 Pro simulator | 36 tests passed: 10 CAS, 19 native engine/licensing, 3 model, 4 UI |
| iPad Pro 11-inch (M5) simulator | Same 36 tests passed |
| Offline CAS adapter checks under Node | 45 checks passed |
| Clean-export arm64 device Release build (unsigned) | Passed |
| Packaged-app dependency, license, and asset audit | Passed |

The CAS integration tests use the actual WebKit worker and packaged Nerdamer
bundle. They cover symbolic algebra, matrix inverse/product/determinant and
row reduction, linear systems, cubic roots, symbolic/definite/numerical integrals,
differentiation of an antiderivative, limits, unresolved integrals, decimal
matrices, singular/malformed matrices, poles, invalid scripts, and stored modes.
A deliberately infinite worker verifies the native deadline; cancellation and a
subsequent successful calculation verify recovery. The UI tests exercise CAS
entry, rendered matrix/integral results, the matrix grid, fraction display, and
landscape controls. Screenshot inspection prompted a compact side-by-side
expression/result layout to prevent an integral fraction being clipped on iPhone.

The adapter checks also exercise reversed integration bounds, oscillatory
quadrature, symbolic determinants, matrix powers/transposes, rank, singularities
between sample points, nonlinear-system rejection, and input limits.

Evidence stays in ignored `.build/` paths:

- `CAS-iPhone-final.xcresult`
- `CAS-iPad-final.xcresult`
- `CAS-layout.xcresult` (iPhone UI recheck after compact equation layout fix)
- `CAS-guard.xcresult` (CAS tests after explicit system-syntax guard)
- `cas-device.log` and `CASDevice/Build/Products/Release-iphoneos/Qalculate.app`

Screenshots are exported from XCTest attachments. Physical device execution and
App Store/TestFlight deployment have not been tested. The deployment target is
17+, while runtime validation used 26.5. These tests establish the listed cases,
not completeness or correctness for all possible CAS expressions. Numerical
integration requires finite continuous real intervals; the sampling checks are
not a proof of convergence. General solving can return incomplete results.

The device build used a clean export of the staged source, excluding all ignored
legacy libraries and prior build products. The payload audit verified the exact
Nerdamer/decimal.js/KaTeX assets and notices and found no legacy calculation
library linkage or datasets.
