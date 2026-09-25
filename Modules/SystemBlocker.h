#ifndef SYSTEM_BLOCKER_H
#define SYSTEM_BLOCKER_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * SystemBlocker - Module chặn các tiến trình hệ thống không cần thiết.
 * 
 * Chức năng:
 * - Chặn analytics/telemetry gửi về Apple
 * - Chặn background app refresh không cần thiết
 * - Quản lý danh sách các tiến trình bị chặn
 * - Toggle on/off cho từng loại blocker
 * 
 * Các tiến trình bị chặn:
 * - analyticsd (Apple Analytics)
 * - adid (Advertising Identifier)
 * - rapportd (Continuity telemetry)
 * 
 * An toàn tuyệt đối trên iOS 14-26 Rootless.
 */
@interface SystemBlocker : NSObject

/**
 * Singleton instance duy nhất của SystemBlocker.
 */
+ (instancetype)sharedInstance;

/**
 * Khởi tạo tất cả blockers.
 * Gọi một lần trong %ctor khi enableBlocker = YES.
 */
- (void)initBlockers;

/**
 * Kiểm tra xem blockers có đang hoạt động không.
 * @return YES nếu ít nhất một blocker đang active
 */
- (BOOL)isActive;

/**
 * Lấy danh sách các tiến trình đang bị chặn.
 * @return Array chứa tên các tiến trình bị chặn
 */
- (NSArray<NSString *> *)blockedProcesses;

/**
 * Toggle blocker cho một tiến trình cụ thể.
 * @param processName Tên tiến trình
 * @param block YES để chặn, NO để bỏ chặn
 */
- (void)setBlock:(BOOL)block forProcess:(NSString *)processName;

/**
 * Stop tất cả blockers và khôi phục trạng thái ban đầu.
 */
- (void)stopAllBlockers;

@end

NS_ASSUME_NONNULL_END

#endif /* SYSTEM_BLOCKER_H */
