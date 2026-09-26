#import "SmartThermal.h"
#import <sys/sysctl.h>
#import <QuartzCore/QuartzCore.h>

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
    
    // Cache kết quả 3 giây để tránh Syscall liên tục làm nóng CPU thêm
    if (now - _lastReadTime < 3.0) {
        return (_lastTemp >= 42.0f ? 0.65f : (_lastTemp >= 39.0f ? 0.85f : 1.0f));
    }
    
    float temp = 35.0f; // Nhiệt độ ảo mặc định
    size_t size = sizeof(float);
    
    // Bọc an toàn, nếu đọc nhiệt độ thất bại, tự động cho máy chạy Max Tốc
    if (sysctlbyname("kern.thermal.temperature", &temp, &size, NULL, 0) != 0) {
        temp = 35.0f; 
    }
    
    _lastTemp = temp;
    _lastReadTime = now;
    
    // Đường cong giảm tốc mềm (0.65 thay vì 0.5) để mắt không cảm thấy máy bị giật lag đột ngột
    if (temp >= 42.0f) return 0.65f;
    if (temp >= 39.0f) return 0.85f;
    return 1.0f;
}

@end
