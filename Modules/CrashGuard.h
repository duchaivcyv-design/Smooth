#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, GuardStatus) {
    GuardStatusNormal = 0,       // Hoạt động bình thường
    GuardStatusWarning = 1,      // Đã xảy ra lỗi nhưng chưa quá nhiều
    GuardStatusSafeMode = 2      // Đang ở chế độ an toàn (Hook bị vô hiệu hóa)
};

@interface CrashGuard : NSObject

+ (instancetype)sharedInstance;

/**
 * Bắt đầu giám sát. Gọi này trong %ctor.
 */
- (void)startMonitoring;

/**
 * Báo cáo một sự cố đã được catch.
 * Nếu số lần vượt ngưỡng -> Kích hoạt Safe Mode.
 */
- (void)reportException:(NSString *)reason;

/**
 * Kiểm tra xem tweak có đang ở trạng thái cho phép chạy Hook hay không.
 * Trả về NO nếu đang ở Safe Mode.
 */
- (BOOL)canExecuteHooks;

/**
 * Force Respring nhẹ để áp dụng thay đổi (ví dụ: thoát Safe Mode).
 */
- (void)triggerSoftRespring;

@end
