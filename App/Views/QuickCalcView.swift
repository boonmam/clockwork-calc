import SwiftUI

struct QuickCalcView: View {
    @State private var formula: QuickFormula = .power
    @State private var values = ["", "", ""]
    @FocusState private var focused: Int?
    private var answer: String? {
        guard let result = try? formula.evaluate(Array(values.prefix(formula.fields.count))) else { return nil }
        return String(format: "%.9g", locale: Locale(identifier: "en_US_POSIX"), result) + " " + formula.units
    }
    private var error: String? {
        guard values.prefix(formula.fields.count).allSatisfy({ !$0.isEmpty }) else { return nil }
        do { _ = try formula.evaluate(Array(values.prefix(formula.fields.count))); return nil }
        catch { return error.localizedDescription }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Quick calculation", selection: $formula) {
                ForEach(QuickFormula.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.menu).accessibilityIdentifier("quickFormula")
            Text(formula.formula).font(.title2.monospaced()).minimumScaleFactor(0.6).lineLimit(1)
            ForEach(Array(formula.fields.enumerated()), id: \.offset) { index, name in
                HStack {
                    Text(name).font(.callout).frame(maxWidth: .infinity, alignment: .leading)
                    TextField("0", text: $values[index])
                        .keyboardType(.numbersAndPunctuation).textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing).focused($focused, equals: index)
                        .accessibilityLabel(name).accessibilityIdentifier("quickInput\(index)")
                }
            }
            Text(answer ?? "Enter values above").font(.title2.monospacedDigit())
                .lineLimit(1).minimumScaleFactor(0.5).accessibilityIdentifier("quickAnswer")
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            Text(formula.note).font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Example") { values = formula.example + Array(repeating: "", count: 3 - formula.fields.count); focused = nil }
                Button("Clear") { values = ["", "", ""] }
                Spacer()
                if focused != nil { Button("Done") { focused = nil } }
                if let answer { Button("Copy") { UIPasteboard.general.string = answer } }
            }.buttonStyle(.bordered)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.bottom, 12)
        .frame(maxWidth: 700).frame(maxWidth: .infinity)
        .onChange(of: formula) { _, _ in values = ["", "", ""]; focused = nil }
    }
}
