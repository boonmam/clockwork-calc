import Foundation

enum ResultNotation: String, Codable, CaseIterable {
    case exact, decimal, engineering, symbolicEngineering
    var title: String {
        switch self {
        case .exact: return "Exact"
        case .decimal: return "Decimal"
        case .engineering: return "Engineering"
        case .symbolicEngineering: return "Engineering (SI symbols)"
        }
    }
}

/// Display-only decimal shifting: no Double conversion or additional rounding.
/// Canonical calculation text remains available for Copy, Ans, and reuse.
enum EngineeringNotation {
    private static let prefixes: [Int: String] = [
        -30: "q", -27: "r", -24: "y", -21: "z", -18: "a", -15: "f",
        -12: "p", -9: "n", -6: "µ", -3: "m", 3: "k", 6: "M", 9: "G",
        12: "T", 15: "P", 18: "E", 21: "Z", 24: "Y", 27: "R", 30: "Q"
    ]
    static func number(_ source: String, symbolic: Bool, latex: Bool) -> String {
        let parts = source.lowercased().split(separator: "e", omittingEmptySubsequences: false)
        guard parts.count <= 2, let explicit = parts.count == 2 ? Int(parts[1]) : 0,
              (-99_999...99_999).contains(explicit) else { return source }
        let mantissa = String(parts[0])
        let components = mantissa.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count <= 2 else { return source }
        let digits = components.joined()
        guard !digits.isEmpty, digits.allSatisfy({ $0.isASCII && $0.isNumber }) else { return source }
        let leading = digits.prefix(while: { $0 == "0" }).count
        guard leading < digits.count else { return "0" }
        let order = explicit + components[0].count - leading - 1
        let exponent = order >= 0 ? order / 3 * 3 : (order - 2) / 3 * 3
        let integerDigits = order - exponent + 1
        var significant = String(digits.dropFirst(leading))
        while significant.count < integerDigits { significant.append("0") }
        let split = significant.index(significant.startIndex, offsetBy: integerDigits)
        let whole = String(significant[..<split])
        var fraction = String(significant[split...])
        while fraction.last == "0" { fraction.removeLast() }
        let coefficient = whole + (fraction.isEmpty ? "" : "." + fraction)
        guard exponent != 0 else { return coefficient }
        if symbolic, let symbol = prefixes[exponent] {
            let texSymbol = symbol == "µ" ? "\\mu" : symbol
            return latex ? "{\(coefficient)\\,\\mathrm{\(texSymbol)}}" : "\(coefficient) \(symbol)"
        }
        return latex ? "{\(coefficient)\\times 10^{\(exponent)}}" : "\(coefficient) × 10^\(exponent)"
    }

    static func format(_ source: String, symbolic: Bool, latex: Bool) -> String {
        // Protect TeX command arguments containing names/units and identifier digits.
        let protected = latex ? #"\\(?:operatorname|mathrm|text|begin|end)\{[^{}]*\}|_(?:\{[^{}]*\}|[A-Za-z0-9])|"# : ""
        let number = #"(?<![A-Za-z_0-9.])(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?"#
        let scientific = latex ? #"(?:\s*\\(?:times|cdot)\s*10\^\{([+-]?[0-9]+)\})?"# : ""
        let regex = try! NSRegularExpression(pattern: protected + number + scientific)
        let original = source as NSString
        var result = source
        for match in regex.matches(in: source, range: NSRange(location: 0, length: original.length)).reversed() {
            let token = original.substring(with: match.range)
            guard !token.hasPrefix("\\"), !token.hasPrefix("_") else { continue }
            var numeric = token
            if latex, match.numberOfRanges > 1, match.range(at: 1).location != NSNotFound,
               let slash = token.firstIndex(of: "\\") {
                numeric = token[..<slash].trimmingCharacters(in: .whitespaces) + "e" + original.substring(with: match.range(at: 1))
            }
            var replacement = self.number(numeric, symbolic: symbolic, latex: latex)
            let standalone = source == token || source == "-" + token || source == "+" + token
            if !latex, !standalone, replacement.contains(" ") { replacement = "(" + replacement + ")" }
            if let range = Range(match.range, in: result) { result.replaceSubrange(range, with: replacement) }
        }
        return result
    }

    static func apply(_ result: Calculation, notation: ResultNotation) -> Calculation {
        var result = result
        result.notation = notation
        guard notation == .engineering || notation == .symbolicEngineering else { return result }
        let symbolic = notation == .symbolicEngineering
        result.displayText = format(result.text, symbolic: symbolic, latex: false)
        result.latex = format(result.latex, symbolic: symbolic, latex: true)
        return result
    }
}
