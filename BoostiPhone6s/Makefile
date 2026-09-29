ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0

# Tắt log rác, tối ưu hóa gói bundle cho môi trường Production
DEBUG = 0
FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

# Định nghĩa Tweak chính và Giao diện Cài đặt (Prefs)
TWEAK_NAME = BoostiPhone6s
BUNDLE_NAME = BoostiPhone6sPrefs

# Mã nguồn Tweak chính
BoostiPhone6s_FILES = RootListController.m
BoostiPhone6s_CFLAGS = -fobjc-arc -O3 -Wall -Wno-error -Wno-deprecated-declarations -Wno-unknown-warning-option -Wno-unused-variable -Wno-unused-function -Wno-implicit-function-declaration -Wno-deprecated-non-prototype -fno-autolink
BoostiPhone6s_FRAMEWORKS = UIKit Foundation CoreGraphics Metal QuartzCore
BoostiPhone6s_LDFLAGS = -Wl,-dead_strip -Wl,-undefined,dynamic_lookup

# Mã nguồn Giao diện Cài đặt V26 SUPREME
BoostiPhone6sPrefs_FILES = RootListController.m
BoostiPhone6sPrefs_FRAMEWORKS = UIKit CoreGraphics Foundation
BoostiPhone6sPrefs_INSTALL_PATH = /Library/PreferenceBundles
BoostiPhone6sPrefs_CFLAGS = -fobjc-arc \
                            -O3 \
                            -Wall \
                            -Wno-error \
                            -Wno-deprecated-declarations \
                            -Wno-unknown-warning-option \
                            -Wno-unused-variable \
                            -Wno-unused-function \
                            -Wno-implicit-function-declaration \
                            -Wno-deprecated-non-prototype \
                            -fno-autolink \
                            -I../Headers \
                            -I../Modules \
                            -I../ \
                            -I.

BoostiPhone6sPrefs_LDFLAGS = -Wl,-dead_strip \
                            -Wl,-undefined,dynamic_lookup

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk

# Tự động dọn dẹp bộ nhớ đệm sau khi build xong
after-package::
	rm -rf .theos/ _/
