import SwiftUI
import UIKit

struct QuickNumberEntry: UIViewRepresentable {
    @Binding var text: String
    @Binding var active: Int?
    @Binding var selection: NSRange
    let index: Int
    let style: QuickInputStyle
    let placeholder: String
    let label: String
    let identifier: String
    var calculated = false
    func makeUIView(context: Context) -> UITextField {
        let view = UITextField()
        view.borderStyle = .roundedRect
        view.keyboardType = .numbersAndPunctuation
        view.font = .monospacedDigitSystemFont(ofSize: 17, weight: .regular)
        view.textAlignment = .right
        view.delegate = context.coordinator
        view.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        view.accessibilityIdentifier = identifier
        view.accessibilityLabel = label
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }
    func updateUIView(_ view: UITextField, context: Context) {
        context.coordinator.parent = self
        let custom = style == .keypad
        if (view.inputView != nil) != custom {
            view.inputView = custom ? context.coordinator.empty : nil
            view.reloadInputViews()
        }
        if view.text != text { view.text = text }
        view.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [.foregroundColor: calculated ? UIColor(Color.calculatorAccent) : UIColor.placeholderText])
        if active == index {
            if view.isFirstResponder, let start = view.position(from: view.beginningOfDocument, offset: min(selection.location, text.utf16.count)),
               let end = view.position(from: start, offset: min(selection.length, text.utf16.count - min(selection.location, text.utf16.count))) {
                view.selectedTextRange = view.textRange(from: start, to: end)
            }
        } else if view.isFirstResponder { view.resignFirstResponder() }
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: QuickNumberEntry
        let empty = UIView(frame: .zero)
        init(_ parent: QuickNumberEntry) { self.parent = parent }
        func textFieldDidBeginEditing(_ view: UITextField) {
            parent.active = parent.index
            parent.selection = NSRange(location: 0, length: parent.text.utf16.count)
            view.selectAll(nil)
        }
        @objc func changed(_ view: UITextField) { parent.text = view.text ?? ""; readSelection(view) }
        func textFieldDidChangeSelection(_ view: UITextField) { if view.isFirstResponder { readSelection(view) } }
        private func readSelection(_ view: UITextField) {
            guard let range = view.selectedTextRange else { return }
            let value = NSRange(location: view.offset(from: view.beginningOfDocument, to: range.start), length: view.offset(from: range.start, to: range.end))
            if parent.selection != value { parent.selection = value }
        }
        func textFieldShouldReturn(_ view: UITextField) -> Bool { view.resignFirstResponder(); parent.active = nil; return false }
    }
}

struct QuickNumberPad: View {
    let press: (String) -> Void
    private let keys = ["7", "8", "9", "⌫", "4", "5", "6", "AC", "1", "2", "3", "±", "0", ".", "EE", "Next"]
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
            ForEach(keys, id: \.self) { key in
                Button { CalculatorHaptics.keyPress(); press(key) } label: {
                    Text(key).font(.system(size: 19, weight: .medium, design: .rounded))
                        .frame(maxWidth: .infinity).frame(height: 38)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                }.buttonStyle(.plain).accessibilityIdentifier("numberPad_\(key)")
            }
        }.accessibilityIdentifier("quickNumberPad")
    }
}

enum NumberPadEditing {
    static func apply(_ key: String, text: inout String, selection: inout NSRange) {
        let source = text as NSString
        let start = min(selection.location, source.length)
        let range = NSRange(location: start, length: min(selection.length, source.length - start))
        if key == "AC" { text = ""; selection = NSRange(location: 0, length: 0); return }
        if key == "±" {
            if let exponent = text.lastIndex(where: { $0 == "e" || $0 == "E" }), start >= text.distance(from: text.startIndex, to: exponent) + 1 {
                let sign = text.index(after: exponent)
                if sign < text.endIndex, text[sign] == "-" { text.remove(at: sign) }
                else if sign < text.endIndex, text[sign] == "+" { text.replaceSubrange(sign...sign, with: "-") }
                else { text.insert("-", at: sign) }
                selection = NSRange(location: text.utf16.count, length: 0); return
            }
            if text.hasPrefix("-") { text.removeFirst() } else if !text.isEmpty { text = "-" + text } else { text = "-" }
            selection = NSRange(location: text.utf16.count, length: 0); return
        }
        if key == "⌫" {
            guard range.length > 0 || start > 0 else { return }
            let deleting = range.length > 0 ? range : NSRange(location: start - 1, length: 1)
            text = source.replacingCharacters(in: deleting, with: "")
            selection = NSRange(location: deleting.location, length: 0); return
        }
        let insert = key == "EE" ? "e" : key
        guard text.utf16.count - range.length + insert.utf16.count <= 40 else { return }
        text = source.replacingCharacters(in: range, with: insert)
        selection = NSRange(location: start + insert.utf16.count, length: 0)
    }
}
