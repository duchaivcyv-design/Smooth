#ifndef CRASH_GUARD_H
#define CRASH_GUARD_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, GuardStatus) {
    GuardStatusNormal = 0,
    GuardStatusWarning = 1,
    GuardStatusSafeMode = 2
};

@interface CrashGuard : NSObject

+ (instancetype)sharedInstance;

- (void)startMonitoring;

- (void)reportException:(NSString *)reason;

- (BOOL)canExecuteHooks;

- (void)resetSafeModeManually;

- (void)triggerSoftRespring;

@end

NS_ASSUME_NONNULL_END

#endif
