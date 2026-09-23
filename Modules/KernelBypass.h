#ifndef KERNEL_BYPASS_H
#define KERNEL_BYPASS_H

#include <stdbool.h>
#include <stdint.h>

/**
 * Khởi tạo môi trường bypass an toàn.
 * Gọi này trong %ctor.
 */
bool init_kernel_bypass_env(void);

/**
 * Ép giải phóng bộ nhớ đệm Kernel thông qua Mach Port.
 * An toàn hơn lệnh 'purge' shell.
 */
void force_mach_purge_memory(void);

/**
 * Vô hiệu hóa kiểm tra Code Signing cục bộ cho process hiện tại.
 * Giúp load dylib unsigned mượt hơn.
 */
void disable_local_code_signing(void);

/**
 * Tăng mức ưu tiên Scheduler cho Thread hiện tại lên mức Realtime Low.
 * Lưu ý: Chỉ áp dụng cho thread UI chính.
 */
void boost_current_thread_priority(void);

#endif /* KERNEL_BYPASS_H */
