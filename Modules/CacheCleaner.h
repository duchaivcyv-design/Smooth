#ifndef CACHE_CLEANER_H
#define CACHE_CLEANER_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CacheCleaner : NSObject

/**
 * Quét và xóa toàn bộ cache trong thư mục đích một cách an toàn.
 * Tự động bỏ qua các file cấu hình hệ thống (.plist, .mobileprovision).
 * Chỉ cho phép thao tác trên các đường dẫn chứa /Caches/, /tmp/ hoặc /Logs/.
 * 
 * @param path Đường dẫn tuyệt đối đến thư mục cần xóa.
 * @return Tổng số byte đã giải phóng thành công.
 */
+ (unsigned long long)cleanDirectoryAtPath:(NSString *)path;

/**
 * Xóa hàng loạt các thư mục rác hệ thống đã được whitelist.
 * Bao gồm: Safari Cache, WebKit Networking, Spotify Cache, Snapshots, Logs CrashReporter.
 */
+ (void)cleanupTempFiles;

/**
 * Ép giải phóng bộ nhớ đệm cơ bản qua shell command 'sync && purge'.
 * An toàn, tương thích mọi phiên bản iOS 14-26.
 */
+ (void)forceMemoryPurge;

/**
 * ★ TÍNH NĂNG MỚI V7.0: Xả RAM cực sâu thông qua Mach Host API.
 * Giải phóng trực tiếp Page Cache và Inactive Memory ở tầng kernel.
 * Chỉ nên kích hoạt khi chơi game nặng hoặc máy bị treo do thiếu RAM.
 * Lưu ý: Có thể gây giật nhẹ trong 1-2 giây đầu do hệ thống tái phân bổ memory.
 */
+ (void)forceDeepMemoryPurge;

@end

NS_ASSUME_NONNULL_END

#endif /* CACHE_CLEANER_H */
