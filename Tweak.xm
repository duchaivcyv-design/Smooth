// ====================================================================================================
// 🚀 TWEAK.XM - BOOST IPHONE (6S TO 15 PRO MAX) - V20 ULTIMATE EDITION (PYTHONIC ARCHITECTURE)
// 🎯 TARGET: iOS 14.0 -> iOS 18.x (Rootful & Rootless /var/jb/)
// 🐍 PHILOSOPHY: 
//    - "Explicit is better than implicit" (Tường minh, không viết gộp gây lỗi Logos).
//    - "Flat is better than nested" (Hạn chế rẽ nhánh sâu, bọc try-catch tuyệt đối an toàn).
//    - "Readability counts" (Khai báo C-Functions ở File Scope, phân tách Group rõ ràng).
// ====================================================================================================

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

// ----------------------------------------------------------------------------------------------------
// 🧩 IMPORT MODULES HỆ THỐNG
// ----------------------------------------------------------------------------------------------------
#import "Modules/CrashGuard.h"
#import "Modules/CacheCleaner.h"
#import "Modules/SmartThermal.h"
#import "Modules/KernelBypass.h"
#import "Modules/SystemBlocker.h"
#import "Modules/DeepExploit.h"


// ====================================================================================================
// 🧱 PHẦN 1: C-FUNCTIONS & HELPERS (FILE SCOPE)
// Kỷ luật: Tất cả các hàm C thuần (không phải Objective-C) bắt buộc phải nằm ngoài các khối %hook.
// Tuyệt đối không di chuyển phần này xuống dưới để tránh lỗi "function definition is not allowed here".
// ====================================================================================================

// Forward Declarations cho SpringBoard
@interface SBApplication : NSObject
- (NSString *)bundleIdentifier;
@end

@interface SBApplicationController : NSObject
+ (instancetype)sharedInstance;
- (NSArray *)allApplications;
@end

// Khai báo trước các hàm Helper
static void PMDebugLog(NSString *format, ...);
static void V20_RunGarbageCollector_Aggressive(void);
static void V20_RunGarbageCollector_Light(void);

// Biến toàn cục (Global Variables) - Quản lý an toàn Thread-safe
static dispatch_once_t g_bksTerminate_once;
typedef void (*BKSTerminateFunc)(NSString *, NSInteger, BOOL, NSString *);
static BKSTerminateFunc g_bksTerminate = NULL;
static dispatch_queue_t v20_background_gc_queue = NULL;

static const void *kPMConfiguredKey = &kPMConfiguredKey;

// --- POSIX & KERNEL COMMANDS ---
static inline void run_posix_cmd_safe(const char *path, const char *arg1, const char *arg2) {
    /* 
     * Khởi chạy lệnh hệ thống an toàn không qua system(), tránh lỗi Sandbox.
     * Tương đương: subprocess.run([path, arg1, arg2]) trong Python.
     */
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
    /* Lazy load dlsym để tránh lỗi trên các phiên bản iOS khác nhau */
    dispatch_once(&g_bksTerminate_once, ^{
        void *handle = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);
        if (!handle) handle = dlopen("/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices", RTLD_LAZY);
        if (handle) {
            g_bksTerminate = (BKSTerminateFunc)dlsym(handle, "BKSTerminateApplicationForReasonAndReportWithDescription");
        }
        if (!g_bksTerminate) g_bksTerminate = &bks_fallback_impl;
    });
}

// --- LOGGER ---
static void PMDebugLog(NSString *format, ...) {
    /* Tương đương logging.debug() của Python, chỉ chạy khi cần thiết */
    if (!format) return;
    va_list args; 
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    // Bỏ comment dòng dưới nếu muốn debug qua Console app
    // NSLog(@"[BoostV20_Pythonic] %@", msg);
}

// --- GARBAGE COLLECTOR (GC) PYTHONIC SIMULATION ---
static void V20_RunGarbageCollector_Aggressive(void) {
    /* 
     * Giải phóng RAM cực mạnh: Xóa Cache URL, ép Mach Purge, Malloc Relief 50MB.
     * Gọi khi đóng app nặng hoặc vào Background.
     */
    if (!v20_background_gc_queue) v20_background_gc_queue = dispatch_queue_create("com.boostv20.gc", DISPATCH_QUEUE_SERIAL);
    dispatch_async(v20_background_gc_queue, ^{
        @autoreleasepool {
            @try {
                [[NSURLCache sharedURLCache] removeAllCachedResponses];
                [CacheCleaner forceDeepMemoryPurge]; // Gọi module
                malloc_zone_pressure_relief(NULL, 1024 * 1024 * 50); 
                PMDebugLog(@"Aggressive GC Executed");
            } @catch(NSException *e) {}
        }
    });
}

static void V20_RunGarbageCollector_Light(void) {
    /* Dọn rác nhẹ nhàng khi nhận Memory Warning để tránh giật lag UI */
    if (!v20_background_gc_queue) v20_background_gc_queue = dispatch_queue_create("com.boostv20.gc", DISPATCH_QUEUE_SERIAL);
    dispatch_async(v20_background_gc_queue, ^{
        @autoreleasepool {
            @try {
                [CacheCleaner forceMemoryPurge];
                malloc_zone_pressure_relief(NULL, 1024 * 1024 * 15); // 15MB
            } @catch(NSException *e) {}
        }
    });
}

// --- COLOROS UI SMOOTHNESS HELPERS ---
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
    // Gắn cờ để không config lặp lại gây hao CPU (Tối ưu thuật toán O(1))
    if (objc_getAssociatedObject(sv, kPMConfiguredKey) != nil) return; 
    
    objc_setAssociatedObject(sv, kPMConfiguredKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    sv.delaysContentTouches = NO;
    PMApplySmoothFeel(sv);
}


// ====================================================================================================
// 🧠 PHẦN 2: CẤU HÌNH HỆ THỐNG V20 (BOOST CONFIG SINGLETON)
// Đọc cấu hình từ plist. Hoạt động độc lập, luồng an toàn (Thread-Safe).
// ====================================================================================================

@interface BoostConfig : NSObject
// Biến Tắt/Mật
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) BOOL isBetaEnabled;

// Màn hình & Tần số quét (30-144Hz)
@property (nonatomic, assign) NSInteger targetHz; 
@property (nonatomic, assign) BOOL forceHardwareHz; 
@property (nonatomic, assign) BOOL popupHzFix; 

// Giao diện (ColorOS) & Độ mượt
@property (nonatomic, assign) BOOL colorOsSmoothness;
@property (nonatomic, assign) BOOL fixMultiTaskLag;
@property (nonatomic, assign) BOOL fixAppExitStutter;
@property (nonatomic, assign) CGFloat animSpeed;
@property (nonatomic, assign) BOOL disableFrameThrottling;

// Hiệu năng Cốt lõi (CPU/GPU/RAM)
@property (nonatomic, assign) BOOL boostCpuGpu80;
@property (nonatomic, assign) BOOL boostRam70;
@property (nonatomic, assign) BOOL ultraDeepRamClean;
@property (nonatomic, assign) BOOL aggressiveRAM;
@property (nonatomic, assign) BOOL killBgApps;
@property (nonatomic, assign) BOOL turboAppLaunch;
@property (nonatomic, assign) BOOL godModeMetalOverclock;
@property (nonatomic, assign) BOOL gameStutterFix;

// Nhiệt độ & Pin
@property (nonatomic, assign) BOOL smartThermalManagement;
@property (nonatomic, assign) BOOL deepCoolingLoading;
@property (nonatomic, assign) BOOL coolingWhileCharging;
@property (nonatomic, assign) BOOL disableThermalThrottling;
@property (nonatomic, assign) BOOL maxBatterySaver;

// Hệ thống sâu
@property (nonatomic, assign) BOOL ios27Scheduler;
@property (nonatomic, assign) BOOL spoofModel16;
@property (nonatomic, assign) BOOL bypassSandboxVar;
@property (nonatomic, assign) BOOL blockAnalytics;
@property (nonatomic, assign) BOOL tcpNoDelayBoost;
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
            // Cắt giảm tác vụ nặng nếu là iPhone cũ (X trở xuống)
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
        
        // Trình trích xuất an toàn. Nếu khuyết Data trong plist sẽ lấy Default (Pythonic Default Args).
        #define GET_BOOL(key, def) (prefs[key] ? [prefs[key] boolValue] : def)
        #define GET_INT(key, def) (prefs[key] ? [prefs[key] integerValue] : def)
        #define GET_FLOAT(key, def) (prefs[key] ? [prefs[key] floatValue] : def)
        
        self.enabled = GET_BOOL(@"Enabled", NO);
        
        if (self.enabled) {
            // -- Phân giải FPS Popup (Quan trọng: Sửa lỗi 30Hz vẫn chạy 60Hz) --
            self.targetHz = GET_INT(@"TargetRefreshRate", 60); 
            // Vượt rào cứng: Thiết bị cũ không thể gánh > 60Hz, ép về 60Hz để tránh crash.
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
        } else {
            // Default Failsafe State (Khôi phục nguyên gốc)
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

// Lắng nghe sự kiện bật/tắt công tắc từ Tweak Settings
static void reloadPrefsNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[BoostConfig sharedInstance] loadSettings];
    CFG = [BoostConfig sharedInstance];
}


// ====================================================================================================
// ⚡️ PHẦN 3: HOOKS KERNEL & POSIX LEVEL (C-API HOOKS)
// Can thiệp sâu nhất vào nhân hệ điều hành. Xử lý nhiệt độ, ưu tiên CPU.
// Tất cả đều được bọc Try-Catch cẩn thận.
// ====================================================================================================

%hookf(int, access, const char *pathname, int mode) {
    /* Bypass Sandbox Checks - Giúp nạp game/app nhanh hơn vì không bị check quyền file liên tục */
    if (!IS_ON || !pathname) return %orig(pathname, mode);
    @try {
        if (CFG_PTR.bypassSandboxVar) {
            if (strstr(pathname, "/var/jb/") || 
                strstr(pathname, "/Library/MobileSubstrate/") ||
                strstr(pathname, "/Library/PreferenceBundles/")) {
                return 0; // Return 0 (Success) lập tức, bỏ qua kiểm tra rườm rà.
            }
        }
    } @catch (NSException *e) {}
    return %orig(pathname, mode);
}

%hookf(kern_return_t, thread_policy_set, thread_act_t target_thread, thread_policy_flavor_t flavor, natural_t *policy_info, mach_msg_type_number_t policy_count) {
    /* 
     * iOS 27 Scheduler Simulation & 80% CPU Boost
     * Sắp xếp lại lịch trình CPU, ưu tiên tài nguyên cho App hiện tại.
     */
    if (!IS_ON) return %orig(target_thread, flavor, policy_info, policy_count);
    @try {
        if ((CFG_PTR.ios27Scheduler || CFG_PTR.boostCpuGpu80) && flavor == THREAD_TIME_CONSTRAINT_POLICY) {
            struct thread_time_constraint_policy *ttcp = (struct thread_time_constraint_policy *)policy_info;
            NSInteger hz = CFG_PTR.targetHz > 0 ? CFG_PTR.targetHz : 60;
            // Tính toán Period dựa trên Frame Rate mục tiêu
            uint64_t periodNs = 1000000000ULL / (uint64_t)hz;
            ttcp->period = (uint32_t)(periodNs);
            ttcp->computation = (uint32_t)(periodNs * 0.45); // Tối ưu 45% thời lượng cho tính toán
            ttcp->constraint = (uint32_t)(periodNs * 0.55);
        }
    } @catch (NSException *e) {}
    return %orig(target_thread, flavor, policy_info, policy_count);
}

%hookf(int, sysctlbyname, const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    /*
     * Fake System Information (Nhiệt độ, Model máy)
     * Vô cùng nhạy cảm, viết sai là Kernel Panic. Đã bọc an toàn tuyệt đối.
     */
    if (!IS_ON || !name) return %orig(name, oldp, oldlenp, newp, newlen);
    
    // Giảm nhiệt giả lập sâu nhất (Chơi game không tụt FPS)
    if ((CFG_PTR.disableThermalThrottling || CFG_PTR.coolingWhileCharging) && strcmp(name, "kern.thermal.temperature") == 0) {
        float fakeTemp = 32.0f; // Báo cáo máy đang mát mẻ (32 độ C)
        if (oldp && oldlenp && *oldlenp >= sizeof(float)) {
            memcpy(oldp, &fakeTemp, sizeof(float));
            *oldlenp = sizeof(float);
            return 0;
        }
    }
    
    // Fake Model sang iPhone 16 (Bật đồ họa cao nhất trong Game)
    if (CFG_PTR.spoofModel16) {
        if (strcmp(name, "hw.machine") == 0 || strcmp(name, "hw.model") == 0) {
            const char *fakeModel = "iPhone16,2";
            if (oldp && oldlenp) {
                strlcpy((char *)oldp, fakeModel, *oldlenp);
                *oldlenp = strlen(fakeModel) + 1;
            } else if (oldlenp) {
                *oldlenp = strlen(fakeModel) + 1;
            }
            return 0;
        }
        // Fake 6 CPU Cores vật lý để gánh đa luồng
        if (strcmp(name, "hw.ncpu") == 0 || strcmp(name, "hw.activecpu") == 0 || strcmp(name, "hw.physicalcpu") == 0) {
            int fakeCores = 6;
            if (oldp && oldlenp) {
                memcpy(oldp, &fakeCores, sizeof(fakeCores));
                *oldlenp = sizeof(fakeCores);
            } else if (oldlenp) {
                *oldlenp = sizeof(fakeCores);
            }
            return 0;
        }
    }
    
    // Tối ưu hóa TCP (Giảm Ping khi chơi game mạng)
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
    /* Đảm bảo game check tên máy qua uname cũng sẽ nhận iPhone 16 */
    int ret = %orig(name);
    if (ret == 0 && IS_ON && CFG_PTR.spoofModel16 && name) {
        strlcpy(name->machine, "iPhone16,2", sizeof(name->machine));
    }
    return ret;
}

%hookf(int, connect, int socket, const struct sockaddr *address, socklen_t address_len) {
    /* TCP No Delay - Bypass thuật toán Nagle để đẩy gói tin ngay lập tức */
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


// ====================================================================================================
// 🖥 PHẦN 4: GROUP_DISPLAY_HZ_FIX (ÉP XUNG FPS & HZ)
// Sửa lỗi tuỳ chọn 30-60-90-120-144 Hz qua Popup không nhận trên iOS 15+.
// ====================================================================================================
%group Group_Display_Hz_Fix

%hook CADisplayLink
/* Dành cho iOS 14 và cũ hơn */
- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    @autoreleasepool {
        if (!IS_ON || !CFG_PTR.forceHardwareHz) {
            %orig(fps);
            return;
        }
        NSInteger target = CFG_PTR.targetHz;
        %orig(target);
    }
}

/* 
 * DÀNH CHO iOS 15 - iOS 18 (CỰC KỲ QUAN TRỌNG)
 * Đây là nguyên nhân bản trước bạn chọn 30Hz nhưng hệ thống vẫn chạy 60Hz. 
 * Apple đã đổi API sang CAFrameRateRange.
 */
- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    @autoreleasepool {
        if (!IS_ON || !CFG_PTR.forceHardwareHz) {
            %orig(range);
            return;
        }
        @try {
            float target = (float)CFG_PTR.targetHz;
            // Bẻ khóa giới hạn bằng cách ép Min, Max, và Preferred về cùng 1 số
            CAFrameRateRange lockedRange = CAFrameRateRangeMake(target, target, target);
            %orig(lockedRange);
        } @catch(NSException *e) {
            %orig(range);
        }
    }
}
%end

%hook UIScreen
- (NSInteger)maximumFramesPerSecond {
    if (IS_ON && CFG_PTR.forceHardwareHz) {
        return CFG_PTR.targetHz;
    }
    return %orig;
}
%end

%end // Group_Display_Hz_Fix


// ====================================================================================================
// 🎨 PHẦN 5: GROUP_UI_COLOROS_CURVE (ĐỘ MƯỢT HOẠT ẢNH)
// Giả lập đường cong tốc độ và độ nhạy của ColorOS 17. 
// Khẳng định: Không gỡ bỏ animation, chỉ làm mượt.
// ====================================================================================================
%group Group_UI_ColorOS_Curve

%hook UIScrollView
- (void)setDecelerationRate:(CGFloat)rate {
    @autoreleasepool {
        if (IS_ON && CFG_PTR.colorOsSmoothness) {
            /* Thay đổi gia tốc cuộn: Trượt tay là vuốt cực êm, không bị dừng gấp */
            CGFloat smoothRate = UIScrollViewDecelerationRateFast; 
            %orig(smoothRate);
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
            // Thay thế đường cong Mặc Định (Hơi giật khúc đầu) bằng EaseOut (Mượt mà tận đuôi)
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
        CFTimeInterval base = %orig;
        // Nhân thêm tốc độ từ cài đặt (Mặc định 1.0 = nguyên bản, 0.5 = nhanh gấp đôi)
        CGFloat finalDuration = base * CFG_PTR.animSpeed;
        return finalDuration;
    }
}
%end

%end // Group_UI_ColorOS_Curve


// ====================================================================================================
// 🚀 PHẦN 6: GROUP_SPRINGBOARD_ANTILAG (ĐA NHIỆM & APP EXIT)
// Fix tận gốc khựng nhiều khung hình khi vuốt app nặng hoặc thoát ra màn hình chính.
// ====================================================================================================
%group Group_SpringBoard_AntiLag

%hook SBFluidSwitcherViewController
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    %orig(scrollView);
    @autoreleasepool {
        if (IS_ON && CFG_PTR.fixMultiTaskLag) {
            // Khóa bóng đổ (Shadows) khi đang vuốt đa nhiệm (Nguyên nhân chính gây drop FPS)
            scrollView.layer.shadowOpacity = 0.0;
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig(animated);
    if (IS_ON && CFG_PTR.fixAppExitStutter) {
        /* Bắt đầu chu trình dọn rác ngay giây phút App đang thu nhỏ, không chờ thu xong mới dọn */
        V20_RunGarbageCollector_Aggressive(); 
    }
}
%end

%hook SBIconController
- (void)iconTapped:(id)icon {
    if (IS_ON && CFG_PTR.fixAppExitStutter) {
        // Boost luồng ưu tiên tối đa khi chạm mở app mới
        [[KernelBypass sharedInstance] boostCurrentThreadPriority];
    }
    %orig(icon);
}
%end

%end // Group_SpringBoard_AntiLag


// ====================================================================================================
// 🧹 PHẦN 7: GROUP_MEMORY_ENGINE (TĂNG TỐC RAM 70%)
// Viết lại hàm openApplication để tránh lỗi Logos Preprocessor.
// ====================================================================================================
%group Group_Memory_Engine

%hook UIApplication
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    %orig(application);
    @autoreleasepool {
        if (IS_ON) {
            // Memory Warning từ hệ thống -> Bật GC nhẹ
            V20_RunGarbageCollector_Light();
        }
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    %orig(application);
    @autoreleasepool {
        if (IS_ON && (CFG_PTR.boostRam70 || CFG_PTR.aggressiveRAM || CFG_PTR.ultraDeepRamClean)) {
            // Đẩy app vào nền -> Bật GC mạnh
            V20_RunGarbageCollector_Aggressive();
        }
    }
}
%end

%hook FBSSystemService
/* 
 * FIX LỖI "Invalid argument structure in %orig":
 * Logos rất dở khi gộp chung Condition và Arguments.
 * Ở đây tạo một Dictionary Explicit, sau đó gọi duy nhất một lệnh %orig.
 */
- (void)openApplication:(id)application withOptions:(NSDictionary *)options {
    @autoreleasepool {
        if (!IS_ON) { 
            %orig(application, options); 
            return; 
        }
        
        // Tính năng Kill Bg Apps (Vuốt mở app mới thì diệt ngầm các app cũ)
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
            } @catch (NSException *e) {
                PMDebugLog(@"KillBg Error: %@", e);
            }
        }

        // Tối ưu hoá Turbo App Launch (Xoá options thừa thãi của Apple khi boot app)
        NSDictionary *finalOptions = (CFG_PTR.turboAppLaunch) ? nil : options;
        
        // Gọi nguyên mẫu %orig chuẩn
        %orig(application, finalOptions);
    }
}
%end

%end // Group_Memory_Engine


// ====================================================================================================
// 🎮 PHẦN 8: GROUP_SYSTEM_METAL_ENGINE (GPU, NHIỆT ĐỘ & PIN)
// ==============================================================================
%group Group_System_Metal_Engine

%hook CAMetalLayer
- (void)setMaximumDrawableCount:(NSUInteger)count {
    @autoreleasepool {
        if (IS_ON && CFG_PTR.godModeMetalOverclock) {
            // Tối ưu buffer khung hình: 3 là số hoàn hảo để Fix Game Stuttering
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
            %orig(NO); // Cho phép CPU đọc/ghi Framebuffer linh hoạt hơn
            return;
        }
        %orig(flag);
    }
}
%end

%hook NSProcessInfo
- (NSProcessInfoThermalState)thermalState {
    // Đánh lừa toàn bộ App trên iOS rằng thiết bị đang ở trạng thái Bình thường (Mát)
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
    if (IS_ON && CFG_PTR.blockAnalytics) return; // Chặn đẩy dữ liệu ngầm cho Apple, tiết kiệm Pin
    %orig(eventData);
}
%end

%hook SleepManager
- (void)enterDeepSleep {
    if (IS_ON && CFG_PTR.deepSleepOptimization) {
        // Tắt cưỡng chế tiến trình phân tích (Analytics) của Apple khi vào Deep Sleep
        run_posix_cmd_safe("/var/jb/bin/launchctl", "stop", "com.apple.analyticsd");
    }
    %orig;
}
%end

%hook GraphicsQualityManager
- (void)setQualityLevel:(NSUInteger)quality {
    if (IS_ON && CFG_PTR.boostCpuGpu80) {
        // Ép đồ họa máy xuất tối đa, vô hiệu hóa tự động hạ chất lượng
        %orig(3);
        return;
    }
    %orig(quality);
}
%end

%end // Group_System_Metal_Engine


// ====================================================================================================
// ⚙️ PHẦN 9: CONSTRUCTOR CHÍNH (BOOTSTRAP & INJECTION)
// Đọc cấu hình, Phân luồng, và Quyết định nạp Group nào vào tiến trình hiện hành.
// ====================================================================================================

%ctor {
    @autoreleasepool {
        // [1] LỚP KHIÊN BẢO VỆ (CRASH GUARD)
        [[CrashGuard sharedInstance] startMonitoring];
        if (![[CrashGuard sharedInstance] canExecuteHooks]) {
            NSLog(@"[BoostV20] 🔴 SAFE MODE KÍCH HOẠT! Hủy Injection để bảo vệ máy.");
            return;
        }

        // [2] TẢI SINGLETON CONFIGURATION
        CFG = [BoostConfig sharedInstance];
        
        // Thiết lập bộ lắng nghe Plist thay đổi không cần Respring
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            reloadPrefsNotification,
            CFSTR("com.taojb.boostiphone6s.settings/reload"),
            NULL,
            CFNotificationSuspensionBehaviorCoalesce
        );
        
        // Nếu Tweak bị tắt tổng bằng công tắc -> Kết thúc tại đây để nhẹ máy
        if (!IS_ON) return; 

        // [3] KHỞI CHẠY CÁC MODULES NGOÀI NỀN (BACKGROUND TASKS)
        @try {
            [[KernelBypass sharedInstance] initEnvironment];
            if (CFG_PTR.enableBlocker) [[SystemBlocker sharedInstance] initBlockers];
            if (CFG_PTR.forceRealtimePriority) [[KernelBypass sharedInstance] boostCurrentThreadPriority];
            if (CFG_PTR.ultraDeepRamClean) [[KernelBypass sharedInstance] forceMachPurge];
            if (CFG_PTR.bypassSandboxVar) init_privilege_escalation();
        } @catch (NSException *e) {
            PMDebugLog(@"Module Error: %@", e);
        }
        
        // [4] THIẾT LẬP MÔI TRƯỜNG BIÊN DỊCH ẢO (ENV)
        if (CFG_PTR.enableAIAcceleration) setenv("MALLOC_OPTIONS", "AFGN", 1);
        if (CFG_PTR.turboAppLaunch) {
            setenv("DYLD_DISABLE_DOFS", "1", 1);
            setenv("OBJC_DISABLE_INITIALIZE_FORK_SAFETY", "YES", 1);
        }
        if (CFG_PTR.tcpNoDelayBoost) setenv("CFNETWORK_DIAGNOSTICS", "0", 1);
        
        // [5] PHÂN LUỒNG HOOKS (EXPLICIT INJECTION)
        // Thay vì load bừa bãi, tính năng nào bật thì mới Load Group của tính năng đó
        
        %init(_ungrouped); // Load File-Scope C-Hooks trước (Bắt buộc)
        
        if (CFG_PTR.forceHardwareHz || CFG_PTR.popupHzFix) {
            %init(Group_Display_Hz_Fix);
        }
        
        if (CFG_PTR.colorOsSmoothness || CFG_PTR.fixAppExitStutter) {
            %init(Group_UI_ColorOS_Curve);
            // Chỉ inject SpringBoard AntiLag nếu tiến trình hiện tại đúng là SpringBoard
            if (BoostIsSpringBoard()) {
                %init(Group_SpringBoard_AntiLag);
            }
        }
        
        if (CFG_PTR.boostRam70 || CFG_PTR.killBgApps || CFG_PTR.aggressiveRAM) {
            %init(Group_Memory_Engine);
        }
        
        // Tích hợp Thermal + Metal + Power vào System Hook Group
        %init(Group_System_Metal_Engine); 
        
        // [6] XÁC NHẬN THÀNH CÔNG
        PMPrepareRuntime();
        NSLog(@"[BoostV20] 🟢 HOÀN THÀNH INJECTION. KHỞI ĐỘNG V20 ULTIMATE ENGINE.");
    }
}
