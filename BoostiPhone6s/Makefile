ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:14.0

DEBUG = 0
FINALPACKAGE = 1
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = BoostiPhone6s

BoostiPhone6s_FILES = RootListController.m
BoostiPhone6s_FRAMEWORKS = UIKit CoreGraphics Foundation
BoostiPhone6s_PRIVATE_FRAMEWORKS = 
BoostiPhone6s_INSTALL_PATH = /Library/PreferenceBundles

BoostiPhone6s_CFLAGS = -fobjc-arc \
                       -O3 \
                       -Wall \
                       -Wno-error \
                       -Wno-deprecated-declarations \
                       -Wno-unused-variable \
                       -Wno-unused-function \
                       -Wno-implicit-function-declaration \
                       -Wno-deprecated-non-prototype \
                       -I$(THEOS)/include \
                       -I$(THEOS)/vendor/include \
                       -I../Headers \
                       -I../Modules \
                       -I../ \
                       -I.

BoostiPhone6s_LDFLAGS = -Wl,-dead_strip \
                       -Wl,-undefined,dynamic_lookup

include $(THEOS_MAKE_PATH)/bundle.mk
