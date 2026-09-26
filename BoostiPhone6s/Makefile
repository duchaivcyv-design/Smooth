ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = BoostiPhone6sPrefs

# File thực thi giao diện cài đặt
BoostiPhone6sPrefs_FILES = RootListController.m

# Chỉ liên kết các framework công khai có sẵn trong SDK
BoostiPhone6sPrefs_FRAMEWORKS = UIKit CoreGraphics Foundation

# Thư mục cài đặt bundle rootless
BoostiPhone6sPrefs_INSTALL_PATH = /Library/PreferenceBundles

# Cờ biên dịch
BoostiPhone6sPrefs_CFLAGS = -fobjc-arc \
                            -O3 \
                            -Wno-deprecated-declarations \
                            -Wno-unknown-warning-option

# Bỏ qua kiểm tra ký hiệu Preferences lúc link (nạp động khi chạy trên iOS)
BoostiPhone6sPrefs_LDFLAGS = -Wl,-dead_strip -Wl,-undefined,dynamic_lookup

include $(THEOS_MAKE_PATH)/bundle.mk
