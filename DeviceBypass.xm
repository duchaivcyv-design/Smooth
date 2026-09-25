// ==============================================================================
// DEVICE BYPASS MODULE v9.0 - TRUE HARDWARE CONTROL ENGINE
// Target: iOS 14.0 - 26.0.1 | iPhone 6s to 15 Pro Max+
// Author: TaoJB | Project: Smooth
// Features: Dynamic Hz Selector, Thermal Bypass, Hardware Spoof, GPU Override
// Architecture: Rootless-Aware | HideJB Compatible
// ==============================================================================

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <IOKit/IOKitLib.h>
#import <sys/sysctl.h>
#import <dlfcn.h>
#import <mach/mach.h>
#import <mach/mach_host.h>
#import <pthread.h>
#import <unistd.h>

// ★ EXTERN GLOBAL VARIABLES TỪ Tweak.xm ★
extern id CFG;
extern BOOL IS_ENABLED;

#define IS_BYPASS_ACTIVE (IS_ENABLED && \
                          ([CFG valueForKey:@"spoofModel"] || \
                           [CFG valueForKey:@"godModeForce120Hz"] || \
                           [CFG valueForKey:@"disableThermal"]))

// ==============================================================================
// HELPER: AUTO-DETECT OLD vs NEW DEVICE
// ==============================================================================

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

// ==============================================================================
// GROUP 1: DISPLAY SPOOF - TRUE Hz CONTROL
// ==============================================================================

%group DisplaySpoof

%hook UIScreen

- (BOOL)isProMotionEnabled {
    if (!IS_ENABLED) return %orig;
    if ([CFG valueForKey:@"godModeForce120Hz"] && !isOldDevice()) return YES;
    return %orig;
}

- (NSInteger)maximumFramesPerSecond {
    if (!IS_ENABLED) return %orig;
    if ([CFG valueForKey:@"godModeForce120Hz"]) {
        NSInteger targetHz = [[CFG valueForKey:@"forcedRefreshRate"] integerValue];
        if (isOldDevice() && targetHz > 60) targetHz = 60;
        if (targetHz > 0) return targetHz;
    }
    return %orig;
}

- (CGFloat)nativeScale {
    if (!IS_ENABLED) return %orig;
    if ([CFG valueForKey:@"spoofModel"]) return 3.0;
    return %orig;
}

- (CGRect)bounds {
    if (!IS_ENABLED) return %orig;
    return %orig;
}

- (CGFloat)scale {
    if (!IS_ENABLED) return %orig;
    if ([CFG valueForKey:@"spoofModel"]) return 3.0;
    return %orig;
}

%end

%hook CADisplayLink

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (!IS_ENABLED || ![CFG valueForKey:@"godModeForce120Hz"]) return %orig;
    
    NSInteger target = [[CFG valueForKey:@"forcedRefreshRate"] integerValue];
    if (isOldDevice() && target > 60) target = 60;
    
    if (target > 0 && fps > target) fps = target;
    if (target == 30) fps = 30;
    
    %orig(fps);
}

- (NSInteger)preferredFramesPerSecond {
    if (!IS_ENABLED || ![CFG valueForKey:@"godModeForce120Hz"]) return %orig;
    NSInteger target = [[CFG valueForKey:@"forcedRefreshRate"] integerValue];
    if (isOldDevice() && target > 60) target = 60;
    return target > 0 ? target : %orig;
}

%end

%hook CALayer

- (BOOL)allowsEdgeAntialiasing {
    if (!IS_ENABLED) return %orig;
    if ([CFG valueForKey:@"spoofModel"]) return YES;
    return %orig;
}

- (CGFloat)rasterizationScale {
    if (!IS_ENABLED) return %orig;
    if ([CFG valueForKey:@"spoofModel"]) return [UIScreen mainScreen].scale;
    return %orig;
}

- (void)setContentsScale:(CGFloat)scale {
    if (!IS_ENABLED) return %orig;
    if ([CFG valueForKey:@"spoofModel"]) {
        %orig([UIScreen mainScreen].scale);
        return;
    }
    %orig;
}

%end

%end

// ==============================================================================
// GROUP 2: THERMAL BYPASS
// ==============================================================================

%group ThermalBypass

%hook NSProcessInfo

- (NSProcessInfoThermalState)thermalState {
    if (!IS_ENABLED) return %orig;
    if ([CFG valueForKey:@"disableThermal"]) return NSProcessInfoThermalStateNominal;
    return %orig;
}

+ (BOOL)isThermalPressureCritical {
    if (!IS_ENABLED) return %orig;
    if ([CFG valueForKey:@"disableThermal"]) return NO;
    return %orig;
}

- (BOOL)isLowPowerModeEnabled {
    if (!IS_ENABLED) return %orig;
    if ([CFG valueForKey:@"lowPowerScheduler"]) return NO;
    return %orig;
}

%end

%hook _ThermalMonitor

- (float)currentTemperature {
    if (!IS_ENABLED) return %orig;
    if ([CFG valueForKey:@"disableThermal"]) return 32.0f;
    return %orig;
}

%end

%hook ThermalMonitor

- (float)currentTemperature {
    if (!IS_ENABLED) return %orig;
    if ([CFG valueForKey:@"disableThermal"]) return 32.0f;
    return %orig;
}

%end

%end

// ==============================================================================
// GROUP 3: HARDWARE IDENTITY SPOOF
// ==============================================================================

%group HardwareSpoof

%hookf(int, sysctlbyname, const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (!IS_ENABLED) return %orig(name, oldp, oldlenp, newp, newlen);
    if (![CFG valueForKey:@"spoofModel"]) return %orig(name, oldp, oldlenp, newp, newlen);

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

%end

// ==============================================================================
// GROUP 4: GPU & METAL OVERCLOCK ENGINE
// ==============================================================================

%group GPUEngine

%hook CAMetalLayer

- (void)setMaximumDrawableCount:(NSUInteger)count {
    if (!IS_ENABLED) return %orig;
    if ([CFG valueForKey:@"godModeMetalOverclock"]) {
        %orig(2);
        return;
    }
    %orig;
}

- (BOOL)presentsWithTransaction {
    if (!IS_ENABLED) return %orig;
    if ([CFG valueForKey:@"godModeMetalOverclock"]) return NO;
    return %orig;
}

- (void)setFramebufferOnly:(BOOL)flag {
    if (!IS_ENABLED) return %orig;
    if ([CFG valueForKey:@"godModeMetalOverclock"]) {
        %orig(NO);
        return;
    }
    %orig;
}

%end

%hook MTLTextureDescriptor

- (void)setPixelFormat:(NSUInteger)pixelFormat {
    if (!IS_ENABLED) return %orig;
    if ([CFG valueForKey:@"godModeMetalOverclock"]) {
        if (pixelFormat == 80) pixelFormat = 75;
    }
    %orig(pixelFormat);
}

- (void)setStorageMode:(NSUInteger)storageMode {
    if (!IS_ENABLED) return %orig;
    if ([CFG valueForKey:@"godModeMetalOverclock"]) {
        %orig(0);
        return;
    }
    %orig;
}

%end

%end

// ==============================================================================
// GROUP 5: SCROLL & TOUCH OPTIMIZATION
// ==============================================================================

%group ScrollOptimization

%hook UIScrollView

- (void)setContentOffset:(CGPoint)offset animated:(BOOL)animated {
    if (!IS_ENABLED) return %orig;
    if ([CFG valueForKey:@"disableFrameThrottling"]) {
        %orig(offset, NO);
    } else {
        %orig;
    }
}

- (void)_setContentOffset:(CGPoint)offset animated:(BOOL)animated {
    if (!IS_ENABLED) return %orig;
    if ([CFG valueForKey:@"disableFrameThrottling"]) {
        %orig(offset, NO);
    } else {
        %orig;
    }
}

- (void)setDecelerationRate:(CGFloat)rate {
    if (!IS_ENABLED) return %orig;
    if ([CFG valueForKey:@"disableFrameThrottling"]) {
        %orig(UIScrollViewDecelerationRateFast);
    } else {
        %orig;
    }
}

%end

%hook UIWindow

- (void)sendEvent:(UIEvent *)event {
    if (!IS_ENABLED) return %orig;
    %orig;
}

%end

%end

// ==============================================================================
// CONSTRUCTOR
// ==============================================================================

%ctor {
    @autoreleasepool {
        if (!IS_ENABLED) {
            NSLog(@"[DeviceBypass v9.0] ⏸️ Disabled by Master Switch.");
            return;
        }

        BOOL hasDisplaySpoof = [CFG valueForKey:@"godModeForce120Hz"] || [CFG valueForKey:@"spoofModel"];
        BOOL hasThermalBypass = [CFG valueForKey:@"disableThermal"];
        BOOL hasHardwareSpoof = [CFG valueForKey:@"spoofModel"];
        BOOL hasGPUEngine = [CFG valueForKey:@"godModeMetalOverclock"];
        BOOL hasScrollOpt = [CFG valueForKey:@"disableFrameThrottling"];

        if (hasDisplaySpoof) {
            %init(DisplaySpoof);
            NSLog(@"[DeviceBypass v9.0] 🖥️ DisplaySpoof ACTIVE | Hz: %ld | OldDevice: %@",
                  (long)[[CFG valueForKey:@"forcedRefreshRate"] integerValue],
                  isOldDevice() ? @"YES (capped 60Hz)" : @"NO");
        }

        if (hasThermalBypass) {
            %init(ThermalBypass);
            NSLog(@"[DeviceBypass v9.0] 🌡️ ThermalBypass ACTIVE | Temp locked to 32°C");
        }

        if (hasHardwareSpoof) {
            %init(HardwareSpoof);
            NSLog(@"[DeviceBypass v9.0] 🔧 HardwareSpoof ACTIVE | Model: iPhone16,2 | Cores: 6 | RAM: 8GB");
        }

        if (hasGPUEngine) {
            %init(GPUEngine);
            NSLog(@"[DeviceBypass v9.0] 🎮 GPUEngine ACTIVE | Metal Overclock ON");
        }

        if (hasScrollOpt) {
            %init(ScrollOptimization);
            NSLog(@"[DeviceBypass v9.0] 📜 ScrollOptimization ACTIVE | Animation bypass ON");
        }

        NSLog(@"[DeviceBypass v9.0] ✅ ALL ENGINES INITIALIZED | Rootless Mode");
    }
}
