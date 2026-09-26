#ifndef SMART_THERMAL_H
#define SMART_THERMAL_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SmartThermal : NSObject
+ (instancetype)sharedInstance;
- (CGFloat)recommendedAnimationMultiplier;
@end

NS_ASSUME_NONNULL_END
#endif
