import AppKit
let size = NSSize(width: 1024, height: 1024)
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let context = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
NSColor(calibratedRed: 0.035, green: 0.12, blue: 0.13, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
let mint = NSColor(calibratedRed: 0.48, green: 0.90, blue: 0.81, alpha: 1)
let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 280, weight: .medium), .foregroundColor: mint]
func center(_ value: String, y: CGFloat) {
    let text = value as NSString; let width = text.size(withAttributes: attributes).width
    text.draw(at: NSPoint(x: (1024-width)/2, y: y), withAttributes: attributes)
}
center("1", y: 520); center("2", y: 150)
mint.setStroke(); let bar = NSBezierPath(); bar.move(to: NSPoint(x: 290, y: 505)); bar.line(to: NSPoint(x: 734, y: 505)); bar.lineWidth = 22; bar.lineCapStyle = .round; bar.stroke()
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
