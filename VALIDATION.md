# Validation

Validated locally with Xcode 26.6 and the iOS 26.5 SDK/runtime.

- iPhone 17 Pro simulator: all 11 tests passed (9 engine/model, 2 UI).
- iPad Pro 11-inch (M5) simulator: all 11 tests passed (9 engine/model, 2 UI).
- Native arm64 iPhone/iPad device build: succeeded with signing disabled.
- Portrait screenshots reviewed on both devices, including actual stacked fractions.

The tests exercise libqalculate directly, exact fractions, unit conversion,
symbolic differentiation, complex numbers, degree mode, input limits, editor
selection, Unicode deletion, persistent history, rendered equations, and reachable
landscape controls. Screenshots are exported from XCTest attachments.

Physical-device installation and TestFlight/App Store distribution have not been
tested. Deployment targets iOS/iPadOS 17+, but runtime validation used 26.5.

Generated logs, result bundles, native libraries, and build products stay in the
ignored `.build/` and `Vendor/Engine/` directories. See README for reproduction.
