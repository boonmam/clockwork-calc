// Copyright (c) 2026 boonmam. MIT licensed.
// Original Swift implementation of arithmetic and unit conversion.
import Foundation

private func mathError(_ message: String) -> CalculationError { CalculationError(message: message) }

/// Reduced signed 64-bit fractions. Overflow falls back to explicitly approximate Double arithmetic.
private struct Rational {
    let n: Int64
    let d: Int64
    init?(_ numerator: Int64, _ denominator: Int64 = 1) {
        guard denominator != 0, numerator != .min, denominator != .min else { return nil }
        let g = Self.gcd(abs(numerator), abs(denominator))
        n = (denominator < 0 ? -numerator : numerator) / g
        d = abs(denominator) / g
    }
    static func gcd(_ a: Int64, _ b: Int64) -> Int64 {
        var x = a, y = b
        while y != 0 { (x, y) = (y, x % y) }
        return max(x, 1)
    }
    func adding(_ b: Rational) -> Rational? {
        let g = Self.gcd(d, b.d)
        let (aN, o1) = n.multipliedReportingOverflow(by: b.d / g)
        let (bN, o2) = b.n.multipliedReportingOverflow(by: d / g)
        let (sum, o3) = aN.addingReportingOverflow(bN)
        let (den, o4) = d.multipliedReportingOverflow(by: b.d / g)
        guard !o1, !o2, !o3, !o4 else { return nil }
        return Rational(sum, den)
    }
    func multiplying(_ b: Rational) -> Rational? {
        let g1 = Self.gcd(abs(n), b.d), g2 = Self.gcd(abs(b.n), d)
        let (num, o1) = (n / g1).multipliedReportingOverflow(by: b.n / g2)
        let (den, o2) = (d / g2).multipliedReportingOverflow(by: b.d / g1)
        return o1 || o2 ? nil : Rational(num, den)
    }
    static func literal(_ text: String) -> Rational? {
        let parts = text.lowercased().split(separator: "e", omittingEmptySubsequences: false)
        guard parts.count <= 2 else { return nil }
        let mantissa = String(parts[0])
        let decimal = mantissa.split(separator: ".", omittingEmptySubsequences: false)
        let fractionalDigits = decimal.count == 2 ? decimal[1].count : 0
        guard let num = Int64(mantissa.replacingOccurrences(of: ".", with: "")),
              let exponent = parts.count == 2 ? Int(parts[1]) : 0,
              (-18...18).contains(exponent),
              (-18...18).contains(exponent - fractionalDigits) else { return nil }
        let power = exponent - fractionalDigits
        var scale: Int64 = 1
        for _ in 0..<abs(power) { scale *= 10 }
        if power < 0 { return Rational(num, scale) }
        let (scaled, overflow) = num.multipliedReportingOverflow(by: scale)
        return overflow ? nil : Rational(scaled)
    }
}

private struct Scalar {
    var re: Double
    var im: Double = 0
    var fraction: Rational?
    init(_ re: Double, _ im: Double = 0, fraction: Rational? = nil) {
        self.re = fraction.map { Double($0.n) / Double($0.d) } ?? re
        self.im = im
        self.fraction = fraction
    }
    static func integer(_ n: Int64) -> Scalar { Scalar(Double(n), fraction: Rational(n)) }
    static let zero = Scalar.integer(0)
    static let one = Scalar.integer(1)
    var isZero: Bool { re == 0 && im == 0 }
    func checked() throws -> Scalar {
        guard re.isFinite, im.isFinite else { throw mathError("Result is outside the supported numeric range.") }
        return self
    }
    func negated() -> Scalar { Scalar(-re, -im, fraction: fraction.flatMap { Rational(-$0.n, $0.d) }) }
    func adding(_ b: Scalar) -> Scalar {
        Scalar(re + b.re, im + b.im, fraction: fraction.flatMap { a in b.fraction.flatMap { a.adding($0) } })
    }
    func multiplying(_ b: Scalar) -> Scalar {
        Scalar(re * b.re - im * b.im, re * b.im + im * b.re,
               fraction: fraction.flatMap { a in b.fraction.flatMap { a.multiplying($0) } })
    }
    func dividing(_ b: Scalar) throws -> Scalar {
        guard !b.isZero else { throw mathError("Division by zero.") }
        // Scale the complex division to avoid squaring large components.
        let scale = max(abs(b.re), abs(b.im)), br = b.re / scale, bi = b.im / scale
        let den = br * br + bi * bi
        return try Scalar(((re / scale) * br + (im / scale) * bi) / den,
                          ((im / scale) * br - (re / scale) * bi) / den,
                          fraction: fraction.flatMap { a in b.fraction.flatMap { r in Rational(r.d, r.n).flatMap { a.multiplying($0) } } }).checked()
    }
    func power(_ b: Scalar) throws -> Scalar {
        if b.im == 0, b.re.rounded() == b.re, abs(b.re) <= 1024 {
            let exponent = Int(b.re)
            if isZero && exponent <= 0 { throw mathError("Zero requires a positive exponent.") }
            var result = Scalar.one, base = self, count = abs(exponent)
            while count > 0 {
                if count % 2 == 1 { result = try result.multiplying(base).checked() }
                count /= 2
                if count > 0 { base = try base.multiplying(base).checked() }
            }
            return exponent < 0 ? try Scalar.one.dividing(result) : result
        }
        if isZero {
            guard b.im == 0, b.re > 0 else { throw mathError("Undefined power of zero.") }
            return .zero
        }
        let logValue = Scalar(log(hypot(re, im)), atan2(im, re))
        let product = b.multiplying(logValue)
        let magnitude = exp(product.re)
        return try Scalar(magnitude * cos(product.im), magnitude * sin(product.im)).checked()
    }
    func isApproximate(exact: Bool) -> Bool {
        guard let fraction else { return true }
        if exact { return false }
        guard let displayed = Rational.literal(Self.number(re)) else { return true }
        return displayed.n != fraction.n || displayed.d != fraction.d
    }
    func rendered(exact: Bool) -> (String, String) {
        if im == 0 {
            if exact, let r = fraction {
                if r.d == 1 { return (String(r.n), String(r.n)) }
                return ("\(r.n)/\(r.d)", "\(r.n < 0 ? "-" : "")\\frac{\(abs(r.n))}{\(r.d)}")
            }
            let text = Self.number(re)
            return (text, Self.numberLatex(text))
        }
        let imaginary = abs(im) == 1 ? "i" : Self.number(abs(im)) + "*i"
        let text = re == 0 ? (im < 0 ? "-" : "") + imaginary : Self.number(re) + (im < 0 ? " - " : " + ") + imaginary
        let latexIm = abs(im) == 1 ? "i" : Self.numberLatex(Self.number(abs(im))) + "i"
        let latex = re == 0 ? (im < 0 ? "-" : "") + latexIm : Self.numberLatex(Self.number(re)) + (im < 0 ? " - " : " + ") + latexIm
        return (text, latex)
    }
    static func number(_ value: Double) -> String {
        value == 0 ? "0" : String(format: "%.15g", locale: Locale(identifier: "en_US_POSIX"), value)
    }
    static func numberLatex(_ text: String) -> String {
        let parts = text.split(separator: "e")
        if parts.count == 2 { return "\(parts[0])\\times 10^{\(Int(parts[1]) ?? 0)}" }
        return text
    }
}

private indirect enum Expression {
    case number(String), symbol(String), unary(Expression), binary(String, Expression, Expression), call(String, [Expression])
    var latex: String {
        switch self {
        case .number(let n): return Scalar.numberLatex(n)
        case .symbol(let n): return n == "pi" || n == "π" ? "\\pi" : "\\mathrm{\(n)}"
        case .unary(let a): return "-\\left(\(a.latex)\\right)"
        case .binary(let op, let a, let b):
            if op == "/" { return "\\frac{\(a.latex)}{\(b.latex)}" }
            if op == "^" { return "{\\left(\(a.latex)\\right)}^{\(b.latex)}" }
            return "\\left(\(a.latex) \(op == "*" ? "\\cdot" : op) \(b.latex)\\right)"
        case .call(let name, let args):
            if name == "sqrt", args.count == 1 { return "\\sqrt{\(args[0].latex)}" }
            return "\\operatorname{\(name)}\\left(\(args.map(\.latex).joined(separator: ","))\\right)"
        }
    }
    var text: String {
        switch self {
        case .number(let n), .symbol(let n): return n
        case .unary(let a): return "-(\(a.text))"
        case .binary(let op, let a, let b): return "(\(a.text)\(op)\(b.text))"
        case .call(let name, let args): return name + "(" + args.map(\.text).joined(separator: ",") + ")"
        }
    }
}

private struct Parser {
    private var tokens: [String] = []
    private var index = 0
    private var depth = 0
    init(_ input: String) throws {
        guard input.utf8.count <= 4096 else { throw mathError("Expressions are limited to 4096 bytes.") }
        let chars = Array(input.replacingOccurrences(of: "×", with: "*").replacingOccurrences(of: "÷", with: "/").replacingOccurrences(of: "−", with: "-"))
        var i = 0
        func digit(_ c: Character) -> Bool { c >= "0" && c <= "9" }
        func letter(_ c: Character) -> Bool { (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || c == "π" }
        while i < chars.count {
            if chars[i].isWhitespace { i += 1; continue }
            let start = i
            if digit(chars[i]) || chars[i] == "." {
                while i < chars.count && (digit(chars[i]) || chars[i] == ".") { i += 1 }
                if i < chars.count, chars[i] == "e" || chars[i] == "E" {
                    var end = i + 1
                    if end < chars.count, chars[end] == "+" || chars[end] == "-" { end += 1 }
                    let exponentStart = end
                    while end < chars.count && digit(chars[end]) { end += 1 }
                    if end > exponentStart { i = end }
                }
                let token = String(chars[start..<i])
                guard let value = Double(token), value.isFinite else { throw mathError("Invalid number: \(token)") }
                tokens.append(token)
            } else if letter(chars[i]) {
                while i < chars.count && letter(chars[i]) { i += 1 }
                tokens.append(String(chars[start..<i]))
            } else if "+-*/^(),=".contains(chars[i]) { tokens.append(String(chars[i])); i += 1 }
            else { throw mathError("Unsupported character: \(chars[i])") }
            guard tokens.count <= 256 else { throw mathError("Expression is too complex (maximum 256 tokens).") }
        }
        tokens.append("")
    }
    private var current: String { tokens[index] }
    private mutating func consume() -> String { let token = current; index += 1; return token }
    mutating func parse() throws -> (Expression, Expression?) {
        let value = try expression()
        var target: Expression?
        if current == "to" { _ = consume(); target = try expression() }
        guard current.isEmpty else { throw mathError("Unexpected token: \(current)") }
        return (value, target)
    }
    private mutating func expression(_ minimum: Int = 0) throws -> Expression {
        depth += 1; defer { depth -= 1 }
        guard depth <= 48 else { throw mathError("Expression nesting is too deep.") }
        var left: Expression
        let token = consume()
        if token == "-" { left = .unary(try expression(30)) }
        else if token == "+" { left = try expression(30) }
        else if token == "(" {
            left = try expression()
            guard current == ")" else { throw mathError("Expected a closing parenthesis.") }; _ = consume()
        } else if Double(token) != nil { left = .number(token) }
        else if token.first?.isLetter == true, token != "to" {
            if current == "(" {
                _ = consume(); var args: [Expression] = []
                if current != ")" {
                    args.append(try expression())
                    while current == "," { _ = consume(); args.append(try expression()) }
                }
                guard current == ")" else { throw mathError("Expected a closing parenthesis.") }; _ = consume()
                left = .call(token, args)
            } else { left = .symbol(token) }
        } else { throw mathError("Expected a number, name, or parenthesis.") }
        while !current.isEmpty {
            let explicit = ["=": 1, "+": 10, "-": 10, "*": 20, "/": 20, "^": 40][current]
            // Adjacent symbols or parentheses mean multiplication, e.g. 5 ft or 2(3+4).
            let numberAfterSymbolOrGroup = Double(current) != nil &&
                (tokens[index - 1].first?.isLetter == true || tokens[index - 1] == ")")
            let implicit = current != "to" && (current.first?.isLetter == true || current == "(" || numberAfterSymbolOrGroup)
            guard let precedence = explicit ?? (implicit ? 20 : nil), precedence >= minimum else { break }
            let op = explicit == nil ? "*" : consume()
            left = .binary(op, left, try expression(precedence + (op == "^" ? 0 : 1)))
        }
        return left
    }
}

private struct Quantity {
    var value: Scalar
    var dimensions: [Int] = [0, 0, 0, 0] // metre, kilogram, second, kelvin
    var isDimensionless: Bool { dimensions.allSatisfy { $0 == 0 } }
}

/// Small, original table of conventional exact SI conversion factors, not an upstream dataset.
private struct UnitDefinition {
    let n: Int64, d: Int64, dimensions: [Int]
    var quantity: Quantity { Quantity(value: Scalar(Double(n) / Double(d), fraction: Rational(n, d)), dimensions: dimensions) }
    static let all: [String: UnitDefinition] = {
        var result: [String: UnitDefinition] = [:]
        func add(_ names: [String], _ n: Int64, _ d: Int64, _ dimensions: [Int]) {
            for name in names { result[name] = UnitDefinition(n: n, d: d, dimensions: dimensions) }
        }
        let length = [1,0,0,0], mass = [0,1,0,0], time = [0,0,1,0]
        add(["m"], 1, 1, length); add(["cm"], 1, 100, length); add(["mm"], 1, 1000, length)
        add(["km"], 1000, 1, length); add(["in"], 127, 5000, length); add(["ft"], 381, 1250, length)
        add(["yd"], 1143, 1250, length); add(["mi"], 201168, 125, length)
        add(["kg"], 1, 1, mass); add(["g"], 1, 1000, mass); add(["mg"], 1, 1000000, mass)
        add(["lb"], 45359237, 100000000, mass); add(["oz"], 45359237, 1600000000, mass)
        add(["s"], 1, 1, time); add(["ms"], 1, 1000, time); add(["min"], 60, 1, time); add(["h"], 3600, 1, time)
        add(["day"], 86400, 1, time); add(["K"], 1, 1, [0,0,0,1])
        add(["L"], 1, 1000, [3,0,0,0]); add(["mL"], 1, 1000000, [3,0,0,0])
        add(["Hz"], 1, 1, [0,0,-1,0]); add(["N"], 1, 1, [1,1,-2,0])
        add(["Pa"], 1, 1, [-1,1,-2,0]); add(["J"], 1, 1, [2,1,-2,0]); add(["W"], 1, 1, [2,1,-3,0])
        return result
    }()
}

private final class Evaluator {
    let degrees: Bool
    var operations = 0
    init(degrees: Bool) { self.degrees = degrees }
    func tick() throws {
        operations += 1
        guard operations < 10000 else { throw mathError("Calculation exceeded the operation limit.") }
    }
    func evaluate(_ expression: Expression) throws -> Quantity {
        try tick()
        switch expression {
        case .number(let text): return Quantity(value: Scalar(Double(text)!, fraction: Rational.literal(text)))
        case .symbol(let name):
            if let unit = UnitDefinition.all[name] { return unit.quantity }
            if name == "pi" || name == "π" { return Quantity(value: Scalar(.pi)) }
            if name == "e" { return Quantity(value: Scalar(M_E)) }
            if name == "i" { return Quantity(value: Scalar(0, 1)) }
            throw mathError("Unknown name: \(name). Use diff or solve for symbolic expressions.")
        case .unary(let a): var q = try evaluate(a); q.value = q.value.negated(); return q
        case .binary(let op, let a, let b):
            let lhs = try evaluate(a), rhs = try evaluate(b)
            switch op {
            case "+", "-":
                guard lhs.dimensions == rhs.dimensions else { throw mathError("Cannot add or subtract incompatible units.") }
                return Quantity(value: try lhs.value.adding(op == "-" ? rhs.value.negated() : rhs.value).checked(), dimensions: lhs.dimensions)
            case "*", "/":
                let dims = zip(lhs.dimensions, rhs.dimensions).map { op == "*" ? $0 + $1 : $0 - $1 }
                guard dims.allSatisfy({ abs($0) <= 64 }) else { throw mathError("Unit exponent is too large.") }
                return Quantity(value: try (op == "*" ? lhs.value.multiplying(rhs.value) : lhs.value.dividing(rhs.value)).checked(), dimensions: dims)
            case "^":
                guard rhs.isDimensionless else { throw mathError("Exponents must be dimensionless.") }
                var dims = lhs.dimensions
                if !lhs.isDimensionless {
                    guard rhs.value.im == 0, rhs.value.re.rounded() == rhs.value.re, abs(rhs.value.re) <= 16 else { throw mathError("Unit powers require an integer from -16 to 16.") }
                    dims = dims.map { $0 * Int(rhs.value.re) }
                    guard dims.allSatisfy({ abs($0) <= 64 }) else { throw mathError("Unit exponent is too large.") }
                }
                return Quantity(value: try lhs.value.power(rhs.value), dimensions: dims)
            default: throw mathError("Use solve(equation, variable) for equations.")
            }
        case .call(let name, let args):
            guard args.count == 1 else { throw mathError("\(name) requires one argument here.") }
            var q = try evaluate(args[0])
            if name == "abs" { q.value = q.value.im == 0 ? (q.value.re < 0 ? q.value.negated() : q.value) : Scalar(hypot(q.value.re, q.value.im)); return q }
            if name == "sqrt" {
                guard q.dimensions.allSatisfy({ $0 % 2 == 0 }) else { throw mathError("Square root requires even unit powers.") }
                q.dimensions = q.dimensions.map { $0 / 2 }
                if let r = q.value.fraction, r.n >= 0 {
                    let n = Int64(Double(r.n).squareRoot()), d = Int64(Double(r.d).squareRoot())
                    if n.multipliedReportingOverflow(by: n) == (r.n, false), d.multipliedReportingOverflow(by: d) == (r.d, false) {
                        q.value = Scalar(Double(n) / Double(d), fraction: Rational(n, d)); return q
                    }
                }
                if q.value.im == 0 {
                    q.value = q.value.re >= 0 ? Scalar(sqrt(q.value.re)) : Scalar(0, sqrt(-q.value.re)); return q
                }
                q.value = try q.value.power(Scalar(0.5)); return q
            }
            guard q.isDimensionless, q.value.im == 0 else { throw mathError("\(name) requires a real, dimensionless argument.") }
            let x = q.value.re, angle = degrees ? x * .pi / 180 : x
            var value: Scalar
            switch name {
            case "sin", "cos", "tan":
                // Exact special angles only when the input itself is an exact degree value.
                if degrees, let r = q.value.fraction, r.d == 1 {
                    let degree = Int((r.n % 360 + 360) % 360)
                    let sine: [Int: Rational] = [0: Rational(0)!,30: Rational(1,2)!,90: Rational(1)!,150: Rational(1,2)!,180: Rational(0)!,210: Rational(-1,2)!,270: Rational(-1)!,330: Rational(-1,2)!]
                    let s = sine[degree], c = sine[(degree + 90) % 360]
                    let r = name == "sin" ? s : name == "cos" ? c : nil
                    if let r { return Quantity(value: Scalar(Double(r.n) / Double(r.d), fraction: r)) }
                    if name == "tan", c?.n == 0 { throw mathError("Tangent is undefined at this angle.") }
                }
                if name == "tan", abs(cos(angle)) < 1e-15 { throw mathError("Tangent is undefined at this angle.") }
                value = Scalar(name == "sin" ? sin(angle) : name == "cos" ? cos(angle) : tan(angle))
            case "asin", "acos", "atan":
                let result = name == "asin" ? asin(x) : name == "acos" ? acos(x) : atan(x)
                value = Scalar(degrees ? result * 180 / .pi : result)
            case "ln": guard x > 0 else { throw mathError("ln requires a positive real argument.") }; value = Scalar(log(x))
            case "log": guard x > 0 else { throw mathError("log requires a positive real argument.") }; value = Scalar(log10(x))
            case "exp": value = Scalar(exp(x))
            case "floor": value = Scalar(floor(x))
            case "ceil": value = Scalar(ceil(x))
            default: throw mathError("Unsupported function: \(name). See About for supported functions.")
            }
            return Quantity(value: try value.checked())
        }
    }
    func derivative(_ e: Expression, variable: String) throws -> Expression {
        try tick()
        func d(_ a: Expression) throws -> Expression { try derivative(a, variable: variable) }
        func b(_ op: String, _ a: Expression, _ c: Expression) -> Expression { simplified(op, a, c) }
        switch e {
        case .number: return .number("0")
        case .symbol(let name): return .number(name == variable ? "1" : "0")
        case .unary(let a): return b("*", .number("-1"), try d(a))
        case .binary(let op, let a, let c):
            switch op {
            case "+", "-": return b(op, try d(a), try d(c))
            case "*": return b("+", b("*", try d(a), c), b("*", a, try d(c)))
            case "/": return b("/", b("-", b("*", try d(a), c), b("*", a, try d(c))), b("^", c, .number("2")))
            case "^":
                let exponentText: String?
                switch c {
                case .number(let n): exponentText = n
                case .unary(.number(let n)): exponentText = "-" + n
                default: exponentText = nil
                }
                if let n = exponentText {
                    let coefficient = Expression.number(n)
                    let reduced: Expression
                    if let integer = Int64(n), integer > Int64.min {
                        reduced = .number(String(integer - 1))
                    } else { reduced = .binary("-", coefficient, .number("1")) }
                    return b("*", b("*", coefficient, b("^", a, reduced)), try d(a))
                }
                throw mathError("Differentiation supports constant numeric exponents.")
            default: throw mathError("Differentiate an expression, not an equation.")
            }
        case .call(let name, let args):
            guard args.count == 1 else { throw mathError("Unsupported derivative.") }
            let a = args[0], inner = try d(a)
            var outer: Expression
            switch name {
            case "sin": outer = .call("cos", [a])
            case "cos": outer = b("*", .number("-1"), .call("sin", [a]))
            case "tan": outer = b("/", .number("1"), b("^", .call("cos", [a]), .number("2")))
            case "ln": outer = b("/", .number("1"), a)
            case "exp": outer = .call("exp", [a])
            case "sqrt": outer = b("/", .number("1"), b("*", .number("2"), .call("sqrt", [a])))
            default: throw mathError("Differentiation does not support \(name).")
            }
            if degrees && ["sin", "cos", "tan"].contains(name) { outer = b("*", b("/", .symbol("pi"), .number("180")), outer) }
            return b("*", outer, inner)
        }
    }
    private func simplified(_ op: String, _ a: Expression, _ b: Expression) -> Expression {
        func number(_ e: Expression) -> Double? { if case .number(let n) = e { return Double(n) }; return nil }
        let x = number(a), y = number(b)
        if op == "*" && (x == 0 || y == 0) { return .number("0") }
        if (op == "+" || op == "-") && y == 0 { return a }
        if op == "+" && x == 0 { return b }
        if op == "*" && x == 1 { return b }
        if (op == "*" || op == "/" || op == "^") && y == 1 { return a }
        if op == "^" && y == 0 { return .number("1") }
        return .binary(op, a, b)
    }
    func polynomial(_ e: Expression, variable: String) throws -> [Scalar] {
        try tick()
        if case .symbol(let name) = e, name == variable { return [.zero, .one, .zero] }
        if case .unary(let a) = e { return try polynomial(a, variable: variable).map { $0.negated() } }
        if case .binary(let op, let a, let b) = e {
            let p = try polynomial(a, variable: variable), q = try polynomial(b, variable: variable)
            switch op {
            case "+", "-", "=": return try zip(p,q).map { try $0.adding(op == "+" ? $1 : $1.negated()).checked() }
            case "*": return try multiplyPolynomials(p, q)
            case "/":
                guard q[1].isZero, q[2].isZero else { throw mathError("Polynomial division requires a constant denominator.") }
                return try p.map { try $0.dividing(q[0]) }
            case "^":
                guard q[1].isZero, q[2].isZero, q[0].im == 0, [0.0, 1.0, 2.0].contains(q[0].re) else { throw mathError("Solve supports polynomial powers 0, 1, and 2.") }
                if q[0].re == 0 { return [.one, .zero, .zero] }
                return q[0].re == 1 ? p : try multiplyPolynomials(p, p)
            default: break
            }
        }
        let q = try evaluate(e)
        guard q.isDimensionless, q.value.im == 0 else { throw mathError("Solve requires real, dimensionless coefficients.") }
        return [q.value, .zero, .zero]
    }
    private func multiplyPolynomials(_ p: [Scalar], _ q: [Scalar]) throws -> [Scalar] {
        var r = Array(repeating: Scalar.zero, count: 5)
        for i in 0...2 { for j in 0...2 { r[i+j] = try r[i+j].adding(p[i].multiplying(q[j])).checked() } }
        guard r[3].isZero, r[4].isZero else { throw mathError("Solve supports degree two or lower.") }
        return Array(r.prefix(3))
    }
}

struct NativeMath {
    func evaluate(_ input: String, exact: Bool, degrees: Bool) throws -> Calculation {
        var parser = try Parser(input)
        let (expression, target) = try parser.parse()
        let evaluator = Evaluator(degrees: degrees)
        var text: String, latex: String, approximate = false
        var warnings: [String] = []
        if case .call(let name, let args) = expression, ["diff", "solve"].contains(name) {
            guard target == nil, args.count == 2, case .symbol(let variable) = args[1],
                  !["pi", "π", "e", "i"].contains(variable), UnitDefinition.all[variable] == nil else {
                throw mathError("Use \(name)(expression, variable), with a variable such as x.")
            }
            if name == "diff" {
                let result = try evaluator.derivative(args[0], variable: variable)
                text = result.text; latex = result.latex
                warnings = ["Symbolic derivative on the original expression's domain; singularities are not tracked."]
            } else {
                let p = try evaluator.polynomial(args[0], variable: variable)
                let c = p[0], b = p[1], a = p[2]
                var roots: [Scalar]
                if a.isZero {
                    guard !b.isZero else { throw mathError(c.isZero ? "Every value satisfies this equation." : "This equation has no solution.") }
                    roots = [try c.negated().dividing(b)]
                } else {
                    let disc = try b.multiplying(b).adding(Scalar.integer(4).multiplying(a).multiplying(c).negated()).checked()
                    let root: Scalar
                    if disc.re >= 0 {
                        let r = sqrt(disc.re)
                        var fraction: Rational?
                        if let f = disc.fraction, f.n >= 0 {
                            let n = Int64(Double(f.n).squareRoot()), d = Int64(Double(f.d).squareRoot())
                            if n.multipliedReportingOverflow(by: n) == (f.n, false), d.multipliedReportingOverflow(by: d) == (f.d, false) { fraction = Rational(n, d) }
                        }
                        root = Scalar(r, fraction: fraction)
                    } else { root = Scalar(0, sqrt(-disc.re)) }
                    let denominator = Scalar.integer(2).multiplying(a)
                    if root.isZero { roots = [try b.negated().dividing(denominator)] }
                    else if root.im == 0 {
                        // Stable quadratic formula avoids subtracting nearly equal floating values.
                        let q = Scalar(-0.5, fraction: Rational(-1, 2)).multiplying(b.adding(b.re < 0 ? root.negated() : root))
                        roots = [try q.dividing(a), try c.dividing(q)]
                    } else {
                        roots = [try b.negated().adding(root).dividing(denominator), try b.negated().adding(root.negated()).dividing(denominator)]
                    }
                }
                let rendered = roots.map { $0.rendered(exact: exact) }
                text = roots.count == 1 ? rendered[0].0 : "{" + rendered.map(\.0).joined(separator: ", ") + "}"
                latex = roots.count == 1 ? rendered[0].1 : "\\left\\{" + rendered.map(\.1).joined(separator: ", ") + "\\right\\}"
                approximate = roots.contains { $0.isApproximate(exact: exact) }
            }
        } else {
            var quantity = try evaluator.evaluate(expression)
            var suffixText = "", suffixLatex = ""
            if let target {
                guard isUnitExpression(target) else { throw mathError("Conversion target must contain only units and integer powers.") }
                let unit = try evaluator.evaluate(target)
                guard quantity.dimensions == unit.dimensions else { throw mathError("Incompatible conversion dimensions.") }
                quantity.value = try quantity.value.dividing(unit.value)
                suffixText = "*(\(target.text))"; suffixLatex = "\\,\(target.latex)"
            } else if !quantity.isDimensionless {
                let names = ["m", "kg", "s", "K"]
                let pieces = zip(names, quantity.dimensions).filter { $0.1 != 0 }
                suffixText = "*" + pieces.map { $0.1 == 1 ? $0.0 : "\($0.0)^(\($0.1))" }.joined(separator: "*")
                suffixLatex = "\\," + pieces.map { "\\mathrm{\($0.0)}" + ($0.1 == 1 ? "" : "^{\($0.1)}") }.joined(separator: "\\,")
            }
            let rendered = quantity.value.rendered(exact: exact)
            text = suffixText.isEmpty ? rendered.0 : "(\(rendered.0))" + suffixText
            latex = rendered.1 + suffixLatex
            approximate = quantity.value.isApproximate(exact: exact)
            if exact && quantity.value.fraction == nil { warnings = ["Approximate result (about 15 significant digits). Exact fractions use signed 64-bit integers."] }
        }
        let inputLatex = expression.latex + (target.map { "\\;\\to\\;" + $0.latex } ?? "")
        return Calculation(id: UUID(), date: Date(), expression: input, text: text, latex: latex,
                           inputLatex: inputLatex, approximate: approximate, warnings: warnings)
    }
    private func isUnitExpression(_ e: Expression) -> Bool {
        switch e {
        case .symbol(let name): return UnitDefinition.all[name] != nil
        case .binary(let op, let a, let b):
            if op == "*" || op == "/" { return isUnitExpression(a) && isUnitExpression(b) }
            if op == "^" {
                if case .number(let n) = b { return isUnitExpression(a) && Int(n) != nil }
                if case .unary(.number(let n)) = b { return isUnitExpression(a) && Int(n) != nil }
            }
            return false
        default: return false
        }
    }
}
