import Foundation
import SwiftUI

struct QuickInput: Codable, Identifiable, Hashable {
    var id = UUID()
    var symbol = "x"
    var label = "Input"
    var unit = ""
    var defaultValue = "1"
}
enum QuickInputStyle: String, Codable, CaseIterable { case keyboard = "Keyboard", keypad = "Keypad" }

struct QuickTab: Codable, Identifiable, Hashable {
    var id = UUID()
    var name = "My calculation"
    var expression = "x*2"
    var resultUnit = ""
    var inputs = [QuickInput()]
    var isPower = false
    var note = ""
    var inputStyle: QuickInputStyle? = nil
    var effectiveInputStyle: QuickInputStyle { inputStyle ?? (isPower ? .keypad : .keyboard) }
    var worksheetIdentity: QuickTab { var identity = self; identity.inputStyle = nil; return identity }

    static var starters: [QuickTab] { [
        QuickTab(name: "Power", expression: "", inputs: [], isPower: true),
        QuickTab(name: "RC cutoff", expression: "1/(2*pi*R*C)", resultUnit: "Hz", inputs: [
            QuickInput(symbol: "R", label: "Resistance", unit: "Ω", defaultValue: "1000"),
            QuickInput(symbol: "C", label: "Capacitance", unit: "F", defaultValue: "100e-9")], note: "Ideal first-order RC filter, −3 dB cutoff. Use positive R and C."),
        QuickTab(name: "Capacitor AC", expression: "2*pi*f*C*V", resultUnit: "A RMS", inputs: [
            QuickInput(symbol: "f", label: "Frequency", unit: "Hz", defaultValue: "60"),
            QuickInput(symbol: "C", label: "Capacitance", unit: "F", defaultValue: "10e-6"),
            QuickInput(symbol: "V", label: "Voltage RMS", unit: "V", defaultValue: "120")], note: "Ideal capacitor, sinusoidal voltage. Use positive capacitance and nonnegative frequency and RMS voltage."),
        QuickTab(name: "Capacitor dV/dt", expression: "C*s", resultUnit: "A", inputs: [
            QuickInput(symbol: "C", label: "Capacitance", unit: "F", defaultValue: "10e-6"),
            QuickInput(symbol: "s", label: "Voltage rate", unit: "V/s", defaultValue: "1000")], note: "Instantaneous current i = C × dV/dt. Use positive capacitance; voltage rate may be negative.")
    ] }
    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw CalculationError(message: "Give this tab a name.") }
        if isPower { return }
        guard (1...4).contains(inputs.count), expression.count <= 500 else { throw CalculationError(message: "Use 1–4 fields and a formula under 500 characters.") }
        var symbols = Set<String>()
        for input in inputs {
            guard input.symbol.range(of: "^[A-Za-z][A-Za-z0-9_]*$", options: .regularExpression) != nil,
                  !["pi", "e", "i", "sin", "cos", "tan", "sqrt", "ln", "log", "exp", "abs"].contains(input.symbol),
                  symbols.insert(input.symbol).inserted else { throw CalculationError(message: "Use unique variable names such as R, C, or x; avoid constants and function names.") }
            guard !input.label.isEmpty else { throw CalculationError(message: "Give each field a label.") }
        }
        _ = try evaluate(inputs.map(\.defaultValue))
    }
    func evaluate(_ values: [String]) throws -> String {
        guard values.count == inputs.count else { throw CalculationError(message: "Enter every input.") }
        var substituted = expression
        for (input, text) in zip(inputs, values) {
            guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)), value.isFinite else { throw CalculationError(message: "Enter a finite number for \(input.label). Use e for exponents.") }
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: input.symbol) + "\\b"
            substituted = substituted.replacingOccurrences(of: pattern, with: "(\(value))", options: .regularExpression)
        }
        return try NativeMath().evaluate(substituted, exact: false, degrees: false).text
    }
}

@MainActor final class QuickTabStore: ObservableObject {
    @Published var tabs: [QuickTab]
    @Published var error: String?
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "quickCalcTabs"), let saved = try? JSONDecoder().decode([QuickTab].self, from: data), !saved.isEmpty {
            tabs = saved
        } else { tabs = QuickTab.starters }
    }
    func save(_ tab: QuickTab) throws {
        try tab.validate()
        if let index = tabs.firstIndex(where: { $0.id == tab.id }) { tabs[index] = tab }
        else { tabs.append(tab) }
        persist()
    }
    func remove(_ id: UUID) {
        guard tabs.count > 1 else { return }
        tabs.removeAll { $0.id == id }; persist()
    }
    private func persist() {
        do { defaults.set(try JSONEncoder().encode(tabs), forKey: "quickCalcTabs") }
        catch { self.error = "Could not save your tabs: \(error.localizedDescription)" }
    }
}

/// DC magnitudes for a passive resistive load: V = IR and P = VI.
enum DCPower {
    // Fields are R, I, V, P. Empty fields are unknown, never prior computed inputs.
    static func solve(_ inputs: [Double?]) throws -> [Double] {
        guard inputs.count == 4, inputs.compactMap({ $0 }).count == 2 else { throw CalculationError(message: "Enter exactly two known values; leave the other two blank.") }
        guard inputs.compactMap({ $0 }).allSatisfy({ $0.isFinite && $0 >= 0 }), inputs[0] != 0 else { throw CalculationError(message: "Use nonnegative DC magnitudes and positive resistance.") }
        var r = 0.0, i = 0.0, v = 0.0, p = 0.0
        switch (inputs[0], inputs[1], inputs[2], inputs[3]) {
        case let (R?, I?, nil, nil): r = R; i = I; v = i*r; p = v*i
        case let (R?, nil, V?, nil): r = R; v = V; i = v/r; p = v*i
        case let (R?, nil, nil, P?): r = R; p = P; i = sqrt(p/r); v = i*r
        case let (nil, I?, V?, nil):
            guard I > 0, V > 0 else { throw CalculationError(message: "Zero current or voltage does not determine a positive finite resistance. Enter resistance instead.") }
            i = I; v = V; r = v/i; p = v*i
        case let (nil, I?, nil, P?):
            guard I > 0, P > 0 else { throw CalculationError(message: "Use positive current and power, or supply resistance for a zero-power load.") }
            i = I; p = P; v = p/i; r = v/i
        case let (nil, nil, V?, P?):
            guard V > 0, P > 0 else { throw CalculationError(message: "Use positive voltage and power, or supply resistance for a zero-power load.") }
            v = V; p = P; i = p/v; r = v/i
        default: throw CalculationError(message: "Enter two known values.")
        }
        let result = [r,i,v,p]
        guard result.allSatisfy(\.isFinite), r > 0 else { throw CalculationError(message: "Values exceed the supported numeric range.") }
        return result
    }
}
