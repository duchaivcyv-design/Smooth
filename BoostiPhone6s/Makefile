include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = BoostiPhone6sPrefs

BoostiPhone6sPrefs_FILES = RootListController.m
BoostiPhone6sPrefs_INSTALL_PATH = /Library/PreferenceBundles

# Khai báo Frameworks
BoostiPhone6sPrefs_FRAMEWORKS = UIKit Foundation
BoostiPhone6sPrefs_PRIVATE_FRAMEWORKS = Preferences

# Ép thêm đường dẫn tìm kiếm PrivateFrameworks cho linker (Khắc phục triệt để lỗi ld not found trên CI/CD)
BoostiPhone6sPrefs_LDFLAGS += -F$(THEOS)/sdks/iPhoneOS.sdk/System/Library/PrivateFrameworks
BoostiPhone6sPrefs_CFLAGS += -fobjc-arc -F$(THEOS)/sdks/iPhoneOS.sdk/System/Library/PrivateFrameworks

BoostiPhone6sPrefs_INSTALL_INFO = Info.plist

include $(THEOS_MAKE_PATH)/bundle.mk
