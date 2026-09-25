// ==============================================================================
// DEVICE BYPASS MODULE v8.0 - HIGH PERFORMANCE SYNC ENGINE
// Target: iOS 14.0 - 26.0.1 | iPhone 6s to Latest
// ==============================================================================

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <IOKit/IOKitLib.h>
#import <sys/sysctl.h>
#import <dlfcn.h>
#import <mach/mach.h>

extern id CFG; 
extern BOOL IS_ENABLED;

#define IS_BYPASS_ACTIVE (IS_ENABLED && \
                          ([CFG valueForKey:@"spoofModel"] || \
                           [CFG valueForKey:@"godModeForce120Hz"] || \
                           [CFG valueForKey:@"disableThermal"]))

// ==========================================
// 1. FAKE HARDWARE CAPABILITIES (GPU & DISPLAY)
// ==========================================

%group DisplaySpoof
%hook UIScreen
- (BOOL)isProMotionEnabled {
    if ([CFG valueForKey:@"godModeForce120Hz"]) return YES;
    return %orig;
}

- (NSInteger)maximumFramesPerSecond {
    NSInteger targetHz = [[CFG valueForKey:@"forcedRefreshRate"] integerValue];
    if ([CFG valueForKey:@"godModeForce120Hz"] && targetHz > 0) return targetHz;
    return %orig;
}

- (CGFloat)nativeScale {
    if ([CFG valueForKey:@"spoofModel"]) return 3.0;
    return %orig;
}
%end

%hook CALayer
- (BOOL)allowsEdgeAntialiasing {
    if ([CFG valueForKey:@"spoofModel"]) return YES;
    return %orig;
}

- (CGFloat)rasterizationScale {
    if ([CFG valueForKey:@"spoofModel"]) return [UIScreen mainScreen].scale;
    return %orig;
}
%end
%end

// ==========================================
// 2. DISABLE THERMAL THROTTLING
// ==========================================

%group ThermalBypass
%hook NSProcessInfo
- (NSProcessInfoThermalState)thermalState {
    if ([CFG valueForKey:@"disableThermal"]) return NSProcessInfoThermalStateNominal;
    return %orig;
}

+ (BOOL)isThermalPressureCritical {
    if ([CFG valueForKey:@"disableThermal"]) return NO;
    return %orig;
}
%end
%end

// ==========================================
// 3. HARDWARE IDENTITY SPOOF
// ==========================================

%group HardwareSpoof
%hookf(int, sysctlbyname, const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
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

    return %orig(name, oldp, oldlenp, newp, newlen);
}
%end

// ==========================================
// 4. INITIALIZATION LOGIC
// ==========================================

%ctor {
    if (IS_ENABLED) {
        if ([CFG valueForKey:@"godModeForce120Hz"] || [CFG valueForKey:@"spoofModel"]) {
            %init(DisplaySpoof);
        }
        
        if ([CFG valueForKey:@"disableThermal"]) {
            %init(ThermalBypass);
        }
        
        if ([CFG valueForKey:@"spoofModel"]) {
            %init(HardwareSpoof);
        }
        
        NSLog(@"[DeviceBypass] ✅ v8.0 Initialized with Dynamic Hz & Safe Spoof.");
    }
}
