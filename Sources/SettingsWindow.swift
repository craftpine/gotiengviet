import Cocoa

/// Ô ghi phím tắt: bấm vào rồi giữ tổ hợp muốn dùng.
final class HotkeyRecorder: NSView {
    var onCommit: ((Hotkey) -> Void)?
    var onRecordingChange: ((Bool) -> Void)?

    private var hotkey: Hotkey
    private var recording = false { didSet { onRecordingChange?(recording); needsDisplay = true } }
    private var heldModifiers: CGEventFlags = []

    init(hotkey: Hotkey) {
        self.hotkey = hotkey
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        recording = true
        heldModifiers = []
    }

    override func resignFirstResponder() -> Bool {
        recording = false
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard recording else { return super.keyDown(with: event) }
        if event.keyCode == 53 {                     // Esc: huỷ
            recording = false
            return
        }
        let mods = Hotkey.relevantMask.intersection(CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue)))
        let candidate = Hotkey(keyCode: event.keyCode, modifiers: mods)
        guard candidate.isValid else { NSSound.beep(); return }
        commit(candidate)
    }

    override func flagsChanged(with event: NSEvent) {
        guard recording else { return super.flagsChanged(with: event) }
        let mods = Hotkey.relevantMask.intersection(CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue)))
        if mods.rawValue.nonzeroBitCount >= heldModifiers.rawValue.nonzeroBitCount {
            heldModifiers = mods
            needsDisplay = true
        } else if mods.isEmpty {
            // Nhả hết phím: chốt tổ hợp chỉ gồm phím bổ trợ
            let candidate = Hotkey(keyCode: nil, modifiers: heldModifiers)
            if candidate.isValid { commit(candidate) } else { heldModifiers = [] ; needsDisplay = true }
        }
    }

    private func commit(_ new: Hotkey) {
        hotkey = new
        recording = false
        heldModifiers = []
        onCommit?(new)
        needsDisplay = true
    }

    func setHotkey(_ new: Hotkey) {
        hotkey = new
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let box = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: box, xRadius: 6, yRadius: 6)
        (recording ? NSColor.controlAccentColor.withAlphaComponent(0.12)
                   : NSColor.controlBackgroundColor).setFill()
        path.fill()
        (recording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = recording ? 2 : 1
        path.stroke()

        let text: String
        if recording {
            let held = Hotkey(keyCode: nil, modifiers: heldModifiers).display
            text = held.isEmpty ? "Giữ tổ hợp phím…" : held
        } else {
            text = hotkey.display
        }
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .medium),
            .foregroundColor: recording ? NSColor.secondaryLabelColor : NSColor.labelColor,
            .paragraphStyle: style,
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        (text as NSString).draw(in: NSRect(x: 0, y: (bounds.height - size.height) / 2,
                                           width: bounds.width, height: size.height),
                                withAttributes: attrs)
    }
}

final class SettingsWindowController: NSWindowController {
    private let recorder: HotkeyRecorder
    var onHotkeyChange: ((Hotkey) -> Void)?
    var onRecordingChange: ((Bool) -> Void)?

    init(hotkey: Hotkey) {
        recorder = HotkeyRecorder(hotkey: hotkey)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 150),
                              styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "Cài đặt"
        window.isReleasedWhenClosed = false
        super.init(window: window)

        let content = window.contentView!

        let label = NSTextField(labelWithString: "Phím tắt chuyển Anh/Việt:")
        label.frame = NSRect(x: 20, y: 96, width: 200, height: 20)
        content.addSubview(label)

        recorder.frame = NSRect(x: 224, y: 90, width: 110, height: 30)
        recorder.onCommit = { [weak self] in
            $0.save()
            self?.onHotkeyChange?($0)
        }
        recorder.onRecordingChange = { [weak self] in self?.onRecordingChange?($0) }
        content.addSubview(recorder)

        let reset = NSButton(title: "Đặt lại", target: self, action: #selector(resetHotkey))
        reset.bezelStyle = .rounded
        reset.frame = NSRect(x: 338, y: 89, width: 66, height: 32)
        content.addSubview(reset)

        let hint = NSTextField(wrappingLabelWithString:
            "Bấm vào ô rồi giữ tổ hợp muốn dùng. Tổ hợp chỉ gồm phím bổ trợ (như ⌃⇧) "
            + "sẽ kích hoạt khi bạn nhả phím, nên không xung đột với ⌃⇧+phím.")
        hint.frame = NSRect(x: 20, y: 20, width: 360, height: 56)
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        content.addSubview(hint)

        window.center()
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func resetHotkey() {
        Hotkey.defaultValue.save()
        recorder.setHotkey(.defaultValue)
        onHotkeyChange?(.defaultValue)
    }
}
