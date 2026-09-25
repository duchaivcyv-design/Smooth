#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <IOKit/IOKitLib.h>
#import <sys/sysctl.h>
#import <sys/utsname.h>
#import <dlfcn.h>
#import <mach/mach.h>
#import <mach/mach_host.h>
#import <pthread.h>
#import <unistd.h>

extern id CFG;
extern BOOL IS_ENABLED;

static BOOL isOldDevice(void) {
    static BOOL cached = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *machine = @"";
        size_t size = 0;
        sysctlbyname("hw.machine", NULL, &size, NULL, 0);
        if (size > 0) {
            char *buf = (char *)malloc(size);
            if (buf) {
                sysctlbyname("hw.machine", buf, &size, NULL, 0);
                machine = [NSString stringWithUTF8String:buf];
                free(buf);
            }
        }
        NSArray *oldPrefixes = @[@"iPhone8,", @"iPhone9,", @"iPhone10,", @"iPhone12,8"];
        for (NSString *prefix in oldPrefixes) {
            if ([machine hasPrefix:prefix]) {
                cached = YES;
                break;
            }
        }
    });
    return cached;
}

static inline BOOL CfgBool(NSString *key) {
    id v = [CFG valueForKey:key];
    return v ? [v boolValue] : NO;
}

static inline NSInteger CfgInt(NSString *key) {
    id v = [CFG valueForKey:key];
    return v ? [v integerValue] : 0;
}

// ==============================================================================
// %hookf Ở FILE SCOPE — TRƯỚC %group DeviceBypassAll
// ★ FIX: Logos yêu cầu %hookf phải ở file scope, không được trong %group ★
// ==============================================================================

%hookf(int, sysctlbyname, const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (!IS_ENABLED) return %orig(name, oldp, oldlenp, newp, newlen);
    if (!CfgBool(@"spoofModel")) return %orig(name, oldp, oldlenp, newp, newlen);

    if ((strcmp(name, "hw.machine") == 0) || (strcmp(name, "hw.model") == 0)) {
        const char *fakeModel = "iPhone16,2";
        if (oldp && oldlenp) {
            strlcpy((char *)oldp, fakeModel, *oldlenp);
            *oldlenp = strlen(fakeModel) + 1;
        } else if (oldlenp) {
            *oldlenp = strlen(fakeModel) + 1;
        }
        return 0;
    }

    if ((strcmp(name, "hw.ncpu") == 0) || (strcmp(name, "hw.activecpu") == 0)) {
        int fakeCores = 6;
        if (oldp && oldlenp) {
            memcpy(oldp, &fakeCores, sizeof(fakeCores));
            *oldlenp = sizeof(fakeCores);
        } else if (oldlenp) {
            *oldlenp = sizeof(fakeCores);
        }
        return 0;
    }

    if (strcmp(name, "hw.physicalcpu") == 0) {
        int fakePhysical = 6;
        if (oldp && oldlenp) {
            memcpy(oldp, &fakePhysical, sizeof(fakePhysical));
            *oldlenp = sizeof(fakePhysical);
        } else if (oldlenp) {
            *oldlenp = sizeof(fakePhysical);
        }
        return 0;
    }

    if (strcmp(name, "hw.logicalcpu") == 0) {
        int fakeLogical = 6;
        if (oldp && oldlenp) {
            memcpy(oldp, &fakeLogical, sizeof(fakeLogical));
            *oldlenp = sizeof(fakeLogical);
        } else if (oldlenp) {
            *oldlenp = sizeof(fakeLogical);
        }
        return 0;
    }

    if (strcmp(name, "hw.memsize") == 0) {
        uint64_t fakeMem = 8ULL * 1024 * 1024 * 1024;
        if (oldp && oldlenp) {
            memcpy(oldp, &fakeMem, sizeof(fakeMem));
            *oldlenp = sizeof(fakeMem);
        } else if (oldlenp) {
            *oldlenp = sizeof(fakeMem);
        }
        return 0;
    }

    return %orig(name, oldp, oldlenp, newp, newlen);
}

%hookf(int, uname, struct utsname *name) {
    int ret = %orig(name);
    if (ret == 0 && IS_ENABLED && CfgBool(@"spoofModel") && name) {
        strlcpy(name->machine, "iPhone16,2", sizeof(name->machine));
    }
    return ret;
}

// ==============================================================================
// GROUP: CHỈ CHỨA %hook (ObjC class hooks) — KHÔNG CÓ %hookf
// ==============================================================================

%group DeviceBypassAll

%hook UIScreen

- (BOOL)isProMotionEnabled {
    if (!IS_ENABLED) return %orig;
    if (CfgBool(@"godModeForce120Hz") && !isOldDevice()) return YES;
    return %orig;
}

- (NSInteger)maximumFramesPerSecond {
    if (!IS_ENABLED) return %orig;
    if (CfgBool(@"godModeForce120Hz")) {
        NSInteger targetHz = CfgInt(@"forcedRefreshRate");
        if (isOldDevice() && targetHz > 60) targetHz = 60;
        if (targetHz > 0) return targetHz;
    }
    return %orig;
}

- (CGFloat)nativeScale {
    if (!IS_ENABLED) return %orig;
    if (CfgBool(@"spoofModel")) return 3.0;
    return %orig;
}

- (CGFloat)scale {
    if (!IS_ENABLED) return %orig;
    if (CfgBool(@"spoofModel")) return 3.0;
    return %orig;
}

%end

%hook CALayer

- (BOOL)allowsEdgeAntialiasing {
    if (!IS_ENABLED) return %orig;
    if (CfgBool(@"spoofModel")) return YES;
    return %orig;
}

- (CGFloat)rasterizationScale {
    if (!IS_ENABLED) return %orig;
    if (CfgBool(@"spoofModel")) return [UIScreen mainScreen].scale;
    return %orig;
}

- (void)setContentsScale:(CGFloat)scale {
    if (!IS_ENABLED) return %orig;
    if (CfgBool(@"spoofModel")) {
        %orig([UIScreen mainScreen].scale);
        return;
    }
    %orig;
}

- (BOOL)allowsGroupOpacity {
    if (IS_ENABLED && CfgBool(@"deepImageProcessing")) return NO;
    return %orig;
}

%end

%hook NSProcessInfo

- (NSProcessInfoThermalState)thermalState {
    if (!IS_ENABLED) return %orig;
    if (CfgBool(@"disableThermal")) return NSProcessInfoThermalStateNominal;
    return %orig;
}

+ (BOOL)isThermalPressureCritical {
    if (!IS_ENABLED) return %orig;
    if (CfgBool(@"disableThermal")) return NO;
    return %orig;
}

- (BOOL)isLowPowerModeEnabled {
    if (!IS_ENABLED) return %orig;
    if (CfgBool(@"lowPowerScheduler")) return NO;
    return %orig;
}

%end

%hook _ThermalMonitor
- (float)currentTemperature {
    if (!IS_ENABLED) return %orig;
    if (CfgBool(@"disableThermal")) return 32.0f;
    return %orig;
}
%end

%hook ThermalMonitor
- (float)currentTemperature {
    if (!IS_ENABLED) return %orig;
    if (CfgBool(@"disableThermal")) return 32.0f;
    return %orig;
}
%end

%hook CAMetalLayer

- (void)setMaximumDrawableCount:(NSUInteger)count {
    if (!IS_ENABLED) return %orig;
    if (CfgBool(@"godModeMetalOverclock")) {
        if (CfgBool(@"gameStutterFix")) {
            %orig(3);
        } else {
            %orig(2);
        }
        return;
    }
    %orig;
}

- (BOOL)presentsWithTransaction {
    if (!IS_ENABLED) return %orig;
    if (CfgBool(@"godModeMetalOverclock")) return NO;
    return %orig;
}

- (void)setFramebufferOnly:(BOOL)flag {
    if (!IS_ENABLED) return %orig;
    if (CfgBool(@"godModeMetalOverclock")) {
        %orig(NO);
        return;
    }
    %orig;
}

%end

%hook MTLTextureDescriptor

- (void)setPixelFormat:(NSUInteger)pixelFormat {
    if (!IS_ENABLED) return %orig;
    if (CfgBool(@"godModeMetalOverclock")) {
        if (pixelFormat == 80) pixelFormat = 75;
    }
    %orig(pixelFormat);
}

- (void)setStorageMode:(NSUInteger)storageMode {
    if (!IS_ENABLED) return %orig;
    if (CfgBool(@"godModeMetalOverclock")) {
        %orig(0);
        return;
    }
    %orig;
}

%end

%hook UIScrollView

- (void)setDecelerationRate:(CGFloat)rate {
    if (!IS_ENABLED) return %orig;
    if (CfgBool(@"disableFrameThrottling")) {
        %orig(UIScrollViewDecelerationRateFast);
    } else {
        %orig;
    }
}

- (void)didMoveToWindow {
    %orig;
    if (IS_ENABLED && CfgBool(@"smoothFeelEngine") && self.window != nil) {
        UIPanGestureRecognizer *pan = self.panGestureRecognizer;
        if (pan) {
            pan.delaysTouchesBegan = NO;
            pan.delaysTouchesEnded = NO;
        }
    }
}

%end

%hook UIWindow

- (void)sendEvent:(UIEvent *)event {
    %orig;
}

%end

%hook NSTimer

+ (NSTimer *)timerWithTimeInterval:(NSTimeInterval)ti target:(id)t selector:(SEL)s userInfo:(id)u repeats:(BOOL)r {
    if (IS_ENABLED && CfgBool(@"batterySaverMax") && r && ti > 0 && ti < 0.033) {
        ti = 0.033;
    }
    return %orig(ti, t, s, u, r);
}

+ (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)ti target:(id)t selector:(SEL)s userInfo:(id)u repeats:(BOOL)r {
    if (IS_ENABLED && CfgBool(@"batterySaverMax") && r && ti > 0 && ti < 0.033) {
        ti = 0.033;
    }
    return %orig(ti, t, s, u, r);
}

%end

%end // DeviceBypassAll

// ==============================================================================
// C-LEVEL CONSTRUCTOR (KHÔNG PHẢI LOGOS %ctor)
// ==============================================================================

__attribute__((constructor))
static void deviceBypass_entry(void) {
    @autoreleasepool {
        if (!IS_ENABLED) {
            NSLog(@"[DeviceBypass v10] Disabled by Master Switch.");
            return;
        }

        %init(DeviceBypassAll);

        NSLog(@"[DeviceBypass v10] ALL ENGINES INITIALIZED | Device: %@ | Spoof: %@ | Thermal: %@",
              isOldDevice() ? @"OLD (6s-8)" : @"NEW (X-15PM)",
              CfgBool(@"spoofModel") ? @"ON" : @"OFF",
              CfgBool(@"disableThermal") ? @"BYPASSED" : @"NORMAL");
    }
}
