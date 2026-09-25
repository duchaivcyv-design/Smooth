include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = BoostiPhone6sPrefs

BoostiPhone6sPrefs_FILES = RootListController.m
BoostiPhone6sPrefs_INSTALL_PATH = /Library/PreferenceBundles
BoostiPhone6sPrefs_INSTALL_INFO = Info.plist

# Frameworks chuẩn
BoostiPhone6sPrefs_FRAMEWORKS = UIKit Foundation
BoostiPhone6sPrefs_PRIVATE_FRAMEWORKS = Preferences

# ★ SỬA: DÙNG THEOS_SDK_DIR THAY VÌ HARDCODE SDK PATH ★
# $(THEOS_SDK_DIR) tự động trỏ đến SDK đang dùng trong môi trường build
# Hoạt động trên mọi phiên bản SDK (16.x, 17.x, 26.x)
BoostiPhone6sPrefs_CFLAGS = -fobjc-arc \
                            -F$(THEOS_SDK_DIR)/System/Library/PrivateFrameworks \
                            -DBUILDING_SUBPROJECT

BoostiPhone6sPrefs_LDFLAGS = -F$(THEOS_SDK_DIR)/System/Library/PrivateFrameworks

include $(THEOS_MAKE_PATH)/bundle.mk
