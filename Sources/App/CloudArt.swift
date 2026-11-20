import CoreGraphics
import Foundation

/// The character: a black cloud with one eye and a beam of light from the eye (vector version of
/// assets/character.png, proportions measured from it). Drawn with CoreGraphics so the menu bar icon and the
/// SwiftUI views share one drawing, and the eye can blink and look around. Assumes a top-left origin context.
enum CloudArt {
    /// Width / height of the cloud alone (931 × 587 px in the artwork).
    static let cloudAspect: CGFloat = 931.0 / 587.0
    /// The full artwork's beam reaches 0.49 cloud-heights below the cloud.
    static let fullBeam: CGFloat = 0.49
    /// Width / height of the whole drawing with a beam `beam` cloud-heights long.
    static func aspect(beam: CGFloat = fullBeam) -> CGFloat { cloudAspect / (1 + beam) }

    /// Draws the character filling `rect` (whose shape should be `aspect(beam:)`).
    /// `excited`: the eye goes wide and rolls around while the cloud hops.
    /// `asleep`: the eye stays shut and the beam (the eye's light) goes out; the space it takes stays the same.
    static func draw(_ ctx: CGContext, in rect: CGRect, t: Double, excited: Bool, asleep: Bool = false, beam: CGFloat = fullBeam) {
        var r = rect
        if excited { // hop inside the rect so nothing gets clipped
            r = rect.insetBy(dx: rect.width * 0.05, dy: rect.height * 0.05)
            r.origin.y -= abs(sin(t * 9)) * rect.height * 0.05
        }
        // Unit: x in cloud widths, y in cloud heights, origin at the cloud's top-left.
        let w = r.width, h = r.width / cloudAspect
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * w, y: r.minY + y * h) }

        // Cloud: three round puffs on a straight base line.
        var cloud = CGPath(rect: CGRect(origin: P(0.2385, 0.3808), size: CGSize(width: (0.7905 - 0.2385) * w, height: (1 - 0.3808) * h)), transform: nil)
        for (x, y, rad) in [(0.2385, 0.6218, 0.2385), (0.5145, 0.3808, 0.2401), (0.7905, 0.6678, 0.2095)] as [(CGFloat, CGFloat, CGFloat)] {
            let c = P(x, y), rr = rad * w
            cloud = cloud.union(CGPath(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2), transform: nil))
        }

        // Eye geometry, and the beam that spreads down from the eye's corners.
        let c = P(0.5005, 0.6065), hw = 0.1847 * w, fullH = 0.155 * h
        let end = 1 + beam, spread: CGFloat = 0.195 // beam edge: x moves 0.195 widths per cloud height
        let beamPath = CGMutablePath()
        beamPath.move(to: CGPoint(x: c.x - hw, y: c.y))
        beamPath.addLine(to: CGPoint(x: c.x + hw, y: c.y))
        beamPath.addLine(to: P(0.5005 + 0.1847 + spread * (end - 0.6065), end))
        beamPath.addLine(to: P(0.5005 - 0.1847 - spread * (end - 0.6065), end))
        beamPath.closeSubpath()

        // The cloud minus the beam, with a soft grey rim just inside its outer edge.
        ctx.saveGState()
        ctx.addPath(asleep ? cloud : cloud.subtracting(beamPath)); ctx.clip()
        ctx.setFillColor(CGColor(gray: 0.02, alpha: 1))
        ctx.fill(r.insetBy(dx: -2, dy: -2))
        ctx.setShadow(offset: .zero, blur: w * 0.05, color: CGColor(gray: 0.42, alpha: 1))
        ctx.addPath(cloud)
        ctx.setStrokeColor(CGColor(gray: 0.16, alpha: 1))
        ctx.setLineWidth(max(0.8, w * 0.02))
        ctx.strokePath()
        ctx.restoreGState()

        // Beam: black at the eye, fading out toward its end (measured from the artwork).
        if beam > 0 && !asleep {
            ctx.saveGState()
            ctx.addPath(beamPath); ctx.clip()
            let alphas: [CGFloat] = [1, 0.9, 0.58, 0.3, 0.12, 0]
            let beamFade = CGGradient(colorsSpace: CGColorSpaceCreateDeviceGray(),
                                      colors: alphas.map { CGColor(gray: 0.02, alpha: $0) } as CFArray,
                                      locations: [0, 0.2, 0.4, 0.6, 0.8, 1])!
            ctx.drawLinearGradient(beamFade, start: CGPoint(x: c.x, y: c.y), end: P(0.5, end), options: [])
            ctx.restoreGState()
        }

        // Eye: a slightly pointed oval (superellipse, n = 1.7) that closes when blinking; the pupil follows the gaze.
        let lid = excited ? 0 : asleep ? 1 : blink(t)
        let hh = fullH * (1 - lid)

        // Eyelashes (속눈썹): three curved lashes fanned out along the upper lid, bending toward the outer edge.
        // They ride the lid down when blinking; with the eye shut they hang down from the closed line.
        func lashes() {
            let len = fullH * (excited ? 1.0 : 0.8), shut = lid > 0.85
            ctx.setStrokeColor(CGColor(gray: 0.9, alpha: 1))
            ctx.setLineWidth(max(1, w * 0.022))
            ctx.setLineCap(.round)
            for u in [-0.62, 0.0, 0.62] as [CGFloat] {
                let base: CGPoint
                if shut { // on the closed line: x = ±0.9·hw·u', y of the quadratic curve
                    let sx = (u / 0.62 * 0.62 * 0.9 + 1) / 2
                    base = CGPoint(x: c.x + u * hw * 0.9, y: c.y + 2 * sx * (1 - sx) * fullH * 0.35)
                } else { // on the upper edge of the eye outline
                    base = CGPoint(x: c.x + u * hw, y: c.y - hh * pow(max(0, 1 - pow(abs(u), 1.7)), 1 / 1.7))
                }
                let dir: CGFloat = shut ? 1 : -1 // down when asleep, up otherwise
                let lean = u * 0.55 // outer lashes lean outward
                let tip = CGPoint(x: base.x + lean * len + u * len * 0.15, y: base.y + dir * len)
                let ctl = CGPoint(x: base.x + lean * len * 0.1, y: base.y + dir * len * 0.6)
                let path = CGMutablePath()
                path.move(to: base)
                path.addQuadCurve(to: tip, control: ctl)
                ctx.addPath(path)
                ctx.strokePath()
            }
        }
        if lid > 0.85 { // closed: a soft curved line
            let p = CGMutablePath()
            p.move(to: CGPoint(x: c.x - hw * 0.9, y: c.y))
            p.addQuadCurve(to: CGPoint(x: c.x + hw * 0.9, y: c.y), control: CGPoint(x: c.x, y: c.y + fullH * 0.35))
            ctx.addPath(p)
            ctx.setStrokeColor(CGColor(gray: 0.88, alpha: 1))
            ctx.setLineWidth(max(1, w * 0.02))
            ctx.setLineCap(.round)
            ctx.strokePath()
            lashes()
            return
        }
        let eye = CGMutablePath()
        for i in 0..<96 {
            let a = Double(i) / 96 * 2 * .pi, e = 2 / 1.7
            let pt = CGPoint(x: c.x + hw * copysign(pow(abs(cos(a)), e), cos(a)), y: c.y + hh * copysign(pow(abs(sin(a)), e), sin(a)))
            if i == 0 { eye.move(to: pt) } else { eye.addLine(to: pt) }
        }
        eye.closeSubpath()
        ctx.saveGState()
        ctx.addPath(eye); ctx.clip()
        let space = CGColorSpaceCreateDeviceGray()
        let white = CGGradient(colorsSpace: space, colors: [CGColor(gray: 1, alpha: 1), CGColor(gray: 0.8, alpha: 1)] as CFArray, locations: nil)!
        ctx.drawLinearGradient(white, start: CGPoint(x: c.x, y: c.y - fullH), end: CGPoint(x: c.x, y: c.y + fullH), options: [])
        let g = excited ? CGPoint(x: cos(t * 7) * 0.8, y: sin(t * 7) * 0.8) : gaze(t)
        let pc = CGPoint(x: c.x + g.x * hw * 0.4, y: c.y + g.y * fullH * 0.3)
        let prx = 0.0623 * w, pry = 0.1107 * h
        // Pupil: black with a soft grey edge.
        ctx.setFillColor(CGColor(gray: 0.38, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: pc.x - prx, y: pc.y - pry, width: prx * 2, height: pry * 2))
        ctx.setFillColor(CGColor(gray: 0, alpha: 1))
        ctx.setShadow(offset: .zero, blur: prx * 0.25, color: CGColor(gray: 0, alpha: 1))
        let k: CGFloat = 0.82
        ctx.fillEllipse(in: CGRect(x: pc.x - prx * k, y: pc.y - pry * k, width: prx * 2 * k, height: pry * 2 * k))
        ctx.restoreGState()
        lashes()
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
