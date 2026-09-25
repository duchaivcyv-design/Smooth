#ifndef CACHE_CLEANER_H
#define CACHE_CLEANER_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CacheCleaner : NSObject

+ (unsigned long long)cleanDirectoryAtPath:(NSString *)path;
+ (unsigned long long)getDirectorySize:(NSString *)path;
+ (unsigned long long)cleanupTempFiles;
+ (void)forceMemoryPurge;
+ (void)forceDeepMemoryPurge;
+ (void)clearURLCache;
+ (void)clearImageCache;
+ (unsigned long long)fullSystemCleanup;

@end

NS_ASSUME_NONNULL_END

#endif /* CACHE_CLEANER_H */
