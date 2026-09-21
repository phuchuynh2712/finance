# Login & Sign up — Chi tiết layout (sáng + tối)

Thiết kế tham chiếu rộng **390px** (chuẩn iPhone), đơn vị = logical pixel Flutter. Font: **Lexend** (UI). Bo góc dùng `--radius-lg` = **6px**, `--radius-md` = **4px**. Tất cả vùng chạm ≥44×44px.

Token màu dùng ký hiệu `var(--x)` + hex tương ứng — xem `theme-tokens.json` để tra cứu đầy đủ (`light.*` / `dark.*`).

---

## 1. ĐĂNG NHẬP (Login)

### Bố cục màn
- Root: full width màn hình, nền `bg-app` (sáng `#FAF8F5` / tối `#1A1714`).
- Không có header/app-bar — nội dung căn giữa theo chiều đứng (`flex: column; justify-content: center`).
- Content wrapper: `padding: 0 28px` (→ vùng nội dung rộng **334px**, căn giữa màn hình).

### 1.1 Khối logo (căn giữa, margin-bottom **36px**)
| Element | Kích thước | Margin | Font | Màu (sáng) | Màu (tối) |
|---|---|---|---|---|---|
| App icon (ảnh) | 72×72px, radius **20px**, overflow hidden | margin: `0 auto 16px` | — | shadow `0 4px 14px rgba(174,128,21,.35)` | shadow `0 4px 14px rgba(0,0,0,.35)` |
| Tiêu đề "Kiểm Soát" | auto | — | 24px / **weight 800** | `fg-1` `#1A1714` | `#FAF8F5` |
| Phụ đề "Quản lý thu chi thông minh" | auto | margin-top: 4px | 13px / weight 400 | `fg-3` `#8A8073` | `#8A8073` |

Căn giữa (`text-align: center`) cho cả khối.

### 1.2 Form (cột, `gap: 14px`)
**Trường "Số điện thoại hoặc email"**
- Label: 13px / weight 600, màu `fg-2` (sáng `#4A443B` / tối `#B0A696`), margin-bottom **6px**.
- Input: height **50px**, border **1.5px solid** `border-2` (sáng `#D4CCC0` / tối `#4A443B`), radius **6px**, padding `0 14px`, font 15px, màu placeholder `fg-3` `#8A8073`.

**Trường "Mật khẩu"**
- Label giống trên.
- Input: cùng kích thước/border/radius; layout `flex row, justify-content: space-between, align-items: center`, padding `0 14px`.
- Icon `eye` bên phải: 18×18px, stroke 2px, màu `fg-3` `#8A8073` — toggle hiện/ẩn mật khẩu.

**Link "Quên mật khẩu?"**
- `text-align: right`, font 12px / weight 600.
- Màu: sáng = mặc định link (`primary` `#1A72E0`); tối = `#6AADFF`.

### 1.3 Nút chính "Đăng nhập"
- height **52px**, full width vùng content (334px), radius **6px**, `align-items/justify-content: center`.
- Background: sáng `primary` `#1A72E0` / tối `#3B8DF8`. Chữ trắng `#FFFFFF`, 16px / **weight 800**.
- margin-top: **22px** (từ form phía trên).

### 1.4 Divider "hoặc"
- `flex row, align-items: center, gap: 10px`, margin `20px 0`.
- 2 đường line 1px cao, nền `border-1` (sáng `#E7E1D8` / tối `#332F29`), `flex: 1`.
- Chữ "hoặc" giữa: 12px, màu `fg-3` `#8A8073`.

### 1.5 Nút phụ "Đăng nhập bằng vân tay"
- height **50px**, border **1.5px solid** `border-2`, radius **6px**, `flex row center, gap: 10px`.
- Icon `fingerprint` 18×18px trước chữ.
- Chữ 14px / weight 700, màu `fg-2` (sáng `#4A443B` / tối `#B0A696`).

### 1.6 Footer "Chưa có tài khoản? Đăng ký ngay"
- `text-align: center`, margin-top **24px**, font 13px, màu `fg-3` `#8A8073`.
- "Đăng ký ngay" là link: weight 700, màu primary (sáng `#1A72E0` / tối `#6AADFF`).

---

## 2. ĐĂNG KÝ (Sign up)

### Bố cục màn
- Có header cố định (không scroll) + thân form scroll được.

### 2.1 Header
- Container: `min-height: 62px`, `flex row, align-items: center, gap: 12px`, `padding: 0 20px`.
- Background: sáng `bg-surface` `#FFFFFF` / tối `#241F1A`. Border-bottom **1px solid** `border-1` (sáng `#E7E1D8` / tối `#4A443B`).
- Nút back: vùng chạm **44×44px** (`margin-left: -11px` để icon thẳng lề nội dung dưới), icon `chevron-left` 22×22px, màu `fg-2`.
- Icon badge: 34×34px, radius **4px** (`--radius-md`), nền `primary-soft` (sáng `#EDF4FF` / tối `rgba(59,141,248,.16)`), icon `user-plus` 17×17px màu primary (sáng `#1A72E0`/blue-600, tối `#6AADFF`).
- Tiêu đề "Tạo tài khoản": 18px / weight 800, màu `fg-1`.

### 2.2 Thân form (scroll, `padding: 20px 24px 24px`, cột `gap: 14px`)
5 trường theo thứ tự — mỗi trường: label 13px/weight 600 màu `fg-2`, margin-bottom **6px**; input height **48px**, border **1.5px solid** `border-2`, radius **6px**, padding `0 14px`, font 14px, placeholder màu `fg-3`.

1. **Họ và tên** — input thường.
2. **Số điện thoại** — input thường, giữ định dạng nhóm số `0901 234 567`.
3. **Email (không bắt buộc)** — input thường, label ghi rõ optional.
4. **Mật khẩu** — layout `space-between`, icon `eye` 17×17px bên phải, màu `fg-3`.
5. **Xác nhận mật khẩu** — input thường (không icon).

**Checkbox điều khoản** (`margin-top: 4px`, `min-height: 44px`, `flex row align-items: flex-start, gap: 9px`):
- Vùng chạm checkbox: 44×44px (`margin: -13px 0 0 -13px` để bù offset, giữ icon thẳng lề text).
- Ô vuông hiển thị: 18×18px, border **1.5px solid** primary, radius **4px**, nền primary khi checked (sáng `#1A72E0` / tối `#3B8DF8`), icon `check` trắng 12×12px giữa ô.
- Text: 12px, line-height **1.5**, màu `fg-2`; 2 link "Điều khoản dịch vụ" / "Chính sách bảo mật" màu primary (sáng mặc định link, tối `#6AADFF`).

**Nút chính "Đăng ký"**
- height **52px**, radius **6px**, nền primary, chữ trắng 16px/weight 800, margin-top **8px**.

**Footer "Đã có tài khoản? Đăng nhập"**
- `text-align: center`, font 13px, màu `fg-3`; "Đăng nhập" weight 700 màu primary — không có margin-top riêng (kế ngay dưới nút, theo `gap: 14px` của cột cha).

---

## 3. Ghi chú dùng chung
- Tất cả input là ô bo góc **6px**, viền **1.5px** — không dùng viền 1px cho input (khác card).
- Placeholder trong mockup chỉ minh hoạ nội dung mẫu; input thật để trống, có `hintText` tương ứng.
- Trạng thái focus: viền chuyển sang ring xanh 3px (`--shadow-focus`) theo design system — mockup không thể hiện, cần tự thêm khi build.
- Trạng thái lỗi (validate sai số điện thoại, mật khẩu không khớp, checkbox chưa tick...) chưa có trong mockup — style theo `danger` token (sáng `#A42619` / tối `#E07A6D`) nếu cần, hỏi lại nếu muốn spec riêng cho error state.
- Toàn bộ theme sáng/tối chỉ khác token màu — layout, kích thước, khoảng cách giữ nguyên 1:1 giữa 2 chế độ.
