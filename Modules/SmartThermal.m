#import "SmartThermal.h"
#import <UIKit/UIKit.h>
#import <mach/mach.h>
#import <mach/mach_host.h>
#import <mach/processor_info.h>
#import <dlfcn.h>
#import <malloc/malloc.h>

#ifndef VM_PURGABLE_PURGE_ALL
#define VM_PURGABLE_PURGE_ALL 0
#endif

#ifdef __cplusplus
extern "C" {
#endif
kern_return_t vm_purgable_control(mach_port_t task, vm_address_t address, vm_purgable_t control, int *state);
#ifdef __cplusplus
}
#endif

// ====================================================================================================
// TRIỂN KHAI 2 HÀM C TRUY VẤN NHANH 0NS CHO TWEAK.XM (KHỚP CHUẨN VỚI SMART_THERMAL.H)
// ====================================================================================================

BOOL SmartThermal_IsDeviceChargingFast(void) {
    return [[SmartThermal sharedInstance] isDeviceCharging];
}

BOOL SmartThermal_IsThermalThrottlingActive(void) {
    return [[SmartThermal sharedInstance] shouldThrottleForChargingProtection];
}

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

@interface SmartThermal ()
@property (nonatomic, assign, readwrite) NSProcessInfoThermalState currentThermalState;
@property (nonatomic, assign, readwrite) BOOL isDeviceCharging;
@property (nonatomic, assign, readwrite) BOOL isHeavyLoadDetected;
@end

@implementation SmartThermal {
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
        _currentThermalState = [NSProcessInfo processInfo].thermalState;
        _isDeviceCharging = NO;
        _isHeavyLoadDetected = NO;
        _isMonitoring = NO;
        [self startThermalMonitoring];
    }
    return self;
}

// ====================================================================================================
// GIÁM SÁT THỤ ĐỘNG THEO SỰ KIỆN (ZERO-OVERHEAD - KHÔNG CHẠY VÒNG LẶP GÂY NÓNG MÁY / HAO PIN)
// ====================================================================================================

- (void)startThermalMonitoring {
    if (_isMonitoring) return;
    _isMonitoring = YES;

    // 1. Lắng nghe thông báo thay đổi nhiệt độ phần cứng của Apple
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(thermalStateDidChange:)
                                                 name:NSProcessInfoThermalStateDidChangeNotification
                                               object:nil];

    // 2. Kích hoạt giám sát trạng thái pin an toàn
    if ([NSThread isMainThread]) {
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(batteryStateDidChange:)
                                                     name:UIDeviceBatteryStateDidChangeNotification
                                                   object:nil];
        [self updateBatteryState];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [UIDevice currentDevice].batteryMonitoringEnabled = YES;
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(batteryStateDidChange:)
                                                         name:UIDeviceBatteryStateDidChangeNotification
                                                       object:nil];
            [self updateBatteryState];
        });
    }
}

- (void)thermalStateDidChange:(NSNotification *)note {
    self.currentThermalState = [NSProcessInfo processInfo].thermalState;
    if (self.currentThermalState >= NSProcessInfoThermalStateSerious) {
        [self mitigateThermalPressureIfNeeded];
    }
}

- (void)batteryStateDidChange:(NSNotification *)note {
    [self updateBatteryState];
}

- (void)updateBatteryState {
    UIDeviceBatteryState state = [UIDevice currentDevice].batteryState;
    self.isDeviceCharging = (state == UIDeviceBatteryStateCharging || state == UIDeviceBatteryStateFull);
}

// ====================================================================================================
// ĐIỀU TIẾT HOẠT ẢNH & TẦN SỐ QUÉT THEO NHIỆT ĐỘ THỰC TẾ
// ====================================================================================================

- (CGFloat)recommendedAnimationMultiplier {
    switch (self.currentThermalState) {
        case NSProcessInfoThermalStateNominal:
            return 0.80f; // Tăng tốc hoạt ảnh 20%
        case NSProcessInfoThermalStateFair:
            return 0.85f;
        case NSProcessInfoThermalStateSerious:
            return 1.0f;  // Về mặc định
        case NSProcessInfoThermalStateCritical:
            return 1.15f; // Giãn nhẹ nhịp render để hạ nhiệt chip
        default:
            return 0.80f;
    }
}

- (NSInteger)recommendedTargetHzWithBase:(NSInteger)baseHz allowOverclock:(BOOL)overclock {
    // 1. Quá nhiệt nghiêm trọng: Hạ trần an toàn
    if (self.currentThermalState == NSProcessInfoThermalStateCritical) {
        return 45;
    }

    // 2. Bảo vệ nhiệt độ khi sạc: Nếu máy ấm khi đang sạc, giữ trần 60Hz để chống phồng pin
    if (self.isDeviceCharging && self.currentThermalState >= NSProcessInfoThermalStateFair) {
        return (baseHz > 60) ? 60 : baseHz;
    }

    // 3. Môi trường mát mẻ: Bung trần tần số quét
    if (overclock && self.currentThermalState <= NSProcessInfoThermalStateFair) {
        return 144;
    }

    switch (self.currentThermalState) {
        case NSProcessInfoThermalStateNominal:
            return (baseHz > 0) ? baseHz : 60;
        case NSProcessInfoThermalStateFair:
            return (baseHz > 90) ? 90 : baseHz;
        case NSProcessInfoThermalStateSerious:
            return (baseHz > 60) ? 60 : baseHz;
        default:
            return (baseHz > 0) ? baseHz : 60;
    }
}

- (NSInteger)recommendedTargetFPSWithBase:(NSInteger)baseFPS {
    return [self recommendedTargetHzWithBase:baseFPS allowOverclock:NO];
}

- (BOOL)shouldThrottleForChargingProtection {
    return (self.isDeviceCharging && self.currentThermalState >= NSProcessInfoThermalStateFair);
}

// ====================================================================================================
// HẠ NHIỆT CƯỠNG BỨC (XẢ VÙNG NHỚ TRANG NHÂN AN TOÀN TRÊN LUỒNG BACKGROUND)
// ====================================================================================================

- (void)mitigateThermalPressureIfNeeded {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        malloc_zone_pressure_relief(NULL, 0);
        mach_port_t selfTask = mach_task_self();
        if (MACH_PORT_VALID(selfTask)) {
            int purgeState = 0;
            vm_purgable_control(selfTask, 0, VM_PURGABLE_PURGE_ALL, &purgeState);
        }
    });
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
