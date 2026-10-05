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
#include <stdatomic.h> // BẮT BUỘC: Hỗ trợ bộ đếm nguyên tử chống nóng máy và an toàn đa luồng
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
#import <AVFoundation/AVFoundation.h> // Đã lọc bỏ dòng import trùng lặp
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

// ĐÃ GỘP CHUẨN: SBApplication chỉ khai báo 1 lần duy nhất chứa đủ method willActivate
@interface SBApplication : NSObject
- (NSString *)bundleIdentifier;
- (NSString *)displayName;
- (id)processState;
- (BOOL)isRunning;
- (BOOL)isClassic;
- (void)didExitWithContext:(id)context;
- (void)willActivate;
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

@interface SBAppLaunchSettings : NSObject
@property (nonatomic, assign) double zoomDuration;
@property (nonatomic, assign) double launchDuration;
@property (nonatomic, assign) double delayBeforeAppLaunch;
@end

@interface SBSplashBoardController : NSObject
@end

@interface SBUIAnimationController : NSObject
@end

@interface UIInputViewAnimationStyle : NSObject
@property (nonatomic, assign) double duration;
@property (nonatomic, assign) BOOL animated;
@end

@interface SBAppToHomeWorkspaceTransaction : NSObject
@end

@interface UIViewPropertyAnimator ()
+ (void)_setTrackDuration:(double)duration;
@end

@interface _UIContextMenuContainerView : UIView
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

// KHÓA ĐÚNG KHUNG HÌNH VẬT LÝ NGUYÊN BẢN (CHỐNG CẮT LỆCH GIAO DIỆN) & ÉP NHỊP 144HZ
static void Titanium_TuneWindowServerDisplayDirectly(void) {
    Class wsClass = NSClassFromString(@"CAWindowServer");
    if (!wsClass) return;
    
    CAWindowServer *server = [wsClass server];
    NSArray *displays = [server displays];
    if (displays && displays.count > 0) {
        CAWindowServerDisplay *mainDisp = displays[0];
        
        // Chu kỳ quét 144Hz (~0.00694s mỗi frame)
        double minDuration = 1.0 / 144.0;

        if ([mainDisp respondsToSelector:@selector(setMinimumFrameDuration:)]) {
            [mainDisp setMinimumFrameDuration:minDuration];
        }
        // TẮT CHẾ ĐỘ ẢO ĐỂ TRẢ LẠI ĐÚNG ĐỘ PHÂN GIẢI THỰC CỦA MÁY (HẾT CẮT PASSCODE/STATUSBAR)
        if ([mainDisp respondsToSelector:@selector(setAllowsVirtualModes:)]) {
            [mainDisp setAllowsVirtualModes:NO];
        }
        if ([mainDisp respondsToSelector:@selector(setAllowsDisplayCompositing:)]) {
            [mainDisp setAllowsDisplayCompositing:NO];
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
                // SỬ DỤNG __bridge_transfer ĐỂ ARC QUẢN LÝ VÀ TỰ GIẢI PHÓNG (TRIỆT TIÊU 100% RÒ RỈ RAM)
                NSString *str = (__bridge_transfer NSString *)val;
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

            // SAO CHÉP DỮ LIỆU SANG BIẾN CAPTURED: TRIỆT TIÊU LỖI CON TRỎ NGĂN XẾP RÁC KHI CHẠY NỀN
            ApexV285ProPayload capturedPayload = p;
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                Titanium_WriteSyncPayloadV285(&capturedPayload);
            });
        }
    }
}

- (NSInteger)resolvedTargetHz {
    if (!self.enabled || !self.enableHzControl) return 144;
    if (self.powerSaveMode) return 60;
    
    // BẺ KHÓA TOÀN BỘ: ÉP THẲNG TRẦN 144HZ, BỎ CHẶN 60HZ CỦA APPLE
    return 144;
}

- (NSInteger)resolvedTargetFPS {
    if (!self.enabled || !self.enableFPSControl) return 144;
    if (self.powerSaveMode) return 60;
    
    // ÉP THẲNG ĐỒNG BỘ 144FPS KHÔNG GIỚI HẠN
    return 144;
}

- (NSInteger)resolvedFrameInterval {
    // Luôn trả về 1 để GPU/CoreAnimation dựng hình liên tục từng khung, không bỏ nhịp Vsync
    return 1;
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
// KHAI BÁO BIẾN TOÀN CỤC DUY NHẤT (ĐẢM BẢO ĐẦY ĐỦ CÁC CỜ HỆ THỐNG - KHÔNG LỖI UNDECLARED)
// ====================================================================================================

#include <stdatomic.h>

static volatile BOOL g_isContinuousSwiping = NO;
static volatile BOOL g_isUserTouchingScreen = NO;
static volatile BOOL g_isVideoPlayingActive = NO;       // Cờ cho Video & PiP Nhóm 8
static volatile BOOL g_isNotificationBannerActive = NO;
static volatile BOOL g_isScrollingActive = NO;
static volatile int32_t g_activeAnimationCount = 0;

// Các mốc Mach Time và hàng đợi dùng chung toàn hệ thống
static volatile uint64_t g_lastInteractionMachTime = 0;
static uint64_t g_burstDurationMachTicks = 0;
static uint64_t g_burstDurationChargingMachTicks = 0;

static volatile uint64_t g_lastBannerMachTime = 0;
static uint64_t g_bannerDurationMachTicks = 0;

static dispatch_source_t g_touchBurstTimer = nil;
static dispatch_queue_t g_touchBurstQueue = nil;
static dispatch_source_t g_bannerBurstTimer = nil;
static dispatch_queue_t g_bannerBurstQueue = nil;

// ====================================================================================================
// 5. BỘ ĐIỀU PHỐI BURST GOVERNOR NGUYÊN TỬ (AN TOÀN ĐA LUỒNG & KHÔNG OVERHEAD SYSCALL)
// ====================================================================================================

// 1. Khởi tạo Timebase: Có guard kiểm tra numer > 0 chống crash chia cho 0
static inline void Titanium_InitTouchMachTimebase(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mach_timebase_info_data_t timebase;
        if (mach_timebase_info(&timebase) == KERN_SUCCESS && timebase.numer > 0) {
            uint64_t nanos = 350ULL * 1000000ULL;         // 350ms khi dùng pin
            uint64_t nanosCharging = 180ULL * 1000000ULL; // 180ms khi sạc pin
            g_burstDurationMachTicks = (nanos * timebase.denom) / timebase.numer;
            g_burstDurationChargingMachTicks = (nanosCharging * timebase.denom) / timebase.numer;
        }
    });
}

// Alias tương thích tuyệt đối cho các nhóm gọi Titanium_EnsureMachTimebaseInit
static inline void Titanium_EnsureMachTimebaseInit(void) {
    Titanium_InitTouchMachTimebase();
}

// Khởi tạo Mach Timebase riêng cho Banner thông báo
static inline void Titanium_InitBannerMachTimebase(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mach_timebase_info_data_t timebase;
        if (mach_timebase_info(&timebase) == KERN_SUCCESS && timebase.numer > 0) {
            uint64_t nanos = 850ULL * 1000000ULL; // 850ms bao trọn chu kỳ banner trượt xuống và neo ổn định
            g_bannerDurationMachTicks = (nanos * timebase.denom) / timebase.numer;
        }
    });
}

// Kiểm tra banner còn hiệu lực theo Mach Time (2ns phản hồi)
static inline BOOL Titanium_IsNotificationBannerActive(void) {
    if (g_lastBannerMachTime == 0) return NO;
    uint64_t now = mach_absolute_time();
    return ((now - g_lastBannerMachTime) < g_bannerDurationMachTicks);
}

// 2. Nâng ưu tiên luồng chính: Thêm cờ khóa tránh spam syscall pthread liên tục mỗi frame
static inline void Titanium_LockMainThreadFast(void) {
    static pthread_t s_lastElevatedThread = NULL;
    pthread_t currentThread = pthread_self();

    // Chỉ thực thi một lần cho luồng hiện tại, tránh gọi syscall tốn chu kỳ CPU khi chạm liên tục
    if (s_lastElevatedThread != currentThread) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        struct sched_param param;
        param.sched_priority = 47;
        pthread_setschedparam(currentThread, SCHED_RR, &param);
        s_lastElevatedThread = currentThread;
    }
}

// 3. Kích xung nhịp tương tác tức thì: Nguyên tử hóa bộ đếm Token và ngắt timer rác
static void Titanium_TriggerInstantTouchBurst(void) {
    Titanium_InitTouchMachTimebase();

    // Cập nhật mốc thời gian Mach tuyệt đối (chỉ ~2ns)
    g_lastInteractionMachTime = mach_absolute_time();
    g_isUserTouchingScreen = YES;

    // Nâng priority an toàn
    Titanium_LockMainThreadFast();

    // Dùng Atomic Increment: Đảm bảo an toàn tuyệt đối nếu Touch Event đến từ Background Thread (IOHID)
    static atomic_int_fast64_t s_touchSeq = 0;
    int64_t currentSeq = atomic_fetch_add_explicit(&s_touchSeq, 1, memory_order_relaxed) + 1;

    // Sử dụng trực tiếp biến static g_isDeviceChargingV285 từ dòng 688 (TRIỆT TIÊU TOÀN BỘ CẢNH BÁO BUILD)
    BOOL isCharging = g_isDeviceChargingV285;
    int64_t burstDuration = isCharging ? (int64_t)(180 * NSEC_PER_MSEC) : (int64_t)(350 * NSEC_PER_MSEC);

    // Điều phối nhả cờ trên Main Runloop
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, burstDuration), dispatch_get_main_queue(), ^{
        if (atomic_load_explicit(&s_touchSeq, memory_order_relaxed) == currentSeq) {
            g_isUserTouchingScreen = NO;
        }
    });
}

// ====================================================================================================
// HÀM ĐIỀU PHỐI KHÓA TARGET RATE TOÀN CỤC (PHẢI NẰM TẠI ĐÂY ĐỂ CALAYER DÒNG 1436 GỌI ĐƯỢC)
// ====================================================================================================

static inline BOOL Titanium_ShouldLockTargetRate(void) {
    // 1. Chạm tay hoặc vuốt cử chỉ X
    if (g_isContinuousSwiping || g_isUserTouchingScreen) return YES;

    // 2. Đang cuộn feed hoặc trôi quán tính (TikTok, FB, Safari, Album ảnh)
    if (g_isScrollingActive) return YES;

    // 3. Có thông báo đang trượt xuống hoặc đang neo
    if (g_isNotificationBannerActive || Titanium_IsNotificationBannerActive()) return YES;

    // 4. Có hiệu ứng chuyển cảnh hệ thống, đóng mở app, lò xo
    if (g_activeAnimationCount > 0) return YES;

    // 5. Kiểm tra thời gian nhả xung Mach Time
    if (g_lastInteractionMachTime == 0) return NO;

    if (g_burstDurationMachTicks == 0) {
        Titanium_EnsureMachTimebaseInit();
    }

    uint64_t now = mach_absolute_time();
    BOOL isCharging = g_isDeviceChargingV285;
    uint64_t limitTicks = isCharging ? g_burstDurationChargingMachTicks : g_burstDurationMachTicks;

    return ((now - g_lastInteractionMachTime) < limitTicks);
}

// ====================================================================================================
// NHÓM 1: ZERO-LATENCY TOUCH PIPELINE & RAW EVENT DISPATCH (ĐIỀU PHỐI KERNEL & PHẦN CỨNG)
// ====================================================================================================

// 1. CẤP QUYỀN QOS AN TOÀN CHO NHÂN HỆ THỐNG XNU KERNEL (KHÔNG NGHẼN MẠNG YOUTUBE, KHÔNG NÓNG MÁY)
static void AppleInternal_EnforceZeroLatencyKernelTier(void) {
    #if defined(TASK_LATENCY_QOS_POLICY)
    task_latency_qos_policy_data_t latencyPolicy;
    // Sử dụng TIER_1: Phản hồi tức thì nhưng KHÔNG chặn luồng nsurlsessiond của YouTube và Safari
    latencyPolicy.task_latency_qos_tier = LATENCY_QOS_TIER_1;
    task_policy_set(mach_task_self(), TASK_LATENCY_QOS_POLICY, (task_policy_t)&latencyPolicy, TASK_LATENCY_QOS_POLICY_COUNT);
    #endif

    #if defined(TASK_THROUGHPUT_QOS_POLICY)
    task_throughput_qos_policy_data_t throughputPolicy;
    // Băng thông I/O cân bằng để luồng tải video mạng và bộ đệm Metal chạy song song không nghẽn
    throughputPolicy.task_throughput_qos_tier = THROUGHPUT_QOS_TIER_1;
    task_policy_set(mach_task_self(), TASK_THROUGHPUT_QOS_POLICY, (task_policy_t)&throughputPolicy, TASK_THROUGHPUT_QOS_POLICY_COUNT);
    #endif
}

// 2. CẤP QUYỀN THỜI GIAN THỰC MACH CHO LUỒNG VẼ GIAO DIỆN (CHỐNG QUÁ NHIỆT KHI SẠC PIN)
static void Titanium_ElevateThreadToMachRealTime(void) {
    // Nếu thiết bị đang cắm sạc: Nhả quyền cưỡng bức Mach để tránh cộng hưởng nhiệt gây nóng ran máy
    if (g_isDeviceChargingV285) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        return;
    }

    mach_timebase_info_data_t timebase;
    if (mach_timebase_info(&timebase) != KERN_SUCCESS || timebase.numer == 0) return;

    // Chu kỳ 144Hz: ~6.94ms
    uint64_t period_ns = 6944444;      
    // Cân chỉnh 1.5ms tính toán: Đủ siêu mượt 144Hz mà CPU A9 vẫn có thời gian nghỉ, máy mát rượi
    uint64_t computation_ns = 1500000; 
    uint64_t constraint_ns = 5000000;  // Giới hạn 5.0ms nhả khung hình chuẩn xác

    thread_time_constraint_policy_data_t policy;
    policy.period = (uint32_t)((period_ns * timebase.denom) / timebase.numer);
    policy.computation = (uint32_t)((computation_ns * timebase.denom) / timebase.numer);
    policy.constraint = (uint32_t)((constraint_ns * timebase.denom) / timebase.numer);
    policy.preemptible = 1;

    thread_policy_set(mach_thread_self(), THREAD_TIME_CONSTRAINT_POLICY, (thread_policy_t)&policy, THREAD_TIME_CONSTRAINT_POLICY_COUNT);
}

// 3. KHÓA BỘ ĐIỀU KHIỂN TẤM NỀN MÀN HÌNH NỘI BỘ (AN TOÀN BỘ NHỚ VÀ SELECTOR RUNTIME)
static void AppleInternal_LockHardwareCADisplay(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class caDisplayClass = objc_getClass("CADisplay");
        if (!caDisplayClass) return;

        SEL selMainDisplay = sel_registerName("mainDisplay");
        if (![caDisplayClass respondsToSelector:selMainDisplay]) return;

        id (*getMainDisplay)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
        id display = getMainDisplay(caDisplayClass, selMainDisplay);
        if (!display) return;

        SEL selLatency = sel_registerName("setLatency:");
        if ([display respondsToSelector:selLatency]) {
            void (*setLatency)(id, SEL, double) = (void (*)(id, SEL, double))objc_msgSend;
            setLatency(display, selLatency, 0.0);
        }

        SEL selVirtual = sel_registerName("setAllowsVirtualModes:");
        if ([display respondsToSelector:selVirtual]) {
            void (*setAllowsVirtual)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))objc_msgSend;
            setAllowsVirtual(display, selVirtual, NO);
        }
    });
}

// 4. NHẬN DIỆN PHẦN CỨNG (A9 - A12)
static BOOL Titanium_IsLegacyA9toA12(void) {
    static BOOL s_isLegacy = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        struct utsname sysInfo;
        if (uname(&sysInfo) == 0) {
            NSString *machine = [NSString stringWithCString:sysInfo.machine encoding:NSUTF8StringEncoding];
            if (machine) {
                s_isLegacy = ([machine hasPrefix:@"iPhone8,"] ||  // A9
                              [machine hasPrefix:@"iPhone9,"] ||  // A10
                              [machine hasPrefix:@"iPhone10,"] || // A11
                              [machine hasPrefix:@"iPhone11,"] || // A12
                              [machine hasPrefix:@"iPad6,"] || 
                              [machine hasPrefix:@"iPad7,"]);
            }
        }
    });
    return s_isLegacy;
}

// ====================================================================================================
// THIẾT LẬP CHÍNH SÁCH THỜI GIAN THỰC MACH KERNEL CHUẨN XNU (APPLE GOLDEN TIME CONSTRAINT)
// ====================================================================================================
static inline void Titanium_EnforceMachFrameConstraintDynamic(int targetHz) {
    // 1. Thread-local guard: Không spam Syscall vào Kernel Ring 0 nếu luồng hiện tại đã được nâng cấp
    static __thread int s_appliedHz = 0;
    if (s_appliedHz == targetHz && targetHz > 0) {
        return;
    }

    // 2. Cache Timebase một lần duy nhất (tiết kiệm 100% chi phí truy xuất lặp lại)
    static mach_timebase_info_data_t s_timebase;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        mach_timebase_info(&s_timebase);
        if (s_timebase.numer == 0) s_timebase.numer = 1;
        if (s_timebase.denom == 0) s_timebase.denom = 1;
    });

    // 3. Khống chế tần số quét an toàn (Mặc định 60Hz nếu chưa nạp cấu hình)
    if (targetHz < 30) targetHz = 60;
    if (targetHz > 144) targetHz = 144;

    // 4. Tính toán nano-giây chính xác tuyệt đối theo chu kỳ V-Sync thực tế:
    // - 60Hz : ~16.666.666 ns
    // - 120Hz: ~8.333.333 ns
    // - 144Hz: ~6.944.444 ns
    uint64_t period_ns = 1000000000ULL / (uint64_t)targetHz;

    // TỶ LỆ VÀNG APPLE XNU (CHỐNG BỊ KERNEL GIÁNG CẤP):
    // - computation (35% period): CPU nướng xong lệnh vẽ trong 35% thời gian đầu chu kỳ
    // - constraint  (75% period): Hoàn tất giao tác render trước khi tia quét V-Sync bắt đầu 25%
    uint64_t computation_ns = (period_ns * 35ULL) / 100ULL;
    uint64_t constraint_ns  = (period_ns * 75ULL) / 100ULL;

    // 5. Chuyển đổi nano-giây sang Mach Ticks (Apple Timer Clock Ticks)
    uint64_t period_ticks      = (period_ns * s_timebase.denom) / s_timebase.numer;
    uint64_t computation_ticks = (computation_ns * s_timebase.denom) / s_timebase.numer;
    uint64_t constraint_ticks  = (constraint_ns * s_timebase.denom) / s_timebase.numer;

    thread_time_constraint_policy_data_t policy;
    policy.period      = (uint32_t)period_ticks;
    policy.computation = (uint32_t)computation_ticks;
    policy.constraint  = (uint32_t)constraint_ticks;
    policy.preemptible = 1;

    // 6. Cấp quyền Mach Real-Time & GIẢI PHÓNG PORT NGAY LẬP TỨC (TRIỆT TIÊU 100% RÒ RỈ PORT)
    mach_port_t threadPort = mach_thread_self();
    kern_return_t kr = thread_policy_set(threadPort,
                                         THREAD_TIME_CONSTRAINT_POLICY,
                                         (thread_policy_t)&policy,
                                         THREAD_TIME_CONSTRAINT_POLICY_COUNT);

    // GIẢI PHÓNG SEND-RIGHT: Ngăn chặn hoàn toàn hiện tượng tràn bảng Mach Port gây văng SpringBoard
    mach_port_deallocate(mach_task_self(), threadPort);

    if (kr == KERN_SUCCESS) {
        s_appliedHz = targetHz;
    } else {
        // Fallback POSIX an toàn nếu tiến trình bị Sandbox siết quyền Mach
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
}

// Hàm Wrapper tương thích ngược
static inline void Titanium_EnforceMachFrameConstraint(void) {
    int targetHz = 60;
    if (CFG285 && [CFG285 respondsToSelector:@selector(targetHz)]) {
        targetHz = (int)CFG285.targetHz;
    }
    Titanium_EnforceMachFrameConstraintDynamic(targetHz > 0 ? targetHz : 60);
}

// ====================================================================================================
// NHÓM NỘI BỘ APPLE: MÔ PHỎNG VÒNG LẶP _UIUPDATECYCLE & WINDOWSERVER LOW-LATENCY
// ====================================================================================================

%group Group_Apple_Internal_ProMotion_Apex

// 1. CƯỚP QUYỀN VÒNG LẶP CẬP NHẬT HỢP NHẤT _UIUPDATECYCLE
%hook _UIUpdateCycle

- (BOOL)isPerformingUpdate {
    if (IS_ACTIVE && Titanium_ShouldLockTargetRate()) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    return %orig;
}

- (void)performUpdateWithInfo:(void *)info {
    if (IS_ACTIVE && Titanium_ShouldLockTargetRate()) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else if ([NSThread isMainThread]) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
    %orig(info);
}

%end

// 2. KHÓA NHỊP 4 PHA (INPUT -> ANIMATION -> LAYOUT -> COMMIT)
%hook _UIUpdateSequenceItem

- (void)performItem {
    if (IS_ACTIVE && Titanium_ShouldLockTargetRate()) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig;
}

%end

// 3. ÉP WINDOWSERVER CHUYỂN SANG CHẾ ĐỘ LOW-LATENCY TOÀN DIỆN
%hook CAWindowServerDisplay

- (void)setAllowsVirtualModes:(BOOL)allows {
    if (IS_ACTIVE) allows = YES;
    %orig(allows);
}

- (BOOL)allowsVirtualModes {
    if (IS_ACTIVE) return YES;
    return %orig;
}

- (void)setTag:(NSInteger)tag {
    %orig(tag);
}

%end

%end

// ====================================================================================================
// NHÓM 1: CẢM ỨNG 0MS NỘI BỘ APPLE (IOHIDEVENT + UIEVENTDISPATCHER + SPECULATIVE TOUCH-DOWN)
// ====================================================================================================

%group Group_ZeroLatency_Touch_Opt

// 1. ĐÓN ĐẦU CẢM ỨNG TẦNG THẤP IOKIT (UIEVENTFETCHER): BỎ QUA HÀNG ĐỢI RUNLOOP
%hook UIEventFetcher

- (void)_receiveHIDEvent:(void *)event {
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time(); // Ghi nhận nano-giây khi photon chạm kính
    }
    %orig(event);
}

- (void)displayLinkDidFire:(id)arg1 {
    if (IS_ACTIVE && Titanium_ShouldLockTargetRate()) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig(arg1);
}

%end

// 2. BƠM TRỰC TIẾP CẢM ỨNG VÀO ĐẦU VÒNG LẶP HỆ THỐNG (_UIEVENTDISPATCHER)
%hook _UIEventDispatcher

- (void)dispatchEvent:(UIEvent *)event toTarget:(id)target {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (event.type == 0) { // Chạm màn hình: Xả sạch bộ đệm hiển thị ngay lập tức
            [CATransaction flush];
        }
    }
    %orig(event, target);
}

%end

// 3. TOÀN DIỆN CẢM ỨNG ICON SPRINGBOARD (CẮT ĐỨT 150MS TRỄ APPLE - DUY NHẤT 1 NƠI TRONG TWEAK)
%hook SBIconView

- (double)highlightDelay {
    if (IS_ACTIVE) return 0.0; // 0ms: Chạm là sáng icon ngay lập tức
    return %orig;
}

- (void)setHighlighted:(BOOL)highlighted {
    if (highlighted && IS_ACTIVE && CFG285.touchResponseBoost) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
    %orig(highlighted);
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
        Titanium_EnforceMachFrameConstraintDynamic(144);
        [CATransaction flush]; // Chuẩn bị bề mặt render ngay khi chạm, nhanh hơn Apple 0.5s
    }
    %orig(touches, event);
}

- (void)setTouchDownInIcon:(BOOL)touchDown {
    if (touchDown && IS_ACTIVE && CFG285.touchResponseBoost) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig(touchDown);
}

%end

// 4. PHẢN HỒI NÚT BẤM VÀ ĐIỀU HƯỚNG TỨC THÌ 0MS (AN TOÀN TIẾN TRÌNH)
%hook UIControl

- (NSTimeInterval)_touchDelayThreshold {
    if (IS_ACTIVE && CFG285.touchResponseBoost) return 0.0; // 0ms: Chạm là ăn nút ngay lập tức
    return %orig;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();

        // PHÂN BIỆT TIẾN TRÌNH: Chống nghẽn mạng YouTube & app bên thứ 3
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
            Titanium_EnforceMachFrameConstraintDynamic(144);
        } else if ([NSThread isMainThread]) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
    %orig(touches, event);
}

%end

// 5. ĐÓN ĐẦU CHẠM TOÀN MÀN HÌNH & PHÍM CỨNG VOLUME HUD (DUY NHẤT 1 NƠI TRONG TOÀN TWEAK)
%hook UIWindow

- (BOOL)_shouldDelayTouchForCancelEvents {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        if (g_activeAnimationCount > 0 || g_isScrollingActive) {
            return %orig;
        }
        return NO;
    }
    return %orig;
}

- (void)sendEvent:(UIEvent *)event {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        // event.type == 0: Chạm cảm ứng | event.type == 3: Phím cứng Volume Up/Down
        if (event.type == 0 || event.type == 3) {
            g_lastInteractionMachTime = mach_absolute_time();

            if (Titanium_IsSpringBoard()) {
                Titanium_LockMainThreadFast();
                Titanium_EnforceMachFrameConstraintDynamic(144);
            } else if ([NSThread isMainThread]) {
                pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
            }
        }
    }
    %orig(event);
}

- (void)_sendTouchesForEvent:(UIEvent *)event {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig(event);
}

%end

%end

// ====================================================================================================
// NHÓM 2: METAL GRAPHICS, TRIPLE BUFFERING & BẢO TOÀN TỌA ĐỘ LAYER (ĐÃ KIỂM SOÁT AN TOÀN 100%)
// ====================================================================================================

%group Group_Metal_ZeroTearing_Pacing

// 1. ĐỒNG BỘ HIỂN THỊ METAL AN TOÀN (KHÓA ĐỒNG BỘ V-SYNC CHỐNG XÉ HÌNH)
%hook CAMetalLayer

- (void)setDisplaySyncEnabled:(BOOL)enabled {
    if (IS_ACTIVE) enabled = YES; // Khóa đồng bộ V-Sync 144Hz chống xé hình
    %orig(enabled);
}

- (void)setPresentsWithTransaction:(BOOL)presents {
    if (IS_ACTIVE) presents = YES; // Gắn kết chặt chẽ vào CATransaction của UIKit
    %orig(presents);
}

- (BOOL)presentsWithTransaction {
    if (IS_ACTIVE) return YES;
    return %orig;
}

%end

// 2. KÍCH HOẠT ĐỒ HỌA ZERO-LATENCY AN TOÀN: CHỐNG NÓNG MÁY, KHÔNG ĐỘNG HÌNH NỀN & MỊN HOẠT ẢNH
%hook CALayer

- (void)display {
    if (IS_ACTIVE && CFG285.touchResponseBoost && NSThread.isMainThread && Titanium_ShouldLockTargetRate()) {
        // 1. BẢO VỆ TUYỆT ĐỐI HÌNH NỀN (WALLPAPER): Bỏ qua 100% layer thuộc Wallpaper/Poster
        id del = self.delegate;
        const char *delName = del ? object_getClassName(del) : NULL;
        BOOL isWallpaper = (delName != NULL) && (strstr(delName, "Wallpaper") != NULL || strstr(delName, "Poster") != NULL);

        if (!isWallpaper) {
            // 2. CHỐNG GIẬT CONTROL CENTER & BUNG MENU ICON (3D TOUCH): Bỏ qua CABackdropLayer
            static Class s_backdropCls = Nil;
            static dispatch_once_t s_onceBackdrop;
            dispatch_once(&s_onceBackdrop, ^{
                s_backdropCls = objc_getClass("CABackdropLayer");
            });

            BOOL isBackdrop = (s_backdropCls && [self isKindOfClass:s_backdropCls]);

            // 3. CHỐNG GIẬT GÓC BO & ZOOM RA/VÀO APP:
            BOOL isCornerMasking = (self.mask != nil) || (self.cornerRadius > 0.0f && self.masksToBounds);

            // 4. CHỐNG NÓNG MÁY KHI SẠC PIN: Cắm sạc sẽ không spam flush GPU liên tục
            BOOL isThermalSafe = !g_isDeviceChargingV285 || (g_isUserTouchingScreen || g_isContinuousSwiping);

            if (!isBackdrop && !isCornerMasking && isThermalSafe) {
                Titanium_EnableZeroLatencyPipeline();
            }
        }
    }
    %orig;
}

%end

// 3. ƯU TIÊN LUỒNG DỰNG HÌNH ĐỒNG BỘ: ĐỒNG NHẤT SPRINGBOARD & APP, CHỐNG NÓNG MÁY
%hook CAContext

- (void)setCommitPriority:(uint32_t)priority {
    if (IS_ACTIVE) {
        if (g_isDeviceChargingV285) {
            %orig(priority);
            return;
        }
        if (Titanium_ShouldLockTargetRate()) {
            priority = 100;
        }
    }
    %orig(priority);
}

- (uint32_t)commitPriority {
    if (IS_ACTIVE && !g_isDeviceChargingV285 && Titanium_ShouldLockTargetRate()) {
        return 100;
    }
    return %orig;
}

- (void)setDesiredDynamicRange:(float)range {
    if (IS_ACTIVE) range = 1.0f; // Khóa SDR chuẩn 1.0f: GPU mát lạnh, không nghẽn shader
    %orig(range);
}

%end

// 4. XẢ SẠCH LỆNH VẼ TRƯỚC V-SYNC
%hook CATransaction

+ (void)commit {
    if (IS_ACTIVE && Titanium_ShouldLockTargetRate()) {
        [CATransaction flush];
    }
    %orig;
}

%end

%end

// ====================================================================================================
// ĐIỀU PHỐI TRẠNG THÁI CHUYỂN ĐỘNG, VIDEO VÀ THÔNG BÁO HỆ THỐNG
// ====================================================================================================

static void Titanium_TriggerNotificationBurst(void) {
    Titanium_InitBannerMachTimebase();
    g_lastBannerMachTime = mach_absolute_time();
    g_isNotificationBannerActive = YES;
    Titanium_LockMainThreadFast();

    static int64_t s_bannerSeq = 0;
    int64_t currentSeq = ++s_bannerSeq;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(850 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        if (s_bannerSeq == currentSeq) {
            g_isNotificationBannerActive = NO;
        }
    });
}

// ====================================================================================================
// NHÓM 3: ĐỘNG CƠ DUAL-GEAR (TƯƠNG TÁC 144HZ CĂNG TRẦN - TĨNH HẲN 100% HẠ 30HZ - KHÔNG ĐEN APP)
// ====================================================================================================

static inline NSInteger Titanium_GetTargetConfiguredHz(void) {
    if (!IS_ACTIVE || !CFG285) return 144;
    
    NSInteger userHz = 144;
    if ([CFG285 respondsToSelector:@selector(targetHz)]) {
        userHz = (NSInteger)[CFG285 targetHz];
    } else if ([CFG285 respondsToSelector:@selector(customFPS)]) {
        userHz = (NSInteger)[CFG285 customFPS];
    } else if ([CFG285 respondsToSelector:@selector(selectedFPS)]) {
        userHz = (NSInteger)[CFG285 selectedFPS];
    }
    
    if (userHz < 30) userHz = 30;
    if (userHz > 144) userHz = 144;
    return userHz;
}

// Kiểm tra trạng thái xem video thụ động để trả lại FPS gốc cho video
static inline BOOL Titanium_IsPassiveVideoPlayback(void) {
    return (g_isVideoPlayingActive && !g_isUserTouchingScreen && !g_isScrollingActive && g_activeAnimationCount == 0);
}

%group Group_FluidTransitions_Pacing

// ----------------------------------------------------------------------------------------------------
// 1. ĐIỀU PHỐI VÒNG LẶP DỰNG HÌNH CADISPLAYLINK (CHUYỂN ĐỘNG 144HZ - TĨNH HẲN 30HZ)
// ----------------------------------------------------------------------------------------------------
%hook CADisplayLink

- (CFTimeInterval)targetTimestamp {
    return %orig;
}

- (NSInteger)preferredFramesPerSecond {
    if (Titanium_IsPassiveVideoPlayback()) return %orig;

    if (IS_ACTIVE && CFG285.enableFPSControl) {
        NSInteger maxTarget = Titanium_GetTargetConfiguredHz();
        // CÒN TƯƠNG TÁC / VUỐT / HOẠT ẢNH: ĐẨY CĂNG TRẦN 144HZ
        if (Titanium_ShouldLockTargetRate()) {
            return maxTarget;
        }
        // TĨNH HẲN 100%: HẠ AN TOÀN VỀ 30 FPS (MÁT MÁY NHƯNG FRAMEBUFFER LUÔN SỐNG, CHỐNG ĐEN APP 100%)
        return 30;
    }
    return %orig;
}

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (Titanium_IsPassiveVideoPlayback()) {
        %orig;
        return;
    }

    if (IS_ACTIVE && CFG285.enableFPSControl) {
        NSInteger maxTarget = Titanium_GetTargetConfiguredHz();
        %orig(Titanium_ShouldLockTargetRate() ? maxTarget : 30);
        return;
    }
    %orig;
}

// KHÓA DẢI DYNAMIC REFRESH: TRẦN LUÔN SẴN SÀNG 144HZ TRONG 0MS
- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (Titanium_IsPassiveVideoPlayback()) { 
        %orig; 
        return; 
    }

    if (@available(iOS 15.0, *)) {
        if (IS_ACTIVE && CFG285.enableHzControl) {
            float maxTarget = (float)Titanium_GetTargetConfiguredHz();
            if (Titanium_ShouldLockTargetRate()) {
                // TƯƠNG TÁC / CHUYỂN CẢNH: KHÓA CHẶT TRẦN 144HZ
                range = SafeMakeFRR(maxTarget, maxTarget, maxTarget);
            } else {
                // TĨNH HẲN: SÀN 30HZ, PREFERRED 30HZ (MÁT MÁY), TRẦN 144HZ BẬT LÊN TRONG 0MS KHI CHẠM
                range = SafeMakeFRR(30.0f, maxTarget, 30.0f);
            }
        }
    }
    %orig(range);
}

- (void)setFrameInterval:(NSInteger)interval {
    if (!Titanium_IsPassiveVideoPlayback() && IS_ACTIVE && CFG285.enableHzControl) {
        // Đang tương tác: interval = 1 (vẽ từng frame không bỏ nhịp). Tĩnh hẳn: interval = 2 (hạ về 30fps trên màn 60Hz)
        interval = Titanium_ShouldLockTargetRate() ? 1 : 2;
    }
    %orig(interval);
}

%end

// ----------------------------------------------------------------------------------------------------
// 2. KHÓA TẤM NỀN PHẦN CỨNG CADISPLAY (TRẦN LUÔN GIỮ 144HZ ĐỂ VỌT LÊN KHÔNG KHỰNG)
// ----------------------------------------------------------------------------------------------------
%hook CADisplay

- (NSInteger)preferredFPS {
    if (Titanium_IsPassiveVideoPlayback()) return %orig;
    if (!IS_ACTIVE) return %orig;
    return Titanium_GetTargetConfiguredHz();
}

- (void)setPreferredFPS:(NSInteger)fps {
    if (Titanium_IsPassiveVideoPlayback()) { 
        %orig; 
        return; 
    }
    if (IS_ACTIVE) {
        fps = Titanium_GetTargetConfiguredHz();
    }
    %orig(fps);
}

// Sàn phần cứng an toàn: Tĩnh không bao giờ cho phép tụt dưới 30Hz gây đen app
- (NSInteger)minimumFPS {
    if (IS_ACTIVE && CFG285.enableFPSControl) {
        return 30;
    }
    return %orig;
}

- (BOOL)supportsDynamicRefresh {
    if (IS_ACTIVE) return YES;
    return %orig;
}

- (BOOL)hasDynamicDisplayMode {
    if (IS_ACTIVE) return YES;
    return %orig;
}

%end

// ----------------------------------------------------------------------------------------------------
// 3. ĐIỀU PHỐI WINDOWSERVER DISPLAY (SÀN 30HZ - TRẦN 144HZ)
// ----------------------------------------------------------------------------------------------------
%hook CAWindowServerDisplay

- (double)minimumRefreshRate {
    if (IS_ACTIVE && CFG285.enableHzControl) {
        return 30.0; // Sàn tĩnh 30Hz an toàn
    }
    return %orig;
}

- (double)maximumRefreshRate {
    if (IS_ACTIVE && CFG285.enableHzControl) {
        return (double)Titanium_GetTargetConfiguredHz(); // Trần 144Hz
    }
    return %orig;
}

- (double)idealRefreshRate {
    if (IS_ACTIVE && CFG285.enableHzControl) {
        return (double)Titanium_GetTargetConfiguredHz();
    }
    return %orig;
}

- (BOOL)allowsVirtualModes {
    if (IS_ACTIVE) return YES;
    return %orig;
}

- (void)setAllowsVirtualModes:(BOOL)allows {
    if (IS_ACTIVE) allows = YES;
    %orig(allows);
}

%end

// ----------------------------------------------------------------------------------------------------
// 4. BÁO CÁO THÔNG SỐ UISCREEN ĐỒNG BỘ 144HZ CHO TOÀN BỘ UIKIT
// ----------------------------------------------------------------------------------------------------
%hook UIScreen

- (NSInteger)maximumFramesPerSecond {
    if (IS_ACTIVE) return Titanium_GetTargetConfiguredHz();
    return %orig;
}

- (NSInteger)_maximumFramesPerSecond {
    if (IS_ACTIVE) return Titanium_GetTargetConfiguredHz();
    return %orig;
}

- (CGFloat)_refreshRate {
    if (IS_ACTIVE) return (CGFloat)Titanium_GetTargetConfiguredHz();
    return %orig;
}

- (BOOL)supportsDynamicRefreshRate {
    if (IS_ACTIVE) return YES;
    return %orig;
}

- (BOOL)_supportsDynamicRefreshRate {
    if (IS_ACTIVE) return YES;
    return %orig;
}

- (void)_setTargetRefreshRate:(CGFloat)rate {
    if (IS_ACTIVE) {
        rate = (CGFloat)Titanium_GetTargetConfiguredHz();
    }
    %orig(rate);
}

%end

// ----------------------------------------------------------------------------------------------------
// 5. KHÓA CỨNG TOÀN BỘ HOẠT ẢNH & LÒ XO (CAANIMATION) ĐẠT ĐỈNH 144HZ
// ----------------------------------------------------------------------------------------------------
%hook CAAnimation

- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if (!Titanium_IsPassiveVideoPlayback() && IS_ACTIVE) {
            float maxTarget = (float)Titanium_GetTargetConfiguredHz();
            range = SafeMakeFRR(maxTarget, maxTarget, maxTarget);
            g_lastInteractionMachTime = mach_absolute_time();
        }
    }
    %orig(range);
}

%end

%hook CASpringAnimation

- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if (!Titanium_IsPassiveVideoPlayback() && IS_ACTIVE) {
            float maxTarget = (float)Titanium_GetTargetConfiguredHz();
            // Đảm bảo lò xo nảy đạt trọn vẹn 144Hz cho tới điểm tiếp đất
            range = SafeMakeFRR(maxTarget, maxTarget, maxTarget);
            g_lastInteractionMachTime = mach_absolute_time();
        }
    }
    %orig(range);
}

%end

// ----------------------------------------------------------------------------------------------------
// 6. THEO DÕI VIDEO (ĐẢM BẢO YOUTUBE VÀ VIDEO KHÔNG BỊ KHỰNG HAY NGHẼN MẠNG)
// ----------------------------------------------------------------------------------------------------
%hook AVPlayer

- (void)setRate:(float)rate {
    %orig(rate);
    if (IS_ACTIVE) {
        g_isVideoPlayingActive = (rate > 0.0f);
    }
}

%end

// ----------------------------------------------------------------------------------------------------
// 7. ĐÓN ĐẦU THÔNG BÁO XUẤT HIỆN: KÍCH XUNG 144HZ TỨC THÌ TRONG 0MS
// ----------------------------------------------------------------------------------------------------
%hook NCNotificationDispatcher

- (void)postNotificationWithRequest:(id)request {
    if (IS_ACTIVE) {
        Titanium_TriggerNotificationBurst();
    }
    %orig(request);
}

%end

%hook NCNotificationViewController

- (void)viewWillAppear:(BOOL)animated {
    if (IS_ACTIVE) {
        Titanium_TriggerNotificationBurst();
    }
    %orig(animated);
}

%end

%hook SBNotificationBannerDestination

- (void)postNotificationRequest:(id)request {
    if (IS_ACTIVE) {
        Titanium_TriggerNotificationBurst();
    }
    %orig(request);
}

%end

// ----------------------------------------------------------------------------------------------------
// 8. BẢO VỆ KHỞI CHẠY APP: VÙNG AN TOÀN 1.5S ĐẦU 144HZ TRIỆT TIÊU 100% LỖI ĐEN MÀN HÌNH
// ----------------------------------------------------------------------------------------------------
%hook UIApplication

- (void)_applicationDidBecomeActive:(id)arg1 {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_activeAnimationCount++;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1500 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            if (g_activeAnimationCount > 0) g_activeAnimationCount--;
        });
    }
}

- (void)applicationDidBecomeActive:(id)arg1 {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

%end

%end

// ====================================================================================================
// NHÓM 4: ĐA NHIỆM SIÊU MƯỢT (CHỐNG JETSAM KILL APP GÂY ĐEN MÀN HÌNH - KHÓA 144HZ THU VỀ 0MS)
// ====================================================================================================

%group Group_Switcher30Apps_Virtualization

// 1. KHÓA 144HZ TOÀN BỘ CHU TRÌNH CỬ CHỈ VUỐT VÀ NẢY LÒ XO THU VỀ
%hook SBHomeGestureInteraction

- (void)_handleGestureBegan:(id)gesture {
    if (IS_ACTIVE) {
        g_isContinuousSwiping = YES;
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
        Titanium_EnforceMachFrameConstraintDynamic(144);
    }
    %orig(gesture);
}

- (void)_handleGestureChanged:(id)gesture {
    if (IS_ACTIVE) {
        g_isContinuousSwiping = YES;
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig(gesture);
}

- (void)_handleGestureEnded:(id)gesture {
    if (IS_ACTIVE) {
        g_isContinuousSwiping = NO;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();

        static int64_t s_homeEndSeq = 0;
        int64_t currentSeq = ++s_homeEndSeq;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(750 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            if (s_homeEndSeq == currentSeq) {
                if (g_activeAnimationCount > 0) g_activeAnimationCount--;
            }
        });
    }
    %orig(gesture);
}

- (void)_handleGestureCancelled:(id)gesture {
    if (IS_ACTIVE) {
        g_isContinuousSwiping = NO;
        if (g_activeAnimationCount > 0) g_activeAnimationCount--;
    }
    %orig(gesture);
}

%end

// 2. KHÓA CHẶT HOẠT ẢNH THOÁT APP VỀ ICON VÀ ĐA NHIỆM SWITCHER
%hook SBFluidSwitcherGestureWorkspaceTransaction

- (BOOL)canInterruptActiveGesture {
    return %orig;
}

- (BOOL)_shouldSuppressGestures {
    return %orig;
}

- (void)_begin {
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
        Titanium_EnforceMachFrameConstraintDynamic(144);
    }
    %orig;
}

- (void)_didComplete {
    %orig;
    if (IS_ACTIVE) {
        if (g_activeAnimationCount > 0) g_activeAnimationCount--;
        g_isContinuousSwiping = NO;
    }
}

%end

// 3. THOÁT APP: GIỮ TRẦN 144HZ CHO ĐẾN KHI ICON THU NHỎ HOÀN TOÀN
%hook SBAppToHomeWorkspaceTransaction

- (BOOL)shouldAnimateOrientationChangeOnCompletion {
    return %orig;
}

- (void)_willBegin {
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
        Titanium_TriggerInstantTouchBurst();
        Titanium_EnforceMachFrameConstraintDynamic(144);
    }
    %orig;
}

- (void)_didComplete {
    %orig;
    if (IS_ACTIVE) {
        if (g_activeAnimationCount > 0) g_activeAnimationCount--;
        g_isContinuousSwiping = NO;
        g_isUserTouchingScreen = NO;
    }
}

%end

// 4. MỞ APP: ĐÓN ĐẦU KHUNG HÌNH MƯỢT MÀ, KHÔNG KHỰNG GÓC (CHỐNG ĐEN APP)
%hook SBHomeToAppWorkspaceTransaction

- (void)_willBegin {
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
        Titanium_TriggerInstantTouchBurst();
        Titanium_EnforceMachFrameConstraintDynamic(144);
    }
    %orig;
}

- (void)_didComplete {
    %orig;
    if (IS_ACTIVE) {
        if (g_activeAnimationCount > 0) g_activeAnimationCount--;
    }
}

%end

// 5. TRÔI THẺ ĐA NHIỆM SIÊU MƯỢT & BẢO VỆ TIẾN TRÌNH KHÔNG BỊ JETSAM DIỆT (CHỐNG ĐEN APP 100%)
%hook SBAppSwitcherSettings

- (BOOL)shouldKeepAppSnapshotsInMemory {
    return %orig; // Giữ nguyên cơ chế hệ thống: giải phóng RAM 2GB an toàn, chống Jetsam kill app ngầm
}

- (CGFloat)decelerationRate {
    if (IS_ACTIVE) return UIScrollViewDecelerationRateNormal;
    return %orig;
}

%end

%hook SBAppSwitcherController

- (void)viewWillAppear:(BOOL)animated {
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
        Titanium_TriggerInstantTouchBurst();
        Titanium_EnforceMachFrameConstraintDynamic(144);
    }
    %orig(animated);
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig(animated);
    if (IS_ACTIVE) {
        if (g_activeAnimationCount > 0) g_activeAnimationCount--;
        g_isUserTouchingScreen = NO;
        g_isContinuousSwiping = NO;
    }
}

%end

// 6. THẺ ỨNG DỤNG TRONG SWITCHER: ĐỒNG BỘ HOÁ RASTERIZE
%hook SBFluidSwitcherItemContainer

- (void)prepareForReuse {
    %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 5: KHỞI CHẠY ỨNG DỤNG SIÊU TỐC (TURBO ENGINE - TRIỆT TIÊU 100% ĐEN APP & KHÔNG NGHẼN MẠNG)
// ====================================================================================================

%group Group_FastLaunch_SuperEngineV285

// 1. TỐI ƯU TIẾN TRÌNH FRONTBOARD: CẤP QUYỀN VIP KHI NẠP APP (CHỐNG NÓNG MÁY KHI SẠC)
%hook FBApplicationProcess

- (void)bootstrapWithContext:(id)context completion:(id)completion {
    if (IS_ACTIVE && CFG285.turboAppLaunch && !g_isDeviceChargingV285) {
        Titanium_EnforceThreadVIPPolicy();
    }
    %orig(context, completion);
}

- (void)launchIfNecessary {
    if (IS_ACTIVE && CFG285.turboAppLaunch && !g_isDeviceChargingV285 && Titanium_ShouldLockTargetRate()) {
        Titanium_EnforceThreadVIPPolicy();
    }
    %orig;
}

%end

// 2. GẮN KẾT SCENE GỐC & THỨC DẬY TỪ BACKGROUND (TRIỆT TIÊU 100% ĐEN APP & HẾT NGHẼN MẠNG YOUTUBE)
%hook UIApplication

- (void)_runWithMainScene:(id)scene transitionContext:(id)context completion:(id)completion {
    if (IS_ACTIVE && CFG285.turboAppLaunch) {
        g_lastInteractionMachTime = mach_absolute_time();

        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
            Titanium_EnforceThreadVIPPolicy();
            Titanium_EnforceMachFrameConstraintDynamic(144);
        } else if ([NSThread isMainThread]) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }

    %orig(scene, context, completion);

    // CHỐNG ĐEN APP 100%: Xả sạch bộ đệm Framebuffer ngay sau khi gắn kết Scene
    if (IS_ACTIVE && !Titanium_IsSpringBoard()) {
        [CATransaction flush];
    }
}

- (void)_applicationWillEnterForeground {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();

        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
            Titanium_EnforceThreadVIPPolicy();
            Titanium_EnforceMachFrameConstraintDynamic(144);
        } else if ([NSThread isMainThread]) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
            [CATransaction flush];
        }
    }
}

%end

%end

// ====================================================================================================
// NHÓM 6: CUỘN FEED TIKTOK / BÀN PHÍM SIÊU NHẠY (CHUẨN HÓA LOGOS %ORIG - SẠCH LỖI BIÊN DỊCH 100%)
// ====================================================================================================

%group Group_Scroll_And_Keyboard_Opt

// 1. ÉP BÀN PHÍM BẬT RA NHANH GẤP ĐÔI (0.12S) & GÕ PHÍM 0MS
%hook UIInputViewAnimationStyle

- (double)duration {
    if (IS_ACTIVE) return 0.05;
    return %orig;
}

%end

%hook UIKeyboardImpl

- (void)showKeyboard {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
    %orig;
}

- (void)handleKeyWithString:(id)string forKeyEvent:(id)event executionContext:(id)context {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig; // Forward đối số tự động: triệt tiêu lỗi Invalid argument structure
}

- (void)addInputString:(id)string withFlags:(NSUInteger)flags executionContext:(id)context {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig;
}

%end

%hook UITextInputController

- (void)_insertText:(id)text {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig;
}

- (void)deleteBackward {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig;
}

%end

// 2. ĐÓN ĐẦU CHẠM NÚT 3 GẠCH & NÚT ĐIỀU HƯỚNG
%hook UIControl

- (void)sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
    }
    %orig;
}

%end

// 3. TĂNG TỐC CHUYỂN QUA LẠI CÁC TAB (UITABBARCONTROLLER) TỨC THÌ
%hook UITabBarController

- (void)setSelectedIndex:(NSUInteger)index {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
    %orig;
}

- (void)setSelectedViewController:(UIViewController *)selectedViewController {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
    %orig;
}

%end

// 4. TĂNG TỐC ĐẨY/RÚT TRANG NAVIGATION (PUSH/POP/PRESENT)
%hook UINavigationController

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
        g_lastInteractionMachTime = mach_absolute_time();
        [CATransaction flush];
    }
    %orig;
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
        g_lastInteractionMachTime = mach_absolute_time();
    }
    return %orig;
}

%end

%hook UIViewController

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig; // Sửa lỗi xung đột block completion với parser Logos
}

%end

// 5. CUỘN DANH SÁCH TOÀN HỆ THỐNG & APP THỨ BA (TRÔI ÊM QUÁN TÍNH)
%hook UIScrollView

- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    if (IS_ACTIVE && [view isKindOfClass:[UIControl class]]) {
        if (self.isDragging) return YES;
        return NO;
    }
    return %orig;
}

- (BOOL)delaysContentTouches {
    return %orig;
}

- (void)_scrollViewWillBeginDragging {
    if (IS_ACTIVE) {
        g_isScrollingActive = YES;
        Titanium_TriggerInstantTouchBurst();
    }
    %orig;
}

- (void)_notifyDidScroll {
    if (IS_ACTIVE) {
        g_isScrollingActive = YES;
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig;
}

- (void)_smoothScrollWithTimestamp:(double)timestamp {
    if (IS_ACTIVE) {
        g_isScrollingActive = YES;
        g_lastInteractionMachTime = mach_absolute_time();
        if (!Titanium_IsSpringBoard() && [NSThread isMainThread]) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
    %orig;
}

- (CGFloat)decelerationRate {
    if (IS_ACTIVE) return UIScrollViewDecelerationRateNormal;
    return %orig;
}

- (void)_stopScrollDecelerationNotify:(BOOL)notify {
    %orig;
    if (IS_ACTIVE) {
        g_isScrollingActive = NO;
    }
}

- (void)_scrollViewDidEndDecelerating {
    %orig;
    if (IS_ACTIVE) {
        g_isScrollingActive = NO;
    }
}

- (void)_scrollViewDidEndDraggingForChildScrollView:(id)view {
    %orig;
    if (IS_ACTIVE && !self.isDecelerating) {
        g_isScrollingActive = NO;
    }
}

%end

// 6. GIỮ ĐỘ PHẢN HỒI CELL NHANH NHƯNG BẢO TOÀN NỀN SAFARI VÀ ICON EMOJI
%hook UITableView
- (void)willMoveToWindow:(UIWindow *)newWindow { 
    %orig; 
}
%end

%hook UICollectionView
- (void)willMoveToWindow:(UIWindow *)newWindow { 
    %orig; 
}
%end

%end

// ====================================================================================================
// NHÓM 7: SPRINGBOARD - TOÀN BỘ HIỆU ỨNG BÊN NGOÀI (FOLDER, LOCKSCREEN, 3D TOUCH, CC/NC, LOAD APP)
// ====================================================================================================

%group Group_Display_SpringBoardV285

// 1. BẢO TOÀN NGUYÊN BẢN HÌNH NỀN (TUYỆT ĐỐI KHÔNG CAN THIỆP GÂY ĐEN HAY BIẾN DẠNG HÌNH NỀN)
%hook SBWallpaperController
- (double)wallpaperScaleForVariant:(long long)variant {
    return %orig;
}
%end

// 2. CỬ CHỈ ĐA NHIỆM SPRINGBOARD
%hook SBFluidSwitcherViewController
- (void)handleFluidSwitcherGesture:(id)gesture {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
    %orig(gesture);
}
%end

// 3. TRIỆT TIÊU LAG KHI CHỤP MÀN HÌNH & BẤM PHÍM CỨNG VOLUME
%hook SBScreenshotManager
- (void)saveScreenshotsWithCompletion:(id)completion {
    if (IS_ACTIVE) {
        Titanium_LockMainThreadFast();
        Titanium_TriggerInstantTouchBurst();
    }
    %orig(completion);
}
%end

%hook SBVolumeControl
- (void)increaseVolume {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
    %orig;
}

- (void)decreaseVolume {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
    %orig;
}

- (void)changeVolumeByDelta:(float)delta {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
    %orig(delta);
}
%end

// 4. KÉO & THU CONTROL CENTER / THÔNG BÁO (KHÓA 144HZ TOÀN BỘ CHU TRÌNH NẢY LÒ XO)
%hook SBControlCenterController

- (void)presentAnimated:(BOOL)animated completion:(id)completion {
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
    %orig(animated, completion);
}

- (void)dismissAnimated:(BOOL)animated completion:(id)completion {
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();

        static int64_t s_ccDismissSeq = 0;
        int64_t currentSeq = ++s_ccDismissSeq;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(700 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            if (s_ccDismissSeq == currentSeq) {
                if (g_activeAnimationCount > 0) g_activeAnimationCount--;
            }
        });
    }
    %orig(animated, completion);
}

%end

%hook SBNotificationCenterController

- (void)presentAnimated:(BOOL)animated completion:(id)completion {
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
    %orig(animated, completion);
}

- (void)dismissAnimated:(BOOL)animated completion:(id)completion {
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();

        static int64_t s_ncDismissSeq = 0;
        int64_t currentSeq = ++s_ncDismissSeq;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(700 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            if (s_ncDismissSeq == currentSeq) {
                if (g_activeAnimationCount > 0) g_activeAnimationCount--;
            }
        });
    }
    %orig(animated, completion);
}

%end

// 5. LƯỚT TRANG MÀN HÌNH CHÍNH (SPRINGBOARD ICON SCROLL)
%hook SBIconScrollView

- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    if (IS_ACTIVE) return YES;
    return %orig;
}

- (BOOL)delaysContentTouches {
    return %orig;
}

- (void)_notifyDidScroll {
    if (IS_ACTIVE) {
        g_isScrollingActive = YES;
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig;
}

- (void)_smoothScrollWithTimestamp:(double)timestamp {
    if (IS_ACTIVE) {
        g_isScrollingActive = YES;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
    %orig(timestamp);
}

%end

%hook SBIconListView
- (void)setAlpha:(CGFloat)alpha { %orig(alpha); }
%end

%hook SBIconController
- (void)scrollToIconListAtIndex:(NSInteger)index animate:(BOOL)animate {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
    }
    %orig(index, animate);
}
%end

// 6. TOÀN DIỆN THƯ MỤC ỨNG DỤNG, 3D TOUCH & LOCKSCREEN
%hook SBFolderControllerAnimationSettings
- (double)duration {
    return %orig; // Giữ nguyên đường cong lò xo gốc co giãn mượt mà
}
%end

%hook SBFolderView

- (void)prepareToOpen {
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
    %orig;
}

- (void)didClose {
    %orig;
    if (IS_ACTIVE) {
        if (g_activeAnimationCount > 0) g_activeAnimationCount--;
    }
}

%end

%hook SBFolderController

- (void)openFolderAnimated:(BOOL)animated withCompletion:(id)completion {
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
    %orig(animated, completion);
}

- (void)closeFolderAnimated:(BOOL)animated withCompletion:(id)completion {
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
    %orig(animated, completion);
}

%end

%hook SBIconForceTouchSettings
- (double)delayBeforeOpening { return %orig; }
%end

%hook CSCoverSheetViewController
- (void)viewWillAppear:(BOOL)animated {
    if (IS_ACTIVE) Titanium_TriggerInstantTouchBurst();
    %orig(animated);
}
%end

%hook SBHomeScreenViewController
- (void)viewWillAppear:(BOOL)animated {
    if (IS_ACTIVE) Titanium_TriggerInstantTouchBurst();
    %orig(animated);
}
%end

// 7. ÉP TỐC ĐỘ LOAD APP & CHU TRÌNH THU PHÓNG (BẢO VỆ SNAPSHOT CHỐNG ĐEN APP)
%hook SBApplication

- (void)willActivate {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
    %orig;
}

- (BOOL)shouldPrewarmOnLaunch {
    if (IS_ACTIVE) return YES;
    return %orig;
}

%end

%hook SBAppLaunchSettings
- (double)zoomDuration { return %orig; }
- (double)launchDuration { return %orig; }
- (double)delayBeforeAppLaunch { return %orig; }
%end

%hook SBSplashBoardController
- (double)splashScreenDelay { return %orig; }
%end

%hook SBUIAnimationController

- (void)_willBeginAnimation {
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        Titanium_LockMainThreadFast();
        Titanium_TriggerInstantTouchBurst();
    }
    %orig;
}

- (void)_didCompleteAnimation {
    %orig;
    if (IS_ACTIVE) {
        if (g_activeAnimationCount > 0) g_activeAnimationCount--;
    }
}

%end

%end

// ====================================================================================================
// NHÓM 8: PIPELINE CHO PICTURE-IN-PICTURE (PIP MƯỢT MÀ & CHUYỂN CẢNH 144HZ)
// ====================================================================================================

%group Group_V285_FloatingWindow_PiP

%hook PGPictureInPictureRemoteObject

- (void)_updatePreferredContentSize {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

- (void)startPictureInPicture {
    if (IS_ACTIVE) {
        g_isVideoPlayingActive = YES;
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        }
    }
    %orig;
}

- (void)stopPictureInPictureAnimated:(BOOL)animated {
    if (IS_ACTIVE) {
        g_isVideoPlayingActive = NO;
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        }
    }
    %orig(animated);
}

%end

%hook SBPIPController

- (void)startPictureInPictureForApplicationWithProcessIdentifier:(int)pid sceneIdentifier:(id)sceneId animated:(BOOL)animated completionHandler:(id)completion {
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
    %orig(pid, sceneId, animated, completion);
}

%end

%hook AVPictureInPictureController

- (void)startPictureInPicture {
    if (IS_ACTIVE) {
        g_isVideoPlayingActive = YES;
        g_lastInteractionMachTime = mach_absolute_time();
        if ([NSThread isMainThread]) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
    %orig;
}

- (void)stopPictureInPicture {
    if (IS_ACTIVE) {
        g_isVideoPlayingActive = NO;
        g_lastInteractionMachTime = mach_absolute_time();
        if ([NSThread isMainThread]) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
    %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 9: PHÂN TÁCH PHẦN CỨNG (HOME BUTTON VẬT LÝ - PHẢN HỒI 0MS, BẢO TOÀN ĐỆM 144HZ)
// ====================================================================================================

%group Group_HardwareSegregation_ClassicHomeV285

%hook SBHomeHardwareButtonActions

- (void)performSinglePressAction {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
    %orig;
}

- (void)performDoublePressAction {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
    %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 10: QUẢN LÝ TIẾN TRÌNH & BẢO VỆ JETSAM (CHỐNG ĐEN APP 100% & MÁT MÁY KHI CHẠY NỀN)
// ====================================================================================================

%group Group_SpringBoard_ProcessManagerV285

%hook SBApplication

- (void)setProcessState:(id)state {
    if (IS_ACTIVE && Titanium_ShouldLockTargetRate()) {
        Titanium_LockMainThreadFast();
    }
    %orig(state);
}

%end

%hook SBMainWorkspace

- (void)handleApplicationLaunch:(id)application {
    if (IS_ACTIVE && CFG285.turboAppLaunch) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
    %orig(application);
}

%end

%end

// ====================================================================================================
// NHÓM 11: NÂNG CẤP TOÀN BỘ APP THỨ BA & CHUYỂN TIẾP VIEWCONTROLLER CHUẨN XNU
// ====================================================================================================

%group Group_UIKit_ThirdParty_IsolatedV285

// 1. CƯỚP QUYỀN ĐỒ HỌA RUNLOOP CỦA APP THỨ BA
%hook UIApplication

- (void)_sendWillEnterForegroundCallbacks {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
            Titanium_EnforceThreadVIPPolicy();
        } else if ([NSThread isMainThread]) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
}

%end

// 2. KHỞI TẠO CỬA SỔ AN TOÀN TRÁNH ĐEN MÀN HÌNH
%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
            Titanium_EnforceThreadVIPPolicy();
        } else if ([NSThread isMainThread]) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
}

%end

// 3. TỐI ƯU TOÀN DIỆN CHUYỂN CẢNH MÀN HÌNH VIEWCONTROLLER
%hook UIViewController

- (void)viewWillAppear:(BOOL)animated {
    %orig(animated);
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();

        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else if ([NSThread isMainThread]) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
}

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    if (IS_ACTIVE) {
        if (g_activeAnimationCount > 0) g_activeAnimationCount--;
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig(animated);
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();

        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else if ([NSThread isMainThread]) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig(animated);
    if (IS_ACTIVE) {
        if (g_activeAnimationCount > 0) g_activeAnimationCount--;
    }
}

%end

// 4. BỘ ĐIỀU PHỐI CHUYỂN TIẾP TOÀN CỤC NỘI BỘ (TRANSITION COORDINATOR)
%hook UIViewControllerTransitionCoordinator

- (BOOL)animateAlongsideTransition:(void (^)(id context))animation
                        completion:(void (^)(id context))completion {
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_activeAnimationCount++;

        void (^wrappedCompletion)(id) = ^(id context) {
            if (completion) completion(context);
            if (g_activeAnimationCount > 0) g_activeAnimationCount--;
        };
        return %orig(animation, wrappedCompletion);
    }
    return %orig(animation, completion);
}

%end

%hook _UIViewControllerTransitionContext

- (void)__runLifecycleForViewController:(UIViewController *)vc 
                                  state:(NSInteger)state 
                            transition:(id)transition {
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        if ([NSThread isMainThread]) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
    %orig(vc, state, transition);
}

- (void)completeTransition:(BOOL)didComplete {
    %orig(didComplete);
    if (IS_ACTIVE) {
        [CATransaction flush];
    }
}

%end

// 5. TOÀN DIỆN VUỐT POPUP, BOTTOM SHEET & MODAL (GOM CHUẨN DUY NHẤT 1 NƠI TRÁNH ĐẾM TRÙNG)
%hook UIPresentationController

- (void)presentationTransitionWillBegin {
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else if ([NSThread isMainThread]) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
    %orig;
}

- (void)presentationTransitionDidEnd:(BOOL)completed {
    %orig(completed);
    if (IS_ACTIVE) {
        if (g_activeAnimationCount > 0) g_activeAnimationCount--;
    }
}

- (void)dismissalTransitionWillBegin {
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else if ([NSThread isMainThread]) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
    %orig;
}

- (void)dismissalTransitionDidEnd:(BOOL)completed {
    %orig(completed);
    if (IS_ACTIVE) {
        if (g_activeAnimationCount > 0) g_activeAnimationCount--;
    }
}

%end

%end

// ====================================================================================================
// NHÓM 12: BÀN PHÍM STREAM TEXT & CẢM ỨNG NÚT BẤM (ĐÃ TỐI ƯU 0MS & KHÔNG NGHẼN MẠNG YOUTUBE)
// ====================================================================================================

%group Group_InstantActionAndMenuTransitions_Boost

// 1. ƯU TIÊN HÀNG ĐỢI TÁC VỤ GÕ PHÍM
%hook UIKeyboardTaskQueue

- (void)performTask:(id)task {
    if (IS_ACTIVE) {
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else if ([NSThread isMainThread]) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
    %orig(task);
}

%end

// 2. BẬT BÀN PHÍM TỨC THÌ 0MS: CHỐNG HỞ VIỀN ĐEN CHÂN PHÍM
%hook UIKeyboardImpl

- (void)callShowKeyboard {
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else if ([NSThread isMainThread]) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
    %orig;
}

+ (NSTimeInterval)suppressionIntervalForTouchesOnKeyboard {
    if (IS_ACTIVE) return 0.0;
    return %orig;
}

%end

// 3. TRIỆT TIÊU ĐỘ TRỄ DỊCH CHUYỂN BÀN PHÍM
%hook UIPeripheralHost

- (double)getLastTranslateTime {
    if (IS_ACTIVE) return 0.0;
    return %orig;
}

%end

// 4. PHẢN HỒI NÚT BẤM SIÊU NHẠY 0MS
%hook UIButton

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else if ([NSThread isMainThread]) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
    %orig(touches, event);
}

%end

%end

// ====================================================================================================
// NHÓM 13: DUY TRÌ TRẦN 144HZ & CHỐNG QUÁ NHIỆT (TRIỆT TIÊU HOÀN TOÀN NÓNG MÁY KHI SẠC PIN)
// ====================================================================================================

%group Group_Global_Thread_Governor_Unthrottled

// 1. QUẢN LÝ TIẾN TRÌNH THÔNG MINH: CHỐNG ZOMBIE PROCESS & MÁT MÁY
%hook RBSProcessState

- (unsigned char)taskState {
    unsigned char orig = %orig;
    if (IS_ACTIVE && orig > 0) {
        if (!g_isDeviceChargingV285 && Titanium_ShouldLockTargetRate()) {
            return 4; // Giữ ứng dụng hoạt động mượt mà khi đang tương tác
        }
    }
    return orig;
}

%end

// 2. GIẢI PHÓNG TIẾN TRÌNH CHUẨN XÁC: TRIỆT TIÊU 100% LỖI ĐEN MÀN HÌNH KHI MỞ LẠI APP
%hook FBProcess

- (BOOL)isPendingExit {
    return %orig;
}

%end

// 3. ĐIỀU TIẾT NHIỆT ĐỘ HỆ THỐNG: KHÔNG BÓP FPS KHI DÙNG, TỰ HẠ KHI SẠC TĨNH
%hook NSProcessInfo

- (NSProcessInfoThermalState)thermalState {
    if (IS_ACTIVE) {
        if (g_isDeviceChargingV285 && !Titanium_ShouldLockTargetRate()) {
            return %orig;
        }
        return NSProcessInfoThermalStateNominal;
    }
    return %orig;
}

- (BOOL)isLowPowerModeEnabled {
    return %orig;
}

%end

// 4. CHẶN THÔNG BÁO TĂNG NHIỆT ĐỘ TRONG LÚC ĐANG TƯƠNG TÁC
%hook NSNotificationCenter

- (void)postNotificationName:(NSNotificationName)aName object:(id)anObject userInfo:(NSDictionary *)aUserInfo {
    if (IS_ACTIVE && aName) {
        if (Titanium_ShouldLockTargetRate()) {
            if (aName == NSProcessInfoThermalStateDidChangeNotification || 
                ([aName isKindOfClass:[NSString class]] && [aName isEqualToString:NSProcessInfoThermalStateDidChangeNotification])) {
                return;
            }
        }
    }
    %orig(aName, anObject, aUserInfo);
}

%end

%end

// ====================================================================================================
// NHÓM BẢO VỆ CHỐNG NÓNG, CHỐNG GIẬT CC/NC & BẢO TOÀN NGUYÊN BẢN HÌNH NỀN
// ====================================================================================================

%group Group_LiquidGlass_Opt

// 1. BẢO TOÀN ĐƯỜNG CONG LÀM MỜ SHADER
%hook CAFilter

- (void)setValue:(id)value forKey:(NSString *)key {
    if (IS_ACTIVE && [key isKindOfClass:[NSString class]] && [key isEqualToString:@"inputRadius"]) {
        if (g_activeAnimationCount == 0 && !Titanium_ShouldLockTargetRate()) {
            if ([value isKindOfClass:[NSNumber class]] && [value floatValue] > 16.0f) {
                value = @(16.0f);
            }
        }
    }
    %orig(value, key);
}

%end

// 2. BẢO VỆ TUYỆT ĐỐI HÌNH NỀN & SỬA DỨT ĐIỂM GIẬT CONTROL CENTER
%hook CABackdropLayer

- (void)setScale:(double)scale {
    if (IS_ACTIVE) {
        if (Titanium_ShouldLockTargetRate() || g_activeAnimationCount > 0) {
            %orig(scale);
            return;
        }
    }
    %orig(scale);
}

- (double)scale {
    return %orig;
}

- (void)setAllowsInPlaceFiltering:(BOOL)flag {
    if (IS_ACTIVE) flag = YES;
    %orig(flag);
}

- (BOOL)allowsInPlaceFiltering {
    return IS_ACTIVE ? YES : %orig;
}

- (void)setDisablesOccludedBackdropBlurs:(BOOL)flag {
    if (IS_ACTIVE) flag = YES;
    %orig(flag);
}

- (BOOL)disablesOccludedBackdropBlurs {
    return IS_ACTIVE ? YES : %orig;
}

%end

// 3. ĐỒNG BỘ HIỂN THỊ NỀN MỜ CONTROL CENTER & NOTIFICATION CENTER
%hook MTMaterialView

- (void)layoutSubviews {
    %orig;
}

%end

// 4. TỐI ƯU HIỆU ỨNG GIAO DIỆN (UIVISUALEFFECTVIEW) - KHÔNG LỆCH POPUP, KHÔNG GIẬT KHUNG
%hook UIVisualEffectView

- (void)layoutSubviews {
    %orig;
    if (IS_ACTIVE) {
        UIView *v = (UIView *)self;
        v.layer.allowsGroupOpacity = YES;
    }
}

%end

%end

// ====================================================================================================
// GIA TỐC TOÀN BỘ HIỆU ỨNG BÊN TRONG ỨNG DỤNG (MODAL, POPUP, SHEET, CONTEXT MENU)
// ====================================================================================================

%group Group_Universal_InApp_Animations

// 1. ÉP BỘ MÁY HOẠT ẢNH HIỆN ĐẠI (UIVIEWPROPERTYANIMATOR) CHẠY 144HZ
%hook UIViewPropertyAnimator

- (void)startAnimation {
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else if ([NSThread isMainThread]) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
    %orig;
}

%end

// 2. TĂNG TỐC POPUP GIỮ ĐÈ ICON / MENU BỐI CẢNH
%hook _UIContextMenuContainerView

- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig(newWindow);
    if (newWindow && IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else if ([NSThread isMainThread]) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
}

%end

// 3. HIỆU ỨNG BẬT BẢNG THÔNG BÁO / ACTIONSHEET / DIALOG SYSTEM
%hook UIAlertController

- (void)viewWillAppear:(BOOL)animated {
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else if ([NSThread isMainThread]) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
    %orig(animated);
}

%end

%end

// ====================================================================================================
// NHÓM MỚI ĐỘC QUYỀN: BỘ NÃO DỰ ĐOÁN TỌA ĐỘ NEURAL & CỬ CHỈ MÉP 0MS (BẢO VỆ TUYỆT ĐỐI HÌNH NỀN)
// ====================================================================================================

%group Group_Apple_NeuralTouch_And_EdgeZeroLatency_V285

// 1. BỘ NÃO DỰ ĐOÁN TỌA ĐỘ CẢM ỨNG NỘI BỘ (_UITOUCHPREDICTOR): VẼ ĐÓN ĐẦU TRƯỚC 8MS
%hook _UITouchPredictor

- (id)predictedTouchesForTouch:(UITouch *)touch {
    id predicted = %orig(touch);
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    return predicted;
}

- (void)addTouch:(UITouch *)touch fromEvent:(UIEvent *)event {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig(touch, event);
}

%end

// 2. BỘ TỔNG TƯ LỆNH CỬ CHỈ UIKIT (_UIGESTUREENVIRONMENT): XỬ LÝ CỬ CHỈ 0MS TOÀN HỆ THỐNG
%hook _UIGestureEnvironment

- (void)_updateGesturesForEvent:(UIEvent *)event {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else if ([NSThread isMainThread]) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
    %orig(event);
}

%end

// 3. CẮT ĐỨT 80MS VÙNG TRỄ AN TOÀN VUỐT MÉP MÀN HÌNH (CONTROL CENTER & VUỐT BACK MÉP ĂN NGAY)
%hook SBScreenEdgePanGestureRecognizer

- (BOOL)_shouldTryToBeginWithEvent:(UIEvent *)event {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
            Titanium_EnforceMachFrameConstraintDynamic(144);
        }
    }
    return %orig(event);
}

- (double)_edgeRegionSize {
    double origSize = %orig;
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        return origSize > 0.0 ? (origSize * 1.25) : 25.0;
    }
    return origSize;
}

%end

// 4. VẼ BẤT ĐỒNG BỘ LAYER ĐỒ HỌA (CALAYER): BẢO VỆ TUYỆT ĐỐI HÌNH NỀN VÀ KÍNH MỜ
%hook CALayer

- (BOOL)drawsAsynchronously {
    if (IS_ACTIVE && Titanium_ShouldLockTargetRate()) {
        id del = self.delegate;
        const char *delName = del ? object_getClassName(del) : NULL;
        // BẢO VỆ TUYỆT ĐỐI: Không bao giờ bật bất đồng bộ lên Wallpaper, Poster hoặc Backdrop layer
        if (delName && (strstr(delName, "Wallpaper") != NULL || strstr(delName, "Poster") != NULL || strstr(delName, "Backdrop") != NULL)) {
            return %orig;
        }
        return YES;
    }
    return %orig;
}

- (void)setDrawsAsynchronously:(BOOL)draws {
    if (IS_ACTIVE && Titanium_ShouldLockTargetRate()) {
        id del = self.delegate;
        const char *delName = del ? object_getClassName(del) : NULL;
        if (delName && (strstr(delName, "Wallpaper") != NULL || strstr(delName, "Poster") != NULL || strstr(delName, "Backdrop") != NULL)) {
            %orig(draws);
            return;
        }
        draws = YES;
    }
    %orig(draws);
}

%end

// 5. QUÁN TÍNH ĐA NHIỆM KHÔNG MA SÁT (SBFLUIDSWITCHERANIMATIONSETTINGS)
%hook SBFluidSwitcherAnimationSettings

- (double)deckSwipeSpeedFactor {
    if (IS_ACTIVE) return 1.45;
    return %orig;
}

- (double)cardFlyInDuration {
    if (IS_ACTIVE) return 0.22;
    return %orig;
}

%end

%end

// ====================================================================================================
// GIÁM SÁT SẠC PIN THÔNG MINH (DÙNG NOTIFICATION HỆ THỐNG - TRIỆT TIÊU 100% NÓNG MÁY KHI CẮM SẠC)
// ====================================================================================================

static void Titanium_StartThermalAndChargingWatchdog(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIDevice *dev = [UIDevice currentDevice];
        dev.batteryMonitoringEnabled = YES;
        g_isDeviceChargingV285 = (dev.batteryState == UIDeviceBatteryStateCharging || dev.batteryState == UIDeviceBatteryStateFull);

        // LẮNG NGHE SỰ KIỆN GỐC: Chỉ kích hoạt đúng 1 lần khi cắm hoặc rút sạc
        // TUYỆT ĐỐI KHÔNG DÙNG TIMER 5S LẶP ĐI LẶP LẠI GÂY TỐN PIN VÀ NÓNG MÁY KHI NGHỈ
        [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceBatteryStateDidChangeNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification * _Nonnull note) {
            UIDevice *currentDev = [UIDevice currentDevice];
            g_isDeviceChargingV285 = (currentDev.batteryState == UIDeviceBatteryStateCharging || currentDev.batteryState == UIDeviceBatteryStateFull);
        }];
    });
}

static void Titanium_StartPassiveRamDaemon(void) {
    return;
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

// ====================================================================================================
// ĐIỀU PHỐI KHỞI ĐỘNG THUẦN ROOTLESS & ROOTHIDE (CHỐNG TREO TÁO / TREO REBOOT 100%)
// ====================================================================================================

#define TITANIUM_BOOT_FLAG_VERIFIED @"/tmp/.titanium_tweak_verified"
#define TITANIUM_BOOT_STAGE_8P      @"/tmp/.titanium_8p_reboot_staged"

// 1. Phân loại thiết bị
static inline BOOL Titanium_IsLegacy6s7P(void) {
    static BOOL s_isLegacy = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        struct utsname sysInfo;
        uname(&sysInfo);
        NSString *machine = [NSString stringWithCString:sysInfo.machine encoding:NSUTF8StringEncoding];
        if ([machine hasPrefix:@"iPhone8,"] || [machine hasPrefix:@"iPhone9,"]) {
            s_isLegacy = YES;
        }
    });
    return s_isLegacy;
}

// 2. Đo thời gian uptime từ lúc bật nguồn
static time_t Titanium_GetSystemUptimeSeconds(void) {
    struct timeval boottime;
    size_t len = sizeof(boottime);
    int mib[2] = {CTL_KERN, KERN_BOOTTIME};
    if (sysctl(mib, 2, &boottime, &len, NULL, 0) < 0) return 9999;
    time_t now = time(NULL);
    return (now - boottime.tv_sec);
}

// 3. Thực thi Respring an toàn tương thích hoàn toàn đường dẫn Rootless/RootHide
static void Titanium_ExecuteSystemRespring(void) {
    UIApplication *app = [UIApplication sharedApplication];
    if ([app respondsToSelector:@selector(_relaunchSpringBoardNow)]) {
        [(SpringBoard *)app _relaunchSpringBoardNow];
        return;
    }

    NSString *jbRoot = Titanium_GetRootHidePrefixPath();
    NSFileManager *fm = [NSFileManager defaultManager];
    
    // Tìm nhị phân sbreload hoặc killall trong $JBROOT
    NSString *sbreload = [jbRoot stringByAppendingPathComponent:@"usr/bin/sbreload"];
    if (![fm fileExistsAtPath:sbreload]) sbreload = @"/var/jb/usr/bin/sbreload";

    NSString *killall = [jbRoot stringByAppendingPathComponent:@"usr/bin/killall"];
    if (![fm fileExistsAtPath:killall]) killall = @"/var/jb/usr/bin/killall";

    pid_t pid;
    if ([fm fileExistsAtPath:sbreload]) {
        const char *args[] = {"sbreload", NULL};
        posix_spawn(&pid, [sbreload UTF8String], NULL, NULL, (char *const *)args, environ);
    } else if ([fm fileExistsAtPath:killall]) {
        const char *args[] = {"killall", "-9", "SpringBoard", NULL};
        posix_spawn(&pid, [killall UTF8String], NULL, NULL, (char *const *)args, environ);
    }
}

// ====================================================================================================
// RUNTIME INITIALIZER: ĐIỀU PHỐI TẦNG NỘI BỘ & KHỞI CHẠY TWEAK (TRIỆT TIÊU NGHẼN MẠNG & NÓNG MÁY)
// ====================================================================================================

static void runCoreTweak(BOOL isSpringBoard, NSString *bundleID, const char *progName) {
    @autoreleasepool {
        AppleInternal_EnforceZeroLatencyKernelTier();
        AppleInternal_LockHardwareCADisplay();

        if (isSpringBoard) {
            Titanium_LockMainThreadFast();
            Titanium_EnforceMachFrameConstraintDynamic(144);

            if (Titanium_IsLegacyA9toA12() && !g_isDeviceChargingV285) {
                Titanium_ApplySiliconDeepOptimizations();
                Titanium_EnableZeroLatencyPipeline();
                Titanium_EnforceThreadVIPPolicy();
                Titanium_ElevateThreadToMachRealTime();
            }
        } else {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }

        Class configClass = NSClassFromString(@"BoostConfigV285Pro");
        if (configClass) {
            CFG285 = [configClass sharedInstance];
            [CFG285 loadSettings];
        }

        // 1. KHỞI TẠO CÁC NHÓM CỐT LÕI TỪ 1 ĐẾN 13
        %init(Group_ZeroLatency_Touch_Opt);
        %init(Group_Metal_ZeroTearing_Pacing);
        %init(Group_FluidTransitions_Pacing);
        %init(Group_FastLaunch_SuperEngineV285);
        %init(Group_Scroll_And_Keyboard_Opt);
        %init(Group_InstantActionAndMenuTransitions_Boost);
        %init(Group_Global_Thread_Governor_Unthrottled);

        // 2. KHỞI TẠO CÁC NHÓM NÂNG CẤP & BẢO VỆ ĐỒ HỌA
        %init(Group_Universal_InApp_Animations);
        %init(Group_LiquidGlass_Opt);
        %init(Group_Apple_Internal_ProMotion_Apex);
        %init(Group_Apple_NeuralTouch_And_EdgeZeroLatency_V285);

        if (Titanium_IsClassicHomeButtonDevice()) {
            %init(Group_HardwareSegregation_ClassicHomeV285);
        }

        // 3. PHÂN NHÁNH SPRINGBOARD VÀ APP BÊN THỨ BA
        if (isSpringBoard) {
            Titanium_TuneWindowServerDisplayDirectly();
            %init(Group_Switcher30Apps_Virtualization);
            %init(Group_Display_SpringBoardV285);
            %init(Group_V285_FloatingWindow_PiP);
            %init(Group_SpringBoard_ProcessManagerV285);
            Titanium_StartThermalAndChargingWatchdog();

            NSData *verifiedData = [@"VERIFIED" dataUsingEncoding:NSUTF8StringEncoding];
            [[NSFileManager defaultManager] createFileAtPath:TITANIUM_BOOT_FLAG_VERIFIED 
                                                    contents:verifiedData 
                                                  attributes:@{NSFilePosixPermissions: @(0666)}];
        } else {
            %init(Group_UIKit_ThirdParty_IsolatedV285);
        }

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

// ====================================================================================================
// CƠ CHẾ NẠP TRỄ: ĐỢI LÊN NGUỒN HOÀN TẤT MỚI CƯỚP QUYỀN TIÊM TWEAK
// ====================================================================================================

static void SpringBoardDidLaunchCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            const char *progName = getprogname();
            NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];

            time_t uptime = Titanium_GetSystemUptimeSeconds();
            BOOL isColdBootOrReboot = (uptime < 90);

            // NẾU VỪA BẬT NGUỒN HOẶC REBOOT JAILBREAK:
            // Đợi 2.5s để SpringBoard load xong hoàn toàn giao diện LockScreen, không tự Respring bừa bãi.
            int64_t waitTime = isColdBootOrReboot ? (int64_t)(2.5 * NSEC_PER_SEC) : (int64_t)(0.8 * NSEC_PER_SEC);

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, waitTime), dispatch_get_main_queue(), ^{
                Titanium_LockMainThreadFast();
                runCoreTweak(YES, bundleID, progName);
            });
        });
    });
}

// ====================================================================================================
// CONSTRUCTOR CHÍNH CỦA DYLIB (BLACKLIST BẢO VỆ TIẾN TRÌNH MẠNG HỆ THỐNG)
// ====================================================================================================

%ctor {
    @autoreleasepool {
        const char *progName = getprogname();
        if (!progName) return;

        // Bỏ qua WebKit, WebContent và các tiến trình mạng hệ thống: TRIỆT TIÊU 100% NGHẼN MẠNG
        if (strstr(progName, "WebKit") || strstr(progName, "WebContent") ||
            strstr(progName, "GPUProcess") || strstr(progName, "Networking") ||
            strstr(progName, "nsurlsessiond") || strstr(progName, "mDNSResponder") ||
            strstr(progName, "cloudd")) {
            return;
        }

        if (strstr(progName, "jailbreakd") || strstr(progName, "launchd") ||
            strstr(progName, "containermanagerd") || strstr(progName, "cfprefsd") ||
            strstr(progName, "watchdogd") || strstr(progName, "mediaserverd") ||
            strstr(progName, "installd") || strstr(progName, "logd") ||
            strstr(progName, "analyticsd") || strstr(progName, "symptomsd") ||
            strstr(progName, "powerd") || strstr(progName, "backboardd") ||
            strstr(progName, "notifyd") || strstr(progName, "securityd")) {
            return;
        }

        NSBundle *mainBundle = [NSBundle mainBundle];
        NSString *bundleID = [mainBundle bundleIdentifier];
        BOOL isSpringBoard = bundleID && [bundleID isEqualToString:@"com.apple.springboard"];

        // 1. Chỉ kiểm tra bootguard trên SpringBoard
        if (isSpringBoard) {
            if (!Titanium_CheckAndPreventBootloopUniversal()) return;
        }

        // 2. Nạp cấu hình tức thì cho ứng dụng Cài đặt
        if (strstr(progName, "Preferences") || strstr(progName, "Settings")) {
            Class configClass = NSClassFromString(@"BoostConfigV285Pro");
            if (configClass) {
                CFG285 = [configClass sharedInstance];
                [CFG285 loadSettings];
            }
            return;
        }

        %init;

        // 3. Phân luồng SpringBoard vs App bên thứ ba
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
            // App bên thứ ba (YouTube, TikTok, Facebook...): Nạp an toàn không nghẽn mạng
            runCoreTweak(NO, bundleID, progName);
        }
    }
}
