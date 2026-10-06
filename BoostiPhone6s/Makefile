# ====================================================================================================
# MAKEFILE CON: CÀI ĐẶT PREFERENCES BUNDLE (CHẾ ĐỘ ÉP TOÀN DIỆN CHO ROOTLESS & ROOTHIDE)
# (ĐÃ LOẠI BỎ LIÊN KẾT TĨNH PREFERENCES FRAMEWORK - SỬ DỤNG RUNTIME DYNAMIC LOOKUP)
# ====================================================================================================

ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:14.0

DEBUG = 0
FINALPACKAGE = 1
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = BoostiPhone6sPrefs

BoostiPhone6sPrefs_FILES = RootListController.m

# PUBLIC FRAMEWORKS CHUẨN
BoostiPhone6sPrefs_FRAMEWORKS = UIKit CoreGraphics Foundation QuartzCore

# [ÉP TOÀN DIỆN]: ĐÃ BỎ PRIVATE_FRAMEWORKS = Preferences ĐỂ TRÁNH GÃY LINKER TRÊN SDK 16.5
# Runtime tự giải quyết symbol qua -Wl,-undefined,dynamic_lookup

# ĐƯỜNG DẪN CÀI ĐẶT CHUẨN ROOTLESS THÍCH ỨNG $(_THEOS_PREFIX)
BoostiPhone6sPrefs_INSTALL_PATH = $(_THEOS_PREFIX)/Library/PreferenceBundles

# CỜ BIÊN DỊCH TỐI ƯU HÓA -O3, FLTO VÀ DẬP TẮT CẢNH BÁO
BoostiPhone6sPrefs_CFLAGS = -fobjc-arc \
                            -O3 \
                            -flto=thin \
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
                            -IHeaders \
                            -I../ \
                            -I.

# LINKER FLAGS: SỬ DỤNG DYNAMIC LOOKUP ĐỂ NẠP PREFERENCES KHI VÀO SETTINGS
BoostiPhone6sPrefs_LDFLAGS = -Wl,-dead_strip \
                            -flto=thin \
                            -Wl,-undefined,dynamic_lookup \
                            -Wl,-rpath,/System/Library/PrivateFrameworks \
                            -Wl,-rpath,/Library/Frameworks \
                            -Wl,-rpath,/var/jb/Library/Frameworks \
                            -Wl,-rpath,/usr/lib \
                            -Wl,-rpath,/var/jb/usr/lib

include $(THEOS_MAKE_PATH)/bundle.mk

# ====================================================================================================
# ĐỒNG BỘ SYMLINK TỰ ĐỘNG & ENTRY PLIST CHO PREFERENCELOADER (ÉP CHUẨN ROOTLESS)
# ====================================================================================================

after-stage::
	@echo ""
	@echo "=== [BoostiPhone6sPrefs] Đồng bộ Symlink & Quyền Bundle vào Staging ==="
	@TARGET_DIR="$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)/Library/PreferenceBundles"; \
	PREFLOADER_DIR="$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)/Library/PreferenceLoader/Preferences"; \
	mkdir -p "$$TARGET_DIR"; \
	mkdir -p "$$PREFLOADER_DIR"; \
	if [ -d "$$TARGET_DIR/BoostiPhone6sPrefs.bundle" ]; then \
		(cd "$$TARGET_DIR" && ln -sf "BoostiPhone6sPrefs.bundle" "BoostiPhone6s.bundle"); \
		echo "  [OK] Đã tạo symlink BoostiPhone6s.bundle -> BoostiPhone6sPrefs.bundle"; \
		chmod -R 0755 "$$TARGET_DIR/BoostiPhone6sPrefs.bundle"; \
		chmod 0644 "$$TARGET_DIR/BoostiPhone6sPrefs.bundle"/*.plist 2>/dev/null || true; \
		echo "  [OK] Đã gán quyền 0755 cho Bundle!"; \
	fi; \
	if [ -d "$$PREFLOADER_DIR" ]; then \
		chmod 0644 "$$PREFLOADER_DIR"/*.plist 2>/dev/null || true; \
		echo "  [OK] Đã gán quyền 0644 cho PreferenceLoader plist!"; \
	fi
	@echo "
