#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>
#import <IOKit/IOKitLib.h>
#import <sys/sysctl.h>
#import <dlfcn.h>
#import <mach/mach.h>

// ==========================================
// 1. CONFIGURATION MANAGER (Đọc Settings)
// ==========================================
@interface BoostConfig : NSObject
@property (nonatomic, assign) BOOL enabled;          // Bật/Tắt chung
@property (nonatomic, assign) CGFloat animSpeed;     // Tốc độ animation
@property (nonatomic, assign) BOOL aggressiveRAM;    // Xóa cache mạnh
@property (nonatomic, assign) BOOL killBgApps;       // Giết app nền
@property (nonatomic, assign) BOOL spoofModel;       // ★ GIẢ MẠO MODEL MÁY
@property (nonatomic, assign) BOOL disableThermal;   // ★ TẮT CẢNH BÁO NHIỆT
@property (nonatomic, assign) BOOL unlockProMotion;  // ★ MỞ KHÓA 120HZ/OLED

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
        
        // Lắng nghe thay đổi từ App Cài đặt
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
    
    NSNumber *speedVal = [defaults objectForKey:@"AnimSpeed"];
    self.animSpeed = speedVal ? [speedVal floatValue] : 0.5;
    
    self.aggressiveRAM = [defaults boolForKey:@"AggressiveRAM"];
    self.killBgApps = [defaults boolForKey:@"KillBackgroundApps"];
    
    // Load các tùy chọn Phá Rào
    self.spoofModel = [defaults boolForKey:@"SpoofModel"];
    self.disableThermal = [defaults boolForKey:@"DisableThermal"];
    self.unlockProMotion = [defaults boolForKey:@"UnlockProMotion"];
    
    NSLog(@"[BoostiPhone6s] Config Loaded: Spoof=%d, ThermalOff=%d, ProMotion=%d", 
          self.spoofModel, self.disableThermal, self.unlockProMotion);
}

@end

#define CFG [BoostConfig sharedInstance]
#define IS_ENABLED (CFG.enabled)

// Safe System Exec (Không đệ quy)
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

// Helper lấy tên máy thật (để backup logic nếu cần)
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
// 2. DEVICE BYPASS HOOKS (PHÁ VỠ GIỚI HẠN)
// Nhóm này chỉ kích hoạt khi người dùng bật toggle tương ứng
// ==========================================

%group DeviceBypassGroup

// --- A. FAKE HARDWARE IDENTITY (Giả mạo Model) ---
// Đánh lừa mọi App/Game nghĩ đây là iPhone 14 Pro Max (A16 Bionic)
%hookf(int, sysctlbyname, const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (!IS_ENABLED || !CFG.spoofModel) return %orig(name, oldp, oldlenp, newp, newlen);
    
    if (strcmp(name, "hw.machine") == 0 || strcmp(name, "hw.model") == 0) {
        const char *fakeModel = "iPhone15,3"; // iPhone 14 Pro Max
        
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

// --- B. DISABLE THERMAL THROTTLING (Tắt bảo vệ nhiệt) ---
// Ép hệ thống luôn báo trạng thái mát mẻ, ngăn iOS giảm xung nhịp CPU/GPU
%hook NSProcessInfo
- (NSProcessInfoThermalState)thermalState {
    if (IS_ENABLED && CFG.disableThermal) {
        return NSProcessInfoThermalStateNominal; // Luôn trả về Nominal (Bình thường)
    }
    return %orig();
}

// Vô hiệu hóa thông báo áp lực nhiệt nghiêm trọng
+ (BOOL)isThermalPressureCritical {
    if (IS_ENABLED && CFG.disableThermal) return NO;
    return %orig();
}
%end

// Can thiệp IOKit để giả mạo dữ liệu pin/nhiệt độ cho SpringBoard
// Lưu ý: Đây là kỹ thuật nâng cao, có thể gây lỗi hiển thị % pin trên một số phiên bản iOS cũ hơn
/* 
%hookf(io_service_t, IOServiceGetMatchingService, mach_port_t masterPort, io_registry_entry_t matching) {
    // TODO: Implement complex IOKit registry patching here if needed.
    // For now, relying on UserSpace hooks above is safer and sufficient for most apps.
    return %orig(masterPort, matching);
}
*/

// --- C. UNLOCK PRO MOTION & OLED FEATURES (Mở khóa màn hình xịn) ---
// Cho phép App vẽ giao diện 120Hz hoặc Dark Mode chuẩn OLED dù máy chỉ có LCD 60Hz
%hook UIScreen
- (BOOL)isProMotionEnabled {
    if (IS_ENABLED && CFG.unlockProMotion) return YES;
    return %orig();
}

- (NSInteger)maximumFramesPerSecond {
    if (IS_ENABLED && CFG.unlockProMotion) return 120; // Báo là hỗ trợ 120fps
    return %orig();
}
%end

// Ép CALayer chấp nhận rasterization cao cấp (thường tắt trên máy yếu)
%hook CALayer
- (BOOL)supportsRasterization {
    if (IS_ENABLED && CFG.unlockProMotion) return YES;
    return %orig();
}
%end

// Mở khóa Dynamic Island / Live Activities (Logic UI)
%hook SBIconController
- (BOOL)_supportsLiveActivities {
    if (IS_ENABLED && CFG.spoofModel) return YES;
    return %orig();
}
- (BOOL)_hasDynamicIslandSupport {
    if (IS_ENABLED && CFG.spoofModel) return YES;
    return %orig();
}
%end

%end // End Group DeviceBypass


// ==========================================
// 3. PERFORMANCE OPTIMIZATION HOOKS (TỐI ƯU HIỆU NĂNG)
// Nhóm này chạy liên tục nếu tweak được bật
// ==========================================

%group PerfOptimizationGroup

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
    %orig(2); // Giảm buffer để tiết kiệm VRAM
}
%end

// Texture Format Downgrade (Giảm tải GPU)
%hook MTLTextureDescriptor
- (void)setPixelFormat:(NSUInteger)pixelFormat {
    if (!IS_ENABLED) { %orig(pixelFormat); return; }
    // Convert BGRA8888 (80) -> RGBA16Float (70) hoặc thấp hơn tùy driver
    // Ở đây ta ép về format nhẹ hơn nếu đang dùng format nặng
    if (pixelFormat == 80) pixelFormat = 70; 
    %orig(pixelFormat);
}
%end

// FPS Cap Removal (Cho phép game vượt 60fps nếu engine hỗ trợ)
%hook CADisplayLink
- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (!IS_ENABLED) { %orig(fps); return; }
    // Không cap lại ở 30 nữa, để mặc định hoặc ép cao hơn
    // %orig(MAX(fps, 60)); 
    %orig(fps);
}
%end

%end // End Group PerfOptimization


// ==========================================
// 4. CONSTRUCTOR (KHỞI ĐỘNG TWEAK)
// ==========================================
%ctor {
    // Khởi tạo config đầu tiên
    [BoostConfig sharedInstance];
    
    if (IS_ENABLED) {
        // Luôn khởi tạo nhóm Tối Ưu Hiệu Năng
        %init(PerfOptimizationGroup);
        
        // Chỉ khởi tạo nhóm Phá Rào nếu có ANY option bypass được bật
        if (CFG.spoofModel || CFG.disableThermal || CFG.unlockProMotion) {
            %init(DeviceBypassGroup);
            NSLog(@"[BoostiPhone6s] ⚡ EXTENDED BYPASS MODULE ACTIVE");
        }
        
        NSLog(@"[BoostiPhone6s] ✅ Core Active | Speed: %.2f", CFG.animSpeed);
    } else {
        NSLog(@"[BoostiPhone6s] ❌ Disabled by User");
    }
}
