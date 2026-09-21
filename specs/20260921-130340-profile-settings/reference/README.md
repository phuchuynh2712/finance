# Hồ sơ — Handoff package

Nguồn: `Finance App Mockups.dc.html`, màn 5 (sáng) và màn 17 (tối). Có bottom nav, tab "Hồ sơ" active. Đây là màn đổi giao diện Sáng/Tối.

## Nội dung
- `ho-so-spec.md` — spec chi tiết từng element, sáng & tối.
- `icons.json` — icon dùng trong màn này, kèm mapping Flutter.
- `theme-tokens.json` — toàn bộ token màu/spacing/type/radius/motion.

## Ghi chú dựng Flutter
- Frame điện thoại 390×844 chỉ để trình bày — vùng nội dung thật dùng `SafeArea`.
- Đơn vị spec = logical pixel ở thiết kế tham chiếu rộng 390px, quy đổi 1:1 sang Flutter `double`.
- Font UI: **Lexend** (`google_fonts`).
- Toggle "Sáng/Tối" là segmented control 2 lựa chọn nối liền `ThemeMode` thật của app — chuyển `ThemeData` toàn app khi bấm, không chỉ đổi màu cục bộ màn này.
- Avatar hiện dùng chữ cái đầu tên ("L") trên nền tròn — cần fallback này khi user chưa có ảnh đại diện; nếu có ảnh thật, thay bằng `CircleAvatar` ảnh.
- 3 dòng "Thông báo/Bảo mật/Trợ giúp" hiện chưa có màn đích trong mockup — cần thống nhất route/nội dung riêng nếu muốn hoạt động đầy đủ.
