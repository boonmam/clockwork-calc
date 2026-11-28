import Foundation
import SwiftUI

enum CalculationMode: String, Codable { case calculator, cas }

struct Calculation: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let expression: String
    let text: String
    var latex: String
    let inputLatex: String
    let approximate: Bool
    let warnings: [String]
    var mode: CalculationMode? = nil
    var notation: ResultNotation? = nil
    var angleDegrees: Bool? = nil
    var displayText: String? = nil
    var storedVariables: [String: String]? = nil
    var presentedText: String { displayText ?? text }
}

actor CalculatorEngine {
    private let math = NativeMath()
    func evaluate(_ expression: String, notation: ResultNotation, degrees: Bool, mode: CalculationMode = .calculator) async throws -> Calculation {
        let result = try await evaluate(expression, exact: notation == .exact, degrees: degrees, mode: mode)
        return EngineeringNotation.apply(result, notation: notation)
    }
    func evaluate(_ expression: String, exact: Bool, degrees: Bool, mode: CalculationMode = .calculator, storedVariables: [String: String] = [:]) async throws -> Calculation {
        var result: Calculation
        if mode == .cas { result = try await CASRuntime.evaluate(expression, exact: exact) }
        else { result = try math.evaluate(expression, exact: exact, degrees: degrees, storedVariables: storedVariables) }
        result.storedVariables = mode == .calculator ? storedVariables : nil
        result.mode = mode
        result.angleDegrees = mode == .calculator ? degrees : nil
        return result
    }
}
struct CalculationError: LocalizedError { let message: String; var errorDescription: String? { message } }

@MainActor final class CalculatorModel: ObservableObject {
    @Published var storedVariables: [String: String] = [:]
    @Published var expression = ""
    @Published var casSolve = false
    @Published var casVariables = "x"
    @Published var selection = NSRange(location: 0, length: 0)
    @Published var result: Calculation?
    @Published var history: [Calculation] = []
    @Published var error: String?
    @Published var busy = false
    @AppStorage("resultNotation") var notation: ResultNotation = .exact
    @AppStorage("angleDegrees") var degrees = false
    @AppStorage("calculationMode") var mode: CalculationMode = .calculator
    private var calculationTask: Task<Void, Never>?
    private let engine = CalculatorEngine()
    // Unformatted exact/decimal bases for the currently displayed calculation.
    private var resultBases: [Bool: Calculation] = [:]
    private let historyURL: URL
    private var variablesURL: URL { historyURL.appendingPathExtension("variables.json") }

    init(historyURL: URL? = nil) {
        if UserDefaults.standard.object(forKey: "resultNotation") == nil,
           let legacyExact = UserDefaults.standard.object(forKey: "exactResults") as? Bool {
            notation = legacyExact ? .exact : .decimal
        }
        self.historyURL = historyURL ?? URL.documentsDirectory.appending(path: "history.json")
        if let data = try? Data(contentsOf: self.historyURL),
           let saved = try? JSONDecoder().decode([Calculation].self, from: data) {
            history = Array(saved.prefix(100))
        }
        if let data = try? Data(contentsOf: variablesURL), let saved = try? JSONDecoder().decode([String: String].self, from: data) {
            storedVariables = saved
        }
    }
    func insertDigit(_ text: String) {
        if mode == .calculator, let result, result.expression == expression,
           selection.length == 0, selection.location == expression.utf16.count {
            expression = ""; selection = NSRange(location: 0, length: 0); error = nil
        }
        insert(text)
    }
    func storeAnswer(as name: String) throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard NativeMath.validStoredVariable(name) else {
            throw CalculationError(message: "Use a name such as x, y, or total. Unit names, functions, and built-in constants are reserved.")
        }
        guard let answer = result ?? history.first else { throw CalculationError(message: "Calculate an answer first.") }
        _ = try NativeMath().evaluate(answer.text, exact: true, degrees: false)
        var updated = storedVariables; updated[name] = answer.text
        try saveVariables(updated)
    }
    func removeVariable(_ name: String) throws {
        var updated = storedVariables; updated.removeValue(forKey: name); try saveVariables(updated)
    }
    func clearVariables() throws { try saveVariables([:]) }
    private func saveVariables(_ values: [String: String]) throws {
        try JSONEncoder().encode(values).write(to: variablesURL, options: .atomic)
        storedVariables = values
    }
    func insertStoredVariable(_ name: String) {
        if mode == .calculator, let result, result.expression == expression,
           selection.length == 0, selection.location == expression.utf16.count {
            expression = ""; selection = NSRange(location: 0, length: 0); error = nil
        }
        insert(name)
    }
    func insertOperator(_ operation: String) {
        if let result, selection.length == 0, selection.location == expression.utf16.count,
           expression.trimmingCharacters(in: .whitespacesAndNewlines) == result.expression {
            expression = "(" + result.text + ")"
            selection = NSRange(location: (expression as NSString).length, length: 0)
        }
        insert(operation)
    }
    func insertLastAnswer() {
        guard let answer = history.first else { error = "No previous answer yet."; return }
        insert("(" + answer.text + ")")
    }
    func insert(_ text: String) {
        let source = expression as NSString
        let start = min(selection.location, source.length)
        let range = NSRange(location: start, length: min(selection.length, source.length - start))
        expression = source.replacingCharacters(in: range, with: text)
        selection = NSRange(location: start + (text as NSString).length, length: 0)
        error = nil
    }
    func insertExponent() {
        let source = expression as NSString
        let prefix = source.substring(to: min(selection.location, source.length))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Keep a numeric mantissa and exponent in one token: 1/2 EE 3 means 1/2000.
        if prefix.range(of: #"(?<![A-Za-z_0-9.])(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)$"#,
                        options: .regularExpression) != nil {
            insert("e"); return
        }
        let followsValue = prefix.last.map { $0.isNumber || $0.isLetter || $0 == ")" || $0 == "]" } ?? false
        insert(followsValue ? "*10^" : "10^")
    }
    func backspace() {
        let source = expression as NSString
        let start = min(selection.location, source.length)
        guard start > 0 || selection.length > 0 else { return }
        let range = selection.length > 0 ? NSRange(location: start, length: min(selection.length, source.length - start)) : source.rangeOfComposedCharacterSequence(at: start - 1)
        expression = source.replacingCharacters(in: range, with: "")
        selection = NSRange(location: range.location, length: 0)
    }
    func clear() { resultBases = [:]; result = nil; expression = ""; selection = NSRange(location: 0, length: 0); error = nil }
    func recall(_ item: Calculation) {
        resultBases = [:]
        casSolve = false
        expression = item.expression; selection = NSRange(location: (expression as NSString).length, length: 0)
        result = item; mode = item.mode ?? .calculator
        if let savedNotation = item.notation { notation = savedNotation }
        if let savedDegrees = item.angleDegrees { degrees = savedDegrees }
        error = nil
    }
    func calculate() {
        var input = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, !busy else { return }
        if mode == .cas && casSolve {
            do { input = try CASSolveInput.command(equations: input, variables: casVariables) }
            catch { self.error = error.localizedDescription; return }
        }
        busy = true; error = nil; result = nil; resultBases = [:]
        let notation = notation, degrees = degrees, mode = mode, variables = storedVariables
        calculationTask = Task {
            do {
                let base = try await engine.evaluate(input, exact: notation == .exact, degrees: degrees, mode: mode, storedVariables: variables)
                resultBases = [notation == .exact: base]
                let calculation = EngineeringNotation.apply(base, notation: notation)
                result = calculation
                history.insert(calculation, at: 0); history = Array(history.prefix(100))
                persist()
            } catch is CancellationError { self.error = "Calculation cancelled." }
            catch { self.error = error.localizedDescription }
            busy = false
        }
    }
    func setNotation(_ value: ResultNotation) {
        notation = value
        guard let source = result, !busy else { return }
        let exact = value == .exact
        if let base = resultBases[exact] {
            present(base, as: value)
            return
        }
        // Re-evaluate the displayed calculation only when its exact/decimal base
        // is unavailable. Subsequent numeric-format switches use the cached base.
        busy = true; error = nil
        let calculationMode = source.mode ?? mode
        let calculationDegrees = source.angleDegrees ?? degrees
        calculationTask = Task {
            defer { busy = false }
            do {
                let evaluated = try await engine.evaluate(source.expression, exact: exact, degrees: calculationDegrees, mode: calculationMode, storedVariables: source.storedVariables ?? [:])
                guard !Task.isCancelled, result?.id == source.id, notation == value else { return }
                let base = Calculation(id: source.id, date: source.date, expression: source.expression,
                                       text: evaluated.text, latex: evaluated.latex, inputLatex: evaluated.inputLatex,
                                       approximate: evaluated.approximate, warnings: evaluated.warnings,
                                       mode: evaluated.mode, angleDegrees: evaluated.angleDegrees, storedVariables: evaluated.storedVariables)
                resultBases[exact] = base
                present(base, as: value)
            } catch is CancellationError { self.error = "Format change cancelled." }
            catch { self.error = error.localizedDescription }
        }
    }
    private func present(_ base: Calculation, as notation: ResultNotation) {
        let formatted = EngineeringNotation.apply(base, notation: notation)
        result = formatted
        if let index = history.firstIndex(where: { $0.id == formatted.id }) {
            history[index] = formatted
            persist()
        }
    }
    func cancelCalculation() { calculationTask?.cancel() }
    func example(_ expression: String, mode: CalculationMode? = nil) {
        if let mode { self.mode = mode }
        casSolve = false
        self.expression = expression; selection = NSRange(location: (expression as NSString).length, length: 0); calculate()
    }
    func deleteHistory(at offsets: IndexSet) { history.remove(atOffsets: offsets); persist() }
    private func persist() {
        do { try JSONEncoder().encode(history).write(to: historyURL, options: .atomic) }
        catch { self.error = "The calculation succeeded, but history could not be saved." }
    }
}
