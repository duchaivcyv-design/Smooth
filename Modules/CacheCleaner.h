#ifndef CACHE_CLEANER_H
#define CACHE_CLEANER_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Module dọn dẹp cache hệ thống và RAM.
 * Hỗ trợ cả standard purge và deep Mach-level purge.
 * An toàn tuyệt đối trên iOS 14-26 Rootless.
 */
@interface CacheCleaner : NSObject

+ (unsigned long long)cleanDirectoryAtPath:(NSString *)path;
+ (unsigned long long)getDirectorySize:(NSString *)path;
+ (void)cleanupTempFiles;
+ (void)forceMemoryPurge;
+ (void)forceDeepMemoryPurge;
+ (void)clearURLCache;
+ (void)clearImageCache;
+ (unsigned long long)fullSystemCleanup;

@end

NS_ASSUME_NONNULL_END

#endif /* CACHE_CLEANER_H */
