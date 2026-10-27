import SwiftUI

@main struct ClockworkCalcApp: App {
    @AppStorage("appearance") private var appearance = "dark"
    @StateObject private var model = CalculatorModel()
    var body: some Scene {
        WindowGroup { CalculatorView().environmentObject(model).tint(.calculatorAccent)
            .preferredColorScheme(appearance == "system" ? nil : (appearance == "dark" ? .dark : .light)) }
    }
}
