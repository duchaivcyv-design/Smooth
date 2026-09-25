#ifndef SMART_THERMAL_H
#define SMART_THERMAL_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ThermalLevel) {
    ThermalCool = 0,
    ThermalWarm = 1,
    ThermalHot = 2,
    ThermalCritical = 3
};

/**
 * Module quản lý nhiệt thông minh với adaptive filtering.
 * Đọc nhiệt từ sysctl, IOKit battery sensor và CPU core heuristic.
 * Tự động điều tiết animation multiplier theo trạng thái nhiệt.
 */
@interface SmartThermal : NSObject

+ (instancetype)sharedInstance;
- (ThermalLevel)currentThermalState;
- (CGFloat)recommendedAnimationMultiplier;
- (BOOL)shouldSuppressBackgroundTasks;
- (float)getCurrentTemperature;

@end

NS_ASSUME_NONNULL_END

#endif /* SMART_THERMAL_H */
