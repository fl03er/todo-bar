import CoreGraphics
import Foundation

/// The character: a black cloud with one eye (vector version of assets/character.png).
/// Drawn with CoreGraphics so the menu bar icon and the SwiftUI views share one drawing, and the eye can
/// blink and look around. All drawing assumes a top-left origin (flipped) context.
enum CloudArt {
    static let aspect: CGFloat = 930.0 / 595.0 // width / height of the cloud

    /// Draws the character filling `r`. `excited`: the eye goes wide and rolls around while the cloud hops.
    static func draw(_ ctx: CGContext, in rect: CGRect, t: Double, excited: Bool) {
        var r = rect
        if excited { // hop inside the rect so nothing gets clipped
            r = rect.insetBy(dx: rect.width * 0.05, dy: rect.height * 0.05)
            r.origin.y -= abs(sin(t * 9)) * rect.height * 0.05
        }
        let w = r.width, h = r.height
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * w, y: r.minY + y * h) }

        // Cloud: three puffs and a flat base, merged into one outline.
        var cloud = CGPath(rect: CGRect(origin: P(0.242, 0.387), size: CGSize(width: 0.543 * w, height: 0.603 * h)), transform: nil)
        for (x, y, rad) in [(0.242, 0.622, 0.242), (0.522, 0.387, 0.247), (0.785, 0.655, 0.215)] as [(CGFloat, CGFloat, CGFloat)] {
            let c = P(x, y), rr = rad * w
            cloud = cloud.union(CGPath(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2), transform: nil))
        }
        ctx.saveGState()
        ctx.addPath(cloud); ctx.clip()
        ctx.setFillColor(CGColor(gray: 0.02, alpha: 1))
        ctx.fill(r.insetBy(dx: -2, dy: -2))
        // Soft grey rim just inside the edge, like the artwork's glow.
        ctx.setShadow(offset: .zero, blur: w * 0.06, color: CGColor(gray: 0.45, alpha: 1))
        ctx.addPath(cloud)
        ctx.setStrokeColor(CGColor(gray: 0.24, alpha: 1))
        ctx.setLineWidth(max(0.8, w * 0.018))
        ctx.strokePath()
        ctx.restoreGState()

        // Eye: an almond that closes when blinking, with a pupil that follows the gaze.
        let lid = excited ? 0 : blink(t)
        let c = P(0.5, 0.597), hw = 0.183 * w, fullH = 0.165 * h
        let hh = fullH * (1 - lid)
        if lid > 0.85 { // closed: a soft curved line
            let p = CGMutablePath()
            p.move(to: CGPoint(x: c.x - hw * 0.9, y: c.y))
            p.addQuadCurve(to: CGPoint(x: c.x + hw * 0.9, y: c.y), control: CGPoint(x: c.x, y: c.y + fullH * 0.35))
            ctx.addPath(p)
            ctx.setStrokeColor(CGColor(gray: 0.88, alpha: 1))
            ctx.setLineWidth(max(1, w * 0.02))
            ctx.setLineCap(.round)
            ctx.strokePath()
            return
        }
        let eye = CGMutablePath()
        eye.move(to: CGPoint(x: c.x - hw, y: c.y))
        eye.addCurve(to: CGPoint(x: c.x + hw, y: c.y), control1: CGPoint(x: c.x - hw * 0.45, y: c.y - hh * 1.33),
                     control2: CGPoint(x: c.x + hw * 0.45, y: c.y - hh * 1.33))
        eye.addCurve(to: CGPoint(x: c.x - hw, y: c.y), control1: CGPoint(x: c.x + hw * 0.45, y: c.y + hh * 1.33),
                     control2: CGPoint(x: c.x - hw * 0.45, y: c.y + hh * 1.33))
        eye.closeSubpath()
        ctx.saveGState()
        ctx.addPath(eye); ctx.clip()
        let space = CGColorSpaceCreateDeviceGray()
        let white = CGGradient(colorsSpace: space, colors: [CGColor(gray: 1, alpha: 1), CGColor(gray: 0.8, alpha: 1)] as CFArray, locations: nil)!
        ctx.drawLinearGradient(white, start: CGPoint(x: c.x, y: c.y - fullH), end: CGPoint(x: c.x, y: c.y + fullH), options: [])
        let g = excited ? CGPoint(x: cos(t * 7) * 0.8, y: sin(t * 7) * 0.8) : gaze(t)
        let pc = CGPoint(x: c.x + g.x * hw * 0.45, y: c.y + g.y * fullH * 0.35)
        let prx = 0.062 * w, pry = 0.11 * h
        // Pupil: black with a soft grey edge.
        ctx.setFillColor(CGColor(gray: 0.38, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: pc.x - prx, y: pc.y - pry, width: prx * 2, height: pry * 2))
        ctx.setFillColor(CGColor(gray: 0, alpha: 1))
        ctx.setShadow(offset: .zero, blur: prx * 0.25, color: CGColor(gray: 0, alpha: 1))
        let k: CGFloat = 0.82
        ctx.fillEllipse(in: CGRect(x: pc.x - prx * k, y: pc.y - pry * k, width: prx * 2 * k, height: pry * 2 * k))
        ctx.restoreGState()
    }

    private static func rand(_ n: Int, _ salt: Double) -> Double { // stable pseudo-random 0..<1
        let v = sin(Double(n) * 12.9898 + salt * 78.233) * 43758.5453
        return v - v.rounded(.down)
    }

    /// Where the eye looks, in -1...1. Each gaze lasts 1.8–4.2 s; the move to the next one takes ~0.35 s and
    /// eases in and out, like a real glance. Every third gaze returns to the centre.
    static func gaze(_ t: Double) -> CGPoint {
        func target(_ n: Int) -> CGPoint {
            if n % 3 == 0 { return .zero }
            return CGPoint(x: rand(n, 1) * 2 - 1, y: (rand(n, 2) * 2 - 1) * 0.7)
        }
        let block = 3.0
        func start(_ m: Int) -> Double { Double(m) * block + (rand(m, 3) - 0.5) * 1.2 }
        var cur = Int((t / block).rounded(.down)) + 1
        while start(cur) > t { cur -= 1 }
        let k = min(1, max(0, (t - start(cur)) / 0.35))
        let e = k * k * (3 - 2 * k) // smoothstep
        let a = target(cur - 1), b = target(cur)
        return CGPoint(x: a.x + (b.x - a.x) * e, y: a.y + (b.y - a.y) * e)
    }

    /// How closed the eye is, 0 (open) … 1 (shut). A quick blink every 2.7–5.7 s, sometimes a double blink.
    static func blink(_ t: Double) -> Double {
        let block = 4.2
        func start(_ m: Int) -> Double { Double(m) * block + (rand(m, 5) - 0.5) * 3 }
        var cur = Int((t / block).rounded(.down)) + 1
        while start(cur) > t { cur -= 1 }
        func lid(_ d: Double) -> Double { // close in 70 ms, open in 110 ms
            d < 0 ? 0 : d < 0.07 ? d / 0.07 : d < 0.18 ? 1 - (d - 0.07) / 0.11 : 0
        }
        let d = t - start(cur)
        return rand(cur, 6) < 0.25 ? max(lid(d), lid(d - 0.26)) : lid(d)
    }
}
