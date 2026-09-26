#ifndef KERNEL_BYPASS_H
#define KERNEL_BYPASS_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KernelBypass : NSObject
+ (instancetype)sharedInstance;
- (void)initEnvironment;
- (void)boostCurrentThreadPriority;
- (void)forceMachPurge;
@end

NS_ASSUME_NONNULL_END
#endif
