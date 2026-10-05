#ifndef SMART_THERMAL_H
#define SMART_THERMAL_H

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

#ifdef __cplusplus
extern "C" {
#endif

// Truy vấn trạng thái nhiệt độ và sạc nhanh trong 0ns cho %ctor và các hook đồ họa của Tweak.xm
BOOL SmartThermal_IsDeviceChargingFast(void);
BOOL SmartThermal_IsThermalThrottlingActive(void);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SmartThermal : NSObject

@property (nonatomic, assign, readonly) NSProcessInfoThermalState currentThermalState;
@property (nonatomic, assign, readonly) BOOL isDeviceCharging;
@property (nonatomic, assign, readonly) BOOL isHeavyLoadDetected;

+ (instancetype)sharedInstance;

// Bắt đầu theo dõi nhiệt độ phần cứng, trạng thái sạc và tải CPU/GPU thụ động
- (void)startThermalMonitoring;

// Hệ số tốc độ hoạt ảnh giao diện theo nhiệt độ
- (CGFloat)recommendedAnimationMultiplier;

// Đề xuất tần số quét (Hz) & FPS linh hoạt theo trạng thái nhiệt và nguồn điện
- (NSInteger)recommendedTargetHzWithBase:(NSInteger)baseHz allowOverclock:(BOOL)overclock;
- (NSInteger)recommendedTargetFPSWithBase:(NSInteger)baseFPS;

// Kiểm tra xem hệ thống có đang kích hoạt bảo vệ quá nhiệt khi cắm sạc không
- (BOOL)shouldThrottleForChargingProtection;

// Ép hạ nhiệt cưỡng bức khi phát hiện nhiệt độ tới hạn (Thermal Shield)
- (void)mitigateThermalPressureIfNeeded;

@end

NS_ASSUME_NONNULL_END

#endif /* SMART_THERMAL_H */
