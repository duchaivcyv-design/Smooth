#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <spawn.h>
#import <sys/wait.h>
#import <sys/stat.h>
#import <fcntl.h>
#import <unistd.h>
#import <notify.h>
#import <dlfcn.h>
#import <mach/mach.h>
#import <mach/mach_time.h>

#define PREF_DOMAIN CFSTR("com.taojb.boostiphone6s")
#define SHARED_SYNC_FILE @"/tmp/.boost_hz_sync"

#define NOTIFY_RELOAD "com.taojb.boostiphone6s/ReloadPrefs"
#define NOTIFY_UIKIT_RELOAD "com.taojb.boostiphone6s/ReloadUIKitPrefs"
#define NOTIFY_HARDWARE_SYNC "com.taojb.boostiphone6s/HardwareSync"
#define NOTIFY_TITANIUM_CHANGED "com.titanium.v261.prefschanged"

#define APEX_SYNC_MAGIC_V261 0x56323631

extern char **environ;

@interface BoostConfigV261 : NSObject
+ (instancetype)sharedInstance;
- (void)loadSettings;
@end

// ============================================================================
// BỘ PHÂN GIẢI ĐƯỜNG DẪN ĐỘNG (ROOTHIDE & ROOTLESS UNIVERSAL RESOLVER)
// ============================================================================
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

static inline const char *Titanium_FindExecutable(const char *name) {
    static char resolvedPath[PATH_MAX];
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
        NSString *candidate = [prefix stringByAppendingPathComponent:[NSString stringWithUTF8String:name]];
        if (access([candidate UTF8String], X_OK) == 0) {
            strlcpy(resolvedPath, [candidate UTF8String], sizeof(resolvedPath));
            return resolvedPath;
        }
    }
    return name;
}

// KHỚP CHUẨN XÁC 100% VỚI STRUCT TRONG TWEAK.XM
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
    uint32_t keyboardZeroLagV3;
    uint32_t aggressiveRamCleaner;
    uint32_t lockFixedFpsWhenThermal;
    uint64_t updateSeq;
    uint64_t reservedTicks;
} ApexV261Payload;

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
+ (instancetype)preferenceSpecifierNamed:(NSString *)name target:(id)target set:(SEL)set get:(SEL)get detail:(Class)detail cell:(NSInteger)cell edit:(Class)edit;
+ (instancetype)groupSpecifierWithName:(NSString *)name;
- (id)propertyForKey:(NSString *)key;
- (void)setProperty:(id)property forKey:(NSString *)key;
@end

@interface RootListController : PSListController {
    NSArray *_allSavedSpecifiers;
}
@end

static inline UIAlertController *alertPresentationControllerHelperV26(UIAlertController *alert, UIViewController *vc) {
    if (alert.popoverPresentationController && vc.navigationItem.rightBarButtonItem) {
        alert.popoverPresentationController.barButtonItem = vc.navigationItem.rightBarButtonItem;
    }
    return alert;
}

static NSDictionary *g_LocDictV26 = nil;

static void PM_LoadLocalizationIfNeededV26(void) {
    if (g_LocDictV26) return;
    
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
            g_LocDictV26 = [[NSDictionary alloc] initWithContentsOfFile:p];
            break;
        }
    }
}

static inline NSString *PM_GetCurrentLanguageCodeV26(void) {
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

static inline NSString *PM_TextV26(NSString *key) {
    PM_LoadLocalizationIfNeededV26();
    if (!g_LocDictV26 || !key) return nil;

    NSString *langCode = PM_GetCurrentLanguageCodeV26();
    if ([langCode isEqualToString:@"vi"]) {
        return nil;
    }

    NSDictionary *langSection = g_LocDictV26[langCode];
    if (langSection && langSection[key]) {
        return langSection[key];
    }
    
    NSDictionary *enSection = g_LocDictV26[@"en"];
    return enSection ? enSection[key] : nil;
}

@implementation RootListController

// ============================================================================
// ĐỒNG BỘ BỘ NHỚ CHIA SẺ & BẮN CƯỠNG BỨC TOÀN BỘ NOTIFICATION CHANNELS
// ============================================================================
- (void)syncSharedMemoryFile:(BOOL)enabled {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        NSDictionary *prefs = [self getMergedPreferences];
        
        ApexV261Payload payload;
        memset(&payload, 0, sizeof(ApexV261Payload));
        payload.magic = APEX_SYNC_MAGIC_V261;
        payload.masterEnabled = enabled ? 1 : 0;

        if (!enabled) {
            payload.targetHz = 60;
            payload.targetFPS = 60;
            payload.forceOverclock = 0;
            payload.pipSyncEnabled = 0;
            payload.thermalShield = 0;
            payload.antiStutterExit = 0;
            payload.smartBufferingLevel = 4;
            payload.zeroLatencyTouch = 0;
            payload.shaderOptimization = 0;
            payload.dynamicInterpolation = 0;
            payload.fastAppLaunch = 0;
            payload.keyboardZeroLagV3 = 0;
            payload.aggressiveRamCleaner = 0;
            payload.lockFixedFpsWhenThermal = 0;
        } else {
            int32_t hz = prefs[@"TargetRefreshRate"] ? (int32_t)[prefs[@"TargetRefreshRate"] intValue] : 60;
            int32_t fps = prefs[@"TargetFPSRate"] ? (int32_t)[prefs[@"TargetFPSRate"] intValue] : 60;
            BOOL dyn = prefs[@"ProMotionEngineBeta7"] ? [prefs[@"ProMotionEngineBeta7"] boolValue] : NO;

            payload.targetHz = (hz >= 15 && hz <= 144) ? hz : 60;
            payload.targetFPS = (fps >= 15 && fps <= 144) ? fps : 60;
            payload.forceOverclock = prefs[@"ForceOverclock144Hz"] ? ([prefs[@"ForceOverclock144Hz"] boolValue] ? 1 : 0) : 0;
            payload.dynamicInterpolation = dyn ? 1 : 0;
            payload.pipSyncEnabled = 1;
            payload.thermalShield = prefs[@"AntiThermalThrottling"] ? ([prefs[@"AntiThermalThrottling"] boolValue] ? 1 : 0) : 1;
            payload.antiStutterExit = prefs[@"FixAppExitStutter"] ? ([prefs[@"FixAppExitStutter"] boolValue] ? 1 : 0) : 1;
            payload.smartBufferingLevel = prefs[@"MetalHexBuffering"] ? ([prefs[@"MetalHexBuffering"] boolValue] ? 6 : 4) : 6;
            payload.zeroLatencyTouch = prefs[@"TouchResponseBoost"] ? ([prefs[@"TouchResponseBoost"] boolValue] ? 1 : 0) : 1;
            payload.shaderOptimization = 1;
            payload.fastAppLaunch = prefs[@"TurboAppLaunch"] ? ([prefs[@"TurboAppLaunch"] boolValue] ? 1 : 0) : 1;
            payload.keyboardZeroLagV3 = prefs[@"KeyboardZeroLagV24"] ? ([prefs[@"KeyboardZeroLagV24"] boolValue] ? 1 : 0) : 1;
            payload.aggressiveRamCleaner = prefs[@"AggressiveRamClean"] ? ([prefs[@"AggressiveRamClean"] boolValue] ? 1 : 0) : 0;
            payload.lockFixedFpsWhenThermal = payload.thermalShield;
        }

        payload.updateSeq = (uint64_t)mach_absolute_time();

        // Ghi đồng bộ tức thì với cờ O_SYNC, cấp quyền 0666 cho toàn bộ Apps đọc được
        int fd = open([SHARED_SYNC_FILE UTF8String], O_WRONLY | O_CREAT | O_TRUNC | O_SYNC, 0666);
        if (fd >= 0) {
            write(fd, &payload, sizeof(payload));
            close(fd);
            chmod([SHARED_SYNC_FILE UTF8String], 0666);
        }
        
        Class configClass = NSClassFromString(@"BoostConfigV261");
        if (configClass && [configClass respondsToSelector:@selector(sharedInstance)]) {
            id cfg = [configClass sharedInstance];
            if ([cfg respondsToSelector:@selector(loadSettings)]) {
                [cfg performSelector:@selector(loadSettings)];
            }
        }

        // Bắn đồng loạt 4 kênh Notify để toàn bộ SpringBoard, UIKit và Daemons cập nhật ngay
        notify_post(NOTIFY_RELOAD);
        notify_post(NOTIFY_UIKIT_RELOAD);
        notify_post(NOTIFY_HARDWARE_SYNC);
        notify_post(NOTIFY_TITANIUM_CHANGED);
    });
}

- (void)applyFullLocalizationToSpecifiers:(NSArray *)specs {
    NSDictionary *headerMap = @{
        @"CÔNG TẮC TỔNG HỆ THỐNG V26 BETA": @"GROUP_MASTER",
        @"ĐẶC QUYỀN NÂNG CẤP V26 (HEX BUFFERING 6 TẦNG)": @"GROUP_SPECIAL",
        @"ĐIỀU PHỐI HZ & FPS (PHÂN NHÁNH 3 MỤC)": @"GROUP_HZ_FPS",
        @"TIÊM TRỄ ỨNG DỤNG BÊN THỨ 3 (CHỐNG ĐEN APP)": @"GROUP_LAZY",
        @"GIA TỐC GIAO DIỆN & HIỆU ỨNG VẬT LÝ": @"GROUP_UI",
        @"LÕI ĐIỀU PHỐI ĐỒ HỌA & PHẦN CỨNG CHUYÊN SÂU": @"GROUP_GRAPHICS",
        @"ĐIỀU PHỐI BỘ NHỚ RAM & TIẾN TRÌNH CPU": @"GROUP_RAM_CPU",
        @"QUẢN LÝ NHIỆT ĐỘ & NGUỒN ĐIỆN": @"GROUP_THERMAL",
        @"BẢO MẬT & QUYỀN RIÊNG TƯ": @"GROUP_SECURITY",
        @"THÔNG TIN PHÁT TRIỂN & HỖ TRỢ": @"GROUP_DEV",
        @"CÀI ĐẶT NGÔN NGỮ": @"GROUP_LANGUAGE"
    };

    NSDictionary *footerMap = @{
        @"Khi tắt công tắc tổng, toàn bộ các chức năng bên dưới sẽ được tự động ẩn đi và nhả hook về mặc định.": @"FOOTER_MASTER",
        @"ProMotion Engine tự động đồng bộ cảm biến nhiệt độ phần cứng, điều phối mức mượt mà khi vuốt chạm và kích hoạt Hex Buffering (6 tầng Metal) thông minh.": @"FOOTER_SPECIAL",
        @"Bấm vào nút chọn để mở Menu 3 mục: Tiết Kiệm Pin (15-40), Bình Thường (45-80), và Cao Nhất (85-144). Chế độ Tự Động dựa trên nhiệt độ phần cứng để co giãn nhịp khung hình.": @"FOOTER_HZ_FPS",
        @"Đồng bộ toàn bộ mô-đun vào app sau khi hoàn thành chu trình khởi tạo UIApplication, đảm bảo 100% không bị đen màn hay treo luồng đồ họa.": @"FOOTER_LAZY",
        @"© 2026 BoostiPhone6s V26 SUPREME - Tối ưu hoàn chỉnh bởi ĐỨC LONG.": @"FOOTER_DEV"
    };

    for (PSSpecifier *spec in specs) {
        NSString *header = [spec propertyForKey:@"label"];
        if (header && headerMap[header]) {
            NSString *transHeader = PM_TextV26(headerMap[header]);
            if (transHeader) {
                [spec setProperty:transHeader forKey:@"label"];
                spec.name = transHeader;
            }
        }
        
        NSString *footer = [spec propertyForKey:@"footerText"];
        if (footer && footerMap[footer]) {
            NSString *transFooter = PM_TextV26(footerMap[footer]);
            if (transFooter) {
                [spec setProperty:transFooter forKey:@"footerText"];
            }
        }

        NSString *key = [spec propertyForKey:@"key"];
        if (key) {
            NSString *translated = PM_TextV26(key);
            if (translated) {
                spec.name = translated;
                [spec setProperty:translated forKey:@"label"];
            }
        } else {
            NSString *lbl = [spec propertyForKey:@"label"];
            if ([lbl isEqualToString:@"Tác Giả"]) {
                NSString *t = PM_TextV26(@"Author");
                if (t) { spec.name = t; [spec setProperty:t forKey:@"label"]; }
            } else if ([lbl isEqualToString:@"Phiên Bản"]) {
                NSString *t = PM_TextV26(@"Version");
                if (t) { spec.name = t; [spec setProperty:t forKey:@"label"]; }
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
    BOOL isMasterEnabled = prefs[@"Enabled"] ? [prefs[@"Enabled"] boolValue] : YES;

    if (!isMasterEnabled) {
        NSMutableArray *minimalSpecifiers = [NSMutableArray array];
        PSSpecifier *langGroupSpecifier = nil;
        PSSpecifier *langCellSpecifier = nil;

        for (NSInteger i = 0; i < (NSInteger)_allSavedSpecifiers.count; i++) {
            PSSpecifier *s = _allSavedSpecifiers[i];
            NSString *k = [s propertyForKey:@"key"];
            if ([k isEqualToString:@"SelectedLanguage"]) {
                langCellSpecifier = s;
                if (i > 0) {
                    PSSpecifier *prev = _allSavedSpecifiers[i - 1];
                    NSString *cellType = [prev propertyForKey:@"cell"];
                    if ([cellType isEqualToString:@"PSGroupCell"]) {
                        langGroupSpecifier = prev;
                    }
                }
                break;
            }
        }

        for (PSSpecifier *s in _allSavedSpecifiers) {
            NSString *k = [s propertyForKey:@"key"];
            NSString *cellType = [s propertyForKey:@"cell"];
            
            if ([cellType isEqualToString:@"PSGroupCell"] && minimalSpecifiers.count == 0) {
                [minimalSpecifiers addObject:s];
            } else if ([k isEqualToString:@"Enabled"]) {
                [minimalSpecifiers addObject:s];
                break;
            }
        }

        if (langGroupSpecifier && ![minimalSpecifiers containsObject:langGroupSpecifier]) {
            [minimalSpecifiers addObject:langGroupSpecifier];
        } else if (!langGroupSpecifier) {
            PSSpecifier *group = [PSSpecifier groupSpecifierWithName:(PM_TextV26(@"GROUP_LANGUAGE") ?: @"CÀI ĐẶT NGÔN NGỮ")];
            [minimalSpecifiers addObject:group];
        }

        if (langCellSpecifier) {
            [minimalSpecifiers addObject:langCellSpecifier];
        }

        _specifiers = minimalSpecifiers;
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

- (void)updateDynamicTitles {
    NSDictionary *prefs = [self getMergedPreferences];
    BOOL isDynamic = prefs[@"ProMotionEngineBeta7"] ? [prefs[@"ProMotionEngineBeta7"] boolValue] : NO;
    NSInteger hz = prefs[@"TargetRefreshRate"] ? [prefs[@"TargetRefreshRate"] integerValue] : 60;
    NSInteger fps = prefs[@"TargetFPSRate"] ? [prefs[@"TargetFPSRate"] integerValue] : 60;
    BOOL isOverclock = prefs[@"ForceOverclock144Hz"] ? [prefs[@"ForceOverclock144Hz"] boolValue] : NO;

    NSString *hzAutoText = PM_TextV26(@"DYNAMIC_HZ_TITLE") ?: @"Tần Số Quét: Tự Động (Max %ld Hz)";
    NSString *hzLockText = PM_TextV26(@"LOCK_HZ_TITLE") ?: @"Tần Số Quét: Khóa %ld Hz";
    NSString *fpsAutoText = PM_TextV26(@"DYNAMIC_FPS_TITLE") ?: @"Khung Hình App: Tự Động (Max %ld FPS)";
    NSString *fpsLockText = PM_TextV26(@"LOCK_FPS_TITLE") ?: @"Khung Hình App: Khóa %ld FPS";

    NSString *langCode = PM_GetCurrentLanguageCodeV26();
    NSDictionary *langNames = @{
        @"vi": @"Tiếng Việt", @"en": @"English", @"zh": @"中文", @"ru": @"Русский",
        @"hi": @"हिन्दी", @"ja": @"日本語", @"ko": @"한국어", @"es": @"Español",
        @"pt": @"Português", @"fr": @"Français", @"de": @"Deutsch", @"ar": @"العربية"
    };
    NSString *currentLangName = langNames[langCode] ?: @"Auto";
    NSString *langLabelFormat = PM_TextV26(@"LANGUAGE_BTN_FORMAT") ?: @"Ngôn Ngữ: %@";

    for (PSSpecifier *spec in (NSArray *)_specifiers) {
        NSString *key = [spec propertyForKey:@"key"];
        if ([key isEqualToString:@"TargetRefreshRate"]) {
            if (isOverclock) {
                spec.name = @"⚡ Tần Số Quét: ÉP XUNG 144Hz TOÀN MÁY";
            } else {
                spec.name = isDynamic ? [NSString stringWithFormat:hzAutoText, (long)hz]
                                      : [NSString stringWithFormat:hzLockText, (long)hz];
            }
            [spec setProperty:spec.name forKey:@"label"];
        } else if ([key isEqualToString:@"TargetFPSRate"]) {
            spec.name = isDynamic ? [NSString stringWithFormat:fpsAutoText, (long)fps]
                                  : [NSString stringWithFormat:fpsLockText, (long)fps];
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
            @"TargetRefreshRate": @144,
            @"EnableFPSControl": @YES,
            @"TargetFPSRate": @144,
            @"ForceOverclock144Hz": @NO,
            @"SyncModuleDelay": @YES,
            @"IsolateRenderPipeline": @YES,
            @"ColorOs17SmoothEngine": @YES,
            @"ReduceMultitaskLag": @YES,
            @"AntiBlackScreenLaunch": @YES,
            @"FixAppExitStutter": @YES,
            @"TouchResponseBoost": @YES,
            @"QuantumRenderShield": @YES,
            @"NeuralBufferOpt": @YES,
            @"BackgroundPacingDaemon": @YES,
            @"HyperMemoryGuardian": @YES,
            @"UltraResponsiveness": @YES,
            @"HyperThreadIO": @YES,
            @"QuantumCoreSync": @YES,
            @"ZeroLagNeuralBooster": @YES,
            @"VsyncAdaptiveBuffer": @YES,
            @"DynamicThermalEngine": @YES,
            @"IOSchedulerEngine": @YES,
            @"RealtimeThreadSched": @YES,
            @"CPUGPUFreqOptimizer": @YES,
            @"PeriodicRamClean": @YES,
            @"MachVMPurgeRam": @YES,
            @"AutoCloseBackgroundApp": @NO,
            @"TurboLaunch": @YES,
            @"TurboAppLaunch": @YES,
            @"GameFPSStabilizer": @YES,
            @"SystemProcessOpt": @YES,
            @"DeviceSpoofer": @YES,
            @"AntiThermalThrottle": @YES,
            @"AntiThermalThrottling": @YES,
            @"SmartThermalDispatch": @YES,
            @"HeavyLoadCooling": @YES,
            @"ChargeThermalProtection": @YES,
            @"PowerSaveMode": @NO,
            @"BypassVarSandbox": @YES,
            @"BlockBackgroundTelemetry": @YES
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

    BOOL currentEnabled = [key isEqualToString:@"Enabled"] ? [value boolValue] : ([self getMergedPreferences][@"Enabled"] ? [[self getMergedPreferences][@"Enabled"] boolValue] : YES);
    [self syncSharedMemoryFile:currentEnabled];

    if ([key isEqualToString:@"Enabled"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self reloadSpecifiers];
        });
    } else if ([key isEqualToString:@"SelectedLanguage"] || [key isEqualToString:@"ForceOverclock144Hz"]) {
        _allSavedSpecifiers = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setupNavigationItems];
            [self reloadSpecifiers];
        });
    }
}

- (void)applyRateValue:(NSInteger)rate isDynamic:(BOOL)dynamicMode isFPS:(BOOL)isFPS {
    NSString *primaryKey = isFPS ? @"TargetFPSRate" : @"TargetRefreshRate";
    NSString *secondaryKey = isFPS ? @"TargetRefreshRate" : @"TargetFPSRate";

    NSString *prefPath = Titanium_ResolvePrefPath();
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:prefPath] ?: [NSMutableDictionary dictionary];
    [prefs setObject:@(rate) forKey:primaryKey];
    [prefs setObject:@(rate) forKey:secondaryKey];
    [prefs setObject:@(dynamicMode) forKey:@"ProMotionEngineBeta7"];
    [prefs writeToFile:prefPath atomically:YES];
    chmod([prefPath UTF8String], 0666);

    CFPreferencesSetAppValue((__bridge CFStringRef)primaryKey, (__bridge CFPropertyListRef)@(rate), PREF_DOMAIN);
    CFPreferencesSetAppValue((__bridge CFStringRef)secondaryKey, (__bridge CFPropertyListRef)@(rate), PREF_DOMAIN);
    CFPreferencesSetAppValue(CFSTR("ProMotionEngineBeta7"), (__bridge CFPropertyListRef)@(dynamicMode), PREF_DOMAIN);
    CFPreferencesAppSynchronize(PREF_DOMAIN);

    [self syncSharedMemoryFile:YES];
    [self updateDynamicTitles];
    [self reloadSpecifiers];
}

- (void)showLanguagePickerPopup:(PSSpecifier *)specifier {
    NSString *title = PM_TextV26(@"POPUP_LANG_TITLE") ?: @"CHỌN NGÔN NGỮ (LANGUAGE)";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

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

    NSString *closeText = PM_TextV26(@"CLOSE") ?: @"Đóng";
    [alert addAction:[UIAlertAction actionWithTitle:closeText style:UIAlertActionStyleCancel handler:nil]];
    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.sourceView = self.view;
    }
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showSubMenuWithOptions:(NSArray *)rates title:(NSString *)title unit:(NSString *)unit isFPS:(BOOL)isFPS {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    NSString *lockPrefix = PM_TextV26(@"LOCK_AT") ?: @"Khóa ở";
    NSString *backText = PM_TextV26(@"BACK") ?: @"Quay lại";

    for (NSNumber *r in rates) {
        NSInteger val = [r integerValue];
        NSString *tag = @"";
        if (val <= 30) tag = PM_TextV26(@"TAG_SAVER") ?: @" - Siêu tiết kiệm";
        else if (val == 60) tag = PM_TextV26(@"TAG_BALANCED") ?: @" - Cân bằng chuẩn";
        else if (val == 90 || val == 120) tag = PM_TextV26(@"TAG_ULTRA") ?: @" - Cực mượt";
        else if (val == 144) tag = PM_TextV26(@"TAG_MAX") ?: @" - Tối đa phần cứng";

        NSString *actionTitle = [NSString stringWithFormat:@"%@ %ld %@%@", lockPrefix, (long)val, unit, tag];

        [alert addAction:[UIAlertAction actionWithTitle:actionTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self applyRateValue:val isDynamic:NO isFPS:isFPS];
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:backText style:UIAlertActionStyleCancel handler:nil]];
    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.sourceView = self.view;
    }
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showHzPickerPopup:(PSSpecifier *)specifier {
    NSString *alertTitle = PM_TextV26(@"TITLE_HZ") ?: @"CHỌN TẦN SỐ QUÉT HỆ THỐNG & PIP (HZ)";
    UIAlertController *mainAlert = [UIAlertController alertControllerWithTitle:alertTitle
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];

    NSString *dynText = PM_TextV26(@"DYNAMIC") ?: @"🌟 Tự Động Quét Nhiệt (Dynamic 30Hz - 144Hz)";
    NSString *saveText = PM_TextV26(@"BATTERY_SAVER") ?: @"🟢 1. TIẾT KIỆM PIN (15Hz - 40Hz)";
    NSString *balText = PM_TextV26(@"BALANCED") ?: @"🟡 2. BÌNH THƯỜNG (45Hz - 80Hz)";
    NSString *maxText = PM_TextV26(@"MAX_PERF") ?: @"🔴 3. CAO NHẤT (85Hz - 144Hz)";
    NSString *closeText = PM_TextV26(@"CLOSE") ?: @"Đóng";

    [mainAlert addAction:[UIAlertAction actionWithTitle:dynText style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self applyRateValue:60 isDynamic:YES isFPS:NO];
    }]];

    [mainAlert addAction:[UIAlertAction actionWithTitle:saveText style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSArray *rates = @[@15, @20, @25, @30, @35, @40];
        [self showSubMenuWithOptions:rates title:saveText unit:@"Hz" isFPS:NO];
    }]];

    [mainAlert addAction:[UIAlertAction actionWithTitle:balText style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSArray *rates = @[@45, @50, @55, @60, @65, @70, @75, @80];
        [self showSubMenuWithOptions:rates title:balText unit:@"Hz" isFPS:NO];
    }]];

    [mainAlert addAction:[UIAlertAction actionWithTitle:maxText style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSArray *rates = @[@85, @90, @95, @100, @105, @110, @115, @120, @125, @130, @135, @140, @144];
        [self showSubMenuWithOptions:rates title:maxText unit:@"Hz" isFPS:NO];
    }]];

    [mainAlert addAction:[UIAlertAction actionWithTitle:closeText style:UIAlertActionStyleCancel handler:nil]];
    if (mainAlert.popoverPresentationController) {
        mainAlert.popoverPresentationController.sourceView = self.view;
    }
    [self presentViewController:mainAlert animated:YES completion:nil];
}

- (void)showFPSPickerPopup:(PSSpecifier *)specifier {
    NSString *alertTitle = PM_TextV26(@"TITLE_FPS") ?: @"CHỌN KHUNG HÌNH APP (FPS)";
    UIAlertController *mainAlert = [UIAlertController alertControllerWithTitle:alertTitle
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];

    NSString *dynText = PM_TextV26(@"DYNAMIC") ?: @"🌟 Tự Động Quét Nhiệt (Dynamic FPS)";
    NSString *saveText = PM_TextV26(@"BATTERY_SAVER") ?: @"🟢 1. TIẾT KIỆM PIN (15 FPS - 40 FPS)";
    NSString *balText = PM_TextV26(@"BALANCED") ?: @"🟡 2. BÌNH THƯỜNG (45 FPS - 80 FPS)";
    NSString *maxText = PM_TextV26(@"MAX_PERF") ?: @"🔴 3. CAO NHẤT (85 FPS - 144 FPS)";
    NSString *closeText = PM_TextV26(@"CLOSE") ?: @"Đóng";

    [mainAlert addAction:[UIAlertAction actionWithTitle:dynText style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self applyRateValue:60 isDynamic:YES isFPS:YES];
    }]];

    [mainAlert addAction:[UIAlertAction actionWithTitle:saveText style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSArray *rates = @[@15, @20, @25, @30, @35, @40];
        [self showSubMenuWithOptions:rates title:saveText unit:@"FPS" isFPS:YES];
    }]];

    [mainAlert addAction:[UIAlertAction actionWithTitle:balText style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSArray *rates = @[@45, @50, @55, @60, @65, @70, @75, @80];
        [self showSubMenuWithOptions:rates title:balText unit:@"FPS" isFPS:YES];
    }]];

    [mainAlert addAction:[UIAlertAction actionWithTitle:maxText style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSArray *rates = @[@85, @90, @95, @100, @105, @110, @115, @120, @125, @130, @135, @140, @144];
        [self showSubMenuWithOptions:rates title:maxText unit:@"FPS" isFPS:YES];
    }]];

    [mainAlert addAction:[UIAlertAction actionWithTitle:closeText style:UIAlertActionStyleCancel handler:nil]];
    if (mainAlert.popoverPresentationController) {
        mainAlert.popoverPresentationController.sourceView = self.view;
    }
    [self presentViewController:mainAlert animated:YES completion:nil];
}

- (id)getAuthorName:(PSSpecifier *)specifier {
    return @"ĐỨC LONG";
}

- (id)getVersionString:(PSSpecifier *)specifier {
    return @"V26 SUPREME BETA 1";
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
    NSString *btnTitle = PM_TextV26(@"NAV_ACTIONS") ?: @"Hành Động";
    UIBarButtonItem *actionBtn = [[UIBarButtonItem alloc] initWithTitle:btnTitle
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self
                                                                 action:@selector(presentActions)];
    actionBtn.tintColor = [UIColor systemBlueColor];
    self.navigationItem.rightBarButtonItem = actionBtn;
}

- (void)presentActions {
    NSString *title = PM_TextV26(@"ACTION_TITLE") ?: @"HÀNH ĐỘNG HỆ THỐNG";
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    NSString *respringText = PM_TextV26(@"RESPRING") ?: @"⚡️ Respring Nhanh";
    NSString *srebootText = PM_TextV26(@"SREBOOT") ?: @"🔥 Khởi Động Không Gian Người Dùng (SReboot)";
    NSString *resetText = PM_TextV26(@"RESET") ?: @"♻️ Đặt Lại Cấu Hình Mặc Định";
    NSString *closeText = PM_TextV26(@"CLOSE") ?: @"Đóng";

    [sheet addAction:[UIAlertAction actionWithTitle:respringText style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
            CFPreferencesAppSynchronize(PREF_DOMAIN);
            pid_t pid;
            
            const char *sbreloadBin = Titanium_FindExecutable("sbreload");
            if (access(sbreloadBin, X_OK) == 0) {
                char *argv[] = {(char *)sbreloadBin, NULL};
                posix_spawn(&pid, sbreloadBin, NULL, NULL, argv, environ);
                waitpid(pid, NULL, 0);
                return;
            }

            const char *killallBin = Titanium_FindExecutable("killall");
            char *argv[] = {(char *)killallBin, (char *)"-9", (char *)"SpringBoard", (char *)"backboardd", NULL};
            posix_spawn(&pid, killallBin, NULL, NULL, argv, environ);
            waitpid(pid, NULL, 0);
        });
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:srebootText style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
            CFPreferencesAppSynchronize(PREF_DOMAIN);
            pid_t pid;
            const char *launchctlBin = Titanium_FindExecutable("launchctl");
            char *argv[] = {(char *)launchctlBin, (char *)"reboot", (char *)"userspace", NULL};
            posix_spawn(&pid, launchctlBin, NULL, NULL, argv, environ);
            waitpid(pid, NULL, 0);
        });
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:resetText style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self executeResetConfiguration];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:closeText style:UIAlertActionStyleCancel handler:nil]];

    UIAlertController *configuredSheet = alertPresentationControllerHelperV26(sheet, self);
    [self presentViewController:configuredSheet animated:YES completion:nil];
}

- (void)executeResetConfiguration {
    NSString *confirmTitle = PM_TextV26(@"RESET_CONFIRM_TITLE") ?: @"Xác Nhận Đặt Lại";
    NSString *confirmMsg = PM_TextV26(@"RESET_CONFIRM_MSG") ?: @"Toàn bộ cài đặt sẽ được đưa về giá trị mặc định tối ưu nhất.";
    NSString *resetNowText = PM_TextV26(@"RESET_NOW") ?: @"Đặt Lại Ngay";
    NSString *cancelText = PM_TextV26(@"BACK") ?: @"Hủy";

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:confirmTitle message:confirmMsg preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:resetNowText style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        NSString *prefPath = Titanium_ResolvePrefPath();
        [[NSFileManager defaultManager] removeItemAtPath:prefPath error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:SHARED_SYNC_FILE error:nil];

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
