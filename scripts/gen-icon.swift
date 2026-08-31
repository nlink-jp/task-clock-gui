// Generates assets/AppIcon-1024.png: a dark rounded plate with a clock
// face — light hands at the classic 10:10, and a green arc along the ring
// from 12 o'clock (the task-clock identity: fires that happen on schedule,
// visibly). Run from the project root: swift scripts/gen-icon.swift
import AppKit

let size = 1024

guard let context = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("could not create CGContext")
}

// Dark rounded plate on transparent background (macOS icon grid margins).
let plateRect = CGRect(x: 64, y: 64, width: 896, height: 896)
let plate = CGPath(roundedRect: plateRect, cornerWidth: 200, cornerHeight: 200, transform: nil)
context.addPath(plate)
context.setFillColor(CGColor(red: 0.11, green: 0.12, blue: 0.15, alpha: 1))
context.fillPath()

let center = CGPoint(x: 512, y: 512)
let ringRadius: CGFloat = 320
let faceColor = CGColor(red: 0.90, green: 0.92, blue: 0.95, alpha: 1)
let accentColor = CGColor(red: 0.24, green: 0.78, blue: 0.35, alpha: 1)

// Clock ring.
context.setStrokeColor(faceColor)
context.setLineWidth(52)
context.addArc(center: center, radius: ringRadius, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
context.strokePath()

// Green arc along the ring: from 12 o'clock, 60 degrees clockwise — the
// stretch of schedule already covered, on time.
context.setStrokeColor(accentColor)
context.setLineWidth(52)
context.setLineCap(.round)
context.addArc(center: center, radius: ringRadius,
               startAngle: .pi / 2, endAngle: .pi / 6, clockwise: true)
context.strokePath()

// Hour ticks at 12 / 3 / 6 / 9.
context.setStrokeColor(faceColor)
context.setLineCap(.round)
context.setLineWidth(30)
for i in 0..<4 {
    let angle = CGFloat(i) * .pi / 2
    let outer = CGPoint(x: center.x + cos(angle) * (ringRadius - 60),
                        y: center.y + sin(angle) * (ringRadius - 60))
    let inner = CGPoint(x: center.x + cos(angle) * (ringRadius - 130),
                        y: center.y + sin(angle) * (ringRadius - 130))
    context.move(to: outer)
    context.addLine(to: inner)
    context.strokePath()
}

// Hands at the classic 10:10 (clockwise angle from 12 o'clock).
func handPoint(clockwiseFromTop degrees: CGFloat, length: CGFloat) -> CGPoint {
    let rad = degrees * .pi / 180
    return CGPoint(x: center.x + sin(rad) * length,
                   y: center.y + cos(rad) * length)
}
context.setLineCap(.round)

// Hour hand: ~10 o'clock.
context.setLineWidth(64)
context.move(to: center)
context.addLine(to: handPoint(clockwiseFromTop: 305, length: 160))
context.strokePath()

// Minute hand: 10 minutes, reaching into the green arc.
context.setLineWidth(56)
context.move(to: center)
context.addLine(to: handPoint(clockwiseFromTop: 60, length: 235))
context.strokePath()

// Center hub.
context.setFillColor(faceColor)
context.addArc(center: center, radius: 42, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
context.fillPath()

guard let image = context.makeImage() else {
    fatalError("could not render image")
}
let rep = NSBitmapImageRep(cgImage: image)
guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("could not encode PNG")
}
let outputURL = URL(fileURLWithPath: "assets/AppIcon-1024.png")
try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try png.write(to: outputURL)
print("wrote \(outputURL.path)")
