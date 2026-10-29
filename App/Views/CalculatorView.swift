import SwiftUI

struct CalculatorView: View {
    @EnvironmentObject private var model: CalculatorModel
    @State private var historyPresented = false
    @State private var aboutPresented = false
    @State private var keyboardVisible = false
    @State private var matrixPresented = false
    @State private var notesPresented = false
    @State private var graphMode = false
    @State private var quickCalcMode = false
    @State private var conversionMode = false
    @State private var programmerMode = false
    @State private var verticalToolbar = false
    private var keys: [String] {
        ["sin", "cos", "tan", "AC", "⌫",
         "ln", "√", "^", "(", ")",
         "7", "8", "9", "EE", "÷",
         "4", "5", "6", "π", "×",
         "1", "2", "3", "Ans", "−",
         "0", ".", "to", "+", "="]
            .map { model.mode == .cas && $0 == "to" ? "x" : $0 }
    }

    var body: some View {
        NavigationStack {
            calculator
        }
        .sheet(isPresented: $historyPresented) { NavigationStack { HistoryView().navigationTitle("History").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { historyPresented = false } } } } }
        .sheet(isPresented: $aboutPresented) { AboutView() }
        .alert("Calculation notes", isPresented: $notesPresented) { Button("Done", role: .cancel) {} } message: {
            Text(model.result?.warnings.joined(separator: "\n\n") ?? "")
        }
        .sheet(isPresented: $matrixPresented) { MatrixEditor { text in model.mode = .cas; model.insert(text) } }
    }
    private var calculationSettings: some View {
        VStack(spacing: 12) {
            HStack {
                Picker("Result format", selection: $model.notation) {
                    ForEach(ResultNotation.allCases, id: \.self) { notation in
                        Text(notation.title).tag(notation)
                    }
                }.pickerStyle(.menu).accessibilityIdentifier("resultNotation").disabled(model.busy)
                Spacer(minLength: 12)
                if model.mode == .cas {
                    Text("Radians · symbolic").font(.caption).foregroundStyle(.secondary)
                } else { Picker("Angle unit", selection: $model.degrees) {
                    Text("RAD").tag(false); Text("DEG").tag(true)
                }.pickerStyle(.segmented).frame(width: 125) }
            }
        }
    }
    private var resultPanel: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                expressionInput
                if let result = model.result {
                    MathView(calculation: result).frame(minHeight: 120)
                    HStack {
                        if model.busy { ProgressView().controlSize(.small) }
                        Spacer()
                        Button { model.insert("(" + result.text + ")") } label: { Label("Use result", systemImage: "arrow.down.left") }
                        Button { UIPasteboard.general.string = result.text } label: { Label("Copy", systemImage: "doc.on.doc") }
                            .accessibilityIdentifier("copyResult").accessibilityValue(result.text)
                    }.font(.caption).buttonStyle(.borderless).padding(12)
                }
            }
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
            .layoutPriority(1)
            if model.busy && model.mode == .cas { Button("Cancel calculation", action: model.cancelCalculation).accessibilityIdentifier("cancelCalculation") }
            if let error = model.error {
                Label(error, systemImage: "exclamationmark.circle").font(.callout).foregroundStyle(.red)
                    .accessibilityIdentifier("calculationError").frame(maxWidth: .infinity, alignment: .leading)
            } else if let warning = model.result?.warnings.first {
                Button { notesPresented = true } label: {
                    Label(warning, systemImage: "info.circle").font(.caption).lineLimit(2)
                }.buttonStyle(.plain).foregroundStyle(.secondary).accessibilityIdentifier("calculationNotes")
            }
        }
    }
    private var expressionInput: some View {
            HStack(alignment: .center, spacing: 8) {
                ExpressionEditor(text: $model.expression, selection: $model.selection, keyboardVisible: $keyboardVisible, calculate: model.calculate)
                    .frame(height: keyboardVisible ? 90 : 64)
                if !keyboardVisible {
                    Button { keyboardVisible = true } label: {
                        Image(systemName: "keyboard")
                    }.accessibilityLabel("Show keyboard")
                }
                if keyboardVisible {
                    Button { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } label: { Image(systemName: "keyboard.chevron.compact.down").font(.title2) }.accessibilityLabel("Hide keyboard")
                }
            }.padding(.horizontal, 4)
    }
    private func keypad(keyHeight: CGFloat) -> some View {
        Group {
            if !keyboardVisible {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                    ForEach(keys, id: \.self) { key in
                        Button { press(key) } label: {
                            Text(key == "to" ? "Units" : key).font(.system(size: key.count > 2 || key == "to" ? 18 : 23, weight: key == "=" ? .bold : .medium, design: .rounded))
                                .frame(maxWidth: .infinity).frame(height: keyHeight)
                                .foregroundStyle(key == "=" ? Color.calculatorAccentText : (isOperator(key) ? Color.calculatorAccent : Color.primary))
                                .background(key == "=" ? Color.calculatorAccent : Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain).accessibilityLabel(accessibilityName(key)).accessibilityIdentifier("key_\(key)")
                            .disabled(key == "=" && model.busy)
                    }
                }
            } else {
                Button(action: model.calculate) { HStack { if model.busy { ProgressView() }; Text("Calculate").bold(); Image(systemName: "equal") }.frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).disabled(model.busy).accessibilityIdentifier("calculateButton")
            }        }
    }
    private func calculatorContent(size: CGSize) -> some View {
        let wide = size.width >= 620 && size.height >= 316 && !keyboardVisible
        let layout = wide ? AnyLayout(HStackLayout(alignment: .top, spacing: 20))
                          : AnyLayout(VStackLayout(spacing: 12))
        let keyHeight = wide ? min(72, max(44, (size.height - 52) / 6)) : 44
        return VStack(spacing: 12) {
            layout {
                VStack(spacing: 12) {
                    calculationSettings
                    GeometryReader { resultSpace in
                        ScrollView {
                            resultPanel.frame(minHeight: resultSpace.size.height)
                        }
                        .scrollBounceBehavior(.basedOnSize)
                        .accessibilityIdentifier("resultScroll")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                keypad(keyHeight: keyHeight)
                    .frame(width: wide ? min(420, (size.width - 52) * 0.49) : nil)
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 12)
        .frame(maxWidth: 1200)
        .frame(height: size.height)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .systemBackground))
    }
    private var calculator: some View {
        GeometryReader { geometry in
            if graphMode { GraphingView() }
            else if quickCalcMode { QuickCalcView() }
            else if programmerMode { ProgrammerView() }
            else if conversionMode { UnitConverterView() }
            else { calculatorContent(size: geometry.size) }
        }
        .background {
            if #available(iOS 27.1, *) { ToolbarEdgeReader() }
        }
        .onPreferenceChange(VerticalToolbarPreference.self) { verticalToolbar = $0 }
        .navigationTitle("Clockwork Calc").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if verticalToolbar {
                ToolbarItem(placement: .topBarLeading) { sideModeMenu }
                if #available(iOS 26.0, *) {
                    ToolbarSpacer(.fixed, placement: .topBarLeading)
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button { historyPresented = true } label: { Image(systemName: "clock.arrow.circlepath") }.accessibilityLabel("History")
            }
            ToolbarItem(placement: .topBarTrailing) {
                if !verticalToolbar { modePicker }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button("Fractions") { model.example("1/2 + 1/3", mode: .calculator) }
                    Section("Computer algebra") {
                        Button("Expand polynomial") { model.example("expand((x+1)^3)", mode: .cas) }
                        Button("Factor polynomial") { model.example("factor(x^2-1)", mode: .cas) }
                        Button("Symbolic integral") { model.example("integrate(x^2*sin(x),x)", mode: .cas) }
                        Button("Infinite interval") { model.example("integrate(exp(-x),x,0,Infinity)", mode: .cas) }
                        Button("Singular endpoint") { model.example("integrate(1/sqrt(x),x,0,1)", mode: .cas) }
                        Button("Definite integral") { model.example("integrate(x^2,x,0,1)", mode: .cas) }
                        Button("Numerical integral") { model.example("nint(exp(-x^2),x,0,1)", mode: .cas) }
                        Button("Matrix inverse") { model.example("invert(matrix([1,2],[3,4]))", mode: .cas) }
                        Button("Linear system") { model.example("linsolve([x+y=3,x-y=1],[x,y])", mode: .cas) }
                        Button("Insert a matrix…") { matrixPresented = true }
                    }
                    Button("Unit conversion") { model.example("5 ft + 3 in to cm", mode: .calculator) }
                    Button("Solve an equation") { model.example("solve(x^2 = 9, x)", mode: .cas) }
                    Button("Differentiate") { model.example("diff(x^3, x)", mode: .cas) }
                    Button("Complex numbers") { model.example("sqrt(-1)") }
                } label: { Image(systemName: "sparkles") }.accessibilityLabel("Examples")
                Button { aboutPresented = true } label: { Image(systemName: "info.circle") }.accessibilityLabel("About")
            }
        }
    }
    private var sideModeMenu: some View {
        Menu {
            Button("Calculator") { selectMode("calculator") }
            Button("CAS") { selectMode("cas") }
            Button("Unit converter") { selectMode("conversion") }
            Button("Programmer") { selectMode("programmer") }
            Button("Quick Calc") { selectMode("quick") }
            Button("Graphing") { selectMode("graph") }
        } label: { Image(systemName: "square.grid.2x2") }
            .accessibilityLabel("Calculation mode")
            .accessibilityIdentifier("calculationMode")
            .disabled(model.busy)
    }
    private func selectMode(_ value: String) {
        graphMode = value == "graph"
        quickCalcMode = value == "quick"
        programmerMode = value == "programmer"
        conversionMode = value == "conversion"
        if let mode = CalculationMode(rawValue: value) { model.mode = mode }
    }
    private var modePicker: some View {
        Picker("Calculation mode", selection: Binding<String>(
            get: { graphMode ? "graph" : quickCalcMode ? "quick" : programmerMode ? "programmer" : conversionMode ? "conversion" : model.mode.rawValue },
            set: selectMode)) {
                Text("Calculator").tag("calculator")
                Text("CAS").tag("cas")
                Text("Unit converter").tag("conversion")
                Text("Programmer").tag("programmer")
                Text("Quick Calc").tag("quick")
                Text("Graphing").tag("graph")
            }.pickerStyle(.menu).disabled(model.busy).accessibilityIdentifier("calculationMode")
    }
    private func isOperator(_ key: String) -> Bool { ["÷", "×", "−", "+", "^", "√", "to", "AC", "⌫", "EE"].contains(key) }
    private func accessibilityName(_ key: String) -> String {
        ["to":"Convert units", "EE":"Enter exponent, times ten to the power", "÷":"Divide", "×":"Multiply", "−":"Subtract", "+":"Add", "=":"Equals", "⌫":"Backspace", "AC":"Clear expression", "√":"Square root", "^":"Power", "Ans":"Last answer"][key] ?? key
    }
    private func press(_ key: String) {
        CalculatorHaptics.keyPress()
        switch key {
        case "=": model.calculate()
        case "AC": model.clear()
        case "EE": model.insertExponent()
        case "⌫": model.backspace()
        case "Ans": model.insertLastAnswer()
        case "√": model.insert("sqrt(")
        case "sin", "cos", "tan", "ln": model.insert(key + "(")
        case "÷": model.insertOperator("/")
        case "×": model.insertOperator("*")
        case "−": model.insertOperator("-")
        case "+", "^": model.insertOperator(key)
        case "to": model.insert(" to ")
        default: model.insert(key)
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject private var model: CalculatorModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List {
            if model.history.isEmpty { ContentUnavailableView("No calculations yet", systemImage: "clock", description: Text("Your last 100 calculations stay on this device.")) }
            ForEach(model.history) { item in
                Button {
                    model.recall(item); dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.expression).font(.system(.subheadline, design: .monospaced)).foregroundStyle(.primary).lineLimit(2)
                        Text(item.presentedText).font(.headline).foregroundStyle(Color.calculatorAccent).lineLimit(2)
                        Text(item.date, style: .time).font(.caption2).foregroundStyle(.secondary)
                    }.padding(.vertical, 5)
                }.contextMenu {
                    Button("Copy expression") { UIPasteboard.general.string = item.expression }
                    Button("Copy result") { UIPasteboard.general.string = item.text }
                }
            }.onDelete(perform: model.deleteHistory)
        }.listStyle(.insetGrouped)
    }
}

struct AboutView: View {
    private var licenseNotices: String {
        ["App-MIT", "KaTeX-MIT", "Nerdamer-Apache-2.0", "Decimal-MIT"].compactMap { name in
            Bundle.main.url(forResource: name, withExtension: "txt", subdirectory: "Licenses")
                .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
        }.joined(separator: "\n\n")
    }
    @AppStorage("appearance") private var appearance = "dark"
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Clockwork Calc for iPhone & iPad") {
                    Text("Calculator mode uses our Swift engine; CAS mode uses offline Nerdamer 2.0. All calculations run on your device.")
                    Text("All calculations run offline. History stays on your device. Choose dark, light, or system appearance below.")
                }
                Section("Appearance") {
                    Picker("Theme", selection: $appearance) { Text("Dark").tag("dark"); Text("Light").tag("light"); Text("System").tag("system") }
                }
                Section("Writing expressions") {
                    Text("Use / for fractions, ^ for powers, and parentheses for grouping. The EE key beside 9 enters a numeric exponent: 4.7 EE 3 means 4.7 × 10³. The upper-right keypad key deletes the character before the cursor. Results and interpreted expressions use textbook notation.")
                    Text("Try: 5 ft + 3 in to cm\nsolve(x^2 = 9, x)\ndiff(x^3, x)").font(.system(.callout, design: .monospaced))
                    Text("Result format and RAD/DEG apply to your next calculation. Engineering uses powers of ten in multiples of three (4.7 × 10³). Engineering (SI symbols) uses scale symbols (4.7 k), from q (10⁻³⁰) to Q (10³⁰), with powers of ten outside that range. These modes use decimal evaluation and format numeric coefficients, including matrix entries. SI symbols are display scale factors, not CAS variables. Copy, Ans, and Use result keep the unambiguous numeric value. Calculator expressions are bounded to 256 tokens. CAS uses radians, treats names as symbols rather than units, and has a five-second deadline.")
                }
                Section("Supported syntax") {
                    Text("sin, cos, tan, asin, acos, atan, sqrt, ln, log (base 10), exp, abs, floor, ceil; constants pi, e, i. Complex arguments are supported for arithmetic, powers, sqrt, and abs. Unit names are case-sensitive. See the README for the complete unit list.")
                }
                Section("Current scope") {
                    Text("Exact 64-bit fractions; scientific real functions; complex arithmetic and square roots; common units; elementary derivatives; linear and quadratic equations. Approximate results use about 15 significant digits. CAS adds symbolic algebra, arbitrary-size rational integers within resource limits, matrices, integration, limits, and broader equation solving. Currency rates and graphing are not supported.")
                }
                Section("CAS syntax") {
                    Text("expand((x+1)^3)\nfactor(x^2-1)\nsimplify((x^2-1)/(x-1))\nintegrate(x^2,x)\nintegrate(x^2,x,0,1)\nnint(exp(-x^2),x,0,1)\ninvert(matrix([1,2],[3,4]))\nlinsolve([x+y=3,x-y=1],[x,y])").font(.system(.callout, design: .monospaced))
                    Text("CAS log is natural log; use log10 for base ten. Integrals without bounds return one antiderivative: add C. Improper integrals use verified antiderivatives and separate one-sided limits for supported elementary expressions. Use Infinity or ∞ for an infinite bound. Each side of an interior singularity must converge independently. Divergent and unresolved cases are reported separately; unresolved does not mean divergent. Finite continuous integrals can use numerical quadrature. Unevaluated integrals and partial solver results are reported explicitly.")
                    Text("Matrices support arithmetic, powers, determinant, invert, transpose, rref, and rank. Use the Examples menu to insert a matrix of up to 8 × 8. Symbolic operations can require nonzero denominators; original domain restrictions still apply.")
                }
                Section("Support") {
                    Link("Email support", destination: URL(string: "mailto:Boonmamccain@gmail.com")!)
                    Text("Include your app version, device, and a short example. Avoid sending sensitive calculation history.")
                }
                Section("Privacy") {
                    Text("Calculations run on your device. Clockwork Calc has no accounts, advertising, tracking, or analytics and does not send your expressions or history to us. History and settings are stored locally and may be included in backups managed by your device. Copy writes a result to the system clipboard only when you tap Copy. Swipe to delete individual history entries.")
                }
                Section("Open source") {
                    Text("Original app and engine: MIT\nKaTeX renderer and fonts: MIT\nNerdamer 2.0: Apache-2.0\ndecimal.js 10.6: MIT")
                    Text("License notices are included below and in the source repository.")
                    NavigationLink("License notices") { ScrollView { Text(licenseNotices).font(.footnote).padding() }.navigationTitle("Licenses") }
                }
            }.navigationTitle("About").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

private struct VerticalToolbarPreference: PreferenceKey {
    static var defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}

@available(iOS 27.1, *)
private struct ToolbarEdgeReader: View {
    @Environment(\.toolbarVerticalEdge) private var edge
    var body: some View { Color.clear.preference(key: VerticalToolbarPreference.self, value: edge != nil) }
}
