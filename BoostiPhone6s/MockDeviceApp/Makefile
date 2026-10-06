TARGET := iphone:clang:latest:14.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = MockDeviceApp

MockDeviceApp_FILES = main.m AppDelegate.m MockDeviceViewController.m
MockDeviceApp_FRAMEWORKS = UIKit CoreGraphics QuartzCore
MockDeviceApp_CFLAGS = -fobjc-arc
MockDeviceApp_CODESIGN_FLAGS = -Sentitlements.plist
MockDeviceApp_INSTALL_PATH = /Applications

include $(THEOS_MAKE_PATH)/application.mk
