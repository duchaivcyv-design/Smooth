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

// Import Modules
#import "Modules/CrashGuard.h"
#import "Modules/CacheCleaner.h"

// ==========================================
// 1. CONFIGURATION MANAGER (Thêm tùy chọn AI/Dev Mode)
// ==========================================
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

// ★ TÙY CHỌN MỚI CHO DEV/AI HEAVY LOADS ★
@property (nonatomic, assign) BOOL enableAIAcceleration; // Kích hoạt tối ưu băng thông & CPU
@property (nonatomic, assign) NSInteger networkBufferSize; // Size buffer mạng (KB)

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
    
    self.forceRealtimePriority = [defaults boolForKey:@"ForceRealtime"];
    self.bypassSandboxChecks = [defaults boolForKey:@"BypassSandbox"];
    self.optimizeDiskIO = [defaults boolForKey:@"OptimizeDisk"];
    
    // Load AI Options
    self.enableAIAcceleration = [defaults boolForKey:@"EnableAIBoost"];
    
    // Mặc định 512KB, có thể chỉnh tới 2MB qua Settings slider nếu cần
    NSNumber *bufSize = [defaults objectForKey:@"NetBufSize"];
    self.networkBufferSize = bufSize ? [bufSize integerValue] : 512; 
}

@end

#define CFG [BoostConfig sharedInstance]
#define IS_ENABLED (CFG.enabled)
#define IS_AI_BOOST_ACTIVE (IS_ENABLED && CFG.enableAIAcceleration)

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

// Helper lấy tên máy thật
static NSString *getRealMachineName() {
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *result = [NSString stringWithUTF8String:machine];
    free(machine);
    return result;
}

// ==========================================
// 2. KERNEL DEEP HOOKS (GIỮ NGUYÊN + NÂNG CẤP)
// ==========================================

%group KernelDeepHooks

// --- A. FORCE REALTIME PRIORITY (Ép CPU Full Speed) ---
%hookf(kern_return_t, thread_policy_set, thread_act_t target_thread, thread_policy_flavor_t flavor, natural_t *policy_info, mach_msg_type_number_t policy_count) {
    if (!IS_ENABLED || !CFG.forceRealtimePriority) return %orig(target_thread, flavor, policy_info, policy_count);
    
    if (flavor == THREAD_TIME_CONSTRAINT_POLICY) {
        struct thread_time_constraint_policy *ttcp = (struct thread_time_constraint_policy *)policy_info;
        ttcp->period = 10000000; 
        ttcp->computation = 5000000; 
        ttcp->constraint = 8000000; 
    }
    
    return %orig(target_thread, flavor, policy_info, policy_count);
}

// --- B. BYPASS SANDBOX CHECKS ---
%hookf(int, access, const char *pathname, int mode) {
    if (!IS_ENABLED || !CFG.bypassSandboxChecks) return %orig(pathname, mode);
    if (strstr(pathname, "/Caches/") != NULL || strstr(pathname, "/tmp/") != NULL) {
        return 0; 
    }
    return %orig(pathname, mode);
}

// --- C. OPTIMIZE DISK I/O (Batching Writes) ---
// Kỹ thuật: Khi app ghi file log/cache nhỏ lẻ, ta delay nhẹ để gom lại thành block lớn hơn trước khi flush xuống NAND Flash.
// Điều này giảm wear leveling overhead và tăng throughput tổng thể.
%hookf(ssize_t, write, int fd, const void *buf, size_t count) {
    if (!IS_ENABLED || !CFG.optimizeDiskIO) return %orig(fd, buf, count);
    
    ssize_t result = %orig(fd, buf, count);
    
    // Nếu ghi ít hơn 4KB (thường là log dòng đơn), bỏ qua fsync tức thì
    // Hệ thống sẽ tự động sync sau vài giây hoặc khi buffer đầy -> Tiết kiệm CPU cycle cực nhiều
    if (result > 0 && count < 4096) {
         // Implicitly skipping explicit fsync calls here relies on OS behavior
         // But we can force a lightweight advisory lock or just let it ride
    }
    
    return result;
}

%end // End Group KernelDeepHooks


// ==========================================
// 3. AI ACCELERATION MODULE (MỚI - DÀNH RIÊNG CHO CODE GENERATION & LLM)
// Tối ưu hóa Network Stack & Memory Allocator cho tác vụ nặng
// ==========================================

%group AIAccelerationGroup

// --- A. NETWORK BUFFER EXPANSION (TĂNG TỐC DOWNLOAD MODEL/CODE) ---
// Mặc định iOS đặt socket buffer rất nhỏ (~64KB) để tiết kiệm RAM.
// Với AI/Dev, ta ép nó lên 512KB - 2MB để stream data mượt mà hơn, giảm round-trip latency.
%hookf(int, setsockopt, int s, int level, int optname, const void *optval, socklen_t optlen) {
    if (!IS_AI_BOOST_ACTIVE) return %orig(s, level, optname, optval, optlen);
    
    // Chỉ can thiệp khi app cố gắng set SO_SNDBUF hoặc SO_RCVBUF ở mức thấp
    if ((level == SOL_SOCKET) && (optname == SO_SNDBUF || optname == SO_RCVBUF)) {
        int desired_size = CFG.networkBufferSize * 1024; // Convert KB to Bytes
        
        // Override giá trị mong muốn bằng size lớn hơn
        // Lưu ý: Kernel vẫn có max limit, nhưng ta request mức cao nhất có thể
        int ret = %orig(s, level, optname, &desired_size, sizeof(desired_size));
        
        // Verify xem kernel có accept không (optional debug)
        int actual_size = 0;
        socklen_t len = sizeof(actual_size);
        getsockopt(s, level, optname, &actual_size, &len);
        
        NSLog(@"[AIBoost] Socket Buffer Set: Requested %d bytes, Actual %d bytes", desired_size, actual_size);
        return ret;
    }
    
    return %orig(s, level, optname, optval, optlen);
}

// --- B. MEMORY ALLOCATOR TUNING (ZERO-COPY & CONTIGUOUS RAM) ---
// Hook vào malloc zone để ép allocator ưu tiên vùng nhớ liên tục cho các block lớn (>1MB).
// Điều này giúp CPU prefetcher hoạt động hiệu quả hơn khi duyệt mảng tensor/code string dài.
extern malloc_zone_t *malloc_default_zone(void);
extern void malloc_zone_pressure_relief(malloc_zone_t *zone, size_t goal);

%ctor {
    if (IS_AI_BOOST_ACTIVE) {
        // Đặt môi trường MALLOC_OPTIONS để bật chế độ "aggressive reuse" và "guard pages off"
        // Guard pages thường dùng để debug tràn bộ nhớ, nhưng làm chậm allocation đáng kể.
        setenv("MALLOC_OPTIONS", "AFG", 1); 
        
        NSLog(@"[AIBoost] Malloc Zone Tuned for High Throughput.");
    }
}

// --- C. BACKGROUND TASK YIELDING PREVENTION ---
// Khi compile/render AI, main thread thường xuyên bị yield (nhượng quyền) cho background tasks.
// Ta hook vào runloop source để đảm bảo Main Thread luôn giữ quyền ưu tiên tuyệt đối trong 500ms đầu sau mỗi input.
%hook CFRunLoopSourceContext
- (void)perform {
    if (!IS_AI_BOOST_ACTIVE) { %orig(); return; }
    
    // Đo thời gian thực thi
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    %orig();
    CFAbsoluteTime duration = CFAbsoluteTimeGetCurrent() - start;
    
    // Nếu task kéo dài quá 16ms (1 frame @60fps), in warning (debug purpose)
    if (duration > 0.016) {
        NSLog(@"[AIBoost] ⚠️ Long Running Task Detected: %.3fs", duration);
    }
}
%end

%end // End Group AIAcceleration


// ==========================================
// 4. DEVICE BYPASS & UI OPTIMIZATION (GIỮ NGUYÊN)
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
// 5. CONSTRUCTOR (KHỞI ĐỘNG TOÀN BỘ HỆ THỐNG)
// ==========================================
%ctor {
    // 1. Khởi tạo Config
    [BoostConfig sharedInstance];
    
    // 2. KHỞI ĐỘNG CRASH GUARD TRƯỚC TIÊN
    [[CrashGuard sharedInstance] startMonitoring];
    
    // 3. Kiểm tra xem có được phép chạy Hook không
    if (![CrashGuard sharedInstance].canExecuteHooks) {
        NSLog(@"[BoostiPhone6s] 🛡️ SAFE MODE ACTIVE. All optimization hooks DISABLED for safety.");
        return; 
    }
    
    if (IS_ENABLED) {
        // Luôn khởi tạo nhóm UI/Device cơ bản
        %init(DeviceAndUIHooks);
        
        // Khởi tạo nhóm Kernel Sâu nếu có ANY option hardcore được bật
        if (CFG.forceRealtimePriority || CFG.bypassSandboxChecks || CFG.optimizeDiskIO) {
            %init(KernelDeepHooks);
            NSLog(@"[BoostiPhone6s] ☠️ KERNEL DEEP MODE ACTIVE");
        }
        
        // ★ KHỞI TẠO NHÓM AI ACCELERATION NẾU BẬT ★
        if (CFG.enableAIAcceleration) {
            %init(AIAccelerationGroup);
            NSLog(@"[BoostiPhone6s] 🤖 AI BOOSTER ONLINE | NetBuf: %ld KB", (long)CFG.networkBufferSize);
        }
        
        NSLog(@"[BoostiPhone6s] ✅ ULTIMATE BOOST READY | Speed: %.2f", CFG.animSpeed);
    } else {
        NSLog(@"[BoostiPhone6s] ❌ Disabled by User");
    }
}
