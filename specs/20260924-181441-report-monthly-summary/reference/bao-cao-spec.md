# Báo cáo — Chi tiết layout (sáng + tối)

Thiết kế tham chiếu rộng **390px**. Font: **Lexend**. Radius: `--radius-lg` 6px, `--radius-md` 4px. Vùng chạm ≥44px.

Có bottom nav, tab "Báo cáo" active.

---

## Header (cố định)
- Container: `min-height: 62px`, `flex row align-items:center`, `gap: 12px`, `padding: 0 20px`, nền `bg-surface` (sáng `#FFFFFF` / tối `#241F1A`), border-bottom **1px solid** `border-1` (sáng `#E7E1D8` / tối `#4A443B`).
- Icon badge: 34×34px, radius **4px**, nền `blue-50` (sáng) / `rgba(59,141,248,.16)` (tối), icon `pie-chart` 17×17px màu `blue-600` (sáng `#1A72E0` / tối `#6AADFF`).
- Tiêu đề "Báo cáo": `flex:1`, 18px/weight 800, màu `fg-1` (sáng `#1A1714` / tối `#FAF8F5`).

## Nội dung (scroll, `padding: 18px 18px 20px`)

### Bộ chọn tháng
- `flex row align-items:center gap:10px`, `margin-bottom: 16px`.
- 2 nút tròn: 44×44px, `border-radius:50%`, border **1px solid** `border-2` (sáng `#D4CCC0` / tối `#4A443B`), nền `bg-surface`/`#241F1A`, icon `chevron-left`/`chevron-right` 18×18px màu `fg-2`.
- Nhãn tháng: `flex:1`, `text-align:center`, 15px/weight 700, màu `fg-1`.

### 2 thẻ tổng Thu nhập / Chi tiêu (grid 2 cột, `gap:10px`, `margin-bottom:20px`)
Mỗi thẻ: radius **6px**, padding **14px**.
- **Thu nhập**: nền `success-soft` (sáng) / `rgba(35,122,80,.16)` (tối), border **1px solid** `green-200` (sáng `#B8E0C8`) / `#154C31` (tối). Label 11px/weight 700 uppercase `letter-spacing:.04em` màu `success-fg` (sáng) / `#8FD6B0` (tối). Số tiền 18px/weight 800, cùng màu, `margin-top:4px`.
- **Chi tiêu**: nền `danger-soft` / `rgba(196,48,32,.16)` (tối), border `red-200` (sáng) / `#5E150E` (tối). Label + số tiền cùng style, màu `danger-fg` (sáng) / `#F0B3A8` (tối).

### Eyebrow "Chi tiêu theo khoản"
- 12px/weight 800, `letter-spacing:.06em`, uppercase, màu `fg-2` (sáng `#4A443B`/tối `#B0A696`), `padding-left:9px`, `border-left:3px solid border-2` (sáng `#D4CCC0`/tối `#4A443B`), `margin-bottom:10px`.

### Danh sách khoản (dữ liệu động `reportRows`, mỗi item `margin-bottom:20px`)
- Dòng trên (`flex row space-between`, `margin-bottom:8px`): tên khoản (`r.name`) 14px/weight 600 màu `fg-1`; số tiền (`r.amountFmt`) 14px/weight 700 màu `fg-1`.
- Thanh tiến trình: height **8px**, nền `neutral-200` (sáng `#EAE4DA`) / `#39332B` (tối), radius **999px**, overflow hidden; fill bên trong `width: {{ r.pct }}%`, nền `blue-500` (sáng)/`#3B8DF8` (tối), radius **999px**.

## Bottom nav (cố định)
- `flex row`, nền `bg-surface`/`#241F1A`, border-top **1px solid** `border-1`/`#4A443B`, padding `8px 0 22px`.
- 5 tab (`navTabsReport`/`navTabsReportDark`, dữ liệu động): Tổng quan · Kiểm soát · Thu chi · **Báo cáo (active)** · Hồ sơ.
- Mỗi tab: `flex:1, flex-column center, gap:3px`. Icon 22×22px, label 10px — active weight 700 màu `blue-600`/`#6AADFF`, inactive weight 500 màu `fg-3`/`#B0A696`.

## Ghi chú
- Không có trạng thái rỗng (tháng không có chi tiêu) trong mockup — hỏi lại nếu cần spec riêng.
- Danh sách khoản trong báo cáo hiện show tối đa các khoản có chi tiêu — không giới hạn số lượng cụ thể trong mockup (đặt `hint-placeholder-count="8"` chỉ là gợi ý số dòng khi loading).
