import Cocoa

/// Phím tắt chuyển Anh/Việt. keyCode == nil nghĩa là tổ hợp chỉ gồm phím bổ trợ
/// (ví dụ Ctrl+Shift), loại mà Carbon RegisterEventHotKey không đăng ký được.
struct Hotkey: Equatable {
    var keyCode: UInt16?
    var modifiers: CGEventFlags

    static let relevantMask: CGEventFlags = [.maskControl, .maskShift, .maskAlternate, .maskCommand]
    static let defaultValue = Hotkey(keyCode: nil, modifiers: [.maskControl, .maskShift])

    var isValid: Bool {
        if keyCode == nil { return modifiers.rawValue.nonzeroBitCount >= 2 }
        return !modifiers.isEmpty
    }

    var display: String {
        var s = ""
        if modifiers.contains(.maskControl) { s += "⌃" }
        if modifiers.contains(.maskAlternate) { s += "⌥" }
        if modifiers.contains(.maskShift) { s += "⇧" }
        if modifiers.contains(.maskCommand) { s += "⌘" }
        if let keyCode { s += Hotkey.keyName(keyCode) }
        return s
    }

    // MARK: - Lưu trữ

    private static let codeKey = "hotkey.keyCode"
    private static let modsKey = "hotkey.modifiers"

    static func load() -> Hotkey {
        let d = UserDefaults.standard
        guard d.object(forKey: modsKey) != nil else { return .defaultValue }
        let raw = d.integer(forKey: codeKey)
        let hotkey = Hotkey(keyCode: raw < 0 ? nil : UInt16(raw),
                            modifiers: CGEventFlags(rawValue: UInt64(d.integer(forKey: modsKey))))
        return hotkey.isValid ? hotkey : .defaultValue
    }

    func save() {
        let d = UserDefaults.standard
        d.set(keyCode.map(Int.init) ?? -1, forKey: Hotkey.codeKey)
        d.set(Int(modifiers.rawValue), forKey: Hotkey.modsKey)
    }

    // MARK: - Tên phím

    private static let names: [UInt16: String] = [
        0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H", 34: "I",
        38: "J", 40: "K", 37: "L", 46: "M", 45: "N", 31: "O", 35: "P", 12: "Q",
        15: "R", 1: "S", 17: "T", 32: "U", 9: "V", 13: "W", 7: "X", 16: "Y", 6: "Z",
        29: "0", 18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7",
        28: "8", 25: "9",
        49: "Space", 36: "↩", 48: "⇥", 53: "⎋", 51: "⌫",
        27: "-", 24: "=", 33: "[", 30: "]", 41: ";", 39: "'", 43: ",", 47: ".", 44: "/", 50: "`",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    static func keyName(_ code: UInt16) -> String {
        names[code] ?? "#\(code)"
    }
}
