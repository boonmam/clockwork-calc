import XCTest
@testable import Qalculate

final class NotationTests: XCTestCase {
    func testEngineeringScalingAndBoundaries() {
        for (input, expected) in [
            ("4700", "4.7 × 10^3"), ("0.0000022", "2.2 × 10^-6"),
            ("0", "0"), ("999", "999"), ("1000", "1 × 10^3"),
            ("0.999", "999 × 10^-3"), ("1e-10", "100 × 10^-12"),
            ("1.79769313486232e308", "179.769313486232 × 10^306"),
            ("5e-324", "5 × 10^-324"), ("123456789012345678901", "123.456789012345678901 × 10^18")
        ] {
            XCTAssertEqual(EngineeringNotation.format(input, symbolic: false, latex: false), expected, input)
        }
    }
    func testSISymbolsAndFallback() {
        for (input, expected) in [("-4700", "-4.7 k"), ("2.2e-6", "2.2 µ"),
                                  ("1e-30", "1 q"), ("1e30", "1 Q"),
                                  ("1e-33", "1 × 10^-33"), ("1e33", "1 × 10^33"),
                                  ("1000000", "1 M"), ("0.001", "1 m")] {
            XCTAssertEqual(EngineeringNotation.format(input, symbolic: true, latex: false), expected)
        }
    }
    func testLatexAndIdentifierProtection() {
        XCTAssertEqual(EngineeringNotation.format(#"1.2\times 10^{-10}"#, symbolic: false, latex: true), #"{120\times 10^{-12}}"#)
        XCTAssertEqual(EngineeringNotation.format(#"\mathrm{unit1000}+4700\cdot x_{1000}"#, symbolic: true, latex: true), #"\mathrm{unit1000}+{4.7\,\mathrm{k}}\cdot x_{1000}"#)
        XCTAssertEqual(EngineeringNotation.format("x1000+4700*x", symbolic: true, latex: false), "x1000+(4.7 k)*x")
    }
    func testExpressionPrecedenceInPlainDisplay() {
        XCTAssertEqual(EngineeringNotation.format("x^1000+1/4700", symbolic: false, latex: false), "x^(1 × 10^3)+1/(4.7 × 10^3)")
    }
    func testNativeValuesAndReusableText() async throws {
        let engine = CalculatorEngine()
        let value = try await engine.evaluate("4700", notation: .engineering, degrees: false)
        XCTAssertEqual(value.presentedText, "4.7 × 10^3")
        XCTAssertEqual(value.text, "4700")
        let reused = try await engine.evaluate(value.text, exact: true, degrees: false)
        XCTAssertEqual(reused.text, "4700")
        let unit = try await engine.evaluate("4700 m", notation: .symbolicEngineering, degrees: false)
        XCTAssertTrue(unit.presentedText.contains("4.7 k"))
        let complex = try await engine.evaluate("4700+0.0000022*i", notation: .engineering, degrees: false)
        XCTAssertTrue(complex.presentedText.contains("4.7 × 10^3"))
        XCTAssertTrue(complex.presentedText.contains("2.2 × 10^-6"))
    }
    func testCASMatrixAndSymbolicCoefficients() async throws {
        let engine = CalculatorEngine()
        let matrix = try await engine.evaluate("matrix([4700,0.0000022])", notation: .symbolicEngineering, degrees: false, mode: .cas)
        XCTAssertTrue(matrix.latex.contains(#"4.7\,\mathrm{k}"#))
        XCTAssertTrue(matrix.latex.contains(#"2.2\,\mathrm{\mu}"#))
        XCTAssertTrue(matrix.latex.contains(#"\begin{matrix}"#))
        let symbolic = try await engine.evaluate("4700*x", notation: .engineering, degrees: false, mode: .cas)
        XCTAssertTrue(symbolic.latex.contains(#"4.7\times 10^{3}"#))
        XCTAssertTrue(symbolic.text.contains("4700"))
    }
    @MainActor func testLegacyPreferenceMigration() {
        let preferences = UserDefaults.standard
        let oldFormat = preferences.object(forKey: "resultNotation")
        let oldExact = preferences.object(forKey: "exactResults")
        defer {
            preferences.set(oldFormat, forKey: "resultNotation")
            preferences.set(oldExact, forKey: "exactResults")
        }
        preferences.removeObject(forKey: "resultNotation")
        preferences.set(false, forKey: "exactResults")
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let model = CalculatorModel(historyURL: url)
        XCTAssertEqual(model.notation, .decimal)
        model.notation = .engineering
        let restored = CalculatorModel(historyURL: url)
        XCTAssertEqual(restored.notation, .engineering)
    }
    @MainActor func testHistoryPersistsNotationAndOldRecordsDecode() async throws {
        let saved = UserDefaults.standard.string(forKey: "resultNotation")
        defer { UserDefaults.standard.set(saved, forKey: "resultNotation") }
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let model = CalculatorModel(historyURL: url)
        model.notation = .symbolicEngineering; model.expression = "4700"; model.calculate()
        while model.busy { try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertNil(model.error)
        let restored = CalculatorModel(historyURL: url)
        let item = try XCTUnwrap(restored.history.first)
        restored.notation = .exact; restored.recall(item)
        XCTAssertEqual(restored.notation, .symbolicEngineering)
        XCTAssertEqual(item.presentedText, "4.7 k")
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(item)) as? [String: Any])
        old.removeValue(forKey: "notation"); old.removeValue(forKey: "displayText")
        let decoded = try JSONDecoder().decode(Calculation.self, from: JSONSerialization.data(withJSONObject: old))
        XCTAssertEqual(decoded.presentedText, decoded.text)
    }
}
