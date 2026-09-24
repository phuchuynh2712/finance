# Tổng quan — Handoff package

Nguồn: `Finance App Mockups.dc.html`, màn 1 (sáng) và màn 10 (tối). Màn chính (home), có bottom nav, tab "Tổng quan" active.

## Nội dung
- `tong-quan-spec.md` — spec chi tiết từng element, sáng & tối.
- `icons.json` — icon dùng trong màn này, kèm mapping Flutter.
- `theme-tokens.json` — toàn bộ token màu/spacing/type/radius/motion.
- `screen-light.png`, `screen-dark.png` — ảnh chụp thật của màn (2x).

## Ghi chú dựng Flutter
- Frame điện thoại 390×844 chỉ để trình bày — vùng nội dung thật dùng `SafeArea`.
- Đơn vị spec = logical pixel ở thiết kế tham chiếu rộng 390px, quy đổi 1:1 sang Flutter `double`.
- Font UI: **Lexend** (`google_fonts`).
- Banner cảnh báo âm quỹ (`showWarning`) là điều kiện động — chỉ hiện khi có ít nhất 1 khoản âm quỹ.
- Danh sách "Các khoản" (scroll ngang) và "Giao dịch gần đây" (`recentTx`) là dữ liệu động — dựng `ListView` ngang/dọc, item tái sử dụng.
- Số dư tổng dùng dạng rút gọn (`totalBalanceShort`, ví dụ "12,4 triệu ₫") ở dòng lớn, số đầy đủ (`totalBalanceFmt`) ở dòng nhỏ dưới — cần cả 2 hàm format.
