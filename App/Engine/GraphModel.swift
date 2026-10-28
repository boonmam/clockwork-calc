import Foundation

struct GraphEquation: Codable, Identifiable, Equatable {
    var id = UUID()
    var expression = "sin(x)"
    var visible = true
}
struct GraphWindow: Equatable {
    var centerX = 0.0
    var centerY = 0.0
    var spanX = 20.0
    var spanY = 20.0
    var xMin: Double { centerX - spanX/2 }
    var yMin: Double { centerY - spanY/2 }
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
    static func sample(_ equation: GraphEquation, window: GraphWindow, count: Int = 700) -> GraphCurve {
        var curve = GraphCurve(id: equation.id)
        guard equation.visible else { return curve }
        do {
            let evaluate = try NativeMath().graphFunction(equation.expression)
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
