import Foundation

var failures = 0
var checks = 0

func expect(_ input: String, _ want: String, file: StaticString = #file, line: UInt = #line) {
    checks += 1
    let got = Telex.render(Array(input))
    if got != want {
        failures += 1
        print("FAIL  \"\(input)\" -> \"\(got)\"  (mong đợi \"\(want)\")  [line \(line)]")
    }
}

// Dấu thanh cơ bản
expect("as", "á")
expect("af", "à")
expect("ar", "ả")
expect("ax", "ã")
expect("aj", "ạ")

// Huỷ dấu
expect("ass", "as")        // gõ lại phím dấu -> chữ thường
expect("asf", "à")         // đổi dấu
expect("asz", "a")         // z xoá dấu
expect("az", "az")         // z khi chưa có dấu -> chữ z

// Nguyên âm biến đổi
expect("aa", "â")
expect("aaa", "aa")
expect("ee", "ê")
expect("oo", "ô")
expect("aw", "ă")
expect("ow", "ơ")
expect("uw", "ư")
expect("uww", "uw")
expect("dd", "đ")
expect("ddd", "dd")
expect("w", "ư")

// Từ thật
expect("vieetj", "việt")
expect("tieengs", "tiếng")
expect("ddax", "đã")
expect("dduowcj", "được")
expect("dduwowcj", "được")
expect("cuowif", "cười")
expect("hoaf", "hòa")
expect("thuyr", "thủy")
expect("khoer", "khỏe")
expect("quar", "quả")
expect("gias", "giá")
expect("gif", "gì")
expect("ngoaif", "ngoài")
expect("toans", "toán")
expect("muaf", "mùa")
expect("kiaf", "kìa")
expect("hocj", "học")
expect("hoocj", "hộc")
expect("nguwowif", "người")

// Hoa
expect("Vieetj", "Việt")
expect("DDaj", "Đạ")
expect("AA", "Â")

// Chuỗi không phải tiếng Việt vẫn phải ổn định
expect("hello", "hello")
// Kiểm tra chính tả: chuỗi không phải âm tiết tiếng Việt được trả về nguyên văn
expect("computer", "computer")   // hai cụm nguyên âm
expect("restore", "restore")
expect("keyboard", "keyboard")
expect("monster", "monster")
expect("start", "start")         // phụ âm đầu "st" không hợp lệ
expect("first", "first")         // phụ âm đầu "f" không hợp lệ
expect("class", "class")         // phụ âm đầu "cl" không hợp lệ

// Vẫn giữ hành vi cũ khi từ chưa có nguyên âm
expect("ddd", "dd")

// Hạn chế còn lại: kết quả tình cờ là âm tiết hợp lệ thì vẫn được giữ (Unikey cũng vậy)
expect("test", "tét")
expect("cats", "cát")

// Gõ nhanh: phím biến đổi đến muộn vẫn phải ra đúng chữ
expect("tienegs", "tiếng")
expect("tiengse", "tiếng")
expect("vietej", "việt")
expect("vietje", "việt")
expect("metej", "mệt")
expect("quene", "quên")
expect("nuawx", "nữa")          // "ưa" là vần có thật, "uă" thì không
expect("nuaxw", "nữa")
expect("guiwr", "gửi")
expect("guirw", "gửi")
expect("duocwj", "dược")
expect("dduocwj", "được")
expect("nguoiwf", "người")      // cặp u+o thành ươ dù còn nguyên âm phía sau
expect("nguoifw", "người")
expect("truongwf", "trường")
expect("hoacwj", "hoặc")
expect("ruouwj", "rượu")
expect("cuusw", "cứu")
expect("dieeuf", "diều")

// Phím đ cũng có thể đến muộn
expect("duwowcjd", "được")
expect("duocwjd", "được")
expect("dieeufd", "điều")
expect("daxd", "đã")

// "u" của "qu" và "i" của "gi" thuộc phụ âm đầu nên không nhận dấu
expect("quawng", "quăng")       // không phải "qưang"
expect("quangw", "quăng")
expect("quowr", "quở")
expect("khuyeenr", "khuyển")
expect("gias", "giá")

// Chữ w không biến đổi được là chữ w bình thường, không phải ký tự thoát
expect("sweet", "sweet")
expect("switch", "switch")
expect("twenty", "twenty")
expect("software", "software")
expect("w", "ư")                // w mở đầu từ vẫn cho ra ư
expect("tuwr", "tử")

// Tiếng Anh thường gặp vẫn giữ nguyên
for word in ["hello", "world", "screen", "browser", "folder", "secret", "design",
             "between", "water", "later", "update", "window", "download",
             "market", "server", "client", "download", "dashboard", "default",
             "decoded", "david", "dried", "demand", "depend", "divided", "dedicated",
             "board", "word", "field", "build", "should", "would", "guard", "hard"] {
    expect(word, word)
}

// Gõ kiểu Unikey: gõ đôi phím để huỷ biến đổi đang hiện, rồi gõ tiếp tiếng Anh.
expect("serrver", "server")
expect("serrvice", "service")
expect("masster", "master")
expect("assv", "asv")
expect("aaav", "aav")
// Đã huỷ dấu thì giữ nguyên những gì đang hiện, không tự khôi phục về phím thô
expect("massster", "máster")
expect("password", "pasword")
// Phím đôi mà lúc đó màn hình đang hiện nguyên văn thì vẫn là chữ thật
for word in ["success", "address", "class", "stress", "process", "access"] {
    expect(word, word)
}

// Hạn chế cố hữu của tính năng gõ nhanh: "data" và "metej" có cấu trúc giống hệt
// nhau (phụ âm + nguyên âm + phụ âm cuối + nguyên âm lặp lại), nên không thể vừa
// cho "metej" -> "mệt" vừa giữ "data". Unikey cũng vậy.
expect("data", "dât")
// ...nhưng gõ lại phím dấu mũ thì huỷ được, như "aaa" -> "aa"
expect("dataa", "data")
expect("mana", "mân")
expect("manaa", "mana")
expect("tienee", "tiene")
expect("maana", "mana")
expectScreen("mana") { $0.type("manaa") }

// Cùng lý do với phím đ đến muộn: các từ d…d ngắn mà phần giữa là âm tiết hợp lệ
expect("dad", "đa")
expect("did", "đi")
expect("deed", "đê")

// Engine: sinh lệnh sửa
func expectEdits(_ input: String, _ want: [String], line: UInt = #line) {
    let e = TelexEngine()
    var got: [String] = []
    for ch in input {
        if let edit = e.input(ch) {
            got.append("<\(edit.backspaces)|\(edit.insert)>")
        } else {
            got.append(String(ch))
        }
    }
    if got != want {
        failures += 1
        print("FAIL  edits \"\(input)\" -> \(got)  (mong đợi \(want))  [line \(line)]")
    }
}

expectEdits("as", ["a", "<1|á>"])
expectEdits("dd", ["d", "<1|đ>"])
expectEdits("vieetj", ["v", "i", "e", "<1|ê>", "t", "<2|ệt>"])

// Backspace: mô phỏng nội dung thật sự hiện trên màn hình
final class Screen {
    private let engine = TelexEngine()
    var text = ""

    func type(_ input: String) {
        for ch in input {
            if let edit = engine.input(ch) {
                text = String(text.dropLast(edit.backspaces)) + edit.insert
            } else {
                text.append(ch)
            }
        }
    }

    func backspace(_ times: Int = 1) {
        for _ in 0..<times {
            if let edit = engine.backspace() {
                text = String(text.dropLast(edit.backspaces)) + edit.insert
            } else {
                text = String(text.dropLast())
            }
        }
    }
}

func expectScreen(_ want: String, line: UInt = #line, _ body: (Screen) -> Void) {
    checks += 1
    let screen = Screen()
    body(screen)
    if screen.text != want {
        failures += 1
        print("FAIL  màn hình \"\(screen.text)\"  (mong đợi \"\(want)\")  [line \(line)]")
    }
}

// Một phát xoá = một ký tự biến mất, kể cả ký tự có dấu
expectScreen("") { $0.type("as"); $0.backspace() }
expectScreen("") { $0.type("ddax"); $0.backspace(3) }
expectScreen("") { $0.type("aas"); $0.backspace() }         // "ấ" là một ký tự
expectScreen("việ") { $0.type("vieetj"); $0.backspace() }
expectScreen("đượ") { $0.type("dduwowcj"); $0.backspace() }

// Xoá xong gõ tiếp vẫn còn hiệu lực bỏ dấu
expectScreen("viện") { $0.type("vieetj"); $0.backspace(); $0.type("n") }
expectScreen("được") { $0.type("dduwowcj"); $0.backspace(); $0.type("c") }

// Màn hình thật khi gõ kiểu Unikey
expectScreen("server") { $0.type("serrver") }
expectScreen("máster") { $0.type("massster") }

// Xoá hết rồi gõ lại từ đầu
expectScreen("hòa") { $0.type("as"); $0.backspace(); $0.type("hoaf") }

if failures == 0 {
    print("Tất cả \(checks) ca test đều pass ✓")
} else {
    print("\(failures) test thất bại")
    exit(1)
}
