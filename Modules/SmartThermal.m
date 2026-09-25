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
        _filteredTemp = 38.0f;
        _lastReadTime = 0;
        _isOverheating = NO;
        _highTempCounter = 0;
        _thermalQueue = dispatch_queue_create("com.boostiphone6s.thermal", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

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
    
    // Đọc nhiệt async trên serial queue để tránh block main thread
    __block float rawTemp = 38.0f;
    dispatch_sync(_thermalQueue, ^{
        rawTemp = [self readRawTemperature];
    });
    
    float delta = fabsf(rawTemp - _filteredTemp);
    float alpha = (delta > 5.0f) ? 0.5f : 0.3f; // Phản ứng nhanh hơn khi nhiệt thay đổi đột ngột
    _filteredTemp = (_filteredTemp * (1.0f - alpha)) + (rawTemp * alpha);
    
    // Track trạng thái quá nhiệt kéo dài
    if (_filteredTemp > 43.0f) {
        _highTempCounter++;
        _isOverheating = (_highTempCounter >= 5); // 5 lần đọc liên tiếp (>10s) = quá nhiệt thật sự
    } else {
        _highTempCounter = MAX(0, _highTempCounter - 1);
        if (_highTempCounter == 0) _isOverheating = NO;
    }
    
    return _filteredTemp;
}

- (float)readRawTemperature {
    float temp = 38.0f;
    BOOL hasValidReading = NO;
    
    // Priority 1: Sysctl thermal temperature (Chính xác nhất)
    size_t size = sizeof(float);
    if (sysctlbyname("kern.thermal.temperature", &temp, &size, NULL, 0) == 0) {
        hasValidReading = YES;
    }
    
    // Priority 2: Active CPU cores heuristic (Fallback khi sysctl fail)
    if (!hasValidReading) {
        int activeCores = 0;
        size = sizeof(int);
        if (sysctlbyname("hw.activecpu", &activeCores, &size, NULL, 0) == 0) {
            if (activeCores <= 2) { temp = 44.0f; hasValidReading = YES; }
            else if (activeCores <= 4) { temp = 41.0f; hasValidReading = YES; }
            else { temp = 38.0f; hasValidReading = YES; }
        }
    }
    
    // Priority 3: IOKit Battery Sensor (An toàn với master port management)
    if (!hasValidReading) {
        mach_port_t masterPort = MACH_PORT_NULL;
        kern_return_t kr = host_get_io_master(mach_host_self(), &masterPort);
        
        if (kr == KERN_SUCCESS && masterPort != MACH_PORT_NULL) {
            io_service_t batteryService = IOServiceGetMatchingService(masterPort, 
                                                                       IOServiceMatching("AppleARMPMUCharger"));
            if (batteryService != MACH_PORT_NULL) {
                CFTypeRef tempData = IORegistryEntryCreateCFProperty(batteryService, 
                                                                      CFSTR("Temperature"), 
                                                                      kCFAllocatorDefault, 0);
                if (tempData && CFGetTypeID(tempData) == CFNumberGetTypeID()) {
                    double battTemp = 0;
                    CFNumberGetValue((CFNumberRef)tempData, kCFNumberDoubleType, &battTemp);
                    temp = (float)(battTemp + 7.0); // Bù chênh lệch giữa pin và CPU
                    hasValidReading = YES;
                }
                if (tempData) CFRelease(tempData);
                IOObjectRelease(batteryService);
            }
            mach_port_deallocate(mach_task_self(), masterPort);
        }
    }
    
    return hasValidReading ? temp : 38.0f;
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
