# Thu nhập — Chi tiết layout (sáng + tối)

Thiết kế tham chiếu rộng **390px**. Font: **Lexend**. Radius: `--radius-lg` 6px, `--radius-md` 4px. Vùng chạm ≥44px.

Màn mở từ nút "Thu nhập" ở Thu chi (hub) — không có bottom nav.

---

## Header (cố định, không scroll)
- Container: `min-height: 62px`, `flex row align-items:center`, `gap: 12px`, `padding: 0 20px`.
- Background: sáng `bg-surface` `#FFFFFF` / tối `#241F1A`. Border-bottom **1px solid** `border-1` (sáng `#E7E1D8` / tối `#4A443B`).
- Nút back: vùng chạm **44×44px** (`margin-left: -11px`), icon `chevron-left` 22×22px, màu `fg-2` (sáng `#4A443B` / tối `#B0A696`).
- Icon badge: 34×34px, radius **4px**, nền `success-soft` (sáng nền xanh nhạt / tối `rgba(35,122,80,.16)`), icon `arrow-up-circle` 17×17px màu `success` (sáng `#237A50` / tối `#62BB91`).
- Tiêu đề "Thu nhập": `flex:1`, 18px / weight 800, màu `fg-1` (sáng `#1A1714` / tối `#FAF8F5`).

## Nội dung (scroll, `padding: 20px 18px 20px`, cột `flex:1`)

### Tổng thu nhập (căn giữa)
- `text-align: center`, `padding: 6px 0 20px`.
- Label "Tổng thu nhập tháng 6": 12px, màu `fg-3` (sáng `#8A8073` / tối `#8A8073`), `margin-bottom: 6px`.
- Số tiền `{{ incomeAmountFmt }}`: 34px / weight 800, màu `fg-1`.

### Eyebrow "Các nguồn thu nhập"
- 12px / weight 800, `letter-spacing: .06em`, uppercase, màu `fg-2` (sáng `#4A443B` / tối `#B0A696`), `margin-bottom: 10px`.

### Danh sách nguồn thu nhập (dữ liệu động, mỗi item `margin-bottom: 10px`)
Mỗi dòng: `flex row align-items:center gap:10px`, nền `bg-surface`/`#241F1A`, border **1px solid** `border-1`/`#4A443B`, radius **6px**, padding **12px**.
1. Icon badge: 32×32px, radius **4px**, nền `blue-50` (sáng `#EDF4FF` / tối `rgba(59,141,248,.16)`), icon 16×16px màu `blue-600` (sáng `#1A72E0` / tối `#6AADFF`).
2. Tên nguồn (`s.name`): `flex:1`, 14px/weight 600, màu `fg-1`.
3. Ô số tiền (`s.amountFmt`): height **42px**, padding `0 14px`, border **1.5px solid** `border-2` (sáng `#D4CCC0` / tối `#4A443B`), radius **4px**, font 14px/weight 700, màu `fg-1`.
4. Nút xoá: vùng chạm 44×44px, icon `trash-2` 16×16px màu `fg-3` `#8A8073`.

### Nút "Thêm nguồn thu nhập khác"
- height **46px**, border **1.5px dashed** `blue-300` (sáng `#8FBBFF` / tối `#3B8DF8`), radius **6px**, `flex center gap:8px`, `margin-bottom: 22px`.
- Icon `plus` 15×15px + text 13px/weight 700, màu `blue-600`/`#6AADFF`.

### Nút chính "Lưu thu nhập"
- height **52px**, nền `blue-500` (sáng)/`#3B8DF8` (tối), radius **6px**, `flex center gap:10px`, chữ trắng.
- `margin-top: auto` — luôn dính đáy vùng nội dung (nếu danh sách ngắn, nút bị đẩy xuống cuối).
- Icon `check` 20×20px trắng + text 16px/weight 800 trắng.

## Ghi chú
- Ô số tiền trong mockup là hiển thị tĩnh minh hoạ — dựng thành `TextFormField` numeric thật khi build (định dạng số theo `đ`/nghìn phân cách VN).
- Không có trạng thái rỗng (chưa có nguồn thu nào) hoặc lỗi validate trong mockup — hỏi lại nếu cần spec riêng.
- Icon từng nguồn (`s.icon`) là dữ liệu động theo loại nguồn thu — xem `handoff/icons-used.json` gốc project.
