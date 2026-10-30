import SwiftUI

private struct GraphRequest: Hashable {
    let equations: String
    let centerX: Double
    let centerY: Double
    let spanX: Double
    let spanY: Double
}
struct GraphingView: View {
    @State private var equations: [GraphEquation]
    @State private var window = GraphWindow()
    @State private var curves: [GraphCurve] = []
    @State private var traceX: Double?
    @FocusState private var editing: UUID?
    private let colors: [Color] = [.cyan, .orange, .pink, .green]
    init() {
        let saved = UserDefaults.standard.data(forKey: "graphEquations")
        let decoded = saved.flatMap { try? JSONDecoder().decode([GraphEquation].self, from: $0) }
        _equations = State(initialValue: decoded.map { Array($0.prefix(4)) }.flatMap { $0.isEmpty ? nil : $0 } ?? [GraphEquation()])
    }
    private var request: GraphRequest {
        GraphRequest(equations: equations.map { "\($0.id):\($0.visible):\($0.expression)" }.joined(separator: "|"), centerX: window.centerX, centerY: window.centerY, spanX: window.spanX, spanY: window.spanY)
    }
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 10) {
                plot
                controls.frame(height: min(220, geometry.size.height * 0.4))
            }
            .padding(.horizontal, 12).padding(.bottom, 12)
        }
        .task(id: request) {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            let equations = equations, window = window
            let sampled = await Task.detached(priority: .userInitiated) {
                equations.map { GraphSampler.sample($0, window: window) }
            }.value
            if !Task.isCancelled { curves = sampled }
        }
        .onChange(of: equations) { _, value in
            if let data = try? JSONEncoder().encode(value) { UserDefaults.standard.set(data, forKey: "graphEquations") }
        }
    }
    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Functions").font(.headline)
                Spacer()
                Button { equations.append(GraphEquation(expression: "x")); editing = equations.last?.id } label: { Image(systemName: "plus") }
                    .disabled(equations.count >= 4).accessibilityLabel("Add graph function")
                if editing != nil { Button("Done") { editing = nil } }
            }
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Array(equations.enumerated()), id: \.element.id) { index, equation in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Button { equations[index].visible.toggle() } label: {
                                    Image(systemName: equation.visible ? "circle.fill" : "circle").foregroundStyle(colors[index])
                                }.accessibilityLabel("Toggle function \(index+1)")
                                TextField("y = sin(x)", text: $equations[index].expression)
                                    .font(.callout.monospaced()).textFieldStyle(.roundedBorder)
                                    .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.asciiCapable)
                                    .focused($editing, equals: equation.id).submitLabel(.done).onSubmit { editing = nil }
                                    .accessibilityIdentifier("graphFunction\(index)")
                                if equations.count > 1 {
                                    Button { equations.remove(at: index) } label: { Image(systemName: "minus.circle") }.accessibilityLabel("Remove function \(index+1)")
                                }
                            }
                            if let error = curves.first(where: { $0.id == equation.id })?.error {
                                Text(error).font(.caption2).foregroundStyle(.secondary)
                            }
                            if let x = traceX, equation.visible,
                               let function = try? NativeMath().graphFunction(equation.expression), let y = function(x) {
                                Text(String(format: "(%.6g, %.6g)", x, y)).font(.caption.monospacedDigit()).foregroundStyle(colors[index])
                                    .accessibilityIdentifier("graphPoint\(index)")
                            }
                        }
                    }
                }
            }
            Text("Use x, powers, sin, cos, tan, sqrt, abs, ln, log or exp. Angles are radians.").font(.caption2).foregroundStyle(.secondary)
        }
    }
    private var plot: some View {
        VStack(spacing: 6) {
            HStack {
                Button { window.zoom(0.5) } label: { Image(systemName: "plus.magnifyingglass") }.accessibilityLabel("Zoom in")
                Button { window.zoom(2) } label: { Image(systemName: "minus.magnifyingglass") }.accessibilityLabel("Zoom out")
                Button("Reset") { window = GraphWindow(); traceX = nil }.accessibilityIdentifier("graphReset")
                Spacer()
                Text("Drag · pinch · tap to inspect").font(.caption2).foregroundStyle(.secondary)
            }.buttonStyle(.bordered)
            GeometryReader { geometry in
                Canvas { context, size in draw(context: &context, size: size) }
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 8).onEnded { value in
                        window.centerX -= value.translation.width / geometry.size.width * window.spanX
                        window.centerY += value.translation.height / geometry.size.height * window.spanY
                        window.centerX = min(1e10, max(-1e10, window.centerX))
                        window.centerY = min(1e10, max(-1e10, window.centerY))
                        traceX = nil; editing = nil
                    })
                    .simultaneousGesture(MagnificationGesture().onEnded { scale in window.zoom(1 / scale); traceX = nil; editing = nil })
                    .simultaneousGesture(SpatialTapGesture().onEnded { value in
                        traceX = window.xMin + value.location.x/geometry.size.width * window.spanX; editing = nil
                    })
                    .accessibilityLabel("Function graph")
                    .accessibilityValue("\(curves.filter { !$0.segments.isEmpty }.count) curves; x from \(window.xMin) to \(window.xMin + window.spanX)")
                    .accessibilityIdentifier("functionGraph")
            }
        }
    }
    private func draw(context: inout GraphicsContext, size: CGSize) {
        func px(_ x: Double) -> CGFloat { (x-window.xMin)/window.spanX * size.width }
        func py(_ y: Double) -> CGFloat { size.height - (y-window.yMin)/window.spanY * size.height }
        var grid = Path()
        let stepX = GraphSampler.step(for: window.spanX), stepY = GraphSampler.step(for: window.spanY)
        for index in 0..<16 {
            let x = ceil(window.xMin/stepX)*stepX + Double(index)*stepX
            if x <= window.xMin + window.spanX {
                let screen = px(x)
                grid.move(to: CGPoint(x: screen, y: 0)); grid.addLine(to: CGPoint(x: screen, y: size.height))
                context.draw(Text(String(format: "%.4g", x)).font(.system(size: 10)).foregroundColor(.secondary), at: CGPoint(x: screen+3, y: min(size.height-10, max(10, py(0)+10))), anchor: .leading)
            }
            let y = ceil(window.yMin/stepY)*stepY + Double(index)*stepY
            if y <= window.yMin + window.spanY {
                let screen = py(y)
                grid.move(to: CGPoint(x: 0, y: screen)); grid.addLine(to: CGPoint(x: size.width, y: screen))
                if abs(y) > stepY*0.01 { context.draw(Text(String(format: "%.4g", y)).font(.system(size: 10)).foregroundColor(.secondary), at: CGPoint(x: min(size.width-30, max(5, px(0)+5)), y: screen-6), anchor: .leading) }
            }
        }
        context.stroke(grid, with: .color(.secondary.opacity(0.18)), lineWidth: 0.5)
        var axes = Path()
        if window.xMin <= 0, window.xMin + window.spanX >= 0 { axes.move(to: CGPoint(x: px(0), y: 0)); axes.addLine(to: CGPoint(x: px(0), y: size.height)) }
        if window.yMin <= 0, window.yMin + window.spanY >= 0 { axes.move(to: CGPoint(x: 0, y: py(0))); axes.addLine(to: CGPoint(x: size.width, y: py(0))) }
        context.stroke(axes, with: .color(.secondary), lineWidth: 1)
        for (index, equation) in equations.enumerated() {
            guard let curve = curves.first(where: { $0.id == equation.id }), equation.visible else { continue }
            var path = Path()
            for segment in curve.segments {
                for (offset, point) in segment.enumerated() {
                    let point = CGPoint(x: px(point.x), y: py(point.y))
                    if offset == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
            }
            context.stroke(path, with: .color(colors[index]), lineWidth: 2)
            if let x = traceX, let function = try? NativeMath().graphFunction(equation.expression), let y = function(x) {
                let circle = Path(ellipseIn: CGRect(x: px(x)-4, y: py(y)-4, width: 8, height: 8))
                context.fill(circle, with: .color(colors[index]))
            }
        }
    }
}
