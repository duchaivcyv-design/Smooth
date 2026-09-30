#import <mach/mach.h>
#import <mach/mach_host.h>
#import <mach/mach_time.h>
#import <mach/mach_types.h>
#import <mach/vm_map.h>
#import <mach/vm_region.h>
#import <mach/vm_statistics.h>
#import <mach/vm_types.h>
#import <mach/thread_act.h>
#import <mach/thread_policy.h>
#import <mach/task.h>
#import <mach/task_info.h>
#import <mach/clock.h>
#import <pthread.h>
#import <pthread/qos.h>
#import <sched.h>
#import <unistd.h>
#import <stdlib.h>
#import <string.h>
#import <spawn.h>
#import <sys/sysctl.h>
#import <sys/resource.h>
#import <sys/utsname.h>
#import <sys/wait.h>
#import <sys/mman.h>
#import <sys/stat.h>
#import <sys/types.h>
#import <fcntl.h>
#import <dlfcn.h>
#import <malloc/malloc.h>
#import <CommonCrypto/CommonDigest.h>
#import <notify.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <QuartzCore/CAFrameRateRange.h>
#import <AVFoundation/AVFoundation.h>
#import <Metal/Metal.h>
#import <WebKit/WebKit.h>
#import <IOKit/IOKitLib.h>

// ============================================================================
// KHAI BÁO CÁC HÀM / MACRO PRIVATE CỦA XNU KERNEL & DARWIN TRÁNH LỖI BIÊN DỊCH
// ============================================================================#ifndef VM_PURGABLE_PURGE_ALL
#ifndef VM_PURGABLE_PURGE_ALL
#define VM_PURGABLE_PURGE_ALL 0
#endif

#ifndef VM_FLAGS_PURGABLE
#define VM_FLAGS_PURGABLE 1
#endif

#ifdef __cplusplus
extern "C" {
#endif
    kern_return_t vm_purgable_control(mach_port_t task, vm_address_t address, vm_purgable_t control, int *state);
    const char *getprogname(void);
    extern char **environ;
#ifdef __cplusplus
}
#endif

#ifndef UIWindowSceneActivationState_DEFINED
#define UIWindowSceneActivationState_DEFINED
typedef NS_ENUM(NSInteger, UIWindowSceneActivationState) {
    UIWindowSceneActivationStateUnspecified = -1,
    UIWindowSceneActivationStateForegroundActive = 0,
    UIWindowSceneActivationStateForegroundInactive = 1,
    UIWindowSceneActivationStateBackground = 2
};
#endif

#define PREF_DOMAIN CFSTR("com.taojb.boostiphone6s")
#define SHARED_SYNC_FILE @"/tmp/.boost_hz_sync"
#define NOTIFY_RELOAD "com.taojb.boostiphone6s/ReloadPrefs"
#define NOTIFY_UIKIT_RELOAD "com.taojb.boostiphone6s/ReloadUIKitPrefs"
#define NOTIFY_HARDWARE_SYNC "com.taojb.boostiphone6s/HardwareSync"

#import "Modules/CrashGuard.h"
#import "Modules/CacheCleaner.h"
#import "Modules/SmartThermal.h"
#import "Modules/KernelBypass.h"
#import "Modules/SystemBlocker.h"
#import "Modules/DeepExploit.h"

// ========================================================
// HỖ TRỢ ĐƯỜNG DẪN TƯƠNG THÍCH ROOTLESS & ROOTHIDE
// ========================================================
static inline NSString *Titanium_GetRootHidePrefixPath(void) {
    static NSString *cachedJbRoot = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Dl_info info;
        if (dladdr((const void *)Titanium_GetRootHidePrefixPath, &info) && info.dli_fname) {
            NSString *dylibPath = [NSString stringWithUTF8String:info.dli_fname];
            NSRange range = [dylibPath rangeOfString:@"/var/jb"];
            if (range.location != NSNotFound) {
                NSRange sub = [dylibPath rangeOfString:@"/" options:0 range:NSMakeRange(range.location + 7, dylibPath.length - (range.location + 7))];
                if (sub.location != NSNotFound) {
                    cachedJbRoot = [dylibPath substringToIndex:sub.location];
                } else {
                    cachedJbRoot = @"/var/jb";
                }
            } else {
                cachedJbRoot = @"/var/jb";
            }
        } else {
            cachedJbRoot = @"/var/jb";
        }
    });
    return cachedJbRoot;
}

static inline NSString *Titanium_GetPrefPath(NSString *path) {
    if (!path) return @"";
    NSString *root = Titanium_GetRootHidePrefixPath();
    if ([root isEqualToString:@"/var/jb"] && ![[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb"]) {
        return path;
    }
    return [root stringByAppendingPathComponent:path];
}

static inline NSString *Titanium_ResolvePrefPath(void) {
    NSString *root = Titanium_GetRootHidePrefixPath();
    NSString *p1 = [NSString stringWithFormat:@"%@/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist", root];
    if ([[NSFileManager defaultManager] fileExistsAtPath:p1]) return p1;
    NSString *p2 = @"/var/jb/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist";
    if ([[NSFileManager defaultManager] fileExistsAtPath:p2]) return p2;
    return p1;
}

static inline BOOL Titanium_IsRootlessOrRootHideEnvironment(void) {
    NSString *root = Titanium_GetRootHidePrefixPath();
    if (!root || [root length] == 0) return NO;
    if ([root containsString:@"/var/jb"]) return YES;
    if ([[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb"]) return YES;
    return NO;
}

@interface BoostConfigV261 : NSObject
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, strong) NSString *selectedLanguage;
@property (nonatomic, assign) BOOL enableHzControl;
@property (nonatomic, assign) NSInteger targetHz;
@property (nonatomic, assign) BOOL enableFPSControl;
@property (nonatomic, assign) NSInteger targetFPS;
@property (nonatomic, assign) BOOL forceOverclock144Hz;
@property (nonatomic, assign) BOOL proMotionEngineBeta7;
@property (nonatomic, assign) BOOL touchResponseBoost;
@property (nonatomic, assign) BOOL colorOs17SmoothEngine;
@property (nonatomic, assign) BOOL keyboardZeroLagV24;
@property (nonatomic, assign) BOOL keyboardZeroLagV3;
@property (nonatomic, assign) BOOL reduceMultitaskLag;
@property (nonatomic, assign) BOOL reduceMultiTaskLag;
@property (nonatomic, assign) BOOL metalHexBuffering;
@property (nonatomic, assign) BOOL neuralBufferOpt;
@property (nonatomic, assign) BOOL fixAppExitStutter;
@property (nonatomic, assign) BOOL vsyncAdaptiveBuffer;
@property (nonatomic, assign) BOOL quantumRenderShield;
@property (nonatomic, assign) BOOL autoCloseBackgroundApp;
@property (nonatomic, assign) BOOL fixAppLaunchBlackScreen;
@property (nonatomic, assign) BOOL syncModuleDelay;
@property (nonatomic, assign) BOOL isolateRenderPipeline;
@property (nonatomic, assign) BOOL antiBlackScreenLaunch;
@property (nonatomic, assign) BOOL turboAppLaunch;
@property (nonatomic, assign) BOOL turboLaunch;
@property (nonatomic, assign) BOOL ultraResponsiveness;
@property (nonatomic, assign) BOOL ultraResponsivenessProEngineOfficial;
@property (nonatomic, assign) BOOL aggressiveRamClean;
@property (nonatomic, assign) BOOL periodicRamClean;
@property (nonatomic, assign) BOOL machVMPurgeRam;
@property (nonatomic, assign) BOOL antiThermalThrottling;
@property (nonatomic, assign) BOOL antiThermalThrottle;
@property (nonatomic, assign) BOOL powerSaveMode;

+ (instancetype)sharedInstance;
- (void)loadSettings;
- (BOOL)isCustomHzEnabled;
- (NSInteger)resolvedTargetHz;
- (NSInteger)resolvedTargetFPS;
@end

@interface SBApplication : NSObject
- (NSString *)bundleIdentifier;
- (id)processState;
@end

@interface SBApplicationController : NSObject
+ (instancetype)sharedInstance;
- (NSArray *)allApplications;
- (SBApplication *)applicationWithBundleIdentifier:(NSString *)bundleIdentifier;
@end

@interface FBProcessState : NSObject
- (int)pid;
- (BOOL)isRunning;
- (BOOL)isForeground;
@end

@interface FBApplicationProcess : NSObject
- (void)bootstrapWithContext:(id)context completion:(id)completion;
- (void)launchIfNecessary;
- (void)_finishInit;
@end

@interface SBWindowScene : NSObject
- (void)_readySceneForDisplay;
@end

@interface UIWindow (ApexV261Revolution)
- (void)_setSecure:(BOOL)arg1;
- (BOOL)_isSecure;
- (UIWindowScene *)windowScene;
- (UIScreen *)screen;
- (UIViewController *)rootViewController;
@end

@interface CALayer (ApexV261Revolution)
- (id)context;
- (void)setContext:(id)arg1;
- (void)setAllowsEdgeAntialiasing:(BOOL)flag;
- (void)setContentsDrawsAsynchronously:(BOOL)flag;
- (void)setNeedsDisplayOnBoundsChange:(BOOL)flag;
@end

@class CADisplay;

@interface UIScreen (ApexV261Revolution)
- (void)_setTargetRefreshRate:(CGFloat)rate;
- (NSInteger)_maximumFramesPerSecond;
- (CGFloat)_refreshRate;
- (CADisplay *)_display;
@end

@interface CADisplay : NSObject
+ (CADisplay *)mainDisplay;
@property (nonatomic, readonly) NSArray *availableModes;
@property (nonatomic, retain) id currentMode;
@property (nonatomic, copy) NSString *colorMode;
@property (nonatomic) NSInteger preferredFPS;
@property (nonatomic) NSInteger preferredModeIndex;
- (void)overrideDisplayTimings:(id)timings;
- (void)overrideDisplayCadence:(id)cadence;
@end

@interface CAContext : NSObject
+ (NSArray *)allContexts;
+ (id)remoteContextWithOptions:(id)arg1;
- (uint32_t)contextId;
- (void)setCommitPriority:(uint32_t)priority;
- (void)setDesiredDynamicRange:(float)range;
- (void)orderAbove:(uint32_t)contextId;
@end

@interface PGPictureInPictureRemoteObject : NSObject
- (void)_updatePreferredContentSize;
- (void)startPictureInPicture;
- (void)stopPictureInPictureAnimated:(BOOL)animated;
- (void)setPictureInPictureShouldStartWhenEnteringBackground:(BOOL)arg1;
@end

@interface SBPIPController : NSObject
- (void)setPictureInPictureWindowMargin:(UIEdgeInsets)arg1;
- (void)_updatePictureInPictureWindowMargin;
- (UIEdgeInsets)pictureInPictureWindowMargin;
@end

@interface AVPictureInPictureController : NSObject
- (void)startPictureInPicture;
- (void)stopPictureInPicture;
- (BOOL)isPictureInPicturePossible;
- (BOOL)isPictureInPictureActive;
- (BOOL)isPictureInPictureSuspended;
@end

@interface UIScrollView (ApexV261Revolution)
- (void)_smoothScrollWithVelocity:(CGPoint)velocity targetContentOffset:(CGPoint)targetContentOffset;
- (BOOL)_isScrolling;
- (void)_setContentOffsetPinned:(CGPoint)point;
- (void)_setInterruptionImpulse:(CGPoint)impulse;
- (void)_forcePanGestureToEndImmediately;
- (CGPoint)_touchPositionForTouches:(id)touches;
@end

@interface CAMetalLayer (ApexV261Revolution)
- (void)setLowLatencyMode:(BOOL)flag;
- (void)setMaximumDrawableCount:(NSUInteger)count;
- (void)setDisplaySyncEnabled:(BOOL)enabled;
- (void)setAllowsNextDrawableTimeout:(BOOL)allow;
- (void)setPresentsWithTransaction:(BOOL)flag;
- (void)setServerPresentsWithTransaction:(BOOL)flag;
@end

@interface UIKeyboardImpl : UIView
+ (instancetype)activeInstance;
- (void)handleKeyWithString:(id)string forKeyEvent:(id)event executionContext:(id)context;
- (void)addInputString:(id)string withFlags:(NSUInteger)flags executionContext:(id)context;
- (void)clearAnimations;
- (void)setReturnKeyEnabled:(BOOL)enabled;
- (void)updateReturnKey:(BOOL)enabled;
- (void)hardwareKeyboardAvailabilityChanged;
- (void)setAutomaticMinimizationEnabled:(BOOL)flag;
@end

@interface UITextInputController : NSObject
- (void)_insertText:(id)text;
- (void)deleteBackward;
@end

@interface SBIconController : NSObject
+ (instancetype)sharedInstance;
- (void)scrollToIconListAtIndex:(NSInteger)index animate:(BOOL)animate;
- (void)viewWillLayoutSubviews;
- (void)viewDidLayoutSubviews;
- (id)model;
@end

@interface SBFloatingDockController : NSObject
- (void)layoutFloatingDock;
- (void)dismissFloatingDockIfPresentedAnimated:(BOOL)animated completionHandler:(id)completion;
@end

@interface SBBacklightController : NSObject
+ (instancetype)sharedInstance;
- (void)setBacklightFactor:(float)factor;
- (float)backlightFactor;
@end

@interface SBVolumeControl : NSObject
+ (instancetype)sharedInstance;
- (void)increaseVolume;
- (void)decreaseVolume;
@end

@interface SBMediaController : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isPlaying;
- (BOOL)isPaused;
@end

@interface SBMainDisplaySceneLayoutViewController : UIViewController
- (void)viewWillLayoutSubviews;
- (void)viewDidLayoutSubviews;
@end

@interface SBHomeHardwareButtonActions : NSObject
- (void)performSinglePressAction;
- (void)performDoublePressAction;
- (void)performTriplePressAction;
- (void)performLongPressCancelled;
@end

@interface SBLockScreenManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isUILocked;
- (void)unlockUIFromSource:(int)source withOptions:(id)options;
- (void)lockUIFromSource:(int)source withOptions:(id)options;
@end

@interface SBControlCenterController : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isVisible;
- (void)presentAnimated:(BOOL)animated;
- (void)dismissAnimated:(BOOL)animated;
@end

@interface SBNotificationCenterController : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isVisible;
- (void)presentAnimated:(BOOL)animated;
- (void)dismissAnimated:(BOOL)animated;
@end

@interface SBWallpaperController : NSObject
+ (instancetype)sharedInstance;
- (void)beginRequiringWithReason:(id)reason;
- (void)endRequiringWithReason:(id)reason;
@end

@interface SBFView : UIView
- (void)setCustomFullHomedStyle:(BOOL)flag;
@end

@interface SBFolderView : UIView
- (void)layoutSubviews;
- (void)scrollViewDidScroll:(id)scrollView;
- (void)willAnimate;
@end

@interface SBIconListView : UIView
- (void)layoutIconsNow;
- (void)layoutSubviews;
- (void)setAlphaForAllIcons:(double)alpha;
@end

@interface SBIconView : UIView
- (void)setIconImageInfo:(id)info;
- (void)setHighlighted:(BOOL)highlighted;
- (void)setTouchDownInIcon:(BOOL)touchDown;
- (void)setAllowsCloseBox:(BOOL)allows;
@end

@interface SBFluidSwitcherViewController : UIViewController
- (void)viewWillLayoutSubviews;
- (void)viewDidLayoutSubviews;
- (id)layoutState;
@end

@interface SBAppSwitcherSettings : NSObject
- (void)setDeckSwitcherPageScale:(double)scaleValue;
- (double)deckSwitcherPageScale;
@end

@interface BSSimpleAssertion : NSObject
- (void)invalidate;
@end

@interface FBScene : NSObject
- (id)identifier;
- (id)settings;
@end

@interface FBProcess : NSObject
- (int)pid;
- (id)workspace;
- (id)bundleIdentifier;
@end

@interface RBSProcessIdentity : NSObject
- (id)embeddedApplicationIdentifier;
@end

@interface RBSProcessHandle : NSObject
+ (instancetype)currentProcess;
- (RBSProcessIdentity *)identity;
@end

@interface RBSLaunchRequest : NSObject
- (BOOL)execute:(out id *)outContext error:(out id *)outError;
@end

@interface SBMainWorkspace : NSObject
+ (instancetype)sharedInstance;
- (void)_handleApplicationProcessExited:(id)processDescription;
- (void)handleApplicationLaunch:(id)application;
- (void)handleApplicationSuspended:(id)application;
@end

@interface SBAppSwitcherController : UIViewController
- (void)switcherContentController:(id)contentController deletedItem:(id)deletedItem;
@end

@interface UIStatusBar : UIView
- (void)requestStyle:(long long)style animated:(BOOL)animated;
- (void)forceUpdateData:(BOOL)animated;
@end

@interface UIStatusBarStyleAttributes : NSObject
- (long long)style;
@end

@interface SBStatusBarStyleOverridesAssertion : NSObject
- (void)invalidate;
@end

@interface SBReachabilityManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)reachabilityModeActive;
- (void)deactivateReachabilityMode;
@end

@interface SBDeviceApplicationSceneHandle : NSObject
- (id)scene;
- (BOOL)isDeviceApplicationSceneHandle;
@end

@interface SBApplicationSceneHandle : NSObject
- (id)application;
@end

@interface SBWorkspaceEntity : NSObject
- (id)application;
- (id)uniqueIdentifier;
@end

@interface SBSceneManager : NSObject
- (id)allScenes;
@end

@interface SBWindow : UIWindow
- (BOOL)_isSecure;
- (void)setHidden:(BOOL)hidden;
@end

@interface SBRootFolderView : UIView
- (void)layoutSubviews;
- (void)setNeedsLayout;
@end

@interface SBSwitcherAppSuggestionViewController : UIViewController
- (void)viewWillAppear:(BOOL)animated;
@end

@interface SBDeckSwitcherViewController : UIViewController
- (void)viewWillAppear:(BOOL)animated;
- (void)viewDidAppear:(BOOL)animated;
- (void)viewWillDisappear:(BOOL)animated;
- (void)viewDidDisappear:(BOOL)animated;
@end

@interface SBMainDisplayLayoutStateManager : NSObject
- (id)layoutState;
@end

@interface SBLayoutState : NSObject
- (id)elements;
@end

@interface SBLayoutElement : NSObject
- (id)uniqueIdentifier;
@end

@interface SBDisplayItem : NSObject
- (id)bundleIdentifier;
- (id)uniqueStringRepresentation;
@end

@interface SBFluidSwitcherItemContainer : UIView
- (void)setContentAlpha:(double)alpha;
@end

@interface SBHomeScreenViewController : UIViewController
- (void)viewWillAppear:(BOOL)animated;
- (void)viewDidAppear:(BOOL)animated;
@end

@interface SBDashBoardViewController : UIViewController
- (void)viewWillAppear:(BOOL)animated;
- (void)viewDidDisappear:(BOOL)animated;
@end

@interface CSCoverSheetViewController : UIViewController
- (void)viewWillAppear:(BOOL)animated;
- (void)viewDidDisappear:(BOOL)animated;
@end

@interface SBDisplayPowerLogReporter : NSObject
- (void)reportPowerLogEvent;
@end

@interface SBUIController : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isAppSwitcherShowing;
- (void)clickedMenuButton;
- (void)handleHomeButtonDoublePressDown;
@end

@interface SpringBoard : UIApplication
- (id)_accessibilityFrontMostApplication;
- (BOOL)isLocked;
- (void)_reboot:(BOOL)arg1;
- (void)_relaunchSpringBoardNow;
@end

@interface SBAttentionAwarenessClient : NSObject
- (void)setAttentionAwarenessConfiguration:(id)config;
- (void)resume;
- (void)suspend;
@end

@interface SBIdleTimerGlobalCoordinator : NSObject
+ (instancetype)sharedInstance;
- (void)resetIdleTimer;
@end

@interface SBAppLayout : NSObject
- (id)allItems;
- (long long)type;
@end

@interface SBFluidSwitcherGesture : NSObject
- (long long)type;
- (long long)state;
@end

@interface SBIconModel : NSObject
- (id)allInstalledApplications;
@end

@interface SBApplicationInfo : NSObject
- (NSString *)bundleIdentifier;
- (NSString *)displayName;
@end

#define APEX_SYNC_MAGIC_V261 0x56323631

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
    uint64_t updateSeq;
    uint64_t lastHeartbeat;
    char     reserved[64];
} ApexV261Payload;

static ApexV261Payload g_syncPayloadV261 = {
    APEX_SYNC_MAGIC_V261, 1, 60, 60, 0, 1, 1, 1, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, {0}
};

static pthread_mutex_t g_syncLockV261 = PTHREAD_MUTEX_INITIALIZER;
static volatile uint64_t g_lastSyncTicksV261 = 0;
static BOOL g_isDeviceChargingV261 = NO;
static volatile BOOL g_isUserTouchingV261 = NO;
static volatile CFTimeInterval g_lastTouchMediaTimeV261 = 0.0;
static volatile NSProcessInfoThermalState g_liveThermalStateV261 = NSProcessInfoThermalStateNominal;

// HÀM CHUẨN HÓA DẢI CAFrameRateRange: TRIỆT TIÊU SAFEMODE CHO TOÀN BỘ MỨC HZ LẺ
static inline CAFrameRateRange Titanium_NormalizeFrameRateRange(float target) {
    if (target < 15.0f) target = 15.0f;
    if (target > 144.0f) target = 144.0f;
    
    float minRate = 15.0f;
    if (target >= 120.0f) {
        minRate = 60.0f;
    } else if (target >= 60.0f) {
        minRate = 30.0f;
    } else if (target >= 30.0f) {
        minRate = 15.0f;
    } else {
        minRate = 10.0f;
    }
    
    if (minRate > target) {
        minRate = target;
    }
    return CAFrameRateRangeMake(minRate, target, target);
}

// NHẬN DIỆN THIẾT BỊ 16:9 NÚT HOME (6s / 7 / 8 / Plus / SE)
static inline BOOL Titanium_IsClassicHomeButtonDevice(void) {
    static BOOL sIsClassic = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        struct utsname sysInfo;
        uname(&sysInfo);
        NSString *dev = [NSString stringWithCString:sysInfo.machine encoding:NSUTF8StringEncoding];
        if ([dev containsString:@"iPhone8,"] || [dev containsString:@"iPhone9,"] || 
            [dev containsString:@"iPhone10,"] || [dev containsString:@"iPhone12,8"] || 
            [dev containsString:@"iPhone14,6"]) {
            sIsClassic = YES;
        }
    });
    return sIsClassic;
}

static BOOL Titanium_IsSpringBoard(void) {
    static BOOL isSB = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *proc = [[NSProcessInfo processInfo] processName];
        if (proc) isSB = [proc isEqualToString:@"SpringBoard"];
    });
    return isSB;
}

static BOOL Titanium_IsSettingsApp(void) {
    static BOOL isPrefs = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *name = [[NSProcessInfo processInfo] processName];
        if (name) {
            isPrefs = [name isEqualToString:@"Preferences"] || [name isEqualToString:@"Settings"] || [name isEqualToString:@"TweakSettings"];
        }
    });
    return isPrefs;
}

static inline BOOL Titanium_IsDeviceProMotionHardware(void) {
    return YES;
}

static inline void Titanium_SetThreadRealtimeConstraintV261(thread_t thread, uint32_t targetHz) {
    if (!thread) return;
    
    if (Titanium_IsSpringBoard()) {
        struct task_qos_policy qos;
        qos.task_latency_qos_tier = 0;
        qos.task_throughput_qos_tier = 0;
        task_policy_set(mach_task_self(), TASK_BASE_QOS_POLICY, (task_policy_t)&qos, TASK_QOS_POLICY_COUNT);
        return;
    }
    
    thread_extended_policy_data_t extendedPolicy;
    extendedPolicy.timeshare = 0;
    thread_policy_set(thread, THREAD_EXTENDED_POLICY, (thread_policy_t)&extendedPolicy, THREAD_EXTENDED_POLICY_COUNT);
    
    uint32_t hz = (targetHz > 0) ? targetHz : 120;
    uint32_t framePeriodNs = 1000000000 / hz;
    
    thread_time_constraint_policy_data_t timeConstraint;
    timeConstraint.period = framePeriodNs;
    timeConstraint.computation = framePeriodNs * 80 / 100;
    timeConstraint.constraint = framePeriodNs;
    timeConstraint.preemptible = 1;
    thread_policy_set(thread, THREAD_TIME_CONSTRAINT_POLICY, (thread_policy_t)&timeConstraint, THREAD_TIME_CONSTRAINT_POLICY_COUNT);
    
    thread_affinity_policy_data_t affinity;
    affinity.affinity_tag = 1;
    thread_policy_set(thread, THREAD_AFFINITY_POLICY, (thread_policy_t)&affinity, THREAD_AFFINITY_POLICY_COUNT);
}

// CƠ CHẾ XẢ SÂU RAM MÀ KHÔNG GÂY TẢI LẠI (RELOAD) APP
static inline void Titanium_PurgeProcessMemoryAggressively(void) {
    malloc_zone_pressure_relief(malloc_default_zone(), 0);
}

static void Titanium_WriteSyncPayloadV261(const ApexV261Payload *payload) {
    if (!payload) return;
    ApexV261Payload temp = *payload;
    temp.magic = APEX_SYNC_MAGIC_V261;
    temp.updateSeq = (uint64_t)mach_absolute_time();
    int fd = open([SHARED_SYNC_FILE UTF8String], O_WRONLY | O_CREAT | O_TRUNC, 0666);
    if (fd >= 0) {
        write(fd, &temp, sizeof(ApexV261Payload));
        close(fd);
        chmod([SHARED_SYNC_FILE UTF8String], 0666);
    }
}

static inline void Titanium_ReloadSharedSyncStateV261(void) {
    pthread_mutex_lock(&g_syncLockV261);
    int fd = open([SHARED_SYNC_FILE UTF8String], O_RDONLY);
    if (fd >= 0) {
        ApexV261Payload temp;
        ssize_t bytes = read(fd, &temp, sizeof(temp));
        if (bytes == sizeof(temp) && temp.magic == APEX_SYNC_MAGIC_V261) {
            if (temp.updateSeq != g_syncPayloadV261.updateSeq) {
                g_syncPayloadV261 = temp;
                g_lastSyncTicksV261 = mach_absolute_time();
            }
        }
        close(fd);
    } else {
        CFPreferencesAppSynchronize(PREF_DOMAIN);
        CFPropertyListRef enVal = CFPreferencesCopyAppValue(CFSTR("Enabled"), PREF_DOMAIN);
        if (enVal) {
            g_syncPayloadV261.masterEnabled = CFBooleanGetValue((CFBooleanRef)enVal) ? 1 : 0;
            CFRelease(enVal);
        }
        CFPropertyListRef hzVal = CFPreferencesCopyAppValue(CFSTR("TargetRefreshRate"), PREF_DOMAIN);
        if (hzVal) {
            int val = 120;
            CFNumberGetValue((CFNumberRef)hzVal, kCFNumberIntType, &val);
            g_syncPayloadV261.targetHz = (val > 0) ? val : 120;
            CFRelease(hzVal);
        }
        CFPropertyListRef fpsVal = CFPreferencesCopyAppValue(CFSTR("TargetFPSRate"), PREF_DOMAIN);
        if (fpsVal) {
            int val = 120;
            CFNumberGetValue((CFNumberRef)fpsVal, kCFNumberIntType, &val);
            g_syncPayloadV261.targetFPS = (val > 0) ? val : 120;
            CFRelease(fpsVal);
        }
        CFPropertyListRef overVal = CFPreferencesCopyAppValue(CFSTR("ForceOverclock144Hz"), PREF_DOMAIN);
        if (overVal) {
            g_syncPayloadV261.forceOverclock = CFBooleanGetValue((CFBooleanRef)overVal) ? 1 : 0;
            CFRelease(overVal);
        }
        CFPropertyListRef dynVal = CFPreferencesCopyAppValue(CFSTR("ProMotionEngineBeta7"), PREF_DOMAIN);
        if (dynVal) {
            g_syncPayloadV261.dynamicInterpolation = CFBooleanGetValue((CFBooleanRef)dynVal) ? 1 : 0;
            CFRelease(dynVal);
        }
        CFPropertyListRef touchVal = CFPreferencesCopyAppValue(CFSTR("TouchResponseBoost"), PREF_DOMAIN);
        if (touchVal) {
            g_syncPayloadV261.zeroLatencyTouch = CFBooleanGetValue((CFBooleanRef)touchVal) ? 1 : 0;
            CFRelease(touchVal);
        }
        CFPropertyListRef keyVal = CFPreferencesCopyAppValue(CFSTR("KeyboardZeroLagV24"), PREF_DOMAIN);
        if (keyVal) {
            g_syncPayloadV261.keyboardZeroLagV3 = CFBooleanGetValue((CFBooleanRef)keyVal) ? 1 : 0;
            CFRelease(keyVal);
        }
        CFPropertyListRef metalVal = CFPreferencesCopyAppValue(CFSTR("MetalHexBuffering"), PREF_DOMAIN);
        if (metalVal) {
            g_syncPayloadV261.smartBufferingLevel = 3;
            CFRelease(metalVal);
        }
        CFPropertyListRef exitVal = CFPreferencesCopyAppValue(CFSTR("FixAppExitStutter"), PREF_DOMAIN);
        if (exitVal) {
            g_syncPayloadV261.antiStutterExit = CFBooleanGetValue((CFBooleanRef)exitVal) ? 1 : 0;
            CFRelease(exitVal);
        }
        CFPropertyListRef launchVal = CFPreferencesCopyAppValue(CFSTR("TurboAppLaunch"), PREF_DOMAIN);
        if (launchVal) {
            g_syncPayloadV261.fastAppLaunch = CFBooleanGetValue((CFBooleanRef)launchVal) ? 1 : 0;
            CFRelease(launchVal);
        }
        CFPropertyListRef ramVal = CFPreferencesCopyAppValue(CFSTR("AggressiveRamClean"), PREF_DOMAIN);
        if (ramVal) {
            g_syncPayloadV261.aggressiveRamCleaner = CFBooleanGetValue((CFBooleanRef)ramVal) ? 1 : 0;
            CFRelease(ramVal);
        }
        CFPropertyListRef thermVal = CFPreferencesCopyAppValue(CFSTR("AntiThermalThrottling"), PREF_DOMAIN);
        if (thermVal) {
            g_syncPayloadV261.thermalShield = CFBooleanGetValue((CFBooleanRef)thermVal) ? 1 : 0;
            g_syncPayloadV261.lockFixedFpsWhenThermal = g_syncPayloadV261.thermalShield;
            CFRelease(thermVal);
        }
    }
    pthread_mutex_unlock(&g_syncLockV261);
}

// BỎ QUA TIẾN TRÌNH HỆ THỐNG NGUY HIỂM & POSTERBOARD (CHỐNG TREO ROOTHIDE & NÓNG MÁY HÌNH NỀN)
static BOOL Titanium_IsCriticalSystemDaemon(void) {
    static BOOL isDaemon = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *proc = [[NSProcessInfo processInfo] processName];
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
        if (proc) {
            if ([proc isEqualToString:@"launchd"] || [proc isEqualToString:@"jailbreakd"] || 
                [proc isEqualToString:@"backboardd"] || [proc isEqualToString:@"runningboardd"] || 
                [proc isEqualToString:@"containermanagerd"] || [proc isEqualToString:@"cfprefsd"] || 
                [proc isEqualToString:@"notifyd"] || [proc isEqualToString:@"Sileo"] || 
                [proc isEqualToString:@"Zebra"] || [proc isEqualToString:@"Filza"] || 
                [proc isEqualToString:@"NewTerm"] || [proc isEqualToString:@"Choicy"] || 
                [proc isEqualToString:@"installd"] || [proc isEqualToString:@"securityd"] || 
                [proc isEqualToString:@"mediaserverd"] || [proc isEqualToString:@"passd"] || 
                [proc isEqualToString:@"identityservicesd"] || [proc isEqualToString:@"PosterBoard"] || 
                [proc isEqualToString:@"tursd"] || [proc isEqualToString:@"roothided"] || 
                [proc isEqualToString:@"PosterBoardPosterExtension"] ||
                [proc isEqualToString:@"thermalmonitord"]) {
                isDaemon = YES;
                return;
            }
        }
        if (bundleId) {
            if ([bundleId containsString:@"org.coolstar.SileoStore"] || [bundleId containsString:@"xyz.willy.Zebra"] || 
                [bundleId containsString:@"com.tigisoftware.Filza"] || [bundleId containsString:@"com.apple.PosterBoard"] || 
                [bundleId containsString:@"com.roothide"] || [bundleId containsString:@"com.apple.WallpaperKit"]) {
                isDaemon = YES;
                return;
            }
        }
    });
    return isDaemon;
}

static BOOL Titanium_IsSecureBankingApp(void) {
    static BOOL isBank = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *procName = [[[NSProcessInfo processInfo] processName] lowercaseString];
        NSString *bundleId = [[[NSBundle mainBundle] bundleIdentifier] lowercaseString];
        NSArray *keywords = @[@"tpbank", @"tpb", @"vietcombank", @"vcb", @"techcombank", @"tcb", @"mbbank", @"mb", @"bidv", @"vietinbank", @"acb", @"vpbank", @"hdbank", @"shb", @"msb", @"vib", @"ocb", @"scb", @"seabank", @"bacabank", @"pvcombank", @"namabank", @"kienlongbank", @"vietbank", @"baovietbank", @"shinhan", @"hsbc", @"standardchartered", @"citi", @"momo", @"zalopay", @"shopeepay", @"viettelmoney", @"viettelpay", @"vnptpay", @"vnpay", @"cake", @"tnex", @"timoplus", @"finhay", @"tikop", @"digibank", @"ebank", @"ibanking", @"bank", @"pay", @"finance", @"wallet", @"smartotp", @"agribank", @"kbank", @"crypto", @"binance", @"trustwallet", @"metamask"];
        for (NSString *kw in keywords) {
            if ((bundleId && [bundleId containsString:kw]) || (procName && [procName containsString:kw])) {
                isBank = YES;
                break;
            }
        }
    });
    return isBank;
}

@implementation BoostConfigV261

+ (instancetype)sharedInstance {
    static BoostConfigV261 *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[self alloc] init];
    });
    return inst;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.enabled = YES;
        self.targetHz = 120;
        self.targetFPS = 120;
        self.enableHzControl = YES;
        self.enableFPSControl = YES;
        self.proMotionEngineBeta7 = YES;
        self.touchResponseBoost = YES;
        self.colorOs17SmoothEngine = YES;
        self.keyboardZeroLagV24 = YES;
        self.metalHexBuffering = YES;
        self.fixAppExitStutter = YES;
        self.fixAppLaunchBlackScreen = YES;
        self.antiThermalThrottling = YES;
        [self loadSettings];
    }
    return self;
}

- (BOOL)isCustomHzEnabled {
    return self.enabled && (self.enableHzControl || self.forceOverclock144Hz);
}

- (void)loadSettings {
    static BOOL s_isLoading = NO;
    if (s_isLoading) return;
    s_isLoading = YES;

    @autoreleasepool {
        CFPreferencesAppSynchronize(PREF_DOMAIN);
        id (^ReadLiveValue)(CFStringRef, id) = ^id(CFStringRef key, id defaultVal) {
            CFPropertyListRef val = CFPreferencesCopyAppValue(key, PREF_DOMAIN);
            if (val) return (__bridge_transfer id)val;
            return defaultVal;
        };
        
        NSDictionary *diskDict = nil;
        NSString *resolvedPath = Titanium_ResolvePrefPath();
        if (resolvedPath && [[NSFileManager defaultManager] fileExistsAtPath:resolvedPath]) {
            diskDict = [NSDictionary dictionaryWithContentsOfFile:resolvedPath];
        }
        
        BOOL (^GetLiveBool)(NSString *, BOOL) = ^BOOL(NSString *k, BOOL d) {
            id val = ReadLiveValue((__bridge CFStringRef)k, nil);
            if (val != nil) return [val boolValue];
            if (diskDict && diskDict[k] != nil) return [diskDict[k] boolValue];
            return d;
        };
        NSInteger (^GetLiveInt)(NSString *, NSInteger) = ^NSInteger(NSString *k, NSInteger d) {
            id val = ReadLiveValue((__bridge CFStringRef)k, nil);
            if (val != nil) return [val integerValue];
            if (diskDict && diskDict[k] != nil) return [diskDict[k] integerValue];
            return d;
        };
        NSString * (^GetLiveString)(NSString *, NSString *) = ^NSString *(NSString *k, NSString *d) {
            id val = ReadLiveValue((__bridge CFStringRef)k, nil);
            if (val != nil && [val isKindOfClass:[NSString class]]) return (NSString *)val;
            if (diskDict && diskDict[k] != nil && [diskDict[k] isKindOfClass:[NSString class]]) return (NSString *)diskDict[k];
            return d;
        };

        self.enabled = GetLiveBool(@"Enabled", YES);
        self.selectedLanguage = GetLiveString(@"SelectedLanguage", @"auto");
        self.enableHzControl = GetLiveBool(@"EnableHzControl", YES);
        self.targetHz = GetLiveInt(@"TargetRefreshRate", 120);
        self.enableFPSControl = GetLiveBool(@"EnableFPSControl", YES);
        self.targetFPS = GetLiveInt(@"TargetFPSRate", 120);
        self.forceOverclock144Hz = GetLiveBool(@"ForceOverclock144Hz", NO);
        self.proMotionEngineBeta7 = GetLiveBool(@"ProMotionEngineBeta7", YES);
        self.touchResponseBoost = GetLiveBool(@"TouchResponseBoost", YES);
        self.colorOs17SmoothEngine = GetLiveBool(@"ColorOs17SmoothEngine", YES);
        self.keyboardZeroLagV24 = GetLiveBool(@"KeyboardZeroLagV24", YES);
        self.keyboardZeroLagV3 = GetLiveBool(@"KeyboardZeroLagV24", YES);
        self.metalHexBuffering = GetLiveBool(@"MetalHexBuffering", YES);
        self.neuralBufferOpt = self.metalHexBuffering;
        self.fixAppExitStutter = GetLiveBool(@"FixAppExitStutter", YES);
        self.vsyncAdaptiveBuffer = self.fixAppExitStutter;
        self.quantumRenderShield = self.fixAppExitStutter;
        self.autoCloseBackgroundApp = self.fixAppExitStutter;
        self.fixAppLaunchBlackScreen = GetLiveBool(@"FixAppLaunchBlackScreen", YES);
        self.syncModuleDelay = self.fixAppLaunchBlackScreen;
        self.isolateRenderPipeline = self.fixAppLaunchBlackScreen;
        self.antiBlackScreenLaunch = self.fixAppLaunchBlackScreen;
        self.reduceMultitaskLag = GetLiveBool(@"ReduceMultiTaskLag", YES);
        self.reduceMultiTaskLag = self.reduceMultitaskLag;
        self.turboAppLaunch = GetLiveBool(@"TurboAppLaunch", YES);
        self.turboLaunch = self.turboAppLaunch;
        self.ultraResponsiveness = self.touchResponseBoost;
        self.ultraResponsivenessProEngineOfficial = self.touchResponseBoost;
        self.aggressiveRamClean = GetLiveBool(@"AggressiveRamClean", NO);
        self.periodicRamClean = self.aggressiveRamClean;
        self.machVMPurgeRam = self.aggressiveRamClean;
        self.antiThermalThrottling = GetLiveBool(@"AntiThermalThrottling", YES);
        self.antiThermalThrottle = self.antiThermalThrottling;
        self.powerSaveMode = GetLiveBool(@"PowerSaveMode", NO);

        if (!Titanium_IsSpringBoard() && !Titanium_IsSettingsApp()) {
            Titanium_ReloadSharedSyncStateV261();
            if (g_syncPayloadV261.magic == APEX_SYNC_MAGIC_V261) {
                self.enabled = g_syncPayloadV261.masterEnabled;
                self.targetHz = g_syncPayloadV261.targetHz;
                self.targetFPS = g_syncPayloadV261.targetFPS;
                self.forceOverclock144Hz = g_syncPayloadV261.forceOverclock;
                self.proMotionEngineBeta7 = g_syncPayloadV261.dynamicInterpolation ? YES : NO;
                self.touchResponseBoost = g_syncPayloadV261.zeroLatencyTouch ? YES : NO;
                self.ultraResponsiveness = self.touchResponseBoost;
                self.ultraResponsivenessProEngineOfficial = self.touchResponseBoost;
                self.keyboardZeroLagV24 = g_syncPayloadV261.keyboardZeroLagV3 ? YES : NO;
                self.keyboardZeroLagV3 = self.keyboardZeroLagV24;
                self.metalHexBuffering = YES;
                self.neuralBufferOpt = YES;
                self.fixAppExitStutter = g_syncPayloadV261.antiStutterExit ? YES : NO;
                self.vsyncAdaptiveBuffer = self.fixAppExitStutter;
                self.quantumRenderShield = self.fixAppExitStutter;
                self.autoCloseBackgroundApp = self.fixAppExitStutter;
                self.reduceMultitaskLag = self.fixAppExitStutter;
                self.reduceMultiTaskLag = self.reduceMultitaskLag;
                self.turboAppLaunch = g_syncPayloadV261.fastAppLaunch ? YES : NO;
                self.turboLaunch = self.turboAppLaunch;
                self.aggressiveRamClean = g_syncPayloadV261.aggressiveRamCleaner ? YES : NO;
                self.periodicRamClean = self.aggressiveRamClean;
                self.machVMPurgeRam = self.aggressiveRamClean;
                self.antiThermalThrottling = g_syncPayloadV261.thermalShield ? YES : NO;
                self.antiThermalThrottle = self.antiThermalThrottling;
            }
        } else if (Titanium_IsSpringBoard()) {
            ApexV261Payload p;
            memset(&p, 0, sizeof(ApexV261Payload));
            p.masterEnabled = self.enabled ? 1 : 0;
            p.targetHz = (int32_t)self.targetHz;
            p.targetFPS = (int32_t)self.targetFPS;
            p.forceOverclock = self.forceOverclock144Hz ? 1 : 0;
            p.pipSyncEnabled = 1;
            p.thermalShield = self.antiThermalThrottling ? 1 : 0;
            p.antiStutterExit = self.fixAppExitStutter ? 1 : 0;
            p.smartBufferingLevel = 3;
            p.zeroLatencyTouch = self.touchResponseBoost ? 1 : 0;
            p.shaderOptimization = 1;
            p.dynamicInterpolation = self.proMotionEngineBeta7 ? 1 : 0;
            p.fastAppLaunch = self.turboAppLaunch ? 1 : 0;
            p.keyboardZeroLagV3 = self.keyboardZeroLagV24 ? 1 : 0;
            p.aggressiveRamCleaner = self.aggressiveRamClean ? 1 : 0;
            p.lockFixedFpsWhenThermal = self.antiThermalThrottling ? 1 : 0;
            
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                Titanium_WriteSyncPayloadV261(&p);
            });
        }
    }
    s_isLoading = NO;
}

- (NSInteger)resolvedTargetHz {
    if (!self.enabled || !self.enableHzControl) return 120;
    
    UIDevice *dev = [UIDevice currentDevice];
    if (dev.batteryMonitoringEnabled) {
        float batLevel = dev.batteryLevel;
        if (batLevel > 0.0f && batLevel <= 0.20f && !g_isDeviceChargingV261) {
            return 60;
        }
    }
    
    if (self.powerSaveMode) return 30;
    if (self.forceOverclock144Hz) return 144;
    
    if (g_liveThermalStateV261 >= NSProcessInfoThermalStateSerious && self.antiThermalThrottling) {
        return 60;
    }
    
    if (self.targetHz >= 15 && self.targetHz <= 144) return self.targetHz;
    return 120;
}

- (NSInteger)resolvedTargetFPS {
    if (!self.enabled || !self.enableFPSControl) return 120;
    
    UIDevice *dev = [UIDevice currentDevice];
    if (dev.batteryMonitoringEnabled) {
        float batLevel = dev.batteryLevel;
        if (batLevel > 0.0f && batLevel <= 0.20f && !g_isDeviceChargingV261) {
            return 60;
        }
    }
    
    if (self.powerSaveMode) return 30;
    if (self.forceOverclock144Hz) return 144;
    
    if (g_liveThermalStateV261 >= NSProcessInfoThermalStateSerious && self.antiThermalThrottling) {
        return 60;
    }
    
    if (self.targetFPS >= 15 && self.targetFPS <= 144) return self.targetFPS;
    return 120;
}
@end

static BoostConfigV261 *CFG261 = nil;
#define IS_ACTIVE (CFG261.enabled)

static BOOL g_ApexRenderPipelineReady = YES;

// FIX LỖI 7: TỐC ĐỘ LOADING APP NHANH TỨC THÌ
%group Group_FastLaunch_SuperEngineV261

%hook FBApplicationProcess
- (void)bootstrapWithContext:(id)context completion:(id)completion {
    if (IS_ACTIVE && CFG261.turboAppLaunch) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(context, completion);
}

- (void)launchIfNecessary {
    if (IS_ACTIVE && CFG261.turboAppLaunch) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}
%end

%hook FBProcess
- (void)killForReason:(long long)reason andReport:(BOOL)report withDescription:(id)description completion:(id)completion {
    if (IS_ACTIVE && CFG261.fixAppExitStutter) {
        Titanium_PurgeProcessMemoryAggressively();
    }
    %orig(reason, report, description, completion);
}
%end

%hook RBSLaunchRequest
- (BOOL)execute:(id *)outContext error:(id *)outError {
    return %orig(outContext, outError);
}
%end

%hook UIApplication
- (void)_runWithMainScene:(id)scene transitionContext:(id)context completion:(id)completion {
    if (IS_ACTIVE && CFG261.turboAppLaunch) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(scene, context, completion);
}

- (BOOL)_handleDelegateCallbacksWithOptions:(id)options isSuspended:(BOOL)suspended restoreState:(BOOL)restoreState {
    if (IS_ACTIVE && CFG261.turboAppLaunch) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    return %orig(options, suspended, restoreState);
}
%end

%end

%group Group_V261_FloatingWindow_PiP
%hook PGPictureInPictureRemoteObject
- (void)_updatePreferredContentSize {
    %orig;
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
}

- (void)startPictureInPicture {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)stopPictureInPictureAnimated:(BOOL)animated {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(animated);
}

- (void)setPictureInPictureShouldStartWhenEnteringBackground:(BOOL)shouldStart {
    %orig(shouldStart);
}

- (BOOL)isStartingStoppingOrCancellingPictureInPicture {
    return %orig;
}

- (void)setSuspended:(BOOL)suspended {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(suspended);
}
%end

%hook SBPIPController
- (void)setPictureInPictureWindowMargin:(UIEdgeInsets)arg1 {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(arg1);
}

- (void)_updatePictureInPictureWindowMargin {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (UIEdgeInsets)pictureInPictureWindowMargin {
    return %orig;
}

- (void)startPictureInPictureForApplicationWithProcessIdentifier:(int)pid sceneIdentifier:(id)sceneId animated:(BOOL)animated completionHandler:(id)completion {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(pid, sceneId, animated, completion);
}

- (void)cancelPictureInPictureForApplicationWithProcessIdentifier:(int)pid sceneIdentifier:(id)sceneId {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(pid, sceneId);
}
%end

%hook AVPictureInPictureController
- (void)startPictureInPicture {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)stopPictureInPicture {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (BOOL)isPictureInPicturePossible {
    return %orig;
}

- (BOOL)isPictureInPictureActive {
    return %orig;
}

- (BOOL)isPictureInPictureSuspended {
    return %orig;
}

- (void)setRequiresLinearPlayback:(BOOL)requiresLinearPlayback {
    %orig(requiresLinearPlayback);
}

- (BOOL)canStopPictureInPicture {
    return %orig;
}
%end
%end

// FIX LỖI 1 & 2: ÉP HZ/FPS HOẠT ĐỘNG TOÀN DIỆN CHO SPRINGBOARD, CC, NC VÀ KHỬ SAFEMODE TẤT CẢ MỨC HZ
%group Group_Display_SpringBoardV261

%hook SBAppSwitcherController
- (void)viewDidLayoutSubviews {
    if (IS_ACTIVE && CFG261.reduceMultitaskLag) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}
%end

%hook CADisplayLink

- (CAFrameRateRange)preferredFrameRateRange {
    if (!IS_ACTIVE || (!CFG261.enableHzControl && !CFG261.proMotionEngineBeta7)) {
        return %orig;
    }
    
    NSInteger targetHz = [CFG261 resolvedTargetHz];
    return Titanium_NormalizeFrameRateRange((float)targetHz);
}

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    if (!IS_ACTIVE || (!CFG261.enableHzControl && !CFG261.proMotionEngineBeta7)) {
        %orig(range);
        return;
    }
    NSInteger targetHz = [CFG261 resolvedTargetHz];
    %orig(Titanium_NormalizeFrameRateRange((float)targetHz));
}

- (BOOL)isPaused {
    return %orig;
}

- (void)setPaused:(BOOL)paused {
    %orig(paused);
}

- (CFTimeInterval)duration {
    return %orig;
}

- (CFTimeInterval)targetTimestamp {
    return %orig;
}

- (CFTimeInterval)timestamp {
    return %orig;
}

%end

// FIX LỖI CHUYỂN CẢNH & KHÔNG ĐÈ ANIMATION
%hook CAAnimation

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    if (IS_ACTIVE && CFG261.isCustomHzEnabled) {
        float target = (float)[CFG261 resolvedTargetHz];
        
        if (range.maximum > 0 && range.maximum != 60) {
            %orig(range);
            return;
        }
        
        %orig(Titanium_NormalizeFrameRateRange(target));
    } else {
        %orig(range);
    }
}

%end

%hook UIScreen
- (NSInteger)maximumFramesPerSecond {
    if (!IS_ACTIVE || (!CFG261.enableHzControl && !CFG261.proMotionEngineBeta7)) return %orig;
    return [CFG261 resolvedTargetHz];
}

- (NSInteger)_maximumFramesPerSecond {
    if (!IS_ACTIVE || (!CFG261.enableHzControl && !CFG261.proMotionEngineBeta7)) return %orig;
    return [CFG261 resolvedTargetHz];
}

- (CGFloat)_refreshRate {
    if (!IS_ACTIVE || (!CFG261.enableHzControl && !CFG261.proMotionEngineBeta7)) {
        return %orig;
    }
    return (CGFloat)[CFG261 resolvedTargetHz];
}

- (void)_setTargetRefreshRate:(CGFloat)rate {
    if (!IS_ACTIVE || (!CFG261.enableHzControl && !CFG261.proMotionEngineBeta7)) {
        %orig(rate);
        return;
    }
    %orig((CGFloat)[CFG261 resolvedTargetHz]);
}

- (CGRect)bounds {
    return %orig;
}

- (CGFloat)scale {
    return %orig;
}

- (CGFloat)nativeScale {
    return %orig;
}

- (CGRect)nativeBounds {
    return %orig;
}

- (id)displayLinkWithTarget:(id)target selector:(SEL)sel {
    return %orig(target, sel);
}
%end

%hook CADisplay
- (NSInteger)preferredFPS {
    if (!IS_ACTIVE || (!CFG261.enableHzControl && !CFG261.proMotionEngineBeta7)) {
        return %orig;
    }
    return [CFG261 resolvedTargetHz];
}

- (void)setPreferredFPS:(NSInteger)fps {
    if (!IS_ACTIVE || (!CFG261.enableHzControl && !CFG261.proMotionEngineBeta7)) {
        %orig(fps);
        return;
    }
    %orig([CFG261 resolvedTargetHz]);
}

- (void)overrideDisplayTimings:(id)timings {
    %orig(timings);
}

- (void)overrideDisplayCadence:(id)cadence {
    %orig(cadence);
}

- (BOOL)supportsDynamicRefresh {
    if (IS_ACTIVE && CFG261.proMotionEngineBeta7) {
        return YES;
    }
    return %orig;
}
%end

%hook SBIconController
- (void)scrollToIconListAtIndex:(NSInteger)index animate:(BOOL)animate {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(index, animate);
}

- (void)viewWillLayoutSubviews {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)viewDidLayoutSubviews {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)openFolder:(id)folder animated:(BOOL)animated completion:(id)completion {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(folder, animated, completion);
}

- (void)closeFolderAnimated:(BOOL)animated completion:(id)completion {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(animated, completion);
}
%end

%hook SBFloatingDockController
- (void)layoutFloatingDock {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)dismissFloatingDockIfPresentedAnimated:(BOOL)animated completionHandler:(id)completion {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(animated, completion);
}

- (void)presentFloatingDockIfPossible:(BOOL)animated completionHandler:(id)completion {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(animated, completion);
}
%end

%hook SBFolderView
- (void)layoutSubviews {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)scrollViewDidScroll:(id)scrollView {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(scrollView);
}

- (void)willAnimate {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)prepareToOpen {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)cleanupAfterClose {
    if (IS_ACTIVE && CFG261.aggressiveRamClean) {
        Titanium_PurgeProcessMemoryAggressively();
    }
    %orig;
}
%end

%hook SBIconListView

- (void)layoutIconsNow {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)layoutSubviews {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)setAlphaForAllIcons:(double)alpha {
    %orig(alpha);
}

- (void)fadeInIcon:(id)icon {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(icon);
}
%end

%hook SBIconView
- (void)setIconImageInfo:(id)info {
    %orig(info);
}

- (void)setHighlighted:(BOOL)highlighted {
    if (IS_ACTIVE && CFG261.touchResponseBoost) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(highlighted);
}

- (void)setTouchDownInIcon:(BOOL)touchDown {
    if (IS_ACTIVE && CFG261.touchResponseBoost) {
        g_isUserTouchingV261 = touchDown;
        g_lastTouchMediaTimeV261 = CACurrentMediaTime();
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(touchDown);
}

- (void)setAllowsCloseBox:(BOOL)allows {
    %orig(allows);
}

- (void)prepareForReuse {
    %orig;
}
%end

%hook SBFluidSwitcherViewController
- (void)viewWillLayoutSubviews {
    if (IS_ACTIVE && CFG261.fixAppExitStutter) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)viewDidLayoutSubviews {
    if (IS_ACTIVE && CFG261.fixAppExitStutter) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)handleFluidSwitcherGesture:(id)gesture {
    if (IS_ACTIVE && CFG261.touchResponseBoost) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(gesture);
}
%end

%hook SBMainDisplaySceneLayoutViewController
- (void)viewWillLayoutSubviews {
    if (IS_ACTIVE && CFG261.fixAppLaunchBlackScreen) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)viewDidLayoutSubviews {
    if (IS_ACTIVE && CFG261.fixAppLaunchBlackScreen) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}
%end

%hook SBWallpaperController
- (void)beginRequiringWithReason:(id)reason {
    %orig(reason);
}

- (void)endRequiringWithReason:(id)reason {
    %orig(reason);
}

- (void)suspendWallpaperAnimationForReason:(id)reason {
    %orig(reason);
}

- (void)resumeWallpaperAnimationForReason:(id)reason {
    %orig(reason);
}
%end

%hook SBBacklightController
- (void)setBacklightFactor:(float)factor {
    %orig(factor);
}

- (float)backlightFactor {
    return %orig;
}

- (void)animateBacklightToFactor:(float)factor duration:(double)duration source:(long long)source completion:(id)completion {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(factor, duration, source, completion);
}
%end

%hook SBVolumeControl
- (void)increaseVolume {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)decreaseVolume {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)cancelVolumeEvent {
    %orig;
}
%end

%hook SBMediaController
- (BOOL)isPlaying {
    return %orig;
}

- (BOOL)isPaused {
    return %orig;
}

- (BOOL)playForEventSource:(long long)source {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    return %orig(source);
}

- (BOOL)pauseForEventSource:(long long)source {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    return %orig(source);
}

- (BOOL)togglePlayPauseForEventSource:(long long)source {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    return %orig(source);
}
%end

%hook SBHomeHardwareButtonActions
- (void)performSinglePressAction {
    if (IS_ACTIVE && CFG261.touchResponseBoost) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)performDoublePressAction {
    if (IS_ACTIVE && CFG261.touchResponseBoost) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)performTriplePressAction {
    if (IS_ACTIVE && CFG261.touchResponseBoost) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)performLongPressCancelled {
    %orig;
}
%end

%hook SBLockScreenManager
- (BOOL)isUILocked {
    return %orig;
}

- (void)unlockUIFromSource:(int)source withOptions:(id)options {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(source, options);
}

- (void)lockUIFromSource:(int)source withOptions:(id)options {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(source, options);
}

- (BOOL)attemptUnlockWithPasscode:(id)passcode finishUIUnlock:(BOOL)finish {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    return %orig(passcode, finish);
}
%end

// FIX: ÉP CONTROL CENTER ĐẠT HZ MƯỢT ĐỈNH CAO
%hook SBControlCenterController
- (BOOL)isVisible {
    return %orig;
}

- (void)presentAnimated:(BOOL)animated {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(animated);
}

- (void)dismissAnimated:(BOOL)animated {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(animated);
}
%end

// FIX: ÉP NOTIFICATION CENTER ĐẠT HZ MƯỢT ĐỈNH CAO
%hook SBNotificationCenterController
- (BOOL)isVisible {
    return %orig;
}

- (void)presentAnimated:(BOOL)animated {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(animated);
}

- (void)dismissAnimated:(BOOL)animated {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(animated);
}
%end

%hook SBFView
- (void)setCustomFullHomedStyle:(BOOL)flag {
    %orig(flag);
}
%end

%hook UIStatusBar
- (void)requestStyle:(long long)style animated:(BOOL)animated {
    if (Titanium_IsClassicHomeButtonDevice()) {
        %orig(0, animated);
        return;
    }
    %orig(style, animated);
}

- (void)forceUpdateData:(BOOL)animated {
    %orig(animated);
}
%end

%hook SBReachabilityManager
- (BOOL)reachabilityModeActive {
    return %orig;
}

- (void)deactivateReachabilityMode {
    %orig;
}

- (void)triggerReachability {
    if (IS_ACTIVE && CFG261.touchResponseBoost) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}
%end

%hook SBWindow
- (BOOL)_isSecure {
    return %orig;
}

- (void)setHidden:(BOOL)hidden {
    %orig(hidden);
}
%end

%hook SBRootFolderView
- (void)layoutSubviews {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)setNeedsLayout {
    %orig;
}
%end

%hook SBSwitcherAppSuggestionViewController
- (void)viewWillAppear:(BOOL)animated {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(animated);
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig(animated);
}
%end

%hook SBDeckSwitcherViewController
- (void)viewWillAppear:(BOOL)animated {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(animated);
}

- (void)viewDidAppear:(BOOL)animated {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(animated);
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig(animated);
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig(animated);
}
%end

%hook SBFluidSwitcherItemContainer
- (void)setContentAlpha:(double)alpha {
    %orig(1.0);
}

- (void)prepareForReuse {
    %orig;
}
%end

%hook SBHomeScreenViewController
- (void)viewWillAppear:(BOOL)animated {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(animated);
}

- (void)viewDidAppear:(BOOL)animated {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(animated);
}
%end

%hook CSCoverSheetViewController
- (void)viewWillAppear:(BOOL)animated {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(animated);
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig(animated);
}
%end

%hook SBDisplayPowerLogReporter
- (void)reportPowerLogEvent {
    %orig;
}
%end

%hook SBAttentionAwarenessClient
- (void)setAttentionAwarenessConfiguration:(id)config {
    %orig(config);
}

- (void)resume {
    %orig;
}

- (void)suspend {
    %orig;
}
%end

%hook SBIdleTimerGlobalCoordinator
- (void)resetIdleTimer {
    if (IS_ACTIVE && CFG261.touchResponseBoost) {
        g_lastTouchMediaTimeV261 = CACurrentMediaTime();
    }
    %orig;
}
%end

%hook SBUIController
- (BOOL)isAppSwitcherShowing {
    return %orig;
}

- (void)clickedMenuButton {
    if (IS_ACTIVE && CFG261.touchResponseBoost) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)handleHomeButtonDoublePressDown {
    if (IS_ACTIVE && CFG261.touchResponseBoost) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)lockFromSource:(int)source {
    if (IS_ACTIVE) {
        Titanium_PurgeProcessMemoryAggressively();
    }
    %orig(source);
}
%end

%hook SpringBoard
- (id)_accessibilityFrontMostApplication {
    return %orig;
}

- (BOOL)isLocked {
    return %orig;
}

- (void)_reboot:(BOOL)arg1 {
    %orig(arg1);
}

- (void)_relaunchSpringBoardNow {
    %orig;
}
%end

%end

%group Group_ZeroLatencyTouch_PhysicsV261

%hook UIWindow

- (void)sendEvent:(UIEvent *)event {
    if (IS_ACTIVE && CFG261.touchResponseBoost && event.type == UIEventTypeTouches) {
        NSSet *allTouches = [event allTouches];
        BOOL hasActiveTouch = NO;
        BOOL isInitialTouch = NO;

        for (UITouch *touch in allTouches) {
            UITouchPhase phase = touch.phase;
            if (phase == UITouchPhaseBegan) {
                isInitialTouch = YES;
                hasActiveTouch = YES;
                break;
            } else if (phase == UITouchPhaseMoved || phase == UITouchPhaseStationary) {
                hasActiveTouch = YES;
            }
        }

        if (hasActiveTouch) {
            g_isUserTouchingV261 = YES;
            g_lastTouchMediaTimeV261 = CACurrentMediaTime();
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);

            if (isInitialTouch && !Titanium_IsSpringBoard()) {
                thread_t currentMachThread = mach_thread_self();
                Titanium_SetThreadRealtimeConstraintV261(currentMachThread, (uint32_t)[CFG261 resolvedTargetFPS]);
                mach_port_deallocate(mach_task_self(), currentMachThread);
            }
        } else {
            g_isUserTouchingV261 = NO;
        }
    }

    %orig(event);
}

- (void)layoutSubviews {
    %orig;
    if (Titanium_IsSpringBoard()) {
        NSString *clsName = NSStringFromClass([self class]);
        if ([clsName containsString:@"StatusBar"] || [clsName containsString:@"SecureWindow"]) {
            return;
        }
    }
}

- (BOOL)_isSecure {
    return %orig;
}

- (void)_setSecure:(BOOL)flag {
    %orig(flag);
}

- (void)setRootViewController:(UIViewController *)rootViewController {
    if (IS_ACTIVE && CFG261.turboAppLaunch) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(rootViewController);
}

- (void)makeKeyAndVisible {
    if (IS_ACTIVE && CFG261.turboAppLaunch) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)becomeKeyWindow {
    if (IS_ACTIVE && CFG261.touchResponseBoost) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)resignKeyWindow {
    %orig;
}

%end

%hook UITouch
- (NSTimeInterval)timestamp {
    return %orig;
}

- (CGPoint)preciseLocationInView:(UIView *)view {
    if (IS_ACTIVE && CFG261.touchResponseBoost) {
        g_isUserTouchingV261 = YES;
        g_lastTouchMediaTimeV261 = CACurrentMediaTime();
    }
    return %orig(view);
}

- (CGPoint)precisePreviousLocationInView:(UIView *)view {
    if (IS_ACTIVE && CFG261.touchResponseBoost) {
        g_isUserTouchingV261 = YES;
        g_lastTouchMediaTimeV261 = CACurrentMediaTime();
    }
    return %orig(view);
}

- (UITouchPhase)phase {
    UITouchPhase currentTouchPhase = %orig;
    if (IS_ACTIVE && CFG261.touchResponseBoost) {
        if (currentTouchPhase == UITouchPhaseBegan || currentTouchPhase == UITouchPhaseMoved) {
            g_isUserTouchingV261 = YES;
            g_lastTouchMediaTimeV261 = CACurrentMediaTime();
        } else if (currentTouchPhase == UITouchPhaseEnded || currentTouchPhase == UITouchPhaseCancelled) {
            g_isUserTouchingV261 = NO;
        }
    }
    return currentTouchPhase;
}

- (UIWindow *)window {
    return %orig;
}

- (UIView *)view {
    return %orig;
}

- (NSUInteger)tapCount {
    return %orig;
}

- (CGFloat)majorRadius {
    return %orig;
}

- (CGFloat)majorRadiusTolerance {
    return %orig;
}

- (NSArray *)gestureRecognizers {
    return %orig;
}

- (CGFloat)force {
    return %orig;
}

- (CGFloat)maximumPossibleForce {
    return %orig;
}

- (CGPoint)locationInView:(UIView *)view {
    if (IS_ACTIVE && CFG261.touchResponseBoost) {
        g_isUserTouchingV261 = YES;
        g_lastTouchMediaTimeV261 = CACurrentMediaTime();
    }
    return %orig(view);
}

- (CGPoint)previousLocationInView:(UIView *)view {
    if (IS_ACTIVE && CFG261.touchResponseBoost) {
        g_isUserTouchingV261 = YES;
        g_lastTouchMediaTimeV261 = CACurrentMediaTime();
    }
    return %orig(view);
}

- (long long)type {
    return %orig;
}

- (float)_pathMajorRadius {
    return %orig;
}
%end

%hook UIGestureRecognizer
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (IS_ACTIVE && CFG261.touchResponseBoost) {
        g_isUserTouchingV261 = YES;
        g_lastTouchMediaTimeV261 = CACurrentMediaTime();
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(touches, event);
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    if (IS_ACTIVE && CFG261.touchResponseBoost) {
        g_isUserTouchingV261 = YES;
        g_lastTouchMediaTimeV261 = CACurrentMediaTime();
    }
    %orig(touches, event);
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (IS_ACTIVE && CFG261.touchResponseBoost) {
        g_isUserTouchingV261 = NO;
    }
    %orig(touches, event);
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    if (IS_ACTIVE && CFG261.touchResponseBoost) {
        g_isUserTouchingV261 = NO;
    }
    %orig(touches, event);
}

- (void)setState:(UIGestureRecognizerState)state {
    if (IS_ACTIVE && CFG261.touchResponseBoost) {
        if (state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged) {
            g_isUserTouchingV261 = YES;
            g_lastTouchMediaTimeV261 = CACurrentMediaTime();
        } else if (state == UIGestureRecognizerStateEnded || state == UIGestureRecognizerStateCancelled || state == UIGestureRecognizerStateFailed) {
            g_isUserTouchingV261 = NO;
        }
    }
    %orig(state);
}

- (BOOL)isEnabled {
    return %orig;
}

- (void)setEnabled:(BOOL)enabled {
    %orig(enabled);
}

- (BOOL)cancelsTouchesInView {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        return NO;
    }
    return %orig;
}

- (BOOL)delaysTouchesBegan {
    if (IS_ACTIVE && CFG261.touchResponseBoost) {
        return NO;
    }
    return %orig;
}

- (BOOL)delaysTouchesEnded {
    if (IS_ACTIVE && CFG261.touchResponseBoost) {
        return NO;
    }
    return %orig;
}

- (void)ignoreTouch:(UITouch *)touch forEvent:(UIEvent *)event {
    %orig(touch, event);
}

- (BOOL)canPreventGestureRecognizer:(UIGestureRecognizer *)preventedGestureRecognizer {
    return %orig(preventedGestureRecognizer);
}

- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)preventingGestureRecognizer {
    return %orig(preventingGestureRecognizer);
}

- (BOOL)shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return %orig(otherGestureRecognizer);
}

- (BOOL)shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return %orig(otherGestureRecognizer);
}
%end

%hook UIPanGestureRecognizer
- (void)setDelaysTouchesBegan:(BOOL)delays {
    if (IS_ACTIVE && CFG261.touchResponseBoost) {
        %orig(NO);
        return;
    }
    %orig(delays);
}

- (void)setDelaysTouchesEnded:(BOOL)delays {
    if (IS_ACTIVE && CFG261.touchResponseBoost) {
        %orig(NO);
        return;
    }
    %orig(delays);
}

- (void)setCancelsTouchesInView:(BOOL)cancels {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        %orig(NO);
        return;
    }
    %orig(cancels);
}

- (CGPoint)velocityInView:(UIView *)view {
    CGPoint computedVelocity = %orig(view);
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        g_isUserTouchingV261 = YES;
        g_lastTouchMediaTimeV261 = CACurrentMediaTime();
    }
    return computedVelocity;
}

- (CGPoint)translationInView:(UIView *)view {
    return %orig(view);
}

- (void)setTranslation:(CGPoint)translation inView:(UIView *)view {
    %orig(translation, view);
}

- (NSUInteger)minimumNumberOfTouches {
    return %orig;
}

- (void)setMinimumNumberOfTouches:(NSUInteger)minimumNumberOfTouches {
    %orig(minimumNumberOfTouches);
}

- (NSUInteger)maximumNumberOfTouches {
    return %orig;
}

- (void)setMaximumNumberOfTouches:(NSUInteger)maximumNumberOfTouches {
    %orig(maximumNumberOfTouches);
}
%end

%hook UIScreenEdgePanGestureRecognizer
- (void)setDelaysTouchesBegan:(BOOL)delays {
    if (IS_ACTIVE && CFG261.touchResponseBoost) {
        %orig(NO);
        return;
    }
    %orig(delays);
}

- (void)setDelaysTouchesEnded:(BOOL)delays {
    if (IS_ACTIVE && CFG261.touchResponseBoost) {
        %orig(NO);
        return;
    }
    %orig(delays);
}

- (UIRectEdge)edges {
    return %orig;
}

- (void)setEdges:(UIRectEdge)edges {
    %orig(edges);
}
%end

// FIX LỖI 4: VUỐT CUỘN NHANH VIDEO KHÔNG BỊ KHỰNG / DELAY
%hook UIScrollView
- (void)_smoothScrollWithVelocity:(CGPoint)velocity targetContentOffset:(CGPoint)targetContentOffset {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(velocity, targetContentOffset);
}

- (void)setContentOffset:(CGPoint)contentOffset animated:(BOOL)animated {
    if (IS_ACTIVE && animated && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(contentOffset, animated);
}

- (CGPoint)_touchPositionForTouches:(id)touches {
    if (IS_ACTIVE && (CFG261.touchResponseBoost || CFG261.ultraResponsiveness)) {
        g_isUserTouchingV261 = YES;
        g_lastTouchMediaTimeV261 = CACurrentMediaTime();
    }
    return %orig(touches);
}

- (void)_setContentOffsetPinned:(CGPoint)point {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(point);
}

- (void)setDecelerationRate:(UIScrollViewDecelerationRate)decelerationRate {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        %orig(UIScrollViewDecelerationRateNormal);
        return;
    }
    %orig(decelerationRate);
}

- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        return YES;
    }
    return %orig(view);
}

- (BOOL)isPagingEnabled {
    return %orig;
}

- (void)setPagingEnabled:(BOOL)pagingEnabled {
    %orig(pagingEnabled);
}

- (BOOL)isScrollEnabled {
    return %orig;
}

- (void)setScrollEnabled:(BOOL)scrollEnabled {
    %orig(scrollEnabled);
}

- (BOOL)bounces {
    return %orig;
}

- (void)setBounces:(BOOL)bounces {
    %orig(bounces);
}

- (BOOL)alwaysBounceVertical {
    return %orig;
}

- (void)setAlwaysBounceVertical:(BOOL)alwaysBounceVertical {
    %orig(alwaysBounceVertical);
}

- (BOOL)alwaysBounceHorizontal {
    return %orig;
}

- (void)setAlwaysBounceHorizontal:(BOOL)alwaysBounceHorizontal {
    %orig(alwaysBounceHorizontal);
}

- (void)_setInterruptionImpulse:(CGPoint)impulse {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(impulse);
}

- (void)_forcePanGestureToEndImmediately {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        g_isUserTouchingV261 = NO;
    }
    %orig;
}

- (BOOL)isTracking {
    return %orig;
}

- (BOOL)isDragging {
    return %orig;
}

- (BOOL)isDecelerating {
    return %orig;
}

- (void)setContentSize:(CGSize)contentSize {
    %orig(contentSize);
}

- (CGSize)contentSize {
    return %orig;
}

- (void)setContentInset:(UIEdgeInsets)contentInset {
    %orig(contentInset);
}

- (UIEdgeInsets)contentInset {
    return %orig;
}

- (void)scrollRectToVisible:(CGRect)rect animated:(BOOL)animated {
    if (IS_ACTIVE && animated && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(rect, animated);
}
%end

%hook UITableView
- (void)reloadData {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)layoutSubviews {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)beginUpdates {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)endUpdates {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)scrollToRowAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(UITableViewScrollPosition)scrollPosition animated:(BOOL)animated {
    if (IS_ACTIVE && animated && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(indexPath, scrollPosition, animated);
}

- (void)reloadRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(indexPaths, animation);
}

- (void)insertRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(indexPaths, animation);
}

- (void)deleteRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(indexPaths, animation);
}
%end

%hook UICollectionView
- (void)reloadData {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)layoutSubviews {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)performBatchUpdates:(void (^)(void))updates completion:(void (^)(BOOL finished))completion {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(updates, completion);
}

- (void)scrollToItemAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(UICollectionViewScrollPosition)scrollPosition animated:(BOOL)animated {
    if (IS_ACTIVE && animated && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(indexPath, scrollPosition, animated);
}

- (void)insertItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(indexPaths);
}

- (void)deleteItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(indexPaths);
}
%end

%hook SBAppSwitcherSettings

- (void)setDeckSwitcherPageScale:(double)scaleValue {
    %orig(scaleValue);
}

- (double)deckSwitcherPageScale {
    return %orig;
}

- (void)setAppSwitcherStyle:(long long)style {
    %orig(style);
}

- (long long)appSwitcherStyle {
    return %orig;
}
%end

%end

// FIX LỖI 6: TỐI ƯU HÓA BÀN PHÍM KHI GÕ NHIỀU CHỮ / CODE TRONG APP NẶNG
%group Group_Keyboard_And_TextV261

%hook UIKeyboardImpl
- (void)handleKeyWithString:(id)string forKeyEvent:(id)event executionContext:(id)context {
    if (IS_ACTIVE && CFG261.keyboardZeroLagV24) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(string, event, context);
}

- (void)addInputString:(id)string withFlags:(NSUInteger)flags executionContext:(id)context {
    if (IS_ACTIVE && CFG261.keyboardZeroLagV24) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(string, flags, context);
}

- (void)clearAnimations {
    if (IS_ACTIVE && CFG261.keyboardZeroLagV24) {
        %orig;
        return;
    }
    %orig;
}

- (void)setAutomaticMinimizationEnabled:(BOOL)flag {
    if (IS_ACTIVE && CFG261.keyboardZeroLagV24) {
        %orig(NO);
        return;
    }
    %orig(flag);
}

- (void)updateReturnKey:(BOOL)arg1 {
    if (IS_ACTIVE && CFG261.keyboardZeroLagV24) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(arg1);
}

- (void)hardwareKeyboardAvailabilityChanged {
    if (IS_ACTIVE && CFG261.keyboardZeroLagV24) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)setReturnKeyEnabled:(BOOL)enabled {
    if (IS_ACTIVE && CFG261.keyboardZeroLagV24) {
        %orig(YES);
        return;
    }
    %orig(enabled);
}

- (BOOL)returnKeyEnabled {
    if (IS_ACTIVE && CFG261.keyboardZeroLagV24) {
        return YES;
    }
    return %orig;
}

- (void)setInputMode:(id)inputMode {
    if (IS_ACTIVE && CFG261.keyboardZeroLagV24) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(inputMode);
}

- (void)setDelegate:(id)delegate {
    if (IS_ACTIVE && CFG261.keyboardZeroLagV24) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(delegate);
}

- (void)textChanged:(id)arg1 {
    if (IS_ACTIVE && CFG261.keyboardZeroLagV24) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(arg1);
}

- (void)deleteFromInput {
    if (IS_ACTIVE && CFG261.keyboardZeroLagV24) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)touchLongPressTimer {
    %orig;
}

- (void)showKeyboard {
    if (IS_ACTIVE && CFG261.keyboardZeroLagV24) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)hideKeyboard {
    %orig;
}
%end

%hook UITextInputController
- (void)_insertText:(id)text {
    if (IS_ACTIVE && CFG261.keyboardZeroLagV24) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(text);
}

- (void)deleteBackward {
    if (IS_ACTIVE && CFG261.keyboardZeroLagV24) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)replaceRange:(id)range withText:(id)text {
    if (IS_ACTIVE && CFG261.keyboardZeroLagV24) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(range, text);
}

- (void)setMarkedText:(id)markedText selectedRange:(NSRange)selectedRange {
    if (IS_ACTIVE && CFG261.keyboardZeroLagV24) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(markedText, selectedRange);
}

- (void)unmarkText {
    if (IS_ACTIVE && (CFG261.keyboardZeroLagV24 || CFG261.keyboardZeroLagV3)) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}
%end

%hook UITextView
- (void)insertText:(id)text {
    if (IS_ACTIVE && (CFG261.keyboardZeroLagV24 || CFG261.keyboardZeroLagV3)) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(text);
}

- (void)deleteBackward {
    if (IS_ACTIVE && (CFG261.keyboardZeroLagV24 || CFG261.keyboardZeroLagV3)) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)setContentOffset:(CGPoint)contentOffset {
    if (IS_ACTIVE && (CFG261.keyboardZeroLagV24 || CFG261.keyboardZeroLagV3)) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(contentOffset);
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
    if (IS_ACTIVE && (CFG261.keyboardZeroLagV24 || CFG261.keyboardZeroLagV3)) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(attributedText);
}

- (void)setFont:(UIFont *)font {
    %orig(font);
}

- (void)setTextColor:(UIColor *)textColor {
    %orig(textColor);
}

- (void)setTextAlignment:(NSTextAlignment)textAlignment {
    %orig(textAlignment);
}

- (BOOL)isEditable {
    return %orig;
}

- (void)setEditable:(BOOL)editable {
    %orig(editable);
}
%end

%hook UITextField
- (void)insertText:(id)text {
    if (IS_ACTIVE && (CFG261.keyboardZeroLagV24 || CFG261.keyboardZeroLagV3)) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(text);
}

- (void)deleteBackward {
    if (IS_ACTIVE && (CFG261.keyboardZeroLagV24 || CFG261.keyboardZeroLagV3)) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)setText:(NSString *)text {
    if (IS_ACTIVE && (CFG261.keyboardZeroLagV24 || CFG261.keyboardZeroLagV3)) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(text);
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
    if (IS_ACTIVE && (CFG261.keyboardZeroLagV24 || CFG261.keyboardZeroLagV3)) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(attributedText);
}

- (void)setPlaceholder:(NSString *)placeholder {
    %orig(placeholder);
}

- (void)setFont:(UIFont *)font {
    %orig(font);
}

- (void)setTextColor:(UIColor *)textColor {
    %orig(textColor);
}

- (BOOL)isSecureTextEntry {
    return %orig;
}

- (void)setSecureTextEntry:(BOOL)secureTextEntry {
    %orig(secureTextEntry);
}
%end

%end

// =========================================================================
// PIPELINE METAL GRAPHICS CHUẨN XÁC: FIX LỖI ĐEN MÀN HÌNH VÀ VIDEO GIẬT
// =========================================================================
%group Group_MetalGraphics_OptV261

%hook CAMetalLayer

- (void)setMaximumDrawableCount:(NSUInteger)count {
    if (Titanium_IsSpringBoard()) {
        %orig(3);
        return;
    }
    if (count > 0 && count <= 3) {
        %orig(count);
    } else {
        %orig(3);
    }
}

- (void)didMoveToSuperlayer {
    %orig;
    if ([self respondsToSelector:@selector(setAllowsGroupOpacity:)]) {
        [self setAllowsGroupOpacity:NO]; 
    }
}

- (NSUInteger)maximumDrawableCount {
    return %orig;
}

- (void)setLowLatencyMode:(BOOL)flag {
    %orig(YES);
}

- (BOOL)lowLatencyMode {
    return YES;
}

- (void)setDisplaySyncEnabled:(BOOL)enabled {
    %orig(YES);
}

- (BOOL)displaySyncEnabled {
    return YES;
}

- (void)setAllowsNextDrawableTimeout:(BOOL)allow {
    %orig(allow);
}

- (BOOL)allowsNextDrawableTimeout {
    return %orig;
}

- (void)setPresentsWithTransaction:(BOOL)flag {
    %orig(flag);
}

- (BOOL)presentsWithTransaction {
    return %orig;
}

- (void)setServerPresentsWithTransaction:(BOOL)flag {
    %orig(flag);
}

- (BOOL)serverPresentsWithTransaction {
    return %orig;
}

- (void)setFramebufferOnly:(BOOL)framebufferOnly {
    %orig(framebufferOnly);
}

- (BOOL)framebufferOnly {
    return %orig;
}

- (void)setDrawableSize:(CGSize)drawableSize {
    %orig(drawableSize);
}

- (CGSize)drawableSize {
    return %orig;
}

- (id)nextDrawable {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    return %orig;
}

%end

%hook CADisplayLink

- (void)setPaused:(BOOL)paused {
    %orig(paused);
}

- (void)setFrameInterval:(NSInteger)interval {
    if (interval < 1) interval = 1;
    %orig(interval);
}

- (void)addToRunLoop:(NSRunLoop *)runloop forMode:(NSString *)mode {
    if ([mode isEqualToString:UITrackingRunLoopMode] || [mode isEqualToString:NSRunLoopCommonModes]) {
        if (IS_ACTIVE && [CFG261 respondsToSelector:@selector(isCustomHzEnabled)] && [CFG261 isCustomHzEnabled]) {
            self.preferredFramesPerSecond = [CFG261 resolvedTargetFPS];
        }
    }
    %orig;
}

%end

%hook CALayer

- (void)setContentsScale:(CGFloat)scale {
    if (Titanium_IsSpringBoard()) {
        %orig;
        return;
    }

    if (IS_ACTIVE && CFG261.metalHexBuffering) {
        %orig(scale > 0 ? scale : [UIScreen mainScreen].scale);
        return;
    }
    %orig;
}

- (void)setContentsDrawsAsynchronously:(BOOL)flag {
    if (IS_ACTIVE) {
        %orig(YES);
        return;
    }
    %orig(flag);
}

- (BOOL)contentsDrawsAsynchronously {
    if (IS_ACTIVE) {
        return YES;
    }
    return %orig;
}

- (void)setAllowsEdgeAntialiasing:(BOOL)flag {
    if (IS_ACTIVE && CFG261.powerSaveMode) {
        %orig(NO);
        return;
    }
    %orig(flag);
}

- (BOOL)allowsEdgeAntialiasing {
    if (IS_ACTIVE && CFG261.powerSaveMode) {
        return NO;
    }
    return %orig;
}

- (void)setNeedsDisplayOnBoundsChange:(BOOL)flag {
    if (IS_ACTIVE && CFG261.fixAppExitStutter) {
        %orig(NO);
        return;
    }
    %orig(flag);
}

- (BOOL)needsDisplayOnBoundsChange {
    if (IS_ACTIVE && CFG261.fixAppExitStutter) {
        return NO;
    }
    return %orig;
}

- (void)setRasterizationScale:(CGFloat)rasterizationScale {
    %orig(rasterizationScale);
}

- (CGFloat)rasterizationScale {
    return %orig;
}

- (void)setShouldRasterize:(BOOL)shouldRasterize {
    if (IS_ACTIVE && CFG261 && CFG261.aggressiveRamClean) {
        %orig(NO);
        return;
    }
    %orig(shouldRasterize);
}

- (BOOL)shouldRasterize {
    return %orig;
}

- (void)setDrawsAsynchronously:(BOOL)drawsAsynchronously {
    if (IS_ACTIVE) {
        %orig(YES);
        return;
    }
    %orig(drawsAsynchronously);
}

- (BOOL)drawsAsynchronously {
    if (IS_ACTIVE) {
        return YES;
    }
    return %orig;
}

- (void)display {
    if (IS_ACTIVE && (CFG261.touchResponseBoost || CFG261.ultraResponsiveness)) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)setNeedsLayout {
    %orig;
}

- (void)layoutIfNeeded {
    %orig;
}

%end

%hook CAContext
- (void)setCommitPriority:(uint32_t)priority {
    if (Titanium_IsSpringBoard()) {
        %orig(priority);
        return;
    }
    if (IS_ACTIVE) {
        %orig(100);
        return;
    }
    %orig(priority);
}

- (uint32_t)commitPriority {
    if (Titanium_IsSpringBoard()) {
        return %orig;
    }
    if (IS_ACTIVE) {
        return 100;
    }
    return %orig;
}

- (void)setDesiredDynamicRange:(float)range {
    if (IS_ACTIVE && CFG261.powerSaveMode) {
        %orig(1.0f);
        return;
    }
    %orig(range);
}

- (float)desiredDynamicRange {
    if (IS_ACTIVE && CFG261.powerSaveMode) {
        return 1.0f;
    }
    return %orig;
}

- (void)orderAbove:(uint32_t)contextId {
    %orig(contextId);
}

- (void)orderBelow:(uint32_t)contextId {
    %orig(contextId);
}
%end

%end

%group Group_UIKit_ThirdParty_IsolatedV261

%hook UIViewController
- (void)viewWillAppear:(BOOL)animated {
    if (IS_ACTIVE) {
        Titanium_ReloadSharedSyncStateV261();
        if (CFG261.syncModuleDelay || CFG261.isolateRenderPipeline) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
    %orig(animated);
}

- (void)viewDidAppear:(BOOL)animated {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(animated);
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig(animated);
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig(animated);
    if (IS_ACTIVE && CFG261.aggressiveRamClean) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            Titanium_PurgeProcessMemoryAggressively();
        });
    }
}

- (void)viewDidLoad {
    if (IS_ACTIVE) {
        Titanium_ReloadSharedSyncStateV261();
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)viewWillLayoutSubviews {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)viewDidLayoutSubviews {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)didReceiveMemoryWarning {
    %orig;
    if (IS_ACTIVE) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
            Titanium_PurgeProcessMemoryAggressively();
        });
    }
}
%end

%hook UIApplication
- (void)_applicationDidEnterBackground {
    %orig;
    if (IS_ACTIVE && CFG261.fixAppExitStutter) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
            Titanium_PurgeProcessMemoryAggressively();
        });
    }
}

- (void)_applicationWillEnterForeground {
    if (IS_ACTIVE) {
        Titanium_ReloadSharedSyncStateV261();
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)_applicationDidBecomeActive {
    if (IS_ACTIVE) {
        Titanium_ReloadSharedSyncStateV261();
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)_applicationWillResignActive {
    %orig;
}

- (void)_applicationWillTerminate {
    if (IS_ACTIVE) {
        Titanium_PurgeProcessMemoryAggressively();
    }
    %orig;
}
%end

%hook UIWindowScene
- (void)_readySceneForDisplay {
    %orig;
}

- (UIWindowSceneActivationState)activationState {
    return %orig;
}

- (UIScreen *)screen {
    return %orig;
}
%end

%end

%group Group_SpringBoard_ProcessManagerV261

%hook SBApplication
- (void)setProcessState:(id)state {
    if (IS_ACTIVE && (CFG261.turboAppLaunch || CFG261.turboLaunch)) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(state);
}

- (id)processState {
    return %orig;
}

- (NSString *)bundleIdentifier {
    return %orig;
}

- (NSString *)displayName {
    return %orig;
}

- (BOOL)isRunning {
    return %orig;
}

- (BOOL)isClassic {
    return %orig;
}

- (void)didExitWithContext:(id)context {
    if (IS_ACTIVE && CFG261.aggressiveRamClean) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            Titanium_PurgeProcessMemoryAggressively();
        });
    }
    %orig(context);
}
%end

%hook SBMainWorkspace
- (void)_handleApplicationProcessExited:(id)processDescription {
    if (IS_ACTIVE && CFG261.aggressiveRamClean) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            Titanium_PurgeProcessMemoryAggressively();
        });
    }
    %orig(processDescription);
}

- (void)handleApplicationLaunch:(id)application {
    if (IS_ACTIVE && (CFG261.turboAppLaunch || CFG261.turboLaunch)) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(application);
}

- (void)handleApplicationSuspended:(id)application {
    if (IS_ACTIVE && (CFG261.fixAppExitStutter || CFG261.autoCloseBackgroundApp)) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
            Titanium_PurgeProcessMemoryAggressively();
        });
    }
    %orig(application);
}
%end

%hook SBAppSwitcherController
- (void)switcherContentController:(id)contentController deletedItem:(id)deletedItem {
    %orig(contentController, deletedItem);
    if (IS_ACTIVE && CFG261.aggressiveRamClean) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            Titanium_PurgeProcessMemoryAggressively();
        });
    }
}

- (void)viewWillAppear:(BOOL)animated {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(animated);
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig(animated);
    if (IS_ACTIVE && CFG261.aggressiveRamClean) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            Titanium_PurgeProcessMemoryAggressively();
        });
    }
}
%end

%end

%group Group_ScrollPerformance_SuperEngineV261

%hook UIScrollView
- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig(newWindow);
    if (newWindow && IS_ACTIVE) {
        NSInteger targetHz = [CFG261 resolvedTargetHz];
        
        if (targetHz >= 80) {
            self.decelerationRate = UIScrollViewDecelerationRateNormal;
            self.delaysContentTouches = NO;
            self.canCancelContentTouches = YES;
        } else if (targetHz >= 45) {
            self.decelerationRate = UIScrollViewDecelerationRateNormal;
            self.delaysContentTouches = NO;
        }
        
        if (self.layer) {
            self.layer.drawsAsynchronously = (targetHz >= 45);
            self.layer.allowsGroupOpacity = NO;
        }
    }
}

- (void)_scrollViewAnimationEnded:(id)arg1 finished:(BOOL)arg2 {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(arg1, arg2);
}
%end

%hook UITextView
- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig(newWindow);
    if (newWindow && IS_ACTIVE) {
        self.layer.drawsAsynchronously = YES;
        if ([self respondsToSelector:@selector(setLayoutManager:)]) {
            self.layoutManager.allowsNonContiguousLayout = YES;
        }
    }
}
%end

%end

static void Titanium_StartThermalWatchdogTimerV261(void) {
    static dispatch_source_t timerSource = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_queue_t watchdogQueue = dispatch_queue_create("com.titanium.v261.thermal", DISPATCH_QUEUE_SERIAL);
        timerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, watchdogQueue);
        dispatch_source_set_timer(timerSource, DISPATCH_TIME_NOW, 5.0 * NSEC_PER_SEC, 1.0 * NSEC_PER_SEC);
        dispatch_source_set_event_handler(timerSource, ^{
            if (!IS_ACTIVE) return;
            NSProcessInfoThermalState currentThermalState = [[NSProcessInfo processInfo] thermalState];
            g_liveThermalStateV261 = currentThermalState;
            
            UIDevice *device = [UIDevice currentDevice];
            if (device.batteryMonitoringEnabled) {
                g_isDeviceChargingV261 = (device.batteryState == UIDeviceBatteryStateCharging || device.batteryState == UIDeviceBatteryStateFull);
            }
            
            if (currentThermalState == NSProcessInfoThermalStateCritical && !CFG261.antiThermalThrottling) {
                Titanium_PurgeProcessMemoryAggressively();
            }
        });
        dispatch_resume(timerSource);
    });
}

static void Titanium_StartPassiveRamDaemonV261(void) {
    if (!Titanium_IsSpringBoard()) return;
    
    static dispatch_source_t ramTimerSource = nil;
    if (ramTimerSource) return;

    dispatch_queue_t daemonQueue = dispatch_queue_create("com.titanium.v261.ramdaemon", DISPATCH_QUEUE_SERIAL);
    ramTimerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, daemonQueue);
    
    dispatch_source_set_timer(ramTimerSource, dispatch_time(DISPATCH_TIME_NOW, 120.0 * NSEC_PER_SEC), 120.0 * NSEC_PER_SEC, 30.0 * NSEC_PER_SEC);
    
    dispatch_source_set_event_handler(ramTimerSource, ^{
        if (IS_ACTIVE && CFG261.aggressiveRamClean) {
            Titanium_PurgeProcessMemoryAggressively();
        }
    });
    dispatch_resume(ramTimerSource);
}

static BOOL Titanium_CheckAndPreventBootloopUniversal(void) {
    NSString *bootCounterFilePath = @"/tmp/.boost_boot_counter";
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDate *currentDate = [NSDate date];
    
    NSDictionary *counterDict = [NSDictionary dictionaryWithContentsOfFile:bootCounterFilePath];
    NSInteger restartCount = 0;
    NSTimeInterval previousRestartTime = 0;
    
    if (counterDict) {
        restartCount = [counterDict[@"count"] integerValue];
        previousRestartTime = [counterDict[@"time"] doubleValue];
    }
    
    NSTimeInterval currentUnixTime = [currentDate timeIntervalSince1970];
    if (currentUnixTime - previousRestartTime < 15.0) {
        restartCount++;
    } else {
        restartCount = 1;
    }
    
    NSDictionary *updatedCounterDict = @{@"count": @(restartCount), @"time": @(currentUnixTime)};
    [updatedCounterDict writeToFile:bootCounterFilePath atomically:YES];
    
    if (restartCount >= 4) {
        return NO;
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([fileManager fileExistsAtPath:bootCounterFilePath]) {
            [fileManager removeItemAtPath:bootCounterFilePath error:nil];
        }
    });
    
    return YES;
}

static void reloadPrefsNotificationV261(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    static dispatch_source_t s_debounceTimer = nil;
    static dispatch_queue_t s_prefQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_prefQueue = dispatch_queue_create("com.titanium.v261.prefsync", DISPATCH_QUEUE_SERIAL);
    });

    if (s_debounceTimer) {
        dispatch_source_cancel(s_debounceTimer);
        s_debounceTimer = nil;
    }

    s_debounceTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, s_prefQueue);
    dispatch_source_set_timer(s_debounceTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(150 * NSEC_PER_MSEC)), DISPATCH_TIME_FOREVER, 0);
    dispatch_source_set_event_handler(s_debounceTimer, ^{
        if (CFG261 && [CFG261 respondsToSelector:@selector(loadSettings)]) {
            [CFG261 loadSettings];
        }
        s_debounceTimer = nil;
    });
    dispatch_resume(s_debounceTimer);
}

static BOOL Titanium_IsProcessEligible(NSString *bundleID, const char *progName) {
    if (!progName) return NO;
    if (strstr(progName, "ReportCrash") || strstr(progName, "crashreporterd") || 
        strstr(progName, "panic_report") || strstr(progName, "analyticsd") ||
        strstr(progName, "symptomsd") || strstr(progName, "logd") ||
        strstr(progName, "PosterBoard") || strstr(progName, "WallpaperKit") ||
        strstr(progName, "thermalmonitord")) {
        return NO;
    }
    if (bundleID) {
        if ([bundleID hasPrefix:@"com.apple.crashreport"] || 
            [bundleID hasPrefix:@"com.apple.ReportCrash"] ||
            [bundleID isEqualToString:@"com.apple.CoreAuthUI"] ||
            [bundleID containsString:@"PosterBoard"] ||
            [bundleID containsString:@"WallpaperKit"]) {
            return NO;
        }
    }
    return YES;
}

// BỘ KHỞI TẠO BẤT ĐỒNG BỘ: FIX LỖI TREO RESPRING VÀ TREO USERSPACE REBOOT TRÊN ROOTHIDE
%ctor {
    @autoreleasepool {
        const char *progName = getprogname();
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];

        if (Titanium_IsCriticalSystemDaemon()) {
            return;
        }

        if (!Titanium_CheckAndPreventBootloopUniversal()) {
            return;
        }

        if (!Titanium_IsProcessEligible(bundleID, progName)) {
            return;
        }

        if (Titanium_IsSecureBankingApp()) {
            return;
        }

        if (Titanium_IsSpringBoard()) {
            [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        }

        Class configClass = NSClassFromString(@"BoostConfigV261");
        if (configClass) {
            CFG261 = [configClass sharedInstance];
            if ([CFG261 respondsToSelector:@selector(loadSettings)]) {
                [CFG261 loadSettings];
            }
        }

        %init(Group_MetalGraphics_OptV261);
        %init(Group_ZeroLatencyTouch_PhysicsV261);
        %init(Group_FastLaunch_SuperEngineV261);
        %init(Group_ScrollPerformance_SuperEngineV261);
        %init(Group_V261_FloatingWindow_PiP);
        %init(_ungrouped);

        if (Titanium_IsSpringBoard()) {
            %init(Group_Display_SpringBoardV261);
            %init(Group_SpringBoard_ProcessManagerV261);
        } else {
            %init(Group_UIKit_ThirdParty_IsolatedV261);
        }

        BOOL isKeyboardExtension = NO;
        if (bundleID) {
            isKeyboardExtension = [bundleID containsString:@"TextInputUI"] || 
                                  [bundleID containsString:@"InputUI"] || 
                                  [bundleID containsString:@"keyboard"];
        }
        if (Titanium_IsSpringBoard() || isKeyboardExtension || 
            (progName && (strstr(progName, "inputhost") || strstr(progName, "Keyboard")))) {
            %init(Group_Keyboard_And_TextV261);
        }

        // Chạy bất đồng bộ để chống treo màn hình đen khi respring hoặc reboot userspace
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
            Titanium_StartThermalWatchdogTimerV261();

            CFNotificationCenterRef darwinCenter = CFNotificationCenterGetDarwinNotifyCenter();
            if (darwinCenter) {
                CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)reloadPrefsNotificationV261,
                    CFSTR("com.taojb.boostiphone6s/ReloadPrefs"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);

                CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)reloadPrefsNotificationV261,
                    CFSTR("com.taojb.boostiphone6s/ReloadUIKitPrefs"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);

                CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)reloadPrefsNotificationV261,
                    CFSTR("com.titanium.v261.prefschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
            }

            if (Titanium_IsSpringBoard()) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    Titanium_StartPassiveRamDaemonV261();
                });
            }
        });
    }
}

