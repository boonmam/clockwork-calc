import Foundation

struct GraphEquation: Codable, Identifiable, Equatable {
    var id = UUID()
    var expression = "sin(x)"
    var visible = true
}
struct GraphWindow: Codable, Equatable {
    var centerX = 0.0
    var centerY = 0.0
    var spanX = 20.0
    var spanY = 20.0
    var xMin: Double { centerX - spanX/2 }
    var yMin: Double { centerY - spanY/2 }
    var xMax: Double { centerX + spanX/2 }
    var yMax: Double { centerY + spanY/2 }
    var isValid: Bool {
        centerX.isFinite && centerY.isFinite && abs(centerX) <= 1e10 && abs(centerY) <= 1e10 &&
        (1e-6...1e8).contains(spanX) && (1e-6...1e8).contains(spanY)
    }
    static func bounds(xMin: Double, xMax: Double, yMin: Double, yMax: Double) throws -> GraphWindow {
        let value = GraphWindow(centerX: xMin + (xMax-xMin)/2, centerY: yMin + (yMax-yMin)/2, spanX: xMax-xMin, spanY: yMax-yMin)
        guard [xMin,xMax,yMin,yMax].allSatisfy(\.isFinite), value.isValid else {
            throw CalculationError(message: "Each minimum must be below its maximum. Use axis spans from 0.000001 to 100000000 and centers within ±10000000000.")
        }
        return value
    }
    mutating func zoom(_ factor: Double) {
        guard factor.isFinite, factor > 0 else { return }
        spanX = min(1e8, max(1e-6, spanX*factor))
        spanY = min(1e8, max(1e-6, spanY*factor))
    }
}
struct GraphPoint { let x: Double; let y: Double }
struct GraphCurve {
    let id: UUID
    var segments: [[GraphPoint]] = []
    var error: String?
}
enum GraphSampler {
    static func sample(_ equation: GraphEquation, window: GraphWindow, count: Int = 700, constants: [String: Double] = [:]) -> GraphCurve {
        var curve = GraphCurve(id: equation.id)
        guard equation.visible else { return curve }
        do {
            let evaluate = try NativeMath().graphFunction(equation.expression, constants: constants)
            var segment: [GraphPoint] = []
            var previous: GraphPoint?
            let samples = min(1400, max(100, count))
            for index in 0...samples {
                if Task.isCancelled { return curve }
                let x = window.xMin + Double(index) / Double(samples) * window.spanX
                guard let y = evaluate(x), abs(y - window.centerY) <= window.spanY * 2 else {
                    if segment.count > 1 { curve.segments.append(segment) }
                    segment = []; previous = nil; continue
                }
                let point = GraphPoint(x: x, y: y)
                var continuous = true
                if let previous {
                    if let middle = evaluate((x+previous.x)/2) {
                        continuous = abs(y - previous.y) < window.spanY * 0.4 && abs(middle - (y+previous.y)/2) < window.spanY * 0.05
                    } else { continuous = false }
                }
                if !continuous {
                    if segment.count > 1 { curve.segments.append(segment) }
                    segment = []
                }
                segment.append(point); previous = point
            }
            if segment.count > 1 { curve.segments.append(segment) }
            if curve.segments.isEmpty { curve.error = "No visible real-valued curve in this window." }
        } catch { curve.error = error.localizedDescription }
        return curve
    }
    static func step(for span: Double) -> Double {
        let raw = span/8
        let power = pow(10, floor(log10(raw)))
        let base = raw/power
        return (base <= 1 ? 1 : base <= 2 ? 2 : base <= 5 ? 5 : 10) * power
    }
}


struct GraphConstant: Codable, Identifiable, Equatable {
    var id = UUID()
    var name = "a"
    var value = 1.0
    var minimum = -10.0
    var maximum = 10.0
    var step = 0.1
    static func addingMissing(for equations: [GraphEquation], to existing: [GraphConstant]) -> [GraphConstant] {
        var result = existing
        let names = Set(equations.flatMap { (try? NativeMath().graphConstantNames($0.expression)) ?? [] }).sorted()
        for name in names where !result.contains(where: { $0.name == name }) && result.count < 8 {
            let constant = GraphConstant(name: name)
            if (try? constant.validate()) != nil { result.append(constant) }
        }
        return result
    }
    static let reserved = ["x", "y", "pi", "π", "e", "i", "sin", "cos", "tan", "asin", "acos", "atan", "sqrt", "abs", "ln", "log", "exp", "floor", "ceil"]
    func validate() throws {
        guard name.count <= 12, name.range(of: "^[A-Za-z]+$", options: .regularExpression) != nil,
              !Self.reserved.contains(name) else { throw CalculationError(message: "Use letters for constant names, such as a, b, or gain. Names x, y, pi, e and function names are reserved.") }
        guard [value,minimum,maximum,step].allSatisfy(\.isFinite), minimum < maximum,
              (maximum-minimum).isFinite, step > 0, step <= maximum-minimum, (maximum-minimum)/step <= 1_000_000,
              (minimum...maximum).contains(value) else { throw CalculationError(message: "Use a valid minimum, maximum, and positive step. The value must be inside the range; use no more than one million steps.") }
    }
}
