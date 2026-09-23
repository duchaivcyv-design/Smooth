#import "SmartThermal.h"
#import <sys/sysctl.h>
#import <mach/mach.h>

@implementation SmartThermal {
    NSTimeInterval _lastCheckTime;
    ThermalLevel _cachedState;
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
        _cachedState = ThermalCool;
        _lastCheckTime = 0;
    }
    return self;
}

// Đọc trạng thái nhiệt chuẩn iOS 15+
- (ThermalLevel)currentThermalState {
    // Cache kết quả trong 2 giây để tránh spam sysctl call tốn CPU
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (now - _lastCheckTime < 2.0) {
        return _cachedState;
    }
    
    _lastCheckTime = now;
    
    @try {
        NSProcessInfo *procInfo = [NSProcessInfo processInfo];
        NSProcessInfoThermalState state = procInfo.thermalState;
        
        switch (state) {
            case NSProcessInfoThermalStateNominal:
                _cachedState = ThermalCool;
                break;
            case NSProcessInfoThermalStateFair:
                _cachedState = ThermalWarm;
                break;
            case NSProcessInfoThermalStateSerious:
                _cachedState = ThermalHot;
                break;
            case NSProcessInfoThermalStateCritical:
                _cachedState = ThermalCritical;
                break;
            default:
                _cachedState = ThermalCool;
                break;
        }
    } @catch (NSException *exception) {
        // Fallback nếu API lỗi (hiếm gặp trên iOS 15+)
        _cachedState = ThermalCool;
    }
    
    return _cachedState;
}

- (CGFloat)recommendedAnimationMultiplier {
    ThermalLevel level = [self currentThermalState];
    
    switch (level) {
        case ThermalCool:
            return 1.0; // Giữ nguyên tốc độ gốc (hoặc multiplier user set)
        case ThermalWarm:
            return 0.85; // Giảm 15% tốc độ để hạ nhiệt nhẹ
        case ThermalHot:
            return 0.6;  // Giảm 40%, ưu tiên ổn định hơn là nhanh
        case ThermalCritical:
            return 0.3;  // Gần như tắt animation để cứu máy
    }
}

- (BOOL)shouldSuppressBackgroundTasks {
    ThermalLevel level = [self currentThermalState];
    // Nếu máy đang Nóng hoặc Nghiêm trọng, chặn mọi task nền không khẩn cấp
    return (level >= ThermalHot);
}

@end
