import SwiftUI
import UIKit

struct ExpressionEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange
    @Binding var keyboardVisible: Bool
    var calculate: () -> Void
    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.inputView = context.coordinator.keypadInputView
        view.font = .monospacedSystemFont(ofSize: 21, weight: .regular)
        view.backgroundColor = .clear; view.textColor = .label
        view.autocorrectionType = .no; view.autocapitalizationType = .none
        view.smartQuotesType = .no; view.smartDashesType = .no
        view.keyboardType = .asciiCapable; view.returnKeyType = .go
        view.accessibilityIdentifier = "expressionEditor"
        view.accessibilityLabel = "Expression"
        view.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        return view
    }
    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.synchronize(view, text: text, selection: selection, keyboardVisible: keyboardVisible)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: ExpressionEditor
        let keypadInputView = UIView(frame: .zero)
        var systemKeyboard = false
        private var synchronizing = false
        init(_ parent: ExpressionEditor) { self.parent = parent }
        func synchronize(_ view: UITextView, text: String, selection: NSRange, keyboardVisible: Bool) {
            // Setting UITextView.text can move its selection and synchronously notify
            // the delegate. Keep that transient cursor out of the SwiftUI binding.
            synchronizing = true
            defer { synchronizing = false }
            if keyboardVisible != systemKeyboard {
                systemKeyboard = keyboardVisible
                view.inputView = keyboardVisible ? nil : keypadInputView
                if keyboardVisible { view.becomeFirstResponder() }
                view.reloadInputViews()
            }
            if view.text != text { view.text = text }
            let length = (text as NSString).length
            let start = min(selection.location, length)
            let safe = NSRange(location: start, length: min(selection.length, length - start))
            if view.selectedRange != safe { view.selectedRange = safe }
        }
        func textViewDidBeginEditing(_ view: UITextView) { if !synchronizing { parent.keyboardVisible = systemKeyboard } }
        func textViewDidEndEditing(_ view: UITextView) { if !synchronizing { parent.keyboardVisible = false } }
        func textViewDidChange(_ view: UITextView) {
            guard !synchronizing else { return }
            let text = view.text ?? "", selection = view.selectedRange
            parent.text = text; parent.selection = selection
        }
        func textViewDidChangeSelection(_ view: UITextView) {
            guard !synchronizing else { return }
            if parent.selection != view.selectedRange { parent.selection = view.selectedRange }
        }
        func textView(_ view: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if text == "\n" { parent.calculate(); view.resignFirstResponder(); return false }
            return true
        }
    }
}
