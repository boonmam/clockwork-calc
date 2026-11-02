import SwiftUI

private struct GraphRequest: Hashable {
    let equations: String
    let constants: String
    let centerX: Double
    let centerY: Double
    let spanX: Double
    let spanY: Double
}
struct GraphingView: View {
    @State private var equations: [GraphEquation]
    @State private var window = GraphWindow()
    @State private var constants: [GraphConstant] = []
    @State private var variablesPresented = false
    @State private var variableLetters = false
    @State private var uppercaseVariables = false
    @State private var axesPresented = false
    @State private var constantEditor: GraphConstant?
    @State private var curves: [GraphCurve] = []
    @State private var traceX: Double?
    @State private var editing: UUID?
    @State private var graphKeyboardVisible = false
    @State private var selections: [UUID: NSRange] = [:]
    private let colors: [Color] = [.cyan, .orange, .pink, .green, .purple, .yellow, .blue, .mint]
    init() {
        let saved = UserDefaults.standard.data(forKey: "graphEquations")
        let decoded = saved.flatMap { try? JSONDecoder().decode([GraphEquation].self, from: $0) }
        _equations = State(initialValue: decoded.map { Array($0.prefix(12)) }.flatMap { $0.isEmpty ? nil : $0 } ?? [GraphEquation()])
        if let data = UserDefaults.standard.data(forKey: "graphWindow"), let saved = try? JSONDecoder().decode(GraphWindow.self, from: data), saved.isValid { _window = State(initialValue: saved) }
        if let data = UserDefaults.standard.data(forKey: "graphConstants"), let saved = try? JSONDecoder().decode([GraphConstant].self, from: data) {
            var names = Set<String>()
            _constants = State(initialValue: Array(saved.filter { (try? $0.validate()) != nil && names.insert($0.name).inserted }.prefix(8)))
        }
    }
    private var constantValues: [String: Double] { Dictionary(uniqueKeysWithValues: constants.map { ($0.name, $0.value) }) }
    private var request: GraphRequest {
        GraphRequest(equations: equations.map { "\($0.id):\($0.visible):\($0.expression)" }.joined(separator: "|"), constants: constants.map { "\($0.name)=\($0.value)" }.joined(separator: "|"), centerX: window.centerX, centerY: window.centerY, spanX: window.spanX, spanY: window.spanY)
    }
    var body: some View {
        GeometryReader { geometry in
            let height = max(0, geometry.size.height-12)
            let keypad = editing != nil && !graphKeyboardVisible
            let wide = geometry.size.width >= 620
            Group {
                if keypad && wide {
                    HStack(spacing: 12) {
                        VStack(spacing: 10) {
                            plot
                            controls.frame(height: min(160, height*0.28))
                        }
                        graphKeypad(height: min(72, max(26, (height-30)/6)))
                            .frame(width: (geometry.size.width-36)*0.49)
                    }
                } else {
                    VStack(spacing: 10) {
                        plot
                        controls.frame(height: keypad ? min(140, height*0.2) : min(220, height*0.4))
                        if keypad { graphKeypad(height: max(24, (height*0.5-30)/6)).frame(height: height*0.5) }
                    }
                }
            }
            .padding(.horizontal, 12).padding(.bottom, 12)
        }
        .ignoresSafeArea(.keyboard, edges: axesPresented ? .bottom : [])
        .task(id: equations) {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let updated = GraphConstant.addingMissing(for: equations, to: constants)
            if updated != constants { constants = updated }
        }
        .task(id: request) {
            guard !Task.isCancelled else { return }
            let equations = equations, window = window, values = constantValues
            let sampling = Task.detached(priority: .userInitiated) {
                GraphSampler.sampleAll(equations, window: window, constants: values)
            }
            let sampled = await withTaskCancellationHandler(operation: { await sampling.value }, onCancel: { sampling.cancel() })
            if !Task.isCancelled { curves = sampled }
        }
        .onChange(of: equations) { _, value in
            if let data = try? JSONEncoder().encode(value) { UserDefaults.standard.set(data, forKey: "graphEquations") }
        }
        .onChange(of: constants) { _, value in
            if let data = try? JSONEncoder().encode(value) { UserDefaults.standard.set(data, forKey: "graphConstants") }
        }
        .onChange(of: window) { _, value in
            if value.isValid, let data = try? JSONEncoder().encode(value) { UserDefaults.standard.set(data, forKey: "graphWindow") }
        }
        .sheet(item: $constantEditor) { constant in
            GraphConstantEditor(constant: constant, usedNames: constants.filter { $0.id != constant.id }.map(\.name)) { updated in
                if let index = constants.firstIndex(where: { $0.id == updated.id }) { constants[index] = updated }
                else { constants.append(updated) }
            }
        }
    }
    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Functions").font(.headline)
                Spacer()
                Button { equations.append(GraphEquation(expression: "x")); editing = equations.last?.id } label: { Image(systemName: "plus") }
                    .disabled(equations.count >= 12).accessibilityLabel("Add graph function")
                Button {
                    let name = ["a", "b", "c", "d", "k", "m", "n", "p"].first { candidate in !constants.contains(where: { $0.name == candidate }) } ?? "a"
                    finishEditing(); constantEditor = GraphConstant(name: name)
                } label: { Image(systemName: "slider.horizontal.3") }
                    .disabled(constants.count >= 8).accessibilityLabel("Add constant slider")
                if editing != nil {
                    Button { graphKeyboardVisible.toggle() } label: { Image(systemName: graphKeyboardVisible ? "square.grid.3x3" : "keyboard") }
                        .accessibilityLabel(graphKeyboardVisible ? "Use graph keypad" : "Use graph keyboard")
                    Button("Done", action: finishEditing)
                }
            }
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Array(equations.enumerated()), id: \.element.id) { index, equation in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Button { equations[index].visible.toggle() } label: {
                                    Image(systemName: equation.visible ? "circle.fill" : "circle").foregroundStyle(colors[index % colors.count])
                                }.disabled(equation.definitionName != nil).accessibilityLabel(equation.definitionName.map { "Definition " + $0 } ?? "Toggle function \(index+1)")
                                ExpressionEditor(text: $equations[index].expression,
                                    selection: Binding(get: { selections[equation.id] ?? NSRange(location: equation.expression.utf16.count, length: 0) }, set: { selections[equation.id] = $0 }),
                                    keyboardVisible: Binding(get: { editing == equation.id && graphKeyboardVisible }, set: { if editing == equation.id { graphKeyboardVisible = $0 } }),
                                    calculate: finishEditing, accessibilityIdentifier: "graphFunction\(index)", accessibilityLabel: "Graph function \(index+1)",
                                    onFocus: { editing = equation.id })
                                    .frame(height: 52)
                                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                                if equations.count > 1 {
                                    Button { equations.remove(at: index) } label: { Image(systemName: "minus.circle") }.accessibilityLabel("Remove function \(index+1)")
                                }
                            }
                            if let error = curves.first(where: { $0.id == equation.id })?.error {
                                Text(error).font(.caption2).foregroundStyle(.secondary)
                            }
                            if let name = equation.definitionName { Text("Defines \(name)").font(.caption2).foregroundStyle(.secondary) }
                            ForEach(curves.filter { $0.id == equation.id && $0.evaluate != nil }, id: \.variant) { curve in
                                HStack(spacing: 6) {
                                    if let label = curve.seriesLabel { Text(label).font(.caption2) }
                                    if let x = traceX, let y = curve.evaluate?(x) {
                                        Text(String(format: "(%.6g, %.6g)", x, y)).font(.caption.monospacedDigit())
                                            .accessibilityIdentifier(curve.variant == 0 ? "graphPoint\(index)" : "graphPoint\(index)_\(curve.variant)")
                                    }
                                }.foregroundStyle(colors[(index+curve.variant) % colors.count])
                            }
                        }
                    }
                    ForEach(Array(constants.enumerated()), id: \.element.id) { index, constant in
                        HStack(spacing: 8) {
                            Button { finishEditing(); constantEditor = constant } label: {
                                Text("\(constant.name) = " + String(format: "%.6g", constant.value)).font(.caption.monospacedDigit())
                            }.accessibilityLabel("Edit slider \(constant.name)")
                            Slider(value: $constants[index].value, in: constant.minimum...constant.maximum, step: constant.step)
                                .accessibilityLabel("Constant \(constant.name)").accessibilityIdentifier("graphSlider_\(constant.name)")
                            Button { constants.remove(at: index) } label: { Image(systemName: "minus.circle") }.accessibilityLabel("Remove slider \(constant.name)")
                        }
                    }
                }
            }
            Text("Use = for definitions; C=[1u,10u,30u,60u] draws a curve for each value.").font(.caption2).foregroundStyle(.secondary)
        }
    }
    private var variableNames: [String] {
        Array(Set(constants.map(\.name) + equations.compactMap(\.definitionName))).sorted()
    }
    private func finishEditing() {
        editing = nil; graphKeyboardVisible = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    private func insertGraphKey(_ key: String) {
        guard let index = equations.firstIndex(where: { $0.id == editing }) else { return }
        CalculatorHaptics.keyPress()
        if key == "Plot" { finishEditing(); return }
        let source = equations[index].expression as NSString
        let selection = selections[equations[index].id] ?? NSRange(location: source.length, length: 0)
        let start = min(selection.location, source.length)
        let range = NSRange(location: start, length: min(selection.length, source.length-start))
        if key == "AC" {
            equations[index].expression = ""; selections[equations[index].id] = NSRange(location: 0, length: 0); return
        }
        if key == "⌫" {
            guard start > 0 || range.length > 0 else { return }
            let removing = range.length > 0 ? range : source.rangeOfComposedCharacterSequence(at: start-1)
            equations[index].expression = source.replacingCharacters(in: removing, with: "")
            selections[equations[index].id] = NSRange(location: removing.location, length: 0); return
        }
        var value = ["sin": "sin(", "cos": "cos(", "tan": "tan(", "ln": "ln(", "√": "sqrt(", "×": "*", "÷": "/", "−": "-" ][key] ?? key
        if key == "EE" {
            let prefix = source.substring(to: start).trimmingCharacters(in: .whitespaces)
            if prefix.range(of: #"(?<![A-Za-z_0-9.])(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)$"#, options: .regularExpression) != nil { value = "e" }
            else { value = prefix.last.map { $0.isNumber || $0.isLetter || $0 == ")" } == true ? "*10^" : "10^" }
        }
        equations[index].expression = source.replacingCharacters(in: range, with: value)
        selections[equations[index].id] = NSRange(location: start + value.utf16.count, length: 0)
    }
    private func graphKeypad(height: CGFloat) -> some View {
        let keys = ["ƒ", "Vars", "^", "AC", "⌫", "x", "y", "=", "(", ")", "7", "8", "9", ",", "÷", "4", "5", "6", "EE", "×", "1", "2", "3", "u", "−", "0", ".", "√", "+", "Plot"]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
            ForEach(keys, id: \.self) { key in
                if key == "Vars" {
                    Button { variablesPresented = true } label: { graphKeyLabel(key, height: height) }
                        .buttonStyle(.plain).accessibilityIdentifier("graphKey_Vars")
                        .popover(isPresented: $variablesPresented) {
                            variablePicker.frame(width: 230)
                                .presentationCompactAdaptation(.popover)
                        }
                } else if key == "ƒ" {
                    Menu {
                        Section("Trigonometry") {
                            ForEach(["sin", "cos", "tan", "asin", "acos", "atan"], id: \.self) { name in
                                Button(name) { insertGraphKey(name + "(") }
                            }
                        }
                        Section("Functions") {
                            ForEach(["ln", "exp", "abs", "floor", "ceil"], id: \.self) { name in
                                Button(name) { insertGraphKey(name + "(") }
                            }
                        }
                        Section("Constants and symbols") {
                            Button("π") { insertGraphKey("pi") }
                            Button("e") { insertGraphKey("e") }
                            ForEach(["[", "]"], id: \.self) { symbol in Button(symbol) { insertGraphKey(symbol) } }
                        }
                    } label: { graphKeyLabel(key, height: height) }
                        .accessibilityLabel("Functions").accessibilityIdentifier("graphKey_Functions")
                } else if key == "(" || key == ")" {
                    let bracket = key == "(" ? "[" : "]"
                    graphKeyLabel(key, height: height)
                        .overlay(alignment: .topTrailing) {
                            Text(bracket).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary).padding(5)
                        }
                        .contentShape(Rectangle())
                        .gesture(LongPressGesture(minimumDuration: 0.4).exclusively(before: TapGesture()).onEnded { value in
                            switch value {
                            case .first: insertGraphKey(bracket)
                            case .second: insertGraphKey(key)
                            }
                        })
                        .accessibilityElement(children: .ignore)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel(key)
                        .accessibilityHint("Hold to insert \(bracket)")
                        .accessibilityAction { insertGraphKey(key) }
                        .accessibilityAction(named: Text("Insert \(bracket)")) { insertGraphKey(bracket) }
                        .accessibilityIdentifier("graphKey_\(key)")
                } else {
                    Button { insertGraphKey(key) } label: { graphKeyLabel(key, height: height) }
                        .buttonStyle(.plain).accessibilityIdentifier("graphKey_\(key)")
                }
            }
        }
    }
    private func chooseVariable(_ name: String) {
        insertGraphKey(name)
        variablesPresented = false
    }
    private var variablePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Variables").font(.headline)
                Spacer()
                Button("Done") { variablesPresented = false }
            }
            Picker("Variable selection", selection: $variableLetters) {
                Text("In use").tag(false)
                Text("Letters").tag(true)
            }.pickerStyle(.segmented)
            if variableLetters {
                Picker("Letter case", selection: $uppercaseVariables) {
                    Text("abc").tag(false)
                    Text("ABC").tag(true)
                }.pickerStyle(.segmented)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                    ForEach(Array((uppercaseVariables ? "ABCDEFGHIJKLMNOPQRSTUVWXYZ" : "abcdefghijklmnopqrstuvwxyz").map(String.init)), id: \.self) { name in
                        Button(name) { chooseVariable(name) }.frame(maxWidth: .infinity, minHeight: 32)
                    }
                }.buttonStyle(.bordered).controlSize(.mini)
                Text("Combine letters for names. New constants get sliders automatically.").font(.caption).foregroundStyle(.secondary)
            } else {
                HStack {
                    ForEach(["x", "y"], id: \.self) { name in
                        Button(name) { chooseVariable(name) }.frame(maxWidth: .infinity)
                    }
                }.buttonStyle(.bordered)
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(variableNames, id: \.self) { name in
                            Button { chooseVariable(name) } label: {
                                HStack {
                                    Text(name).font(.body.monospaced().bold()).frame(minWidth: 32, alignment: .leading)
                                    Text(variableDetail(name)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    Spacer(minLength: 0)
                                }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                            }.buttonStyle(.plain).accessibilityLabel(name).accessibilityValue(variableDetail(name))
                        }
                    }
                }.frame(maxHeight: 140)
                Text("Quick letters").font(.caption).foregroundStyle(.secondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                    ForEach(["M", "C", "n", "a", "b", "c", "k", "t"].filter { !variableNames.contains($0) }, id: \.self) { name in
                        Button(name) { chooseVariable(name) }.frame(maxWidth: .infinity, minHeight: 32)
                    }
                }.buttonStyle(.bordered)
            }
        }.padding(16)
    }
    private func variableDetail(_ name: String) -> String {
        if let equation = equations.first(where: { $0.definitionName == name }), let equal = equation.expression.firstIndex(of: "=") {
            return "= " + equation.expression[equation.expression.index(after: equal)...].trimmingCharacters(in: .whitespaces)
        }
        if let constant = constants.first(where: { $0.name == name }) { return "= " + String(format: "%.6g", constant.value) + " · slider" }
        return ""
    }
    private func graphKeyLabel(_ key: String, height: CGFloat) -> some View {
        Text(key).font(.system(size: key.count > 2 ? 16 : 21, weight: .medium, design: .rounded))
            .frame(maxWidth: .infinity).frame(height: height)
            .overlay(alignment: .bottom) {
                if key == "u" { Text("micro").font(.system(size: 8)).foregroundStyle(.secondary).fixedSize().padding(.bottom, 2) }
            }
            .foregroundStyle(key == "Plot" ? Color.calculatorAccentText : Color.primary)
            .background(key == "Plot" ? Color.calculatorAccent : Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 9))
    }
    private var plot: some View {
        VStack(spacing: 6) {
            HStack {
                Button { window.zoom(0.5) } label: { Image(systemName: "plus.magnifyingglass") }.accessibilityLabel("Zoom in")
                Button { window.zoom(2) } label: { Image(systemName: "minus.magnifyingglass") }.accessibilityLabel("Zoom out")
                Button("Reset") { window = GraphWindow(); traceX = nil }.accessibilityIdentifier("graphReset")
                Button("Axes") { finishEditing(); axesPresented = true }.accessibilityIdentifier("graphAxes")
                    .popover(isPresented: $axesPresented, arrowEdge: .top) {
                        GraphAxesEditor(window: $window).frame(width: 260)
                            .presentationCompactAdaptation(.popover)
                    }
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
                        traceX = nil; finishEditing()
                    })
                    .simultaneousGesture(MagnificationGesture().onEnded { scale in window.zoom(1 / scale); traceX = nil; finishEditing() })
                    .simultaneousGesture(SpatialTapGesture().onEnded { value in
                        traceX = window.xMin + value.location.x/geometry.size.width * window.spanX; finishEditing()
                    })
                    .accessibilityLabel("Function graph")
                    .accessibilityValue(graphDescription)
                    .accessibilityIdentifier("functionGraph")
            }
        }
    }
    private var graphDescription: String {
        "\(curves.filter { !$0.segments.isEmpty }.count) curves; x from \(window.xMin) to \(window.xMax); y from \(window.yMin) to \(window.yMax)"
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
        for (index, equation) in equations.enumerated() where equation.visible && equation.definitionName == nil {
            for curve in curves.filter({ $0.id == equation.id }) {
                var path = Path()
                for segment in curve.segments {
                    for (offset, point) in segment.enumerated() {
                        let point = CGPoint(x: px(point.x), y: py(point.y))
                        if offset == 0 { path.move(to: point) } else { path.addLine(to: point) }
                    }
                }
                let color = colors[(index+curve.variant) % colors.count]
                context.stroke(path, with: .color(color), lineWidth: 2)
                if let x = traceX, let y = curve.evaluate?(x) {
                    let circle = Path(ellipseIn: CGRect(x: px(x)-4, y: py(y)-4, width: 8, height: 8))
                    context.fill(circle, with: .color(color))
                }
            }
        }
    }
}

private struct GraphAxesEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var window: GraphWindow
    @State private var original: GraphWindow
    @State private var fields: [String]
    @State private var active: Int?
    @State private var numericSelection = NSRange(location: 0, length: 0)
    @State private var error: String?
    private let labels = ["X min", "X max", "Y min", "Y max"]
    init(window: Binding<GraphWindow>) {
        _window = window
        _original = State(initialValue: window.wrappedValue)
        let initial = window.wrappedValue
        _fields = State(initialValue: [initial.xMin,initial.xMax,initial.yMin,initial.yMax].map { String(format: "%.12g", $0) })
    }
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Axes").font(.headline)
                Spacer()
                Button("Done") { dismiss() }.disabled(error != nil).accessibilityIdentifier("applyGraphAxes")
            }
            ForEach(0..<2) { axis in
                HStack(spacing: 6) {
                    Text(axis == 0 ? "X" : "Y").font(.callout).frame(width: 16)
                    ForEach(0..<2) { bound in
                        let index = axis*2+bound
                        QuickNumberEntry(text: $fields[index], active: $active, selection: $numericSelection, index: index,
                                         style: .keyboard, placeholder: labels[index], label: labels[index], identifier: "graphAxis\(index)")
                            .frame(height: 32)
                    }
                }
            }
            Text(error ?? "Min → Max · updates live").font(.caption2).foregroundStyle(error == nil ? Color.secondary : .red).frame(height: 24)
            HStack {
                Button("Cancel") { window = original; dismiss() }
                Spacer()
                Button("Reset") { fields = ["-10", "10", "-10", "10"] }
            }.font(.caption)
        }
        .padding(12)
        .onChange(of: fields) { _, fields in
            do {
                let numbers = try fields.map { text -> Double in
                    guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)) else { throw CalculationError(message: "Enter a number for every bound.") }
                    return value
                }
                window = try GraphWindow.bounds(xMin: numbers[0], xMax: numbers[1], yMin: numbers[2], yMax: numbers[3])
                error = nil
            } catch { self.error = error.localizedDescription }
        }
    }
}

private struct GraphConstantEditor: View {
    @Environment(\.dismiss) private var dismiss
    let constant: GraphConstant
    let usedNames: [String]
    let save: (GraphConstant) -> Void
    @State private var name: String
    @State private var fields: [String]
    @State private var active: Int?
    @State private var numericSelection = NSRange(location: 0, length: 0)
    @State private var error: String?
    private let labels = ["Value", "Minimum", "Maximum", "Step"]
    init(constant: GraphConstant, usedNames: [String], save: @escaping (GraphConstant) -> Void) {
        self.constant = constant; self.usedNames = usedNames; self.save = save
        _name = State(initialValue: constant.name)
        _fields = State(initialValue: [constant.value,constant.minimum,constant.maximum,constant.step].map { String(format: "%.12g", $0) })
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Constant") {
                    TextField("Name (a, b, gain…)", text: $name).textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("graphConstantName")
                    ForEach(0..<4) { index in
                        HStack {
                            Text(labels[index])
                            QuickNumberEntry(text: $fields[index], active: $active, selection: $numericSelection, index: index,
                                             style: .keyboard, placeholder: labels[index], label: labels[index], identifier: "graphConstantField\(index)")
                                .frame(height: 34)
                        }
                    }
                }
                Text("Use the name in your function, for example a*sin(x). Moving the slider updates every curve that uses it.")
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("Constant slider").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            let numbers = try fields.map { text -> Double in
                                guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)) else { throw CalculationError(message: "Enter a number in each field.") }
                                return value
                            }
                            var updated = constant
                            updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                            updated.value = numbers[0]; updated.minimum = numbers[1]; updated.maximum = numbers[2]; updated.step = numbers[3]
                            try updated.validate()
                            guard !usedNames.contains(updated.name) else { throw CalculationError(message: "A slider with this name already exists.") }
                            save(updated); dismiss()
                        } catch { self.error = error.localizedDescription }
                    }.accessibilityIdentifier("saveGraphConstant")
                }
            }
        }
    }
}
