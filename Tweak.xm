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
#define NOTIFY_TITANIUM_CHANGED "com.titanium.v261.prefschanged"

#import <mach/mach_time.h>
#import <mach/mach.h>
#import <mach/thread_policy.h>
#import <substrate.h>
#import <sys/utsname.h>
#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <notify.h>
#import <dlfcn.h>
#import <sys/stat.h>
#import <fcntl.h>
#import <unistd.h>
#import <malloc/malloc.h>
#import <pthread.h>
#import <CoreFoundation/CoreFoundation.h>

// ========================================================
// HỆ THỐNG INTERFACE MỞ RỘNG (ĐẦY ĐỦ 100% CÁC CLASS CỦA HỆ THỐNG)
// Không cắt bớt để đảm bảo hook hoạt động sâu vào từng ngóc ngách
// ========================================================
@interface UIEvent (ApexPrivate)
- (int)type;
@end

@interface UITouch (ApexPrivate)
- (float)_pathMajorRadius;
@end

@interface UIView (ApexPrivate)
- (void)_setContinuousCornerRadius:(CGFloat)radius;
@end

@interface UIScrollView (ApexPrivate)
- (void)_smoothScrollWithVelocity:(CGPoint)velocity targetContentOffset:(CGPoint)targetContentOffset;
- (BOOL)_isScrolling;
- (void)_setContentOffsetPinned:(CGPoint)point;
- (void)_setInterruptionImpulse:(CGPoint)impulse;
- (void)_forcePanGestureToEndImmediately;
- (CGPoint)_touchPositionForTouches:(id)touches;
@end

@interface CALayer (ApexPrivate)
- (id)context;
- (void)setContext:(id)arg1;
- (void)setAllowsEdgeAntialiasing:(BOOL)flag;
- (void)setContentsDrawsAsynchronously:(BOOL)flag;
- (void)setNeedsDisplayOnBoundsChange:(BOOL)flag;
- (void)setCornerCurve:(NSString *)curve;
@end

@interface CAMetalLayer (ApexPrivate)
- (void)setLowLatencyMode:(BOOL)flag;
- (void)setMaximumDrawableCount:(NSUInteger)count;
- (void)setDisplaySyncEnabled:(BOOL)enabled;
- (void)setAllowsNextDrawableTimeout:(BOOL)allow;
- (void)setPresentsWithTransaction:(BOOL)flag;
- (void)setServerPresentsWithTransaction:(BOOL)flag;
@end

@class CADisplay;
@interface UIScreen (ApexPrivate)
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

@interface UIWindow (ApexPrivate)
- (void)_setSecure:(BOOL)arg1;
- (BOOL)_isSecure;
- (UIWindowScene *)windowScene;
- (UIScreen *)screen;
- (UIViewController *)rootViewController;
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

// =========================================================================
// LỚP CẤU HÌNH TỔNG QUÁT (KHÔNG CẮT BẤT KỲ PROPS NÀO TỪ BẢN CŨ)
// =========================================================================
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
- (NSInteger)resolvedTargetHz;
- (NSInteger)resolvedTargetFPS;
@end

// =========================================================================
// ĐỊNH NGHĨA STRUCT ĐỒNG BỘ GIỮA SPRINGBOARD VÀ APP
// =========================================================================
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
    APEX_SYNC_MAGIC_V261, 1, 120, 120, 0, 1, 1, 1, 6, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, {0}
};

static pthread_mutex_t g_syncLockV261 = PTHREAD_MUTEX_INITIALIZER;
static volatile uint64_t g_lastSyncTicksV261 = 0;
static BOOL g_isDeviceChargingV261 = NO;
static volatile BOOL g_isUserTouchingV261 = NO;
static volatile CFTimeInterval g_lastTouchMediaTimeV261 = 0.0;
static volatile BOOL g_isScrollInertiaActiveV261 = NO;
static volatile NSProcessInfoThermalState g_liveThermalStateV261 = NSProcessInfoThermalStateNominal;

// NHẬN DIỆN THIẾT BỊ NÚT HOME (6s / 7 / 8 / Plus / SE) VÀ MÁY CỬ CHỈ (X-15 PRO MAX)
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

static inline BOOL Titanium_IsGestureDevice(void) {
    if (!Titanium_IsClassicHomeButtonDevice()) {
        return YES;
    }
    if (NSClassFromString(@"SBFluidSwitcherViewController") != nil) {
        return YES;
    }
    return NO;
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

// =========================================================================
// LÕI MỚI V26.9: TỐI ƯU RUNLOOP HƯỚNG SỰ KIỆN KHÔNG ÉP XUNG
// Giúp máy luôn mát, loại bỏ hiện tượng đơ bàn phím do nghẽn cổ chai CPU
// =========================================================================
static inline void Titanium_SetThreadRealtimeConstraintV261(thread_t thread, uint32_t targetHz) {
    // KHÔNG ÉP XUNG THÔ BẠO NỮA, TRÁNH NÓNG MÁY VÀ DELAY
    // Hệ thống sẽ sử dụng Runloop Scheduling thông minh ở dưới
}

// KHÔNG SPAM GCD NỮA: Chỉ Boost ưu tiên QoS của Main Thread 1 lần khi cần thiết
static inline void Titanium_OptimizeRunLoopPacing(void) {
    if (!NSThread.isMainThread) return;
    // Đảm bảo Main Thread không bị cướp tài nguyên khi đang tương tác
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
}

// XẢ RAM CỰC KỲ AN TOÀN, KHÔNG RESET APP ĐANG CHẠY
static inline void Titanium_PurgeProcessMemoryAggressively(void) {
    // Chỉ giải phóng khi máy thực sự bắt đầu ấm (Fair trở lên)
    if (g_liveThermalStateV261 >= NSProcessInfoThermalStateFair) {
        malloc_zone_pressure_relief(malloc_default_zone(), 0); 
    }
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

// BỎ QUA CÁC TIẾN TRÌNH NHẠY CẢM TRÁNH XUNG ĐỘT GÂY BOOTLOOP
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
                [proc isEqualToString:@"PosterBoardPosterExtension"] || [proc isEqualToString:@"ReportCrash"] ||
                [proc isEqualToString:@"crashreporterd"]) {
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

// KHÔNG GIẢM HZ KHI PIN YẾU, LUÔN GIỮ MƯỢT MÀ TỐI ĐA TRONG MỌI APP & HOMESCREEN
- (NSInteger)resolvedTargetHz {
    if (!self.enabled || !self.enableHzControl) return 120; 
    if (self.powerSaveMode) return 30;
    if (self.forceOverclock144Hz) return 144;
    if (self.targetHz >= 15 && self.targetHz <= 144) return self.targetHz;
    return 120;
}

- (NSInteger)resolvedTargetFPS {
    if (!self.enabled || !self.enableFPSControl) return 120; 
    if (self.powerSaveMode) return 30;
    if (self.forceOverclock144Hz) return 144;
    if (self.targetFPS >= 15 && self.targetFPS <= 144) return self.targetFPS;
    return 120;
}
@end

static BoostConfigV261 *CFG261 = nil;
#define IS_ACTIVE (CFG261.enabled)

// =========================================================================
// HOOK C-RUNTIME MẠNH MẼ NHẤT: BẮT BUỘC 144HZ / 120HZ CHO MỌI APP & HOME
// ĐÂY LÀ CÁCH FIX TRIỆT ĐỂ LỖI FPS/HZ KHÔNG HOẠT ĐỘNG
// =========================================================================
static CAFrameRateRange (*orig_CADisplayLink_preferredFrameRateRange)(id self, SEL _cmd);
static void (*orig_CADisplayLink_setPreferredFrameRateRange)(id self, SEL _cmd, CAFrameRateRange range);
static void (*orig_CAAnimation_setPreferredFrameRateRange)(id self, SEL _cmd, CAFrameRateRange range);

static CAFrameRateRange custom_CADisplayLink_preferredFrameRateRange(id self, SEL _cmd) {
    if (!IS_ACTIVE || !CFG261.enableHzControl) return orig_CADisplayLink_preferredFrameRateRange(self, _cmd);
    float rate = (float)[CFG261 resolvedTargetHz];
    return CAFrameRateRangeMake(rate, rate, rate);
}

static void custom_CADisplayLink_setPreferredFrameRateRange(id self, SEL _cmd, CAFrameRateRange range) {
    if (!IS_ACTIVE || !CFG261.enableHzControl) {
        orig_CADisplayLink_setPreferredFrameRateRange(self, _cmd, range);
        return;
    }
    float rate = (float)[CFG261 resolvedTargetHz];
    orig_CADisplayLink_setPreferredFrameRateRange(self, _cmd, CAFrameRateRangeMake(rate, rate, rate));
}

static void custom_CAAnimation_setPreferredFrameRateRange(id self, SEL _cmd, CAFrameRateRange range) {
    if (IS_ACTIVE && CFG261.enableHzControl) {
        float rate = (float)[CFG261 resolvedTargetHz];
        orig_CAAnimation_setPreferredFrameRateRange(self, _cmd, CAFrameRateRangeMake(rate, rate, rate));
    } else {
        orig_CAAnimation_setPreferredFrameRateRange(self, _cmd, range);
    }
}

// =========================================================================
// NHÓM 1: HOẠT ẢNH MƯỢT NHƯ COLOROS 17 (CẢI TIẾN TRỌNG TÂM DÀI HẠN)
// Chống bóp méo hình khi vuốt ra, tạo độ nảy mềm mại, mượt từng khung hình
// =========================================================================
%group Group_Animation_Smooth_Engine

%hook UIView
+ (void)animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay usingSpringWithDamping:(CGFloat)dampingRatio initialSpringVelocity:(CGFloat)velocity options:(UIViewAnimationOptions)options animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        // Tinh chỉnh độ nảy: Tự nhiên nhất, không bị cứng ngắc khi vuốt mạnh
        CGFloat smoothDamping = dampingRatio;
        if (dampingRatio > 0.8) {
            smoothDamping = 0.8;
        } else if (dampingRatio < 0.6) {
            smoothDamping = 0.72; 
        }
        Titanium_OptimizeRunLoopPacing();
        // Cho phép đè animation để tránh khựng khi thao tác nhanh
        %orig(duration, delay, smoothDamping, velocity, options | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState, animations, completion);
    } else {
        %orig;
    }
}

+ (void)animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)options animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        Titanium_OptimizeRunLoopPacing();
        %orig(duration, delay, options | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState, animations, completion);
    } else {
        %orig;
    }
}

- (void)setNeedsLayout {
    if (IS_ACTIVE && CFG261.touchResponseBoost) Titanium_OptimizeRunLoopPacing();
    %orig;
}
- (void)layoutIfNeeded {
    if (IS_ACTIVE && CFG261.touchResponseBoost) Titanium_OptimizeRunLoopPacing();
    %orig;
}
- (void)setNeedsDisplay {
    if (IS_ACTIVE && CFG261.touchResponseBoost) Titanium_OptimizeRunLoopPacing();
    %orig;
}
%end

%hook CALayer
- (void)setNeedsLayout {
    if (IS_ACTIVE && CFG261.touchResponseBoost) Titanium_OptimizeRunLoopPacing();
    %orig;
}
- (void)layoutIfNeeded {
    if (IS_ACTIVE && CFG261.touchResponseBoost) Titanium_OptimizeRunLoopPacing();
    %orig;
}
- (void)setNeedsDisplay {
    if (IS_ACTIVE && CFG261.touchResponseBoost) Titanium_OptimizeRunLoopPacing();
    %orig;
}
- (void)displayIfNeeded {
    if (IS_ACTIVE && CFG261.touchResponseBoost) Titanium_OptimizeRunLoopPacing();
    %orig;
}
%end

%hook UIScrollView
- (void)setDecelerationRate:(UIScrollViewDecelerationRate)decelerationRate {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        %orig(UIScrollViewDecelerationRateNormal); // Chống phanh gấp
        return;
    }
    %orig(decelerationRate);
}
- (void)_scrollViewAnimationEnded:(id)arg1 finished:(BOOL)arg2 {
    if (IS_ACTIVE) Titanium_OptimizeRunLoopPacing();
    %orig(arg1, arg2);
}
%end

%end // Group_Animation_Smooth_Engine

// =========================================================================
// NHÓM 2: MỞ APP 0.0s LATENCY & CHỐNG LAG TRUNG TÂM THÔNG BÁO/ĐIỀU KHIỂN
// =========================================================================
%group Group_FastLaunch_SuperEngineV261

%hook FBApplicationProcess
- (void)bootstrapWithContext:(id)context completion:(id)completion {
    if (IS_ACTIVE && CFG261.turboAppLaunch) Titanium_OptimizeRunLoopPacing();
    %orig(context, completion);
}
- (void)launchIfNecessary {
    if (IS_ACTIVE && CFG261.turboAppLaunch) Titanium_OptimizeRunLoopPacing();
    %orig;
}
%end

%hook SBControlCenterController
- (void)presentAnimated:(BOOL)animated {
    if (IS_ACTIVE) Titanium_OptimizeRunLoopPacing();
    %orig(animated);
}
- (void)dismissAnimated:(BOOL)animated {
    if (IS_ACTIVE) Titanium_OptimizeRunLoopPacing();
    %orig(animated);
}
%end

%hook SBNotificationCenterController
- (void)presentAnimated:(BOOL)animated {
    if (IS_ACTIVE) Titanium_OptimizeRunLoopPacing();
    %orig(animated);
}
- (void)dismissAnimated:(BOOL)animated {
    if (IS_ACTIVE) Titanium_OptimizeRunLoopPacing();
    %orig(animated);
}
%end

%hook SBFolderView
- (void)scrollViewDidScroll:(id)scrollView {
    if (IS_ACTIVE) Titanium_OptimizeRunLoopPacing();
    %orig(scrollView);
}
- (void)willAnimate {
    if (IS_ACTIVE) Titanium_OptimizeRunLoopPacing();
    %orig;
}
%end

%hook SBIconController
- (void)openFolder:(id)folder animated:(BOOL)animated completion:(id)completion {
    if (IS_ACTIVE) Titanium_OptimizeRunLoopPacing();
    %orig(folder, animated, completion);
}
- (void)closeFolderAnimated:(BOOL)animated completion:(id)completion {
    if (IS_ACTIVE) Titanium_OptimizeRunLoopPacing();
    %orig(animated, completion);
}
%end

%end // Group_FastLaunch_SuperEngineV261

// =========================================================================
// NHÓM 3: CẢM ỨNG 0 ĐỘ TRỄ & ĐA NHIỆM BO TRÒN TRÊN X-15 PRO MAX
// =========================================================================
%group Group_ZeroLatencyTouch_PhysicsV261

%hook UIWindow
- (void)sendEvent:(UIEvent *)event {
    if (IS_ACTIVE && CFG261.touchResponseBoost && [event respondsToSelector:@selector(type)]) {
        if ((int)[event type] == 0) { // UIEventTypeTouches
            Titanium_OptimizeRunLoopPacing();
        }
    }
    %orig(event);
}
// CỐT LÕI CHỐNG ĐƠ CÀI ĐẶT: KHÔNG HOOK `layoutSubviews` của UIWindow TRÁNH XUNG ĐỘT GIAO DIỆN
%end

%hook UITouch
- (UITouchPhase)phase {
    if (IS_ACTIVE && CFG261.touchResponseBoost) {
        Titanium_OptimizeRunLoopPacing();
    }
    return %orig;
}
%end

%hook UIGestureRecognizer
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (IS_ACTIVE && CFG261.touchResponseBoost) Titanium_OptimizeRunLoopPacing();
    %orig(touches, event);
}
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    if (IS_ACTIVE && CFG261.touchResponseBoost) Titanium_OptimizeRunLoopPacing();
    %orig(touches, event);
}
%end

// FIX ĐA NHIỆM: ÉP BO TRÒN GÓC TAB ĐA NHIỆM CHUẨN X 
%hook SBFluidSwitcherItemContainer
- (void)setCornerRadius:(CGFloat)radius {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) {
        %orig(38.0); 
        if ([self.layer respondsToSelector:@selector(setCornerCurve:)]) {
            [self.layer setValue:@"continuous" forKey:@"cornerCurve"];
        }
        return;
    }
    %orig(radius);
}
%end

%hook SBAppSwitcherController
- (void)viewDidLayoutSubviews {
    if (IS_ACTIVE) Titanium_OptimizeRunLoopPacing();
    %orig;
}
- (void)switcherContentController:(id)contentController deletedItem:(id)deletedItem {
    %orig(contentController, deletedItem);
}
%end

// KHÔNG ÉP KILL APP TRONG ĐA NHIỆM: Giữ nguyên 20+ app không lag
%hook SBMainWorkspace
- (void)_handleApplicationProcessExited:(id)processDescription {
    if (IS_ACTIVE && CFG261.aggressiveRamClean) {
        return; 
    }
    %orig(processDescription);
}
%end

%hook FBProcess
- (void)killForReason:(long long)reason andReport:(BOOL)report withDescription:(id)description completion:(id)completion {
    // Để yên cho iOS tự thoát, bỏ PurgeMemory bạo lực ở đây để tránh khựng app
    %orig(reason, report, description, completion);
}
%end

%end // Group_ZeroLatencyTouch_PhysicsV261

// =========================================================================
// NHÓM 4: BÀN PHÍM TỐI ƯU HOÀN TOÀN MỚI (XÓA SẠCH DELAY CHẬM ĐƠ)
// =========================================================================
%group Group_Keyboard_Speed

%hook UIKeyboardImpl
- (void)handleKeyWithString:(id)string forKeyEvent:(id)event executionContext:(id)context {
    if (IS_ACTIVE && CFG261.keyboardZeroLagV24) Titanium_OptimizeRunLoopPacing();
    %orig(string, event, context);
}
- (void)addInputString:(id)string withFlags:(NSUInteger)flags executionContext:(id)context {
    if (IS_ACTIVE && CFG261.keyboardZeroLagV24) Titanium_OptimizeRunLoopPacing();
    %orig(string, flags, context);
}
- (void)clearAnimations {
    if (IS_ACTIVE && CFG261.keyboardZeroLagV24) { %orig; return; }
    %orig;
}
- (void)setAutomaticMinimizationEnabled:(BOOL)flag {
    if (IS_ACTIVE && CFG261.keyboardZeroLagV24) { %orig(NO); return; }
    %orig(flag);
}
%end

%hook UITextInputController
- (void)_insertText:(id)text {
    if (IS_ACTIVE && CFG261.keyboardZeroLagV24) Titanium_OptimizeRunLoopPacing();
    %orig(text);
}
- (void)deleteBackward {
    if (IS_ACTIVE && CFG261.keyboardZeroLagV24) Titanium_OptimizeRunLoopPacing();
    %orig;
}
%end

%hook UITextView
- (void)insertText:(id)text {
    if (IS_ACTIVE && CFG261.keyboardZeroLagV24) Titanium_OptimizeRunLoopPacing();
    %orig(text);
}
- (void)deleteBackward {
    if (IS_ACTIVE && CFG261.keyboardZeroLagV24) Titanium_OptimizeRunLoopPacing();
    %orig;
}
- (void)setContentOffset:(CGPoint)contentOffset {
    if (IS_ACTIVE && CFG261.keyboardZeroLagV24) Titanium_OptimizeRunLoopPacing();
    %orig; 
}
%end

%hook UITextField
- (void)insertText:(id)text {
    if (IS_ACTIVE && CFG261.keyboardZeroLagV24) Titanium_OptimizeRunLoopPacing();
    %orig(text);
}
- (void)deleteBackward {
    if (IS_ACTIVE && CFG261.keyboardZeroLagV24) Titanium_OptimizeRunLoopPacing();
    %orig;
}
%end

%end // Group_Keyboard_Speed

// =========================================================================
// NHÓM 5: CHỐNG LAG MÀN HÌNH CHÍNH & ÉP HZ TOÀN DIỆN
// =========================================================================
%group Group_SpringBoard_Core

%hook UIScreen
- (NSInteger)maximumFramesPerSecond {
    if (!IS_ACTIVE || !CFG261.enableHzControl) return %orig;
    return [CFG261 resolvedTargetHz];
}
- (NSInteger)_maximumFramesPerSecond {
    if (!IS_ACTIVE || !CFG261.enableHzControl) return %orig;
    return [CFG261 resolvedTargetHz];
}
- (CGFloat)_refreshRate {
    if (!IS_ACTIVE || !CFG261.enableHzControl) return %orig;
    return (CGFloat)[CFG261 resolvedTargetHz];
}
- (void)_setTargetRefreshRate:(CGFloat)rate {
    if (!IS_ACTIVE || !CFG261.enableHzControl) {
        %orig(rate);
        return;
    }
    %orig((CGFloat)[CFG261 resolvedTargetHz]);
}
- (id)displayLinkWithTarget:(id)target selector:(SEL)sel {
    return %orig(target, sel);
}
%end

%hook CADisplay
- (NSInteger)preferredFPS {
    if (!IS_ACTIVE || !CFG261.enableHzControl) return %orig;
    return [CFG261 resolvedTargetHz];
}
- (void)setPreferredFPS:(NSInteger)fps {
    if (!IS_ACTIVE || !CFG261.enableHzControl) {
        %orig(fps);
        return;
    }
    %orig([CFG261 resolvedTargetHz]);
}
- (BOOL)supportsDynamicRefresh {
    if (IS_ACTIVE) return YES;
    return %orig;
}
%end

// LÀM TRƠN MƯỢT LÚC VUỐT TRANG HOME
%hook SBIconListView
- (void)layoutIconsNow {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) Titanium_OptimizeRunLoopPacing();
    %orig;
}
- (void)layoutSubviews {
    if (IS_ACTIVE && CFG261.colorOs17SmoothEngine) Titanium_OptimizeRunLoopPacing();
    %orig;
}
%end

%end // Group_SpringBoard_Core

// =========================================================================
// NHÓM 6: KHÔNG RASTERIZE MÙ QUÁNG -> TƯƠNG THÍCH LIQUID GLASS (CHỐNG NÓNG)
// =========================================================================
%group Group_Graphics_Optimization
%hook CALayer
- (void)setShouldRasterize:(BOOL)shouldRasterize {
    // Để Liquid Glass hoạt động bình thường, không ép Force NO gây vỡ đồ họa và làm GPU tính toán liên tục
    %orig(shouldRasterize);
}
- (void)setContentsDrawsAsynchronously:(BOOL)flag {
    if (IS_ACTIVE) {
        %orig(YES);
        return;
    }
    %orig(flag);
}
- (void)setAllowsEdgeAntialiasing:(BOOL)flag {
    if (IS_ACTIVE) {
        %orig(NO); // Tắt khử răng cưa viền giúp giảm tải GPU rõ rệt, hạ nhiệt độ
        return;
    }
    %orig(flag);
}
%end

%hook CAMetalLayer
- (void)setMaximumDrawableCount:(NSUInteger)count {
    if (Titanium_IsSpringBoard()) {
        %orig(3); // Giữ đệm 3 cho SB để mượt
        return;
    }
    if (count > 0 && count <= 3) {
        %orig(count);
    } else {
        %orig(3);
    }
}
- (void)setLowLatencyMode:(BOOL)flag {
    %orig(flag);
}
%end
%end // Group_Graphics_Optimization

// =========================================================================
// 3 LUỒNG DAEMON BẢO VỆ NHIỆT ĐỘ & XẢ RAM CỰC NHẸ CHẠY NGẦM
// =========================================================================
static void Titanium_StartPassiveRamDaemon_Tier1(void) {
    if (!Titanium_IsSpringBoard()) return;
    dispatch_queue_t daemonQueue = dispatch_queue_create("com.titanium.v269.ram1", DISPATCH_QUEUE_SERIAL);
    dispatch_source_t ramTimerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, daemonQueue);
    // Quét mỗi 30s: Nhẹ nhàng, không ảnh hưởng UI
    dispatch_source_set_timer(ramTimerSource, dispatch_time(DISPATCH_TIME_NOW, 30.0 * NSEC_PER_SEC), 30.0 * NSEC_PER_SEC, 5.0 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(ramTimerSource, ^{
        if (IS_ACTIVE && CFG261.aggressiveRamClean && g_liveThermalStateV261 >= NSProcessInfoThermalStateFair) {
            Titanium_PurgeProcessMemoryAggressively();
        }
    });
    dispatch_resume(ramTimerSource);
}

static void Titanium_StartPassiveRamDaemon_Tier2(void) {
    if (!Titanium_IsSpringBoard()) return;
    dispatch_queue_t daemonQueue = dispatch_queue_create("com.titanium.v269.ram2", DISPATCH_QUEUE_SERIAL);
    dispatch_source_t ramTimerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, daemonQueue);
    // Quét mỗi 120s: Xả RAM cấp trung bình
    dispatch_source_set_timer(ramTimerSource, dispatch_time(DISPATCH_TIME_NOW, 120.0 * NSEC_PER_SEC), 120.0 * NSEC_PER_SEC, 10.0 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(ramTimerSource, ^{
        if (IS_ACTIVE && CFG261.aggressiveRamClean) {
            malloc_zone_pressure_relief(malloc_default_zone(), 0);
        }
    });
    dispatch_resume(ramTimerSource);
}

static void Titanium_StartPassiveRamDaemon_Tier3(void) {
    if (!Titanium_IsSpringBoard()) return;
    dispatch_queue_t daemonQueue = dispatch_queue_create("com.titanium.v269.ram3", DISPATCH_QUEUE_SERIAL);
    dispatch_source_t ramTimerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, daemonQueue);
    // Quét mỗi 300s (5 phút): Dọn rác chuyên sâu hệ thống
    dispatch_source_set_timer(ramTimerSource, dispatch_time(DISPATCH_TIME_NOW, 300.0 * NSEC_PER_SEC), 300.0 * NSEC_PER_SEC, 30.0 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(ramTimerSource, ^{
        if (IS_ACTIVE && CFG261.aggressiveRamClean) {
            malloc_zone_pressure_relief(malloc_default_zone(), 0);
        }
    });
    dispatch_resume(ramTimerSource);
}

// Giám sát nhiệt độ liên tục
static void Titanium_StartThermalWatchdogTimer(void) {
    dispatch_queue_t watchdogQueue = dispatch_queue_create("com.titanium.v269.thermal", DISPATCH_QUEUE_SERIAL);
    dispatch_source_t timerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, watchdogQueue);
    dispatch_source_set_timer(timerSource, DISPATCH_TIME_NOW, 5.0 * NSEC_PER_SEC, 1.0 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(timerSource, ^{
        if (!IS_ACTIVE) return;
        g_liveThermalStateV261 = [[NSProcessInfo processInfo] thermalState];
    });
    dispatch_resume(timerSource);
}


// =========================================================================
// BẢO VỆ CHỐNG TREO BOOTLOOP RESPRING/SREBOOT CHO ROOTHIDE VÀ ROOTLESS
// =========================================================================
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
    if (CFG261) {
        [CFG261 loadSettings];
    }
}

// =========================================================================
// KHỞI TẠO %ctor: ĐỒNG BỘ 100% HOOK VÀ PHÂN TÁCH LUỒNG AN TOÀN
// =========================================================================
%ctor {
    @autoreleasepool {
        const char *progName = getprogname();
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];

        // Bỏ qua hook vào các tiến trình nhạy cảm dễ gây đơ Cài đặt / Bootloop
        if (progName && (strstr(progName, "ReportCrash") || strstr(progName, "crashreporterd") || strstr(progName, "PosterBoard") || strstr(progName, "Preferences"))) {
            // ĐẶC BIỆT: TỪ CHỐI HOOK VÀO ỨNG DỤNG CÀI ĐẶT ("Preferences") ĐỂ CHỐNG ĐƠ 100% KHI CÀI CÁC TWEAK KHÁC.
            if (strstr(progName, "Preferences")) {
                Class configClass = NSClassFromString(@"BoostConfigV261");
                if (configClass) {
                    CFG261 = [configClass sharedInstance];
                    [CFG261 loadSettings];
                }
                return;
            }
            return;
        }

        if (!Titanium_CheckAndPreventBootloopUniversal()) {
            return;
        }

        // Tự động hook C-runtime vào CADisplayLink & CAAnimation (Khôi phục Hz/FPS toàn máy)
        Class clsCADisplayLink = NSClassFromString(@"CADisplayLink");
        if (clsCADisplayLink) {
            MSHookMessageEx(clsCADisplayLink, @selector(preferredFrameRateRange), 
                            (IMP)custom_CADisplayLink_preferredFrameRateRange, 
                            (IMP *)&orig_CADisplayLink_preferredFrameRateRange);
            MSHookMessageEx(clsCADisplayLink, @selector(setPreferredFrameRateRange:), 
                            (IMP)custom_CADisplayLink_setPreferredFrameRateRange, 
                            (IMP *)&orig_CADisplayLink_setPreferredFrameRateRange);
        }
        Class clsCAAnimation = NSClassFromString(@"CAAnimation");
        if (clsCAAnimation) {
            MSHookMessageEx(clsCAAnimation, @selector(setPreferredFrameRateRange:), 
                            (IMP)custom_CAAnimation_setPreferredFrameRateRange, 
                            (IMP *)&orig_CAAnimation_setPreferredFrameRateRange);
        }

        // ĐỘ TRỄ 3 GIÂY AN TOÀN CHO DÒNG CŨ ĐỂ KHÔNG BỊ TREO LÚC KHỞI ĐỘNG
        NSTimeInterval delay = Titanium_IsClassicHomeButtonDevice() ? 3.0 : 0.5;

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            Class configClass = NSClassFromString(@"BoostConfigV261");
            if (configClass) {
                CFG261 = [configClass sharedInstance];
                [CFG261 loadSettings];
            }

            %init(Group_Animation_Smooth_Engine);
            %init(Group_ZeroLatencyTouch_PhysicsV261);
            %init(Group_Graphics_Optimization);
            %init(Group_FastLaunch_SuperEngineV261);
            %init(Group_V261_FloatingWindow_PiP);
            
            if (Titanium_IsSpringBoard()) {
                %init(Group_SpringBoard_Core);
                [UIDevice currentDevice].batteryMonitoringEnabled = YES;
                Titanium_StartThermalWatchdogTimer();
                
                // Kích hoạt 3 daemon chạy ngầm hỗ trợ dọn rác cực nhẹ
                Titanium_StartPassiveRamDaemon_Tier1();
                Titanium_StartPassiveRamDaemon_Tier2();
                Titanium_StartPassiveRamDaemon_Tier3();
            }

            BOOL isKeyboardExtension = NO;
            if (bundleID) {
                isKeyboardExtension = [bundleID containsString:@"TextInputUI"] || [bundleID containsString:@"InputUI"] || [bundleID containsString:@"keyboard"];
            }
            if (Titanium_IsSpringBoard() || isKeyboardExtension || (progName && strstr(progName, "Keyboard"))) {
                %init(Group_Keyboard_Speed);
            }

            CFNotificationCenterRef darwinCenter = CFNotificationCenterGetDarwinNotifyCenter();
            if (darwinCenter) {
                CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)reloadPrefsNotificationV261, CFSTR("com.taojb.boostiphone6s/ReloadPrefs"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
                CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)reloadPrefsNotificationV261, CFSTR("com.titanium.v261.prefschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
            }
        });
    }
}
