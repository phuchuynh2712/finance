# Chi tiêu — Handoff package

Nguồn: `Finance App Mockups.dc.html`, màn 3b (sáng) và màn 14 (tối). Mở từ nút "Chi tiêu" ở màn Thu chi (hub) — không có bottom nav. Có 2 tab: **Nhập tay** (default) và **Quét hoá đơn** (option).

## Nội dung
- `chi-tieu-spec.md` — spec chi tiết từng element cho cả 2 tab, sáng & tối.
- `icons.json` — icon dùng trong màn này, kèm mapping Flutter.
- `theme-tokens.json` — toàn bộ token màu/spacing/type/radius/motion.

## Ghi chú dựng Flutter
- Frame điện thoại 390×844 chỉ để trình bày — vùng nội dung thật dùng `SafeArea`.
- Đơn vị spec = logical pixel ở thiết kế tham chiếu rộng 390px, quy đổi 1:1 sang Flutter `double`.
- Font UI: **Lexend** (`google_fonts`).
- Tab "Nhập tay"/"Quét hoá đơn" là segmented control 2 lựa chọn — state cục bộ (`isManual`/`isScan`), style active/inactive khác nhau theo spec.
- Số pad (`keypad`) là dữ liệu tĩnh 12 phím (0-9, xoá, dấu phẩy) — dựng `GridView` 3 cột.
- Danh sách khoản để trừ (`pickerItems`) là dữ liệu động — `ListView` ngang, item tái sử dụng.
- Banner xem trước số dư sau giao dịch đổi màu động: xanh nếu còn dương, đỏ nếu về âm quỹ (`previewNeg`) — logic cần replicate, không phải giá trị tĩnh.
- Tab "Quét hoá đơn" là placeholder UI cho tính năng OCR — chưa có logic xử lý ảnh thật, chỉ dựng UI theo spec, phần nhận diện xử lý ở backend/sau.
