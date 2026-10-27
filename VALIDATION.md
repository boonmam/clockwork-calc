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
The archive is `.build/clean-release/.build/Release/ClockworkCalc.xcarchive`.

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
- `engineering-device.log` and `EngineeringDevice/Build/Products/Release-iphoneos/ClockworkCalc.app`.

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
- `improper-device.log` and `ImproperDevice/Build/Products/Release-iphoneos/ClockworkCalc.app`.

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

## Keypad update — 1.0.0 build 7 (2026-10-20)

Moved delete to the top-right keypad position and added a persistent EE button
beside the expression editor. Numeric EE entry retains scientific-notation
precedence (`1/2e3` evaluates to `1/2000`).

Targeted validation passed on iPhone 17 Pro Max and iPad Pro 13-inch (M5),
iOS 26.5: four model tests and two UI tests per device, zero failures.
Checks cover cursor/selection entry, positive and negative exponents, exact
results, delete placement and landscape control reachability. The iPhone
portrait screenshot was visually inspected. Results are in
`.build/Keypad-iPhone-final.xcresult` and `.build/Keypad-iPad.xcresult`.

The build 6 release archive and store screenshots predate this update and must
be regenerated before submission.

## Full-size EE key — build 8 (2026-10-20)

EE now occupies the bottom-row keypad position beside the decimal point,
replacing the comma key. Commas remain available through the text keyboard.
The editor accessory was removed. Targeted iPhone UI tests passed for EE
position and equal key width, positive/negative exponent evaluation, delete
placement and landscape reachability (two tests, zero failures).

## Regrouped keypad — build 9 (2026-10-20)

Scientific functions occupy the first two rows; AC and delete share the top
right. EE sits beside 9; division, multiplication and subtraction align down
the right edge. The conversion key displays Units and remains x in CAS mode.
Two targeted iPhone UI tests passed, covering placement, key width, exponent
evaluation, conversion accessibility label and landscape reachability.
The portrait screenshot was visually inspected. Results: `.build/Keypad9.xcresult`.

## Duo layout — build 12 (2026-10-23)

Built with Xcode 27.1 (27A9275) and the iOS 27.1 SDK. A persistent
NavigationSplitView preserves the calculator hierarchy across window changes.
The outer calculator does not scroll. Only the result panel and expression editor
scroll internally. Wide windows place the editor/results beside the complete
keypad; narrower windows stack them. Key targets remain at least 44 points tall.

On the iOS 27.1 Duo simulator, the unfolded 951 × 669-point window passed
`testWideKeypadFitsWithoutScrolling`: keypad keys were hittable, within the
window, and at least 44 points high. The inner-display screenshot was visually
inspected and is saved as `Release/duo/unfolded-keypad.png`. The folded layout
was also visually inspected. Two further UI tests passed with zero failures:
calculation state across rotation and EE entry/upper-right delete placement.
Logs: `.build/duo-fixed-test.log` and `.build/duo-fixed-regression.log`.

The signed build succeeded, and build 12 was installed and launched successfully
on the user's physical iPhone Duo running iOS 27.2. Physical display appearance
was not independently captured. A full-suite attempt was interrupted; only the
targeted checks above are claimed. App Store/TestFlight distribution remains
unvalidated. The packaged build 6 release archive must be regenerated.

## Integrated expression panel — build 13 (2026-10-23)

Removed the separate expression bar and its placeholder, retaining the editable
expression inside the result panel. Calculator/CAS now uses a menu in the system
toolbar, which appears at the side on the unfolded Duo. The signed device build
succeeded and was installed and launched on the physical Duo. The targeted
EE/delete UI regression passed on the Duo simulator, including selecting
Calculator from the new toolbar menu.

## Blank calculation start — build 14 (2026-10-23)

Removed the welcome/sample expression card. Launch loads history without showing
an unrelated previous result beside an empty editor. AC clears the displayed
result as well as the expression. Signed device build succeeded; the fraction
entry/result UI test passed on the Duo simulator. Installed and launched on the physical Duo; Device Hub confirmed the empty
calculator has no restored sample expression/result. Inspection revealed the
reported input `200/(1/2π150e−6*60)`. Fixed implicit multiplication before a
number following a symbol or group, while keeping separate bare numbers invalid.
All 20 EngineTests passed, including that exact input versus its explicit-product
equivalent. Starting a calculation clears the old result so errors are not shown
alongside an unrelated answer. Multiplication/division retain left-to-right
precedence; parentheses are required to group a denominator product.

## Unit converter — build 15 (2026-10-24)

Added a separate converter with 11 categories, From/To menus, unit swapping,
copyable live results, and a fixed keypad. Uses Apple Foundation Measurement
conversions without adding third-party libraries. Conversion tests passed for
feet/centimeters, Celsius/Fahrenheit, and round trips for every listed unit.
The Duo simulator UI test passed for entering converter mode, live conversion,
swapping units, clearing, and reaching EE. Signed device build succeeded.

## Compact unit converter — build 16 (2026-10-24)

Removed the converter ScrollView, condensed labels and actions into rows, and
reduced value text and padding. Long values scale to one line. Short landscape
windows use side-by-side controls and keypad. The Duo UI test passed with zero
scroll views and category/unit menus, swap/copy controls, and bottom keys inside
the window and hittable. Signed build succeeded and installed on the Duo.

## Single-line unit selectors — build 17 (2026-10-24)

Unit menus take the available row width, keep their text on one line, and scale
long labels down when necessary. The wide layout allocates more width to the
conversion panel. Signed device build succeeded.

## Programmer and Duo mode menu — build 18 (2026-10-27)

Five programmer unit tests passed, covering word widths, full UInt64 entry,
overflow, bitwise operations, signed division/shifts, invalid digits and recovery.
Duo and standard iPhone simulator programmer UI checks passed after correcting
base-selector hit regions. Converter regression passed. Signed device build
installed and launched. Device Hub inspection of build 19 confirms the mode
button appears immediately above History in the Duo side toolbar.

## Quick Calculator widget — build 19 (2026-10-27)

Signed app and widget extension build succeeded; installed and launched on the
physical Duo. Ten standalone Swift calculator checks passed: arithmetic,
decimals, division-by-zero recovery, deletion, fresh entry, operator replacement,
Codable continuation, and page cycling. Run with:

```sh
swiftc Widget/QuickCalculation.swift Tests/quick-widget-tests.swift -o /tmp/fraction-widget-tests
/tmp/fraction-widget-tests
```

Widget actions explicitly use IntentAuthenticationPolicy.alwaysAllowed and do
not open the app. Extension-local defaults isolate scratch calculations from
app history. Lock Screen layout, interaction, and genuinely locked-device
execution have not yet been verified; user setup/testing is pending. No security
settings were weakened.

## Widget removal — build 20 (2026-10-27)

Removed the experimental Quick Calculator extension, scratch engine, and its
standalone tests at user request. Programmer mode and Duo sidebar are retained.
Signed device build succeeded and installed on the physical Duo. Verified the
built app contains no PlugIns directory or embedded widget extension.

## History navigation and toolbar spacing — build 21 (2026-10-27)

Replaced the duplicate history NavigationSplitView sidebar with one calculator
NavigationStack. History is only presented as a sheet with Done, avoiding a
sidebar becoming the root screen when the Duo closes. Added a fixed toolbar
spacer between Mode and History on the Duo. The history dismissal UI regression
passed across portrait/landscape changes on the Duo simulator. Physical folding
while History is open still needs confirmation. Signed build succeeded, installed,
and launched on the Duo; Device Hub shows separate Mode/History buttons and the
full keypad on the outer display.

## Clockwork Calc — build 22 (2026-10-27)

Renamed app, project, scheme, module, bundle identifier, repository, and current
source/documentation references. Preserved third-party license bytes. Added
operator continuation from a completed result, Ans from persisted history,
PasteButton without keyboard focus, and four electrical Quick Calc worksheets.
ModelTests and QuickCalcTests passed on the Duo simulator, including chaining,
history restoration, known formula values, invalid inputs and overflow. UI test
passed for copy/clear/paste with no keyboard, reachable keypad, Quick Calc mode,
and the 6 W power example. Signed device build and distribution audit passed.
Installed and launched on the Duo and copied its existing history into the new
app container. Visually checked the name, paste control, and Quick Calc layout.
Previous release screenshots and archives require regeneration before submission.

## Native editing menu — build 23 (2026-10-27)

Removed the dedicated Paste button. The expression UITextView keeps native
selection and editing menus with an empty input view by default, retaining the
calculator keypad. A keyboard button explicitly enables the system keyboard.
Duo UI regression passed: copy a result, clear, long-press the expression, choose
native Paste, verify the pasted value, no keyboard, and a reachable equals key.
Signed build succeeded and installed/launched on the physical Duo.
