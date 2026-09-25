include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = BoostiPhone6sPrefs

BoostiPhone6sPrefs_FILES = RootListController.m
BoostiPhone6sPrefs_INSTALL_PATH = /Library/PreferenceBundles
BoostiPhone6sPrefs_INSTALL_INFO = Info.plist

# Frameworks chuẩn
BoostiPhone6sPrefs_FRAMEWORKS = UIKit Foundation
BoostiPhone6sPrefs_PRIVATE_FRAMEWORKS = Preferences

# SỬA: THÊM CFLAGS ĐỂ TRÁNH LỖI LINKER VÀ ĐỊNH NGHĨA FLAG BUILD
# -F giúp linker tìm PrivateFrameworks trong SDK
# -DBUILDING_SUBPROJECT để kích hoạt conditional import trong code
BoostiPhone6sPrefs_CFLAGS = -fobjc-arc -F$(THEOS)/sdks/iPhoneOS16.5.sdk/System/Library/PrivateFrameworks -DBUILDING_SUBPROJECT
BoostiPhone6sPrefs_LDFLAGS = -F$(THEOS)/sdks/iPhoneOS16.5.sdk/System/Library/PrivateFrameworks

include $(THEOS_MAKE_PATH)/bundle.mk
