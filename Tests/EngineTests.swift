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

extension EngineTests {
    func testPrecedenceAndImplicitMultiplication() async throws {
        for (input, expected) in [("2^3^2", "512"), ("-2^2", "-4"), ("(-2)^2", "4"),
                                  ("2^-3", "1/8"), ("2(3+4)", "14"), ("1e3+2", "1002"),
                                  ("0.1+0.2", "3/10"), (".5+1.", "3/2")] {
            let result = try await engine.evaluate(input, exact: true, degrees: false)
            XCTAssertEqual(result.text, expected, input)
            XCTAssertFalse(result.approximate, input)
        }
    }
    func testExactArithmeticBeyondDoubleIntegerPrecision() async throws {
        let inputs = ["9007199254740993-9007199254740992": "1",
                      "1/(9007199254740993-9007199254740992)": "1",
                      "9007199254740993/9007199254740993": "1",
                      "9223372036854775807/9223372036854775807": "1"]
        for (input, expected) in inputs {
            let result = try await engine.evaluate(input, exact: true, degrees: false)
            XCTAssertEqual(result.text, expected, input)
            XCTAssertFalse(result.approximate)
        }
    }
    func testFractionArithmeticTable() async throws {
        // Compare a grid of small exact rational sums to independently reduced integer results.
        func gcd(_ a: Int, _ b: Int) -> Int { var x = abs(a), y = b; while y != 0 { (x,y) = (y,x % y) }; return max(x,1) }
        for a in -4...4 { for b in 1...5 {
            let n = a * 7 + 2 * b, d = b * 7, g = gcd(n,d)
            let expected = d/g == 1 ? "\(n/g)" : "\(n/g)/\(d/g)"
            let result = try await engine.evaluate("\(a)/\(b)+2/7", exact: true, degrees: false)
            XCTAssertEqual(result.text, expected)
        } }
    }
    func testOverflowIsApproximateOrExplicitError() async throws {
        let result = try await engine.evaluate("9223372036854775807+1", exact: true, degrees: false)
        XCTAssertTrue(result.approximate)
        XCTAssertFalse(result.warnings.isEmpty)
        let roundedInteger = try await engine.evaluate("9007199254740993", exact: false, degrees: false)
        XCTAssertTrue(roundedInteger.approximate)
        let exactDecimal = try await engine.evaluate("1/2", exact: false, degrees: false)
        XCTAssertFalse(exactDecimal.approximate)
        for input in ["1e308*1e308", "exp(1000)", "2^1024"] {
            do { _ = try await engine.evaluate(input, exact: true, degrees: false); XCTFail(input) }
            catch { XCTAssertTrue(error.localizedDescription.contains("range"), error.localizedDescription) }
        }
    }
    func testCompoundUnitsAndResultRoundTrip() async throws {
        let converted = try await engine.evaluate("60 km/h to m/s", exact: true, degrees: false)
        XCTAssertTrue(converted.text.contains("50/3"), converted.text)
        let again = try await engine.evaluate(converted.text + " to km/h", exact: true, degrees: false)
        XCTAssertTrue(again.text.contains("60"), again.text)
        let area = try await engine.evaluate("sqrt(9 m^2) to cm", exact: true, degrees: false)
        XCTAssertEqual(area.text, "(300)*(cm)")
        let volume = try await engine.evaluate("1 L to cm^3", exact: true, degrees: false)
        XCTAssertTrue(volume.text.contains("1000"), volume.text)
    }
    func testComplexArithmetic() async throws {
        for (input, expected) in [("(1+i)/(1-i)", "i"), ("i*i", "-1"), ("abs(3+4i)", "5"), ("sqrt(-4)", "2*i")] {
            let result = try await engine.evaluate(input, exact: true, degrees: false)
            XCTAssertEqual(result.text, expected, input)
        }
    }
    func testLinearAndQuadraticSolving() async throws {
        let linear = try await engine.evaluate("solve(2*x+1=0,x)", exact: true, degrees: false)
        XCTAssertEqual(linear.text, "-1/2")
        let quadratic = try await engine.evaluate("solve(x^2=9,x)", exact: true, degrees: false)
        XCTAssertEqual(quadratic.text, "{-3, 3}")
        XCTAssertFalse(quadratic.approximate)
        let complex = try await engine.evaluate("solve(x^2+1=0,x)", exact: true, degrees: false)
        XCTAssertEqual(complex.text, "{i, -i}")
        let repeated = try await engine.evaluate("solve(x^2-2*x+1=0,x)", exact: true, degrees: false)
        XCTAssertEqual(repeated.text, "1")
    }
    func testDerivativeChainRuleAndDegrees() async throws {
        let derivative = try await engine.evaluate("diff(sin(x^2),x)", exact: true, degrees: false)
        let atOne = derivative.text.replacingOccurrences(of: "x", with: "1")
        let value = try await engine.evaluate(atOne, exact: false, degrees: false)
        XCTAssertEqual(Double(value.text)!, 2*cos(1), accuracy: 1e-13)
        let degreeDerivative = try await engine.evaluate("diff(sin(x),x)", exact: true, degrees: true)
        let degreeValue = try await engine.evaluate(degreeDerivative.text.replacingOccurrences(of: "x", with: "0"), exact: false, degrees: true)
        XCTAssertEqual(Double(degreeValue.text)!, Double.pi/180, accuracy: 1e-15)
    }
    func testNegativePowerDerivativeAndDecimalRoots() async throws {
        let derivative = try await engine.evaluate("diff(x^-2,x)", exact: true, degrees: false)
        let atTwo = try await engine.evaluate(derivative.text.replacingOccurrences(of: "x", with: "2"), exact: true, degrees: false)
        XCTAssertEqual(atTwo.text, "-1/4")
        let root = try await engine.evaluate("solve(3*x=1,x)", exact: false, degrees: false)
        XCTAssertTrue(root.approximate)
        XCTAssertEqual(Double(root.text)!, 1.0/3, accuracy: 1e-14)
    }
    func testScientificFunctions() async throws {
        for (input, expected) in [("ln(e)", 1.0), ("log(100)", 2.0), ("sin(pi/2)", 1.0),
                                  ("sqrt(9/16)", 0.75), ("floor(-1.2)", -2.0), ("ceil(-1.2)", -1.0)] {
            let result = try await engine.evaluate(input, exact: false, degrees: false)
            XCTAssertEqual(Double(result.text)!, expected, accuracy: 1e-14)
        }
    }
    func testExplicitErrorsForUnsupportedOrInvalidInput() async {
        for input in ["1/0", "0^0", "ln(-1)", "asin(2)", "1 m + 1 s", "1 m to kg",
                      "1 m to 2 m", "sqrt(1 m)", "sin(i)", "matrix(1,2)", "integrate(x,x)",
                      "solve(x^3=1,x)", "solve(x/x=1,x)", "solve(1=1,x)", "diff(abs(x),x)",
                      "2+", "(", "1..2", "1,2", "1)", "\\frac{1}{2}", "", "to", "1e999"] {
            do { _ = try await engine.evaluate(input, exact: true, degrees: false); XCTFail("Expected rejection: \(input)") }
            catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
        }
    }
    func testComplexityLimitsAndExtremeLiterals() async throws {
        for input in [String(repeating: "(", count: 60)+"1"+String(repeating: ")", count: 60),
                      Array(repeating: "1", count: 200).joined(separator: "+")] {
            do { _ = try await engine.evaluate(input, exact: true, degrees: false); XCTFail("Expected limit") }
            catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
        }
        let zero = try await engine.evaluate("0e-9223372036854775808", exact: true, degrees: false)
        XCTAssertEqual(zero.text, "0")
    }
    func testLicenseNoticesAndNoLegacyResources() throws {
        let bundle = Bundle(for: CalculatorModel.self)
        for name in ["App-MIT", "KaTeX-MIT"] {
            let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "txt", subdirectory: "Licenses"))
            XCTAssertTrue(try String(contentsOf: url).contains("Permission is hereby granted"))
        }
        XCTAssertNil(bundle.url(forResource: "functions", withExtension: "xml", subdirectory: "Definitions"))
    }
}

extension EngineTests {
    func testNumberAfterPiAndGroupedExpression() async throws {
        for (input, explicit) in [("200/(1/2π150e−6*60)", "200/(1/2*pi*150e-6*60)"),
                                  ("π150", "pi*150"), ("(2+3)4", "(2+3)*4")] {
            let actual = try await engine.evaluate(input, exact: false, degrees: false)
            let expected = try await engine.evaluate(explicit, exact: false, degrees: false)
            XCTAssertEqual(actual.text, expected.text)
        }
        do {
            _ = try await engine.evaluate("2 3", exact: false, degrees: false)
            XCTFail("Separate numbers still require an operator")
        } catch {}
    }
}
