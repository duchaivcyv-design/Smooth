ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:14.0

DEBUG = 0
FINALPACKAGE = 1
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = BoostiPhone6sApp

# [ĐÃ ÉP TOÀN DIỆN]: Nạp các tệp mã nguồn chính của ứng dụng
BoostiPhone6sApp_FILES = main.m \
                         AppDelegate.m \
                         RootListController.m

BoostiPhone6sApp_FRAMEWORKS = UIKit CoreGraphics Foundation QuartzCore
BoostiPhone6sApp_INSTALL_PATH = /Applications

# CỜ BIÊN DỊCH: TỐI ƯU HÓA O3 & LOẠI BỎ INCLUDE THỪA
BoostiPhone6sApp_CFLAGS = -fobjc-arc \
                          -O3 \
                          -Wall \
                          -Wno-error \
                          -Wno-deprecated-declarations \
                          -Wno-unused-variable \
                          -Wno-unused-function \
                          -Wno-implicit-function-declaration \
                          -Wno-deprecated-non-prototype \
                          -Wno-unused-command-line-argument \
                          -Wno-unguarded-availability-new \
                          -Wno-unguarded-availability \
                          -D__IPHONE_OS_VERSION_MIN_REQUIRED=140000 \
                          -IHeaders \
                          -I../Headers \
                          -I.

# LINKER FLAGS: LIÊN KẾT NHỊ PHÂN TINH GỌN
BoostiPhone6sApp_LDFLAGS = -Wl,-dead_strip \
                          -Wl,-undefined,dynamic_lookup

# [ĐÃ ÉP TOÀN DIỆN]: Ký quyền vượt Sandbox qua entitlements.plist
BoostiPhone6sApp_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk

# [ĐÃ ÉP TOÀN DIỆN]: PHÂN QUYỀN CHUẨN 0755 CHO ỨNG DỤNG HỆ THỐNG
after-stage::
	@echo "=== [BoostiPhone6sApp] Cấp quyền nhị phân & hoàn tất Staging ==="
	@chmod -R 0755 "$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)/Applications/BoostiPhone6sApp.app"
	@chmod 0644 "$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)/Applications/BoostiPhone6sApp.app"/*.plist 2>/dev/null || true
	@echo "  [OK] Đã hoàn tất đóng gói BoostiPhone6sApp!"
