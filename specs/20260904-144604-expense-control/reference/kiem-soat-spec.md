# Kiểm soát chi tiêu — Chi tiết layout (sáng + tối)

Thiết kế tham chiếu rộng **390px**. Font: **Lexend**. Radius: `--radius-lg` 6px, `--radius-md` 4px, `--radius-xl` 10px (thẻ nhóm). Vùng chạm ≥44px.

Đây là màn **định nghĩa công thức** (% hoặc số tiền cố định) — KHÔNG hiển thị số dư thực tế (số dư nằm ở "Thu chi").

---

## Header (cố định, không scroll)
- Container: `min-height: 62px`, `flex row align-items:center`, `gap: 12px`, `padding: 0 20px`.
- Background: sáng `bg-surface` `#FFFFFF` / tối `#241F1A`. Border-bottom **1px solid** `border-1` (sáng `#E7E1D8` / tối `#4A443B`).
- Icon badge: 34×34px, radius **4px**, nền `blue-50` (sáng `#EDF4FF` / tối `rgba(59,141,248,.16)`), icon `sliders-horizontal` 17×17px màu `blue-600` (sáng `#1A72E0` / tối `#6AADFF`).
- Tiêu đề "Kiểm soát chi tiêu": 18px / weight 800, màu `fg-1` (sáng `#1A1714` / tối `#FAF8F5`).

## Nội dung (scroll, `padding: 16px 18px 20px`)

### Banner hướng dẫn
- `flex row, align-items: flex-start, gap: 10px`, nền `blue-50` (sáng) / `rgba(59,141,248,.16)` (tối), border **1px solid** `blue-200` (sáng `#B8D6FF`) / `#0C4D9A` (tối), radius **6px**, padding `12px 14px`, margin-bottom **14px**.
- Icon `info` 16×16px, màu `blue-600` (sáng) / `#6AADFF` (tối), `margin-top: 1px`.
- Text 12px, line-height **1.5**, màu `blue-700` (sáng `#0F52A8`) / `#A4CFFF` (tối): "Bấm tên các khoản để đóng/mở."

### Danh sách nhóm (5 card, `margin-bottom: 10px` mỗi card)
Mỗi card nhóm:
- Container: nền `bg-surface` (sáng `#FFFFFF` / tối `#241F1A`), border **1px solid** `border-1` (sáng `#E7E1D8` / tối `#4A443B`), radius **10px**, shadow `--shadow-sm`, padding **14px**.

**Dòng header nhóm** (`flex row align-items:center`, `gap: 10px`, cả dòng clickable để toggle):
1. Icon `grip-vertical` 15×15px, màu `fg-3` (sáng `#8A8073` / tối `#8A8073`) — kéo sắp xếp.
2. Icon badge nhóm: 28×28px, radius **4px**, nền `blue-50`/tối tương ứng, icon 14×14px màu `blue-600`/`#6AADFF`.
3. Tên nhóm + sub-label: `flex:1`, tên 14px/weight 700 màu `fg-1`; sub-label (nếu có) 12px màu `fg-2` (sáng `#4A443B` / tối `#B0A696`) ngay dưới, không margin riêng (tự nhiên theo dòng).
4. Nút sửa: vùng chạm 44×44px, icon `pencil` 15×15px màu `fg-3`.
5. Nút xoá: vùng chạm 44×44px, icon `trash-2` 16×16px màu `fg-3`.
6. Chevron mở/đóng (chỉ hiện nếu có khoản con): 15×15px, màu `fg-3`.

**Khi mở (planExpanded = true):** `margin-top: 10px`, danh sách khoản con.

Mỗi khoản con (`padding: 8px 0 8px 8px`, border-top **1px dashed** `border-1`/`#4A443B`):
- Dòng tên (`flex row align-items:center`, `gap: 8px`, `margin-bottom: 10px`):
  - Icon badge 22×22px, radius **4px**, nền `neutral-100` (sáng) / `#332F29` (tối), icon 11×11px màu `fg-2`/`#B0A696`.
  - Tên khoản con: `flex:1`, 12px/weight 600, màu `fg-1`.
  - Nút sửa 44×44px chạm, icon `pencil` 14×14px màu `fg-3`.
  - Nút xoá 44×44px chạm, icon `trash-2` 15×15px màu `fg-3`.
- Dòng công thức (`padding-left: 30px`, `flex row align-items:center gap: 8px`):
  - Ô giá trị: height **40px**, padding `0 14px`, border **1.5px solid** `border-2` (sáng `#D4CCC0` / tối `#4A443B`), radius **4px**, font 14px/weight 700, màu `fg-1`.
  - Toggle %/₫: nền `neutral-100`/`#332F29`, radius **999px** (pill), padding **2px**, gap **2px**; mỗi chip height **32px**, padding `0 12px`, radius **999px**, font 12px/weight 700 — chip active có nền `blue-500`/`#3B8DF8` chữ trắng, chip inactive trong suốt chữ `fg-2`.

Nút "Thêm khoản trong [Tên nhóm]" (dưới danh sách khoản con): height **34px**, `margin-top: 8px`, border **1.5px dashed** `border-2`/`#4A443B`, radius **4px**, `flex center gap:6px`, icon `plus` 13×13px + text 11px/weight 700, màu `blue-600`/`#6AADFF`.

**Khi nhóm là lá (leafRule, không có khoản con):** hiện trực tiếp dòng công thức, `padding-left: 38px`, `margin-top: 10px` — cùng style ô giá trị + toggle %/₫ như trên.

### Nút "Thêm khoản mới"
- height **48px**, border **1.5px dashed** `blue-300` (sáng `#8FBBFF`) / `#3B8DF8` (tối), radius **6px**, `flex center gap:8px`, margin-bottom **16px**.
- Icon `plus` 16×16px + text 14px/weight 700, màu `blue-600`/`#6AADFF`.

### Banner tổng phân bổ
- `flex row align-items: flex-start, gap: 10px`, padding `12px 14px`, nền `warning-soft` (sáng nền vàng nhạt) / `rgba(201,151,31,.16)` (tối), border **1px solid** `gold-200` (sáng) / `#6B4D0D` (tối), radius **6px**.
- Icon `pie-chart` 16×16px, màu `warning` (sáng `#C9971F` / tối `#DFB04A`), `margin-top: 2px`.
- Dòng 1: 12px/weight 700, màu `warning-fg` (sáng) / `#ECCB7E` (tối): "Đã phân bổ {X}% + 1 khoản cố định".
- Dòng 2: 12px thường, `margin-top: 4px`, cùng màu: "Còn {Y}% tự do".

### Nút chính "Lưu công thức"
- height **52px**, nền `blue-500` (sáng `#1A72E0`... thực tế `--blue-500`) / `#3B8DF8` (tối), radius **6px**, `flex center gap:10px`, `margin-top: 16px`.
- Icon `check` 20×20px trắng + text 16px/weight 800 trắng.

## Bottom nav (cố định)
- `flex row`, nền `bg-surface`/`#241F1A`, border-top **1px solid** `border-1`/`#4A443B`, padding `8px 0 22px` (22px đáy để tránh home-indicator).
- Mỗi tab: `flex:1, flex-column center, gap:3px`. Icon 22×22px, label 10px, weight theo trạng thái active (700) / inactive (500), màu theo token nav active/inactive.

## Ghi chú
- Tất cả icon nhóm/khoản con là dữ liệu động (`g.icon`, `c.icon`) — danh sách icon cụ thể cho 5 nhóm + khoản con xem `handoff/icons-used.json` ở gốc project.
- Không có trạng thái lỗi trong mockup (ví dụ tổng % vượt 100%) — hỏi lại nếu cần spec riêng.
- Toggle %/₫ và giá trị ô input là minh hoạ tĩnh — dựng thành control thật (segmented control + TextFormField numeric) khi build.
