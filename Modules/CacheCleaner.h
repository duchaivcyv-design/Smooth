#import <Foundation/Foundation.h>

@interface CacheCleaner : NSObject

/**
 * Quét và xóa toàn bộ cache của ứng dụng cụ thể hoặc hệ thống.
 * @param path Đường dẫn tuyệt đối đến thư mục cần xóa (vd: /var/mobile/Library/Caches/Safari)
 * @return Số byte đã giải phóng được.
 */
+ (unsigned long long)cleanDirectoryAtPath:(NSString *)path;

/**
 * Xóa tất cả các file tạm (.tmp, .log) trong thư mục gốc của người dùng.
 */
+ (void)cleanupTempFiles;

/**
 * Ép SpringBoard giải phóng memory warning ngay lập tức.
 */
+ (void)forceMemoryPurge;

@end
