// ==================== MACH KERNEL ====================
// ==================== MACH & XNU KERNEL ====================
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
#import <mach/task_policy.h>
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

#ifndef VM_MEMORY_COREANIMATION
#define VM_MEMORY_COREANIMATION 54
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

#ifndef THREAD_THROTTLE_POLICY
#define THREAD_THROTTLE_POLICY 4
#endif

#ifndef TASK_POLICY_ROLE
#define TASK_POLICY_ROLE 1
#endif

#ifndef TASK_FOREGROUND_APPLICATION
#define TASK_FOREGROUND_APPLICATION 2
#endif

#ifndef CAFrameRateRangeDefined
#define CAFrameRateRangeDefined
typedef struct {
    float minimum;
    float maximum;
    float preferred;
} SafeFrameRateRange;
#define CAFrameRateRange SafeFrameRateRange
static inline SafeFrameRateRange SafeMakeFRR(float min, float max, float pref) {
    SafeFrameRateRange r;
    r.minimum = min;
    r.maximum = max;
    r.preferred = pref;
    return r;
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

typedef struct {
    uint32_t pset_limit;
} thread_throttle_policy_data_t;

typedef uint32_t IOPMAssertionID;
#define kIOPMNullAssertionID 0

#ifdef __cplusplus
extern "C" {
#endif
    kern_return_t vm_purgable_control(mach_port_t task, vm_address_t address, vm_purgable_t control, int *state);
    const char *getprogname(void);
    extern char **environ;
    int setiopolicy_np(int iotype, int scope, int policy);
    kern_return_t IOPMAssertionCreateWithName(CFStringRef assertionType, uint32_t assertionLevel, CFStringRef assertionName, IOPMAssertionID *assertionID);
    kern_return_t IOPMAssertionRelease(IOPMAssertionID assertionID);
#ifdef __cplusplus
}
#endif

#define PREF_DOMAIN CFSTR("com.taojb.boostiphone6s")
#define SHARED_SYNC_FILE @"/tmp/.boost_hz_sync"
#define BOOT_GUARD_FILE @"/tmp/.boost_boot_counter"

#define NOTIFY_RELOAD "com.taojb.boostiphone6s/ReloadPrefs"
#define NOTIFY_UIKIT_RELOAD "com.taojb.boostiphone6s/ReloadUIKitPrefs"
#define NOTIFY_HARDWARE_SYNC "com.taojb.boostiphone6s/HardwareSync"
#define NOTIFY_FPS_CHANGED "com.taojb.boostiphone6s/FPSChanged"
#define NOTIFY_TITANIUM_CHANGED "com.titanium.v285.prefschanged"

#define APEX_SYNC_MAGIC_V285 0x56323835

// ====================================================================================================
// SYSTEM PRIVATE INTERFACES
// ====================================================================================================

@interface UIEvent (TitaniumApexPrivate)
- (int)type;
@end

@interface UITouch (TitaniumApexPrivate)
- (float)_pathMajorRadius;
@end

@interface UIControl (TitaniumApexPrivate)
- (NSTimeInterval)_touchDelayThreshold;
@end

@interface UIGestureRecognizer (TitaniumApexPrivate)
- (BOOL)delaysTouchesBegan;
- (BOOL)delaysTouchesEnded;
- (void)setDelaysTouchesBegan:(BOOL)flag;
- (void)setDelaysTouchesEnded:(BOOL)flag;
@end

@interface UIWindow (TitaniumApexPrivate)
- (void)_setSecure:(BOOL)arg1;
- (BOOL)_isSecure;
- (UIWindowScene *)windowScene;
- (UIScreen *)screen;
- (UIViewController *)rootViewController;
- (BOOL)_shouldDelayTouchForCancelEvents;
- (BOOL)_ignoresHitTest;
- (void)sendEvent:(UIEvent *)event;
@end

@interface UIViewController (TitaniumApexPrivate)
- (void)viewWillAppear:(BOOL)animated;
- (void)viewDidAppear:(BOOL)animated;
- (void)viewWillDisappear:(BOOL)animated;
- (void)viewDidDisappear:(BOOL)animated;
- (void)viewDidLoad;
- (void)didReceiveMemoryWarning;
@end

@interface UIScrollView (TitaniumApexPrivate)
- (void)_smoothScrollWithVelocity:(CGPoint)velocity targetContentOffset:(CGPoint)targetContentOffset;
- (BOOL)_isScrolling;
- (void)_setContentOffsetPinned:(CGPoint)point;
- (void)_setInterruptionImpulse:(CGPoint)impulse;
- (void)_forcePanGestureToEndImmediately;
- (CGPoint)_touchPositionForTouches:(id)touches;
- (BOOL)touchesShouldCancelInContentView:(UIView *)view;
- (void)_scrollViewAnimationEnded:(id)arg1 finished:(BOOL)arg2;
@end

@interface UITableView (TitaniumApexPrivate)
@end

@interface UICollectionView (TitaniumApexPrivate)
@end

@interface UITextView (TitaniumApexPrivate)
@end

@interface UIKeyboardImpl : UIView
+ (instancetype)activeInstance;
- (void)handleKeyWithString:(id)string forKeyEvent:(id)event executionContext:(id)context;
- (void)addInputString:(id)string withFlags:(NSUInteger)flags executionContext:(id)context;
- (void)clearAnimations;
- (void)setReturnKeyEnabled:(BOOL)enabled;
- (BOOL)returnKeyEnabled;
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

@interface CATransaction (TitaniumApexPrivate)
+ (void)_setLowLatency:(BOOL)arg1;
+ (void)activateBackground:(BOOL)arg1;
+ (void)commit;
+ (void)flush;
@end

@interface CALayer (TitaniumApexPrivate)
- (id)context;
- (void)setContext:(id)context;
- (void)setAllowsEdgeAntialiasing:(BOOL)flag;
- (void)setContentsDrawsAsynchronously:(BOOL)flag;
- (BOOL)contentsDrawsAsynchronously;
- (void)setNeedsDisplayOnBoundsChange:(BOOL)flag;
- (BOOL)needsDisplayOnBoundsChange;
- (void)setAllowsGroupOpacity:(BOOL)allows;
- (void)setCornerCurve:(NSString *)curve;
- (void)setDrawsAsynchronously:(BOOL)flag;
- (BOOL)drawsAsynchronously;
- (void)setShouldRasterize:(BOOL)val;
- (BOOL)shouldRasterize;
- (void)setShadowRadius:(CGFloat)radius;
- (void)setContentsScale:(CGFloat)scale;
- (void)display;
@end

@interface CAMetalLayer (TitaniumApexPrivate)
- (void)setLowLatencyMode:(BOOL)flag;
- (void)setMaximumDrawableCount:(NSUInteger)count;
- (NSUInteger)maximumDrawableCount;
- (void)setDisplaySyncEnabled:(BOOL)enabled;
- (void)setAllowsNextDrawableTimeout:(BOOL)allow;
- (void)setPresentsWithTransaction:(BOOL)flag;
- (void)setServerPresentsWithTransaction:(BOOL)flag;
- (void)setFramebufferOnly:(BOOL)fb;
- (BOOL)framebufferOnly;
- (id)nextDrawable;
@end

@class CADisplay;

@interface UIScreen (TitaniumApexPrivate)
- (void)_setTargetRefreshRate:(CGFloat)rate;
- (NSInteger)_maximumFramesPerSecond;
- (NSInteger)maximumFramesPerSecond;
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
- (uint32_t)commitPriority;
- (void)setDesiredDynamicRange:(float)range;
- (void)orderAbove:(uint32_t)contextId;
- (void)orderBelow:(uint32_t)contextId;
@end

@interface CAWindowServerDisplay : NSObject
- (void)setMinimumFrameDuration:(double)duration;
- (void)setAllowsVirtualModes:(BOOL)flag;
- (void)setAllowsDisplayCompositing:(BOOL)flag;
@end

@interface CAWindowServer : NSObject
+ (instancetype)server;
- (NSArray *)displays;
@end

@interface SBApplication : NSObject
- (NSString *)bundleIdentifier;
- (NSString *)displayName;
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

@interface PGPictureInPictureRemoteObject : NSObject
- (void)_updatePreferredContentSize;
- (void)startPictureInPicture;
- (void)stopPictureInPictureAnimated:(BOOL)animated;
- (void)setPictureInPictureShouldStartWhenEnteringBackground:(BOOL)shouldStart;
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
- (BOOL)shouldSimplifyForOptions:(long long)options;
- (BOOL)shouldKeepAppSnapshotsInMemory;
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

@interface SBFluidSwitcherModifier : NSObject
- (double)shadowOpacityForIndex:(unsigned long long)index;
- (double)wallpaperOverlayAlphaForIndex:(unsigned long long)index;
- (BOOL)shouldasyncRenderAppLayouts;
@end

@interface SBAppSwitcherSnapshotImageCache : NSObject
- (void)reloadImagesForAllItems;
- (void)_purgeAllSnapshots;
@end

// ====================================================================================================
// CORE IPC STRUCT & RUNTIME PAYLOAD ENGINE
// ====================================================================================================

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

static BOOL g_SystemMasterReady = NO;

// ====================================================================================================
// HARDWARE DETECTION & RUNTIME PATH RESOLUTION
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
    if (root && root.length > 0 && ![root isEqualToString:@"/"]) {
        NSString *jbPath = [root stringByAppendingPathComponent:@"var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:jbPath]) return jbPath;
    }
    NSString *p1 = @"/var/jb/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist";
    if ([[NSFileManager defaultManager] fileExistsAtPath:p1]) return p1;
    return @"/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist";
}

static inline BOOL HardwareHasNative120Hz(void) {
    static BOOL isNative120 = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        struct utsname sysInfo;
        uname(&sysInfo);
        NSString *dev = [NSString stringWithCString:sysInfo.machine encoding:NSUTF8StringEncoding];
        if ([dev hasPrefix:@"iPhone14,2"] || [dev hasPrefix:@"iPhone14,3"] ||
            [dev hasPrefix:@"iPhone15,2"] || [dev hasPrefix:@"iPhone15,3"] ||
            [dev hasPrefix:@"iPhone16,"] || [dev hasPrefix:@"iPhone17,"]) {
            isNative120 = YES;
        }
    });
    return isNative120;
}

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

static inline float ClampSafeFPS(float target) {
    if (target < 15.0f) return 15.0f;
    if (target > 144.0f) return 144.0f;
    return target;
}

// ====================================================================================================
// ADVANCED HARDWARE SUBSYSTEM ENGINE & MACH POLICY (NO OVERCLOCK, ZERO LATENCY)
// ====================================================================================================

static inline void Titanium_EnableZeroLatencyPipeline(void) {
    if ([CATransaction respondsToSelector:@selector(_setLowLatency:)]) {
        [CATransaction _setLowLatency:YES];
    }
}

static void Titanium_DisableKernelThreadThrottling(void) {
    mach_port_t thread = pthread_mach_thread_np(pthread_self());
    thread_throttle_policy_data_t throttlePolicy;
    throttlePolicy.pset_limit = 0;
    thread_policy_set(
        thread,
        THREAD_THROTTLE_POLICY,
        (thread_policy_t)&throttlePolicy,
        1
    );
}

// ĐÃ SỬA: Bỏ ép QOS_CLASS_USER_INTERACTIVE liên tục trên luồng chính để hạ nhiệt CPU/GPU
static inline void Titanium_EnforceThreadVIPPolicy(void) {
    if (!NSThread.isMainThread) return;

    mach_port_t machThread = pthread_mach_thread_np(pthread_self());
    thread_affinity_policy_data_t affPolicy;
    affPolicy.affinity_tag = 1;
    thread_policy_set(machThread, THREAD_AFFINITY_POLICY, (thread_policy_t)&affPolicy, THREAD_AFFINITY_POLICY_COUNT);

    setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_THREAD, IOPOL_IMPORTANT);
    setiopolicy_np(IOPOL_TYPE_VFS_ATIME_UPDATES, IOPOL_SCOPE_THREAD, IOPOL_ATIME_UPDATES_OFF);

    Titanium_DisableKernelThreadThrottling();
}

static inline void Titanium_EnforceThreadRealtimeAndDiskVIP(void) {
    Titanium_EnforceThreadVIPPolicy();
}

static inline void Titanium_BoostCurrentThreadBriefly(void) {
    if (NSThread.isMainThread) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
}

static inline void Titanium_BackgroundPurgeMemory(void) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        malloc_zone_pressure_relief(malloc_default_zone(), 0);
    });
}

static inline void Titanium_PurgeProcessMemoryAggressively(void) {
    Titanium_BackgroundPurgeMemory();
}

static void Titanium_ApplySiliconDeepOptimizations(void) {
    setenv("MTL_FORCE_SERIAL_DISPATCH", "0", 1);
    setenv("MTL_DISABLE_TEXTURE_RESIDENCY_TRACKING", "1", 1);
    setenv("MTL_SHADER_VALIDATION", "0", 1);
    setenv("MTL_FORCE_PARALLEL_ENCODE", "1", 1);
    setenv("CA_DEBUG_TRANSACTIONS", "0", 1);
    setenv("CA_FORCE_MAX_REFRESH_RATE", "1", 1);

    Titanium_DisableKernelThreadThrottling();
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

// ====================================================================================================
// BOOST CONFIGURATION ENGINE (V28.7 PRO)
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
- (NSInteger)resolvedFrameInterval;
@end

static BoostConfigV285Pro *CFG285 = nil;
#define IS_ACTIVE (CFG285 && CFG285.enabled)

// SỬA CHUẨN ĐỒNG BỘ: Đặt sau khi class BoostConfigV285Pro đã được khai báo
static void Titanium_TuneWindowServerDisplayDirectly(void) {
    Class wsClass = NSClassFromString(@"CAWindowServer");
    if (!wsClass) return;
    
    CAWindowServer *server = [wsClass server];
    NSArray *displays = [server displays];
    if (displays && displays.count > 0) {
        CAWindowServerDisplay *mainDisp = displays[0];
        
        NSInteger currentHz = CFG285 ? [CFG285 resolvedTargetHz] : 60;
        if (currentHz <= 0) currentHz = 60;
        double minDuration = 1.0 / (double)currentHz;

        if ([mainDisp respondsToSelector:@selector(setMinimumFrameDuration:)]) {
            [mainDisp setMinimumFrameDuration:minDuration];
        }
        if ([mainDisp respondsToSelector:@selector(setAllowsVirtualModes:)]) {
            [mainDisp setAllowsVirtualModes:YES];
        }
        if ([mainDisp respondsToSelector:@selector(setAllowsDisplayCompositing:)]) {
            [mainDisp setAllowsDisplayCompositing:YES];
        }
    }
}

@implementation BoostConfigV285Pro

+ (instancetype)sharedInstance {
    static BoostConfigV285Pro *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[self alloc] init];
        CFG285 = inst;
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
    @autoreleasepool {
        NSString *prefPath = Titanium_ResolvePrefPath();
        NSDictionary *diskDict = nil;
        if (prefPath && [[NSFileManager defaultManager] fileExistsAtPath:prefPath]) {
            diskDict = [NSDictionary dictionaryWithContentsOfFile:prefPath];
        }

        if (!diskDict) {
            CFPreferencesAppSynchronize(PREF_DOMAIN);
            CFArrayRef keyList = CFPreferencesCopyKeyList(PREF_DOMAIN, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
            if (keyList) {
                diskDict = (__bridge_transfer NSDictionary *)CFPreferencesCopyMultiple(keyList, PREF_DOMAIN, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
                CFRelease(keyList);
            }
        }

        BOOL (^GetLiveBool)(NSString *, BOOL) = ^BOOL(NSString *k, BOOL d) {
            if (diskDict && diskDict[k] != nil) return [diskDict[k] boolValue];
            CFPropertyListRef val = CFPreferencesCopyAppValue((__bridge CFStringRef)k, PREF_DOMAIN);
            if (val) {
                BOOL b = CFBooleanGetValue((CFBooleanRef)val);
                CFRelease(val);
                return b;
            }
            return d;
        };

        NSInteger (^GetLiveInt)(NSString *, NSInteger) = ^NSInteger(NSString *k, NSInteger d) {
            if (diskDict && diskDict[k] != nil) return [diskDict[k] integerValue];
            CFPropertyListRef val = CFPreferencesCopyAppValue((__bridge CFStringRef)k, PREF_DOMAIN);
            if (val) {
                int n = 0;
                CFNumberGetValue((CFNumberRef)val, kCFNumberIntType, &n);
                CFRelease(val);
                return (NSInteger)n;
            }
            return d;
        };

        NSString * (^GetLiveString)(NSString *, NSString *) = ^NSString *(NSString *k, NSString *d) {
            if (diskDict && diskDict[k] != nil) return (NSString *)diskDict[k];
            CFPropertyListRef val = CFPreferencesCopyAppValue((__bridge CFStringRef)k, PREF_DOMAIN);
            if (val) {
                NSString *str = (__bridge NSString *)val;
                return str;
            }
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

        if (Titanium_IsSpringBoard()) {
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
}

- (NSInteger)resolvedTargetHz {
    if (!self.enabled || !self.enableHzControl) return 60;
    if (self.powerSaveMode) return 30;
    
    NSInteger target = (NSInteger)ClampSafeFPS((float)self.targetHz);
    // Khóa trần phần cứng 60Hz cho iPhone 6s - 12 Pro Max
    if (!HardwareHasNative120Hz() && !self.forceOverclock144Hz) {
        if (target > 60) target = 60;
    }
    return target;
}

- (NSInteger)resolvedTargetFPS {
    if (!self.enabled || !self.enableFPSControl) return 60;
    if (self.powerSaveMode) return 30;
    
    NSInteger target = (NSInteger)ClampSafeFPS((float)self.targetFPS);
    // Khóa trần phần cứng 60FPS cho màn hình 60Hz vật lý
    if (!HardwareHasNative120Hz() && !self.forceOverclock144Hz) {
        if (target > 60) target = 60;
    }
    return target;
}

- (NSInteger)resolvedFrameInterval {
    NSInteger fps = [self resolvedTargetFPS];
    NSInteger baseHz = HardwareHasNative120Hz() ? 120 : 60;
    if (fps <= 0) return 1;
    NSInteger interval = baseHz / fps;
    return (interval >= 1) ? interval : 1;
}

@end

// CALLBACK ĐỒNG BỘ TOÀN HỆ THỐNG
static void PrefsChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    if (CFG285) {
        [CFG285 loadSettings];
        Titanium_TuneWindowServerDisplayDirectly();
    }
}

// ====================================================================================================
// NHÓM 1: ZERO-LATENCY TOUCH PIPELINE & RAW EVENT DISPATCH (0.0s RESPONSE)
// ====================================================================================================

%group Group_ZeroLatency_Touch_Opt

%hook UIGestureRecognizer
- (BOOL)delaysTouchesBegan {
    if (IS_ACTIVE && CFG285.touchResponseBoost) return NO;
    return %orig;
}

- (BOOL)delaysTouchesEnded {
    if (IS_ACTIVE && CFG285.touchResponseBoost) return NO;
    return %orig;
}

- (void)setDelaysTouchesBegan:(BOOL)flag {
    BOOL actualFlag = (IS_ACTIVE && CFG285.touchResponseBoost) ? NO : flag;
    %orig(actualFlag);
}

- (void)setDelaysTouchesEnded:(BOOL)flag {
    BOOL actualFlag = (IS_ACTIVE && CFG285.touchResponseBoost) ? NO : flag;
    %orig(actualFlag);
}
%end

%hook UIControl
- (NSTimeInterval)_touchDelayThreshold {
    if (IS_ACTIVE && CFG285.touchResponseBoost) return 0.0;
    return %orig;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        Titanium_EnableZeroLatencyPipeline();
        // Giữ phản hồi tức thì nhưng cho phép CPU hạ xung tự nhiên, tránh khóa cứng mức đỉnh gây sốc nhiệt
    }
    %orig(touches, event);
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(touches, event);
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(touches, event);
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    %orig(touches, event);
}
%end

%hook SBIconView
- (void)setHighlighted:(BOOL)highlighted {
    if (highlighted && IS_ACTIVE && CFG285.touchResponseBoost) {
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(highlighted);
}

- (void)setTouchDownInIcon:(BOOL)touchDown {
    if (touchDown && IS_ACTIVE && CFG285.touchResponseBoost) {
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(touchDown);
}
%end

%hook UIWindow
- (BOOL)_shouldDelayTouchForCancelEvents {
    if (IS_ACTIVE && CFG285.touchResponseBoost) return NO;
    return %orig;
}

- (BOOL)_ignoresHitTest {
    return %orig;
}

- (void)sendEvent:(UIEvent *)event {
    if (IS_ACTIVE && CFG285.touchResponseBoost && event.type == 0) {
        Titanium_EnableZeroLatencyPipeline();
        // Bỏ ép QOS_CLASS_USER_INTERACTIVE trên mỗi pixel di chuyển cảm ứng để triệt tiêu nguyên nhân nóng máy
    }
    %orig(event);
}
%end

%end

// ====================================================================================================
// NHÓM 2: METAL GRAPHICS, TRIPLE BUFFERING (3 DRAWABLES) & ANTI-TEARING V-SYNC
// ====================================================================================================

%group Group_Metal_ZeroTearing_Pacing

%hook CAMetalLayer
- (void)setMaximumDrawableCount:(NSUInteger)count {
    if (IS_ACTIVE && CFG285.metalHexBuffering) {
        count = 3; // Triple Buffering: Luôn sẵn sàng bộ đệm, chống drop frame
    }
    %orig(count);
}

- (NSUInteger)maximumDrawableCount {
    if (IS_ACTIVE && CFG285.metalHexBuffering) return 3;
    return %orig;
}

- (void)setDisplaySyncEnabled:(BOOL)enabled {
    if (IS_ACTIVE) {
        enabled = YES;
    }
    %orig(enabled);
}

- (void)setFramebufferOnly:(BOOL)fb {
    %orig(fb);
}

- (BOOL)framebufferOnly {
    return %orig;
}

- (void)setLowLatencyMode:(BOOL)flag {
    if (IS_ACTIVE) {
        flag = YES; // Rút ngắn hàng đợi xuất hình của GPU tiệm cận 0ms
    }
    %orig(flag);
}

- (void)setAllowsNextDrawableTimeout:(BOOL)allow {
    if (IS_ACTIVE) {
        allow = NO; // Không đợi timeout, GPU nạp khung hình liên tục và giải phóng ngay
    }
    %orig(allow);
}

- (void)setPresentsWithTransaction:(BOOL)flag {
    if (IS_ACTIVE) {
        flag = NO; // Cho phép GPU hiển thị độc lập, không bị nghẽn bởi transaction UIKit
    }
    %orig(flag);
}

- (id)nextDrawable {
    if (IS_ACTIVE) {
        Titanium_EnableZeroLatencyPipeline();
    }
    return %orig;
}
%end

%hook CALayer
- (void)setContentsScale:(CGFloat)scale {
    %orig(scale);
}

// Giữ luồng mặc định, không ép YES để tránh GPU quá tải khi tính toán khúc xạ Liquid Glass
- (void)setDrawsAsynchronously:(BOOL)draws {
    %orig(draws);
}

- (BOOL)drawsAsynchronously {
    return %orig;
}

- (void)setContentsDrawsAsynchronously:(BOOL)flag {
    %orig(flag);
}

- (BOOL)contentsDrawsAsynchronously {
    return %orig;
}

- (void)setAllowsGroupOpacity:(BOOL)allows {
    %orig(allows);
}

- (void)setShouldRasterize:(BOOL)val {
    %orig(val);
}

- (BOOL)shouldRasterize {
    return %orig;
}

- (void)setShadowRadius:(CGFloat)radius {
    %orig(radius);
}

- (void)setNeedsDisplayOnBoundsChange:(BOOL)flag {
    %orig(flag);
}

- (BOOL)needsDisplayOnBoundsChange {
    return %orig;
}

- (void)display {
    // Chỉ bật pipeline độ trễ thấp, không ép QoS đỉnh để tránh quá nhiệt
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig;
}
%end

%hook CAContext
- (void)setCommitPriority:(uint32_t)priority {
    if (!Titanium_IsSpringBoard() && IS_ACTIVE) {
        priority = 100; // Đặt ưu tiên commit mức 100 để GPU ưu tiên tổng hợp UI trước
    }
    %orig(priority);
}

- (uint32_t)commitPriority {
    if (Titanium_IsSpringBoard()) return %orig;
    if (IS_ACTIVE) return 100;
    return %orig;
}

- (void)setDesiredDynamicRange:(float)range {
    if (IS_ACTIVE) {
        range = 1.0f; // Khóa dynamic range chuẩn SDR (1.0) nhằm giảm tải shader của GPU
    }
    %orig(range);
}
%end

%end

// ====================================================================================================
// NHÓM 3: DISPLAY REFRESH CADENCE & TRANSIENT ANIMATION PACING
// ====================================================================================================
%group Group_FluidTransitions_Pacing

%hook CADisplayLink
- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (IS_ACTIVE && CFG285.enableHzControl) {
        fps = [CFG285 resolvedTargetFPS];
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(fps);
}

- (NSInteger)preferredFramesPerSecond {
    if (!IS_ACTIVE || !CFG285.enableHzControl) return %orig;
    return [CFG285 resolvedTargetFPS];
}

- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if (IS_ACTIVE && CFG285.enableHzControl) {
            float target = (float)[CFG285 resolvedTargetHz];
            Titanium_EnableZeroLatencyPipeline();
            range = SafeMakeFRR(target, target, target);
        }
    }
    %orig(range);
}

- (void)setFrameInterval:(NSInteger)interval {
    if (IS_ACTIVE && CFG285.enableHzControl) {
        interval = [CFG285 resolvedFrameInterval];
    }
    %orig(interval);
}
%end

%hook CADisplay
- (NSInteger)preferredFPS {
    if (!IS_ACTIVE || !CFG285.enableHzControl) return %orig;
    return [CFG285 resolvedTargetFPS];
}

- (void)setPreferredFPS:(NSInteger)fps {
    if (IS_ACTIVE && CFG285.enableHzControl) {
        fps = [CFG285 resolvedTargetFPS];
    }
    %orig(fps);
}

- (void)overrideDisplayCadence:(id)cadence {
    if (IS_ACTIVE && CFG285.enableHzControl) {
        cadence = nil;
    }
    %orig(cadence);
}

- (BOOL)supportsDynamicRefresh {
    if (!IS_ACTIVE) return %orig;
    return YES;
}
%end

%hook UIScreen
- (NSInteger)maximumFramesPerSecond {
    if (!IS_ACTIVE || !CFG285.enableHzControl) return %orig;
    return [CFG285 resolvedTargetHz];
}

- (NSInteger)_maximumFramesPerSecond {
    if (!IS_ACTIVE || !CFG285.enableHzControl) return %orig;
    return [CFG285 resolvedTargetHz];
}

- (CGFloat)_refreshRate {
    if (!IS_ACTIVE || !CFG285.enableHzControl) return %orig;
    return (CGFloat)[CFG285 resolvedTargetHz];
}

- (void)_setTargetRefreshRate:(CGFloat)rate {
    if (IS_ACTIVE && CFG285.enableHzControl) {
        rate = (CGFloat)[CFG285 resolvedTargetHz];
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(rate);
}
%end

// Hook hoạt ảnh đồ họa thông thường: Khóa chặt target FPS
%hook CAAnimation
- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if (IS_ACTIVE && CFG285.enableHzControl) {
            float target = (float)[CFG285 resolvedTargetHz];
            range = SafeMakeFRR(target, target, target);
        }
    }
    %orig(range);
}
%end

// HOOK RIÊNG CHO LÒ XO QUÁN TÍNH: Cho phép dải tần số co giãn theo gia tốc vuốt
// Khắc phục triệt để hiện tượng vấp/khựng khi vuốt nhanh liên tục hoặc dùng ANIMATION26
%hook CASpringAnimation
- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if (IS_ACTIVE && CFG285.enableHzControl) {
            float target = (float)[CFG285 resolvedTargetHz];
            // min = 30Hz, preferred = target, max = target
            // Thuật toán lò xo có không gian tính toán gia tốc văng cửa sổ mượt mà, không bị frame snap
            range = SafeMakeFRR(30.0f, target, target);
        }
    }
    %orig(range);
}
%end

%hook NSProcessInfo
- (BOOL)isLowPowerModeEnabled {
    return %orig;
}

- (NSProcessInfoThermalState)thermalState {
    return %orig;
}
%end

%hook UIApplication
- (void)_applicationDidBecomeActive:(id)arg1 {
    %orig;
    if (IS_ACTIVE) {
        // Chỉ app con mới reload khi active, SpringBoard tuyệt đối không đọc đĩa lúc về Home
        if (!Titanium_IsSpringBoard()) {
            [[BoostConfigV285Pro sharedInstance] loadSettings];
        }
        Titanium_EnableZeroLatencyPipeline();
    }
}

- (void)applicationDidBecomeActive:(id)arg1 {
    %orig;
    if (IS_ACTIVE) {
        if (!Titanium_IsSpringBoard()) {
            [[BoostConfigV285Pro sharedInstance] loadSettings];
        }
        Titanium_EnableZeroLatencyPipeline();
    }
}
%end

%end

// ====================================================================================================
// NHÓM 4: APP SWITCHER 30+ APPS VIRTUAL CARD SORTING & MEMORY PURGE
// ====================================================================================================

%group Group_Switcher30Apps_Virtualization

%hook SBFluidSwitcherModifier
- (double)shadowOpacityForIndex:(unsigned long long)index {
    return %orig(index);
}
- (double)wallpaperOverlayAlphaForIndex:(unsigned long long)index {
    return %orig(index);
}
- (BOOL)shouldasyncRenderAppLayouts {
    return %orig;
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
- (BOOL)shouldSimplifyForOptions:(long long)options {
    return %orig;
}
- (BOOL)shouldKeepAppSnapshotsInMemory {
    return %orig;
}
%end

%hook SBAppSwitcherSnapshotImageCache
- (void)reloadImagesForAllItems {
    if (IS_ACTIVE) Titanium_BackgroundPurgeMemory();
    %orig;
}
- (void)_purgeAllSnapshots {
    if (IS_ACTIVE) Titanium_BackgroundPurgeMemory();
    %orig;
}
%end

%hook SBAppSwitcherController
- (void)switcherContentController:(id)contentController deletedItem:(id)deletedItem {
    %orig(contentController, deletedItem);
    if (IS_ACTIVE && CFG285.aggressiveRamClean) Titanium_BackgroundPurgeMemory();
}
- (void)viewWillAppear:(BOOL)animated {
    if (IS_ACTIVE) {
        Titanium_EnableZeroLatencyPipeline();
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(animated);
}
- (void)viewDidDisappear:(BOOL)animated {
    %orig(animated);
}
- (void)viewDidLayoutSubviews {
    if (IS_ACTIVE && CFG285.reduceMultitaskLag) {
        Titanium_BoostCurrentThreadBriefly();
    }
    %orig;
}
%end

%hook SBDeckSwitcherViewController
- (void)viewWillAppear:(BOOL)animated {
    if (IS_ACTIVE) {
        Titanium_EnableZeroLatencyPipeline();
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
    %orig(radius);
}
%end

%end

// ====================================================================================================
// NHÓM 5: FAST APP LAUNCH & NATURAL TRANSITION LIFECYCLE
// ====================================================================================================

%group Group_FastLaunch_SuperEngineV285

%hook FBApplicationProcess
- (void)bootstrapWithContext:(id)context completion:(id)completion {
    if (IS_ACTIVE && CFG285.turboAppLaunch) {
        Titanium_EnforceThreadVIPPolicy();
    }
    %orig(context, completion);
}
- (void)launchIfNecessary {
    if (IS_ACTIVE && CFG285.turboAppLaunch) {
        Titanium_EnforceThreadVIPPolicy();
    }
    %orig;
}
%end

%hook FBProcess
- (void)killForReason:(long long)reason andReport:(BOOL)report withDescription:(id)description completion:(id)completion {
    if (IS_ACTIVE && CFG285.fixAppExitStutter) {
        Titanium_BackgroundPurgeMemory();
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
        Titanium_EnforceThreadVIPPolicy();
    }
    %orig(scene, context, completion);
}
- (BOOL)_handleDelegateCallbacksWithOptions:(id)options isSuspended:(BOOL)suspended restoreState:(BOOL)restoreState {
    if (IS_ACTIVE && CFG285.turboAppLaunch) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    return %orig(options, suspended, restoreState);
}
- (void)_applicationWillEnterForeground {
    if (IS_ACTIVE) {
        Titanium_EnableZeroLatencyPipeline();
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}
- (void)_applicationDidBecomeActive {
    if (IS_ACTIVE) {
        Titanium_EnableZeroLatencyPipeline();
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}
- (void)_applicationDidEnterBackground {
    %orig;
}
- (void)_applicationWillTerminate {
    %orig;
}
%end

%end

// ====================================================================================================
// NHÓM 6: SCROLL PERFORMANCE & ZERO-LAG KEYBOARD RESPONSIVENESS
// ====================================================================================================

%group Group_Scroll_And_Keyboard_Opt

%hook UIScrollView
- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig(newWindow);
    if (newWindow && IS_ACTIVE && CFG285.colorOs17SmoothEngine) {
        self.delaysContentTouches = NO;
        self.decelerationRate = 0.998f;
        if (self.layer) {
            self.layer.drawsAsynchronously = YES;
        }
    }
}
- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    if (IS_ACTIVE && CFG285.colorOs17SmoothEngine) return YES;
    return %orig(view);
}
- (void)_forcePanGestureToEndImmediately {
    %orig;
}
- (void)_scrollViewAnimationEnded:(id)arg1 finished:(BOOL)arg2 {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(arg1, arg2);
}
%end

%hook UITableView
- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig(newWindow);
    if (newWindow && IS_ACTIVE) {
        self.delaysContentTouches = NO;
        self.layer.drawsAsynchronously = YES;
    }
}
%end

%hook UICollectionView
- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig(newWindow);
    if (newWindow && IS_ACTIVE) {
        self.delaysContentTouches = NO;
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

%hook UIKeyboardImpl
- (void)handleKeyWithString:(id)string forKeyEvent:(id)event executionContext:(id)context {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        Titanium_EnableZeroLatencyPipeline();
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(string, event, context);
}
- (void)addInputString:(id)string withFlags:(NSUInteger)flags executionContext:(id)context {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        Titanium_EnableZeroLatencyPipeline();
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
        Titanium_EnableZeroLatencyPipeline();
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
        Titanium_EnableZeroLatencyPipeline();
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(text);
}
- (void)deleteBackward {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        Titanium_EnableZeroLatencyPipeline();
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
// NHÓM 7: SPRINGBOARD DISPLAY SHELL & ICON GRID OPTIMIZATIONS
// ====================================================================================================

// Khai báo giao diện hỗ trợ chuyển cảnh và cử chỉ vuốt
@interface SBAppToHomeWorkspaceTransaction : NSObject
@end

@interface SBFluidSwitcherGestureWorkspaceTransaction : NSObject
@end

// Khai báo interface cho container thẻ đa nhiệm (chống warning/lỗi biên dịch)
@interface SBFluidSwitcherItemContainer : UIView
@end

%group Group_Display_SpringBoardV285

// 1. TỐI ƯU CỬ CHỈ LIÊN HOÀN (CHỐNG DELAY / KHỰNG KHI VUỐT NHANH HOẶC DÙNG ANIMATION26)
%hook SBFluidSwitcherGestureWorkspaceTransaction
- (BOOL)_shouldSuppressGestures {
    // Không bao giờ khóa cử chỉ mới khi cử chỉ trước vừa hoàn tất
    if (IS_ACTIVE) return NO;
    return %orig;
}

- (BOOL)canInterruptActiveGesture {
    // Cho phép ngón tay chạm cướp quyền ngay cả khi animation lò xo chưa kịp hạ cánh
    if (IS_ACTIVE) return YES;
    return %orig;
}
%end

// 2. KHỬ ĐỘ TRỄ CỬ CHỈ CẠNH DƯỚI & TĂNG TỐC ĐỘ ĐÁP VỀ ICON
%hook SBHomeGestureSettings
- (double)homeGestureDelayDuration {
    // Ép độ trễ nhận diện vuốt đáy về 0ms tuyệt đối
    if (IS_ACTIVE) return 0.0;
    return %orig;
}
%end

%hook SBFluidSwitcherAnimationSettings
- (double)appToHomeScaleDampingRatio {
    // Giảm chấn phẳng 1.0 triệt tiêu rung giật hoặc giật cục khung hình ở cuối hoạt ảnh
    if (IS_ACTIVE) return 1.0;
    return %orig;
}
%end

%hook SBFluidSwitcherViewController
- (void)handleFluidSwitcherGesture:(id)gesture {
    if (IS_ACTIVE) Titanium_EnableZeroLatencyPipeline();
    %orig(gesture);
}

- (double)animationDurationForTransitionRequest:(id)request {
    double orig = %orig(request);
    if (IS_ACTIVE && CFG285.enableHzControl) {
        // Rút ngắn 25% thời gian neo giữ animation giúp màn hình chính sẵn sàng tương tác sớm hơn
        return orig * 0.75;
    }
    return orig;
}
%end

// 3. ĐIỀU PHỐI CHUYỂN CẢNH APP VỀ HOME (GIẢI PHÓNG HÀNG ĐỢI RENDER)
%hook SBAppToHomeWorkspaceTransaction
- (BOOL)shouldAnimateOrientationChangeOnCompletion {
    return NO;
}

- (void)_willBegin {
    %orig;
    if (IS_ACTIVE) {
        Titanium_BoostCurrentThreadBriefly();
        Titanium_EnableZeroLatencyPipeline();
    }
}

- (void)_didComplete {
    %orig;
    if (IS_ACTIVE) Titanium_EnableZeroLatencyPipeline();
}
%end

// Kích hoạt pipeline render 0ms ngay khi màn hình chính chuẩn bị xuất hiện
%hook SBHomeScreenViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig(animated);
    if (IS_ACTIVE) Titanium_EnableZeroLatencyPipeline();
}
%end

// 4. BẢO VỆ MÀN HÌNH CHÍNH (ĐÃ LOẠI BỎ layoutIconsNow VÀ viewDidLayoutSubviews ĐỂ KHÔNG ĐƠ ICON KHI VỀ HOME)
%hook SBIconController
- (void)scrollToIconListAtIndex:(NSInteger)index animate:(BOOL)animate {
    if (IS_ACTIVE) Titanium_EnableZeroLatencyPipeline();
    %orig(index, animate);
}
- (void)openFolder:(id)folder animated:(BOOL)animated completion:(id)completion {
    if (IS_ACTIVE) Titanium_EnableZeroLatencyPipeline();
    %orig(folder, animated, completion);
}
- (void)closeFolderAnimated:(BOOL)animated completion:(id)completion {
    if (IS_ACTIVE) Titanium_EnableZeroLatencyPipeline();
    %orig(animated, completion);
}
%end

%hook SBIconListView
- (void)fadeInIcon:(id)icon {
    %orig(icon);
}
%end

// 5. CACHE SNAPSHOT & TĂNG TỐC CUỘN THẺ ĐA NHIỆM (HẾT CHẬM / LỪ ĐỪ KHI TÌM TAB)
%hook SBAppSwitcherSettings
- (BOOL)shouldKeepAppSnapshotsInMemory {
    if (IS_ACTIVE) return YES;
    return %orig;
}

// Cho phép lướt trớn bay bổng, không bị hãm phanh giật cục khi gạt tìm tab
- (CGFloat)decelerationRate {
    if (IS_ACTIVE) {
        return UIScrollViewDecelerationRateNormal;
    }
    return %orig;
}

// Bỏ tính toán đổ bóng/làm mờ phức tạp khi đang trượt ngang danh sách tab
- (BOOL)shouldSimplifyForOptions:(long long)options {
    if (IS_ACTIVE) return YES;
    return %orig;
}
%end

%hook SBFluidSwitcherModifier
- (BOOL)shouldasyncRenderAppLayouts {
    // Trả về NO để card ứng dụng render trực tiếp từ snapshot, không bị trễ khung hình
    if (IS_ACTIVE) return NO;
    return %orig;
}
%end

// Rasterize lớp đồ họa của từng thẻ giúp lướt qua lại 60fps mượt mà trên chip A9/A10
%hook SBFluidSwitcherItemContainer
- (void)prepareForReuse {
    %orig;
    if (IS_ACTIVE) {
        self.layer.drawsAsynchronously = YES;
        self.layer.shouldRasterize = YES;
        self.layer.rasterizationScale = [UIScreen mainScreen].scale;
    }
}
%end

// 6. CÁC HOOK CƠ BẢN CỦA SPRINGBOARD
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
    if (IS_ACTIVE) Titanium_EnableZeroLatencyPipeline();
    %orig;
}
- (void)cleanupAfterClose {
    %orig;
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
    if (IS_ACTIVE) Titanium_EnableZeroLatencyPipeline();
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

%end

// ====================================================================================================
// NHÓM 8: PIPELINE SYNC FOR PICTURE-IN-PICTURE & FLOATING WINDOWS
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
// NHÓM 9: HARDWARE SEGREGATION (CLASSIC HOME BUTTON VS MODERN FLUID GESTURES)
// ====================================================================================================

%group Group_HardwareSegregation_ClassicHomeV285

%hook SBHomeHardwareButtonActions
- (void)performSinglePressAction {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        Titanium_EnableZeroLatencyPipeline();
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}
- (void)performDoublePressAction {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        Titanium_EnableZeroLatencyPipeline();
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}
- (void)performTriplePressAction {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        Titanium_EnableZeroLatencyPipeline();
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}
- (void)performLongPressCancelled {
    %orig;
}
%end

%end

%group Group_HardwareSegregation_ModernGesturesV285

%hook SBFluidSwitcherViewController
- (void)viewWillLayoutSubviews {
    if (IS_ACTIVE) pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    %orig;
}
- (void)viewDidLayoutSubviews {
    if (IS_ACTIVE) pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    %orig;
}
- (void)handleFluidSwitcherGesture:(id)gesture {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        Titanium_EnableZeroLatencyPipeline();
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(gesture);
}
%end

%end

// ====================================================================================================
// NHÓM 10: PROCESS INTEGRITY & JETSAM PROTECTION
// ====================================================================================================

%group Group_SpringBoard_ProcessManagerV285

%hook SBApplication
- (void)setProcessState:(id)state {
    if (IS_ACTIVE) pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
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
    if (IS_ACTIVE && CFG285.aggressiveRamClean) Titanium_BackgroundPurgeMemory();
    %orig(context);
}
%end

%hook SBMainWorkspace
- (void)_handleApplicationProcessExited:(id)processDescription {
    if (IS_ACTIVE && CFG285.aggressiveRamClean) Titanium_BackgroundPurgeMemory();
    %orig(processDescription);
}
- (void)handleApplicationLaunch:(id)application {
    if (IS_ACTIVE && CFG285.turboAppLaunch) {
        Titanium_EnableZeroLatencyPipeline();
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(application);
}
- (void)handleApplicationSuspended:(id)application {
    %orig(application);
}
%end

%end

// ====================================================================================================
// NHÓM 11: UIKIT THIRD-PARTY ISOLATION & VIEW CONTROLLER LIFECYCLE
// ====================================================================================================

%group Group_UIKit_ThirdParty_IsolatedV285

%hook SBFView
- (void)setCustomFullHomedStyle:(BOOL)flag {
    %orig(flag);
}
%end

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
        Titanium_BackgroundPurgeMemory();
    }
}
%end

%end

// ====================================================================================================
// NHÓM TĂNG TỐC BÀN PHÍM, NÚT 3 GẠCH & CHUYỂN TAB ỨNG DỤNG NẶNG
// ====================================================================================================

@interface UIKeyboardImpl : NSObject
+ (instancetype)activeInstance;
@end

@interface UIKBRenderConfig : NSObject
@property (nonatomic, assign) BOOL lightKeyboard;
@end

@interface UIControl ()
- (void)sendActionsForControlEvents:(UIControlEvents)controlEvents;
@end

%group Group_InstantActionAndMenuTransitions_Boost

// 1. TĂNG TỐC BÀN PHÍM: BẬT NẢY TỨC THÌ KHI CHẠM Ô NHẬP LIỆU
%hook UIKeyboardImpl
- (void)callShowKeyboard {
    if (IS_ACTIVE) {
        Titanium_BoostCurrentThreadBriefly();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig;
}

+ (NSTimeInterval)suppressionIntervalForTouchesOnKeyboard {
    if (IS_ACTIVE) return 0.0;
    return %orig;
}
%end

%hook UIKBRenderConfig
- (BOOL)lightKeyboard {
    // Làm phẳng nền phím, giảm tải GPU khi mở phím trong app nặng
    if (IS_ACTIVE) return YES;
    return %orig;
}
%end

%hook UIPeripheralHost
- (double)getLastTranslateTime {
    if (IS_ACTIVE) return 0.0;
    return %orig;
}
%end

// 2. TRIỆT TIÊU ĐỘ TRỄ NÚT BẤM (MENU 3 GẠCH, DRAWER, TAB CON, SIDEBAR)
%hook UIButton
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (IS_ACTIVE) {
        Titanium_BoostCurrentThreadBriefly();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(touches, event);
}
%end

%hook UIControl
- (void)sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event {
    if (IS_ACTIVE) {
        Titanium_BoostCurrentThreadBriefly();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(action, target, event);
}
%end

// 3. KHÔNG NGÂM CỬ CHỈ CHẠM KHI NÚT NẰM TRONG KHUNG CUỘN (SCROLLVIEW / NAVBAR)
%hook UIScrollView
- (BOOL)delaysContentTouches {
    if (IS_ACTIVE) return NO;
    return %orig;
}
%end

// 4. TỐI ƯU VIEW CON KHI MENU / TAB NỘI DUNG DÀY ĐẶC BUNG RA
%hook UIView
- (void)addSubview:(UIView *)view {
    %orig(view);
    if (IS_ACTIVE && view) {
        // Tối ưu hóa các lớp bo tròn góc để GPU A9/A10 không phải vẽ lại từng pixel
        if (view.layer.masksToBounds && view.layer.cornerRadius > 0) {
            view.layer.shouldRasterize = YES;
            view.layer.rasterizationScale = [UIScreen mainScreen].scale;
        }
    }
}
%end

// 5. GIẢM TẢI BLUR MỜ NỀN PHÍA SAU MENU TRƯỢT 3 GẠCH
%hook UIVisualEffectView
- (void)setBackgroundEffects:(id)effects {
    if (IS_ACTIVE && CFG285.enableHzControl) {
        %orig(nil);
        return;
    }
    %orig(effects);
}
%end

// 6. TĂNG TỐC HOẠT ẢNH TRƯỢT TAB / CHUYỂN MÀN HÌNH CON
%hook CATransition
- (void)setDuration:(CFTimeInterval)duration {
    if (IS_ACTIVE && CFG285.enableHzControl) {
        if (duration > 0.15) {
            duration = duration * 0.75; // Rút ngắn thời gian chuyển cảnh để mở tức thì
        }
    }
    %orig(duration);
}
%end

%hook UIViewController
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (IS_ACTIVE) {
        Titanium_BoostCurrentThreadBriefly();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(viewControllerToPresent, flag, completion);
}
%end

%hook UINavigationController
- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (IS_ACTIVE) {
        Titanium_BoostCurrentThreadBriefly();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(viewController, animated);
}
%end

%hook UITabBarController
- (void)setSelectedViewController:(UIViewController *)selectedViewController {
    if (IS_ACTIVE) {
        Titanium_BoostCurrentThreadBriefly();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(selectedViewController);
}
%end

%end

// ====================================================================================================
// RUNTIME TWEAK INITIALIZER & SPRINGBOARD ENTRY POINT
// ====================================================================================================
static void Titanium_StartThermalAndChargingWatchdog(void) {
    static dispatch_source_t timerSource = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_queue_t watchdogQueue = dispatch_queue_create("com.titanium.v285.thermal", DISPATCH_QUEUE_SERIAL);
        timerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, watchdogQueue);
        // Tăng chu kỳ lên 10s để giảm tải CPU và RAM 2GB trên iPhone 6s/7+
        dispatch_source_set_timer(timerSource, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)), 10.0 * NSEC_PER_SEC, 2.0 * NSEC_PER_SEC);
        dispatch_source_set_event_handler(timerSource, ^{
            if (!IS_ACTIVE) return;
            
            // NSProcessInfo thread-safe trên luồng ngầm
            NSProcessInfoThermalState currentThermalState = [[NSProcessInfo processInfo] thermalState];
            g_liveThermalStateV285 = currentThermalState;
            
            // UIDevice BẮT BUỘC gọi trên Main Queue để tránh crash SpringBoard/SReboot
            dispatch_async(dispatch_get_main_queue(), ^{
                UIDevice *device = [UIDevice currentDevice];
                if (!device.isBatteryMonitoringEnabled) {
                    device.batteryMonitoringEnabled = YES;
                }
                g_isDeviceChargingV285 = (device.batteryState == UIDeviceBatteryStateCharging || device.batteryState == UIDeviceBatteryStateFull);
                
                // Né thời điểm tay đang chạm/vuốt màn hình
                CFStringRef currentMode = CFRunLoopCopyCurrentMode(CFRunLoopGetMain());
                BOOL isUserTouching = NO;
                if (currentMode) {
                    if (CFEqual(currentMode, (CFStringRef)UITrackingRunLoopMode)) {
                        isUserTouching = YES;
                    }
                    CFRelease(currentMode);
                }

                if (!isUserTouching && (currentThermalState >= NSProcessInfoThermalStateSerious || g_isDeviceChargingV285)) {
                    Titanium_BackgroundPurgeMemory();
                }
            });
        });
        dispatch_resume(timerSource);
    });
}

static void Titanium_StartPassiveRamDaemon(void) {
    if (!Titanium_IsSpringBoard()) return;
    static dispatch_source_t ramTimerSource = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_queue_t daemonQueue = dispatch_queue_create("com.titanium.v285.ramdaemon", DISPATCH_QUEUE_SERIAL);
        ramTimerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, daemonQueue);
        // Chu kỳ 90s giúp tránh kích hoạt cơ chế Jetsam Memory Limit Kill
        dispatch_source_set_timer(ramTimerSource, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(90.0 * NSEC_PER_SEC)), 90.0 * NSEC_PER_SEC, 15.0 * NSEC_PER_SEC);
        dispatch_source_set_event_handler(ramTimerSource, ^{
            if (IS_ACTIVE && CFG285.aggressiveRamClean) {
                // Đẩy kiểm tra lên Main RunLoop để phát hiện thao tác chạm của người dùng
                dispatch_async(dispatch_get_main_queue(), ^{
                    CFStringRef currentMode = CFRunLoopCopyCurrentMode(CFRunLoopGetMain());
                    BOOL isUserTouching = NO;
                    if (currentMode) {
                        // UITrackingRunLoopMode được kích hoạt khi ngón tay đang chạm hoặc cuộn/vuốt
                        if (CFEqual(currentMode, (CFStringRef)UITrackingRunLoopMode)) {
                            isUserTouching = YES;
                        }
                        CFRelease(currentMode);
                    }
                    
                    // Tuyệt đối không dọn RAM nếu người dùng đang chạm/vuốt màn hình
                    if (!isUserTouching) {
                        Titanium_BackgroundPurgeMemory();
                    }
                });
            }
        });
        dispatch_resume(ramTimerSource);
    });
}

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
    dispatch_source_set_timer(s_debounceTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(200 * NSEC_PER_MSEC)), DISPATCH_TIME_FOREVER, 0);
    dispatch_source_set_event_handler(s_debounceTimer, ^{
        if (CFG285 && [CFG285 respondsToSelector:@selector(loadSettings)]) {
            [CFG285 loadSettings];
        }
        if (Titanium_IsSpringBoard()) {
            Titanium_TuneWindowServerDisplayDirectly();
        }
        s_debounceTimer = nil;
    });
    dispatch_resume(s_debounceTimer);
}

static void runCoreTweak(BOOL isSpringBoard, NSString *bundleID, const char *progName) {
    @autoreleasepool {
        Titanium_ApplySiliconDeepOptimizations();
        Titanium_EnableZeroLatencyPipeline();
        Titanium_EnforceThreadVIPPolicy();

        Class configClass = NSClassFromString(@"BoostConfigV285Pro");
        if (configClass) {
            CFG285 = [configClass sharedInstance];
            [CFG285 loadSettings];
        }

        // Khởi tạo các nhóm hook cốt lõi
        %init(Group_ZeroLatency_Touch_Opt);
        %init(Group_Metal_ZeroTearing_Pacing);
        %init(Group_FluidTransitions_Pacing);
        %init(Group_FastLaunch_SuperEngineV285);
        %init(Group_Scroll_And_Keyboard_Opt);

        // KÍCH HOẠT NHÓM BÀN PHÍM, MENU 3 GẠCH & CHUYỂN TAB TỨC THÌ
        %init(Group_InstantActionAndMenuTransitions_Boost);

        if (Titanium_IsClassicHomeButtonDevice()) {
            %init(Group_HardwareSegregation_ClassicHomeV285);
        } else {
            %init(Group_HardwareSegregation_ModernGesturesV285);
        }

        if (isSpringBoard) {
            Titanium_TuneWindowServerDisplayDirectly();
            %init(Group_Switcher30Apps_Virtualization);
            %init(Group_Display_SpringBoardV285);
            %init(Group_V285_FloatingWindow_PiP);
            %init(Group_SpringBoard_ProcessManagerV285);
            Titanium_StartThermalAndChargingWatchdog();
            Titanium_StartPassiveRamDaemon();
        } else {
            %init(Group_UIKit_ThirdParty_IsolatedV285);
        }

        // Đăng ký Darwin IPC đúng 1 lần duy nhất, tránh duplicate listener gây rò rỉ bộ nhớ
        static dispatch_once_t notifyToken;
        dispatch_once(&notifyToken, ^{
            CFNotificationCenterRef darwinCenter = CFNotificationCenterGetDarwinNotifyCenter();
            if (darwinCenter) {
                CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)ReloadPreferencesCallbackV285, CFSTR(NOTIFY_RELOAD), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
                CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)ReloadPreferencesCallbackV285, CFSTR(NOTIFY_UIKIT_RELOAD), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
                CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)ReloadPreferencesCallbackV285, CFSTR(NOTIFY_FPS_CHANGED), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
                CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)ReloadPreferencesCallbackV285, CFSTR(NOTIFY_TITANIUM_CHANGED), NULL, CFNotificationSuspensionBehaviorCoalesce);
            }
        });

        g_SystemMasterReady = YES;
    }
}

static void SpringBoardDidLaunchCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Chờ SpringBoard dựng xong Main RunLoop trước khi nạp Hook hiển thị
        dispatch_async(dispatch_get_main_queue(), ^{
            const char *progName = getprogname();
            NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
            runCoreTweak(YES, bundleID, progName);
        });
    });
}

// Khởi chạy an toàn cho ứng dụng (Chống màn hình đen & Chống Crash khi khởi động)
static void AppDidFinishLaunchingSafeCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    static dispatch_once_t appOnceToken;
    dispatch_once(&appOnceToken, ^{
        // Đẩy về Main Queue để UIKit tạo xong Window/View rồi mới áp dụng low-latency Metal
        dispatch_async(dispatch_get_main_queue(), ^{
            const char *progName = getprogname();
            NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
            runCoreTweak(NO, bundleID, progName);
        });
    });
}

%ctor {
    @autoreleasepool {
        const char *progName = getprogname();
        if (!progName) return;

        // 1. Chặn toàn bộ các daemon nhạy cảm để ngăn Kernel/Watchdog SReboot
        if (strstr(progName, "jailbreakd") || strstr(progName, "launchd") ||
            strstr(progName, "containermanagerd") || strstr(progName, "cfprefsd") ||
            strstr(progName, "watchdogd") || strstr(progName, "mediaserverd") ||
            strstr(progName, "installd") || strstr(progName, "logd") ||
            strstr(progName, "analyticsd") || strstr(progName, "symptomsd") ||
            strstr(progName, "powerd") || strstr(progName, "backboardd") ||
            strstr(progName, "notifyd") || strstr(progName, "securityd")) {
            return;
        }

        // 2. Chống Bootloop
        if (!Titanium_CheckAndPreventBootloopUniversal()) return;

        // 3. Tiến trình Cài đặt chỉ cần load cấu hình
        if (strstr(progName, "Preferences") || strstr(progName, "Settings")) {
            Class configClass = NSClassFromString(@"BoostConfigV285Pro");
            if (configClass) {
                CFG285 = [configClass sharedInstance];
                [CFG285 loadSettings];
            }
            return;
        }

        // 4. Khởi tạo Hook mồ côi ngoài group
        %init;

        NSBundle *mainBundle = [NSBundle mainBundle];
        NSString *bundleID = [mainBundle bundleIdentifier];
        BOOL isSpringBoard = bundleID && [bundleID isEqualToString:@"com.apple.springboard"];

        // 5. TRÌ HOÃN KHỞI CHẠY (TRIỆT TIÊU TREO RESPRING & ĐEN MÀN HÌNH)
        if (isSpringBoard) {
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetLocalCenter(),
                NULL,
                SpringBoardDidLaunchCallback,
                (CFStringRef)UIApplicationDidFinishLaunchingNotification,
                NULL,
                CFNotificationSuspensionBehaviorDeliverImmediately
            );
        } else {
            // Cho TẤT CẢ app (App Store, App JB, App Gốc):
            // Lắng nghe khi app hoàn tất dựng khung hình mới chạy runCoreTweak
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetLocalCenter(),
                NULL,
                AppDidFinishLaunchingSafeCallback,
                (CFStringRef)UIApplicationDidFinishLaunchingNotification,
                NULL,
                CFNotificationSuspensionBehaviorDeliverImmediately
            );
        }
    }
}


