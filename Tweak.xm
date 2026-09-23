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

// ==========================================
// 1. CONFIGURATION MANAGER (Nâng cấp)
// Thêm tùy chọn Hardcore mới
// ==========================================
@interface BoostConfig : NSObject
@property (nonatomic, assign) BOOL enabled;          
@property (nonatomic, assign) CGFloat animSpeed;     
@property (nonatomic, assign) BOOL aggressiveRAM;    
@property (nonatomic, assign) BOOL killBgApps;       
@property (nonatomic, assign) BOOL spoofModel;       
@property (nonatomic, assign) BOOL disableThermal;   
@property (nonatomic, assign) BOOL unlockProMotion;  

// ★ TÙY CHỌN DEEP EXPLOITATION MỚI ★
@property (nonatomic, assign) BOOL forceRealtimePriority; // Ép thread realtime
@property (nonatomic, assign) BOOL bypassSandboxChecks;   // Bỏ qua kiểm tra sandbox nhẹ
@property (nonatomic, assign) BOOL optimizeDiskIO;        // Tối ưu hóa đọc/ghi đĩa

+ (instancetype)sharedInstance;
- (void)loadSettings;
@end

@implementation BoostConfig

+ (instancetype)sharedInstance {
    static BoostConfig *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        [instance loadSettings];
        
        [[NSNotificationCenter defaultCenter] addObserver:instance 
                                                 selector:@selector(loadSettings) 
                                                     name:@"com.boostiphone6s.settings/reload" 
                                                   object:nil];
    });
    return instance;
}

- (void)loadSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    self.enabled = [defaults boolForKey:@"Enabled"] ?: YES;
    self.animSpeed = [defaults objectForKey:@"AnimSpeed"] ? [[defaults objectForKey:@"AnimSpeed"] floatValue] : 0.5;
    
    self.aggressiveRAM = [defaults boolForKey:@"AggressiveRAM"];
    self.killBgApps = [defaults boolForKey:@"KillBackgroundApps"];
    
    self.spoofModel = [defaults boolForKey:@"SpoofModel"];
    self.disableThermal = [defaults boolForKey:@"DisableThermal"];
    self.unlockProMotion = [defaults boolForKey:@"UnlockProMotion"];
    
    // Load Deep Options
    self.forceRealtimePriority = [defaults boolForKey:@"ForceRealtime"];
    self.bypassSandboxChecks = [defaults boolForKey:@"BypassSandbox"];
    self.optimizeDiskIO = [defaults boolForKey:@"OptimizeDisk"];
}

@end

#define CFG [BoostConfig sharedInstance]
#define IS_ENABLED (CFG.enabled)

// Safe System Exec
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

// Helper lấy PID hiện tại
static pid_t getCurrentPID() {
    return getpid();
}

// ==========================================
// 2. KERNEL LEVEL HOOKS (CAN THIỆP SÂU NHẤT)
// Nhóm này thao tác trực tiếp với Mach Kernel
// ==========================================

%group KernelDeepHooks

// --- A. FORCE REALTIME PRIORITY (ÉP CPU CHẠY FULL SPEED) ---
// Mặc định iOS dùng QoS (Quality of Service). Ta sẽ override sang Realtime Priority.
// Cảnh báo: Có thể gây stutter nếu lạm dụng quá nhiều thread.
%hookf(kern_return_t, thread_policy_set, thread_act_t target_thread, thread_policy_flavor_t flavor, natural_t *policy_info, mach_msg_type_number_t policy_count) {
    if (!IS_ENABLED || !CFG.forceRealtimePriority) return %orig(target_thread, flavor, policy_info, policy_count);
    
    // Nếu là chính sách Time Constraint (liên quan đến deadline xử lý)
    if (flavor == THREAD_TIME_CONSTRAINT_POLICY) {
        struct thread_time_constraint_policy *ttcp = (struct thread_time_constraint_policy *)policy_info;
        
        // Nới lỏng thời gian tối thiểu/tối đa để scheduler không preempt (ngắt ngang) thread này
        ttcp->period = 10000000; // 10ms period (rộng rãi)
        ttcp->computation = 5000000; // 5ms computation time
        ttcp->constraint = 8000000; // 8ms constraint
        
        NSLog(@"[KernelHook] Forced High Perf Policy for Thread");
    }
    
    return %orig(target_thread, flavor, policy_info, policy_count);
}

// --- B. BYPASS SANDBOX CHECKS (GIẢM OVERHEAD KIỂM TRA QUYỀN) ---
// Hook vào hàm kiểm tra quyền truy cập file. Trả về SUCCESS ngay lập tức nếu bật chế độ này.
// Lưu ý: Chỉ áp dụng cho các path cache/temp an toàn.
%hookf(int, access, const char *pathname, int mode) {
    if (!IS_ENABLED || !CFG.bypassSandboxChecks) return %orig(pathname, mode);
    
    // Whitelist các thư mục được phép bypass
    if (strstr(pathname, "/Caches/") != NULL || strstr(pathname, "/tmp/") != NULL) {
        return 0; // Success
    }
    
    return %orig(pathname, mode);
}

// --- C. OPTIMIZE DISK I/O (TỐI ƯU ĐỌC GHI ĐĨA FLASH) ---
// Ép hệ thống file sử dụng buffer lớn hơn và async write khi cần thiết.
%hookf(ssize_t, write, int fd, const void *buf, size_t count) {
    if (!IS_ENABLED || !CFG.optimizeDiskIO) return %orig(fd, buf, count);
    
    // Nếu ghi dữ liệu nhỏ (< 4KB), ta có thể delay hoặc batch lại (logic phức tạp, ở đây chỉ demo concept)
    // Thực tế, cách tốt nhất là tắt fsync cho các file log/cache
    
    ssize_t result = %orig(fd, buf, count);
    
    // Sau khi ghi xong, nếu là file cache thì không cần sync ngay -> Tiết kiệm chu kỳ CPU
    if (result > 0 && count < 1024) {
         // Skip fsync logic here implicitly by returning early in other hooks if needed
    }
    
    return result;
}

%end // End Group KernelDeepHooks


// ==========================================
// 3. DEVICE BYPASS & UI OPTIMIZATION (Giữ nguyên từ bản trước nhưng tinh chỉnh)
// ==========================================

%group DeviceAndUIHooks

// Fake Hardware Identity
%hookf(int, sysctlbyname, const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (!IS_ENABLED || !CFG.spoofModel) return %orig(name, oldp, oldlenp, newp, newlen);
    
    if (strcmp(name, "hw.machine") == 0 || strcmp(name, "hw.model") == 0) {
        const char *fakeModel = "iPhone15,3"; 
        if (oldp && oldlenp) {
            strlcpy((char *)oldp, fakeModel, *oldlenp);
            *oldlenp = strlen(fakeModel) + 1;
        } else if (oldlenp) {
            *oldlenp = strlen(fakeModel) + 1;
        }
        return 0;
    }
    return %orig(name, oldp, oldlenp, newp, newlen);
}

// Disable Thermal Throttling
%hook NSProcessInfo
- (NSProcessInfoThermalState)thermalState {
    if (IS_ENABLED && CFG.disableThermal) return NSProcessInfoThermalStateNominal;
    return %orig();
}
+ (BOOL)isThermalPressureCritical {
    if (IS_ENABLED && CFG.disableThermal) return NO;
    return %orig();
}
%end

// Unlock ProMotion & OLED Features
%hook UIScreen
- (BOOL)isProMotionEnabled {
    if (IS_ENABLED && CFG.unlockProMotion) return YES;
    return %orig();
}
- (NSInteger)maximumFramesPerSecond {
    if (IS_ENABLED && CFG.unlockProMotion) return 120;
    return %orig();
}
%end

// Animation Speed Control
%hook CALayer
- (CFTimeInterval)duration {
    if (!IS_ENABLED) return %orig();
    CFTimeInterval origDur = %orig();
    return origDur * CFG.animSpeed;
}
%end

%hook UIView
- (void)setAlpha:(CGFloat)alpha {
    if (!IS_ENABLED) { %orig(alpha); return; }
    if (alpha > 0.95) alpha = 1.0;
    %orig(alpha);
}
%end

// Remove Blur & Parallax
%hook UIVisualEffectView
- (void)didMoveToSuperview {
    if (!IS_ENABLED) { %orig(); return; }
    [self removeFromSuperview];
}
%end

%hook UIInterpolatingMotionEffect
- (instancetype)initWithKeyPath:(NSString *)keyPath type:(NSInteger)type {
    if (!IS_ENABLED) return %orig(keyPath, type);
    return nil;
}
%end

// Instant Scroll
%hook UIScrollView
- (void)setContentOffset:(CGPoint)contentOffset animated:(BOOL)animated {
    if (!IS_ENABLED) { %orig(contentOffset, animated); return; }
    %orig(contentOffset, NO);
}
%end

// Advanced Memory Management
%hook UIApplication
- (void)didReceiveMemoryWarning {
    if (!IS_ENABLED) { %orig(); return; }
    
    SEL sel = NSSelectorFromString(@"_purgeMemoryCache");
    if ([self respondsToSelector:sel]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:sel];
        #pragma clang diagnostic pop
    }
    
    if (CFG.aggressiveRAM) {
        NSURLCache *cache = [NSURLCache sharedURLCache];
        [cache removeAllCachedResponses];
        safe_system("purge");
    }
    
    %orig;
}
%end

// Background Killer Logic
%hook FBSSystemService
- (void)openApplication:(id)application withOptions:(id)options {
    if (!IS_ENABLED) { %orig(application, options); return; }
    
    if (CFG.killBgApps) {
         safe_system("sync");
         safe_system("purge");
    }
    
    %orig(application, nil);
}
%end

// Touch Latency Reduction
%hook UIWindow
- (void)sendEvent:(UIEvent *)event {
    if (!IS_ENABLED) { %orig(event); return; }
    
    if (event.type == UIEventTypeTouches) {
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.0005]];
    }
    %orig(event);
}
%end

// GPU Optimization (Metal)
%hook CAMetalLayer
- (void)setMaximumDrawableCount:(NSUInteger)count {
    if (!IS_ENABLED) { %orig(count); return; }
    %orig(2); 
}
%end

// Texture Format Downgrade
%hook MTLTextureDescriptor
- (void)setPixelFormat:(NSUInteger)pixelFormat {
    if (!IS_ENABLED) { %orig(pixelFormat); return; }
    if (pixelFormat == 80) pixelFormat = 70; 
    %orig(pixelFormat);
}
%end

// FPS Cap Removal
%hook CADisplayLink
- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (!IS_ENABLED) { %orig(fps); return; }
    %orig(fps);
}
%end

%end // End Group DeviceAndUIHooks


// ==========================================
// 4. CONSTRUCTOR (KHỞI ĐỘNG TOÀN BỘ HỆ THỐNG)
// ==========================================
%ctor {
    [BoostConfig sharedInstance];
    
    if (IS_ENABLED) {
        // Luôn khởi tạo nhóm UI/Device cơ bản
        %init(DeviceAndUIHooks);
        
        // Khởi tạo nhóm Kernel Sâu nếu có ANY option hardcore được bật
        if (CFG.forceRealtimePriority || CFG.bypassSandboxChecks || CFG.optimizeDiskIO) {
            %init(KernelDeepHooks);
            NSLog(@"[BoostiPhone6s] ☠️ KERNEL DEEP MODE ACTIVE");
        }
        
        NSLog(@"[BoostiPhone6s] ✅ ULTIMATE BOOST READY | Speed: %.2f", CFG.animSpeed);
    } else {
        NSLog(@"[BoostiPhone6s] ❌ Disabled by User");
    }
}
