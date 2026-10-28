import SwiftUI

struct QuickCalcView: View {
    @StateObject private var store = QuickTabStore()
    @State private var selected: UUID?
    @State private var editing: QuickTab?
    @State private var deleteRequested = false
    private var tab: QuickTab { store.tabs.first(where: { $0.id == selected }) ?? store.tabs[0] }
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Picker("Quick Calc tabs", selection: Binding(get: { tab.id }, set: { selected = $0 })) {
                    ForEach(store.tabs) { Text($0.name).tag($0.id) }
                }.pickerStyle(.menu).accessibilityIdentifier("quickTabs")
                Spacer()
                Button { editing = QuickTab() } label: { Image(systemName: "plus") }.accessibilityLabel("New calculation tab")
                Menu {
                    Button("Edit tab") { editing = tab }
                    Button("Duplicate tab") { var copy = tab; copy.id = UUID(); copy.name += " copy"; editing = copy }
                    Button("Delete tab", role: .destructive) { deleteRequested = true }.disabled(store.tabs.count <= 1)
                } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel("Tab options")
            }
            Picker("Input method", selection: Binding(get: { tab.effectiveInputStyle }, set: { style in
                var updated = tab; updated.inputStyle = style
                do { try store.save(updated) } catch { store.error = error.localizedDescription }
            })) { ForEach(QuickInputStyle.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                .pickerStyle(.segmented).accessibilityIdentifier("quickInputMethod")
            if tab.isPower { PowerQuickView(style: tab.effectiveInputStyle).id(tab.id) }
            else { FormulaQuickView(tab: tab).id(tab.worksheetIdentity) }
            if let error = store.error { Text(error).font(.caption).foregroundStyle(.red) }
        }
        .padding(.horizontal, 16).padding(.bottom, 12)
        .frame(maxWidth: 800).frame(maxWidth: .infinity)
        .sheet(item: $editing) { draft in
            QuickTabEditor(tab: draft) { updated in
                try store.save(updated); selected = updated.id
            }
        }
        .confirmationDialog("Delete \(tab.name)?", isPresented: $deleteRequested, titleVisibility: .visible) {
            Button("Delete tab", role: .destructive) { store.remove(tab.id); selected = store.tabs.first?.id }
        }
    }
}

private struct FormulaQuickView: View {
    let tab: QuickTab
    @State private var values: [String]
    @State private var focused: Int?
    @State private var selection = NSRange(location: 0, length: 0)
    init(tab: QuickTab) { self.tab = tab; _values = State(initialValue: tab.inputs.map(\.defaultValue)) }
    private var result: Result<String, Error> { Result { try tab.evaluate(values) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tab.expression).font(.headline.monospaced()).lineLimit(2).minimumScaleFactor(0.6)
            ForEach(Array(tab.inputs.enumerated()), id: \.element.id) { index, field in
                HStack {
                    Text(field.label + (field.unit.isEmpty ? "" : " (\(field.unit))")).font(.callout).frame(maxWidth: .infinity, alignment: .leading)
                    QuickNumberEntry(text: $values[index], active: $focused, selection: $selection, index: index,
                                     style: tab.effectiveInputStyle, placeholder: field.symbol, label: field.label, identifier: "quickInput\(index)")
                        .frame(height: 34)

                }
            }
            switch result {
            case .success(let answer):
                Text(answer + " " + tab.resultUnit).font(.title2.monospacedDigit()).lineLimit(2).minimumScaleFactor(0.6).accessibilityIdentifier("quickAnswer")
            case .failure(let error): Text(error.localizedDescription).font(.caption).foregroundStyle(.red)
            }
            if !tab.note.isEmpty { Text(tab.note).font(.caption).foregroundStyle(.secondary) }
            HStack {
                Button("Defaults") { values = tab.inputs.map(\.defaultValue); focused = nil }
                Button("Clear") { values = tab.inputs.map { _ in "" } }
                Spacer()
                if focused != nil { Button("Done") { focused = nil } }
                if case .success(let answer) = result { Button("Copy") { UIPasteboard.general.string = answer + " " + tab.resultUnit } }
            }.buttonStyle(.bordered)
            if tab.effectiveInputStyle == .keypad {
                QuickNumberPad { key in
                    let index = focused ?? 0
                    if focused == nil { focused = index; selection = NSRange(location: values[index].utf16.count, length: 0) }
                    if key == "Next" { focused = (index + 1) % values.count; selection = NSRange(location: 0, length: values[focused!].utf16.count) }
                    else { NumberPadEditing.apply(key, text: &values[index], selection: &selection) }
                }
            }
            Spacer(minLength: 0)
        }
        .onChange(of: tab.effectiveInputStyle) { _, _ in focused = nil; UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
    }
}

private struct PowerQuickView: View {
    let style: QuickInputStyle
    @State private var values = ["", "", "", ""]
    @State private var scales = [1.0, 1.0, 1.0, 1.0]
    @State private var focused: Int?
    @State private var selection = NSRange(location: 0, length: 0)
    private let labels = ["Resistance", "Current", "Voltage", "Power"]
    private let units = ["Ω", "A", "V", "W"]
    private let prefixes: [(String, Double)] = [("µ", 1e-6), ("m", 1e-3), ("", 1), ("k", 1e3), ("M", 1e6)]
    private var solved: Result<[Double], Error> {
        Result {
            let inputs: [Double?] = try values.enumerated().map { index, text in
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nil }
                guard let number = Double(text), number.isFinite else { throw CalculationError(message: "Enter a valid number for \(labels[index]).") }
                return number * scales[index]
            }
            return try DCPower.solve(inputs)
        }
    }
    private func output(_ index: Int) -> String? {
        guard case .success(let result) = solved else { return nil }
        return String(format: "%.9g", locale: Locale(identifier: "en_US_POSIX"), result[index] / scales[index])
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DC power · resistive load").font(.headline)
            Text("Enter any two values. The blank fields are calculated automatically.").font(.caption).foregroundStyle(.secondary)
            ForEach(0..<4) { index in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(labels[index]).font(.callout)
                        Text(values[index].isEmpty && output(index) != nil ? "Calculated" : "Input").font(.caption2).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    QuickNumberEntry(text: $values[index], active: $focused, selection: $selection, index: index,
                                     style: style, placeholder: output(index) ?? "—", label: labels[index], identifier: "powerInput\(index)", calculated: values[index].isEmpty && output(index) != nil)
                        .frame(height: 32)
                    Picker("\(labels[index]) unit", selection: $scales[index]) {
                        ForEach(prefixes, id: \.1) { prefix in Text(prefix.0 + units[index]).tag(prefix.1) }
                    }.pickerStyle(.menu).frame(width: 74)
                }
            }
            if case .failure(let error) = solved { Text(error.localizedDescription).font(.caption).foregroundStyle(.secondary) }
            Text("V = IR    P = VI = I²R = V²/R").font(.caption.monospaced())
            HStack {
                Button("Example") { scales = [1,1,1,1]; values = ["", "0.5", "12", ""]; focused = nil }
                Button("Clear") { values = ["", "", "", ""] }
                Spacer()
                if focused != nil { Button("Done") { focused = nil } }
                if case .success = solved {
                    Button("Copy") {
                        UIPasteboard.general.string = (0..<4).map { index in "\(labels[index]): \(output(index) ?? "") \(prefixes.first { $0.1 == scales[index] }?.0 ?? "")\(units[index])" }.joined(separator: "\n")
                    }
                }
            }.buttonStyle(.bordered)
            if style == .keypad {
                QuickNumberPad { key in
                    let index = focused ?? 0
                    if focused == nil { focused = index; selection = NSRange(location: values[index].utf16.count, length: 0) }
                    if key == "Next" { focused = (index + 1) % 4; selection = NSRange(location: 0, length: values[focused!].utf16.count) }
                    else { NumberPadEditing.apply(key, text: &values[index], selection: &selection) }
                }
            }
            Spacer(minLength: 0)
        }
        .onChange(of: style) { _, _ in focused = nil; UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
    }
}

private struct QuickTabEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var tab: QuickTab
    let save: (QuickTab) throws -> Void
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Tab") {
                    TextField("Name", text: $tab.name).accessibilityIdentifier("tabName")
                    Picker("Input method", selection: Binding(get: { tab.effectiveInputStyle }, set: { tab.inputStyle = $0 })) {
                        ForEach(QuickInputStyle.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    if !tab.isPower {
                        TextField("Formula, e.g. V*I", text: $tab.expression).textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("tabFormula")
                        TextField("Result unit, e.g. W", text: $tab.resultUnit)
                        TextField("Notes (optional)", text: $tab.note)
                    }
                }
                if !tab.isPower {
                    Section {
                        Text("Use 1–4 variables with unique names. Formulas use radians and base-unit numbers; unit labels do not convert values. Set defaults that produce a valid result. Examples: V*I, 1/(2*pi*R*C), sqrt(x).")
                    }
                    ForEach($tab.inputs) { $field in
                        Section("Input field") {
                            TextField("Variable, e.g. R", text: $field.symbol).textInputAutocapitalization(.never).autocorrectionDisabled()
                            TextField("Label", text: $field.label)
                            TextField("Unit label", text: $field.unit)
                            TextField("Default value", text: $field.defaultValue).keyboardType(.numbersAndPunctuation)
                            Button("Remove field", role: .destructive) { tab.inputs.removeAll { $0.id == field.id } }.disabled(tab.inputs.count <= 1)
                        }
                    }
                    if tab.inputs.count < 4 { Button("Add field") { tab.inputs.append(QuickInput(symbol: "x\(tab.inputs.count+1)")) } }
                } else { Text("Power solves the four DC fields from any two known values. Duplicate a formula tab or create a new tab for a custom equation.") }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("Configure tab").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { do { try save(tab); dismiss() } catch { self.error = error.localizedDescription } }.accessibilityIdentifier("saveQuickTab")
                }
            }
        }
    }
}
