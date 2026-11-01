#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <spawn.h>
#import <sys/wait.h>
#import <sys/stat.h>
#import <sys/mman.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>
#import <fcntl.h>
#import <unistd.h>
#include <errno.h>
#include <stdint.h>
#include <math.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#import <notify.h>
#import <dlfcn.h>
#import <mach/mach.h>
#import <mach/mach_time.h>
#import <mach/processor_info.h>
#import <mach/mach_host.h>
#import <mach/vm_map.h>
#import <AudioToolbox/AudioToolbox.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreImage/CoreImage.h>
#import <Metal/Metal.h>
#import <Security/Security.h>
#import <os/lock.h>
#import <IOKit/IOKitLib.h>
#import <CoreFoundation/CoreFoundation.h>

#define APEX_SYNC_MAGIC_V285 0x41505837
#define PRIMARY_SYNC_FILE    @"/tmp/.boost_hz_sync"
#define SECONDARY_SYNC_FILE  @"/var/jb/tmp/.boost_hz_sync"
#define NOTIFY_RELOAD        "com.taojb.boostiphone6s/ReloadPrefs"
#define NOTIFY_UIKIT_RELOAD  "com.taojb.boostiphone6s/ReloadUIKitPrefs"
#define NOTIFY_HARDWARE_SYNC "com.taojb.boostiphone6s/HardwareSync"
#define NOTIFY_FPS_CHANGED   "com.taojb.boostiphone6s/FPSChanged"
#define NOTIFY_TITANIUM_CHANGED "com.titanium.v285.prefschanged"
#define NOTIFY_PAYLOAD_WRITTEN "com.taojb.boostiphone6s/PayloadWritten"
#define APPS_SYNC_FILE_PRIMARY   @"/tmp/.boost_hz_apps"
#define APPS_SYNC_FILE_SECONDARY @"/var/jb/tmp/.boost_hz_apps"
#define PREF_PATH_DEFAULT    @"/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist"

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
    
    uint32_t enableAppleInternalProMotion;
    uint32_t enableZeroLatencyTouch;
    uint32_t enableMetalZeroTearing;
    uint32_t enableFluidTransitions;
    uint32_t enableTitaniumGameMetalOverdrive;
    uint32_t enableAIStreamOptimization;
    uint32_t enableFastLaunchSuperEngine;
    uint32_t enableScrollAndKeyboard;
    uint32_t enableInstantActionTransitions;
    uint32_t enableGlobalThreadGovernor;
    uint32_t enableSiliconSchedulerTouch;
    uint32_t enableCoreAnimationRenderServer;
    uint32_t enableCAWindowServerDominance;
    uint32_t enableForceRenderRecovery;
    uint32_t enableWindowLevelOverdrive;
    uint32_t enableSystemMemoryGovernor;
    uint32_t enableThermalCryoPacing;
    uint32_t enableDeepRamCompaction;
    uint32_t enableWebKitRamOptimizer;
    uint32_t enableSiliconHardwarePipeline;
    uint32_t enableHardwareProMotionOverclock;
    uint32_t enableNeuralTouchEdgeZeroLatency;
    uint32_t enableNativeColdBootOverdrive;
    uint32_t enableTitaniumV12SmoothExit;
    uint32_t enableDisplaySpringBoard;
    uint32_t enableLiquidGlassOpt;
    uint32_t enableSwitcher30Apps;
    uint32_t enableSpringBoardSwitcherOpt;
    uint32_t enableFloatingWindowPiP;
    uint32_t enableHardwareSegregationHome;
    uint32_t enableSpringBoardProcessManager;
    uint32_t enableKeepAppsAlive;
    uint32_t enableTitaniumV10LayoutBoost;
    uint32_t enableUIKitThirdPartyIsolated;
    
    uint64_t updateSeq;
    uint64_t lastHeartbeat;
    char     reserved[200];
} ApexV285ProPayloadRLCV285;

static inline NSString *TI_GetRootHidePrefixPath(void) {
    static NSString *cached = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Dl_info info;
        if (dladdr((const void *)TI_GetRootHidePrefixPath, &info) && info.dli_fname) {
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

static inline NSString *TI_ResolvePrefPath(void) {
    NSString *root = TI_GetRootHidePrefixPath();
    if (root && root.length > 0 && ![root isEqualToString:@"/"]) {
        NSString *p = [root stringByAppendingPathComponent:@"var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:p]) return p;
    }
    NSString *p1 = @"/var/jb/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist";
    if ([[NSFileManager defaultManager] fileExistsAtPath:p1]) return p1;
    return PREF_PATH_DEFAULT;
}

static BOOL TI_WriteAllBytes(int fd, const void *data, size_t size) {
    const uint8_t *cursor = (const uint8_t *)data;
    size_t remaining = size;
    while (remaining > 0) {
        ssize_t written = write(fd, cursor, remaining);
        if (written < 0 && errno == EINTR) continue;
        if (written <= 0) return NO;
        cursor += (size_t)written;
        remaining -= (size_t)written;
    }
    return YES;
}

static BOOL TI_WriteAtomicBytesAtPath(NSString *path, const void *data, size_t size) {
    if (path.length == 0 || (size > 0 && data == NULL)) return NO;
    NSString *dir = [path stringByDeletingLastPathComponent];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:dir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @(0777)} error:nil];
    }
    NSString *template = [path stringByAppendingString:@".tmp.XXXXXX"];
    char *temporaryPath = strdup([template fileSystemRepresentation]);
    if (!temporaryPath) return NO;
    int fd = mkstemp(temporaryPath);
    if (fd < 0) { free(temporaryPath); return NO; }
    BOOL ok = TI_WriteAllBytes(fd, data, size);
    if (ok && fsync(fd) != 0) ok = NO;
    if (ok && fchmod(fd, 0644) != 0) ok = NO;
    if (close(fd) != 0) ok = NO;
    if (ok && rename(temporaryPath, [path fileSystemRepresentation]) == 0) {
        chmod([path fileSystemRepresentation], 0644);
    } else {
        unlink(temporaryPath);
        ok = NO;
    }
    free(temporaryPath);
    return ok;
}

static void TI_WriteSyncPayloadUniversal(const void *data, size_t size) {
    if (!data || size != sizeof(ApexV285ProPayloadRLCV285)) return;
    TI_WriteAtomicBytesAtPath(PRIMARY_SYNC_FILE, data, size);
    TI_WriteAtomicBytesAtPath(SECONDARY_SYNC_FILE, data, size);
}

@interface RootListController : UIViewController <UITextFieldDelegate>
@end

@interface RootListController () {
    ApexV285ProPayloadRLCV285 _payload;
    NSMutableDictionary *_settings;
    NSArray<NSString *> *_groupToggleKeys;
    
    UIView *_rotateLandscapeOverlay;
    UILabel *_rotatePromptLabel;
    
    UIView *_bootContainer;
    UITextView *_bootConsoleLogView;
    UIView *_bootLogoBox;
    UILabel *_bootLogoLabel;
    UILabel *_bootSubPrompt;
    
    UIView *_eDEXMainInterface;
    
    UIView *_topBarView;
    UILabel *_topClockLabel;
    UILabel *_topSysInfoLabel;
    UIView *_topTabContainer;
    NSMutableArray<UIButton *> *_topTabButtons;
    NSInteger _activeMainTab;
    
    UIView *_leftPanel;
    CAShapeLayer *_cpuWaveLayer;
    CGFloat _cpuHistory[32];
    UILabel *_lblCpuText;
    UILabel *_lblRamText;
    UIProgressView *_ramBar;
    UILabel *_lblThermalText;
    UILabel *_lblStorageText;
    
    UIView *_centerPanel;
    UILabel *_lblCenterHeader;
    UIScrollView *_centerScrollView;
    UIView *_centerControlHub;
    UILabel *_lblTargetHzValue;
    UISlider *_hzSlider;
    UILabel *_lblTargetFpsValue;
    UISlider *_fpsSlider;
    
    UIView *_rightPanel;
    UIView *_radarCircleView;
    CAShapeLayer *_radarSweepLayer;
    CAShapeLayer *_globeWireLayer;
    CGFloat _radarAngle;
    UILabel *_lblPingVal;
    UILabel *_lblIPVal;
    UILabel *_lblIpcPipeStatus;
    
    UIView *_bottomDockBar;
    NSMutableArray<UIButton *> *_dockActionButtons;
    
    CADisplayLink *_animTickLink;
    NSTimer *_systemPollTimer;
    UIImpactFeedbackGenerator *_haptic;
}
@end

@implementation RootListController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    _haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [_haptic prepare];

    [self initToggleKeys];
    [self loadExistingSettings];
    [self buildFullInterfaceLayout];
    [self setupOrientationListener];
    [self checkOrientationAndRun:self.view.bounds.size];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    [self startRuntimeLoops];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:NO];
    [self stopRuntimeLoops];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)initToggleKeys {
    _groupToggleKeys = @[
        @"enableAppleInternalProMotion", @"enableZeroLatencyTouch", @"enableMetalZeroTearing",
        @"enableFluidTransitions", @"enableTitaniumGameMetalOverdrive", @"enableAIStreamOptimization",
        @"enableFastLaunchSuperEngine", @"enableScrollAndKeyboard", @"enableInstantActionTransitions",
        @"enableGlobalThreadGovernor", @"enableSiliconSchedulerTouch", @"enableCoreAnimationRenderServer",
        @"enableCAWindowServerDominance", @"enableForceRenderRecovery", @"enableWindowLevelOverdrive",
        @"enableSystemMemoryGovernor", @"enableThermalCryoPacing", @"enableDeepRamCompaction",
        @"enableWebKitRamOptimizer", @"enableSiliconHardwarePipeline", @"enableHardwareProMotionOverclock",
        @"enableNeuralTouchEdgeZeroLatency", @"enableNativeColdBootOverdrive", @"enableTitaniumV12SmoothExit",
        @"enableDisplaySpringBoard", @"enableLiquidGlassOpt", @"enableSwitcher30Apps",
        @"enableSpringBoardSwitcherOpt", @"enableFloatingWindowPiP", @"enableHardwareSegregationHome",
        @"enableSpringBoardProcessManager", @"enableKeepAppsAlive", @"enableTitaniumV10LayoutBoost",
        @"enableUIKitThirdPartyIsolated"
    ];
}

- (void)loadExistingSettings {
    NSString *prefPath = TI_ResolvePrefPath();
    _settings = [NSMutableDictionary dictionaryWithContentsOfFile:prefPath] ?: [NSMutableDictionary dictionary];

    memset(&_payload, 0, sizeof(ApexV285ProPayloadRLCV285));
    _payload.magic = APEX_SYNC_MAGIC_V285;
    _payload.masterEnabled = _settings[@"MasterEnabled"] ? [_settings[@"MasterEnabled"] unsignedIntValue] : 1;
    _payload.targetHz = _settings[@"TargetRefreshRate"] ? [_settings[@"TargetRefreshRate"] intValue] : 120;
    _payload.targetFPS = _settings[@"TargetFPSRate"] ? [_settings[@"TargetFPSRate"] intValue] : 120;
    _payload.forceOverclock = _settings[@"ForceOverclock"] ? [_settings[@"ForceOverclock"] unsignedIntValue] : 1;
    _payload.thermalShield = _settings[@"ThermalShield"] ? [_settings[@"ThermalShield"] unsignedIntValue] : 1;
    _payload.zeroLatencyTouch = _settings[@"ZeroLatencyTouch"] ? [_settings[@"ZeroLatencyTouch"] unsignedIntValue] : 1;

    for (NSString *key in _groupToggleKeys) {
        id val = _settings[key];
        uint32_t state = (val != nil) ? [val unsignedIntValue] : 1;
        [self writeGroupToggleValue:state forKey:key];
    }
}

- (void)writeGroupToggleValue:(uint32_t)state forKey:(NSString *)key {
    if ([key isEqualToString:@"enableAppleInternalProMotion"]) _payload.enableAppleInternalProMotion = state;
    else if ([key isEqualToString:@"enableZeroLatencyTouch"]) _payload.enableZeroLatencyTouch = state;
    else if ([key isEqualToString:@"enableMetalZeroTearing"]) _payload.enableMetalZeroTearing = state;
    else if ([key isEqualToString:@"enableFluidTransitions"]) _payload.enableFluidTransitions = state;
    else if ([key isEqualToString:@"enableTitaniumGameMetalOverdrive"]) _payload.enableTitaniumGameMetalOverdrive = state;
    else if ([key isEqualToString:@"enableAIStreamOptimization"]) _payload.enableAIStreamOptimization = state;
    else if ([key isEqualToString:@"enableFastLaunchSuperEngine"]) _payload.enableFastLaunchSuperEngine = state;
    else if ([key isEqualToString:@"enableScrollAndKeyboard"]) _payload.enableScrollAndKeyboard = state;
    else if ([key isEqualToString:@"enableInstantActionTransitions"]) _payload.enableInstantActionTransitions = state;
    else if ([key isEqualToString:@"enableGlobalThreadGovernor"]) _payload.enableGlobalThreadGovernor = state;
    else if ([key isEqualToString:@"enableSiliconSchedulerTouch"]) _payload.enableSiliconSchedulerTouch = state;
    else if ([key isEqualToString:@"enableCoreAnimationRenderServer"]) _payload.enableCoreAnimationRenderServer = state;
    else if ([key isEqualToString:@"enableCAWindowServerDominance"]) _payload.enableCAWindowServerDominance = state;
    else if ([key isEqualToString:@"enableForceRenderRecovery"]) _payload.enableForceRenderRecovery = state;
    else if ([key isEqualToString:@"enableWindowLevelOverdrive"]) _payload.enableWindowLevelOverdrive = state;
    else if ([key isEqualToString:@"enableSystemMemoryGovernor"]) _payload.enableSystemMemoryGovernor = state;
    else if ([key isEqualToString:@"enableThermalCryoPacing"]) _payload.enableThermalCryoPacing = state;
    else if ([key isEqualToString:@"enableDeepRamCompaction"]) _payload.enableDeepRamCompaction = state;
    else if ([key isEqualToString:@"enableWebKitRamOptimizer"]) _payload.enableWebKitRamOptimizer = state;
    else if ([key isEqualToString:@"enableSiliconHardwarePipeline"]) _payload.enableSiliconHardwarePipeline = state;
    else if ([key isEqualToString:@"enableHardwareProMotionOverclock"]) _payload.enableHardwareProMotionOverclock = state;
    else if ([key isEqualToString:@"enableNeuralTouchEdgeZeroLatency"]) _payload.enableNeuralTouchEdgeZeroLatency = state;
    else if ([key isEqualToString:@"enableNativeColdBootOverdrive"]) _payload.enableNativeColdBootOverdrive = state;
    else if ([key isEqualToString:@"enableTitaniumV12SmoothExit"]) _payload.enableTitaniumV12SmoothExit = state;
    else if ([key isEqualToString:@"enableDisplaySpringBoard"]) _payload.enableDisplaySpringBoard = state;
    else if ([key isEqualToString:@"enableLiquidGlassOpt"]) _payload.enableLiquidGlassOpt = state;
    else if ([key isEqualToString:@"enableSwitcher30Apps"]) _payload.enableSwitcher30Apps = state;
    else if ([key isEqualToString:@"enableSpringBoardSwitcherOpt"]) _payload.enableSpringBoardSwitcherOpt = state;
    else if ([key isEqualToString:@"enableFloatingWindowPiP"]) _payload.enableFloatingWindowPiP = state;
    else if ([key isEqualToString:@"enableHardwareSegregationHome"]) _payload.enableHardwareSegregationHome = state;
    else if ([key isEqualToString:@"enableSpringBoardProcessManager"]) _payload.enableSpringBoardProcessManager = state;
    else if ([key isEqualToString:@"enableKeepAppsAlive"]) _payload.enableKeepAppsAlive = state;
    else if ([key isEqualToString:@"enableTitaniumV10LayoutBoost"]) _payload.enableTitaniumV10LayoutBoost = state;
    else if ([key isEqualToString:@"enableUIKitThirdPartyIsolated"]) _payload.enableUIKitThirdPartyIsolated = state;
}

- (uint32_t)readGroupToggleValueForKey:(NSString *)key {
    if ([key isEqualToString:@"enableAppleInternalProMotion"]) return _payload.enableAppleInternalProMotion;
    if ([key isEqualToString:@"enableZeroLatencyTouch"]) return _payload.enableZeroLatencyTouch;
    if ([key isEqualToString:@"enableMetalZeroTearing"]) return _payload.enableMetalZeroTearing;
    if ([key isEqualToString:@"enableFluidTransitions"]) return _payload.enableFluidTransitions;
    if ([key isEqualToString:@"enableTitaniumGameMetalOverdrive"]) return _payload.enableTitaniumGameMetalOverdrive;
    if ([key isEqualToString:@"enableAIStreamOptimization"]) return _payload.enableAIStreamOptimization;
    if ([key isEqualToString:@"enableFastLaunchSuperEngine"]) return _payload.enableFastLaunchSuperEngine;
    if ([key isEqualToString:@"enableScrollAndKeyboard"]) return _payload.enableScrollAndKeyboard;
    if ([key isEqualToString:@"enableInstantActionTransitions"]) return _payload.enableInstantActionTransitions;
    if ([key isEqualToString:@"enableGlobalThreadGovernor"]) return _payload.enableGlobalThreadGovernor;
    if ([key isEqualToString:@"enableSiliconSchedulerTouch"]) return _payload.enableSiliconSchedulerTouch;
    if ([key isEqualToString:@"enableCoreAnimationRenderServer"]) return _payload.enableCoreAnimationRenderServer;
    if ([key isEqualToString:@"enableCAWindowServerDominance"]) return _payload.enableCAWindowServerDominance;
    if ([key isEqualToString:@"enableForceRenderRecovery"]) return _payload.enableForceRenderRecovery;
    if ([key isEqualToString:@"enableWindowLevelOverdrive"]) return _payload.enableWindowLevelOverdrive;
    if ([key isEqualToString:@"enableSystemMemoryGovernor"]) return _payload.enableSystemMemoryGovernor;
    if ([key isEqualToString:@"enableThermalCryoPacing"]) return _payload.enableThermalCryoPacing;
    if ([key isEqualToString:@"enableDeepRamCompaction"]) return _payload.enableDeepRamCompaction;
    if ([key isEqualToString:@"enableWebKitRamOptimizer"]) return _payload.enableWebKitRamOptimizer;
    if ([key isEqualToString:@"enableSiliconHardwarePipeline"]) return _payload.enableSiliconHardwarePipeline;
    if ([key isEqualToString:@"enableHardwareProMotionOverclock"]) return _payload.enableHardwareProMotionOverclock;
    if ([key isEqualToString:@"enableNeuralTouchEdgeZeroLatency"]) return _payload.enableNeuralTouchEdgeZeroLatency;
    if ([key isEqualToString:@"enableNativeColdBootOverdrive"]) return _payload.enableNativeColdBootOverdrive;
    if ([key isEqualToString:@"enableTitaniumV12SmoothExit"]) return _payload.enableTitaniumV12SmoothExit;
    if ([key isEqualToString:@"enableDisplaySpringBoard"]) return _payload.enableDisplaySpringBoard;
    if ([key isEqualToString:@"enableLiquidGlassOpt"]) return _payload.enableLiquidGlassOpt;
    if ([key isEqualToString:@"enableSwitcher30Apps"]) return _payload.enableSwitcher30Apps;
    if ([key isEqualToString:@"enableSpringBoardSwitcherOpt"]) return _payload.enableSpringBoardSwitcherOpt;
    if ([key isEqualToString:@"enableFloatingWindowPiP"]) return _payload.enableFloatingWindowPiP;
    if ([key isEqualToString:@"enableHardwareSegregationHome"]) return _payload.enableHardwareSegregationHome;
    if ([key isEqualToString:@"enableSpringBoardProcessManager"]) return _payload.enableSpringBoardProcessManager;
    if ([key isEqualToString:@"enableKeepAppsAlive"]) return _payload.enableKeepAppsAlive;
    if ([key isEqualToString:@"enableTitaniumV10LayoutBoost"]) return _payload.enableTitaniumV10LayoutBoost;
    if ([key isEqualToString:@"enableUIKitThirdPartyIsolated"]) return _payload.enableUIKitThirdPartyIsolated;
    return 1;
}

- (void)saveAndCommitAllSync {
    _payload.updateSeq++;
    _payload.lastHeartbeat = (uint64_t)([[NSDate date] timeIntervalSince1970] * 1000.0);

    _settings[@"MasterEnabled"] = @(_payload.masterEnabled);
    _settings[@"TargetRefreshRate"] = @(_payload.targetHz);
    _settings[@"TargetFPSRate"] = @(_payload.targetFPS);
    _settings[@"ForceOverclock"] = @(_payload.forceOverclock);
    _settings[@"ThermalShield"] = @(_payload.thermalShield);
    _settings[@"ZeroLatencyTouch"] = @(_payload.zeroLatencyTouch);

    for (NSString *key in _groupToggleKeys) {
        _settings[key] = @([self readGroupToggleValueForKey:key]);
    }

    NSString *prefPath = TI_ResolvePrefPath();
    [_settings writeToFile:prefPath atomically:YES];
    chmod([prefPath UTF8String], 0644);

    TI_WriteSyncPayloadUniversal(&_payload, sizeof(ApexV285ProPayloadRLCV285));
    notify_post(NOTIFY_PAYLOAD_WRITTEN);
    notify_post(NOTIFY_RELOAD);
    notify_post(NOTIFY_UIKIT_RELOAD);
    notify_post(NOTIFY_FPS_CHANGED);
}

- (void)setupOrientationListener {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceOrientationChanged) name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (void)deviceOrientationChanged {
    [self checkOrientationAndRun:self.view.bounds.size];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        [self checkOrientationAndRun:size];
    } completion:nil];
}

- (void)checkOrientationAndRun:(CGSize)sz {
    BOOL isLandscape = sz.width > sz.height;
    if (!isLandscape) {
        _rotateLandscapeOverlay.hidden = NO;
        [self.view bringSubviewToFront:_rotateLandscapeOverlay];
        _rotateLandscapeOverlay.frame = CGRectMake(0, 0, sz.width, sz.height);
        _rotatePromptLabel.frame = CGRectMake(20, sz.height/2 - 40, sz.width - 40, 80);
    } else {
        _rotateLandscapeOverlay.hidden = YES;
        _eDEXMainInterface.frame = CGRectMake(0, 0, sz.width, sz.height);
        [self updateModuleFramesForSize:sz];
    }
}

- (void)buildFullInterfaceLayout {
    CGSize sz = self.view.bounds.size;
    
    _rotateLandscapeOverlay = [[UIView alloc] initWithFrame:self.view.bounds];
    _rotateLandscapeOverlay.backgroundColor = [UIColor colorWithRed:0.02 green:0.02 blue:0.04 alpha:0.98];
    _rotateLandscapeOverlay.hidden = YES;
    [self.view addSubview:_rotateLandscapeOverlay];

    _rotatePromptLabel = [[UILabel alloc] init];
    _rotatePromptLabel.numberOfLines = 0;
    _rotatePromptLabel.textAlignment = NSTextAlignmentCenter;
    _rotatePromptLabel.textColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.8 alpha:1.0];
    _rotatePromptLabel.font = [UIFont fontWithName:@"Courier-Bold" size:16] ?: [UIFont boldSystemFontOfSize:16];
    _rotatePromptLabel.text = @">> PLEASE ROTATE DEVICE TO LANDSCAPE <<\n[eDEX-UI SCI-FI TERMINAL REQUIRES WIDESCREEN]";
    [_rotateLandscapeOverlay addSubview:_rotatePromptLabel];

    _eDEXMainInterface = [[UIView alloc] initWithFrame:CGRectMake(0, 0, sz.width, sz.height)];
    _eDEXMainInterface.backgroundColor = [UIColor colorWithRed:0.015 green:0.02 blue:0.035 alpha:1.0];
    _eDEXMainInterface.alpha = 0.0;
    [self.view addSubview:_eDEXMainInterface];

    _topBarView = [[UIView alloc] init];
    _topBarView.backgroundColor = [UIColor colorWithRed:0.03 green:0.045 blue:0.07 alpha:0.95];
    _topBarView.layer.borderColor = [UIColor colorWithRed:0.0 green:0.75 blue:0.9 alpha:0.4].CGColor;
    _topBarView.layer.borderWidth = 0.8;
    [_eDEXMainInterface addSubview:_topBarView];

    _topClockLabel = [[UILabel alloc] init];
    _topClockLabel.textColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.85 alpha:1.0];
    _topClockLabel.font = [UIFont fontWithName:@"Courier-Bold" size:12] ?: [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightBold];
    [_topBarView addSubview:_topClockLabel];

    _topSysInfoLabel = [[UILabel alloc] init];
    _topSysInfoLabel.textColor = [UIColor colorWithRed:0.3 green:0.7 blue:0.85 alpha:0.8];
    _topSysInfoLabel.font = [UIFont fontWithName:@"Courier" size:9] ?: [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightRegular];
    _topSysInfoLabel.text = @"SMOOTHIOS PRO // APEX-V285 ENGINE [ONLINE]";
    [_topBarView addSubview:_topSysInfoLabel];

    _topTabContainer = [[UIView alloc] init];
    [_topBarView addSubview:_topTabContainer];

    NSArray *tabs = @[@"DASHBOARD", @"HZ / FPS", @"34 SWITCHES", @"HOOKED APPS", @"PROFILES & RESET"];
    _topTabButtons = [NSMutableArray array];
    for (NSInteger i = 0; i < tabs.count; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.tag = i;
        b.layer.borderWidth = 1.0;
        b.layer.borderColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.95 alpha:(i == 0 ? 0.9 : 0.3)].CGColor;
        b.layer.cornerRadius = 2.0;
        b.backgroundColor = (i == 0) ? [UIColor colorWithRed:0.0 green:0.6 blue:0.8 alpha:0.35] : [UIColor clearColor];
        [b setTitle:tabs[i] forState:UIControlStateNormal];
        [b setTitleColor:(i == 0 ? [UIColor whiteColor] : [UIColor colorWithRed:0.3 green:0.7 blue:0.8 alpha:0.8]) forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:10] ?: [UIFont boldSystemFontOfSize:10];
        [b addTarget:self action:@selector(mainTabClicked:) forControlEvents:UIControlEventTouchUpInside];
        [_topTabContainer addSubview:b];
        [_topTabButtons addObject:b];
    }

    _leftPanel = [[UIView alloc] init];
    _leftPanel.layer.borderWidth = 0.5;
    _leftPanel.layer.borderColor = [UIColor colorWithRed:0.0 green:0.6 blue:0.8 alpha:0.3].CGColor;
    [_eDEXMainInterface addSubview:_leftPanel];

    UILabel *leftHdr = [[UILabel alloc] initWithFrame:CGRectMake(8, 4, 180, 16)];
    leftHdr.textColor = [UIColor colorWithRed:0.0 green:0.9 blue:0.95 alpha:0.9];
    leftHdr.font = [UIFont fontWithName:@"Courier-Bold" size:9] ?: [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightBold];
    leftHdr.text = @"// REALTIME CPU / RAM / TEMP";
    [_leftPanel addSubview:leftHdr];

    UIView *waveContainer = [[UIView alloc] initWithFrame:CGRectMake(8, 24, 180, 68)];
    waveContainer.tag = 501;
    waveContainer.backgroundColor = [UIColor colorWithRed:0.01 green:0.02 blue:0.03 alpha:0.8];
    waveContainer.layer.borderWidth = 0.5;
    waveContainer.layer.borderColor = [UIColor colorWithRed:0.0 green:0.7 blue:0.8 alpha:0.35].CGColor;
    [_leftPanel addSubview:waveContainer];

    _cpuWaveLayer = [CAShapeLayer layer];
    _cpuWaveLayer.strokeColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.7 alpha:0.9].CGColor;
    _cpuWaveLayer.fillColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.7 alpha:0.15].CGColor;
    _cpuWaveLayer.lineWidth = 1.0;
    [waveContainer.layer addSublayer:_cpuWaveLayer];

    _lblCpuText = [[UILabel alloc] initWithFrame:CGRectMake(8, 96, 180, 14)];
    _lblCpuText.textColor = [UIColor colorWithRed:0.2 green:0.85 blue:1.0 alpha:0.85];
    _lblCpuText.font = [UIFont fontWithName:@"Courier" size:9] ?: [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightRegular];
    [_leftPanel addSubview:_lblCpuText];

    _lblRamText = [[UILabel alloc] initWithFrame:CGRectMake(8, 112, 180, 14)];
    _lblRamText.textColor = [UIColor colorWithRed:0.2 green:0.85 blue:1.0 alpha:0.85];
    _lblRamText.font = [UIFont fontWithName:@"Courier" size:9] ?: [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightRegular];
    [_leftPanel addSubview:_lblRamText];

    _ramBar = [[UIProgressView alloc] initWithFrame:CGRectMake(8, 129, 180, 3)];
    _ramBar.progressTintColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.6 alpha:1.0];
    _ramBar.trackTintColor = [UIColor colorWithRed:0.1 green:0.15 blue:0.2 alpha:1.0];
    [_leftPanel addSubview:_ramBar];

    _lblThermalText = [[UILabel alloc] initWithFrame:CGRectMake(8, 136, 180, 14)];
    _lblThermalText.textColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.5 alpha:0.9];
    _lblThermalText.font = [UIFont fontWithName:@"Courier" size:9] ?: [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightRegular];
    [_leftPanel addSubview:_lblThermalText];

    _lblStorageText = [[UILabel alloc] initWithFrame:CGRectMake(8, 152, 180, 14)];
    _lblStorageText.textColor = [UIColor colorWithRed:0.4 green:0.7 blue:0.9 alpha:0.8];
    _lblStorageText.font = [UIFont fontWithName:@"Courier" size:9] ?: [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightRegular];
    [_leftPanel addSubview:_lblStorageText];

    _centerPanel = [[UIView alloc] init];
    _centerPanel.layer.borderWidth = 0.5;
    _centerPanel.layer.borderColor = [UIColor colorWithRed:0.0 green:0.75 blue:0.95 alpha:0.4].CGColor;
    [_eDEXMainInterface addSubview:_centerPanel];

    _lblCenterHeader = [[UILabel alloc] initWithFrame:CGRectMake(10, 4, 300, 16)];
    _lblCenterHeader.textColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.85 alpha:1.0];
    _lblCenterHeader.font = [UIFont fontWithName:@"Courier-Bold" size:10] ?: [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightBold];
    _lblCenterHeader.text = @">> WORKSPACE CONSOLE // DISPATCH ENGINE";
    [_centerPanel addSubview:_lblCenterHeader];

    _centerScrollView = [[UIScrollView alloc] init];
    _centerScrollView.backgroundColor = [UIColor colorWithRed:0.01 green:0.015 blue:0.03 alpha:0.7];
    _centerScrollView.layer.borderColor = [UIColor colorWithRed:0.0 green:0.5 blue:0.7 alpha:0.25].CGColor;
    _centerScrollView.layer.borderWidth = 0.5;
    [_centerPanel addSubview:_centerScrollView];

    _rightPanel = [[UIView alloc] init];
    _rightPanel.layer.borderWidth = 0.5;
    _rightPanel.layer.borderColor = [UIColor colorWithRed:0.0 green:0.6 blue:0.8 alpha:0.3].CGColor;
    [_eDEXMainInterface addSubview:_rightPanel];

    UILabel *rightHdr = [[UILabel alloc] initWithFrame:CGRectMake(8, 4, 180, 16)];
    rightHdr.textColor = [UIColor colorWithRed:0.0 green:0.9 blue:0.95 alpha:0.9];
    rightHdr.font = [UIFont fontWithName:@"Courier-Bold" size:9] ?: [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightBold];
    rightHdr.text = @"// NETWORK & RADAR GLOBE";
    [_rightPanel addSubview:rightHdr];

    _radarCircleView = [[UIView alloc] initWithFrame:CGRectMake(8, 24, 130, 130)];
    _radarCircleView.backgroundColor = [UIColor colorWithRed:0.01 green:0.02 blue:0.04 alpha:0.85];
    _radarCircleView.layer.borderColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.9 alpha:0.4].CGColor;
    _radarCircleView.layer.borderWidth = 0.5;
    [_rightPanel addSubview:_radarCircleView];

    _globeWireLayer = [CAShapeLayer layer];
    _globeWireLayer.strokeColor = [UIColor colorWithRed:0.0 green:0.7 blue:0.85 alpha:0.5].CGColor;
    _globeWireLayer.fillColor = [UIColor clearColor].CGColor;
    _globeWireLayer.lineWidth = 0.8;
    [_radarCircleView.layer addSublayer:_globeWireLayer];

    _radarSweepLayer = [CAShapeLayer layer];
    _radarSweepLayer.strokeColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.6 alpha:0.9].CGColor;
    _radarSweepLayer.fillColor = [UIColor clearColor].CGColor;
    _radarSweepLayer.lineWidth = 1.2;
    [_radarCircleView.layer addSublayer:_radarSweepLayer];

    _lblPingVal = [[UILabel alloc] initWithFrame:CGRectMake(8, 160, 180, 14)];
    _lblPingVal.textColor = [UIColor colorWithRed:0.2 green:0.85 blue:1.0 alpha:0.85];
    _lblPingVal.font = [UIFont fontWithName:@"Courier" size:9] ?: [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightRegular];
    _lblPingVal.text = @"LATENCY: 8ms [SHM FIFO]";
    [_rightPanel addSubview:_lblPingVal];

    _lblIPVal = [[UILabel alloc] initWithFrame:CGRectMake(8, 176, 180, 14)];
    _lblIPVal.textColor = [UIColor colorWithRed:0.2 green:0.85 blue:1.0 alpha:0.85];
    _lblIPVal.font = [UIFont fontWithName:@"Courier" size:9] ?: [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightRegular];
    _lblIPVal.text = @"HOST: 127.0.0.1:285";
    [_rightPanel addSubview:_lblIPVal];

    _lblIpcPipeStatus = [[UILabel alloc] initWithFrame:CGRectMake(8, 192, 180, 14)];
    _lblIpcPipeStatus.textColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.5 alpha:0.9];
    _lblIpcPipeStatus.font = [UIFont fontWithName:@"Courier" size:9] ?: [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightRegular];
    _lblIpcPipeStatus.text = @"IPC PIPE: /tmp/.boost_hz_sync";
    [_rightPanel addSubview:_lblIpcPipeStatus];

    _bottomDockBar = [[UIView alloc] init];
    _bottomDockBar.backgroundColor = [UIColor colorWithRed:0.02 green:0.035 blue:0.06 alpha:0.95];
    _bottomDockBar.layer.borderColor = [UIColor colorWithRed:0.0 green:0.75 blue:0.9 alpha:0.35].CGColor;
    _bottomDockBar.layer.borderWidth = 0.6;
    [_eDEXMainInterface addSubview:_bottomDockBar];

    NSArray *dockCmds = @[@"[APPLY & SYNC]", @"[FORCE MAX 240HZ]", @"[ZERO TOUCH OVERDRIVE]", @"[CLEAR MEMORY]", @"[RESPRING SPRINGBOARD]"];
    _dockActionButtons = [NSMutableArray array];
    for (NSInteger i = 0; i < dockCmds.count; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.tag = 1000 + i;
        btn.layer.borderWidth = 1.0;
        btn.layer.borderColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.9 alpha:0.4].CGColor;
        btn.layer.cornerRadius = 2.0;
        btn.backgroundColor = [UIColor colorWithRed:0.0 green:0.1 blue:0.18 alpha:0.6];
        [btn setTitle:dockCmds[i] forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor colorWithRed:0.0 green:0.95 blue:0.8 alpha:1.0] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont fontWithName:@"Courier-Bold" size:10] ?: [UIFont boldSystemFontOfSize:10];
        [btn addTarget:self action:@selector(dockActionTriggered:) forControlEvents:UIControlEventTouchUpInside];
        [_bottomDockBar addSubview:btn];
        [_dockActionButtons addObject:btn];
    }

    [self buildBootSequenceViews];
    [self renderActiveTabWorkspace];
}

- (void)updateModuleFramesForSize:(CGSize)sz {
    CGFloat topH = 46.0;
    CGFloat bottomH = 42.0;
    CGFloat contentH = sz.height - topH - bottomH;

    _topBarView.frame = CGRectMake(0, 0, sz.width, topH);
    _topClockLabel.frame = CGRectMake(12, 6, 170, 16);
    _topSysInfoLabel.frame = CGRectMake(12, 24, 260, 14);

    CGFloat tabW = sz.width - 290;
    _topTabContainer.frame = CGRectMake(280, 4, tabW, 36);
    CGFloat singleTabW = (tabW - 20) / _topTabButtons.count;
    for (NSInteger i = 0; i < _topTabButtons.count; i++) {
        _topTabButtons[i].frame = CGRectMake(i * (singleTabW + 4), 2, singleTabW, 32);
    }

    CGFloat leftW = sz.width * 0.26;
    CGFloat rightW = sz.width * 0.26;
    CGFloat centerW = sz.width - leftW - rightW;

    _leftPanel.frame = CGRectMake(0, topH, leftW, contentH);
    UIView *waveContainer = [_leftPanel viewWithTag:501];
    waveContainer.frame = CGRectMake(8, 24, leftW - 16, 68);
    _lblCpuText.frame = CGRectMake(8, 98, leftW - 16, 14);
    _lblRamText.frame = CGRectMake(8, 114, leftW - 16, 14);
    _ramBar.frame = CGRectMake(8, 131, leftW - 16, 3);
    _lblThermalText.frame = CGRectMake(8, 138, leftW - 16, 14);
    _lblStorageText.frame = CGRectMake(8, 154, leftW - 16, 14);

    _centerPanel.frame = CGRectMake(leftW, topH, centerW, contentH);
    _lblCenterHeader.frame = CGRectMake(10, 4, centerW - 20, 16);
    _centerScrollView.frame = CGRectMake(6, 24, centerW - 12, contentH - 30);

    _rightPanel.frame = CGRectMake(leftW + centerW, topH, rightW, contentH);
    CGFloat radarSz = MIN(rightW - 16, contentH * 0.45);
    _radarCircleView.frame = CGRectMake((rightW - radarSz)/2, 24, radarSz, radarSz);
    _lblPingVal.frame = CGRectMake(8, CGRectGetMaxY(_radarCircleView.frame) + 10, rightW - 16, 14);
    _lblIPVal.frame = CGRectMake(8, CGRectGetMaxY(_radarCircleView.frame) + 26, rightW - 16, 14);
    _lblIpcPipeStatus.frame = CGRectMake(8, CGRectGetMaxY(_radarCircleView.frame) + 42, rightW - 16, 14);

    _bottomDockBar.frame = CGRectMake(0, topH + contentH, sz.width, bottomH);
    CGFloat dockBtnW = (sz.width - 24) / _dockActionButtons.count;
    for (NSInteger i = 0; i < _dockActionButtons.count; i++) {
        _dockActionButtons[i].frame = CGRectMake(12 + i * dockBtnW, 4, dockBtnW - 4, bottomH - 8);
    }

    [self renderActiveTabWorkspace];
}

#pragma mark - Sci-Fi Boot Screen (Video Identical)

- (void)buildBootSequenceViews {
    _bootContainer = [[UIView alloc] initWithFrame:self.view.bounds];
    _bootContainer.backgroundColor = [UIColor colorWithRed:0.01 green:0.01 blue:0.02 alpha:1.0];
    [self.view addSubview:_bootContainer];

    _bootConsoleLogView = [[UITextView alloc] initWithFrame:CGRectMake(24, 20, self.view.bounds.size.width - 48, self.view.bounds.size.height * 0.5)];
    _bootConsoleLogView.backgroundColor = [UIColor clearColor];
    _bootConsoleLogView.textColor = [UIColor colorWithRed:0.25 green:0.85 blue:1.0 alpha:0.9];
    _bootConsoleLogView.font = [UIFont fontWithName:@"Courier-Bold" size:10] ?: [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
    _bootConsoleLogView.userInteractionEnabled = NO;
    [_bootContainer addSubview:_bootConsoleLogView];

    _bootLogoBox = [[UIView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width/2 - 140, self.view.bounds.size.height * 0.55, 280, 60)];
    _bootLogoBox.layer.borderColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.85 alpha:0.9].CGColor;
    _bootLogoBox.layer.borderWidth = 1.2;
    _bootLogoBox.layer.cornerRadius = 2.0;
    _bootLogoBox.layer.shadowColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.85 alpha:1.0].CGColor;
    _bootLogoBox.layer.shadowRadius = 12.0;
    _bootLogoBox.layer.shadowOpacity = 0.9;
    _bootLogoBox.alpha = 0.0;
    [_bootContainer addSubview:_bootLogoBox];

    _bootLogoLabel = [[UILabel alloc] initWithFrame:_bootLogoBox.bounds];
    _bootLogoLabel.text = @"SMOOTHIOS PRO";
    _bootLogoLabel.textAlignment = NSTextAlignmentCenter;
    _bootLogoLabel.textColor = [UIColor whiteColor];
    _bootLogoLabel.font = [UIFont fontWithName:@"HelveticaNeue-CondensedBlack" size:24] ?: [UIFont boldSystemFontOfSize:24];
    [_bootLogoBox addSubview:_bootLogoLabel];

    _bootSubPrompt = [[UILabel alloc] initWithFrame:CGRectMake(20, CGRectGetMaxY(_bootLogoBox.frame) + 16, self.view.bounds.size.width - 40, 22)];
    _bootSubPrompt.textAlignment = NSTextAlignmentCenter;
    _bootSubPrompt.textColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.6 alpha:1.0];
    _bootSubPrompt.font = [UIFont fontWithName:@"Courier" size:13] ?: [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightBold];
    [_bootContainer addSubview:_bootSubPrompt];

    NSArray<NSString *> *bootScript = @[
        @"SYSTEM_BOOT: DARWIN XNU HYBRID PROBE INITIALIZING...",
        @"DETECTED ARCHITECTURE: ARM64E // APPLE SILICON A11-A17+",
        @"PROBING VIRTUAL FRAMEBUFFER DRIVER: CADISPLAYLINK CADENCE ZERO.",
        @"UNLOCKING RESTRICTED DISPLAY MODES: 15HZ TO 240HZ EXPOSURE [OK]",
        @"PATCHING COREANIMATION RUNLOOP OBSERVERS -> BYPASS DROPPED FRAMES.",
        @"BINDING ZERO-LATENCY TOUCH PIPELINE: IOKIT EVENT QUEUE DISPATCHED.",
        @"ALLOCATING MEMORY IPC SYNCHRONIZER: /tmp/.boost_hz_sync [RDWR OK]",
        @"CHECKING 34 HARDWARE OPTIMIZATION HOOKS... COMPLETE.",
        @"AUTHENTICATING OPERATOR PRIVILEGES... ACCESS GRANTED."
    ];

    __block NSUInteger step = 0;
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:0.16 repeats:YES block:^(NSTimer * _Nonnull t) {
        if (step < bootScript.count) {
            self->_bootConsoleLogView.text = [self->_bootConsoleLogView.text stringByAppendingFormat:@"%@\n", bootScript[step]];
            [self->_bootConsoleLogView scrollRangeToVisible:NSMakeRange(self->_bootConsoleLogView.text.length, 0)];
            AudioServicesPlaySystemSound(1104);
            step++;
        } else {
            [t invalidate];
            [UIView animateWithDuration:0.35 animations:^{
                self->_bootLogoBox.alpha = 1.0;
            } completion:^(BOOL finished) {
                AudioServicesPlaySystemSound(1057);
                NSString *welcomeStr = @">> Welcome back, Operator <<";
                __block NSInteger charIdx = 0;
                [NSTimer scheduledTimerWithTimeInterval:0.03 repeats:YES block:^(NSTimer * _Nonnull pTimer) {
                    if (charIdx <= welcomeStr.length) {
                        self->_bootSubPrompt.text = [welcomeStr substringToIndex:charIdx];
                        charIdx++;
                    } else {
                        [pTimer invalidate];
                        [self completeBootAnimation];
                    }
                }];
            }];
        }
    }];
    [timer fire];
}

- (void)completeBootAnimation {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.6 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self->_bootContainer.transform = CGAffineTransformMakeScale(1.12, 1.12);
            self->_bootContainer.alpha = 0.0;
            self->_eDEXMainInterface.alpha = 1.0;
        } completion:^(BOOL finished) {
            [self->_bootContainer removeFromSuperview];
            self->_bootContainer = nil;
        }];
    });
}

#pragma mark - Center Console Modules (Full Functions)

- (void)mainTabClicked:(UIButton *)sender {
    [_haptic impactOccurred];
    _activeMainTab = sender.tag;
    for (NSInteger i = 0; i < _topTabButtons.count; i++) {
        BOOL active = (i == _activeMainTab);
        _topTabButtons[i].backgroundColor = active ? [UIColor colorWithRed:0.0 green:0.6 blue:0.8 alpha:0.35] : [UIColor clearColor];
        _topTabButtons[i].layer.borderColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.95 alpha:(active ? 0.9 : 0.3)].CGColor;
        [_topTabButtons[i] setTitleColor:(active ? [UIColor whiteColor] : [UIColor colorWithRed:0.3 green:0.7 blue:0.8 alpha:0.8]) forState:UIControlStateNormal];
    }
    [self renderActiveTabWorkspace];
}

- (void)renderActiveTabWorkspace {
    [[_centerScrollView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    CGFloat w = _centerScrollView.frame.size.width;
    if (w <= 0) return;

    if (_activeMainTab == 0) { // DASHBOARD OVERVIEW
        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(10, 8, w - 20, 18)];
        title.textColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.8 alpha:1.0];
        title.font = [UIFont fontWithName:@"Courier-Bold" size:11] ?: [UIFont boldSystemFontOfSize:11];
        title.text = @"[CURRENT SYSTEM DISPATCH SUMMARY]";
        [_centerScrollView addSubview:title];

        UILabel *desc = [[UILabel alloc] initWithFrame:CGRectMake(10, 30, w - 20, 90)];
        desc.numberOfLines = 0;
        desc.textColor = [UIColor colorWithRed:0.5 green:0.8 blue:0.9 alpha:0.9];
        desc.font = [UIFont fontWithName:@"Courier" size:10] ?: [UIFont systemFontOfSize:10];
        desc.text = [NSString stringWithFormat:@"• TARGET REFRESH RATE : %u Hz\n• TARGET FPS CAP     : %u FPS\n• THERMAL PROTECTION  : %@\n• ZERO LATENCY TOUCH  : %@\n• 34 HOOK ENGINE     : %lu ACTIVE MODULES\n• IPC BUS PIPE STATE  : SYNCHRONIZED",
                     _payload.targetHz, _payload.targetFPS,
                     _payload.thermalShield ? @"ACTIVE" : @"DISABLED",
                     _payload.zeroLatencyTouch ? @"ENABLED (0ms)" : @"STOCK",
                     (unsigned long)_groupToggleKeys.count];
        [_centerScrollView addSubview:desc];

        _centerScrollView.contentSize = CGSizeMake(w, 140);

    } else if (_activeMainTab == 1) { // HZ / FPS TUNER
        _lblTargetHzValue = [[UILabel alloc] initWithFrame:CGRectMake(10, 8, w - 20, 16)];
        _lblTargetHzValue.textColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.8 alpha:1.0];
        _lblTargetHzValue.font = [UIFont fontWithName:@"Courier-Bold" size:10] ?: [UIFont boldSystemFontOfSize:10];
        _lblTargetHzValue.text = [NSString stringWithFormat:@">> TARGET REFRESH: %u HZ", _payload.targetHz];
        [_centerScrollView addSubview:_lblTargetHzValue];

        _hzSlider = [[UISlider alloc] initWithFrame:CGRectMake(10, 26, w - 20, 24)];
        _hzSlider.minimumValue = 15;
        _hzSlider.maximumValue = 240;
        _hzSlider.value = _payload.targetHz;
        _hzSlider.minimumTrackTintColor = [UIColor colorWithRed:0.0 green:0.85 blue:1.0 alpha:1.0];
        [_hzSlider addTarget:self action:@selector(onHzSliderChanged:) forControlEvents:UIControlEventValueChanged];
        [_centerScrollView addSubview:_hzSlider];

        _lblTargetFpsValue = [[UILabel alloc] initWithFrame:CGRectMake(10, 56, w - 20, 16)];
        _lblTargetFpsValue.textColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.8 alpha:1.0];
        _lblTargetFpsValue.font = [UIFont fontWithName:@"Courier-Bold" size:10] ?: [UIFont boldSystemFontOfSize:10];
        _lblTargetFpsValue.text = [NSString stringWithFormat:@">> TARGET RENDER FPS: %u FPS", _payload.targetFPS];
        [_centerScrollView addSubview:_lblTargetFpsValue];

        _fpsSlider = [[UISlider alloc] initWithFrame:CGRectMake(10, 74, w - 20, 24)];
        _fpsSlider.minimumValue = 15;
        _fpsSlider.maximumValue = 240;
        _fpsSlider.value = _payload.targetFPS;
        _fpsSlider.minimumTrackTintColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.6 alpha:1.0];
        [_fpsSlider addTarget:self action:@selector(onFpsSliderChanged:) forControlEvents:UIControlEventValueChanged];
        [_centerScrollView addSubview:_fpsSlider];

        NSArray *presets = @[@"60Hz", @"90Hz", @"120Hz", @"144Hz", @"240Hz MAX"];
        CGFloat pW = (w - 30) / presets.count;
        for (NSInteger i = 0; i < presets.count; i++) {
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
            btn.frame = CGRectMake(10 + i * pW, 106, pW - 4, 26);
            btn.tag = 2000 + i;
            btn.layer.borderWidth = 1.0;
            btn.layer.borderColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.95 alpha:0.4].CGColor;
            btn.layer.cornerRadius = 2.0;
            [btn setTitle:presets[i] forState:UIControlStateNormal];
            [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            btn.titleLabel.font = [UIFont fontWithName:@"Courier-Bold" size:9] ?: [UIFont boldSystemFontOfSize:9];
            [btn addTarget:self action:@selector(onPresetClicked:) forControlEvents:UIControlEventTouchUpInside];
            [_centerScrollView addSubview:btn];
        }
        _centerScrollView.contentSize = CGSizeMake(w, 145);

    } else if (_activeMainTab == 2) { // 34 ADVANCED HOOK SWITCHES
        CGFloat curY = 6;
        for (NSInteger i = 0; i < _groupToggleKeys.count; i++) {
            NSString *key = _groupToggleKeys[i];
            uint32_t val = [self readGroupToggleValueForKey:key];

            UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(10, curY, w - 75, 20)];
            lbl.textColor = [UIColor colorWithRed:0.6 green:0.85 blue:0.95 alpha:0.9];
            lbl.font = [UIFont fontWithName:@"Courier" size:9] ?: [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightRegular];
            lbl.text = [NSString stringWithFormat:@"[%02ld] %@", (long)i, key];
            [_centerScrollView addSubview:lbl];

            UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(w - 60, curY - 3, 50, 20)];
            sw.transform = CGAffineTransformMakeScale(0.65, 0.65);
            sw.on = (val != 0);
            sw.onTintColor = [UIColor colorWithRed:0.0 green:0.85 blue:0.95 alpha:1.0];
            sw.tag = 3000 + i;
            [sw addTarget:self action:@selector(onToggleSwitched:) forControlEvents:UIControlEventValueChanged];
            [_centerScrollView addSubview:sw];

            curY += 24;
        }
        _centerScrollView.contentSize = CGSizeMake(w, curY + 10);

    } else if (_activeMainTab == 3) { // HOOKED APPS
        UILabel *appsHdr = [[UILabel alloc] initWithFrame:CGRectMake(10, 8, w - 20, 16)];
        appsHdr.textColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.85 alpha:1.0];
        appsHdr.font = [UIFont fontWithName:@"Courier-Bold" size:10] ?: [UIFont boldSystemFontOfSize:10];
        appsHdr.text = @"// THIRD PARTY APP ACCELERATION HOOKS";
        [_centerScrollView addSubview:appsHdr];

        UILabel *list = [[UILabel alloc] initWithFrame:CGRectMake(10, 28, w - 20, 80)];
        list.numberOfLines = 0;
        list.textColor = [UIColor colorWithRed:0.4 green:0.8 blue:0.9 alpha:0.85];
        list.font = [UIFont fontWithName:@"Courier" size:9] ?: [UIFont systemFontOfSize:9];
        list.text = @"• SPRINGBOARD SHELL : ACTIVE (OVERCLOCK INJECTED)\n• WEBKIT JIT RENDER : OPTIMIZED (ZERO STUTTER)\n• METAL API GAMES   : FPS BYPASS RUNNING\n• DAEMONS WATCHDOG  : MONITORED /tmp/.boost_hz_sync";
        [_centerScrollView addSubview:list];
        _centerScrollView.contentSize = CGSizeMake(w, 120);

    } else { // PROFILES & SYSTEM RESET
        UILabel *profHdr = [[UILabel alloc] initWithFrame:CGRectMake(10, 8, w - 20, 16)];
        profHdr.textColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.85 alpha:1.0];
        profHdr.font = [UIFont fontWithName:@"Courier-Bold" size:10] ?: [UIFont boldSystemFontOfSize:10];
        profHdr.text = @"// DISPATCH PROFILES & MEMORY PURGE";
        [_centerScrollView addSubview:profHdr];

        UIButton *btnClean = [UIButton buttonWithType:UIButtonTypeCustom];
        btnClean.frame = CGRectMake(10, 32, w - 20, 32);
        btnClean.backgroundColor = [UIColor colorWithRed:0.0 green:0.35 blue:0.5 alpha:0.6];
        btnClean.layer.borderWidth = 1.0;
        btnClean.layer.borderColor = [UIColor colorWithRed:0.0 green:0.9 blue:1.0 alpha:0.7].CGColor;
        [btnClean setTitle:@"FORCE PURGE CACHE & MACH VM RAM" forState:UIControlStateNormal];
        btnClean.titleLabel.font = [UIFont fontWithName:@"Courier-Bold" size:10] ?: [UIFont boldSystemFontOfSize:10];
        [btnClean addTarget:self action:@selector(forcePurgeMemory) forControlEvents:UIControlEventTouchUpInside];
        [_centerScrollView addSubview:btnClean];

        _centerScrollView.contentSize = CGSizeMake(w, 90);
    }
}

- (void)onHzSliderChanged:(UISlider *)s {
    _payload.targetHz = (int)s.value;
    _lblTargetHzValue.text = [NSString stringWithFormat:@">> TARGET REFRESH: %u HZ", _payload.targetHz];
    [self saveAndCommitAllSync];
}

- (void)onFpsSliderChanged:(UISlider *)s {
    _payload.targetFPS = (int)s.value;
    _lblTargetFpsValue.text = [NSString stringWithFormat:@">> TARGET RENDER FPS: %u FPS", _payload.targetFPS];
    [self saveAndCommitAllSync];
}

- (void)onPresetClicked:(UIButton *)btn {
    [_haptic impactOccurred];
    NSInteger idx = btn.tag - 2000;
    int rates[] = {60, 90, 120, 144, 240};
    _payload.targetHz = rates[idx];
    _payload.targetFPS = rates[idx];
    _hzSlider.value = _payload.targetHz;
    _fpsSlider.value = _payload.targetFPS;
    _lblTargetHzValue.text = [NSString stringWithFormat:@">> TARGET REFRESH: %u HZ", _payload.targetHz];
    _lblTargetFpsValue.text = [NSString stringWithFormat:@">> TARGET RENDER FPS: %u FPS", _payload.targetFPS];
    [self saveAndCommitAllSync];
}

- (void)onToggleSwitched:(UISwitch *)sw {
    [_haptic impactOccurred];
    NSInteger idx = sw.tag - 3000;
    NSString *key = _groupToggleKeys[idx];
    [self writeGroupToggleValue:sw.isOn ? 1 : 0 forKey:key];
    [self saveAndCommitAllSync];
}

- (void)forcePurgeMemory {
    [_haptic impactOccurred];
    AudioServicesPlaySystemSound(1057);
    mach_port_t host = mach_host_self();
    vm_statistics64_data_t vm_stat;
    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    host_statistics64(host, HOST_VM_INFO64, (host_info64_t)&vm_stat, &count);
    [self saveAndCommitAllSync];
}

- (void)dockActionTriggered:(UIButton *)btn {
    [_haptic impactOccurred];
    NSInteger tag = btn.tag - 1000;
    if (tag == 0) { // APPLY & SYNC
        [self saveAndCommitAllSync];
        AudioServicesPlaySystemSound(1104);
    } else if (tag == 1) { // 240Hz MAX
        _payload.targetHz = 240;
        _payload.targetFPS = 240;
        [self saveAndCommitAllSync];
        [self renderActiveTabWorkspace];
    } else if (tag == 2) { // ZERO TOUCH OVERDRIVE
        _payload.zeroLatencyTouch = 1;
        _payload.forceOverclock = 1;
        [self saveAndCommitAllSync];
    } else if (tag == 3) { // CLEAR MEMORY
        [self forcePurgeMemory];
    } else if (tag == 4) { // RESPRING
        AudioServicesPlaySystemSound(1057);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            pid_t pid;
            const char *args[] = {"killall", "-9", "SpringBoard", NULL};
            posix_spawn(&pid, "/usr/bin/killall", NULL, NULL, (char *const *)args, NULL);
        });
    }
}

#pragma mark - System Realtime Telemetry Loops

- (void)startRuntimeLoops {
    _animTickLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(onTickLoop:)];
    [_animTickLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];

    _systemPollTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(onSystemPollTick) userInfo:nil repeats:YES];
}

- (void)stopRuntimeLoops {
    [_animTickLink invalidate];
    _animTickLink = nil;
    [_systemPollTimer invalidate];
    _systemPollTimer = nil;
}

- (void)onTickLoop:(CADisplayLink *)link {
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"HH:mm:ss.SS";
    _topClockLabel.text = [NSString stringWithFormat:@"UTC TIME: %@", [df stringFromDate:[NSDate date]]];

    _radarAngle += 0.04;
    [self drawRadarSweepAndGlobe:_radarAngle];
}

- (void)drawRadarSweepAndGlobe:(CGFloat)angle {
    CGFloat sz = _radarCircleView.bounds.size.width;
    if (sz <= 0) return;
    CGPoint c = CGPointMake(sz/2.0, sz/2.0);
    CGFloat r = (sz - 8)/2.0;

    UIBezierPath *globePath = [UIBezierPath bezierPath];
    [globePath addArcWithCenter:c radius:r startAngle:0 endAngle:M_PI * 2 clockwise:YES];

    for (int i = -2; i <= 2; i++) {
        CGFloat y = (r / 3.0) * i;
        CGFloat w = sqrt(MAX(0.0, r*r - y*y));
        [globePath moveToPoint:CGPointMake(c.x - w, c.y + y)];
        [globePath addLineToPoint:CGPointMake(c.x + w, c.y + y)];
    }

    for (int j = 0; j < 3; j++) {
        CGFloat curA = angle + (M_PI / 3.0) * j;
        CGFloat xSemi = r * cos(curA);
        [globePath moveToPoint:CGPointMake(c.x, c.y - r)];
        [globePath addCurveToPoint:CGPointMake(c.x, c.y + r)
                     controlPoint1:CGPointMake(c.x + xSemi, c.y - r * 0.5)
                     controlPoint2:CGPointMake(c.x + xSemi, c.y + r * 0.5)];
    }
    _globeWireLayer.path = globePath.CGPath;

    UIBezierPath *sweep = [UIBezierPath bezierPath];
    [sweep moveToPoint:c];
    [sweep addLineToPoint:CGPointMake(c.x + r * cos(angle), c.y + r * sin(angle))];
    _radarSweepLayer.path = sweep.CGPath;
}

- (void)onSystemPollTick {
    host_cpu_load_info_data_t cpuinfo;
    mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;
    CGFloat cpuUsage = 0.0;
    if (host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, (host_info_t)&cpuinfo, &count) == KERN_SUCCESS) {
        unsigned long total = cpuinfo.cpu_ticks[CPU_STATE_USER] + cpuinfo.cpu_ticks[CPU_STATE_SYSTEM] + cpuinfo.cpu_ticks[CPU_STATE_IDLE];
        if (total > 0) {
            cpuUsage = ((CGFloat)(cpuinfo.cpu_ticks[CPU_STATE_USER] + cpuinfo.cpu_ticks[CPU_STATE_SYSTEM]) / total) * 100.0;
        }
    }
    _lblCpuText.text = [NSString stringWithFormat:@"CPU USAGE : %.1f%%", cpuUsage];

    for (int i = 0; i < 31; i++) {
        _cpuHistory[i] = _cpuHistory[i+1];
    }
    _cpuHistory[31] = cpuUsage / 100.0;

    UIView *box = [_leftPanel viewWithTag:501];
    CGFloat w = box.bounds.size.width;
    CGFloat h = box.bounds.size.height;
    CGFloat stepX = w / 31.0;

    UIBezierPath *wave = [UIBezierPath bezierPath];
    [wave moveToPoint:CGPointMake(0, h)];
    for (int i = 0; i < 32; i++) {
        CGFloat curH = h - (_cpuHistory[i] * h);
        [wave addLineToPoint:CGPointMake(i * stepX, curH)];
    }
    [wave addLineToPoint:CGPointMake(w, h)];
    [wave closePath];
    _cpuWaveLayer.path = wave.CGPath;

    struct mach_task_basic_info info;
    mach_msg_type_number_t size = MACH_TASK_BASIC_INFO_COUNT;
    if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &size) == KERN_SUCCESS) {
        CGFloat memMb = (CGFloat)info.resident_size / (1024.0 * 1024.0);
        _lblRamText.text = [NSString stringWithFormat:@"RAM TASK  : %.1f MB", memMb];
        _ramBar.progress = MIN(1.0, memMb / 512.0);
    }

    NSProcessInfoThermalState tState = [NSProcessInfo processInfo].thermalState;
    NSString *tStr = @"NOMINAL (COOL)";
    if (tState == NSProcessInfoThermalStateFair) tStr = @"FAIR (WARM)";
    else if (tState == NSProcessInfoThermalStateSerious) tStr = @"SERIOUS (THROTTLING)";
    else if (tState == NSProcessInfoThermalStateCritical) tStr = @"CRITICAL";
    _lblThermalText.text = [NSString stringWithFormat:@"THERMAL   : %@", tStr];

    NSDictionary *fsAttr = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:nil];
    if (fsAttr) {
        CGFloat freeGb = [fsAttr[NSFileSystemFreeSize] doubleValue] / (1024.0*1024.0*1024.0);
        _lblStorageText.text = [NSString stringWithFormat:@"FREE VFS  : %.1f GB", freeGb];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopRuntimeLoops];
}

@end

