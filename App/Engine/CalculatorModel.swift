import Foundation
import SwiftUI

struct Calculation: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let expression: String
    let text: String
    let latex: String
    let inputLatex: String
    let approximate: Bool
    let warnings: [String]
}

actor CalculatorEngine {
    private let bridge = QalculateBridge()
    func evaluate(_ expression: String, exact: Bool, degrees: Bool) throws -> Calculation {
        let result = bridge.evaluate(expression, exact: exact, degrees: degrees)
        if let error = result.error { throw CalculationError(message: error) }
        return Calculation(id: UUID(), date: Date(), expression: expression, text: result.text,
                           latex: result.latex, inputLatex: result.inputLatex,
                           approximate: result.approximate, warnings: result.warnings)
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
    @AppStorage("exactResults") var exact = true
    @AppStorage("angleDegrees") var degrees = false
    private let engine = CalculatorEngine()
    private let historyURL: URL

    init(historyURL: URL? = nil) {
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
        result = item; error = nil
    }
    func calculate() {
        let input = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, !busy else { return }
        busy = true; error = nil
        let exact = exact, degrees = degrees
        Task {
            do {
                let calculation = try await engine.evaluate(input, exact: exact, degrees: degrees)
                result = calculation
                history.insert(calculation, at: 0); history = Array(history.prefix(100))
                persist()
            } catch { self.error = error.localizedDescription }
            busy = false
        }
    }
    func example(_ expression: String) {
        self.expression = expression; selection = NSRange(location: (expression as NSString).length, length: 0); calculate()
    }
    func deleteHistory(at offsets: IndexSet) { history.remove(atOffsets: offsets); persist() }
    private func persist() {
        do { try JSONEncoder().encode(history).write(to: historyURL, options: .atomic) }
        catch { self.error = "The calculation succeeded, but history could not be saved." }
    }
}
