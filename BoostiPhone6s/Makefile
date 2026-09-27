ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = BoostiPhone6sPrefs

# File ma nguon
BoostiPhone6sPrefs_FILES = RootListController.m

# Chi su dung cac Public Frameworks co san trong SDK Xcode
BoostiPhone6sPrefs_FRAMEWORKS = UIKit CoreGraphics Foundation

# Thu muc cai dat bundle cho jailbreak Rootless
BoostiPhone6sPrefs_INSTALL_PATH = /Library/PreferenceBundles

# Duong dan tim Header Preferences thu cong
BoostiPhone6sPrefs_CFLAGS = -fobjc-arc \
                            -O3 \
                            -I../Headers \
                            -I../ \
                            -Wno-deprecated-declarations \
                            -Wno-unknown-warning-option

# Bo qua kiem tra ky hieu Preferences luc link, nap dong runtime tren iOS
BoostiPhone6sPrefs_LDFLAGS = -Wl,-dead_strip -Wl,-undefined,dynamic_lookup

include $(THEOS_MAKE_PATH)/bundle.mk
