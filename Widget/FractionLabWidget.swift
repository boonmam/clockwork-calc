import SwiftUI
import WidgetKit
import AppIntents

private enum Scratch {
    static let key = "lockScreenScratch"
    static func read() -> QuickCalculation {
        guard let data = UserDefaults.standard.data(forKey: key),
              let value = try? JSONDecoder().decode(QuickCalculation.self, from: data) else { return .init() }
        return value
    }
    static func write(_ value: QuickCalculation) throws {
        UserDefaults.standard.set(try JSONEncoder().encode(value), forKey: key)
    }
}
struct CalculatorKeyIntent: AppIntent {
    static var title: LocalizedStringResource = "Calculator key"
    static var openAppWhenRun = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    @Parameter(title: "Key") var key: String
    init() {}
    init(_ key: String) { self.key = key }
    func perform() async throws -> some IntentResult {
        var scratch = Scratch.read(); scratch.press(key); try Scratch.write(scratch)
        WidgetCenter.shared.reloadTimelines(ofKind: "FractionLabScratch")
        return .result()
    }
}
private struct ScratchEntry: TimelineEntry {
    let date: Date
    let calculation: QuickCalculation
}
private struct ScratchProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScratchEntry { .init(date: .now, calculation: .init()) }
    func getSnapshot(in context: Context, completion: @escaping (ScratchEntry) -> Void) {
        completion(.init(date: .now, calculation: Scratch.read()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ScratchEntry>) -> Void) {
        completion(Timeline(entries: [.init(date: .now, calculation: Scratch.read())], policy: .never))
    }
}
private struct ScratchView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ScratchEntry
    private let pages = [["1","2","3","Next"], ["4","5","6","Next"], ["7","8","9","Next"], ["0",".","⌫","Next"], ["+","−","×","Next"], ["÷","=","AC","Next"]]
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(entry.calculation.operation ?? "ƒ").font(.caption)
                Spacer(minLength: 2)
                Text(entry.calculation.display).font(.system(.headline, design: .monospaced))
                    .lineLimit(1).minimumScaleFactor(0.5).invalidatableContent()
            }
            if family == .accessoryRectangular {
                HStack(spacing: 2) {
                    ForEach(pages[entry.calculation.page], id: \.self) { key in keyButton(key) }
                }
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 4) {
                    ForEach(["7","8","9","÷","AC","4","5","6","×","⌫","1","2","3","−","=","0",".","+"], id: \.self) { key in keyButton(key) }
                }
            }
        }.containerBackground(.fill.tertiary, for: .widget)
    }
    private func keyButton(_ key: String) -> some View {
        Button(intent: CalculatorKeyIntent(key)) {
            Text(key == "Next" ? "›" : key)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: family == .accessoryRectangular ? 30 : 24)
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityLabel(key == "Next" ? "Next keypad page" : key == "AC" ? "Clear calculator" : key)
    }
}
@main
struct FractionLabWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FractionLabScratch", provider: ScratchProvider()) { entry in
            ScratchView(entry: entry)
        }
        .configurationDisplayName("Quick Calculator")
        .description("Calculate in the widget. On the Lock Screen, tap › for more digits and operations. AC clears the scratch calculation.")
        .supportedFamilies([.accessoryRectangular, .systemMedium])
    }
}
