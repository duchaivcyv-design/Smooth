#ifndef SYSTEM_BLOCKER_H
#define SYSTEM_BLOCKER_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Module chặn GPS, iCloud Sync, Analytics Telemetry và Rating Prompt.
 * Tích hợp Smart Whitelist cho app thiết yếu.
 * An toàn tuyệt đối trên iOS 14-26 Rootless.
 */
@interface SystemBlocker : NSObject

+ (instancetype)sharedInstance;
- (void)initBlockers;
- (void)stopBlockers;
- (BOOL)isActive;
- (void)resetSafeModeManually;

@end

NS_ASSUME_NONNULL_END

#endif /* SYSTEM_BLOCKER_H */
