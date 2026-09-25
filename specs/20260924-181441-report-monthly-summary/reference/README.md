# Báo cáo — Handoff package

Nguồn: `Finance App Mockups.dc.html`, màn 4 (sáng) và màn 16 (tối). Có bottom nav, tab "Báo cáo" active.

## Nội dung
- `bao-cao-spec.md` — spec chi tiết từng element, sáng & tối.
- `icons.json` — icon dùng trong màn này, kèm mapping Flutter.
- `theme-tokens.json` — toàn bộ token màu/spacing/type/radius/motion.

## Ghi chú dựng Flutter
- Frame điện thoại 390×844 chỉ để trình bày — vùng nội dung thật dùng `SafeArea`.
- Đơn vị spec = logical pixel ở thiết kế tham chiếu rộng 390px, quy đổi 1:1 sang Flutter `double`.
- Font UI: **Lexend** (`google_fonts`).
- Danh sách chi tiêu theo khoản (`reportRows`) là dữ liệu động — thanh tiến trình `r.pct` (%) render theo tỷ lệ so với tổng chi, dựng widget progress bar tái sử dụng.
- Bottom nav dữ liệu động (`navTabsReport`/`navTabsReportDark`) — 5 tab, style/màu theo trạng thái active/inactive đã render sẵn trong `t.color`/`t.weight` (mockup); khi build cần tự tính theo route hiện tại thay vì hard-code.
