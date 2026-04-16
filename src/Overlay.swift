import AppKit

final class OverlayWindow: NSWindow {
    private let overlay = OverlayView()
    private let posKey = "OverlayPos"

    var onClicked: (() -> Void)?
    var onRightClicked: (() -> Void)?
    var onDraggedToMenuBar: (() -> Void)?

    init(initialFrame: NSRect) {
        super.init(contentRect: initialFrame, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        level = .floating; isOpaque = false; backgroundColor = .clear
        hasShadow = true; isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        ignoresMouseEvents = false; hidesOnDeactivate = false
        contentView = overlay; overlay.frame = NSRect(origin: .zero, size: initialFrame.size)
        overlay.onSingleClick = { [weak self] in self?.onClicked?() }
        overlay.onDragMoved = { [weak self] dx, dy in
            guard let s = self else { return }
            s.setFrameOrigin(NSPoint(x: s.frame.origin.x + dx, y: s.frame.origin.y - dy))
        }
        overlay.onDragEnded = { [weak self] in 
            guard let s = self else { return }
            s.savePos()
            
            // Allow drag to menu bar area
            if let screen = s.screen {
                let currentY = s.frame.maxY
                let screenH = screen.frame.maxY
                if currentY > screenH - 25 {
                    s.onDraggedToMenuBar?()
                }
            }
        }
        overlay.onRightClick = { [weak self] in self?.onRightClicked?() }
        restorePos()
    }
    private func restorePos() {
        if let d = UserDefaults.standard.dictionary(forKey: posKey),
           let x = d["x"] as? CGFloat, let y = d["y"] as? CGFloat {
            setFrameOrigin(NSPoint(x: x, y: y))
        } else if let s = NSScreen.main {
            let f = s.visibleFrame
            setFrameOrigin(NSPoint(x: f.midX - frame.width/2, y: f.maxY - frame.height - 50))
        }
    }
    func savePos() {
        UserDefaults.standard.set(["x": frame.origin.x, "y": frame.origin.y], forKey: posKey)
    }

    func updateLyrics(_ text: String, info: String) { overlay.updateText(text, info: info) }
    func updateArtwork(_ img: NSImage?) { overlay.updateArtwork(img) }
    func updateTheme(_ color: NSColor) { overlay.updateTheme(color) }
    func showIdle() { overlay.showIdle() }
}

private final class OverlayView: NSView {
    private let cr: CGFloat = 14, artSz: CGFloat = 38, pad: CGFloat = 12
    private var text = "", info = "", prevText = ""
    private var art: NSImage?, theme = NSColor(white: 0.15, alpha: 1), txtC = NSColor.white
    private var idle = true, animP: CGFloat = 1, animT: Timer?
    private var mouseDownPt = NSPoint.zero, dragging = false

    var onSingleClick: (() -> Void)?
    var onDragMoved: ((CGFloat, CGFloat) -> Void)?
    var onDragEnded: (() -> Void)?
    var onRightClick: (() -> Void)?

    override init(frame: NSRect) { super.init(frame: frame); wantsLayer = true }
    required init?(coder: NSCoder) { fatalError() }

    func updateText(_ t: String, info i: String) {
        idle = false; info = i
        if t != text && !text.isEmpty { prevText = text; text = t; startAnim() }
        else { text = t; needsDisplay = true }
    }
    func updateArtwork(_ i: NSImage?) { art = i; needsDisplay = true }
    func updateTheme(_ c: NSColor) {
        theme = c
        let rgb = c.usingColorSpace(.sRGB) ?? c
        txtC = (0.299*rgb.redComponent + 0.587*rgb.greenComponent + 0.114*rgb.blueComponent) > 0.5 ? .black : .white
        needsDisplay = true
    }
    func showIdle() {
        idle = true; text = ""; info = ""; art = nil
        theme = NSColor(white: 0.15, alpha: 1); txtC = .white; needsDisplay = true
    }

    private func startAnim() {
        animP = 0; animT?.invalidate()
        let step: CGFloat = 1.0 / (0.3 * 60)
        animT = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { [weak self] _ in
            guard let s = self else { return }
            s.animP = min(1, s.animP + step)
            if s.animP >= 1 { s.animT?.invalidate(); s.animT = nil }
            s.needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let ctx = NSGraphicsContext.current!.cgContext
        let bg = NSBezierPath(roundedRect: bounds, xRadius: cr, yRadius: cr)
        let dk = theme.blended(withFraction: 0.6, of: .black) ?? theme
        NSGradient(starting: theme.withAlphaComponent(0.92), ending: dk.withAlphaComponent(0.92))?.draw(in: bg, angle: 0)
        NSColor.white.withAlphaComponent(0.08).setStroke(); bg.lineWidth = 0.5; bg.stroke()

        if idle {
            let a: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 14, weight: .medium), .foregroundColor: txtC.withAlphaComponent(0.5)]
            NSAttributedString(string: "♫ Waiting for Spotify…", attributes: a)
                .draw(in: NSRect(x: pad, y: (bounds.height-18)/2, width: bounds.width-pad*2, height: 20)); return
        }

        let ay = (bounds.height - artSz)/2, ar = NSRect(x: pad, y: ay, width: artSz, height: artSz)
        if let a = art {
            ctx.saveGState()
            NSBezierPath(roundedRect: ar, xRadius: 6, yRadius: 6).addClip()
            a.draw(in: ar, from: .zero, operation: .sourceOver, fraction: 1)
            ctx.restoreGState()
        }

        let tx = pad + artSz + 10, tw = bounds.width - tx - pad
        let ia: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 10, weight: .regular), .foregroundColor: txtC.withAlphaComponent(0.45)]
        NSAttributedString(string: info, attributes: ia).draw(with: NSRect(x: tx, y: 6, width: tw, height: 14), options: [.truncatesLastVisibleLine, .usesLineFragmentOrigin])

        let f = NSFont.systemFont(ofSize: 14, weight: .semibold)
        if animP < 1 {
            let e = animP < 0.5 ? 2*animP*animP : -1+(4-2*animP)*animP, sl: CGFloat = 14
            let oa: [NSAttributedString.Key: Any] = [.font: f, .foregroundColor: txtC.withAlphaComponent(1-e)]
            NSAttributedString(string: prevText, attributes: oa).draw(with: NSRect(x: tx, y: 24+sl*e, width: tw, height: 22), options: [.truncatesLastVisibleLine, .usesLineFragmentOrigin])
            let na: [NSAttributedString.Key: Any] = [.font: f, .foregroundColor: txtC.withAlphaComponent(e)]
            NSAttributedString(string: text, attributes: na).draw(with: NSRect(x: tx, y: 24-sl*(1-e), width: tw, height: 22), options: [.truncatesLastVisibleLine, .usesLineFragmentOrigin])
        } else {
            let la: [NSAttributedString.Key: Any] = [.font: f, .foregroundColor: txtC]
            NSAttributedString(string: text, attributes: la).draw(with: NSRect(x: tx, y: 24, width: tw, height: 22), options: [.truncatesLastVisibleLine, .usesLineFragmentOrigin])
        }
    }

    override var mouseDownCanMoveWindow: Bool { false }
    override func mouseDown(with e: NSEvent) { mouseDownPt = NSEvent.mouseLocation; dragging = false }
    override func mouseDragged(with e: NSEvent) {
        let cur = NSEvent.mouseLocation
        if hypot(cur.x - mouseDownPt.x, cur.y - mouseDownPt.y) > 5 { dragging = true }
        if dragging { onDragMoved?(e.deltaX, e.deltaY) }
    }
    override func mouseUp(with e: NSEvent) {
        if dragging { onDragEnded?() } else { onSingleClick?() }
        dragging = false
    }
    override func rightMouseDown(with e: NSEvent) { onRightClick?() }
}
