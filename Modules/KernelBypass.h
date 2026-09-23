#ifndef KERNEL_BYPASS_H
#define KERNEL_BYPASS_H

#import <Foundation/Foundation.h>

@interface KernelBypass : NSObject // ★ Phải kế thừa NSObject ★

+ (instancetype)sharedInstance;
- (void)initEnvironment;
- (void)forceMachPurge;
- (void)boostCurrentThreadPriority;

@end

#endif /* KERNEL_BYPASS_H */
