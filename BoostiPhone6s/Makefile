ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = BoostiPhone6sPrefs

# File ma nguon
BoostiPhone6sPrefs_FILES = RootListController.m

# Frameworks can thiet
BoostiPhone6sPrefs_FRAMEWORKS = UIKit CoreGraphics Foundation

# Thu muc cai dat bundle Rootless
BoostiPhone6sPrefs_INSTALL_PATH = /Library/PreferenceBundles

# Duong dan Header thu cong va tat canh bao cu
BoostiPhone6sPrefs_CFLAGS = -fobjc-arc \
                            -O3 \
                            -I../Headers \
                            -I../ \
                            -Wno-deprecated-declarations \
                            -Wno-unknown-warning-option

# Xoa cac co bi deprecated/obsolete tren iOS linker
BoostiPhone6sPrefs_LDFLAGS = -Wl,-dead_strip

include $(THEOS_MAKE_PATH)/bundle.mk
