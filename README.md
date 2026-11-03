# VietTelex

Bộ gõ tiếng Việt kiểu Telex cho macOS. Chạy nền trên thanh menu, không cần cài
làm input source của hệ thống.

## Yêu cầu

- macOS 13 trở lên, Apple Silicon
- Quyền Accessibility (app cần đọc sự kiện bàn phím để biến đổi ký tự)

## Cài đặt

**Từ file DMG:**

1. Mở `VietTelex-0.2.dmg`, kéo `VietTelex.app` vào `Applications`.
2. App chưa được notarize nên Gatekeeper sẽ chặn lần mở đầu. Gỡ chặn bằng một
   trong hai cách:

   ```sh
   xattr -dr com.apple.quarantine /Applications/VietTelex.app
   ```

   hoặc bấm chuột phải vào app → **Open** → **Open** lần nữa ở hộp thoại.

3. Mở app. macOS sẽ hỏi quyền Accessibility → **System Settings → Privacy &
   Security → Accessibility** → bật `VietTelex`. App tự nhận quyền sau khoảng
   hai giây, không cần khởi động lại.

**Từ mã nguồn:**

```sh
make install      # build và chép vào /Applications
```

## Sử dụng

Biểu tượng trên thanh menu hiển thị `VI` khi bộ gõ đang bật, `EN` khi tắt.

- **Bấm vào biểu tượng** → menu bật/tắt, mở Cài đặt, thoát.
- **Phím tắt mặc định `⌃⇧`** để chuyển qua lại Anh/Việt. Đổi trong **Cài đặt**:
  bấm vào ô ghi phím tắt rồi giữ tổ hợp muốn dùng.

Tổ hợp chỉ gồm phím bổ trợ (như `⌃⇧`) kích hoạt lúc bạn *nhả* phím và bị huỷ nếu
có phím thường bấm xen giữa, nên `⌃⇧S` vẫn là `⌃⇧S` chứ không chuyển bộ gõ.

## Cách gõ

| Gõ | Ra | Gõ | Ra |
|---|---|---|---|
| `s` | dấu sắc | `aa` | â |
| `f` | dấu huyền | `ee` | ê |
| `r` | dấu hỏi | `oo` | ô |
| `x` | dấu ngã | `aw` | ă |
| `j` | dấu nặng | `ow` | ơ |
| `z` | xoá dấu | `uw` | ư |
| | | `dd` | đ |

Gõ lại phím biến đổi để huỷ: `aaa` → `aa`, `ass` → `as`, `uww` → `uw`. Như Unikey,
sau khi huỷ thì chỉ phím dấu còn tác dụng, các chữ khác gõ tiếp nguyên văn và
những gì đang hiện được giữ nguyên: `serrver` → `server`, `massster` → `máster`.

Bỏ dấu theo **kiểu cũ**: `hòa`, `thủy`, `khỏe`.

### Gõ nhanh

Phím biến đổi có thể đến muộn — mọi thứ tự dưới đây đều ra cùng kết quả:

```
tieengs  = tienegs  = tiengse            → tiếng
nuwax    = nuawx    = nuaxw              → nữa
dduwowcj = duocwjd  = duwowcjd           → được
nguwowif = nguoiwf  = nguoifw            → người
```

Khi một phím `w` có nhiều chỗ áp dụng được, bộ gõ chọn chỗ tạo ra vần tiếng Việt
có thật: `nuawx` cho `nữa` (vần `ưa`) chứ không phải `nuặ` (vần `uă`).

### Kiểm tra chính tả

Chuỗi không phải âm tiết tiếng Việt được trả lại nguyên văn, nên gõ tiếng Anh
xen kẽ phần lớn vẫn ổn: `computer`, `keyboard`, `sweet`, `download`, `password`
đều giữ nguyên.

## Hạn chế đã biết

- **Ô nhập mật khẩu (Secure Input) không hoạt động.** Đây là giới hạn cố hữu của
  cơ chế CGEventTap, macOS chặn mọi app đọc phím trong ngữ cảnh này.
- **Vài từ tiếng Anh vẫn bị biến đổi** khi kết quả tình cờ là âm tiết tiếng Việt
  hợp lệ: `test` → `tét`, `data` → `dât`, `dad` → `đa`, `did` → `đi`. Không có
  quy tắc nào vừa giữ được chúng vừa cho `metej` → `mệt` và `daxd` → `đã`, vì
  hai nhóm có cấu trúc giống hệt nhau. Dùng phím tắt chuyển sang `EN` khi cần.
- **Chưa notarize**, xem phần Cài đặt.

## Phát triển

```sh
make build        # dựng build/VietTelex.app
make test         # chạy bộ test của engine
make run          # build rồi chạy
make dmg          # đóng gói build/VietTelex-0.2.dmg
make install      # chép vào /Applications
make reset-perm   # xoá mục Accessibility cũ, cấp lại quyền từ đầu
make clean
```

Makefile tự dò cert Apple Development qua `security find-identity`. Ký bằng cert
thật là bắt buộc: chữ ký ad-hoc đổi `cdhash` sau mỗi lần build nên macOS coi bản
mới là app khác và đòi cấp lại quyền Accessibility mỗi lần. Ghi đè bằng
`make build IDENTITY="..."`.

### Cấu trúc

```
Sources/
  Telex.swift          engine thuần, không phụ thuộc AppKit — toàn bộ quy tắc gõ
  KeyTap.swift         CGEventTap: bắt phím, gửi backspace + ký tự thay thế
  Hotkey.swift         mô hình phím tắt và lưu trữ
  SettingsWindow.swift cửa sổ Cài đặt và ô ghi phím tắt
  main.swift           NSApplication + biểu tượng thanh menu
Tests/main.swift       148 ca kiểm thử engine
```

Engine giữ chuỗi phím thô của từ đang gõ và **dựng lại toàn bộ từ sau mỗi phím**,
rồi so sánh với chuỗi cũ để biết cần gửi bao nhiêu `⌫` và chèn gì. Nhờ vậy mọi
quy tắc Telex là hàm thuần của chuỗi phím và test được không cần bàn phím thật.

Backspace nhắm vào *kết quả* chứ không lùi từng phím: lấy chuỗi hiện tại bỏ ký tự
cuối làm đích rồi tìm chuỗi phím dựng ra đúng đích đó. Vì thế `việt` xoá một phát
ra `việ` — giữ được dấu nặng — chứ không phải `viê`.
