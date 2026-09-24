#ifndef CRASH_GUARD_H
#define CRASH_GUARD_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Trạng thái hoạt động của hệ thống bảo vệ CrashGuard.
 */
typedef NS_ENUM(NSInteger, GuardStatus) {
    GuardStatusNormal = 0,       // Hoạt động bình thường, tất cả hook đều active
    GuardStatusWarning = 1,      // Đã xảy ra lỗi nhưng chưa vượt ngưỡng an toàn
    GuardStatusSafeMode = 2      // Chế độ an toàn: Tất cả hook deep đã bị vô hiệu hóa
};

@interface CrashGuard : NSObject

/**
 * Singleton instance truy cập duy nhất.
 */
+ (instancetype)sharedInstance;

/**
 * Bắt đầu giám sát exception. Gọi trong %ctor ngay sau khi khởi tạo singleton.
 */
- (void)startMonitoring;

/**
 * Báo cáo một sự cố đã được catch bởi UncaughtExceptionHandler.
 * Tự động đếm số lần crash trong 60s gần nhất. Nếu >= 3 -> Kích hoạt Safe Mode.
 * 
 * @param reason Mô tả nguyên nhân exception (tên + message).
 */
- (void)reportException:(NSString *)reason;

/**
 * Kiểm tra xem tweak có đang ở trạng thái cho phép chạy Hook hay không.
 * Trả về NO nếu đang ở Safe Mode hoặc UserDefaults lưu trạng thái safe.
 * 
 * @return YES nếu an toàn để execute hooks, NO nếu cần bypass.
 */
- (BOOL)canExecuteHooks;

/**
 * ★ QUAN TRỌNG: Reset thủ công trạng thái Safe Mode.
 * Gọi hàm này từ RootListController khi user bật lại Master Switch
 * hoặc nhấn nút "Exit Safe Mode" trong Settings.
 * Xóa key BoostiPhone6s_SafeModeActive khỏi UserDefaults và reset internal state.
 */
- (void)resetSafeModeManually;

/**
 * Force Respring nhẹ để áp dụng thay đổi (thoát Safe Mode / cập nhật config).
 * Sử dụng fallback chain: sbreload -> killall SpringBoard -> killall backboardd.
 */
- (void)triggerSoftRespring;

@end

NS_ASSUME_NONNULL_END

#endif /* CRASH_GUARD_H */
