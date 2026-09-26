ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = BoostiPhone6sPrefs

# Khai báo mã nguồn điều khiển giao diện Cài đặt
BoostiPhone6sPrefs_FILES = RootListController.m

# Khung làm việc bắt buộc cho Preferences UI
BoostiPhone6sPrefs_FRAMEWORKS = UIKit CoreGraphics Foundation
BoostiPhone6sPrefs_PRIVATE_FRAMEWORKS = Preferences

# Đường dẫn cài đặt Bundle theo chuẩn Theos Rootless
BoostiPhone6sPrefs_INSTALL_PATH = /Library/PreferenceBundles

# Cờ biên dịch: Tối ưu hiệu năng, triệt tiêu cảnh báo deprecated
BoostiPhone6sPrefs_CFLAGS = -fobjc-arc \
                            -O3 \
                            -Wno-deprecated-declarations \
                            -Wno-unknown-warning-option

# Cờ liên kết: Khắc phục triệt để lỗi dynamic_lookup & multiply_defined obsolete
BoostiPhone6sPrefs_LDFLAGS = -Wl,-dead_strip

include $(THEOS_MAKE_PATH)/bundle.mk
