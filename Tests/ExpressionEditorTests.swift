import XCTest
import SwiftUI
import UIKit
@testable import ClockworkCalc

@MainActor final class ExpressionEditorTests: XCTestCase {
    /// Reproduces UIKit's temporary end selection while text is being replaced.
    final class NotifyingTextView: UITextView {
        override var text: String! {
            didSet {
                selectedRange = NSRange(location: (text as NSString?)?.length ?? 0, length: 0)
                delegate?.textViewDidChangeSelection?(self)
            }
        }
    }
    func testKeypadEditsKeepCursorInMiddle() {
        let model = CalculatorModel(historyURL: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString))
        var keyboard = false
        let editor = ExpressionEditor(text: Binding(get: { model.expression }, set: { model.expression = $0 }),
                                      selection: Binding(get: { model.selection }, set: { model.selection = $0 }),
                                      keyboardVisible: Binding(get: { keyboard }, set: { keyboard = $0 }), calculate: {})
        let coordinator = editor.makeCoordinator()
        let view = NotifyingTextView()
        model.insert("12345")
        view.text = model.expression; view.delegate = coordinator
        view.selectedRange = NSRange(location: 2, length: 0)
        coordinator.textViewDidChangeSelection(view)
        model.backspace()
        coordinator.synchronize(view, text: model.expression, selection: model.selection, keyboardVisible: false)
        XCTAssertEqual(model.expression, "1345")
        XCTAssertEqual(model.selection, NSRange(location: 1, length: 0))
        XCTAssertEqual(view.selectedRange, model.selection)
        model.insert("7")
        coordinator.synchronize(view, text: model.expression, selection: model.selection, keyboardVisible: false)
        XCTAssertEqual(view.text, "17345")
        XCTAssertEqual(model.selection, NSRange(location: 2, length: 0))
        model.backspace()
        coordinator.synchronize(view, text: model.expression, selection: model.selection, keyboardVisible: false)
        XCTAssertEqual(view.text, "1345")
        XCTAssertEqual(view.selectedRange, NSRange(location: 1, length: 0))
    }
    func testSelectionReplacementAndNativeEditingStillUpdateBindings() {
        var text = "12+34", selection = NSRange(location: 3, length: 2), keyboard = false
        let editor = ExpressionEditor(text: Binding(get: { text }, set: { text = $0 }),
                                      selection: Binding(get: { selection }, set: { selection = $0 }),
                                      keyboardVisible: Binding(get: { keyboard }, set: { keyboard = $0 }), calculate: {})
        let coordinator = editor.makeCoordinator(), view = NotifyingTextView()
        view.delegate = coordinator
        coordinator.synchronize(view, text: text, selection: selection, keyboardVisible: false)
        XCTAssertEqual(selection, NSRange(location: 3, length: 2))
        XCTAssertEqual(view.selectedRange, selection)
        // Native typing/pasting must still publish the final text and caret.
        view.text = "12+5/6"; view.selectedRange = NSRange(location: 5, length: 0)
        coordinator.textViewDidChange(view)
        XCTAssertEqual(text, "12+5/6")
        XCTAssertEqual(selection, NSRange(location: 5, length: 0))
        view.selectedRange = NSRange(location: 0, length: 2)
        coordinator.textViewDidChangeSelection(view)
        XCTAssertEqual(selection, NSRange(location: 0, length: 2))
    }
}
