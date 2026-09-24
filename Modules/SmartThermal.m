#import "SmartThermal.h"
#import <sys/sysctl.h>
#import <mach/mach.h>
#import <Foundation/Foundation.h>

@implementation SmartThermal {
    float _filteredTemp;          // Nhiệt độ sau khi lọc nhiễu
    NSTimeInterval _lastReadTime; // Thời điểm đọc nhiệt cuối cùng
    BOOL _isOverheating;          // Trạng thái quá nhiệt kéo dài
    NSUInteger _highTempCounter;  // Đếm số lần liên tiếp vượt ngưỡng cao
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
        _filteredTemp = 38.0f;
        _lastReadTime = 0;
        _isOverheating = NO;
        _highTempCounter = 0;
    }
    return self;
}

- (CGFloat)recommendedAnimationMultiplier {
    float currentTemp = [self getCurrentTemperature];
    
    // ★ LOGIC ĐIỀU TIẾT ĐỘNG THEO TẢI TRỌNG ★
    // Nếu đang quá nhiệt KÉO DÀI, giảm mạnh hơn nữa để ép hạ nhiệt nhanh
    if (_isOverheating && currentTemp > 44.0f) {
        return 0.6f; // Chế độ khẩn cấp: Giảm animation xuống 60%
    }
    
    // Ngưỡng nhiệt an toàn cho iPhone 6s-X series
    if (currentTemp > 43.5f) return 0.75f; // Rất nóng: Giảm đáng kể
    if (currentTemp > 41.5f) return 0.85f; // Nóng vừa: Giảm nhẹ
    if (currentTemp > 39.5f) return 0.95f; // Ấm: Gần như full speed
    return 1.0f;                           // Mát: Full tốc độ
}

- (float)getCurrentTemperature {
    NSTimeInterval now = CFAbsoluteTimeGetCurrent();
    
    // ★ GIỚI HẠN TẦN SUẤT ĐỌC: Chỉ đọc tối đa mỗi 2 giây ★
    // Tránh spam sysctl gây overhead CPU không cần thiết
    if (now - _lastReadTime < 2.0) {
        return _filteredTemp;
    }
    _lastReadTime = now;
    
    float rawTemp = [self readRawTemperature];
    
    // ★ BỘ LỌC NHIỄU SIMPLE MOVING AVERAGE ★
    // Làm mượt biến động nhiệt đột ngột do sensor noise
    _filteredTemp = (_filteredTemp * 0.7f) + (rawTemp * 0.3f);
    
    // ★ TRACKING TRẠNG THÁI QUÁ NHIỆT KÉO DÀI ★
    if (_filteredTemp > 43.0f) {
        _highTempCounter++;
        _isOverheating = (_highTempCounter >= 5); // 5 lần đọc liên tiếp (>10s) = quá nhiệt thật sự
    } else {
        _highTempCounter = MAX(0, _highTempCounter - 1); // Giảm dần counter khi mát lại
        if (_highTempCounter == 0) _isOverheating = NO;
    }
    
    return _filteredTemp;
}

// Đọc nhiệt thô từ nhiều nguồn fallback
- (float)readRawTemperature {
    float temp = 38.0f; // Default safe value
    
    // Priority 1: kern.thermal.temperature (iOS 15+)
    size_t size = sizeof(float);
    if (sysctlbyname("kern.thermal.temperature", &temp, &size, NULL, 0) == 0) {
        return temp;
    }
    
    // Priority 2: hw.perflevel0.physicalcpu (Indirect thermal proxy on A-series)
    // Khi CPU bị throttle, physical active cores giảm -> suy ra nhiệt cao
    int activeCores = 0;
    size = sizeof(int);
    if (sysctlbyname("hw.activecpu", &activeCores, &size, NULL, 0) == 0) {
        // Heuristic: Ít core active hơn mức bình thường = đang bị thermal throttle
        // iPhone 6s/X có 2-6 cores tùy model
        if (activeCores <= 2) temp = 44.0f;
        else if (activeCores <= 4) temp = 41.0f;
        else temp = 38.0f;
    }
    
    // Priority 3: Battery temperature via IOKit (Most accurate but slowest)
    // Chỉ dùng làm fallback cuối cùng vì IOServiceGetMatchingService tốn thời gian
    io_service_t batteryService = IOServiceGetMatchingService(kIOMasterPortDefault, 
                                                               IOServiceMatching("AppleARMPMUCharger"));
    if (batteryService != MACH_PORT_NULL) {
        CFTypeRef tempData = IORegistryEntryCreateCFProperty(batteryService, 
                                                              CFSTR("Temperature"), 
                                                              kCFAllocatorDefault, 0);
        if (tempData && CFGetTypeID(tempData) == CFNumberGetTypeID()) {
            double battTemp = 0;
            CFNumberGetValue((CFNumberRef)tempData, kCFNumberDoubleType, &battTemp);
            // Battery temp thường thấp hơn CPU temp ~5-8°C, cộng bù vào
            temp = (float)(battTemp + 7.0);
        }
        if (tempData) CFRelease(tempData);
        IOObjectRelease(batteryService);
    }
    
    return temp;
}

@end
