#ifndef CACHE_CLEANER_H
#define CACHE_CLEANER_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CacheCleaner : NSObject

+ (unsigned long long)cleanDirectoryAtPath:(NSString *)path;

+ (void)cleanupTempFiles;

+ (void)forceMemoryPurge;

+ (void)forceDeepMemoryPurge;

@end

NS_ASSUME_NONNULL_END

#endif
