#ifndef CACHE_CLEANER_H
#define CACHE_CLEANER_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CacheCleaner : NSObject

+ (instancetype)sharedInstance;

// Dọn dẹp RAM thông thường & áp lực bộ nhớ hệ thống
+ (void)forceMemoryPurge;

// Dọn dẹp chuyên sâu cấp Mach VM & Purgeable Pages
+ (void)forceDeepMemoryPurge;

// Quét dọn cache tệp tạm, WebView & ImageIO (Hỗ trợ phân vùng Rootless & RootHide)
+ (void)cleanAppTemporaryCaches;
+ (void)cleanSystemCachesAndSnapshots;

// Khởi chạy daemon dọn RAM định kỳ theo thiết lập người dùng
+ (void)startPeriodicCleanerWithInterval:(NSTimeInterval)interval;
+ (void)stopPeriodicCleaner;

@end

NS_ASSUME_NONNULL_END

#endif
