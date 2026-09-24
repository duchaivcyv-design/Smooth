include $(THEOS)/makefiles/common.mk

BUNDLE_NAME := BoostiPhone6sPrefs

BoostiPhone6sPrefs_FILES := RootListController.m
BoostiPhone6sPrefs_FRAMEWORKS := UIKit
BoostiPhone6sPrefs_PRIVATE_FRAMEWORKS := Preferences
BoostiPhone6sPrefs_INSTALL_PATH := /Library/PreferenceLoader/Preferences
BoostiPhone6sPrefs_CFLAGS := -fobjc-arc -O3

# Trỏ trực tiếp vào SDK đang được Theos sử dụng trên GitHub Actions
ifeq ($(wildcard $(THEOS_SDK_DIR)),)
    THEOS_SDK_DIR := $(shell $(THEOS)/bin/theos-sdk-path iphoneos)
endif

BoostiPhone6sPrefs_LDFLAGS += -F$(THEOS_SDK_DIR)/System/Library/PrivateFrameworks

include $(THEOS_MAKE_PATH)/bundle.mk
