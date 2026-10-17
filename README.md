# Fraction Lab for iPhone and iPad

An offline SwiftUI calculator with an **original MIT-licensed Swift engine**,
dark mode, history, and textbook-style stacked fractions. Version 0.2 replaces
the earlier Qalculate-based prototype; it no longer contains or links Qalculate,
GMP, MPFR, or their definition datasets. It is not an official Qalculate product.
The repository and Xcode target names remain unchanged for continuity.

## Supported calculations

- Exact reduced fractions within signed 64-bit numerator/denominator limits.
  Overflow falls back to approximately 15 significant digits, visibly marked
  approximate. Decimal input is exact when its fraction fits the supported range.
- Arithmetic, parentheses, unary signs, right-associative powers, implicit
  multiplication (`2(3+4)`, `5 ft`), scientific notation; constants `pi`, `π`, `e`, `i`.
- Real scientific functions: `sin`, `cos`, `tan`, `asin`, `acos`, `atan`, `ln`,
  `log` (base 10), `exp`, `sqrt`, `abs`, `floor`, `ceil`. RAD/DEG controls angles.
- Complex arithmetic, powers, square roots and absolute values. Other functions
  require real arguments; complex output is currently marked approximate.
- Dimension-checked units and compound conversions, including `5 ft + 3 in to cm`
  and `60 km/h to m/s`. Unit names are case-sensitive; supported units:
  `m cm mm km in ft yd mi kg g mg lb oz s ms min h day K L mL Hz N Pa J W`.
  Kelvin is supported; affine Celsius/Fahrenheit conversions are not.
- Symbolic `diff(expression, x)` with sum/product/quotient/chain rules, constant
  numeric powers, `sin cos tan ln exp sqrt`. Derivatives use the selected angle
  mode. Other names act as symbolic constants; domains/singularities are not tracked.
- `solve(equation, x)` for real-coefficient, dimensionless linear/quadratic
  polynomials, including complex quadratic roots. A root set cannot be reused
  as a scalar expression; copy an individual root to calculate with it.
- Local history (last 100 results), selection-aware editing, copy/recall, iPad
  sidebar, portrait/landscape, dark/light/system appearance.
- Offline KaTeX (MIT) renders interpreted input and results. Entry is linear
  text notation, not a visual fraction editor.

Examples:

```text
1/2 + 1/3
0.1 + 0.2
5 ft + 3 in to cm
60 km/h to m/s
solve(x^2 = 9, x)
diff(x^3, x)
sqrt(-1)
(1+i)/(1-i)
```

## Scope changes from the prototype

This is a smaller independent calculator, not a replacement for every Qalculate
feature. Arbitrary precision, matrices, integration, broad symbolic simplification,
higher-order equation solving, currency rates, external datasets, custom functions,
and graphing are not supported. Unsupported expressions fail explicitly.
Input is limited to 4096 UTF-8 bytes, 256 tokens, 48 parser nesting levels, and a
bounded evaluation operation count. Numeric overflow/nonfinite results produce
errors. Historical saved results remain readable but may not be recalculable.

## Build

Requirements: Apple Silicon Mac, Xcode with an iOS SDK/Simulator runtime, and
Homebrew `xcodegen`. Deployment target: iOS/iPadOS 17+. No external calculation
libraries, downloads, C/C++ compiler setup, or package resolution are needed.
The build script cleans previous generated products before rebuilding, so old
prototype resources cannot survive an incremental build. It audits the device
app after building.

```sh
brew install xcodegen
Scripts/build-app.sh
open Qalculate.xcodeproj
```

Select the **Qalculate** scheme and an iPhone or iPad simulator, then Run. The app
appears as **Fraction Lab**. `project.yml` is the source of Xcode project settings.
Run `xcodegen generate` after changing it. `Scripts/vendor-math.sh` optionally
refreshes the committed checksum-pinned KaTeX assets; normal builds are offline.

For a physical device, select your Apple team under Signing & Capabilities,
connect the device, and Run. Signing credentials and provisioning profiles are
not included. App Store/TestFlight submission has not been performed.

## Tests and dependency audit

```sh
xcodebuild -project Qalculate.xcodeproj -scheme Qalculate \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath .build/Tests CODE_SIGNING_ALLOWED=NO test
python3 Scripts/audit-distribution.py .build/DeviceData/Build/Products/Debug-iphoneos/Qalculate.app
```

The audit checks source/project dependency removal, bundled notices and assets,
and (when given an app) resources and executable symbols/linkage. It is a technical
check of the shipped payload, not a general license scanner or legal opinion.
See [validation](VALIDATION.md) and [third-party inventory](THIRD_PARTY.md).

## License

Current original code is MIT-licensed; the only vendored runtime component,
KaTeX, is also MIT-licensed with its notices preserved. See `LICENSE` and
`THIRD_PARTY.md`. Earlier GPL-based commits retain their original licensing.

## Screenshots

| iPhone | iPad |
| --- | --- |
| ![Fraction Lab on iPhone](Screenshots/iphone.png) | ![Fraction Lab on iPad](Screenshots/ipad.png) |
