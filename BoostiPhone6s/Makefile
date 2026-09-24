include $(THEOS)/makefiles/common.mk

BUNDLE_NAME := BoostiPhone6sPrefs

BoostiPhone6sPrefs_FILES := RootListController.m
BoostiPhone6sPrefs_FRAMEWORKS := UIKit
BoostiPhone6sPrefs_PRIVATE_FRAMEWORKS := Preferences
BoostiPhone6sPrefs_INSTALL_PATH := /Library/PreferenceLoader/Preferences
BoostiPhone6sPrefs_CFLAGS := -fobjc-arc -O3

# Thêm dòng này để cấp đường dẫn PrivateFrameworks cho Theos tìm thấy trên GitHub Actions
BoostiPhone6sPrefs_LDFLAGS += -F$(THEOS)/theos/include -F$(THEOS)/sdk/iPhoneOS.sdk/System/Library/PrivateFrameworks

include $(THEOS_MAKE_PATH)/bundle.mk
