#ifndef TitaniumKernelOverdrive_h
#define TitaniumKernelOverdrive_h

#import <Foundation/Foundation.h>
#import <mach/mach.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Ghi đè bộ nhớ an toàn (Memory Patching).
 * 
 * Thay đổi quyền trang bộ nhớ sang RW, sao chép dữ liệu, sau đó khôi phục RX.
 *
 * @param targetAddr Địa chỉ bộ nhớ cần ghi đè.
 * @param patchBytes Con trỏ tới mảng byte chứa dữ liệu patch.
 * @param size Kích thước dữ liệu cần ghi (tính bằng bytes).
 * @return true nếu ghi thành công, false nếu thất bại.
 */
bool Titanium_ForceKernelMemoryWrite(void *targetAddr, const void *patchBytes, size_t size);

/**
 * @brief Nâng mức ưu tiên luồng hiện tại lên User Interactive và gỡ bỏ throttle của nhân.
 * 
 * Áp dụng Thread Precedence Policy (mức tối đa) và Thread Throttle Policy (0).
 */
void Titanium_OverclockChipAndUnthrottle(void);

/**
 * @brief Mở rộng giới hạn bộ nhớ ảo (Jetsam) cho tiến trình hiện tại.
 * 
 * Sử dụng private API memorystatus_control để nâng Task Limit và High Water Mark.
 */
void Titanium_BreakJetsamMemoryLimits(void);

#ifdef __cplusplus
}
#endif

#endif /* TitaniumKernelOverdrive_h */
