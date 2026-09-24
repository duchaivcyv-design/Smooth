include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = BoostiPhone6sPrefs

BoostiPhone6sPrefs_FILES = RootListController.m
BoostiPhone6sPrefs_INSTALL_PATH = /Library/PreferenceBundles
BoostiPhone6sPrefs_FRAMEWORKS = UIKit Foundation
BoostiPhone6sPrefs_PRIVATE_FRAMEWORKS = Preferences
BoostiPhone6sPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk

# Tự động tạo thư mục usr/lib và copy core dylib ngay khi subproject chạy gói package
internal-stage::
	@echo "Auto-injecting BoostiPhone6sCore.dylib into usr/lib..."
	@mkdir -p $(THEOS_STAGING_DIR)/usr/lib
	@cp $(THEOS_OBJ_DIR)/../BoostiPhone6sCore.dylib $(THEOS_STAGING_DIR)/usr/lib/BoostiPhone6sCore.dylib
	@codesign -s - --entitlements "" $(THEOS_STAGING_DIR)/usr/lib/BoostiPhone6sCore.dylib 2>/dev/null || true
