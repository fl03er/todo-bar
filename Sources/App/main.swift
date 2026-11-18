import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    let store = TodoStore()
    var statusItem: NSStatusItem!
    let popover = NSPopover()

    var eyeTimer: Timer?
    var lastEyes = "" // what the icon last drew; redraw only when it changes
    var excitedUntil = Date.distantPast

    func applicationDidFinishLaunching(_ note: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let b = statusItem.button {
            b.imagePosition = .imageLeft
            b.imageScaling = .scaleNone // the default shrinks the icon to ~17pt
            b.target = self
            b.action = #selector(togglePopover)
        }

        let host = NSHostingController(rootView: ContentView(store: store))
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
        popover.behavior = .transient
        popover.animates = true
        popover.appearance = NSAppearance(named: .aqua)
        popover.delegate = self

        store.onChange = { [weak self] in self?.updateButton() }
        store.onAllDone = { [weak self] in
            self?.excitedUntil = Date().addingTimeInterval(3.5)
            self?.showCelebration()
        }
        updateButton()

        // Animate the menu bar eyes. Redraws only when they actually moved, so it idles almost free.
        let timer = Timer(timeInterval: 1 / 30, repeats: true) { [weak self] _ in self?.tickEyes() }
        RunLoop.main.add(timer, forMode: .common)
        eyeTimer = timer
    }

    func updateButton() {
        guard let b = statusItem?.button else { return }
        lastEyes = ""; tickEyes()
        let n = store.remaining
        b.attributedTitle = n == 0 ? NSAttributedString() : NSAttributedString(
            string: " \(n)", attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)])
        b.toolTip = store.todos.isEmpty ? "할 일 없음" : (n == 0 ? "전부 끝!" : "할 일 \(n)개 남음")
    }

    func tickEyes() {
        guard let b = statusItem?.button else { return }
        let t = Date().timeIntervalSinceReferenceDate
        let excited = Date() < excitedUntil
        let g = CloudArt.gaze(t), lid = CloudArt.blink(t)
        let key = excited ? "\(t)" : String(format: "%.2f %.2f %.2f", g.x, g.y, lid)
        if key == lastEyes { return }
        lastEyes = key
        let h: CGFloat = 26 // fills the (notch-height) menu bar
        let beam: CGFloat = 0.3 // a shorter beam than the artwork's, so the cloud stays readable at this size
        b.image = NSImage(size: NSSize(width: (h * CloudArt.aspect(beam: beam)).rounded(), height: h), flipped: true) { r in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            CloudArt.draw(ctx, in: r, t: t, excited: excited, beam: beam)
            return true
        }
    }

    @objc func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            show()
            NSApp.activate(ignoringOtherApps: true)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func show() {
        guard let b = statusItem.button else { return }
        popover.show(relativeTo: b.bounds, of: b, preferredEdge: .minY)
    }

    /// When the last item is checked off while the panel is closed (CLI / Claude Code), pop a small card under
    /// the icon. It's a non-activating panel that never becomes key, so it can't steal what the user is typing.
    var cheerPanel: NSPanel?
    func showCelebration() {
        guard !popover.isShown, let b = statusItem.button, let bw = b.window else { return }
        cheerPanel?.orderOut(nil)
        let size = NSSize(width: 230, height: 150)
        let iconFrame = bw.convertToScreen(b.convert(b.bounds, to: nil))
        let panel = NSPanel(contentRect: NSRect(x: iconFrame.midX - size.width / 2, y: iconFrame.minY - size.height - 6,
                                                width: size.width, height: size.height),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        panel.contentView = NSHostingView(rootView: CheerCard(count: store.todos.count))
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.2; panel.animator().alphaValue = 1 }
        cheerPanel = panel
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self, weak panel] in
            guard let panel else { return }
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.4; panel.animator().alphaValue = 0 }) {
                panel.orderOut(nil)
                if self?.cheerPanel === panel { self?.cheerPanel = nil }
            }
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
