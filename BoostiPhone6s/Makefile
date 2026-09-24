include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = BoostiPhone6sPrefs

BoostiPhone6sPrefs_FILES = RootListController.m
BoostiPhone6sPrefs_INSTALL_PATH = /Library/PreferenceBundles
BoostiPhone6sPrefs_CFLAGS = -fobjc-arc

# Bắt buộc phải khai báo dùng UIKit, Foundation và Preferences (dạng private framework)
BoostiPhone6sPrefs_FRAMEWORKS = UIKit Foundation
BoostiPhone6sPrefs_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/bundle.mk
