#import "SmartThermal.h"
#import <sys/sysctl.h>

@implementation SmartThermal {
    float _lastTemp;
    NSTimeInterval _lastReadTime;
}

+ (instancetype)sharedInstance {
    static SmartThermal *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (CGFloat)recommendedAnimationMultiplier {
    NSTimeInterval now = CACurrentMediaTime();
    if (now - _lastReadTime < 2.0) return (_lastTemp > 42.0f ? 0.5f : (_lastTemp > 39.0f ? 0.8f : 1.0f));
    
    float temp = 38.0f;
    size_t size = sizeof(float);
    sysctlbyname("kern.thermal.temperature", &temp, &size, NULL, 0);
    
    _lastTemp = temp;
    _lastReadTime = now;
    
    if (temp >= 42.0f) return 0.5f;
    if (temp >= 39.0f) return 0.8f;
    return 1.0f;
}

@end
