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
