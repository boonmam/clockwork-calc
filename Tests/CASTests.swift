import XCTest
@testable import ClockworkCalc

final class CASTests: XCTestCase {
    let engine = CalculatorEngine()
    func cas(_ input: String, exact: Bool = true) async throws -> Calculation {
        try await engine.evaluate(input, exact: exact, degrees: false, mode: .cas)
    }
    func testSymbolicAlgebra() async throws {
        let sum = try await cas("x+x")
        XCTAssertEqual(sum.text, "2*x")
        XCTAssertEqual(sum.mode, .cas)
        let expanded = try await cas("expand((x+1)^3)")
        XCTAssertEqual(expanded.text, "1+3*x+3*x^2+x^3")
        let reduced = try await cas("simplify((x^2-1)/(x-1))")
        XCTAssertEqual(reduced.text, "1+x")
    }
    func testMatrices() async throws {
        let inverse = try await cas("invert(matrix([1,2],[3,4]))")
        XCTAssertEqual(inverse.text, "matrix([-2, 1], [3/2, -1/2])")
        XCTAssertTrue(inverse.latex.contains("matrix"))
        let identity = try await cas("(" + inverse.text + ")*matrix([1,2],[3,4])")
        XCTAssertEqual(identity.text, "matrix([1, 0], [0, 1])")
        let determinant = try await cas("determinant(matrix([1,2],[3,4]))")
        XCTAssertEqual(determinant.text, "-2")
    }
    func testIntegration() async throws {
        let anti = try await cas("integrate(x^2,x)")
        XCTAssertEqual(anti.text, "(1/3)*x^3")
        XCTAssertTrue(anti.warnings.joined().contains("constant C"))
        let definite = try await cas("integrate(x^2,x,0,1)")
        XCTAssertEqual(definite.text, "1/3")
        XCTAssertFalse(definite.approximate)
        let numeric = try await cas("nint(exp(-x^2),x,0,1)")
        XCTAssertEqual(Double(numeric.text)!, 0.7468241328124271, accuracy: 1e-8)
        XCTAssertTrue(numeric.approximate)
    }
}

extension CASTests {
    func testLimitsSystemsAndRREF() async throws {
        let limit = try await cas("limit(sin(x)/x,x,0)")
        XCTAssertEqual(limit.text, "1")
        let system = try await cas("linsolve([x+y=3,x-y=1],[x,y])")
        XCTAssertEqual(system.text, "[{x => 2, y => 1}]")
        let rref = try await cas("rref(matrix([1,2,3],[2,4,6]))")
        XCTAssertEqual(rref.text, "matrix([1, 2, 3], [0, 0, 0])")
        let roots = try await cas("solve(x^3-1,x)")
        XCTAssertTrue(roots.text.contains("3^(1/2)*i"))
    }
    func testSymbolicDerivativeOfAntiderivative() async throws {
        let result = try await cas("simplify(diff(integrate(x^2*sin(x),x),x)-x^2*sin(x))")
        XCTAssertEqual(result.text, "0")
    }
    func testRejectedInputs() async {
        for input in ["invert(matrix([1,2],[2,4]))", "matrix([1,2],[3])",
                      "nint(1/x,x,-1,1)", "nint(1/(x-0.1),x,-1,1)", "unknown(x)",
                      "x:=1", "while(1)", "imatrix(1000000)", "solve([x+y=3,x-y=1],[x,y])"] {
            do { _ = try await cas(input); XCTFail("Expected rejection: \(input)") }
            catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
        }
    }
    func testUnresolvedIntegralAndDecimalMatrix() async throws {
        let unresolved = try await cas("integrate(sin(x^x),x)")
        XCTAssertTrue(unresolved.warnings.joined().contains("unevaluated"))
        let decimal = try await cas("matrix([1/3,pi])", exact: false)
        XCTAssertTrue(decimal.approximate)
        XCTAssertTrue(decimal.text.contains("3.14159"))
    }
    @MainActor func testWorkerDeadlineAndRecovery() async throws {
        let runtime = CASRuntime()
        let start = Date()
        do {
            _ = try await runtime.run("1", exact: true, timeout: .seconds(1),
                                      scriptOverride: "self.onmessage = () => { while (true) {} };")
            XCTFail("Expected worker timeout")
        } catch { XCTAssertTrue(error.localizedDescription.contains("timed out"), error.localizedDescription) }
        XCTAssertLessThan(Date().timeIntervalSince(start), 4)
        let recovery = try await cas("x+x")
        XCTAssertEqual(recovery.text, "2*x")
    }
    @MainActor func testWorkerCancellation() async throws {
        let task = Task {
            try await CASRuntime().run("1", exact: true, timeout: .seconds(5),
                                       scriptOverride: "self.onmessage = () => { while (true) {} };")
        }
        try await Task.sleep(for: .milliseconds(200))
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
    }
    @MainActor func testCASModeHistoryRoundTrip() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url); UserDefaults.standard.set("calculator", forKey: "calculationMode") }
        let model = CalculatorModel(historyURL: url)
        model.mode = .cas; model.expression = "matrix([1,2],[3,4])"; model.calculate()
        while model.busy { try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertNil(model.error)
        let restored = CalculatorModel(historyURL: url)
        restored.mode = .calculator
        let result = try XCTUnwrap(restored.history.first)
        restored.recall(result)
        XCTAssertEqual(restored.mode, .cas)
    }
}

// Exercise the shipped analysis module through the real offline WebKit worker.
extension CASTests {
    func testConvergentImproperEndpoints() async throws {
        for (input, expected) in [
            ("integrate(exp(-x),x,0,Infinity)", "1"),
            ("integrate(1/sqrt(x),x,0,1)", "2"),
            ("integrate(exp(x),x,-Infinity,0)", "1"),
            ("integrate(x^2*exp(-x),x,0,∞)", "2")
        ] {
            let result = try await cas(input)
            XCTAssertEqual(result.text, expected, input)
            XCTAssertFalse(result.approximate)
            XCTAssertTrue(result.warnings.joined().contains("Convergent"))
        }
    }
    func testSeparateComponentsAndReversedBounds() async throws {
        let split = try await cas("integrate(1/sqrt(abs(x)),x,-1,1)")
        XCTAssertEqual(split.text, "4")
        XCTAssertTrue(split.warnings.joined().contains("Split at 0"))
        let whole = try await cas("integrate(1/(1+x^2),x,-Infinity,Infinity)")
        XCTAssertEqual(whole.text, "pi")
        let reversed = try await cas("integrate(1/(1+x^2),x,Infinity,-Infinity)")
        XCTAssertEqual(reversed.text, "-pi")
        let numeric = try await cas("nint(exp(-x),x,0,Infinity)")
        XCTAssertEqual(Double(numeric.text)!, 1, accuracy: 1e-10)
        XCTAssertTrue(numeric.approximate)
    }
    func testDivergenceIsNotPrincipalValue() async {
        for input in ["integrate(1/x,x,0,1)", "integrate(1/x,x,-1,1)",
                      "integrate(1/(x-0.1),x,-1,1)",
                      "integrate(x/(1+x^2),x,-Infinity,Infinity)"] {
            do { _ = try await cas(input); XCTFail("Expected divergence: \(input)") }
            catch { XCTAssertTrue(error.localizedDescription.contains("Divergent improper integral"), error.localizedDescription) }
        }
    }
    func testUnresolvedConvergenceIsNotDivergence() async {
        for input in ["integrate(exp(-x^2),x,0,Infinity)", "integrate(sin(x),x,0,Infinity)",
                      "integrate(1/(1+x^3),x,0,Infinity)", "integrate(1/(x^2-2),x,0,2)"] {
            do { _ = try await cas(input); XCTFail("Expected unresolved: \(input)") }
            catch { XCTAssertTrue(error.localizedDescription.contains("Convergence unresolved"), error.localizedDescription) }
        }
    }
}
