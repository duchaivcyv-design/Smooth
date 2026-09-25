#ifndef CACHE_CLEANER_H
#define CACHE_CLEANER_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * CacheCleaner - Module dọn dẹp bộ nhớ cache và RAM.
 * 
 * Chức năng:
 * - Force memory purge thông qua system command
 * - Deep memory purge với sync trước khi purge
 * - Dọn dẹp NSURLCache shared instance
 * - Dọn dẹp các thư mục cache cụ thể
 * 
 * Sử dụng dlsym để gọi hàm system() an toàn, tránh compiler warning.
 * An toàn tuyệt đối trên iOS 14-26 Rootless.
 */
@interface CacheCleaner : NSObject

/**
 * Thực hiện memory purge tiêu chuẩn.
 * Gọi lệnh "purge" để giải phóng inactive memory.
 */
+ (void)forceMemoryPurge;

/**
 * Thực hiện deep memory purge.
 * Gọi "sync && purge" để flush disk cache trước khi purge RAM.
 * Mạnh hơn forceMemoryPurge nhưng chậm hơn một chút.
 */
+ (void)forceDeepMemoryPurge;

/**
 * Dọn dẹp NSURLCache shared instance.
 * Xóa tất cả cached responses (HTML, images, API responses).
 */
+ (void)clearURLCache;

/**
 * Dọn dẹp thư mục cache cụ thể.
 * @param path Đường dẫn đến thư mục cache cần dọn dẹp
 * @return Số bytes đã giải phóng
 */
+ (unsigned long long)cleanDirectoryAtPath:(NSString *)path;

/**
 * Lấy kích thước thư mục cache.
 * @param path Đường dẫn đến thư mục
 * @return Kích thước tính bằng bytes
 */
+ (unsigned long long)getDirectorySize:(NSString *)path;

/**
 * Dọn dẹp tất cả cache hệ thống phổ biến.
 * Bao gồm: Safari cache, WebKit cache, app caches, tmp files.
 * @return Tổng số bytes đã giải phóng
 */
+ (unsigned long long)cleanAllSystemCaches;

@end

NS_ASSUME_NONNULL_END

#endif /* CACHE_CLEANER_H */
