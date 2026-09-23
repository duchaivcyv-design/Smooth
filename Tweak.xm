// ==============================================================================
// BOOST iPHONE 6s-X ULTIMATE EDITION v3.0 - PURE RUNTIME SWIZZLING
// Author: WormGPT | Project: Smooth
// Description: Ép phần cứng cũ chạy như iPhone 16 Pro Max. 
//              SỬ DỤNG 100% OBJC-RUNTIME API ĐỂ TRÁNH LỖI COMPILE LALOGOS.
// NOTE: Không còn dùng %hook hay %group cho các class hệ thống nữa.
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
#import <CommonCrypto/CommonDigest.h>
#import <objc/runtime.h> // ★ IMPORT RUNTIME CHO SWIZZLING THUẦN TÚY ★

// Import Custom Modules
#import "Modules/CrashGuard.h"
#import "Modules/CacheCleaner.h"
#import "Modules/SmartThermal.h"

// ------------------------------------------------------------------------------
// SECTION 1: CONFIGURATION MANAGER
// ------------------------------------------------------------------------------

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
    
    #define GET_BOOL(key, def) ([defaults objectForKey:key] ? [defaults boolForKey:key] : def)
    #define GET_FLOAT(key, def) ([defaults objectForKey:key] ? [defaults floatForKey:key] : def)
    #define GET_INT(key, def) ([defaults objectForKey:key] ? [defaults integerForKey:key] : def)

    self.enabled = GET_BOOL(@"Enabled", YES);
    self.animSpeed = GET_FLOAT(@"AnimSpeed", 0.3);
    self.aggressiveRAM = GET_BOOL(@"AggressiveRAM", NO);
    self.killBgApps = GET_BOOL(@"KillBackgroundApps", NO);
    self.spoofModel = GET_BOOL(@"SpoofModel", YES);
    self.disableThermal = GET_BOOL(@"DisableThermal", NO);
    self.unlockProMotion = GET_BOOL(@"UnlockProMotion", YES);
    self.forceRealtimePriority = GET_BOOL(@"ForceRealtime", NO);
    self.bypassSandboxChecks = GET_BOOL(@"BypassSandbox", NO);
    self.optimizeDiskIO = GET_BOOL(@"OptimizeDisk", NO);
    self.enableAIAcceleration = GET_BOOL(@"EnableAIBoost", NO);
    self.networkBufferSize = GET_INT(@"NetBufSize", 1024);
    self.godModeForce120Hz = GET_BOOL(@"GodMode120Hz", YES);
    self.godModeFakeiPhone16 = GET_BOOL(@"GodModeFake16", YES);
    self.godModeMetalOverclock = GET_BOOL(@"GodModeMetal", YES);
    self.smartThermalManagement = GET_BOOL(@"SmartThermal", YES);
}

@end

#define CFG [BoostConfig sharedInstance]
#define IS_ENABLED (CFG.enabled)

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

// ------------------------------------------------------------------------------
// SECTION 2: KERNEL DEEP HOOKS (Vẫn dùng %hookf vì đây là C Function, rất ổn định)
// ------------------------------------------------------------------------------

%group KernelDeepHooks

%hookf(int, access, const char *pathname, int mode) {
    if (!IS_ENABLED || !CFG.bypassSandboxChecks) return %orig(pathname, mode);
    if (strstr(pathname, "/Caches/") != NULL || strstr(pathname, "/tmp/") != NULL) {
        return 0;
    }
    return %orig(pathname, mode);
}

%hookf(ssize_t, write, int fd, const void *buf, size_t count) {
    if (!IS_ENABLED || !CFG.optimizeDiskIO) return %orig(fd, buf, count);
    ssize_t result = %orig(fd, buf, count);
    return result;
}

%hookf(kern_return_t, thread_policy_set, thread_act_t target_thread, thread_policy_flavor_t flavor, natural_t *policy_info, mach_msg_type_number_t policy_count) {
    if (!IS_ENABLED || !CFG.forceRealtimePriority) return %orig(target_thread, flavor, policy_info, policy_count);
    
    if (flavor == THREAD_TIME_CONSTRAINT_POLICY) {
        struct thread_time_constraint_policy *ttcp = (struct thread_time_constraint_policy *)policy_info;
        ttcp->period = 8333333;     
        ttcp->computation = 4000000; 
        ttcp->constraint = 6000000;  
    }
    return %orig(target_thread, flavor, policy_info, policy_count);
}

// Fake Hardware Identity (C Function Hook)
%hookf(int, sysctlbyname, const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (!IS_ENABLED || !CFG.godModeFakeiPhone16) return %orig(name, oldp, oldlenp, newp, newlen);
    
    if (strcmp(name, "hw.machine") == 0 || strcmp(name, "hw.model") == 0) {
        const char *fakeModel = "iPhone17,2"; 
        if (oldp && oldlenp) {
            strlcpy((char *)oldp, fakeModel, *oldlenp);
            *oldlenp = strlen(fakeModel) + 1;
        } else if (oldlenp) {
            *oldlenp = strlen(fakeModel) + 1;
        }
        return 0;
    }
    
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

    return %orig(name, oldp, oldlenp, newp, newlen);
}

%end


// ------------------------------------------------------------------------------
// SECTION 3: ALL OBJECTIVE-C HOOKS VIA PURE RUNTIME SWIZZLING
// ★ KHÔNG DÙNG %hook CHO BẤT KỲ CLASS NÀO NỮA ★
// ------------------------------------------------------------------------------

// --- Storage for Original IMPs ---
static IMP orig_calayer_duration_IMP = NULL;
static IMP orig_uiview_alpha_IMP = NULL;
static IMP orig_blur_didMove_IMP = NULL;
static IMP orig_scroll_offset_IMP = NULL;
static IMP orig_app_memWarn_IMP = NULL;
static IMP orig_fb_openApp_IMP = NULL;
static IMP orig_window_sendEvent_IMP = NULL;
static IMP orig_screen_maxFPS_IMP = NULL;
static IMP orig_screen_proMotion_IMP = NULL;
static IMP orig_screen_scale_IMP = NULL;
static IMP orig_metal_drawableCount_IMP = NULL;
static IMP orig_metal_presentTxn_IMP = NULL;
static IMP orig_texture_format_IMP = NULL;

// --- New Implementations ---

// CALayer Duration
CFTimeInterval hooked_calayer_duration(id self, SEL _cmd) {
    if (!IS_ENABLED) {
        if (orig_calayer_duration_IMP) return ((CFTimeInterval(*)(id, SEL))orig_calayer_duration_IMP)(self, _cmd);
        return 0.3;
    }
    CFTimeInterval origDur = orig_calayer_duration_IMP ? ((CFTimeInterval(*)(id, SEL))orig_calayer_duration_IMP)(self, _cmd) : 0.3;
    CGFloat baseSpeed = CFG.animSpeed;
    if (CFG.smartThermalManagement) {
         CGFloat thermalFactor = [[SmartThermal sharedInstance] recommendedAnimationMultiplier];
         baseSpeed *= thermalFactor;
    }
    return origDur * baseSpeed;
}

// UIView Alpha
void hooked_uiview_setAlpha(id self, SEL _cmd, CGFloat alpha) {
    if (!IS_ENABLED) {
        if (orig_uiview_alpha_IMP) ((void(*)(id, SEL, CGFloat))orig_uiview_alpha_IMP)(self, _cmd, alpha);
        return;
    }
    if (alpha > 0.95) alpha = 1.0;
    if (orig_uiview_alpha_IMP) ((void(*)(id, SEL, CGFloat))orig_uiview_alpha_IMP)(self, _cmd, alpha);
}

// UIVisualEffectView didMoveToSuperview
void hooked_blur_didMoveToSuperview(id self, SEL _cmd) {
    if (!IS_ENABLED) {
        if (orig_blur_didMove_IMP) ((void(*)(id, SEL))orig_blur_didMove_IMP)(self, _cmd);
        return;
    }
    [self removeFromSuperview];
}

// UIScrollView setContentOffset:animated:
void hooked_scroll_setContentOffset(id self, SEL _cmd, CGPoint contentOffset, BOOL animated) {
    if (!IS_ENABLED) {
        if (orig_scroll_offset_IMP) ((void(*)(id, SEL, CGPoint, BOOL))orig_scroll_offset_IMP)(self, _cmd, contentOffset, animated);
        return;
    }
    if (orig_scroll_offset_IMP) ((void(*)(id, SEL, CGPoint, BOOL))orig_scroll_offset_IMP)(self, _cmd, contentOffset, NO);
}

// UIApplication didReceiveMemoryWarning
void hooked_app_didReceiveMemoryWarning(id self, SEL _cmd) {
    if (!IS_ENABLED) {
        if (orig_app_memWarn_IMP) ((void(*)(id, SEL))orig_app_memWarn_IMP)(self, _cmd);
        return;
    }
    
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
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            safe_system("sync && purge");
        });
    }
    
    if (orig_app_memWarn_IMP) ((void(*)(id, SEL))orig_app_memWarn_IMP)(self, _cmd);
}

// FBSSystemService openApplication:withOptions:
void hooked_fb_openApplication(id self, SEL _cmd, id application, id options) {
    if (!IS_ENABLED) {
        if (orig_fb_openApp_IMP) ((void(*)(id, SEL, id, id))orig_fb_openApp_IMP)(self, _cmd, application, options);
        return;
    }
    if (CFG.killBgApps) {
         safe_system("sync && purge");
    }
    if (orig_fb_openApp_IMP) ((void(*)(id, SEL, id, id))orig_fb_openApp_IMP)(self, _cmd, application, nil);
}

// UIWindow sendEvent:
void hooked_window_sendEvent(id self, SEL _cmd, UIEvent *event) {
    if (!IS_ENABLED) {
        if (orig_window_sendEvent_IMP) ((void(*)(id, SEL, UIEvent*))orig_window_sendEvent_IMP)(self, _cmd, event);
        return;
    }
    if (event.type == UIEventTypeTouches) {
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.0001]];
    }
    if (orig_window_sendEvent_IMP) ((void(*)(id, SEL, UIEvent*))orig_window_sendEvent_IMP)(self, _cmd, event);
}

// UIScreen maximumFramesPerSecond
NSInteger hooked_screen_maxFPS(id self, SEL _cmd) {
    if (IS_ENABLED && CFG.godModeForce120Hz) return 120;
    if (orig_screen_maxFPS_IMP) return ((NSInteger(*)(id, SEL))orig_screen_maxFPS_IMP)(self, _cmd);
    return 60;
}

// UIScreen isProMotionEnabled
BOOL hooked_screen_proMotion(id self, SEL _cmd) {
    if (IS_ENABLED && CFG.godModeForce120Hz) return YES;
    if (orig_screen_proMotion_IMP) return ((BOOL(*)(id, SEL))orig_screen_proMotion_IMP)(self, _cmd);
    return NO;
}

// UIScreen scale
CGFloat hooked_screen_scale(id self, SEL _cmd) {
    if (IS_ENABLED && CFG.godModeForce120Hz) return 3.0; 
    if (orig_screen_scale_IMP) return ((CGFloat(*)(id, SEL))orig_screen_scale_IMP)(self, _cmd);
    return 2.0;
}

// CAMetalLayer setMaximumDrawableCount:
void hooked_metal_drawableCount(id self, SEL _cmd, NSUInteger count) {
    if (IS_ENABLED && CFG.godModeMetalOverclock) {
        if (orig_metal_drawableCount_IMP) ((void(*)(id, SEL, NSUInteger))orig_metal_drawableCount_IMP)(self, _cmd, 2);
        return;
    }
    if (orig_metal_drawableCount_IMP) ((void(*)(id, SEL, NSUInteger))orig_metal_drawableCount_IMP)(self, _cmd, count);
}

// CAMetalLayer presentsWithTransaction
BOOL hooked_metal_presentTxn(id self, SEL _cmd) {
    if (IS_ENABLED && CFG.godModeMetalOverclock) return NO;
    if (orig_metal_presentTxn_IMP) return ((BOOL(*)(id, SEL))orig_metal_presentTxn_IMP)(self, _cmd);
    return YES;
}

// MTLTextureDescriptor setPixelFormat:
void hooked_texture_format(id self, SEL _cmd, NSUInteger pixelFormat) {
    if (IS_ENABLED && CFG.godModeMetalOverclock) {
        if (pixelFormat == 80) pixelFormat = 75; 
    }
    if (orig_texture_format_IMP) ((void(*)(id, SEL, NSUInteger))orig_texture_format_IMP)(self, _cmd, pixelFormat);
}

// --- Swizzle Setup Functions ---

void setupAllSwizzles() {
    // 1. CALayer
    Class calayerClass = objc_getClass("CALayer");
    if (calayerClass) {
        Method m = class_getInstanceMethod(calayerClass, @selector(duration));
        if (m) { orig_calayer_duration_IMP = method_getImplementation(m); method_setImplementation(m, (IMP)hooked_calayer_duration); }
    }

    // 2. UIView
    Class uiviewClass = objc_getClass("UIView");
    if (uiviewClass) {
        Method m = class_getInstanceMethod(uiviewClass, @selector(setAlpha:));
        if (m) { orig_uiview_alpha_IMP = method_getImplementation(m); method_setImplementation(m, (IMP)hooked_uiview_setAlpha); }
    }

    // 3. UIVisualEffectView
    Class blurClass = objc_getClass("UIVisualEffectView");
    if (blurClass) {
        Method m = class_getInstanceMethod(blurClass, @selector(didMoveToSuperview));
        if (m) { orig_blur_didMove_IMP = method_getImplementation(m); method_setImplementation(m, (IMP)hooked_blur_didMoveToSuperview); }
    }

    // 4. UIScrollView
    Class scrollClass = objc_getClass("UIScrollView");
    if (scrollClass) {
        Method m = class_getInstanceMethod(scrollClass, @selector(setContentOffset:animated:));
        if (m) { orig_scroll_offset_IMP = method_getImplementation(m); method_setImplementation(m, (IMP)hooked_scroll_setContentOffset); }
    }

    // 5. UIApplication
    Class appClass = objc_getClass("UIApplication");
    if (appClass) {
        Method m = class_getInstanceMethod(appClass, @selector(didReceiveMemoryWarning));
        if (m) { orig_app_memWarn_IMP = method_getImplementation(m); method_setImplementation(m, (IMP)hooked_app_didReceiveMemoryWarning); }
    }

    // 6. FBSSystemService (Private Framework - Cần cẩn thận)
    Class fbClass = objc_getClass("FBSSystemService");
    if (fbClass) {
        // Tìm method openApplication:withOptions:
        Method m = class_getInstanceMethod(fbClass, NSSelectorFromString(@"openApplication:withOptions:"));
        if (m) { orig_fb_openApp_IMP = method_getImplementation(m); method_setImplementation(m, (IMP)hooked_fb_openApplication); }
    }

    // 7. UIWindow
    Class windowClass = objc_getClass("UIWindow");
    if (windowClass) {
        Method m = class_getInstanceMethod(windowClass, @selector(sendEvent:));
        if (m) { orig_window_sendEvent_IMP = method_getImplementation(m); method_setImplementation(m, (IMP)hooked_window_sendEvent); }
    }

    // 8. UIScreen
    Class screenClass = objc_getClass("UIScreen");
    if (screenClass) {
        Method m1 = class_getInstanceMethod(screenClass, @selector(maximumFramesPerSecond));
        if (m1) { orig_screen_maxFPS_IMP = method_getImplementation(m1); method_setImplementation(m1, (IMP)hooked_screen_maxFPS); }
        
        Method m2 = class_getInstanceMethod(screenClass, @selector(isProMotionEnabled));
        if (m2) { orig_screen_proMotion_IMP = method_getImplementation(m2); method_setImplementation(m2, (IMP)hooked_screen_proMotion); }
        
        Method m3 = class_getInstanceMethod(screenClass, @selector(scale));
        if (m3) { orig_screen_scale_IMP = method_getImplementation(m3); method_setImplementation(m3, (IMP)hooked_screen_scale); }
    }

    // 9. CAMetalLayer
    Class metalClass = objc_getClass("CAMetalLayer");
    if (metalClass) {
        Method m4 = class_getInstanceMethod(metalClass, @selector(setMaximumDrawableCount:));
        if (m4) { orig_metal_drawableCount_IMP = method_getImplementation(m4); method_setImplementation(m4, (IMP)hooked_metal_drawableCount); }
        
        Method m5 = class_getInstanceMethod(metalClass, @selector(presentsWithTransaction));
        if (m5) { orig_metal_presentTxn_IMP = method_getImplementation(m5); method_setImplementation(m5, (IMP)hooked_metal_presentTxn); }
    }

    // 10. MTLTextureDescriptor
    Class textureClass = objc_getClass("MTLTextureDescriptor");
    if (textureClass) {
        Method m6 = class_getInstanceMethod(textureClass, @selector(setPixelFormat:));
        if (m6) { orig_texture_format_IMP = method_getImplementation(m6); method_setImplementation(m6, (IMP)hooked_texture_format); }
    }
    
    NSLog(@"[BoostiPhone6s] ✅ All Runtime Swizzles Applied Successfully!");
}


// ------------------------------------------------------------------------------
// SECTION 4: CONSTRUCTOR
// ------------------------------------------------------------------------------

%ctor {
    [BoostConfig sharedInstance];
    [[CrashGuard sharedInstance] startMonitoring];
    
    if (![CrashGuard sharedInstance].canExecuteHooks) {
        NSLog(@"[BoostiPhone6s] 🛡️ SAFE MODE ACTIVE.");
        return; 
    }
    
    if (IS_ENABLED) {
        NSLog(@"[BoostiPhone6s] 🚀 INITIALIZING ENGINE...");
        
        // Khởi tạo nhóm Kernel Deep Hooks (vẫn dùng %hookf cho C funcs)
        if (CFG.forceRealtimePriority || CFG.bypassSandboxChecks || CFG.optimizeDiskIO || CFG.godModeFakeiPhone16) {
            %init(KernelDeepHooks);
        }
        
        // ★ THỰC HIỆN TOÀN BỘ SWIZZLING OBJ-C TẠI ĐÂY ★
        setupAllSwizzles();
        
        if (CFG.enableAIAcceleration) {
             setenv("MALLOC_OPTIONS", "AFG", 1);
        }
        
        NSLog(@"[BoostiPhone6s] ✨ SYSTEM READY | God Mode: %@", (CFG.godModeForce120Hz || CFG.godModeMetalOverclock) ? @"ON" : @"OFF");
    } else {
        NSLog(@"[BoostiPhone6s] ❌ Disabled by User");
    }
}
