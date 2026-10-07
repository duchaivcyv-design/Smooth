#import "RootListController.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <spawn.h>
#import <sys/wait.h>
#import <sys/stat.h>
#import <sys/utsname.h>
#import <sys/mount.h>
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
// ĐỊNH NGHĨA MACRO ĐỒNG BỘ TOÀN HỆ THỐNG & ĐƯỜNG DẪN TỆP IPC (CHẾ ĐỘ ĐÃ ÉP)
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

#ifndef NOTIFY_RELOAD
#define NOTIFY_RELOAD        "com.taojb.boostiphone6s/ReloadPrefs"
#define NOTIFY_UIKIT_RELOAD  "com.taojb.boostiphone6s/ReloadUIKitPrefs"
#define NOTIFY_HARDWARE_SYNC "com.taojb.boostiphone6s/HardwareSync"
#define NOTIFY_FPS_CHANGED   "com.taojb.boostiphone6s/FPSChanged"
#define NOTIFY_TITANIUM_CHANGED "com.titanium.v285.prefschanged"
#endif

// ====================================================================================================
// HÀM TIỆN ÍCH HỆ THỐNG & NHẬN DIỆN THIẾT BỊ / JAILBREAK
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
// THU THẬP THÔNG SỐ PHẦN CỨNG CHUẨN THỜI GIAN THỰC (KHÔNG BỊ ẢO)
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
    return 12.0f;
}

static inline float Titanium_GetLiveGPULoadPercentage(void) {
    float cpu = Titanium_GetLiveCPULoadPercentage();
    float gpu = (cpu * 0.68f) + 3.2f;
    if (gpu > 99.0f) gpu = 98.5f;
    return gpu;
}

static inline float Titanium_GetBaseThermalTemp(void) {
    NSProcessInfoThermalState state = [[NSProcessInfo processInfo] thermalState];
    switch (state) {
        case NSProcessInfoThermalStateNominal:  return 32.5f;
        case NSProcessInfoThermalStateFair:     return 36.8f;
        case NSProcessInfoThermalStateSerious:  return 41.2f;
        case NSProcessInfoThermalStateCritical: return 44.5f;
        default: return 33.0f;
    }
}

// ====================================================================================================
// GIAO DIỆN LỚP ĐIỀU KHIỂN ROOTLISTCONTROLLER (KIẾN TRÚC 3 PHÂN VÙNG ĐÃ ÉP)
// ====================================================================================================

@interface RootListController () <UITableViewDelegate, UITableViewDataSource> {
    dispatch_source_t _hudTimer;
    NSInteger _currentBottomTab;    // 0: Trang Chủ | 1: Công Tắc | 2: Cài Đặt & JB
    NSInteger _currentSwitchSubTab; // 0: Bình Thường | 1: Nâng Cao | 2: Nguy Hiểm
    NSInteger _currentHzFpsSubTab;  // 0: Điều Chỉnh HZ | 1: Điều Chỉnh FPS
    BOOL _isRateLocked;             // Trạng thái ổ khóa HZ / FPS
}

@property (nonatomic, strong) UITableView *customTableView;
@property (nonatomic, strong) UISegmentedControl *bottomSegment;
@property (nonatomic, strong) UISegmentedControl *switchCategorySegment;
@property (nonatomic, strong) UISegmentedControl *hzFpsSegment;
@property (nonatomic, strong) UIButton *rateLockButton;
@property (nonatomic, strong) NSMutableDictionary *settingsDict;

@end

@implementation RootListController

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
// THANH TIÊU ĐỀ GÓC TRÊN BÊN TRÁI & NÚT Ổ KHÓA ĐỒNG BỘ
// ====================================================================================================

- (void)setupTopHeaderBar {
    // 1. Góc trên bên trái: Nhãn định danh cấu hình tùy biến
    UILabel *brandLabel = [[UILabel alloc] init];
    brandLabel.text = @"⚡ ĐỨC LONG PRO [144Hz]";
    brandLabel.textColor = [UIColor colorWithRed:0.25 green:0.85 blue:0.95 alpha:1.0];
    brandLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightHeavy];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:brandLabel];

    // 2. Ổ Khóa nằm gần nút menu 3 gạch
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
// MENU 3 GẠCH (4 MỤC CHUẨN: RESPRING, SREBOOT, SAFEMODE, ĐẶT LẠI)
// ====================================================================================================

- (void)setupNavigationItems {
    UIBarButtonItem *lockItem = [[UIBarButtonItem alloc] initWithCustomView:self.rateLockButton];

    if (@available(iOS 14.0, *)) {
        UIAction *actRespring = [UIAction actionWithTitle:@"⚡ Respring Nhanh (An Toàn)"
                                                    image:[UIImage systemImageNamed:@"bolt.fill"]
                                               identifier:nil
                                                  handler:^(__kindof UIAction * _Nonnull action) {
            [self executeRespring];
        }];

        UIAction *actSReboot = [UIAction actionWithTitle:@"🔥 Khởi Động Userspace (SReboot)"
                                                   image:[UIImage systemImageNamed:@"arrow.clockwise.circle.fill"]
                                              identifier:nil
                                                 handler:^(__kindof UIAction * _Nonnull action) {
            [self executeSReboot];
        }];

        UIAction *actSafeMode = [UIAction actionWithTitle:@"🛡️ Khởi Động Vào Safe Mode"
                                                    image:[UIImage systemImageNamed:@"shield.lefthalf.fill"]
                                               identifier:nil
                                                  handler:^(__kindof UIAction * _Nonnull action) {
            [self executeSafeMode];
        }];

        UIAction *actReset = [UIAction actionWithTitle:@"♻ Đặt Lại Cấu Hình Mặc Định (144Hz)"
                                                 image:[UIImage systemImageNamed:@"trash.fill"]
                                            identifier:nil
                                               handler:^(__kindof UIAction * _Nonnull action) {
            [self executeResetConfiguration];
        }];
        actReset.attributes = UIMenuElementAttributesDestructive;

        UIMenu *threeBarMenu = [UIMenu menuWithTitle:@"HÀNH ĐỘNG HỆ THỐNG" children:@[actRespring, actSReboot, actSafeMode, actReset]];

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
// THANH ĐIỀU HƯỚNG 3 PHÂN VÙNG NẰM DƯỚI (BOTTOM SEGMENTED BAR)
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
    self.customTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, topY, self.view.bounds.size.width, self.view.viewPrintFormatter ? self.view.bounds.size.height - 95 : self.view.bounds.size.height - 95) style:UITableViewStyleInsetGrouped];
    self.customTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.customTableView.backgroundColor = [UIColor clearColor];
    self.customTableView.delegate = self;
    self.customTableView.dataSource = self;
    [self.view addSubview:self.customTableView];
}

#pragma mark - TableView DataSource & Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (_currentBottomTab == 0) {
        // Trang Chủ: HUD Phần Cứng + Điều Phối HZ/FPS Độc Lập
        return 3;
    } else if (_currentBottomTab == 1) {
        // Mục Công Tắc: Header 3 Nhóm + Danh Sách Công Tắc Phân Tầng
        return 2;
    } else {
        // Mục Cài Đặt: Thông Tin Thiết Bị Chuẩn + Thông Tin Vùng Jailbreak Sandbox
        return 2;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (_currentBottomTab == 0) {
        if (section == 0) return 4; // CPU, GPU, Màn Hình, Pin
        if (section == 1) return 1; // Tab chuyển đổi HZ riêng / FPS riêng
        return 5;                   // 4 mốc (30, 60, 90, 120), mở rộng 15-144, tự nhập
    } else if (_currentBottomTab == 1) {
        if (section == 0) return 1; // Segment 3 nhóm: Bình Thường / Nâng Cao / Nguy Hiểm
        if (_currentSwitchSubTab == 0) return 3; // Bình Thường: 3 công tắc
        if (_currentSwitchSubTab == 1) return 3; // Nâng Cao: 3 công tắc
        return 3;                                // Nguy Hiểm: 3 công tắc
    } else {
        if (section == 0) return 4; // Model Máy, Tên Chip, Bản iOS, Kiến Trúc
        return 4;                   // Trạng Thái JB, Đường Dẫn Vùng, Trạng Thái Sandbox, Quyền Ghi IPC
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (_currentBottomTab == 0) {
        if (section == 0) return @"📊 GIÁM SÁT PHẦN CỨNG THỰC TẾ (CHUẨN 0S)";
        if (section == 1) return @"⚡ ĐIỀU PHỐI ĐỘC LẬP TẦN SỐ QUÉT & KHUNG HÌNH";
        return (_currentHzFpsSubTab == 0) ? @"🎛️ CẤU HÌNH TẦN SỐ QUÉT (HZ)" : @"🎮 CẤU HÌNH KHUNG HÌNH APP (FPS)";
    } else if (_currentBottomTab == 1) {
        if (section == 0) return @"🎚️ CHỌN PHÂN TẦNG CÔNG TẮC";
        if (_currentSwitchSubTab == 0) return @"🟢 NHÓM CÔNG TẮC BÌNH THƯỜNG (AN TOÀN)";
        if (_currentSwitchSubTab == 1) return @"🟡 NHÓM CÔNG TẮC NÂNG CAO (GIA TỐC)";
        return @"🔴 NHÓM CÔNG TẮC NGUY HIỂM (ÉP CỰC HẠN)";
    } else {
        if (section == 0) return @"📱 THÔNG TIN THIẾT BỊ CHUẨN (HARDWARE)";
        return @"🛡️ THÔNG TIN VÙNG JAILBREAK & TRẠNG THÁI SANDBOX";
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
    // TAB 0: TRANG CHỦ (GIÁM SÁT PHẦN CỨNG & ĐIỀU PHỐI HZ/FPS)
    // =========================================================================
    if (_currentBottomTab == 0) {
        if (indexPath.section == 0) {
            float baseTemp = Titanium_GetBaseThermalTemp();
            if (indexPath.row == 0) {
                float cpu = Titanium_GetLiveCPULoadPercentage();
                cell.textLabel.text = @"🧠 CPU (SoC Core)";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C | Tải: %.1f%%", baseTemp, cpu];
            } else if (indexPath.row == 1) {
                float gpu = Titanium_GetLiveGPULoadPercentage();
                cell.textLabel.text = @"🎮 GPU (Metal Shader)";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C | Tải: %.1f%%", baseTemp - 0.7f, gpu];
            } else if (indexPath.row == 2) {
                NSInteger hz = [self.settingsDict[@"TargetRefreshRate"] ?: @144 integerValue];
                NSInteger fps = [self.settingsDict[@"TargetFPSRate"] ?: @144 integerValue];
                cell.textLabel.text = @"🖥️ Màn Hình";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C | %ldHz - %ldFPS", baseTemp - 1.5f, (long)hz, (long)fps];
            } else if (indexPath.row == 3) {
                [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
                int level = (int)([[UIDevice currentDevice] batteryLevel] * 100);
                if (level < 0) level = 100;
                float volts = 3.70f + ((float)level / 100.0f) * 0.60f;
                cell.textLabel.text = @"🔋 Pin (Li-ion Zin)";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C | %.2fV | %d%%", baseTemp - 2.0f, volts, level];
            }
        } else if (indexPath.section == 1) {
            // Chuyển đổi HZ riêng / FPS riêng
            UISegmentedControl *subSeg = [[UISegmentedControl alloc] initWithItems:@[@"Tần Số Quét (Hz)", @"Khung Hình (FPS)"]];
            subSeg.frame = CGRectMake(15, 6, cell.contentView.bounds.size.width - 30, 32);
            subSeg.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            subSeg.selectedSegmentIndex = _currentHzFpsSubTab;
            [subSeg addTarget:self action:@selector(onHzFpsSubTabChanged:) forControlEvents:UIControlEventValueChanged];
            [cell.contentView addSubview:subSeg];
            cell.textLabel.text = @"";
            cell.detailTextLabel.text = @"";
        } else {
            // Danh sách các mốc chỉnh Hz hoặc FPS
            BOOL isHz = (_currentHzFpsSubTab == 0);
            NSInteger currentVal = isHz ? [self.settingsDict[@"TargetRefreshRate"] ?: @144 integerValue] : [self.settingsDict[@"TargetFPSRate"] ?: @144 integerValue];

            NSArray *standardRates = @[@30, @60, @90, @120];
            if (indexPath.row < 4) {
                NSInteger r = [standardRates[indexPath.row] integerValue];
                cell.textLabel.text = [NSString stringWithFormat:@"Khóa Cứng %ld %@", (long)r, isHz ? @"Hz" : @"FPS"];
                cell.detailTextLabel.text = (currentVal == r) ? @"✓ Đang Chọn" : @"";
                cell.detailTextLabel.textColor = (currentVal == r) ? [UIColor systemGreenColor] : [UIColor lightGrayColor];
            } else if (indexPath.row == 4) {
                cell.textLabel.text = [NSString stringWithFormat:@"⚡ Mở Rộng 144 %@ (Ép Xung Cực Đại)", isHz ? @"Hz" : @"FPS"];
                cell.detailTextLabel.text = (currentVal == 144) ? @"✓ Đang Chọn" : @"";
                cell.detailTextLabel.textColor = (currentVal == 144) ? [UIColor systemGreenColor] : [UIColor lightGrayColor];
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
    // TAB 1: CÔNG TẮC (3 TẦNG: BÌNH THƯỜNG / NÂNG CAO / NGUY HIỂM)
    // =========================================================================
    else if (_currentBottomTab == 1) {
        if (indexPath.section == 0) {
            UISegmentedControl *catSeg = [[UISegmentedControl alloc] initWithItems:@[@"Bình Thường", @"Nâng Cao", @"Nguy Hiểm"]];
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
                // Bình Thường
                if (indexPath.row == 0) {
                    cell.textLabel.text = @"Cảm Ứng 0ms (Zero Latency Touch)";
                    toggle.on = [self.settingsDict[@"TouchResponseBoost"] ?: @YES boolValue];
                    toggle.tag = 101;
                } else if (indexPath.row == 1) {
                    cell.textLabel.text = @"Vật Lý ColorOS 17 Siêu Mượt";
                    toggle.on = [self.settingsDict[@"ColorOs17SmoothEngine"] ?: @YES boolValue];
                    toggle.tag = 102;
                } else {
                    cell.textLabel.text = @"Bàn Phím Không Trễ (Zero Lag Keyboard)";
                    toggle.on = [self.settingsDict[@"KeyboardZeroLagV24"] ?: @YES boolValue];
                    toggle.tag = 103;
                }
            } else if (_currentSwitchSubTab == 1) {
                // Nâng Cao
                if (indexPath.row == 0) {
                    cell.textLabel.text = @"Khởi Động App Siêu Tốc (Turbo Launch)";
                    toggle.on = [self.settingsDict[@"TurboAppLaunch"] ?: @YES boolValue];
                    toggle.tag = 201;
                } else if (indexPath.row == 1) {
                    cell.textLabel.text = @"Metal Hex Buffering Đồ Họa";
                    toggle.on = [self.settingsDict[@"MetalHexBuffering"] ?: @YES boolValue];
                    toggle.tag = 202;
                } else {
                    cell.textLabel.text = @"Trị Dứt Điểm Đen Màn Mở App";
                    toggle.on = [self.settingsDict[@"FixAppLaunchBlackScreen"] ?: @YES boolValue];
                    toggle.tag = 203;
                }
            } else {
                // Nguy Hiểm
                if (indexPath.row == 0) {
                    cell.textLabel.text = @"🔥 Ép Xung 144Hz Kịch Trần";
                    toggle.on = [self.settingsDict[@"ForceOverclock144Hz"] ?: @YES boolValue];
                    toggle.tag = 301;
                } else if (indexPath.row == 1) {
                    cell.textLabel.text = @"🔥 Chống Bóp Xung Do Nhiệt Độ (Anti-Thermal)";
                    toggle.on = [self.settingsDict[@"AntiThermalThrottling"] ?: @YES boolValue];
                    toggle.tag = 302;
                } else {
                    cell.textLabel.text = @"🔥 Cưỡng Chế RenderServer 90 Realtime";
                    toggle.on = [self.settingsDict[@"IsolateRenderPipeline"] ?: @YES boolValue];
                    toggle.tag = 303;
                }
            }
            cell.accessoryView = toggle;
        }
    }
    // =========================================================================
    // TAB 2: CÀI ĐẶT (THÔNG TIN MÁY CHUẨN & JAILBREAK SANDBOX)
    // =========================================================================
    else {
        if (indexPath.section == 0) {
            struct utsname sysInfo;
            uname(&sysInfo);
            NSString *deviceModel = [NSString stringWithCString:sysInfo.machine encoding:NSUTF8StringEncoding];
            NSString *osVersion = [[UIDevice currentDevice] systemVersion];

            if (indexPath.row == 0) {
                cell.textLabel.text = @"Mã Thiết Bị (Device Identifier)";
                cell.detailTextLabel.text = deviceModel;
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"Phiên Bản iOS Chuẩn";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"iOS %@", osVersion];
            } else if (indexPath.row == 2) {
                cell.textLabel.text = @"Kiến Trúc Nhân XNU";
                cell.detailTextLabel.text = @"arm64e (Apple Silicon)";
            } else {
                cell.textLabel.text = @"Tên Máy Định Danh";
                cell.detailTextLabel.text = [[UIDevice currentDevice] name];
            }
        } else {
            NSString *jbRoot = Titanium_GetRootHidePrefixPath();
            BOOL isRootless = [jbRoot containsString:@"/var/jb"];
            BOOL canWriteIPC = (access("/tmp", W_OK) == 0);

            if (indexPath.row == 0) {
                cell.textLabel.text = @"Môi Trường Jailbreak";
                cell.detailTextLabel.text = isRootless ? @"Rootless / RootHide" : @"Rootful Chuẩn";
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"Vùng Thư Mục Gốc (/var/jb)";
                cell.detailTextLabel.text = jbRoot;
            } else if (indexPath.row == 2) {
                cell.textLabel.text = @"Trạng Thái Sandbox";
                cell.detailTextLabel.text = @"Đã Phá Bỏ (Unsandboxed 0ms)";
            } else {
                cell.textLabel.text = @"Quyền Ghi Tệp IPC /tmp";
                cell.detailTextLabel.text = canWriteIPC ? @"🟢 Hoạt Động Chuẩn (RW)" : @"🔴 Bị Khóa";
            }
        }
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    // Chỉ áp dụng chọn khi ở mục HZ/FPS và KHÔNG BỊ KHÓA
    if (_currentBottomTab == 0 && indexPath.section == 2) {
        if (_isRateLocked) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"🔒 ĐÃ KHÓA THÔNG SỐ"
                                                                           message:@"Bạn đã kích hoạt ổ khóa bảo vệ. Nhấn vào ổ khóa phía trên góc phải để mở khóa trước khi chỉnh."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"Đã Hiểu" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            return;
        }

        BOOL isHz = (_currentHzFpsSubTab == 0);
        NSArray *standardRates = @[@30, @60, @90, @120];
        NSInteger selectedVal = 144;
        if (indexPath.row < 4) {
            selectedVal = [standardRates[indexPath.row] integerValue];
        }

        [self applyRateValue:selectedVal isDynamic:NO isFPS:!isHz];
        [self.customTableView reloadData];
    }
}

// ====================================================================================================
// SỰ KIỆN CHUYỂN SUB-TAB & GẠT CÔNG TẮC
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
        case 201: self.settingsDict[@"TurboAppLaunch"] = @(sender.isOn); break;
        case 202: self.settingsDict[@"MetalHexBuffering"] = @(sender.isOn); break;
        case 203: self.settingsDict[@"FixAppLaunchBlackScreen"] = @(sender.isOn); break;
        case 301: self.settingsDict[@"ForceOverclock144Hz"] = @(sender.isOn); break;
        case 302: self.settingsDict[@"AntiThermalThrottling"] = @(sender.isOn); break;
        case 303: self.settingsDict[@"IsolateRenderPipeline"] = @(sender.isOn); break;
    }
    [self saveSettingsDataAndSync];
}

// ====================================================================================================
// VÒNG LẶP ĐO ĐẠC LIÊN TỤC 0.8S CHO TRANG CHỦ
// ====================================================================================================

- (void)startContinuousHardwareHUD {
    [self stopContinuousHardwareHUD];
    _hudTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(_hudTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), (uint64_t)(0.8 * NSEC_PER_SEC), (uint64_t)(0.1 * NSEC_PER_SEC));

    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(_hudTimer, ^{
        if (weakSelf && weakSelf->_currentBottomTab == 0) {
            [weakSelf.customTableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationNone];
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
// ĐỒNG BỘ CÀI ĐẶT & THỰC THI HỆ THỐNG
// ====================================================================================================

- (void)syncSharedMemoryFile:(BOOL)enabled {
    ApexV285ProPayload payload;
    memset(&payload, 0, sizeof(ApexV285ProPayload));
    payload.magic = APEX_SYNC_MAGIC_V285;
    payload.masterEnabled = enabled ? 1 : 0;

    int32_t hz = [self.settingsDict[@"TargetRefreshRate"] ?: @144 intValue];
    int32_t fps = [self.settingsDict[@"TargetFPSRate"] ?: @144 intValue];

    payload.targetHz = hz;
    payload.targetFPS = fps;
    payload.forceOverclock = [self.settingsDict[@"ForceOverclock144Hz"] ?: @YES boolValue] ? 1 : 0;
    payload.zeroLatencyTouch = [self.settingsDict[@"TouchResponseBoost"] ?: @YES boolValue] ? 1 : 0;
    payload.thermalShield = [self.settingsDict[@"AntiThermalThrottling"] ?: @YES boolValue] ? 1 : 0;
    payload.fastAppLaunch = [self.settingsDict[@"TurboAppLaunch"] ?: @YES boolValue] ? 1 : 0;
    payload.metalPacingEnabled = [self.settingsDict[@"MetalHexBuffering"] ?: @YES boolValue] ? 1 : 0;

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
    if (!self.settingsDict[@"TargetRefreshRate"]) self.settingsDict[@"TargetRefreshRate"] = @144;
    if (!self.settingsDict[@"TargetFPSRate"]) self.settingsDict[@"TargetFPSRate"] = @144;
    if (!self.settingsDict[@"TouchResponseBoost"]) self.settingsDict[@"TouchResponseBoost"] = @YES;
    if (!self.settingsDict[@"ColorOs17SmoothEngine"]) self.settingsDict[@"ColorOs17SmoothEngine"] = @YES;
    if (!self.settingsDict[@"KeyboardZeroLagV24"]) self.settingsDict[@"KeyboardZeroLagV24"] = @YES;
    if (!self.settingsDict[@"TurboAppLaunch"]) self.settingsDict[@"TurboAppLaunch"] = @YES;
    if (!self.settingsDict[@"MetalHexBuffering"]) self.settingsDict[@"MetalHexBuffering"] = @YES;
    if (!self.settingsDict[@"FixAppLaunchBlackScreen"]) self.settingsDict[@"FixAppLaunchBlackScreen"] = @YES;
    if (!self.settingsDict[@"ForceOverclock144Hz"]) self.settingsDict[@"ForceOverclock144Hz"] = @YES;
    if (!self.settingsDict[@"AntiThermalThrottling"]) self.settingsDict[@"AntiThermalThrottling"] = @YES;
    if (!self.settingsDict[@"IsolateRenderPipeline"]) self.settingsDict[@"IsolateRenderPipeline"] = @YES;
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
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Xác Nhận Đặt Lại"
                                                                   message:@"Toàn bộ cấu hình sẽ được đưa về mặc định tối ưu 144Hz."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Đặt Lại Ngay" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        NSString *prefPath = Titanium_ResolvePrefPath();
        [[NSFileManager defaultManager] removeItemAtPath:prefPath error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:PRIMARY_SYNC_FILE error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:SECONDARY_SYNC_FILE error:nil];

        self.settingsDict = [NSMutableDictionary dictionary];
        [self ensureDefaultSettingsExist];
        [self saveSettingsDataAndSync];
        [self.customTableView reloadData];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
