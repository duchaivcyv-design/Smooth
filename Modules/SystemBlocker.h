#ifndef SYSTEM_BLOCKER_H
#define SYSTEM_BLOCKER_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SystemBlocker : NSObject

/**
 * Singleton instance truy cập duy nhất.
 */
+ (instancetype)sharedInstance;

/**
 * Khởi tạo bộ chặn hệ thống (GPS, iCloud, Analytics, Rating).
 * Chỉ nên gọi từ %ctor khi Master Switch bật VÀ EnableBlocker = YES.
 */
- (void)initBlockers;

/**
 * Dừng bộ chặn và khôi phục IMP gốc (nếu cần).
 */
- (void)stopBlockers;

/**
 * Kiểm tra trạng thái hoạt động của bộ chặn.
 * @return YES nếu các hook đang active, NO nếu chưa khởi tạo hoặc đã dừng.
 */
- (BOOL)isActive;

/**
 * ★ QUAN TRỌNG: Reset thủ công trạng thái Safe Mode.
 * Gọi hàm này từ RootListController khi user bật lại Master Switch
 * hoặc nhấn nút "Exit Safe Mode" trong Settings.
 */
- (void)resetSafeModeManually;

@end

NS_ASSUME_NONNULL_END

#endif /* SYSTEM_BLOCKER_H */
