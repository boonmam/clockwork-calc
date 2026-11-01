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

extension GraphTests {
    func testAxisBoundsAndPersistence() throws {
        let window = try GraphWindow.bounds(xMin: -5, xMax: 15, yMin: -2, yMax: 8)
        XCTAssertEqual(window.centerX, 5); XCTAssertEqual(window.centerY, 3)
        XCTAssertEqual(window.xMin, -5); XCTAssertEqual(window.xMax, 15)
        XCTAssertEqual(window.yMin, -2); XCTAssertEqual(window.yMax, 8)
        XCTAssertEqual(try JSONDecoder().decode(GraphWindow.self, from: JSONEncoder().encode(window)), window)
        XCTAssertThrowsError(try GraphWindow.bounds(xMin: 2, xMax: 2, yMin: -1, yMax: 1))
        XCTAssertThrowsError(try GraphWindow.bounds(xMin: 2, xMax: -2, yMin: -1, yMax: 1))
        XCTAssertThrowsError(try GraphWindow.bounds(xMin: -.infinity, xMax: 1, yMin: -1, yMax: 1))
    }
    func testSliderConstantsEvaluateAndPersist() throws {
        var a = GraphConstant(name: "a", value: 2, minimum: -5, maximum: 5, step: 0.25)
        try a.validate()
        XCTAssertEqual(try JSONDecoder().decode(GraphConstant.self, from: JSONEncoder().encode(a)), a)
        let function = try NativeMath().graphFunction("a*sin(b*x)", constants: ["a": 2, "b": 3])
        XCTAssertEqual(try XCTUnwrap(function(.pi/6)), 2, accuracy: 1e-12)
        let changed = try NativeMath().graphFunction("a*sin(b*x)", constants: ["a": 4, "b": 3])
        XCTAssertEqual(try XCTUnwrap(changed(.pi/6)), 4, accuracy: 1e-12)
        XCTAssertNil(GraphSampler.sample(GraphEquation(expression: "a*x"), window: GraphWindow(), constants: ["a": 0.5]).error)
        XCTAssertThrowsError(try NativeMath().graphFunction("a*x"))
        XCTAssertThrowsError(try NativeMath().graphFunction("x", constants: ["x": 4]))
        a.name = "pi"; XCTAssertThrowsError(try a.validate())
        a.name = "a"; a.step = 0; XCTAssertThrowsError(try a.validate())
        a.step = 0.1; a.value = 6; XCTAssertThrowsError(try a.validate())
    }
}

extension GraphTests {
    func testConstantsAutomaticallyCreateSliders() throws {
        let a = GraphConstant(name: "a", value: 3)
        let equations = [GraphEquation(expression: "a*sin(b*x)+offset+pi+2e-3")]
        let merged = GraphConstant.addingMissing(for: equations, to: [a])
        XCTAssertEqual(merged.map(\.name), ["a", "b", "offset"])
        XCTAssertEqual(merged[0].value, 3)
        XCTAssertEqual(GraphConstant.addingMissing(for: equations, to: merged), merged)
        XCTAssertEqual(try NativeMath().graphConstantNames("y = gain*x+pi+exp(x)"), ["gain"])
        XCTAssertTrue(GraphConstant.addingMissing(for: [GraphEquation(expression: "sin(")], to: []).isEmpty)
        let many = GraphEquation(expression: ["a", "b", "c", "d", "f", "g", "h", "j", "k", "m", "n", "p"].joined(separator: "+"))
        XCTAssertEqual(GraphConstant.addingMissing(for: [many], to: []).count, 8)
    }
}
