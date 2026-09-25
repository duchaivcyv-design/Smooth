#ifndef KERNEL_BYPASS_H
#define KERNEL_BYPASS_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Module điều khiển kernel-level và IOKit power management.
 * Boost priority thread, purge RAM qua Mach API.
 * An toàn tuyệt đối trên iOS 14-26 Rootless.
 */
@interface KernelBypass : NSObject

+ (instancetype)sharedInstance;
- (void)initEnvironment;
- (void)forceMachPurge;
- (void)boostCurrentThreadPriority;
- (void)boostGPUThreadPriority;

@end

NS_ASSUME_NONNULL_END

#endif /* KERNEL_BYPASS_H */
