#ifndef CRASH_GUARD_H
#define CRASH_GUARD_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, GuardStatus) {
    GuardStatusNormal = 0,
    GuardStatusSafeMode = 1,
    GuardStatusCritical = 2
};

@interface CrashGuard : NSObject
+ (instancetype)sharedInstance;
- (void)startMonitoring;
- (BOOL)canExecuteHooks;
- (void)resetSafeModeManually;
- (GuardStatus)currentStatus;
@end

NS_ASSUME_NONNULL_END
#endif
