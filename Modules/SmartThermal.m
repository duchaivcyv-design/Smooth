#import "SmartThermal.h"
#import <UIKit/UIKit.h>
#import <mach/mach.h>
#import <mach/mach_host.h>
#import <mach/processor_info.h>
#import <IOKit/IOKitLib.h>
#import <dlfcn.h>
#import <malloc/malloc.h>

static inline NSString *SmartThermal_ResolvePrefix(void) {
    static NSString *cachedRoot = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Dl_info info;
        if (dladdr((const void *)SmartThermal_ResolvePrefix, &info) && info.dli_fname) {
            NSString *dylibPath = [NSString stringWithUTF8String:info.dli_fname];
            NSRange range = [dylibPath rangeOfString:@"/var/jb"];
            if (range.location != NSNotFound) {
                NSRange sub = [dylibPath rangeOfString:@"/" options:0 range:NSMakeRange(range.location + 7, dylibPath.length - (range.location + 7))];
                cachedRoot = (sub.location != NSNotFound) ? [dylibPath substringToIndex:sub.location] : @"/var/jb";
            } else {
                cachedRoot = @"/var/jb";
            }
        } else {
            cachedRoot = @"/var/jb";
        }
    });
    return cachedRoot;
}

@implementation SmartThermal {
    dispatch_source_t _thermalWatchdog;
    BOOL _isMonitoring;
}

+ (instancetype)sharedInstance {
    static SmartThermal *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[self alloc] init];
    });
    return inst;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _currentThermalState = NSProcessInfoThermalStateNominal;
        _isDeviceCharging = NO;
        _isHeavyLoadDetected = NO;
        _isMonitoring = NO;
        [self startThermalMonitoring];
    }
    return self;
}

- (void)startThermalMonitoring {
    if (_isMonitoring) return;
    _isMonitoring = YES;

    // 1. Lắng nghe thay đổi nhiệt độ từ NSProcessInfo
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(thermalStateDidChange:)
                                                 name:NSProcessInfoThermalStateDidChangeNotification
                                               object:nil];

    // 2. Kích hoạt giám sát pin trên main thread an toàn
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(batteryStateDidChange:)
                                                     name:UIDeviceBatteryStateDidChangeNotification
                                                   object:nil];
        [self updateBatteryState];
    });

    // 3. Khởi chạy Watchdog kiểm tra tải hệ thống ngầm mỗi 4 giây
    dispatch_queue_t queue = dispatch_queue_create("com.taojb.smartthermal.watchdog", DISPATCH_QUEUE_SERIAL);
    _thermalWatchdog = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(_thermalWatchdog, DISPATCH_TIME_NOW, 4.0 * NSEC_PER_SEC, 1.0 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(_thermalWatchdog, ^{
        [self inspectHardwareLoad];
    });
    dispatch_resume(_thermalWatchdog);
}

- (void)thermalStateDidChange:(NSNotification *)note {
    _currentThermalState = [[NSProcessInfo processInfo] thermalState];
    if (_currentThermalState >= NSProcessInfoThermalStateSerious) {
        [self mitigateThermalPressureIfNeeded];
    }
}

- (void)batteryStateDidChange:(NSNotification *)note {
    [self updateBatteryState];
}

- (void)updateBatteryState {
    UIDeviceBatteryState state = [UIDevice currentDevice].batteryState;
    _isDeviceCharging = (state == UIDeviceBatteryStateCharging || state == UIDeviceBatteryStateFull);
}

- (void)inspectHardwareLoad {
    _currentThermalState = [[NSProcessInfo processInfo] thermalState];

    // Đo tải CPU thông qua Mach host statistics
    host_cpu_load_info_data_t cpuinfo;
    mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;
    kern_return_t kr = host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, (host_info_t)&cpuinfo, &count);
    if (kr == KERN_SUCCESS) {
        unsigned long long totalTicks = cpuinfo.cpu_ticks[CPU_STATE_USER] +
                                        cpuinfo.cpu_ticks[CPU_STATE_SYSTEM] +
                                        cpuinfo.cpu_ticks[CPU_STATE_NICE] +
                                        cpuinfo.cpu_ticks[CPU_STATE_IDLE];
        unsigned long long busyTicks = cpuinfo.cpu_ticks[CPU_STATE_USER] +
                                       cpuinfo.cpu_ticks[CPU_STATE_SYSTEM] +
                                       cpuinfo.cpu_ticks[CPU_STATE_NICE];
        if (totalTicks > 0) {
            float usage = (float)busyTicks / (float)totalTicks;
            _isHeavyLoadDetected = (usage > 0.85f);
        }
    }

    if (_isHeavyLoadDetected && _currentThermalState >= NSProcessInfoThermalStateSerious) {
        [self mitigateThermalPressureIfNeeded];
    }
}

- (CGFloat)recommendedAnimationMultiplier {
    switch (_currentThermalState) {
        case NSProcessInfoThermalStateNominal:
            return 0.80f; // Siêu mượt, gia tốc tốc độ hiển thị
        case NSProcessInfoThermalStateFair:
            return 0.85f;
        case NSProcessInfoThermalStateSerious:
            return 1.0f;  // Về chuẩn khi máy ấm
        case NSProcessInfoThermalStateCritical:
            return 1.15f; // Giãn nhẹ thời gian render để hạ nhiệt chip
        default:
            return 0.80f;
    }
}

- (NSInteger)recommendedTargetHzWithBase:(NSInteger)baseHz allowOverclock:(BOOL)overclock {
    if (overclock && _currentThermalState <= NSProcessInfoThermalStateFair) {
        return 144;
    }

    // Bảo vệ hạ nhiệt khi cắm sạc
    if (_isDeviceCharging && _currentThermalState >= NSProcessInfoThermalStateFair) {
        return (baseHz > 60) ? 60 : baseHz;
    }

    switch (_currentThermalState) {
        case NSProcessInfoThermalStateNominal:
            return (baseHz > 0) ? baseHz : 60;
        case NSProcessInfoThermalStateFair:
            return (baseHz > 90) ? 90 : baseHz;
        case NSProcessInfoThermalStateSerious:
            return (baseHz > 60) ? 60 : baseHz;
        case NSProcessInfoThermalStateCritical:
            return 45;
        default:
            return (baseHz > 0) ? baseHz : 60;
    }
}

- (NSInteger)recommendedTargetFPSWithBase:(NSInteger)baseFPS {
    return [self recommendedTargetHzWithBase:baseFPS allowOverclock:NO];
}

- (BOOL)shouldThrottleForChargingProtection {
    return (_isDeviceCharging && _currentThermalState >= NSProcessInfoThermalStateFair);
}

- (void)mitigateThermalPressureIfNeeded {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        malloc_zone_pressure_relief(NULL, 0);
        mach_port_t selfTask = mach_task_self();
#if defined(VM_FLAGS_PURGABLE)
        vm_purgable_control(selfTask, 0, VM_PURGABLE_PURGE_ALL, NULL);
#endif
    });
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_thermalWatchdog) {
        dispatch_source_cancel(_thermalWatchdog);
        _thermalWatchdog = nil;
    }
}

@end
