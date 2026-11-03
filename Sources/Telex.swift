import Foundation

// Bộ chuyển đổi Telex thuần tuý: không phụ thuộc AppKit, dễ kiểm thử.
// Nguyên tắc: giữ nguyên chuỗi phím thô của từ đang gõ, dựng lại kết quả
// từ đầu sau mỗi phím. Nhờ vậy mọi quy tắc đều là hàm thuần của chuỗi phím.

enum Tone: Int {
    case none = 0, acute, grave, hook, tilde, dot
}

enum VMark {
    case none, hat, breve, horn, stroke
}

private struct VChar {
    var base: Character   // chữ gốc, luôn viết thường
    var mark: VMark
    var isUpper: Bool
    /// Ký tự do người dùng huỷ một biến đổi mà sinh ra ("ass" -> "as").
    /// Đây là ký tự thoát, không tính là bộ phận của âm tiết khi kiểm tra chính tả.
    var isEscape = false
}

private let markMap: [Character: [VMark: Character]] = [
    "a": [.none: "a", .hat: "â", .breve: "ă"],
    "e": [.none: "e", .hat: "ê"],
    "o": [.none: "o", .hat: "ô", .horn: "ơ"],
    "u": [.none: "u", .horn: "ư"],
    "d": [.none: "d", .stroke: "đ"],
]

// [sắc, huyền, hỏi, ngã, nặng]
private let toneMap: [Character: [Character]] = [
    "a": ["á", "à", "ả", "ã", "ạ"],
    "â": ["ấ", "ầ", "ẩ", "ẫ", "ậ"],
    "ă": ["ắ", "ằ", "ẳ", "ẵ", "ặ"],
    "e": ["é", "è", "ẻ", "ẽ", "ẹ"],
    "ê": ["ế", "ề", "ể", "ễ", "ệ"],
    "i": ["í", "ì", "ỉ", "ĩ", "ị"],
    "o": ["ó", "ò", "ỏ", "õ", "ọ"],
    "ô": ["ố", "ồ", "ổ", "ỗ", "ộ"],
    "ơ": ["ớ", "ờ", "ở", "ỡ", "ợ"],
    "u": ["ú", "ù", "ủ", "ũ", "ụ"],
    "ư": ["ứ", "ừ", "ử", "ữ", "ự"],
    "y": ["ý", "ỳ", "ỷ", "ỹ", "ỵ"],
]

private let toneKeys: [Character: Tone] = [
    "s": .acute, "f": .grave, "r": .hook, "x": .tilde, "j": .dot,
]

private let vowelBases: Set<Character> = ["a", "e", "i", "o", "u", "y"]

enum Telex {

    static func render(_ keys: [Character]) -> String {
        var chars: [VChar] = []
        var tone: Tone = .none

        func appendLiteral(_ k: Character, escape: Bool = false) {
            let lower = Character(k.lowercased())
            chars.append(VChar(base: lower, mark: .none,
                               isUpper: k.isUppercase, isEscape: escape))
        }

        // Huỷ một biến đổi đang hiện trên màn hình ("serr" -> "ser") nghĩa là người
        // dùng đang tự điều khiển dấu như Unikey. Từ đó chỉ phím dấu còn tác dụng;
        // gặp chữ khác thì giữ nguyên những gì đang hiện rồi gõ tiếp nguyên văn:
        // "serrver" -> "server", "massster" -> "máster". Còn nếu lúc huỷ màn hình
        // đang hiện nguyên văn ("clas") thì người dùng không thấy gì để huỷ, phím
        // đó là chữ thật và "class" vẫn là "class".
        var cancelled = false

        for (i, key) in keys.enumerated() {
            let lower = Character(key.lowercased())
            if cancelled, toneKeys[lower] == nil {
                return display(chars, tone: tone) + String(keys[i...])
            }
            let shown = isValidSyllable(chars)

            func cancel() {
                appendLiteral(key, escape: true)
                if shown { cancelled = true }
            }

            if let t = toneKeys[lower] {
                if vowelRun(chars) == nil {
                    appendLiteral(key)
                } else if tone == t {
                    tone = .none            // gõ lại phím dấu để huỷ
                    cancel()
                } else {
                    tone = t
                }
                continue
            }

            if lower == "z" {
                if tone != .none { tone = .none } else { appendLiteral(key) }
                continue
            }

            if lower == "w" {
                switch applyW(&chars, isUpper: key.isUppercase) {
                case .applied: break
                case .cancelled: cancel()
                case .literal: appendLiteral(key)
                }
                continue
            }

            if lower == "d" {
                if let last = chars.last, last.base == "d" {
                    if last.mark == .none {
                        chars[chars.count - 1].mark = .stroke
                    } else {
                        chars[chars.count - 1].mark = .none
                        cancel()
                    }
                    continue
                }
                // Gõ nhanh: phím đ có thể đến muộn ("duwowcjd" -> "được")
                if let target = deferredStroke(chars, isUpper: key.isUppercase) {
                    chars[target].mark = .stroke
                    continue
                }
            }

            if lower == "a" || lower == "e" || lower == "o" {
                if let last = chars.last, last.base == lower {
                    if last.mark == .none {
                        chars[chars.count - 1].mark = .hat
                        continue
                    } else if last.mark == .hat {
                        chars[chars.count - 1].mark = .none
                        cancel()
                        continue
                    }
                }
                // Gõ nhanh: phím dấu mũ có thể đến muộn ("tienegs" -> "tiếng")
                if let target = deferredHat(chars, base: lower, isUpper: key.isUppercase) {
                    chars[target].mark = .hat
                    continue
                }
            }

            appendLiteral(key)
        }

        // Không phải âm tiết tiếng Việt hợp lệ: trả lại đúng những phím đã gõ
        guard isValidSyllable(chars) else { return String(keys) }
        return display(chars, tone: tone)
    }

    private static func display(_ chars: [VChar], tone: Tone) -> String {
        let pos = tonePosition(chars)
        var out = ""
        for (i, c) in chars.enumerated() {
            out.append(compose(c, tone: i == pos ? tone : .none))
        }
        return out
    }

    // MARK: - Kiểm tra chính tả

    private static let onsets: Set<String> = [
        "", "b", "c", "ch", "d", "đ", "g", "gh", "gi", "h", "k", "kh", "l", "m",
        "n", "ng", "ngh", "nh", "p", "ph", "q", "qu", "r", "s", "t", "th", "tr", "v", "x",
    ]

    private static let codas: Set<String> = ["", "c", "ch", "m", "n", "ng", "nh", "p", "t"]

    /// Các vần tiếng Việt. Chỉ dùng để *chọn* cách hiểu một phím biến đổi khi có
    /// nhiều khả năng, không dùng để bác bỏ từ — nếu dùng để bác bỏ thì các trạng
    /// thái gõ dở như "đưo" trên đường tới "được" sẽ bị chặn nhầm.
    private static let nuclei: Set<String> = [
        "a", "ă", "â", "e", "ê", "i", "o", "ô", "ơ", "u", "ư", "y",
        "ai", "ao", "au", "ay", "âu", "ây", "eo", "êu", "ia", "iê", "iu",
        "oa", "oă", "oe", "oi", "ôi", "ơi", "oo", "ôô",
        "ua", "uâ", "uê", "ui", "uô", "uơ", "uy", "ưa", "ưi", "ươ", "ưu",
        "ya", "yê", "yu",
        "iêu", "oai", "oao", "oay", "oeo", "uai", "uay", "uây",
        "uôi", "ươi", "ươu", "uya", "uyê", "uyu", "yêu",
    ]

    private static let nucleusPrefixes: Set<String> = {
        var out: Set<String> = []
        for nucleus in nuclei {
            var prefix = ""
            for ch in nucleus {
                prefix.append(ch)
                out.insert(prefix)
            }
        }
        return out
    }()

    private static func nucleusText(_ all: [VChar]) -> String {
        let chars = all.filter { !$0.isEscape }
        guard let (s, e) = nucleusRange(chars) else { return "" }
        return chars[s...e].map(letter).joined()
    }

    /// Cụm nguyên âm mang vần, đã trừ "u" của "qu" và "i" của "gi" vì chúng
    /// thuộc phụ âm đầu: "quawng" -> vần "a" nên w cho ra "quăng", không phải "qưang".
    private static func nucleusRange(_ chars: [VChar]) -> (Int, Int)? {
        guard let run = vowelRun(chars) else { return nil }
        var s = run.0
        let e = run.1
        if e > s, chars[s].base == "u", s > 0, chars[s - 1].base == "q" { s += 1 }
        if e > s, chars[s].base == "i", s > 0, chars[s - 1].base == "g" { s += 1 }
        return (s, e)
    }

    /// Có thể là một âm tiết tiếng Việt đang gõ dở hay không.
    private static func isPlausible(_ chars: [VChar]) -> Bool {
        let nucleus = nucleusText(chars)
        if nucleus.isEmpty { return true }
        return isValidSyllable(chars) && nucleusPrefixes.contains(nucleus)
    }

    /// Chỉ kiểm tra cấu trúc: phụ âm đầu + đúng một cụm nguyên âm + phụ âm cuối.
    /// Không whitelist danh sách vần, để không chặn nhầm các trạng thái gõ dở
    /// như "đưo" trên đường tới "được".
    private static func isValidSyllable(_ all: [VChar]) -> Bool {
        let chars = all.filter { !$0.isEscape }
        guard let first = chars.firstIndex(where: { vowelBases.contains($0.base) }) else {
            return true          // chưa có nguyên âm thì chưa có gì để bác bỏ
        }
        var end = first
        while end + 1 < chars.count, vowelBases.contains(chars[end + 1].base) { end += 1 }

        let onset = chars[..<first].map(letter).joined()
        let coda = chars[(end + 1)...].map(letter).joined()
        return onsets.contains(onset) && codas.contains(coda)
    }

    private static func letter(_ c: VChar) -> String {
        String(markMap[c.base]?[c.mark] ?? c.base)
    }

    // MARK: - Phím w: ă / ơ / ư / ươ

    private enum WResult {
        case applied              // đã biến đổi một nguyên âm
        case cancelled            // huỷ biến đổi cũ, chữ "w" là ký tự thoát
        case literal              // không biến đổi được gì, "w" là chữ w bình thường
    }

    private static func applyW(_ chars: inout [VChar], isUpper: Bool) -> WResult {
        guard let (s, e) = nucleusRange(chars) else {
            // w mở đầu một từ thì cho ra "ư". Sau phụ âm thì để nguyên là "w",
            // nếu không "sweet" sẽ thành "sưêt".
            guard chars.isEmpty else { return .literal }
            chars.append(VChar(base: "u", mark: .horn, isUpper: isUpper))
            return .applied
        }

        if chars[e].mark == .breve || chars[e].mark == .horn {
            let isUoHorn = e > s && chars[e - 1].base == "u" && chars[e - 1].mark == .horn
                && chars[e].base == "o"
            chars[e].mark = .none
            if isUoHorn { chars[e - 1].mark = .none }
            return .cancelled
        }

        if let pair = (s..<e).last(where: {
            chars[$0].base == "u" && chars[$0].mark == .none
                && chars[$0 + 1].base == "o" && chars[$0 + 1].mark == .none
        }) {
            chars[pair].mark = .horn       // uo -> ươ, kể cả khi còn nguyên âm phía sau
            chars[pair + 1].mark = .horn
        } else if let target = wTarget(chars, from: s, to: e) {
            chars[target].mark = chars[target].base == "a" ? .breve : .horn
        } else {
            return .literal
        }
        return .applied
    }

    /// Nguyên âm nào nhận dấu móc/trăng. Khi có nhiều lựa chọn thì lấy lựa chọn
    /// tạo ra vần có thật: "nuawx" -> "nữa" (vần "ưa") chứ không phải "nuặ" (vần "uă").
    private static func wTarget(_ chars: [VChar], from s: Int, to e: Int) -> Int? {
        let candidates = (s...e).filter { chars[$0].mark == .none && "aou".contains(chars[$0].base) }
        guard !candidates.isEmpty else { return nil }
        for i in candidates.reversed() {
            var trial = chars
            trial[i].mark = trial[i].base == "a" ? .breve : .horn
            if nucleusPrefixes.contains(nucleusText(trial)) { return i }
        }
        return candidates.last
    }

    /// Chữ d trong phụ âm đầu nhận nét gạch khi phím d đến muộn. Cũng chỉ nhận
    /// khi gõ ra chữ "d" không tạo được âm tiết hợp lệ — chữ d không bao giờ là
    /// phụ âm cuối hợp lệ nên điều kiện này gần như luôn đúng ở cuối từ.
    private static func deferredStroke(_ chars: [VChar], isUpper: Bool) -> Int? {
        guard let first = chars.firstIndex(where: { vowelBases.contains($0.base) }) else { return nil }
        guard let target = chars[..<first].lastIndex(where: { $0.base == "d" && $0.mark == .none })
        else { return nil }
        var literal = chars
        literal.append(VChar(base: "d", mark: .none, isUpper: isUpper))
        return isPlausible(literal) ? nil : target
    }

    /// Nguyên âm trong vần nhận dấu mũ khi phím a/e/o đến muộn. Chỉ nhận khi việc
    /// gõ ra chữ cái đó không tạo được âm tiết hợp lệ, để "khoeo" vẫn là "khoeo".
    private static func deferredHat(_ chars: [VChar], base: Character, isUpper: Bool) -> Int? {
        guard let (s, e) = nucleusRange(chars) else { return nil }
        guard let target = (s...e).last(where: { chars[$0].base == base && chars[$0].mark == .none })
        else { return nil }
        var literal = chars
        literal.append(VChar(base: base, mark: .none, isUpper: isUpper))
        return isPlausible(literal) ? nil : target
    }

    // MARK: - Vị trí bỏ dấu (kiểu cũ: hòa, thủy, khỏe)

    private static func tonePosition(_ chars: [VChar]) -> Int? {
        guard let (s, e) = nucleusRange(chars) else { return nil }

        let marked = (s...e).filter { chars[$0].mark != .none }
        if let last = marked.last { return last }

        if e < chars.count - 1 { return e }        // có phụ âm cuối

        let count = e - s + 1
        if count >= 3 { return s + 1 }
        return s
    }

    private static func vowelRun(_ chars: [VChar]) -> (Int, Int)? {
        guard let e = chars.lastIndex(where: { vowelBases.contains($0.base) }) else { return nil }
        var s = e
        while s > 0, vowelBases.contains(chars[s - 1].base) { s -= 1 }
        return (s, e)
    }

    private static func compose(_ c: VChar, tone: Tone) -> Character {
        var ch = markMap[c.base]?[c.mark] ?? c.base
        if tone != .none, let variants = toneMap[ch] {
            ch = variants[tone.rawValue - 1]
        }
        return c.isUpper ? Character(String(ch).uppercased()) : ch
    }
}

// MARK: - Trạng thái từ đang gõ

struct Edit: Equatable {
    let backspaces: Int
    let insert: String
}

final class TelexEngine {
    private var keys: [Character] = []
    private var output = ""

    var isEmpty: Bool { keys.isEmpty }

    func reset() {
        keys.removeAll()
        output = ""
    }

    /// Trả về nil nếu phím có thể đi thẳng ra ứng dụng mà không cần sửa gì.
    func input(_ ch: Character) -> Edit? {
        let newKeys = keys + [ch]
        let newOutput = Telex.render(newKeys)
        defer {
            keys = newKeys
            output = newOutput
        }
        if newOutput == output + String(ch) { return nil }
        return diff(from: output, to: newOutput)
    }

    /// Xoá đúng một ký tự đang hiển thị, không phải một phím đã gõ:
    /// "á" do hai phím a+s tạo ra nhưng vẫn phải biến mất sau một phát xoá.
    /// Trả về nil nếu phím xoá có thể đi thẳng ra ứng dụng.
    func backspace() -> Edit? {
        guard !keys.isEmpty, !output.isEmpty else {
            reset()
            return nil
        }
        let target = String(output.dropLast())

        guard let resolved = keysRendering(target) else {
            reset()
            return nil
        }
        keys = resolved
        let edit = diff(from: output, to: target)
        output = target
        return edit == Edit(backspaces: 1, insert: "") ? nil : edit
    }

    /// Tìm chuỗi phím dựng ra đúng `target`. Ưu tiên cắt bớt ở cuối; nếu không
    /// được thì bỏ đúng một phím ở giữa, để các phím dấu gõ sau nó vẫn còn tác
    /// dụng ("việt" xoá một phát ra "việ" chứ không phải "viê").
    private func keysRendering(_ target: String) -> [Character]? {
        for k in 1...keys.count {
            let candidate = Array(keys.dropLast(k))
            if Telex.render(candidate) == target { return candidate }
        }
        for i in stride(from: keys.count - 1, through: 0, by: -1) {
            var candidate = keys
            candidate.remove(at: i)
            if Telex.render(candidate) == target { return candidate }
        }
        return nil
    }

    private func diff(from old: String, to new: String) -> Edit {
        let a = Array(old), b = Array(new)
        var p = 0
        while p < min(a.count, b.count), a[p] == b[p] { p += 1 }
        return Edit(backspaces: a.count - p, insert: String(b[p...]))
    }
}
