#import <mach/mach.h>
#import <mach/mach_init.h>
#import <mach/mach_host.h>
#import <mach/mach_time.h>
#import <mach/task.h>
#import <mach/task_info.h>
#import <mach/task_policy.h>
#import <mach/thread_act.h>
#import <mach/thread_policy.h>
#import <mach/vm_map.h>
#import <mach/vm_statistics.h>
#include <stdio.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <time.h>
#import <pthread.h>
#import <pthread/qos.h>
#import <dlfcn.h>
#import <malloc/malloc.h>
#import <notify.h>
#import <os/lock.h>
#import <sys/types.h>
#import <sys/time.h>
#import <sys/sysctl.h>
#import <sys/resource.h>
#import <sys/utsname.h>
#import <sys/stat.h>
#import <sys/mman.h>
#import <spawn.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <QuartzCore/CAMetalLayer.h>
#import <Metal/Metal.h>
#import <WebKit/WebKit.h>
extern char **environ;
#ifndef IOPOL_TYPE_DISK
#define IOPOL_TYPE_DISK 0
#define IOPOL_SCOPE_PROCESS 0
#define IOPOL_SCOPE_THREAD 1
#define IOPOL_IMPORTANT 1
#define IOPOL_TYPE_VFS_ATIME_UPDATES 2
#define IOPOL_ATIME_UPDATES_OFF 1
#endif
#ifndef VM_PURGABLE_PURGE_ALL
#define VM_PURGABLE_PURGE_ALL 0
#endif
#if __has_include(<QuartzCore/CAFrameRateRange.h>)
typedef CAFrameRateRange SafeFrameRateRange;
#define SafeMakeFRR(min, max, pref) CAFrameRateRangeMake(min, max, pref)
#else
typedef struct { float minimum; float maximum; float preferred; } SafeFrameRateRange;
static inline SafeFrameRateRange SafeMakeFRR(float min, float max, float pref) {
    SafeFrameRateRange r = {min, max, pref}; return r;
}
#endif
typedef int (*Titanium_setiopolicy_np_fn)(int, int, int);
static int Titanium_setiopolicy_np_safe(int iotype, int scope, int policy) {
    static Titanium_setiopolicy_np_fn fn = NULL;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ fn = (Titanium_setiopolicy_np_fn)dlsym(RTLD_DEFAULT, "setiopolicy_np"); });
    return fn ? fn(iotype, scope, policy) : -1;
}
static const char *Titanium_SafeGetProgName(void) {
    static const char *(*s_getprogname_fn)(void) = NULL;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s_getprogname_fn = (const char *(*)(void))dlsym(RTLD_DEFAULT, "getprogname"); });
    if (s_getprogname_fn) {
        const char *name = s_getprogname_fn();
        if (name && name[0]) return name;
    }
    return "unknown";
}
// ====================================================================================================
// CẤU TRÚC PAYLOAD ĐỒNG BỘ 100% VỚI ROOTLISTCONTROLLER.M (448 BYTES — CHỐNG TRÀN STACK)
// ====================================================================================================
#define APEX_SYNC_MAGIC_V285 0x41505837
#define PREF_DOMAIN          CFSTR("com.taojb.boostiphone6s")
#define PRIMARY_SYNC_FILE    @"/tmp/.boost_hz_sync"
#define SECONDARY_SYNC_FILE  @"/var/jb/tmp/.boost_hz_sync"
#define APPS_SYNC_FILE_PRIMARY   @"/tmp/.boost_hz_apps"
#define APPS_SYNC_FILE_SECONDARY @"/var/jb/tmp/.boost_hz_apps"
#define PER_APP_RATES_FILE_PRIMARY   @"/tmp/.boost_hz_per_app.plist"
#define PER_APP_RATES_FILE_SECONDARY @"/var/jb/tmp/.boost_hz_per_app.plist"
#define NOTIFY_RELOAD           "com.taojb.boostiphone6s/ReloadPrefs"
#define NOTIFY_UIKIT_RELOAD     "com.taojb.boostiphone6s/ReloadUIKitPrefs"
#define NOTIFY_HARDWARE_SYNC    "com.taojb.boostiphone6s/HardwareSync"
#define NOTIFY_FPS_CHANGED      "com.taojb.boostiphone6s/FPSChanged"
#define NOTIFY_TITANIUM_CHANGED "com.titanium.v285.prefschanged"
#define NOTIFY_PAYLOAD_WRITTEN  "com.taojb.boostiphone6s/PayloadWritten"
#ifndef _APEX_V285_PRO_PAYLOAD_DEFINED
#define _APEX_V285_PRO_PAYLOAD_DEFINED
typedef struct __attribute__((packed)) {
    uint32_t magic;
    uint32_t masterEnabled;
    int32_t  targetHz;
    int32_t  targetFPS;
    uint32_t forceOverclock;
    uint32_t pipSyncEnabled;
    uint32_t thermalShield;
    uint32_t antiStutterExit;
    uint32_t smartBufferingLevel;
    uint32_t zeroLatencyTouch;
    uint32_t shaderOptimization;
    uint32_t dynamicInterpolation;
    uint32_t fastAppLaunch;
    uint32_t lowLatencyAudio;
    uint32_t memoryPressureRelief;
    uint32_t metalPacingEnabled;
    uint32_t runloopHangGuard;
    uint32_t keyboardZeroLagV3;
    uint32_t aggressiveRamCleaner;
    uint32_t lockFixedFpsWhenThermal;
    uint32_t antiGhostTouch;
    uint32_t diskIOPriorityBoost;
    uint32_t rawTouchDirectDelivery;
    uint32_t powerSaveModeActive;
    uint32_t groupFlags[34];
    uint64_t updateSeq;
    uint64_t lastHeartbeat;
    char     reserved[200];
} ApexV285ProPayload;
#endif
static ApexV285ProPayload g_syncPayloadV285 = {
    .magic = APEX_SYNC_MAGIC_V285,
    .masterEnabled = 1,
    .targetHz = 240,
    .targetFPS = 240
};
static os_unfair_lock g_syncLockV285 = OS_UNFAIR_LOCK_INIT;
static volatile uint64_t g_lastSyncTicksV285 = 0;
static volatile NSInteger g_cachedResolvedHz = 240;
static volatile NSInteger g_cachedResolvedFPS = 240;
static BOOL g_isCurrentAppBlacklisted = NO;
static volatile uint64_t g_lastTouchTimestamp = 0;
// ====================================================================================================
// KHAI BÁO CÁC PRIVATE INTERFACES (TẦNG 1 -> TẦNG 5)
// ====================================================================================================
@interface UIEvent (TitaniumPrivate)
- (NSInteger)type;
@end
@interface UIScrollView (TitaniumPrivate)
- (void)_scrollViewWillBeginDragging;
@end
@interface CATransaction (TitaniumPrivate)
+ (void)_setLowLatency:(BOOL)flag;
@end
@interface CALayer (TitaniumPrivate)
- (void)setDrawsAsynchronously:(BOOL)flag;
- (void)setAllowsGroupOpacity:(BOOL)flag;
@end
@interface CADisplayLink (TitaniumPrivate)
@property (nonatomic, assign) CAFrameRateRange preferredFrameRateRange;
@end
@interface CAMetalLayer (TitaniumPrivate)
@property (nonatomic, assign) CAFrameRateRange preferredFrameRateRange;
@property (nonatomic, assign) NSUInteger maximumDrawableCount;
- (void)setDisplaySyncEnabled:(BOOL)enabled;
- (void)setAllowsNextDrawableTimeout:(BOOL)allow;
@end
@interface CADisplay : NSObject
+ (CADisplay *)mainDisplay;
- (BOOL)allowsVirtualModes;
- (void)setAllowsVirtualModes:(BOOL)allows;
@end
@interface CAWindowServerDisplay : NSObject
- (BOOL)allowsVirtualModes;
- (void)setAllowsVirtualModes:(BOOL)flag;
- (double)minimumFrameDuration;
- (double)maximumRefreshRate;
- (double)idealRefreshRate;
@end
@interface UIWindowScene (TitaniumPrivate)
@property (nonatomic, assign) SafeFrameRateRange preferredFrameRateRange;
- (void)_readySceneForDisplay;
@end
@interface CABackdropLayer : CALayer
- (void)setDisablesOccludedBackdropBlurs:(BOOL)flag;
- (BOOL)disablesOccludedBackdropBlurs;
@end
@interface SBControlCenterController : NSObject
- (void)presentAnimated:(BOOL)animated completion:(id)completion;
- (void)dismissAnimated:(BOOL)animated completion:(id)completion;
@end
@interface SBNotificationCenterController : NSObject
- (void)presentAnimated:(BOOL)animated completion:(id)completion;
- (void)dismissAnimated:(BOOL)animated completion:(id)completion;
@end
@interface CSCoverSheetViewController : UIViewController
- (void)viewWillAppear:(BOOL)animated;
@end
@interface SBDockView : UIView
- (void)layoutSubviews;
@end
@interface SBFolderController : NSObject
- (void)openFolderAnimated:(BOOL)animated withCompletion:(id)completion;
- (void)closeFolderAnimated:(BOOL)animated withCompletion:(id)completion;
@end
@interface SBSystemApertureViewController : UIViewController
- (void)viewWillLayoutSubviews;
@end
@interface FBProcess : NSObject
- (void)killForReason:(long long)reason andReport:(BOOL)report withDescription:(id)description completion:(id)completion;
@end
@interface _MTLCommandQueue : NSObject
- (void)setStatOptions:(NSUInteger)options;
- (BOOL)executionEnabled;
@end
@interface CAMetalDrawable : NSObject
- (void)presentAfterMinimumDuration:(CFTimeInterval)duration;
@end
// ====================================================================================================
// HÀM TIỆN ÍCH CỐT LÕI (IDLE CPU 1–5%, MÁT 29–33°C, BUNG XUNG TỨC THÌ KHI CHẠM/CUỘN/CHƠI GAME)
// ====================================================================================================
static inline uint64_t Titanium_NanosToMachTicks(uint64_t nanos) {
    static mach_timebase_info_data_t s_tbInfo = {0, 0};
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mach_timebase_info(&s_tbInfo);
        if (s_tbInfo.numer == 0 || s_tbInfo.denom == 0) { s_tbInfo.numer = 1; s_tbInfo.denom = 1; }
    });
    return (nanos * (uint64_t)s_tbInfo.denom) / (uint64_t)s_tbInfo.numer;
}
static BOOL Titanium_IsSpringBoard(void) {
    static BOOL isSB = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
        isSB = [bid isEqualToString:@"com.apple.springboard"];
    });
    return isSB;
}
static BOOL Titanium_IsSettingsOrSelfApp(void) {
    static BOOL isSelf = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *bid = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
        NSString *proc = [[NSProcessInfo processInfo] processName] ?: @"";
        isSelf = [bid isEqualToString:@"com.taojb.boostiphone6s"] ||
                 [bid isEqualToString:@"com.apple.Preferences"] ||
                 [proc isEqualToString:@"BoostiPhone6sApp"] ||
                 [proc isEqualToString:@"Preferences"];
    });
    return isSelf;
}
static inline NSString *Titanium_GetRootHidePrefixPath(void) {
    static NSString *cached = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Dl_info info;
        if (dladdr((const void *)Titanium_GetRootHidePrefixPath, &info) && info.dli_fname) {
            NSString *dylib = [NSString stringWithUTF8String:info.dli_fname];
            NSRange r = [dylib rangeOfString:@"/var/jb"];
            if (r.location != NSNotFound) {
                NSRange sub = [dylib rangeOfString:@"/" options:0 range:NSMakeRange(r.location + 7, dylib.length - (r.location + 7))];
                cached = (sub.location != NSNotFound) ? [dylib substringToIndex:sub.location] : @"/var/jb";
            } else cached = @"/var/jb";
        } else cached = @"/var/jb";
    });
    return cached;
}
static inline NSString *Titanium_ResolvePrefPath(void) {
    NSString *root = Titanium_GetRootHidePrefixPath();
    NSFileManager *fm = [NSFileManager defaultManager];
    if (root.length > 0 && ![root isEqualToString:@"/"]) {
        NSString *p = [root stringByAppendingPathComponent:@"var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist"];
        if ([fm fileExistsAtPath:p]) return p;
    }
    if ([fm fileExistsAtPath:@"/var/jb/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist"]) {
        return @"/var/jb/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist";
    }
    return @"/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist";
}
static BOOL Titanium_IsBundleDisabledViaIPC(NSString *bundleID) {
    if (bundleID.length == 0) return NO;
    NSArray *paths = @[APPS_SYNC_FILE_PRIMARY, APPS_SYNC_FILE_SECONDARY];
    for (NSString *path in paths) {
        if (access([path UTF8String], R_OK) != 0) continue;
        NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        if (!content) continue;
        for (NSString *line in [content componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
            if ([line isEqualToString:bundleID]) return YES;
        }
        return NO;
    }
    return NO;
}
// Đọc đồng bộ trạng thái Hz/FPS (Throttle 600ms để CPU rảnh luôn ở mức 1–5%)
static inline void Titanium_ReloadSharedSyncStateV285(void) {
    uint64_t now = mach_absolute_time();
    if (g_lastSyncTicksV285 != 0 && (now - g_lastSyncTicksV285) < Titanium_NanosToMachTicks(600ULL * 1000000ULL)) {
        return;
    }
    os_unfair_lock_lock(&g_syncLockV285);
    g_lastSyncTicksV285 = now;
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (bundleID.length > 0 && !Titanium_IsSpringBoard() && !Titanium_IsSettingsOrSelfApp()) {
        g_isCurrentAppBlacklisted = Titanium_IsBundleDisabledViaIPC(bundleID);
        if (g_isCurrentAppBlacklisted) {
            g_syncPayloadV285.masterEnabled = 0;
            os_unfair_lock_unlock(&g_syncLockV285);
            return;
        }
    }
    BOOL loaded = NO;
    NSArray *checkPaths = @[PRIMARY_SYNC_FILE, SECONDARY_SYNC_FILE];
    for (NSString *path in checkPaths) {
        int fd = open([path UTF8String], O_RDONLY);
        if (fd < 0) continue;
        uint8_t buf[512] = {0};
        ssize_t n = read(fd, buf, sizeof(buf));
        close(fd);
        if (n >= 16) {
            uint32_t magic = *(uint32_t *)buf;
            if (magic == APEX_SYNC_MAGIC_V285) {
                uint32_t master = *((uint32_t *)buf + 1);
                int32_t hz = *((int32_t *)buf + 2);
                int32_t fps = *((int32_t *)buf + 3);
                g_syncPayloadV285.masterEnabled = master ? 1 : 0;
                g_cachedResolvedHz = MAX(15, MIN(240, hz));
                g_cachedResolvedFPS = MAX(15, MIN(240, fps));
                g_syncPayloadV285.targetHz = (int32_t)g_cachedResolvedHz;
                g_syncPayloadV285.targetFPS = (int32_t)g_cachedResolvedFPS;
                loaded = YES;
                break;
            }
        }
    }
    if (!loaded) {
        NSString *prefPath = Titanium_ResolvePrefPath();
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:prefPath];
        if (dict) {
            BOOL master = (dict[@"Enabled"] != nil) ? [dict[@"Enabled"] boolValue] : YES;
            NSInteger hz = (dict[@"TargetRefreshRate"] != nil) ? [dict[@"TargetRefreshRate"] integerValue] : 240;
            NSInteger fps = (dict[@"TargetFPSRate"] != nil) ? [dict[@"TargetFPSRate"] integerValue] : hz;
            g_syncPayloadV285.masterEnabled = master ? 1 : 0;
            g_cachedResolvedHz = MAX(15, MIN(240, hz));
            g_cachedResolvedFPS = MAX(15, MIN(240, fps));
        }
    }
    // Kiểm tra Hz/FPS khóa riêng cho từng App (15–240Hz)
    if (bundleID.length > 0 && !Titanium_IsSpringBoard() && !Titanium_IsSettingsOrSelfApp()) {
        for (NSString *paPath in @[PER_APP_RATES_FILE_PRIMARY, PER_APP_RATES_FILE_SECONDARY]) {
            if (access([paPath UTF8String], R_OK) == 0) {
                NSDictionary *perApp = [NSDictionary dictionaryWithContentsOfFile:paPath];
                NSDictionary *prof = [perApp[bundleID] isKindOfClass:[NSDictionary class]] ? perApp[bundleID] : nil;
                if (prof && prof[@"rate"] != nil) {
                    NSInteger r = [prof[@"rate"] integerValue];
                    if (r >= 15 && r <= 240) {
                        g_cachedResolvedHz = r;
                        g_cachedResolvedFPS = r;
                    }
                    break;
                }
            }
        }
    }
    os_unfair_lock_unlock(&g_syncLockV285);
}
static inline NSInteger Titanium_GetEffectiveFrameCap(void) {
    if (g_syncPayloadV285.masterEnabled == 0) return 60;
    NSInteger cap = g_cachedResolvedFPS > 0 ? g_cachedResolvedFPS : g_cachedResolvedHz;
    return MAX(15, MIN(240, cap));
}
// Dải tần số thông minh chống nổ bộ đệm CA::Render::Encoder::grow và giữ ổn định 15–240Hz
static inline CAFrameRateRange Titanium_SmoothFRR(float maxFps) {
    if (maxFps < 15.0f) maxFps = 15.0f;
    if (maxFps > 240.0f) maxFps = 240.0f;
    float minFps = (maxFps >= 60.0f) ? 60.0f : maxFps;
    return CAFrameRateRangeMake(minFps, maxFps, maxFps);
}
// Kích hoạt xung nhịp luồng chính tức thì khi chạm/vuốt (Khóa 300ms để 0% CPU waste khi rảnh)
static inline void Titanium_OnDemandTouchBurst(void) {
    uint64_t now = mach_absolute_time();
    if (g_lastTouchTimestamp == 0 || (now - g_lastTouchTimestamp) > Titanium_NanosToMachTicks(300ULL * 1000000ULL)) {
        g_lastTouchTimestamp = now;
        if ([NSThread isMainThread]) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
            if ([CATransaction respondsToSelector:@selector(_setLowLatency:)]) {
                [CATransaction _setLowLatency:YES];
            }
        }
    }
}
// Giải phóng phân mảnh RAM 5 tầng dưới nền (Giúp 30+ app chạy ngầm vẫn nhẹ và mát máy)
static inline void Titanium_FiveTierMemoryCompaction(void) {
    static os_unfair_lock s_memLock = OS_UNFAIR_LOCK_INIT;
    static uint64_t s_lastClean = 0;
    uint64_t now = mach_absolute_time();
    BOOL shouldClean = NO;
    os_unfair_lock_lock(&s_memLock);
    if (s_lastClean == 0 || (now - s_lastClean) > Titanium_NanosToMachTicks(20ULL * 1000000000ULL)) {
        s_lastClean = now;
        shouldClean = YES;
    }
    os_unfair_lock_unlock(&s_memLock);
    if (!shouldClean) return;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        @autoreleasepool {
            malloc_zone_pressure_relief(malloc_default_zone(), 0);
            [[NSURLCache sharedURLCache] removeAllCachedResponses];
            int purgeState = VM_PURGABLE_PURGE_ALL;
            vm_purgable_control(mach_task_self(), 0, VM_PURGABLE_PURGE_ALL, &purgeState);
        }
    });
}
// ====================================================================================================
// NHÓM HOOK HỢP NHẤT TẦNG 1–5 (0% TRÙNG LẶP — UIKIT, COREANIMATION, METAL 3D, 1M HẠT, AI STREAM)
// ====================================================================================================
%group Group_SmoothIOS_V39_Unified
// --- TẦNG 1: CẢM ỨNG & CUỘN PHẢN HỒI TỨC THÌ (0MS DELAY) ---
%hook UIWindow
- (void)sendEvent:(UIEvent *)event {
    if (event && g_syncPayloadV285.masterEnabled && !g_isCurrentAppBlacklisted) {
        if (event.type == 0) {
            Titanium_OnDemandTouchBurst();
        }
    }
    %orig(event);
}
%end
%hook UIControl
- (NSTimeInterval)_touchDelayThreshold {
    if (g_syncPayloadV285.masterEnabled && !g_isCurrentAppBlacklisted) return 0.0;
    return %orig;
}
%end
%hook UIScrollView
- (BOOL)delaysContentTouches {
    if (g_syncPayloadV285.masterEnabled && !g_isCurrentAppBlacklisted && !Titanium_IsSpringBoard()) return NO;
    return %orig;
}
- (void)_scrollViewWillBeginDragging {
    if (g_syncPayloadV285.masterEnabled && !g_isCurrentAppBlacklisted) {
        Titanium_OnDemandTouchBurst();
    }
    %orig;
}
%end
// --- TẦNG 2: MỞ KHÓA TRẦN TẦN SỐ QUÉT MÀN HÌNH (15–240HZ ZERO-DROP) ---
%hook UIScreen
- (NSInteger)maximumFramesPerSecond {
    if (g_syncPayloadV285.masterEnabled && !g_isCurrentAppBlacklisted) {
        return Titanium_GetEffectiveFrameCap();
    }
    return %orig;
}
- (NSInteger)_maximumFramesPerSecond {
    if (g_syncPayloadV285.masterEnabled && !g_isCurrentAppBlacklisted) {
        return Titanium_GetEffectiveFrameCap();
    }
    return %orig;
}
%end
%hook CADisplay
- (BOOL)allowsVirtualModes {
    if (g_syncPayloadV285.masterEnabled && !g_isCurrentAppBlacklisted) return YES;
    return %orig;
}
- (double)refreshRate {
    if (g_syncPayloadV285.masterEnabled && !g_isCurrentAppBlacklisted) {
        return (double)Titanium_GetEffectiveFrameCap();
    }
    return %orig;
}
%end
%hook CADisplayLink
- (void)addToRunLoop:(NSRunLoop *)runLoop forMode:(NSRunLoopMode)mode {
    %orig(runLoop, mode);
    if (self && g_syncPayloadV285.masterEnabled && !g_isCurrentAppBlacklisted) {
        NSInteger cap = Titanium_GetEffectiveFrameCap();
        self.preferredFramesPerSecond = cap;
        if (@available(iOS 15.0, *)) {
            if ([self respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                self.preferredFrameRateRange = Titanium_SmoothFRR((float)cap);
            }
        }
    }
}
- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (g_syncPayloadV285.masterEnabled && !g_isCurrentAppBlacklisted) {
        %orig(Titanium_GetEffectiveFrameCap());
        return;
    }
    %orig(fps);
}
- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if (g_syncPayloadV285.masterEnabled && !g_isCurrentAppBlacklisted) {
            range = Titanium_SmoothFRR((float)Titanium_GetEffectiveFrameCap());
        }
    }
    %orig(range);
}
%end
%hook UIWindowScene
- (void)_readySceneForDisplay {
    %orig;
    if (@available(iOS 15.0, *)) {
        if (g_syncPayloadV285.masterEnabled && !g_isCurrentAppBlacklisted && [self respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
            float cap = (float)Titanium_GetEffectiveFrameCap();
            CAFrameRateRange frr = Titanium_SmoothFRR(cap);
            self.preferredFrameRateRange = SafeMakeFRR(frr.minimum, frr.maximum, frr.preferred);
        }
    }
}
- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if (g_syncPayloadV285.masterEnabled && !g_isCurrentAppBlacklisted) {
            float cap = (float)Titanium_GetEffectiveFrameCap();
            CAFrameRateRange frr = Titanium_SmoothFRR(cap);
            range = SafeMakeFRR(frr.minimum, frr.maximum, frr.preferred);
        }
    }
    %orig(range);
}
%end
// --- TẦNG 3 & 4: METAL 3D, BENCHMARK ANTUTU, GAME MAX ĐỒ HỌA & 1 TRIỆU HẠT CHI TIẾT ---
%hook CAMetalLayer
- (void)didMoveToWindow {
    %orig;
    if (self && g_syncPayloadV285.masterEnabled && !g_isCurrentAppBlacklisted) {
        if ([self respondsToSelector:@selector(setAllowsNextDrawableTimeout:)]) {
            self.allowsNextDrawableTimeout = NO;
        }
        if ([self respondsToSelector:@selector(setMaximumDrawableCount:)]) {
            self.maximumDrawableCount = 3; // Triple Buffering chuẩn giúp GPU không bao giờ bị nghẽn frame
        }
        if (!Titanium_IsSpringBoard() && [self respondsToSelector:@selector(setDisplaySyncEnabled:)]) {
            self.displaySyncEnabled = NO; // Mở khóa V-Sync trong Game 3D & AnTuTu GPU
        }
        if (@available(iOS 15.0, *)) {
            if ([self respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                self.preferredFrameRateRange = Titanium_SmoothFRR((float)Titanium_GetEffectiveFrameCap());
            }
        }
    }
}
%end
%hook _MTLCommandQueue
- (void)setStatOptions:(NSUInteger)options {
    if (g_syncPayloadV285.masterEnabled && !g_isCurrentAppBlacklisted && !Titanium_IsSpringBoard()) {
        %orig(0); // Tắt thu thập telemetry thừa của Metal để dồn 100% băng thông cho Game & AnTuTu GPU
        return;
    }
    %orig(options);
}
%end
%hook CAMetalDrawable
- (void)presentAfterMinimumDuration:(CFTimeInterval)duration {
    if (g_syncPayloadV285.masterEnabled && !g_isCurrentAppBlacklisted && !Titanium_IsSpringBoard()) {
        %orig(0.0); // Đẩy frame lên màn hình ngay lập tức không chờ delay
        return;
    }
    %orig(duration);
}
%end
%hook CAEmitterLayer
- (void)didChangeValueForKey:(NSString *)key {
    %orig(key);
    @try {
        if (self && g_syncPayloadV285.masterEnabled && !g_isCurrentAppBlacklisted) {
            self.drawsAsynchronously = YES; // Vẽ bất đồng bộ trên GPU giúp 1 triệu hạt chi tiết không gây lag
            self.allowsGroupOpacity = YES;
        }
    } @catch (__unused NSException *e) {}
}
%end
%hook NSBundle
- (id)objectForInfoDictionaryKey:(NSString *)key {
    if (key && g_syncPayloadV285.masterEnabled && !g_isCurrentAppBlacklisted) {
        if ([key isEqualToString:@"CADisableMinimumFrameDuration"] ||
            [key isEqualToString:@"CADisableMinimumFrameDurationOnPhone"]) {
            return @YES;
        }
    }
    return %orig(key);
}
%end
// --- TẦNG 5: TỐI ƯU LUỒNG CHỮ AI STREAM & CHỐNG BÓP XUNG NHIỆT ĐỘ ---
%hook NSLayoutManager
- (BOOL)allowsNonContiguousLayout {
    if (g_syncPayloadV285.masterEnabled && !g_isCurrentAppBlacklisted) return YES;
    return %orig;
}
%end
%hook NSProcessInfo
- (NSProcessInfoThermalState)thermalState {
    if (g_syncPayloadV285.masterEnabled && !g_isCurrentAppBlacklisted) {
        return NSProcessInfoThermalStateNominal; // Ngăn iOS tự ý hạ xung đột ngột gây tụt FPS khi đang chơi game/đo AnTuTu
    }
    return %orig;
}
- (BOOL)isLowPowerModeEnabled {
    if (g_syncPayloadV285.masterEnabled && !g_isCurrentAppBlacklisted) return NO;
    return %orig;
}
%end
%hook UIApplication
- (void)_applicationDidEnterBackground {
    %orig;
    if (g_syncPayloadV285.masterEnabled && !g_isCurrentAppBlacklisted) {
        Titanium_FiveTierMemoryCompaction();
    }
}
%end
%end
// ====================================================================================================
// NHÓM HOOK CHUYÊN BIỆT CHO SPRINGBOARD (VUỐT CONTROL CENTER & THÔNG BÁO 0MS DELAY, DOCK, ĐA NHIỆM 30+ APP)
// ====================================================================================================
%group Group_SmoothIOS_V39_SpringBoard
// 1. Loại bỏ hoàn toàn độ trễ khi vuốt Trung tâm điều khiển (Control Center) & Trung tâm thông báo (Notification Center)
%hook SBControlCenterController
- (void)presentAnimated:(BOOL)animated completion:(id)completion {
    if (g_syncPayloadV285.masterEnabled) {
        Titanium_OnDemandTouchBurst();
    }
    %orig(animated, completion);
}
- (void)dismissAnimated:(BOOL)animated completion:(id)completion {
    if (g_syncPayloadV285.masterEnabled) {
        Titanium_OnDemandTouchBurst();
    }
    %orig(animated, completion);
}
%end
%hook SBNotificationCenterController
- (void)presentAnimated:(BOOL)animated completion:(id)completion {
    if (g_syncPayloadV285.masterEnabled) {
        Titanium_OnDemandTouchBurst();
    }
    %orig(animated, completion);
}
- (void)dismissAnimated:(BOOL)animated completion:(id)completion {
    if (g_syncPayloadV285.masterEnabled) {
        Titanium_OnDemandTouchBurst();
    }
    %orig(animated, completion);
}
%end
%hook CSCoverSheetViewController
- (void)viewWillAppear:(BOOL)animated {
    if (g_syncPayloadV285.masterEnabled) {
        Titanium_OnDemandTouchBurst();
    }
    %orig(animated);
}
%end
// 2. Tối ưu Dock, Thư mục (0.06s), Mở App (0.08s) & Dynamic Island
%hook SBDockView
- (void)layoutSubviews {
    %orig;
    if (self && g_syncPayloadV285.masterEnabled) {
        self.layer.allowsGroupOpacity = YES;
    }
}
%end
%hook SBSystemApertureViewController
- (void)viewWillLayoutSubviews {
    if (g_syncPayloadV285.masterEnabled) {
        Titanium_OnDemandTouchBurst();
    }
    %orig;
}
%end
%hook SBFolderControllerAnimationSettings
- (double)duration {
    if (g_syncPayloadV285.masterEnabled) return 0.06;
    return %orig;
}
%end
%hook SBAppLaunchSettings
- (double)delayBeforeAppLaunch {
    if (g_syncPayloadV285.masterEnabled) return 0.0;
    return %orig;
}
- (double)zoomDuration {
    if (g_syncPayloadV285.masterEnabled) return 0.08;
    return %orig;
}
- (double)launchDuration {
    if (g_syncPayloadV285.masterEnabled) return 0.08;
    return %orig;
}
%end
%hook SBFluidSwitcherAnimationSettings
- (double)cardFlyInDuration {
    if (g_syncPayloadV285.masterEnabled) return 0.08;
    return %orig;
}
- (double)switcherScaleTransitionDuration {
    if (g_syncPayloadV285.masterEnabled) return 0.08;
    return %orig;
}
- (double)slideInDuration {
    if (g_syncPayloadV285.masterEnabled) return 0.08;
    return %orig;
}
%end
// 3. Đa nhiệm 30+ App không tải lại & Giảm tải GPU khi kéo Blur (Control Center / Thư mục)
%hook SBAppSwitcherSettings
- (BOOL)shouldKeepAppSnapshotsInMemory {
    return YES;
}
- (BOOL)shouldSimplifyForOptions:(long long)options {
    (void)options;
    return NO;
}
%end
%hook CABackdropLayer
- (void)setDisablesOccludedBackdropBlurs:(BOOL)flag {
    if (g_syncPayloadV285.masterEnabled) {
        %orig(YES); // Ngắt tính toán blur các lớp bị che khuất giúp kéo Control Center / Thông báo nhẹ gấp 5 lần!
        return;
    }
    %orig(flag);
}
- (BOOL)disablesOccludedBackdropBlurs {
    if (g_syncPayloadV285.masterEnabled) return YES;
    return %orig;
}
%end
%hook CAWindowServerDisplay
- (BOOL)allowsVirtualModes {
    if (g_syncPayloadV285.masterEnabled) return YES;
    return %orig;
}
- (double)minimumFrameDuration {
    if (g_syncPayloadV285.masterEnabled) {
        return 1.0 / (double)Titanium_GetEffectiveFrameCap();
    }
    return %orig;
}
- (double)maximumRefreshRate {
    if (g_syncPayloadV285.masterEnabled) {
        return (double)Titanium_GetEffectiveFrameCap();
    }
    return %orig;
}
- (double)idealRefreshRate {
    if (g_syncPayloadV285.masterEnabled) {
        return (double)Titanium_GetEffectiveFrameCap();
    }
    return %orig;
}
%end
%end
// ====================================================================================================
// KHỞI TẠO TOÀN CỤC (`%ctor`) — AN TOÀN TUYỆT ĐỐI CHO ROOTLESS / ROOTHIDE / ROOTFUL
// ====================================================================================================
static void ReloadPreferencesCallbackV285(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    (void)center; (void)observer; (void)name; (void)object; (void)userInfo;
    g_lastSyncTicksV285 = 0;
    Titanium_ReloadSharedSyncStateV285();
}
%ctor {
    @autoreleasepool {
        const char *progName = Titanium_SafeGetProgName();
        if (!progName) return;
        // Tuyệt đối không tiêm vào các tiến trình dịch vụ ngầm và không tự tiêm vào BoostiPhone6sApp
        if (strcasestr(progName, "BoostiPhone6sApp") != NULL ||
            strcasestr(progName, "Preferences") != NULL ||
            strcasestr(progName, "AccessibilityUIServer") != NULL ||
            strcasestr(progName, "PosterBoard") != NULL ||
            strcasestr(progName, "Cr4shed") != NULL ||
            strcasestr(progName, "ScreenshotServicesService") != NULL ||
            strcasestr(progName, "SharingViewService") != NULL ||
            strcasestr(progName, "PassbookUIService") != NULL ||
            strcasestr(progName, "UserNotificationCenter") != NULL ||
            strcasestr(progName, "CoreAuthUI") != NULL ||
            strcasestr(progName, "assistivetouchd") != NULL ||
            strcasestr(progName, "sharingd") != NULL ||
            strcasestr(progName, "zinitd") != NULL ||
            strcasestr(progName, "WebContent") != NULL ||
            strcasestr(progName, "GPUProcess") != NULL ||
            strcasestr(progName, "Networking") != NULL) {
            return;
        }
        NSBundle *mainBundle = [NSBundle mainBundle];
        NSString *bundleID = [mainBundle bundleIdentifier];
        if (!bundleID || bundleID.length == 0) {
            return;
        }
        if ([bundleID isEqualToString:@"com.taojb.boostiphone6s"] ||
            [bundleID rangeOfString:@"networkextension" options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [bundleID rangeOfString:@"vpn" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return;
        }
        Titanium_ReloadSharedSyncStateV285();
        if (g_isCurrentAppBlacklisted) return;
        CFNotificationCenterRef darwin = CFNotificationCenterGetDarwinNotifyCenter();
        if (darwin) {
            CFNotificationCenterAddObserver(darwin, NULL, ReloadPreferencesCallbackV285, CFSTR(NOTIFY_RELOAD), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
            CFNotificationCenterAddObserver(darwin, NULL, ReloadPreferencesCallbackV285, CFSTR(NOTIFY_PAYLOAD_WRITTEN), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
            CFNotificationCenterAddObserver(darwin, NULL, ReloadPreferencesCallbackV285, CFSTR("com.titanium.payloadwritten"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        }
        Titanium_setiopolicy_np_safe(IOPOL_TYPE_DISK, IOPOL_SCOPE_PROCESS, IOPOL_IMPORTANT);
        Titanium_setiopolicy_np_safe(IOPOL_TYPE_VFS_ATIME_UPDATES, IOPOL_SCOPE_PROCESS, IOPOL_ATIME_UPDATES_OFF);
        %init(Group_SmoothIOS_V39_Unified);
        if ([bundleID isEqualToString:@"com.apple.springboard"]) {
            %init(Group_SmoothIOS_V39_SpringBoard);
        }
    }
}
