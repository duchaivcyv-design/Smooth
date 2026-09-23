TARGET := iphone:clang:latest:15.0
ARCHS := arm64 arm64e
INSTALL_TARGET_PROCESSES := SpringBoard backboardd

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = BoostiPhone6s

BoostiPhone6s_FILES = Tweak.xm
BoostiPhone6s_CFLAGS = -fobjc-arc -O3 -flto
BoostiPhone6s_LDFLAGS = -Wl,-dead_strip
BoostiPhone6s_INSTALL_PATH = /usr/lib
BoostiPhone6s_FRAMEWORKS = UIKit CoreGraphics QuartzCore IOKit

include $(THEOS_MAKE_PATH)/library.mk

after-install::
	install.exec "killall -9 SpringBoard backboardd"
