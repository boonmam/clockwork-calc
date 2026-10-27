import Foundation

@main struct QuickWidgetTests {
    static func main() throws {
        func calculate(_ keys: [String]) -> QuickCalculation {
            var c = QuickCalculation(); for key in keys { c.press(key) }; return c
        }
        assert(calculate(["1", ".", "5", "+", "2", "="]).display == "3.5")
        assert(calculate(["9", "−", "1", "2", "="]).display == "-3")
        assert(calculate(["6", "×", "7", "="]).display == "42")
        assert(calculate(["8", "÷", "0", "="]).error)
        assert(calculate(["8", "÷", "0", "=", "AC"]).display == "0")
        assert(calculate(["1", "2", "⌫"]).display == "1")
        assert(calculate(["1", "+", "2", "=", "4"]).display == "4")
        assert(calculate(["1", "+", "×", "3", "="]).display == "3")
        var c = calculate(["2", "+", "3"])
        c = try JSONDecoder().decode(QuickCalculation.self, from: JSONEncoder().encode(c))
        c.press("="); assert(c.display == "5")
        for _ in 0..<6 { c.press("Next") }; assert(c.page == 0)
        print("10 widget calculator checks passed")
    }
}
