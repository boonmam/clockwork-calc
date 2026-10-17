import SwiftUI

struct CalculatorView: View {
    @EnvironmentObject private var model: CalculatorModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var historyPresented = false
    @State private var aboutPresented = false
    @State private var keyboardVisible = false
    private let keys = ["sin", "cos", "tan", "√", "^", "(", ")", "π", "ln", "⌫", "7", "8", "9", "÷", "AC", "4", "5", "6", "×", "to", "1", "2", "3", "−", "Ans", "0", ".", ",", "+", "="]

    var body: some View {
        Group {
            if sizeClass == .regular {
                NavigationSplitView {
                    HistoryView().navigationTitle("History")
                } detail: { NavigationStack { calculator } }
            } else { NavigationStack { calculator } }
        }
        .sheet(isPresented: $historyPresented) { NavigationStack { HistoryView().navigationTitle("History").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { historyPresented = false } } } } }
        .sheet(isPresented: $aboutPresented) { AboutView() }
    }
    private var calculatorContent: some View {
        VStack(spacing: 12) {
            HStack {
                Picker("Result format", selection: $model.exact) {
                    Text("Exact").tag(true); Text("Decimal").tag(false)
                }.pickerStyle(.segmented).frame(maxWidth: 220)
                Spacer(minLength: 12)
                Picker("Angle unit", selection: $model.degrees) {
                    Text("RAD").tag(false); Text("DEG").tag(true)
                }.pickerStyle(.segmented).frame(width: 125)
            }
            VStack(alignment: .leading, spacing: 0) {
                if let result = model.result {
                    MathView(calculation: result).frame(minHeight: 120)
                    HStack {
                        if model.busy { ProgressView().controlSize(.small) }
                        Spacer()
                        Button { model.insert("(" + result.text + ")") } label: { Label("Use result", systemImage: "arrow.down.left") }
                        Button { UIPasteboard.general.string = result.text } label: { Label("Copy", systemImage: "doc.on.doc") }
                            .accessibilityIdentifier("copyResult").accessibilityValue(result.text)
                    }.font(.caption).buttonStyle(.borderless).padding(12)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        Image(systemName: "function").font(.system(size: 36)).foregroundStyle(Color.calculatorAccent)
                        Text("More than numbers.").font(.title2.bold())
                        Text("Fractions, algebra, units, and calculus.\nCalculated on your device.").foregroundStyle(.secondary)
                        Button("Try ½ + ⅓") { model.example("1/2 + 1/3") }.buttonStyle(.bordered)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading).padding(24)
                }
            }
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
            .layoutPriority(1)
            if let error = model.error {
                Label(error, systemImage: "exclamationmark.circle").font(.callout).foregroundStyle(.red)
                    .accessibilityIdentifier("calculationError").frame(maxWidth: .infinity, alignment: .leading)
            } else if let warning = model.result?.warnings.first {
                Text(warning).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            HStack(alignment: .center, spacing: 8) {
                ExpressionEditor(text: $model.expression, selection: $model.selection, keyboardVisible: $keyboardVisible, calculate: model.calculate)
                    .frame(height: keyboardVisible ? 90 : 64)
                    .overlay(alignment: .leading) {
                        if model.expression.isEmpty { Text("Enter an expression…").foregroundStyle(.tertiary).padding(.leading, 13).allowsHitTesting(false) }
                    }
                if keyboardVisible {
                    Button { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } label: { Image(systemName: "keyboard.chevron.compact.down").font(.title2) }.accessibilityLabel("Hide keyboard")
                }
            }.padding(.horizontal, 4).background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
            if !keyboardVisible {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                    ForEach(keys, id: \.self) { key in
                        Button { press(key) } label: {
                            Text(key).font(.system(size: key.count > 2 ? 18 : 23, weight: key == "=" ? .bold : .medium, design: .rounded))
                                .frame(maxWidth: .infinity).frame(height: 43)
                                .foregroundStyle(key == "=" ? Color.calculatorAccentText : (isOperator(key) ? Color.calculatorAccent : Color.primary))
                                .background(key == "=" ? Color.calculatorAccent : Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain).accessibilityLabel(accessibilityName(key)).accessibilityIdentifier("key_\(key)")
                            .disabled(key == "=" && model.busy)
                    }
                }
            } else {
                Button(action: model.calculate) { HStack { if model.busy { ProgressView() }; Text("Calculate").bold(); Image(systemName: "equal") }.frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).disabled(model.busy).accessibilityIdentifier("calculateButton")
            }
        }
        .padding(.horizontal, sizeClass == .regular ? 28 : 16).padding(.bottom, 12)
        .frame(maxWidth: 850)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }
    private var calculator: some View {
        Group {
            if verticalSizeClass == .compact {
                ScrollView { calculatorContent.frame(minHeight: 600) }.accessibilityIdentifier("landscapeCalculator")
            } else { calculatorContent }
        }
        .navigationTitle("Fraction Lab").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) {
                if sizeClass != .regular { Button { historyPresented = true } label: { Image(systemName: "clock.arrow.circlepath") }.accessibilityLabel("History") }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button("Fractions") { model.example("1/2 + 1/3") }
                    Button("Unit conversion") { model.example("5 ft + 3 in to cm") }
                    Button("Solve an equation") { model.example("solve(x^2 = 9, x)") }
                    Button("Differentiate") { model.example("diff(x^3, x)") }
                    Button("Complex numbers") { model.example("sqrt(-1)") }
                } label: { Image(systemName: "sparkles") }.accessibilityLabel("Examples")
                Button { aboutPresented = true } label: { Image(systemName: "info.circle") }.accessibilityLabel("About")
            }
        }
    }
    private func isOperator(_ key: String) -> Bool { ["÷", "×", "−", "+", "^", "√", "to", "AC", "⌫"].contains(key) }
    private func accessibilityName(_ key: String) -> String {
        ["÷":"Divide", "×":"Multiply", "−":"Subtract", "+":"Add", "=":"Equals", "⌫":"Backspace", "AC":"Clear expression", "√":"Square root", "^":"Power", "Ans":"Last answer"][key] ?? key
    }
    private func press(_ key: String) {
        switch key {
        case "=": model.calculate()
        case "AC": model.clear()
        case "⌫": model.backspace()
        case "Ans": if let result = model.result { model.insert("(" + result.text + ")") }
        case "√": model.insert("sqrt(")
        case "sin", "cos", "tan", "ln": model.insert(key + "(")
        case "÷": model.insert("/")
        case "×": model.insert("*")
        case "−": model.insert("-")
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
                        Text(item.text).font(.headline).foregroundStyle(Color.calculatorAccent).lineLimit(2)
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
        ["App-MIT", "KaTeX-MIT"].compactMap { name in
            Bundle.main.url(forResource: name, withExtension: "txt", subdirectory: "Licenses")
                .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
        }.joined(separator: "\n\n")
    }
    @AppStorage("appearance") private var appearance = "dark"
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Fraction Lab for iPhone & iPad") {
                    Text("An independent calculator with an original Swift engine. No Qalculate code or datasets are included.")
                    Text("All calculations run offline. History stays on your device. Choose dark, light, or system appearance below.")
                }
                Section("Appearance") {
                    Picker("Theme", selection: $appearance) { Text("Dark").tag("dark"); Text("Light").tag("light"); Text("System").tag("system") }
                }
                Section("Writing expressions") {
                    Text("Use / for fractions, ^ for powers, and parentheses for grouping. Results and interpreted expressions use textbook notation.")
                    Text("Try: 5 ft + 3 in to cm\nsolve(x^2 = 9, x)\ndiff(x^3, x)").font(.system(.callout, design: .monospaced))
                    Text("Exact/Decimal and RAD/DEG apply to your next calculation. Expressions are bounded to 256 tokens and 48 nesting levels.")
                }
                Section("Supported syntax") {
                    Text("sin, cos, tan, asin, acos, atan, sqrt, ln, log (base 10), exp, abs, floor, ceil; constants pi, e, i. Complex arguments are supported for arithmetic, powers, sqrt, and abs. Unit names are case-sensitive. See the README for the complete unit list.")
                }
                Section("Current scope") {
                    Text("Exact 64-bit fractions; scientific real functions; complex arithmetic and square roots; common units; elementary derivatives; linear and quadratic equations. Approximate results use about 15 significant digits. Matrices, integration, arbitrary precision, currency rates, and graphing are not supported.")
                }
                Section("Open source") {
                    Link("Source repository", destination: URL(string: "https://github.com/boonmam/qalculate-ios")!)
                    Text("Original app and engine: MIT\nKaTeX renderer and fonts: MIT")
                    Text("License notices are included below and in the source repository.")
                    NavigationLink("License notices") { ScrollView { Text(licenseNotices).font(.footnote).padding() }.navigationTitle("Licenses") }
                }
            }.navigationTitle("About").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
