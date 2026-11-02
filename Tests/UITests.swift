import XCTest
final class UITests: XCTestCase {
    func testFractionEntryAndResult() {
        let app = XCUIApplication(); app.launch()
        let editor = app.textViews["expressionEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        editor.tap(); editor.typeText("1/2 + 1/3\n")
        let copy = app.buttons["copyResult"]
        XCTAssertTrue(copy.waitForExistence(timeout: 10))
        let value = copy.value as? String ?? ""
        XCTAssertTrue(value.contains("5") && value.contains("6"), value)
        let renderedExpression = app.webViews.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Expression")).firstMatch
        XCTAssertTrue(renderedExpression.waitForExistence(timeout: 40))
        XCTAssertTrue(renderedExpression.isHittable)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); attachment.lifetime = .keepAlways; add(attachment)
    }
    func testLandscapeControlsRemainReachable() {
        let app = XCUIApplication(); app.launch()
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        XCTAssertTrue(app.buttons["key_="].isHittable)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); attachment.lifetime = .keepAlways; add(attachment)
    }
}

extension UITests {
    func testCASMatrixAndIntegral() {
        let app = XCUIApplication(); app.launch()
        app.buttons["calculationMode"].tap()
        app.buttons["CAS"].tap()
        let editor = app.textViews["expressionEditor"]
        editor.tap(); editor.typeText("invert(matrix([1,2],[3,4]))\n")
        let copy = app.buttons["copyResult"]
        let matrix = NSPredicate(format: "value CONTAINS %@", "matrix([-2, 1]")
        expectation(for: matrix, evaluatedWith: copy)
        waitForExpectations(timeout: 15)
        let rendered = app.webViews.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Expression")).firstMatch
        XCTAssertTrue(rendered.waitForExistence(timeout: 10))
        // Accessibility can appear before WebKit's first composited frame.
        XCTAssertTrue(rendered.isHittable)
        Thread.sleep(forTimeInterval: 2)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); screenshot.name = "CAS matrix"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.buttons["key_AC"].tap()
        editor.tap(); editor.typeText("integrate(x^2,x,0,1)\n")
        expectation(for: NSPredicate(format: "value == %@", "1/3"), evaluatedWith: copy)
        waitForExpectations(timeout: 15)
        let integral = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); integral.name = "CAS integral"; integral.lifetime = .keepAlways; add(integral)
        app.buttons["calculationMode"].tap()
        app.buttons["Calculator"].tap()
    }
}

extension UITests {
    func testMatrixEntryGrid() {
        let app = XCUIApplication(); app.launch()
        app.buttons["Examples"].tap()
        app.buttons["Insert a matrix…"].tap()
        XCTAssertTrue(app.textFields["Row 1, column 1"].waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Matrix editor"; attachment.lifetime = .keepAlways; add(attachment)
        app.buttons["insertMatrix"].tap()
        app.buttons["key_="].tap()
        expectation(for: NSPredicate(format: "value == %@", "matrix([0, 0], [0, 0])"), evaluatedWith: app.buttons["copyResult"])
        waitForExpectations(timeout: 15)
        app.buttons["calculationMode"].tap()
        app.buttons["Calculator"].tap()
    }
}

extension UITests {
    func testImproperIntegral() {
        let app = XCUIApplication(); app.launch()
        app.buttons["calculationMode"].tap()
        app.buttons["CAS"].tap()
        let editor = app.textViews["expressionEditor"]
        editor.tap(); editor.typeText("integrate(exp(-x),x,0,Infinity)\n")
        expectation(for: NSPredicate(format: "value == %@", "1"), evaluatedWith: app.buttons["copyResult"])
        waitForExpectations(timeout: 15)
        let rendered = app.webViews.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Expression")).firstMatch
        XCTAssertTrue(rendered.waitForExistence(timeout: 10))
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Improper integral"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.buttons["calculationNotes"].tap()
        XCTAssertTrue(app.alerts["Calculation notes"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.alerts.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "one-sided endpoint limits")).firstMatch.exists)
        app.alerts.buttons["Done"].tap()
        app.buttons["calculationMode"].tap()
        app.buttons["Calculator"].tap()
    }
}

extension UITests {
    func testEngineeringNotationOptions() {
        let app = XCUIApplication(); app.launch()
        app.buttons["calculationMode"].tap()
        app.buttons["Calculator"].tap()
        let format = app.buttons["resultNotation"]
        XCTAssertTrue(format.waitForExistence(timeout: 5))
        format.tap(); app.buttons["Engineering"].tap()
        let editor = app.textViews["expressionEditor"]
        editor.tap(); editor.typeText("4700\n")
        expectation(for: NSPredicate(format: "value == %@", "4700"), evaluatedWith: app.buttons["copyResult"])
        waitForExpectations(timeout: 10)
        XCTAssertTrue(app.webViews["formattedEquation"].label.contains("4.7 × 10^3"))
        format.tap(); app.buttons["Engineering (SI symbols)"].tap()
        app.buttons["key_="].tap()
        expectation(for: NSPredicate(format: "label CONTAINS %@", "4.7 k"), evaluatedWith: app.webViews["formattedEquation"])
        waitForExpectations(timeout: 10)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Symbolic engineering"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.buttons["key_AC"].tap()
        editor.tap(); editor.typeText("0.0000022\n")
        expectation(for: NSPredicate(format: "label CONTAINS %@", "2.2 µ"), evaluatedWith: app.webViews["formattedEquation"])
        waitForExpectations(timeout: 10)
        let micro = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        micro.name = "Micro engineering"; micro.lifetime = .keepAlways; add(micro)
        format.tap(); app.buttons["Exact"].tap()
    }
}

extension UITests {
    func testExponentEntryAndUpperRightDelete() {
        let app = XCUIApplication(); app.launch()
        app.buttons["calculationMode"].tap()
        app.buttons["Calculator"].tap()
        app.buttons["resultNotation"].tap(); app.buttons["Exact"].tap()
        app.buttons["key_AC"].tap()
        let delete = app.buttons["key_⌫"]
        XCTAssertEqual(delete.frame.minY, app.buttons["key_sin"].frame.minY, accuracy: 1)
        XCTAssertGreaterThan(delete.frame.minX, app.buttons["key_AC"].frame.minX)
        let exponent = app.buttons["key_EE"]
        XCTAssertEqual(exponent.frame.minY, app.buttons["key_9"].frame.minY, accuracy: 1)
        XCTAssertEqual(exponent.frame.width, app.buttons["key_0"].frame.width, accuracy: 1)
        XCTAssertGreaterThan(exponent.frame.minX, app.buttons["key_9"].frame.minX)
        XCTAssertEqual(app.buttons["key_÷"].frame.minX, app.buttons["key_×"].frame.minX, accuracy: 1)
        XCTAssertEqual(app.buttons["key_×"].frame.minX, app.buttons["key_−"].frame.minX, accuracy: 1)
        XCTAssertEqual(app.buttons["key_to"].label, "Convert units")
        for key in ["4", ".", "7", "EE", "3", "="] { app.buttons["key_" + key].tap() }
        expectation(for: NSPredicate(format: "value == %@", "4700"), evaluatedWith: app.buttons["copyResult"])
        waitForExpectations(timeout: 10)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Accessible EE and delete"; screenshot.lifetime = .keepAlways; add(screenshot)
        delete.tap()
        XCTAssertEqual(app.textViews["expressionEditor"].value as? String, "4.7e")
        app.buttons["key_AC"].tap()
        for key in ["2", "EE", "−", "3", "="] { app.buttons["key_" + key].tap() }
        expectation(for: NSPredicate(format: "value == %@", "1/500"), evaluatedWith: app.buttons["copyResult"])
        waitForExpectations(timeout: 10)
    }
}


extension UITests {
    func testCalculationSurvivesWindowShapeChanges() {
        let app = XCUIApplication(); app.launch()
        defer { XCUIDevice.shared.orientation = .portrait }
        app.buttons["calculationMode"].tap()
        app.buttons["Calculator"].tap()
        let editor = app.textViews["expressionEditor"]
        app.buttons["key_AC"].tap()
        for key in ["7", "+", "8", "="] { app.buttons["key_" + key].tap() }
        let copy = app.buttons["copyResult"]
        expectation(for: NSPredicate(format: "value == %@", "15"), evaluatedWith: copy)
        waitForExpectations(timeout: 10)
        for orientation: UIDeviceOrientation in [.landscapeLeft, .portrait] {
            XCUIDevice.shared.orientation = orientation
            XCTAssertEqual(editor.value as? String, "7+8")
            XCTAssertEqual(copy.value as? String, "15")
            XCTAssertTrue(app.buttons["key_EE"].isHittable)
            XCTAssertTrue(app.buttons["key_="].isHittable)
        }
    }
}


extension UITests {
    func testWideKeypadFitsWithoutScrolling() throws {
        let app = XCUIApplication(); app.launch()
        let window = app.windows.firstMatch
        guard window.frame.width >= 700 else { throw XCTSkip("Run with Duo unfolded or a wide window") }
        let editor = app.textViews["expressionEditor"]
        let equals = app.buttons["key_="]
        XCTAssertGreaterThan(equals.frame.minX, editor.frame.maxX)
        for key in ["sin", "cos", "tan", "AC", "⌫", "ln", "√", "^", "(", ")", "7", "8", "9", "EE", "÷", "4", "5", "6", "π", "×", "1", "2", "3", "Ans", "−", "0", ".", "+", "="] {
            let button = app.buttons["key_" + key]
            XCTAssertTrue(button.isHittable, key)
            XCTAssertTrue(window.frame.contains(button.frame), key)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44, key)
        }
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "Duo full keypad without scrolling"; shot.lifetime = .keepAlways; add(shot)
    }
}

extension UITests {
    func testUnitConverterMode() {
        let app = XCUIApplication(); app.launch()
        app.buttons["calculationMode"].tap()
        app.buttons["Unit converter"].tap()
        XCTAssertEqual(app.scrollViews.count, 0)
        for identifier in ["conversionCategory", "fromUnit", "toUnit", "swapUnits", "copyConversion", "convertKey_0", "convertKey_Copy"] {
            let control = app.buttons[identifier]
            XCTAssertTrue(control.isHittable, identifier)
            XCTAssertTrue(app.windows.firstMatch.frame.contains(control.frame), identifier)
        }
        app.buttons["convertKey_5"].tap()
        XCTAssertEqual(app.staticTexts["conversionResult"].label, "500")
        app.buttons["swapUnits"].tap()
        XCTAssertEqual(app.staticTexts["conversionResult"].label, "0.05")
        XCTAssertTrue(app.buttons["convertKey_EE"].isHittable)
        app.buttons["convertKey_AC"].tap()
        XCTAssertEqual(app.staticTexts["conversionResult"].label, "0")
        for key in ["5", "EE", "±", "3"] { app.buttons["convertKey_" + key].tap() }
        XCTAssertEqual(app.staticTexts["conversionInput"].label, "5e-3")
    }
}

extension UITests {
    func testProgrammerModeAndToolbar() {
        let app = XCUIApplication(); app.launch()
        let mode = app.buttons["calculationMode"].firstMatch
        XCTAssertTrue(mode.waitForExistence(timeout: 10))
        mode.tap(); app.buttons["Programmer"].tap()
        app.buttons["base_16"].tap()
        app.buttons["programKey_F"].tap(); app.buttons["programKey_F"].tap()
        XCTAssertEqual(app.buttons["base_10"].value as? String, "255")
        app.buttons["programKey_Bits"].tap(); app.buttons["programKey_AND"].tap(); app.buttons["programKey_F"].tap()
        app.buttons["programKey_="].tap()
        XCTAssertEqual(app.buttons["base_10"].value as? String, "15")
        app.buttons["base_2"].tap()
        XCTAssertFalse(app.buttons["programKey_2"].isEnabled)
        for id in ["wordSize", "base_16", "base_2", "programKey_0", "programKey_+", "programKey_="] {
            let button = app.buttons[id]
            XCTAssertTrue(button.isHittable, id)
            XCTAssertTrue(app.windows.firstMatch.frame.contains(button.frame), id)
        }
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.lifetime = .keepAlways; add(shot)
    }
}

extension UITests {
    func testHistoryCanDismissAfterLayoutChange() {
        let app = XCUIApplication(); app.launch()
        defer { XCUIDevice.shared.orientation = .portrait }
        for orientation: UIDeviceOrientation in [.landscapeLeft, .portrait] {
            app.buttons["History"].tap()
            XCUIDevice.shared.orientation = orientation
            let done = app.buttons["Done"]
            XCTAssertTrue(done.waitForExistence(timeout: 5))
            XCTAssertTrue(done.isHittable)
            done.tap()
            XCTAssertTrue(app.buttons["key_="].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["key_="].isHittable)
            XCTAssertTrue(app.buttons["key_EE"].isHittable)
        }
    }
}

extension UITests {
    func testQuickCalcAndPasteWithoutKeyboard() {
        let app = XCUIApplication(); app.launch()
        app.buttons["key_AC"].tap()
        for key in ["2", "+", "3", "="] { app.buttons["key_" + key].tap() }
        let copy = app.buttons["copyResult"]
        expectation(for: NSPredicate(format: "value == %@", "5"), evaluatedWith: copy)
        waitForExpectations(timeout: 10)
        copy.tap()
        app.buttons["key_AC"].tap()
        app.textViews["expressionEditor"].tap()
        app.textViews["expressionEditor"].press(forDuration: 1.2)
        let paste = app.menuItems["Paste"].exists ? app.menuItems["Paste"] : app.buttons["Paste"]
        XCTAssertTrue(paste.waitForExistence(timeout: 5))
        paste.tap()
        expectation(for: NSPredicate(format: "value == %@", "5"), evaluatedWith: app.textViews["expressionEditor"])
        waitForExpectations(timeout: 5)
        XCTAssertEqual(app.keyboards.count, 0)
        XCTAssertTrue(app.buttons["key_="].isHittable)
        app.buttons["calculationMode"].tap()
        app.buttons["Quick Calc"].tap()
        app.buttons["Example"].tap()
        XCTAssertEqual(app.textFields["powerInput3"].placeholderValue, "6")
        XCTAssertTrue(app.buttons["quickTabs"].isHittable)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.lifetime = .keepAlways; add(attachment)
    }
}

extension UITests {
    func testCustomQuickTabPersists() {
        let app = XCUIApplication(); app.launch()
        app.buttons["calculationMode"].tap(); app.buttons["Quick Calc"].tap()
        app.buttons["New calculation tab"].tap()
        let name = "Test tab " + String(UUID().uuidString.prefix(6))
        let nameField = app.textFields["tabName"]
        nameField.tap(); nameField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30) + name)
        let formula = app.textFields["tabFormula"]
        formula.tap(); formula.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 10) + "x*3")
        app.buttons["saveQuickTab"].tap()
        XCTAssertTrue(app.staticTexts["quickAnswer"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["quickAnswer"].label.trimmingCharacters(in: .whitespaces), "3")
        app.terminate(); app.launch()
        app.buttons["calculationMode"].tap(); app.buttons["Quick Calc"].tap()
        app.buttons["quickTabs"].tap(); app.buttons[name].tap()
        XCTAssertEqual(app.staticTexts["quickAnswer"].label.trimmingCharacters(in: .whitespaces), "3")
    }
}

extension UITests {
    func testPowerKeypadAndGraphing() {
        let app = XCUIApplication(); app.launch()
        app.buttons["calculationMode"].tap(); app.buttons["Quick Calc"].tap()
        app.buttons["Clear"].tap()
        let voltage = app.textFields["powerInput2"]
        voltage.tap()
        XCTAssertEqual(app.keyboards.count, 0)
        for key in ["1", "2"] { app.buttons["numberPad_" + key].tap() }
        app.textFields["powerInput1"].tap()
        for key in ["0", ".", "5"] { app.buttons["numberPad_" + key].tap() }
        XCTAssertEqual(app.textFields["powerInput3"].placeholderValue, "6")
        XCTAssertTrue(app.buttons["numberPad_Next"].isHittable)
        app.buttons["Tab options"].tap(); app.buttons["Keyboard"].tap()
        app.textFields["powerInput2"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        app.buttons["Tab options"].tap(); app.buttons["Keypad"].tap()
        XCTAssertEqual(app.keyboards.count, 0)
        app.buttons["calculationMode"].tap(); app.buttons["Graphing"].tap()
        let graph = app.otherElements["functionGraph"]
        XCTAssertTrue(graph.waitForExistence(timeout: 5))
        for _ in 0..<12 {
            if app.buttons["Remove function 2"].exists { app.buttons["Remove function 2"].tap() } else { break }
        }
        app.textViews["graphFunction0"].tap(); app.buttons["graphKey_AC"].tap()
        app.buttons["graphKey_Functions"].tap(); app.buttons["sin"].tap()
        for key in ["x", ")", "Plot"] { app.buttons["graphKey_" + key].tap() }
        expectation(for: NSPredicate(format: "value BEGINSWITH %@", "1 curves"), evaluatedWith: graph)
        waitForExpectations(timeout: 10)
        app.buttons["graphReset"].tap()
        graph.tap()
        XCTAssertTrue(app.staticTexts["graphPoint0"].waitForExistence(timeout: 5))
        let before = graph.value as? String
        app.buttons["Zoom in"].tap()
        XCTAssertNotEqual(graph.value as? String, before)
        app.buttons["graphReset"].tap()
        XCTAssertEqual(graph.value as? String, before)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); attachment.lifetime = .keepAlways; add(attachment)
    }
}


extension UITests {
    func testChangingResultFormatRefreshesWithoutEquals() {
        let app = XCUIApplication(); app.launch()
        app.buttons["calculationMode"].tap(); app.buttons["Calculator"].tap()
        let format = app.buttons["resultNotation"]
        format.tap(); app.buttons["Exact"].tap()
        app.buttons["key_AC"].tap()
        for key in ["4", "7", "0", "0", "0", "="] { app.buttons["key_" + key].tap() }
        expectation(for: NSPredicate(format: "value == %@", "47000"), evaluatedWith: app.buttons["copyResult"])
        waitForExpectations(timeout: 10)
        let rendered = app.webViews["formattedEquation"]
        for (name, text) in [("Scientific", "4.7 × 10^4"), ("Engineering", "47 × 10^3"), ("Engineering (SI symbols)", "47 k"), ("Decimal", "47000")] {
            format.tap(); app.buttons[name].tap()
            expectation(for: NSPredicate(format: "label ENDSWITH %@", "equals " + text), evaluatedWith: rendered)
            waitForExpectations(timeout: 10)
            if name == "Engineering (SI symbols)" {
                let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                attachment.name = "Live format change"; attachment.lifetime = .keepAlways; add(attachment)
            }
        }
    }
}

extension UITests {
    func testGraphAxesSliderAndModifiedKeypad() {
        let app = XCUIApplication(); app.launch()
        app.buttons["calculationMode"].tap(); app.buttons["Graphing"].tap()
        app.buttons["graphAxes"].tap()
        for (index, value) in ["-5", "5", "-5", "5"].enumerated() {
            let field = app.textFields["graphAxis\(index)"]
            field.tap(); field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 20) + value)
        }
        let liveAxes = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); liveAxes.name = "Live axes popup"; liveAxes.lifetime = .keepAlways; add(liveAxes)
        app.buttons["applyGraphAxes"].tap()
        let graph = app.otherElements["functionGraph"]
        XCTAssertTrue(graph.waitForExistence(timeout: 5))
        XCTAssertTrue((graph.value as? String ?? "").contains("x from -5.0 to 5.0; y from -5.0 to 5.0"), graph.value as? String ?? "missing ranges")
        if app.buttons["Remove slider a"].exists { app.buttons["Remove slider a"].tap() }
        let field = app.textViews["graphFunction0"]
        field.tap()
        XCTAssertEqual(app.keyboards.count, 0)
        app.buttons["graphKey_AC"].tap()
        app.buttons["graphKey_Vars"].tap(); app.buttons["a"].tap()
        let startKey = app.buttons["graphKey_sin"], endKey = app.buttons["graphKey_Plot"]
        let bounds = app.windows.firstMatch.frame
        if bounds.width < 620 { XCTAssertGreaterThan(endKey.frame.maxY-startKey.frame.minY, bounds.height*0.38) }
        else { XCTAssertGreaterThan(endKey.frame.maxX-startKey.frame.minX, bounds.width*0.38) }
        let keypadShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); keypadShot.name = "Half-screen graph keypad"; keypadShot.lifetime = .keepAlways; add(keypadShot)
        for key in ["×", "x", "Plot"] { app.buttons["graphKey_" + key].tap() }
        XCTAssertEqual(field.value as? String, "a*x")
        XCTAssertTrue(app.sliders["graphSlider_a"].waitForExistence(timeout: 5))
        expectation(for: NSPredicate(format: "value BEGINSWITH %@", "1 curves"), evaluatedWith: graph)
        waitForExpectations(timeout: 10)
        graph.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5)).tap()
        let point = app.staticTexts["graphPoint0"]
        XCTAssertTrue(point.waitForExistence(timeout: 5))
        let before = point.label
        let inspectedX = Double(before.dropFirst().split(separator: ",")[0]) ?? .nan
        XCTAssertEqual(inspectedX, 2.5, accuracy: 0.05)
        app.sliders["graphSlider_a"].adjust(toNormalizedSliderPosition: 0.8)
        XCTAssertNotEqual(point.label, before)
        app.terminate(); app.launch()
        app.buttons["calculationMode"].tap(); app.buttons["Graphing"].tap()
        XCTAssertTrue(app.sliders["graphSlider_a"].waitForExistence(timeout: 5))
        XCTAssertTrue((app.otherElements["functionGraph"].value as? String ?? "").contains("x from -5.0 to 5.0"))
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); screenshot.lifetime = .keepAlways; add(screenshot)
    }
}

extension UITests {
    func testGraphEqualsDefinitionsAndListCurves() {
        let app = XCUIApplication(); app.launch()
        app.buttons["calculationMode"].tap(); app.buttons["Graphing"].tap()
        for _ in 0..<12 {
            if app.buttons["Remove function 2"].exists { app.buttons["Remove function 2"].tap() }
            else { break }
        }
        let helper = app.textViews["graphFunction0"]
        helper.tap(); app.buttons["graphKey_AC"].tap()
        app.buttons["graphKey_Vars"].tap(); app.buttons["M"].tap()
        for key in ["=", "2", "Plot"] { app.buttons["graphKey_" + key].tap() }
        XCTAssertEqual(helper.value as? String, "M=2")
        app.buttons["Add graph function"].tap()
        let output = app.textViews["graphFunction1"]
        output.tap(); app.buttons["graphKey_AC"].tap()
        app.buttons["graphKey_Vars"].tap(); app.buttons["M"].tap()
        for key in ["×", "x", "Plot"] { app.buttons["graphKey_" + key].tap() }
        let graph = app.otherElements["functionGraph"]
        expectation(for: NSPredicate(format: "value BEGINSWITH %@", "1 curves"), evaluatedWith: graph)
        waitForExpectations(timeout: 10)
        helper.tap(); app.buttons["graphKey_AC"].tap()
        app.buttons["Use graph keyboard"].tap()
        helper.typeText("M=[1u,10u,30u,60u]\n")
        expectation(for: NSPredicate(format: "value BEGINSWITH %@", "4 curves"), evaluatedWith: graph)
        waitForExpectations(timeout: 10)
        XCTAssertFalse(app.sliders["graphSlider_M"].exists)
        app.buttons["graphAxes"].tap()
        for (index, value) in [(2, "-0.001"), (3, "0.001")] {
            let field = app.textFields["graphAxis\(index)"]
            field.tap(); field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 20)+value)
        }
        app.buttons["applyGraphAxes"].tap()
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = "Four engineering-value curves"; shot.lifetime = .keepAlways; add(shot)
        app.terminate(); app.launch()
        app.buttons["calculationMode"].tap(); app.buttons["Graphing"].tap()
        expectation(for: NSPredicate(format: "value BEGINSWITH %@", "4 curves"), evaluatedWith: app.otherElements["functionGraph"])
        waitForExpectations(timeout: 10)
    }
}


extension UITests {
    func testGraphBracketLongPress() {
        let app = XCUIApplication(); app.launch()
        app.buttons["calculationMode"].tap(); app.buttons["Graphing"].tap()
        let expression = app.textViews["graphFunction0"]
        expression.tap(); app.buttons["graphKey_AC"].tap()
        app.buttons["graphKey_("].tap(); app.buttons["graphKey_)"].tap()
        XCTAssertEqual(expression.value as? String, "()")
        app.buttons["graphKey_AC"].tap()
        app.buttons["graphKey_("].press(forDuration: 0.6)
        app.buttons["graphKey_1"].tap()
        app.buttons["graphKey_)"].press(forDuration: 0.6)
        XCTAssertEqual(expression.value as? String, "[1]")
    }
}


extension UITests {
    func testGraphListKeypadAndVariablePicker() {
        let app = XCUIApplication(); app.launch()
        app.buttons["calculationMode"].tap(); app.buttons["Graphing"].tap()
        if !app.textViews["graphFunction0"].waitForExistence(timeout: 5) {
            app.buttons["calculationMode"].tap(); app.buttons["Graphing"].tap()
        }
        let expression = app.textViews["graphFunction0"]
        expression.tap(); app.buttons["graphKey_AC"].tap()
        app.buttons["graphKey_Vars"].tap(); app.buttons["C"].tap()
        app.buttons["graphKey_="].tap()
        app.buttons["graphKey_("].press(forDuration: 0.6)
        XCTAssertFalse(app.buttons["graphKey_u"].exists)
        for key in ["1", "EE", "−", "6", ",", "1", "0", "EE", "−", "6"] { app.buttons["graphKey_" + key].tap() }
        app.buttons["graphKey_)"].press(forDuration: 0.6)
        XCTAssertEqual(expression.value as? String, "C=[1e-6,10e-6]")
        app.buttons["graphKey_Vars"].tap()
        XCTAssertTrue(app.buttons["C"].exists)
        XCTAssertEqual(app.buttons["C"].value as? String, "= [1e-6,10e-6]")
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = "Graph variable picker"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["Letters"].tap(); app.buttons["ABC"].tap()
        app.buttons["R"].tap()
        XCTAssertEqual(expression.value as? String, "C=[1e-6,10e-6]R")
        app.buttons["graphKey_AC"].tap()
        app.buttons["graphKey_Functions"].tap(); app.buttons["sin"].tap()
        for key in ["x", ")"] { app.buttons["graphKey_" + key].tap() }
        XCTAssertEqual(expression.value as? String, "sin(x)")
        let keypad = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); keypad.name = "Refined graph keypad"; keypad.lifetime = .keepAlways; add(keypad)
    }
}


extension UITests {
    func testGraphJPEGShareAndLegend() {
        let app = XCUIApplication(); app.launch()
        if app.buttons["header.closeButton"].exists { app.buttons["header.closeButton"].tap() }
        app.buttons["calculationMode"].tap(); app.buttons["Graphing"].tap()
        if !app.textViews["graphFunction0"].waitForExistence(timeout: 5) {
            app.buttons["calculationMode"].tap(); app.buttons["Graphing"].tap()
        }
        let first = app.textViews["graphFunction0"]
        if first.value as? String != "y=C*x" {
            first.tap(); app.buttons["graphKey_AC"].tap(); app.buttons["Use graph keyboard"].tap()
            first.typeText("y=C*x\n")
        }
        if !app.textViews["graphFunction1"].exists { app.buttons["Add graph function"].tap() }
        let second = app.textViews["graphFunction1"]
        if second.value as? String != "C=[1u,10u,30u,60u]" {
            second.tap(); app.buttons["graphKey_AC"].tap(); app.buttons["Use graph keyboard"].tap()
            second.typeText("C=[1u,10u,30u,60u]\n")
        }
        app.buttons["graphAxes"].tap()
        for (index, value) in [(0, "0"), (1, "10"), (2, "0"), (3, "0.0006")] {
            let field = app.textFields["graphAxis\(index)"]
            field.tap(); field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 20)+value)
        }
        app.buttons["applyGraphAxes"].tap()
        let legend = app.scrollViews["graphLegend"]
        XCTAssertTrue(legend.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["C=60 µ"].exists)
        let plot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); plot.name = "On-plot sweep legend"; plot.lifetime = .keepAlways; add(plot)
        let export = app.buttons["exportGraphJPEG"]
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: export)
        waitForExpectations(timeout: 5)
        export.tap()
        let file = app.otherElements.matching(NSPredicate(format: "label CONTAINS %@", "Clockwork-Calc-Plot-")).firstMatch
        XCTAssertTrue(file.waitForExistence(timeout: 10))
        XCTAssertTrue(app.cells["Save to Files"].exists)
        XCTAssertTrue(app.otherElements.matching(NSPredicate(format: "label BEGINSWITH %@", "JPEG Image")).firstMatch.exists)
        let share = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); share.name = "JPEG share sheet"; share.lifetime = .keepAlways; add(share)
        app.buttons["header.closeButton"].tap()
        XCTAssertTrue(app.buttons["exportGraphJPEG"].waitForExistence(timeout: 5))
    }
}
