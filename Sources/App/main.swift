import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    let store = TodoStore()
    var statusItem: NSStatusItem!
    let popover = NSPopover()

    lazy var icon = loadIcon("StatusIcon")

    func applicationDidFinishLaunching(_ note: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let b = statusItem.button {
            b.imagePosition = .imageLeft
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
        store.onAllDone = { [weak self] in self?.showCelebration() }
        updateButton()
    }

    func loadIcon(_ name: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"), let img = NSImage(contentsOf: url) else { return nil }
        let h: CGFloat = 21 // the character is wider than tall; keep its proportions
        img.size = NSSize(width: (h * img.size.width / max(img.size.height, 1)).rounded(), height: h)
        return img
    }

    func updateButton() {
        guard let b = statusItem?.button else { return }
        b.image = icon
        let n = store.remaining
        b.attributedTitle = n == 0 ? NSAttributedString() : NSAttributedString(
            string: " \(n)", attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)])
        b.toolTip = store.todos.isEmpty ? "할 일 없음" : (n == 0 ? "전부 끝!" : "할 일 \(n)개 남음")
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
