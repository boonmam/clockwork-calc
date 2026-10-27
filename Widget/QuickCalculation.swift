import Foundation

struct QuickCalculation: Codable {
    var input = "0"
    var left: Double?
    var operation: String?
    var fresh = true
    var page = 0
    var error = false
    var display: String { error ? "Error · AC to reset" : input }
    mutating func press(_ key: String) {
        if key == "Next" { page = (page + 1) % 6; return }
        if key == "AC" { self = Self(); return }
        if error { self = Self() }
        if key == "⌫" { input = String(input.dropLast()); if input.isEmpty || input == "-" { input = "0" }; fresh = false; return }
        if ["+", "−", "×", "÷", "="].contains(key) {
            guard let number = Double(input) else { error = true; return }
            if let lhs = left, let op = operation, !fresh || key == "=" {
                let result: Double
                switch op {
                case "+": result = lhs + number
                case "−": result = lhs - number
                case "×": result = lhs * number
                default: result = lhs / number
                }
                guard result.isFinite else { error = true; return }
                input = String(format: "%.12g", locale: Locale(identifier: "en_US_POSIX"), result)
            }
            left = key == "=" ? nil : Double(input)
            operation = key == "=" ? nil : key
            fresh = true; return
        }
        guard key == "." || (key.count == 1 && key.first?.isNumber == true) else { return }
        if fresh { input = "0"; fresh = false }
        if key == "." { if !input.contains(".") { input += "." }; return }
        if input.count < 15 { input = input == "0" ? key : input + key }
    }
}
