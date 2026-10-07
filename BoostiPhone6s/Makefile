ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:14.0

DEBUG = 0
FINALPACKAGE = 1
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = BoostiPhone6sApp

# Nạp các tệp mã nguồn chính của ứng dụng
BoostiPhone6sApp_FILES = main.m \
                         AppDelegate.m \
                         RootListController.m

BoostiPhone6sApp_FRAMEWORKS = UIKit CoreGraphics Foundation QuartzCore AudioToolbox
BoostiPhone6sApp_INSTALL_PATH = $(_THEOS_PREFIX)/Applications

# CỜ BIÊN DỊCH: TỐI ƯU HÓA O3 & TƯƠNG THÍCH ĐẦY ĐỦ CÁC MACRO
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

# LINKER FLAGS
BoostiPhone6sApp_LDFLAGS = -Wl,-dead_strip

# Ký quyền chuẩn qua cơ chế tự động của Theos
BoostiPhone6sApp_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk

# ĐẢM BẢO QUYỀN THỰC THI CHO BINARY VÀ GÓI APP
after-stage::
	@echo "=== [BoostiPhone6sApp] Cấp quyền phân phối gói Rootless ==="
	@APP_DIR="$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)/Applications/BoostiPhone6sApp.app"; \
	chmod -R 0755 "$$APP_DIR"; \
	chmod 0755 "$$APP_DIR/BoostiPhone6sApp"; \
	echo "  [OK] Đã hoàn tất phân quyền 0755!"
