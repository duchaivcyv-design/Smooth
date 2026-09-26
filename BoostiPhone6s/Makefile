# ==============================================================
# V20 ULTIMATE MAKEFILE - OPTIMIZED FOR GITHUB ACTIONS
# ==============================================================

# Target iOS 14.0 -> iOS 18.x
TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = SpringBoard

# Không hiển thị log biên dịch rườm rà (Clean build output)
GO_EASY_ON_ME = 1
DEBUG = 0
FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BoostiPhone6sCore

# Tự động gộp Tweak.xm và TOÀN BỘ các file .m / .c trong thư mục Modules
BoostiPhone6sCore_FILES = Tweak.xm $(wildcard Modules/*.m) $(wildcard Modules/*.c)

# Cờ tối ưu hóa: 
# -fobjc-arc: Bật quản lý bộ nhớ tự động
# -O3: Tối ưu hóa hiệu năng thuật toán ở mức cao nhất
# -Wno-*: Bỏ qua các cảnh báo không cần thiết để tránh Github Actions dừng build
BoostiPhone6sCore_CFLAGS = -fobjc-arc -O3 -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-function

# Liên kết với các Framework hệ thống để không bị thiếu hàm
BoostiPhone6sCore_FRAMEWORKS = UIKit Foundation QuartzCore AVFoundation IOKit

include $(THEOS_MAKE_PATH)/tweak.mk
