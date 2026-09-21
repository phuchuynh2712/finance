# Thu nhập — Handoff package

Nguồn: `Finance App Mockups.dc.html`, màn 3a (sáng) và màn 13 (tối). Mở từ nút "Thu nhập" ở màn Thu chi (hub) — không có bottom nav.

## Nội dung
- `thu-nhap-spec.md` — spec chi tiết từng element: kích thước, margin, padding, font, màu, align — sáng & tối.
- `icons.json` — icon dùng trong màn này, kèm mapping Flutter (`lucide_icons`).
- `theme-tokens.json` — toàn bộ token màu/spacing/type/radius/motion.

## Ghi chú dựng Flutter
- Frame điện thoại 390×844 chỉ để trình bày — vùng nội dung thật dùng `SafeArea`.
- Đơn vị spec = logical pixel ở thiết kế tham chiếu rộng 390px, quy đổi 1:1 sang Flutter `double`.
- Font UI: **Lexend** (`google_fonts` package).
- Danh sách nguồn thu nhập (`incomeSources`) là dữ liệu động — dựng `ListView`/`Column` + item tái sử dụng, không hard-code 2 dòng mẫu.
- Icon từng nguồn (`s.icon`) chọn theo loại nguồn thu (lương, thu phụ...) — xem `icons-used.json` gốc project cho danh sách icon Lucide đầy đủ của app.
- Nút "Lưu thu nhập" dùng `margin-top: auto` — luôn dính đáy vùng scroll (đẩy xuống dưới nếu danh sách ngắn).
