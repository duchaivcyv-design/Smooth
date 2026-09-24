#import "SmartThermal.h"
#import <sys/sysctl.h>

@implementation SmartThermal

+ (instancetype)sharedInstance {
    static SmartThermal *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (CGFloat)recommendedAnimationMultiplier {
    float currentTemp = [self getCurrentTemperature];
    
    // Ngưỡng nhiệt an toàn cho iPhone 6s-X
    if (currentTemp > 43.0f) return 0.8f; // Nóng: Giảm nhẹ animation để hạ nhiệt
    if (currentTemp > 40.0f) return 0.9f; // Ấm: Giữ gần như nguyên bản
    return 1.0f;                          // Mát: Full tốc độ
}

- (float)getCurrentTemperature {
    // Đọc nhiệt độ từ sysctl an toàn, fallback về 38 nếu không đọc được
    size_t size = sizeof(float);
    float temp = 38.0f;
    
    if (sysctlbyname("kern.thermal.temperature", &temp, &size, NULL, 0) != 0) {
        // Fallback cho các thiết bị/iOS cũ không có key này
        temp = 38.0f; 
    }
    return temp;
}

@end
