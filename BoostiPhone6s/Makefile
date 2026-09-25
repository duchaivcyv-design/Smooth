include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = BoostiPhone6sPrefs

BoostiPhone6sPrefs_FILES = RootListController.m
BoostiPhone6sPrefs_INSTALL_PATH = /Library/PreferenceBundles
BoostiPhone6sPrefs_INSTALL_INFO = Info.plist

BoostiPhone6sPrefs_RESOURCE_DIRS = Resources

BoostiPhone6sPrefs_FRAMEWORKS = UIKit Foundation
BoostiPhone6sPrefs_PRIVATE_FRAMEWORKS = Preferences

# v10: -I../Headers de tim PSListController.h, PSSpecifier.h
# v10: -I. de tim RootListController.h cung thu muc
# v10: -F SDK path dong cho PrivateFrameworks
BoostiPhone6sPrefs_CFLAGS = -fobjc-arc \
                            -I../Headers \
                            -I. \
                            -F$(THEOS)/sdks/iPhoneOS16.5.sdk/System/Library/PrivateFrameworks \
                            -DBUILDING_SUBPROJECT

BoostiPhone6sPrefs_LDFLAGS = -F$(THEOS)/sdks/iPhoneOS16.5.sdk/System/Library/PrivateFrameworks

include $(THEOS_MAKE_PATH)/bundle.mk
