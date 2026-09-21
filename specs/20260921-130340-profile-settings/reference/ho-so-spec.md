# Hồ sơ — Chi tiết layout (sáng + tối)

Thiết kế tham chiếu rộng **390px**. Font: **Lexend**. Radius: `--radius-xl` 10px (card), `--radius-md` 4px. Vùng chạm ≥44px.

Có bottom nav, tab "Hồ sơ" active. Đây là màn đổi giao diện Sáng/Tối.

---

## Header (cố định)
- Container: `min-height: 62px`, `flex row align-items:center`, `gap: 12px`, `padding: 0 20px`, nền `bg-surface` (sáng `#FFFFFF` / tối `#241F1A`), border-bottom **1px solid** `border-1` (sáng `#E7E1D8` / tối `#4A443B`).
- Icon badge: 34×34px, radius **4px**, nền `blue-50` (sáng) / `rgba(59,141,248,.16)` (tối), icon `user-round` 17×17px màu `blue-600` (sáng `#1A72E0` / tối `#6AADFF`).
- Tiêu đề "Hồ sơ": `flex:1`, 18px/weight 800, màu `fg-1` (sáng `#1A1714` / tối `#FAF8F5`).

## Nội dung (scroll, `padding: 20px 18px 20px`)

### Khối thông tin người dùng
- `flex row align-items:center gap:14px`, `margin-bottom: 22px`.
- Avatar: 56×56px, `border-radius:50%`, nền `blue-100` (sáng) / `rgba(59,141,248,.25)` (tối), chữ cái đầu tên căn giữa, 20px/weight 800, màu `blue-700` (sáng `#0F52A8`) / `#A4CFFF` (tối).
- Tên: 17px/weight 800, màu `fg-1`. Email: 12px, màu `fg-3` (sáng `#8A8073` / tối `#8A8073`), ngay dưới tên.

### Card "Giao diện" (toggle Sáng/Tối)
- Nền `bg-surface`/`#241F1A`, border **1px solid** `border-1`/`#4A443B`, radius **10px**, shadow `--shadow-sm`, `margin-bottom: 16px`.
- Dòng: `flex row align-items:center gap:12px`, padding `14px 16px`.
  - Icon `sun-moon` 18×18px, màu `fg-2` (sáng `#4A443B`/tối `#B0A696`).
  - Text "Giao diện": `flex:1`, 14px/weight 600, màu `fg-1`.
  - Toggle segmented: nền `neutral-100` (sáng `#F2EEE7`) / `#332F29` (tối), radius **999px**, padding **2px**, gap **2px**. Mỗi chip "Sáng"/"Tối": height **28px**, padding `0 12px`, radius **999px**, font 12px/weight 700.
    - Chip **active**: nền `blue-500` (sáng)/`#3B8DF8` (tối), chữ trắng (`themeLightStyle`/`themeDarkStyle` theo `theme` hiện tại).
    - Chip **inactive**: nền trong suốt, chữ `fg-2`.

### Card menu (3 dòng, `margin-bottom: 16px`)
- Nền `bg-surface`/`#241F1A`, border **1px solid** `border-1`/`#4A443B`, radius **10px**, shadow `--shadow-sm`, `overflow:hidden`.
- Mỗi dòng: `flex row align-items:center gap:12px`, padding `14px 16px`; 2 dòng đầu có border-bottom **1px solid** `border-1`/`#4A443B`, dòng cuối không.
  1. "Thông báo" — icon `bell` 18×18px.
  2. "Bảo mật" — icon `shield-check` 18×18px.
  3. "Trợ giúp" — icon `circle-help` 18×18px.
  - Mỗi dòng: icon trái màu `fg-2`; text `flex:1` 14px/weight 600 màu `fg-1`; icon `chevron-right` 16×16px màu `fg-3` `#8A8073` bên phải.

### Dòng "Đăng xuất"
- `flex row align-items:center gap:12px`, padding `14px 16px`, nền `bg-surface`/`#241F1A`, border **1px solid** `border-1`/`#4A443B`, radius **10px** (đứng riêng, không nhóm card).
- Icon `log-out` 18×18px + text 14px/weight 700 — cả 2 màu `danger` (sáng `#C43020`) / `#E07A6D` (tối).

## Bottom nav (cố định)
- `flex row`, nền `bg-surface`/`#241F1A`, border-top **1px solid** `border-1`/`#4A443B`, padding `8px 0 22px`.
- 5 tab (`navTabsProfile`/`navTabsProfileDark`): Tổng quan · Kiểm soát · Thu chi · Báo cáo · **Hồ sơ (active)**.
- Mỗi tab: `flex:1, flex-column center, gap:3px`. Icon 22×22px, label 10px — active weight 700 màu `blue-600`/`#6AADFF`, inactive weight theo token, màu `fg-3`/`#B0A696`.

## Ghi chú
- 3 dòng menu (Thông báo/Bảo mật/Trợ giúp) chưa có màn đích cụ thể trong mockup — chỉ dựng UI điều hướng (`chevron-right`), hành vi/route thật cần xác nhận thêm.
- Card "Giao diện" và card menu dùng cùng style card (radius 10px, shadow-sm) nhưng tách 2 khối riêng — không gộp chung 1 card.
