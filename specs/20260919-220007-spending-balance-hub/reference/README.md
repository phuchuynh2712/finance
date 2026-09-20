# Thu chi (hub) — Handoff package

Nguồn: `Finance App Mockups.dc.html`, màn 3 (sáng) và màn 11 (tối).
Dùng cùng `theme-tokens.json` (copy đầy đủ ở đây) và `icons.json` (icon riêng màn này).

## Nội dung
- `thu-chi-spec.md` — spec chi tiết từng element: kích thước, margin, padding, font, màu, align — sáng & tối.
- `icons.json` — icon dùng trong màn này, kèm mapping Flutter (`lucide_icons`).
- `theme-tokens.json` — toàn bộ token màu/spacing/type/radius/motion.

## Ghi chú dựng Flutter
- Frame điện thoại 390×844 chỉ để trình bày — vùng nội dung thật dùng `SafeArea`.
- Đơn vị spec = logical pixel ở thiết kế tham chiếu rộng 390px, quy đổi 1:1 sang Flutter `double`.
- Font UI: **Lexend** (`google_fonts` package).
- Đây là màn hiển thị **số dư thực tế** từng khoản (khác màn Kiểm soát chi tiêu chỉ định nghĩa công thức) — `g.balanceFmt` màu xanh khi dương, đỏ khi âm quỹ (`g.barColor`).
- 2 nút "Thu nhập"/"Chi tiêu" điều hướng sang 2 màn con riêng (đã có package/spec ở màn Đăng nhập/Đăng ký trước — nếu cần spec 2 màn con này, yêu cầu riêng).
- Danh sách nhóm (`groups`/`children`) là dữ liệu động — dựng `ListView` + widget item tái sử dụng.
