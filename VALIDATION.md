# Version 0.2 validation — original Swift engine

Validated 2026-10-17 using Xcode 26.6 and the iOS 26.5 SDK/runtime.

| Check | Result |
| --- | --- |
| iPhone 17 Pro simulator | 24 tests passed: 19 engine/licensing, 3 model, 2 UI |
| iPad Pro 11-inch (M5) simulator | Same 24 tests passed |
| Clean-export arm64 device Release build, signing disabled | Passed |
| Source and packaged-device-app dependency audit | Passed |

The device build used a fresh staging copy containing only current non-ignored
source files. It contained no `Vendor/Engine`, no prior build products, and no
upstream calculation sources. It required no external dependency compilation or
package downloads. The Release binary links Apple system frameworks/runtimes;
no Qalculate, GMP or MPFR references were found by the audit. The bundled
resources contain the MIT notices and checksum-verified KaTeX assets, and no
legacy definition dataset directory.

Tests cover exact fractions (including an independently reduced arithmetic grid),
integer precision beyond Double's exact range, precedence, implicit multiplication,
scientific notation, bounded overflow, complex arithmetic, compound unit conversion,
result re-entry, elementary derivatives and degree scaling, linear/quadratic roots,
invalid/unsupported expressions, depth/token limits, extreme exponents, bundled
license notices, editor selection, Unicode deletion, and history persistence.
The UI tests verify visibly rendered stacked fractions and reachable landscape
controls. Screenshots in `Screenshots/` are exported from these test attachments.

Latest local evidence (ignored, not source artifacts):

- `.build/Permissive-iPhone-final.xcresult`
- `.build/Permissive-iPad-final.xcresult`
- `.build/Permissive-numeric-final.xcresult` (22 engine/model tests after the final decimal approximation-label fix)
- `.build/permissive-device-final.log`
- `.build/permissive-build-script.log` (clean migration build and payload audit)
- `.build/PermissiveDevice/Build/Products/Release-iphoneos/Qalculate.app`

No physical device or App Store/TestFlight deployment was tested. iOS/iPadOS 17
is the deployment target; runtime validation used 26.5. The audit verifies known
component removal and notices; it does not guarantee App Store approval or
substitute for a legal review of a future release's full distribution terms.
Earlier validation results apply to the historical GPL-based prototype only.
