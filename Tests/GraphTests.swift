import XCTest
@testable import ClockworkCalc
final class GraphTests: XCTestCase {
    func testCompiledFunctionsAndDomains() throws {
        let sine = try NativeMath().graphFunction("y = sin(x)")
        XCTAssertEqual(sine(.pi/2)!, 1, accuracy: 1e-12)
        let polynomial = try NativeMath().graphFunction("x^2-2*x+1")
        XCTAssertEqual(polynomial(3), 4)
        let root = try NativeMath().graphFunction("sqrt(x)")
        XCTAssertNil(root(-1)); XCTAssertEqual(root(9), 3)
        XCTAssertThrowsError(try NativeMath().graphFunction("z+1"))
        XCTAssertThrowsError(try NativeMath().graphFunction("x=2"))
    }
    func testDiscontinuitiesDoNotConnectAcrossZero() {
        let curve = GraphSampler.sample(GraphEquation(expression: "1/x"), window: GraphWindow())
        XCTAssertNil(curve.error)
        XCTAssertGreaterThanOrEqual(curve.segments.count, 2)
        for segment in curve.segments {
            XCTAssertFalse(segment.contains { $0.x < 0 } && segment.contains { $0.x > 0 })
        }
        XCTAssertNotNil(GraphSampler.sample(GraphEquation(expression: "bogus(x)"), window: GraphWindow()).error)
        var window = GraphWindow(); window.zoom(0.5)
        XCTAssertEqual(window.spanX, 10)
        window.zoom(1e-100); XCTAssertEqual(window.spanX, 1e-6)
    }
    func testKeypadSelectionAndExponent() {
        var text = "1000", selection = NSRange(location: 0, length: 4)
        NumberPadEditing.apply("2", text: &text, selection: &selection)
        XCTAssertEqual(text, "2")
        NumberPadEditing.apply("EE", text: &text, selection: &selection)
        NumberPadEditing.apply("3", text: &text, selection: &selection)
        XCTAssertEqual(text, "2e3")
        NumberPadEditing.apply("±", text: &text, selection: &selection)
        XCTAssertEqual(text, "2e-3")
        NumberPadEditing.apply("±", text: &text, selection: &selection)
        NumberPadEditing.apply("⌫", text: &text, selection: &selection)
        XCTAssertEqual(text, "2e")
        NumberPadEditing.apply("AC", text: &text, selection: &selection)
        XCTAssertEqual(text, "")
    }
    @MainActor func testLegacyTabsRetainInputDefaultsAndSaveChoice() throws {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var tab = QuickTab.starters[0]
        XCTAssertEqual(tab.effectiveInputStyle, .keypad)
        XCTAssertEqual(QuickTab.starters[1].effectiveInputStyle, .keyboard)
        let store = QuickTabStore(defaults: defaults)
        tab.inputStyle = .keyboard; try store.save(tab)
        XCTAssertEqual(QuickTabStore(defaults: defaults).tabs.first { $0.id == tab.id }?.effectiveInputStyle, .keyboard)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(tab)) as! [String: Any]
        json.removeValue(forKey: "inputStyle")
        let legacy = try JSONDecoder().decode(QuickTab.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(legacy.effectiveInputStyle, .keypad)
    }
}
