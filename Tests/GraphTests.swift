import XCTest
import UIKit
import ImageIO
@testable import ClockworkCalc
final class GraphTests: XCTestCase {
    func testCompiledFunctionsAndDomains() throws {
        let sine = try NativeMath().graphFunction("y = sin(x)")
        XCTAssertEqual(sine(.pi/2)!, 1, accuracy: 1e-12)
        let polynomial = try NativeMath().graphFunction("x^2-2*x+1")
        XCTAssertEqual(polynomial(3), 4)
        let root = try NativeMath().graphFunction("sqrt(x)")
        XCTAssertNil(root(-1)); XCTAssertEqual(root(9), 3)
        XCTAssertThrowsError(try NativeMath().graphFunction("z+1"))
        XCTAssertThrowsError(try NativeMath().graphFunction("x=2"))
    }
    func testDiscontinuitiesDoNotConnectAcrossZero() {
        let curve = GraphSampler.sample(GraphEquation(expression: "1/x"), window: GraphWindow())
        XCTAssertNil(curve.error)
        XCTAssertGreaterThanOrEqual(curve.segments.count, 2)
        for segment in curve.segments {
            XCTAssertFalse(segment.contains { $0.x < 0 } && segment.contains { $0.x > 0 })
        }
        XCTAssertNotNil(GraphSampler.sample(GraphEquation(expression: "bogus(x)"), window: GraphWindow()).error)
        var window = GraphWindow(); window.zoom(0.5)
        XCTAssertEqual(window.spanX, 10)
        window.zoom(1e-100); XCTAssertEqual(window.spanX, 1e-6)
    }
    func testKeypadSelectionAndExponent() {
        var text = "1000", selection = NSRange(location: 0, length: 4)
        NumberPadEditing.apply("2", text: &text, selection: &selection)
        XCTAssertEqual(text, "2")
        NumberPadEditing.apply("EE", text: &text, selection: &selection)
        NumberPadEditing.apply("3", text: &text, selection: &selection)
        XCTAssertEqual(text, "2e3")
        NumberPadEditing.apply("±", text: &text, selection: &selection)
        XCTAssertEqual(text, "2e-3")
        NumberPadEditing.apply("±", text: &text, selection: &selection)
        NumberPadEditing.apply("⌫", text: &text, selection: &selection)
        XCTAssertEqual(text, "2e")
        NumberPadEditing.apply("AC", text: &text, selection: &selection)
        XCTAssertEqual(text, "")
    }
    @MainActor func testLegacyTabsRetainInputDefaultsAndSaveChoice() throws {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var tab = QuickTab.starters[0]
        XCTAssertEqual(tab.effectiveInputStyle, .keypad)
        XCTAssertEqual(QuickTab.starters[1].effectiveInputStyle, .keyboard)
        let store = QuickTabStore(defaults: defaults)
        tab.inputStyle = .keyboard; try store.save(tab)
        XCTAssertEqual(QuickTabStore(defaults: defaults).tabs.first { $0.id == tab.id }?.effectiveInputStyle, .keyboard)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(tab)) as! [String: Any]
        json.removeValue(forKey: "inputStyle")
        let legacy = try JSONDecoder().decode(QuickTab.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(legacy.effectiveInputStyle, .keypad)
    }
}

extension GraphTests {
    func testAxisBoundsAndPersistence() throws {
        let window = try GraphWindow.bounds(xMin: -5, xMax: 15, yMin: -2, yMax: 8)
        XCTAssertEqual(window.centerX, 5); XCTAssertEqual(window.centerY, 3)
        XCTAssertEqual(window.xMin, -5); XCTAssertEqual(window.xMax, 15)
        XCTAssertEqual(window.yMin, -2); XCTAssertEqual(window.yMax, 8)
        XCTAssertEqual(try JSONDecoder().decode(GraphWindow.self, from: JSONEncoder().encode(window)), window)
        XCTAssertThrowsError(try GraphWindow.bounds(xMin: 2, xMax: 2, yMin: -1, yMax: 1))
        XCTAssertThrowsError(try GraphWindow.bounds(xMin: 2, xMax: -2, yMin: -1, yMax: 1))
        XCTAssertThrowsError(try GraphWindow.bounds(xMin: -.infinity, xMax: 1, yMin: -1, yMax: 1))
    }
    func testSliderConstantsEvaluateAndPersist() throws {
        var a = GraphConstant(name: "a", value: 2, minimum: -5, maximum: 5, step: 0.25)
        try a.validate()
        XCTAssertEqual(try JSONDecoder().decode(GraphConstant.self, from: JSONEncoder().encode(a)), a)
        let function = try NativeMath().graphFunction("a*sin(b*x)", constants: ["a": 2, "b": 3])
        XCTAssertEqual(try XCTUnwrap(function(.pi/6)), 2, accuracy: 1e-12)
        let changed = try NativeMath().graphFunction("a*sin(b*x)", constants: ["a": 4, "b": 3])
        XCTAssertEqual(try XCTUnwrap(changed(.pi/6)), 4, accuracy: 1e-12)
        XCTAssertNil(GraphSampler.sample(GraphEquation(expression: "a*x"), window: GraphWindow(), constants: ["a": 0.5]).error)
        XCTAssertThrowsError(try NativeMath().graphFunction("a*x"))
        XCTAssertThrowsError(try NativeMath().graphFunction("x", constants: ["x": 4]))
        a.name = "pi"; XCTAssertThrowsError(try a.validate())
        a.name = "a"; a.step = 0; XCTAssertThrowsError(try a.validate())
        a.step = 0.1; a.value = 6; XCTAssertThrowsError(try a.validate())
    }
}

extension GraphTests {
    func testConstantsAutomaticallyCreateSliders() throws {
        let a = GraphConstant(name: "a", value: 3)
        let equations = [GraphEquation(expression: "a*sin(b*x)+offset+pi+2e-3")]
        let merged = GraphConstant.addingMissing(for: equations, to: [a])
        XCTAssertEqual(merged.map(\.name), ["a", "b", "offset"])
        XCTAssertEqual(merged[0].value, 3)
        XCTAssertEqual(GraphConstant.addingMissing(for: equations, to: merged), merged)
        XCTAssertEqual(try NativeMath().graphConstantNames("y = gain*x+pi+exp(x)"), ["gain"])
        XCTAssertTrue(GraphConstant.addingMissing(for: [GraphEquation(expression: "sin(")], to: []).isEmpty)
        let many = GraphEquation(expression: ["a", "b", "c", "d", "f", "g", "h", "j", "k", "m", "n", "p"].joined(separator: "+"))
        XCTAssertEqual(GraphConstant.addingMissing(for: [many], to: []).count, 8)
    }
}

extension GraphTests {
    func testUserDefinitionAndCapacitanceSweep() throws {
        let equations = [
            GraphEquation(expression: "y = (1-x/50)*(101*M)*C"),
            GraphEquation(expression: "M = 1/(1-(x/120)^n)"),
            GraphEquation(expression: "C = [1u, 10u, 30u, 60u]")]
        let sliders = GraphConstant.addingMissing(for: equations, to: [GraphConstant(name: "M"), GraphConstant(name: "C")])
        XCTAssertEqual(sliders.map(\.name), ["n"])
        let workspace = NativeMath().graphWorkspace(equations, constants: ["n": 2])
        XCTAssertTrue(workspace.errors.isEmpty, "\(workspace.errors)")
        XCTAssertEqual(workspace.curves.count, 4)
        let values = [1e-6, 10e-6, 30e-6, 60e-6]
        for (curve, c) in zip(workspace.curves, values) {
            XCTAssertEqual(try XCTUnwrap(curve.evaluate(0)), 101*c, accuracy: 1e-12)
            XCTAssertEqual(try XCTUnwrap(curve.evaluate(30)), (1-30.0/50)*101/(1-pow(30.0/120,2))*c, accuracy: 1e-12)
            XCTAssertEqual(curve.evaluate(50), 0)
            XCTAssertNil(curve.evaluate(120))
            XCTAssertTrue(curve.label?.hasPrefix("C=") == true)
        }
        let reversed = NativeMath().graphWorkspace(equations.reversed(), constants: ["n": 2])
        XCTAssertTrue(reversed.errors.isEmpty)
        XCTAssertEqual(reversed.curves.count, 4)
    }
    func testNamedDefinitionsAndListErrors() throws {
        let native = NativeMath()
        let good = native.graphWorkspace([GraphEquation(expression: "y=A*x"), GraphEquation(expression: "A=2u")], constants: [:])
        XCTAssertTrue(good.errors.isEmpty)
        XCTAssertEqual(try XCTUnwrap(good.curves.first?.evaluate(3)), 6e-6, accuracy: 1e-12)
        let circular = native.graphWorkspace([GraphEquation(expression: "y=A"), GraphEquation(expression: "A=B+1"), GraphEquation(expression: "B=A+1")], constants: [:])
        XCTAssertTrue(circular.curves.isEmpty)
        XCTAssertTrue(circular.errors.values.contains { $0.contains("Circular") })
        let duplicate = native.graphWorkspace([GraphEquation(expression: "y=A"), GraphEquation(expression: "A=1"), GraphEquation(expression: "A=2")], constants: [:])
        XCTAssertTrue(duplicate.curves.isEmpty)
        XCTAssertTrue(duplicate.errors.values.contains { $0.contains("Duplicate") })
        let oversized = native.graphWorkspace([GraphEquation(expression: "y=A*B"), GraphEquation(expression: "A=[1,2,3,4,5]"), GraphEquation(expression: "B=[1,2,3,4]")], constants: [:])
        XCTAssertTrue(oversized.curves.isEmpty)
        XCTAssertTrue(oversized.errors.values.contains { $0.contains("16") })
        let sampled = GraphSampler.sampleAll([GraphEquation(expression: "y=C*x"), GraphEquation(expression: "C=[1u,10u,30u,60u]")], window: GraphWindow(), constants: [:])
        XCTAssertEqual(sampled.filter { !$0.segments.isEmpty }.count, 4)
    }
}


extension GraphTests {
    @MainActor func testJPEGExportIncludesEverySweepLegendEntry() throws {
        let equations = [GraphEquation(expression: "y=(1-x/50)*(101*M)*C"),
                         GraphEquation(expression: "M=1/(1-(x/120)^n)"),
                         GraphEquation(expression: "C=[1u,10u,30u,60u]")]
        let window = try GraphWindow.bounds(xMin: 0, xMax: 100, yMin: -0.02, yMax: 0.01)
        let curves = GraphSampler.sampleAll(equations, window: window, constants: ["n": 2])
        let entries = GraphLegendEntry.entries(equations: equations, curves: curves)
        XCTAssertEqual(entries.map(\.label), ["C=1 µ", "C=10 µ", "C=30 µ", "C=60 µ"])
        XCTAssertEqual(Set(entries.map(\.id)).count, 4)
        let url = try GraphJPEGExport.write(equations: equations, window: window, curves: curves, constants: [GraphConstant(name: "n", value: 2)])
        defer { try? FileManager.default.removeItem(at: url) }
        let data = try Data(contentsOf: url)
        XCTAssertEqual(Array(data.prefix(3)), [0xff, 0xd8, 0xff])
        let image = try XCTUnwrap(UIImage(data: data)?.cgImage)
        XCTAssertEqual(image.width, 2000)
        XCTAssertGreaterThan(image.height, 1500)
        let attachment = XCTAttachment(contentsOfFile: url); attachment.name = "Four-value plot JPEG"; attachment.lifetime = .keepAlways; add(attachment)
        var hidden = equations; hidden[0].visible = false
        XCTAssertTrue(GraphLegendEntry.entries(equations: hidden, curves: curves).isEmpty)
    }
}


extension GraphTests {
    @MainActor func testPrintJPEGUsesWhiteBackgroundAndDistinctMonochromeLines() throws {
        let equations = [GraphEquation(expression: "y=C*x"), GraphEquation(expression: "C=[1u,10u,30u,60u]")]
        let window = try GraphWindow.bounds(xMin: 0, xMax: 10, yMin: 0, yMax: 0.0006)
        let curves = GraphSampler.sampleAll(equations, window: window, constants: [:])
        let entries = GraphLegendEntry.entries(equations: equations, curves: curves, monochrome: true)
        XCTAssertEqual(entries.count, 4)
        XCTAssertEqual(Set(entries.map(\.dash)).count, 4)
        XCTAssertTrue(entries.allSatisfy { $0.color == .black })
        let url = try GraphJPEGExport.write(equations: equations, window: window, curves: curves, constants: [], monochrome: true)
        defer { try? FileManager.default.removeItem(at: url) }
        let image = try XCTUnwrap(UIImage(contentsOfFile: url.path)?.cgImage)
        XCTAssertEqual(image.width, 2000)
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        pixels.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        XCTAssertGreaterThan(pixels[0], 250)
        var dark = 0
        for index in stride(from: 0, to: pixels.count-4, by: 124) {
            let channels = pixels[index...index+2]
            XCTAssertLessThanOrEqual(Int(channels.max()!)-Int(channels.min()!), 3)
            if pixels[index] < 128 { dark += 1 }
        }
        XCTAssertGreaterThan(dark, 100)
        let attachment = XCTAttachment(contentsOfFile: url); attachment.name = "Black and white print JPEG"; attachment.lifetime = .keepAlways; add(attachment)
    }
}


extension GraphTests {
    @MainActor func testX3ExportPaperSizesResolutionAndLegend() throws {
        let equations = [GraphEquation(expression: "y=C*x"), GraphEquation(expression: "C=[1u,10u,30u,60u]")]
        let window = try GraphWindow.bounds(xMin: 0, xMax: 10, yMin: 0, yMax: 0.0006)
        let curves = GraphSampler.sampleAll(equations, window: window, constants: [:])
        for (millimeters, pixels) in [(80,945), (50,591)] {
            let url = try GraphJPEGExport.write(equations: equations, window: window, curves: curves, constants: [], x3PaperWidth: millimeters)
            defer { try? FileManager.default.removeItem(at: url) }
            let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
            let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
            let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
            XCTAssertEqual(image.width, pixels)
            XCTAssertEqual(properties[kCGImagePropertyDPIWidth] as? Int, 300)
            XCTAssertEqual(image.colorSpace?.model, .monochrome)
            XCTAssertEqual(GraphLegendEntry.entries(equations: equations, curves: curves, monochrome: true).count, 4)
            let attachment = XCTAttachment(contentsOfFile: url); attachment.name = "X3 \(millimeters) mm JPEG"; attachment.lifetime = .keepAlways; add(attachment)
        }
        XCTAssertThrowsError(try GraphJPEGExport.write(equations: equations, window: window, curves: curves, constants: [], x3PaperWidth: 999))
    }
}
