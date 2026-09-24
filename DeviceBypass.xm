// ==============================================================================
// DEVICE BYPASS MODULE v7.0 - SAFE SPOOFING ENGINE
// Target: iOS 14.0 - 26.0.1 | iPhone 6s to Latest
// Features: ProMotion Force, Thermal Bypass, Hardware Identity Spoof
// ==============================================================================

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <IOKit/IOKitLib.h>
#import <sys/sysctl.h>
#import <dlfcn.h>
#import <mach/mach.h>

// ★ FIX: IMPORT TRỰC TIẾP CONFIG THAY VÌ DÙNG EXTERN GLOBAL ★
// Giả định Tweak.xm đã expose macro CFG hoặc BoostConfig class
// Nếu tách biệt hoàn toàn, hãy copy interface BoostConfig vào header riêng
#import "../Tweak.xm" 

#define IS_BYPASS_ACTIVE (CFG.enabled && (CFG.spoofModel || CFG.godModeForce120Hz || CFG.disableThermal))

// ==========================================
// 1. FAKE HARDWARE CAPABILITIES (GPU & DISPLAY)
// ==========================================

%group DisplaySpoof
%hook UIScreen
- (BOOL)isProMotionEnabled {
    if (CFG.godModeForce120Hz) return YES;
    return %orig;
}

- (NSInteger)maximumFramesPerSecond {
    if (CFG.godModeForce120Hz) return 120;
    return %orig;
}

- (CGFloat)nativeScale {
    // Ép scale 3.0 cho màn hình OLED giả lập độ sắc nét cao
    if (CFG.spoofModel) return 3.0;
    return %orig;
}
%end

%hook CALayer
- (BOOL)allowsEdgeAntialiasing {
    // Bật antialiasing cạnh để UI trông mượt hơn trên máy cũ
    if (CFG.spoofModel) return YES;
    return %orig;
}

- (CGFloat)rasterizationScale {
    if (CFG.spoofModel) return [UIScreen mainScreen].scale;
    return %orig;
}
%end
%end

// ==========================================
// 2. DISABLE THERMAL THROTTLING (FIXED SYNTAX)
// ==========================================

%group ThermalBypass
%hook NSProcessInfo
- (NSProcessInfoThermalState)thermalState {
    if (CFG.disableThermal) return NSProcessInfoThermalStateNominal;
    return %orig;
}

+ (BOOL)isThermalPressureCritical {
    if (CFG.disableThermal) return NO;
    return %orig;
}
%end
%end

// ==========================================
// 3. HARDWARE IDENTITY SPOOF (SAFE VERSION)
// ==========================================

%group HardwareSpoof
%hookf(int, sysctlbyname, const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (!CFG.spoofModel) return %orig(name, oldp, oldlenp, newp, newlen);
    
    // Fake Machine Model (iPhone 17,2 = iPhone 16 Pro Max)
    if ((strcmp(name, "hw.machine") == 0) || (strcmp(name, "hw.model") == 0)) {
        const char *fakeModel = "iPhone17,2";
        if (oldp && oldlenp) {
            strlcpy((char *)oldp, fakeModel, *oldlenp);
            *oldlenp = strlen(fakeModel) + 1;
        } else if (oldlenp) {
            *oldlenp = strlen(fakeModel) + 1;
        }
        return 0;
    }
    
    // Fake CPU Cores (6 cores = A18 Pro spec)
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
// 4. INITIALIZATION LOGIC (CONDITIONAL GROUPS)
// ==========================================

%ctor {
    // Chỉ init nhóm hook khi config tương ứng được bật
    // Tránh hook thừa gây overhead hoặc crash trên iOS lạ
    
    if (CFG.enabled) {
        if (CFG.godModeForce120Hz || CFG.spoofModel) {
            %init(DisplaySpoof);
        }
        
        if (CFG.disableThermal) {
            %init(ThermalBypass);
        }
        
        if (CFG.spoofModel) {
            %init(HardwareSpoof);
        }
        
        NSLog(@"[DeviceBypass] ✅ Initialized with active spoofing modules.");
    }
}
