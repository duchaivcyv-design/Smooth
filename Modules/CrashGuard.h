#ifndef CRASH_GUARD_H
#define CRASH_GUARD_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * CrashGuard - Module giám sát crash loop và Safe Mode.
 * 
 * Chức năng:
 * - Theo dõi số lần crash liên tiếp trong khoảng thời gian ngắn
 * - Tự động kích hoạt Safe Mode khi phát hiện crash loop
 * - Cung cấp API để Tweak.xm kiểm tra xem có được phép hook hay không
 * - Reset Safe Mode thủ công từ Settings
 * 
 * An toàn tuyệt đối trên iOS 14-26 Rootless.
 */
@interface CrashGuard : NSObject

/**
 * Singleton instance duy nhất của CrashGuard.
 */
+ (instancetype)sharedInstance;

/**
 * Bắt đầu giám sát crash.
 * Gọi một lần duy nhất trong %ctor của Tweak.xm.
 * Thiết lập NSUncaughtExceptionHandler và kiểm tra trạng thái Safe Mode.
 */
- (void)startMonitoring;

/**
 * Kiểm tra xem tweak có được phép thực thi hooks hay không.
 * Trả về NO nếu đang ở Safe Mode (crash loop detected).
 * Trả về YES nếu hệ thống ổn định.
 */
- (BOOL)canExecuteHooks;

/**
 * Reset Safe Mode thủ công (gọi từ Settings bundle).
 * Xóa cờ Safe Mode khỏi UserDefaults và cho phép hook trở lại.
 */
- (void)resetSafeModeManually;

/**
 * Lấy trạng thái hiện tại của CrashGuard.
 * @return NSString mô tả trạng thái ("Normal", "SafeMode", "Monitoring")
 */
- (NSString *)currentStatusDescription;

@end

NS_ASSUME_NONNULL_END

#endif /* CRASH_GUARD_H */
