import XCTest
@testable import ClockworkCalc

@MainActor final class ModelTests: XCTestCase {
    func testEditingAtSelection() {
        let model = CalculatorModel(historyURL: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString))
        model.expression = "12+34"; model.selection = NSRange(location: 3, length: 2)
        model.insert("5/6")
        XCTAssertEqual(model.expression, "12+5/6")
        XCTAssertEqual(model.selection.location, 6)
        model.backspace(); XCTAssertEqual(model.expression, "12+5/")
    }
    func testExponentEntryAtCursor() async throws {
        let model = CalculatorModel(historyURL: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString))
        model.insertExponent(); XCTAssertEqual(model.expression, "10^")
        model.expression = "4.7"; model.selection = NSRange(location: 3, length: 0)
        model.insertExponent(); XCTAssertEqual(model.expression, "4.7e")
        model.expression = "1/2"; model.selection = NSRange(location: 3, length: 0)
        model.insertExponent(); XCTAssertEqual(model.expression, "1/2e")
        model.expression = "2+"; model.selection = NSRange(location: 2, length: 0)
        model.insertExponent(); XCTAssertEqual(model.expression, "2+10^")
        model.expression = "2+3"; model.selection = NSRange(location: 2, length: 1)
        model.insertExponent(); XCTAssertEqual(model.expression, "2+10^")
        let quotient = try await CalculatorEngine().evaluate("1/2e3", exact: true, degrees: false)
        XCTAssertEqual(quotient.text, "1/2000")
    }
    func testUnicodeBackspace() {
        let model = CalculatorModel(historyURL: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString))
        model.expression = "1+π"; model.selection = NSRange(location: 3, length: 0)
        model.backspace(); XCTAssertEqual(model.expression, "1+")
    }
    func testHistoryRoundTrip() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let model = CalculatorModel(historyURL: url)
        model.expression = "2+2"; model.calculate()
        while model.busy { try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertEqual(model.result?.text, "4")
        let restored = CalculatorModel(historyURL: url)
        XCTAssertEqual(restored.history.count, 1)
        XCTAssertEqual(restored.history.first?.expression, "2+2")
    }
}

extension ModelTests {
    func testAnswerChainingAndHistoryAns() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let model = CalculatorModel(historyURL: url)
        model.expression = "2+3"; model.calculate()
        while model.busy { try await Task.sleep(for: .milliseconds(20)) }
        model.insertOperator("*"); model.insert("4"); model.calculate()
        while model.busy { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(model.result?.text, "20")
        model.clear(); model.insertLastAnswer()
        XCTAssertEqual(model.expression, "(20)")
        let restored = CalculatorModel(historyURL: url)
        restored.insertLastAnswer(); XCTAssertEqual(restored.expression, "(20)")
        restored.clear(); restored.insert("7+"); restored.insertOperator("-")
        XCTAssertEqual(restored.expression, "7+-")
    }
}
