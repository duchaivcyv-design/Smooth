include $(THEOS)/makefiles/common.mk

BUNDLE_NAME := BoostiPhone6sPrefs

BoostiPhone6sPrefs_FILES := RootListController.m
BoostiPhone6sPrefs_FRAMEWORKS := UIKit
BoostiPhone6sPrefs_PRIVATE_FRAMEWORKS := Preferences
BoostiPhone6sPrefs_INSTALL_PATH := /Library/PreferenceLoader/Preferences
BoostiPhone6sPrefs_CFLAGS := -fobjc-arc -O3

# Sử dụng biến SDK chính thức của Theos để trỏ động đến thư mục PrivateFrameworks
BoostiPhone6sPrefs_LDFLAGS += -F$(THEOS_TARGET_SDK_DIR)/System/Library/PrivateFrameworks

include $(THEOS_MAKE_PATH)/bundle.mk
