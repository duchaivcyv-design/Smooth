include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = BoostiPhone6sPrefs

BoostiPhone6sPrefs_FILES = RootListController.m
BoostiPhone6sPrefs_INSTALL_PATH = /Library/PreferenceBundles
BoostiPhone6sPrefs_INSTALL_INFO = Info.plist

# Khai báo Frameworks
BoostiPhone6sPrefs_FRAMEWORKS = UIKit Foundation
BoostiPhone6sPrefs_PRIVATE_FRAMEWORKS = Preferences

# Thêm đường dẫn tìm kiếm PrivateFrameworks trực tiếp trong SDK được tải về
BoostiPhone6sPrefs_CFLAGS = -fobjc-arc -F$(THEOS)/sdks/iPhoneOS16.5.sdk/System/Library/PrivateFrameworks
BoostiPhone6sPrefs_LDFLAGS = -F$(THEOS)/sdks/iPhoneOS16.5.sdk/System/Library/PrivateFrameworks -undefined dynamic_lookup

include $(THEOS_MAKE_PATH)/bundle.mk
