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
