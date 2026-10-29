import UIKit

@MainActor enum CalculatorHaptics {
    private static let generator = UIImpactFeedbackGenerator(style: .soft)
    static func keyPress() {
        generator.impactOccurred(intensity: 0.35)
        generator.prepare()
    }
}
