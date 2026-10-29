import SwiftUI

struct ProgrammerView: View {
    @StateObject private var model = ProgrammerModel()
    private let keys = ["A", "B", "C", "D", "E", "F",
                        "AND", "OR", "XOR", "NOT", "AC", "⌫",
                        "7", "8", "9", "÷", "<<", ">>",
                        "4", "5", "6", "×", "MOD", "ASR",
                        "1", "2", "3", "−", "±", "=",
                        "0", "+"]
    var body: some View {
        GeometryReader { space in
            let wide = space.size.width >= 620 || (space.size.width >= 500 && space.size.height < 500)
            let layout = wide ? AnyLayout(HStackLayout(alignment: .top, spacing: 12)) : AnyLayout(VStackLayout(spacing: 8))
            layout {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Picker("Word size", selection: Binding(get: { model.width }, set: model.setWidth)) {
                            ForEach([8,16,32,64], id: \.self) { Text("\($0)-bit").tag($0) }
                        }.accessibilityIdentifier("wordSize")
                        Spacer(minLength: 0)
                        Toggle("Signed", isOn: $model.signed).fixedSize().accessibilityIdentifier("signedInteger")
                    }.font(.caption).frame(minHeight: 44)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                    ForEach([16,10,8,2], id: \.self) { base in
                        Button { model.setRadix(base) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text([16:"HEX",10:"DEC",8:"OCT",2:"BIN"][base]!).font(.caption.bold()).frame(width: 36, alignment: .leading)
                                Text(model.formatted(base: base)).font(.system(.body, design: .monospaced))
                                    .lineLimit(base == 2 ? 2 : 1).minimumScaleFactor(0.45)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }.padding(.horizontal, 8).frame(height: 58)
                                .contentShape(Rectangle())
                                .background(model.radix == base ? Color.calculatorAccent.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain).contentShape(Rectangle()).accessibilityIdentifier("base_\(base)")
                            .accessibilityValue(model.formatted(base: base))
                    }
                    }
                    HStack {
                        Text(model.error ?? model.operation.map { "\($0) · enter next integer" } ?? "Wraps at \(model.width) bits · shifts by 1")
                            .font(.caption2).foregroundStyle(model.error == nil ? Color.secondary : .red)
                            .lineLimit(2).accessibilityIdentifier("programmerStatus")
                        Spacer(minLength: 0)
                        Button { UIPasteboard.general.string = model.formatted(base: model.radix) } label: {
                            Image(systemName: "doc.on.doc").frame(width: 44, height: 44)
                        }.accessibilityLabel("Copy integer")
                    }
                }.padding(8).background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                    ForEach(keys, id: \.self) { key in
                        Button { press(key) } label: {
                            Text(key).font(.system(size: key.count > 2 ? 13 : 20, weight: .medium, design: .rounded))
                                .frame(maxWidth: .infinity).frame(height: 44)
                                .foregroundStyle(key == "=" ? Color.calculatorAccentText : Color.primary)
                                .background(key == "=" ? Color.calculatorAccent : Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                        }.buttonStyle(.plain).disabled(disabled(key)).opacity(disabled(key) ? 0.3 : 1)
                            .accessibilityIdentifier("programKey_\(key)")
                            .accessibilityLabel(key == "ASR" ? "Arithmetic right shift" : key == ">>" ? "Logical right shift" : key == "<<" ? "Left shift" : key)
                    }
                }.frame(width: wide ? space.size.width * 0.5 : nil)
            }.padding(12).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
    private func disabled(_ key: String) -> Bool {
        guard key.count == 1, let number = UInt64(key, radix: 16) else { return false }
        return number >= model.radix
    }
    private func press(_ key: String) {
        CalculatorHaptics.keyPress()
        if key.count == 1, UInt64(key, radix: 16) != nil { model.digit(key); return }
        switch key {
        case "AC": model.clear()
        case "⌫": model.backspace()
        case "=": model.evaluate()
        case "NOT", "±", "<<", ">>", "ASR": model.unary(key)
        default: model.choose(key)
        }
    }
}
