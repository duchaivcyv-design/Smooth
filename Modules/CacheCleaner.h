#ifndef CACHE_CLEANER_H
#define CACHE_CLEANER_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Module dọn dẹp bộ nhớ đệm và tối ưu hóa RAM cấp thấp.
 * Được thiết kế riêng cho môi trường Rootless Jailbreak (iOS 14-26).
 */
@interface CacheCleaner : NSObject

/**
 * Dọn dẹp thư mục đích một cách an toàn và thông minh.
 * Tự động chuẩn hóa đường dẫn Rootless (/var/jb/var/mobile -> /var/mobile).
 * Sử dụng lstat() để quét nhanh, bỏ qua file hệ thống quan trọng.
 *
 * @param path Đường dẫn tuyệt đối đến thư mục cần xóa cache.
 * @return Tổng số byte đã giải phóng thành công.
 */
+ (unsigned long long)cleanDirectoryAtPath:(NSString *)path;

/**
 * Quét và dọn dẹp hàng loạt các thư mục rác hệ thống đã được whitelist.
 * Bao gồm: Safari, WebKit, Snapshots, CrashReporter, MobileGestalt logs.
 * An toàn tuyệt đối, không ảnh hưởng dữ liệu người dùng.
 */
+ (void)cleanupTempFiles;

/**
 * Ép giải phóng bộ nhớ đệm cơ bản qua shell command 'sync && purge'.
 * Phù hợp cho tác vụ nền hoặc khi nhận memory warning nhẹ.
 */
+ (void)forceMemoryPurge;

/**
 * ★ TÍNH NĂNG V8.0: Xả RAM cực sâu thông qua Mach Host API.
 * Giải phóng trực tiếp Page Cache và Inactive Memory ở tầng kernel.
 * Chỉ nên kích hoạt khi chơi game nặng hoặc máy bị treo do thiếu RAM.
 * Lưu ý: Có thể gây giật nhẹ 1-2 giây đầu do hệ thống tái phân bổ memory.
 */
+ (void)forceDeepMemoryPurge;

@end

NS_ASSUME_NONNULL_END

#endif /* CACHE_CLEANER_H */
