import SwiftUI
extension Color {
    static let calculatorAccent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.49, green: 0.90, blue: 0.81, alpha: 1) : UIColor(red: 0.02, green: 0.45, blue: 0.39, alpha: 1)
    })
    static let calculatorAccentText = Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? .black : .white })
}
