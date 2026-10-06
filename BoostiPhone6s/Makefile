ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:14.0

DEBUG = 0
FINALPACKAGE = 1
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = BoostiPhone6sPrefs

BoostiPhone6sPrefs_FILES = RootListController.m MockDeviceViewController.m
BoostiPhone6sPrefs_FRAMEWORKS = UIKit CoreGraphics Foundation
BoostiPhone6sPrefs_INSTALL_PATH = /Library/PreferenceBundles

# CỜ BIÊN DỊCH: ĐỒNG BỘ HOÀN TOÀN VỚI MAKEFILE CHA & DẬP TẮT CẢNH BÁO RUNNER
BoostiPhone6sPrefs_CFLAGS = -fobjc-arc \
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

# LINKER FLAGS: LOẠI BỎ CẢNH BÁO -install_name TRÊN MACH-O BUNDLE
BoostiPhone6sPrefs_LDFLAGS = -Wl,-dead_strip \
                            -Wl,-undefined,dynamic_lookup \
                            -Wl,-rpath,/System/Library/PrivateFrameworks \
                            -Wl,-rpath,/Library/Frameworks \
                            -Wl,-rpath,/var/jb/Library/Frameworks \
                            -Wl,-rpath,/usr/lib \
                            -Wl,-rpath,/var/jb/usr/lib

include $(THEOS_MAKE_PATH)/bundle.mk

# ĐỒNG BỘ SYMLINK TỰ ĐỘNG & CẤP QUYỀN CHUẨN ROOTLESS CHO PREFERENCELOADER
after-stage::
	@echo "=== [BoostiPhone6sPrefs] Đồng bộ Symlink & Quyền Bundle vào Staging ==="
	@TARGET_DIR="$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)/Library/PreferenceBundles"; \
	mkdir -p "$$TARGET_DIR"; \
	if [ -d "$$TARGET_DIR/BoostiPhone6sPrefs.bundle" ] && [ ! -e "$$TARGET_DIR/BoostiPhone6s.bundle" ]; then \
		ln -sf "BoostiPhone6sPrefs.bundle" "$$TARGET_DIR/BoostiPhone6s.bundle"; \
		echo "  [OK] Đã tạo symlink BoostiPhone6s.bundle -> BoostiPhone6sPrefs.bundle"; \
	fi; \
	chmod -R 0755 "$$TARGET_DIR/BoostiPhone6sPrefs.bundle"; \
	chmod 0644 "$$TARGET_DIR/BoostiPhone6sPrefs.bundle"/*.plist 2>/dev/null || true; \
	echo "  [OK] Đã gán quyền 0755 cho Bundle!"
