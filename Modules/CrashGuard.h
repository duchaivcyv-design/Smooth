#ifndef CRASH_GUARD_H
#define CRASH_GUARD_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, GuardStatus) {
    GuardStatusNormal = 0,
    GuardStatusSafeMode = 1,
    GuardStatusCritical = 2
};

@interface CrashGuard : NSObject

@property (nonatomic, assign, readonly) GuardStatus currentStatus;
@property (nonatomic, assign, readonly) NSInteger crashCount;

+ (instancetype)sharedInstance;

// Khởi chạy giám sát tiến trình và cài đặt signal/exception traps
- (void)startMonitoring;

// Kiểm tra xem tweak có được phép nạp các hook nhạy cảm hay không
- (BOOL)canExecuteHooks;

// Đặt lại trạng thái Safe Mode thủ công
- (void)resetSafeModeManually;

// Báo cáo sự cố crash từ các module con
- (void)reportFailureWithReason:(NSString *)reason;

// Xóa bộ đếm bootloop sau khi tiến trình đã chạy ổn định
- (void)markAppSuccessfullyLaunched;

@end

NS_ASSUME_NONNULL_END

#endif
