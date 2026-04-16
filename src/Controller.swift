import AppKit
import Foundation

final class MenuBarController: @unchecked Sendable {
    private let poller = SpotifyPoller()
    private let lyricsFetcher = LyricsFetcher()
    private let lyricsEngine = LyricsEngine()
    private let transliterator = Transliterator()

    private var statusItem: NSStatusItem?
    private var overlayWindow: OverlayWindow?
    private var settingsWindow: SettingsWindow?

    private var displayState: DisplayState = .idle
    private var uiMode: UIMode = .menuBar
    private var currentTrack: SpotifyTrack?
    private var currentLyrics: [LyricLine]?
    private var hasNoLyrics = false
    private var isPlaying = false
    private var introTimer: Timer?
    private var isEnabled = true
    private var lastDisplayedLine: String?
    private var useStyledIcon = true
    private var menuBarWidth: CGFloat = 340
    private var showRomanized = false
    private var syncOffsetMs: Int = 300

    private var dominantColor: NSColor = NSColor(white: 0.15, alpha: 1.0)
    private var currentArtworkImage: NSImage?
    private var artworkCache: [URL: NSImage] = [:]
    private var currentArtworkURL: URL?

    init(statusItem: NSStatusItem) {
        self.statusItem = statusItem
    }

    func setup() {
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        }
        restoreStatusMenu()
        
        let pan = NSPanGestureRecognizer(target: self, action: #selector(handleMenuBarPan(_:)))
        statusItem?.button?.addGestureRecognizer(pan)

        let w = OverlayWindow(initialFrame: NSRect(x: 200, y: 200, width: 440, height: 56))
        w.onClicked = { [weak self] in self?.toggleRomanized() }
        w.onRightClicked = { [weak self] in self?.showSettings() }
        w.onDraggedToMenuBar = { [weak self] in self?.switchToMenuBar() }
        overlayWindow = w

        poller.onTrackChanged = { [weak self] in self?.handleTrackChanged($0) }
        poller.onPositionUpdate = { [weak self] in self?.handlePositionUpdate(positionMs: $0, isPlaying: $1) }
        poller.onSpotifyQuit = { [weak self] in self?.handleSpotifyQuit() }
        poller.start()
        updateDisplay()
    }

    func teardown() {
        poller.stop()
        introTimer?.invalidate()
        overlayWindow?.orderOut(nil)
    }

    private func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        restoreStatusMenu()
        addPanGesture()
    }

    private func addPanGesture() {
        if let btn = statusItem?.button, btn.gestureRecognizers.isEmpty {
            let pan = NSPanGestureRecognizer(target: self, action: #selector(handleMenuBarPan(_:)))
            btn.addGestureRecognizer(pan)
        }
    }

    private func restoreStatusMenu() {
        let m = NSMenu()
        let romanItem = NSMenuItem(title: "Convert to ENG", action: #selector(toggleRomanizedClicked), keyEquivalent: "r")
        romanItem.target = self
        m.addItem(romanItem)
        m.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings", action: #selector(settingsClicked), keyEquivalent: ",")
        settingsItem.target = self
        m.addItem(settingsItem)
        m.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitClicked), keyEquivalent: "q")
        quitItem.target = self
        m.addItem(quitItem)
        statusItem?.menu = m
    }

    @objc private func toggleRomanizedClicked() { toggleRomanized() }
    @objc private func settingsClicked() { showSettings() }
    @objc private func quitClicked() { NSApp.terminate(nil) }

    @objc private func handleMenuBarPan(_ gesture: NSPanGestureRecognizer) {
        let screenLoc = NSEvent.mouseLocation
        
        if uiMode == .menuBar && gesture.state == .changed {
            let screenHeight = NSScreen.main?.frame.height ?? 1080
            if screenLoc.y < screenHeight - 30 {
                switchToFloating(at: screenLoc)
            }
        } else if uiMode == .floating {
            if gesture.state == .changed {
                let w = overlayWindow?.frame.width ?? 440
                let h = overlayWindow?.frame.height ?? 56
                overlayWindow?.setFrameOrigin(NSPoint(x: screenLoc.x - w/2, y: screenLoc.y - h/2))
            } else if gesture.state == .ended || gesture.state == .cancelled {
                overlayWindow?.savePos()
                // The continuous transitioning drag has completed. Remove intercepts to allow perfect crisp clicks.
                if let btn = statusItem?.button {
                    for g in btn.gestureRecognizers { btn.removeGestureRecognizer(g) }
                    btn.action = #selector(floatingIconClicked)
                    btn.target = self
                }
            }
        }
    }

    @objc private func floatingIconClicked() {
        switchToMenuBar()
    }

    private func switchToFloating(at location: NSPoint) {
        NSLog("[Captions] Transitioning to FLOATING mode at %@", NSStringFromPoint(location))
        uiMode = .floating
        statusItem?.menu = nil
        
        let w = overlayWindow?.frame.width ?? 440
        let h = overlayWindow?.frame.height ?? 56
        let origin = NSPoint(x: location.x - w/2, y: location.y - h/2)
        overlayWindow?.setFrameOrigin(origin)
        overlayWindow?.makeKeyAndOrderFront(nil)
        updateDisplay()
    }

    private func switchToMenuBar() {
        if uiMode == .menuBar { return }
        NSLog("[Captions] Transitioning to MENU BAR mode")
        uiMode = .menuBar
        overlayWindow?.orderOut(nil)
        
        statusItem?.button?.action = nil
        restoreStatusMenu()
        addPanGesture()
        updateDisplay()
    }

    private func toggleRomanized() {
        showRomanized.toggle()
        updateDisplay()
    }

    private func showSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow()
            settingsWindow?.onToggleEnabled = { [weak self] en in
                self?.isEnabled = en
                if en { self?.poller.start() } else { self?.poller.stop(); self?.displayState = .idle; self?.updateDisplay() }
            }
            settingsWindow?.onSyncOffsetChanged = { [weak self] in self?.syncOffsetMs = $0 }
            settingsWindow?.onToggleStyledIcon = { [weak self] styled in
                self?.useStyledIcon = styled
                if let i = self?.currentArtworkImage { self?.applyArtwork(i) }
            }
            settingsWindow?.onWidthChanged = { [weak self] w in
                self?.menuBarWidth = w
                self?.updateDisplay()
            }
        }
        settingsWindow?.updateEnabled(isEnabled)
        settingsWindow?.updateSyncOffset(syncOffsetMs)
        settingsWindow?.updateStyledIcon(useStyledIcon)
        settingsWindow?.updateWidth(menuBarWidth)
        settingsWindow?.show()
    }

    private func handleTrackChanged(_ track: SpotifyTrack) {
        currentTrack = track
        currentLyrics = nil
        hasNoLyrics = false
        lastDisplayedLine = nil
        lyricsEngine.reset()
        introTimer?.invalidate()
        introTimer = nil

        if track.positionMs > 5000 {
            displayState = .fallback(track: track)
        } else {
            displayState = .intro(track: track)
            introTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in self?.endIntroPhase() }
        }
        updateDisplay()
        
        Task {
            if let lyrics = await lyricsFetcher.fetchLyrics(trackName: track.name, artistName: track.artist, albumName: track.album) {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, self.currentTrack?.id == track.id else { return }
                    self.currentLyrics = lyrics
                    if case .intro = self.displayState {
                        if let ft = self.lyricsEngine.firstLyricTimeMs(in: lyrics), track.positionMs >= ft { self.endIntroPhase() }
                    } else {
                        self.displayState = .lyrics(track: track, currentLine: "")
                        self.updateDisplay()
                    }
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, self.currentTrack?.id == track.id else { return }
                    self.hasNoLyrics = true
                    if case .intro = self.displayState {} else {
                        self.displayState = .fallback(track: track)
                        self.updateDisplay()
                    }
                }
            }
        }
        
        loadArtwork(for: track)
    }

    private func endIntroPhase() {
        introTimer?.invalidate()
        introTimer = nil
        guard let track = currentTrack else { return }
        displayState = (hasNoLyrics || currentLyrics == nil) ? .fallback(track: track) : .lyrics(track: track, currentLine: "")
        updateDisplay()
    }

    private func loadArtwork(for track: SpotifyTrack) {
        guard let url = track.artworkUrl, url != currentArtworkURL else { return }
        currentArtworkURL = url
        if let cached = artworkCache[url] { applyArtwork(cached); return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let img = NSImage(data: data) else { return }
            DispatchQueue.main.async { [weak self] in
                self?.artworkCache[url] = img
                if self?.currentArtworkURL == url { self?.applyArtwork(img) }
            }
        }.resume()
    }

    private func applyArtwork(_ image: NSImage) {
        currentArtworkImage = image
        dominantColor = extractDominantColor(from: image)
        
        updateDisplay()
        overlayWindow?.updateArtwork(image)
        overlayWindow?.updateTheme(dominantColor)
    }

    private func handlePositionUpdate(positionMs: Int, isPlaying: Bool) {
        self.isPlaying = isPlaying
        guard isPlaying, let track = currentTrack else { return }
        let adj = positionMs + syncOffsetMs
        
        if case .intro = displayState, let lyrics = currentLyrics, let ft = lyricsEngine.firstLyricTimeMs(in: lyrics), adj >= ft {
            endIntroPhase()
        }

        if case .lyrics = displayState, let lyrics = currentLyrics, let line = lyricsEngine.currentLine(for: adj, in: lyrics), line != lastDisplayedLine {
            lastDisplayedLine = line
            displayState = .lyrics(track: track, currentLine: line)
            updateDisplay()
        }
    }

    private func handleSpotifyQuit() {
        currentTrack = nil; currentLyrics = nil; hasNoLyrics = false
        introTimer?.invalidate(); introTimer = nil
        lastDisplayedLine = nil; lyricsEngine.reset()
        currentArtworkImage = nil; currentArtworkURL = nil
        displayState = .idle; updateDisplay()
    }

    private func updateDisplay() {
        var text = ""
        var info = ""

        switch displayState {
        case .idle:
            statusItem?.button?.title = "♫"
            statusItem?.button?.image = nil
            overlayWindow?.showIdle()
            return
        case .intro(let track):
            text = "\(track.name) — \(track.artist)"
            info = "\(track.artist) — \(track.album)"
        case .lyrics(_, let line):
            text = line.isEmpty ? (currentTrack?.name ?? "🎵") : line
            info = currentTrack.map { t in "\(t.artist) — \(t.album)" } ?? ""
        case .fallback(let track):
            text = "\(track.name) — \(track.artist)"
            info = "\(track.artist) — \(track.album)"
        }

        if showRomanized { text = transliterator.transliterate(text) }
        
        let maxLength = 35
        let truncatedText = text.count > maxLength ? String(text.prefix(maxLength - 1)) + "…" : text

        if !useStyledIcon {
            if uiMode == .menuBar {
                statusItem?.button?.title = " \(truncatedText)"
                statusItem?.button?.image = currentArtworkImage.map { resizeImage($0, to: NSSize(width: 16, height: 16)) }
            } else {
                statusItem?.button?.title = ""
                statusItem?.button?.image = currentArtworkImage.map { resizeImage($0, to: NSSize(width: 16, height: 16)) }
                overlayWindow?.updateLyrics(text, info: info)
            }
        } else {
            statusItem?.button?.title = ""
            statusItem?.button?.imagePosition = .imageOnly
            if uiMode == .menuBar {
                statusItem?.button?.image = renderMenuBarItem(text: truncatedText, art: currentArtworkImage, theme: dominantColor)
            } else {
                statusItem?.button?.image = renderMenuBarItem(text: "", art: currentArtworkImage, theme: dominantColor)
                overlayWindow?.updateLyrics(text, info: info)
            }
        }
    }

    private func extractDominantColor(from image: NSImage) -> NSColor {
        guard let tiffData = image.tiffRepresentation, let bmp = NSBitmapImageRep(data: tiffData) else { return NSColor(white: 0.15, alpha: 1.0) }
        let n = 8; var rT: CGFloat = 0, gT: CGFloat = 0, bT: CGFloat = 0, rV: CGFloat = 0, gV: CGFloat = 0, bV: CGFloat = 0, vc: CGFloat = 0, tc: CGFloat = 0
        let w = bmp.pixelsWide, h = bmp.pixelsHigh
        guard w > 0, h > 0 else { return NSColor(white: 0.15, alpha: 1.0) }
        for x in 0..<n { for y in 0..<n {
            guard let c = bmp.colorAt(x: x*w/n, y: y*h/n)?.usingColorSpace(.sRGB) else { continue }
            let r = c.redComponent, g = c.greenComponent, b = c.blueComponent
            rT += r; gT += g; bT += b; tc += 1
            let mx = max(r,g,b), mn = min(r,g,b)
            if mx > 0 && (mx-mn)/mx > 0.3 && mx > 0.2 && mx < 0.9 { rV += r; gV += g; bV += b; vc += 1 }
        }}
        guard tc > 0 else { return NSColor(white: 0.15, alpha: 1.0) }
        let r, g, b: CGFloat
        if vc > 3 { r = rV/vc; g = gV/vc; b = bV/vc } else { r = rT/tc; g = gT/tc; b = bT/tc }
        return NSColor(red: r*0.7, green: g*0.7, blue: b*0.7, alpha: 1.0)
    }

    private func renderMenuBarItem(text: String, art: NSImage?, theme: NSColor) -> NSImage {
        let height: CGFloat = 20
        let artSize: CGFloat = 14
        let padding: CGFloat = 8
        let gap: CGFloat = 6
        let fixedMenuWidth: CGFloat = self.menuBarWidth
        
        let font = NSFont.systemFont(ofSize: 13, weight: .medium)
        let rgb = theme.usingColorSpace(.sRGB) ?? theme
        let isLight = (0.299*rgb.redComponent + 0.587*rgb.greenComponent + 0.114*rgb.blueComponent) > 0.5
        let textColor = isLight ? NSColor.black : NSColor.white
        
        let pStyle = NSMutableParagraphStyle()
        pStyle.alignment = .center
        pStyle.lineBreakMode = .byTruncatingTail
        let textAttr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor, .paragraphStyle: pStyle]
        
        let totalWidth: CGFloat = text.isEmpty ? (art != nil ? height : 0) : fixedMenuWidth
        guard totalWidth > 0 else { return NSImage(size: NSSize(width: 1, height: 1)) }
        
        let img = NSImage(size: NSSize(width: totalWidth, height: height))
        img.lockFocus()
        
        let bounds = NSRect(origin: .zero, size: NSSize(width: totalWidth, height: height))
        let bg = NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10)
        let dk = theme.blended(withFraction: 0.6, of: .black) ?? theme
        if let grad = NSGradient(starting: theme.withAlphaComponent(0.92), ending: dk.withAlphaComponent(0.92)) {
            grad.draw(in: bg, angle: 0)
        }
        NSColor.white.withAlphaComponent(0.08).setStroke()
        bg.lineWidth = 0.5
        bg.stroke()
        
        var currentX: CGFloat = padding
        if text.isEmpty && art != nil { currentX = (totalWidth - artSize) / 2 }
        
        if let art = art {
            let artRect = NSRect(x: currentX, y: (height - artSize)/2, width: artSize, height: artSize)
            NSGraphicsContext.current?.saveGraphicsState()
            NSBezierPath(roundedRect: artRect, xRadius: 4, yRadius: 4).addClip()
            art.draw(in: artRect, from: NSRect(origin: .zero, size: art.size), operation: .sourceOver, fraction: 1.0)
            NSGraphicsContext.current?.restoreGraphicsState()
            currentX += artSize + gap
        }
        
        if !text.isEmpty {
            let availableTextWidth = totalWidth - currentX - padding
            let textRect = NSRect(x: currentX, y: 3, width: availableTextWidth, height: 16)
            (text as NSString).draw(in: textRect, withAttributes: textAttr)
        }
        
        img.unlockFocus()
        img.isTemplate = false
        return img
    }

    private func resizeImage(_ image: NSImage, to size: NSSize) -> NSImage {
        let img = NSImage(size: size)
        img.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size), from: NSRect(origin: .zero, size: image.size), operation: .sourceOver, fraction: 1.0)
        img.unlockFocus()
        return img
    }
}
