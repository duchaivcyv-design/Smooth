ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0

DEBUG = 0
FINALPACKAGE = 1
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = BoostiPhone6sApp

BoostiPhone6sApp_FILES = main.m \
                         AppDelegate.m \
                         RootListController.m

BoostiPhone6sApp_FRAMEWORKS = UIKit CoreGraphics Foundation QuartzCore AudioToolbox IOKit
BoostiPhone6sApp_INSTALL_PATH = $(_THEOS_PREFIX)/Applications

BoostiPhone6sApp_RESOURCE_DIRS = Resources

BoostiPhone6sApp_CFLAGS = -fobjc-arc \
                          -O2 \
                          -Wall \
                          -Wno-unused-variable \
                          -Wno-unused-function \
                          -Wno-deprecated-declarations \
                          -Wno-deprecated-non-prototype \
                          -Wno-macro-redefined \
                          -Wno-unused-command-line-argument \
                          -Wno-unguarded-availability-new \
                          -Wno-unguarded-availability \
                          -IHeaders \
                          -I../Headers \
                          -I.

BoostiPhone6sApp_LDFLAGS = -Wl,-dead_strip \
                           -Wl,-undefined,dynamic_lookup

BoostiPhone6sApp_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk

after-stage::
	@echo "=== [BoostiPhone6sApp] Cấp quyền phân phối gói Rootless ==="
	@APP_DIR="$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)/Applications/BoostiPhone6sApp.app"; \
	if [ -d "$$APP_DIR" ]; then \
		find "$$APP_DIR" -type d -exec chmod 0755 {} +; \
		find "$$APP_DIR" -type f -exec chmod 0644 {} +; \
		if [ -f "$$APP_DIR/BoostiPhone6sApp" ]; then \
			chmod 0755 "$$APP_DIR/BoostiPhone6sApp"; \
			echo "  [OK] Binary 0755"; \
		else \
			echo "  [WARN] Binary không tìm thấy: $$APP_DIR/BoostiPhone6sApp"; \
		fi; \
		echo "  [OK] Folder 0755, file 0644, binary 0755"; \
	else \
		echo "  [ERROR] App bundle không tồn tại: $$APP_DIR"; \
		exit 1; \
	fi
