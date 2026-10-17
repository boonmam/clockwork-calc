import XCTest
@testable import Qalculate

@MainActor final class ModelTests: XCTestCase {
    func testEditingAtSelection() {
        let model = CalculatorModel(historyURL: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString))
        model.expression = "12+34"; model.selection = NSRange(location: 3, length: 2)
        model.insert("5/6")
        XCTAssertEqual(model.expression, "12+5/6")
        XCTAssertEqual(model.selection.location, 6)
        model.backspace(); XCTAssertEqual(model.expression, "12+5/")
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
