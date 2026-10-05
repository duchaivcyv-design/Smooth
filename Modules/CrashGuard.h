#ifndef CRASH_GUARD_H
#define CRASH_GUARD_H

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

// Kiểm tra nhanh trực tiếp cờ Safe Mode (0ns overhead cho %ctor của Tweak.xm)
BOOL CrashGuard_IsSafeModeActive(void);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, GuardStatus) {
    GuardStatusNormal = 0,      // Hệ thống ổn định, đầy đủ 144Hz & tối ưu hóa
    GuardStatusSafeMode = 1,    // Kích hoạt Safe Mode, ngắt toàn bộ hook nhạy cảm
    GuardStatusCritical = 2     // Phát hiện sập bất thường, chuẩn bị hạ tải bảo vệ máy
};

@interface CrashGuard : NSObject

@property (nonatomic, assign, readonly) GuardStatus currentStatus;
@property (nonatomic, assign, readonly) NSInteger crashCount;

+ (instancetype)sharedInstance;

// Khởi chạy giám sát tiến trình và cài đặt signal/exception traps an toàn
- (void)startMonitoring;

// Kiểm tra xem tweak có được phép nạp các hook nhạy cảm hay không
- (BOOL)canExecuteHooks;

// Đặt lại trạng thái Safe Mode thủ công (Reset counter và xóa cờ /tmp)
- (void)resetSafeModeManually;

// Báo cáo sự cố crash từ các module con để đếm số lần sập
- (void)reportFailureWithReason:(NSString *)reason;

// Đánh dấu ứng dụng/SpringBoard đã chạy ổn định (tự xóa bộ đếm sập sau 3 giây)
- (void)markAppSuccessfullyLaunched;

@end

NS_ASSUME_NONNULL_END

#endif /* CRASH_GUARD_H */
