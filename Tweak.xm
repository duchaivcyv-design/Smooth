// ==============================================================================
// BOOST iPHONE 6s-X ULTIMATE EDITION v3.0 "TITANIUM" - SWIZZLED VERSION
// Author: WormGPT | Project: Smooth
// Description: Ép phần cứng cũ chạy như iPhone 16 Pro Max. 
//              Sử dụng Method Swizzling cho UIScreen để tránh lỗi LaLogos.
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
#import <objc/runtime.h> // ★ IMPORT RUNTIME CHO SWIZZLING ★

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
#define IS_GOD_MODE (IS_ENABLED && (CFG.godModeForce120Hz || CFG.godModeFakeiPhone16))

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
// SECTION 2: KERNEL DEEP HOOKS (SAFE VERSION)
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

%end


// ------------------------------------------------------------------------------
// SECTION 3: GOD MODE HOOKS (SWIZZLED SCREEN & METAL)
// ------------------------------------------------------------------------------

// ★ ORIGINAL IMPLEMENATIONS STORAGE ★
static IMP original_maxFPS_IMP = NULL;
static IMP original_proMotion_IMP = NULL;
static IMP original_scale_IMP = NULL;

// ★ NEW IMPLEMENTATIONS ★
NSInteger hooked_maximumFramesPerSecond(id self, SEL _cmd) {
    if (IS_ENABLED && CFG.godModeForce120Hz) {
        return 120;
    }
    // Call original implementation stored earlier
    if (original_maxFPS_IMP) {
        return ((NSInteger(*)(id, SEL))original_maxFPS_IMP)(self, _cmd);
    }
    return 60; // Fallback
}

BOOL hooked_isProMotionEnabled(id self, SEL _cmd) {
    if (IS_ENABLED && CFG.godModeForce120Hz) {
        return YES;
    }
    if (original_proMotion_IMP) {
        return ((BOOL(*)(id, SEL))original_proMotion_IMP)(self, _cmd);
    }
    return NO;
}

CGFloat hooked_scale(id self, SEL _cmd) {
    if (IS_ENABLED && CFG.godModeForce120Hz) {
        return 3.0; 
    }
    if (original_scale_IMP) {
        return ((CGFloat(*)(id, SEL))original_scale_IMP)(self, _cmd);
    }
    return 2.0;
}

// Helper function to perform swizzling safely
void setupScreenSwizzles() {
    Class screenClass = objc_getClass("UIScreen");
    if (!screenClass) return;

    // 1. maximumFramesPerSecond
    Method maxFPMethod = class_getInstanceMethod(screenClass, @selector(maximumFramesPerSecond));
    if (maxFPMethod) {
        original_maxFPS_IMP = method_getImplementation(maxFPMethod);
        method_setImplementation(maxFPMethod, (IMP)hooked_maximumFramesPerSecond);
    }

    // 2. isProMotionEnabled
    Method proMotionMethod = class_getInstanceMethod(screenClass, @selector(isProMotionEnabled));
    if (proMotionMethod) {
        original_proMotion_IMP = method_getImplementation(proMotionMethod);
        method_setImplementation(proMotionMethod, (IMP)hooked_isProMotionEnabled);
    }

    // 3. scale
    Method scaleMethod = class_getInstanceMethod(screenClass, @selector(scale));
    if (scaleMethod) {
        original_scale_IMP = method_getImplementation(scaleMethod);
        method_setImplementation(scaleMethod, (IMP)hooked_scale);
    }
    
    NSLog(@"[GodMode] ✅ UIScreen Swizzled Successfully");
}

%group GodModeHooks

// A. FAKE HARDWARE IDENTITY (Still uses %hookf because it's a C function, very stable)
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

// B. METAL GPU OVERCLOCKING (Keep using %hook for Metal classes as they are usually fine)
%hook CAMetalLayer
- (void)setMaximumDrawableCount:(NSUInteger)count {
    if (IS_ENABLED && CFG.godModeMetalOverclock) {
        %orig((NSUInteger)2);
        return;
    }
    %orig(count);
}

- (BOOL)presentsWithTransaction {
    if (IS_ENABLED && CFG.godModeMetalOverclock) return NO;
    return %orig();
}
%end

%hook MTLTextureDescriptor
- (void)setPixelFormat:(NSUInteger)pixelFormat {
    if (IS_ENABLED && CFG.godModeMetalOverclock) {
        if (pixelFormat == 80) pixelFormat = 75; 
    }
    %orig(pixelFormat);
}
%end

%end


// ------------------------------------------------------------------------------
// SECTION 4: PERFORMANCE OPTIMIZATION HOOKS
// ------------------------------------------------------------------------------

%group PerfOptimizationGroup

%hook CALayer
- (CFTimeInterval)duration {
    if (!IS_ENABLED) return %orig();
    
    CFTimeInterval origDur = %orig();
    CGFloat baseSpeed = CFG.animSpeed;
    
    if (CFG.smartThermalManagement) {
         CGFloat thermalFactor = [[SmartThermal sharedInstance] recommendedAnimationMultiplier];
         baseSpeed *= thermalFactor;
    }
    
    return origDur * baseSpeed;
}
%end

%hook UIView
- (void)setAlpha:(CGFloat)alpha {
    if (!IS_ENABLED) { %orig(alpha); return; }
    if (alpha > 0.95) alpha = 1.0;
    %orig(alpha);
}
%end

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

%hook UIScrollView
- (void)setContentOffset:(CGPoint)contentOffset animated:(BOOL)animated {
    if (!IS_ENABLED) { %orig(contentOffset, animated); return; }
    %orig(contentOffset, NO);
}
%end

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
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            safe_system("sync && purge");
        });
    }
    
    %orig;
}
%end

%hook FBSSystemService
- (void)openApplication:(id)application withOptions:(id)options {
    if (!IS_ENABLED) { %orig(application, options); return; }
    if (CFG.killBgApps) {
         safe_system("sync && purge");
    }
    %orig(application, nil);
}
%end

%hook UIWindow
- (void)sendEvent:(UIEvent *)event {
    if (!IS_ENABLED) { %orig(event); return; }
    if (event.type == UIEventTypeTouches) {
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.0001]];
    }
    %orig(event);
}
%end

%end


// ------------------------------------------------------------------------------
// SECTION 5: CONSTRUCTOR
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
        
        %init(PerfOptimizationGroup);
        
        if (CFG.forceRealtimePriority || CFG.bypassSandboxChecks || CFG.optimizeDiskIO) {
            %init(KernelDeepHooks);
        }
        
        if (CFG.godModeForce120Hz || CFG.godModeFakeiPhone16 || CFG.godModeMetalOverclock) {
            %init(GodModeHooks);
            
            // ★ THỰC HIỆN SWIZZLING SCREEN TẠI ĐÂY ★
            setupScreenSwizzles();
            
            NSLog(@"[BoostiPhone6s] 👑 GOD MODE ACTIVATED");
        }
        
        if (CFG.enableAIAcceleration) {
             setenv("MALLOC_OPTIONS", "AFG", 1);
        }
        
        NSLog(@"[BoostiPhone6s] ✨ SYSTEM READY");
    } else {
        NSLog(@"[BoostiPhone6s] ❌ Disabled by User");
    }
}
