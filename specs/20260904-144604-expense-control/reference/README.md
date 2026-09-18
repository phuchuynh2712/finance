# Kiểm soát chi tiêu — Handoff package

Nguồn: `Finance App Mockups.dc.html`, màn 2 (sáng) và màn 12 (tối).
Dùng cùng `theme-tokens.json` (copy đầy đủ ở đây) và `icons.json` (icon riêng màn này).

## Nội dung
- `kiem-soat-spec.md` — spec chi tiết từng element: kích thước, margin, padding, font, màu, align — sáng & tối.
- `icons.json` — icon dùng trong màn này, kèm mapping Flutter (`lucide_icons`).
- `theme-tokens.json` — toàn bộ token màu/spacing/type/radius/motion.

## Ghi chú dựng Flutter
- Frame điện thoại 390×844 trong mockup chỉ để trình bày — vùng nội dung thật dùng `SafeArea`.
- Đơn vị spec = logical pixel ở thiết kế tham chiếu rộng 390px, quy đổi 1:1 sang Flutter `double`.
- Font UI: **Lexend** (Google Fonts / `google_fonts` package).
- Danh sách nhóm/khoản (`groups`/`children`) là dữ liệu động — dựng `ListView` + widget item tái sử dụng, không hard-code.
- Trạng thái mở/đóng nhóm (`planExpanded`) là state cục bộ — dùng `AnimatedCrossFade`/`ExpansionTile` tuỳ ý, miễn giữ đúng kích thước/khoảng cách khi mở.
