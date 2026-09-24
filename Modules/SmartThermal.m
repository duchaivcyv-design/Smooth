#import "SmartThermal.h"
#import <sys/sysctl.h>
#import <mach/mach.h>
#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>

@implementation SmartThermal {
    float _filteredTemp;
    NSTimeInterval _lastReadTime;
    BOOL _isOverheating;
    NSUInteger _highTempCounter;
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

// ★ SỬA LẠI NGƯNG NHIỆT CHO KHỚP VỚI ENUM MỚI TRONG HEADER ★
- (CGFloat)recommendedAnimationMultiplier {
    ThermalLevel state = [self currentThermalState];
    
    switch (state) {
        case ThermalCritical: return 0.5f; // Nguy hiểm: Giảm mạnh nhất
        case ThermalHot:      return 0.7f; // Nóng: Giảm đáng kể
        case ThermalWarm:     return 0.9f; // Ấm: Giảm nhẹ
        case ThermalCool:     return 1.0f; // Mát: Full tốc độ
        default:              return 1.0f;
    }
}

- (float)getCurrentTemperature {
    NSTimeInterval now = CFAbsoluteTimeGetCurrent();
    
    if (now - _lastReadTime < 2.0) {
        return _filteredTemp;
    }
    _lastReadTime = now;
    
    float rawTemp = [self readRawTemperature];
    _filteredTemp = (_filteredTemp * 0.7f) + (rawTemp * 0.3f);
    
    if (_filteredTemp > 43.0f) {
        _highTempCounter++;
        _isOverheating = (_highTempCounter >= 5);
    } else {
        _highTempCounter = MAX(0, _highTempCounter - 1);
        if (_highTempCounter == 0) _isOverheating = NO;
    }
    
    return _filteredTemp;
}

- (float)readRawTemperature {
    float temp = 38.0f;
    
    size_t size = sizeof(float);
    if (sysctlbyname("kern.thermal.temperature", &temp, &size, NULL, 0) == 0) {
        return temp;
    }
    
    int activeCores = 0;
    size = sizeof(int);
    if (sysctlbyname("hw.activecpu", &activeCores, &size, NULL, 0) == 0) {
        if (activeCores <= 2) temp = 44.0f;
        else if (activeCores <= 4) temp = 41.0f;
        else temp = 38.0f;
    }
    
    io_service_t batteryService = IOServiceGetMatchingService(kIOMasterPortDefault, 
                                                               IOServiceMatching("AppleARMPMUCharger"));
    if (batteryService != MACH_PORT_NULL) {
        CFTypeRef tempData = IORegistryEntryCreateCFProperty(batteryService, 
                                                              CFSTR("Temperature"), 
                                                              kCFAllocatorDefault, 0);
        if (tempData && CFGetTypeID(tempData) == CFNumberGetTypeID()) {
            double battTemp = 0;
            CFNumberGetValue((CFNumberRef)tempData, kCFNumberDoubleType, &battTemp);
            temp = (float)(battTemp + 7.0);
        }
        if (tempData) CFRelease(tempData);
        IOObjectRelease(batteryService);
    }
    
    return temp;
}

- (ThermalLevel)currentThermalState {
    float temp = [self getCurrentTemperature];
    
    if (temp > 43.5f) return ThermalCritical;  // > 43.5°C = Nguy hiểm
    if (temp > 40.0f) return ThermalHot;       // > 40°C = Nóng
    if (temp > 35.0f) return ThermalWarm;      // > 35°C = Ấm vừa
    return ThermalCool;                        // ≤ 35°C = Mát mẻ
}

- (BOOL)shouldSuppressBackgroundTasks {
    ThermalLevel state = [self currentThermalState];
    BOOL deepSleepOpt = [[NSUserDefaults standardUserDefaults] boolForKey:@"DeepSleepOpt"];
    
    // Chặn background khi nóng trở lên HOẶC khi bật tối ưu ngủ sâu
    return (state == ThermalHot || state == ThermalCritical) || deepSleepOpt;
}

@end
