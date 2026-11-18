// Makes AppIcon.icns from assets/character.png (the cloud artwork on purple).
//   swift tools/make-icons.swift <outdir>
// The menu bar icon and in-app character are drawn in code (Sources/App/CloudArt.swift).
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/icons")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

guard let src = NSImage(contentsOfFile: "assets/character.png"),
      let cg = src.cgImage(forProposedRect: nil, context: nil, hints: nil) else { fatalError("assets/character.png missing") }
// A centred square, keeping the top (the cloud) and trimming the sides.
let side = min(cg.width, cg.height)
let crop = cg.cropping(to: CGRect(x: (cg.width - side) / 2, y: 0, width: side, height: side))!

let iconset = out.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let size = base * scale
        let r = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                                 samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                 bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: r)
        let ctx = NSGraphicsContext.current!.cgContext
        ctx.interpolationQuality = .high
        let s = CGFloat(size)
        // Rounded square inside the standard icon margin.
        let inner = CGRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8)
        ctx.addPath(CGPath(roundedRect: inner, cornerWidth: s * 0.18, cornerHeight: s * 0.18, transform: nil))
        ctx.clip()
        ctx.draw(crop, in: inner)
        NSGraphicsContext.restoreGraphicsState()
        try! r.representation(using: .png, properties: [:])!
            .write(to: iconset.appendingPathComponent("icon_\(base)x\(base)\(scale == 2 ? "@2x" : "").png"))
    }
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", out.appendingPathComponent("AppIcon.icns").path]
try! p.run(); p.waitUntilExit()
print("icon in \(out.path)")
