#ifndef TitaniumKernelOverdrive_h
#define TitaniumKernelOverdrive_h

#import <Foundation/Foundation.h>
#import <mach/mach.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Ghi đè bộ nhớ an toàn (thay đổi quyền trang bộ nhớ sang RW, sao chép dữ liệu, sau đó khôi phục RX)
bool Titanium_ForceKernelMemoryWrite(void *targetAddr, const void *patchBytes, size_t size);

/// Nâng mức ưu tiên luồng hiện tại lên User Interactive và gỡ bỏ throttle của nhân
void Titanium_OverclockChipAndUnthrottle(void);

/// Mở rộng giới hạn bộ nhớ ảo (Jetsam) cho tiến trình hiện tại để chống bị hệ thống ngắt ngầm
void Titanium_BreakJetsamMemoryLimits(void);

#ifdef __cplusplus
}
#endif

#endif /* TitaniumKernelOverdrive_h */
