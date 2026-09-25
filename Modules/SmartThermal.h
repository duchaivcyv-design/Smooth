#ifndef SMART_THERMAL_H
#define SMART_THERMAL_H

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * SmartThermal - Module quản lý nhiệt độ thông minh.
 * 
 * Chức năng:
 * - Đọc nhiệt độ thực tế từ kernel qua sysctl
 * - Tính toán animation multiplier dựa trên nhiệt độ
 * - Cung cấp thermal state hiện tại
 * - Adaptive performance: giảm tốc animation khi nóng
 * 
 * Nhiệt độ thresholds:
 * - < 39°C: Normal (multiplier = 1.0)
 * - 39-42°C: Warm (multiplier = 0.8)
 * - > 42°C: Hot (multiplier = 0.5)
 * 
 * An toàn tuyệt đối trên iOS 14-26 Rootless.
 */
@interface SmartThermal : NSObject

/**
 * Singleton instance duy nhất của SmartThermal.
 */
+ (instancetype)sharedInstance;

/**
 * Lấy animation multiplier khuyến nghị dựa trên nhiệt độ hiện tại.
 * @return CGFloat từ 0.5 đến 1.0
 *         1.0 = mát mẻ, giữ nguyên tốc độ
 *         0.8 = hơi nóng, giảm 20%
 *         0.5 = rất nóng, giảm 50%
 */
- (CGFloat)recommendedAnimationMultiplier;

/**
 * Lấy nhiệt độ hiện tại từ kernel.
 * @return Nhiệt độ tính bằng °C, hoặc 38.0 nếu không đọc được
 */
- (float)currentTemperature;

/**
 * Lấy thermal state mô tả bằng text.
 * @return @"Normal", @"Warm", hoặc @"Hot"
 */
- (NSString *)thermalStateDescription;

/**
 * Kiểm tra xem máy có đang quá nóng không.
 * @return YES nếu nhiệt độ > 42°C
 */
- (BOOL)isOverheating;

@end

NS_ASSUME_NONNULL_END

#endif /* SMART_THERMAL_H */
