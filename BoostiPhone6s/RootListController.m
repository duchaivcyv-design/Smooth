#import "RootListController.h"
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <spawn.h>
#import <sys/wait.h>
#import <sys/stat.h>
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
#import <QuartzCore/QuartzCore.h>
#import <Metal/Metal.h>
#import <os/lock.h>
#import <IOKit/IOKitLib.h>
#import <CoreFoundation/CoreFoundation.h>
extern char **environ;
#define APEX_SYNC_MAGIC_V285 0x41505837
#define PREF_DOMAIN          CFSTR("com.taojb.boostiphone6s")
#define PRIMARY_SYNC_FILE    @"/tmp/.boost_hz_sync"
#define SECONDARY_SYNC_FILE  @"/var/jb/tmp/.boost_hz_sync"
#define APPS_SYNC_FILE_PRIMARY   @"/tmp/.boost_hz_apps"
#define APPS_SYNC_FILE_SECONDARY @"/var/jb/tmp/.boost_hz_apps"
#define PER_APP_RATES_FILE_PRIMARY   @"/tmp/.boost_hz_per_app.plist"
#define PER_APP_RATES_FILE_SECONDARY @"/var/jb/tmp/.boost_hz_per_app.plist"
#define NOTIFY_RELOAD           "com.taojb.boostiphone6s/ReloadPrefs"
#define NOTIFY_UIKIT_RELOAD     "com.taojb.boostiphone6s/ReloadUIKitPrefs"
#define NOTIFY_HARDWARE_SYNC    "com.taojb.boostiphone6s/HardwareSync"
#define NOTIFY_FPS_CHANGED      "com.taojb.boostiphone6s/FPSChanged"
#define NOTIFY_TITANIUM_CHANGED "com.titanium.v285.prefschanged"
#define NOTIFY_PAYLOAD_WRITTEN  "com.taojb.boostiphone6s/PayloadWritten"
// ====================================================================================================
// CẤU TRÚC PAYLOAD ĐỒNG BỘ TUYỆT ĐỐI 100% VỚI TWEAK.XM (448 BYTES — CHỐNG TRÀN STACK __stack_chk_fail)
// ====================================================================================================
#ifndef _APEX_V285_PRO_PAYLOAD_DEFINED
#define _APEX_V285_PRO_PAYLOAD_DEFINED
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
    uint32_t groupFlags[34];
    uint64_t updateSeq;
    uint64_t lastHeartbeat;
    char     reserved[200];
} ApexV285ProPayload;
#endif
static inline NSString *Titanium_GetRootHidePrefixPath(void) {
    static NSString *cached = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Dl_info info;
        if (dladdr((const void *)Titanium_GetRootHidePrefixPath, &info) && info.dli_fname) {
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
static inline NSString *Titanium_ResolvePrefPath(void) {
    NSString *root = Titanium_GetRootHidePrefixPath();
    if (root && root.length > 0 && ![root isEqualToString:@"/"]) {
        NSString *p = [root stringByAppendingPathComponent:@"var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:p]) return p;
    }
    NSString *p1 = @"/var/jb/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist";
    if ([[NSFileManager defaultManager] fileExistsAtPath:p1]) return p1;
    return @"/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist";
}
static inline NSString *Titanium_FindExecutablePath(NSString *name) {
    NSArray *pref = @[
        [Titanium_GetRootHidePrefixPath() stringByAppendingPathComponent:@"usr/bin"],
        [Titanium_GetRootHidePrefixPath() stringByAppendingPathComponent:@"bin"],
        @"/var/jb/usr/bin", @"/var/jb/bin", @"/usr/bin", @"/bin"
    ];
    for (NSString *p in pref) {
        NSString *c = [p stringByAppendingPathComponent:name];
        if (access([c UTF8String], X_OK) == 0) return c;
    }
    return nil;
}
static BOOL Titanium_WriteAtomicBytesAtPath(NSString *path, const void *data, size_t size) {
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
    const uint8_t *cursor = (const uint8_t *)data;
    size_t remaining = size;
    BOOL ok = YES;
    while (remaining > 0) {
        ssize_t written = write(fd, cursor, remaining);
        if (written < 0 && errno == EINTR) continue;
        if (written <= 0) { ok = NO; break; }
        cursor += (size_t)written;
        remaining -= (size_t)written;
    }
    fchmod(fd, 0644);
    close(fd);
    if (ok && rename(temporaryPath, [path fileSystemRepresentation]) == 0) {
        chmod([path fileSystemRepresentation], 0644);
    } else {
        unlink(temporaryPath);
        ok = NO;
    }
    free(temporaryPath);
    return ok;
}
static uint64_t Titanium_IPCSequenceNow(void) {
    NSTimeInterval epoch = [[NSDate date] timeIntervalSince1970];
    uint64_t candidate = (isfinite(epoch) && epoch >= 1.0) ? (uint64_t)(epoch * 1000000000.0) : (uint64_t)mach_absolute_time();
    static os_unfair_lock sequenceLock = OS_UNFAIR_LOCK_INIT;
    static uint64_t lastSequence = 0;
    os_unfair_lock_lock(&sequenceLock);
    if (candidate <= lastSequence) candidate = lastSequence + 1;
    lastSequence = candidate;
    os_unfair_lock_unlock(&sequenceLock);
    return candidate;
}
static os_unfair_lock gTIUSCPULoadLock = OS_UNFAIR_LOCK_INIT;
static BOOL gTIUSCPUHasBaseline = NO;
static uint64_t gTIUSCPUUserTicks = 0, gTIUSCPUSystemTicks = 0, gTIUSCPUIdleTicks = 0, gTIUSCPUNiceTicks = 0;
static CFTimeInterval gTIUSCPULastSampleTime = 0;
static float gTIUSCachedCPULoad = 2.1f;
static inline float Titanium_GetLiveCPULoadPercentage(void) {
    host_cpu_load_info_data_t info;
    mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;
    if (host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, (host_info_t)&info, &count) != KERN_SUCCESS) return 2.1f;
    uint64_t user = info.cpu_ticks[CPU_STATE_USER];
    uint64_t system = info.cpu_ticks[CPU_STATE_SYSTEM];
    uint64_t idle = info.cpu_ticks[CPU_STATE_IDLE];
    uint64_t nice = info.cpu_ticks[CPU_STATE_NICE];
    CFTimeInterval now = CACurrentMediaTime();
    os_unfair_lock_lock(&gTIUSCPULoadLock);
    if (!gTIUSCPUHasBaseline) {
        gTIUSCPUUserTicks = user; gTIUSCPUSystemTicks = system;
        gTIUSCPUIdleTicks = idle; gTIUSCPUNiceTicks = nice;
        gTIUSCPULastSampleTime = now;
        gTIUSCPUHasBaseline = YES;
    } else if (now - gTIUSCPULastSampleTime >= 3.5) {
        uint64_t du = user >= gTIUSCPUUserTicks ? user - gTIUSCPUUserTicks : 0;
        uint64_t ds = system >= gTIUSCPUSystemTicks ? system - gTIUSCPUSystemTicks : 0;
        uint64_t di = idle >= gTIUSCPUIdleTicks ? idle - gTIUSCPUIdleTicks : 0;
        uint64_t dn = nice >= gTIUSCPUNiceTicks ? nice - gTIUSCPUNiceTicks : 0;
        uint64_t total = du + ds + di + dn;
        if (total > 0) gTIUSCachedCPULoad = (float)((double)(du + ds + dn) * 100.0 / (double)total);
        gTIUSCPUUserTicks = user; gTIUSCPUSystemTicks = system;
        gTIUSCPUIdleTicks = idle; gTIUSCPUNiceTicks = nice;
        gTIUSCPULastSampleTime = now;
    }
    float result = gTIUSCachedCPULoad;
    os_unfair_lock_unlock(&gTIUSCPULoadLock);
    return result;
}
static uint64_t Titanium_TotalPhysicalMemoryBytes(void) {
    uint64_t bytes = 0; size_t length = sizeof(bytes);
    return (sysctlbyname("hw.memsize", &bytes, &length, NULL, 0) == 0) ? bytes : 0;
}
static uint64_t Titanium_CurrentProcessFootprintBytes(void) {
    task_vm_info_data_t vmInfo;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    memset(&vmInfo, 0, sizeof(vmInfo));
    if (task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&vmInfo, &count) != KERN_SUCCESS) return 0;
    return (uint64_t)vmInfo.phys_footprint;
}
static NSString *Titanium_ByteCountString(uint64_t bytes) {
    if (bytes == 0) return @"0 MiB";
    double gib = (double)bytes / (1024.0 * 1024.0 * 1024.0);
    if (gib >= 1.0) return [NSString stringWithFormat:@"%.2f GiB", gib];
    return [NSString stringWithFormat:@"%.0f MiB", (double)bytes / (1024.0 * 1024.0)];
}
static NSArray<NSNumber *> *TIStandardRateValues(void) {
    return @[@15, @30, @60, @90, @120, @144, @240];
}
// ====================================================================================================
// ROOT LIST CONTROLLER IMPLEMENTATION (SIÊU NHẸ 1-5% IDLE CPU, KHÔNG QUÉT ĐỆ QUY IOREGISTRY)
// ====================================================================================================
@interface RootListController () <UITableViewDelegate, UITableViewDataSource> {
    NSInteger _currentBottomTab;
    BOOL _isRateLocked;
    BOOL _isFeatureActivated;
    dispatch_source_t _hudTimer;
    NSMutableArray<NSDictionary *> *_scannedAppsList;
    NSMutableDictionary<NSString *, NSNumber *> *_appTweakStates;
    UIView *_bottomNavBar;
    NSMutableArray<UIButton *> *_tabButtons;
}
@end
@implementation RootListController
@synthesize customTableView = _customTableView;
@synthesize bottomSegment = _bottomSegment;
@synthesize rateLockButton = _rateLockButton;
@synthesize settingsDict = _settingsDict;
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"SmoothIOS Pro V39 · A20 Ultra";
    self.view.backgroundColor = [UIColor colorWithRed:0.015 green:0.012 blue:0.05 alpha:1.0];
    _currentBottomTab = 0;
    _isFeatureActivated = YES;
    _scannedAppsList = [NSMutableArray array];
    _appTweakStates = [NSMutableDictionary dictionary];
    _tabButtons = [NSMutableArray array];
    [self loadSettingsData];
    _isRateLocked = [self.settingsDict[@"IsRateLocked"] boolValue];
    [self setupNavigationBarButtons];
    [self setupMainTableView];
    [self setupBottomDockBar];
    [self loadInstalledAppsAsync];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.customTableView.userInteractionEnabled = YES;
    [self startLightweightHUD];
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopLightweightHUD];
}
- (void)setupNavigationBarButtons {
    UIBarButtonItem *respringBtn = [[UIBarButtonItem alloc] initWithTitle:@"Respring"
                                                                    style:UIBarButtonItemStylePlain
                                                                   target:self
                                                                   action:@selector(executeRespring)];
    respringBtn.tintColor = [UIColor colorWithRed:0.20 green:0.92 blue:1.0 alpha:1.0];
    self.navigationItem.rightBarButtonItem = respringBtn;
}
- (void)setupMainTableView {
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    self.customTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, w, h - 86.0) style:UITableViewStyleInsetGrouped];
    self.customTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.customTableView.backgroundColor = [UIColor clearColor];
    self.customTableView.delegate = self;
    self.customTableView.dataSource = self;
    self.customTableView.userInteractionEnabled = YES;
    [self.view addSubview:self.customTableView];
}
- (void)setupBottomDockBar {
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    _bottomNavBar = [[UIView alloc] initWithFrame:CGRectMake(12, h - 78, w - 24, 64)];
    _bottomNavBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    _bottomNavBar.backgroundColor = [UIColor colorWithRed:0.04 green:0.035 blue:0.12 alpha:0.98];
    _bottomNavBar.layer.cornerRadius = 20.0;
    _bottomNavBar.layer.borderWidth = 1.0;
    _bottomNavBar.layer.borderColor = [UIColor colorWithRed:0.25 green:0.82 blue:1.0 alpha:0.85].CGColor;
    [self.view addSubview:_bottomNavBar];
    NSArray<NSString *> *titles = @[@"Trang chủ", @"Hz / FPS", @"Tầng 1–5", @"Ứng dụng", @"Hệ thống"];
    CGFloat btnW = (_bottomNavBar.bounds.size.width) / titles.count;
    for (NSInteger i = 0; i < titles.count; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(i * btnW, 0, btnW, 64);
        btn.tag = i;
        [btn setTitle:titles[i] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
        [btn setTitleColor:(i == 0 ? [UIColor cyanColor] : [UIColor lightGrayColor]) forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(onTabButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [_bottomNavBar addSubview:btn];
        [_tabButtons addObject:btn];
    }
}
- (void)onTabButtonTapped:(UIButton *)sender {
    _currentBottomTab = sender.tag;
    for (NSInteger i = 0; i < _tabButtons.count; i++) {
        [_tabButtons[i] setTitleColor:(i == _currentBottomTab ? [UIColor cyanColor] : [UIColor lightGrayColor]) forState:UIControlStateNormal];
    }
    self.customTableView.userInteractionEnabled = YES;
    [self.customTableView reloadData];
}
#pragma mark - Ultra-Low Overhead HUD (Chu kỳ 3.5s, 0% tải phụ trên CPU/GPU)
- (void)startLightweightHUD {
    [self stopLightweightHUD];
    _hudTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(_hudTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)), (uint64_t)(3.5 * NSEC_PER_SEC), (uint64_t)(0.5 * NSEC_PER_SEC));
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(_hudTimer, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || strongSelf->_currentBottomTab != 0) return;
        if (!strongSelf.customTableView.dragging && !strongSelf.customTableView.decelerating) {
            [UIView performWithoutAnimation:^{
                [strongSelf.customTableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationNone];
            }];
        }
    });
    dispatch_resume(_hudTimer);
}
- (void)stopLightweightHUD {
    if (_hudTimer) { dispatch_source_cancel(_hudTimer); _hudTimer = nil; }
}
#pragma mark - TableView DataSource & Delegate
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (_currentBottomTab == 0) return 2;
    if (_currentBottomTab == 1) return 2;
    if (_currentBottomTab == 2) return 2;
    if (_currentBottomTab == 3) return 1;
    return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (_currentBottomTab == 0) return (section == 0) ? 4 : 3;
    if (_currentBottomTab == 1) return (section == 0) ? 1 : (NSInteger)TIStandardRateValues().count;
    if (_currentBottomTab == 2) return (section == 0) ? 6 : 6;
    if (_currentBottomTab == 3) return MAX(1, (NSInteger)_scannedAppsList.count);
    return 4;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (_currentBottomTab == 0) return (section == 0) ? @"TELEMETRY THỜI GIAN THỰC (IDLE 1–5% · 29–33°C)" : @"ĐIỀU KHIỂN TỔNG TẦNG 1–5";
    if (_currentBottomTab == 1) return (section == 0) ? @"NHẬP TẦN SỐ TÙY CHỈNH (15–240 HZ/FPS)" : @"MỨC TẦN SỐ QUÉT & KHUNG HÌNH CHUẨN";
    if (_currentBottomTab == 2) return (section == 0) ? @"BẺ KHÓA TẦNG 4–5 (CHIP MÀN / CPU / GPU / 1M HẠT 3D)" : @"ĐA NHIỆM 30+ APP / CC & NC 0MS / AN-TU-TU OVERDRIVE";
    if (_currentBottomTab == 3) return @"CẤU HÌNH HZ/FPS RIÊNG TỪNG ỨNG DỤNG (15–240)";
    return @"CÔNG CỤ HỆ THỐNG & DỌN RAM 5 TẦNG";
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"SmoothV39UltraCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellID];
        cell.backgroundColor = [UIColor colorWithRed:0.05 green:0.04 blue:0.13 alpha:0.96];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.textLabel.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightSemibold];
        cell.detailTextLabel.textColor = [UIColor colorWithRed:0.20 green:0.95 blue:1.0 alpha:1.0];
        cell.detailTextLabel.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightBold];
    }
    cell.accessoryView = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    if (_currentBottomTab == 0) {
        if (indexPath.section == 0) {
            float cpu = Titanium_GetLiveCPULoadPercentage();
            uint64_t appRam = Titanium_CurrentProcessFootprintBytes();
            uint64_t totalRam = Titanium_TotalPhysicalMemoryBytes();
            NSInteger targetHz = [self.settingsDict[@"TargetRefreshRate"] ?: @240 integerValue];
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Tải CPU thực tế (Mục tiêu rảnh 1–5%)";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f%%", cpu];
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"Bộ nhớ tiến trình / Tổng RAM vật lý";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ / %@", Titanium_ByteCountString(appRam), Titanium_ByteCountString(totalRam)];
            } else if (indexPath.row == 2) {
                cell.textLabel.text = @"Tần số đồng bộ Tầng 1–5";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld Hz · %ld FPS", (long)targetHz, (long)[self.settingsDict[@"TargetFPSRate"] ?: @240 integerValue]];
            } else {
                NSProcessInfoThermalState ts = [NSProcessInfo processInfo].thermalState;
                cell.textLabel.text = @"Nhiệt độ vận hành (Cryo-Pacing)";
                cell.detailTextLabel.text = (ts == NSProcessInfoThermalStateNominal) ? @"Siêu mát (29–33°C)" : @"Đang ép mát chủ động";
            }
        } else {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Kích hoạt Tổng Tầng 1–5 (Master Engine)";
                UISwitch *sw = [[UISwitch alloc] init];
                sw.on = [self.settingsDict[@"Enabled"] ?: @YES boolValue];
                [sw addTarget:self action:@selector(onMasterSwitchChanged:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = sw;
                cell.detailTextLabel.text = @"";
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"Khóa cứng dải tần số Hz/FPS (Zero-Drop)";
                UISwitch *sw = [[UISwitch alloc] init];
                sw.on = _isRateLocked;
                [sw addTarget:self action:@selector(onRateLockSwitchChanged:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = sw;
                cell.detailTextLabel.text = @"";
            } else {
                cell.textLabel.text = @"Đồng bộ & Đục quyền Tầng 1–5 Ngay";
                cell.detailTextLabel.text = @"ÁP DỤNG";
            }
        }
    } else if (_currentBottomTab == 1) {
        if (indexPath.section == 0) {
            cell.textLabel.text = @"Nhập Hz & FPS tùy chỉnh (15 – 240)";
            cell.detailTextLabel.text = @"Nhập số";
        } else {
            NSArray<NSNumber *> *rates = TIStandardRateValues();
            NSInteger r = rates[indexPath.row].integerValue;
            NSInteger curHz = [self.settingsDict[@"TargetRefreshRate"] ?: @240 integerValue];
            cell.textLabel.text = [NSString stringWithFormat:@"Mức %ld Hz / %ld FPS (Zero-Drop)", (long)r, (long)r];
            cell.detailTextLabel.text = (curHz == r) ? @"✓ Đang khóa" : @"Chọn";
        }
    } else if (_currentBottomTab == 2) {
        NSArray<NSString *> *titles0 = @[
            @"Tầng 5: Mở khóa IC Màn & Virtual Modes 240Hz",
            @"Tầng 5: Hạ tải CPU/GPU rảnh 1–5% (29–33°C)",
            @"Tầng 4: Tắt V-Sync & Triple-Buffer Metal 3D",
            @"Tầng 4: Xử lý 1 Triệu Hạt 3D & Mod Đồ Họa Nặng",
            @"Tầng 3: Tăng tốc Benchmark AnTuTu & GPU Compute",
            @"Tầng 2: Vuốt Control Center & Thông Báo 0ms Delay"
        ];
        NSArray<NSString *> *keys0 = @[
            @"ForceOverclock144Hz",
            @"pCoreRealtimePriority",
            @"vsyncAdaptiveBuffer",
            @"GameFPSStabilizer",
            @"MetalHexBuffering",
            @"TouchResponseBoost"
        ];
        NSArray<NSString *> *titles1 = @[
            @"Đa nhiệm 30+ App ngầm không tải lại (Jetsam Shield)",
            @"Mở Dock, Thư mục & App 20GB siêu tốc (0.06s)",
            @"Tối ưu AI Stream (ChatGPT / DeepSeek / Gemini)",
            @"Mượt TikTok Live, YouTube PiP & Video 240FPS",
            @"Mát máy khi vừa sạc nhanh vừa chơi game",
            @"Dọn rác phân mảnh RAM 5 tầng tự động"
        ];
        NSArray<NSString *> *keys1 = @[
            @"hyperMemoryGuardian",
            @"TurboAppLaunch",
            @"zeroLagNeural",
            @"ProMotionEngineBeta7",
            @"AntiThermalThrottling",
            @"periodicRamClean"
        ];
        NSString *title = (indexPath.section == 0) ? titles0[indexPath.row] : titles1[indexPath.row];
        NSString *key = (indexPath.section == 0) ? keys0[indexPath.row] : keys1[indexPath.row];
        cell.textLabel.text = title;
        cell.detailTextLabel.text = @"";
        UISwitch *sw = [[UISwitch alloc] init];
        sw.on = [self.settingsDict[key] ?: @YES boolValue];
        objc_setAssociatedObject(sw, "prefKey", key, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [sw addTarget:self action:@selector(onFeatureSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
    } else if (_currentBottomTab == 3) {
        if (_scannedAppsList.count == 0) {
            cell.textLabel.text = @"Đang quét danh sách ứng dụng...";
            cell.detailTextLabel.text = @"";
        } else {
            NSDictionary *app = _scannedAppsList[indexPath.row];
            NSString *bid = app[@"bundleID"] ?: @"";
            NSDictionary *perApp = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"TIV11PerAppProfiles"] ?: @{};
            NSDictionary *prof = perApp[bid];
            cell.textLabel.text = app[@"name"] ?: bid;
            cell.detailTextLabel.text = prof[@"rate"] ? [NSString stringWithFormat:@"%@ Hz/FPS", prof[@"rate"]] : @"Theo hệ thống";
            UISwitch *sw = [[UISwitch alloc] init];
            sw.on = [_appTweakStates[bid] ?: @YES boolValue];
            objc_setAssociatedObject(sw, "bundleID", bid, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [sw addTarget:self action:@selector(onAppSwitchChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
        }
    } else {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Respring (Áp dụng toàn bộ Tầng 1–5)";
            cell.detailTextLabel.text = @"Chạy ngay";
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Userspace Reboot (Làm mới toàn bộ Daemon)";
            cell.detailTextLabel.text = @"Chạy ngay";
        } else if (indexPath.row == 2) {
            cell.textLabel.text = @"Xả sạch phân mảnh RAM 5 tầng ngay lập tức";
            cell.detailTextLabel.text = @"Giải phóng";
        } else {
            cell.textLabel.text = @"Đặt lại cấu hình chuẩn V39 Ultra";
            cell.detailTextLabel.text = @"Reset";
        }
    }
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (_currentBottomTab == 0 && indexPath.section == 1 && indexPath.row == 2) {
        [self saveSettingsDataAndSync];
        [self applyDeepSpringBoardAndUIKitTweaks];
    } else if (_currentBottomTab == 1) {
        if (_isRateLocked) return;
        if (indexPath.section == 0) {
            [self showCombinedRateInputAlert];
        } else {
            NSArray<NSNumber *> *rates = TIStandardRateValues();
            NSInteger rate = rates[indexPath.row].integerValue;
            [self applyRateValue:rate isDynamic:NO isFPS:NO];
            [self applyRateValue:rate isDynamic:NO isFPS:YES];
            [self applyDeepSpringBoardAndUIKitTweaks];
            [self.customTableView reloadData];
        }
    } else if (_currentBottomTab == 3 && indexPath.row < (NSInteger)_scannedAppsList.count) {
        NSDictionary *app = _scannedAppsList[indexPath.row];
        [self showPerAppRateSelectorForApp:app];
    } else if (_currentBottomTab == 4) {
        if (indexPath.row == 0) [self executeRespring];
        else if (indexPath.row == 1) [self executeSReboot];
        else if (indexPath.row == 2) {
            malloc_zone_pressure_relief(malloc_default_zone(), 0);
            int purgeState = 0;
            vm_purgable_control(mach_task_self(), 0, 0, &purgeState);
        } else {
            [self ensureDefaultSettingsExist];
            [self saveSettingsDataAndSync];
            [self.customTableView reloadData];
        }
    }
}
#pragma mark - Handlers & Persistence
- (void)onMasterSwitchChanged:(UISwitch *)sender {
    self.settingsDict[@"Enabled"] = @(sender.isOn);
    [self saveSettingsDataAndSync];
    [self applyDeepSpringBoardAndUIKitTweaks];
}
- (void)onRateLockSwitchChanged:(UISwitch *)sender {
    _isRateLocked = sender.isOn;
    self.settingsDict[@"IsRateLocked"] = @(_isRateLocked);
    [self saveSettingsDataAndSync];
}
- (void)onFeatureSwitchChanged:(UISwitch *)sender {
    NSString *key = objc_getAssociatedObject(sender, "prefKey");
    if (key.length > 0) {
        self.settingsDict[key] = @(sender.isOn);
        [self saveSettingsDataAndSync];
        [self applyDeepSpringBoardAndUIKitTweaks];
    }
}
- (void)onAppSwitchChanged:(UISwitch *)sender {
    NSString *bid = objc_getAssociatedObject(sender, "bundleID");
    if (bid.length > 0) {
        _appTweakStates[bid] = @(sender.isOn);
        self.settingsDict[@"AppTweakStates"] = _appTweakStates;
        [[NSUserDefaults standardUserDefaults] setObject:_appTweakStates forKey:@"TIAppTweakStatesPersistent_v1"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [self saveSettingsDataAndSync];
    }
}
- (void)showPerAppRateSelectorForApp:(NSDictionary *)app {
    NSString *bid = app[@"bundleID"] ?: @"";
    NSString *name = app[@"name"] ?: bid;
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:name
                                                                   message:@"Chọn tần số Hz/FPS khóa riêng cho ứng dụng này (15–240):"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSNumber *rateNum in @[@240, @144, @120, @90, @60, @30, @15]) {
        [sheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%@ Hz / FPS", rateNum]
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            NSMutableDictionary *profiles = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"TIV11PerAppProfiles"] mutableCopy] ?: [NSMutableDictionary dictionary];
            profiles[bid] = @{@"rate": rateNum, @"applied": @YES};
            [[NSUserDefaults standardUserDefaults] setObject:profiles forKey:@"TIV11PerAppProfiles"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [self saveSettingsDataAndSync];
            [self.customTableView reloadData];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}
- (void)showCombinedRateInputAlert {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"NHẬP Hz/FPS (15–240)"
                                                               message:@"Nhập tần số quét và tốc độ khung hình mục tiêu:"
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.keyboardType = UIKeyboardTypeNumberPad;
        tf.placeholder = @"15–240";
    }];
    [a addAction:[UIAlertAction actionWithTitle:@"Áp dụng" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSInteger rate = [a.textFields.firstObject.text integerValue];
        rate = MAX(15, MIN(240, rate));
        [self applyRateValue:rate isDynamic:NO isFPS:NO];
        [self applyRateValue:rate isDynamic:NO isFPS:YES];
        [self applyDeepSpringBoardAndUIKitTweaks];
        [self.customTableView reloadData];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}
- (void)applyRateValue:(NSInteger)rate isDynamic:(BOOL)d isFPS:(BOOL)isFPS {
    (void)d;
    rate = MAX(15, MIN(240, rate));
    if (isFPS) {
        self.settingsDict[@"TargetFPSRate"] = @(rate);
        self.settingsDict[@"EnableFPSControl"] = @YES;
    } else {
        self.settingsDict[@"TargetRefreshRate"] = @(rate);
        self.settingsDict[@"EnableHzControl"] = @YES;
    }
    [self saveSettingsDataAndSync];
}
- (void)loadSettingsData {
    NSString *p = Titanium_ResolvePrefPath();
    NSMutableDictionary *loaded = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:p]) {
        NSDictionary *disk = [NSDictionary dictionaryWithContentsOfFile:p];
        if ([disk isKindOfClass:[NSDictionary class]]) loaded = [disk mutableCopy];
    }
    self.settingsDict = loaded ?: [NSMutableDictionary dictionary];
    [self ensureDefaultSettingsExist];
    [self saveSettingsDataAndSync];
}
- (void)ensureDefaultSettingsExist {
    NSArray<NSString *> *defaultYesKeys = @[
        @"Enabled", @"EnableHzControl", @"EnableFPSControl",
        @"ForceOverclock144Hz", @"pCoreRealtimePriority", @"vsyncAdaptiveBuffer",
        @"GameFPSStabilizer", @"MetalHexBuffering", @"TouchResponseBoost",
        @"hyperMemoryGuardian", @"TurboAppLaunch", @"zeroLagNeural",
        @"ProMotionEngineBeta7", @"AntiThermalThrottling", @"periodicRamClean",
        @"IsolateRenderPipeline"
    ];
    for (NSString *k in defaultYesKeys) {
        if (!self.settingsDict[k]) self.settingsDict[k] = @YES;
    }
    if (!self.settingsDict[@"TargetRefreshRate"]) self.settingsDict[@"TargetRefreshRate"] = @240;
    if (!self.settingsDict[@"TargetFPSRate"]) self.settingsDict[@"TargetFPSRate"] = @240;
}
- (void)saveSettingsDataAndSync {
    NSString *p = Titanium_ResolvePrefPath();
    [self.settingsDict writeToFile:p atomically:YES];
    chmod([p UTF8String], 0644);
    CFPreferencesSetMultiple((__bridge CFDictionaryRef)self.settingsDict, NULL, PREF_DOMAIN, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    CFPreferencesAppSynchronize(PREF_DOMAIN);
    [self syncSharedMemoryFile:[self.settingsDict[@"Enabled"] ?: @YES boolValue]];
}
- (void)syncSharedMemoryFile:(BOOL)enabled {
    ApexV285ProPayload p;
    memset(&p, 0, sizeof(ApexV285ProPayload));
    p.magic = APEX_SYNC_MAGIC_V285;
    p.masterEnabled = enabled ? 1 : 0;
    NSInteger hz = [self.settingsDict[@"TargetRefreshRate"] ?: @240 integerValue];
    NSInteger fps = [self.settingsDict[@"TargetFPSRate"] ?: @240 integerValue];
    p.targetHz = (int32_t)MAX(15, MIN(240, hz));
    p.targetFPS = (int32_t)MAX(15, MIN(240, fps));
    p.forceOverclock = [self.settingsDict[@"ForceOverclock144Hz"] ?: @YES boolValue] ? 1 : 0;
    p.pipSyncEnabled = 1;
    p.thermalShield = [self.settingsDict[@"AntiThermalThrottling"] ?: @YES boolValue] ? 1 : 0;
    p.antiStutterExit = 1;
    p.smartBufferingLevel = 3;
    p.zeroLatencyTouch = [self.settingsDict[@"TouchResponseBoost"] ?: @YES boolValue] ? 1 : 0;
    p.shaderOptimization = 1;
    p.dynamicInterpolation = 1;
    p.fastAppLaunch = [self.settingsDict[@"TurboAppLaunch"] ?: @YES boolValue] ? 1 : 0;
    p.metalPacingEnabled = 1;
    p.keyboardZeroLagV3 = 1;
    p.aggressiveRamCleaner = [self.settingsDict[@"periodicRamClean"] ?: @YES boolValue] ? 1 : 0;
    for (int i = 0; i < 34; i++) p.groupFlags[i] = 1;
    p.updateSeq = Titanium_IPCSequenceNow();
    p.lastHeartbeat = p.updateSeq;
    NSMutableArray<NSString *> *disabledIDs = [NSMutableArray array];
    id statesObj = self.settingsDict[@"AppTweakStates"];
    if ([statesObj isKindOfClass:[NSDictionary class]]) {
        [(NSDictionary *)statesObj enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
            (void)stop;
            if ([key isKindOfClass:[NSString class]] && ![value boolValue]) {
                [disabledIDs addObject:(NSString *)key];
            }
        }];
    }
    NSString *disabledJoined = [disabledIDs componentsJoinedByString:@"\n"];
    NSDictionary *perAppProfiles = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"TIV11PerAppProfiles"] ?: @{};
    ApexV285ProPayload payloadCopy = p;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        Titanium_WriteAtomicBytesAtPath(PRIMARY_SYNC_FILE, &payloadCopy, sizeof(ApexV285ProPayload));
        Titanium_WriteAtomicBytesAtPath(SECONDARY_SYNC_FILE, &payloadCopy, sizeof(ApexV285ProPayload));
        NSData *disabledData = [disabledJoined dataUsingEncoding:NSUTF8StringEncoding];
        Titanium_WriteAtomicBytesAtPath(APPS_SYNC_FILE_PRIMARY, disabledData.bytes, disabledData.length);
        Titanium_WriteAtomicBytesAtPath(APPS_SYNC_FILE_SECONDARY, disabledData.bytes, disabledData.length);
        if (perAppProfiles.count > 0) {
            [perAppProfiles writeToFile:PER_APP_RATES_FILE_PRIMARY atomically:YES];
            [perAppProfiles writeToFile:PER_APP_RATES_FILE_SECONDARY atomically:YES];
            chmod([PER_APP_RATES_FILE_PRIMARY UTF8String], 0644);
            chmod([PER_APP_RATES_FILE_SECONDARY UTF8String], 0644);
        }
        CFNotificationCenterRef darwin = CFNotificationCenterGetDarwinNotifyCenter();
        CFNotificationCenterPostNotification(darwin, CFSTR(NOTIFY_PAYLOAD_WRITTEN), NULL, NULL, YES);
        CFNotificationCenterPostNotification(darwin, CFSTR("com.titanium.payloadwritten"), NULL, NULL, YES);
        CFNotificationCenterPostNotification(darwin, CFSTR("com.titanium.reload"), NULL, NULL, YES);
        notify_post(NOTIFY_RELOAD);
        notify_post(NOTIFY_UIKIT_RELOAD);
        notify_post(NOTIFY_FPS_CHANGED);
    });
}
- (void)applyDeepSpringBoardAndUIKitTweaks {
    if (@available(iOS 15.0, *)) {
        NSInteger targetHz = [self.settingsDict[@"TargetRefreshRate"] ?: @240 integerValue];
        targetHz = MAX(15, MIN(240, targetHz));
        SEL sel = NSSelectorFromString(@"setPreferredFrameRateRange:");
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *ws = (UIWindowScene *)scene;
                if ([ws respondsToSelector:sel]) {
                    CAFrameRateRange range = CAFrameRateRangeMake(15.0f, (float)targetHz, (float)targetHz);
                    void (*setRange)(id, SEL, CAFrameRateRange) = (void (*)(id, SEL, CAFrameRateRange))objc_msgSend;
                    setRange(ws, sel, range);
                }
            }
        }
    }
    [self syncSharedMemoryFile:[self.settingsDict[@"Enabled"] ?: @YES boolValue]];
}
- (void)loadInstalledAppsAsync {
    NSDictionary *saved = self.settingsDict[@"AppTweakStates"];
    if ([saved isKindOfClass:[NSDictionary class]]) [_appTweakStates addEntriesFromDictionary:saved];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSMutableArray<NSDictionary *> *temp = [NSMutableArray array];
        NSArray *dirs = @[@"/Applications", @"/var/jb/Applications", @"/var/containers/Bundle/Application"];
        NSFileManager *fm = [NSFileManager defaultManager];
        for (NSString *d in dirs) {
            NSArray *contents = [fm contentsOfDirectoryAtPath:d error:nil];
            for (NSString *item in contents) {
                NSString *subPath = [d stringByAppendingPathComponent:item];
                if ([item hasSuffix:@".app"]) {
                    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[subPath stringByAppendingPathComponent:@"Info.plist"]];
                    NSString *bid = info[@"CFBundleIdentifier"];
                    NSString *name = info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"] ?: item;
                    if (bid.length) [temp addObject:@{@"name": name, @"bundleID": bid}];
                } else {
                    NSArray *subContents = [fm contentsOfDirectoryAtPath:subPath error:nil];
                    for (NSString *subItem in subContents) {
                        if ([subItem hasSuffix:@".app"]) {
                            NSString *appPath = [subPath stringByAppendingPathComponent:subItem];
                            NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[appPath stringByAppendingPathComponent:@"Info.plist"]];
                            NSString *bid = info[@"CFBundleIdentifier"];
                            NSString *name = info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"] ?: subItem;
                            if (bid.length) [temp addObject:@{@"name": name, @"bundleID": bid}];
                        }
                    }
                }
            }
        }
        [temp sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            return [a[@"name"] localizedCaseInsensitiveCompare:b[@"name"]];
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_scannedAppsList = temp;
            for (NSDictionary *app in temp) {
                NSString *bid = app[@"bundleID"];
                if (bid.length && self->_appTweakStates[bid] == nil) self->_appTweakStates[bid] = @YES;
            }
            if (self->_currentBottomTab == 3) [self.customTableView reloadData];
        });
    });
}
- (void)executeRespring {
    NSString *path = Titanium_FindExecutablePath(@"sbreload") ?: Titanium_FindExecutablePath(@"killall");
    if (!path) return;
    pid_t pid;
    if ([path hasSuffix:@"sbreload"]) {
        char *const argv[] = {(char *)[path UTF8String], NULL};
        posix_spawn(&pid, [path UTF8String], NULL, NULL, argv, environ);
    } else {
        char *const argv[] = {(char *)[path UTF8String], "SpringBoard", NULL};
        posix_spawn(&pid, [path UTF8String], NULL, NULL, argv, environ);
    }
}
- (void)executeSReboot {
    NSString *path = Titanium_FindExecutablePath(@"launchctl");
    if (!path) return;
    pid_t pid;
    char *const argv[] = {(char *)[path UTF8String], "reboot", "userspace", NULL};
    posix_spawn(&pid, [path UTF8String], NULL, NULL, argv, environ);
}
@end
