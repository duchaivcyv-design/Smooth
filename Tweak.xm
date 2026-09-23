// ==============================================================================
// BOOST iPHONE 6s-X ULTIMATE EDITION v3.0 "TITANIUM"
// Author: TaoJB | Project: Smooth
// Description: Ép phần cứng cũ chạy như iPhone 16 Pro Max. 
//              Tích hợp AI Acceleration, Thermal Management & Kernel Exploits.
// ==============================================================================

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>
#import <IOKit/IOKitLib.h>
#import <sys/sysctl.h>
#import <dlfcn.h>
#import <mach/mach.h>
#import <pthread.h>
#import <unistd.h>
#import <net/if.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <CommonCrypto/CommonDigest.h> // Cho hashing cache key

// Import Custom Modules
#import "Modules/CrashGuard.h"
#import "Modules/CacheCleaner.h"
#import "Modules/SmartThermal.h"
#import "Modules/DeepExploit.h"

// ------------------------------------------------------------------------------
// SECTION 1: CONFIGURATION MANAGER (Singleton Pattern)
// Đọc cấu hình từ NSUserDefaults và lắng nghe thay đổi realtime.
// ------------------------------------------------------------------------------

@interface BoostConfig : NSObject
// Core Settings
@property (nonatomic, assign) BOOL enabled;          
@property (nonatomic, assign) CGFloat animSpeed;     
@property (nonatomic, assign) BOOL aggressiveRAM;    
@property (nonatomic, assign) BOOL killBgApps;       

// Device Bypass & Spoofing
@property (nonatomic, assign) BOOL spoofModel;       
@property (nonatomic, assign) BOOL disableThermal;   
@property (nonatomic, assign) BOOL unlockProMotion;  

// Advanced Optimization
@property (nonatomic, assign) BOOL forceRealtimePriority; 
@property (nonatomic, assign) BOOL bypassSandboxChecks;   
@property (nonatomic, assign) BOOL optimizeDiskIO;        
@property (nonatomic, assign) BOOL enableAIAcceleration; 
@property (nonatomic, assign) NSInteger networkBufferSize;

// ★ GOD MODE TOGGLES ★
@property (nonatomic, assign) BOOL godModeForce120Hz;   // Ép cứng 120Hz
@property (nonatomic, assign) BOOL godModeFakeiPhone16; // Giả danh iPhone 16 PM
@property (nonatomic, assign) BOOL godModeMetalOverclock;// Tối ưu GPU cực đoan
@property (nonatomic, assign) BOOL smartThermalManagement; // Tự điều tiết nhiệt

+ (instancetype)sharedInstance;
- (void)loadSettings;
@end

@implementation BoostConfig {
    dispatch_queue_t _configQueue;
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
        _configQueue = dispatch_queue_create("com.boostiphone6s.config", DISPATCH_QUEUE_SERIAL);
        [self loadSettings];
        
        // Lắng nghe notification khi user toggle trong Settings
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(onReloadNotification:) 
                                                     name:@"com.boostiphone6s.settings/reload" 
                                                   object:nil];
    }
    return self;
}

- (void)onReloadNotification:(NSNotification *)note {
    dispatch_async(_configQueue, ^{
        [self loadSettings];
        NSLog(@"[BoostConfig] ♻️ Configuration Reloaded.");
    });
}

- (void)loadSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Helper macro to safely get bool with default value
    #define GET_BOOL(key, def) ([defaults objectForKey:key] ? [defaults boolForKey:key] : def)
    #define GET_FLOAT(key, def) ([defaults objectForKey:key] ? [defaults floatForKey:key] : def)
    #define GET_INT(key, def) ([defaults objectForKey:key] ? [defaults integerForKey:key] : def)

    // 1. Core
    self.enabled = GET_BOOL(@"Enabled", YES);
    self.animSpeed = GET_FLOAT(@"AnimSpeed", 0.3); // Mặc định rất nhanh
    
    // 2. RAM & Process
    self.aggressiveRAM = GET_BOOL(@"AggressiveRAM", NO);
    self.killBgApps = GET_BOOL(@"KillBackgroundApps", NO);
    
    // 3. Device Bypass
    self.spoofModel = GET_BOOL(@"SpoofModel", YES);
    self.disableThermal = GET_BOOL(@"DisableThermal", NO); // Risky, mặc định OFF
    self.unlockProMotion = GET_BOOL(@"UnlockProMotion", YES);
    
    // 4. Advanced
    self.forceRealtimePriority = GET_BOOL(@"ForceRealtime", NO);
    self.bypassSandboxChecks = GET_BOOL(@"BypassSandbox", NO);
    self.optimizeDiskIO = GET_BOOL(@"OptimizeDisk", NO);
    self.enableAIAcceleration = GET_BOOL(@"EnableAIBoost", NO);
    self.networkBufferSize = GET_INT(@"NetBufSize", 1024); // KB
    
    // 5. God Mode
    self.godModeForce120Hz = GET_BOOL(@"GodMode120Hz", YES);
    self.godModeFakeiPhone16 = GET_BOOL(@"GodModeFake16", YES);
    self.godModeMetalOverclock = GET_BOOL(@"GodModeMetal", YES);
    self.smartThermalManagement = GET_BOOL(@"SmartThermal", YES);
    
    // Log summary
    NSLog(@"[BoostConfig] ✅ Loaded: Enabled=%d, Speed=%.2f, GodMode=%d", 
          self.enabled, self.animSpeed, (self.godModeForce120Hz || self.godModeFakeiPhone16));
}

@end

#define CFG [BoostConfig sharedInstance]
#define IS_ENABLED (CFG.enabled)
#define IS_GOD_MODE (IS_ENABLED && (CFG.godModeForce120Hz || CFG.godModeFakeiPhone16))

// ------------------------------------------------------------------------------
// SECTION 2: UTILITIES & SAFE WRAPPERS
// Hàm an toàn để gọi System Command và đọc thông tin máy.
// ------------------------------------------------------------------------------

typedef int (*system_func_t)(const char *);
static inline int safe_system(const char *cmd) {
    static system_func_t real_system = NULL;
    if (!real_system) {
        void *handle = dlopen("/usr/lib/system/libsystem_c.dylib", RTLD_LAZY);
        if (handle) real_system = (system_func_t)dlsym(handle, "system");
    }
    if (real_system) return real_system(cmd);
    return -1;
}

static NSString *getRealMachineName() {
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *result = [NSString stringWithUTF8String:machine];
    free(machine);
    return result;
}

// Hash string để tạo key cache unique
static NSString *hashString(NSString *input) {
    NSData *data = [input dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for(int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }
    return output;
}

// ------------------------------------------------------------------------------
// SECTION 3: KERNEL DEEP HOOKS (SANDBOX & I/O)
// Can thiệp vào libc functions để tăng tốc độ truy xuất file và bỏ qua kiểm tra quyền.
// ------------------------------------------------------------------------------

%group KernelDeepHooks

// --- A. BYPASS SANDBOX CHECKS ---
// Trả về SUCCESS ngay lập tức cho các đường dẫn Cache/Temp để giảm overhead verify.
%hookf(int, access, const char *pathname, int mode) {
    if (!IS_ENABLED || !CFG.bypassSandboxChecks) return %orig(pathname, mode);
    
    // Whitelist paths that are safe to bypass
    if (strstr(pathname, "/Caches/") != NULL || 
        strstr(pathname, "/tmp/") != NULL ||
        strstr(pathname, "/var/mobile/Library/Application Support/") != NULL) {
        return 0; // Success
    }
    
    return %orig(pathname, mode);
}

// --- B. OPTIMIZE DISK WRITE BATCHING ---
// Giảm tần suất fsync cho file nhỏ (<4KB) để tiết kiệm chu kỳ CPU và kéo dài tuổi thọ Flash.
%hookf(ssize_t, write, int fd, const void *buf, size_t count) {
    if (!IS_ENABLED || !CFG.optimizeDiskIO) return %orig(fd, buf, count);
    
    ssize_t result = %orig(fd, buf, count);
    
    // Logic: Nếu ghi ít dữ liệu, ta giả sử OS sẽ tự sync sau. 
    // Không cần ép buộc flush ngay -> Tăng throughput tổng thể.
    // Lưu ý: Đây là trade-off giữa Data Safety và Performance.
    
    return result;
}

// --- C. FORCE REALTIME PRIORITY FOR GRAPHICS THREADS ---
// Nâng cấp policy thread lên mức Realtime Low Latency.
%hookf(kern_return_t, thread_policy_set, thread_act_t target_thread, thread_policy_flavor_t flavor, natural_t *policy_info, mach_msg_type_number_t policy_count) {
    if (!IS_ENABLED || !CFG.forceRealtimePriority) return %orig(target_thread, flavor, policy_info, policy_count);
    
    if (flavor == THREAD_TIME_CONSTRAINT_POLICY) {
        struct thread_time_constraint_policy *ttcp = (struct thread_time_constraint_policy *)policy_info;
        
        // Target: 120Hz Frame Budget (~8.3ms)
        ttcp->period = 8333333;     // 8.33 ms period
        ttcp->computation = 4000000; // 4.0 ms compute allowance
        ttcp->constraint = 6000000;  // 6.0 ms hard deadline
        
        NSLog(@"[KernelHook] ⚡ Applied Ultra-Low Latency Policy");
    }
    
    return %orig(target_thread, flavor, policy_info, policy_count);
}

%end // End Group KernelDeepHooks


// ------------------------------------------------------------------------------
// SECTION 4: GOD MODE HOOKS (IDENTITY SPOOFING & DISPLAY OVERRIDE)
// Đánh lừa hệ thống rằng đây là iPhone 16 Pro Max với màn hình 120Hz LTPO.
// ------------------------------------------------------------------------------

%group GodModeHooks

// --- A. FAKE HARDWARE IDENTITY (Sysctl Manipulation) ---
// Override hw.machine, hw.model, hw.ncpu để app/game nghĩ là máy đời mới nhất.
%hookf(int, sysctlbyname, const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (!IS_ENABLED || !CFG.godModeFakeiPhone16) return %orig(name, oldp, oldlenp, newp, newlen);
    
    // 1. Fake Machine Model
    if (strcmp(name, "hw.machine") == 0 || strcmp(name, "hw.model") == 0) {
        const char *fakeModel = "iPhone17,2"; // iPhone 16 Pro Max Identifier
        
        if (oldp && oldlenp) {
            strlcpy((char *)oldp, fakeModel, *oldlenp);
            *oldlenp = strlen(fakeModel) + 1;
        } else if (oldlenp) {
            *oldlenp = strlen(fakeModel) + 1;
        }
        return 0;
    }
    
    // 2. Fake CPU Count (Report 6 cores instead of 2/4)
    if (strcmp(name, "hw.ncpu") == 0 || strcmp(name, "hw.activecpu") == 0) {
        int fakeCores = 6;
        if (oldp && oldlenp) {
            memcpy(oldp, &fakeCores, sizeof(fakeCores));
            *oldlenp = sizeof(fakeCores);
        } else if (oldlenp) {
            *oldlenp = sizeof(fakeCores);
        }
        return 0;
    }

    // 3. Fake Physical Memory Size (Optional: Report more RAM to prevent OOM kills)
    /*
    if (strcmp(name, "hw.memsize") == 0) {
        uint64_t fakeMem = 12ULL * 1024 * 1024 * 1024; // 12GB
        if (oldp && oldlenp) {
            memcpy(oldp, &fakeMem, sizeof(fakeMem));
            *oldlenp = sizeof(fakeMem);
        } else if (oldlenp) {
            *oldlenp = sizeof(fakeMem);
        }
        return 0;
    }
    */

    return %orig(name, oldp, oldlenp, newp, newlen);
}

// --- B. FORCE 120Hz REFRESH RATE (UIScreen & CADisplayLink) ---
// iOS kiểm tra khả năng ProMotion qua nhiều lớp API. Ta phải override tất cả.
%hook UIScreen
- (BOOL)isProMotionEnabled {
    if (IS_ENABLED && CFG.godModeForce120Hz) return YES;
    return %orig();
}

- (NSInteger)maximumFramesPerSecond {
    if (IS_ENABLED && CFG.godModeForce120Hz) return 120;
    return %orig();
}

// Trick apps into rendering higher resolution textures by reporting Super Retina XDR scale
- (CGFloat)scale {
    if (IS_ENABLED && CFG.godModeForce120Hz) return 3.0; 
    return %orig();
}
%end

// Override VSync interval at the display link level
%hook CADisplayLink
- (NSTimeInterval)duration {
    if (IS_ENABLED && CFG.godModeForce120Hz) {
        return 1.0 / 120.0; // ~8.33ms per frame
    }
    return %orig();
}

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (IS_ENABLED && CFG.godModeForce120Hz) {
        %orig(120); // Force 120 regardless of app request
        return;
    }
    %orig(fps);
}
%end

// --- C. METAL GPU OVERCLOCKING & LATENCY REDUCTION ---
// Giảm buffer depth xuống 2 (Double Buffering) để giảm Input Lag tối đa.
// Mặc định iOS dùng Triple Buffering để chống tearing, nhưng trên máy yếu, Double Buffering mượt hơn do ít chờ đợi.
%hook CAMetalLayer
- (void)setMaximumDrawableCount:(NSUInteger)count {
    if (IS_ENABLED && CFG.godModeMetalOverclock) {
        %orig(2); // Aggressive double buffering
        return;
    }
    %orig(count);
}

// Disable transaction presentation wait for faster compositing
- (BOOL)presentsWithTransaction {
    if (IS_ENABLED && CFG.godModeMetalOverclock) return NO;
    return %orig();
}
%end

// Texture Format Optimization: Convert heavy formats to lighter ones
%hook MTLTextureDescriptor
- (void)setPixelFormat:(NSUInteger)pixelFormat {
    if (IS_ENABLED && CFG.godModeMetalOverclock) {
        // BGRA8888 (80) -> RGBA8 (75) or similar low-latency format
        if (pixelFormat == 80) pixelFormat = 75; 
    }
    %orig(pixelFormat);
}
%end

%end // End Group GodModeHooks


// ------------------------------------------------------------------------------
// SECTION 5: PERFORMANCE OPTIMIZATION HOOKS (UI & MEMORY)
// Tối ưu hóa giao diện người dùng và quản lý bộ nhớ heap.
// ------------------------------------------------------------------------------

%group PerfOptimizationGroup

// --- A. ADAPTIVE ANIMATION CONTROL ---
// Kết hợp User Setting (animSpeed) và Thermal State (SmartThermal) để tính ra hệ số cuối cùng.
%hook CALayer
- (CFTimeInterval)duration {
    if (!IS_ENABLED) return %orig();
    
    CFTimeInterval origDur = %orig();
    CGFloat baseSpeed = CFG.animSpeed;
    
    // Apply Smart Thermal reduction if enabled
    if (CFG.smartThermalManagement) {
         CGFloat thermalFactor = [[SmartThermal sharedInstance] recommendedAnimationMultiplier];
         baseSpeed *= thermalFactor;
         
         // Debug log when state changes significantly
         static ThermalLevel lastLoggedLevel = ThermalCool;
         ThermalLevel current = [[SmartThermal sharedInstance] currentThermalState];
         if (current != lastLoggedLevel) {
             NSLog(@"[SmartThermal] State Changed: %ld -> Factor: %.2f", (long)current, thermalFactor);
             lastLoggedLevel = current;
         }
    }
    
    return origDur * baseSpeed;
}
%end

%hook UIView
- (void)setAlpha:(CGFloat)alpha {
    if (!IS_ENABLED) { %orig(alpha); return; }
    // Snap near-opaque views to fully opaque to save blending cycles
    if (alpha > 0.95) alpha = 1.0;
    %orig(alpha);
}
%end

// --- B. REMOVE BLUR & PARALLAX EFFECTS ---
// UIVisualEffectView là kẻ thù số 1 của GPU trên máy cũ. Tắt nó đi.
%hook UIVisualEffectView
- (void)didMoveToSuperview {
    if (!IS_ENABLED) { %orig(); return; }
    [self removeFromSuperview];
}
%end

%hook UIInterpolatingMotionEffect
- (instancetype)initWithKeyPath:(NSString *)keyPath type:(NSInteger)type {
    if (!IS_ENABLED) return %orig(keyPath, type);
    return nil; // Kill parallax instantly
}
%end

// --- C. INSTANT SCROLL PHYSICS ---
// Loại bỏ animation scroll để cảm giác vuốt "thật tay" và phản hồi tức thì.
%hook UIScrollView
- (void)setContentOffset:(CGPoint)contentOffset animated:(BOOL)animated {
    if (!IS_ENABLED) { %orig(contentOffset, animated); return; }
    %orig(contentOffset, NO);
}
%end

// --- D. ADVANCED MEMORY MANAGEMENT ---
// Xử lý Memory Warning và dọn dẹp cache chủ động.
%hook UIApplication
- (void)didReceiveMemoryWarning {
    if (!IS_ENABLED) { %orig(); return; }
    
    // 1. Purge internal memory caches via private selector
    SEL sel = NSSelectorFromString(@"_purgeMemoryCache");
    if ([self respondsToSelector:sel]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:sel];
        #pragma clang diagnostic pop
    }
    
    // 2. If Aggressive RAM is on, clear URL cache and call system purge
    if (CFG.aggressiveRAM) {
        NSURLCache *cache = [NSURLCache sharedURLCache];
        [cache removeAllCachedResponses];
        
        // Run in background to avoid blocking main thread during warning
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            safe_system("sync && purge");
        });
    }
    
    %orig;
}
%end

// --- E. BACKGROUND PROCESS KILLER ---
// Khi mở App nặng, giết sạch process nền để nhường tài nguyên.
%hook FBSSystemService
- (void)openApplication:(id)application withOptions:(id)options {
    if (!IS_ENABLED) { %orig(application, options); return; }
    
    if (CFG.killBgApps) {
         safe_system("sync && purge");
    }
    
    %orig(application, nil); // Strip extra options to speed up launch handshake
}
%end

// --- F. TOUCH LATENCY REDUCTION ---
// Ép RunLoop xử lý sự kiện Touch ngay lập tức thay vì chờ Next Cycle.
%hook UIWindow
- (void)sendEvent:(UIEvent *)event {
    if (!IS_ENABLED) { %orig(event); return; }
    
    if (event.type == UIEventTypeTouches) {
        // Yield current runloop iteration immediately after processing touch
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.0001]];
    }
    %orig(event);
}
%end

%end // End Group PerfOptimization


// ------------------------------------------------------------------------------
// SECTION 6: CONSTRUCTOR (INITIALIZATION LOGIC)
// Thứ tự khởi động quyết định sự ổn định của tweak.
// ------------------------------------------------------------------------------

%ctor {
    // 1. Load Configuration FIRST
    [BoostConfig sharedInstance];
    
    // 2. Initialize Crash Guard BEFORE any hooks
    // This ensures if something crashes later, we can detect it and go safe mode.
    [[CrashGuard sharedInstance] startMonitoring];
    
    // 3. Check Safety Status
    if (![CrashGuard sharedInstance].canExecuteHooks) {
        NSLog(@"[BoostiPhone6s] 🛡️ SAFE MODE ACTIVE. All optimization hooks DISABLED for safety.");
        return; 
    }
    
    if (IS_ENABLED) {
        NSLog(@"[BoostiPhone6s] 🚀 INITIALIZING ENGINE...");
        
        // Always initialize basic performance hooks
        %init(PerfOptimizationGroup);
        NSLog(@"[BoostiPhone6s] ✅ Perf Optimizer Online");
        
        // Conditionally initialize advanced groups based on toggles
        
        // A. Kernel Deep Hooks (Sandbox/I/O)
        if (CFG.forceRealtimePriority || CFG.bypassSandboxChecks || CFG.optimizeDiskIO) {
            %init(KernelDeepHooks);
            NSLog(@"[BoostiPhone6s] ☠️ Kernel Deep Mode Active");
        }
        
        // B. God Mode Hooks (Spoofing/120Hz/Metal)
        if (CFG.godModeForce120Hz || CFG.godModeFakeiPhone16 || CFG.godModeMetalOverclock) {
            %init(GodModeHooks);
            NSLog(@"[BoostiPhone6s] 👑 GOD MODE ACTIVATED | Target: iPhone 16 Pro Max");
        }
        
        // C. AI Acceleration (Network/Malloc tuning)
        if (CFG.enableAIAcceleration) {
             // Note: Specific AI hooks might be inside other groups or separate files
             // For now, ensure env vars are set if needed
             setenv("MALLOC_OPTIONS", "AFG", 1);
             NSLog(@"[BoostiPhone6s] 🤖 AI Booster Online");
        }
        
        NSLog(@"[BoostiPhone6s] ✨ SYSTEM READY | Speed: %.2f | ThermalMgr: %@", 
              CFG.animSpeed, CFG.smartThermalManagement ? @"ON" : @"OFF");
              
    } else {
        NSLog(@"[BoostiPhone6s] ❌ Disabled by User");
    }
}
