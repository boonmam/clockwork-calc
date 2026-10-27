import Foundation

/// Fixed-width integer calculator. Arithmetic wraps to the selected word size.
@MainActor final class ProgrammerModel: ObservableObject {
    @Published private(set) var value: UInt64 = 0
    @Published private(set) var radix = 10
    @Published private(set) var width = 64
    @Published var signed = true
    @Published private(set) var error: String?
    @Published private(set) var operation: String?
    private var left: UInt64 = 0
    private var replacing = true
    var mask: UInt64 { width == 64 ? UInt64.max : (UInt64(1) << width) - 1 }
    var signedValue: Int64 { signedInteger(value) }
    private func signedInteger(_ bits: UInt64) -> Int64 {
        let truncated = bits & mask
        return Int64(bitPattern: truncated & (UInt64(1) << (width - 1)) == 0 ? truncated : truncated | ~mask)
    }
    func formatted(base: Int) -> String {
        if base == 10 && signed { return String(signedValue) }
        return String(value, radix: base, uppercase: true)
    }
    func setRadix(_ base: Int) { guard [2, 8, 10, 16].contains(base) else { return }; radix = base }
    func setWidth(_ bits: Int) {
        guard [8, 16, 32, 64].contains(bits) else { return }
        width = bits; value &= mask; left &= mask; error = nil
    }
    func clear() { value = 0; left = 0; operation = nil; replacing = true; error = nil }
    func digit(_ text: String) {
        guard let digit = UInt64(text, radix: radix) else { return }
        let previous = replacing ? 0 : value
        let product = previous.multipliedReportingOverflow(by: UInt64(radix))
        let sum = product.partialValue.addingReportingOverflow(digit)
        guard !product.overflow && !sum.overflow && sum.partialValue <= mask else {
            error = "Value exceeds \(width) bits."; return
        }
        value = sum.partialValue; replacing = false; error = nil
    }
    func backspace() { value /= UInt64(radix); replacing = false; error = nil }
    func unary(_ op: String) {
        switch op {
        case "NOT": value = ~value & mask
        case "±": value = (0 &- value) & mask
        case "<<": value = (value << 1) & mask
        case ">>": value >>= 1
        case "ASR": value = UInt64(bitPattern: signedInteger(value) >> 1) & mask
        default: return
        }
        replacing = false; error = nil
    }
    func choose(_ op: String) {
        guard ["+", "−", "×", "÷", "MOD", "AND", "OR", "XOR"].contains(op) else { return }
        if operation != nil && !replacing { evaluate(); if error != nil { return } }
        left = value; operation = op; replacing = true; error = nil
    }
    func evaluate() {
        guard let op = operation else { return }
        let right = value
        switch op {
        case "+": value = left &+ right
        case "−": value = left &- right
        case "×": value = left &* right
        case "AND": value = left & right
        case "OR": value = left | right
        case "XOR": value = left ^ right
        case "÷", "MOD":
            guard right != 0 else { error = "Cannot divide by zero."; return }
            if signed {
                let a = signedInteger(left), b = signedInteger(right)
                // Int64.min / -1 is the only signed division overflow; wrap it.
                if a == Int64.min && b == -1 { value = op == "÷" ? UInt64(bitPattern: a) : 0 }
                else { value = UInt64(bitPattern: op == "÷" ? a / b : a % b) }
            } else { value = op == "÷" ? left / right : left % right }
        default: return
        }
        value &= mask; operation = nil; replacing = true; error = nil
    }
}
