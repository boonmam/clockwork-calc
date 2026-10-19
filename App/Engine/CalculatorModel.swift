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
    var displayText: String? = nil
    var presentedText: String { displayText ?? text }
}

actor CalculatorEngine {
    private let math = NativeMath()
    func evaluate(_ expression: String, notation: ResultNotation, degrees: Bool, mode: CalculationMode = .calculator) async throws -> Calculation {
        let result = try await evaluate(expression, exact: notation == .exact, degrees: degrees, mode: mode)
        return EngineeringNotation.apply(result, notation: notation)
    }
    func evaluate(_ expression: String, exact: Bool, degrees: Bool, mode: CalculationMode = .calculator) async throws -> Calculation {
        if mode == .cas { return try await CASRuntime.evaluate(expression, exact: exact) }
        return try math.evaluate(expression, exact: exact, degrees: degrees)
    }
}
struct CalculationError: LocalizedError { let message: String; var errorDescription: String? { message } }

@MainActor final class CalculatorModel: ObservableObject {
    @Published var expression = ""
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
    private let historyURL: URL

    init(historyURL: URL? = nil) {
        if UserDefaults.standard.object(forKey: "resultNotation") == nil,
           let legacyExact = UserDefaults.standard.object(forKey: "exactResults") as? Bool {
            notation = legacyExact ? .exact : .decimal
        }
        self.historyURL = historyURL ?? URL.documentsDirectory.appending(path: "history.json")
        if let data = try? Data(contentsOf: self.historyURL),
           let saved = try? JSONDecoder().decode([Calculation].self, from: data) {
            history = Array(saved.prefix(100)); result = history.first
        }
    }
    func insert(_ text: String) {
        let source = expression as NSString
        let start = min(selection.location, source.length)
        let range = NSRange(location: start, length: min(selection.length, source.length - start))
        expression = source.replacingCharacters(in: range, with: text)
        selection = NSRange(location: start + (text as NSString).length, length: 0)
        error = nil
    }
    func backspace() {
        let source = expression as NSString
        let start = min(selection.location, source.length)
        guard start > 0 || selection.length > 0 else { return }
        let range = selection.length > 0 ? NSRange(location: start, length: min(selection.length, source.length - start)) : source.rangeOfComposedCharacterSequence(at: start - 1)
        expression = source.replacingCharacters(in: range, with: "")
        selection = NSRange(location: range.location, length: 0)
    }
    func clear() { expression = ""; selection = NSRange(location: 0, length: 0); error = nil }
    func recall(_ item: Calculation) {
        expression = item.expression; selection = NSRange(location: (expression as NSString).length, length: 0)
        result = item; mode = item.mode ?? .calculator
        if let savedNotation = item.notation { notation = savedNotation }
        error = nil
    }
    func calculate() {
        let input = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, !busy else { return }
        busy = true; error = nil
        let notation = notation, degrees = degrees, mode = mode
        calculationTask = Task {
            do {
                let calculation = try await engine.evaluate(input, notation: notation, degrees: degrees, mode: mode)
                result = calculation
                history.insert(calculation, at: 0); history = Array(history.prefix(100))
                persist()
            } catch is CancellationError { self.error = "Calculation cancelled." }
            catch { self.error = error.localizedDescription }
            busy = false
        }
    }
    func cancelCalculation() { calculationTask?.cancel() }
    func example(_ expression: String, mode: CalculationMode? = nil) {
        if let mode { self.mode = mode }
        self.expression = expression; selection = NSRange(location: (expression as NSString).length, length: 0); calculate()
    }
    func deleteHistory(at offsets: IndexSet) { history.remove(atOffsets: offsets); persist() }
    private func persist() {
        do { try JSONEncoder().encode(history).write(to: historyURL, options: .atomic) }
        catch { self.error = "The calculation succeeded, but history could not be saved." }
    }
}
