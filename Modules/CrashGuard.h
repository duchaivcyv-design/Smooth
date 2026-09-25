#ifndef CRASH_GUARD_H
#define CRASH_GUARD_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, GuardStatus) {
    GuardStatusNormal = 0,
    GuardStatusSafeMode = 1,
    GuardStatusCritical = 2
};

/**
 * Module bảo vệ chống crash loop.
 * Theo dõi exception liên tiếp và tự động kích hoạt Safe Mode.
 * Hỗ trợ reset thủ công từ Settings.
 */
@interface CrashGuard : NSObject

+ (instancetype)sharedInstance;
- (void)startMonitoring;
- (BOOL)canExecuteHooks;
- (void)resetSafeModeManually;
- (GuardStatus)currentStatus;
- (void)reportException:(NSString *)reason;

@end

NS_ASSUME_NONNULL_END

#endif /* CRASH_GUARD_H */
