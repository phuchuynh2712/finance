# Login & Sign up — Handoff package

Nguồn: `Finance App Mockups.dc.html`, màn 6–9 (Đăng nhập / Đăng ký, sáng + tối).
Dùng cùng với `theme-tokens.json` (copy đầy đủ ở đây) và `icons.json` (chỉ icon 2 màn này).

## Nội dung
- `login-signup-spec.md` — spec chi tiết từng element: kích thước, margin, padding, font, màu, align — cả sáng & tối.
- `icons.json` — 5 icon dùng trong 2 màn này, kèm mapping sang package `lucide_icons` cho Flutter.
- `theme-tokens.json` — toàn bộ token màu/spacing/type/radius/motion của app (copy từ `handoff/`).
- `app-icon-khai-tam.svg` — icon app dùng ở màn Đăng nhập (nền vàng, tạm dùng — team đang cân nhắc đổi sang xanh lá, xem `app-icon-khai-tam-green.svg` bản thay thế nếu cần).

## Ghi chú dựng bằng Flutter
- Frame điện thoại 390×844 trong mockup CHỈ để trình bày — không phải UI thật. Vùng nội dung thật là toàn bộ chiều rộng màn hình (safe area), Claude Code cần tự thêm status bar / notch theo `SafeArea` của Flutter, không hard-code offset của mockup.
- Toàn bộ đơn vị trong spec là **logical pixels** ở thiết kế tham chiếu rộng 390px (chuẩn iPhone) — quy đổi trực tiếp sang `double` trong Flutter (1px thiết kế = 1 logical pixel), không cần scale.
- Font UI: **Lexend** (Google Fonts) — cần thêm vào `pubspec.yaml` hoặc dùng `google_fonts` package.
- Input trong mockup là hình chữ nhật tĩnh minh hoạ placeholder — dựng thành `TextFormField` thật với style tương ứng.
- Theme sáng/tối chuyển qua `ThemeData`/`ThemeExtension` dùng đúng token trong `theme-tokens.json`, không hard-code hex trong widget.
