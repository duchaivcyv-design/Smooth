ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = BoostiPhone6sPrefs

# File mã nguồn
BoostiPhone6sPrefs_FILES = RootListController.m

# Framework công khai và Framework giao diện Settings của Apple
BoostiPhone6sPrefs_FRAMEWORKS = UIKit CoreGraphics Foundation
BoostiPhone6sPrefs_PRIVATE_FRAMEWORKS = Preferences

# Đường dẫn cài đặt bundle cho jailbreak Rootless
BoostiPhone6sPrefs_INSTALL_PATH = /Library/PreferenceBundles

# Thêm đường dẫn tìm file Header (trỏ ra thư mục Smooth/Headers ở cấp cha)
BoostiPhone6sPrefs_CFLAGS = -fobjc-arc \
                            -O3 \
                            -I../Headers \
                            -I../ \
                            -Wno-deprecated-declarations \
                            -Wno-unknown-warning-option

# Bỏ qua kiểm tra ký hiệu Preferences lúc link (nạp động khi chạy trên iOS)
BoostiPhone6sPrefs_LDFLAGS = -Wl,-dead_strip -Wl,-undefined,dynamic_lookup

include $(THEOS_MAKE_PATH)/bundle.mk
