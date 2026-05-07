# HostsManager

Ứng dụng native macOS để quản lý file `/etc/hosts` và `.env` files của repo dev với giao diện thiết kế dành riêng cho developer.

## Tính năng v2.0

### Hosts management
- Parse và edit `/etc/hosts` với syntax tag markers `## [tag:Name]`
- **Profile system**: nhóm hosts theo profile (Release/Production/Master/...) với màu phân biệt
- Bật/tắt entry với DSToggle 24×13 spring animation
- IP color tokens: localhost xanh nhạt, remote xanh lục, blocking đỏ
- Apply với sudo qua AppleScript, cache 5 phút trong session
- Auto DNS flush sau khi áp dụng

### Env file management (carry-over từ v1.7.7)
- Quản lý nhiều repo, mỗi repo nhiều `.env` file
- Profile env vars per repo: save/restore bộ env states
- Raw editor mode cho file edit trực tiếp

### UI/UX redesign v2
- **Profile-first sidebar**: card gradient cho profile đang active, ⌘1-9 shortcut
- **Custom window chrome**: hidden title bar, gradient TitleBar 44px overlap traffic lights
- **Inline detail header**: title + count + search + view mode + actions
- **StatusBar 28px**: file path + pending counter + Apply ⌘S gradient blue button
- Dark mode primary với design tokens: Colors/Typography/Spacing/Radius

## Yêu cầu

- macOS 14.0 (Sonoma) trở lên — bumped từ v1 vì cần `@Observable`, `NavigationSplitView` modern
- Xcode 15+ (để build)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Cài đặt

### Homebrew (khuyên dùng)

```bash
brew tap twannguyenba-hash/hostsmanager
brew install hostsmanager

# Cập nhật lên phiên bản mới
brew update && brew upgrade hostsmanager
```

### Build từ source

```bash
# Cách 1: Script tự động
chmod +x setup.sh
./setup.sh

# Cách 2: Make
make build
make install

# Cách 3: Xcode
xcodegen generate
open HostsManager.xcodeproj
# Nhấn Cmd+R để chạy
```

## Sử dụng

1. Mở app, danh sách entries từ `/etc/hosts` hiển thị tự động
2. Click profile bên sidebar để filter hosts theo nhóm; click lần nữa hoặc ⌘0 để xem tất cả
3. Dùng ⌘1, ⌘2, ⌘3... để switch profile nhanh (mapping theo `Profile.shortcutNumber`)
4. Toggle bật/tắt entry inline
5. Nhấn ⌘S (hoặc click "Áp dụng" ở StatusBar) để ghi thay đổi vào `/etc/hosts`
6. Nhập mật khẩu admin khi được yêu cầu (cache 5 phút)

Settings (⌘,): chọn theme, quản lý profiles.

## Giấy phép

MIT
