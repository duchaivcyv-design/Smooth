include $(THEOS)/makefiles/common.mk

BUNDLE_NAME := BoostiPhone6sPrefs

BoostiPhone6sPrefs_FILES := RootListController.m
BoostiPhone6sPrefs_FRAMEWORKS := UIKit
BoostiPhone6sPrefs_PRIVATE_FRAMEWORKS := Preferences

# Sửa lại đúng đường dẫn chuẩn rootless cho PreferenceBundles
BoostiPhone6sPrefs_INSTALL_PATH := /Library/PreferenceBundles

BoostiPhone6sPrefs_CFLAGS := -fobjc-arc -O3

# Tự động tìm SDK để tránh lỗi trên GitHub Actions
ifeq ($(THEOS_SDK_DIR),)
    THEOS_SDK_DIR := $(shell ls -d $(THEOS)/sdks/iPhoneOS*.sdk 2>/dev/null | head -n 1)
endif

ifneq ($(THEOS_SDK_DIR),)
    BoostiPhone6sPrefs_LDFLAGS += -F$(THEOS_SDK_DIR)/System/Library/PrivateFrameworks
endif

include $(THEOS_MAKE_PATH)/bundle.mk
