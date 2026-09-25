#ifndef KERNEL_BYPASS_H
#define KERNEL_BYPASS_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Module điều khiển kernel-level và IOKit power management.
 * Cung cấp các hàm boost priority thread, purge RAM qua Mach API 
 * và quản lý safe connection đến hardware services trên iOS 14-26.
 */
@interface KernelBypass : NSObject

/**
 * Singleton instance truy cập duy nhất.
 */
+ (instancetype)sharedInstance;

/**
 * Khởi tạo môi trường IOKit an toàn.
 * Tự động detect master port hợp lệ và kết nối đến AppleARMIODevice hoặc AppleARMPMU.
 * CHỈ gọi MỘT LẦN trong %ctor trước khi sử dụng bất kỳ hàm nào khác.
 * Chạy async trên serial queue để tránh block main thread lúc init.
 */
- (void)initEnvironment;

/**
 * Ép Kernel giải phóng bộ nhớ đệm (Page Cache) qua HOST_VM_INFO.
 * Nhanh hơn shell command 'purge' vì bypass qua syscall trực tiếp.
 * An toàn tuyệt đối, không gây crash hay watchdog kill.
 */
- (void)forceMachPurge;

/**
 * Boost priority của CURRENT THREAD lên SCHED_RR max-safe (≤47).
 * Dùng cho main thread hoặc worker thread cần xử lý tức thì.
 * Giới hạn 47 để tránh bị watchdog kill trên iOS 24+.
 */
- (void)boostCurrentThreadPriority;

/**
 * ★ QUAN TRỌNG: Boost priority GPU/render thread lên SCHED_RR (≤48).
 * Dùng SCHED_RR thay vì SCHED_FIFO để tránh starvation/deadlock.
 * Chỉ log lỗi ở DEBUG build, KHÔNG spam console lúc render frame.
 * PHẢI gọi từ GPU thread (CAMetalLayer present), không gọi từ main thread.
 */
- (void)boostGPUThreadPriority;

@end

NS_ASSUME_NONNULL_END

#endif /* KERNEL_BYPASS_H */
