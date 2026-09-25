#import "SmartThermal.h"
#import <sys/sysctl.h>

// Thermal thresholds (°C)
static const float kThermalWarmThreshold = 39.0f;
static const float kThermalHotThreshold = 42.0f;
static const float kDefaultTemperature = 38.0f;

// Animation multipliers
static const CGFloat kMultiplierNormal = 1.0;
static const CGFloat kMultiplierWarm = 0.8;
static const CGFloat kMultiplierHot = 0.5;

@implementation SmartThermal {
    float _lastKnownTemperature;
    NSTimeInterval _lastReadTime;
    dispatch_queue_t _thermalQueue;
}

+ (instancetype)sharedInstance {
    static SmartThermal *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _lastKnownTemperature = kDefaultTemperature;
        _lastReadTime = 0;
        _thermalQueue = dispatch_queue_create("com.boostiphone6s.smartthermal", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (CGFloat)recommendedAnimationMultiplier {
    float temp = [self currentTemperature];
    
    if (temp >= kThermalHotThreshold) {
        NSLog(@"[SmartThermal] 🔥 HOT (%.1f°C) - Animation speed reduced to 50%%", temp);
        return kMultiplierHot;
    } else if (temp >= kThermalWarmThreshold) {
        NSLog(@"[SmartThermal] 🌡️ WARM (%.1f°C) - Animation speed reduced to 80%%", temp);
        return kMultiplierWarm;
    } else {
        return kMultiplierNormal;
    }
}

- (float)currentTemperature {
    // Cache nhiệt độ trong 2 giây để tránh đọc sysctl quá thường xuyên
    NSTimeInterval now = CACurrentMediaTime();
    if (now - _lastReadTime < 2.0) {
        return _lastKnownTemperature;
    }
    
    __block float temp = kDefaultTemperature;
    
    dispatch_sync(_thermalQueue, ^{
        temp = [self readKernelTemperature];
        self->_lastKnownTemperature = temp;
        self->_lastReadTime = CACurrentMediaTime();
    });
    
    return temp;
}

- (NSString *)thermalStateDescription {
    float temp = [self currentTemperature];
    
    if (temp >= kThermalHotThreshold) {
        return @"Hot";
    } else if (temp >= kThermalWarmThreshold) {
        return @"Warm";
    } else {
        return @"Normal";
    }
}

- (BOOL)isOverheating {
    return [self currentTemperature] >= kThermalHotThreshold;
}

#pragma mark - Private Methods

/**
 * Đọc nhiệt độ từ kernel qua sysctlbyname.
 * 
 * kern.thermal.temperature trả về nhiệt độ SoC hiện tại.
 * Trên một số thiết bị/iOS version, key này có thể không tồn tại,
 * khi đó trả về giá trị mặc định 38.0°C.
 * 
 * @return Nhiệt độ tính bằng °C
 */
- (float)readKernelTemperature {
    float temperature = kDefaultTemperature;
    size_t size = sizeof(float);
    
    // Thử đọc kern.thermal.temperature
    int result = sysctlbyname("kern.thermal.temperature", &temperature, &size, NULL, 0);
    
    if (result == 0 && temperature > 0) {
        // Thành công - nhiệt độ hợp lệ
        return temperature;
    }
    
    // Fallback: thử đọc hw.thermal (một số thiết bị dùng key khác)
    size = sizeof(float);
    result = sysctlbyname("hw.thermal", &temperature, &size, NULL, 0);
    
    if (result == 0 && temperature > 0) {
        return temperature;
    }
    
    // Không đọc được - trả về mặc định
    NSLog(@"[SmartThermal] ⚠️ Cannot read kernel temperature, using default %.1f°C", kDefaultTemperature);
    return kDefaultTemperature;
}

@end
