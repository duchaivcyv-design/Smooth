#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <IOKit/IOKitLib.h>
#import <sys/sysctl.h>
#import <dlfcn.h>
#import <mach/mach.h>

// Sử dụng extern để truy cập biến global đã export từ Tweak.xm
// Lưu ý: CFG là id trong context này nên ta dùng valueForKey hoặc ép kiểu nếu cần
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
    if ([CFG valueForKey:@"godModeForce120Hz"]) return 120;
    return %orig;
}

- (CGFloat)nativeScale {
    // Ép scale 3.0 cho màn hình OLED giả lập độ sắc nét cao
    if ([CFG valueForKey:@"spoofModel"]) return 3.0;
    return %orig;
}
%end

%hook CALayer
- (BOOL)allowsEdgeAntialiasing {
    // Bật antialiasing cạnh để UI trông mượt hơn trên máy cũ
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
// 2. DISABLE THERMAL THROTTLING (FIXED SYNTAX)
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
// 3. HARDWARE IDENTITY SPOOF (SAFE VERSION)
// ==========================================

%group HardwareSpoof
%hookf(int, sysctlbyname, const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (![CFG valueForKey:@"spoofModel"]) return %orig(name, oldp, oldlenp, newp, newlen);
    
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
        
        NSLog(@"[DeviceBypass] Initialized with active spoofing modules.");
    }
}
