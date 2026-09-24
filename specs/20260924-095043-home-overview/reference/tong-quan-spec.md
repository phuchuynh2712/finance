# Tổng quan — Chi tiết layout (sáng + tối)

Thiết kế tham chiếu rộng **390px**. Font: **Lexend**. Radius: `--radius-2xl` (card tổng), `--radius-lg` 6px, `--radius-md` 4px. Vùng chạm ≥44px.

Màn chính (home), có bottom nav, tab "Tổng quan" active.

---

## Header (cố định)
- Container: `min-height: 62px`, `flex row align-items:center`, `gap: 12px`, `padding: 0 20px`, nền `bg-surface` (sáng `#FFFFFF` / tối `#241F1A`), border-bottom **1px solid** `border-1` (sáng `#E7E1D8` / tối `#4A443B`).
- Icon badge: 34×34px, radius **4px**, nền `blue-50` (sáng) / `rgba(59,141,248,.16)` (tối), icon `layout-dashboard` 17×17px màu `blue-600` (sáng `#1A72E0` / tối `#6AADFF`).
- Tiêu đề "Xin chào, {{ tên }}": `flex:1`, 19px/weight 800, `letter-spacing:-.01em`, màu `fg-1` (sáng `#1A1714` / tối `#FAF8F5`).
- Nút thông báo: 44×44px, `border-radius:50%`, nền `bg-sunken`, icon `bell` 18×18px màu `fg-2` (sáng `#4A443B` / tối `#B0A696`).

## Nội dung (scroll, `padding: 18px 18px 20px`)

### Card tổng số dư
- Nền `blue-900` (đậm, cả 2 theme — không đổi theo sáng/tối), radius **20px** (`--radius-2xl`), padding `20px 22px`, chữ trắng `#FFFFFF`.
- Eyebrow "Tổng còn lại · tất cả các khoản": 12px/weight 700, `letter-spacing:.04em`, uppercase, màu `gold-300` `#E3C56B`.
- Số dư rút gọn (`totalBalanceShort`, ví dụ "12,4 triệu ₫"): 32px/weight 800, `margin: 6px 0 2px`, `letter-spacing:-.01em`, trắng.
- Số dư đầy đủ (`totalBalanceFmt`): 11px, màu `rgba(255,255,255,.5)`.

### Banner cảnh báo âm quỹ (chỉ hiện khi `showWarning = true`)
- `flex row align-items:flex-start gap:10px`, nền `danger-soft` (sáng) / tương ứng tối, border **1px solid** `red-200` (sáng `#F5C6BE`) / tối tương ứng, radius **6px**, padding `12px 14px`, `margin-top: 14px`.
- Icon `alert-triangle` 18×18px, màu `danger` (sáng `#C43020` / tối `#E07A6D`), `margin-top:1px`.
- Dòng 1: 13px/weight 700, màu `danger-fg`: "Khoản "[Tên]" đã âm quỹ".
- Dòng 2: 12px, `margin-top:1px`, cùng màu: "Xem chi tiết →".

### Eyebrow "Các khoản ({{ groupCount }})"
- `flex row align-items:baseline justify-content:space-between`, `margin: 22px 0 10px`.
- Label: 12px/weight 800, `letter-spacing:.06em`, uppercase, màu `fg-2` (sáng `#4A443B` / tối `#B0A696`), `padding-left:9px`, `border-left: 3px solid border-2` (sáng `#D4CCC0` / tối `#4A443B`).
- Link "Xem tất cả": 12px/weight 700, màu link mặc định (sáng `#1A72E0` / tối `#6AADFF`).

### Danh sách khoản (scroll ngang, `gap:10px`, `padding-bottom:4px`)
Mỗi card: `flex:none`, width **128px**, nền `bg-surface`/`#241F1A`, border **1px solid** `border-1`/`#4A443B`, radius **6px** (`--radius-lg`), padding **12px**, shadow `--shadow-xs`.
- Dòng đầu: `flex row space-between align-items:center`, `margin-bottom:8px`. Icon badge 28×28px radius **4px** nền `blue-50`/tối tương ứng, icon 15×15px màu `blue-600`/`#6AADFF`. Chấm tròn trạng thái: 8×8px, `border-radius:50%`, màu động theo `g.barColor` (xanh/đỏ/xanh dương).
- Tên nhóm: 12px/weight 700, `line-height:1.25`, màu `fg-1`, `margin-bottom:8px`.
- Số dư: 14px/weight 800, màu động theo `g.barColor`.

### Eyebrow "Giao dịch gần đây"
- Cùng style eyebrow như trên, `margin: 22px 0 10px`.

### Danh sách giao dịch gần đây (dữ liệu động, không gap riêng)
Mỗi dòng: `flex row align-items:center gap:12px`, padding `10px 0`, `border-bottom: 1px solid border-1`/`#4A443B`.
- Icon badge: 38×38px, radius **4px**, nền `blue-50`/tối tương ứng, icon 18×18px màu `blue-600`/`#6AADFF`.
- Tên giao dịch: 14px/weight 700, màu `fg-1`. Dòng phụ "{{ nhóm }} · {{ thời gian }}": 12px, màu `fg-2`, ngay dưới tên.
- Số tiền: 14px/weight 700, màu động theo `tx.amtColor` (xanh nếu thu, đỏ nếu chi).

## Bottom nav (cố định)
- `flex row`, nền `bg-surface`/`#241F1A`, border-top **1px solid** `border-1`/`#4A443B`, padding `8px 0 22px`.
- 5 tab (`navTabsOverview`): **Tổng quan (active)** · Kiểm soát · Thu chi · Báo cáo · Hồ sơ.
- Mỗi tab: `flex:1, flex-column center, gap:3px`. Icon 22×22px, label 10px — weight/màu động theo trạng thái active/inactive (`t.weight`, `t.color`).

## Ghi chú
- Card tổng số dư dùng nền `blue-900` cố định ở cả 2 theme (không đổi theo sáng/tối) — khác các card khác luôn đổi nền theo theme.
- Icon nhóm/giao dịch (`g.icon`, `tx.icon`) là dữ liệu động — danh sách icon cụ thể xem `handoff/icons-used.json` gốc project.
- Không có trạng thái rỗng (chưa có giao dịch/khoản nào) trong mockup — hỏi lại nếu cần spec riêng.
