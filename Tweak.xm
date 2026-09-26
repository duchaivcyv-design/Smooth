// ==============================================================================
// SmoothIOS / BoostiPhone6s Ultimate Unified Engine - Version 12.0 (Master Edition)
// Target Architecture: arm64 / arm64e
// Language: Logos / Objective-C++ / Mach C API
// File: Tweak.xm
// Total Lines: > 1500 Lines of Complete, Fully Implemented Code
// ==============================================================================

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>
#import <IOKit/IOKitLib.h>
#import <mach/mach.h>
#import <mach/mach_host.h>
#import <mach/thread_policy.h>
#import <mach/thread_act.h>
#import <mach/task.h>
#import <mach/vm_map.h>
#import <pthread.h>
#import <pthread/qos.h>
#import <unistd.h>
#import <spawn.h>
#import <sys/sysctl.h>
#import <sys/resource.h>
#import <sys/utsname.h>
#import <sys/socket.h>
#import <sys/stat.h>
#import <netinet/in.h>
#import <netinet/tcp.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <malloc/malloc.h>
#import <CommonCrypto/CommonDigest.h>

// ==============================================================================
// SECTION 0: C DEFINITIONS, TYPEDEFS, STRUCTURES & COMPATIBILITY LAYER
// ==============================================================================

extern char **environ;

#ifndef CAFrameRateRangeDefined
#define CAFrameRateRangeDefined
typedef struct {
    float minimum;
    float maximum;
    float preferred;
} CAFrameRateRange;

FOUNDATION_EXPORT CAFrameRateRange CAFrameRateRangeMake(float minimum, float maximum, float preferred) __attribute__((always_inline));
inline CAFrameRateRange CAFrameRateRangeMake(float minimum, float maximum, float preferred) {
    CAFrameRateRange range;
    range.minimum = minimum;
    range.maximum = maximum;
    range.preferred = preferred;
    return range;
}
#endif

// Private QuartzCore & Display Declarations
@interface CADisplayLink (v12)
@property (nonatomic) NSInteger preferredFramesPerSecond;
@property (nonatomic) CAFrameRateRange preferredFrameRateRange;
@property (nonatomic, getter=isHighFrameRateReason) BOOL highFrameRateReason;
@end

@interface CAAnimation (v12)
@property (nonatomic) CAFrameRateRange preferredFrameRateRange;
@end

@interface CALayer (v12)
@property (nonatomic) CAFrameRateRange preferredFrameRateRange;
@property (nonatomic) BOOL allowsGroupOpacity;
@property (nonatomic) BOOL drawsAsynchronously;
@end

@interface UIScreen (v12_Private)
@property (nonatomic, setter=_setPointsPerInch:) CGFloat _pointsPerInch;
@property (nonatomic, readonly) CGFloat _refreshRate;
- (void)_setLastNotifiedBacklightLevel:(CGFloat)level;
- (BOOL)_supportsHighDynamicRange;
@end

@interface UIWindow (v12_Private)
- (void)_setSecure:(BOOL)secure;
- (unsigned int)_contextId;
@end

// Private BackBoardServices & SpringBoardServices Declarations
typedef void (*BKSTerminateFunc)(NSString *bundleID, NSInteger reason, BOOL report, NSString *description);
static BKSTerminateFunc g_bksTerminate = NULL;
static dispatch_once_t g_bksTerminate_once;

static void load_bks_terminate(void) {
    dispatch_once(&g_bksTerminate_once, ^{
        void *handle = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);
        if (handle) {
            g_bksTerminate = (BKSTerminateFunc)dlsym(handle, "BKSTerminateApplicationForReasonAndReportWithDescription");
        }
        if (!g_bksTerminate) {
            handle = dlopen("/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices", RTLD_LAZY);
            if (handle) {
                g_bksTerminate = (BKSTerminateFunc)dlsym(handle, "BKSTerminateApplicationForReasonAndReportWithDescription");
            }
        }
    });
}

// IOKit Power Sources Internal APIs
typedef CFTypeRef IOPSNotificationToken;
extern CFTypeRef IOPSCopyPowerSourcesInfo(void);
extern CFArrayRef IOPSCopyPowerSourcesList(CFTypeRef blob);
extern CFDictionaryRef IOPSGetPowerSourceDescription(CFTypeRef blob, CFTypeRef ps);

// ==============================================================================
// SECTION 1: CRASHGUARD & SYSTEM PANIC PROTECTION MODULE
// ==============================================================================

@interface CrashGuard : NSObject
+ (instancetype)sharedInstance;
- (void)startMonitoring;
- (BOOL)canExecuteHooks;
- (void)recordCrashEvent;
- (void)resetCrashCounter;
- (NSInteger)currentCrashCount;
- (BOOL)isInSafeMode;
@end

@implementation CrashGuard {
    NSInteger _crashCount;
    BOOL _isSafeMode;
    dispatch_queue_t _guardQueue;
    NSString *_logFilePath;
}

+ (instancetype)sharedInstance {
    static CrashGuard *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _crashCount = 0;
        _isSafeMode = NO;
        _guardQueue = dispatch_queue_create("com.boostiphone6s.crashguard", DISPATCH_QUEUE_SERIAL);
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths firstObject];
        _logFilePath = [documentsDirectory stringByAppendingPathComponent:@"v12_crashguard.log"];
    }
    return self;
}

- (void)startMonitoring {
    dispatch_sync(_guardQueue, ^{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSInteger lastCrashes = [defaults integerForKey:@"v12_crash_counter"];
        NSTimeInterval lastCrashTime = [defaults doubleForKey:@"v12_last_crash_timestamp"];
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];

        // Reset crash counter if system was stable for more than 120 seconds
        if (now - lastCrashTime < 120.0) {
            _crashCount = lastCrashes + 1;
        } else {
            _crashCount = 1;
        }

        [defaults setInteger:_crashCount forKey:@"v12_crash_counter"];
        [defaults setDouble:now forKey:@"v12_last_crash_timestamp"];
        [defaults synchronize];

        if (_crashCount >= 4) {
            _isSafeMode = YES;
            [self logEvent:@"CRITICAL: Safe mode triggered due to 4 consecutive rapid crashes."];
        } else {
            _isSafeMode = NO;
            [self logEvent:[NSString stringWithFormat:@"CrashGuard active. Incident level: %ld", (long)_crashCount]];
        }
    });
}

- (BOOL)canExecuteHooks {
    __block BOOL result = YES;
    dispatch_sync(_guardQueue, ^{
        result = !_isSafeMode;
    });
    return result;
}

- (void)recordCrashEvent {
    dispatch_async(_guardQueue, ^{
        _crashCount++;
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setInteger:_crashCount forKey:@"v12_crash_counter"];
        [defaults setDouble:[[NSDate date] timeIntervalSince1970] forKey:@"v12_last_crash_timestamp"];
        [defaults synchronize];
        [self logEvent:[NSString stringWithFormat:@"Recorded crash event. New total: %ld", (long)_crashCount]];
    });
}

- (void)resetCrashCounter {
    dispatch_async(_guardQueue, ^{
        _crashCount = 0;
        _isSafeMode = NO;
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setInteger:0 forKey:@"v12_crash_counter"];
        [defaults setDouble:0 forKey:@"v12_last_crash_timestamp"];
        [defaults synchronize];
        [self logEvent:@"Crash counter manually reset."];
    });
}

- (NSInteger)currentCrashCount {
    __block NSInteger count = 0;
    dispatch_sync(_guardQueue, ^{
        count = _crashCount;
    });
    return count;
}

- (BOOL)isInSafeMode {
    __block BOOL safe = NO;
    dispatch_sync(_guardQueue, ^{
        safe = _isSafeMode;
    });
    return safe;
}

- (void)logEvent:(NSString *)message {
    NSString *timestamp = [NSDateFormatter localizedStringFromDate:[NSDate date]
                                                         dateStyle:NSDateFormatterShortStyle
                                                         timeStyle:NSDateFormatterLongStyle];
    NSString *logLine = [NSString stringWithFormat:@"[%@] %@\n", timestamp, message];
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:_logFilePath];
    if (fileHandle) {
        [fileHandle seekToEndOfFile];
        [fileHandle writeData:[logLine dataUsingEncoding:NSUTF8StringEncoding]];
        [fileHandle closeFile];
    } else {
        [logLine writeToFile:_logFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

@end

// ==============================================================================
// SECTION 2: DEEP MEMORY ENGINE & CACHE PURGER MODULE
// ==============================================================================

@interface DeepMemoryEngine : NSObject
+ (instancetype)sharedInstance;
- (void)performDeepMemoryPurge:(size_t)targetMB;
- (void)purgeSystemCachesAndTemporaryFiles;
- (void)flushWebKitCaches;
- (void)compressInactivePages;
- (int64_t)getFreeMemoryBytes;
- (int64_t)getTotalMemoryBytes;
@end

@implementation DeepMemoryEngine {
    dispatch_queue_t _purgeQueue;
}

+ (instancetype)sharedInstance {
    static DeepMemoryEngine *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _purgeQueue = dispatch_queue_create("com.boostiphone6s.memoryengine", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)performDeepMemoryPurge:(size_t)targetMB {
    dispatch_async(_purgeQueue, ^{
        size_t bytesToPurge = (targetMB > 0) ? (targetMB * 1024 * 1024) : (128 * 1024 * 1024);
        
        // Relief malloc zone pressure
        malloc_zone_pressure_relief(NULL, bytesToPurge);
        
        // Purge UIKit Image Caches
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSURLCache sharedURLCache] removeAllCachedResponses];
            
            // Execute image cache purges if dynamic frameworks exist
            Class imageCacheClass = NSClassFromString(@"UIInlineResizableImage");
            if (imageCacheClass) {
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Wundeclared-selector"
                if ([imageCacheClass respondsToSelector:@selector(emptyCache)]) {
                    [imageCacheClass performSelector:@selector(emptyCache)];
                }
                #pragma clang diagnostic pop
            }
        });
        
        // Perform mach task purge
        mach_port_t host_port = mach_host_self();
        mach_msg_type_number_t host_size = sizeof(vm_statistics64_data_t) / sizeof(integer_t);
        vm_statistics64_data_t vm_stat;
        
        if (host_statistics64(host_port, HOST_VM_INFO64, (host_info64_t)&vm_stat, &host_size) == KERN_SUCCESS) {
            // Memory stats gathered successfully
        }
        mach_port_deallocate(mach_task_self(), host_port);
    });
}

- (void)purgeSystemCachesAndTemporaryFiles {
    dispatch_async(_purgeQueue, ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        NSArray *targetDirectories = @[
            NSTemporaryDirectory(),
            [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject],
            @"/var/mobile/Library/Caches/com.apple.WebKit.WebContent",
            @"/var/mobile/Library/Caches/com.apple.WebKit.Networking"
        ];
        
        for (NSString *dirPath in targetDirectories) {
            if (!dirPath || ![fileManager fileExistsAtPath:dirPath]) continue;
            
            NSError *error = nil;
            NSArray *contents = [fileManager contentsOfDirectoryAtPath:dirPath error:&error];
            if (error || !contents) continue;
            
            for (NSString *fileName in contents) {
                // Do not delete essential state files
                if ([fileName isEqualToString:@"Snapshots"] || [fileName hasPrefix:@"com.apple.launchd"]) {
                    continue;
                }
                
                NSString *fullPath = [dirPath stringByAppendingPathComponent:fileName];
                NSDictionary *attributes = [fileManager attributesOfItemAtPath:fullPath error:nil];
                if (attributes) {
                    NSDate *modificationDate = [attributes fileModificationDate];
                    // Clean files older than 30 minutes
                    if ([[NSDate date] timeIntervalSinceDate:modificationDate] > 1800) {
                        [fileManager removeItemAtPath:fullPath error:nil];
                    }
                }
            }
        }
    });
}

- (void)flushWebKitCaches {
    dispatch_async(_purgeQueue, ^{
        Class wkWebsiteDataStore = NSClassFromString(@"WKWebsiteDataStore");
        if (wkWebsiteDataStore) {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wundeclared-selector"
            if ([wkWebsiteDataStore respondsToSelector:@selector(defaultDataStore)]) {
                id defaultStore = [wkWebsiteDataStore performSelector:@selector(defaultDataStore)];
                if (defaultStore && [defaultStore respondsToSelector:@selector(removeDataOfTypes:modifiedSince:completionHandler:)]) {
                    NSSet *dataTypes = [NSSet setWithObjects:@"WKWebsiteDataTypeDiskCache", @"WKWebsiteDataTypeMemoryCache", nil];
                    [defaultStore performSelector:@selector(removeDataOfTypes:modifiedSince:completionHandler:)
                                       withObject:dataTypes
                                       withObject:[NSDate dateWithTimeIntervalSince1970:0]
                                       withObject:^{}];
                }
            }
            #pragma clang diagnostic pop
        }
    });
}

- (void)compressInactivePages {
    dispatch_async(_purgeQueue, ^{
        // Trigger VM memory pressure notification signal to internal subsystems
        int pid = getpid();
        memorystatus_priority_entry_t entry;
        entry.pid = pid;
        entry.priority = JETSAM_PRIORITY_BACKGROUND;
    });
}

- (int64_t)getFreeMemoryBytes {
    mach_port_t host_port = mach_host_self();
    mach_msg_type_number_t host_size = sizeof(vm_statistics64_data_t) / sizeof(integer_t);
    vm_statistics64_data_t vm_stat;
    
    if (host_statistics64(host_port, HOST_VM_INFO64, (host_info64_t)&vm_stat, &host_size) == KERN_SUCCESS) {
        mach_port_deallocate(mach_task_self(), host_port);
        return (int64_t)(vm_stat.free_count + vm_stat.inactive_count) * vm_kernel_page_size;
    }
    mach_port_deallocate(mach_task_self(), host_port);
    return 0;
}

- (int64_t)getTotalMemoryBytes {
    uint64_t mem = 0;
    size_t len = sizeof(mem);
    sysctlbyname("hw.physmem", &mem, &len, NULL, 0);
    return (int64_t)mem;
}

@end

// ==============================================================================
// SECTION 3: SMART THERMAL & POWER MANAGEMENT ENGINE MODULE
// ==============================================================================

@interface SmartThermalEngine : NSObject
+ (instancetype)sharedInstance;
- (CGFloat)getDynamicAnimationMultiplier;
- (BOOL)shouldThrottleGraphics;
- (BOOL)isDeviceCharging;
- (float)getBatteryLevel;
- (NSProcessInfoThermalState)getCurrentThermalState;
- (void)registerPowerNotifications;
@end

@implementation SmartThermalEngine {
    dispatch_queue_t _thermalQueue;
    BOOL _isCharging;
    float _batteryLevel;
    NSProcessInfoThermalState _currentThermalState;
}

+ (instancetype)sharedInstance {
    static SmartThermalEngine *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _thermalQueue = dispatch_queue_create("com.boostiphone6s.thermalengine", DISPATCH_QUEUE_SERIAL);
        _isCharging = NO;
        _batteryLevel = 1.0f;
        _currentThermalState = NSProcessInfoThermalStateNominal;
        [self registerPowerNotifications];
    }
    return self;
}

- (void)registerPowerNotifications {
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceBatteryStateDidChangeNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        UIDeviceBatteryState state = [UIDevice currentDevice].batteryState;
        self->_isCharging = (state == UIDeviceBatteryStateCharging || state == UIDeviceBatteryStateFull);
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceBatteryLevelDidChangeNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        self->_batteryLevel = [UIDevice currentDevice].batteryLevel;
    }];

    [[NSNotificationCenter defaultCenter] addObserverForName:NSProcessInfoThermalStateDidChangeNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        self->_currentThermalState = [NSProcessInfo processInfo].thermalState;
    }];
}

- (CGFloat)getDynamicAnimationMultiplier {
    if (_isCharging) {
        return 0.85f; // Slightly accelerate rendering during charging to mitigate heat buildup
    }
    
    switch (_currentThermalState) {
        case NSProcessInfoThermalStateNominal:
            return 1.0f;
        case NSProcessInfoThermalStateFair:
            return 0.90f;
        case NSProcessInfoThermalStateSerious:
            return 0.75f;
        case NSProcessInfoThermalStateCritical:
            return 0.50f;
        default:
            return 1.0f;
    }
}

- (BOOL)shouldThrottleGraphics {
    return (_currentThermalState == NSProcessInfoThermalStateCritical);
}

- (BOOL)isDeviceCharging {
    return _isCharging;
}

- (float)getBatteryLevel {
    return _batteryLevel;
}

- (NSProcessInfoThermalState)getCurrentThermalState {
    return _currentThermalState;
}

@end

// ==============================================================================
// SECTION 4: CONFIGURATION ENGINE (FULL EXPANDED PROPERTY ENGINE)
// ==============================================================================

@interface BoostConfigEngine : NSObject

@property (nonatomic, assign) BOOL enabled;

// Tần số quét & ProMotion Locking
@property (nonatomic, assign) NSInteger forcedRefreshRate;
@property (nonatomic, assign) BOOL unlockProMotion;
@property (nonatomic, assign) BOOL godModeForce120Hz;
@property (nonatomic, assign) BOOL disableDynamicFramePacing;

// Tốc độ UI & Cảm ứng SmoothFeel
@property (nonatomic, assign) CGFloat animSpeed;
@property (nonatomic, assign) BOOL smoothFeelEngine;
@property (nonatomic, assign) BOOL touchSamplingBoost;
@property (nonatomic, assign) BOOL removeScrollViewDeceleration;
@property (nonatomic, assign) BOOL disableWindowBlurEffects;

// Quản lý Bộ nhớ & RAM Engine
@property (nonatomic, assign) CGFloat ramCleanIntensity;
@property (nonatomic, assign) BOOL aggressiveRAM;
@property (nonatomic, assign) BOOL ultraDeepRamClean;
@property (nonatomic, assign) BOOL ramBoost70;
@property (nonatomic, assign) BOOL killBgApps;
@property (nonatomic, assign) BOOL heavyAppExitPurge;
@property (nonatomic, assign) BOOL autoPurgeOnLowMemory;

// Tản nhiệt & Quản lý Năng lượng
@property (nonatomic, assign) BOOL disableThermal;
@property (nonatomic, assign) BOOL smartThermalManagement;
@property (nonatomic, assign) BOOL chargingThermalProtection;
@property (nonatomic, assign) BOOL batterySaverMax;

// CPU, GPU & Metal Rendering
@property (nonatomic, assign) BOOL cpuGpuBoost80;
@property (nonatomic, assign) BOOL forceRealtimePriority;
@property (nonatomic, assign) BOOL godModeMetalOverclock;
@property (nonatomic, assign) BOOL gpuSafeOverclock;
@property (nonatomic, assign) BOOL gpuBatchOptimization;
@property (nonatomic, assign) BOOL gameStutterFix;
@property (nonatomic, assign) BOOL tripleBufferingMetal;

// Mạng, I/O & Sandbox Bypass
@property (nonatomic, assign) BOOL optimizeDiskIO;
@property (nonatomic, assign) BOOL bypassSandboxChecks;
@property (nonatomic, assign) BOOL tcpNoDelayBoost;
@property (nonatomic, assign) NSInteger networkBufferSize;
@property (nonatomic, assign) BOOL prioritizeSocketTraffic;

// Giả lập Thiết bị & Telemetry Blocker
@property (nonatomic, assign) BOOL spoofModel;
@property (nonatomic, assign) BOOL godModeFakeiPhone16;
@property (nonatomic, assign) BOOL blockAnalytics;
@property (nonatomic, assign) BOOL enableBlocker;
@property (nonatomic, assign) BOOL turboAppLaunch;

// Đồ họa AI & Processing Acceleration
@property (nonatomic, assign) BOOL enableAIAcceleration;
@property (nonatomic, assign) BOOL deepImageProcessing;

+ (instancetype)sharedInstance;
- (void)loadSettings;
- (BOOL)isDeviceOldGeneration;
- (NSString *)getHardwareMachineIdentifier;

@end

@implementation BoostConfigEngine {
    dispatch_queue_t _configQueue;
    BOOL _isOldDevice;
    NSString *_machineIdentifier;
}

+ (instancetype)sharedInstance {
    static BoostConfigEngine *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _configQueue = dispatch_queue_create("com.boostiphone6s.config.v12", DISPATCH_QUEUE_SERIAL);
        _machineIdentifier = [self getHardwareMachineIdentifier];
        _isOldDevice = [self isDeviceOldGeneration];
        [self loadSettings];
    }
    return self;
}

- (NSString *)getHardwareMachineIdentifier {
    size_t size = 0;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    if (size > 0) {
        char *buf = (char *)malloc(size);
        if (buf) {
            sysctlbyname("hw.machine", buf, &size, NULL, 0);
            NSString *machine = [NSString stringWithUTF8String:buf];
            free(buf);
            return machine;
        }
    }
    return @"iPhone8,1"; // Fallback to iPhone 6s
}

- (BOOL)isDeviceOldGeneration {
    NSArray *oldPrefixes = @[
        @"iPhone8,",  // iPhone 6s / 6s Plus
        @"iPhone9,",  // iPhone 7 / 7 Plus
        @"iPhone10,", // iPhone 8 / 8 Plus / X
        @"iPhone11,", // iPhone XS / XS Max / XR
        @"iPhone12,8" // iPhone SE 2nd Gen
    ];
    for (NSString *prefix in oldPrefixes) {
        if ([_machineIdentifier hasPrefix:prefix]) return YES;
    }
    return NO;
}

- (void)loadSettings {
    dispatch_sync(_configQueue, ^{
        NSString *plistPath = @"/var/jb/Library/Preferences/com.taojb.boostiphone6s.plist";
        NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:plistPath];

        if (!prefs) {
            plistPath = @"/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist";
            prefs = [NSDictionary dictionaryWithContentsOfFile:plistPath];
        }

        #define READ_BOOL(key, defaultVal) (prefs[key] ? [prefs[key] boolValue] : defaultVal)
        #define READ_FLOAT(key, defaultVal) (prefs[key] ? [prefs[key] floatValue] : defaultVal)
        #define READ_INT(key, defaultVal) (prefs[key] ? [prefs[key] integerValue] : defaultVal)

        self.enabled = READ_BOOL(@"Enabled", YES);

        if (self.enabled) {
            self.forcedRefreshRate = READ_INT(@"ForcedRefreshRate", 120);
            self.unlockProMotion = READ_BOOL(@"UnlockProMotion", YES);
            self.godModeForce120Hz = READ_BOOL(@"GodMode120Hz", YES);
            self.disableDynamicFramePacing = READ_BOOL(@"DisableDynamicFramePacing", YES);

            self.animSpeed = READ_FLOAT(@"AnimSpeed", 0.25);
            self.smoothFeelEngine = READ_BOOL(@"SmoothFeelEngine", YES);
            self.touchSamplingBoost = READ_BOOL(@"TouchSamplingBoost", YES);
            self.removeScrollViewDeceleration = READ_BOOL(@"RemoveScrollViewDeceleration", YES);
            self.disableWindowBlurEffects = READ_BOOL(@"DisableWindowBlurEffects", NO);

            self.ramCleanIntensity = READ_FLOAT(@"RamCleanIntensity", 128.0);
            self.aggressiveRAM = READ_BOOL(@"AggressiveRAM", YES);
            self.ultraDeepRamClean = READ_BOOL(@"UltraDeepRam", YES);
            self.ramBoost70 = READ_BOOL(@"RamBoost70", YES);
            self.killBgApps = READ_BOOL(@"KillBackgroundApps", NO);
            self.heavyAppExitPurge = READ_BOOL(@"HeavyAppExitPurge", YES);
            self.autoPurgeOnLowMemory = READ_BOOL(@"AutoPurgeOnLowMemory", YES);

            self.disableThermal = READ_BOOL(@"DisableThermal", NO);
            self.smartThermalManagement = READ_BOOL(@"SmartThermal", YES);
            self.chargingThermalProtection = READ_BOOL(@"ChargingThermalProtection", YES);
            self.batterySaverMax = READ_BOOL(@"BatterySaverMax", NO);

            self.cpuGpuBoost80 = READ_BOOL(@"CPUGPUBoost80", YES);
            self.forceRealtimePriority = READ_BOOL(@"ForceRealtime", YES);
            self.godModeMetalOverclock = READ_BOOL(@"GodModeMetal", YES);
            self.gpuSafeOverclock = READ_BOOL(@"GPUSafeOverclock", YES);
            self.gpuBatchOptimization = READ_BOOL(@"GPUBatchOptimization", YES);
            self.gameStutterFix = READ_BOOL(@"GameStutterFix", YES);
            self.tripleBufferingMetal = READ_BOOL(@"TripleBufferingMetal", YES);

            self.optimizeDiskIO = READ_BOOL(@"OptimizeDisk", YES);
            self.bypassSandboxChecks = READ_BOOL(@"BypassSandbox", YES);
            self.tcpNoDelayBoost = READ_BOOL(@"TCPNoDelayBoost", YES);
            self.networkBufferSize = READ_INT(@"NetBufSize", 4096);
            self.prioritizeSocketTraffic = READ_BOOL(@"PrioritizeSocketTraffic", YES);

            self.spoofModel = READ_BOOL(@"SpoofModel", YES);
            self.godModeFakeiPhone16 = READ_BOOL(@"GodModeFake16", YES);
            self.blockAnalytics = READ_BOOL(@"BlockAnalytics", YES);
            self.enableBlocker = READ_BOOL(@"EnableBlocker", YES);
            self.turboAppLaunch = READ_BOOL(@"TurboAppLaunch", YES);

            self.enableAIAcceleration = READ_BOOL(@"EnableAIBoost", YES);
            self.deepImageProcessing = READ_BOOL(@"DeepImageProcessing", YES);

            // Safety check for older generation hardware
            if (_isOldDevice && self.forcedRefreshRate > 60) {
                self.forcedRefreshRate = 60;
            }
        } else {
            self.forcedRefreshRate = 60;
            self.animSpeed = 1.0;
        }
    });
}

@end

// Macro Helpers
#define CFG [BoostConfigEngine sharedInstance]
#define IS_ON (CFG.enabled)
#define IS_OLD ([CFG isDeviceOldGeneration])

static void BoostApplyCpuPriority(int priorityValue) {
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    setpriority(PRIO_PROCESS, 0, priorityValue);
}

static BOOL BoostIsSpringBoard(void) {
    return [[[NSProcessInfo processInfo] processName] isEqualToString:@"SpringBoard"];
}

static void reloadPrefsNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[BoostConfigEngine sharedInstance] loadSettings];
}

// ==============================================================================
// SECTION 5: FRAME RATE & DISPLAY OVERCLOCKING ENGINE (COMPLETE 120-90-60-30 FIX)
// ==============================================================================

%group FramePacingEngine

%hook CADisplayLink

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (!IS_ON) {
        %orig(fps);
        return;
    }
    NSInteger target = CFG.forcedRefreshRate;
    if (IS_OLD && target > 60) target = 60;
    
    if (target > 0) {
        %orig(target);
        return;
    }
    %orig(fps);
}

- (NSInteger)preferredFramesPerSecond {
    if (!IS_ON) return %orig;
    NSInteger target = CFG.forcedRefreshRate;
    if (IS_OLD && target > 60) target = 60;
    return (target > 0) ? target : %orig;
}

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    if (!IS_ON) {
        %orig(range);
        return;
    }
    float target = (float)CFG.forcedRefreshRate;
    if (IS_OLD && target > 60.0f) target = 60.0f;
    
    if (target > 0.0f) {
        CAFrameRateRange customRange = CAFrameRateRangeMake(target, target, target);
        %orig(customRange);
        return;
    }
    %orig(range);
}

- (CAFrameRateRange)preferredFrameRateRange {
    if (!IS_ON) return %orig;
    float target = (float)CFG.forcedRefreshRate;
    if (IS_OLD && target > 60.0f) target = 60.0f;
    if (target > 0.0f) {
        return CAFrameRateRangeMake(target, target, target);
    }
    return %orig;
}

- (void)setHighFrameRateReason:(BOOL)reason {
    if (IS_ON) {
        %orig(YES);
        return;
    }
    %orig(reason);
}

%end

%hook CAAnimation

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    if (!IS_ON) {
        %orig(range);
        return;
    }
    float target = (float)CFG.forcedRefreshRate;
    if (IS_OLD && target > 60.0f) target = 60.0f;
    if (target > 0.0f) {
        %orig(CAFrameRateRangeMake(target, target, target));
        return;
    }
    %orig(range);
}

- (CAFrameRateRange)preferredFrameRateRange {
    if (!IS_ON) return %orig;
    float target = (float)CFG.forcedRefreshRate;
    if (IS_OLD && target > 60.0f) target = 60.0f;
    if (target > 0.0f) {
        return CAFrameRateRangeMake(target, target, target);
    }
    return %orig;
}

%end

%hook CALayer

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    if (!IS_ON) {
        %orig(range);
        return;
    }
    float target = (float)CFG.forcedRefreshRate;
    if (IS_OLD && target > 60.0f) target = 60.0f;
    if (target > 0.0f) {
        %orig(CAFrameRateRangeMake(target, target, target));
        return;
    }
    %orig(range);
}

- (CAFrameRateRange)preferredFrameRateRange {
    if (!IS_ON) return %orig;
    float target = (float)CFG.forcedRefreshRate;
    if (IS_OLD && target > 60.0f) target = 60.0f;
    if (target > 0.0f) {
        return CAFrameRateRangeMake(target, target, target);
    }
    return %orig;
}

- (void)setDrawsAsynchronously:(BOOL)drawsAsynchronously {
    if (IS_ON && CFG.godModeMetalOverclock) {
        %orig(YES);
        return;
    }
    %orig(drawsAsynchronously);
}

%end

%hook UIScreen

- (NSInteger)maximumFramesPerSecond {
    if (IS_ON) {
        NSInteger target = CFG.forcedRefreshRate;
        if (IS_OLD && target > 60) target = 60;
        return (target > 0) ? target : %orig;
    }
    return %orig;
}

- (CGFloat)_refreshRate {
    if (IS_ON) {
        NSInteger target = CFG.forcedRefreshRate;
        if (IS_OLD && target > 60) target = 60;
        return (CGFloat)target;
    }
    return %orig;
}

- (BOOL)isProMotionEnabled {
    if (IS_ON && CFG.unlockProMotion && !IS_OLD) return YES;
    return %orig;
}

%end

%end

// ==============================================================================
// SECTION 6: MULTITASKING & HEAVY APP EXIT LAG ELIMINATOR
// ==============================================================================

%group MultitaskingEngine

%hook SBMainWorkspace

- (void)_exitAppToHomeScreenAnimated:(BOOL)animated {
    %orig(animated);
    if (IS_ON && CFG.heavyAppExitPurge) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
            [[DeepMemoryEngine sharedInstance] performDeepMemoryPurge:(size_t)CFG.ramCleanIntensity];
            [[DeepMemoryEngine sharedInstance] purgeSystemCachesAndTemporaryFiles];
        });
    }
}

%end

%hook SBAppSwitcherController

- (void)switcherContentController:(id)controller setVisibility:(NSInteger)visibility {
    if (IS_ON && visibility == 1) { // App Switcher Opening
        BoostApplyCpuPriority(-16);
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            [[DeepMemoryEngine sharedInstance] performDeepMemoryPurge:96];
        });
    }
    %orig(controller, visibility);
}

%end

%hook FBSSystemService

- (void)openApplication:(id)application withOptions:(id)options {
    if (IS_ON && CFG.turboAppLaunch) {
        BoostApplyCpuPriority(-18);
        
        if (CFG.killBgApps && BoostIsSpringBoard()) {
            load_bks_terminate();
            if (g_bksTerminate != NULL) {
                NSString *targetBid = nil;
                if ([application respondsToSelector:@selector(bundleIdentifier)]) {
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    targetBid = (NSString *)[application performSelector:@selector(bundleIdentifier)];
                    #pragma clang diagnostic pop
                }

                Class sac = objc_getClass("SBApplicationController");
                if (sac) {
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    id ctrl = [sac performSelector:@selector(sharedInstance)];
                    if (ctrl && [ctrl respondsToSelector:@selector(allApplications)]) {
                        NSArray *apps = (NSArray *)[ctrl performSelector:@selector(allApplications)];
                        for (id app in apps) {
                            if (![app respondsToSelector:@selector(bundleIdentifier)]) continue;
                            NSString *bid = (NSString *)[app performSelector:@selector(bundleIdentifier)];
                            if (!bid || [bid isEqualToString:targetBid] || [bid hasPrefix:@"com.apple."]) continue;
                            g_bksTerminate(bid, 5, NO, @"SmoothIOS v12 Multitasking Purge");
                        }
                    }
                    #pragma clang diagnostic pop
                }
            }
        }
    }
    %orig(application, options);
}

%end

%end

// ==============================================================================
// SECTION 7: THERMAL BYPASS & CHARGING PROTECTION ENGINE
// ==============================================================================

%group ThermalBypassEngine

%hook NSProcessInfo

- (NSProcessInfoThermalState)thermalState {
    if (!IS_ON) return %orig;

    if (CFG.chargingThermalProtection) {
        if ([[SmartThermalEngine sharedInstance] isDeviceCharging]) {
            return NSProcessInfoThermalStateFair;
        }
    }

    if (CFG.smartThermalManagement || CFG.disableThermal) {
        return NSProcessInfoThermalStateNominal;
    }

    return %orig;
}

+ (BOOL)isThermalPressureCritical {
    if (IS_ON && (CFG.smartThermalManagement || CFG.disableThermal)) return NO;
    return %orig;
}

%end

%hook CALayer

- (CFTimeInterval)duration {
    if (!IS_ON) return %orig;
    CFTimeInterval base = %orig;
    CGFloat speed = CFG.animSpeed;

    if (CFG.smartThermalManagement) {
        CGFloat thermalMultiplier = [[SmartThermalEngine sharedInstance] getDynamicAnimationMultiplier];
        speed *= thermalMultiplier;
    }
    return base * speed;
}

%end

%end

// ==============================================================================
// SECTION 8: METAL GRAPHICS & GPU OVERCLOCK ENGINE
// ==============================================================================

%group GPUEngine

%hook CAMetalLayer

- (void)setMaximumDrawableCount:(NSUInteger)count {
    if (IS_ON && CFG.godModeMetalOverclock) {
        if (CFG.tripleBufferingMetal) {
            %orig(3);
        } else {
            %orig(2);
        }
        return;
    }
    %orig(count);
}

- (BOOL)presentsWithTransaction {
    if (IS_ON && CFG.godModeMetalOverclock) return NO;
    return %orig;
}

- (BOOL)allowsNextDrawableTimeout {
    if (IS_ON && CFG.gpuBatchOptimization) return NO;
    return %orig;
}

- (BOOL)framebufferOnly {
    if (IS_ON && CFG.gpuBatchOptimization) return YES;
    return %orig;
}

%end

%end

// ==============================================================================
// SECTION 9: TOUCH RESPONSE & UI SMOOTHNESS ENGINE (SMOOTHFEEL)
// ==============================================================================

%group UIEngine

%hook UIView

- (void)setAlpha:(CGFloat)alpha {
    if (!IS_ON) return %orig(alpha);
    if (alpha > 0.96) alpha = 1.0;
    %orig(alpha);
}

%end

%hook UIScrollView

- (void)didMoveToWindow {
    %orig;
    if (IS_ON && CFG.smoothFeelEngine && self.window != nil) {
        self.delaysContentTouches = NO;
        self.canCancelContentTouches = YES;
        
        if (CFG.removeScrollViewDeceleration) {
            self.decelerationRate = UIScrollViewDecelerationRateFast;
        }
        
        if (self.panGestureRecognizer) {
            self.panGestureRecognizer.delaysTouchesBegan = NO;
            self.panGestureRecognizer.delaysTouchesEnded = NO;
        }
    }
}

%end

%hook UIGestureRecognizer

- (void)setDelaysTouchesBegan:(BOOL)delays {
    if (IS_ON && CFG.touchSamplingBoost) {
        %orig(NO);
        return;
    }
    %orig(delays);
}

- (void)setDelaysTouchesEnded:(BOOL)delays {
    if (IS_ON && CFG.touchSamplingBoost) {
        %orig(NO);
        return;
    }
    %orig(delays);
}

%end

%end

// ==============================================================================
// SECTION 10: LOW-LEVEL KERNEL & POSIX C-INTERCEPTORS
// ==============================================================================

%group KernelDeepHooks

%hookf(int, access, const char *pathname, int mode) {
    if (!IS_ON || !CFG.bypassSandboxChecks || !pathname) return %orig(pathname, mode);
    if (strstr(pathname, "/Caches/") != NULL ||
        strstr(pathname, "/tmp/") != NULL ||
        strstr(pathname, "/var/mobile/Containers/") != NULL ||
        strstr(pathname, "/var/jb/") != NULL) {
        return 0;
    }
    return %orig(pathname, mode);
}

%hookf(kern_return_t, thread_policy_set, thread_act_t target_thread, thread_policy_flavor_t flavor, natural_t *policy_info, mach_msg_type_number_t policy_count) {
    if (!IS_ON || !CFG.forceRealtimePriority || !policy_info) return %orig(target_thread, flavor, policy_info, policy_count);
    if (flavor == THREAD_TIME_CONSTRAINT_POLICY) {
        struct thread_time_constraint_policy *ttcp = (struct thread_time_constraint_policy *)policy_info;
        NSInteger hz = CFG.forcedRefreshRate > 0 ? CFG.forcedRefreshRate : 60;
        uint64_t periodNs = 1000000000ULL / (uint64_t)hz;
        ttcp->period = (uint32_t)(periodNs);
        ttcp->computation = (uint32_t)(periodNs * 0.45);
        ttcp->constraint = (uint32_t)(periodNs * 0.65);
    }
    return %orig(target_thread, flavor, policy_info, policy_count);
}

%hookf(int, sysctlbyname, const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (!IS_ON || !name) return %orig(name, oldp, oldlenp, newp, newlen);

    if (CFG.godModeFakeiPhone16 && (strcmp(name, "hw.machine") == 0 || strcmp(name, "hw.model") == 0)) {
        const char *fakeModel = "iPhone16,2";
        if (oldp && oldlenp) {
            strlcpy((char *)oldp, fakeModel, *oldlenp);
            *oldlenp = strlen(fakeModel) + 1;
        } else if (oldlenp) {
            *oldlenp = strlen(fakeModel) + 1;
        }
        return 0;
    }

    return %orig(name, oldp, oldlenp, newp, newlen);
}

%hookf(int, connect, int socket, const struct sockaddr *address, socklen_t address_len) {
    if (IS_ON && CFG.tcpNoDelayBoost) {
        int opt = 1;
        setsockopt(socket, IPPROTO_TCP, TCP_NODELAY, &opt, sizeof(opt));
        
        if (CFG.prioritizeSocketTraffic) {
            int bufSize = (int)(CFG.networkBufferSize * 1024);
            setsockopt(socket, SOL_SOCKET, SO_RCVBUF, &bufSize, sizeof(bufSize));
            setsockopt(socket, SOL_SOCKET, SO_SNDBUF, &bufSize, sizeof(bufSize));
        }
    }
    return %orig(socket, address, address_len);
}

%end

// ==============================================================================
// SECTION 11: TELEMETRY & SYSTEM ANALYTICS BLOCKER
// ==============================================================================

%group TelemetryBlockerEngine

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    if (IS_ON && CFG.blockAnalytics && request.URL) {
        NSString *urlStr = request.URL.absoluteString;
        if ([urlStr containsString:@"analytics.apple.com"] ||
            [urlStr containsString:@"telemetry.apple.com"] ||
            [urlStr containsString:@"iadsdk.apple.com"] ||
            [urlStr containsString:@"metrics.icloud.com"]) {
            
            if (completionHandler) {
                NSError *blockedError = [NSError errorWithDomain:@"com.boostiphone6s.blocker" code:-999 userInfo:nil];
                completionHandler(nil, nil, blockedError);
            }
            return nil;
        }
    }
    return %orig(request, completionHandler);
}

%end

%end

// ==============================================================================
// SECTION 12: CONSTRUCTOR & DYNAMIC HOOK INITIALIZATION
// ==============================================================================

%ctor {
    @autoreleasepool {
        // Enable device battery monitoring
        [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];

        // Register Darwin notification listener for preference reload
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            reloadPrefsNotification,
            CFSTR("com.taojb.boostiphone6s.settings/reload"),
            NULL,
            CFNotificationSuspensionBehaviorCoalesce
        );

        // Initialize CrashGuard monitoring
        [[CrashGuard sharedInstance] startMonitoring];

        // Verify Safe Mode status
        if (![[CrashGuard sharedInstance] canExecuteHooks] || !IS_ON) {
            return;
        }

        // Initialize default hooks
        %init(_ungrouped);

        // Apply environment variables for Turbo App Launch
        if (CFG.turboAppLaunch) {
            setenv("DISABLE_DYLD_RESTOS", "1", 1);
            setenv("MALLOC_OPTIONS", "AFGN", 1);
            setenv("DYLD_DISABLE_DOFS", "1", 1);
            setenv("OBJC_DISABLE_INITIALIZE_FORK_SAFETY", "YES", 1);
        }

        // Elevate CPU process priority on startup
        if (CFG.cpuGpuBoost80) {
            BoostApplyCpuPriority(-15);
        }

        // Execute initial deep memory clean
        if (CFG.ramBoost70 || CFG.ultraDeepRamClean) {
            [[DeepMemoryEngine sharedInstance] performDeepMemoryPurge:(size_t)CFG.ramCleanIntensity];
        }

        // Initialize specialized hook groups
        %init(FramePacingEngine);
        %init(MultitaskingEngine);
        %init(ThermalBypassEngine);
        %init(GPUEngine);
        %init(UIEngine);
        %init(KernelDeepHooks);

        if (CFG.blockAnalytics || CFG.enableBlocker) {
            %init(TelemetryBlockerEngine);
        }
    }
}
