#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>
#import <IOKit/IOKitLib.h>
#import <mach/mach.h>
#import <mach/mach_host.h>
#import <mach/vm_map.h>
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

// Tích hợp các Module phụ trợ
#import "Modules/CrashGuard.h"
#import "Modules/CacheCleaner.h"
#import "Modules/SmartThermal.h"
#import "Modules/KernelBypass.h"
#import "Modules/SystemBlocker.h"
#import "Modules/DeepExploit.h"

#ifndef CAFrameRateRangeDefault
typedef struct {
    float minimum;
    float maximum;
    float preferred;
} CAFrameRateRange;

static inline CAFrameRateRange CAFrameRateRangeMake(float minimum, float maximum, float preferred) {
    CAFrameRateRange range;
    range.minimum = minimum;
    range.maximum = maximum;
    range.preferred = preferred;
    return range;
}
#endif

// --- Forward Declarations ---
@interface SBApplication : NSObject
- (NSString *)bundleIdentifier;
@end

@interface SBApplicationController : NSObject
+ (instancetype)sharedInstance;
- (NSArray *)allApplications;
@end

static void V21_RunGarbageCollector_Aggressive(void);
static void V21_RunGarbageCollector_Light(void);
static void PMPrepareRuntime(void);
static BOOL PMIsUsableProcess(void);

static dispatch_once_t g_bksTerminate_once;
typedef void (*BKSTerminateFunc)(NSString *, NSInteger, BOOL, NSString *);
static BKSTerminateFunc g_bksTerminate = NULL;

static dispatch_queue_t v21_background_queue = NULL;
static BOOL PMRuntimeReady = NO;
static const void *kPMConfiguredKey = &kPMConfiguredKey;

static inline void run_posix_cmd_safe(const char *path, const char *arg1, const char *arg2) {
    if (!path) return;
    pid_t pid;
    char *argv[] = {(char *)path, (char *)arg1, (char *)arg2, NULL};
    int result = posix_spawn(&pid, path, NULL, NULL, argv, environ);
    if (result == 0) waitpid(pid, NULL, WNOHANG);
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

static void PMPrepareRuntime(void) {
    if (PMRuntimeReady) return;
    PMRuntimeReady = YES;
}

static BOOL PMIsUsableProcess(void) {
    return [[NSProcessInfo processInfo] processName].length > 0;
}

// Xử lý dọn RAM và Framebuffer ngầm theo phong cách Garbage Collector
static void V21_RunGarbageCollector_Aggressive(void) {
    if (!v21_background_queue) v21_background_queue = dispatch_queue_create("com.boostv21.gc", DISPATCH_QUEUE_SERIAL);
    dispatch_async(v21_background_queue, ^{
        @try {
            [[NSURLCache sharedURLCache] removeAllCachedResponses];
            [CacheCleaner forceDeepMemoryPurge];
            malloc_zone_pressure_relief(NULL, 1024 * 1024 * 64);
            
            mach_port_t host_port = mach_host_self();
            mach_msg_type_number_t host_size = sizeof(vm_statistics64_data_t) / sizeof(integer_t);
            vm_statistics64_data_t vm_stat;
            host_statistics64(host_port, HOST_VM_INFO64, (host_info64_t)&vm_stat, &host_size);
        } @catch(NSException *e) {}
    });
}

static void V21_RunGarbageCollector_Light(void) {
    if (!v21_background_queue) v21_background_queue = dispatch_queue_create("com.boostv21.gc", DISPATCH_QUEUE_SERIAL);
    dispatch_async(v21_background_queue, ^{
        @try {
            [CacheCleaner forceMemoryPurge];
            malloc_zone_pressure_relief(NULL, 1024 * 1024 * 20);
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
    if (objc_getAssociatedObject(sv, kPMConfiguredKey) != nil) return;
    objc_setAssociatedObject(sv, kPMConfiguredKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    sv.delaysContentTouches = NO;
    PMApplySmoothFeel(sv);
}

// ==============================================================================
// 🧠 PHẦN 2: CẤU HÌNH HỆ THỐNG V21 (GỘP CHUNG VÀ TỐI ƯU CÔNG TẮC)
// ==============================================================================

@interface BoostConfig : NSObject
@property (nonatomic, assign) BOOL enabled;

// Nhóm 1: Điều phối Frame rate & Tần số quét (30 - 60 - 90 - 120 - 144)
@property (nonatomic, assign) NSInteger targetHz; 

// Nhóm 2: Tối ưu cảm ứng & Độ mượt chuyển cảnh (ColorOS Curve)
@property (nonatomic, assign) BOOL colorOsSmoothness;
@property (nonatomic, assign) CGFloat animSpeed;

// Nhóm 3: Sửa lỗi khựng đa nhiệm & thoát app nặng
@property (nonatomic, assign) BOOL fixMultiTaskAndExitLag;
@property (nonatomic, assign) BOOL turboAppLaunch;
@property (nonatomic, assign) BOOL killBgApps;

// Nhóm 4: Phần cứng, Đồ họa Metal & Điều tiết nhiệt
@property (nonatomic, assign) BOOL godModeMetal;
@property (nonatomic, assign) BOOL smartThermalCharging;
@property (nonatomic, assign) BOOL bypassSandboxVar;
@property (nonatomic, assign) BOOL blockAnalytics;
@property (nonatomic, assign) BOOL tcpNoDelayBoost;

+ (instancetype)sharedInstance;
- (void)loadSettings;
@end

@implementation BoostConfig {
    dispatch_queue_t _configQueue;
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
        _configQueue = dispatch_queue_create("com.boostv21.config", DISPATCH_QUEUE_SERIAL);
        [self loadSettings];
    }
    return self;
}

- (void)loadSettings {
    dispatch_sync(_configQueue, ^{
        NSString *plistPath = @"/var/jb/var/mobile/Library/Preferences/com.duchaivcy.boostiphone6s.plist";
        NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:plistPath];
        if (!prefs) {
            plistPath = @"/var/mobile/Library/Preferences/com.duchaivcy.boostiphone6s.plist";
            prefs = [NSDictionary dictionaryWithContentsOfFile:plistPath];
        }
        
        #define GET_BOOL(key, def) (prefs[key] ? [prefs[key] boolValue] : def)
        #define GET_INT(key, def) (prefs[key] ? [prefs[key] integerValue] : def)
        #define GET_FLOAT(key, def) (prefs[key] ? [prefs[key] floatValue] : def)
        
        self.enabled = GET_BOOL(@"Enabled", YES);
        
        if (self.enabled) {
            // Đọc tần số quét (mặc định 60, hỗ trợ 30, 60, 90, 120, 144)
            self.targetHz = GET_INT(@"TargetRefreshRate", 60);
            if (self.targetHz <= 0) self.targetHz = 60;
            
            // Gộp các nhóm tính năng mượt mà và chuyển cảnh
            self.colorOsSmoothness = GET_BOOL(@"ColorOsSmoothness", YES);
            self.animSpeed = GET_FLOAT(@"AnimSpeed", 0.82); 
            
            // Khắc phục triệt để khựng đa nhiệm và thoát ứng dụng nặng
            self.fixMultiTaskAndExitLag = GET_BOOL(@"FixMultiTaskAndExitLag", YES);
            self.turboAppLaunch = GET_BOOL(@"TurboAppLaunch", YES);
            self.killBgApps = GET_BOOL(@"KillBgApps", NO);
            
            // Đồ họa Metal và kiểm soát nhiệt
            self.godModeMetal = GET_BOOL(@"GodModeMetal", YES);
            self.smartThermalCharging = GET_BOOL(@"SmartThermalCharging", YES);
            
            // Tối ưu mạng và hệ thống ngầm
            self.bypassSandboxVar = GET_BOOL(@"BypassSandboxVar", YES);
            self.blockAnalytics = GET_BOOL(@"BlockAnalytics", YES);
            self.tcpNoDelayBoost = GET_BOOL(@"TcpNoDelayBoost", YES);
        } else {
            self.targetHz = 60;
            self.animSpeed = 1.0;
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
// ⚡️ PHẦN 3: CAN THIỆP KERNEL, TIẾN TRÌNH & ĐIỀU PHỐI THỜI GIAN THỰC (QOS)
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
        if (flavor == THREAD_TIME_CONSTRAINT_POLICY) {
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
    
    // Giảm nhiệt giả lập để ngăn hệ điều hành bóp xung nhịp đột ngột
    if (CFG_PTR.smartThermalCharging && strcmp(name, "kern.thermal.temperature") == 0) {
        float fakeTemp = 31.5f;
        if (oldp && oldlenp && *oldlenp >= sizeof(float)) {
            memcpy(oldp, &fakeTemp, sizeof(float));
            *oldlenp = sizeof(float);
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

%hookf(int, connect, int socket, const struct sockaddr *address, socklen_t address_len) {
    if (IS_ON && CFG_PTR.tcpNoDelayBoost) {
        int nodelay = 1;
        setsockopt(socket, IPPROTO_TCP, TCP_NODELAY, &nodelay, sizeof(nodelay));
        int bufSize = 2048 * 1024;
        setsockopt(socket, SOL_SOCKET, SO_RCVBUF, &bufSize, sizeof(bufSize));
        setsockopt(socket, SOL_SOCKET, SO_SNDBUF, &bufSize, sizeof(bufSize));
    }
    return %orig(socket, address, address_len);
}

// ==============================================================================
// 🖥 PHẦN 4: KHÓA CHUẨN XÁC TẦN SỐ QUÉT HZ/FPS (FIX 30-60-90-120-144 HZ)
// ==============================================================================
%group Group_Display_Hz_Fix

%hook CADisplayLink
- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (IS_ON && CFG_PTR.targetHz > 0) {
        %orig(CFG_PTR.targetHz);
    } else {
        %orig(fps);
    }
}

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    if (IS_ON && CFG_PTR.targetHz > 0) {
        float target = (float)CFG_PTR.targetHz;
        // Khóa chặt dải ProMotion: Min, Max và Preferred đều nhận chung một giá trị
        CAFrameRateRange forcedRange = CAFrameRateRangeMake(target, target, target);
        %orig(forcedRange);
    } else {
        %orig(range);
    }
}

- (void)setFrameInterval:(NSInteger)interval {
    if (IS_ON && CFG_PTR.targetHz == 30) {
        // Khi chọn 30Hz, kéo giãn chu kỳ khung hình gấp đôi để hạ tải triệt để
        %orig(2);
    } else {
        %orig(1);
    }
}
%end

%hook UIScreen
- (NSInteger)maximumFramesPerSecond {
    if (IS_ON && CFG_PTR.targetHz > 0) {
        return CFG_PTR.targetHz;
    }
    return %orig;
}

- (NSInteger)_maximumFramesPerSecond {
    if (IS_ON && CFG_PTR.targetHz > 0) {
        return CFG_PTR.targetHz;
    }
    return %orig;
}

- (void)_setTargetRefreshRate:(CGFloat)rate {
    if (IS_ON && CFG_PTR.targetHz > 0) {
        %orig((CGFloat)CFG_PTR.targetHz);
    } else {
        %orig(rate);
    }
}
%end

%end // Group_Display_Hz_Fix

// ==============================================================================
// 🎨 PHẦN 5: ĐỘ MƯỢT TỪNG CHUYỂN CẢNH & PHẢN HỒI CẢM ỨNG (COLOROS CURVE)
// ==============================================================================
%group Group_UI_ColorOS_Curve

%hook UIWindow
- (void)sendEvent:(UIEvent *)event {
    if (IS_ON && CFG_PTR.colorOsSmoothness) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(event);
}
%end

%hook UIScrollView
- (void)setDecelerationRate:(CGFloat)rate {
    if (IS_ON && CFG_PTR.colorOsSmoothness) {
        %orig(UIScrollViewDecelerationRateFast);
    } else {
        %orig(rate);
    }
}

- (void)didMoveToWindow {
    %orig;
    if (IS_ON && CFG_PTR.colorOsSmoothness && self.window != nil) {
        PMConfigureScrollView(self);
    }
}
%end

%hook CAMediaTimingFunction
+ (instancetype)functionWithName:(CAMediaTimingFunctionName)name {
    if (IS_ON && CFG_PTR.colorOsSmoothness) {
        if ([name isEqualToString:kCAMediaTimingFunctionDefault] || 
            [name isEqualToString:kCAMediaTimingFunctionEaseInEaseOut]) {
            return %orig(kCAMediaTimingFunctionEaseOut);
        }
    }
    return %orig(name);
}
%end

%hook CALayer
- (CFTimeInterval)duration {
    if (!IS_ON) return %orig;
    return %orig * CFG_PTR.animSpeed;
}

- (void)setNeedsDisplay {
    %orig;
    if (IS_ON && CFG_PTR.colorOsSmoothness) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
}
%end

%hook UIView
+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations {
    if (IS_ON && CFG_PTR.colorOsSmoothness) {
        %orig(duration * 0.82, animations);
    } else {
        %orig(duration, animations);
    }
}
%end

%end // Group_UI_ColorOS_Curve

// ==============================================================================
// 🚀 PHẦN 6: FIX TRIỆT ĐỂ KHỰNG ĐA NHIỆM & VUỐT THOÁT ỨNG DỤNG NẶNG
// ==============================================================================
%group Group_SpringBoard_AntiLag

%hook SBAppSwitcherController
- (void)viewWillAppear:(BOOL)animated {
    if (IS_ON && CFG_PTR.fixMultiTaskAndExitLag) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        [UIView setAnimationDuration:0.16];
        [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
    }
    %orig(animated);
}

- (void)viewWillDisappear:(BOOL)animated {
    if (IS_ON && CFG_PTR.fixMultiTaskAndExitLag) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        V21_RunGarbageCollector_Aggressive();
    }
    %orig(animated);
}
%end

%hook SBFluidSwitcherViewController
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    %orig(scrollView);
    if (IS_ON && CFG_PTR.fixMultiTaskAndExitLag) {
        scrollView.layer.shadowOpacity = 0.0;
    }
}

- (void)handleFluidSwitcherGesture:(id)gesture {
    if (IS_ON && CFG_PTR.fixMultiTaskAndExitLag) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(gesture);
}
%end

// Xả bộ đệm đồ họa ngay khi thoát app nặng ra màn hình chính
%hook SBApplication
- (void)processDidExit:(id)process {
    %orig(process);
    if (IS_ON && CFG_PTR.fixMultiTaskAndExitLag) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            [CATransaction commit];
            V21_RunGarbageCollector_Aggressive();
        });
    }
}
%end

%hook SBIconController
- (void)iconTapped:(id)icon {
    if (IS_ON && CFG_PTR.fixMultiTaskAndExitLag) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(icon);
}
%end

%end // Group_SpringBoard_AntiLag

// ==============================================================================
// 🧹 PHẦN 7: ĐIỀU TIẾT RAM & KHỞI CHẠY APP
// ==============================================================================
%group Group_Memory_Engine

%hook UIApplication
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    %orig(application);
    if (IS_ON) {
        V21_RunGarbageCollector_Light();
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    %orig(application);
    if (IS_ON) {
        V21_RunGarbageCollector_Aggressive();
    }
}
%end

%hook FBSSystemService
- (void)openApplication:(id)application withOptions:(NSDictionary *)options {
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
                            g_bksTerminate(bid, 5, NO, @"V21 Kill Background");
                        }
                    }
                }
            }
        } @catch (NSException *e) {}
    }

    NSDictionary *finalOptions = (CFG_PTR.turboAppLaunch) ? nil : options;
    %orig(application, finalOptions);
}
%end

%end // Group_Memory_Engine

// ==============================================================================
// 🎮 PHẦN 8: ĐỒ HỌA METAL TRIPLE BUFFERING & GIẢM NHIỆT ĐỘ KHI SẠC
// ==============================================================================
%group Group_System_Metal_Engine

%hook CAMetalLayer
- (void)setMaximumDrawableCount:(NSUInteger)count {
    if (IS_ON && CFG_PTR.godModeMetal) {
        %orig(3); // Cấp phát 3 frame buffer liên tục chống drop frame
    } else {
        %orig(count);
    }
}

- (void)setPresentsWithTransaction:(BOOL)flag {
    if (IS_ON && CFG_PTR.godModeMetal) {
        %orig(NO); // Render bất đồng bộ, không bao giờ khóa luồng giao diện chính
    } else {
        %orig(flag);
    }
}

- (BOOL)allowsNextDrawableTimeout {
    if (IS_ON && CFG_PTR.godModeMetal) {
        return NO;
    }
    return %orig;
}

- (void)setFramebufferOnly:(BOOL)only {
    if (IS_ON && CFG_PTR.godModeMetal) {
        %orig(YES);
    } else {
        %orig(only);
    }
}
%end

%hook NSProcessInfo
- (NSProcessInfoThermalState)thermalState {
    if (IS_ON && CFG_PTR.smartThermalCharging) {
        return NSProcessInfoThermalStateNominal;
    }
    return %orig;
}

+ (BOOL)isThermalPressureCritical {
    if (IS_ON && CFG_PTR.smartThermalCharging) return NO;
    return %orig;
}
%end

%hook ATXAnalyticsManager
- (void)sendEvent:(id)eventData {
    if (IS_ON && CFG_PTR.blockAnalytics) return; 
    %orig(eventData);
}
%end

%hook UIDevice
- (void)setBatteryMonitoringEnabled:(BOOL)enabled {
    %orig(YES);
}
%end

// Tự động giải phóng áp lực render khi thiết bị cắm sạc hoặc sinh nhiệt cao
%hook IOPMPowerSource
- (void)updateStatus {
    %orig;
    if (IS_ON && CFG_PTR.smartThermalCharging) {
        UIDeviceBatteryState bState = [[UIDevice currentDevice] batteryState];
        if (bState == UIDeviceBatteryStateCharging || bState == UIDeviceBatteryStateFull) {
            [CATransaction begin];
            [CATransaction setAnimationDuration:0.10];
            [CATransaction commit];
        }
    }
}
%end

%end // Group_System_Metal_Engine

// ==============================================================================
// ⚙️ PHẦN 9: KHỞI TẠO BỘ LÕI TWEAK V21
// ==============================================================================

%ctor {
    @autoreleasepool {
        [[CrashGuard sharedInstance] startMonitoring];
        if (![[CrashGuard sharedInstance] canExecuteHooks]) {
            return;
        }

        CFG = [BoostConfig sharedInstance];
        
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            reloadPrefsNotification,
            CFSTR("com.duchaivcy.boostiphone6s/ReloadPrefs"),
            NULL,
            CFNotificationSuspensionBehaviorCoalesce
        );
        
        if (!IS_ON) return; 

        @try {
            [[KernelBypass sharedInstance] initEnvironment];
            [[SystemBlocker sharedInstance] initBlockers];
            [[KernelBypass sharedInstance] boostCurrentThreadPriority];
            [[KernelBypass sharedInstance] forceMachPurge];
            if (CFG_PTR.bypassSandboxVar) init_privilege_escalation();
        } @catch (NSException *e) {}
        
        setenv("MALLOC_OPTIONS", "AFGN", 1);
        if (CFG_PTR.turboAppLaunch) {
            setenv("DYLD_DISABLE_DOFS", "1", 1);
            setenv("OBJC_DISABLE_INITIALIZE_FORK_SAFETY", "YES", 1);
        }
        if (CFG_PTR.tcpNoDelayBoost) setenv("CFNETWORK_DIAGNOSTICS", "0", 1);
        
        %init(_ungrouped); 
        %init(Group_Display_Hz_Fix);
        %init(Group_UI_ColorOS_Curve);
        
        if (BoostIsSpringBoard()) {
            %init(Group_SpringBoard_AntiLag);
        }
        
        %init(Group_Memory_Engine);
        %init(Group_System_Metal_Engine); 
        
        PMPrepareRuntime();
        if (!PMIsUsableProcess()) PMRuntimeReady = NO;
    }
}
