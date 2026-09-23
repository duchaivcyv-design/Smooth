ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0
# Tắt auto respring để tránh lỗi dpkg
# INSTALL_TARGET_PROCESSES = SpringBoard backboardd 

include $(THEOS)/makefiles/common.mk

# ===================================================================
# PART 1: BUILD MAIN LIBRARY (TWEEK CORE LOGIC)
# ===================================================================
LIBRARY_NAME = BoostiPhone6s

BoostiPhone6s_FILES = Tweak.xm \
                      Modules/CacheCleaner.m \
                      Modules/CrashGuard.m \
                      Modules/SmartThermal.m \
                      Modules/DeepExploit.c \
                      Modules/KernelBypass.m \
                      Modules/SystemBlocker.m

BoostiPhone6s_CFLAGS = \
    -fobjc-arc \
    -O3 \
    -Wall \
    -Wno-unused-variable \
    -Wno-deprecated-declarations \
    -Wno-module-import-in-extern-c \
    -D__IPHONE_OS_VERSION_MIN_REQUIRED=150000

BoostiPhone6s_LDFLAGS = -Wl,-dead_strip
BoostiPhone6s_FRAMEWORKS = UIKit CoreGraphics QuartzCore AVFoundation IOKit Foundation Metal

include $(THEOS_MAKE_PATH)/library.mk


# ===================================================================
# PART 2: BUILD PREFERENCE BUNDLE (SETTINGS UI)
# ★ CẤU HÌNH CHUẨN CHO FOLDER RESOURCES CỦA BẠN ★
# ===================================================================
INTERNAL_INSTALL_PREFIX = Library/PreferenceBundles
BUNDLE_NAME = BoostiPhone6sPrefs

# Code logic cho Bundle
BoostiPhone6sPrefs_FILES = RootListController.m

# ★ QUAN TRỌNG NHẤT: Chỉ định folder Resources chứa cả Info.plist, root.plist VÀ entry.plist ★
# Theos sẽ tự động copy MỌI THỨ trong folder này vào bên trong .bundle khi đóng gói.
# Nhờ vậy, file 'entry.plist' sẽ nằm sẵn trong bundle, và hệ thống PreferenceLoader 
# có thể đọc trực tiếp từ đó nếu được khai báo đúng cách trong control hoặc postinst.
# Tuy nhiên, cách an toàn nhất vẫn là copy riêng lẻ ra thư mục Entries qua script dưới.
BoostiPhone6sPrefs_RESOURCES_DIR = Resources 

# Include headers giả lập
BoostiPhone6sPrefs_INCLUDE_DIRS = Headers

Frameworks & Flags
BoostiPhone6sPrefs_FRAMEWORKS = UIKit Foundation CoreGraphics
BoostiPhone6sPrefs_LDFLAGS = -Wl,-undefined,dynamic_lookup
BoostiPhone6sPrefs_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable

include $(THEOS_MAKE_PATH)/bundle.mk


# ===================================================================
# PACKAGING SCRIPT (SIÊU NGẮN GỌN - LẤY FILE TỪ RESOURCES)
# ★ SỬA Ở ĐÂY: Copy file entry.plist từ folder Resources vào PreferenceLoader ★
# ===================================================================
before-package::
	@echo "🛠️ Preparing Debian Control Files..."
	@mkdir -p .theos/_/DEBIAN
	@cp control .theos/_/DEBIAN/control
	
	# Copy Scripts cài đặt/gỡ bỏ nếu có
	@if [ -f postinst ]; then cp postinst .theos/_/DEBIAN/postinst; chmod 755 .theos/_/DEBIAN/postinst; fi
	@if [ -f prerm ]; then cp prerm .theos/_/DEBIAN/prerm; chmod 755 .theos/_/DEBIAN/prerm; fi
	
	# ★ KHAI BÁO MENU SETTINGS: Lấy file entry.plist từ folder Resources ★
	# Đường dẫn nguồn: Resources/entry.plist (nằm cạnh root.plist, Info.plist...)
	@mkdir -p .theos/_/Library/PreferenceLoader/Entries
	@cp Resources/entry.plist .theos/_/Library/PreferenceLoader/Entries/BoostiPhone6sPrefs.plist
	
	@echo "✅ Done. All assets handled automatically by Theos."

# after-install:: (Tắt thủ công như yêu cầu)
