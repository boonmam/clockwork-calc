import SwiftUI

struct ConversionCategory: Identifiable {
    let name: String
    let units: [Dimension]
    var id: String { name }
    func convert(_ value: Double, from: Int, to: Int) -> Double {
        Measurement(value: value, unit: units[from]).converted(to: units[to]).value
    }
    static let all: [Self] = [
        .init(name: "Length", units: [UnitLength.meters, UnitLength.centimeters, UnitLength.millimeters, UnitLength.kilometers, UnitLength.inches, UnitLength.feet, UnitLength.yards, UnitLength.miles]),
        .init(name: "Area", units: [UnitArea.squareMeters, UnitArea.squareKilometers, UnitArea.squareFeet, UnitArea.squareInches, UnitArea.acres, UnitArea.hectares]),
        .init(name: "Volume", units: [UnitVolume.liters, UnitVolume.milliliters, UnitVolume.cubicMeters, UnitVolume.cups, UnitVolume.pints, UnitVolume.quarts, UnitVolume.gallons, UnitVolume.imperialGallons]),
        .init(name: "Weight & mass", units: [UnitMass.kilograms, UnitMass.grams, UnitMass.milligrams, UnitMass.ounces, UnitMass.pounds, UnitMass.metricTons]),
        .init(name: "Temperature", units: [UnitTemperature.celsius, UnitTemperature.fahrenheit, UnitTemperature.kelvin]),
        .init(name: "Speed", units: [UnitSpeed.metersPerSecond, UnitSpeed.kilometersPerHour, UnitSpeed.milesPerHour, UnitSpeed.knots]),
        .init(name: "Time", units: [UnitDuration.seconds, UnitDuration.minutes, UnitDuration.hours, UnitDuration.milliseconds]),
        .init(name: "Energy", units: [UnitEnergy.joules, UnitEnergy.kilojoules, UnitEnergy.calories, UnitEnergy.kilocalories, UnitEnergy.kilowattHours]),
        .init(name: "Power", units: [UnitPower.watts, UnitPower.kilowatts, UnitPower.megawatts, UnitPower.horsepower]),
        .init(name: "Pressure", units: [UnitPressure.newtonsPerMetersSquared, UnitPressure.kilopascals, UnitPressure.bars, UnitPressure.poundsForcePerSquareInch, UnitPressure.millimetersOfMercury]),
        .init(name: "Angle", units: [UnitAngle.degrees, UnitAngle.radians, UnitAngle.revolutions])
    ]
    static func label(_ unit: Dimension) -> String {
        if unit == UnitVolume.gallons { return "US gallons (gal)" }
        if unit == UnitVolume.imperialGallons { return "Imperial gallons (imp gal)" }
        if unit == UnitVolume.cups { return "US cups" }
        if unit == UnitVolume.pints { return "US pints" }
        if unit == UnitVolume.quarts { return "US quarts" }
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .long
        return "\(formatter.string(from: unit)) (\(unit.symbol))"
    }
}

struct UnitConverterView: View {
    @State private var categoryIndex = 0
    @State private var from = 0
    @State private var to = 1
    @State private var input = "0"
    private var category: ConversionCategory { ConversionCategory.all[categoryIndex] }
    private var output: String {
        guard let value = Double(input), value.isFinite else { return "—" }
        let result = category.convert(value, from: from, to: to)
        guard result.isFinite else { return "Out of range" }
        return result.formatted(.number.precision(.significantDigits(1...12)))
    }
    var body: some View {
        GeometryReader { space in
            let wide = space.size.width >= 620 || (space.size.width >= 500 && space.size.height < 500)
            let layout = wide ? AnyLayout(HStackLayout(spacing: 20)) : AnyLayout(VStackLayout(spacing: 12))
            layout {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Picker("Category", selection: $categoryIndex) {
                            ForEach(ConversionCategory.all.indices, id: \.self) { i in
                                Text(ConversionCategory.all[i].name).tag(i)
                            }
                        }.accessibilityIdentifier("conversionCategory")
                        Spacer(minLength: 0)
                        Button { swap(&from, &to) } label: {
                            Image(systemName: "arrow.up.arrow.down").frame(width: 44, height: 44)
                        }.accessibilityLabel("Swap units").accessibilityIdentifier("swapUnits")
                    }
                    HStack {
                        Text("From").font(.caption).foregroundStyle(.secondary).fixedSize()
                        unitPicker("From unit", selection: $from)
                    }.frame(minHeight: 44)
                    Text(input).font(.system(size: 28, weight: .medium, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.4).textSelection(.enabled)
                        .accessibilityIdentifier("conversionInput")
                    HStack {
                        Text("To").font(.caption).foregroundStyle(.secondary).fixedSize()
                        unitPicker("To unit", selection: $to)
                    }.frame(minHeight: 44)
                    HStack {
                        Text(output).font(.system(size: 28, weight: .medium, design: .rounded))
                            .lineLimit(1).minimumScaleFactor(0.4).foregroundStyle(Color.calculatorAccent).textSelection(.enabled)
                            .accessibilityIdentifier("conversionResult")
                        Spacer(minLength: 0)
                        Button { UIPasteboard.general.string = output } label: {
                            Image(systemName: "doc.on.doc").frame(width: 44, height: 44)
                        }.accessibilityLabel("Copy result").accessibilityIdentifier("copyConversion")
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(["7", "8", "9", "⌫", "4", "5", "6", "AC", "1", "2", "3", "±", "0", ".", "EE", "−"], id: \.self) { key in
                        Button { press(key) } label: {
                            Text(key).font(.title2).frame(maxWidth: .infinity).frame(height: 48)
                                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain).accessibilityIdentifier("convertKey_\(key)")
                    }
                }.frame(width: wide ? min(340, space.size.width * 0.38) : nil)
            }.padding(12).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onChange(of: categoryIndex) { _, _ in from = 0; to = 1 }
    }
    private func unitPicker(_ title: String, selection: Binding<Int>) -> some View {
        Picker(title, selection: selection) {
            ForEach(category.units.indices, id: \.self) { i in
                Text(ConversionCategory.label(category.units[i]))
                    .lineLimit(1).minimumScaleFactor(0.6).tag(i)
            }
        }.pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(1).minimumScaleFactor(0.6)
            .accessibilityIdentifier(title == "From unit" ? "fromUnit" : "toUnit")
    }
    private func press(_ key: String) {
        CalculatorHaptics.keyPress()
        switch key {
        case "AC": input = "0"
        case "⌫": input = String(input.dropLast()); if input.isEmpty || input == "-" { input = "0" }
        case "±": if input.hasPrefix("-") { input.removeFirst() } else { input = "-" + input }
        case "−": if input.hasSuffix("e") { input += "-" } else if !input.contains("e") { input = "-" + input.replacingOccurrences(of: "-", with: "") }
        case "EE": if !input.contains("e") { input += "e" }
        case ".": if !input.contains(".") && !input.contains("e") { input += "." }
        default: if input.count < 32 { input = input == "0" ? key : input + key }
        }
    }
}
