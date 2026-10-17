// render-icon.swift: renders the app icon (steam clouds rising over a roller) as PNGs for an .iconset.
// Usage: swift render-icon.swift <output-dir>
import AppKit

func draw(size: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { return img }
    let s = size
    // macOS-style squircle background with vertical gradient (Steam-like dark blue)
    let inset = s * 0.05
    let rect = CGRect(x: inset, y: inset, width: s - 2*inset, height: s - 2*inset)
    let bg = NSBezierPath(roundedRect: rect, xRadius: s*0.22, yRadius: s*0.22)
    let gradient = NSGradient(colors: [NSColor(red: 0.16, green: 0.30, blue: 0.42, alpha: 1),
                                       NSColor(red: 0.07, green: 0.12, blue: 0.20, alpha: 1)])!
    gradient.draw(in: bg, angle: -90)
    // subtle inner highlight at the top
    ctx.saveGState(); bg.addClip()
    let hl = NSGradient(colors: [NSColor.white.withAlphaComponent(0.14), NSColor.white.withAlphaComponent(0.0)])!
    hl.draw(in: CGRect(x: inset, y: s*0.55, width: s - 2*inset, height: s*0.40), angle: 90)
    ctx.restoreGState()

    // roller: horizontal cylinder (rounded pill) in the lower third
    let rollerH = s * 0.20, rollerW = s * 0.62
    let roller = CGRect(x: (s - rollerW)/2, y: s*0.17, width: rollerW, height: rollerH)
    let rollerPath = NSBezierPath(roundedRect: roller, xRadius: rollerH/2, yRadius: rollerH/2)
    let rg = NSGradient(colors: [NSColor(white: 0.97, alpha: 1), NSColor(white: 0.72, alpha: 1)])!
    rg.draw(in: rollerPath, angle: -90)
    // roller axle hubs
    for cx in [roller.minX + rollerH*0.55, roller.maxX - rollerH*0.55] {
        let hub = NSBezierPath(ovalIn: CGRect(x: cx - rollerH*0.17, y: roller.midY - rollerH*0.17, width: rollerH*0.34, height: rollerH*0.34))
        NSColor(red: 0.07, green: 0.12, blue: 0.20, alpha: 0.85).setFill(); hub.fill()
    }
    // steam: three S-curves with round caps, rising from the roller
    NSColor.white.withAlphaComponent(0.92).setStroke()
    let xs: [CGFloat] = [0.36, 0.50, 0.64]
    for (i, fx) in xs.enumerated() {
        let p = NSBezierPath()
        p.lineWidth = s * 0.075; p.lineCapStyle = .round; p.lineJoinStyle = .round
        let x = s * fx, y0 = s * 0.42, h = s * (i == 1 ? 0.40 : 0.32)
        p.move(to: CGPoint(x: x, y: y0))
        p.curve(to: CGPoint(x: x, y: y0 + h),
                controlPoint1: CGPoint(x: x + s*0.12, y: y0 + h*0.33),
                controlPoint2: CGPoint(x: x - s*0.12, y: y0 + h*0.66))
        p.stroke()
    }
    img.unlockFocus()
    return img
}

func writePNG(_ img: NSImage, size: Int, to url: URL) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    img.draw(in: NSRect(x: 0, y: 0, width: size, height: size), from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
let master = draw(size: 1024)
for (name, px) in [("icon_16x16",16),("icon_16x16@2x",32),("icon_32x32",32),("icon_32x32@2x",64),
                   ("icon_128x128",128),("icon_128x128@2x",256),("icon_256x256",256),("icon_256x256@2x",512),
                   ("icon_512x512",512),("icon_512x512@2x",1024)] {
    writePNG(master, size: px, to: out.appendingPathComponent(name + ".png"))
}
print("iconset written to \(out.path)")
