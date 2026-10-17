import XCTest
@testable import Qalculate

final class EngineTests: XCTestCase {
    let engine = CalculatorEngine()
    func testExactFractionsAndTypesetting() async throws {
        let result = try await engine.evaluate("1/2 + 1/3", exact: true, degrees: false)
        XCTAssertTrue(result.text.contains("5") && result.text.contains("6"), result.text)
        XCTAssertTrue(result.latex.contains("\\frac"), result.latex)
        XCTAssertTrue(result.inputLatex.contains("\\frac"), result.inputLatex)
        XCTAssertFalse(result.approximate)
    }
    func testUnitConversion() async throws {
        let result = try await engine.evaluate("5 ft + 3 in to cm", exact: false, degrees: false)
        XCTAssertTrue(result.text.contains("160.02"), result.text)
        XCTAssertTrue(result.text.contains("cm"), result.text)
    }
    func testSymbolicDifferentiation() async throws {
        let result = try await engine.evaluate("diff(x^3, x)", exact: true, degrees: false)
        XCTAssertTrue(result.text.contains("3") && result.text.contains("x"), result.text)
        XCTAssertTrue(result.latex.contains("2"), result.latex)
    }
    func testDegreeMode() async throws {
        let result = try await engine.evaluate("sin(30)", exact: true, degrees: true)
        XCTAssertTrue(result.latex.contains("\\frac"), result.latex)
    }
    func testComplexNumbers() async throws {
        let result = try await engine.evaluate("sqrt(-1)", exact: true, degrees: false)
        XCTAssertTrue(result.text.contains("i"), result.text)
    }
    func testInputLimit() async {
        do { _ = try await engine.evaluate(String(repeating: "1", count: 4097), exact: true, degrees: false); XCTFail("Expected input error") }
        catch { XCTAssertTrue(error.localizedDescription.contains("4096")) }
    }
}
