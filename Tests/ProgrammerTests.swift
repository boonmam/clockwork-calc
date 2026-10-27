import XCTest
@testable import Qalculate

@MainActor final class ProgrammerTests: XCTestCase {
    private func enter(_ digits: String, into model: ProgrammerModel) { for digit in digits { model.digit(String(digit)) } }
    func testBasesAndFullUInt64Precision() {
        let m = ProgrammerModel(); m.setRadix(16)
        enter("FFFFFFFFFFFFFFFF", into: m)
        XCTAssertEqual(m.value, UInt64.max)
        XCTAssertEqual(m.formatted(base: 10), "-1")
        m.signed = false
        XCTAssertEqual(m.formatted(base: 10), "18446744073709551615")
        XCTAssertEqual(m.formatted(base: 2), String(repeating: "1", count: 64))
        m.digit("F"); XCTAssertNotNil(m.error); XCTAssertEqual(m.value, UInt64.max)
    }
    func testWidthWrappingAndBitwise() {
        let m = ProgrammerModel(); m.setWidth(8); enter("255", into: m)
        m.choose("+"); m.digit("1"); m.evaluate(); XCTAssertEqual(m.value, 0)
        m.unary("NOT"); XCTAssertEqual(m.value, 255)
        m.choose("AND"); enter("15", into: m); m.evaluate(); XCTAssertEqual(m.value, 15)
        m.choose("XOR"); enter("255", into: m); m.evaluate(); XCTAssertEqual(m.value, 240)
        m.choose("OR"); m.digit("1"); m.evaluate(); XCTAssertEqual(m.value, 241)
        m.setWidth(16); XCTAssertEqual(m.value, 241)
    }
    func testSignedDivisionAndShifts() {
        let m = ProgrammerModel(); m.setWidth(8); enter("128", into: m)
        m.unary("ASR"); XCTAssertEqual(m.signedValue, -64)
        m.unary(">>"); XCTAssertEqual(m.value, 96)
        m.unary("<<"); XCTAssertEqual(m.value, 192)
        m.choose("÷"); m.digit("2"); m.evaluate(); XCTAssertEqual(m.signedValue, -32)
        m.choose("÷"); m.digit("0"); m.evaluate(); XCTAssertNotNil(m.error)
        m.digit("2"); m.evaluate(); XCTAssertEqual(m.signedValue, -16)
    }
    func testSignedDivisionOverflowAndUnsignedDivision() {
        let m = ProgrammerModel(); m.setRadix(16); enter("8000000000000000", into: m)
        m.choose("÷"); enter("FFFFFFFFFFFFFFFF", into: m); m.evaluate()
        XCTAssertEqual(m.value, 1 << 63)
        m.clear(); m.signed = false; enter("FFFFFFFFFFFFFFFF", into: m)
        m.choose("÷"); m.digit("2"); m.evaluate(); XCTAssertEqual(m.value, UInt64.max / 2)
    }
    func testInvalidDigitsAndTruncation() {
        let m = ProgrammerModel(); m.setRadix(2); m.digit("2"); XCTAssertEqual(m.value, 0)
        m.setRadix(16); enter("1234", into: m); m.setWidth(8); XCTAssertEqual(m.value, 0x34)
        m.backspace(); XCTAssertEqual(m.value, 3)
        m.clear(); XCTAssertNil(m.error); XCTAssertNil(m.operation); XCTAssertEqual(m.value, 0)
    }
}
