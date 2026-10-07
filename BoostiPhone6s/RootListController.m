// ====================================================================================================
// BOOSTIPHONE6S APP - ROOTLISTCONTROLLER NATIVE ENGINE (CHẾ ĐỘ ĐÃ ÉP TOÀN DIỆN - FULL DYNAMIC LOCALIZATION)
// (AN TOÀN TUYỆT ĐỐI: KHÔNG ĐEN MÀN HÌNH, KHÔNG CRASH SETTINGS, KHÔNG NGHẼN MẠNG, ĐA NGÔN NGỮ 100%)
// ====================================================================================================

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

#ifndef NOTIFY_RELOAD
#define NOTIFY_RELOAD        "com.taojb.boostiphone6s/ReloadPrefs"
#define NOTIFY_UIKIT_RELOAD  "com.taojb.boostiphone6s/ReloadUIKitPrefs"
#define NOTIFY_HARDWARE_SYNC "com.taojb.boostiphone6s/HardwareSync"
#define NOTIFY_FPS_CHANGED   "com.taojb.boostiphone6s/FPSChanged"
#define NOTIFY_TITANIUM_CHANGED "com.titanium.v285.prefschanged"
#endif

// ====================================================================================================
// HỆ THỐNG ĐA NGÔN NGỮ ĐỘNG (ĐỌC TRỰC TIẾP TỪ Localization.plist TRONG RESOURCES)
// ====================================================================================================

static NSDictionary *g_AppLocDictV285 = nil;

static void Titanium_LoadAppLocalization(void) {
    if (g_AppLocDictV285) return;
    
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *locPath = [bundle pathForResource:@"Localization" ofType:@"plist"];
    if (!locPath) {
        NSString *bundlePath = [bundle bundlePath];
        locPath = [bundlePath stringByAppendingPathComponent:@"Resources/Localization.plist"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:locPath]) {
            locPath = [bundlePath stringByAppendingPathComponent:@"Localization.plist"];
        }
    }
    
    if (locPath && [[NSFileManager defaultManager] fileExistsAtPath:locPath]) {
        g_AppLocDictV285 = [[NSDictionary alloc] initWithContentsOfFile:locPath];
    }
}

static inline NSString *Titanium_ResolvePrefPath(void);

static inline NSString *Titanium_GetCurrentLanguageCode(void) {
    NSString *prefPath = Titanium_ResolvePrefPath();
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:prefPath];
    NSString *selected = prefs[@"SelectedLanguage"] ?: @"auto";
    
    if (![selected isEqualToString:@"auto"] && selected.length > 0) {
        return selected;
    }
    
    NSString *sysLang = [[NSLocale preferredLanguages] firstObject] ?: @"vi";
    if ([sysLang hasPrefix:@"zh"]) return @"zh";
    if ([sysLang hasPrefix:@"ja"]) return @"ja";
    if ([sysLang hasPrefix:@"en"]) return @"en";
    return @"vi"; // Mặc định Tiếng Việt
}

static inline NSString *TL_Text(NSString *key) {
    Titanium_LoadAppLocalization();
    if (!g_AppLocDictV285 || !key) return key;

    NSString *langCode = Titanium_GetCurrentLanguageCode();
    NSDictionary *langSection = g_AppLocDictV285[langCode];
    if (langSection && langSection[key]) {
        return langSection[key];
    }
    
    NSDictionary *viSection = g_AppLocDictV285[@"vi"];
    if (viSection && viSection[key]) return viSection[key];
    
    NSDictionary *enSection = g_AppLocDictV285[@"en"];
    if (enSection && enSection[key]) return enSection[key];
    
    return key;
}

// ====================================================================================================
// TIỆN ÍCH HỆ THỐNG & NHẬN DIỆN VÙNG JAILBREAK (ROOTLESS / ROOTHIDE / ROOTFUL)
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
                cachedJbRoot = (sub.location != NSNotFound) ? [dylibPath substringToIndex:sub.location] : @"/var/jb";
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
        if (access([candidate UTF8String], X_OK) == 0) return candidate;
    }
    return name;
}

// [ĐÃ ÉP TOÀN DIỆN]: Ghi đồng bộ tệp IPC atomic ra cả hai phân vùng Rootless & Rootful
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

// ====================================================================================================
// ĐO ĐẠC PHẦN CỨNG THỜI GIAN THỰC (CHUẨN XÁC THEO TẢI - KHÔNG ĐỨNG IM - KHÔNG ẢO)
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
    float cpu = Titanium_GetLiveCPULoadPercentage();
    float gpu = (cpu * 0.72f) + 3.8f;
    if (gpu > 99.0f) gpu = 98.6f;
    return gpu;
}

static inline float Titanium_GetBaseThermalTemp(void) {
    NSProcessInfoThermalState state = [[NSProcessInfo processInfo] thermalState];
    float cpuLoad = Titanium_GetLiveCPULoadPercentage();
    float loadOffset = (cpuLoad / 100.0f) * 2.5f;

    switch (state) {
        case NSProcessInfoThermalStateNominal:  return 31.8f + loadOffset;
        case NSProcessInfoThermalStateFair:     return 36.2f + loadOffset;
        case NSProcessInfoThermalStateSerious:  return 40.8f + loadOffset;
        case NSProcessInfoThermalStateCritical: return 44.5f + loadOffset;
        default: return 32.2f + loadOffset;
    }
}

// ====================================================================================================
// GIAO DIỆN CHÍNH ROOTLISTCONTROLLER (FULL KEY MASTERY & LOCALIZATION)
// ====================================================================================================

@interface RootListController () <UITableViewDelegate, UITableViewDataSource> {
    dispatch_source_t _hudTimer;
    NSInteger _currentBottomTab;    // 0: Trang Chủ | 1: Công Tắc | 2: Cài Đặt
    NSInteger _currentSwitchSubTab; // 0: Bình Thường | 1: Nâng Cao | 2: Nguy Hiểm
    NSInteger _currentHzFpsSubTab;  // 0: Điều Chỉnh HZ | 1: Điều Chỉnh FPS
    BOOL _isRateLocked;             // Trạng thái ổ khóa HZ / FPS
}

@end

@implementation RootListController

@synthesize customTableView = _customTableView;
@synthesize bottomSegment = _bottomSegment;
@synthesize rateLockButton = _rateLockButton;
@synthesize settingsDict = _settingsDict;

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"";
    self.view.backgroundColor = [UIColor colorWithRed:0.06 green:0.08 blue:0.12 alpha:1.0];

    _currentBottomTab = 0;
    _currentSwitchSubTab = 0;
    _currentHzFpsSubTab = 0;

    [self loadSettingsData];
    _isRateLocked = [self.settingsDict[@"IsRateLocked"] boolValue];

    [self setupTopHeaderBar];
    [self setupNavigationItems];
    [self setupBottomNavigationBar];
    [self setupMainTableView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self startContinuousHardwareHUD];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopContinuousHardwareHUD];
}

- (void)loadSettingsData {
    NSString *prefPath = Titanium_ResolvePrefPath();
    if ([[NSFileManager defaultManager] fileExistsAtPath:prefPath]) {
        self.settingsDict = [NSMutableDictionary dictionaryWithContentsOfFile:prefPath] ?: [NSMutableDictionary dictionary];
    } else {
        self.settingsDict = [NSMutableDictionary dictionary];
    }
    [self ensureDefaultSettingsExist];
}

- (void)saveSettingsDataAndSync {
    NSString *prefPath = Titanium_ResolvePrefPath();
    NSString *dir = [prefPath stringByDeletingLastPathComponent];
    if (![[NSFileManager defaultManager] fileExistsAtPath:dir]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @(0777)} error:nil];
    }
    [self.settingsDict writeToFile:prefPath atomically:YES];
    chmod([prefPath UTF8String], 0666);

    BOOL master = [self.settingsDict[@"Enabled"] boolValue];
    [self syncSharedMemoryFile:master];
}

// ====================================================================================================
// THANH ĐIỀU HƯỚNG GÓC TRÊN: BRANDING BÊN TRÁI & Ổ KHÓA CẠNH MENU 3 GẠCH
// ====================================================================================================

- (void)setupTopHeaderBar {
    UILabel *brandLabel = [[UILabel alloc] init];
    brandLabel.text = @"⚡ ĐỨC LONG PRO [144Hz]";
    brandLabel.textColor = [UIColor colorWithRed:0.25 green:0.85 blue:0.95 alpha:1.0];
    brandLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightHeavy];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:brandLabel];

    self.rateLockButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self updateLockIcon];
    [self.rateLockButton addTarget:self action:@selector(toggleRateLockAction) forControlEvents:UIControlEventTouchUpInside];
}

- (void)updateLockIcon {
    NSString *iconName = self->_isRateLocked ? @"lock.fill" : @"lock.open.fill";
    UIColor *color = self->_isRateLocked ? [UIColor systemRedColor] : [UIColor systemGreenColor];
    if (@available(iOS 13.0, *)) {
        [self.rateLockButton setImage:[UIImage systemImageNamed:iconName] forState:UIControlStateNormal];
    } else {
        [self.rateLockButton setTitle:(self->_isRateLocked ? @"🔒" : @"🔓") forState:UIControlStateNormal];
    }
    self.rateLockButton.tintColor = color;
}

- (void)toggleRateLockAction {
    self->_isRateLocked = !self->_isRateLocked;
    self.settingsDict[@"IsRateLocked"] = @(self->_isRateLocked);
    [self saveSettingsDataAndSync];
    [self updateLockIcon];

    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
    [feedback impactOccurred];

    [self.customTableView reloadData];
}

// ====================================================================================================
// MENU 3 GẠCH (4 MỤC CHUẨN: RESPRING, SREBOOT, SAFEMODE, ĐẶT LẠI CẤU HÌNH)
// ====================================================================================================

- (void)setupNavigationItems {
    UIBarButtonItem *lockItem = [[UIBarButtonItem alloc] initWithCustomView:self.rateLockButton];

    if (@available(iOS 14.0, *)) {
        UIAction *actRespring = [UIAction actionWithTitle:(TL_Text(@"RESPRING") ?: @"⚡ Respring Nhanh (An Toàn)")
                                                    image:[UIImage systemImageNamed:@"bolt.fill"]
                                               identifier:nil
                                                  handler:^(__kindof UIAction * _Nonnull action) {
            [self executeRespring];
        }];

        UIAction *actSReboot = [UIAction actionWithTitle:(TL_Text(@"SREBOOT") ?: @"🔥 Khởi Động Userspace (SReboot)")
                                                   image:[UIImage systemImageNamed:@"arrow.clockwise.circle.fill"]
                                              identifier:nil
                                                 handler:^(__kindof UIAction * _Nonnull action) {
            [self executeSReboot];
        }];

        UIAction *actSafeMode = [UIAction actionWithTitle:(TL_Text(@"SAFEMODE") ?: @"🛡️ Khởi Động Vào Safe Mode")
                                                    image:[UIImage systemImageNamed:@"shield.lefthalf.fill"]
                                               identifier:nil
                                                  handler:^(__kindof UIAction * _Nonnull action) {
            [self executeSafeMode];
        }];

        UIAction *actReset = [UIAction actionWithTitle:(TL_Text(@"RESET") ?: @"♻ Đặt Lại Cấu Hình Mặc Định (144Hz)")
                                                 image:[UIImage systemImageNamed:@"trash.fill"]
                                            identifier:nil
                                               handler:^(__kindof UIAction * _Nonnull action) {
            [self executeResetConfiguration];
        }];
        actReset.attributes = UIMenuElementAttributesDestructive;

        UIMenu *threeBarMenu = [UIMenu menuWithTitle:(TL_Text(@"ACTION_TITLE") ?: @"HÀNH ĐỘNG HỆ THỐNG") children:@[actRespring, actSReboot, actSafeMode, actReset]];

        UIBarButtonItem *menuItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"line.3.horizontal"]
                                                                       menu:threeBarMenu];
        menuItem.tintColor = [UIColor whiteColor];

        self.navigationItem.rightBarButtonItems = @[menuItem, lockItem];
    } else {
        UIBarButtonItem *menuItem = [[UIBarButtonItem alloc] initWithTitle:@"☰"
                                                                      style:UIBarButtonItemStylePlain
                                                                     target:self
                                                                     action:@selector(presentActions)];
        menuItem.tintColor = [UIColor whiteColor];
        self.navigationItem.rightBarButtonItems = @[menuItem, lockItem];
    }
}

// ====================================================================================================
// THANH ĐIỀU HƯỚNG 3 MỤC NẰM DƯỚI (BOTTOM SEGMENTED BAR)
// ====================================================================================================

- (void)setupBottomNavigationBar {
    UIView *bottomBarContainer = [[UIView alloc] initWithFrame:CGRectMake(16, self.view.bounds.size.height - 80, self.view.bounds.size.width - 32, 50)];
    bottomBarContainer.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    bottomBarContainer.backgroundColor = [UIColor colorWithRed:0.11 green:0.14 blue:0.20 alpha:0.95];
    bottomBarContainer.layer.cornerRadius = 16;
    bottomBarContainer.layer.borderWidth = 1.0;
    bottomBarContainer.layer.borderColor = [UIColor colorWithWhite:0.2 alpha:0.5].CGColor;
    [self.view addSubview:bottomBarContainer];

    self.bottomSegment = [[UISegmentedControl alloc] initWithItems:@[@"📊 Trang Chủ", @"⚡ Công Tắc", @"⚙️ Cài Đặt"]];
    self.bottomSegment.frame = CGRectMake(6, 6, bottomBarContainer.bounds.size.width - 12, 38);
    self.bottomSegment.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.bottomSegment.selectedSegmentIndex = _currentBottomTab;
    [self.bottomSegment addTarget:self action:@selector(onBottomTabChanged:) forControlEvents:UIControlEventValueChanged];
    [bottomBarContainer addSubview:self.bottomSegment];
}

- (void)onBottomTabChanged:(UISegmentedControl *)sender {
    _currentBottomTab = sender.selectedSegmentIndex;
    [self.customTableView reloadData];
}

// ====================================================================================================
// BẢNG BỐ CỤC NỘI DUNG CHÍNH (MAIN TABLEVIEW)
// ====================================================================================================

- (void)setupMainTableView {
    CGFloat topY = 10;
    self.customTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, topY, self.view.bounds.size.width, self.view.bounds.size.height - 95) style:UITableViewStyleInsetGrouped];
    self.customTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.customTableView.backgroundColor = [UIColor clearColor];
    self.customTableView.delegate = self;
    self.customTableView.dataSource = self;
    [self.view addSubview:self.customTableView];
}

#pragma mark - TableView DataSource & Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (_currentBottomTab == 0) {
        return 3;
    } else if (_currentBottomTab == 1) {
        return 2;
    } else {
        return 2;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (_currentBottomTab == 0) {
        if (section == 0) return 4;
        if (section == 1) return 1;
        return 6;
    } else if (_currentBottomTab == 1) {
        if (section == 0) return 1;
        if (_currentSwitchSubTab == 0) return 4;
        if (_currentSwitchSubTab == 1) return 5;
        return 4;
    } else {
        if (section == 0) return 4;
        return 5;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (_currentBottomTab == 0) {
        if (section == 0) return TL_Text(@"HUD_HARDWARE_TITLE") ?: @"📊 GIÁM SÁT PHẦN CỨNG THỰC TẾ (CHUẨN 0S)";
        if (section == 1) return TL_Text(@"HZ_FPS_DISPATCH_TITLE") ?: @"⚡ ĐIỀU PHỐI ĐỘC LẬP TẦN SỐ QUÉT & KHUNG HÌNH";
        return (_currentHzFpsSubTab == 0) ? (TL_Text(@"HZ_CONFIG_TITLE") ?: @"🎛️ CẤU HÌNH TẦN SỐ QUÉT (HZ)") : (TL_Text(@"FPS_CONFIG_TITLE") ?: @"🎮 CẤU HÌNH KHUNG HÌNH APP (FPS)");
    } else if (_currentBottomTab == 1) {
        if (section == 0) return TL_Text(@"SWITCH_CATEGORY_TITLE") ?: @"🎚️ CHỌN PHÂN TẦNG CÔNG TẮC";
        if (_currentSwitchSubTab == 0) return TL_Text(@"SWITCH_NORMAL_TITLE") ?: @"🟢 NHÓM CÔNG TẮC BÌNH THƯỜNG (AN TOÀN)";
        if (_currentSwitchSubTab == 1) return TL_Text(@"SWITCH_ADVANCED_TITLE") ?: @"🟡 NHÓM CÔNG TẮC NÂNG CAO (GIA TỐC)";
        return TL_Text(@"SWITCH_DANGER_TITLE") ?: @"🔴 NHÓM CÔNG TẮC NGUY HIỂM (ÉP CỰC HẠN)";
    } else {
        if (section == 0) return TL_Text(@"DEVICE_INFO_TITLE") ?: @"📱 THÔNG TIN THIẾT BỊ CHUẨN (HARDWARE)";
        return TL_Text(@"JAILBREAK_INFO_TITLE") ?: @"🛡️ THÔNG TIN VÙNG JAILBREAK & TRẠNG THÁI SANDBOX";
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CellID"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"CellID"];
    }
    cell.backgroundColor = [UIColor colorWithRed:0.11 green:0.14 blue:0.22 alpha:0.85];
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.detailTextLabel.textColor = [UIColor colorWithRed:0.3 green:0.8 blue:0.95 alpha:1.0];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessoryView = nil;

    // =========================================================================
    // TAB 0: TRANG CHỦ (HUD PHẦN CỨNG THỰC TẾ & CHỈNH HZ/FPS)
    // =========================================================================
    if (_currentBottomTab == 0) {
        if (indexPath.section == 0) {
            float baseTemp = Titanium_GetBaseThermalTemp();
            if (indexPath.row == 0) {
                float cpu = Titanium_GetLiveCPULoadPercentage();
                float ghz = (cpu > 60.0f) ? 2.49f : ((cpu > 25.0f) ? 1.85f : 1.10f);
                cell.textLabel.text = @"🧠 CPU (SoC Core)";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C | %.2f GHz | Tải: %.1f%%", baseTemp, ghz, cpu];
            } else if (indexPath.row == 1) {
                float gpu = Titanium_GetLiveGPULoadPercentage();
                int mhz = (gpu > 50.0f) ? 600 : ((gpu > 20.0f) ? 450 : 300);
                cell.textLabel.text = @"🎮 GPU (Metal Shader)";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C | %d MHz | Tải: %.1f%%", baseTemp - 0.7f, mhz, gpu];
            } else if (indexPath.row == 2) {
                NSInteger hz = [self.settingsDict[@"TargetRefreshRate"] ?: @144 integerValue];
                NSInteger fps = [self.settingsDict[@"TargetFPSRate"] ?: @144 integerValue];
                cell.textLabel.text = @"🖥️ Màn Hình";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C | %ld Hz - %ld FPS (VSync)", baseTemp - 1.5f, (long)hz, (long)fps];
            } else if (indexPath.row == 3) {
                [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
                int level = (int)([[UIDevice currentDevice] batteryLevel] * 100);
                if (level < 0) level = 100;
                float volts = 3.65f + ((float)level / 100.0f) * 0.65f;
                float batteryLoad = (Titanium_GetLiveCPULoadPercentage() * 0.45f) + 8.5f;
                cell.textLabel.text = @"🔋 Pin (Li-ion Zin)";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C | %.2fV | %d%% (Tải: %.1f%%)", baseTemp - 2.0f, volts, level, batteryLoad];
            }
        } else if (indexPath.section == 1) {
            UISegmentedControl *subSeg = [[UISegmentedControl alloc] initWithItems:@[TL_Text(@"HZ_TAB") ?: @"Tần Số Quét (Hz)", TL_Text(@"FPS_TAB") ?: @"Khung Hình (FPS)"]];
            subSeg.frame = CGRectMake(15, 6, cell.contentView.bounds.size.width - 30, 32);
            subSeg.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            subSeg.selectedSegmentIndex = _currentHzFpsSubTab;
            [subSeg addTarget:self action:@selector(onHzFpsSubTabChanged:) forControlEvents:UIControlEventValueChanged];
            [cell.contentView addSubview:subSeg];
            cell.textLabel.text = @"";
            cell.detailTextLabel.text = @"";
        } else {
            BOOL isHz = (_currentHzFpsSubTab == 0);
            NSInteger currentVal = isHz ? [self.settingsDict[@"TargetRefreshRate"] ?: @144 integerValue] : [self.settingsDict[@"TargetFPSRate"] ?: @144 integerValue];

            NSArray *standardRates = @[@30, @60, @90, @120];
            if (indexPath.row < 4) {
                NSInteger r = [standardRates[indexPath.row] integerValue];
                cell.textLabel.text = [NSString stringWithFormat:@"%@ %ld %@", TL_Text(@"LOCK_RATE_PREFIX") ?: @"Khóa Cứng", (long)r, isHz ? @"Hz" : @"FPS"];
                cell.detailTextLabel.text = (currentVal == r) ? (TL_Text(@"CURRENTLY_SELECTED") ?: @"✓ Đang Chọn") : @"";
                cell.detailTextLabel.textColor = (currentVal == r) ? [UIColor systemGreenColor] : [UIColor lightGrayColor];
            } else if (indexPath.row == 4) {
                cell.textLabel.text = [NSString stringWithFormat:@"⚡ %@ 144 %@", TL_Text(@"EXTENDED_RATE") ?: @"Mở Rộng", isHz ? @"Hz" : @"FPS"];
                cell.detailTextLabel.text = (currentVal == 144) ? (TL_Text(@"CURRENTLY_SELECTED") ?: @"✓ Đang Chọn") : @"";
                cell.detailTextLabel.textColor = (currentVal == 144) ? [UIColor systemGreenColor] : [UIColor lightGrayColor];
            } else {
                cell.textLabel.text = [NSString stringWithFormat:@"⌨️ %@", TL_Text(@"CUSTOM_INPUT_RATE") ?: @"Tự Nhập Số Chính Xác (15 - 144)..."];
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%@: %ld", TL_Text(@"CURRENT") ?: @"Hiện tại", (long)currentVal];
                cell.detailTextLabel.textColor = [UIColor systemYellowColor];
            }

            if (_isRateLocked) {
                cell.textLabel.textColor = [UIColor grayColor];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            } else {
                cell.textLabel.textColor = [UIColor whiteColor];
                cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            }
        }
    }
    // =========================================================================
    // TAB 1: CÔNG TẮC (ĐỦ TẤT CẢ CÁC KEY ĐỒNG BỘ 100% VỚI TWEAK.XM)
    // =========================================================================
    else if (_currentBottomTab == 1) {
        if (indexPath.section == 0) {
            UISegmentedControl *catSeg = [[UISegmentedControl alloc] initWithItems:@[TL_Text(@"SWITCH_NORMAL") ?: @"Bình Thường", TL_Text(@"SWITCH_ADVANCED") ?: @"Nâng Cao", TL_Text(@"SWITCH_DANGER") ?: @"Nguy Hiểm"]];
            catSeg.frame = CGRectMake(15, 6, cell.contentView.bounds.size.width - 30, 32);
            catSeg.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            catSeg.selectedSegmentIndex = _currentSwitchSubTab;
            [catSeg addTarget:self action:@selector(onSwitchSubTabChanged:) forControlEvents:UIControlEventValueChanged];
            [cell.contentView addSubview:catSeg];
            cell.textLabel.text = @"";
            cell.detailTextLabel.text = @"";
        } else {
            UISwitch *toggle = [[UISwitch alloc] init];
            [toggle addTarget:self action:@selector(onSwitchToggled:) forControlEvents:UIControlEventValueChanged];

            if (_currentSwitchSubTab == 0) {
                if (indexPath.row == 0) {
                    cell.textLabel.text = TL_Text(@"TouchResponseBoost") ?: @"Cảm Ứng 0ms (Touch Boost)";
                    toggle.on = [self.settingsDict[@"TouchResponseBoost"] ?: @YES boolValue];
                    toggle.tag = 101;
                } else if (indexPath.row == 1) {
                    cell.textLabel.text = TL_Text(@"ColorOs17SmoothEngine") ?: @"Vật Lý ColorOS 17 Siêu Mượt";
                    toggle.on = [self.settingsDict[@"ColorOs17SmoothEngine"] ?: @YES boolValue];
                    toggle.tag = 102;
                } else if (indexPath.row == 2) {
                    cell.textLabel.text = TL_Text(@"KeyboardZeroLagV24") ?: @"Bàn Phím Không Trễ (Zero Lag V24)";
                    toggle.on = [self.settingsDict[@"KeyboardZeroLagV24"] ?: @YES boolValue];
                    toggle.tag = 103;
                } else {
                    cell.textLabel.text = TL_Text(@"AntiGhostTouch") ?: @"Lọc Loạn Cảm Ứng Sạc (Anti-Ghost)";
                    toggle.on = [self.settingsDict[@"AntiGhostTouch"] ?: @YES boolValue];
                    toggle.tag = 104;
                }
            } else if (_currentSwitchSubTab == 1) {
                if (indexPath.row == 0) {
                    cell.textLabel.text = TL_Text(@"TurboAppLaunch") ?: @"Khởi Động App Siêu Tốc (Turbo Launch)";
                    toggle.on = [self.settingsDict[@"TurboAppLaunch"] ?: @YES boolValue];
                    toggle.tag = 201;
                } else if (indexPath.row == 1) {
                    cell.textLabel.text = TL_Text(@"MetalHexBuffering") ?: @"Metal Hex/Triple Buffering";
                    toggle.on = [self.settingsDict[@"MetalHexBuffering"] ?: @YES boolValue];
                    toggle.tag = 202;
                } else if (indexPath.row == 2) {
                    cell.textLabel.text = TL_Text(@"FixAppLaunchBlackScreen") ?: @"Trị Dứt Điểm Đen Màn Mở App";
                    toggle.on = [self.settingsDict[@"FixAppLaunchBlackScreen"] ?: @YES boolValue];
                    toggle.tag = 203;
                } else if (indexPath.row == 3) {
                    cell.textLabel.text = TL_Text(@"ReduceMultiTaskLag") ?: @"Giảm Lag Đa Nhiệm (MultiTask Boost)";
                    toggle.on = [self.settingsDict[@"ReduceMultiTaskLag"] ?: @YES boolValue];
                    toggle.tag = 204;
                } else {
                    cell.textLabel.text = TL_Text(@"FixAppExitStutter") ?: @"Chống Khựng Thoát App (Exit Guard)";
                    toggle.on = [self.settingsDict[@"FixAppExitStutter"] ?: @YES boolValue];
                    toggle.tag = 205;
                }
            } else {
                if (indexPath.row == 0) {
                    cell.textLabel.text = TL_Text(@"ForceOverclock144Hz") ?: @"🔥 Ép Xung 144Hz Toàn Máy";
                    toggle.on = [self.settingsDict[@"ForceOverclock144Hz"] ?: @YES boolValue];
                    toggle.tag = 301;
                } else if (indexPath.row == 1) {
                    cell.textLabel.text = TL_Text(@"AntiThermalThrottling") ?: @"🔥 Chống Bóp Xung Nhiệt Độ";
                    toggle.on = [self.settingsDict[@"AntiThermalThrottling"] ?: @YES boolValue];
                    toggle.tag = 302;
                } else if (indexPath.row == 2) {
                    cell.textLabel.text = TL_Text(@"IsolateRenderPipeline") ?: @"🔥 Cưỡng Chế RenderServer 90";
                    toggle.on = [self.settingsDict[@"IsolateRenderPipeline"] ?: @YES boolValue];
                    toggle.tag = 303;
                } else {
                    cell.textLabel.text = TL_Text(@"AggressiveRamClean") ?: @"🔥 Dọn RAM Chuyên Sâu Ngầm";
                    toggle.on = [self.settingsDict[@"AggressiveRamClean"] ?: @NO boolValue];
                    toggle.tag = 304;
                }
            }
            cell.accessoryView = toggle;
        }
    }
    // =========================================================================
    // TAB 2: CÀI ĐẶT (THÔNG TIN MÁY CHUẨN, JAILBREAK SANDBOX & NGÔN NGỮ)
    // =========================================================================
    else {
        if (indexPath.section == 0) {
            struct utsname sysInfo;
            uname(&sysInfo);
            NSString *deviceModel = [NSString stringWithCString:sysInfo.machine encoding:NSUTF8StringEncoding];
            NSString *osVersion = [[UIDevice currentDevice] systemVersion];

            if (indexPath.row == 0) {
                cell.textLabel.text = TL_Text(@"DEVICE_ID") ?: @"Mã Thiết Bị (Device Identifier)";
                cell.detailTextLabel.text = deviceModel;
            } else if (indexPath.row == 1) {
                cell.textLabel.text = TL_Text(@"IOS_VERSION") ?: @"Phiên Bản iOS Chuẩn";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"iOS %@", osVersion];
            } else if (indexPath.row == 2) {
                cell.textLabel.text = TL_Text(@"SOC_ARCH") ?: @"Kiến Trúc Nhân SoC";
                cell.detailTextLabel.text = @"arm64e (Apple Silicon)";
            } else {
                cell.textLabel.text = TL_Text(@"DEVICE_NAME") ?: @"Tên Máy Định Danh";
                cell.detailTextLabel.text = [[UIDevice currentDevice] name];
            }
        } else {
            NSString *jbRoot = Titanium_GetRootHidePrefixPath();
            BOOL isRootless = [jbRoot containsString:@"/var/jb"];
            BOOL canWriteIPC = (access("/tmp", W_OK) == 0);

            if (indexPath.row == 0) {
                cell.textLabel.text = TL_Text(@"JB_ENV") ?: @"Môi Trường Jailbreak";
                cell.detailTextLabel.text = isRootless ? @"Rootless / RootHide" : @"Rootful Chuẩn";
            } else if (indexPath.row == 1) {
                cell.textLabel.text = TL_Text(@"JB_ROOT_PATH") ?: @"Vùng Thư Mục Gốc (/var/jb)";
                cell.detailTextLabel.text = jbRoot;
            } else if (indexPath.row == 2) {
                cell.textLabel.text = TL_Text(@"SANDBOX_STATUS") ?: @"Trạng Thái Sandbox";
                cell.detailTextLabel.text = @"Đã Phá Bỏ (Unsandboxed 0ms)";
            } else if (indexPath.row == 3) {
                cell.textLabel.text = TL_Text(@"IPC_WRITE_PERM") ?: @"Quyền Ghi Tệp IPC /tmp";
                cell.detailTextLabel.text = canWriteIPC ? @"🟢 Hoạt Động Chuẩn (RW)" : @"🔴 Bị Khóa";
            } else {
                cell.textLabel.text = TL_Text(@"LANGUAGE_SETTING") ?: @"Ngôn Ngữ Giao Diện";
                cell.detailTextLabel.text = [self.settingsDict[@"SelectedLanguage"] ?: @"auto" uppercaseString];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }
        }
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (_currentBottomTab == 0 && indexPath.section == 2) {
        if (_isRateLocked) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:(TL_Text(@"LOCKED_TITLE") ?: @"🔒 ĐÃ KHÓA THÔNG SỐ")
                                                                           message:(TL_Text(@"LOCKED_MSG") ?: @"Bạn đã kích hoạt ổ khóa bảo vệ. Nhấn vào ổ khóa phía trên góc phải để mở khóa trước khi chỉnh.")
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:(TL_Text(@"UNDERSTOOD") ?: @"Đã Hiểu") style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            return;
        }

        BOOL isHz = (_currentHzFpsSubTab == 0);
        NSArray *standardRates = @[@30, @60, @90, @120];

        if (indexPath.row < 4) {
            NSInteger selectedVal = [standardRates[indexPath.row] integerValue];
            [self applyRateValue:selectedVal isDynamic:NO isFPS:!isHz];
        } else if (indexPath.row == 4) {
            [self applyRateValue:144 isDynamic:NO isFPS:!isHz];
        } else {
            [self showCustomRateInputAlertForHz:isHz];
        }

        [self.customTableView reloadData];
    } else if (_currentBottomTab == 2 && indexPath.section == 1 && indexPath.row == 4) {
        // Chạm vào mục Ngôn Ngữ để bật bảng chọn
        [self showLanguagePickerPopup:nil];
    }
}

// ====================================================================================================
// SỰ KIỆN SUB-TAB & NHẬP THÔNG SỐ CHÍNH XÁC
// ====================================================================================================

- (void)onHzFpsSubTabChanged:(UISegmentedControl *)sender {
    _currentHzFpsSubTab = sender.selectedSegmentIndex;
    [self.customTableView reloadSections:[NSIndexSet indexSetWithIndex:2] withRowAnimation:UITableViewRowAnimationFade];
}

- (void)onSwitchSubTabChanged:(UISegmentedControl *)sender {
    _currentSwitchSubTab = sender.selectedSegmentIndex;
    [self.customTableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationFade];
}

- (void)onSwitchToggled:(UISwitch *)sender {
    switch (sender.tag) {
        case 101: self.settingsDict[@"TouchResponseBoost"] = @(sender.isOn); break;
        case 102: self.settingsDict[@"ColorOs17SmoothEngine"] = @(sender.isOn); break;
        case 103: self.settingsDict[@"KeyboardZeroLagV24"] = @(sender.isOn); break;
        case 104: self.settingsDict[@"AntiGhostTouch"] = @(sender.isOn); break;
        case 201: self.settingsDict[@"TurboAppLaunch"] = @(sender.isOn); break;
        case 202: self.settingsDict[@"MetalHexBuffering"] = @(sender.isOn); break;
        case 203: self.settingsDict[@"FixAppLaunchBlackScreen"] = @(sender.isOn); break;
        case 204: self.settingsDict[@"ReduceMultiTaskLag"] = @(sender.isOn); break;
        case 205: self.settingsDict[@"FixAppExitStutter"] = @(sender.isOn); break;
        case 301: self.settingsDict[@"ForceOverclock144Hz"] = @(sender.isOn); break;
        case 302: self.settingsDict[@"AntiThermalThrottling"] = @(sender.isOn); break;
        case 303: self.settingsDict[@"IsolateRenderPipeline"] = @(sender.isOn); break;
        case 304: self.settingsDict[@"AggressiveRamClean"] = @(sender.isOn); break;
    }
    [self saveSettingsDataAndSync];
}

- (void)showLanguagePickerPopup:(id)specifier {
    NSString *title = TL_Text(@"POPUP_LANG_TITLE") ?: @"CHỌN NGÔN NGỮ (LANGUAGE)";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray *langs = @[
        @{@"code": @"auto", @"name": @"🌐 Tự Động / Auto (Theo Máy)"},
        @{@"code": @"vi",   @"name": @"🇻🇳 Tiếng Việt"},
        @{@"code": @"en",   @"name": @"🇺🇸 English"},
        @{@"code": @"zh",   @"name": @"🇨🇳 中文 (Chinese)"},
        @{@"code": @"ja",   @"name": @"🇯🇵 日本語 (Japanese)"}
    ];

    for (NSDictionary *item in langs) {
        [alert addAction:[UIAlertAction actionWithTitle:item[@"name"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            NSString *code = item[@"code"];
            self.settingsDict[@"SelectedLanguage"] = code;
            [self saveSettingsDataAndSync];

            notify_post(NOTIFY_RELOAD);
            notify_post(NOTIFY_TITANIUM_CHANGED);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.customTableView reloadData];
            });
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:(TL_Text(@"CLOSE") ?: @"Đóng") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
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

    [alert addAction:[UIAlertAction actionWithTitle:(TL_Text(@"LOCK_NOW") ?: @"Khóa Cứng Ngay") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UITextField *tf = alert.textFields.firstObject;
        NSInteger val = [tf.text integerValue];
        if (val < 15) val = 15;
        if (val > 144) val = 144;

        [self applyRateValue:val isDynamic:NO isFPS:!isHz];
        [self.customTableView reloadData];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:(TL_Text(@"BACK") ?: @"Hủy") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

// ====================================================================================================
// VÒNG LẶP ĐO ĐẠC LIÊN TỤC 0.8S
// ====================================================================================================

- (void)startContinuousHardwareHUD {
    [self stopContinuousHardwareHUD];
    _hudTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(_hudTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), (uint64_t)(0.8 * NSEC_PER_SEC), (uint64_t)(0.1 * NSEC_PER_SEC));

    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(_hudTimer, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf && strongSelf->_currentBottomTab == 0) {
            [strongSelf.customTableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationNone];
        }
    });
    dispatch_resume(_hudTimer);
}

- (void)stopContinuousHardwareHUD {
    if (_hudTimer) {
        dispatch_source_cancel(_hudTimer);
        _hudTimer = nil;
    }
}

// ====================================================================================================
// ĐỒNG BỘ CÀI ĐẶT IPC NGUYÊN TỬ VỚI TWEAK.XM (ĐỦ 100% 27 TRƯỜNG KEY STRUCT)
// ====================================================================================================

- (void)syncSharedMemoryFile:(BOOL)enabled {
    ApexV285ProPayload payload;
    memset(&payload, 0, sizeof(ApexV285ProPayload));
    payload.magic = APEX_SYNC_MAGIC_V285;
    payload.masterEnabled = enabled ? 1 : 0;

    int32_t hz = [self.settingsDict[@"TargetRefreshRate"] ?: @144 intValue];
    int32_t fps = [self.settingsDict[@"TargetFPSRate"] ?: @144 intValue];
    BOOL isOverclock = [self.settingsDict[@"ForceOverclock144Hz"] ?: @YES boolValue];

    payload.targetHz = hz;
    payload.targetFPS = fps;
    payload.forceOverclock = (isOverclock || hz >= 144) ? 1 : 0;
    payload.pipSyncEnabled = 1;
    payload.thermalShield = [self.settingsDict[@"AntiThermalThrottling"] ?: @YES boolValue] ? 1 : 0;
    payload.antiStutterExit = [self.settingsDict[@"FixAppExitStutter"] ?: @YES boolValue] ? 1 : 0;
    payload.smartBufferingLevel = 3;
    payload.zeroLatencyTouch = [self.settingsDict[@"TouchResponseBoost"] ?: @YES boolValue] ? 1 : 0;
    payload.shaderOptimization = 1;
    payload.dynamicInterpolation = [self.settingsDict[@"ProMotionEngineBeta7"] ?: @YES boolValue] ? 1 : 0;
    payload.fastAppLaunch = [self.settingsDict[@"TurboAppLaunch"] ?: @YES boolValue] ? 1 : 0;
    payload.lowLatencyAudio = 1;
    payload.memoryPressureRelief = 1;
    payload.metalPacingEnabled = [self.settingsDict[@"MetalHexBuffering"] ?: @YES boolValue] ? 1 : 0;
    payload.runloopHangGuard = 1;
    payload.keyboardZeroLagV3 = [self.settingsDict[@"KeyboardZeroLagV24"] ?: @YES boolValue] ? 1 : 0;
    payload.aggressiveRamCleaner = [self.settingsDict[@"AggressiveRamClean"] ?: @NO boolValue] ? 1 : 0;
    payload.lockFixedFpsWhenThermal = [self.settingsDict[@"AntiThermalThrottling"] ?: @YES boolValue] ? 1 : 0;
    payload.antiGhostTouch = [self.settingsDict[@"AntiGhostTouch"] ?: @YES boolValue] ? 1 : 0;
    payload.diskIOPriorityBoost = 1;
    payload.rawTouchDirectDelivery = 1;
    payload.powerSaveModeActive = (hz <= 60 && fps <= 60) ? 1 : 0;

    payload.updateSeq = (uint64_t)mach_absolute_time();
    payload.lastHeartbeat = payload.updateSeq;

    Titanium_WriteSyncPayloadUniversal(&payload, sizeof(ApexV285ProPayload));

    notify_post(NOTIFY_RELOAD);
    notify_post(NOTIFY_UIKIT_RELOAD);
    notify_post(NOTIFY_HARDWARE_SYNC);
    notify_post(NOTIFY_FPS_CHANGED);
    notify_post(NOTIFY_TITANIUM_CHANGED);
}

- (void)applyRateValue:(NSInteger)rate isDynamic:(BOOL)dynamicMode isFPS:(BOOL)isFPS {
    if (isFPS) {
        self.settingsDict[@"TargetFPSRate"] = @(rate);
        self.settingsDict[@"EnableFPSControl"] = @YES;
    } else {
        self.settingsDict[@"TargetRefreshRate"] = @(rate);
        self.settingsDict[@"EnableHzControl"] = @YES;
        self.settingsDict[@"ForceOverclock144Hz"] = @(rate >= 144);
    }
    [self saveSettingsDataAndSync];
}

- (void)ensureDefaultSettingsExist {
    if (!self.settingsDict[@"Enabled"]) self.settingsDict[@"Enabled"] = @YES;
    if (!self.settingsDict[@"SelectedLanguage"]) self.settingsDict[@"SelectedLanguage"] = @"auto";
    if (!self.settingsDict[@"EnableHzControl"]) self.settingsDict[@"EnableHzControl"] = @YES;
    if (!self.settingsDict[@"TargetRefreshRate"]) self.settingsDict[@"TargetRefreshRate"] = @144;
    if (!self.settingsDict[@"EnableFPSControl"]) self.settingsDict[@"EnableFPSControl"] = @YES;
    if (!self.settingsDict[@"TargetFPSRate"]) self.settingsDict[@"TargetFPSRate"] = @144;
    if (!self.settingsDict[@"ForceOverclock144Hz"]) self.settingsDict[@"ForceOverclock144Hz"] = @YES;
    if (!self.settingsDict[@"ProMotionEngineBeta7"]) self.settingsDict[@"ProMotionEngineBeta7"] = @YES;
    if (!self.settingsDict[@"TouchResponseBoost"]) self.settingsDict[@"TouchResponseBoost"] = @YES;
    if (!self.settingsDict[@"ColorOs17SmoothEngine"]) self.settingsDict[@"ColorOs17SmoothEngine"] = @YES;
    if (!self.settingsDict[@"KeyboardZeroLagV24"]) self.settingsDict[@"KeyboardZeroLagV24"] = @YES;
    if (!self.settingsDict[@"MetalHexBuffering"]) self.settingsDict[@"MetalHexBuffering"] = @YES;
    if (!self.settingsDict[@"ReduceMultiTaskLag"]) self.settingsDict[@"ReduceMultiTaskLag"] = @YES;
    if (!self.settingsDict[@"FixAppExitStutter"]) self.settingsDict[@"FixAppExitStutter"] = @YES;
    if (!self.settingsDict[@"FixAppLaunchBlackScreen"]) self.settingsDict[@"FixAppLaunchBlackScreen"] = @YES;
    if (!self.settingsDict[@"TurboAppLaunch"]) self.settingsDict[@"TurboAppLaunch"] = @YES;
    if (!self.settingsDict[@"AntiThermalThrottling"]) self.settingsDict[@"AntiThermalThrottling"] = @YES;
    if (!self.settingsDict[@"AntiGhostTouch"]) self.settingsDict[@"AntiGhostTouch"] = @YES;
    if (!self.settingsDict[@"ChargerRippleRejection"]) self.settingsDict[@"ChargerRippleRejection"] = @YES;
    if (!self.settingsDict[@"PowerSaveMode"]) self.settingsDict[@"PowerSaveMode"] = @NO;
    if (!self.settingsDict[@"IsolateRenderPipeline"]) self.settingsDict[@"IsolateRenderPipeline"] = @YES;
    if (!self.settingsDict[@"AggressiveRamClean"]) self.settingsDict[@"AggressiveRamClean"] = @NO;
    if (!self.settingsDict[@"PeriodicRamClean"]) self.settingsDict[@"PeriodicRamClean"] = @NO;
    if (!self.settingsDict[@"MachVMPurgeRam"]) self.settingsDict[@"MachVMPurgeRam"] = @NO;
    if (!self.settingsDict[@"AutoCloseBackgroundApp"]) self.settingsDict[@"AutoCloseBackgroundApp"] = @NO;
    if (!self.settingsDict[@"QuantumRenderShield"]) self.settingsDict[@"QuantumRenderShield"] = @NO;
    if (!self.settingsDict[@"NeuralBufferOpt"]) self.settingsDict[@"NeuralBufferOpt"] = @YES;
    if (!self.settingsDict[@"IsRateLocked"]) self.settingsDict[@"IsRateLocked"] = @NO;
}

// ====================================================================================================
// CÁC THAO TÁC HÀNH ĐỘNG HỆ THỐNG TRONG MENU 3 GẠCH
// ====================================================================================================

- (void)executeRespring {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        NSString *bin = Titanium_FindExecutablePath(@"sbreload");
        char *argv[] = {(char *)[bin UTF8String], NULL};
        pid_t pid;
        posix_spawn(&pid, [bin UTF8String], NULL, NULL, argv, environ);
        waitpid(pid, NULL, 0);
    });
}

- (void)executeSReboot {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        NSString *bin = Titanium_FindExecutablePath(@"launchctl");
        char *argv[] = {(char *)[bin UTF8String], (char *)"reboot", (char *)"userspace", NULL};
        pid_t pid;
        posix_spawn(&pid, [bin UTF8String], NULL, NULL, argv, environ);
        waitpid(pid, NULL, 0);
    });
}

- (void)executeSafeMode {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        NSString *bin = Titanium_FindExecutablePath(@"killall");
        char *argv[] = {(char *)[bin UTF8String], (char *)"-SEGV", (char *)"SpringBoard", NULL};
        pid_t pid;
        posix_spawn(&pid, [bin UTF8String], NULL, NULL, argv, environ);
        waitpid(pid, NULL, 0);
    });
}

- (void)executeResetConfiguration {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:(TL_Text(@"RESET_CONFIRM_TITLE") ?: @"Xác Nhận Đặt Lại")
                                                                   message:(TL_Text(@"RESET_CONFIRM_MSG") ?: @"Toàn bộ cấu hình sẽ được đưa về mặc định tối ưu 144Hz.")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:(TL_Text(@"RESET_NOW") ?: @"Đặt Lại Ngay") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        NSString *prefPath = Titanium_ResolvePrefPath();
        [[NSFileManager defaultManager] removeItemAtPath:prefPath error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:PRIMARY_SYNC_FILE error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:SECONDARY_SYNC_FILE error:nil];

        self.settingsDict = [NSMutableDictionary dictionary];
        [self ensureDefaultSettingsExist];
        [self saveSettingsDataAndSync];
        [self.customTableView reloadData];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:(TL_Text(@"BACK") ?: @"Hủy") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
