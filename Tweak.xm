// ==============================================================================
// 🚀 TWEAK.XM - BOOST IPHONE 6S TO 15 PRO MAX - V20 ULTIMATE EDITION
// 🐍 PHILOSOPHY: PYTHONIC SAFETY - EXPLICIT, CLEAN, CRASH-PROOF, MODULAR.
// 🎯 TARGET: iOS 14.0 -> iOS 18.x (Rootful & Rootless /var/jb/)
// ==============================================================================

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>
#import <IOKit/IOKitLib.h>
#import <mach/mach.h>
#import <mach/mach_host.h>
#import <pthread.h>
#import <pthread/qos.h>
#import <unistd.h>
#import <spawn.h>
#import <sys/sysctl.h>
#import <sys/resource.h>
#import <sys/utsname.h>
#import <sys/wait.h>
#import <netinet/in.h>
#import <netinet/tcp.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <malloc/malloc.h>
#import <CommonCrypto/CommonDigest.h>

extern char **environ;

// Tích hợp Module cốt lõi
#import "Modules/CrashGuard.h"
#import "Modules/CacheCleaner.h"
#import "Modules/SmartThermal.h"
#import "Modules/KernelBypass.h"
#import "Modules/SystemBlocker.h"
#import "Modules/DeepExploit.h"

// ==============================================================================
// 🧱 PHẦN 1: C-FUNCTIONS & HELPERS (FILE SCOPE)
// Kỷ luật: Tất cả hàm C phải ở đây. KHÔNG BAO GIỜ bị lỗi "function definition".
// ==============================================================================

// --- Forward Declarations (Tránh lỗi biên dịch) ---
@interface SBApplication : NSObject
- (NSString *)bundleIdentifier;
@end

@interface SBApplicationController : NSObject
+ (instancetype)sharedInstance;
- (NSArray *)allApplications;
@end

static void PMDebugLog(NSString *format, ...);
static void V20_RunGarbageCollector_Aggressive(void);
static void V20_RunGarbageCollector_Light(void);
static void PMPrepareRuntime(void);
static BOOL PMIsUsableProcess(void);

// --- Biến toàn cục an toàn ---
static dispatch_once_t g_bksTerminate_once;
typedef void (*BKSTerminateFunc)(NSString *, NSInteger, BOOL, NSString *);
static BKSTerminateFunc g_bksTerminate = NULL;

static dispatch_queue_t v20_background_queue = NULL;
static const BOOL PMDiagnosticsEnabled = NO;
static BOOL PMRuntimeReady = NO;
static const void *kPMConfiguredKey = &kPMConfiguredKey;

// --- Hàm thực thi an toàn (POSIX) /var/jb/ ---
static inline void run_posix_cmd_safe(const char *path, const char *arg1, const char *arg2) {
    if (!path) return;
    pid_t pid;
    char *argv[] = {(char *)path, (char *)arg1, (char *)arg2, NULL};
    int result = posix_spawn(&pid, path, NULL, NULL, argv, environ);
    if (result == 0) waitpid(pid, NULL, WNOHANG); // Non-blocking wait
}

static BOOL BoostIsSpringBoard(void) {
    return [[[NSProcessInfo processInfo] processName] isEqualToString:@"SpringBoard"];
}

static void bks_fallback_impl(NSString *bid, NSInteger reason, BOOL report, NSString *desc) {
    if (!bid) return;
    pid_t pid;
    char *argv[] = {(char *)"/var/jb/bin/launchctl", (char *)"kill", (char *)[bid UTF8String], NULL};
    posix_spawn(&pid, "/var/jb/bin/launchctl", NULL, NULL, argv, environ);
}

static void load_bks_terminate(void) {
    dispatch_once(&g_bksTerminate_once, ^{
        void *handle = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);
        if (!handle) handle = dlopen("/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices", RTLD_LAZY);
        if (handle) {
            g_bksTerminate = (BKSTerminateFunc)dlsym(handle, "BKSTerminateApplicationForReasonAndReportWithDescription");
        }
        if (!g_bksTerminate) g_bksTerminate = &bks_fallback_impl;
    });
}

static void PMDebugLog(NSString *format, ...) {
    if (!format || !PMDiagnosticsEnabled) return;
    va_list args; 
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    // NSLog(@"[BoostV20_Pythonic] %@", msg);
}

// Khai báo định nghĩa hàm Runtime để tránh lỗi dòng 839
static void PMPrepareRuntime(void) {
    if (PMRuntimeReady) return;
    PMRuntimeReady = YES;
    PMDebugLog(@"Runtime V20 Initialized Safely");
}

static BOOL PMIsUsableProcess(void) {
    return [[NSProcessInfo processInfo] processName].length > 0;
}

// Giả lập Garbage Collector của Python
static void V20_RunGarbageCollector_Aggressive(void) {
    if (!v20_background_queue) v20_background_queue = dispatch_queue_create("com.boostv20.gc", DISPATCH_QUEUE_SERIAL);
    dispatch_async(v20_background_queue, ^{
        @try {
            [[NSURLCache sharedURLCache] removeAllCachedResponses];
            [CacheCleaner forceDeepMemoryPurge];
            malloc_zone_pressure_relief(NULL, 1024 * 1024 * 50); // Giải phóng 50MB rác
        } @catch(NSException *e) {
            PMDebugLog(@"GC Error: %@", e);
        }
    });
}

static void V20_RunGarbageCollector_Light(void) {
    if (!v20_background_queue) v20_background_queue = dispatch_queue_create("com.boostv20.gc", DISPATCH_QUEUE_SERIAL);
    dispatch_async(v20_background_queue, ^{
        @try {
            [CacheCleaner forceMemoryPurge];
            malloc_zone_pressure_relief(NULL, 1024 * 1024 * 15);
        } @catch(NSException *e) {}
    });
}

static void PMApplySmoothFeel(UIScrollView *sv) {
    if (!sv) return;
    UIPanGestureRecognizer *pan = sv.panGestureRecognizer;
    if (pan) {
        pan.delaysTouchesBegan = NO;
        pan.delaysTouchesEnded = NO;
    }
}

static void PMConfigureScrollView(UIScrollView *sv) {
    if (!sv || !sv.window) return;
    if (objc_getAssociatedObject(sv, kPMConfiguredKey) != nil) return; // Tránh config lặp
    
    objc_setAssociatedObject(sv, kPMConfiguredKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    sv.delaysContentTouches = NO;
    PMApplySmoothFeel(sv);
}

// ==============================================================================
// 🧠 PHẦN 2: CẤU HÌNH HỆ THỐNG V20 (BOOST CONFIG)
// Khai báo đầy đủ các property để tránh lỗi "property not found".
// ==============================================================================

@interface BoostConfig : NSObject
// Cốt lõi
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) BOOL isBetaEnabled; 
// Frame Pacing & Display (30-60-90-120-144)
@property (nonatomic, assign) NSInteger targetHz; 
@property (nonatomic, assign) BOOL forceHardwareHz; 
@property (nonatomic, assign) BOOL popupHzFix;
// Smoothness & Animation (ColorOS)
@property (nonatomic, assign) BOOL colorOsSmoothness;
@property (nonatomic, assign) BOOL fixMultiTaskLag;
@property (nonatomic, assign) BOOL fixAppExitStutter;
@property (nonatomic, assign) CGFloat animSpeed;
@property (nonatomic, assign) BOOL disableFrameThrottling;
// CPU/GPU & RAM
@property (nonatomic, assign) BOOL boostCpuGpu80;
@property (nonatomic, assign) BOOL boostRam70;
@property (nonatomic, assign) BOOL ultraDeepRamClean;
@property (nonatomic, assign) BOOL aggressiveRAM;
@property (nonatomic, assign) BOOL killBgApps;
@property (nonatomic, assign) BOOL turboAppLaunch;
@property (nonatomic, assign) BOOL godModeMetalOverclock;
@property (nonatomic, assign) BOOL gameStutterFix;
// Thermal & Power
@property (nonatomic, assign) BOOL smartThermalManagement;
@property (nonatomic, assign) BOOL deepCoolingLoading;
@property (nonatomic, assign) BOOL coolingWhileCharging;
@property (nonatomic, assign) BOOL disableThermalThrottling;
@property (nonatomic, assign) BOOL maxBatterySaver;
// System & Bypass (Đã thêm đủ các property còn thiếu)
@property (nonatomic, assign) BOOL ios27Scheduler;
@property (nonatomic, assign) BOOL spoofModel16;
@property (nonatomic, assign) BOOL bypassSandboxVar;
@property (nonatomic, assign) BOOL blockAnalytics;
@property (nonatomic, assign) BOOL tcpNoDelayBoost;
@property (nonatomic, assign) BOOL deepSleepOptimization;
@property (nonatomic, assign) BOOL enableBlocker;
@property (nonatomic, assign) BOOL forceRealtimePriority;
@property (nonatomic, assign) BOOL enableAIAcceleration;
@property (nonatomic, assign) NSInteger networkBufferSize;

+ (instancetype)sharedInstance;
- (void)loadSettings;
@end

@implementation BoostConfig {
    dispatch_queue_t _configQueue;
    BOOL _isOldDevice;
}

+ (instancetype)sharedInstance {
    static BoostConfig *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _configQueue = dispatch_queue_create("com.boostv20.config", DISPATCH_QUEUE_SERIAL);
        _isOldDevice = [self checkOldDevice];
        [self loadSettings];
    }
    return self;
}

- (BOOL)checkOldDevice {
    size_t size = 0;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    if (size > 0) {
        char *buf = (char *)malloc(size);
        if (buf) {
            sysctlbyname("hw.machine", buf, &size, NULL, 0);
            NSString *machine = [NSString stringWithUTF8String:buf];
            free(buf);
            NSArray *oldPrefixes = @[@"iPhone8,", @"iPhone9,", @"iPhone10,", @"iPhone12,8"];
            for (NSString *prefix in oldPrefixes) {
                if ([machine hasPrefix:prefix]) return YES;
            }
        }
    }
    return NO;
}

- (void)loadSettings {
    dispatch_sync(_configQueue, ^{
        NSString *plistPath = @"/var/jb/Library/Preferences/com.taojb.boostiphone6s.plist";
        NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:plistPath];
        if (!prefs) {
            plistPath = @"/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist";
            prefs = [NSDictionary dictionaryWithContentsOfFile:plistPath];
        }
        
        #define GET_BOOL(key, def) (prefs[key] ? [prefs[key] boolValue] : def)
        #define GET_INT(key, def) (prefs[key] ? [prefs[key] integerValue] : def)
        #define GET_FLOAT(key, def) (prefs[key] ? [prefs[key] floatValue] : def)
        
        self.enabled = GET_BOOL(@"Enabled", NO);
        
        if (self.enabled) {
            self.targetHz = GET_INT(@"TargetRefreshRate", 60); 
            if (_isOldDevice && self.targetHz > 60) self.targetHz = 60; 
            
            self.forceHardwareHz = GET_BOOL(@"ForceHardwareHz", YES);
            self.popupHzFix = GET_BOOL(@"PopupHzFix", YES);
            self.colorOsSmoothness = GET_BOOL(@"ColorOsSmoothness", YES);
            self.fixMultiTaskLag = GET_BOOL(@"FixMultiTaskLag", YES);
            self.fixAppExitStutter = GET_BOOL(@"FixAppExitStutter", YES);
            self.animSpeed = GET_FLOAT(@"AnimSpeed", 1.0); 
            self.disableFrameThrottling = GET_BOOL(@"DisableFrameThrottling", YES);
            
            self.boostCpuGpu80 = GET_BOOL(@"BoostCpuGpu80", YES);
            self.boostRam70 = GET_BOOL(@"BoostRam70", YES);
            self.ultraDeepRamClean = GET_BOOL(@"UltraDeepRamClean", YES);
            self.aggressiveRAM = GET_BOOL(@"AggressiveRAM", NO);
            self.killBgApps = GET_BOOL(@"KillBgApps", NO);
            self.turboAppLaunch = GET_BOOL(@"TurboAppLaunch", YES);
            self.godModeMetalOverclock = GET_BOOL(@"GodModeMetal", YES);
            self.gameStutterFix = GET_BOOL(@"GameStutterFix", YES);
            
            self.smartThermalManagement = GET_BOOL(@"SmartThermal", YES);
            self.deepCoolingLoading = GET_BOOL(@"DeepCoolingLoading", YES);
            self.coolingWhileCharging = GET_BOOL(@"CoolingWhileCharging", YES);
            self.disableThermalThrottling = GET_BOOL(@"DisableThermalThrottling", YES);
            self.maxBatterySaver = GET_BOOL(@"MaxBatterySaver", NO);
            
            self.ios27Scheduler = GET_BOOL(@"Ios27Scheduler", YES);
            self.spoofModel16 = GET_BOOL(@"SpoofModel16", YES);
            self.bypassSandboxVar = GET_BOOL(@"BypassSandboxVar", YES);
            self.blockAnalytics = GET_BOOL(@"BlockAnalytics", YES);
            self.tcpNoDelayBoost = GET_BOOL(@"TcpNoDelayBoost", YES);
            self.networkBufferSize = GET_INT(@"NetBufSize", 2048);
            self.isBetaEnabled = GET_BOOL(@"EnableBetaFeatures", NO);
            
            // Đọc thêm 4 biến vừa bổ sung để tránh lỗi thiếu property
            self.deepSleepOptimization = GET_BOOL(@"DeepSleepOpt", NO);
            self.enableBlocker = GET_BOOL(@"EnableBlocker", NO);
            self.forceRealtimePriority = GET_BOOL(@"ForceRealtime", YES);
            self.enableAIAcceleration = GET_BOOL(@"EnableAIBoost", YES);
        } else {
            self.targetHz = 60;
            self.animSpeed = 1.0;
            self.forceHardwareHz = NO;
        }
    });
}
@end

BoostConfig *CFG = nil;
#define CFG_PTR [BoostConfig sharedInstance]
#define IS_ON (CFG_PTR.enabled)

static void reloadPrefsNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[BoostConfig sharedInstance] loadSettings];
    CFG = [BoostConfig sharedInstance];
}

// ==============================================================================
// ⚡️ PHẦN 3: HOOKS KERNEL & POSIX (CHẠY NGẦM KHÔNG CẦN CÔNG TẮC Ở MỘT SỐ MỤC)
// ==============================================================================

%hookf(int, access, const char *pathname, int mode) {
    if (!IS_ON || !pathname) return %orig(pathname, mode);
    @try {
        if (CFG_PTR.bypassSandboxVar) {
            if (strstr(pathname, "/var/jb/") || strstr(pathname, "/Library/MobileSubstrate/")) return 0;
        }
    } @catch (NSException *e) {}
    return %orig(pathname, mode);
}

%hookf(kern_return_t, thread_policy_set, thread_act_t target_thread, thread_policy_flavor_t flavor, natural_t *policy_info, mach_msg_type_number_t policy_count) {
    if (!IS_ON) return %orig(target_thread, flavor, policy_info, policy_count);
    @try {
        if ((CFG_PTR.ios27Scheduler || CFG_PTR.boostCpuGpu80 || CFG_PTR.forceRealtimePriority) && flavor == THREAD_TIME_CONSTRAINT_POLICY) {
            struct thread_time_constraint_policy *ttcp = (struct thread_time_constraint_policy *)policy_info;
            NSInteger hz = CFG_PTR.targetHz > 0 ? CFG_PTR.targetHz : 60;
            uint64_t periodNs = 1000000000ULL / (uint64_t)hz;
            ttcp->period = (uint32_t)(periodNs);
            ttcp->computation = (uint32_t)(periodNs * 0.45); 
            ttcp->constraint = (uint32_t)(periodNs * 0.55);
        }
    } @catch (NSException *e) {}
    return %orig(target_thread, flavor, policy_info, policy_count);
}

%hookf(int, sysctlbyname, const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (!IS_ON || !name) return %orig(name, oldp, oldlenp, newp, newlen);
    
    if ((CFG_PTR.disableThermalThrottling || CFG_PTR.coolingWhileCharging) && strcmp(name, "kern.thermal.temperature") == 0) {
        float fakeTemp = 32.0f;
        if (oldp && oldlenp && *oldlenp >= sizeof(float)) {
            memcpy(oldp, &fakeTemp, sizeof(float));
            *oldlenp = sizeof(float);
            return 0;
        }
    }
    
    if (CFG_PTR.spoofModel16) {
        if (strcmp(name, "hw.machine") == 0 || strcmp(name, "hw.model") == 0) {
            const char *fakeModel = "iPhone16,2";
            if (oldp && oldlenp) {
                strlcpy((char *)oldp, fakeModel, *oldlenp);
                *oldlenp = strlen(fakeModel) + 1;
            }
            return 0;
        }
        if (strcmp(name, "hw.ncpu") == 0 || strcmp(name, "hw.activecpu") == 0) {
            int fakeCores = 6;
            if (oldp && oldlenp) {
                memcpy(oldp, &fakeCores, sizeof(fakeCores));
                *oldlenp = sizeof(fakeCores);
            }
            return 0;
        }
    }
    
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

%hookf(int, uname, struct utsname *name) {
    int ret = %orig(name);
    if (ret == 0 && IS_ON && CFG_PTR.spoofModel16 && name) {
        strlcpy(name->machine, "iPhone16,2", sizeof(name->machine));
    }
    return ret;
}

%hookf(int, connect, int socket, const struct sockaddr *address, socklen_t address_len) {
    if (IS_ON && CFG_PTR.tcpNoDelayBoost) {
        int nodelay = 1;
        setsockopt(socket, IPPROTO_TCP, TCP_NODELAY, &nodelay, sizeof(nodelay));
        int bufSize = (int)(CFG_PTR.networkBufferSize * 1024);
        if (bufSize > 0) {
            setsockopt(socket, SOL_SOCKET, SO_RCVBUF, &bufSize, sizeof(bufSize));
            setsockopt(socket, SOL_SOCKET, SO_SNDBUF, &bufSize, sizeof(bufSize));
        }
    }
    return %orig(socket, address, address_len);
}


// ==============================================================================
// 🖥 PHẦN 4: GROUP_DISPLAY_HZ_FIX (SỬA LỖI HZ)
// ==============================================================================
%group Group_Display_Hz_Fix

%hook CADisplayLink
- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    @autoreleasepool {
        if (!IS_ON || (!CFG_PTR.forceHardwareHz && !CFG_PTR.popupHzFix)) {
            %orig(fps);
            return;
        }
        %orig(CFG_PTR.targetHz);
    }
}

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    @autoreleasepool {
        if (!IS_ON || (!CFG_PTR.forceHardwareHz && !CFG_PTR.popupHzFix)) {
            %orig(range);
            return;
        }
        @try {
            float target = (float)CFG_PTR.targetHz;
            CAFrameRateRange newRange = CAFrameRateRangeMake(target, target, target);
            %orig(newRange);
        } @catch(NSException *e) {
            %orig(range);
        }
    }
}
%end

%hook UIScreen
- (NSInteger)maximumFramesPerSecond {
    if (IS_ON && (CFG_PTR.forceHardwareHz || CFG_PTR.popupHzFix)) {
        return CFG_PTR.targetHz;
    }
    return %orig;
}
%end

%end // Group_Display_Hz_Fix


// ==============================================================================
// 🎨 PHẦN 5: GROUP_UI_COLOROS_CURVE (ĐỘ MƯỢT GIAO DIỆN)
// ==============================================================================
%group Group_UI_ColorOS_Curve

%hook UIScrollView
- (void)setDecelerationRate:(CGFloat)rate {
    @autoreleasepool {
        if (IS_ON && CFG_PTR.colorOsSmoothness) {
            %orig(UIScrollViewDecelerationRateFast);
        } else {
            %orig(rate);
        }
    }
}

- (void)didMoveToWindow {
    %orig;
    @autoreleasepool {
        if (IS_ON && CFG_PTR.colorOsSmoothness && self.window != nil) {
            PMConfigureScrollView(self);
        }
    }
}
%end

%hook CAMediaTimingFunction
+ (instancetype)functionWithName:(CAMediaTimingFunctionName)name {
    @autoreleasepool {
        if (IS_ON && CFG_PTR.colorOsSmoothness) {
            if ([name isEqualToString:kCAMediaTimingFunctionDefault] || 
                [name isEqualToString:kCAMediaTimingFunctionEaseInEaseOut]) {
                return %orig(kCAMediaTimingFunctionEaseOut);
            }
        }
        return %orig(name);
    }
}
%end

%hook CALayer
- (CFTimeInterval)duration {
    if (!IS_ON) return %orig;
    @autoreleasepool {
        return %orig * CFG_PTR.animSpeed;
    }
}
%end

%end // Group_UI_ColorOS_Curve


// ==============================================================================
// 🚀 PHẦN 6: GROUP_SPRINGBOARD_ANTILAG (ĐA NHIỆM)
// ==============================================================================
%group Group_SpringBoard_AntiLag

%hook SBFluidSwitcherViewController
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    %orig(scrollView);
    @autoreleasepool {
        if (IS_ON && CFG_PTR.fixMultiTaskLag) {
            scrollView.layer.shadowOpacity = 0.0;
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig(animated);
    if (IS_ON && CFG_PTR.fixAppExitStutter) {
        V20_RunGarbageCollector_Aggressive(); 
    }
}
%end

%hook SBIconController
- (void)iconTapped:(id)icon {
    if (IS_ON && CFG_PTR.fixAppExitStutter) {
        [[KernelBypass sharedInstance] boostCurrentThreadPriority];
    }
    %orig(icon);
}
%end

%end // Group_SpringBoard_AntiLag


// ==============================================================================
// 🧹 PHẦN 7: GROUP_MEMORY_ENGINE (RAM)
// ==============================================================================
%group Group_Memory_Engine

%hook UIApplication
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    %orig(application);
    @autoreleasepool {
        if (IS_ON) {
            V20_RunGarbageCollector_Light();
        }
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    %orig(application);
    @autoreleasepool {
        if (IS_ON && (CFG_PTR.boostRam70 || CFG_PTR.aggressiveRAM || CFG_PTR.ultraDeepRamClean)) {
            V20_RunGarbageCollector_Aggressive();
        }
    }
}
%end

%hook FBSSystemService
- (void)openApplication:(id)application withOptions:(NSDictionary *)options {
    @autoreleasepool {
        if (!IS_ON) { 
            %orig(application, options); 
            return; 
        }
        
        if (CFG_PTR.killBgApps && BoostIsSpringBoard()) {
            @try {
                load_bks_terminate();
                if (g_bksTerminate != NULL && [application respondsToSelector:@selector(bundleIdentifier)]) {
                    NSString *openingBid = [application performSelector:@selector(bundleIdentifier)];
                    Class sac = objc_getClass("SBApplicationController");
                    if (sac) {
                        id controller = [sac performSelector:@selector(sharedInstance)];
                        NSArray *apps = [controller performSelector:@selector(allApplications)];
                        for (id app in apps) {
                            NSString *bid = [app performSelector:@selector(bundleIdentifier)];
                            if (bid && ![bid isEqualToString:openingBid] && ![bid hasPrefix:@"com.apple."]) {
                                g_bksTerminate(bid, 5, NO, @"V20 Kill Background");
                            }
                        }
                    }
                }
            } @catch (NSException *e) {}
        }

        NSDictionary *finalOptions = (CFG_PTR.turboAppLaunch) ? nil : options;
        %orig(application, finalOptions);
    }
}
%end

%end // Group_Memory_Engine


// ==============================================================================
// 🎮 PHẦN 8: GROUP_SYSTEM_METAL_ENGINE (HỆ THỐNG & NHIỆT ĐỘ)
// ==============================================================================
%group Group_System_Metal_Engine

%hook CAMetalLayer
- (void)setMaximumDrawableCount:(NSUInteger)count {
    @autoreleasepool {
        if (IS_ON && CFG_PTR.godModeMetalOverclock) {
            NSUInteger optimalCount = CFG_PTR.gameStutterFix ? 3 : 2; 
            %orig(optimalCount);
            return;
        }
        %orig(count);
    }
}

- (void)setFramebufferOnly:(BOOL)flag {
    @autoreleasepool {
        if (IS_ON && CFG_PTR.godModeMetalOverclock) {
            %orig(NO); 
            return;
        }
        %orig(flag);
    }
}
%end

%hook NSProcessInfo
- (NSProcessInfoThermalState)thermalState {
    if (IS_ON && (CFG_PTR.disableThermalThrottling || CFG_PTR.deepCoolingLoading)) {
        return NSProcessInfoThermalStateNominal;
    }
    return %orig;
}

+ (BOOL)isThermalPressureCritical {
    if (IS_ON && CFG_PTR.disableThermalThrottling) return NO;
    return %orig;
}
%end

%hook ATXAnalyticsManager
- (void)sendEvent:(id)eventData {
    if (IS_ON && CFG_PTR.blockAnalytics) return; 
    %orig(eventData);
}
%end

%hook SleepManager
- (void)enterDeepSleep {
    if (IS_ON && CFG_PTR.deepSleepOptimization) {
        run_posix_cmd_safe("/var/jb/bin/launchctl", "stop", "com.apple.analyticsd");
    }
    %orig;
}
%end

%hook GraphicsQualityManager
- (void)setQualityLevel:(NSUInteger)quality {
    if (IS_ON && CFG_PTR.boostCpuGpu80) {
        %orig(3);
        return;
    }
    %orig(quality);
}
%end

%end // Group_System_Metal_Engine


// ==============================================================================
// ⚙️ PHẦN 9: CONSTRUCTOR (BỘ KHỞI ĐỘNG V20)
// Gọi PMPrepareRuntime để đánh thức hệ thống!
// ==============================================================================

%ctor {
    @autoreleasepool {
        [[CrashGuard sharedInstance] startMonitoring];
        if (![[CrashGuard sharedInstance] canExecuteHooks]) {
            NSLog(@"[BoostV20] 🔴 SAFE MODE TRIGGERED. INJECTION ABORTED.");
            return;
        }

        CFG = [BoostConfig sharedInstance];
        
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            reloadPrefsNotification,
            CFSTR("com.taojb.boostiphone6s.settings/reload"),
            NULL,
            CFNotificationSuspensionBehaviorCoalesce
        );
        
        if (!IS_ON) return; 

        @try {
            [[KernelBypass sharedInstance] initEnvironment];
            if (CFG_PTR.enableBlocker) [[SystemBlocker sharedInstance] initBlockers];
            if (CFG_PTR.forceRealtimePriority) [[KernelBypass sharedInstance] boostCurrentThreadPriority];
            if (CFG_PTR.ultraDeepRamClean) [[KernelBypass sharedInstance] forceMachPurge];
            if (CFG_PTR.bypassSandboxVar) init_privilege_escalation();
        } @catch (NSException *e) {}
        
        if (CFG_PTR.enableAIAcceleration) setenv("MALLOC_OPTIONS", "AFGN", 1);
        if (CFG_PTR.turboAppLaunch) {
            setenv("DYLD_DISABLE_DOFS", "1", 1);
            setenv("OBJC_DISABLE_INITIALIZE_FORK_SAFETY", "YES", 1);
        }
        if (CFG_PTR.tcpNoDelayBoost) setenv("CFNETWORK_DIAGNOSTICS", "0", 1);
        
        %init(_ungrouped); 
        
        if (CFG_PTR.forceHardwareHz || CFG_PTR.popupHzFix) {
            %init(Group_Display_Hz_Fix);
        }
        
        if (CFG_PTR.colorOsSmoothness || CFG_PTR.fixAppExitStutter) {
            %init(Group_UI_ColorOS_Curve);
            if (BoostIsSpringBoard()) {
                %init(Group_SpringBoard_AntiLag);
            }
        }
        
        if (CFG_PTR.boostRam70 || CFG_PTR.killBgApps || CFG_PTR.aggressiveRAM) {
            %init(Group_Memory_Engine);
        }
        
        %init(Group_System_Metal_Engine); 
        
        PMPrepareRuntime(); // Gọi hàm khởi động Engine
        if (!PMIsUsableProcess()) PMRuntimeReady = NO;
        
        NSLog(@"[BoostV20] 🟢 HOÀN THÀNH INJECTION. KHỞI ĐỘNG V20 ULTIMATE ENGINE.");
    }
}
