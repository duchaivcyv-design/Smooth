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

- (CGFloat)recommendedAnimationMultiplier {
    float currentTemp = [self getCurrentTemperature];
    
    if (_isOverheating && currentTemp > 44.0f) {
        return 0.6f; 
    }
    
    if (currentTemp > 43.5f) return 0.75f;
    if (currentTemp > 41.5f) return 0.85f;
    if (currentTemp > 39.5f) return 0.95f;
    return 1.0f;
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
    if (temp > 43.5f) return ThermalCritical;
    if (temp > 41.5f) return ThermalWarning;
    if (temp > 39.5f) return ThermalElevated;
    return ThermalNormal;
}

- (BOOL)shouldSuppressBackgroundTasks {
    return _isOverheating || [[NSUserDefaults standardUserDefaults] boolForKey:@"DeepSleepOpt"];
}

@end
