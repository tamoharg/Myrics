import AppKit

final class SettingsWindow: NSWindow {
    var onToggleEnabled: ((Bool) -> Void)?
    var onSyncOffsetChanged: ((Int) -> Void)?
    var onToggleStyledIcon: ((Bool) -> Void)?
    var onWidthChanged: ((CGFloat) -> Void)?

    private let toggleBtn = NSButton(checkboxWithTitle: "Enable Captions", target: nil, action: nil)
    private let styledBtn = NSButton(checkboxWithTitle: "Styled Menu Icon", target: nil, action: nil)
    private let offsetField = NSTextField(string: "300")
    private let widthSlider = NSSlider(value: 340, minValue: 150, maxValue: 500, target: nil, action: nil)

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 300, height: 210),
                   styleMask: [.titled, .closable, .fullSizeContentView],
                   backing: .buffered, defer: false)
        title = "Captions Settings"
        center()
        let v = NSView()

        toggleBtn.target = self
        toggleBtn.action = #selector(toggleAct)
        toggleBtn.state = .on
        toggleBtn.frame = NSRect(x: 20, y: 160, width: 260, height: 24)
        v.addSubview(toggleBtn)

        styledBtn.target = self
        styledBtn.action = #selector(styledAct)
        styledBtn.state = .on
        styledBtn.frame = NSRect(x: 20, y: 130, width: 260, height: 24)
        v.addSubview(styledBtn)

        let wLabel = NSTextField(labelWithString: "Menu Bar Width:")
        wLabel.frame = NSRect(x: 20, y: 100, width: 120, height: 20)
        v.addSubview(wLabel)

        widthSlider.frame = NSRect(x: 140, y: 100, width: 140, height: 20)
        widthSlider.isContinuous = true
        widthSlider.target = self
        widthSlider.action = #selector(widthAct)
        v.addSubview(widthSlider)

        let l = NSTextField(labelWithString: "Sync Offset (ms):")
        l.frame = NSRect(x: 20, y: 70, width: 120, height: 20)
        v.addSubview(l)

        offsetField.frame = NSRect(x: 140, y: 70, width: 60, height: 22)
        offsetField.target = self
        offsetField.action = #selector(offsetAct)
        v.addSubview(offsetField)

        let info = NSTextField(labelWithString: "Positive = delay lyrics\nNegative = advance lyrics")
        info.font = .systemFont(ofSize: 11)
        info.textColor = .secondaryLabelColor
        info.frame = NSRect(x: 20, y: 10, width: 260, height: 40)
        v.addSubview(info)

        contentView = v
    }

    func show() { makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    func updateEnabled(_ e: Bool) { toggleBtn.state = e ? .on : .off }
    func updateSyncOffset(_ o: Int) { offsetField.stringValue = "\\(o)" }
    func updateStyledIcon(_ s: Bool) { styledBtn.state = s ? .on : .off }
    func updateWidth(_ w: CGFloat) { widthSlider.doubleValue = Double(w) }

    @objc private func toggleAct() { onToggleEnabled?(toggleBtn.state == .on) }
    @objc private func styledAct() { onToggleStyledIcon?(styledBtn.state == .on) }
    @objc private func offsetAct() { if let v = Int(offsetField.stringValue) { onSyncOffsetChanged?(v) } }
    @objc private func widthAct() { onWidthChanged?(CGFloat(widthSlider.doubleValue)) }
}
