ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = BoostiPhone6sPrefs

# File ma nguon giao dien
BoostiPhone6sPrefs_FILES = RootListController.m

# Frameworks cong khai
BoostiPhone6sPrefs_FRAMEWORKS = UIKit CoreGraphics Foundation

# Thu muc cai dat bundle Rootless
BoostiPhone6sPrefs_INSTALL_PATH = /Library/PreferenceBundles

# Chi dinh duong dan Header thu cong va tat auto-link Preferences gay loi
BoostiPhone6sPrefs_CFLAGS = -fobjc-arc \
                            -O3 \
                            -I../Headers \
                            -I../ \
                            -fno-autolink \
                            -Wno-deprecated-declarations \
                            -Wno-unknown-warning-option

# Bat buoc dung dynamic_lookup de bo qua kiem tra ky hieu PSListController luc link
BoostiPhone6sPrefs_LDFLAGS = -Wl,-dead_strip -Wl,-undefined,dynamic_lookup

include $(THEOS_MAKE_PATH)/bundle.mk
