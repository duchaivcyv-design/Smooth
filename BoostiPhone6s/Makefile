# ==============================================================
# V20 PREFERENCE BUNDLE MAKEFILE (BYPASS GITHUB ACTIONS)
# ==============================================================

ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = BoostiPhone6sPrefs

BoostiPhone6sPrefs_FILES = RootListController.m
BoostiPhone6sPrefs_FRAMEWORKS = UIKit
BoostiPhone6sPrefs_INSTALL_PATH = /Library/PreferenceBundles
BoostiPhone6sPrefs_CFLAGS = -fobjc-arc -O3

# Kỷ luật thép: Ép Github Actions bỏ qua lỗi thiếu Framework nội bộ của Apple
# Tweak sẽ tự động lấy Framework Preferences từ iOS khi chạy thực tế trên máy
BoostiPhone6sPrefs_LDFLAGS = -undefined dynamic_lookup

include $(THEOS_MAKE_PATH)/bundle.mk
