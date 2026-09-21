# Chi tiêu — Chi tiết layout (sáng + tối)

Thiết kế tham chiếu rộng **390px**. Font: **Lexend**. Radius: `--radius-lg` 6px, `--radius-md` 4px, `--radius-xl` 10px. Vùng chạm ≥44px.

Màn mở từ nút "Chi tiêu" ở Thu chi (hub) — không có bottom nav. 2 tab: **Nhập tay** (default) / **Quét hoá đơn** (option).

---

## Header (cố định)
- Container: `min-height: 62px`, `flex row align-items:center`, `gap: 12px`, `padding: 0 20px`, nền `bg-surface` (sáng `#FFFFFF` / tối `#241F1A`), border-bottom **1px solid** `border-1` (sáng `#E7E1D8` / tối `#4A443B`).
- Nút back: vùng chạm 44×44px (`margin-left: -11px`), icon `chevron-left` 22×22px, màu `fg-2` (sáng `#4A443B` / tối `#B0A696`).
- Icon badge: 34×34px, radius **4px**, nền `danger-soft` (sáng) / `rgba(196,48,32,.16)` (tối), icon `arrow-down-circle` 17×17px màu `danger` (sáng `#C43020` / tối `#E07A6D`).
- Tiêu đề "Chi tiêu": `flex:1`, 18px/weight 800, màu `fg-1` (sáng `#1A1714` / tối `#FAF8F5`).

## Segmented tab (cố định, `padding: 16px 18px 0`, `flex row gap:8px`)
Mỗi tab: `flex:1`, height **38px**, radius **4px**, `flex center gap:7px`, font 13px/weight 700.
- **Active**: nền `blue-500` (sáng)/`#3B8DF8` (tối), chữ trắng.
- **Inactive**: nền `bg-surface`/`#241F1A`, border **1px solid** `border-1`/`#4A443B`, chữ `fg-2`/`#B0A696`.
- Icon trong tab: `pencil-line` 15×15px (Nhập tay) / `camera` 15×15px (Quét hoá đơn), màu theo trạng thái tab (trắng nếu active, theo chữ inactive nếu không).

---

## TAB "Nhập tay" (default, `isManual = true`)

Nội dung scroll `padding: 16px 18px 24px`, cột `flex:1`.

### Số tiền (căn giữa, `padding: 8px 0 10px`)
- Label "Số tiền": 12px, màu `fg-3` `#8A8073`, `margin-bottom: 6px`.
- Số tiền lớn: 38px/weight 800, màu `fg-1`, `border-bottom: 2px solid blue-300` (sáng `#8FBBFF` / tối `#3B8DF8`), `display: inline-block`, `padding-bottom: 6px`.

### Bàn phím số (grid 3 cột, `gap: 8px`, `margin: 14px 0 18px`)
- 12 phím: height **48px**, nền `bg-surface`/`#241F1A`, border **1px solid** `border-1`/`#4A443B`, radius **4px**, font 18px/weight 600, màu `fg-1`, `flex center`.

### Eyebrow "Trừ vào khoản nào"
- 12px/weight 800, `letter-spacing:.06em`, uppercase, màu `fg-2` (sáng `#4A443B` / tối `#B0A696`), `margin-bottom: 8px`.

### Danh sách khoản (scroll ngang, `gap: 8px`, `padding-bottom: 10px`)
Mỗi item: `flex: none`, `min-width: 84px`, height **50px**, padding `6px 14px`, border **1.5px solid** `border-2` (sáng `#D4CCC0` / tối `#4A443B`), radius **4px**, cột trái căn trái, `gap: 1px`.
- Tên khoản: 13px/weight 700, màu `fg-1`.
- Tên nhóm cha (nếu có): 11px, màu `fg-2`.

### Banner xem trước số dư sau giao dịch
- `flex row align-items:center gap:8px`, padding `9px 12px`, radius **4px**, `margin-bottom: 14px`.
- Màu động theo `previewNeg` (số dư sau giao dịch có âm không):
  - **Bình thường**: nền `blue-50` (sáng) / `rgba(59,141,248,.16)` (tối); icon `corner-down-right` 14×14px màu `blue-500`; text màu `blue-700` (sáng `#0F52A8` / tối `#A4CFFF`).
  - **Âm quỹ**: nền `danger-soft` / tối tương ứng; icon + text màu `danger`/`danger-fg` (sáng) hoặc `#E07A6D` (tối).
- Text 14px: "Sau giao dịch này, "[Tên khoản]" còn lại **[số tiền]**" — số tiền in đậm (`<b>`).

### Nút chính "Lưu giao dịch"
- height **52px**, nền `blue-500`/`#3B8DF8`, radius **6px**, `flex center gap:10px`, chữ trắng 16px/weight 800, icon `check` 20×20px trắng.
- `margin-top: auto` — dính đáy vùng nội dung.

---

## TAB "Quét hoá đơn" (option, `isScan = true`)

### Khung camera
- height **200px**, `border: 2px dashed blue-300` (sáng `#8FBBFF` / tối `#3B8DF8`), radius **10px**, nền `blue-50` (sáng) / `rgba(59,141,248,.16)` (tối), `flex column center gap:10px`, `margin-bottom: 14px`.
- Icon `camera` 34×34px, màu `blue-400` (sáng `#5CA3F5`) / `#3B8DF8` (tối).
- Text "Đưa hoá đơn vào khung hình": 13px/weight 600, màu `blue-600` (sáng) / `#6AADFF` (tối).

### Nút "Chụp hoá đơn"
- height **52px**, nền `blue-500`/`#3B8DF8`, radius **6px**, `flex center gap:10px`, chữ trắng 16px/weight 800, `margin-bottom: 10px`.
- Icon `scan-line` 20×20px trắng.

### Card "Đã nhận diện"
- Nền `success-soft` (sáng) / `rgba(35,122,80,.16)` (tối), border **1px solid** `green-200` (sáng) / `#154C31` (tối), radius **10px**, padding **14px**.
- Dòng badge: `flex row align-items:center gap:8px`, `margin-bottom: 10px`. Icon `check-circle-2` 17×17px màu `success` (sáng `#237A50` / tối `#62BB91`). Text 13px/weight 700, màu `success-fg` (sáng) / `#8FD6B0` (tối): "Đã nhận diện: 450.000 ₫ · Coopmart".
- Ô chọn nhóm: height **44px**, nền trắng `#FFFFFF` (sáng) / `#2F2A24` (tối), border **1.5px solid** `border-2`/`#4A443B`, radius **4px**, padding `0 12px`, `flex row space-between align-items:center`.
  - Text nhóm: 13px/weight 700, màu `blue-700` (sáng `#0F52A8`) / `#A4CFFF` (tối).
  - Icon `chevron-down` 15×15px, màu `fg-3` `#8A8073`.

### Nút "Xác nhận & lưu"
- Giống nút "Lưu giao dịch" nhưng `margin-top: 14px` (không `margin-top: auto`).
- Icon `check` 20×20px trắng + chữ trắng 16px/weight 800.

## Ghi chú
- Số pad (`keypad`) là dữ liệu tĩnh 12 phím cố định — không cần data động, chỉ cần đúng grid 3 cột.
- Tab "Quét hoá đơn" hiện là UI minh hoạ tĩnh (số tiền/tên cửa hàng nhận diện là mock) — logic OCR thật xử lý riêng, không nằm trong spec này.
- Không có trạng thái lỗi (ví dụ chưa chọn khoản, số tiền = 0) trong mockup — hỏi lại nếu cần spec riêng.
