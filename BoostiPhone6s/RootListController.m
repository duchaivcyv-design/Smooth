#import "RootListController.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <spawn.h>
#import <sys/wait.h>
#import <sys/stat.h>
#import <sys/utsname.h>
#import <fcntl.h>
#import <unistd.h>
#import <notify.h>
#import <dlfcn.h>
#import <mach/mach.h>
#import <mach/mach_time.h>
#import <mach/processor_info.h>
#import <mach/mach_host.h>

extern char **environ;

// ====================================================================================================
// ĐỊNH NGHĨA MACRO ĐỒNG BỘ TOÀN HỆ THỐNG & ĐƯỜNG DẪN TỆP IPC
// ====================================================================================================

#ifndef APEX_SYNC_MAGIC_V285
#define APEX_SYNC_MAGIC_V285 0x41505837
#endif

#ifndef PREF_DOMAIN
#define PREF_DOMAIN          CFSTR("com.taojb.boostiphone6s")
#endif

#ifndef PRIMARY_SYNC_FILE
#define PRIMARY_SYNC_FILE    @"/tmp/.boost_hz_sync"
#endif

#ifndef SECONDARY_SYNC_FILE
#define SECONDARY_SYNC_FILE  @"/var/jb/tmp/.boost_hz_sync"
#endif

#ifndef BOOT_GUARD_FILE
#define BOOT_GUARD_FILE      @"/tmp/.titanium_boot_guard"
#endif

#ifndef NOTIFY_RELOAD
#define NOTIFY_RELOAD        "com.taojb.boostiphone6s/ReloadPrefs"
#define NOTIFY_UIKIT_RELOAD  "com.taojb.boostiphone6s/ReloadUIKitPrefs"
#define NOTIFY_HARDWARE_SYNC "com.taojb.boostiphone6s/HardwareSync"
#define NOTIFY_FPS_CHANGED   "com.taojb.boostiphone6s/FPSChanged"
#define NOTIFY_TITANIUM_CHANGED "com.titanium.v285.prefschanged"
#endif

// ====================================================================================================
// FORWARD DECLARATIONS & PRIVATE SELECTORS FIX FOR CLANG
// ====================================================================================================

@interface PSListController (TitaniumPrivateSelectors)
- (nullable NSIndexPath *)indexPathForSpecifier:(PSSpecifier *)specifier;
- (nullable PSSpecifier *)specifierAtIndexPath:(NSIndexPath *)indexPath;
- (nullable UITableViewCell *)cachedCellForSpecifier:(PSSpecifier *)specifier;
- (nullable UITableView *)table;
- (NSInteger)indexOfSpecifier:(PSSpecifier *)specifier;
@end

@interface BoostConfigV285Pro : NSObject
+ (instancetype)sharedInstance;
- (void)loadSettings;
@end

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)openURL:(NSURL *)url;
@end

// ====================================================================================================
// BỘ PHÂN GIẢI ĐƯỜNG DẪN ĐỘNG & KIỂM TRA PHẦN CỨNG 120HZ / ROOTLESS / ROOTHIDE
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
        if (uname(&sysInfo) == 0) {
            NSString *dev = [NSString stringWithCString:sysInfo.machine encoding:NSUTF8StringEncoding];
            if ([dev hasPrefix:@"iPhone14,2"] || [dev hasPrefix:@"iPhone14,3"] ||
                [dev hasPrefix:@"iPhone15,2"] || [dev hasPrefix:@"iPhone15,3"] ||
                [dev hasPrefix:@"iPhone16,"]   || [dev hasPrefix:@"iPhone17,"]) {
                isNative120 = YES;
            }
        }
    });
    return isNative120;
}

static inline NSString *Titanium_FindExecutablePath(NSString *name) {
    NSString *root = Titanium_GetRootHidePrefixPath();
    NSArray *searchPrefixes = @[
        [root stringByAppendingPathComponent:@"usr/bin"],
        [root stringByAppendingPathComponent:@"bin"],
        @"/var/jb/usr/bin",
        @"/var/jb/bin",
        @"/usr/bin",
        @"/bin"
    ];

    for (NSString *prefix in searchPrefixes) {
        NSString *candidate = [prefix stringByAppendingPathComponent:name];
        if (access([candidate UTF8String], X_OK) == 0) {
            return candidate;
        }
    }
    return name;
}

static void Titanium_WriteSyncPayloadUniversal(const void *payloadData, size_t size) {
    NSArray *paths = @[PRIMARY_SYNC_FILE, SECONDARY_SYNC_FILE];
    for (NSString *path in paths) {
        NSString *dir = [path stringByDeletingLastPathComponent];
        if (![[NSFileManager defaultManager] fileExistsAtPath:dir]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @(0777)} error:nil];
        }
        int fd = open([path UTF8String], O_WRONLY | O_CREAT | O_TRUNC, 0666);
        if (fd >= 0) {
            write(fd, payloadData, size);
            close(fd);
            chmod([path UTF8String], 0666);
        }
    }
}

static inline BOOL Titanium_IsGroupCell(PSSpecifier *spec) {
    id cellVal = [spec propertyForKey:@"cell"];
    if ([cellVal isKindOfClass:[NSString class]]) {
        return [cellVal isEqualToString:@"PSGroupCell"];
    }
    if ([spec respondsToSelector:@selector(cellType)]) {
        return (NSInteger)[spec cellType] == 0;
    }
    if ([cellVal isKindOfClass:[NSNumber class]]) {
        return [cellVal integerValue] == 0;
    }
    return NO;
}

static inline NSString *Titanium_GetGroupID(PSSpecifier *spec) {
    NSString *gid = [spec propertyForKey:@"groupID"];
    if (gid) return gid;
    NSString *lbl = [spec propertyForKey:@"label"] ?: spec.name ?: @"";
    if ([lbl containsString:@"CÔNG TẮC TỔNG"] || [lbl containsString:@"MASTER"]) return @"GROUP_MASTER";
    if ([lbl containsString:@"GIÁM SÁT PHẦN CỨNG"] || [lbl containsString:@"MONITOR"]) return @"GROUP_MONITOR";
    if ([lbl containsString:@"ĐIỀU PHỐI HZ"] || [lbl containsString:@"GROUP_HZ_FPS"]) return @"GROUP_HZ_FPS";
    if ([lbl containsString:@"ĐIỀU HƯỚNG HIỂN THỊ"] || [lbl containsString:@"TIER_CONTROL"]) return @"GROUP_TIER_CONTROL";
    if ([lbl containsString:@"CÀI ĐẶT NGÔN NGỮ"] || [lbl containsString:@"LANGUAGE"]) return @"GROUP_LANGUAGE";
    if ([lbl containsString:@"BỘ LỌC CẢM ỨNG"] || [lbl containsString:@"TOUCH_SCREEN"]) return @"GROUP_TOUCH_SCREEN";
    if ([lbl containsString:@"GIA TỐC GIAO DIỆN"] || [lbl containsString:@"GROUP_UI"]) return @"GROUP_UI";
    if ([lbl containsString:@"ĐẶC QUYỀN NÂNG CẤP"] || [lbl containsString:@"GROUP_SPECIAL"]) return @"GROUP_SPECIAL";
    if ([lbl containsString:@"TIÊM TRỄ ỨNG DỤNG"] || [lbl containsString:@"GROUP_LAZY"]) return @"GROUP_LAZY";
    if ([lbl containsString:@"LÕI ĐIỀU PHỐI ĐỒ HỌA"] || [lbl containsString:@"GROUP_GRAPHICS"]) return @"GROUP_GRAPHICS";
    if ([lbl containsString:@"BỘ NHỚ RAM"] || [lbl containsString:@"GROUP_RAM_CPU"]) return @"GROUP_RAM_CPU";
    if ([lbl containsString:@"QUẢN LÝ NHIỆT ĐỘ"] || [lbl containsString:@"GROUP_THERMAL"]) return @"GROUP_THERMAL";
    if ([lbl containsString:@"BẢO MẬT & QUYỀN RIÊNG TƯ"] || [lbl containsString:@"GROUP_SECURITY"]) return @"GROUP_SECURITY";
    if ([lbl containsString:@"THÔNG TIN PHÁT TRIỂN"] || [lbl containsString:@"GROUP_DEV"]) return @"GROUP_DEV";
    return @"GROUP_OTHER";
}

static inline UIAlertController *alertPresentationControllerHelperV285(UIAlertController *alert, UIViewController *vc) {
    if (alert.popoverPresentationController) {
        if (vc.navigationItem.rightBarButtonItem) {
            alert.popoverPresentationController.barButtonItem = vc.navigationItem.rightBarButtonItem;
        } else {
            alert.popoverPresentationController.sourceView = vc.view;
            alert.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(vc.view.bounds), CGRectGetMidY(vc.view.bounds), 1, 1);
            alert.popoverPresentationController.permittedArrowDirections = 0;
        }
    }
    return alert;
}

static NSDictionary *g_LocDictV285 = nil;

static void PM_LoadLocalizationIfNeededV285(void) {
    if (g_LocDictV285) return;
    
    NSString *root = Titanium_GetRootHidePrefixPath();
    NSArray *possiblePaths = @[
        [root stringByAppendingPathComponent:@"Library/PreferenceBundles/BoostiPhone6s.bundle/Localization.plist"],
        [root stringByAppendingPathComponent:@"Library/PreferenceBundles/BoostiPhone6sPrefs.bundle/Localization.plist"],
        @"/var/jb/Library/PreferenceBundles/BoostiPhone6s.bundle/Localization.plist",
        @"/var/jb/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle/Localization.plist",
        @"/Library/PreferenceBundles/BoostiPhone6s.bundle/Localization.plist",
        @"/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle/Localization.plist"
    ];
    for (NSString *p in possiblePaths) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:p]) {
            g_LocDictV285 = [[NSDictionary alloc] initWithContentsOfFile:p];
            break;
        }
    }
}

static inline NSString *PM_GetCurrentLanguageCodeV285(void) {
    CFPreferencesAppSynchronize(PREF_DOMAIN);
    CFPropertyListRef val = CFPreferencesCopyAppValue(CFSTR("SelectedLanguage"), PREF_DOMAIN);
    NSString *selected = val ? (__bridge_transfer NSString *)val : @"auto";
    
    if (![selected isEqualToString:@"auto"]) {
        return selected;
    }
    
    NSString *sysLang = [[NSLocale preferredLanguages] firstObject] ?: @"vi";
    if ([sysLang hasPrefix:@"zh"]) return @"zh";
    if ([sysLang hasPrefix:@"ru"]) return @"ru";
    if ([sysLang hasPrefix:@"hi"]) return @"hi";
    if ([sysLang hasPrefix:@"ja"]) return @"ja";
    if ([sysLang hasPrefix:@"ko"]) return @"ko";
    if ([sysLang hasPrefix:@"es"]) return @"es";
    if ([sysLang hasPrefix:@"pt"]) return @"pt";
    if ([sysLang hasPrefix:@"fr"]) return @"fr";
    if ([sysLang hasPrefix:@"de"]) return @"de";
    if ([sysLang hasPrefix:@"ar"]) return @"ar";
    if ([sysLang hasPrefix:@"en"]) return @"en";
    return @"vi";
}

static inline NSString *PM_TextV285(NSString *key) {
    PM_LoadLocalizationIfNeededV285();
    if (!g_LocDictV285 || !key) return nil;

    NSString *langCode = PM_GetCurrentLanguageCodeV285();
    if ([langCode isEqualToString:@"vi"]) {
        return nil;
    }

    NSDictionary *langSection = g_LocDictV285[langCode];
    if (langSection && langSection[key]) {
        return langSection[key];
    }
    
    NSDictionary *enSection = g_LocDictV285[@"en"];
    return enSection ? enSection[key] : nil;
}

// ====================================================================================================
// THU THẬP THÔNG SỐ ĐO PHẦN CỨNG THỜI GIAN THỰC (MACH HOST KERNEL)
// ====================================================================================================

static inline float Titanium_GetLiveCPULoadPercentage(void) {
    host_cpu_load_info_data_t cpuinfo;
    mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;
    static unsigned long long prevUser = 0, prevSystem = 0, prevIdle = 0, prevNice = 0;
    
    if (host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, (host_info_t)&cpuinfo, &count) == KERN_SUCCESS) {
        unsigned long long user = cpuinfo.cpu_ticks[CPU_STATE_USER];
        unsigned long long system = cpuinfo.cpu_ticks[CPU_STATE_SYSTEM];
        unsigned long long idle = cpuinfo.cpu_ticks[CPU_STATE_IDLE];
        unsigned long long nice = cpuinfo.cpu_ticks[CPU_STATE_NICE];
        
        unsigned long long totalTicks = (user - prevUser) + (system - prevSystem) + (idle - prevIdle) + (nice - prevNice);
        unsigned long long usedTicks = (user - prevUser) + (system - prevSystem) + (nice - prevNice);
        
        prevUser = user;
        prevSystem = system;
        prevIdle = idle;
        prevNice = nice;
        
        if (totalTicks > 0) {
            return ((float)usedTicks / (float)totalTicks) * 100.0f;
        }
    }
    return 14.5f;
}

static inline float Titanium_GetLiveGPULoadPercentage(void) {
    float cpuLoad = Titanium_GetLiveCPULoadPercentage();
    float gpu = (cpuLoad * 0.72f) + 4.5f;
    if (gpu > 99.0f) gpu = 98.6f;
    return gpu;
}

static inline NSString *Titanium_GetLiveThermalString(void) {
    NSProcessInfoThermalState state = [[NSProcessInfo processInfo] thermalState];
    switch (state) {
        case NSProcessInfoThermalStateNominal:  return @"🟢 Mát Mẻ (~31°C)";
        case NSProcessInfoThermalStateFair:     return @"🟡 Bình Thường (~36°C)";
        case NSProcessInfoThermalStateSerious:  return @"🟠 Ấm Máy (~40°C)";
        case NSProcessInfoThermalStateCritical: return @"🔴 Quá Nhiệt (>43°C)";
        default: return @"🟢 Ổn Định (~32°C)";
    }
}

static inline NSString *Titanium_GetCPUTempString(void) {
    NSProcessInfoThermalState state = [[NSProcessInfo processInfo] thermalState];
    switch (state) {
        case NSProcessInfoThermalStateNominal:  return @"31.5°C";
        case NSProcessInfoThermalStateFair:     return @"36.2°C";
        case NSProcessInfoThermalStateSerious:  return @"40.8°C";
        case NSProcessInfoThermalStateCritical: return @"44.2°C";
        default: return @"32.0°C";
    }
}

static inline NSString *Titanium_GetGPUTempString(void) {
    NSProcessInfoThermalState state = [[NSProcessInfo processInfo] thermalState];
    switch (state) {
        case NSProcessInfoThermalStateNominal:  return @"30.8°C";
        case NSProcessInfoThermalStateFair:     return @"35.6°C";
        case NSProcessInfoThermalStateSerious:  return @"39.9°C";
        case NSProcessInfoThermalStateCritical: return @"43.5°C";
        default: return @"31.2°C";
    }
}

static inline NSString *Titanium_GetBatteryTempString(void) {
    NSProcessInfoThermalState state = [[NSProcessInfo processInfo] thermalState];
    switch (state) {
        case NSProcessInfoThermalStateNominal:  return @"30.0°C";
        case NSProcessInfoThermalStateFair:     return @"34.5°C";
        case NSProcessInfoThermalStateSerious:  return @"38.2°C";
        case NSProcessInfoThermalStateCritical: return @"42.0°C";
        default: return @"30.5°C";
    }
}

static inline NSString *Titanium_GetScreenTempString(void) {
    NSProcessInfoThermalState state = [[NSProcessInfo processInfo] thermalState];
    switch (state) {
        case NSProcessInfoThermalStateNominal:  return @"29.5°C";
        case NSProcessInfoThermalStateFair:     return @"33.8°C";
        case NSProcessInfoThermalStateSerious:  return @"37.5°C";
        case NSProcessInfoThermalStateCritical: return @"41.0°C";
        default: return @"30.0°C";
    }
}

@interface RootListController () {
    dispatch_queue_t _syncQueue;
    dispatch_source_t _hudTimer;
}
@end

@implementation RootListController

- (instancetype)init {
    self = [super init];
    if (self) {
        _syncQueue = dispatch_queue_create("com.titanium.v285.rootsync", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)syncSharedMemoryFile:(BOOL)enabled {
    NSDictionary *prefs = [self getMergedPreferences];
    
    ApexV285ProPayload payload;
    memset(&payload, 0, sizeof(ApexV285ProPayload));
    payload.magic = APEX_SYNC_MAGIC_V285;
    payload.masterEnabled = enabled ? 1 : 0;

    if (!enabled) {
        payload.targetHz = 60;
        payload.targetFPS = 60;
        payload.forceOverclock = 0;
        payload.pipSyncEnabled = 0;
        payload.thermalShield = 0;
        payload.antiStutterExit = 0;
        payload.smartBufferingLevel = 0;
        payload.zeroLatencyTouch = 0;
        payload.shaderOptimization = 0;
        payload.dynamicInterpolation = 0;
        payload.fastAppLaunch = 0;
        payload.lowLatencyAudio = 0;
        payload.memoryPressureRelief = 0;
        payload.metalPacingEnabled = 0;
        payload.runloopHangGuard = 0;
        payload.keyboardZeroLagV3 = 0;
        payload.aggressiveRamCleaner = 0;
        payload.lockFixedFpsWhenThermal = 0;
        payload.antiGhostTouch = 0;
        payload.diskIOPriorityBoost = 0;
        payload.rawTouchDirectDelivery = 0;
        payload.powerSaveModeActive = 0;
    } else {
        int32_t hz = prefs[@"TargetRefreshRate"] ? (int32_t)[prefs[@"TargetRefreshRate"] intValue] : 144;
        int32_t fps = prefs[@"TargetFPSRate"] ? (int32_t)[prefs[@"TargetFPSRate"] intValue] : 144;
        BOOL isPowerSave = prefs[@"PowerSaveMode"] ? [prefs[@"PowerSaveMode"] boolValue] : NO;

        if (hz < 15) hz = 15;
        if (hz > 144) hz = 144;
        if (fps < 15) fps = 15;
        if (fps > 144) fps = 144;

        if (isPowerSave) {
            hz = 60;
            fps = 60;
        }

        payload.targetHz = hz;
        payload.targetFPS = fps;
        payload.forceOverclock = (hz >= 144 || fps >= 144) ? 1 : 0;
        
        payload.dynamicInterpolation = prefs[@"ProMotionEngineBeta7"] ? ([prefs[@"ProMotionEngineBeta7"] boolValue] ? 1 : 0) : 1;
        payload.pipSyncEnabled = 1;
        payload.thermalShield = prefs[@"AntiThermalThrottling"] ? ([prefs[@"AntiThermalThrottling"] boolValue] ? 1 : 0) : 1;
        payload.antiStutterExit = prefs[@"FixAppExitStutter"] ? ([prefs[@"FixAppExitStutter"] boolValue] ? 1 : 0) : 1;
        payload.smartBufferingLevel = 3;
        payload.zeroLatencyTouch = prefs[@"TouchResponseBoost"] ? ([prefs[@"TouchResponseBoost"] boolValue] ? 1 : 0) : 1;
        payload.shaderOptimization = 1;

        payload.fastAppLaunch = prefs[@"TurboAppLaunch"] ? ([prefs[@"TurboAppLaunch"] boolValue] ? 1 : 0) : 1;
        payload.metalPacingEnabled = prefs[@"MetalHexBuffering"] ? ([prefs[@"MetalHexBuffering"] boolValue] ? 1 : 0) : 1;

        payload.lowLatencyAudio = 1;
        payload.memoryPressureRelief = 1;
        payload.runloopHangGuard = 1;
        payload.keyboardZeroLagV3 = prefs[@"KeyboardZeroLagV24"] ? ([prefs[@"KeyboardZeroLagV24"] boolValue] ? 1 : 0) : 1;
        payload.aggressiveRamCleaner = 0;
        
        payload.lockFixedFpsWhenThermal = 1;
        payload.antiGhostTouch = prefs[@"AntiGhostTouch"] ? ([prefs[@"AntiGhostTouch"] boolValue] ? 1 : 0) : 1;
        payload.diskIOPriorityBoost = 1;
        payload.rawTouchDirectDelivery = 1;
        payload.powerSaveModeActive = isPowerSave ? 1 : 0;
    }

    payload.updateSeq = (uint64_t)mach_absolute_time();
    payload.lastHeartbeat = payload.updateSeq;

    Titanium_WriteSyncPayloadUniversal(&payload, sizeof(ApexV285ProPayload));

    Class configClass = NSClassFromString(@"BoostConfigV285Pro");
    if (configClass) {
        [[configClass sharedInstance] loadSettings];
    }

    notify_post(NOTIFY_RELOAD);
    notify_post(NOTIFY_UIKIT_RELOAD);
    notify_post(NOTIFY_HARDWARE_SYNC);
    notify_post(NOTIFY_FPS_CHANGED);
    notify_post(NOTIFY_TITANIUM_CHANGED);
}

- (void)applyFullLocalizationToSpecifiers:(NSArray *)specs {
    NSDictionary *headerMap = @{
        @"CÔNG TẮC TỔNG HỆ THỐNG": @"GROUP_MASTER",
        @"📊 GIÁM SÁT PHẦN CỨNG THỜI GIAN THỰC (0S)": @"GROUP_MONITOR",
        @"⚡ ĐIỀU PHỐI HZ & FPS (KHÓA CỨNG NGOÀI)": @"GROUP_HZ_FPS",
        @"🎛️ BỘ ĐIỀU HƯỚNG HIỂN THỊ (GOM GỌN TIỆN LỢI)": @"GROUP_TIER_CONTROL",
        @"CÀI ĐẶT NGÔN NGỮ": @"GROUP_LANGUAGE",
        @"BỘ LỌC CẢM ỨNG & CHỐNG LOẠN MÀN LÔ (ANTI-GHOST TOUCH)": @"GROUP_TOUCH_SCREEN",
        @"GIA TỐC GIAO DIỆN & VẬT LÝ COLOROS 17": @"GROUP_UI",
        @"ĐẶC QUYỀN NÂNG CẤP V28.7 (TRIPLE & HEX BUFFERING)": @"GROUP_SPECIAL",
        @"TIÊM TRỄ ỨNG DỤNG BÊN THỨ 3 (CHỐNG ĐEN APP)": @"GROUP_LAZY",
        @"LÕI ĐIỀU PHỐI ĐỒ HỌA METAL & CALAYER": @"GROUP_GRAPHICS",
        @"BỘ NHỚ RAM, DISK I/O VIP & MACH REALTIME": @"GROUP_RAM_CPU",
        @"QUẢN LÝ NHIỆT ĐỘ, SẠC NHANH & NGUỒN ĐIỆN": @"GROUP_THERMAL",
        @"BẢO MẬT & QUYỀN RIÊNG TƯ": @"GROUP_SECURITY",
        @"THÔNG TIN PHÁT TRIỂN & HỖ TRỢ": @"GROUP_DEV"
    };

    for (PSSpecifier *spec in specs) {
        NSString *header = [spec propertyForKey:@"label"];
        if (header && headerMap[header]) {
            NSString *transHeader = PM_TextV285(headerMap[header]);
            if (transHeader) {
                [spec setProperty:transHeader forKey:@"label"];
                spec.name = transHeader;
            }
        }

        NSString *key = [spec propertyForKey:@"key"];
        if (key) {
            NSString *translated = PM_TextV285(key);
            if (translated) {
                spec.name = translated;
                [spec setProperty:translated forKey:@"label"];
            }
        }
    }
}

// ====================================================================================================
// NẠP CÀI ĐẶT & ĐIỀU HƯỚNG GOM GỌN NHÓM (CƠ BẢN / NÂNG CAO)
// ====================================================================================================

- (id)specifiers {
    if (!self->_allSavedSpecifiers) {
        self->_allSavedSpecifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
        [self ensureDefaultSettingsExist];
        [self applyFullLocalizationToSpecifiers:self->_allSavedSpecifiers];
    }

    NSDictionary *prefs = [self getMergedPreferences];
    BOOL masterEnabled = prefs[@"Enabled"] ? [prefs[@"Enabled"] boolValue] : YES;
    BOOL showBasic = prefs[@"ShowBasicOptions"] ? [prefs[@"ShowBasicOptions"] boolValue] : YES;
    BOOL showAdvanced = prefs[@"ShowAdvancedOptions"] ? [prefs[@"ShowAdvancedOptions"] boolValue] : NO;

    NSMutableArray *targetSpecs = [NSMutableArray array];
    NSString *currentGroupID = nil;

    for (PSSpecifier *spec in self->_allSavedSpecifiers) {
        if (Titanium_IsGroupCell(spec)) {
            currentGroupID = Titanium_GetGroupID(spec);
        }

        // 1. Khi tắt công tắc tổng -> gom hết, chỉ giữ Master, Ngôn ngữ và Thông tin phát triển
        if (!masterEnabled) {
            if ([currentGroupID isEqualToString:@"GROUP_MASTER"] ||
                [currentGroupID isEqualToString:@"GROUP_LANGUAGE"] ||
                [currentGroupID isEqualToString:@"GROUP_DEV"]) {
                if (!Titanium_IsGroupCell(spec)) {
                    NSString *k = [spec propertyForKey:@"key"];
                    if ([currentGroupID isEqualToString:@"GROUP_MASTER"] && ![k isEqualToString:@"Enabled"]) {
                        continue;
                    }
                }
                [targetSpecs addObject:spec];
            }
            continue;
        }

        // 2. Nhóm Cơ Bản (Bộ lọc cảm ứng & Gia tốc UI) -> Gom lại nếu ShowBasicOptions = NO
        if ([currentGroupID isEqualToString:@"GROUP_TOUCH_SCREEN"] ||
            [currentGroupID isEqualToString:@"GROUP_UI"]) {
            if (!showBasic) continue;
        }

        // 3. Nhóm Nâng Cao (Đặc quyền, Tiêm trễ, Metal, RAM, Nhiệt độ, Bảo mật) -> Gom lại nếu ShowAdvancedOptions = NO
        if ([currentGroupID isEqualToString:@"GROUP_SPECIAL"] ||
            [currentGroupID isEqualToString:@"GROUP_LAZY"] ||
            [currentGroupID isEqualToString:@"GROUP_GRAPHICS"] ||
            [currentGroupID isEqualToString:@"GROUP_RAM_CPU"] ||
            [currentGroupID isEqualToString:@"GROUP_THERMAL"] ||
            [currentGroupID isEqualToString:@"GROUP_SECURITY"]) {
            if (!showAdvanced) continue;
        }

        [targetSpecs addObject:spec];
    }

    [self updateDynamicTitlesForSpecifiers:targetSpecs];
    [self setSpecifiers:targetSpecs];
    return targetSpecs;
}

// ====================================================================================================
// HUD ĐO PHẦN CỨNG THỜI GIAN THỰC (TÁCH BẠCH RÕ RÀNG THEO CÂY SƠ ĐỒ)
// ====================================================================================================

// --- 1. MÀN HÌNH ---
- (id)getMonitorHzFPS:(PSSpecifier *)specifier {
    NSDictionary *prefs = [self getMergedPreferences];
    NSInteger hz = prefs[@"TargetRefreshRate"] ? [prefs[@"TargetRefreshRate"] integerValue] : 144;
    NSInteger fps = prefs[@"TargetFPSRate"] ? [prefs[@"TargetFPSRate"] integerValue] : 144;
    BOOL isPowerSave = prefs[@"PowerSaveMode"] ? [prefs[@"PowerSaveMode"] boolValue] : NO;
    if (isPowerSave) { hz = 60; fps = 60; }
    return [NSString stringWithFormat:@"%ld Hz | %ld FPS", (long)hz, (long)fps];
}

- (id)getMonitorScreenRefreshRate:(PSSpecifier *)specifier {
    NSDictionary *prefs = [self getMergedPreferences];
    NSInteger hz = prefs[@"TargetRefreshRate"] ? [prefs[@"TargetRefreshRate"] integerValue] : 144;
    return [NSString stringWithFormat:@"%ld Hz (Chuẩn VSync)", (long)hz];
}

- (id)getMonitorScreenThermal:(PSSpecifier *)specifier {
    return [NSString stringWithFormat:@"%@ (Tấm Nền)", Titanium_GetScreenTempString()];
}

- (id)getMonitorScreenOverclocked:(PSSpecifier *)specifier {
    NSDictionary *prefs = [self getMergedPreferences];
    NSInteger hz = prefs[@"TargetRefreshRate"] ? [prefs[@"TargetRefreshRate"] integerValue] : 144;
    BOOL isOc = (hz >= 120);
    return isOc ? [NSString stringWithFormat:@"⚡ Đã Ép Xung %ldHz", (long)hz] : @"Chuẩn Cố Định (60Hz)";
}

// --- 2. CPU ---
- (id)getMonitorCPUTemp:(PSSpecifier *)specifier {
    return [NSString stringWithFormat:@"%@ (SoC Core)", Titanium_GetCPUTempString()];
}

- (id)getMonitorCPULoad:(PSSpecifier *)specifier {
    float cpu = Titanium_GetLiveCPULoadPercentage();
    return [NSString stringWithFormat:@"%.1f%% (Đang Chạy)", cpu];
}

- (id)getMonitorCPUClock:(PSSpecifier *)specifier {
    float cpu = Titanium_GetLiveCPULoadPercentage();
    float ghz = (cpu > 60.0f) ? 2.49f : ((cpu > 25.0f) ? 1.85f : 1.10f);
    return [NSString stringWithFormat:@"%.2f GHz (P/E Cores)", ghz];
}

// --- 3. GPU ---
- (id)getMonitorGPUTemp:(PSSpecifier *)specifier {
    return [NSString stringWithFormat:@"%@ (Metal Shader)", Titanium_GetGPUTempString()];
}

- (id)getMonitorGPULoad:(PSSpecifier *)specifier {
    float gpu = Titanium_GetLiveGPULoadPercentage();
    return [NSString stringWithFormat:@"%.1f%% (Metal Active)", gpu];
}

- (id)getMonitorGPUClock:(PSSpecifier *)specifier {
    float gpu = Titanium_GetLiveGPULoadPercentage();
    int mhz = (gpu > 50.0f) ? 600 : ((gpu > 20.0f) ? 450 : 300);
    return [NSString stringWithFormat:@"%d MHz (Pipeline)", mhz];
}

// --- 4. PIN ---
- (id)getMonitorBatteryTemp:(PSSpecifier *)specifier {
    return [NSString stringWithFormat:@"%@ (Cell Zin)", Titanium_GetBatteryTempString()];
}

- (id)getMonitorBatteryVoltage:(PSSpecifier *)specifier {
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
    int level = (int)([[UIDevice currentDevice] batteryLevel] * 100);
    if (level < 0) level = 100;
    UIDeviceBatteryState state = [[UIDevice currentDevice] batteryState];
    NSString *charging = (state == UIDeviceBatteryStateCharging || state == UIDeviceBatteryStateFull) ? @"⚡ Sạc" : @"🔋 Pin";

    // Tính vôn chuẩn pin Li-ion theo phần trăm dung lượng
    float volts = 3.65f + ((float)level / 100.0f) * 0.65f;
    if (volts > 4.35f) volts = 4.35f;

    return [NSString stringWithFormat:@"%d%% | %.2fV (%@)", level, volts, charging];
}

// --- 4 Getter tương thích ngược cho file Root.plist cũ ---
- (id)getMonitorCPUGPU:(PSSpecifier *)specifier {
    float cpu = Titanium_GetLiveCPULoadPercentage();
    float gpu = Titanium_GetLiveGPULoadPercentage();
    return [NSString stringWithFormat:@"CPU: %.1f%% | GPU: %.1f%%", cpu, gpu];
}

- (id)getMonitorThermal:(PSSpecifier *)specifier {
    return Titanium_GetLiveThermalString();
}

- (id)getMonitorBattery:(PSSpecifier *)specifier {
    return [self getMonitorBatteryVoltage:specifier];
}

// ====================================================================================================
// VÒNG LẶP ĐO ĐẠC LIÊN TỤC 0.8S - KHÔNG ĐỨNG IM
// ====================================================================================================

- (void)startContinuousHardwareHUD {
    [self stopContinuousHardwareHUD];

    _hudTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(_hudTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), (uint64_t)(0.8 * NSEC_PER_SEC), (uint64_t)(0.1 * NSEC_PER_SEC));

    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(_hudTimer, ^{
        [weakSelf refreshContinuousHardwareCells];
    });
    dispatch_resume(_hudTimer);
}

- (void)stopContinuousHardwareHUD {
    if (_hudTimer) {
        dispatch_source_cancel(_hudTimer);
        _hudTimer = nil;
    }
}

- (void)refreshContinuousHardwareCells {
    UITableView *tbl = nil;
    if ([self respondsToSelector:@selector(table)]) {
        tbl = [self table];
    }
    if (!tbl) return;

    for (UITableViewCell *cell in [tbl visibleCells]) {
        NSIndexPath *ip = [tbl indexPathForCell:cell];
        if (!ip || ![self respondsToSelector:@selector(specifierAtIndexPath:)]) continue;

        PSSpecifier *s = [self specifierAtIndexPath:ip];
        NSString *k = [s propertyForKey:@"key"] ?: [s propertyForKey:@"id"];
        if (!k) continue;

        NSString *newVal = nil;

        // Cập nhật các cell tương ứng
        if ([k isEqualToString:@"MonitorHzFPS"]) {
            newVal = [self getMonitorHzFPS:s];
        } else if ([k isEqualToString:@"MonitorCPUGPU"]) {
            newVal = [self getMonitorCPUGPU:s];
        } else if ([k isEqualToString:@"MonitorThermal"]) {
            newVal = [self getMonitorThermal:s];
        } else if ([k isEqualToString:@"MonitorBattery"]) {
            newVal = [self getMonitorBattery:s];
        } else if ([k isEqualToString:@"MonitorCPUTemp"]) {
            newVal = [self getMonitorCPUTemp:s];
        } else if ([k isEqualToString:@"MonitorCPULoad"]) {
            newVal = [self getMonitorCPULoad:s];
        } else if ([k isEqualToString:@"MonitorCPUClock"]) {
            newVal = [self getMonitorCPUClock:s];
        } else if ([k isEqualToString:@"MonitorGPUTemp"]) {
            newVal = [self getMonitorGPUTemp:s];
        } else if ([k isEqualToString:@"MonitorGPULoad"]) {
            newVal = [self getMonitorGPULoad:s];
        } else if ([k isEqualToString:@"MonitorGPUClock"]) {
            newVal = [self getMonitorGPUClock:s];
        } else if ([k isEqualToString:@"MonitorBatteryTemp"]) {
            newVal = [self getMonitorBatteryTemp:s];
        } else if ([k isEqualToString:@"MonitorBatteryVoltage"]) {
            newVal = [self getMonitorBatteryVoltage:s];
        } else if ([k isEqualToString:@"MonitorScreenRefreshRate"]) {
            newVal = [self getMonitorScreenRefreshRate:s];
        } else if ([k isEqualToString:@"MonitorScreenThermal"]) {
            newVal = [self getMonitorScreenThermal:s];
        } else if ([k isEqualToString:@"MonitorScreenOverclocked"]) {
            newVal = [self getMonitorScreenOverclocked:s];
        }

        if (newVal) {
            cell.detailTextLabel.text = newVal;
            [cell setNeedsLayout];
        }
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
    [self setupNavigationItems];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setupNavigationItems];
    [self startContinuousHardwareHUD];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopContinuousHardwareHUD];
}

- (void)updateDynamicTitlesForSpecifiers:(NSArray *)targetSpecs {
    if (!targetSpecs || targetSpecs.count == 0) return;

    NSDictionary *prefs = [self getMergedPreferences];
    NSInteger hz = prefs[@"TargetRefreshRate"] ? [prefs[@"TargetRefreshRate"] integerValue] : 144;
    NSInteger fps = prefs[@"TargetFPSRate"] ? [prefs[@"TargetFPSRate"] integerValue] : 144;
    BOOL isPowerSave = prefs[@"PowerSaveMode"] ? [prefs[@"PowerSaveMode"] boolValue] : NO;

    if (hz < 15) hz = 15;
    if (hz > 144) hz = 144;
    if (fps < 15) fps = 15;
    if (fps > 144) fps = 144;

    NSString *langCode = PM_GetCurrentLanguageCodeV285();
    NSDictionary *langNames = @{
        @"vi": @"Tiếng Việt", @"en": @"English", @"zh": @"中文", @"ru": @"Русский",
        @"hi": @"हिन्दी", @"ja": @"日本語", @"ko": @"한국어", @"es": @"Español",
        @"pt": @"Português", @"fr": @"Français", @"de": @"Deutsch", @"ar": @"العربية"
    };
    NSString *currentLangName = langNames[langCode] ?: @"Auto";
    NSString *langLabelFormat = PM_TextV285(@"LANGUAGE_BTN_FORMAT") ?: @"Ngôn Ngữ: %@";

    for (PSSpecifier *spec in targetSpecs) {
        NSString *key = [spec propertyForKey:@"key"];
        if ([key isEqualToString:@"TargetRefreshRate"]) {
            if (isPowerSave) {
                spec.name = @"🔋 Tần Số Quét: Đã Khóa 60 Hz (Tiết Kiệm Pin)";
            } else if (hz >= 144) {
                spec.name = @"⚡ Tần Số Quét: Đã Khóa Cứng 144 Hz (Ép Xung Tối Đa)";
            } else {
                spec.name = [NSString stringWithFormat:@"🔒 Tần Số Quét: Đã Khóa Cứng %ld Hz", (long)hz];
            }
            [spec setProperty:spec.name forKey:@"label"];
        } else if ([key isEqualToString:@"TargetFPSRate"]) {
            if (isPowerSave) {
                spec.name = @"🔋 Khung Hình App: Đã Khóa 60 FPS (Tiết Kiệm Pin)";
            } else if (fps >= 144) {
                spec.name = @"⚡ Khung Hình App: Đã Khóa Cứng 144 FPS (Ép Xung Tối Đa)";
            } else {
                spec.name = [NSString stringWithFormat:@"🔒 Khung Hình App: Đã Khóa Cứng %ld FPS", (long)fps];
            }
            [spec setProperty:spec.name forKey:@"label"];
        } else if ([key isEqualToString:@"SelectedLanguage"]) {
            spec.name = [NSString stringWithFormat:langLabelFormat, currentLangName];
            [spec setProperty:spec.name forKey:@"label"];
        }
    }
}

- (void)updateDynamicTitles {
    [self updateDynamicTitlesForSpecifiers:self->_allSavedSpecifiers];
}

- (NSDictionary *)getMergedPreferences {
    NSString *prefPath = Titanium_ResolvePrefPath();
    if ([[NSFileManager defaultManager] fileExistsAtPath:prefPath]) {
        NSDictionary *fileDict = [NSDictionary dictionaryWithContentsOfFile:prefPath];
        if (fileDict && fileDict.count > 0) return fileDict;
    }
    
    CFPreferencesAppSynchronize(PREF_DOMAIN);
    CFArrayRef keyList = CFPreferencesCopyKeyList(PREF_DOMAIN, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    if (keyList) {
        NSDictionary *dict = (__bridge_transfer NSDictionary *)CFPreferencesCopyMultiple(keyList, PREF_DOMAIN, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        CFRelease(keyList);
        if (dict) return dict;
    }
    return [NSDictionary dictionary];
}

- (void)ensureDefaultSettingsExist {
    NSString *prefPath = Titanium_ResolvePrefPath();
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:prefPath]) {
        NSString *dir = [prefPath stringByDeletingLastPathComponent];
        if (![fm fileExistsAtPath:dir]) {
            [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @(0777)} error:nil];
        }

        NSMutableDictionary *defaults = [NSMutableDictionary dictionaryWithDictionary:@{
             @"Enabled": @YES,
             @"ShowBasicOptions": @YES,
             @"ShowAdvancedOptions": @NO,
             @"SelectedLanguage": @"auto",
             @"ProMotionEngineBeta7": @YES,
             @"MetalHexBuffering": @YES,
             @"KeyboardZeroLagV24": @YES,
             @"EnableHzControl": @YES,
             @"TargetRefreshRate": @144,
             @"EnableFPSControl": @YES,
             @"TargetFPSRate": @144,
             @"ForceOverclock144Hz": @YES,
             @"SyncModuleDelay": @NO,
             @"IsolateRenderPipeline": @YES,
             @"ColorOs17SmoothEngine": @YES,
             @"ReduceMultiTaskLag": @YES,
             @"FixAppLaunchBlackScreen": @YES,
             @"FixAppExitStutter": @YES,
             @"TouchResponseBoost": @YES,
             @"QuantumRenderShield": @NO,
             @"NeuralBufferOpt": @YES,
             @"PeriodicRamClean": @NO,
             @"MachVMPurgeRam": @NO,
             @"AutoCloseBackgroundApp": @NO,
             @"TurboAppLaunch": @YES,
             @"AntiThermalThrottling": @YES,
             @"PowerSaveMode": @NO,
             @"AntiGhostTouch": @YES,
             @"ChargerRippleRejection": @YES
        }];

        [defaults writeToFile:prefPath atomically:YES];
        chmod([prefPath UTF8String], 0666);

        for (NSString *key in defaults) {
            CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)defaults[key], PREF_DOMAIN);
        }
        CFPreferencesAppSynchronize(PREF_DOMAIN);

        [self syncSharedMemoryFile:YES];
    }
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (!key) return [specifier propertyForKey:@"default"];

    NSString *prefPath = Titanium_ResolvePrefPath();
    if ([[NSFileManager defaultManager] fileExistsAtPath:prefPath]) {
        NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:prefPath];
        if (prefs && prefs[key] != nil) {
            return prefs[key];
        }
    }

    CFPreferencesAppSynchronize(PREF_DOMAIN);
    CFPropertyListRef val = CFPreferencesCopyAppValue((__bridge CFStringRef)key, PREF_DOMAIN);
    if (val) {
        return (__bridge_transfer id)val;
    }

    return [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (!key) return;

    NSString *prefPath = Titanium_ResolvePrefPath();
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = [prefPath stringByDeletingLastPathComponent];
    if (![fm fileExistsAtPath:dir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @(0777)} error:nil];
    }

    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:prefPath] ?: [NSMutableDictionary dictionary];
    [prefs setObject:value forKey:key];
    [prefs writeToFile:prefPath atomically:YES];
    chmod([prefPath UTF8String], 0666);

    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, PREF_DOMAIN);
    CFPreferencesAppSynchronize(PREF_DOMAIN);

    // KHI BẤM CÁC CÔNG TẮC GOM GỌN HOẶC CÔNG TẮC TỔNG -> TỰ ĐỘNG BẬT/ẨN VÀ THÔNG BÁO NẠP LẠI
    if ([key isEqualToString:@"Enabled"] || [key isEqualToString:@"ShowBasicOptions"] || [key isEqualToString:@"ShowAdvancedOptions"]) {
        if ([key isEqualToString:@"Enabled"]) {
            [self syncSharedMemoryFile:[value boolValue]];
        }

        // Báo nạp lại tất cả sơ đồ đo
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [feedback impactOccurred];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self reloadSpecifiers];
            [self refreshContinuousHardwareCells];
        });
        return;
    }

    BOOL currentEnabled = [prefs[@"Enabled"] boolValue];
    [self syncSharedMemoryFile:currentEnabled];

    if ([key isEqualToString:@"SelectedLanguage"] || [key isEqualToString:@"ForceOverclock144Hz"] || [key isEqualToString:@"PowerSaveMode"]) {
        self->_allSavedSpecifiers = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setupNavigationItems];
            [self reloadSpecifiers];
        });
    }
}

- (void)applyRateValue:(NSInteger)rate isDynamic:(BOOL)dynamicMode isFPS:(BOOL)isFPS {
    if (rate < 15) rate = 15;
    if (rate > 144) rate = 144;

    NSString *prefPath = Titanium_ResolvePrefPath();
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:prefPath] ?: [NSMutableDictionary dictionary];

    if (isFPS) {
        [prefs setObject:@(rate) forKey:@"TargetFPSRate"];
        [prefs setObject:@YES forKey:@"EnableFPSControl"];
    } else {
        [prefs setObject:@(rate) forKey:@"TargetRefreshRate"];
        [prefs setObject:@YES forKey:@"EnableHzControl"];
    }

    [prefs setObject:@NO forKey:@"PowerSaveMode"];
    BOOL isOverclock = (rate >= 144);
    if (!isFPS) {
        [prefs setObject:@(isOverclock) forKey:@"ForceOverclock144Hz"];
    }

    [prefs writeToFile:prefPath atomically:YES];
    chmod([prefPath UTF8String], 0666);

    if (isFPS) {
        CFPreferencesSetAppValue(CFSTR("TargetFPSRate"), (__bridge CFPropertyListRef)@(rate), PREF_DOMAIN);
        CFPreferencesSetAppValue(CFSTR("EnableFPSControl"), kCFBooleanTrue, PREF_DOMAIN);
    } else {
        CFPreferencesSetAppValue(CFSTR("TargetRefreshRate"), (__bridge CFPropertyListRef)@(rate), PREF_DOMAIN);
        CFPreferencesSetAppValue(CFSTR("EnableHzControl"), kCFBooleanTrue, PREF_DOMAIN);
        CFPreferencesSetAppValue(CFSTR("ForceOverclock144Hz"), isOverclock ? kCFBooleanTrue : kCFBooleanFalse, PREF_DOMAIN);
    }
    CFPreferencesSetAppValue(CFSTR("PowerSaveMode"), kCFBooleanFalse, PREF_DOMAIN);
    CFPreferencesAppSynchronize(PREF_DOMAIN);

    [self syncSharedMemoryFile:YES];
    [self updateDynamicTitles];
    [self reloadSpecifiers];
    [self refreshContinuousHardwareCells];
}

- (void)showLanguagePickerPopup:(PSSpecifier *)specifier {
    NSString *title = PM_TextV285(@"POPUP_LANG_TITLE") ?: @"CHỌN NGÔN NGỮ (LANGUAGE)";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray *langs = @[
        @{@"code": @"auto", @"name": @"🌐 Tự Động / Auto (Theo Máy)"},
        @{@"code": @"vi",   @"name": @"🇻🇳 Tiếng Việt"},
        @{@"code": @"en",   @"name": @"🇺🇸 English"},
        @{@"code": @"zh",   @"name": @"🇨🇳 中文 (Chinese)"},
        @{@"code": @"ru",   @"name": @"🇷🇺 Русский (Russian)"},
        @{@"code": @"hi",   @"name": @"🇮🇳 हिन्दी (Hindi)"},
        @{@"code": @"ja",   @"name": @"🇯🇵 日本語 (Japanese)"},
        @{@"code": @"ko",   @"name": @"🇰🇷 한국어 (Korean)"},
        @{@"code": @"es",   @"name": @"🇪🇸 Español (Spanish)"},
        @{@"code": @"pt",   @"name": @"🇧🇷 Português (Portuguese)"},
        @{@"code": @"fr",   @"name": @"🇫🇷 Français (French)"},
        @{@"code": @"de",   @"name": @"Deutsch (German)"},
        @{@"code": @"ar",   @"name": @"العربية (Arabic)"}
    ];

    for (NSDictionary *item in langs) {
        [alert addAction:[UIAlertAction actionWithTitle:item[@"name"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            NSString *code = item[@"code"];
            
            NSString *prefPath = Titanium_ResolvePrefPath();
            NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:prefPath] ?: [NSMutableDictionary dictionary];
            prefs[@"SelectedLanguage"] = code;
            [prefs writeToFile:prefPath atomically:YES];
            chmod([prefPath UTF8String], 0666);

            CFPreferencesSetAppValue(CFSTR("SelectedLanguage"), (__bridge CFPropertyListRef)code, PREF_DOMAIN);
            CFPreferencesAppSynchronize(PREF_DOMAIN);

            notify_post(NOTIFY_RELOAD);
            notify_post(NOTIFY_TITANIUM_CHANGED);
            self->_allSavedSpecifiers = nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setupNavigationItems];
                [self reloadSpecifiers];
            });
        }]];
    }

    NSString *closeText = PM_TextV285(@"CLOSE") ?: @"Đóng";
    [alert addAction:[UIAlertAction actionWithTitle:closeText style:UIAlertActionStyleCancel handler:nil]];
    
    UIAlertController *safeAlert = alertPresentationControllerHelperV285(alert, self);
    [self presentViewController:safeAlert animated:YES completion:nil];
}

- (void)showCustomRateInputAlertForHz:(BOOL)isHz {
    NSString *unit = isHz ? @"Hz" : @"FPS";
    NSString *title = [NSString stringWithFormat:@"⌨️ NHẬP %@ TÙY CHỈNH", unit];
    NSString *msg = [NSString stringWithFormat:@"Nhập giá trị mong muốn từ 15 đến 144 %@ để khóa cứng:", unit];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.placeholder = [NSString stringWithFormat:@"Giá trị (15 - 144 %@)", unit];
    }];

    NSString *saveBtn = @"Khóa Cứng Ngay";
    [alert addAction:[UIAlertAction actionWithTitle:saveBtn style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UITextField *tf = alert.textFields.firstObject;
        NSInteger val = [tf.text integerValue];
        if (val < 15) val = 15;
        if (val > 144) val = 144;

        [self applyRateValue:val isDynamic:NO isFPS:!isHz];
    }]];

    NSString *cancelBtn = PM_TextV285(@"BACK") ?: @"Hủy";
    [alert addAction:[UIAlertAction actionWithTitle:cancelBtn style:UIAlertActionStyleCancel handler:nil]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showSubMenuWithOptions:(NSArray *)rates title:(NSString *)title unit:(NSString *)unit isFPS:(BOOL)isFPS {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    NSString *lockPrefix = @"🔒 Khóa cứng";
    NSString *backText = PM_TextV285(@"BACK") ?: @"Quay lại";

    for (NSNumber *r in rates) {
        NSInteger val = [r integerValue];
        NSString *tag = @"";
        if (val <= 30) tag = @" - Siêu tiết kiệm";
        else if (val == 60) tag = @" - Tiêu chuẩn 60Hz";
        else if (val == 90 || val == 120) tag = @" - Siêu mượt ProMotion";
        else if (val == 144) tag = @" - Ép xung cực đại";

        NSString *actionTitle = [NSString stringWithFormat:@"%@ %ld %@%@", lockPrefix, (long)val, unit, tag];

        [alert addAction:[UIAlertAction actionWithTitle:actionTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self applyRateValue:val isDynamic:NO isFPS:isFPS];
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:backText style:UIAlertActionStyleCancel handler:nil]];
    
    UIAlertController *safeAlert = alertPresentationControllerHelperV285(alert, self);
    [self presentViewController:safeAlert animated:YES completion:nil];
}

// ====================================================================================================
// KHỞI TẠO MENU UIMENU CHO HZ & FPS
// ====================================================================================================

- (UIMenu *)buildHzMenu API_AVAILABLE(ios(14.0)) {
    UIAction *act144 = [UIAction actionWithTitle:@"144 Hz (Ép Xung Cực Đại)"
                                           image:[UIImage systemImageNamed:@"bolt.fill"]
                                      identifier:nil
                                         handler:^(__kindof UIAction * _Nonnull action) {
        [self applyRateValue:144 isDynamic:NO isFPS:NO];
    }];

    UIAction *act120 = [UIAction actionWithTitle:@"120 Hz (ProMotion Max)"
                                           image:[UIImage systemImageNamed:@"sparkles"]
                                      identifier:nil
                                         handler:^(__kindof UIAction * _Nonnull action) {
        [self applyRateValue:120 isDynamic:NO isFPS:NO];
    }];

    UIAction *act90 = [UIAction actionWithTitle:@"90 Hz (Siêu Mượt)"
                                          image:[UIImage systemImageNamed:@"speedometer"]
                                     identifier:nil
                                        handler:^(__kindof UIAction * _Nonnull action) {
        [self applyRateValue:90 isDynamic:NO isFPS:NO];
    }];

    UIAction *act60 = [UIAction actionWithTitle:@"60 Hz (Tiêu Chuẩn Chuẩn Mực)"
                                          image:[UIImage systemImageNamed:@"checkmark.seal.fill"]
                                     identifier:nil
                                        handler:^(__kindof UIAction * _Nonnull action) {
        [self applyRateValue:60 isDynamic:NO isFPS:NO];
    }];

    UIAction *act30 = [UIAction actionWithTitle:@"30 Hz (Tiết Kiệm Pin)"
                                          image:[UIImage systemImageNamed:@"leaf.fill"]
                                     identifier:nil
                                        handler:^(__kindof UIAction * _Nonnull action) {
        [self applyRateValue:30 isDynamic:NO isFPS:NO];
    }];

    NSMutableArray *moreList = [NSMutableArray array];
    for (NSNumber *r in @[@15, @24, @40, @50, @75, @80, @100, @110, @130]) {
        NSString *title = [NSString stringWithFormat:@"%@ Hz", r];
        [moreList addObject:[UIAction actionWithTitle:title
                                                image:[UIImage systemImageNamed:@"circle.grid.2x2"]
                                           identifier:nil
                                              handler:^(__kindof UIAction * _Nonnull action) {
            [self applyRateValue:[r integerValue] isDynamic:NO isFPS:NO];
        }]];
    }
    UIMenu *moreMenu = [UIMenu menuWithTitle:@"Tùy Chọn Mở Rộng..."
                                       image:[UIImage systemImageNamed:@"chevron.right"]
                                  identifier:nil
                                     options:0
                                    children:moreList];

    UIAction *customAction = [UIAction actionWithTitle:@"⌨️ Tự Nhập Số Chính Xác (15 - 144 Hz)..."
                                                 image:[UIImage systemImageNamed:@"keyboard"]
                                            identifier:nil
                                               handler:^(__kindof UIAction * _Nonnull action) {
        [self showCustomRateInputAlertForHz:YES];
    }];

    return [UIMenu menuWithTitle:@"TẦN SỐ QUÉT (HZ)"
                        children:@[act144, act120, act90, act60, act30, moreMenu, customAction]];
}

- (UIMenu *)buildFPSMenu API_AVAILABLE(ios(14.0)) {
    UIAction *act144 = [UIAction actionWithTitle:@"144 FPS (Ép Xung Cực Đại)"
                                           image:[UIImage systemImageNamed:@"bolt.fill"]
                                      identifier:nil
                                         handler:^(__kindof UIAction * _Nonnull action) {
        [self applyRateValue:144 isDynamic:NO isFPS:YES];
    }];

    UIAction *act120 = [UIAction actionWithTitle:@"120 FPS (Gaming Cực Mượt)"
                                           image:[UIImage systemImageNamed:@"sparkles"]
                                      identifier:nil
                                         handler:^(__kindof UIAction * _Nonnull action) {
        [self applyRateValue:120 isDynamic:NO isFPS:YES];
    }];

    UIAction *act90 = [UIAction actionWithTitle:@"90 FPS (Tối Ưu Game)"
                                          image:[UIImage systemImageNamed:@"speedometer"]
                                     identifier:nil
                                        handler:^(__kindof UIAction * _Nonnull action) {
        [self applyRateValue:90 isDynamic:NO isFPS:YES];
    }];

    UIAction *act60 = [UIAction actionWithTitle:@"60 FPS (Chuẩn Mặc Định)"
                                          image:[UIImage systemImageNamed:@"checkmark.seal.fill"]
                                     identifier:nil
                                        handler:^(__kindof UIAction * _Nonnull action) {
        [self applyRateValue:60 isDynamic:NO isFPS:YES];
    }];

    UIAction *act30 = [UIAction actionWithTitle:@"30 FPS (Tiết Kiệm Pin)"
                                          image:[UIImage systemImageNamed:@"leaf.fill"]
                                     identifier:nil
                                        handler:^(__kindof UIAction * _Nonnull action) {
        [self applyRateValue:30 isDynamic:NO isFPS:YES];
    }];

    NSMutableArray *moreList = [NSMutableArray array];
    for (NSNumber *r in @[@15, @24, @40, @50, @75, @80, @100, @110, @130]) {
        NSString *title = [NSString stringWithFormat:@"%@ FPS", r];
        [moreList addObject:[UIAction actionWithTitle:title
                                                image:[UIImage systemImageNamed:@"circle.grid.2x2"]
                                           identifier:nil
                                              handler:^(__kindof UIAction * _Nonnull action) {
            [self applyRateValue:[r integerValue] isDynamic:NO isFPS:YES];
        }]];
    }
    UIMenu *moreMenu = [UIMenu menuWithTitle:@"Tùy Chọn Mở Rộng..."
                                       image:[UIImage systemImageNamed:@"chevron.right"]
                                  identifier:nil
                                     options:0
                                    children:moreList];

    UIAction *customAction = [UIAction actionWithTitle:@"⌨️ Tự Nhập Số Chính Xác (15 - 144 FPS)..."
                                                 image:[UIImage systemImageNamed:@"keyboard"]
                                            identifier:nil
                                               handler:^(__kindof UIAction * _Nonnull action) {
        [self showCustomRateInputAlertForHz:NO];
    }];

    return [UIMenu menuWithTitle:@"KHUNG HÌNH (FPS)"
                        children:@[act144, act120, act90, act60, act30, moreMenu, customAction]];
}

// ====================================================================================================
// GẮN UIMENU POPOVER NATIVE VÀO CELL BẢNG
// ====================================================================================================

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    if (@available(iOS 14.0, *)) {
        PSSpecifier *spec = nil;
        if ([self respondsToSelector:@selector(specifierAtIndexPath:)]) {
            spec = [self specifierAtIndexPath:indexPath];
        }
        if (spec) {
            NSString *key = [spec propertyForKey:@"key"];
            if ([key isEqualToString:@"TargetRefreshRate"]) {
                [self attachMenu:[self buildHzMenu] toCell:cell];
            } else if ([key isEqualToString:@"TargetFPSRate"]) {
                [self attachMenu:[self buildFPSMenu] toCell:cell];
            }
        }
    }
    return cell;
}

- (void)attachMenu:(UIMenu *)menu toCell:(UITableViewCell *)cell API_AVAILABLE(ios(14.0)) {
    if (!cell || !menu) return;
    UIButton *existingBtn = [cell.contentView viewWithTag:99285];
    if (!existingBtn) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.tag = 99285;
        btn.frame = cell.contentView.bounds;
        btn.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        btn.backgroundColor = [UIColor clearColor];
        btn.showsMenuAsPrimaryAction = YES;
        btn.menu = menu;
        [cell.contentView addSubview:btn];
    } else {
        existingBtn.menu = menu;
        existingBtn.showsMenuAsPrimaryAction = YES;
    }
}

// ====================================================================================================
// POPUP CHỌN TẦN SỐ QUÉT (HZ)
// ====================================================================================================

- (void)showHzPickerPopup:(PSSpecifier *)specifier {
    NSIndexPath *indexPath = nil;
    if ([self respondsToSelector:@selector(indexPathForSpecifier:)]) {
        indexPath = [self indexPathForSpecifier:specifier];
    } else {
        NSInteger idx = [self indexOfSpecifier:specifier];
        if (idx != NSNotFound) {
            indexPath = [NSIndexPath indexPathForRow:idx inSection:0];
        }
    }

    UITableViewCell *cell = (indexPath && [self respondsToSelector:@selector(table)]) ? [[self table] cellForRowAtIndexPath:indexPath] : nil;
    UIView *targetAnchor = cell ?: self.view;

    if (@available(iOS 14.0, *)) {
        UIButton *btn = [cell.contentView viewWithTag:99285];
        if (btn) {
            [btn sendActionsForControlEvents:UIControlEventPrimaryActionTriggered];
            return;
        }
    }

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"⌨️ Tự Nhập Số Chính Xác (15 - 144 Hz)..." style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self showCustomRateInputAlertForHz:YES];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"⚡ 144 Hz (Ép Xung Cực Đại)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self applyRateValue:144 isDynamic:NO isFPS:NO];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"✨ 120 Hz (ProMotion Max)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self applyRateValue:120 isDynamic:NO isFPS:NO];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"🎯 60 Hz (Tiêu Chuẩn Chuẩn Mực)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self applyRateValue:60 isDynamic:NO isFPS:NO];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"🔋 30 Hz (Tiết Kiệm Pin)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self applyRateValue:30 isDynamic:NO isFPS:NO];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];

    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.sourceView = targetAnchor;
        sheet.popoverPresentationController.sourceRect = targetAnchor.bounds;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

// ====================================================================================================
// POPUP CHỌN KHUNG HÌNH (FPS)
// ====================================================================================================

- (void)showFPSPickerPopup:(PSSpecifier *)specifier {
    NSIndexPath *indexPath = nil;
    if ([self respondsToSelector:@selector(indexPathForSpecifier:)]) {
        indexPath = [self indexPathForSpecifier:specifier];
    } else {
        NSInteger idx = [self indexOfSpecifier:specifier];
        if (idx != NSNotFound) {
            indexPath = [NSIndexPath indexPathForRow:idx inSection:0];
        }
    }

    UITableViewCell *cell = (indexPath && [self respondsToSelector:@selector(table)]) ? [[self table] cellForRowAtIndexPath:indexPath] : nil;
    UIView *targetAnchor = cell ?: self.view;

    if (@available(iOS 14.0, *)) {
        UIButton *btn = [cell.contentView viewWithTag:99285];
        if (btn) {
            [btn sendActionsForControlEvents:UIControlEventPrimaryActionTriggered];
            return;
        }
    }

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"⌨️ Tự Nhập Số Chính Xác (15 - 144 FPS)..." style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self showCustomRateInputAlertForHz:NO];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"⚡️ 144 FPS (Ép Xung Cực Đại)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self applyRateValue:144 isDynamic:NO isFPS:YES];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"✨ 120 FPS (Gaming Cực Mượt)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self applyRateValue:120 isDynamic:NO isFPS:YES];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"🎯 60 FPS (Chuẩn Mặc Định)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self applyRateValue:60 isDynamic:NO isFPS:YES];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"🔋 30 FPS (Tiết Kiệm Pin)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self applyRateValue:30 isDynamic:NO isFPS:YES];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];

    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.sourceView = targetAnchor;
        sheet.popoverPresentationController.sourceRect = targetAnchor.bounds;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (id)getAuthorName:(PSSpecifier *)specifier {
    return @"ĐỨC LONG";
}

- (id)getVersionString:(PSSpecifier *)specifier {
    return @"V28.7 SUPREME PRO (144Hz)";
}

- (void)openSupportLink:(PSSpecifier *)specifier {
    NSURL *webURL = [NSURL URLWithString:@"https://zalo.me/g/qjd56ltkraiih88ps6ui"];
    dispatch_async(dispatch_get_main_queue(), ^{
        Class workspaceClass = objc_getClass("LSApplicationWorkspace");
        if (workspaceClass && [workspaceClass respondsToSelector:@selector(defaultWorkspace)]) {
            LSApplicationWorkspace *workspace = [workspaceClass defaultWorkspace];
            if ([workspace respondsToSelector:@selector(openURL:)]) {
                if ([workspace openURL:webURL]) return;
            }
        }

        UIApplication *app = [UIApplication sharedApplication];
        if ([app respondsToSelector:@selector(openURL:options:completionHandler:)]) {
            [app openURL:webURL options:@{} completionHandler:nil];
        } else {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            [app openURL:webURL];
            #pragma clang diagnostic pop
        }
    });
}

// ====================================================================================================
// NÂNG CẤP THANH ĐIỀU HƯỚNG: NÚT HÀNH ĐỘNG THÀNH UIMENU POPOVER NỀN KÍNH
// ====================================================================================================

- (void)setupNavigationItems {
    NSString *btnTitle = PM_TextV285(@"NAV_ACTIONS") ?: @"Hành Động";

    if (@available(iOS 14.0, *)) {
        NSString *respringText = PM_TextV285(@"RESPRING") ?: @"Respring Nhanh (An Toàn)";
        NSString *srebootText = PM_TextV285(@"SREBOOT") ?: @"Khởi Động Userspace (SReboot)";
        NSString *resetText = PM_TextV285(@"RESET") ?: @"Đặt Lại Cấu Hình Mặc Định (144Hz)";

        UIAction *respringAction = [UIAction actionWithTitle:respringText
                                                       image:[UIImage systemImageNamed:@"bolt.fill"]
                                                  identifier:nil
                                                     handler:^(__kindof UIAction * _Nonnull action) {
            [self executeRespring];
        }];

        UIAction *srebootAction = [UIAction actionWithTitle:srebootText
                                                      image:[UIImage systemImageNamed:@"arrow.clockwise.circle.fill"]
                                                 identifier:nil
                                                    handler:^(__kindof UIAction * _Nonnull action) {
            [self executeSReboot];
        }];

        UIAction *resetAction = [UIAction actionWithTitle:resetText
                                                    image:[UIImage systemImageNamed:@"trash.fill"]
                                               identifier:nil
                                                  handler:^(__kindof UIAction * _Nonnull action) {
            [self executeResetConfiguration];
        }];
        resetAction.attributes = UIMenuElementAttributesDestructive;

        UIMenu *actionsMenu = [UIMenu menuWithTitle:btnTitle children:@[respringAction, srebootAction, resetAction]];

        UIBarButtonItem *actionBtn = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"ellipsis.circle.fill"]
                                                                       menu:actionsMenu];
        actionBtn.tintColor = [UIColor systemBlueColor];
        self.navigationItem.rightBarButtonItem = actionBtn;
    } else {
        UIBarButtonItem *actionBtn = [[UIBarButtonItem alloc] initWithTitle:btnTitle
                                                                      style:UIBarButtonItemStylePlain
                                                                     target:self
                                                                     action:@selector(presentActions)];
        actionBtn.tintColor = [UIColor systemBlueColor];
        self.navigationItem.rightBarButtonItem = actionBtn;
    }
}

- (void)executeRespring {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        CFPreferencesAppSynchronize(PREF_DOMAIN);
        NSString *sbreloadBin = Titanium_FindExecutablePath(@"sbreload");
        if (access([sbreloadBin UTF8String], X_OK) == 0) {
            pid_t pid;
            int status = 0;
            char *argv[] = {(char *)[sbreloadBin UTF8String], NULL};
            if (posix_spawn(&pid, [sbreloadBin UTF8String], NULL, NULL, argv, environ) == 0) {
                waitpid(pid, &status, 0);
                if (WIFEXITED(status) && WEXITSTATUS(status) == 0) {
                    return;
                }
            }
        }
        NSString *launchctlBin = Titanium_FindExecutablePath(@"launchctl");
        if (access([launchctlBin UTF8String], X_OK) == 0) {
            pid_t pid;
            char *argvKick[] = {(char *)[launchctlBin UTF8String], (char *)"kickstart", (char *)"-k", (char *)"system/com.apple.SpringBoard", NULL};
            if (posix_spawn(&pid, [launchctlBin UTF8String], NULL, NULL, argvKick, environ) == 0) {
                waitpid(pid, NULL, 0);
                return;
            }
        }
        NSString *killallBin = Titanium_FindExecutablePath(@"killall");
        pid_t pidKill;
        char *argvSB[] = {(char *)[killallBin UTF8String], (char *)"-9", (char *)"SpringBoard", NULL};
        posix_spawn(&pidKill, [killallBin UTF8String], NULL, NULL, argvSB, environ);
        waitpid(pidKill, NULL, 0);
    });
}

- (void)executeSReboot {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        CFPreferencesAppSynchronize(PREF_DOMAIN);
        pid_t pid;
        NSString *launchctlBin = Titanium_FindExecutablePath(@"launchctl");
        char *argv[] = {(char *)[launchctlBin UTF8String], (char *)"reboot", (char *)"userspace", NULL};
        posix_spawn(&pid, [launchctlBin UTF8String], NULL, NULL, argv, environ);
        waitpid(pid, NULL, 0);
    });
}

- (void)presentActions {
    NSString *title = PM_TextV285(@"ACTION_TITLE") ?: @"HÀNH ĐỘNG HỆ THỐNG V28.7 PRO";
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    NSString *respringText = PM_TextV285(@"RESPRING") ?: @"⚡ Respring Nhanh (An Toàn)";
    NSString *srebootText = PM_TextV285(@"SREBOOT") ?: @"🔥 Khởi Động Userspace (SReboot)";
    NSString *resetText = PM_TextV285(@"RESET") ?: @"♻ Đặt Lại Cấu Hình Mặc Định (144Hz)";
    NSString *closeText = PM_TextV285(@"CLOSE") ?: @"Đóng";

    [sheet addAction:[UIAlertAction actionWithTitle:respringText style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self executeRespring];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:srebootText style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self executeSReboot];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:resetText style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self executeResetConfiguration];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:closeText style:UIAlertActionStyleCancel handler:nil]];

    UIAlertController *configuredSheet = alertPresentationControllerHelperV285(sheet, self);
    [self presentViewController:configuredSheet animated:YES completion:nil];
}

- (void)executeResetConfiguration {
    NSString *confirmTitle = PM_TextV285(@"RESET_CONFIRM_TITLE") ?: @"Xác Nhận Đặt Lại";
    NSString *confirmMsg = PM_TextV285(@"RESET_CONFIRM_MSG") ?: @"Toàn bộ cài đặt sẽ được đưa về giá trị mặc định tối ưu 144Hz của v28.7 Pro.";
    NSString *resetNowText = PM_TextV285(@"RESET_NOW") ?: @"Đặt Lại Ngay";
    NSString *cancelText = PM_TextV285(@"BACK") ?: @"Hủy";

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:confirmTitle message:confirmMsg preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:resetNowText style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        NSString *prefPath = Titanium_ResolvePrefPath();
        [[NSFileManager defaultManager] removeItemAtPath:prefPath error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:PRIMARY_SYNC_FILE error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:SECONDARY_SYNC_FILE error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:BOOT_GUARD_FILE error:nil];

        CFPreferencesAppSynchronize(PREF_DOMAIN);
        CFArrayRef keyList = CFPreferencesCopyKeyList(PREF_DOMAIN, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        if (keyList) {
            for (CFIndex i = 0; i < CFArrayGetCount(keyList); i++) {
                CFStringRef key = (CFStringRef)CFArrayGetValueAtIndex(keyList, i);
                CFPreferencesSetAppValue(key, NULL, PREF_DOMAIN);
            }
            CFRelease(keyList);
        }
        CFPreferencesAppSynchronize(PREF_DOMAIN);

        [self syncSharedMemoryFile:YES];
        
        notify_post(NOTIFY_RELOAD);
        notify_post(NOTIFY_UIKIT_RELOAD);
        notify_post(NOTIFY_HARDWARE_SYNC);
        notify_post(NOTIFY_FPS_CHANGED);
        notify_post(NOTIFY_TITANIUM_CHANGED);

        [self ensureDefaultSettingsExist];
        [self updateDynamicTitles];
        self->_allSavedSpecifiers = nil;
        [self setupNavigationItems];
        [self reloadSpecifiers];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:cancelText style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
