import Cocoa

/// Đánh dấu các sự kiện do chính app sinh ra để không xử lý lại chúng.
private let selfMarker: Int64 = 0x56_54_31

final class KeyTap {
    private var machPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let engine = TelexEngine()
    private let source = CGEventSource(stateID: .privateState)

    var enabled = true {
        didSet { engine.reset() }
    }

    var hotkey = Hotkey.load()
    var onToggle: (() -> Void)?

    /// Tổ hợp phím bổ trợ đang giữ đúng bằng phím tắt và chưa bị phím thường nào cắt ngang.
    private var armed = false

    func start() -> Bool {
        let mask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            let tap = Unmanaged<KeyTap>.fromOpaque(refcon!).takeUnretainedValue()
            return tap.handle(proxy: proxy, type: type, event: event)
        }

        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                           place: .headInsertEventTap,
                                           options: .defaultTap,
                                           eventsOfInterest: CGEventMask(mask),
                                           callback: callback,
                                           userInfo: Unmanaged.passUnretained(self).toOpaque())
        else { return false }

        machPort = port
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return true
    }

    // MARK: - Xử lý sự kiện

    private func handle(proxy: CGEventTapProxy,
                        type: CGEventType,
                        event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let port = machPort { CGEvent.tapEnable(tap: port, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        if event.getIntegerValueField(.eventSourceUserData) == selfMarker {
            return Unmanaged.passUnretained(event)
        }

        let flags = event.flags.intersection(Hotkey.relevantMask)
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        switch type {
        case .flagsChanged:
            engine.reset()
            checkModifierHotkey(flags)
            return Unmanaged.passUnretained(event)
        case .leftMouseDown, .rightMouseDown:
            armed = false
            engine.reset()
            return Unmanaged.passUnretained(event)
        case .keyDown:
            armed = false
            if let code = hotkey.keyCode, UInt16(keyCode) == code, flags == hotkey.modifiers {
                onToggle?()
                return nil
            }
        default:
            return Unmanaged.passUnretained(event)
        }

        guard enabled else { return Unmanaged.passUnretained(event) }

        // Mọi tổ hợp có Command/Control/Option đều ngắt từ đang gõ
        if flags.contains(.maskCommand) || flags.contains(.maskControl)
            || flags.contains(.maskAlternate) {
            engine.reset()
            return Unmanaged.passUnretained(event)
        }

        if keyCode == 51 {                      // Delete
            guard let edit = engine.backspace() else {
                return Unmanaged.passUnretained(event)
            }
            emit(edit, proxy: proxy)
            return nil
        }

        guard let ch = character(of: event), ch.isLetter, ch.isASCII else {
            engine.reset()
            return Unmanaged.passUnretained(event)
        }

        guard let edit = engine.input(ch) else {
            return Unmanaged.passUnretained(event)
        }
        emit(edit, proxy: proxy)
        return nil
    }

    /// Phím tắt chỉ gồm phím bổ trợ: kích hoạt lúc nhả ra, và chỉ khi
    /// không có phím thường nào được bấm trong lúc giữ.
    private func checkModifierHotkey(_ flags: CGEventFlags) {
        guard hotkey.keyCode == nil, hotkey.isValid else { return }
        if flags == hotkey.modifiers {
            armed = true
        } else if armed {
            armed = false
            if !flags.isSuperset(of: hotkey.modifiers) { onToggle?() }
        }
    }

    private func character(of event: CGEvent) -> Character? {
        var length = 0
        var buffer = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4,
                                       actualStringLength: &length,
                                       unicodeString: &buffer)
        guard length == 1 else { return nil }
        return Character(UnicodeScalar(buffer[0]) ?? " ")
    }

    // MARK: - Gửi ký tự thay thế

    private func emit(_ edit: Edit, proxy: CGEventTapProxy) {
        var backspaces = edit.backspaces
        // Thanh địa chỉ trình duyệt bôi đen phần gợi ý tự hoàn thành sau con trỏ
        // ("ma[il.google.com]"), phát xoá đầu tiên chỉ xoá phần đó nên "mas" thành
        // "maá". Gõ một ký tự đệm để thay phần bôi đen rồi xoá luôn nó.
        if backspaces > 0, isBrowserFrontmost() {
            post(keyDown: true, virtualKey: 0, text: "\u{202F}", proxy: proxy)
            post(keyDown: false, virtualKey: 0, text: "\u{202F}", proxy: proxy)
            backspaces += 1
        }
        for _ in 0..<backspaces {
            post(keyDown: true, virtualKey: 51, text: nil, proxy: proxy)
            post(keyDown: false, virtualKey: 51, text: nil, proxy: proxy)
        }
        if !edit.insert.isEmpty {
            post(keyDown: true, virtualKey: 0, text: edit.insert, proxy: proxy)
            post(keyDown: false, virtualKey: 0, text: edit.insert, proxy: proxy)
        }
    }

    private func post(keyDown: Bool, virtualKey: CGKeyCode, text: String?, proxy: CGEventTapProxy) {
        guard let event = CGEvent(keyboardEventSource: source,
                                  virtualKey: virtualKey,
                                  keyDown: keyDown) else { return }
        if let text {
            var utf16 = Array(text.utf16)
            event.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
        }
        event.setIntegerValueField(.eventSourceUserData, value: selfMarker)
        event.tapPostEvent(proxy)
    }

    private static let browsers: Set<String> = [
        "com.google.Chrome", "com.google.Chrome.canary", "com.apple.Safari",
        "company.thebrowser.Browser", "com.microsoft.edgemac", "com.brave.Browser",
        "org.mozilla.firefox", "com.operasoftware.Opera", "com.vivaldi.Vivaldi",
        "org.chromium.Chromium",
    ]

    private func isBrowserFrontmost() -> Bool {
        guard let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return false }
        return Self.browsers.contains(id)
    }
}
