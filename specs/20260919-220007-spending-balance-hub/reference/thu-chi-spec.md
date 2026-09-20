# Thu chi (hub) — Chi tiết layout (sáng + tối)

Thiết kế tham chiếu rộng **390px**. Font: **Lexend**. Radius: `--radius-lg` 6px, `--radius-md` 4px, `--radius-xl` 10px (thẻ nhóm). Vùng chạm ≥44px.

Đây là màn hiển thị **số dư thực tế** từng khoản (khác màn Kiểm soát chi tiêu chỉ định nghĩa công thức %/₫).

---

## Header (cố định, không scroll)
- Container: `min-height: 62px`, `flex row align-items:center`, `gap: 12px`, `padding: 0 20px`.
- Background: sáng `bg-surface` `#FFFFFF` / tối `#241F1A`. Border-bottom **1px solid** `border-1` (sáng `#E7E1D8` / tối `#4A443B`).
- Icon badge: 34×34px, radius **4px**, nền `blue-50` (sáng `#EDF4FF` / tối `rgba(59,141,248,.16)`), icon `arrow-left-right` 17×17px màu `blue-600` (sáng `#1A72E0` / tối `#6AADFF`).
- Tiêu đề "Thu chi": 18px / weight 800, màu `fg-1` (sáng `#1A1714` / tối `#FAF8F5`).

## Nội dung (scroll, `padding: 18px 18px 20px`)

### 2 nút Thu nhập / Chi tiêu
- `flex row, gap: 10px`, `margin-bottom: 12px`.
- Mỗi nút: `flex:1`, height **64px**, radius **6px**, border **1.5px solid**, `flex center gap:10px`.
  - **Thu nhập**: nền `success-soft` (sáng nền xanh nhạt) / `rgba(35,122,80,.16)` (tối), border `green-200` (sáng) / `#154C31` (tối). Icon `arrow-up-circle` 22×22px màu `success` (sáng `#237A50` / tối `#62BB91`). Text 15px/weight 800 màu `success-fg` (sáng) / `#8FD6B0` (tối).
  - **Chi tiêu**: nền `danger-soft` / `rgba(196,48,32,.16)` (tối), border `red-200` (sáng) / `#5E150E` (tối). Icon `arrow-down-circle` 22×22px màu `danger` (sáng `#C43020` / tối `#E07A6D`). Text 15px/weight 800 màu `danger-fg` (sáng) / `#F0B3A8` (tối).

### Dòng "Xem lịch sử giao dịch"
- height **48px**, padding `0 14px`, nền `bg-surface` (sáng) / `#241F1A` (tối), border **1px solid** `border-1`/`#4A443B`, radius **6px**, `margin-bottom: 18px`.
- `flex row align-items:center gap:10px`: icon `history` 17×17px màu `fg-2` (sáng `#4A443B` / tối `#B0A696`) → text `flex:1` 13px/weight 700 màu `fg-1` → icon `chevron-right` 16×16px màu `fg-3` `#8A8073`.

### Eyebrow "Số dư từng khoản"
- 12px / weight 800, `letter-spacing: .06em`, uppercase, màu `fg-2`, `padding-left: 9px`, `border-left: 3px solid border-2` (sáng `#D4CCC0` / tối `#4A443B`), `margin-bottom: 10px`.

### Danh sách nhóm (5 card, `margin-bottom: 10px` mỗi card)
Mỗi card:
- Nền `bg-surface`/`#241F1A`, border **1px solid** `border-1`/`#4A443B`, radius **10px**, padding `14px 16px`. (Bản sáng có thêm `box-shadow: --shadow-sm`; bản tối không có shadow.)

**Dòng chính** (`flex row align-items:center gap:10px`, clickable để mở/đóng):
1. Icon badge nhóm: 32×32px, radius **4px**, nền `blue-50`/`rgba(59,141,248,.16)`, icon 16×16px màu `blue-600`/`#6AADFF`.
2. Tên + sub-label: `flex:1`. Tên 14px/weight 700 màu `fg-1`; sub-label 12px màu `fg-2` (sáng) / `#B0A696` (tối), ngay dưới tên.
3. Số dư: `text-align:right`, 15px/weight 800, màu động theo `g.barColor` (xanh nếu dương/tiết kiệm, đỏ nếu âm quỹ).
4. Chevron (chỉ nếu có khoản con): 16×16px màu `fg-3`.

**Khi mở rộng (trackExpanded = true):** `margin-top: 12px`, `border-top: 1px dashed border-1`/`#4A443B`, danh sách khoản con dạng cột không gap riêng (mỗi item tự padding).

Mỗi khoản con: `flex row align-items:center gap:10px`, padding `10px 0 10px 12px`, `border-bottom: 1px solid border-1`/`#4A443B`, có thanh dọc trang trí `position:absolute left:0 width:2px` màu `border-2`/`#4A443B` full height.
- Icon badge 24×24px, radius **4px**, nền `neutral-100`/`#332F29`, icon 12×12px màu `fg-2`/`#B0A696`.
- Tên: `flex:1`, 12px/weight 600, màu `fg-1`.
- Số dư: `text-align:right, flex:none`, 13px/weight 800, màu theo `c.barColor`.

## Bottom nav (cố định)
- `flex row`, nền `bg-surface`/`#241F1A`, border-top **1px solid** `border-1`/`#4A443B`, padding `8px 0 22px`.
- 5 tab cố định (không phải data động ở bản tối; bản sáng dùng `navTabsTxn`): Tổng quan · Kiểm soát · **Thu chi (active)** · Báo cáo · Hồ sơ.
- Mỗi tab: `flex:1, flex-column center, gap:3px`. Icon 22×22px. Label 11px — active weight 700 màu `blue-600`/`#6AADFF`; inactive weight 600 màu `fg-3`/`#B0A696`.

## Ghi chú
- Icon nhóm/khoản con (`g.icon`, `c.icon`) là dữ liệu động — icon cụ thể cho 5 nhóm + khoản con xem `handoff/icons-used.json` gốc project.
- Không có trạng thái lỗi/rỗng trong mockup (ví dụ chưa có giao dịch nào) — hỏi lại nếu cần spec riêng.
- Bản sáng có `box-shadow: --shadow-sm` trên card nhóm, bản tối không — giữ đúng khác biệt này khi build theme.
