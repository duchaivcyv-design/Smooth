#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, ThermalLevel) {
    ThermalCool = 0,     // Mát mẻ (< 35°C) - Chạy full hiệu năng
    ThermalWarm = 1,     // Ấm vừa (35-40°C) - Giảm animation nhẹ
    ThermalHot = 2,      // Nóng (> 40°C) - Hạn chế background, ép xung thấp
    ThermalCritical = 3  // Nguy hiểm - Kích hoạt Safe Mode tạm thời
};

@interface SmartThermal : NSObject

+ (instancetype)sharedInstance;

/**
 * Đọc cảm biến nhiệt độ hiện tại từ IOKit/Sysctl.
 */
- (ThermalLevel)currentThermalState;

/**
 * Trả về hệ số nhân tốc độ Animation tương ứng với mức nhiệt.
 * VD: Cool=1.0 (Full speed), Warm=0.8, Hot=0.5
 */
- (CGFloat)recommendedAnimationMultiplier;

/**
 * Kiểm tra xem có nên chặn tác vụ nền nặng không.
 */
- (BOOL)shouldSuppressBackgroundTasks;

@end
