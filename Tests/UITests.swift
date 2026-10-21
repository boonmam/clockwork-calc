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
        let scroll = app.scrollViews["landscapeCalculator"]
        if scroll.waitForExistence(timeout: 3) { scroll.swipeUp() }
        XCTAssertTrue(app.buttons["key_="].isHittable)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); attachment.lifetime = .keepAlways; add(attachment)
    }
}

extension UITests {
    func testCASMatrixAndIntegral() {
        let app = XCUIApplication(); app.launch()
        app.segmentedControls["calculationMode"].buttons["CAS"].tap()
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
        app.segmentedControls["calculationMode"].buttons["Calculator"].tap()
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
        app.segmentedControls["calculationMode"].buttons["Calculator"].tap()
    }
}

extension UITests {
    func testImproperIntegral() {
        let app = XCUIApplication(); app.launch()
        app.segmentedControls["calculationMode"].buttons["CAS"].tap()
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
        app.segmentedControls["calculationMode"].buttons["Calculator"].tap()
    }
}

extension UITests {
    func testEngineeringNotationOptions() {
        let app = XCUIApplication(); app.launch()
        app.segmentedControls["calculationMode"].buttons["Calculator"].tap()
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
        app.segmentedControls["calculationMode"].buttons["Calculator"].tap()
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
