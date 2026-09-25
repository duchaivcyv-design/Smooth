#ifndef KERNEL_BYPASS_H
#define KERNEL_BYPASS_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * KernelBypass - Module tối ưu kernel-level và thread priority.
 * 
 * Chức năng:
 * - Khởi tạo môi trường kernel bypass
 * - Boost thread priority lên Realtime (SCHED_RR)
 * - Force Mach VM purge qua host_statistics
 * - Theo dõi VM statistics (free/active/inactive pages)
 * 
 * Lưu ý: Một số thao tác yêu cầu entitlement đặc biệt.
 * Trên Rootless jailbreak, hầu hết các thao tác đều hoạt động.
 * An toàn tuyệt đối trên iOS 14-26 Rootless.
 */
@interface KernelBypass : NSObject

/**
 * Singleton instance duy nhất của KernelBypass.
 */
+ (instancetype)sharedInstance;

/**
 * Khởi tạo môi trường kernel bypass.
 * Gọi một lần trong %ctor để setup các kết nối Mach port.
 */
- (void)initEnvironment;

/**
 * Boost thread hiện tại lên priority cao nhất (Realtime).
 * Sử dụng SCHED_RR với priority max.
 * Chỉ áp dụng cho thread gọi hàm này.
 */
- (void)boostCurrentThreadPriority;

/**
 * Force Mach VM purge - giải phóng inactive memory pages.
 * Đọc VM statistics trước và sau khi purge để log kết quả.
 */
- (void)forceMachPurge;

/**
 * Lấy VM statistics hiện tại.
 * @return Dictionary chứa free_count, active_count, inactive_count, wire_count
 */
- (NSDictionary *)getVMStatistics;

/**
 * Boost GPU thread priority (nếu có thể).
 * Tương tự boostCurrentThreadPriority nhưng tối ưu cho GPU workloads.
 */
- (void)boostGPUThreadPriority;

@end

NS_ASSUME_NONNULL_END

#endif /* KERNEL_BYPASS_H */
