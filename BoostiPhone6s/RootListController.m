#import <UIKit/UIKit.h>
#import <objc/runtime.h>
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

#define PREF_DOMAIN CFSTR("com.taojb.boostiphone6s")
#define SHARED_SYNC_FILE @"/tmp/.boost_hz_sync"
#define BOOT_GUARD_FILE @"/tmp/.boost_boot_counter"

#define NOTIFY_RELOAD "com.taojb.boostiphone6s/ReloadPrefs"
#define NOTIFY_UIKIT_RELOAD "com.taojb.boostiphone6s/ReloadUIKitPrefs"
#define NOTIFY_HARDWARE_SYNC "com.taojb.boostiphone6s/HardwareSync"
#define NOTIFY_FPS_CHANGED "com.taojb.boostiphone6s/FPSChanged"
#define NOTIFY_TITANIUM_CHANGED "com.titanium.v285.prefschanged"

#define APEX_SYNC_MAGIC_V285 0x56323835

extern char **environ;

@interface BoostConfigV285Pro : NSObject
+ (instancetype)sharedInstance;
- (void)loadSettings;
@end

// ====================================================================================================
// BỘ PHÂN GIẢI ĐƯỜNG DẪN ĐỘNG & KIỂM TRA PHẦN CỨNG 120HZ
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
        return jbPath;
    }
    return @"/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist";
}

// Nhận diện phần cứng (không dùng bóp xung 60Hz)
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

// ====================================================================================================
// ĐỒNG BỘ CHUẨN XÁC 100% CẤU TRÚC STRUCT V28.7 PRO VỚI TWEAK.XM
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

enum PSCellType {
    PSGroupCell = 0,
    PSLinkCell = 1,
    PSLinkListCell = 2,
    PSSwitchCell = 6,
    PSButtonCell = 13
};

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)openURL:(NSURL *)url;
@end

@interface PSListController : UIViewController {
    id _specifiers;
}
- (id)specifiers;
- (void)reloadSpecifiers;
- (id)loadSpecifiersFromPlistName:(NSString *)name target:(id)target bundle:(NSBundle *)bundle;
@end

@interface PSSpecifier : NSObject
@property (nonatomic, strong) NSString *name;
- (NSInteger)cellType;
+ (instancetype)preferenceSpecifierNamed:(NSString *)name target:(id)target set:(SEL)set get:(SEL)get detail:(Class)detail cell:(NSInteger)cell edit:(Class)edit;
+ (instancetype)groupSpecifierWithName:(NSString *)name;
- (id)propertyForKey:(NSString *)key;
- (void)setProperty:(id)property forKey:(NSString *)key;
@end

@interface RootListController : PSListController {
    NSArray *_allSavedSpecifiers;
}
@property (nonatomic, strong) dispatch_source_t debounceSyncTimer;
@property (nonatomic, strong) dispatch_source_t stepDownTimer; // Timer hạ nhịp từ từ
@property (nonatomic, strong) dispatch_queue_t syncQueue;
@end

static inline BOOL Titanium_IsGroupCell(PSSpecifier *spec) {
    id cellVal = [spec propertyForKey:@"cell"];
    if ([cellVal isKindOfClass:[NSString class]]) {
        return [cellVal isEqualToString:@"PSGroupCell"];
    }
    if ([spec respondsToSelector:@selector(cellType)]) {
        return [spec cellType] == PSGroupCell;
    }
    if ([cellVal isKindOfClass:[NSNumber class]]) {
        return [cellVal integerValue] == PSGroupCell;
    }
    return NO;
}

static inline NSString *Titanium_GetGroupID(PSSpecifier *spec) {
    NSString *gid = [spec propertyForKey:@"groupID"];
    if (gid) return gid;
    NSString *lbl = [spec propertyForKey:@"label"] ?: spec.name ?: @"";
    if ([lbl containsString:@"CÔNG TẮC TỔNG"] || [lbl containsString:@"MASTER"]) return @"GROUP_MASTER";
    if ([lbl containsString:@"NGÔN NGỮ"] || [lbl containsString:@"LANGUAGE"]) return @"GROUP_LANGUAGE";
    if ([lbl containsString:@"THÔNG TIN"] || [lbl containsString:@"DEV"] || [lbl containsString:@"HỖ TRỢ"]) return @"GROUP_DEV";
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

@implementation RootListController

- (instancetype)init {
    self = [super init];
    if (self) {
        _syncQueue = dispatch_queue_create("com.titanium.v285.rootsync", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

// ====================================================================================================
// ĐỒNG BỘ BỘ NHỚ CHIA SẺ & GỬI TÍN HIỆU ĐIỀU KHIỂN
// ====================================================================================================
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
        payload.smartBufferingLevel = 3;
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
        int32_t hz = prefs[@"TargetRefreshRate"] ? (int32_t)[prefs[@"TargetRefreshRate"] intValue] : 120;
        int32_t fps = prefs[@"TargetFPSRate"] ? (int32_t)[prefs[@"TargetFPSRate"] intValue] : 120;
        BOOL isPowerSave = prefs[@"PowerSaveMode"] ? [prefs[@"PowerSaveMode"] boolValue] : NO;
        BOOL isOverclock = prefs[@"ForceOverclock144Hz"] ? [prefs[@"ForceOverclock144Hz"] boolValue] : NO;

        if (isPowerSave) {
            hz = 30;
            fps = 30;
        } else if (isOverclock) {
            hz = 144;
            fps = 144;
        } else {
            if (hz < 15) hz = 15;
            if (hz > 144) hz = 144;
            if (fps < 15) fps = 15;
            if (fps > 144) fps = 144;
        }

        payload.targetHz = hz;
        payload.targetFPS = fps;
        payload.forceOverclock = isOverclock ? 1 : 0;
        payload.dynamicInterpolation = 0; // Khóa cứng tuyệt đối
        payload.pipSyncEnabled = 1;
        payload.thermalShield = prefs[@"AntiThermalThrottling"] ? ([prefs[@"AntiThermalThrottling"] boolValue] ? 1 : 0) : 1;
        payload.antiStutterExit = prefs[@"FixAppExitStutter"] ? ([prefs[@"FixAppExitStutter"] boolValue] ? 1 : 0) : 1;
        payload.smartBufferingLevel = 3;
        payload.zeroLatencyTouch = prefs[@"TouchResponseBoost"] ? ([prefs[@"TouchResponseBoost"] boolValue] ? 1 : 0) : 1;
        payload.shaderOptimization = 1;
        payload.fastAppLaunch = prefs[@"TurboAppLaunch"] ? ([prefs[@"TurboAppLaunch"] boolValue] ? 1 : 0) : 1;
        payload.lowLatencyAudio = 1;
        payload.memoryPressureRelief = 1;
        payload.metalPacingEnabled = 1;
        payload.runloopHangGuard = 1;
        payload.keyboardZeroLagV3 = prefs[@"KeyboardZeroLagV24"] ? ([prefs[@"KeyboardZeroLagV24"] boolValue] ? 1 : 0) : 1;
        payload.aggressiveRamCleaner = prefs[@"AggressiveRamClean"] ? ([prefs[@"AggressiveRamClean"] boolValue] ? 1 : 0) : 0;
        payload.lockFixedFpsWhenThermal = payload.thermalShield;
        payload.antiGhostTouch = prefs[@"AntiGhostTouch"] ? ([prefs[@"AntiGhostTouch"] boolValue] ? 1 : 0) : 1;
        payload.diskIOPriorityBoost = 1;
        payload.rawTouchDirectDelivery = 1;
        payload.powerSaveModeActive = isPowerSave ? 1 : 0;
    }

    payload.updateSeq = (uint64_t)mach_absolute_time();
    payload.lastHeartbeat = payload.updateSeq;

    int fd = open([SHARED_SYNC_FILE UTF8String], O_WRONLY | O_CREAT | O_TRUNC, 0666);
    if (fd >= 0) {
        write(fd, &payload, sizeof(ApexV285ProPayload));
        close(fd);
        chmod([SHARED_SYNC_FILE UTF8String], 0666);
    }

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

// Bơm nấc trung gian hạ nhịp đồng bộ CẢ HZ LẪN FPS song song
- (void)emitTransientRate:(NSInteger)rate {
    ApexV285ProPayload payload;
    memset(&payload, 0, sizeof(ApexV285ProPayload));
    
    int fdRead = open([SHARED_SYNC_FILE UTF8String], O_RDONLY);
    if (fdRead >= 0) {
        read(fdRead, &payload, sizeof(ApexV285ProPayload));
        close(fdRead);
    } else {
        payload.magic = APEX_SYNC_MAGIC_V285;
        payload.masterEnabled = 1;
    }

    // ĐỒNG BỘ CẢ 2 NẤC TRUNG GIAN TRÁNH LỆCH NHỊP V-SYNC
    payload.targetHz = (int32_t)rate;
    payload.targetFPS = (int32_t)rate;
    payload.updateSeq = (uint64_t)mach_absolute_time();
    payload.lastHeartbeat = payload.updateSeq;

    int fdWrite = open([SHARED_SYNC_FILE UTF8String], O_WRONLY | O_CREAT | O_TRUNC, 0666);
    if (fdWrite >= 0) {
        write(fdWrite, &payload, sizeof(ApexV285ProPayload));
        close(fdWrite);
        chmod([SHARED_SYNC_FILE UTF8String], 0666);
    }

    notify_post(NOTIFY_FPS_CHANGED);
    notify_post(NOTIFY_HARDWARE_SYNC);
}

- (void)applyFullLocalizationToSpecifiers:(NSArray *)specs {
    NSDictionary *headerMap = @{
        @"CÔNG TẮC TỔNG HỆ THỐNG V28.7 PRO": @"GROUP_MASTER",
        @"CÀI ĐẶT NGÔN NGỮ": @"GROUP_LANGUAGE",
        @"ĐẶC QUYỀN NÂNG CẤP V28.7 (TRIPLE & HEX BUFFERING)": @"GROUP_SPECIAL",
        @"ĐIỀU PHỐI HZ & FPS ĐỘNG (15HZ - 144HZ)": @"GROUP_HZ_FPS",
        @"BỘ LỌC CẢM ỨNG & CHỐNG LOẠN MÀN LÔ (ANTI-GHOST TOUCH)": @"GROUP_TOUCH_SCREEN",
        @"TIÊM TRỄ ỨNG DỤNG BÊN THỨ 3 (CHỐNG ĐEN APP)": @"GROUP_LAZY",
        @"GIA TỐC GIAO DIỆN & VẬT LÝ COLOROS 17": @"GROUP_UI",
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

- (id)specifiers {
    if (!_allSavedSpecifiers) {
        NSString *root = Titanium_GetRootHidePrefixPath();
        NSString *bundlePath = [root stringByAppendingPathComponent:@"Library/PreferenceBundles/BoostiPhone6s.bundle"];
        NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
        if (!bundle) bundle = [NSBundle bundleWithPath:[root stringByAppendingPathComponent:@"Library/PreferenceBundles/BoostiPhone6sPrefs.bundle"]];
        if (!bundle) bundle = [NSBundle bundleWithPath:@"/var/jb/Library/PreferenceBundles/BoostiPhone6s.bundle"];
        if (!bundle) bundle = [NSBundle bundleForClass:[self class]];

        _allSavedSpecifiers = [self loadSpecifiersFromPlistName:@"Root" target:self bundle:bundle];
        [self ensureDefaultSettingsExist];
        [self applyFullLocalizationToSpecifiers:_allSavedSpecifiers];
    }

    NSDictionary *prefs = [self getMergedPreferences];
    BOOL masterEnabled = prefs[@"Enabled"] ? [prefs[@"Enabled"] boolValue] : YES;

    if (!masterEnabled) {
        NSMutableArray *collapsedSpecs = [NSMutableArray array];
        NSString *currentGroupID = nil;

        for (PSSpecifier *spec in _allSavedSpecifiers) {
            if (Titanium_IsGroupCell(spec)) {
                currentGroupID = Titanium_GetGroupID(spec);
                if ([currentGroupID isEqualToString:@"GROUP_MASTER"] ||
                    [currentGroupID isEqualToString:@"GROUP_LANGUAGE"] ||
                    [currentGroupID isEqualToString:@"GROUP_DEV"]) {
                    [collapsedSpecs addObject:spec];
                }
            } else {
                if ([currentGroupID isEqualToString:@"GROUP_MASTER"]) {
                    NSString *key = [spec propertyForKey:@"key"];
                    if ([key isEqualToString:@"Enabled"]) {
                        [collapsedSpecs addObject:spec];
                    }
                } else if ([currentGroupID isEqualToString:@"GROUP_LANGUAGE"] ||
                           [currentGroupID isEqualToString:@"GROUP_DEV"]) {
                    [collapsedSpecs addObject:spec];
                }
            }
        }
        _specifiers = collapsedSpecs;
    } else {
        _specifiers = [_allSavedSpecifiers mutableCopy];
    }

    [self updateDynamicTitles];
    return _specifiers;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupNavigationItems];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setupNavigationItems];
    [self reloadSpecifiers];
}

// Cập nhật nhãn hiển thị: KHÓA CHẶT THÔNG SỐ ĐÃ CHỌN (ĐỒNG BỘ 1:1)
- (void)updateDynamicTitles {
    NSDictionary *prefs = [self getMergedPreferences];
    NSInteger hz = prefs[@"TargetRefreshRate"] ? [prefs[@"TargetRefreshRate"] integerValue] : 120;
    NSInteger fps = prefs[@"TargetFPSRate"] ? [prefs[@"TargetFPSRate"] integerValue] : 120;
    BOOL isOverclock = prefs[@"ForceOverclock144Hz"] ? [prefs[@"ForceOverclock144Hz"] boolValue] : NO;
    BOOL isPowerSave = prefs[@"PowerSaveMode"] ? [prefs[@"PowerSaveMode"] boolValue] : NO;

    NSString *hzLockText = PM_TextV285(@"LOCK_HZ_TITLE") ?: @"🔒 Tần Số Quét: Khóa Cứng %ld Hz";
    NSString *fpsLockText = PM_TextV285(@"LOCK_FPS_TITLE") ?: @"🔒 Khung Hình App: Khóa Cứng %ld FPS";

    NSString *langCode = PM_GetCurrentLanguageCodeV285();
    NSDictionary *langNames = @{
        @"vi": @"Tiếng Việt", @"en": @"English", @"zh": @"中文", @"ru": @"Русский",
        @"hi": @"हिन्दी", @"ja": @"日本語", @"ko": @"한국어", @"es": @"Español",
        @"pt": @"Português", @"fr": @"Français", @"de": @"Deutsch", @"ar": @"العربية"
    };
    NSString *currentLangName = langNames[langCode] ?: @"Auto";
    NSString *langLabelFormat = PM_TextV285(@"LANGUAGE_BTN_FORMAT") ?: @"Ngôn Ngữ: %@";

    for (PSSpecifier *spec in (NSArray *)_specifiers) {
        NSString *key = [spec propertyForKey:@"key"];
        if ([key isEqualToString:@"TargetRefreshRate"]) {
            if (isPowerSave) {
                spec.name = @"🔋 Tần Số Quét: Khóa 30 Hz (Tiết Kiệm Pin)";
            } else if (isOverclock) {
                spec.name = @"⚡ Tần Số Quét: ÉP XUNG 144Hz TOÀN MÁY";
            } else {
                spec.name = [NSString stringWithFormat:hzLockText, (long)hz];
            }
            [spec setProperty:spec.name forKey:@"label"];
        } else if ([key isEqualToString:@"TargetFPSRate"]) {
            if (isPowerSave) {
                spec.name = @"🔋 Khung Hình App: Khóa 30 FPS (Tiết Kiệm Pin)";
            } else {
                spec.name = [NSString stringWithFormat:fpsLockText, (long)fps];
            }
            [spec setProperty:spec.name forKey:@"label"];
        } else if ([key isEqualToString:@"SelectedLanguage"]) {
            spec.name = [NSString stringWithFormat:langLabelFormat, currentLangName];
            [spec setProperty:spec.name forKey:@"label"];
        }
    }
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
             @"SelectedLanguage": @"auto",
             @"ProMotionEngineBeta7": @NO,
             @"MetalHexBuffering": @YES,
             @"KeyboardZeroLagV24": @YES,
             @"EnableHzControl": @YES,
             @"TargetRefreshRate": @120,
             @"EnableFPSControl": @YES,
             @"TargetFPSRate": @120,
             @"ForceOverclock144Hz": @NO,
             @"SyncModuleDelay": @YES,
             @"IsolateRenderPipeline": @YES,
             @"ColorOs17SmoothEngine": @YES,
             @"ReduceMultiTaskLag": @YES,
             @"FixAppLaunchBlackScreen": @YES,
             @"FixAppExitStutter": @YES,
             @"TouchResponseBoost": @YES,
             @"QuantumRenderShield": @YES,
             @"NeuralBufferOpt": @YES,
             @"PeriodicRamClean": @YES,
             @"MachVMPurgeRam": @YES,
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

    // Xử lý công tắc tổng
    if ([key isEqualToString:@"Enabled"]) {
        BOOL isMasterOn = [value boolValue];
        [self syncSharedMemoryFile:isMasterOn];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self reloadSpecifiers];
        });
        return;
    }

    BOOL currentEnabled = [prefs[@"Enabled"] boolValue];
    [self syncSharedMemoryFile:currentEnabled];

    if ([key isEqualToString:@"SelectedLanguage"] || [key isEqualToString:@"ForceOverclock144Hz"] || [key isEqualToString:@"PowerSaveMode"]) {
        _allSavedSpecifiers = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setupNavigationItems];
            [self reloadSpecifiers];
        });
    }
}

// ====================================================================================================
// THUẬT TOÁN HẠ NHỊP TỪ TỪ ĐỒNG BỘ 100% CẢ HZ LẪN FPS
// ====================================================================================================
- (void)executeSmoothRateTransition:(NSInteger)targetRate {
    NSDictionary *prefs = [self getMergedPreferences];
    // Lấy nhịp hiện tại của TargetRefreshRate làm mốc
    NSInteger currentRate = prefs[@"TargetRefreshRate"] ? [prefs[@"TargetRefreshRate"] integerValue] : 120;

    if (self.stepDownTimer) {
        dispatch_source_cancel(self.stepDownTimer);
        self.stepDownTimer = nil;
    }

    // 1. TĂNG XUNG: Kích xung lập tức 0ms cho cả Hz & FPS
    if (targetRate >= currentRate) {
        [self commitFinalRateValue:targetRate];
        return;
    }

    // 2. HẠ XUNG: Hạ qua từng nấc 15Hz để GPU và V-Sync thích ứng
    NSMutableArray *steps = [NSMutableArray array];
    NSInteger stepRate = currentRate;
    while (stepRate - 15 > targetRate) {
        stepRate -= 15;
        [steps addObject:@(stepRate)];
    }
    [steps addObject:@(targetRate)];

    __block NSUInteger stepIndex = 0;
    self.stepDownTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.syncQueue);
    dispatch_source_set_timer(self.stepDownTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(70 * NSEC_PER_MSEC)), (uint64_t)(70 * NSEC_PER_MSEC), (uint64_t)(5 * NSEC_PER_MSEC));

    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(self.stepDownTimer, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (stepIndex < steps.count) {
            NSInteger intermediateRate = [steps[stepIndex] integerValue];
            [strongSelf emitTransientRate:intermediateRate]; // Bơm đồng thời Hz và FPS
            stepIndex++;
        } else {
            if (strongSelf.stepDownTimer) {
                dispatch_source_cancel(strongSelf.stepDownTimer);
                strongSelf.stepDownTimer = nil;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongSelf commitFinalRateValue:targetRate];
            });
        }
    });

    dispatch_resume(self.stepDownTimer);
}

// ====================================================================================================
// LƯU CẢ 2 GIÁ TRỊ (TARGET HZ VÀ TARGET FPS) TRÙNG NHAU 100%
// ====================================================================================================
- (void)commitFinalRateValue:(NSInteger)rate {
    NSString *prefPath = Titanium_ResolvePrefPath();
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:prefPath] ?: [NSMutableDictionary dictionary];

    // ĐỒNG BỘ CẢ 2 GIÁ TRỊ VÀ BẬT ĐỒNG THỜI CẢ 2 CÔNG TẮC ĐIỀU KHIỂN
    [prefs setObject:@(rate) forKey:@"TargetRefreshRate"];
    [prefs setObject:@(rate) forKey:@"TargetFPSRate"];
    [prefs setObject:@YES forKey:@"EnableHzControl"];
    [prefs setObject:@YES forKey:@"EnableFPSControl"];
    [prefs setObject:@NO forKey:@"ProMotionEngineBeta7"]; // Tắt thả trôi, khóa chết
    [prefs setObject:@NO forKey:@"PowerSaveMode"];
    [prefs writeToFile:prefPath atomically:YES];
    chmod([prefPath UTF8String], 0666);

    CFPreferencesSetAppValue(CFSTR("TargetRefreshRate"), (__bridge CFPropertyListRef)@(rate), PREF_DOMAIN);
    CFPreferencesSetAppValue(CFSTR("TargetFPSRate"), (__bridge CFPropertyListRef)@(rate), PREF_DOMAIN);
    CFPreferencesSetAppValue(CFSTR("EnableHzControl"), kCFBooleanTrue, PREF_DOMAIN);
    CFPreferencesSetAppValue(CFSTR("EnableFPSControl"), kCFBooleanTrue, PREF_DOMAIN);
    CFPreferencesSetAppValue(CFSTR("ProMotionEngineBeta7"), kCFBooleanFalse, PREF_DOMAIN);
    CFPreferencesSetAppValue(CFSTR("PowerSaveMode"), kCFBooleanFalse, PREF_DOMAIN);
    CFPreferencesAppSynchronize(PREF_DOMAIN);

    [self syncSharedMemoryFile:YES];
    [self updateDynamicTitles];
    [self reloadSpecifiers];
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
        @{@"code": @"de",   @"name": @"🇩🇪 Deutsch (German)"},
        @{@"code": @"ar",   @"name": @"🇸🇦 العربية (Arabic)"}
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
            _allSavedSpecifiers = nil;
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

- (void)showSubMenuWithOptions:(NSArray *)rates title:(NSString *)title unit:(NSString *)unit {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    NSString *lockPrefix = PM_TextV285(@"LOCK_AT") ?: @"🔒 Khóa cứng";
    NSString *backText = PM_TextV285(@"BACK") ?: @"Quay lại";

    for (NSNumber *r in rates) {
        NSInteger val = [r integerValue];
        NSString *tag = @"";
        if (val <= 30) tag = PM_TextV285(@"TAG_SAVER") ?: @" - Siêu tiết kiệm";
        else if (val == 60) tag = PM_TextV285(@"TAG_BALANCED") ?: @" - Cân bằng chuẩn";
        else if (val == 90 || val == 120) tag = PM_TextV285(@"TAG_ULTRA") ?: @" - Siêu mượt (ProMotion)";
        else if (val == 144) tag = PM_TextV285(@"TAG_MAX") ?: @" - Ép xung tối đa";

        NSString *actionTitle = [NSString stringWithFormat:@"%@ %ld %@%@", lockPrefix, (long)val, unit, tag];

        [alert addAction:[UIAlertAction actionWithTitle:actionTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            // Khi chọn bất kỳ giá trị nào, gọi đồng bộ song hành
            [self executeSmoothRateTransition:val];
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:backText style:UIAlertActionStyleCancel handler:nil]];
    
    UIAlertController *safeAlert = alertPresentationControllerHelperV285(alert, self);
    [self presentViewController:safeAlert animated:YES completion:nil];
}

// Bảng chọn tần số quét (Hz) -> Đồng bộ trực tiếp sang FPS
- (void)showHzPickerPopup:(PSSpecifier *)specifier {
    NSString *alertTitle = PM_TextV285(@"TITLE_HZ") ?: @"CHỌN TẦN SỐ QUÉT HỆ THỐNG & PIP (HZ)";
    UIAlertController *mainAlert = [UIAlertController alertControllerWithTitle:alertTitle message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    NSString *saveText = PM_TextV285(@"BATTERY_SAVER") ?: @"🟢 1. TIẾT KIỆM PIN (15Hz - 40Hz)";
    NSString *balText = PM_TextV285(@"BALANCED") ?: @"🟡 2. BÌNH THƯỜNG (45Hz - 80Hz)";
    NSString *maxText = PM_TextV285(@"MAX_PERF") ?: @"🔴 3. CAO NHẤT (85Hz - 144Hz)";
    NSString *closeText = PM_TextV285(@"CLOSE") ?: @"Đóng";

    [mainAlert addAction:[UIAlertAction actionWithTitle:saveText style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSArray *rates = @[@15, @20, @25, @30, @35, @40];
        [self showSubMenuWithOptions:rates title:saveText unit:@"Hz"];
    }]];

    [mainAlert addAction:[UIAlertAction actionWithTitle:balText style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSArray *rates = @[@45, @50, @55, @60, @65, @70, @75, @80];
        [self showSubMenuWithOptions:rates title:balText unit:@"Hz"];
    }]];

    [mainAlert addAction:[UIAlertAction actionWithTitle:maxText style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSArray *rates = @[@85, @90, @95, @100, @105, @110, @115, @120, @125, @130, @135, @140, @144];
        [self showSubMenuWithOptions:rates title:maxText unit:@"Hz"];
    }]];

    [mainAlert addAction:[UIAlertAction actionWithTitle:closeText style:UIAlertActionStyleCancel handler:nil]];
    
    UIAlertController *safeAlert = alertPresentationControllerHelperV285(mainAlert, self);
    [self presentViewController:safeAlert animated:YES completion:nil];
}

// Bảng chọn khung hình ứng dụng (FPS) -> Đồng bộ trực tiếp sang Hz
- (void)showFPSPickerPopup:(PSSpecifier *)specifier {
    NSString *alertTitle = PM_TextV285(@"TITLE_FPS") ?: @"CHỌN KHUNG HÌNH APP (FPS)";
    UIAlertController *mainAlert = [UIAlertController alertControllerWithTitle:alertTitle message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    NSString *saveText = PM_TextV285(@"BATTERY_SAVER") ?: @"🟢 1. TIẾT KIỆM PIN (15 FPS - 40 FPS)";
    NSString *balText = PM_TextV285(@"BALANCED") ?: @"🟡 2. BÌNH THƯỜNG (45 FPS - 80 FPS)";
    NSString *maxText = PM_TextV285(@"MAX_PERF") ?: @"🔴 3. CAO NHẤT (85 FPS - 144 FPS)";
    NSString *closeText = PM_TextV285(@"CLOSE") ?: @"Đóng";

    [mainAlert addAction:[UIAlertAction actionWithTitle:saveText style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSArray *rates = @[@15, @20, @25, @30, @35, @40];
        [self showSubMenuWithOptions:rates title:saveText unit:@"FPS"];
    }]];

    [mainAlert addAction:[UIAlertAction actionWithTitle:balText style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSArray *rates = @[@45, @50, @55, @60, @65, @70, @75, @80];
        [self showSubMenuWithOptions:rates title:balText unit:@"FPS"];
    }]];

    [mainAlert addAction:[UIAlertAction actionWithTitle:maxText style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSArray *rates = @[@85, @90, @95, @100, @105, @110, @115, @120, @125, @130, @135, @140, @144];
        [self showSubMenuWithOptions:rates title:maxText unit:@"FPS"];
    }]];

    [mainAlert addAction:[UIAlertAction actionWithTitle:closeText style:UIAlertActionStyleCancel handler:nil]];
    
    UIAlertController *safeAlert = alertPresentationControllerHelperV285(mainAlert, self);
    [self presentViewController:safeAlert animated:YES completion:nil];
}

- (id)getAuthorName:(PSSpecifier *)specifier {
    return @"ĐỨC LONG";
}

- (id)getVersionString:(PSSpecifier *)specifier {
    return @"V28.7 SUPREME PRO";
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

- (void)setupNavigationItems {
    NSString *btnTitle = PM_TextV285(@"NAV_ACTIONS") ?: @"Hành Động";
    UIBarButtonItem *actionBtn = [[UIBarButtonItem alloc] initWithTitle:btnTitle
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self
                                                                 action:@selector(presentActions)];
    actionBtn.tintColor = [UIColor systemBlueColor];
    self.navigationItem.rightBarButtonItem = actionBtn;
}

- (void)presentActions {
    NSString *title = PM_TextV285(@"ACTION_TITLE") ?: @"HÀNH ĐỘNG HỆ THỐNG V28.7 PRO";
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    NSString *respringText = PM_TextV285(@"RESPRING") ?: @"⚡️ Respring Nhanh (sbreload)";
    NSString *srebootText = PM_TextV285(@"SREBOOT") ?: @"🔥 Khởi Động Userspace (SReboot)";
    NSString *resetText = PM_TextV285(@"RESET") ?: @"♻️ Đặt Lại Cấu Hình Mặc Định";
    NSString *closeText = PM_TextV285(@"CLOSE") ?: @"Đóng";

    [sheet addAction:[UIAlertAction actionWithTitle:respringText style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
            CFPreferencesAppSynchronize(PREF_DOMAIN);
            pid_t pid;
            int status = 0;
            
            NSString *sbreloadBin = Titanium_FindExecutablePath(@"sbreload");
            if (access([sbreloadBin UTF8String], X_OK) == 0) {
                char *argv[] = {(char *)[sbreloadBin UTF8String], NULL};
                if (posix_spawn(&pid, [sbreloadBin UTF8String], NULL, NULL, argv, environ) == 0) {
                    waitpid(pid, &status, 0);
                    if (WIFEXITED(status) && WEXITSTATUS(status) == 0) {
                        return;
                    }
                }
            }

            NSString *killallBin = Titanium_FindExecutablePath(@"killall");
            char *argvSB[] = {(char *)[killallBin UTF8String], (char *)"-9", (char *)"SpringBoard", NULL};
            posix_spawn(&pid, [killallBin UTF8String], NULL, NULL, argvSB, environ);
            waitpid(pid, NULL, 0);

            char *argvBB[] = {(char *)[killallBin UTF8String], (char *)"-9", (char *)"backboardd", NULL};
            posix_spawn(&pid, [killallBin UTF8String], NULL, NULL, argvBB, environ);
            waitpid(pid, NULL, 0);
        });
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:srebootText style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
            CFPreferencesAppSynchronize(PREF_DOMAIN);
            pid_t pid;
            NSString *launchctlBin = Titanium_FindExecutablePath(@"launchctl");
            char *argv[] = {(char *)[launchctlBin UTF8String], (char *)"reboot", (char *)"userspace", NULL};
            posix_spawn(&pid, [launchctlBin UTF8String], NULL, NULL, argv, environ);
            waitpid(pid, NULL, 0);
        });
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
    NSString *confirmMsg = PM_TextV285(@"RESET_CONFIRM_MSG") ?: @"Toàn bộ cài đặt sẽ được đưa về giá trị mặc định tối ưu nhất của v28.7 Pro.";
    NSString *resetNowText = PM_TextV285(@"RESET_NOW") ?: @"Đặt Lại Ngay";
    NSString *cancelText = PM_TextV285(@"BACK") ?: @"Hủy";

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:confirmTitle message:confirmMsg preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:resetNowText style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        NSString *prefPath = Titanium_ResolvePrefPath();
        [[NSFileManager defaultManager] removeItemAtPath:prefPath error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:SHARED_SYNC_FILE error:nil];
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
        _allSavedSpecifiers = nil;
        [self setupNavigationItems];
        [self reloadSpecifiers];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:cancelText style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
