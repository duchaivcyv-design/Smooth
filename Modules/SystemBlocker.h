#ifndef SYSTEM_BLOCKER_H
#define SYSTEM_BLOCKER_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SystemBlocker : NSObject
+ (instancetype)sharedInstance;
- (void)initBlockers;
@end

NS_ASSUME_NONNULL_END
#endif
