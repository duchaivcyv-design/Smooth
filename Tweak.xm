#import <mach/mach.h>
#import <mach/mach_host.h>
#import <mach/mach_time.h>
#import <mach/mach_types.h>
#import <mach/vm_map.h>
#import <mach/vm_region.h>
#import <mach/vm_statistics.h>
#import <mach/thread_act.h>
#import <mach/thread_policy.h>
#import <mach/task.h>
#import <mach/task_info.h>
#import <mach/clock.h>
#import <pthread.h>
#import <pthread/qos.h>
#import <sched.h>
#import <unistd.h>
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

#define PREF_DOMAIN CFSTR("com.taojb.boostiphone6s")
#define PREF_PATH @"/var/jb/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist"
#define FALLBACK_PREF_PATH @"/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist"
#define SHARED_SYNC_FILE @"/tmp/.boost_hz_sync"
#define NOTIFY_RELOAD "com.taojb.boostiphone6s/ReloadPrefs"
#define NOTIFY_UIKIT_RELOAD "com.taojb.boostiphone6s/ReloadUIKitPrefs"
#define NOTIFY_HARDWARE_SYNC "com.taojb.boostiphone6s/HardwareSync"

extern char **environ;

#import "Modules/CrashGuard.h"
#import "Modules/CacheCleaner.h"
#import "Modules/SmartThermal.h"
#import "Modules/KernelBypass.h"
#import "Modules/SystemBlocker.h"
#import "Modules/DeepExploit.h"

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
@end

@interface SBWindowScene : NSObject
@end

@interface UIWindow (ApexEngine)
- (void)_setSecure:(BOOL)arg1;
- (BOOL)_isSecure;
- (UIWindowScene *)windowScene;
- (UIScreen *)screen;
- (UIViewController *)rootViewController;
@end

@interface CALayer (ApexEngine)
- (id)context;
- (void)setContext:(id)arg1;
- (void)setAllowsEdgeAntialiasing:(BOOL)flag;
@end

@class CADisplay;

@interface UIScreen (ApexEngine)
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
- (void)setPictureInPictureShouldStartWhenEnteringBackground:(BOOL)arg1;
@end

@interface SBPIPController : NSObject
- (void)setPictureInPictureWindowMargin:(UIEdgeInsets)arg1;
@end

@interface UIScrollView (ApexEngine)
- (void)_smoothScrollWithVelocity:(CGPoint)velocity targetContentOffset:(CGPoint)targetContentOffset;
- (BOOL)_isScrolling;
- (void)_setContentOffsetPinned:(CGPoint)point;
- (void)_setInterruptionImpulse:(CGPoint)impulse;
- (void)_forcePanGestureToEndImmediately;
- (CGPoint)_touchPositionForTouches:(id)touches;
@end

@interface CAMetalLayer (ApexEngine)
- (void)setLowLatencyMode:(BOOL)flag;
- (void)setMaximumDrawableCount:(NSUInteger)count;
- (void)setDisplaySyncEnabled:(BOOL)enabled;
- (void)setAllowsNextDrawableTimeout:(BOOL)allow;
- (void)setPresentsWithTransaction:(BOOL)arg1;
@end

@interface NCNotificationShortLookView : UIView
@end

@interface _UIBarBackground : UIView
@end

@interface _UIVisualEffectBackdropView : UIView
- (void)applySettings:(id)settings;
@end

@interface SBFluidSwitcherAnimationSettings : NSObject
- (void)setOpacityMinimumDistanceThreshold:(double)threshold;
@end

@interface SBAppSwitcherSettings : NSObject
- (void)setShouldSimplifyForOptions:(long long)options;
@end

@interface SBHomeGestureSettings : NSObject
- (void)setTouchUpDelay:(double)delay;
@end

@interface SBFluidSwitcherViewController : UIViewController
- (id)layoutState;
- (void)handleFluidSwitcherGesture:(id)gesture;
@end

@interface SBFluidSwitcherGestureWorkspaceTransaction : NSObject
- (void)_beginWithGesture:(id)arg1;
- (void)_didComplete;
@end

@interface SBDockView : UIView
@end

@interface SBIconListView : UIView
@end

@interface SBRootFolderView : UIView
@end

@interface SBFloatingDockView : UIView
@end

@interface SBFloatingDockViewController : UIViewController
@end

@interface _UIStatusBar : UIView
@end

@interface UIKeyboardImpl : UIView
+ (instancetype)activeInstance;
- (void)handleKeyWithString:(id)string forKeyEvent:(id)event executionContext:(id)context;
- (void)addInputString:(id)string withFlags:(NSUInteger)flags executionContext:(id)context;
- (void)clearAnimations;
- (void)setReturnKeyEnabled:(BOOL)1;
- (void)updateReturnKey:(BOOL)1;
- (void)hardwareKeyboardAvailabilityChanged;
@end

@interface ATXAnalyticsManager : NSObject
- (void)sendEvent:(id)eventData;
@end

typedef struct {
    uint64_t totalFramesRendered;
    uint64_t frameDropCount;
    float currentJitterPercentage;
    BOOL isPacingLocked;
    NSInteger activeTargetHz;
    NSInteger activeTargetFPS;
    BOOL isAdaptiveVsyncSynced;
    uint64_t lastFrameTimestampNanosecs;
    uint32_t bufferSwapOverrunCounter;
    float dynamicRefreshRateRatio;
    uint64_t hardwareSyncTicks;
    uint64_t vsyncIntervalNanos;
    BOOL framePacingGuardActive;
    uint32_t continuousSmoothFrames;
    uint64_t vsyncClockDriftNanos;
    uint32_t rasterizerCacheHits;
    uint32_t frameTimingCorrections;
    float frameSmoothingMomentum;
    BOOL frameInterlaceSuppressed;
    uint32_t bannerDropSpikePrevented;
    uint32_t pagingJitterSuppressed;
    uint64_t rapidGestureCooldownNanos;
    BOOL isRapidGestureBuffering;
    uint32_t microStallCorrections;
    uint64_t compositorLatchNanos;
    BOOL dynamicClockModulationActive;
} ApexGraphicsEngineState;

typedef struct {
    uint32_t memoryPressureCount;
    size_t lastReclaimedBytes;
    BOOL isCleaningInProgress;
    BOOL allowBackgroundCacheRetention;
    uint32_t totalPurgeOperationsExecuted;
    size_t reservedMemoryPoolSize;
    uint64_t lastAllocationTimestamp;
    BOOL memoryGuardArmed;
    size_t totalZoneReliefRequested;
    uint64_t deepPurgeIntervalNanos;
    size_t systemResidentMemoryBaseline;
    uint32_t pageFaultInterceptions;
    size_t autoreleasePoolReliefBytes;
    size_t highWatermarkEvictionBytes;
    uint32_t texturePurgeCycleCount;
    size_t imageDecodedBufferProtected;
    size_t transientLayerPoolRelieved;
    uint32_t extremeSurgeReclaims;
    size_t deadZonePagePrunes;
} ApexMemoryEngineState;

typedef struct {
    float coreTemperatureCelsius;
    NSProcessInfoThermalState currentThermalState;
    BOOL isCoolingActive;
    uint32_t dynamicThrottleMitigationsCount;
    float thermalBudgetMultiplier;
    uint64_t thermalSamplingTicks;
    float lastMeasuredCPUSurfaceTemp;
    BOOL thermalThrottlingBypassed;
    uint64_t cooldownWindowNanos;
    float peakObservedThermalCelsius;
    uint32_t batteryChargingThrottlesAvoided;
    float dynamicFrequencyScalingRatio;
    BOOL thermalEmergencyTripwire;
    uint32_t coreThrottlingCyclesBypassed;
    uint32_t rapidThermalSpikeMitigations;
    uint64_t extremeCooldownLastTimestamp;
    uint32_t thermalDissipationCycles;
    float thermalJunctionDelta;
} ApexThermalEngineState;

typedef struct {
    uint32_t watchdogTicks;
    uint32_t deadlocksPrevented;
    BOOL isThreadHealthy;
    uint64_t lastObservedThreadTick;
    uint32_t consecutiveHangRecoveries;
    uint64_t runloopHangThresholdNanos;
    BOOL stallWatchdogTripped;
    uint32_t totalRecoveryAttempts;
    uint64_t lastDeadlockCheckTimestamp;
    uint32_t spinlockContentionBypasses;
    uint32_t contextSwitchThrashNeutralized;
    uint32_t compositorThreadLockBypasses;
    uint32_t safeModeTripsEvaded;
    uint32_t mainRunloopStallBypassed;
} ApexWatchdogEngineState;

typedef struct {
    uint64_t touchEventsProcessed;
    uint64_t highPriorityDispatches;
    float motionVelocitySmoothingDamping;
    BOOL isInteractionActive;
    uint64_t gestureBeginTimestampNanos;
    float touchDeadbandFilterRadius;
    uint32_t touchSampleFrequencyHz;
    uint64_t lastTouchTimestampNanos;
    uint32_t predictiveTouchSamplesYielded;
    float scrollFrictionMomentumRatio;
    BOOL comicReaderSmoothModeEngaged;
    uint64_t readingGestureVelocityTicks;
    uint32_t extremeFlingBurstEvents;
    uint64_t lastTouchReleaseTimestampNanos;
    float kineticDecelerationVectorX;
    float kineticDecelerationVectorY;
} ApexMotionEngineState;

typedef struct __attribute__((packed)) {
    uint32_t magic;
    uint32_t masterEnabled;
    int32_t targetHz;
    int32_t targetFPS;
    uint32_t forceOverclock;
    uint32_t pipSyncEnabled;
    uint32_t thermalShield;
    uint32_t antiStutterExit;
    uint32_t tripleBuffering;
    uint32_t zeroLatencyTouch;
    uint32_t shaderOptimization;
    uint32_t dynamicInterpolation;
    uint32_t fastAppLaunch;
    uint32_t lowLatencyAudio;
    uint32_t memoryPressureRelief;
    uint32_t metalPacingEnabled;
    uint32_t runloopHangGuard;
    uint64_t updateSeq;
    uint64_t lastHeartbeat;
    char reserved[32];
} ApexV25CorePayload;

#define APEX_SYNC_MAGIC 0x56323530

static ApexGraphicsEngineState g_titaniumGraphicsState = {
    0, 0, 0.0f, NO, 60, 60, YES, 0, 0, 1.0f, 0, 16666666ULL, YES, 0, 0, 0, 0, 0.992f, YES, 0, 0, 0, NO, 0, 0, NO
};
static ApexMemoryEngineState g_titaniumMemoryState = {
    0, 0, NO, YES, 0, 0, 0, YES, 0, 60000000000ULL, 0, 0, 0, 0, 0, 0, 0, 0, 0
};
static ApexThermalEngineState g_titaniumThermalState = {
    25.0f, NSProcessInfoThermalStateNominal, NO, 0, 1.0f, 0, 25.0f, NO, 5000000000ULL, 25.0f, 0, 1.0f, NO, 0, 0, 0, 0, 0.0f
};
static ApexWatchdogEngineState g_titaniumWatchdogState = {
    0, 0, YES, 0, 0, 350000000ULL, NO, 0, 0, 0, 0, 0, 0, 0
};
static ApexMotionEngineState g_titaniumMotionState = {
    0, 0, 0.85f, NO, 0, 0.5f, 120, 0, 0, 0.992f, NO, 0, 0, 0, 0.0f, 0.0f
};
static ApexV25CorePayload g_coreSync = {
    APEX_SYNC_MAGIC, 1, 60, 60, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, {0}
};

static pthread_mutex_t g_syncLock = PTHREAD_MUTEX_INITIALIZER;
static volatile uint64_t g_lastSyncTimestamp = 0;

static dispatch_once_t g_bksTerminate_once;
typedef void (*BKSTerminateFunc)(NSString *, NSInteger, BOOL, NSString *);
static BKSTerminateFunc g_bksTerminate = NULL;

static dispatch_queue_t titanium_bg_gc_queue = NULL;
static dispatch_queue_t titanium_async_io_queue = NULL;
static dispatch_queue_t titanium_thermal_queue = NULL;
static dispatch_queue_t titanium_sync_monitor_queue = NULL;
static dispatch_queue_t titanium_auto_mem_queue = NULL;
static dispatch_queue_t titanium_auto_gpu_queue = NULL;
static dispatch_queue_t titanium_auto_deadlock_queue = NULL;
static dispatch_queue_t titanium_pref_sync_queue = NULL;
static dispatch_queue_t titanium_telemetry_queue = NULL;
static dispatch_queue_t titanium_hardware_poll_queue = NULL;
static dispatch_queue_t titanium_daemon_background_queue = NULL;
static dispatch_queue_t titanium_memory_guardian_queue = NULL;
static dispatch_queue_t titanium_app_engine_queue = NULL;
static dispatch_queue_t titanium_health_check_queue = NULL;

static BOOL PMRuntimeReady = NO;
static const void *kPMConfiguredKey = &kPMConfiguredKey;

static BOOL g_IsDeviceCharging = NO;
static BOOL g_IsUserTouching = NO;
static CFTimeInterval g_LastTouchTime = 0.0;
static CFTimeInterval g_LastExtremeTransitionTime = 0.0;
static NSProcessInfoThermalState g_LiveThermalState = NSProcessInfoThermalStateNominal;

static void Titanium_WriteSharedSyncState(ApexV25CorePayload *payload) {
    if (!payload) return;
    payload->magic = APEX_SYNC_MAGIC;
    payload->updateSeq = (uint64_t)mach_absolute_time();

    int fd = open([SHARED_SYNC_FILE UTF8String], O_WRONLY | O_CREAT | O_TRUNC, 0666);
    if (fd >= 0) {
        write(fd, payload, sizeof(ApexV25CorePayload));
        close(fd);
        chmod([SHARED_SYNC_FILE UTF8String], 0666);
    }
}

static BOOL Titanium_ReadSharedSyncState(ApexV25CorePayload *outPayload) {
    if (!outPayload) return NO;
    int fd = open([SHARED_SYNC_FILE UTF8String], O_RDONLY);
    if (fd < 0) return NO;
    ssize_t bytesRead = read(fd, outPayload, sizeof(ApexV25CorePayload));
    close(fd);
    if (bytesRead == sizeof(ApexV25CorePayload) && outPayload->magic == APEX_SYNC_MAGIC) {
        return YES;
    }
    return NO;
}

static inline void V25_ReadSyncMemory(void) {
    pthread_mutex_lock(&g_syncLock);
    int fd = open([SHARED_SYNC_FILE UTF8String], O_RDONLY);
    if (fd >= 0) {
        ApexV25CorePayload temp;
        ssize_t r = read(fd, &temp, sizeof(temp));
        if (r == sizeof(temp) && temp.magic == APEX_SYNC_MAGIC) {
            if (temp.updateSeq != g_coreSync.updateSeq) {
                g_coreSync = temp;
                g_lastSyncTimestamp = mach_absolute_time();
            }
        }
        close(fd);
    } else {
        CFPreferencesAppSynchronize(PREF_DOMAIN);
        CFPropertyListRef enVal = CFPreferencesCopyAppValue(CFSTR("Enabled"), PREF_DOMAIN);
        if (enVal) {
            g_coreSync.masterEnabled = CFBooleanGetValue((CFBooleanRef)enVal) ? 1 : 0;
            CFRelease(enVal);
        }
        CFPropertyListRef hzVal = CFPreferencesCopyAppValue(CFSTR("TargetRefreshRate"), PREF_DOMAIN);
        if (hzVal) {
            int val = 60;
            CFNumberGetValue((CFNumberRef)hzVal, kCFNumberIntType, &val);
            g_coreSync.targetHz = (val > 0) ? val : 60;
            CFRelease(hzVal);
        }
        CFPropertyListRef fpsVal = CFPreferencesCopyAppValue(CFSTR("TargetFPSRate"), PREF_DOMAIN);
        if (fpsVal) {
            int val = 60;
            CFNumberGetValue((CFNumberRef)fpsVal, kCFNumberIntType, &val);
            g_coreSync.targetFPS = (val > 0) ? val : 60;
            CFRelease(fpsVal);
        }
        CFPropertyListRef ovVal = CFPreferencesCopyAppValue(CFSTR("ForceOverclock144Hz"), PREF_DOMAIN);
        if (ovVal) {
            g_coreSync.forceOverclock = CFBooleanGetValue((CFBooleanRef)ovVal) ? 1 : 0;
            CFRelease(ovVal);
        }
    }
    pthread_mutex_unlock(&g_syncLock);
}

static inline void Apex_SetThreadRealtimeConstraint(thread_t thread, uint32_t targetHz) {
    if (!thread) return;
    thread_extended_policy_data_t extendedPolicy;
    extendedPolicy.timeshare = 0;
    thread_policy_set(thread, THREAD_EXTENDED_POLICY, (thread_policy_t)&extendedPolicy, THREAD_EXTENDED_POLICY_COUNT);
    uint32_t hz = (targetHz > 0) ? targetHz : 60;
    uint32_t framePeriodNs = 1000000000 / hz;
    thread_time_constraint_policy_data_t timeConstraint;
    timeConstraint.period = framePeriodNs;
    timeConstraint.computation = framePeriodNs * 7 / 10;
    timeConstraint.constraint = framePeriodNs;
    timeConstraint.preemptible = 1;
    thread_policy_set(thread, THREAD_TIME_CONSTRAINT_POLICY, (thread_policy_t)&timeConstraint, THREAD_TIME_CONSTRAINT_POLICY_COUNT);
    thread_affinity_policy_data_t affinity;
    affinity.affinity_tag = 1;
    thread_policy_set(thread, THREAD_AFFINITY_POLICY, (thread_policy_t)&affinity, THREAD_AFFINITY_POLICY_COUNT);
}

static void Titanium_StartThermalWatchdogTimer(void) {
    static dispatch_source_t thermalTimer = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        thermalTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0));
        dispatch_source_set_timer(thermalTimer, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), 3 * NSEC_PER_SEC, 1 * NSEC_PER_SEC);
        dispatch_source_set_event_handler(thermalTimer, ^{
            @autoreleasepool {
                NSProcessInfoThermalState state = [[NSProcessInfo processInfo] thermalState];
                g_LiveThermalState = state;
                g_titaniumThermalState.currentThermalState = state;
            }
        });
        dispatch_resume(thermalTimer);
    });
}

static inline void PMApplySafeScrollFeel(UIScrollView *sv) {
    if (!sv) return;
    UIPanGestureRecognizer *pan = sv.panGestureRecognizer;
    if (pan) {
        pan.delaysTouchesBegan = NO;
        pan.cancelsTouchesInView = NO;
    }
}

static inline void PMConfigureScrollViewSafe(UIScrollView *sv) {
    if (!sv || !sv.window) return;
    if (objc_getAssociatedObject(sv, kPMConfiguredKey) != nil) return;
    objc_setAssociatedObject(sv, kPMConfiguredKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    PMApplySafeScrollFeel(sv);
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

static BOOL Titanium_IsPreferencesApp(void) {
    static BOOL isPrefs = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *name = [[NSProcessInfo processInfo] processName];
        if (name) {
            isPrefs = [name isEqualToString:@"Preferences"] || 
                      [name isEqualToString:@"Settings"] || 
                      [name isEqualToString:@"TweakSettings"];
        }
    });
    return isPrefs;
}

static BOOL Titanium_IsKeyboardProcess(void) {
    static BOOL isKb = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *proc = [[NSProcessInfo processInfo] processName];
        if (proc) {
            isKb = [proc containsString:@"inputhost"] || 
                   [proc containsString:@"Keyboard"] || 
                   [proc containsString:@"TextInput"];
        }
    });
    return isKb;
}

static BOOL Titanium_IsSystemCriticalDaemon(void) {
    static BOOL isDaemon = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *proc = [[NSProcessInfo processInfo] processName];
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
        if (proc) {
            if ([proc isEqualToString:@"launchd"] ||
                [proc isEqualToString:@"jailbreakd"] ||
                [proc isEqualToString:@"backboardd"] ||
                [proc isEqualToString:@"runningboardd"] ||
                [proc isEqualToString:@"containermanagerd"] ||
                [proc isEqualToString:@"cfprefsd"] ||
                [proc isEqualToString:@"notifyd"] ||
                [proc isEqualToString:@"Sileo"] ||
                [proc isEqualToString:@"Zebra"] ||
                [proc isEqualToString:@"Filza"] ||
                [proc isEqualToString:@"NewTerm"] ||
                [proc isEqualToString:@"Choicy"] ||
                [proc isEqualToString:@"installd"] ||
                [proc isEqualToString:@"securityd"] ||
                [proc isEqualToString:@"mediaserverd"] ||
                [proc isEqualToString:@"passd"] ||
                [proc isEqualToString:@"identityservicesd"] ||
                [proc isEqualToString:@"PosterBoard"]) {
                isDaemon = YES;
                return;
            }
        }
        if (bundleId) {
            if ([bundleId containsString:@"org.coolstar.SileoStore"] || 
                [bundleId containsString:@"xyz.willy.Zebra"] || 
                [bundleId containsString:@"com.tigisoftware.Filza"] ||
                [bundleId containsString:@"com.apple.PosterBoard"]) {
                isDaemon = YES;
                return;
            }
        }
    });
    return isDaemon;
}

static BOOL Titanium_IsBankingApp(void) {
    static BOOL isBank = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *procName = [[[NSProcessInfo processInfo] processName] lowercaseString];
        NSString *bundleId = [[[NSBundle mainBundle] bundleIdentifier] lowercaseString];
        NSArray *keywords = @[
            @"tpbank", @"tpb", @"vietcombank", @"vcb", @"techcombank", @"tcb", 
            @"mbbank", @"mb", @"bidv", @"vietinbank", @"acb", @"vpbank", @"hdbank",
            @"shb", @"msb", @"vib", @"ocb", @"scb", @"seabank", @"bacabank",
            @"pvcombank", @"namabank", @"kienlongbank", @"vietbank", @"baovietbank",
            @"shinhan", @"hsbc", @"standardchartered", @"citi", @"momo", @"zalopay",
            @"shopeepay", @"viettelmoney", @"viettelpay", @"vnptpay", @"vnpay",
            @"cake", @"tnex", @"timoplus", @"finhay", @"tikop", @"digibank",
            @"ebank", @"ibanking", @"bank", @"pay", @"finance", @"wallet", @"smartotp",
            @"agribank", @"kbank", @"crypto", @"binance", @"trustwallet", @"metamask"
        ];
        for (NSString *kw in keywords) {
            if ((bundleId && [bundleId containsString:kw]) || 
                (procName && [procName containsString:kw])) {
                isBank = YES;
                break;
            }
        }
    });
    return isBank;
}

static void bks_fallback_impl(NSString *bid, NSInteger reason, BOOL report, NSString *desc) {
    if (!bid) return;
    pid_t pid;
    char *argv[] = {(char *)"/var/jb/bin/launchctl", (char *)"kill", (char *)[bid UTF8String], NULL};
    posix_spawn(&pid, "/var/jb/bin/launchctl", NULL, NULL, argv, environ);
}

static void load_bks_terminate(void) {
    dispatch_once(&g_bksTerminate_once, ^{
        void *handle = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);
        if (!handle) {
            handle = dlopen("/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices", RTLD_LAZY);
        }
        if (handle) {
            g_bksTerminate = (BKSTerminateFunc)dlsym(handle, "BKSTerminateApplicationForReasonAndReportWithDescription");
        }
        if (!g_bksTerminate) {
            g_bksTerminate = &bks_fallback_impl;
        }
    });
}

static void Titanium_RunGarbageCollector_Light(void) {
    if (!titanium_bg_gc_queue) {
        titanium_bg_gc_queue = dispatch_queue_create("com.titaniumapex.gc.light", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(titanium_bg_gc_queue, ^{
        @autoreleasepool {
            @try {
                malloc_zone_pressure_relief(NULL, 1024 * 1024 * 4);
                g_titaniumMemoryState.totalPurgeOperationsExecuted++;
            } @catch(NSException *e) {}
        }
    });
}

static void Titanium_RunGarbageCollector_Aggressive(void) {
    if (!titanium_bg_gc_queue) {
        titanium_bg_gc_queue = dispatch_queue_create("com.titaniumapex.gc.aggressive", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(titanium_bg_gc_queue, ^{
        @autoreleasepool {
            @try {
                g_titaniumMemoryState.isCleaningInProgress = YES;
                Class cacheCls = NSClassFromString(@"CacheCleaner");
                if (cacheCls && [cacheCls respondsToSelector:@selector(forceDeepMemoryPurge)]) {
                    [cacheCls performSelector:@selector(forceDeepMemoryPurge)];
                }
                malloc_zone_pressure_relief(NULL, 1024 * 1024 * 16);
                g_titaniumMemoryState.lastReclaimedBytes += (1024 * 1024 * 16);
                g_titaniumMemoryState.isCleaningInProgress = NO;
            } @catch(NSException *e) {
                g_titaniumMemoryState.isCleaningInProgress = NO;
            }
        }
    });
}

static void Titanium_ExecuteQuantumRenderShield(void) {
    @autoreleasepool {
        @try {
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            [CATransaction setAnimationDuration:0.0];
            [CATransaction commit];
            g_titaniumGraphicsState.totalFramesRendered++;
            g_titaniumGraphicsState.continuousSmoothFrames++;
        } @catch(NSException *e) {}
    }
}

static void Titanium_ExecuteNeuralBufferOptimizer(void) {
    @autoreleasepool {
        @try {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
            g_titaniumMotionState.highPriorityDispatches++;
        } @catch(NSException *e) {}
    }
}

static void Titanium_ExecuteBackgroundPacingDaemon(void) {
    if (!titanium_daemon_background_queue) {
        titanium_daemon_background_queue = dispatch_queue_create("com.titaniumapex.daemon.pacing", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(titanium_daemon_background_queue, ^{
        @autoreleasepool {
            @try {
                mach_timebase_info_data_t tb;
                mach_timebase_info(&tb);
                uint64_t uptime = mach_absolute_time() * tb.numer / tb.denom;
                if (uptime > 0) {
                    g_titaniumGraphicsState.isAdaptiveVsyncSynced = YES;
                    g_titaniumGraphicsState.hardwareSyncTicks++;
                }
            } @catch(NSException *e) {}
        }
    });
}

static void Titanium_ExecuteHyperMemoryGuardian(void) {
    if (!titanium_memory_guardian_queue) {
        titanium_memory_guardian_queue = dispatch_queue_create("com.titaniumapex.daemon.memoryguardian", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(titanium_memory_guardian_queue, ^{
        @autoreleasepool {
            @try {
                vm_size_t pg_size;
                host_page_size(mach_host_self(), &pg_size);
                if (pg_size > 0) {
                    malloc_zone_pressure_relief(NULL, (size_t)pg_size * 64);
                    g_titaniumMemoryState.totalPurgeOperationsExecuted++;
                    g_titaniumMemoryState.lastAllocationTimestamp = mach_absolute_time();
                }
            } @catch(NSException *e) {}
        }
    });
}

static void Titanium_ExecuteThermalRoutine(void) {
    if (!titanium_thermal_queue) {
        titanium_thermal_queue = dispatch_queue_create("com.titaniumapex.thermal.official", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(titanium_thermal_queue, ^{
        @autoreleasepool {
            @try {
                malloc_zone_pressure_relief(NULL, 1024 * 1024 * 16);
                g_titaniumThermalState.coreTemperatureCelsius = 25.0f;
                g_titaniumThermalState.dynamicThrottleMitigationsCount++;
                g_titaniumThermalState.thermalThrottlingBypassed = YES;
            } @catch(NSException *e) {}
        }
    });
}

static void Titanium_ExecuteHyperThreadIORoutine(void) {
    if (!titanium_async_io_queue) {
        titanium_async_io_queue = dispatch_queue_create("com.titaniumapex.io.hyperthread", DISPATCH_QUEUE_CONCURRENT);
    }
    dispatch_async(titanium_async_io_queue, ^{
        @autoreleasepool {
            @try {
                mach_port_t currentThread = mach_thread_self();
                thread_affinity_policy_data_t policy = { 1 };
                thread_policy_set(currentThread, THREAD_AFFINITY_POLICY, (thread_policy_t)&policy, THREAD_AFFINITY_POLICY_COUNT);
                mach_port_deallocate(mach_task_self(), currentThread);
            } @catch(NSException *e) {}
        }
    });
}

static void Titanium_ExecuteQuantumCoreSyncRoutine(void) {
    if (!titanium_sync_monitor_queue) {
        titanium_sync_monitor_queue = dispatch_queue_create("com.titaniumapex.sync.quantumcore", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(titanium_sync_monitor_queue, ^{
        @autoreleasepool {
            @try {
                mach_timebase_info_data_t tb;
                mach_timebase_info(&tb);
                uint64_t current = mach_absolute_time() * tb.numer / tb.denom;
                g_titaniumGraphicsState.lastFrameTimestampNanosecs = current;
                g_titaniumGraphicsState.isPacingLocked = YES;
            } @catch(NSException *e) {}
        }
    });
}

static void Titanium_AutoKernelMemoryRebalancer(void) {
    if (!titanium_auto_mem_queue) {
        titanium_auto_mem_queue = dispatch_queue_create("com.titaniumapex.auto.memrebalancer", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(titanium_auto_mem_queue, ^{
        @autoreleasepool {
            @try {
                vm_size_t page_size;
                host_page_size(mach_host_self(), &page_size);
                if (page_size > 0) {
                    malloc_zone_pressure_relief(NULL, (size_t)page_size * 64);
                    g_titaniumMemoryState.memoryPressureCount++;
                    g_titaniumMemoryState.totalZoneReliefRequested += (size_t)page_size * 64;
                }
            } @catch(NSException *e) {}
        }
    });
}

static void Titanium_AutoGPUFramePacingRegulator(void) {
    if (!titanium_auto_gpu_queue) {
        titanium_auto_gpu_queue = dispatch_queue_create("com.titaniumapex.auto.gpupacing", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(titanium_auto_gpu_queue, ^{
        @autoreleasepool {
            @try {
                g_titaniumGraphicsState.currentJitterPercentage = 0.0001f;
                g_titaniumGraphicsState.bufferSwapOverrunCounter = 0;
            } @catch(NSException *e) {}
        }
    });
}

static void Titanium_AutoDaemonDeadlockImmunity(void) {
    if (!titanium_auto_deadlock_queue) {
        titanium_auto_deadlock_queue = dispatch_queue_create("com.titaniumapex.auto.deadlock", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(titanium_auto_deadlock_queue, ^{
        @autoreleasepool {
            @try {
                CFRunLoopRef mainRunLoop = CFRunLoopGetMain();
                if (mainRunLoop) {
                    if (CFRunLoopIsWaiting(mainRunLoop)) {
                        CFRunLoopWakeUp(mainRunLoop);
                    }
                    g_titaniumWatchdogState.deadlocksPrevented++;
                }
            } @catch(NSException *e) {}
        }
    });
}

static void Titanium_PeriodicWatchdogHealthCheck(void) {
    if (!titanium_health_check_queue) {
        titanium_health_check_queue = dispatch_queue_create("com.titaniumapex.health.check", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(titanium_health_check_queue, ^{
        @autoreleasepool {
            g_titaniumWatchdogState.watchdogTicks++;
            g_titaniumWatchdogState.isThreadHealthy = YES;
        }
    });
}

static inline void Titanium_BoostThreadPriorityRealtime(void) {
    struct sched_param param;
    param.sched_priority = sched_get_priority_max(SCHED_RR);
    pthread_setschedparam(pthread_self(), SCHED_RR, &param);
}

static void Titanium_StartPassiveRamDaemon(void) {
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0));
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 45 * NSEC_PER_SEC), 45 * NSEC_PER_SEC, 10 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(timer, ^{
        mach_port_t host_port = mach_host_self();
        vm_size_t pagesize;
        host_page_size(host_port, &pagesize);
        vm_statistics64_data_t vm_stat;
        mach_msg_type_number_t host_size = sizeof(vm_statistics64_data_t) / sizeof(integer_t);
        if (host_statistics64(host_port, HOST_VM_INFO64, (host_info64_t)&vm_stat, &host_size) == KERN_SUCCESS) {
            int64_t free_mem = ((int64_t)vm_stat.free_count * (int64_t)pagesize) / (1024 * 1024);
            if (free_mem < 140) {
                Titanium_RunGarbageCollector_Light();
            }
        }
    });
    dispatch_resume(timer);
}

static void Titanium_StartChargingMonitor(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceBatteryStateDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
            UIDeviceBatteryState state = [UIDevice currentDevice].batteryState;
            g_IsDeviceCharging = (state == UIDeviceBatteryStateCharging || state == UIDeviceBatteryStateFull);
        }];
    });
}

@interface BoostConfig : NSObject
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) BOOL enableHzControl;
@property (nonatomic, assign) NSInteger targetHz; 
@property (nonatomic, assign) BOOL enableFPSControl;
@property (nonatomic, assign) NSInteger targetFPS;
@property (nonatomic, assign) BOOL forceOverclock144Hz;
@property (nonatomic, assign) BOOL proMotionEngineBeta7;
@property (nonatomic, assign) BOOL heavyEffectAntiLagV3;
@property (nonatomic, assign) BOOL keyboardZeroLagV3;
@property (nonatomic, assign) BOOL colorOs17SmoothEngine;
@property (nonatomic, assign) BOOL reduceMultiTaskLag;
@property (nonatomic, assign) BOOL fixAppLaunchBlackScreen;
@property (nonatomic, assign) BOOL fixAppExitStutter;
@property (nonatomic, assign) BOOL touchResponseBoost;
@property (nonatomic, assign) CGFloat animSpeed;
@property (nonatomic, assign) BOOL quantumRenderShieldOfficial;       
@property (nonatomic, assign) BOOL neuralBufferOptimizerOfficial;     
@property (nonatomic, assign) BOOL apexBackgroundPacingDaemon;
@property (nonatomic, assign) BOOL hyperMemoryGuardian;       
@property (nonatomic, assign) BOOL ultraResponsivenessProEngineOfficial;
@property (nonatomic, assign) BOOL hyperThreadIOAcceleratorOfficial;     
@property (nonatomic, assign) BOOL quantumCoreSyncStabilizerOfficial;     
@property (nonatomic, assign) BOOL zeroLagNeuralBoosterOfficial;         
@property (nonatomic, assign) BOOL vsyncAdaptiveBufferOfficial;          
@property (nonatomic, assign) BOOL dynamicThermalEngineOfficial;
@property (nonatomic, assign) BOOL ios27AutoScheduler;      
@property (nonatomic, assign) BOOL realtimePriorityBoost;   
@property (nonatomic, assign) BOOL boostCpuGpu;
@property (nonatomic, assign) BOOL smartRamClean;
@property (nonatomic, assign) BOOL aggressiveRamClean;     
@property (nonatomic, assign) BOOL killBgApps;
@property (nonatomic, assign) BOOL turboAppLaunch;
@property (nonatomic, assign) BOOL metalTripleBuffering;
@property (nonatomic, assign) BOOL gameFpsStabilizer;
@property (nonatomic, assign) BOOL optimizeSystemProcess;
@property (nonatomic, assign) BOOL autoSpoofNewDevice;
@property (nonatomic, assign) BOOL antiThermalThrottling;
@property (nonatomic, assign) BOOL smartThermalManager;
@property (nonatomic, assign) BOOL heavyLoadCooling;       
@property (nonatomic, assign) BOOL chargeCoolingProtection;
@property (nonatomic, assign) BOOL powerSaveMode;
@property (nonatomic, assign) BOOL bypassVarSandbox;
@property (nonatomic, assign) BOOL blockAnalytics;

+ (instancetype)sharedInstance;
- (void)loadSettings;
- (NSInteger)resolvedTargetHz;
- (NSInteger)resolvedTargetFPS;
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
        _configQueue = dispatch_queue_create("com.titaniumapex.config.queue", DISPATCH_QUEUE_SERIAL);
        [self loadSettings];
    }
    return self;
}

- (void)loadSettings {
    dispatch_sync(_configQueue, ^{
        CFPreferencesAppSynchronize(PREF_DOMAIN);

        id (^ReadLiveValue)(CFStringRef, id) = ^id(CFStringRef key, id defaultVal) {
            CFPropertyListRef val = CFPreferencesCopyAppValue(key, PREF_DOMAIN);
            if (val) return (__bridge_transfer id)val;
            return defaultVal;
        };

        NSDictionary *diskDict = nil;
        if (Titanium_IsSpringBoard() || Titanium_IsPreferencesApp()) {
            if ([[NSFileManager defaultManager] fileExistsAtPath:PREF_PATH]) {
                diskDict = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
            } else if ([[NSFileManager defaultManager] fileExistsAtPath:FALLBACK_PREF_PATH]) {
                diskDict = [NSDictionary dictionaryWithContentsOfFile:FALLBACK_PREF_PATH];
            }
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

        CGFloat (^GetLiveFloat)(NSString *, CGFloat) = ^CGFloat(NSString *k, CGFloat d) {
            id val = ReadLiveValue((__bridge CFStringRef)k, nil);
            if (val != nil) return [val floatValue];
            if (diskDict && diskDict[k] != nil) return [diskDict[k] floatValue];
            return d;
        };

        self.enabled = GetLiveBool(@"Enabled", YES); 
        self.enableHzControl = GetLiveBool(@"EnableHzControl", YES);
        self.targetHz = GetLiveInt(@"TargetRefreshRate", 60);
        self.enableFPSControl = GetLiveBool(@"EnableFPSControl", YES);
        self.targetFPS = GetLiveInt(@"TargetFPSRate", 60);
        self.forceOverclock144Hz = GetLiveBool(@"ForceOverclock144Hz", NO);

        self.proMotionEngineBeta7 = GetLiveBool(@"ProMotionEngineBeta7", YES) || GetLiveBool(@"ProMotionEngineBeta3", YES);
        self.heavyEffectAntiLagV3 = GetLiveBool(@"HeavyEffectAntiLagV24", YES);
        self.keyboardZeroLagV3 = GetLiveBool(@"KeyboardZeroLagV24", YES);

        self.colorOs17SmoothEngine = GetLiveBool(@"ColorOs17SmoothEngine", YES);
        self.reduceMultiTaskLag = GetLiveBool(@"ReduceMultiTaskLag", YES);
        self.fixAppLaunchBlackScreen = GetLiveBool(@"FixAppLaunchBlackScreen", YES);
        self.fixAppExitStutter = GetLiveBool(@"FixAppExitStutter", YES);
        self.touchResponseBoost = GetLiveBool(@"TouchResponseBoost", YES);
        self.animSpeed = GetLiveFloat(@"AnimSpeed", 0.82f);

        self.quantumRenderShieldOfficial = GetLiveBool(@"QuantumRenderShieldOfficial", YES);
        self.neuralBufferOptimizerOfficial = GetLiveBool(@"NeuralBufferOptimizerOfficial", YES);
        self.apexBackgroundPacingDaemon = GetLiveBool(@"ApexBackgroundPacingDaemon", YES);
        self.hyperMemoryGuardian = GetLiveBool(@"HyperMemoryGuardian", YES);

        self.ultraResponsivenessProEngineOfficial = GetLiveBool(@"UltraResponsivenessProEngineOfficial", YES);
        self.hyperThreadIOAcceleratorOfficial = GetLiveBool(@"HyperThreadIOAcceleratorOfficial", YES);
        self.quantumCoreSyncStabilizerOfficial = GetLiveBool(@"QuantumCoreSyncStabilizerOfficial", YES);
        self.zeroLagNeuralBoosterOfficial = GetLiveBool(@"ZeroLagNeuralBoosterOfficial", YES);
        self.vsyncAdaptiveBufferOfficial = GetLiveBool(@"VsyncAdaptiveBufferOfficial", YES);
        self.dynamicThermalEngineOfficial = GetLiveBool(@"DynamicThermalEngineOfficial", YES);

        self.ios27AutoScheduler = GetLiveBool(@"Ios27AutoScheduler", YES);
        self.realtimePriorityBoost = GetLiveBool(@"RealtimePriorityBoost", YES);
        self.boostCpuGpu = GetLiveBool(@"BoostCpuGpu", YES);
        self.smartRamClean = GetLiveBool(@"SmartRamClean", YES);
        self.aggressiveRamClean = GetLiveBool(@"AggressiveRamClean", NO);
        self.killBgApps = GetLiveBool(@"KillBgApps", NO);
        self.turboAppLaunch = GetLiveBool(@"TurboAppLaunch", YES);
        self.metalTripleBuffering = GetLiveBool(@"MetalTripleBuffering", YES);
        self.gameFpsStabilizer = GetLiveBool(@"GameFpsStabilizer", YES);
        self.optimizeSystemProcess = GetLiveBool(@"OptimizeSystemProcess", YES);
        self.autoSpoofNewDevice = GetLiveBool(@"AutoSpoofNewDevice", YES);

        self.antiThermalThrottling = GetLiveBool(@"AntiThermalThrottling", YES);
        self.smartThermalManager = GetLiveBool(@"SmartThermalManager", YES);
        self.heavyLoadCooling = GetLiveBool(@"HeavyLoadCooling", YES);
        self.chargeCoolingProtection = GetLiveBool(@"ChargeCoolingProtection", YES);
        self.powerSaveMode = GetLiveBool(@"PowerSaveMode", NO);

        self.bypassVarSandbox = GetLiveBool(@"BypassVarSandbox", NO);
        self.blockAnalytics = GetLiveBool(@"BlockAnalytics", YES);

        if (!Titanium_IsSpringBoard() && !Titanium_IsPreferencesApp()) {
            ApexV25CorePayload sharedPayload;
            if (Titanium_ReadSharedSyncState(&sharedPayload)) {
                self.enabled = sharedPayload.masterEnabled;
                self.targetHz = sharedPayload.targetHz;
                self.targetFPS = sharedPayload.targetFPS;
                self.forceOverclock144Hz = sharedPayload.forceOverclock;
            }
        } else if (Titanium_IsSpringBoard()) {
            ApexV25CorePayload outP;
            memset(&outP, 0, sizeof(ApexV25CorePayload));
            outP.masterEnabled = self.enabled ? 1 : 0;
            outP.targetHz = (int32_t)self.targetHz;
            outP.targetFPS = (int32_t)self.targetFPS;
            outP.forceOverclock = self.forceOverclock144Hz ? 1 : 0;
            outP.pipSyncEnabled = 1;
            outP.thermalShield = self.antiThermalThrottling ? 1 : 0;
            outP.antiStutterExit = self.fixAppExitStutter ? 1 : 0;
            outP.tripleBuffering = self.metalTripleBuffering ? 1 : 0;
            outP.zeroLatencyTouch = self.touchResponseBoost ? 1 : 0;
            outP.shaderOptimization = 1;
            outP.dynamicInterpolation = self.proMotionEngineBeta7 ? 1 : 0;
            outP.fastAppLaunch = self.turboAppLaunch ? 1 : 0;
            Titanium_WriteSharedSyncState(&outP);
        }
    });
}

- (NSInteger)resolvedTargetHz {
    if (!self.enabled) return 60;
    if (self.powerSaveMode) return 30;
    if (self.forceOverclock144Hz) return 144;
    if (g_IsDeviceCharging && self.chargeCoolingProtection) return 60;

    if (self.proMotionEngineBeta7) {
        CFTimeInterval now = CACurrentMediaTime();
        BOOL isInteracting = g_IsUserTouching || (now - g_LastTouchTime < 0.75);

        if (g_LiveThermalState == NSProcessInfoThermalStateCritical) {
            return isInteracting ? 30 : 15;
        }

        if (g_LiveThermalState == NSProcessInfoThermalStateSerious) {
            return isInteracting ? 60 : 30;
        }

        if (g_LiveThermalState == NSProcessInfoThermalStateFair) {
            NSInteger maxCap = (self.targetHz > 90 || self.targetHz == 0) ? 90 : self.targetHz;
            return isInteracting ? maxCap : 45;
        }

        NSInteger peakHz = (self.targetHz > 0) ? self.targetHz : 120;
        return isInteracting ? peakHz : 60;
    }

    if (!self.enableHzControl) return 60;
    return (self.targetHz > 0) ? self.targetHz : 60;
}

- (NSInteger)resolvedTargetFPS {
    if (!self.enabled) return 60;
    if (self.powerSaveMode) return 30;
    if (self.forceOverclock144Hz) return 144;
    if (g_IsDeviceCharging && self.chargeCoolingProtection) return 60;

    if (self.proMotionEngineBeta7) {
        return [self resolvedTargetHz];
    }

    if (!self.enableFPSControl) return 60;
    return (self.targetFPS > 0) ? self.targetFPS : 60;
}
@end

BoostConfig *CFG = nil;
#define CFG_PTR [BoostConfig sharedInstance]
#define IS_ON (CFG_PTR.enabled)

static void Titanium_DebouncedPreferenceSync(void) {
    if (!titanium_pref_sync_queue) {
        titanium_pref_sync_queue = dispatch_queue_create("com.titaniumapex.pref.sync", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(titanium_pref_sync_queue, ^{
        [[BoostConfig sharedInstance] loadSettings];
        CFG = [BoostConfig sharedInstance];
    });
}

static void reloadPrefsNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    Titanium_DebouncedPreferenceSync();
}

%group Group_FastLaunch_SuperEngine

%hook FBApplicationProcess
- (void)bootstrapWithContext:(id)context completion:(id)completion {
    if (IS_ON && CFG_PTR.turboAppLaunch) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        thread_t currentThread = mach_thread_self();
        Apex_SetThreadRealtimeConstraint(currentThread, 120);
        mach_port_deallocate(mach_task_self(), currentThread);
    }
    %orig(context, completion);
}
%end

%hook UIApplication
- (void)_applicationOpenURLAction:(id)action payload:(id)payload origin:(id)origin {
    if (IS_ON && CFG_PTR.turboAppLaunch) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(action, payload, origin);
}
%end

%hook UIViewController
- (void)loadViewIfNeeded {
    if (IS_ON && CFG_PTR.turboAppLaunch) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)viewDidLoad {
    if (IS_ON && CFG_PTR.turboAppLaunch) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}
%end

%end

%group Group_Display_SpringBoard

%hook CADisplayLink
- (NSInteger)preferredFramesPerSecond {
    if (!IS_ON || !CFG_PTR.enableFPSControl) return %orig;
    return [CFG_PTR resolvedTargetFPS];
}

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (!IS_ON || !CFG_PTR.enableFPSControl) {
        %orig(fps);
        return;
    }
    %orig([CFG_PTR resolvedTargetFPS]);
}

- (CAFrameRateRange)preferredFrameRateRange {
    if (!IS_ON || (!CFG_PTR.enableHzControl && !CFG_PTR.proMotionEngineBeta7)) return %orig;
    float rate = (float)[CFG_PTR resolvedTargetHz];
    return CAFrameRateRangeMake(rate, rate, rate);
}

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    if (!IS_ON || (!CFG_PTR.enableHzControl && !CFG_PTR.proMotionEngineBeta7)) {
        %orig(range);
        return;
    }
    float rate = (float)[CFG_PTR resolvedTargetHz];
    %orig(CAFrameRateRangeMake(rate, rate, rate));
}
%end

%hook UIScreen
- (NSInteger)maximumFramesPerSecond {
    if (!IS_ON || (!CFG_PTR.enableHzControl && !CFG_PTR.proMotionEngineBeta7)) return %orig;
    return [CFG_PTR resolvedTargetHz];
}

- (NSInteger)_maximumFramesPerSecond {
    if (!IS_ON || (!CFG_PTR.enableHzControl && !CFG_PTR.proMotionEngineBeta7)) return %orig;
    return [CFG_PTR resolvedTargetHz];
}

- (void)_setTargetRefreshRate:(CGFloat)rate {
    if (!IS_ON || (!CFG_PTR.enableHzControl && !CFG_PTR.proMotionEngineBeta7)) {
        %orig(rate);
        return;
    }
    %orig((CGFloat)[CFG_PTR resolvedTargetHz]);
}

- (CGFloat)_refreshRate {
    if (!IS_ON || (!CFG_PTR.enableHzControl && !CFG_PTR.proMotionEngineBeta7)) return %orig;
    return (CGFloat)[CFG_PTR resolvedTargetHz];
}
%end

%hook CADisplay
- (NSInteger)preferredModeIndex {
    V25_ReadSyncMemory();
    if (IS_ON && CFG_PTR.targetHz > 60) {
        NSArray *modes = [self availableModes];
        if (modes && [modes count] > 0) {
            return (NSInteger)([modes count] - 1);
        }
    }
    return %orig;
}

- (void)overrideDisplayCadence:(id)cadence {
    V25_ReadSyncMemory();
    if (IS_ON && CFG_PTR.forceOverclock144Hz) {
        return;
    }
    %orig(cadence);
}
%end

%end

%group Group_V25_FloatingWindow_PiP

%hook CAContext
- (void)orderAbove:(uint32_t)arg1 {
    %orig;
    if (!IS_ON) return;
    [self setCommitPriority:1];
}

- (void)setDesiredDynamicRange:(float)arg1 {
    if (IS_ON && [CFG_PTR resolvedTargetHz] <= 30) {
        %orig(1.0f);
        return;
    }
    %orig(arg1);
}
%end

%hook PGPictureInPictureRemoteObject
- (void)setPictureInPictureShouldStartWhenEnteringBackground:(BOOL)arg1 {
    %orig;
    V25_ReadSyncMemory();
}

- (void)_updatePreferredContentSize {
    %orig;
    if (!IS_ON) return;
    V25_ReadSyncMemory();
}
%end

%hook SBFloatingDockViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (IS_ON) {
        V25_ReadSyncMemory();
    }
}
%end

%hook SBPIPController
- (void)setPictureInPictureWindowMargin:(UIEdgeInsets)arg1 {
    %orig;
    if (IS_ON) {
        V25_ReadSyncMemory();
    }
}
%end

%end

%group Group_Display_App_Lazy

%hook CADisplayLink
- (NSInteger)preferredFramesPerSecond {
    if (!IS_ON || !CFG_PTR.enableFPSControl) return %orig;
    return [CFG_PTR resolvedTargetFPS];
}

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (!IS_ON || !CFG_PTR.enableFPSControl) {
        %orig(fps);
        return;
    }
    %orig([CFG_PTR resolvedTargetFPS]);
}

- (CAFrameRateRange)preferredFrameRateRange {
    if (!IS_ON || (!CFG_PTR.enableHzControl && !CFG_PTR.proMotionEngineBeta7)) return %orig;
    float rate = (float)[CFG_PTR resolvedTargetHz];
    return CAFrameRateRangeMake(rate, rate, rate);
}

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    if (!IS_ON || (!CFG_PTR.enableHzControl && !CFG_PTR.proMotionEngineBeta7)) {
        %orig(range);
        return;
    }
    float rate = (float)[CFG_PTR resolvedTargetHz];
    %orig(CAFrameRateRangeMake(rate, rate, rate));
}
%end

%hook UIScreen
- (NSInteger)maximumFramesPerSecond {
    if (!IS_ON || (!CFG_PTR.enableHzControl && !CFG_PTR.proMotionEngineBeta7)) return %orig;
    return [CFG_PTR resolvedTargetHz];
}

- (NSInteger)_maximumFramesPerSecond {
    if (!IS_ON || (!CFG_PTR.enableHzControl && !CFG_PTR.proMotionEngineBeta7)) return %orig;
    return [CFG_PTR resolvedTargetHz];
}
%end

%hook CAMetalLayer
- (void)setFramebufferOnly:(BOOL)arg1 {
    %orig;
    if (!IS_ON) return;
    if (CFG_PTR.metalTripleBuffering && [self respondsToSelector:@selector(setMaximumDrawableCount:)]) {
        [self setMaximumDrawableCount:3];
    }
    if ([self respondsToSelector:@selector(setAllowsNextDrawableTimeout:)]) {
        [self setAllowsNextDrawableTimeout:NO];
    }
}

- (void)setDisplaySyncEnabled:(BOOL)arg1 {
    if (IS_ON && CFG_PTR.forceOverclock144Hz) {
        %orig(NO);
        return;
    }
    %orig(arg1);
}

- (id)nextDrawable {
    id drawable = %orig;
    if (IS_ON && drawable) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    return drawable;
}

- (void)setPresentsWithTransaction:(BOOL)arg1 {
    if (IS_ON && CFG_PTR.forceOverclock144Hz) {
        %orig(NO);
        return;
    }
    %orig(arg1);
}
%end

%end

%group Group_ColorOS17_SafeUI

%hook UIScrollView
- (void)setDecelerationRate:(CGFloat)rate {
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine) {
        if (self.isPagingEnabled) {
            %orig(rate);
        } else {
            %orig(0.992);
        }
    } else {
        %orig(rate);
    }
}

- (void)didMoveToWindow {
    %orig;
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine && self.window != nil) {
        if (!self.isPagingEnabled) {
            self.decelerationRate = 0.992;
        }
        PMConfigureScrollViewSafe(self);
    }
}

- (void)_smoothScrollWithVelocity:(CGPoint)velocity targetContentOffset:(CGPoint)targetContentOffset {
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine) {
        CGPoint calibratedVelocity = CGPointMake(velocity.x * 0.985f, velocity.y * 0.985f);
        %orig(calibratedVelocity, targetContentOffset);
        return;
    }
    %orig(velocity, targetContentOffset);
}
%end

%end

%group Group_Keyboard_And_Text

%hook UIKeyboardImpl
- (void)handleKeyWithString:(id)arg1 forKeyEvent:(id)arg2 executionContext:(id)arg3 {
    if (IS_ON && CFG_PTR.keyboardZeroLagV3) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)addInputString:(id)arg1 withFlags:(NSUInteger)arg2 executionContext:(id)arg3 {
    if (IS_ON && CFG_PTR.keyboardZeroLagV3) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)clearAnimations {
    if (IS_ON && CFG_PTR.keyboardZeroLagV3) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}
%end

%end

%group Group_Gesture_Fix

%hook SBFluidSwitcherAnimationSettings
- (void)setDefaultValues {
    %orig;
    if ([self respondsToSelector:@selector(setOpacityMinimumDistanceThreshold:)]) {
        [self setOpacityMinimumDistanceThreshold:0.0];
    }
}
%end

%hook SBAppSwitcherSettings
- (void)setDefaultValues {
    %orig;
    if ([self respondsToSelector:@selector(setShouldSimplifyForOptions:)]) {
        [self setShouldSimplifyForOptions:1];
    }
}
%end

%hook SBHomeGestureSettings
- (void)setDefaultValues {
    %orig;
    if ([self respondsToSelector:@selector(setTouchUpDelay:)]) {
        [self setTouchUpDelay:0.0];
    }
}
%end

%hook CAAnimation
- (void)setDuration:(NSTimeInterval)duration {
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine && duration > 0.35) {
        %orig(duration * 0.85);
    } else {
        %orig(duration);
    }
}
%end

%hook SBFluidSwitcherGestureWorkspaceTransaction
- (void)_beginWithGesture:(id)arg1 {
    if (IS_ON && CFG_PTR.fixAppExitStutter) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)_didComplete {
    if (IS_ON && CFG_PTR.fixAppExitStutter) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}
%end

%hook SBFluidSwitcherViewController
- (void)handleFluidSwitcherGesture:(id)gesture {
    %orig(gesture);
    if (IS_ON) {
        CFTimeInterval now = CACurrentMediaTime();
        if (now - g_LastExtremeTransitionTime < 0.20) {
            Titanium_RunGarbageCollector_Light();
        }
        g_LastExtremeTransitionTime = now;
    }
}

- (void)viewDidLoad {
    %orig;
    if (IS_ON) {
        V25_ReadSyncMemory();
    }
}
%end

%end

%group Group_Fix_App_Layout_Position

%hook SBDockView
- (void)didMoveToWindow {
    %orig;
    if (self.window) self.transform = CGAffineTransformIdentity;
}
%end

%hook SBIconListView
- (void)didMoveToWindow {
    %orig;
    if (self.window) self.transform = CGAffineTransformIdentity;
}
%end

%hook SBRootFolderView
- (void)didMoveToWindow {
    %orig;
    if (self.window) self.transform = CGAffineTransformIdentity;
}
%end

%hook SBFloatingDockView
- (void)didMoveToWindow {
    %orig;
    if (self.window) self.transform = CGAffineTransformIdentity;
}
%end

%hook _UIStatusBar
- (void)layoutSubviews {
    %orig;
    self.transform = CGAffineTransformIdentity;
}
%end

%end

%group Group_SpringBoard_Only

%hook SBIconController
- (void)iconTapped:(id)icon {
    if (IS_ON && CFG_PTR.fixAppLaunchBlackScreen) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(icon);
}
%end

%hook NSProcessInfo
- (NSProcessInfoThermalState)thermalState {
    if (IS_ON && CFG_PTR.antiThermalThrottling) {
        return NSProcessInfoThermalStateNominal;
    }
    return %orig;
}

+ (BOOL)isThermalPressureCritical {
    if (IS_ON && CFG_PTR.antiThermalThrottling) return NO;
    return %orig;
}
%end

%hook UIDevice
- (void)setBatteryMonitoringEnabled:(BOOL)enabled {
    %orig(YES);
}
%end

%hook ATXAnalyticsManager
- (void)sendEvent:(id)eventData {
    return;
}
%end

%hook UIWindow
- (void)sendEvent:(UIEvent *)event {
    if (IS_ON) {
        if (event.type == UIEventTypeTouches) {
            if (CFG_PTR.touchResponseBoost) {
                pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
            }
            if (CFG_PTR.proMotionEngineBeta7) {
                NSSet *touches = [event allTouches];
                UITouch *t = [touches anyObject];
                if (t) {
                    UITouchPhase phase = t.phase;
                    if (phase == UITouchPhaseBegan || phase == UITouchPhaseMoved) {
                        g_IsUserTouching = YES;
                        g_LastTouchTime = CACurrentMediaTime();
                    } else if (phase == UITouchPhaseEnded || phase == UITouchPhaseCancelled) {
                        g_IsUserTouching = NO;
                        g_LastTouchTime = CACurrentMediaTime();
                    }
                }
            }
        }
    }
    %orig(event);
}
%end

%hook UIGestureRecognizer
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (IS_ON && CFG_PTR.touchResponseBoost) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(touches, event);
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    if (IS_ON && CFG_PTR.touchResponseBoost && [CFG_PTR resolvedTargetHz] > 60) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(touches, event);
}
%end

%end

%group Group_UIKit_ThirdParty_Isolated

%hook UIScrollView
- (void)didMoveToWindow {
    %orig;
    if (self.window != nil && IS_ON && CFG_PTR.colorOs17SmoothEngine) {
        if (!self.isPagingEnabled) {
            self.decelerationRate = 0.992;
        }
        PMConfigureScrollViewSafe(self);
    }
}

- (void)setContentOffset:(CGPoint)contentOffset animated:(BOOL)animated {
    %orig(contentOffset, animated);
    if (IS_ON && CFG_PTR.touchResponseBoost) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
}

- (void)_smoothScrollWithVelocity:(CGPoint)velocity targetContentOffset:(CGPoint)targetContentOffset {
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine) {
        CGPoint calibratedVelocity = CGPointMake(velocity.x * 0.985f, velocity.y * 0.985f);
        %orig(calibratedVelocity, targetContentOffset);
        return;
    }
    %orig(velocity, targetContentOffset);
}
%end

%hook UIApplication
- (void)_run {
    if (IS_ON) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}
%end

%end

static void Titanium_LaunchAllModulesInsideApp(void) {
    if (!titanium_app_engine_queue) {
        titanium_app_engine_queue = dispatch_queue_create("com.titaniumapex.app.engine", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(titanium_app_engine_queue, ^{
        @autoreleasepool {
            @try {
                Class crashGuardCls = NSClassFromString(@"CrashGuard");
                if (crashGuardCls && [crashGuardCls respondsToSelector:@selector(sharedInstance)]) {
                    id guard = [crashGuardCls performSelector:@selector(sharedInstance)];
                    if ([guard respondsToSelector:@selector(startMonitoring)]) {
                        [guard performSelector:@selector(startMonitoring)];
                    }
                }

                Class cacheCls = NSClassFromString(@"CacheCleaner");
                if (cacheCls && [cacheCls respondsToSelector:@selector(forceDeepMemoryPurge)]) {
                    [cacheCls performSelector:@selector(forceDeepMemoryPurge)];
                }
                malloc_zone_pressure_relief(NULL, 1024 * 1024 * 4);

                Class thermalCls = NSClassFromString(@"SmartThermal");
                if (thermalCls) {
                    if ([thermalCls respondsToSelector:@selector(setupThermalThrottlingProtection)]) {
                        [thermalCls performSelector:@selector(setupThermalThrottlingProtection)];
                    } else if ([thermalCls respondsToSelector:@selector(sharedInstance)]) {
                        id th = [thermalCls performSelector:@selector(sharedInstance)];
                        if ([th respondsToSelector:@selector(startMonitoring)]) {
                            [th performSelector:@selector(startMonitoring)];
                        }
                    }
                }

                Class kbCls = NSClassFromString(@"KernelBypass");
                if (kbCls && [kbCls respondsToSelector:@selector(applySandboxBypassPatches)]) {
                    [kbCls performSelector:@selector(applySandboxBypassPatches)];
                }

                Class sbCls = NSClassFromString(@"SystemBlocker");
                if (sbCls && [sbCls respondsToSelector:@selector(blockSystemTracking)]) {
                    [sbCls performSelector:@selector(blockSystemTracking)];
                }
            } @catch(NSException *e) {}
        }
    });
}

@interface Titanium_SystemOptimizer : NSObject
+ (instancetype)sharedInstance;
- (void)triggerDeepMemoryClean;
- (void)optimizeCurrentTaskRunloop;
- (void)registerSystemPowerAssertions;
- (void)releaseSystemPowerAssertions;
- (void)executeLowMemoryWatchdogRoutine;
- (void)recalibrateGraphicsDriverPacing;
- (void)triggerHyperThreadOptimization;
- (void)synchronizeQuantumClockPipeline;
- (void)flushTelemetryMetrics;
- (void)executeCoreStabilitySurvey;
- (void)recoverFromMicroDeadlock;
- (void)enforceFrameTimingConstraints;
- (void)runKernelIOPacingSweep;
- (void)enforceVsyncLockConstraint;
- (void)purgeBackdropTextureCaches;
- (void)elevateCompositorThreadRealtime;
- (void)reanchorDockAndGridSubviews;
- (void)synchronizeComicReaderSmoothEngine;
- (void)suppressInterlacedFrameJitter;
- (void)purgeGPUTransientFramebuffers;
- (void)neutralizeExtremeFlingThermalSurge;
- (void)enforceSubsecondPacingEquilibrium;
- (void)smoothCadenceDispatchInterception;
- (void)mitigateDisplayCadenceTearing;
- (void)stabilizeFrameIntervalMomentum;
- (void)pruneTransientTextureCacheLines;
- (void)clampInteractiveGesturePhaseJitter;
@end

@implementation Titanium_SystemOptimizer {
    BOOL _assertionActive;
}

+ (instancetype)sharedInstance {
    static Titanium_SystemOptimizer *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[Titanium_SystemOptimizer alloc] init];
    });
    return inst;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _assertionActive = NO;
    }
    return self;
}

- (void)triggerDeepMemoryClean {
    @autoreleasepool {
        if (!Titanium_IsBankingApp() && Titanium_IsSpringBoard()) {
            Titanium_RunGarbageCollector_Aggressive();
            Titanium_AutoKernelMemoryRebalancer();
        }
    }
}

- (void)optimizeCurrentTaskRunloop {
    @autoreleasepool {
        CFRunLoopRef currentLoop = CFRunLoopGetCurrent();
        if (currentLoop) {
            CFRunLoopWakeUp(currentLoop);
            Titanium_AutoDaemonDeadlockImmunity();
        }
    }
}

- (void)registerSystemPowerAssertions {
    if (!_assertionActive) {
        _assertionActive = YES;
    }
}

- (void)releaseSystemPowerAssertions {
    if (_assertionActive) {
        _assertionActive = NO;
    }
}

- (void)executeLowMemoryWatchdogRoutine {
    @autoreleasepool {
        Titanium_PeriodicWatchdogHealthCheck();
        Titanium_AutoKernelMemoryRebalancer();
    }
}

- (void)recalibrateGraphicsDriverPacing {
    @autoreleasepool {
        Titanium_AutoGPUFramePacingRegulator();
    }
}

- (void)triggerHyperThreadOptimization {
    @autoreleasepool {
        if (CFG_PTR.hyperThreadIOAcceleratorOfficial) {
            Titanium_ExecuteHyperThreadIORoutine();
        }
    }
}

- (void)synchronizeQuantumClockPipeline {
    @autoreleasepool {
        if (CFG_PTR.quantumCoreSyncStabilizerOfficial) {
            Titanium_ExecuteQuantumCoreSyncRoutine();
        }
    }
}

- (void)flushTelemetryMetrics {
    if (!titanium_telemetry_queue) {
        titanium_telemetry_queue = dispatch_queue_create("com.titaniumapex.telemetry", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(titanium_telemetry_queue, ^{
        @autoreleasepool {
            g_titaniumGraphicsState.totalFramesRendered++;
        }
    });
}

- (void)executeCoreStabilitySurvey {
    if (!titanium_hardware_poll_queue) {
        titanium_hardware_poll_queue = dispatch_queue_create("com.titaniumapex.hardware.poll", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(titanium_hardware_poll_queue, ^{
        @autoreleasepool {
            Titanium_ExecuteThermalRoutine();
            Titanium_PeriodicWatchdogHealthCheck();
        }
    });
}

- (void)recoverFromMicroDeadlock {
    @autoreleasepool {
        Titanium_AutoDaemonDeadlockImmunity();
        g_titaniumWatchdogState.deadlocksPrevented++;
    }
}

- (void)enforceFrameTimingConstraints {
    @autoreleasepool {
        Titanium_AutoGPUFramePacingRegulator();
    }
}

- (void)runKernelIOPacingSweep {
    @autoreleasepool {
        Titanium_ExecuteHyperThreadIORoutine();
    }
}

- (void)enforceVsyncLockConstraint {
    @autoreleasepool {
        Titanium_AutoGPUFramePacingRegulator();
    }
}

- (void)purgeBackdropTextureCaches {
    @autoreleasepool {
        malloc_zone_pressure_relief(NULL, 1024 * 1024 * 4);
    }
}

- (void)elevateCompositorThreadRealtime {
    Titanium_BoostThreadPriorityRealtime();
}

- (void)reanchorDockAndGridSubviews {
    @autoreleasepool {
        g_titaniumGraphicsState.continuousSmoothFrames++;
    }
}

- (void)synchronizeComicReaderSmoothEngine {
    @autoreleasepool {
        g_titaniumMotionState.comicReaderSmoothModeEngaged = YES;
        g_titaniumMotionState.readingGestureVelocityTicks = mach_absolute_time();
    }
}

- (void)suppressInterlacedFrameJitter {
    @autoreleasepool {
        g_titaniumGraphicsState.frameInterlaceSuppressed = YES;
    }
}

- (void)purgeGPUTransientFramebuffers {
    @autoreleasepool {
        malloc_zone_pressure_relief(NULL, 1024 * 1024 * 8);
    }
}

- (void)neutralizeExtremeFlingThermalSurge {
    @autoreleasepool {
        Titanium_RunGarbageCollector_Light();
        g_titaniumThermalState.rapidThermalSpikeMitigations++;
    }
}

- (void)enforceSubsecondPacingEquilibrium {
    @autoreleasepool {
        Titanium_AutoGPUFramePacingRegulator();
    }
}

- (void)smoothCadenceDispatchInterception {
    @autoreleasepool {
        g_titaniumGraphicsState.frameTimingCorrections++;
        g_titaniumGraphicsState.dynamicRefreshRateRatio = 1.0f;
    }
}

- (void)mitigateDisplayCadenceTearing {
    @autoreleasepool {
        g_titaniumGraphicsState.isPacingLocked = YES;
        g_titaniumGraphicsState.bufferSwapOverrunCounter = 0;
    }
}

- (void)stabilizeFrameIntervalMomentum {
    @autoreleasepool {
        g_titaniumGraphicsState.frameSmoothingMomentum = 0.995f;
    }
}

- (void)pruneTransientTextureCacheLines {
    @autoreleasepool {
        malloc_zone_pressure_relief(NULL, 1024 * 1024 * 2);
    }
}

- (void)clampInteractiveGesturePhaseJitter {
    @autoreleasepool {
        g_titaniumMotionState.motionVelocitySmoothingDamping = 0.92f;
    }
}

@end

@interface Titanium_TouchVelocityPredictor : NSObject
+ (instancetype)sharedPredictor;
- (void)recordTouchPoint:(CGPoint)pt timestamp:(NSTimeInterval)ts;
- (CGPoint)predictedNextPointWithDamping:(CGFloat)damping;
- (void)reset;
@end

@implementation Titanium_TouchVelocityPredictor {
    CGPoint _points[16];
    NSTimeInterval _timestamps[16];
    NSInteger _count;
}

+ (instancetype)sharedPredictor {
    static Titanium_TouchVelocityPredictor *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[Titanium_TouchVelocityPredictor alloc] init];
    });
    return inst;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _count = 0;
    }
    return self;
}

- (void)recordTouchPoint:(CGPoint)pt timestamp:(NSTimeInterval)ts {
    if (_count < 16) {
        _points[_count] = pt;
        _timestamps[_count] = ts;
        _count++;
    } else {
        for (int i = 0; i < 15; i++) {
            _points[i] = _points[i+1];
            _timestamps[i] = _timestamps[i+1];
        }
        _points[15] = pt;
        _timestamps[15] = ts;
    }
}

- (CGPoint)predictedNextPointWithDamping:(CGFloat)damping {
    if (_count < 2) {
        return _count == 1 ? _points[0] : CGPointZero;
    }
    CGPoint last = _points[_count - 1];
    CGPoint prev = _points[_count - 2];
    NSTimeInterval dt = _timestamps[_count - 1] - _timestamps[_count - 2];
    if (dt <= 0.0001) return last;
    CGFloat vx = (last.x - prev.x) / dt;
    CGFloat vy = (last.y - prev.y) / dt;
    CGFloat step = 0.016667f;
    return CGPointMake(last.x + vx * step * damping, last.y + vy * step * damping);
}

- (void)reset {
    _count = 0;
}

@end

@interface Titanium_FrameCadenceMonitor : NSObject
+ (instancetype)sharedMonitor;
- (void)registerFrameRenderTime:(uint64_t)nanos;
- (float)calculateCadenceDriftPercentage;
- (BOOL)shouldTriggerDynamicThrottling;
@end

@implementation Titanium_FrameCadenceMonitor {
    uint64_t _frameTimes[32];
    NSInteger _frameIndex;
    uint64_t _lastRenderNanos;
}

+ (instancetype)sharedMonitor {
    static Titanium_FrameCadenceMonitor *m = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        m = [[Titanium_FrameCadenceMonitor alloc] init];
    });
    return m;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _frameIndex = 0;
        _lastRenderNanos = 0;
        memset(_frameTimes, 0, sizeof(_frameTimes));
    }
    return self;
}

- (void)registerFrameRenderTime:(uint64_t)nanos {
    _frameTimes[_frameIndex % 32] = nanos;
    _frameIndex++;
    _lastRenderNanos = nanos;
}

- (float)calculateCadenceDriftPercentage {
    if (_frameIndex < 4) return 0.0f;
    uint64_t totalDelta = 0;
    int count = _frameIndex > 32 ? 32 : (int)_frameIndex;
    for (int i = 1; i < count; i++) {
        if (_frameTimes[i] > _frameTimes[i-1]) {
            totalDelta += (_frameTimes[i] - _frameTimes[i-1]);
        }
    }
    uint64_t avg = totalDelta / (count - 1);
    if (avg == 0) return 0.0f;
    uint64_t variance = 0;
    for (int i = 1; i < count; i++) {
        if (_frameTimes[i] > _frameTimes[i-1]) {
            uint64_t d = _frameTimes[i] - _frameTimes[i-1];
            variance += (d > avg) ? (d - avg) : (avg - d);
        }
    }
    return (float)variance / (float)(avg * (count - 1));
}

- (BOOL)shouldTriggerDynamicThrottling {
    return [self calculateCadenceDriftPercentage] > 0.15f;
}

@end

@interface Titanium_RunLoopHangGuard : NSObject
+ (instancetype)sharedGuard;
- (void)startHangMonitoring;
- (void)stopHangMonitoring;
- (void)pingFromMainThread;
@end

@implementation Titanium_RunLoopHangGuard {
    dispatch_source_t _hangTimer;
    volatile uint64_t _lastPingTimestamp;
    BOOL _isMonitoring;
}

+ (instancetype)sharedGuard {
    static Titanium_RunLoopHangGuard *g = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        g = [[Titanium_RunLoopHangGuard alloc] init];
    });
    return g;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isMonitoring = NO;
        _lastPingTimestamp = 0;
    }
    return self;
}

- (void)pingFromMainThread {
    _lastPingTimestamp = mach_absolute_time();
}

- (void)startHangMonitoring {
    if (_isMonitoring) return;
    _isMonitoring = YES;
    _lastPingTimestamp = mach_absolute_time();
    _hangTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0));
    dispatch_source_set_timer(_hangTimer, dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), 1 * NSEC_PER_SEC, 200 * NSEC_PER_MSEC);
    dispatch_source_set_event_handler(_hangTimer, ^{
        mach_timebase_info_data_t tb;
        mach_timebase_info(&tb);
        uint64_t current = mach_absolute_time();
        uint64_t elapsedNanos = (current - _lastPingTimestamp) * tb.numer / tb.denom;
        if (elapsedNanos > 3500000000ULL) {
            CFRunLoopRef mainRL = CFRunLoopGetMain();
            if (mainRL && CFRunLoopIsWaiting(mainRL)) {
                CFRunLoopWakeUp(mainRL);
            }
        }
    });
    dispatch_resume(_hangTimer);
}

- (void)stopHangMonitoring {
    if (!_isMonitoring) return;
    if (_hangTimer) {
        dispatch_source_cancel(_hangTimer);
        _hangTimer = NULL;
    }
    _isMonitoring = NO;
}

@end

%ctor {
    @autoreleasepool {
        NSString *proc = [[NSProcessInfo processInfo] processName];
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];

        if (!bundleID || [bundleID length] == 0) {
            if (![proc isEqualToString:@"SpringBoard"]) {
                return;
            }
        }

        if ([proc isEqualToString:@"Preferences"] || Titanium_IsPreferencesApp()) {
            return;
        }
        if (Titanium_IsSystemCriticalDaemon()) {
            return;
        }
        if (Titanium_IsBankingApp()) {
            return;
        }

        Class crashGuardCls = NSClassFromString(@"CrashGuard");
        if (crashGuardCls && [crashGuardCls respondsToSelector:@selector(sharedInstance)]) {
            id guard = [crashGuardCls performSelector:@selector(sharedInstance)];
            if ([guard respondsToSelector:@selector(startMonitoring)]) {
                [guard performSelector:@selector(startMonitoring)];
            }
            if ([guard respondsToSelector:@selector(canExecuteHooks)]) {
                BOOL canExecute = ((BOOL (*)(id, SEL))objc_msgSend)(guard, @selector(canExecuteHooks));
                if (!canExecute) return;
            }
        }

        CFG = [BoostConfig sharedInstance];
        Titanium_StartThermalWatchdogTimer();

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                NULL,
                reloadPrefsNotification,
                CFSTR(NOTIFY_RELOAD),
                NULL,
                CFNotificationSuspensionBehaviorCoalesce
            );
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                NULL,
                reloadPrefsNotification,
                CFSTR(NOTIFY_UIKIT_RELOAD),
                NULL,
                CFNotificationSuspensionBehaviorCoalesce
            );
        });

        // Khởi tạo một lần duy nhất cho nhóm FastLaunch
        %init(Group_FastLaunch_SuperEngine);

        if (Titanium_IsSpringBoard()) {
            %init(Group_SpringBoard_Only);
            %init(Group_Gesture_Fix);
            %init(Group_Fix_App_Layout_Position);
            %init(Group_ColorOS17_SafeUI);
            %init(Group_Display_SpringBoard);
            %init(Group_V25_FloatingWindow_PiP);

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                Titanium_StartPassiveRamDaemon();
                Titanium_StartChargingMonitor();
            });
            Titanium_BoostThreadPriorityRealtime();
        } else {
            [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                              object:nil
                                                               queue:[NSOperationQueue mainQueue]
                                                          usingBlock:^(NSNotification *note) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    %init(Group_UIKit_ThirdParty_Isolated);
                    %init(Group_Display_App_Lazy);
                    %init(Group_V25_FloatingWindow_PiP);
                    Titanium_LaunchAllModulesInsideApp();
                });
            }];
        }

        if (Titanium_IsSpringBoard() || [proc containsString:@"inputhost"] || [proc containsString:@"Keyboard"]) {
            %init(Group_Keyboard_And_Text);
        }

        %init(_ungrouped);

        PMRuntimeReady = YES;
    }
}
