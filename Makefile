ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard backboardd

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = BoostiPhone6s

BoostiPhone6s_FILES = Tweak.xm

# ===================================================================
# CFLAGS: Chống lỗi compile cũ & IOKit Module
# ===================================================================
BoostiPhone6s_CFLAGS = \
    -fobjc-arc \
    -O3 \
    -Wno-deprecated-declarations \
    -Wno-unused-variable \
    -Wno-module-import-in-extern-c \
    -D__IPHONE_OS_VERSION_MIN_REQUIRED=150000

BoostiPhone6s_LDFLAGS = -Wl,-dead_strip

# ===================================================================
# FRAMEWORKS: Chỉ giữ Public Frameworks để tránh lỗi Linker
# ===================================================================
BoostiPhone6s_FRAMEWORKS = UIKit CoreGraphics QuartzCore AVFoundation IOKit Foundation

# Lưu ý: Rootless tweak thường không cần link substrate nếu dùng ElleKit/Substitute runtime injection.
# Nếu bắt buộc phải link thì uncomment dòng dưới:
# BoostiPhone6s_LIBRARIES = substrate 

include $(THEOS_MAKE_PATH)/library.mk

# ===================================================================
# FIX LỖI DEBIAN STRUCTURE (QUAN TRỌNG NHẤT)
# Sử dụng .theos/_ thay vì $(THEOBJ) để đảm bảo đường dẫn đúng
# ===================================================================
before-package::
	@echo "🛠️ Organizing Debian structure for Rootless..."
	
	# 1. Đảm bảo thư mục đích tồn tại (.theos/_ là nơi Theos stage files trước khi đóng gói)
	mkdir -p .theos/_/DEBIAN
	
	# 2. Copy các file control từ thư mục gốc repo vào DEBIAN folder
	cp control .theos/_/DEBIAN/control
	cp postinst .theos/_/DEBIAN/postinst
	chmod 755 .theos/_/DEBIAN/postinst
	
	# 3. Xử lý prerm nếu có
	if [ -f prerm ]; then 
	    cp prerm .theos/_/DEBIAN/prerm; 
	    chmod 755 .theos/_/DEBIAN/prerm; 
	fi
	
	# 4. Kiểm tra nhanh xem đã copy chưa
	ls -la .theos/_/DEBIAN/

after-install::
	install.exec "killall -9 SpringBoard backboardd"
