import XCTest
@testable import ClockworkCalc
final class QuickCalcTests: XCTestCase {
    func testElectricalExamples() throws {
        XCTAssertEqual(try QuickFormula.power.evaluate(["12", "0.5"]), 6)
        XCTAssertEqual(try QuickFormula.cutoff.evaluate(["1000", "100e-9"]), 1591.5494309, accuracy: 0.0001)
        XCTAssertEqual(try QuickFormula.capacitorAC.evaluate(["60", "10e-6", "120"]), 0.452389342, accuracy: 0.000001)
        XCTAssertEqual(try QuickFormula.capacitorRate.evaluate(["10e-6", "-1000"]), -0.01, accuracy: 0.000001)
    }
    func testInvalidInputs() {
        XCTAssertThrowsError(try QuickFormula.cutoff.evaluate(["0", "1"]))
        XCTAssertThrowsError(try QuickFormula.capacitorAC.evaluate(["60", "-1", "120"]))
        XCTAssertThrowsError(try QuickFormula.power.evaluate(["nan", "1"]))
        XCTAssertThrowsError(try QuickFormula.power.evaluate(["1e308", "1e308"]))
    }
}

extension QuickCalcTests {
    func testAllSixPowerPairs() throws {
        let expected = [24.0, 0.5, 12.0, 6.0]
        for a in 0..<4 {
            for b in (a+1)..<4 {
                var inputs = [Double?](repeating: nil, count: 4)
                inputs[a] = expected[a]; inputs[b] = expected[b]
                let answer = try DCPower.solve(inputs)
                for index in 0..<4 { XCTAssertEqual(answer[index], expected[index], accuracy: 1e-10) }
            }
        }
        XCTAssertEqual(try DCPower.solve([24, 0, nil, nil]), [24,0,0,0])
        XCTAssertThrowsError(try DCPower.solve([nil, 0, 0, nil]))
        XCTAssertThrowsError(try DCPower.solve([24, 0.5, 12, nil]))
        XCTAssertThrowsError(try DCPower.solve([0, 1, nil, nil]))
        XCTAssertThrowsError(try DCPower.solve([1e308, 1e308, nil, nil]))
    }
    @MainActor func testSavedCustomTabs() throws {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = QuickTabStore(defaults: defaults)
        let tab = QuickTab(name: "Voltage divider", expression: "V*R2/(R1+R2)", resultUnit: "V", inputs: [
            QuickInput(symbol: "V", label: "Supply", defaultValue: "12"),
            QuickInput(symbol: "R1", label: "Top", defaultValue: "1000"),
            QuickInput(symbol: "R2", label: "Bottom", defaultValue: "2000")])
        try store.save(tab)
        XCTAssertEqual(try tab.evaluate(["12", "1000", "2000"]), "8")
        let restored = QuickTabStore(defaults: defaults)
        XCTAssertEqual(restored.tabs.last, tab)
        var bad = tab; bad.inputs[1].symbol = "V"
        XCTAssertThrowsError(try restored.save(bad))
        bad = tab; bad.expression = "V/(R1-R1)"
        XCTAssertThrowsError(try restored.save(bad))
        restored.remove(tab.id)
        XCTAssertFalse(QuickTabStore(defaults: defaults).tabs.contains(where: { $0.id == tab.id }))
    }
}
