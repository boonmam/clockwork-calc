import Foundation

enum QuickFormula: String, CaseIterable, Identifiable {
    case power = "Power", cutoff = "RC cutoff frequency", capacitorAC = "Capacitor current · AC", capacitorRate = "Capacitor current · dV/dt"
    var id: String { rawValue }
    var formula: String {
        switch self {
        case .power: return "P = V × I"
        case .cutoff: return "f_c = 1 / (2πRC)"
        case .capacitorAC: return "I = 2πfCV"
        case .capacitorRate: return "i = C × dV/dt"
        }
    }
    var fields: [String] {
        switch self {
        case .power: return ["Voltage (V)", "Current (A)"]
        case .cutoff: return ["Resistance (Ω)", "Capacitance (F)"]
        case .capacitorAC: return ["Frequency (Hz)", "Capacitance (F)", "Voltage RMS (V)"]
        case .capacitorRate: return ["Capacitance (F)", "Voltage rate (V/s)"]
        }
    }
    var units: String { self == .power ? "W" : self == .cutoff ? "Hz" : "A" }
    var note: String {
        switch self {
        case .power: return "DC or instantaneous power. For AC average power, power factor is also required."
        case .cutoff: return "Ideal first-order RC filter, −3 dB cutoff."
        case .capacitorAC: return "Ideal capacitor with sinusoidal voltage. RMS voltage gives RMS current."
        case .capacitorRate: return "Instantaneous current. A falling voltage gives negative current."
        }
    }
    var example: [String] {
        switch self {
        case .power: return ["12", "0.5"]
        case .cutoff: return ["1000", "100e-9"]
        case .capacitorAC: return ["60", "10e-6", "120"]
        case .capacitorRate: return ["10e-6", "1000"]
        }
    }
    func evaluate(_ values: [String]) throws -> Double {
        guard values.count == fields.count else { throw CalculationError(message: "Fill in every value.") }
        let numbers = try values.map { text -> Double in
            guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)), value.isFinite else {
                throw CalculationError(message: "Enter numbers, using e for exponents (for example, 10e-6).")
            }
            return value
        }
        let result: Double
        switch self {
        case .power: result = numbers[0] * numbers[1]
        case .cutoff:
            guard numbers[0] > 0, numbers[1] > 0 else { throw CalculationError(message: "Resistance and capacitance must be positive.") }
            result = 1 / (2 * .pi * numbers[0] * numbers[1])
        case .capacitorAC:
            guard numbers[0] >= 0, numbers[1] > 0, numbers[2] >= 0 else { throw CalculationError(message: "Use nonnegative frequency and RMS voltage, and positive capacitance.") }
            result = 2 * .pi * numbers[0] * numbers[1] * numbers[2]
        case .capacitorRate:
            guard numbers[0] > 0 else { throw CalculationError(message: "Capacitance must be positive.") }
            result = numbers[0] * numbers[1]
        }
        guard result.isFinite else { throw CalculationError(message: "These values exceed the supported numeric range.") }
        return result
    }
}
