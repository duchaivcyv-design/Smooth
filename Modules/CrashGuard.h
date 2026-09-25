#ifndef CRASH_GUARD_H
#define CRASH_GUARD_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Trạng thái hoạt động của hệ thống bảo vệ CrashGuard.
 */
typedef NS_ENUM(NSInteger, GuardStatus) {
    /** Hoạt động bình thường, tất cả hook đều active */
    GuardStatusNormal = 0,
    
    /** Đã xảy ra lỗi nhưng chưa vượt ngưỡng an toàn (chưa dùng trong v8.0, dành cho mở rộng) */
    GuardStatusWarning = 1,
    
    /** Chế độ an toàn: Tất cả hook deep đã bị vô hiệu hóa do phát hiện crash lặp lại */
    GuardStatusSafeMode = 2
};

/**
 * Module giám sát exception và bảo vệ hệ thống khỏi bootloop/crash loop.
 * Tự động kích hoạt Safe Mode khi phát hiện ≥3 crash trong 60 giây.
 * Hỗ trợ reset thủ công từ Settings mà không cần respring.
 */
@interface CrashGuard : NSObject

/**
 * Singleton instance truy cập duy nhất.
 */
+ (instancetype)sharedInstance;

/**
 * Bắt đầu giám sát uncaught exception.
 * PHẢI gọi trong %ctor trước khi init bất kỳ module nào khác.
 */
- (void)startMonitoring;

/**
 * Báo cáo một sự cố đã được catch bởi UncaughtExceptionHandler.
 * Tự động đếm số lần crash trong 60s gần nhất. Nếu >= 3 → Kích hoạt Safe Mode.
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
 * Sử dụng fallback chain: sbreload → killall SpringBoard → killall backboardd.
 * Tương thích mọi bản Rootless Jailbreak (Dopamine/Palera1n/TrollStore).
 */
- (void)triggerSoftRespring;

@end

NS_ASSUME_NONNULL_END

#endif /* CRASH_GUARD_H */
