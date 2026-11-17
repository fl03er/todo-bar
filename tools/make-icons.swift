// Makes the app's icons from assets/character.png (the character artwork).
//   swift tools/make-icons.swift <outdir>
// Writes StatusIcon.png (the character without its sky, for the menu bar), Character.png and AppIcon.icns.
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/icons")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

guard let src = NSImage(contentsOfFile: "assets/character.png"),
      let cg = src.cgImage(forProposedRect: nil, context: nil, hints: nil) else { fatalError("assets/character.png missing") }
let rep = NSBitmapImageRep(cgImage: cg)

// The artwork sits on a white background with a soft shadow: find the blue rounded square by its colour.
var minX = rep.pixelsWide, minY = rep.pixelsHigh, maxX = 0, maxY = 0
for y in stride(from: 0, to: rep.pixelsHigh, by: 2) {
    for x in stride(from: 0, to: rep.pixelsWide, by: 2) {
        guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
        if c.blueComponent - c.redComponent > 0.25 {
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        }
    }
}
let side = min(maxX - minX, maxY - minY)
let crop = cg.cropping(to: CGRect(x: minX, y: minY, width: side, height: side))!

func render(_ size: Int, _ draw: (CGContext, CGFloat) -> Void) -> NSBitmapImageRep {
    let r = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                             samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                             bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: r)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.interpolationQuality = .high
    draw(ctx, CGFloat(size))
    NSGraphicsContext.restoreGraphicsState()
    return r
}
func save(_ r: NSBitmapImageRep, _ name: String) {
    try! r.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent(name))
}

// Character only: drop the "sky" above the body. For each column, everything above the body's white rim
// becomes transparent; the bottom corners follow the rounded square.
let cropRep = NSBitmapImageRep(cgImage: crop)
var rim = [Int](repeating: side, count: side)
for x in 0..<side {
    var sky = false // the white page shows above the rounded corners: the rim is the first white *below* sky
    for y in 0..<side {
        let c = cropRep.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
        if c.blueComponent - c.redComponent > 0.4 { sky = true }
        else if sky && c.redComponent > 0.8 && c.greenComponent > 0.88 { rim[x] = y; break }
    }
}
let feather = max(2, side / 120)
let bodyCX = 0.55, bodyCY = 0.6, bodyRX = 0.35, bodyRY = 0.3
let top = max(0, (rim.min() ?? 0) - feather)
let maskCtx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side,
                        space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
let buf = maskCtx.data!.assumingMemoryBound(to: UInt8.self)
for x in 0..<side {
    for y in 0..<side { // buffer rows run top to bottom
        let d = y - rim[x] // start just inside the rim so no sky fringe is left
        let a = d <= 0 ? 0.0 : d >= feather * 2 ? 1.0 : Double(d) / Double(feather * 2)
        // Trim the white glow on the sides and bottom: keep an ellipse around the blue body.
        let ex = (Double(x) / Double(side) - bodyCX) / bodyRX, ey = (Double(y) / Double(side) - bodyCY) / bodyRY
        let e = max(0, min(1, (1 - (ex * ex + ey * ey).squareRoot()) / 0.02))
        buf[y * side + x] = UInt8(255 * min(a, e))
    }
}
let mask = maskCtx.makeImage()!
let body = crop.masking(mask)! // white = keep

/// The body cropped to its own bounds (wider than tall), `h` pixels high.
func character(height h: Int) -> NSBitmapImageRep {
    let x0 = CGFloat(bodyCX - bodyRX) * CGFloat(side), x1 = CGFloat(bodyCX + bodyRX) * CGFloat(side)
    let bottom = min(CGFloat(side), CGFloat(bodyCY + bodyRY) * CGFloat(side))
    let bodyH = bottom - CGFloat(top), scale = CGFloat(h) / bodyH
    let w = Int(((x1 - x0) * scale).rounded())
    let r = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8,
                             samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                             bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: r)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.interpolationQuality = .high
    // Place the square so the body's box fills the canvas (image y runs bottom-up).
    let full = CGRect(x: -x0 * scale, y: -(CGFloat(side) - bottom) * scale,
                      width: CGFloat(side) * scale, height: CGFloat(side) * scale)
    ctx.draw(body, in: full)
    NSGraphicsContext.restoreGraphicsState()
    return r
}
save(character(height: 66), "StatusIcon.png")
save(character(height: 400), "Character.png")

// App icon: the rounded square itself, with transparent corners, inside the standard icon margin.
let iconset = out.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let size = base * scale
        let r = render(size) { ctx, s in
            let inner = CGRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8)
            ctx.addPath(CGPath(roundedRect: inner, cornerWidth: s * 0.18, cornerHeight: s * 0.18, transform: nil))
            ctx.clip()
            ctx.draw(crop, in: inner)
        }
        save(r, "AppIcon.iconset/icon_\(base)x\(base)\(scale == 2 ? "@2x" : "").png")
    }
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", out.appendingPathComponent("AppIcon.icns").path]
try! p.run(); p.waitUntilExit()
print("icons in \(out.path) (square \(side)px at \(minX),\(minY))")
