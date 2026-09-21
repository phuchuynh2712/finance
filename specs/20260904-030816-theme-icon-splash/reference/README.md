# Kiểm Soát — Design Handoff Package

Gói bàn giao thiết kế cho app "Quản lý tài chính cá nhân" — đủ để dựng theme sáng/tối, app icon, và bộ icon trong Flutter (hoặc bất kỳ stack nào khác).

## Nội dung gói

```
handoff/
├── README.md                 ← file này
├── theme-tokens.json          ← toàn bộ màu (sáng+tối), type scale, spacing, radius, shadow, motion
├── icons-used.json            ← danh sách icon Lucide đã dùng + cách cài trong Flutter
└── app-icon/
    ├── app-icon-khai-tam.svg  ← nguồn vector (chỉnh sửa được)
    └── app-icon-{size}.png    ← 1024/512/192/180/144/120/96/87/72/60/48px
```

## 1. Theme — màu sắc

Tất cả giá trị nằm trong `theme-tokens.json`, tách `light` và `dark`. Đây KHÔNG phải màu tự chuyển đổi tự động — light và dark là hai bộ giá trị được thiết kế riêng, cùng ngữ nghĩa vai trò (primary, danger, success, warning, bg, fg, border) nhưng khác độ sáng/độ bão hoà để đủ tương phản trên nền tối.

**Cách dựng trong Flutter (ví dụ với `ColorScheme` + `ThemeData`):**

```dart
final lightScheme = ColorScheme.light(
  primary: Color(0xFF1A72E0),
  onPrimary: Colors.white,
  surface: Color(0xFFFFFFFF),
  background: Color(0xFFFAF8F5),
  onSurface: Color(0xFF1A1714),
  outline: Color(0xFFD4CCC0),
  error: Color(0xFFA42619),
);

final darkScheme = ColorScheme.dark(
  primary: Color(0xFF3B8DF8),
  onPrimary: Colors.white,
  surface: Color(0xFF241F1A),
  background: Color(0xFF1A1714),
  onSurface: Color(0xFFFAF8F5),
  outline: Color(0xFF4A443B),
  error: Color(0xFFE07A6D),
);

ThemeData.from(colorScheme: lightScheme).copyWith(
  scaffoldBackgroundColor: lightScheme.background,
  textTheme: GoogleFonts.lexendTextTheme(),
);
```

Dùng `ThemeMode.system` (hoặc toggle thủ công từ màn Hồ sơ, như trong mockup) và cấp cả `theme:` (light) lẫn `darkTheme:` (dark) cho `MaterialApp`.

**Semantic colors dùng ở đâu:**
- `primary` (xanh biển) — nút chính, link, tab đang chọn, số dư dương.
- `success` (xanh lá) — thu nhập, số dư khoản tiết kiệm.
- `danger` (đỏ) — số dư âm, cảnh báo, nút xoá/đăng xuất. Dùng tiết kiệm, không trang trí.
- `warning` (vàng/gold) — banner thông tin phân bổ %, không dùng cho lỗi.
- Neutrals (fg1/fg2/fg3, bg-app/bg-surface/bg-sunken, border1/border2) làm ~80% việc còn lại.

## 2. Typography

- Font UI/body: **Lexend** (Google Fonts) — `google_fonts` package: `GoogleFonts.lexend(...)`.
- Font hiển thị lớn (nếu có màn marketing): **Crimson Pro**.
- Cỡ chữ tối thiểu đã dùng trong mockup: 11-12px cho caption phụ, 14px+ cho nội dung chính, 18px cho tiêu đề màn hình — không xuống dưới 11px ở bất kỳ đâu (đã rà theo yêu cầu dễ đọc cho người lớn tuổi).

## 3. Spacing, bo góc, đổ bóng

Xem chi tiết số trong `theme-tokens.json`. Điểm quan trọng nhất: **vùng chạm tối thiểu 44px** cho mọi nút/icon thao tác (đã rà và sửa toàn app theo chuẩn này — vừa đạt tối thiểu Apple HIG 44pt, gần với Material 48dp).

## 4. Icon

Bộ icon: **Lucide** (line icon, stroke 2px). Trong Flutter, cài package `lucide_icons`:

```
flutter pub add lucide_icons
```

Xem `icons-used.json` để biết chính xác icon nào đã dùng ở đâu — khỏi phải đoán hoặc quét lại toàn app.

## 5. App icon

- File nguồn: `app-icon/app-icon-khai-tam.svg` (hoa sen 5 cánh, nền vàng sáng, cánh trắng/xanh biển, đế đỏ — đúng 3 màu thương hiệu Kiểm Soát, đổi từ nền xanh đậm gốc để icon nổi bật, dễ nhận ở kích thước nhỏ).
- Đã xuất sẵn PNG ở các size cần cho:
  - **iOS**: 1024 (App Store), 180, 120, 87, 60 (@1x/2x/3x các slot trong Assets.xcassets).
  - **Android**: 512 (Play Store), 192, 144, 96, 72, 48 (mipmap-xxxhdpi → mipmap-mdpi).
- Dùng công cụ như `flutter_launcher_icons` package để tự sinh toàn bộ biến thể (adaptive icon Android, rounded/square iOS) từ file 1024px:
  ```
  flutter pub add flutter_launcher_icons --dev
  ```
  rồi trỏ `image_path: "handoff/app-icon/app-icon-1024.png"` trong `pubspec.yaml`.

## 6. Việc còn lại khi code thật (không có trong file tĩnh này)

- Icon "quay lại" nên thích ứng theo nền tảng: mũi tên cong `<` trên iOS, mũi tên thẳng `←` (Material `arrow_back`) trên Android — dùng widget thích ứng của Flutter, không cần 2 bộ thiết kế.
- Toggle Sáng/Tối ở màn Hồ sơ trong mockup chỉ là UI tĩnh minh hoạ vị trí — cần nối vào `ThemeMode` thật (lưu lựa chọn người dùng, ví dụ bằng `shared_preferences`).
