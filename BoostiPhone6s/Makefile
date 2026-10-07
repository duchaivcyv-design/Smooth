ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:14.0

DEBUG = 0
FINALPACKAGE = 1
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = BoostiPhone6sApp

# [ĐÃ ÉP TOÀN DIỆN]: Nạp toàn bộ mã nguồn vòng đời và giao diện App
BoostiPhone6sApp_FILES = main.m \
                         AppDelegate.m \
                         RootListController.m

BoostiPhone6sApp_FRAMEWORKS = UIKit CoreGraphics Foundation QuartzCore
BoostiPhone6sApp_INSTALL_PATH = /Applications

# CỜ BIÊN DỊCH: ĐỒNG BỘ HOÀN TOÀN & DẬP TẮT CẢNH BÁO RUNNER
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
                          -I$(THEOS)/include \
                          -I$(THEOS)/vendor/include \
                          -I../Headers \
                          -I../ \
                          -I.

# LINKER FLAGS: LIÊN KẾT NHỊ PHÂN VÀ ĐỊNH VỊ FRAMEWORK HỆ THỐNG
BoostiPhone6sApp_LDFLAGS = -Wl,-dead_strip \
                          -Wl,-undefined,dynamic_lookup \
                          -Wl,-rpath,/System/Library/PrivateFrameworks \
                          -Wl,-rpath,/Library/Frameworks \
                          -Wl,-rpath,/var/jb/Library/Frameworks \
                          -Wl,-rpath,/usr/lib \
                          -Wl,-rpath,/var/jb/usr/lib

# [ĐÃ ÉP TOÀN DIỆN]: Ký quyền vượt Sandbox qua entitlements.plist
BoostiPhone6sApp_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk

# [ĐÃ ÉP TOÀN DIỆN]: ĐỒNG BỘ PHÂN QUYỀN 0755 VÀ CHUẨN BỊ MÔI TRƯỜNG CHO UICACHE
after-stage::
	@echo "=== [BoostiPhone6sApp] Cấp quyền nhị phân & cấu hình ứng dụng vào Staging ==="
	@APP_DIR="$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)/Applications/BoostiPhone6sApp.app"; \
	mkdir -p "$$APP_DIR"; \
	chmod -R 0755 "$$APP_DIR"; \
	chmod 0644 "$$APP_DIR"/*.plist 2>/dev/null || true; \
	echo "  [OK] Đã hoàn tất đóng gói App độc lập vào $$APP_DIR!"
