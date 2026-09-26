# ==============================================================================
# V20 ULTIMATE ROOT MAKEFILE - SIÊU SẠCH (THEOS NATIVE)
# ==============================================================================
ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0

# Bật dòng dưới nếu muốn Build cho Rootless, tắt nếu Build Rootful
# THEOS_PACKAGE_SCHEME=rootless

GO_EASY_ON_ME = 1
DEBUG = 0
FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

# --------------------------------------------------------------
# 1. BIÊN DỊCH LÕI TWEAK
# --------------------------------------------------------------
TWEAK_NAME = BoostiPhone6sCore
BoostiPhone6sCore_FILES = Tweak.xm $(wildcard Modules/*.m) $(wildcard Modules/*.c)

# Tối ưu hóa -O3 cực độ và ẩn toàn bộ cảnh báo rác
BoostiPhone6sCore_CFLAGS = -fobjc-arc -O3 -Wno-everything
BoostiPhone6sCore_FRAMEWORKS = UIKit CoreGraphics QuartzCore AVFoundation IOKit Foundation Metal CoreVideo Accelerate CoreServices
BoostiPhone6sCore_LDFLAGS = -Wl,-dead_strip

include $(THEOS_MAKE_PATH)/tweak.mk

# --------------------------------------------------------------
# 2. BIÊN DỊCH MENU CÀI ĐẶT
# --------------------------------------------------------------
SUBPROJECTS += BoostiPhone6s
include $(THEOS_MAKE_PATH)/aggregate.mk
