#ifndef SYSTEM_BLOCKER_H
#define SYSTEM_BLOCKER_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Module chặn các tác vụ hệ thống không cần thiết để tiết kiệm pin/RAM.
 * Hỗ trợ chặn GPS, iCloud Sync, Analytics Telemetry và Rating Prompt.
 * Tích hợp Smart Whitelist cho các app thiết yếu (Maps, Find My, HomeKit...).
 * An toàn tuyệt đối trên iOS 14-26 Rootless, không gây crash hay memory leak.
 */
@interface SystemBlocker : NSObject

/**
 * Singleton instance truy cập duy nhất. Thread-safe qua dispatch_once.
 */
+ (instancetype)sharedInstance;

/**
 * Khởi tạo và kích hoạt tất cả bộ chặn hệ thống.
 * Swizzle runtime methods của CLLocationManager, NSUbiquitousKeyValueStore, 
 * SKStoreReviewController và Analytics Manager.
 * 
 * ★ CHỈ GỌI MỘT LẦN trong %ctor khi Master Switch BẬT VÀ EnableBlocker = YES.
 * Chạy sync trên serial queue để đảm bảo thread-safety khi swizzle.
 */
- (void)initBlockers;

/**
 * Dừng bộ chặn và khôi phục IMP gốc cho CLLocationManager.
 * Gọi khi user tắt EnableBlocker hoặc trước khi dealloc.
 * An toàn: Không restore nếu chưa từng init hoặc đã stop rồi.
 */
- (void)stopBlockers;

/**
 * Kiểm tra trạng thái hoạt động nội bộ của bộ chặn.
 * @return YES nếu các hook đang active, NO nếu chưa init hoặc đã stop.
 * Lưu ý: KHÔNG check CFG.enableBlocker ở đây – caller phải tự check.
 */
- (BOOL)isActive;

/**
 * ★ QUAN TRỌNG: Reset thủ công trạng thái Safe Mode từ Settings.
 * Xóa key BoostiPhone6s_SafeModeActive và LastCrashReason khỏi UserDefaults.
 * Reset internal state về Normal để user có thể bật lại tweak mà không cần respring.
 * 
 * PHẢI gọi từ RootListController khi user nhấn "Exit Safe Mode" hoặc bật Master Switch.
 * Chạy async trên serial queue để tránh block UI thread.
 */
- (void)resetSafeModeManually;

@end

NS_ASSUME_NONNULL_END

#endif /* SYSTEM_BLOCKER_H */
