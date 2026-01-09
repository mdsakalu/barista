import AppKit

let outputPath = CommandLine.arguments.dropFirst().first ?? "dist/icon-1024.png"
let size: CGFloat = 1024

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let context = NSGraphicsContext.current?.cgContext
context?.setAllowsAntialiasing(true)
context?.setShouldAntialias(true)

let canvas = NSRect(x: 0, y: 0, width: size, height: size)
let bgGradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.98, green: 0.93, blue: 0.85, alpha: 1.0),
    NSColor(calibratedRed: 0.95, green: 0.86, blue: 0.72, alpha: 1.0)
])
bgGradient?.draw(in: canvas, angle: 90)

let panelRect = NSRect(x: 80, y: 80, width: 864, height: 864)
let panelPath = NSBezierPath(roundedRect: panelRect, xRadius: 200, yRadius: 200)
NSColor(calibratedRed: 0.92, green: 0.82, blue: 0.68, alpha: 1.0).setFill()
panelPath.fill()

NSGraphicsContext.current?.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
shadow.shadowBlurRadius = 24
shadow.shadowOffset = NSSize(width: 0, height: -8)
shadow.set()

let cupRect = NSRect(x: 260, y: 320, width: 500, height: 360)
let cupPath = NSBezierPath(roundedRect: cupRect, xRadius: 80, yRadius: 80)
NSColor(calibratedRed: 0.98, green: 0.97, blue: 0.95, alpha: 1.0).setFill()
cupPath.fill()

NSGraphicsContext.current?.restoreGraphicsState()

let rimRect = NSRect(x: 260, y: 600, width: 500, height: 110)
let rimPath = NSBezierPath(roundedRect: rimRect, xRadius: 55, yRadius: 55)
NSColor(calibratedRed: 0.93, green: 0.91, blue: 0.88, alpha: 1.0).setFill()
rimPath.fill()

let coffeeRect = NSRect(x: 280, y: 615, width: 460, height: 80)
let coffeePath = NSBezierPath(roundedRect: coffeeRect, xRadius: 40, yRadius: 40)
NSColor(calibratedRed: 0.36, green: 0.22, blue: 0.12, alpha: 1.0).setFill()
coffeePath.fill()

let handleOuter = NSBezierPath(ovalIn: NSRect(x: 700, y: 395, width: 190, height: 210))
let handleInner = NSBezierPath(ovalIn: NSRect(x: 735, y: 430, width: 120, height: 140))
handleOuter.append(handleInner)
handleOuter.windingRule = .evenOdd
NSColor(calibratedRed: 0.98, green: 0.97, blue: 0.95, alpha: 1.0).setFill()
handleOuter.fill()

let saucerRect = NSRect(x: 220, y: 260, width: 584, height: 110)
let saucerPath = NSBezierPath(roundedRect: saucerRect, xRadius: 55, yRadius: 55)
NSColor(calibratedRed: 0.90, green: 0.86, blue: 0.82, alpha: 1.0).setFill()
saucerPath.fill()

let steamColor = NSColor(calibratedWhite: 1.0, alpha: 0.5)
steamColor.setStroke()

func drawSteam(x: CGFloat) {
    let path = NSBezierPath()
    path.lineWidth = 14
    path.lineCapStyle = .round
    path.move(to: NSPoint(x: x, y: 720))
    path.curve(to: NSPoint(x: x + 20, y: 880),
              controlPoint1: NSPoint(x: x - 30, y: 780),
              controlPoint2: NSPoint(x: x + 50, y: 820))
    path.stroke()
}

drawSteam(x: 380)
drawSteam(x: 500)
drawSteam(x: 620)

image.unlockFocus()

if let tiff = image.tiffRepresentation,
   let rep = NSBitmapImageRep(data: tiff),
   let png = rep.representation(using: .png, properties: [:]) {
    try png.write(to: URL(fileURLWithPath: outputPath))
} else {
    fputs("Failed to create PNG\n", stderr)
    exit(1)
}
