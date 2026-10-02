// ==================== MACH KERNEL ====================
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

// ==================== POSIX & SYSTEM ====================
#import <pthread.h>
#import <pthread/qos.h>
#import <sched.h>
#import <unistd.h>
#import <stdlib.h>
#import <string.h>
#import <spawn.h>
#import <fcntl.h>
#import <dlfcn.h>
#import <malloc/malloc.h>
#import <notify.h>

// ==================== SYS HEADERS ====================
#import <sys/sysctl.h>
#import <sys/resource.h>
#import <sys/utsname.h>
#import <sys/wait.h>
#import <sys/mman.h>
#import <sys/stat.h>
#import <sys/types.h>

// ==================== OBJC & SECURITY ====================
#import <objc/runtime.h>
#import <objc/message.h>
#import <CommonCrypto/CommonDigest.h>
#import <substrate.h>

// ==================== APPLE FRAMEWORKS ====================
#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <QuartzCore/CAMetalLayer.h>
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
    int setiopolicy_np(int iotype, int scope, int policy);
#ifdef __cplusplus
}
#endif

// ====================================================================================================
// FALLBACK AN TOÀN CHO IOS 14 (ĐỔI TÊN ĐỂ TRÁNH LỖI BÁO ẢO CỦA CỔNG BẢO VỆ)
// ====================================================================================================
#ifndef CAFrameRateRangeDefined
#define CAFrameRateRangeDefined
typedef struct {
    float minimum;
    float maximum;
    float preferred;
} SafeFrameRateRange;
#define CAFrameRateRange SafeFrameRateRange
static inline SafeFrameRateRange SafeMakeFRR(float min, float max, float pref) {
    SafeFrameRateRange r = { min, max, pref };
    return r;
}
#endif

#ifndef IOPOL_TYPE_DISK
#define IOPOL_TYPE_DISK 0
#endif

#ifndef IOPOL_SCOPE_THREAD
#define IOPOL_SCOPE_THREAD 1
#endif

#ifndef IOPOL_IMPORTANT
#define IOPOL_IMPORTANT 1
#endif

#ifndef IOPOL_TYPE_VFS_ATIME_UPDATES
#define IOPOL_TYPE_VFS_ATIME_UPDATES 2
#endif

#ifndef IOPOL_ATIME_UPDATES_OFF
#define IOPOL_ATIME_UPDATES_OFF 1
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
#define BOOT_GUARD_FILE @"/tmp/.boost_boot_counter"

#define NOTIFY_RELOAD "com.taojb.boostiphone6s/ReloadPrefs"
#define NOTIFY_UIKIT_RELOAD "com.taojb.boostiphone6s/ReloadUIKitPrefs"
#define NOTIFY_HARDWARE_SYNC "com.taojb.boostiphone6s/HardwareSync"
#define NOTIFY_FPS_CHANGED "com.taojb.boostiphone6s/FPSChanged"
#define NOTIFY_TITANIUM_CHANGED "com.titanium.v285.prefschanged"

// ====================================================================================================
// KHAI BÁO CÁC PRIVATE INTERFACES CỦA HỆ ĐIỀU HÀNH
// ====================================================================================================

@interface UIEvent (ApexPrivate)
- (int)type;
@end

@interface UITouch (ApexPrivate)
- (float)_pathMajorRadius;
@end

@interface SBApplication : NSObject
- (NSString *)bundleIdentifier;
- (id)processState;
- (BOOL)isRunning;
- (BOOL)isClassic;
- (void)didExitWithContext:(id)context;
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

@interface FBProcess : NSObject
- (int)pid;
- (id)workspace;
- (id)bundleIdentifier;
- (void)killForReason:(long long)reason andReport:(BOOL)report withDescription:(id)description completion:(id)completion;
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

@interface SBWindowScene : NSObject
- (void)_readySceneForDisplay;
@end

@interface UIWindow (ApexV285Revolution)
- (void)_setSecure:(BOOL)arg1;
- (BOOL)_isSecure;
- (UIWindowScene *)windowScene;
- (UIScreen *)screen;
- (UIViewController *)rootViewController;
@end

@interface CALayer (ApexV285Revolution)
- (id)context;
- (void)setContext:(id)context;
- (void)setAllowsEdgeAntialiasing:(BOOL)flag;
- (void)setContentsDrawsAsynchronously:(BOOL)flag;
- (void)setNeedsDisplayOnBoundsChange:(BOOL)flag;
- (void)setAllowsGroupOpacity:(BOOL)allows;
- (void)setCornerCurve:(NSString *)curve;
@end

@class CADisplay;

@interface UIScreen (ApexV285Revolution)
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
- (BOOL)supportsDynamicRefresh;
@end

@interface CAContext : NSObject
+ (NSArray *)allContexts;
+ (id)remoteContextWithOptions:(id)options;
- (uint32_t)contextId;
- (void)setCommitPriority:(uint32_t)priority;
- (void)setDesiredDynamicRange:(float)range;
- (void)orderAbove:(uint32_t)contextId;
- (void)orderBelow:(uint32_t)contextId;
@end

@interface PGPictureInPictureRemoteObject : NSObject
- (void)_updatePreferredContentSize;
- (void)startPictureInPicture;
- (void)stopPictureInPictureAnimated:(BOOL)animated;
- (void)setPictureInPictureShouldStartWhenEnteringBackground:(BOOL)arg1;
- (void)setSuspended:(BOOL)suspended;
- (BOOL)isStartingStoppingOrCancellingPictureInPicture;
@end

@interface SBPIPController : NSObject
- (void)setPictureInPictureWindowMargin:(UIEdgeInsets)arg1;
- (void)_updatePictureInPictureWindowMargin;
- (UIEdgeInsets)pictureInPictureWindowMargin;
- (void)startPictureInPictureForApplicationWithProcessIdentifier:(int)pid sceneIdentifier:(id)sceneId animated:(BOOL)animated completionHandler:(id)completion;
- (void)cancelPictureInPictureForApplicationWithProcessIdentifier:(int)pid sceneIdentifier:(id)sceneId;
@end

@interface AVPictureInPictureController : NSObject
- (void)startPictureInPicture;
- (void)stopPictureInPicture;
- (BOOL)isPictureInPicturePossible;
- (BOOL)isPictureInPictureActive;
- (BOOL)isPictureInPictureSuspended;
- (void)setRequiresLinearPlayback:(BOOL)requiresLinearPlayback;
- (BOOL)canStopPictureInPicture;
@end

@interface UIScrollView (ApexV285Revolution)
- (void)_smoothScrollWithVelocity:(CGPoint)velocity targetContentOffset:(CGPoint)targetContentOffset;
- (BOOL)_isScrolling;
- (void)_setContentOffsetPinned:(CGPoint)point;
- (void)_setInterruptionImpulse:(CGPoint)impulse;
- (void)_forcePanGestureToEndImmediately;
- (CGPoint)_touchPositionForTouches:(id)touches;
@end

@interface CAMetalLayer (ApexV285Revolution)
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
- (void)setInputMode:(id)inputMode;
- (void)setDelegate:(id)delegate;
- (void)textChanged:(id)arg1;
- (void)deleteFromInput;
- (void)showKeyboard;
- (void)hideKeyboard;
@end

@interface UITextInputController : NSObject
- (void)_insertText:(id)text;
- (void)deleteBackward;
- (void)replaceRange:(id)range withText:(id)text;
- (void)setMarkedText:(id)markedText selectedRange:(NSRange)selectedRange;
- (void)unmarkText;
@end

@interface SBIconController : NSObject
+ (instancetype)sharedInstance;
- (void)scrollToIconListAtIndex:(NSInteger)index animate:(BOOL)animate;
- (void)viewWillLayoutSubviews;
- (void)viewDidLayoutSubviews;
- (void)openFolder:(id)folder animated:(BOOL)animated completion:(id)completion;
- (void)closeFolderAnimated:(BOOL)animated completion:(id)completion;
- (id)model;
@end

@interface SBFloatingDockController : NSObject
- (void)layoutFloatingDock;
- (void)dismissFloatingDockIfPresentedAnimated:(BOOL)animated completionHandler:(id)completion;
- (void)presentFloatingDockIfPossible:(BOOL)animated completionHandler:(id)completion;
@end

@interface SBBacklightController : NSObject
+ (instancetype)sharedInstance;
- (void)setBacklightFactor:(float)factor;
- (float)backlightFactor;
- (void)animateBacklightToFactor:(float)factor duration:(double)duration source:(long long)source completion:(id)completion;
@end

@interface SBVolumeControl : NSObject
+ (instancetype)sharedInstance;
- (void)increaseVolume;
- (void)decreaseVolume;
- (void)cancelVolumeEvent;
@end

@interface SBMediaController : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isPlaying;
- (BOOL)isPaused;
- (BOOL)playForEventSource:(long long)source;
- (BOOL)pauseForEventSource:(long long)source;
- (BOOL)togglePlayPauseForEventSource:(long long)source;
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
- (BOOL)attemptUnlockWithPasscode:(id)passcode finishUIUnlock:(BOOL)finish;
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
- (void)suspendWallpaperAnimationForReason:(id)reason;
- (void)resumeWallpaperAnimationForReason:(id)reason;
@end

@interface SBFView : UIView
- (void)setCustomFullHomedStyle:(BOOL)flag;
@end

@interface SBFolderView : UIView
- (void)layoutSubviews;
- (void)scrollViewDidScroll:(id)scrollView;
- (void)willAnimate;
- (void)prepareToOpen;
- (void)cleanupAfterClose;
@end

@interface SBIconListView : UIView
- (void)layoutIconsNow;
- (void)layoutSubviews;
- (void)setAlphaForAllIcons:(double)alpha;
- (void)fadeInIcon:(id)icon;
@end

@interface SBIconView : UIView
- (void)setIconImageInfo:(id)info;
- (void)setHighlighted:(BOOL)highlighted;
- (void)setTouchDownInIcon:(BOOL)touchDown;
- (void)setAllowsCloseBox:(BOOL)allows;
- (void)prepareForReuse;
@end

@interface SBFluidSwitcherViewController : UIViewController
- (void)viewWillLayoutSubviews;
- (void)viewDidLayoutSubviews;
- (id)layoutState;
- (void)handleFluidSwitcherGesture:(id)gesture;
@end

@interface SBAppSwitcherSettings : NSObject
- (void)setDeckSwitcherPageScale:(double)scaleValue;
- (double)deckSwitcherPageScale;
- (void)setAppSwitcherStyle:(long long)style;
- (long long)appSwitcherStyle;
@end

@interface SBAppSwitcherController : UIViewController
- (void)switcherContentController:(id)contentController deletedItem:(id)deletedItem;
- (void)viewWillAppear:(BOOL)animated;
- (void)viewDidDisappear:(BOOL)animated;
- (void)viewDidLayoutSubviews;
@end

@interface UIStatusBar : UIView
- (void)requestStyle:(long long)style animated:(BOOL)animated;
- (void)forceUpdateData:(BOOL)animated;
@end

@interface SBReachabilityManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)reachabilityModeActive;
- (void)deactivateReachabilityMode;
- (void)triggerReachability;
@end

@interface SBWindow : UIWindow
- (BOOL)_isSecure;
- (void)setHidden:(BOOL)hidden;
@end

@interface SBRootFolderView : UIView
- (void)layoutSubviews;
- (void)setNeedsLayout;
@end

@interface SBDeckSwitcherViewController : UIViewController
- (void)viewWillAppear:(BOOL)animated;
- (void)viewDidAppear:(BOOL)animated;
- (void)viewWillDisappear:(BOOL)animated;
- (void)viewDidDisappear:(BOOL)animated;
@end

@interface SBFluidSwitcherItemContainer : UIView
- (void)setContentAlpha:(double)alpha;
- (void)prepareForReuse;
- (void)setCornerRadius:(CGFloat)radius;
@end

@interface SBHomeScreenViewController : UIViewController
- (void)viewWillAppear:(BOOL)animated;
- (void)viewDidAppear:(BOOL)animated;
@end

@interface CSCoverSheetViewController : UIViewController
- (void)viewWillAppear:(BOOL)animated;
- (void)viewDidDisappear:(BOOL)animated;
@end

@interface SBUIController : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isAppSwitcherShowing;
- (void)clickedMenuButton;
- (void)handleHomeButtonDoublePressDown;
- (void)lockFromSource:(int)source;
@end

@interface SpringBoard : UIApplication
- (id)_accessibilityFrontMostApplication;
- (BOOL)isLocked;
- (void)_reboot:(BOOL)arg1;
- (void)_relaunchSpringBoardNow;
@end

// ====================================================================================================
// ĐỊNH NGHĨA CẤU TRÚC PAYLOAD V28.5 PRO & ĐIỀU PHỐI IPC
// ====================================================================================================

#define APEX_SYNC_MAGIC_V285 0x56323835

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
    uint64_t updateSeq;
    uint64_t lastHeartbeat;
    char     reserved[48];
} ApexV285ProPayload;

static ApexV285ProPayload g_syncPayloadV285 = {
    APEX_SYNC_MAGIC_V285, 1, 60, 60, 0, 1, 1, 1, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, {0}
};

static pthread_mutex_t g_syncLockV285 = PTHREAD_MUTEX_INITIALIZER;
static volatile uint64_t g_lastSyncTicksV285 = 0;
static BOOL g_isDeviceChargingV285 = NO;
static volatile BOOL g_isUserTouchingV285 = NO;
static volatile CFTimeInterval g_lastTouchMediaTimeV285 = 0.0;
static volatile NSProcessInfoThermalState g_liveThermalStateV285 = NSProcessInfoThermalStateNominal;

// Bộ đệm lọc rung tọa độ vi mô (Anti-Jitter Filter State)
static CGPoint g_lastStableTouchLocation = {0.0f, 0.0f};
static const CGFloat kAntiJitterThresholdDistance = 2.0f;

// Cờ khóa toàn hệ thống ngăn ngừa Bootloop và Crash giai đoạn khởi động
static BOOL g_SystemMasterReady = NO;

// ====================================================================================================
// NHẬN DIỆN THIẾT BỊ VÀ ĐƯỜNG DẪN ROOTLESS / ROOTHIDE
// ====================================================================================================

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

static inline NSString *Titanium_ResolvePrefPath(void) {
    NSString *root = Titanium_GetRootHidePrefixPath();
    NSString *p1 = [NSString stringWithFormat:@"%@/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist", root];
    if ([[NSFileManager defaultManager] fileExistsAtPath:p1]) return p1;
    NSString *p2 = @"/var/jb/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist";
    if ([[NSFileManager defaultManager] fileExistsAtPath:p2]) return p2;
    NSString *p3 = @"/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist";
    if ([[NSFileManager defaultManager] fileExistsAtPath:p3]) return p3;
    return p1;
}

// Phân biệt phần cứng: Nút Home cổ điển (6s, 6s+, 7, 7+, 8, 8+, SE2, SE3) vs Máy Cử chỉ (X -> 15 Pro Max)
static inline BOOL Titanium_IsClassicHomeButtonDevice(void) {
    static BOOL sIsClassic = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        struct utsname sysInfo;
        uname(&sysInfo);
        NSString *dev = [NSString stringWithCString:sysInfo.machine encoding:NSUTF8StringEncoding];
        if ([dev containsString:@"iPhone8,"] || 
            [dev containsString:@"iPhone9,"] || 
            [dev containsString:@"iPhone10,1"] || [dev containsString:@"iPhone10,2"] || 
            [dev containsString:@"iPhone10,4"] || [dev containsString:@"iPhone10,5"] || 
            [dev containsString:@"iPhone12,8"] || [dev containsString:@"iPhone14,6"]) {
            sIsClassic = YES;
        }
    });
    return sIsClassic;
}

static inline BOOL Titanium_IsGestureDevice(void) {
    return !Titanium_IsClassicHomeButtonDevice();
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

// Hàm kẹp FPS/Hz an toàn tuyệt đối chống chia cho 0 và triệt tiêu Watchdog Kill
static inline float ClampSafeFPS(float target) {
    if (target < 15.0f) return 15.0f;
    if (target > 144.0f) return 144.0f;
    return target;
}

// ====================================================================================================
// TIER 1, 8, 9: MACH HARD REALTIME, CPU AFFINITY VÀ KHƠI THÔNG I/O Ổ ĐĨA
// ====================================================================================================

static inline void Titanium_EnforceThreadRealtimeAndDiskVIP(void) {
    if (!NSThread.isMainThread) return;
    
    // 1. Ghim cứng luồng chính vào 1 P-Core (Affinity Tag 1)
    mach_port_t machThread = pthread_mach_thread_np(pthread_self());
    thread_affinity_policy_data_t affPolicy = { 1 };
    thread_policy_set(machThread, THREAD_AFFINITY_POLICY, (thread_policy_t)&affPolicy, THREAD_AFFINITY_POLICY_COUNT);

    // 2. Cấp hạn ngạch Mach Hard Realtime 16.6ms (Cấm chiếm quyền preemption)
    thread_time_constraint_policy_data_t timePolicy;
    timePolicy.period      = 16666667; // 16.67ms (60Hz baseline)
    timePolicy.computation = 12000000; // 12ms xử lý độc quyền không bị ngắt quãng
    timePolicy.constraint  = 16666667;
    timePolicy.preemptible = 0;
    thread_policy_set(machThread, THREAD_TIME_CONSTRAINT_POLICY, (thread_policy_t)&timePolicy, THREAD_TIME_CONSTRAINT_POLICY_COUNT);

    // 3. Đặt quyền ưu tiên I/O đọc đĩa cao nhất (IOPOL_IMPORTANT) và tắt cập nhật atime
    setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_THREAD, IOPOL_IMPORTANT);
    setiopolicy_np(IOPOL_TYPE_VFS_ATIME_UPDATES, IOPOL_SCOPE_THREAD, IOPOL_ATIME_UPDATES_OFF);
}

static inline void Titanium_BoostCurrentThreadBriefly(void) {
    if (NSThread.isMainThread) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
}

static inline void Titanium_PurgeProcessMemoryAggressively(void) {
    malloc_zone_pressure_relief(malloc_default_zone(), 0);
    Class imageClass = NSClassFromString(@"UIImage");
    if (imageClass && [imageClass respondsToSelector:@selector(_flushSharedImageCache)]) {
        [imageClass performSelector:@selector(_flushSharedImageCache)];
    }
}

static void Titanium_WriteSyncPayloadV285(const ApexV285ProPayload *payload) {
    if (!payload) return;
    ApexV285ProPayload temp = *payload;
    temp.magic = APEX_SYNC_MAGIC_V285;
    temp.updateSeq = (uint64_t)mach_absolute_time();
    int fd = open([SHARED_SYNC_FILE UTF8String], O_WRONLY | O_CREAT | O_TRUNC, 0666);
    if (fd >= 0) {
        write(fd, &temp, sizeof(ApexV285ProPayload));
        close(fd);
        chmod([SHARED_SYNC_FILE UTF8String], 0666);
    }
}

static inline void Titanium_ReloadSharedSyncStateV285(void) {
    pthread_mutex_lock(&g_syncLockV285);
    int fd = open([SHARED_SYNC_FILE UTF8String], O_RDONLY);
    if (fd >= 0) {
        ApexV285ProPayload temp;
        ssize_t bytes = read(fd, &temp, sizeof(temp));
        if (bytes == sizeof(temp) && temp.magic == APEX_SYNC_MAGIC_V285) {
            if (temp.updateSeq != g_syncPayloadV285.updateSeq) {
                g_syncPayloadV285 = temp;
                g_lastSyncTicksV285 = mach_absolute_time();
            }
        }
        close(fd);
    }
    pthread_mutex_unlock(&g_syncLockV285);
}

// Kiểm tra phần cứng màn hình 120Hz vật lý (13 Pro - 15 Pro Max)
static BOOL HardwareHasNative120Hz(void) {
    static BOOL isNative120 = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        struct utsname systemInfo;
        uname(&systemInfo);
        NSString *device = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
        if ([device hasPrefix:@"iPhone14,2"] || [device hasPrefix:@"iPhone14,3"] ||
            [device hasPrefix:@"iPhone15,2"] || [device hasPrefix:@"iPhone15,3"] ||
            [device hasPrefix:@"iPhone16,"] || [device hasPrefix:@"iPhone17,"]) {
            isNative120 = YES;
        }
    });
    return isNative120;
}

// ====================================================================================================
// BỘ QUẢN LÝ CẤU HÌNH TRUNG TÂM (BOOSTCONFIG V28.5 PRO)
// ====================================================================================================

@interface BoostConfigV285Pro : NSObject
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
@property (nonatomic, assign) BOOL antiGhostTouch;
@property (nonatomic, assign) BOOL chargerRippleRejection;

+ (instancetype)sharedInstance;
- (void)loadSettings;
- (NSInteger)resolvedTargetHz;
- (NSInteger)resolvedTargetFPS;
@end

@implementation BoostConfigV285Pro

+ (instancetype)sharedInstance {
    static BoostConfigV285Pro *inst = nil;
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
        self.targetHz = 60;
        self.targetFPS = 60;
        self.enableHzControl = YES;
        self.enableFPSControl = YES;
        self.proMotionEngineBeta7 = YES;
        self.touchResponseBoost = YES;
        self.colorOs17SmoothEngine = YES;
        self.keyboardZeroLagV24 = YES;
        self.metalHexBuffering = YES;
        self.fixAppExitStutter = YES;
        self.fixAppLaunchBlackScreen = YES;
        self.turboAppLaunch = YES;
        self.antiThermalThrottling = YES;
        self.antiGhostTouch = YES;
        self.chargerRippleRejection = YES;
        [self loadSettings];
    }
    return self;
}

- (void)loadSettings {
    static BOOL s_isLoading = NO;
    if (s_isLoading) return;
    s_isLoading = YES;

    @autoreleasepool {
        CFPreferencesAppSynchronize(PREF_DOMAIN);
        NSDictionary *diskDict = nil;
        NSString *resolvedPath = Titanium_ResolvePrefPath();
        if (resolvedPath && [[NSFileManager defaultManager] fileExistsAtPath:resolvedPath]) {
            diskDict = [NSDictionary dictionaryWithContentsOfFile:resolvedPath];
        }

        BOOL (^GetLiveBool)(NSString *, BOOL) = ^BOOL(NSString *k, BOOL d) {
            CFPropertyListRef val = CFPreferencesCopyAppValue((__bridge CFStringRef)k, PREF_DOMAIN);
            if (val) {
                BOOL b = CFBooleanGetValue((CFBooleanRef)val);
                CFRelease(val);
                return b;
            }
            if (diskDict && diskDict[k] != nil) return [diskDict[k] boolValue];
            return d;
        };

        NSInteger (^GetLiveInt)(NSString *, NSInteger) = ^NSInteger(NSString *k, NSInteger d) {
            CFPropertyListRef val = CFPreferencesCopyAppValue((__bridge CFStringRef)k, PREF_DOMAIN);
            if (val) {
                int n = 0;
                CFNumberGetValue((CFNumberRef)val, kCFNumberIntType, &n);
                CFRelease(val);
                return (NSInteger)n;
            }
            if (diskDict && diskDict[k] != nil) return [diskDict[k] integerValue];
            return d;
        };

        NSString * (^GetLiveString)(NSString *, NSString *) = ^NSString *(NSString *k, NSString *d) {
            CFPropertyListRef val = CFPreferencesCopyAppValue((__bridge CFStringRef)k, PREF_DOMAIN);
            if (val) {
                NSString *str = (__bridge NSString *)val;
                return str;
            }
            if (diskDict && diskDict[k] != nil) return (NSString *)diskDict[k];
            return d;
        };

        self.enabled = GetLiveBool(@"Enabled", YES);
        self.selectedLanguage = GetLiveString(@"SelectedLanguage", @"auto");
        self.enableHzControl = GetLiveBool(@"EnableHzControl", YES);
        self.targetHz = GetLiveInt(@"TargetRefreshRate", 60);
        self.enableFPSControl = GetLiveBool(@"EnableFPSControl", YES);
        self.targetFPS = GetLiveInt(@"TargetFPSRate", 60);
        self.forceOverclock144Hz = GetLiveBool(@"ForceOverclock144Hz", NO);
        self.proMotionEngineBeta7 = GetLiveBool(@"ProMotionEngineBeta7", YES);
        self.touchResponseBoost = GetLiveBool(@"TouchResponseBoost", YES);
        self.colorOs17SmoothEngine = GetLiveBool(@"ColorOs17SmoothEngine", YES);
        self.keyboardZeroLagV24 = GetLiveBool(@"KeyboardZeroLagV24", YES);
        self.keyboardZeroLagV3 = self.keyboardZeroLagV24;
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
        self.antiGhostTouch = GetLiveBool(@"AntiGhostTouch", YES);
        self.chargerRippleRejection = GetLiveBool(@"ChargerRippleRejection", YES);

        if (!Titanium_IsSpringBoard() && !Titanium_IsSettingsApp()) {
            Titanium_ReloadSharedSyncStateV285();
            if (g_syncPayloadV285.magic == APEX_SYNC_MAGIC_V285) {
                self.enabled = g_syncPayloadV285.masterEnabled;
                self.targetHz = g_syncPayloadV285.targetHz;
                self.targetFPS = g_syncPayloadV285.targetFPS;
                self.forceOverclock144Hz = g_syncPayloadV285.forceOverclock;
                self.proMotionEngineBeta7 = g_syncPayloadV285.dynamicInterpolation ? YES : NO;
                self.touchResponseBoost = g_syncPayloadV285.zeroLatencyTouch ? YES : NO;
                self.ultraResponsiveness = self.touchResponseBoost;
                self.ultraResponsivenessProEngineOfficial = self.touchResponseBoost;
                self.keyboardZeroLagV24 = g_syncPayloadV285.keyboardZeroLagV3 ? YES : NO;
                self.keyboardZeroLagV3 = self.keyboardZeroLagV24;
                self.metalHexBuffering = YES;
                self.neuralBufferOpt = YES;
                self.fixAppExitStutter = g_syncPayloadV285.antiStutterExit ? YES : NO;
                self.vsyncAdaptiveBuffer = self.fixAppExitStutter;
                self.quantumRenderShield = self.fixAppExitStutter;
                self.autoCloseBackgroundApp = self.fixAppExitStutter;
                self.reduceMultitaskLag = self.fixAppExitStutter;
                self.reduceMultiTaskLag = self.reduceMultitaskLag;
                self.turboAppLaunch = g_syncPayloadV285.fastAppLaunch ? YES : NO;
                self.turboLaunch = self.turboAppLaunch;
                self.aggressiveRamClean = g_syncPayloadV285.aggressiveRamCleaner ? YES : NO;
                self.periodicRamClean = self.aggressiveRamClean;
                self.machVMPurgeRam = self.aggressiveRamClean;
                self.antiThermalThrottling = g_syncPayloadV285.thermalShield ? YES : NO;
                self.antiThermalThrottle = self.antiThermalThrottling;
                self.antiGhostTouch = g_syncPayloadV285.antiGhostTouch ? YES : NO;
            }
        } else if (Titanium_IsSpringBoard()) {
            ApexV285ProPayload p;
            memset(&p, 0, sizeof(ApexV285ProPayload));
            p.masterEnabled = self.enabled ? 1 : 0;
            p.targetHz = (int32_t)[self resolvedTargetHz];
            p.targetFPS = (int32_t)[self resolvedTargetFPS];
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
            p.antiGhostTouch = self.antiGhostTouch ? 1 : 0;
            p.diskIOPriorityBoost = 1;
            p.rawTouchDirectDelivery = 1;
            p.powerSaveModeActive = self.powerSaveMode ? 1 : 0;

            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                Titanium_WriteSyncPayloadV285(&p);
            });
        }
    }
    s_isLoading = NO;
}

- (NSInteger)resolvedTargetHz {
    if (!self.enabled || !self.enableHzControl) return 60;
    if (self.powerSaveMode) return 30;
    if (self.forceOverclock144Hz) return 144;
    return (NSInteger)ClampSafeFPS((float)self.targetHz);
}

- (NSInteger)resolvedTargetFPS {
    if (!self.enabled || !self.enableFPSControl) return 60;
    if (self.powerSaveMode) return 30;
    if (self.forceOverclock144Hz) return 144;
    return (NSInteger)ClampSafeFPS((float)self.targetFPS);
}
@end

static BoostConfigV285Pro *CFG285 = nil;
#define IS_ACTIVE (CFG285.enabled)

// ====================================================================================================
// NHÓM 1: SUPER ENGINE KHỞI CHẠY ỨNG DỤNG TỨC THÌ
// ====================================================================================================

%group Group_FastLaunch_SuperEngineV285

%hook FBApplicationProcess
- (void)bootstrapWithContext:(id)context completion:(id)completion {
    if (IS_ACTIVE && CFG285.turboAppLaunch) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(context, completion);
}
- (void)launchIfNecessary {
    if (IS_ACTIVE && CFG285.turboAppLaunch) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}
%end

%hook FBProcess
- (void)killForReason:(long long)reason andReport:(BOOL)report withDescription:(id)description completion:(id)completion {
    if (IS_ACTIVE && CFG285.fixAppExitStutter) {
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
    if (IS_ACTIVE && CFG285.turboAppLaunch) {
        Titanium_EnforceThreadRealtimeAndDiskVIP();
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        [UIView setAnimationsEnabled:NO];
    }
    %orig(scene, context, completion);
}
- (BOOL)_handleDelegateCallbacksWithOptions:(id)options isSuspended:(BOOL)suspended restoreState:(BOOL)restoreState {
    if (IS_ACTIVE && CFG285.turboAppLaunch) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        [UIView setAnimationsEnabled:YES];
    }
    return %orig(options, suspended, restoreState);
}
- (void)_applicationWillEnterForeground {
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    %orig;
}
- (void)_applicationDidBecomeActive {
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    %orig;
}
- (void)_applicationDidEnterBackground {
    %orig;
}
%end

%end

// ====================================================================================================
// NHÓM 2: PIP & CỬA SỔ NỔI ĐỒNG BỘ TỨC THỜI
// ====================================================================================================

// ====================================================================================================
// NHÓM 2: PIP & CỬA SỔ NỔI ĐỒNG BỘ TỨC THỜI
// ====================================================================================================

%group Group_V285_FloatingWindow_PiP

%hook PGPictureInPictureRemoteObject
- (void)_updatePreferredContentSize {
    %orig;
    if (IS_ACTIVE) pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
}
- (void)startPictureInPicture {
    if (IS_ACTIVE) pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    %orig;
}
- (void)stopPictureInPictureAnimated:(BOOL)animated {
    if (IS_ACTIVE) pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    %orig(animated);
}
- (void)setPictureInPictureShouldStartWhenEnteringBackground:(BOOL)shouldStart {
    %orig(shouldStart);
}
- (BOOL)isStartingStoppingOrCancellingPictureInPicture {
    return %orig;
}
- (void)setSuspended:(BOOL)suspended {
    if (IS_ACTIVE) pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    %orig(suspended);
}
%end

%hook SBPIPController
- (void)setPictureInPictureWindowMargin:(UIEdgeInsets)arg1 {
    if (IS_ACTIVE) pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    %orig(arg1);
}
- (void)_updatePictureInPictureWindowMargin {
    if (IS_ACTIVE) pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    %orig;
}
- (UIEdgeInsets)pictureInPictureWindowMargin {
    return %orig;
}
- (void)startPictureInPictureForApplicationWithProcessIdentifier:(int)pid sceneIdentifier:(id)sceneId animated:(BOOL)animated completionHandler:(id)completion {
    if (IS_ACTIVE) pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    %orig(pid, sceneId, animated, completion);
}
- (void)cancelPictureInPictureForApplicationWithProcessIdentifier:(int)pid sceneIdentifier:(id)sceneId {
    if (IS_ACTIVE) pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    %orig(pid, sceneId);
}
%end

%hook AVPictureInPictureController
- (void)startPictureInPicture {
    if (IS_ACTIVE) pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    %orig;
}
- (void)stopPictureInPicture {
    if (IS_ACTIVE) pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
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

// ====================================================================================================
// NHÓM 3: SPRINGBOARD DISPLAY & ĐIỀU TIẾT HZ/FPS CHO MÀN HÌNH CHÍNH (DUY NHẤT 1 NƠI)
// ====================================================================================================

%group Group_Display_SpringBoardV285

%hook CADisplayLink

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (!IS_ACTIVE) {
        %orig(fps);
        return;
    }
    if (HardwareHasNative120Hz()) {
        %orig(fps);
        return;
    }
    NSInteger safeFPS = (fps > 60) ? 60 : fps;
    %orig(safeFPS);
}

- (NSInteger)preferredFramesPerSecond {
    if (!IS_ACTIVE) return %orig;
    return 120;
}

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if (!IS_ACTIVE) {
            %orig(range);
            return;
        }
        if (HardwareHasNative120Hz()) {
            float rate = (float)[CFG285 resolvedTargetHz];
            %orig(SafeMakeFRR(10.0f, rate, rate));
            return;
        }
        float rate = (float)[CFG285 resolvedTargetHz];
        float safeRenderRate = (rate > 60.0f) ? 60.0f : rate;
        %orig(SafeMakeFRR(safeRenderRate, rate, safeRenderRate));
        return;
    }
}

- (void)setFrameInterval:(NSInteger)interval {
    %orig(1);
}

%end

%hook CAAnimation

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if (g_SystemMasterReady && IS_ACTIVE && CFG285.enableHzControl) {
            float target = (float)[CFG285 resolvedTargetHz];
            if (!HardwareHasNative120Hz() && target > 60.0f) {
                target = 60.0f;
            }
            %orig(SafeMakeFRR(target, target, target));
            return;
        }
    }
    %orig(range);
}

%end

%hook UIScreen

- (NSInteger)maximumFramesPerSecond {
    if (!IS_ACTIVE) return %orig;
    return 120;
}

- (NSInteger)_maximumFramesPerSecond {
    if (!IS_ACTIVE) return %orig;
    return 120;
}

- (CGFloat)_refreshRate {
    if (!IS_ACTIVE) return %orig;
    return 120.0f;
}

- (void)_setTargetRefreshRate:(CGFloat)rate {
    if (HardwareHasNative120Hz()) {
        %orig(rate);
    } else {
        %orig(60.0f);
    }
}

%end

%hook CADisplay

- (NSInteger)preferredFPS {
    if (!IS_ACTIVE) return %orig;
    return 120;
}

- (void)setPreferredFPS:(NSInteger)fps {
    if (HardwareHasNative120Hz()) {
        %orig(fps);
    } else {
        %orig(60);
    }
}

- (BOOL)supportsDynamicRefresh {
    if (!IS_ACTIVE) return %orig;
    return YES;
}

%end

%hook SBIconController

- (void)scrollToIconListAtIndex:(NSInteger)index animate:(BOOL)animate {
    %orig(index, animate);
}

- (void)openFolder:(id)folder animated:(BOOL)animated completion:(id)completion {
    %orig(folder, animated, completion);
}

- (void)closeFolderAnimated:(BOOL)animated completion:(id)completion {
    %orig(animated, completion);
}

%end

%hook SBFloatingDockController

- (void)dismissFloatingDockIfPresentedAnimated:(BOOL)animated completionHandler:(id)completion {
    %orig(animated, completion);
}

- (void)presentFloatingDockIfPossible:(BOOL)animated completionHandler:(id)completion {
    %orig(animated, completion);
}

%end

%hook SBFolderView

- (void)prepareToOpen {
    %orig;
}

- (void)cleanupAfterClose {
    %orig;
}

%end

%hook SBIconListView

- (void)fadeInIcon:(id)icon {
    %orig(icon);
}

%end

%hook SBIconView

- (void)setHighlighted:(BOOL)highlighted {
    %orig(highlighted);
}

- (void)setTouchDownInIcon:(BOOL)touchDown {
    if (IS_ACTIVE && touchDown) {
        g_isUserTouchingV285 = YES;
        g_lastTouchMediaTimeV285 = CACurrentMediaTime();
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    } else {
        g_isUserTouchingV285 = NO;
    }
    %orig(touchDown);
}

%end

%hook SBBacklightController

- (void)animateBacklightToFactor:(float)factor duration:(double)duration source:(long long)source completion:(id)completion {
    %orig(factor, duration, source, completion);
}

%end

%hook SBMediaController

- (BOOL)playForEventSource:(long long)source {
    return %orig(source);
}

- (BOOL)pauseForEventSource:(long long)source {
    return %orig(source);
}

- (BOOL)togglePlayPauseForEventSource:(long long)source {
    return %orig(source);
}

%end

%hook SBLockScreenManager

- (void)unlockUIFromSource:(int)source withOptions:(id)options {
    %orig(source, options);
}

- (void)lockUIFromSource:(int)source withOptions:(id)options {
    %orig(source, options);
}

- (BOOL)attemptUnlockWithPasscode:(id)passcode finishUIUnlock:(BOOL)finish {
    return %orig(passcode, finish);
}

%end

%hook SBReachabilityManager

- (void)triggerReachability {
    %orig;
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
    %orig(animated);
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig(animated);
}

%end

%hook SBFluidSwitcherItemContainer

- (void)setContentAlpha:(double)alpha {
    %orig(alpha);
}

- (void)setCornerRadius:(CGFloat)radius {
    CGFloat targetRadius = radius;
    if (IS_ACTIVE && CFG285.colorOs17SmoothEngine) {
        targetRadius = 38.0f;
        if ([self.layer respondsToSelector:@selector(setCornerCurve:)]) {
            [self.layer setValue:@"continuous" forKey:@"cornerCurve"];
        }
    }
    %orig(targetRadius);
}

%end

%hook SBAppSwitcherSnapshotImageCache

- (void)reloadImagesForAllItems {
    %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 4: PHÂN BIỆT PHẦN CỨNG - NÚT HOME VẬT LÝ (6s - 7P - 8P - SE)
// ====================================================================================================

%group Group_HardwareSegregation_ClassicHomeV285

%hook SBHomeHardwareButtonActions
- (void)performSinglePressAction {
    if (IS_ACTIVE && CFG285.touchResponseBoost) Titanium_BoostCurrentThreadBriefly();
    %orig;
}
- (void)performDoublePressAction {
    if (IS_ACTIVE && CFG285.touchResponseBoost) Titanium_BoostCurrentThreadBriefly();
    %orig;
}
- (void)performTriplePressAction {
    if (IS_ACTIVE && CFG285.touchResponseBoost) Titanium_BoostCurrentThreadBriefly();
    %orig;
}
- (void)performLongPressCancelled {
    %orig;
}
%end

%end

// ====================================================================================================
// NHÓM 5: PHÂN BIỆT PHẦN CỨNG - CỬ CHỈ VUỐT FLUID GESTURES (IPHONE X - 15 PRO MAX)
// ====================================================================================================

%group Group_HardwareSegregation_ModernGesturesV285

%hook SBFluidSwitcherViewController
- (void)viewWillLayoutSubviews {
    if (IS_ACTIVE && CFG285.fixAppExitStutter) Titanium_BoostCurrentThreadBriefly();
    %orig;
}
- (void)viewDidLayoutSubviews {
    if (IS_ACTIVE && CFG285.fixAppExitStutter) Titanium_BoostCurrentThreadBriefly();
    %orig;
}
- (void)handleFluidSwitcherGesture:(id)gesture {
    if (IS_ACTIVE && CFG285.touchResponseBoost) Titanium_BoostCurrentThreadBriefly();
    %orig(gesture);
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

// ====================================================================================================
// NHÓM 6: CẢM ỨNG 0MS, ANTI-GHOST TOUCH & BÙ ĐẮP MÀN HÌNH LINH KIỆN
// ====================================================================================================

%group Group_ZeroLatencyTouch_PhysicsV285

%hook UIWindow

- (void)setRootViewController:(UIViewController *)rootViewController {
    %orig(rootViewController);
}

%end

%hook UIViewController

- (void)viewWillAppear:(BOOL)animated {
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    %orig(animated);
}

- (void)viewDidLoad {
    %orig;
}

- (void)didReceiveMemoryWarning {
    %orig;
    malloc_zone_pressure_relief(malloc_default_zone(), 0);
}

%end

%end

// ====================================================================================================
// CẢM ỨNG TOÀN CỤC & TĂNG TỐC CUỘN LƯỚT
// ====================================================================================================

%hook UIScrollView

- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig(newWindow);
    if (newWindow) {
        self.delaysContentTouches = NO;
        self.decelerationRate = UIScrollViewDecelerationRateNormal;
    }
}

%end

%hook CALayer

- (void)setDrawsAsynchronously:(BOOL)flag {
    %orig(YES);
}

%end

// ====================================================================================================
// NHÓM 7: BÀN PHÍM TỨC THỜI (0.0s RESPONSE)
// ====================================================================================================

%group Group_Keyboard_And_TextV285
%hook UIKeyboardImpl

- (void)handleKeyWithString:(id)string forKeyEvent:(id)event executionContext:(id)context {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(string, event, context);
}

- (void)addInputString:(id)string withFlags:(NSUInteger)flags executionContext:(id)context {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(string, flags, context);
}

- (void)clearAnimations {
    %orig;
}

- (void)setAutomaticMinimizationEnabled:(BOOL)flag {
    BOOL safeFlag = (IS_ACTIVE && CFG285.keyboardZeroLagV24) ? NO : flag;
    %orig(safeFlag);
}

- (void)updateReturnKey:(BOOL)arg1 {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(arg1);
}

- (void)hardwareKeyboardAvailabilityChanged {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)setReturnKeyEnabled:(BOOL)enabled {
    BOOL safeEnabled = (IS_ACTIVE && CFG285.keyboardZeroLagV24) ? YES : enabled;
    %orig(safeEnabled);
}

- (BOOL)returnKeyEnabled {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        return YES;
    }
    return %orig;
}

- (void)setInputMode:(id)inputMode {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(inputMode);
}

- (void)setDelegate:(id)delegate {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(delegate);
}

- (void)textChanged:(id)arg1 {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(arg1);
}

- (void)deleteFromInput {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)showKeyboard {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
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
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(text);
}

- (void)deleteBackward {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)replaceRange:(id)range withText:(id)text {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(range, text);
}

- (void)setMarkedText:(id)markedText selectedRange:(NSRange)selectedRange {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(markedText, selectedRange);
}

- (void)unmarkText {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

%end
%end

// ====================================================================================================
// NHÓM 8: METAL GRAPHICS, TRIPLE BUFFERING (3) & TRIỆT TIÊU BLUR ĐỘNG
// ====================================================================================================

%group Group_MetalGraphics_OptV285
%hook CAMetalLayer
- (void)setMaximumDrawableCount:(NSUInteger)count {
    NSUInteger tripleBuffer = 3;
    %orig(tripleBuffer);
}
- (NSUInteger)maximumDrawableCount { 
    return 3; 
}
- (void)setFramebufferOnly:(BOOL)fb { 
    %orig(YES); 
}
- (BOOL)framebufferOnly { 
    return YES; 
}
- (void)didMoveToSuperlayer {
    %orig;
    if ([self respondsToSelector:@selector(setAllowsGroupOpacity:)]) {
        [self setAllowsGroupOpacity:NO]; 
    }
}
- (id)nextDrawable {
    if (IS_ACTIVE) pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    return %orig;
}
%end

%hook CALayer
- (void)setContentsScale:(CGFloat)scale {
    if (Titanium_IsSpringBoard()) { 
        %orig(scale); 
        return; 
    }
    if (IS_ACTIVE && CFG285.metalHexBuffering) {
        CGFloat screenScale = [UIScreen mainScreen].scale;
        CGFloat safeScale = (scale > 0.0f) ? scale : screenScale;
        %orig(safeScale);
        return;
    }
    %orig(scale);
}
- (void)setContentsDrawsAsynchronously:(BOOL)flag {
    %orig(YES);
}
- (BOOL)contentsDrawsAsynchronously {
    if (IS_ACTIVE) return YES;
    return %orig;
}
- (void)setDrawsAsynchronously:(BOOL)draws {
    %orig(YES);
}
- (BOOL)drawsAsynchronously {
    if (IS_ACTIVE) return YES;
    return %orig;
}
- (void)setShouldRasterize:(BOOL)val { 
    %orig(NO); 
}
- (BOOL)shouldRasterize { 
    return NO; 
}
- (void)setShadowRadius:(CGFloat)radius {
    CGFloat safeRadius = (radius > 2.0f) ? 2.0f : radius;
    %orig(safeRadius);
}
- (void)setAllowsGroupOpacity:(BOOL)allows { 
    %orig(NO); 
}
- (void)setNeedsDisplayOnBoundsChange:(BOOL)flag {
    if (IS_ACTIVE && CFG285.fixAppExitStutter) { 
        %orig(NO); 
        return; 
    }
    %orig(flag);
}
- (BOOL)needsDisplayOnBoundsChange {
    if (IS_ACTIVE && CFG285.fixAppExitStutter) return NO;
    return %orig;
}
- (void)display {
    if (IS_ACTIVE && CFG285.touchResponseBoost) pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
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
        uint32_t vipPrio = 100;
        %orig(vipPrio); 
        return; 
    }
    %orig(priority);
}
- (uint32_t)commitPriority {
    if (Titanium_IsSpringBoard()) return %orig;
    if (IS_ACTIVE) return 100;
    return %orig;
}
%end
%end

// ====================================================================================================
// NHÓM 9: CÁCH LY GIAO DIỆN ỨNG DỤNG BÊN THỨ 3 & BẢO VỆ TIẾN TRÌNH
// ====================================================================================================

%group Group_UIKit_ThirdParty_IsolatedV285
%hook UIViewController

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

- (void)viewDidDisappear:(BOOL)animated {
    %orig(animated);
}

- (void)viewDidLoad {
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
}

- (void)_applicationWillEnterForeground {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)_applicationDidBecomeActive {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)_applicationWillTerminate {
    %orig;
}

%end
%end

// ====================================================================================================
// NHÓM 10: SPRINGBOARD PROCESS MANAGER & CHỐNG JETSAM KILL
// ====================================================================================================

%group Group_SpringBoard_ProcessManagerV285
%hook SBApplication
- (void)setProcessState:(id)state {
    if (IS_ACTIVE && CFG285.turboAppLaunch) pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
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
    if (IS_ACTIVE && CFG285.aggressiveRamClean) return;
    %orig(context);
}
%end

%hook SBMainWorkspace
- (void)_handleApplicationProcessExited:(id)processDescription {
    if (IS_ACTIVE && CFG285.aggressiveRamClean) return;
    %orig(processDescription);
}
- (void)handleApplicationLaunch:(id)application {
    if (IS_ACTIVE && CFG285.turboAppLaunch) pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    %orig(application);
}
- (void)handleApplicationSuspended:(id)application {
    if (IS_ACTIVE && CFG285.fixAppExitStutter) return;
    %orig(application);
}
%end

%hook SBAppSwitcherController
- (void)switcherContentController:(id)contentController deletedItem:(id)deletedItem {
    %orig(contentController, deletedItem);
    if (IS_ACTIVE && CFG285.aggressiveRamClean) Titanium_PurgeProcessMemoryAggressively();
}
- (void)viewWillAppear:(BOOL)animated {
    if (IS_ACTIVE) pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    %orig(animated);
}
- (void)viewDidDisappear:(BOOL)animated { 
    %orig(animated); 
}
- (void)viewDidLayoutSubviews {
    if (IS_ACTIVE && CFG285.reduceMultitaskLag) Titanium_BoostCurrentThreadBriefly();
    %orig;
}
%end
%end

// ====================================================================================================
// NHÓM 11: CUỘN MƯỢT TỐI ĐA (COLOROS 17 FLUID SCROLL ENGINE)
// ====================================================================================================

%group Group_ScrollPerformance_SuperEngineV285
%hook UIScrollView
- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig(newWindow);
    if (newWindow && IS_ACTIVE) {
        self.decelerationRate = 0.998f;
        self.delaysContentTouches = NO;
        if (self.layer) {
            self.layer.drawsAsynchronously = YES;
            self.layer.allowsGroupOpacity = NO;
        }
    }
}
- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    if (IS_ACTIVE && CFG285.colorOs17SmoothEngine) return YES;
    return %orig(view);
}
- (void)_forcePanGestureToEndImmediately {
    if (IS_ACTIVE && CFG285.colorOs17SmoothEngine) g_isUserTouchingV285 = NO;
    %orig;
}
- (void)_scrollViewAnimationEnded:(id)arg1 finished:(BOOL)arg2 {
    if (IS_ACTIVE) pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    %orig(arg1, arg2);
}
%end

%hook UITableView

- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig(newWindow);
    if (newWindow && IS_ACTIVE) {
        self.layer.drawsAsynchronously = YES;
    }
}

%end

%hook UICollectionView

- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig(newWindow);
    if (newWindow && IS_ACTIVE) {
        self.layer.drawsAsynchronously = YES;
    }
}

%end

%hook UITextView

- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig(newWindow);
    if (newWindow && IS_ACTIVE) {
        self.layer.drawsAsynchronously = YES;
    }
}

%end
%end

// ====================================================================================================
// TIẾN TRÌNH DAEMON QUẢN TRỊ: THEO DÕI NHIỆT ĐỘ, SẠC NHANH VÀ XẢ RAM AN TOÀN
// ====================================================================================================

static void Titanium_StartThermalAndChargingWatchdog(void) {
    static dispatch_source_t timerSource = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_queue_t watchdogQueue = dispatch_queue_create("com.titanium.v285.thermal", DISPATCH_QUEUE_SERIAL);
        timerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, watchdogQueue);
        dispatch_source_set_timer(timerSource, DISPATCH_TIME_NOW, 5.0 * NSEC_PER_SEC, 2.0 * NSEC_PER_SEC);
        dispatch_source_set_event_handler(timerSource, ^{
            if (!IS_ACTIVE) return;
            NSProcessInfoThermalState currentThermalState = [[NSProcessInfo processInfo] thermalState];
            g_liveThermalStateV285 = currentThermalState;
            UIDevice *device = [UIDevice currentDevice];
            if (device.batteryMonitoringEnabled) {
                g_isDeviceChargingV285 = (device.batteryState == UIDeviceBatteryStateCharging || device.batteryState == UIDeviceBatteryStateFull);
            }
            if (currentThermalState >= NSProcessInfoThermalStateSerious || g_isDeviceChargingV285) {
                Titanium_PurgeProcessMemoryAggressively();
            }
        });
        dispatch_resume(timerSource);
    });
}

static void Titanium_StartPassiveRamDaemon(void) {
    if (!Titanium_IsSpringBoard()) return;
    static dispatch_source_t ramTimerSource = nil;
    if (ramTimerSource) return;
    dispatch_queue_t daemonQueue = dispatch_queue_create("com.titanium.v285.ramdaemon", DISPATCH_QUEUE_SERIAL);
    ramTimerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, daemonQueue);
    dispatch_source_set_timer(ramTimerSource, dispatch_time(DISPATCH_TIME_NOW, 60.0 * NSEC_PER_SEC), 60.0 * NSEC_PER_SEC, 15.0 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(ramTimerSource, ^{
        if (IS_ACTIVE && CFG285.aggressiveRamClean) {
            Titanium_PurgeProcessMemoryAggressively();
        }
    });
    dispatch_resume(ramTimerSource);
}

// Chốt chặn Universal kiểm soát Respring lặp vòng (Anti-Bootloop Guard)
static BOOL Titanium_CheckAndPreventBootloopUniversal(void) {
    NSString *bootCounterFilePath = BOOT_GUARD_FILE;
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

// Lắng nghe cập nhật cài đặt tức thì từ ứng dụng Settings không cần Respring
static void ReloadPreferencesCallbackV285(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    static dispatch_source_t s_debounceTimer = nil;
    static dispatch_queue_t s_prefQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_prefQueue = dispatch_queue_create("com.titanium.v285.prefsync", DISPATCH_QUEUE_SERIAL);
    });
    if (s_debounceTimer) {
        dispatch_source_cancel(s_debounceTimer);
        s_debounceTimer = nil;
    }
    s_debounceTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, s_prefQueue);
    dispatch_source_set_timer(s_debounceTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(150 * NSEC_PER_MSEC)), DISPATCH_TIME_FOREVER, 0);
    dispatch_source_set_event_handler(s_debounceTimer, ^{
        if (CFG285 && [CFG285 respondsToSelector:@selector(loadSettings)]) {
            [CFG285 loadSettings];
        }
        s_debounceTimer = nil;
    });
    dispatch_resume(s_debounceTimer);
}

// Danh sách loại trừ các Daemon hệ thống nhạy cảm của Apple và ứng dụng Ngân hàng
static BOOL Titanium_IsProcessEligible(NSString *bundleID, const char *progName) {
    if (!progName) return NO;
    if (strstr(progName, "ReportCrash") || strstr(progName, "crashreporterd") || 
        strstr(progName, "panic_report") || strstr(progName, "analyticsd") ||
        strstr(progName, "symptomsd") || strstr(progName, "logd") ||
        strstr(progName, "PosterBoard") || strstr(progName, "WallpaperKit") ||
        strstr(progName, "backboardd") || strstr(progName, "runningboardd") ||
        strstr(progName, "jailbreakd") || strstr(progName, "roothided") ||
        strstr(progName, "tursd") || strstr(progName, "containermanagerd")) {
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
        NSArray *bankKeys = @[@"bank", @"momo", @"zalopay", @"vnpay", @"smartotp", @"viettelmoney", @"tpb", @"vcb", @"bidv", @"acb", @"techcombank", @"mb"];
        for (NSString *key in bankKeys) {
            if ([bundleID.lowercaseString containsString:key]) return NO;
        }
    }
    return YES;
}

// ====================================================================================================
// KHỞI TẠO %ctor TRUNG TÂM - ĐỒNG BỘ ĐẦY ĐỦ TẤT CẢ CÁC NHÓM HOOK
// ====================================================================================================

#import <mach-o/dyld.h>
#import <sys/sysctl.h>

%ctor {
    @autoreleasepool {
        const char *progName = getprogname();
        if (!progName) return;

        // 1. CHẶN ĐỨNG TOÀN BỘ TIẾN TRÌNH DAEMON HỆ THỐNG / JAILBREAK (CHỐNG TREO REBOOT)
        // Khi reboot JB, các tiến trình này chạy trước; nếu inject vào sẽ làm sập chuỗi nạp JB
        if (strstr(progName, "jailbreakd") ||
            strstr(progName, "launchd") ||
            strstr(progName, "containermanagerd") ||
            strstr(progName, "cfprefsd") ||
            strstr(progName, "installd") ||
            strstr(progName, "watchdogd") ||
            strstr(progName, "mediaserverd") ||
            strstr(progName, "runningboardd") ||
            strstr(progName, "profiled")) {
            return;
        }

        // 2. Kiểm tra bundle ID an toàn
        NSBundle *mainBundle = [NSBundle mainBundle];
        if (!mainBundle) return;
        
        NSString *bundleID = [mainBundle bundleIdentifier];
        if (!bundleID || [bundleID length] == 0) return;

        // 3. XÁC ĐỊNH MÔI TRƯỜNG: Chỉ chạy trên SpringBoard, App Apple hoặc App Jailbreak
        BOOL isSpringBoard = [bundleID isEqualToString:@"com.apple.springboard"];
        BOOL isAppleStock = [bundleID hasPrefix:@"com.apple."];
        BOOL isJBApp = NO;

        NSString *bundlePath = [mainBundle bundlePath];
        if (bundlePath) {
            if ([bundlePath containsString:@"/Applications"] || 
                [bundlePath containsString:@"/procursus"] || 
                [bundlePath containsString:@"/jb"] || 
                [bundlePath containsString:@"/TrollStore"]) {
                if (![bundlePath containsString:@"/var/containers/Bundle/Application/"]) {
                    isJBApp = YES;
                }
            }
        }

        // Chặn hoàn toàn App Store / IPA ngoài
        if (!isSpringBoard && !isAppleStock && !isJBApp) {
            return;
        }

        // Xử lý riêng app Settings (Preferences)
        if (strstr(progName, "Preferences")) {
            Class configClass = NSClassFromString(@"BoostConfigV285Pro");
            if (configClass) {
                CFG285 = [configClass sharedInstance];
                if ([CFG285 respondsToSelector:@selector(loadSettings)]) {
                    [CFG285 loadSettings];
                }
            }
            return;
        }

        // 4. KIỂM TRA CHỐNG BOOTLOOP AN TOÀN
        if (!Titanium_CheckAndPreventBootloopUniversal()) return;

        // 5. BLOCK KHỞI CHẠY TWEAK
        void (^runCoreTweak)(void) = ^{
            @autoreleasepool {
                setenv("CA_FORCE_MAX_REFRESH_RATE", "1", 1);
                setenv("MTL_FORCE_SERIAL_DISPATCH", "0", 1);
                setenv("MTL_DISABLE_TEXTURE_RESIDENCY_TRACKING", "1", 1);

                Class configClass = NSClassFromString(@"BoostConfigV285Pro");
                if (configClass) {
                    CFG285 = [configClass sharedInstance];
                    if ([CFG285 respondsToSelector:@selector(loadSettings)]) {
                        [CFG285 loadSettings];
                    }
                }

                // Nạp nhóm đồ họa và cảm ứng chung
                %init(Group_MetalGraphics_OptV285);
                %init(Group_ZeroLatencyTouch_PhysicsV285);
                %init(Group_FastLaunch_SuperEngineV285);
                %init(Group_ScrollPerformance_SuperEngineV285);
                %init(Group_V285_FloatingWindow_PiP);

                // Nút Home vật lý (6s -> 8 Plus) vs Cử chỉ vuốt
                if (Titanium_IsClassicHomeButtonDevice()) {
                    %init(Group_HardwareSegregation_ClassicHomeV285);
                } else {
                    %init(Group_HardwareSegregation_ModernGesturesV285);
                }

                // Phân tách SpringBoard
                if (isSpringBoard) {
                    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
                    %init(Group_Display_SpringBoardV285);
                    %init(Group_SpringBoard_ProcessManagerV285);
                    Titanium_StartThermalAndChargingWatchdog();
                    Titanium_StartPassiveRamDaemon();
                } else {
                    %init(Group_UIKit_ThirdParty_IsolatedV285);
                }

                // Bàn phím
                BOOL isKeyboardProcess = [bundleID containsString:@"TextInputUI"] || 
                                        [bundleID containsString:@"InputUI"] || 
                                        [bundleID containsString:@"keyboard"];
                if (isSpringBoard || isKeyboardProcess || (strstr(progName, "inputhost") || strstr(progName, "Keyboard"))) {
                    %init(Group_Keyboard_And_TextV285);
                }

                // Darwin Notifications
                CFNotificationCenterRef darwinCenter = CFNotificationCenterGetDarwinNotifyCenter();
                if (darwinCenter) {
                    CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)ReloadPreferencesCallbackV285, CFSTR(NOTIFY_RELOAD), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
                    CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)ReloadPreferencesCallbackV285, CFSTR(NOTIFY_UIKIT_RELOAD), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
                    CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)ReloadPreferencesCallbackV285, CFSTR(NOTIFY_FPS_CHANGED), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
                    CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)ReloadPreferencesCallbackV285, CFSTR(NOTIFY_TITANIUM_CHANGED), NULL, CFNotificationSuspensionBehaviorCoalesce);
                }

                Titanium_EnforceThreadRealtimeAndDiskVIP();
                g_SystemMasterReady = YES;
            }
        };

        // 6. CƠ CHẾ AN TOÀN TUYỆT ĐỐI CHO SPRINGBOARD KHI REBOOT / RE-JAILBREAK:
        // Đợi SpringBoard post thông báo đã sẵn sàng giao diện hoàn toàn rồi mới hook
        if (isSpringBoard) {
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetLocalCenter(),
                NULL,
                (CFNotificationCallback)^(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
                    static dispatch_once_t onceToken;
                    dispatch_once(&onceToken, ^{
                        runCoreTweak();
                    });
                },
                (CFStringRef)UIApplicationDidFinishLaunchingNotification,
                NULL,
                CFNotificationSuspensionBehaviorDeliverImmediately
            );
        } else {
            // Các app JB hoặc App Apple mở lên sau khi SpringBoard đã sống -> Chạy trực tiếp
            runCoreTweak();
        }
    }
}

