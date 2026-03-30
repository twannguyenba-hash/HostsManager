# HostsManager

Ứng dụng native macOS để quản lý file `/etc/hosts` với giao diện đồ hoạ.

## Tính năng

- Đọc và parse file `/etc/hosts` tự động
- Thêm, sửa, xóa entry với giao diện trực quan
- Bật/tắt entry bằng toggle switch
- Ghi trực tiếp vào `/etc/hosts` với quyền admin (hiện dialog nhập mật khẩu macOS)
- Tự động flush DNS cache sau khi áp dụng
- Import/Export nội dung hosts
- Tạo backup file hosts
- Preset nhanh để chặn mạng xã hội hoặc thêm domain dev
- Tìm kiếm entry theo IP, hostname, comment
- Bộ lọc: Tất cả, Đang bật, Đã tắt, Đang chặn

## Yêu cầu

- macOS 13.0 (Ventura) trở lên
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

1. Mở app, danh sách entries từ `/etc/hosts` sẽ hiển thị tự động
2. Dùng toggle để bật/tắt entry
3. Nhấn "+" để thêm entry mới
4. Nhấn "Áp dụng" để ghi thay đổi vào `/etc/hosts`
5. Nhập mật khẩu admin khi được yêu cầu

## Giấy phép

MIT
