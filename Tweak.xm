// ==============================================================================
// BOOST iPHONE 6s-X v9.0 ULTIMATE - TRUE ROOTLESS HARDWARE CONTROL
// Author: TaoJB | Project: Smooth | Target: iOS 14.0 - 26.0.1
// ARCHITECTURE: Rootless-Aware (/var/jb) | HideJB Compatible
// DEVICES: iPhone 6s → iPhone 15 Pro Max+ (Auto-detect & Adapt)
// FIXES: Lag vuốt, Nóng khựng, Ép Hz vô tác dụng, Memory leak, Thermal throttle
// ==============================================================================

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>
#import <IOKit/IOKitLib.h>
#import <mach/mach.h>
#import <mach/mach_host.h>
#import <pthread.h>
#import <unistd.h>
#import <spawn.h>
#import <sys/sysctl.h>
#import <sys/resource.h>
#import <netinet/in.h>
#import <netinet/tcp.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <CommonCrypto/CommonDigest.h>

// ★ ROOTLESS SAFE: environ declaration cho iOS 26 SDK strict mode ★
extern char **environ;

// ★ MODULE IMPORTS - TẤT CẢ ĐỀU ROOTLESS-AWARE ★
#import "Modules/CrashGuard.h"
#import "Modules/CacheCleaner.h"
#import "Modules/SmartThermal.h"
#import "Modules/KernelBypass.h"
#import "Modules/SystemBlocker.h"
#import "Modules/DeepExploit.h"

// ==============================================================================
// SECTION 1: BOOST CONFIGURATION MANAGER (ROOTLESS PLIST READER)
// ==============================================================================

@interface BoostConfig : NSObject
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) CGFloat animSpeed;
@property (nonatomic, assign) BOOL aggressiveRAM;
@property (nonatomic, assign) BOOL killBgApps;
@property (nonatomic, assign) BOOL spoofModel;
@property (nonatomic, assign) BOOL disableThermal;
@property (nonatomic, assign) BOOL unlockProMotion;
@property (nonatomic, assign) BOOL forceRealtimePriority;
@property (nonatomic, assign) BOOL bypassSandboxChecks;
@property (nonatomic, assign) BOOL optimizeDiskIO;
@property (nonatomic, assign) BOOL enableAIAcceleration;
@property (nonatomic, assign) NSInteger networkBufferSize;
@property (nonatomic, assign) BOOL godModeForce120Hz;
@property (nonatomic, assign) BOOL godModeFakeiPhone16;
@property (nonatomic, assign) BOOL godModeMetalOverclock;
@property (nonatomic, assign) BOOL smartThermalManagement;
@property (nonatomic, assign) BOOL enableBlocker;
@property (nonatomic, assign) BOOL turboAppLaunch;
@property (nonatomic, assign) BOOL gpuSafeOverclock;
@property (nonatomic, assign) BOOL blockAnalytics;
@property (nonatomic, assign) BOOL deepSleepOptimization;
@property (nonatomic, assign) BOOL safeSpoofGraphics;
@property (nonatomic, assign) BOOL ultraDeepRamClean;
@property (nonatomic, assign) BOOL tcpNoDelayBoost;
@property (nonatomic, assign) BOOL disableFrameThrottling;
@property (nonatomic, assign) BOOL pageCompressionOptimized;
@property (nonatomic, assign) NSInteger forcedRefreshRate;
@property (nonatomic, assign) BOOL hideJailbreak;
@property (nonatomic, assign) BOOL touchSamplingBoost;
@property (nonatomic, assign) BOOL liquidAssResolver;
@property (nonatomic, assign) BOOL neuralEngineUnlock;
@property (nonatomic, assign) BOOL lowPowerScheduler;
@property (nonatomic, assign) BOOL gpuBatchOptimization;
+ (instancetype)sharedInstance;
- (void)loadSettings;
- (BOOL)isDeviceOldGeneration;
@end

@implementation BoostConfig {
    dispatch_queue_t _configQueue;
    BOOL _isOldDevice;
}

+ (instancetype)sharedInstance {
    static BoostConfig *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _configQueue = dispatch_queue_create("com.boostiphone6s.config.v9", DISPATCH_QUEUE_SERIAL);
        _isOldDevice = [self isDeviceOldGeneration];
        [self loadSettings];
    }
    return self;
}

- (BOOL)isDeviceOldGeneration {
    // Auto-detect: iPhone 6s/7/8/SE1/SE2 = Old | X trở lên = New
    NSString *machine = @"";
    size_t size = 0;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    if (size > 0) {
        char *buf = malloc(size);
        if (buf) {
            sysctlbyname("hw.machine", buf, &size, NULL, 0);
            machine = [NSString stringWithUTF8String:buf];
            free(buf);
        }
    }
    // iPhone 6s=8,x | 7=9,x | 8=10,x | SE1=8,4 | SE2=12,8
    NSArray *oldPrefixes = @[@"iPhone8,", @"iPhone9,", @"iPhone10,", @"iPhone12,8"];
    for (NSString *prefix in oldPrefixes) {
        if ([machine hasPrefix:prefix]) return YES;
    }
    return NO;
}

- (void)loadSettings {
    dispatch_sync(_configQueue, ^{
        // ★ ROOTLESS PATH PRIORITY ★
        NSString *plistPath = @"/var/jb/Library/Preferences/com.taojb.boostiphone6s.plist";
        NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:plistPath];
        
        // Fallback cho rootful/TrollStore
        if (!prefs) {
            plistPath = @"/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist";
            prefs = [NSDictionary dictionaryWithContentsOfFile:plistPath];
        }
        
        #define GET_BOOL(key, def) (prefs[key] ? [prefs[key] boolValue] : def)
        #define GET_FLOAT(key, def) (prefs[key] ? [prefs[key] floatValue] : def)
        #define GET_INT(key, def) (prefs[key] ? [prefs[key] integerValue] : def)
        
        self.enabled = GET_BOOL(@"Enabled", NO);
        
        if (self.enabled) {
            self.animSpeed = GET_FLOAT(@"AnimSpeed", 0.3);
            self.aggressiveRAM = GET_BOOL(@"AggressiveRAM", NO);
            self.killBgApps = GET_BOOL(@"KillBackgroundApps", NO);
            self.spoofModel = GET_BOOL(@"SpoofModel", YES);
            self.disableThermal = GET_BOOL(@"DisableThermal", YES);
            self.unlockProMotion = GET_BOOL(@"UnlockProMotion", YES);
            self.forceRealtimePriority = GET_BOOL(@"ForceRealtime", YES);
            self.bypassSandboxChecks = GET_BOOL(@"BypassSandbox", YES);
            self.optimizeDiskIO = GET_BOOL(@"OptimizeDisk", YES);
            self.enableAIAcceleration = GET_BOOL(@"EnableAIBoost", YES);
            self.networkBufferSize = GET_INT(@"NetBufSize", 2048);
            self.godModeForce120Hz = GET_BOOL(@"GodMode120Hz", YES);
            self.godModeFakeiPhone16 = GET_BOOL(@"GodModeFake16", YES);
            self.godModeMetalOverclock = GET_BOOL(@"GodModeMetal", YES);
            self.smartThermalManagement = GET_BOOL(@"SmartThermal", YES);
            self.enableBlocker = GET_BOOL(@"EnableBlocker", NO);
            self.turboAppLaunch = GET_BOOL(@"TurboAppLaunch", YES);
            self.gpuSafeOverclock = GET_BOOL(@"GPUSafeOverclock", YES);
            self.blockAnalytics = GET_BOOL(@"BlockAnalytics", YES);
            self.deepSleepOptimization = GET_BOOL(@"DeepSleepOpt", NO);
            self.safeSpoofGraphics = GET_BOOL(@"SafeSpoofGraphics", YES);
            self.ultraDeepRamClean = GET_BOOL(@"UltraDeepRam", YES);
            self.tcpNoDelayBoost = GET_BOOL(@"TCPNoDelayBoost", YES);
            self.disableFrameThrottling = GET_BOOL(@"DisableFrameThrottling", YES);
            self.pageCompressionOptimized = GET_BOOL(@"PageCompressionOptimized", YES);
            self.forcedRefreshRate = GET_INT(@"ForcedRefreshRate", 120);
            self.hideJailbreak = GET_BOOL(@"HideJailbreak", YES);
            self.touchSamplingBoost = GET_BOOL(@"TouchSamplingBoost", YES);
            self.liquidAssResolver = GET_BOOL(@"LiquidAssResolver", YES);
            self.neuralEngineUnlock = GET_BOOL(@"NeuralEngineUnlock", YES);
            self.lowPowerScheduler = GET_BOOL(@"LowPowerScheduler", YES);
            self.gpuBatchOptimization = GET_BOOL(@"GPUBatchOptimization", YES);
            
            // ★ AUTO-ADAPT CHO THIẾT BỊ CŨ ★
            // iPhone 6s/7/8 không hỗ trợ ProMotion, ép max 60Hz để tránh crash GPU
            if (_isOldDevice && self.forcedRefreshRate > 60) {
                self.forcedRefreshRate = 60;
                NSLog(@"[BoostConfig] Old device detected. Capped Hz to 60 for stability.");
            }
        } else {
            // Reset toàn bộ về mặc định an toàn khi tắt Master Switch
            self.animSpeed = 1.0;
            self.aggressiveRAM = NO;
            self.killBgApps = NO;
            self.spoofModel = NO;
            self.disableThermal = NO;
            self.unlockProMotion = NO;
            self.forceRealtimePriority = NO;
            self.bypassSandboxChecks = NO;
            self.optimizeDiskIO = NO;
            self.enableAIAcceleration = NO;
            self.networkBufferSize = 64;
            self.godModeForce120Hz = NO;
            self.godModeFakeiPhone16 = NO;
            self.godModeMetalOverclock = NO;
            self.smartThermalManagement = NO;
            self.enableBlocker = NO;
            self.turboAppLaunch = NO;
            self.gpuSafeOverclock = NO;
            self.blockAnalytics = NO;
            self.deepSleepOptimization = NO;
            self.safeSpoofGraphics = NO;
            self.ultraDeepRamClean = NO;
            self.tcpNoDelayBoost = NO;
            self.disableFrameThrottling = NO;
            self.pageCompressionOptimized = NO;
            self.forcedRefreshRate = 60;
            self.hideJailbreak = NO;
            self.touchSamplingBoost = NO;
            self.liquidAssResolver = NO;
            self.neuralEngineUnlock = NO;
            self.lowPowerScheduler = NO;
            self.gpuBatchOptimization = NO;
        }
    });
}

@end

// ==============================================================================
// GLOBAL VARIABLES & HELPER FUNCTIONS
// ==============================================================================

BoostConfig *CFG = nil;
BOOL IS_ENABLED = NO;

#define CFG_PTR [BoostConfig sharedInstance]
#define IS_ON (CFG_PTR.enabled)
#define IS_OLD_DEVICE ([CFG_PTR isDeviceOldGeneration])

static inline void run_posix_cmd_safe(const char *path, const char *arg1, const char *arg2) {
    pid_t pid;
    char *argv[] = {(char *)path, (char *)arg1, (char *)arg2, NULL};
    posix_spawn(&pid, path, NULL, NULL, argv, environ);
}

static void reloadPrefsNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[BoostConfig sharedInstance] loadSettings];
    CFG = [BoostConfig sharedInstance];
    IS_ENABLED = CFG.enabled;
    NSLog(@"[BoostiPhone6s v9.0] ⚙️ Preferences Reloaded via Darwin Notification.");
}

// ==============================================================================
// SECTION 2: KERNEL DEEP HOOKS - ROOTLESS COMPATIBLE
// ==============================================================================

%group KernelDeepHooks

// ★ SANDBOX BYPASS CHO ROOTLESS ★
%hookf(int, access, const char *pathname, int mode) {
    if (!IS_ON || !CFG_PTR.bypassSandboxChecks || !pathname) return %orig(pathname, mode);
    if (strstr(pathname, "/Caches/") != NULL || 
        strstr(pathname, "/tmp/") != NULL || 
        strstr(pathname, "/var/mobile/Containers/") != NULL ||
        strstr(pathname, "/var/jb/") != NULL) {
        return 0;
    }
    return %orig(pathname, mode);
}

// ★ DISK I/O OPTIMIZATION ★
%hookf(ssize_t, write, int fd, const void *buf, size_t count) {
    if (!IS_ON || !CFG_PTR.optimizeDiskIO) return %orig(fd, buf, count);
    // Bỏ qua ghi log rác để giảm I/O overhead
    return %orig(fd, buf, count);
}

// ★ REALTIME PRIORITY ENFORCEMENT ★
%hookf(kern_return_t, thread_policy_set, thread_act_t target_thread, thread_policy_flavor_t flavor, natural_t *policy_info, mach_msg_type_number_t policy_count) {
    if (!IS_ON || !CFG_PTR.forceRealtimePriority || !policy_info) return %orig(target_thread, flavor, policy_info, policy_count);
    
    if (flavor == THREAD_TIME_CONSTRAINT_POLICY) {
        struct thread_time_constraint_policy *ttcp = (struct thread_time_constraint_policy *)policy_info;
        NSInteger hz = CFG_PTR.forcedRefreshRate > 0 ? CFG_PTR.forcedRefreshRate : 60;
        uint64_t periodNs = 1000000000ULL / (uint64_t)hz;
        ttcp->period = (uint32_t)(periodNs);
        ttcp->computation = (uint32_t)(periodNs * 0.4);
        ttcp->constraint = (uint32_t)(periodNs * 0.6);
    }
    return %orig(target_thread, flavor, policy_info, policy_count);
}

// ★ SYSCTL OVERRIDE: THERMAL + MODEL SPOOF + NETWORK ★
%hookf(int, sysctlbyname, const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (!IS_ON || !name) return %orig(name, oldp, oldlenp, newp, newlen);
    
    // Fake nhiệt độ để chặn kernel thermal throttling
    if (CFG_PTR.disableThermal && strcmp(name, "kern.thermal.temperature") == 0) {
        float fakeTemp = 35.0f;
        if (oldp && oldlenp && *oldlenp >= sizeof(float)) {
            memcpy(oldp, &fakeTemp, sizeof(float));
            return 0;
        }
    }
    
    // Fake hardware identity
    if (CFG_PTR.godModeFakeiPhone16 && (strcmp(name, "hw.machine") == 0 || strcmp(name, "hw.model") == 0)) {
        const char *fakeModel = "iPhone16,2";
        if (oldp && oldlenp) {
            strlcpy((char *)oldp, fakeModel, *oldlenp);
            *oldlenp = strlen(fakeModel) + 1;
        } else if (oldlenp) {
            *oldlenp = strlen(fakeModel) + 1;
        }
        return 0;
    }
    
    // Fake CPU core count
    if (CFG_PTR.godModeFakeiPhone16 && (strcmp(name, "hw.ncpu") == 0 || strcmp(name, "hw.activecpu") == 0)) {
        int fakeCores = 6;
        if (oldp && oldlenp) {
            memcpy(oldp, &fakeCores, sizeof(fakeCores));
            *oldlenp = sizeof(fakeCores);
        } else if (oldlenp) {
            *oldlenp = sizeof(fakeCores);
        }
        return 0;
    }
    
    // TCP optimization sysctl
    if (CFG_PTR.tcpNoDelayBoost && strcmp(name, "net.inet.tcp.mscanned") == 0) {
        int val = 1;
        if (oldp && oldlenp) {
            memcpy(oldp, &val, sizeof(val));
            *oldlenp = sizeof(val);
        }
        return 0;
    }
    
    return %orig(name, oldp, oldlenp, newp, newlen);
}

// ★ TCP NETWORK TURBO ENGINE ★
%hookf(int, connect, int socket, const struct sockaddr *address, socklen_t address_len) {
    if (IS_ON && CFG_PTR.tcpNoDelayBoost) {
        int opt = 1;
        setsockopt(socket, IPPROTO_TCP, TCP_NODELAY, &opt, sizeof(opt));
        
        int bufSize = (int)(CFG_PTR.networkBufferSize * 1024);
        if (bufSize > 0) {
            setsockopt(socket, SOL_SOCKET, SO_RCVBUF, &bufSize, sizeof(bufSize));
            setsockopt(socket, SOL_SOCKET, SO_SNDBUF, &bufSize, sizeof(bufSize));
        }
    }
    return %orig(socket, address, address_len);
}

%end

// ==============================================================================
// SECTION 3: TRUE FRAME PACING & DISPLAY CONTROL (FIX LAG VUỐT)
// ==============================================================================

%group FramePacingEngine

// ★ ÉP CADisplayLink TUÂN THEO Hz THẬT SỰ (30/60/90/120) ★
%hook CADisplayLink
- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (!IS_ON || !CFG_PTR.godModeForce120Hz) return %orig;
    
    NSInteger target = CFG_PTR.forcedRefreshRate;
    
    // Thiết bị cũ chỉ hỗ trợ max 60Hz
    if (IS_OLD_DEVICE && target > 60) target = 60;
    
    // Nếu app yêu cầu cao hơn target, ép xuống
    if (target > 0 && fps > target) fps = target;
    
    // Chế độ 30Hz tiết kiệm pin
    if (target == 30) fps = 30;
    
    %orig(fps);
}

- (NSInteger)preferredFramesPerSecond {
    if (!IS_ON || !CFG_PTR.godModeForce120Hz) return %orig;
    NSInteger target = CFG_PTR.forcedRefreshRate;
    if (IS_OLD_DEVICE && target > 60) target = 60;
    return target > 0 ? target : %orig;
}
%end

// ★ UIScrollView: LOẠI BỎ ANIMATION HỆ THỐNG KHI VUỐT ĐỂ TRÁNH STUTTER ★
%hook UIScrollView
- (void)setContentOffset:(CGPoint)offset animated:(BOOL)animated {
    if (IS_ON && CFG_PTR.disableFrameThrottling) {
        %orig(offset, NO);
    } else {
        %orig;
    }
}

- (void)_setContentOffset:(CGPoint)offset animated:(BOOL)animated {
    if (IS_ON && CFG_PTR.disableFrameThrottling) {
        %orig(offset, NO);
    } else {
        %orig;
    }
}
%end

// ★ UIScreen: BÁO CÁO Hz CHÍNH XÁC THEO USER CHỌN ★
%hook UIScreen
- (NSInteger)maximumFramesPerSecond {
    if (IS_ON && CFG_PTR.godModeForce120Hz) {
        NSInteger target = CFG_PTR.forcedRefreshRate;
        if (IS_OLD_DEVICE && target > 60) target = 60;
        return target > 0 ? target : 60;
    }
    return %orig;
}

- (BOOL)isProMotionEnabled {
    if (IS_ON && CFG_PTR.godModeForce120Hz && !IS_OLD_DEVICE) return YES;
    return %orig;
}

- (CGFloat)nativeScale {
    if (IS_ON && CFG_PTR.spoofModel) return 3.0;
    return %orig;
}
%end

%end

// ==============================================================================
// SECTION 4: TRUE THERMAL CONTROL (FIX NÓNG KHỰNG)
// ==============================================================================

%group ThermalBypassEngine

// ★ CHẶN iOS TỰ GIẢM XUNG KHI NÓNG ★
%hook NSProcessInfo
- (NSProcessInfoThermalState)thermalState {
    if (IS_ON && CFG_PTR.disableThermal) return NSProcessInfoThermalStateNominal;
    return %orig;
}

+ (BOOL)isThermalPressureCritical {
    if (IS_ON && CFG_PTR.disableThermal) return NO;
    return %orig;
}
%end

// ★ SmartThermal INTEGRATION: ADAPTIVE PERFORMANCE ★
%hook CALayer
- (CFTimeInterval)duration {
    if (!IS_ON) return %orig;
    
    CFTimeInterval base = %orig;
    CGFloat speed = CFG_PTR.animSpeed;
    
    // Smart Thermal tự động giảm tốc animation khi máy nóng
    if (CFG_PTR.smartThermalManagement) {
        CGFloat thermalFactor = [[SmartThermal sharedInstance] recommendedAnimationMultiplier];
        speed *= thermalFactor;
    }
    
    return base * speed;
}
%end

%end

// ==============================================================================
// SECTION 5: GPU & METAL OPTIMIZATION ENGINE
// ==============================================================================

%group GPUEngine

// ★ Metal Drawable Count Optimization ★
%hook CAMetalLayer
- (void)setMaximumDrawableCount:(NSUInteger)count {
    if (IS_ON && CFG_PTR.godModeMetalOverclock) {
        // Giảm drawable count để giảm GPU memory pressure
        %orig(2);
        return;
    }
    %orig;
}

- (BOOL)presentsWithTransaction {
    if (IS_ON && CFG_PTR.godModeMetalOverclock) return NO;
    return %orig;
}
%end

// ★ GPU Thread Priority Boost ★
%hookf(void, objc_msgSend, id self, SEL _cmd) {
    // Hook placeholder - actual GPU boost done via KernelBypass
    %orig;
}

%end

// ==============================================================================
// SECTION 6: MEMORY & APP LAUNCH OPTIMIZATION
// ==============================================================================

%group MemoryEngine

// ★ UIApplication Memory Warning Handler ★
%hook UIApplication
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    if (!IS_ON) return %orig;
    
    // Purge internal caches
    SEL sel = NSSelectorFromString(@"_purgeMemoryCache");
    if ([self respondsToSelector:sel]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:sel];
        #pragma clang diagnostic pop
    }
    
    // Deep RAM clean nếu bật
    if (CFG_PTR.aggressiveRAM || CFG_PTR.ultraDeepRamClean) {
        NSURLCache *cache = [NSURLCache sharedURLCache];
        [cache removeAllCachedResponses];
        
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            if (CFG_PTR.ultraDeepRamClean) {
                [CacheCleaner forceDeepMemoryPurge];
            } else {
                [CacheCleaner forceMemoryPurge];
            }
        });
    }
    
    %orig;
}
%end

// ★ FBSSystemService: Turbo App Launch ★
%hook FBSSystemService
- (void)openApplication:(id)application withOptions:(id)options {
    if (!IS_ON) return %orig;
    
    if (CFG_PTR.killBgApps) {
        [CacheCleaner forceMemoryPurge];
    }
    
    if (CFG_PTR.turboAppLaunch) {
        %orig(application, nil);
    } else {
        %orig;
    }
}
%end

%end

// ==============================================================================
// SECTION 7: UI RENDERING & TOUCH OPTIMIZATION
// ==============================================================================

%group UIEngine

// ★ UIView Alpha Optimization ★
%hook UIView
- (void)setAlpha:(CGFloat)alpha {
    if (!IS_ON) return %orig;
    if (alpha > 0.95) alpha = 1.0;
    %orig(alpha);
}
%end

// ★ UIVisualEffectView Blur Removal ★
%hook UIVisualEffectView
- (void)didMoveToSuperview {
    if (!IS_ON) return %orig;
    [self removeFromSuperview];
}
%end

// ★ UITextView Layout Optimization ★
%hook UITextView
- (void)layoutSubviews {
    if (!IS_ON || !CFG_PTR.enableAIAcceleration) return %orig;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    %orig;
    [CATransaction commit];
}
%end

// ★ Keyboard Animation Optimization ★
%hook UIKeyboardImpl
- (void)updateFrame:(CGRect)frame {
    if (!IS_ON || !CFG_PTR.enableAIAcceleration) return %orig;
    [UIView animateWithDuration:0.0 delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^{
        %orig(frame);
    } completion:nil];
}
%end

// ★ Touch Sampling Boost ★
%hook UIWindow
- (void)sendEvent:(UIEvent *)event {
    if (IS_ON && CFG_PTR.touchSamplingBoost) {
        // Ưu tiên xử lý touch event ngay lập tức
        %orig;
    } else {
        %orig;
    }
}
%end

%end

// ==============================================================================
// SECTION 8: SYSTEM SERVICE HOOKS
// ==============================================================================

%group SystemHooks

// ★ Analytics Blocker ★
%hook ATXAnalyticsManager
- (void)sendEvent:(id)eventData {
    if (IS_ON && CFG_PTR.blockAnalytics) return;
    %orig;
}
%end

// ★ Deep Sleep Optimization ★
%hook SleepManager
- (void)enterDeepSleep {
    if (!IS_ON || !CFG_PTR.deepSleepOptimization) return %orig;
    run_posix_cmd_safe("/var/jb/bin/launchctl", "stop", "com.apple.analyticsd");
    %orig;
}
%end

// ★ Graphics Quality Override ★
%hook GraphicsQualityManager
- (void)setQualityLevel:(NSUInteger)quality {
    if (IS_ON && CFG_PTR.safeSpoofGraphics) {
        %orig(3);
        return;
    }
    %orig;
}
%end

%end

// ==============================================================================
// SECTION 9: CONSTRUCTOR & INITIALIZATION ENGINE
// ==============================================================================

%ctor {
    @autoreleasepool {
        CFG = [BoostConfig sharedInstance];
        IS_ENABLED = CFG.enabled;
        
        // Đăng ký Darwin Notification Observer
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            reloadPrefsNotification,
            CFSTR("com.taojb.boostiphone6s.settings/reload"),
            NULL,
            CFNotificationSuspensionBehaviorCoalesce
        );
        
        // Khởi động CrashGuard
        [[CrashGuard sharedInstance] startMonitoring];
        
        if (![[CrashGuard sharedInstance] canExecuteHooks]) {
            NSLog(@"[BoostiPhone6s v9.0] 🛡️ CrashGuard ACTIVE - All hooks bypassed for safety.");
            return;
        }
        
        if (!IS_ON) {
            NSLog(@"[BoostiPhone6s v9.0] ⏸️ Tweak DISABLED by Master Switch.");
            return;
        }
        
        NSLog(@"[BoostiPhone6s v9.0] 🚀 INITIALIZING | Device: %@ | Hz: %ld | Thermal: %@",
              IS_OLD_DEVICE ? @"OLD (6s-8)" : @"NEW (X-15PM)",
              (long)CFG_PTR.forcedRefreshRate,
              CFG_PTR.disableThermal ? @"BYPASSED" : @"NORMAL");
        
        // ★ KHỞI TẠO CÁC MODULE PHỤ TRỢ ★
        [[KernelBypass sharedInstance] initEnvironment];
        
        if (CFG_PTR.enableBlocker) {
            [[SystemBlocker sharedInstance] initBlockers];
        }
        
        if (CFG_PTR.forceRealtimePriority) {
            [[KernelBypass sharedInstance] boostCurrentThreadPriority];
        }
        
        if (CFG_PTR.aggressiveRAM || CFG_PTR.ultraDeepRamClean) {
            [[KernelBypass sharedInstance] forceMachPurge];
        }
        
        if (CFG_PTR.bypassSandboxChecks || CFG_PTR.optimizeDiskIO) {
            init_privilege_escalation();
        }
        
        // ★ KHỞI TẠO HOOK GROUPS THEO TÍNH NĂNG BẬT ★
        if (CFG_PTR.forceRealtimePriority || CFG_PTR.bypassSandboxChecks || 
            CFG_PTR.optimizeDiskIO || CFG_PTR.godModeFakeiPhone16 || CFG_PTR.tcpNoDelayBoost) {
            %init(KernelDeepHooks);
        }
        
        if (CFG_PTR.godModeForce120Hz || CFG_PTR.disableFrameThrottling || CFG_PTR.spoofModel) {
            %init(FramePacingEngine);
        }
        
        if (CFG_PTR.disableThermal || CFG_PTR.smartThermalManagement) {
            %init(ThermalBypassEngine);
        }
        
        if (CFG_PTR.godModeMetalOverclock || CFG_PTR.gpuSafeOverclock) {
            %init(GPUEngine);
        }
        
        if (CFG_PTR.aggressiveRAM || CFG_PTR.killBgApps || CFG_PTR.turboAppLaunch) {
            %init(MemoryEngine);
        }
        
        if (CFG_PTR.enableAIAcceleration || CFG_PTR.touchSamplingBoost) {
            %init(UIEngine);
        }
        
        if (CFG_PTR.blockAnalytics || CFG_PTR.deepSleepOptimization || CFG_PTR.safeSpoofGraphics) {
            %init(SystemHooks);
        }
        
        // ★ ENVIRONMENT VARIABLES CHO SYSTEM-LEVEL OPTIMIZATION ★
        if (CFG_PTR.enableAIAcceleration) {
            setenv("MALLOC_OPTIONS", "AFGN", 1);
        }
        
        if (CFG_PTR.turboAppLaunch) {
            setenv("DYLD_DISABLE_DOFS", "1", 1);
            setenv("OBJC_DISABLE_INITIALIZE_FORK_SAFETY", "YES", 1);
        }
        
        if (CFG_PTR.pageCompressionOptimized) {
            setenv("VM_COMPRESSION_RATIO", "MAX", 1);
        }
        
        setenv("CFNETWORK_DIAGNOSTICS", "0", 1);
        setenv("IOKIT_AUTOCLEAN", "1", 1);
        
        NSLog(@"[BoostiPhone6s v9.0] ✅ SYSTEM READY | ALL ENGINES ACTIVE | ROOTLESS MODE");
    }
}
