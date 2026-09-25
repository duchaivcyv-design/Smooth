#ifndef SMART_THERMAL_H
#define SMART_THERMAL_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Trạng thái nhiệt độ thiết bị, dùng để điều tiết hiệu năng động.
 */
typedef NS_ENUM(NSInteger, ThermalLevel) {
    /** Mát mẻ (< 35°C): Chạy full hiệu năng, không giới hạn */
    ThermalCool = 0,
    
    /** Ấm vừa (35-40°C): Giảm animation nhẹ, giữ ổn định */
    ThermalWarm = 1,
    
    /** Nóng (> 40°C): Hạn chế background tasks, giảm clock speed */
    ThermalHot = 2,
    
    /** Nguy hiểm (> 43.5°C): Kích hoạt Safe Mode tạm thời, giảm mạnh hiệu năng */
    ThermalCritical = 3
};

/**
 * Module quản lý nhiệt thông minh với adaptive filtering và multi-source sensing.
 * Đọc nhiệt từ sysctl, IOKit battery sensor và CPU core heuristic.
 * Tự động điều tiết animation multiplier và background suppression theo trạng thái nhiệt.
 * An toàn tuyệt đối trên iOS 14-26 Rootless, không gây leak mach port.
 */
@interface SmartThermal : NSObject

/**
 * Singleton instance truy cập duy nhất. Thread-safe qua dispatch_once.
 */
+ (instancetype)sharedInstance;

/**
 * Trả về trạng thái nhiệt hiện tại dựa trên filtered temperature.
 * Ngưỡng: Cool ≤35°C, Warm 35-40°C, Hot 40-43.5°C, Critical >43.5°C.
 * 
 * @return ThermalLevel tương ứng với nhiệt độ đã lọc nhiễu.
 */
- (ThermalLevel)currentThermalState;

/**
 * Trả về hệ số nhân tốc độ Animation tương ứng với mức nhiệt.
 * Được gọi trong hooked_calayer_duration để điều tiết UI mượt mà.
 * 
 * Cool=1.0 | Warm=0.9 | Hot=0.7 | Critical=0.5
 * @return Multiplier từ 0.5 đến 1.0.
 */
- (CGFloat)recommendedAnimationMultiplier;

/**
 * Kiểm tra xem có nên chặn tác vụ nền nặng không.
 * Trả về YES khi: (ThermalHot || ThermalCritical) || DeepSleepOpt enabled.
 * Dùng trong SystemBlocker để quyết định kill/suspend background processes.
 * 
 * @return YES nếu cần suppress background, NO nếu bình thường.
 */
- (BOOL)shouldSuppressBackgroundTasks;

@end

NS_ASSUME_NONNULL_END

#endif /* SMART_THERMAL_H */
