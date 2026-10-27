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
        let wantsKeyboard = keyboardVisible
        if wantsKeyboard != context.coordinator.systemKeyboard {
            context.coordinator.systemKeyboard = wantsKeyboard
            view.inputView = wantsKeyboard ? nil : context.coordinator.keypadInputView
            if wantsKeyboard { view.becomeFirstResponder() }
            view.reloadInputViews()
        }
        if view.text != text { view.text = text }
        let length = (text as NSString).length
        let safe = NSRange(location: min(selection.location, length), length: min(selection.length, max(0, length - selection.location)))
        if view.selectedRange != safe { view.selectedRange = safe }
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: ExpressionEditor
        let keypadInputView = UIView(frame: .zero)
        var systemKeyboard = false
        init(_ parent: ExpressionEditor) { self.parent = parent }
        func textViewDidBeginEditing(_ view: UITextView) { parent.keyboardVisible = systemKeyboard }
        func textViewDidEndEditing(_ view: UITextView) { parent.keyboardVisible = false }
        func textViewDidChange(_ view: UITextView) { parent.text = view.text; parent.selection = view.selectedRange }
        func textViewDidChangeSelection(_ view: UITextView) {
            if parent.selection != view.selectedRange { parent.selection = view.selectedRange }
        }
        func textView(_ view: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if text == "\n" { parent.calculate(); view.resignFirstResponder(); return false }
            return true
        }
    }
}
