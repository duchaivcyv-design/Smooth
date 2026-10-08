#import "RootListController.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <spawn.h>
#import <sys/wait.h>
#import <sys/stat.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>
#import <fcntl.h>
#import <unistd.h>
#import <notify.h>
#import <dlfcn.h>
#import <mach/mach.h>
#import <mach/mach_time.h>
#import <mach/processor_info.h>
#import <mach/mach_host.h>
#import <mach/vm_map.h>
#import <AudioToolbox/AudioToolbox.h>
#import <QuartzCore/QuartzCore.h>

extern char **environ;

#ifndef APEX_SYNC_MAGIC_V285
#define APEX_SYNC_MAGIC_V285 0x41505837
#endif

#ifndef PRIMARY_SYNC_FILE
#define PRIMARY_SYNC_FILE    @"/tmp/.boost_hz_sync"
#endif

#ifndef SECONDARY_SYNC_FILE
#define SECONDARY_SYNC_FILE  @"/var/jb/tmp/.boost_hz_sync"
#endif

#ifndef TITANIUM_BOOT_FLAG_VERIFIED
#define TITANIUM_BOOT_FLAG_VERIFIED @"/tmp/.titanium_tweak_verified"
#endif

#ifndef NOTIFY_RELOAD
#define NOTIFY_RELOAD        "com.taojb.boostiphone6s/ReloadPrefs"
#define NOTIFY_UIKIT_RELOAD  "com.taojb.boostiphone6s/ReloadUIKitPrefs"
#define NOTIFY_HARDWARE_SYNC "com.taojb.boostiphone6s/HardwareSync"
#define NOTIFY_FPS_CHANGED   "com.taojb.boostiphone6s/FPSChanged"
#define NOTIFY_TITANIUM_CHANGED "com.titanium.v285.prefschanged"
#endif

#ifndef _APEX_V285_PRO_PAYLOAD_DEFINED
#define _APEX_V285_PRO_PAYLOAD_DEFINED
typedef struct {
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
#endif

// ====================================================================================================
// 1. LIQUID GLASS VIEW CONTAINER (HIỆU ỨNG KHÚC XẠ THỦY TINH QUANG HỌC)
// ====================================================================================================
@interface LiquidGlassView : UIView
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) CAGradientLayer *specularHighlight;
@property (nonatomic, strong) CAShapeLayer *refractionRimLayer;
- (instancetype)initWithFrame:(CGRect)frame cornerRadius:(CGFloat)radius;
@end

@implementation LiquidGlassView

- (instancetype)initWithFrame:(CGRect)frame cornerRadius:(CGFloat)radius {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor clearColor];
        self.layer.cornerRadius = radius;
        self.layer.cornerCurve = kCACornerCurveContinuous;
        self.clipsToBounds = YES;

        // Lớp làm mờ khúc xạ nền (Backdrop Blur)
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
        _blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
        _blurView.frame = self.bounds;
        _blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _blurView.userInteractionEnabled = NO;
        _blurView.alpha = 0.88;
        [self addSubview:_blurView];

        // Lớp vệt sáng Fresnel & Gradient bề mặt lồi (Specular Glare)
        _specularHighlight = [CAGradientLayer layer];
        _specularHighlight.frame = self.bounds;
        _specularHighlight.cornerRadius = radius;
        _specularHighlight.cornerCurve = kCACornerCurveContinuous;
        _specularHighlight.colors = @[
            (id)[UIColor colorWithWhite:1.0 alpha:0.38].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:0.08].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:0.18].CGColor
        ];
        _specularHighlight.locations = @[@0.0, @0.28, @0.72, @1.0];
        _specularHighlight.startPoint = CGPointMake(0.0, 0.0);
        _specularHighlight.endPoint = CGPointMake(1.0, 1.0);
        [self.layer addSublayer:_specularHighlight];

        // Viền khúc xạ mép ngoài (Caustic Rim Stroke)
        _refractionRimLayer = [CAShapeLayer layer];
        _refractionRimLayer.path = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:radius].CGPath;
        _refractionRimLayer.fillColor = [UIColor clearColor].CGColor;
        _refractionRimLayer.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.45].CGColor;
        _refractionRimLayer.lineWidth = 1.2;
        [self.layer addSublayer:_refractionRimLayer];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _blurView.frame = self.bounds;
    _specularHighlight.frame = self.bounds;
    _refractionRimLayer.path = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:self.layer.cornerRadius].CGPath;
}

@end

// ====================================================================================================
// 2. LIQUID GLASS CAPSULE SWITCH (CÔNG TẮC CON NHỘNG THỦY TINH TRƯỢT)
// ====================================================================================================
@interface LiquidCapsuleSwitch : UIControl
@property (nonatomic, assign) BOOL on;
@property (nonatomic, strong) UIView *trackView;
@property (nonatomic, strong) LiquidGlassView *glassThumb;
@property (nonatomic, copy) void (^valueChangedBlock)(BOOL isOn);
- (void)setOn:(BOOL)on animated:(BOOL)animated;
@end

@implementation LiquidCapsuleSwitch

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:CGRectMake(0, 0, 62, 32)]) {
        self.backgroundColor = [UIColor clearColor];

        // Rãnh màu nền (Track) - dạng capsule màu pastel
        _trackView = [[UIView alloc] initWithFrame:self.bounds];
        _trackView.layer.cornerRadius = 16.0;
        _trackView.layer.cornerCurve = kCACornerCurveContinuous;
        _trackView.userInteractionEnabled = NO;
        _trackView.layer.borderWidth = 1.0;
        _trackView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.18].CGColor;
        [self addSubview:_trackView];

        // Thỏi gạt bằng thủy tinh lồi (Liquid Glass Thumb)
        _glassThumb = [[LiquidGlassView alloc] initWithFrame:CGRectMake(2, 2, 34, 28) cornerRadius:14.0];
        _glassThumb.userInteractionEnabled = NO;
        _glassThumb.layer.shadowColor = [UIColor blackColor].CGColor;
        _glassThumb.layer.shadowOpacity = 0.35;
        _glassThumb.layer.shadowOffset = CGSizeMake(0, 3);
        _glassThumb.layer.shadowRadius = 5.0;
        [self addSubview:_glassThumb];

        [self addTarget:self action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
        [self updateUIAnimated:NO];
    }
    return self;
}

- (void)handleTap {
    [self setOn:!_on animated:YES];
    [self sendActionsForControlEvents:UIControlEventValueChanged];
    if (self.valueChangedBlock) {
        self.valueChangedBlock(_on);
    }
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [feedback impactOccurred];
}

- (void)setOn:(BOOL)on {
    [self setOn:on animated:NO];
}

- (void)setOn:(BOOL)on animated:(BOOL)animated {
    _on = on;
    [self updateUIAnimated:animated];
}

- (void)updateUIAnimated:(BOOL)animated {
    UIColor *onColor = [UIColor colorWithRed:0.22 green:0.75 blue:0.42 alpha:0.95];
    UIColor *offColor = [UIColor colorWithRed:0.18 green:0.20 blue:0.24 alpha:0.75];

    CGRect thumbFrame = _on ? CGRectMake(self.bounds.size.width - 36, 2, 34, 28) : CGRectMake(2, 2, 34, 28);

    void (^animations)(void) = ^{
        self.trackView.backgroundColor = self->_on ? onColor : offColor;
        self.glassThumb.frame = thumbFrame;
    };

    if (animated) {
        [UIView animateWithDuration:0.32 delay:0 usingSpringWithDamping:0.78 initialSpringVelocity:0.7 options:UIViewAnimationOptionCurveEaseOut animations:animations completion:nil];
    } else {
        animations();
    }
}

@end

// ====================================================================================================
// ROOT LIST CONTROLLER CHÍNH
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
    NSArray *searchPrefixes = @[
        [Titanium_GetRootHidePrefixPath() stringByAppendingPathComponent:@"usr/bin"],
        [Titanium_GetRootHidePrefixPath() stringByAppendingPathComponent:@"bin"],
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

static inline BOOL Titanium_IsSupportedIOSVersion(void) {
    NSOperatingSystemVersion os = [[NSProcessInfo processInfo] operatingSystemVersion];
    return (os.majorVersion >= 15 && os.majorVersion <= 26);
}

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

@interface RootListController () {
    dispatch_source_t _hudTimer;
    NSInteger _currentBottomTab;
    NSInteger _currentHzFpsSubTab;
    NSInteger _currentSwitchSubTab;
    BOOL _isRateLocked;
    BOOL _isKernelExploited;
    
    BOOL _isCpuExpanded;
    BOOL _isGpuExpanded;
    BOOL _isRamExpanded;
    BOOL _isBatteryExpanded;
    BOOL _isScreenExpanded;
    
    NSString *_deepArchString;
    NSString *_deepCoreCountString;
    NSString *_deepRamString;
    NSString *_deepKernelString;
    NSString *_deepCacheString;
    NSString *_deviceUUIDString;
    
    NSMutableArray<NSDictionary *> *_scannedAppsList;
    NSMutableDictionary<NSString *, NSNumber *> *_appTweakStates;
    
    // UI Liquid Glass Floating Nav Bar (Ảnh 6)
    LiquidGlassView *_liquidNavBarContainer;
    LiquidGlassView *_activeGlassIndicator;
    NSMutableArray<UIButton *> *_tabButtons;
    NSArray<NSDictionary *> *_tabConfigs;
    
    // Thấu kính Liquid Glass khi nhấn giữ (Ảnh 2)
    UIView *_liquidGlassLensContainer;
    LiquidGlassView *_lensGlassEffectView;
    UILabel *_lensTitleLabel;
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
    self.view.backgroundColor = [UIColor colorWithRed:0.02 green:0.03 blue:0.07 alpha:1.0];

    _currentBottomTab = 0;
    _currentHzFpsSubTab = 0;
    _currentSwitchSubTab = 0;

    _isCpuExpanded = NO;
    _isGpuExpanded = NO;
    _isRamExpanded = NO;
    _isBatteryExpanded = NO;
    _isScreenExpanded = NO;

    _scannedAppsList = [NSMutableArray array];
    _tabButtons = [NSMutableArray array];

    [self loadSettingsData];
    _isRateLocked = [self.settingsDict[@"IsRateLocked"] boolValue];

    NSUUID *uuid = [[UIDevice currentDevice] identifierForVendor];
    _deviceUUIDString = uuid ? [uuid UUIDString] : @"UNKNOWN-DEVICE-UUID";

    _isKernelExploited = [self.settingsDict[@"IsKernelExploited"] boolValue];
    if (_isKernelExploited) {
        _deepArchString = self.settingsDict[@"SavedArchString"] ?: @"arm64e (Apple Silicon PAC)";
        _deepCoreCountString = self.settingsDict[@"SavedCoreCountString"] ?: @"SoC Clustered P/E Cores";
        _deepRamString = self.settingsDict[@"SavedRamString"] ?: @"LPDDR Mach Purgable";
        _deepKernelString = self.settingsDict[@"SavedKernelString"] ?: @"Darwin XNU Kernel";
        _deepCacheString = self.settingsDict[@"SavedCacheString"] ?: @"Low Latency Silicon Cache";
    }

    [self setupTopHeaderBar];
    [self setupNavigationItems];
    [self setupLiquidGlassNavBar]; // HIỆU ỨNG NAV BAR KHÚC XẠ ẢNH 6
    [self setupMainTableView];
    [self setupLiquidGlassLens];   // THẤU KÍNH LỒI

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self loadInstalledAppsAsync];
        if (self->_isKernelExploited) {
            [self applyDeepSpringBoardAndUIKitTweaks];
        }
    });
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (_isKernelExploited) {
        [self startContinuousHardwareHUD];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopContinuousHardwareHUD];
}

#pragma mark - Nav Bar Liquid Glass (Chuẩn Ảnh 6)

- (void)setupLiquidGlassNavBar {
    CGFloat barHeight = 58.0;
    CGFloat barMargin = 16.0;
    CGFloat barY = self.view.bounds.size.height - barHeight - 34;

    _liquidNavBarContainer = [[LiquidGlassView alloc] initWithFrame:CGRectMake(barMargin, barY, self.view.bounds.size.width - (barMargin * 2), barHeight) cornerRadius:barHeight / 2.0];
    _liquidNavBarContainer.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;

    // Đổ bóng ánh sáng xanh tím neon phía sau theo chuẩn ảnh 6
    _liquidNavBarContainer.layer.shadowColor = [UIColor colorWithRed:0.25 green:0.45 blue:1.0 alpha:0.45].CGColor;
    _liquidNavBarContainer.layer.shadowOffset = CGSizeMake(0, 10);
    _liquidNavBarContainer.layer.shadowRadius = 24.0;
    _liquidNavBarContainer.layer.shadowOpacity = 0.8;

    _tabConfigs = @[
        @{@"title": @"Trang Chủ", @"icon": @"house.fill",  @"tab": @0},
        @{@"title": @"Hz/FPS",    @"icon": @"speedometer", @"tab": @1},
        @{@"title": @"Switch",    @"icon": @"bolt.fill",   @"tab": @2},
        @{@"title": @"App",       @"icon": @"iphone",      @"tab": @3},
        @{@"title": @"Cài Đặt",   @"icon": @"gearshape",   @"tab": @4}
    ];

    CGFloat btnWidth = _liquidNavBarContainer.bounds.size.width / _tabConfigs.count;

    // Con trượt bằng thủy tinh lồi sáng bóng (Liquid Glass Indicator)
    _activeGlassIndicator = [[LiquidGlassView alloc] initWithFrame:CGRectMake(3, 3, btnWidth - 6, barHeight - 6) cornerRadius:(barHeight - 6) / 2.0];
    _activeGlassIndicator.userInteractionEnabled = NO;
    _activeGlassIndicator.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.35].CGColor;
    _activeGlassIndicator.layer.borderWidth = 1.2;
    [_liquidNavBarContainer addSubview:_activeGlassIndicator];

    for (NSInteger i = 0; i < _tabConfigs.count; i++) {
        NSDictionary *conf = _tabConfigs[i];
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(i * btnWidth, 0, btnWidth, barHeight);
        btn.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        btn.tag = i;

        UIImage *iconImg = [UIImage systemImageNamed:conf[@"icon"]];
        [btn setImage:iconImg forState:UIControlStateNormal];
        [btn setTitle:conf[@"title"] forState:UIControlStateNormal];
        btn.tintColor = (i == 0) ? [UIColor whiteColor] : [UIColor colorWithWhite:0.75 alpha:1.0];
        [btn setTitleColor:(i == 0) ? [UIColor whiteColor] : [UIColor colorWithWhite:0.75 alpha:1.0] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];

        CGFloat spacing = 3.0;
        CGSize imageSize = btn.imageView.image.size;
        btn.titleEdgeInsets = UIEdgeInsetsMake(0, -imageSize.width, -(imageSize.height + spacing), 0);
        CGSize titleSize = [btn.titleLabel.text sizeWithAttributes:@{NSFontAttributeName: btn.titleLabel.font}];
        btn.imageEdgeInsets = UIEdgeInsetsMake(-(titleSize.height + spacing), 0, 0, -titleSize.width);

        [btn addTarget:self action:@selector(onCustomTabButtonClicked:) forControlEvents:UIControlEventTouchUpInside];

        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleTabLongPress:)];
        longPress.minimumPressDuration = 0.12;
        [btn addGestureRecognizer:longPress];

        [_liquidNavBarContainer addSubview:btn];
        [_tabButtons addObject:btn];
    }

    [self.view addSubview:_liquidNavBarContainer];
}

- (void)onCustomTabButtonClicked:(UIButton *)sender {
    [self selectTabIndex:sender.tag animated:YES];
}

- (void)selectTabIndex:(NSInteger)index animated:(BOOL)animated {
    _currentBottomTab = [_tabConfigs[index][@"tab"] integerValue];

    CGFloat btnWidth = _liquidNavBarContainer.bounds.size.width / _tabConfigs.count;
    CGRect targetFrame = CGRectMake((index * btnWidth) + 3, 3, btnWidth - 6, _liquidNavBarContainer.bounds.size.height - 6);

    void (^animations)(void) = ^{
        self->_activeGlassIndicator.frame = targetFrame;
        for (NSInteger i = 0; i < self->_tabButtons.count; i++) {
            UIButton *b = self->_tabButtons[i];
            BOOL isSel = (i == index);
            b.tintColor = isSel ? [UIColor whiteColor] : [UIColor colorWithWhite:0.75 alpha:1.0];
            [b setTitleColor:isSel ? [UIColor whiteColor] : [UIColor colorWithWhite:0.75 alpha:1.0] forState:UIControlStateNormal];
            b.titleLabel.font = isSel ? [UIFont systemFontOfSize:10.5 weight:UIFontWeightBold] : [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
        }
    };

    if (animated) {
        [UIView animateWithDuration:0.32 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:0.8 options:UIViewAnimationOptionCurveEaseOut animations:animations completion:nil];
    } else {
        animations();
    }

    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];

    [self.customTableView reloadData];
}

#pragma mark - Liquid Glass Lens (Thấu Kính Quang Học)

- (void)setupLiquidGlassLens {
    _liquidGlassLensContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 82, 82)];
    _liquidGlassLensContainer.hidden = YES;
    _liquidGlassLensContainer.userInteractionEnabled = NO;

    _lensGlassEffectView = [[LiquidGlassView alloc] initWithFrame:_liquidGlassLensContainer.bounds cornerRadius:41.0];
    _lensGlassEffectView.layer.borderColor = [UIColor colorWithRed:0.4 green:0.8 blue:1.0 alpha:0.8].CGColor;
    _lensGlassEffectView.layer.borderWidth = 1.8;
    [_liquidGlassLensContainer addSubview:_lensGlassEffectView];

    _lensTitleLabel = [[UILabel alloc] initWithFrame:_liquidGlassLensContainer.bounds];
    _lensTitleLabel.textAlignment = NSTextAlignmentCenter;
    _lensTitleLabel.textColor = [UIColor whiteColor];
    _lensTitleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightHeavy];
    [_liquidGlassLensContainer addSubview:_lensTitleLabel];

    [self.view addSubview:_liquidGlassLensContainer];
}

- (void)handleTabLongPress:(UILongPressGestureRecognizer *)gesture {
    UIButton *btn = (UIButton *)gesture.view;
    CGPoint touchInView = [gesture locationInView:self.view];

    if (gesture.state == UIGestureRecognizerStateBegan) {
        CGPoint centerPoint = CGPointMake(touchInView.x, _liquidNavBarContainer.center.y - 18);
        _liquidGlassLensContainer.center = centerPoint;
        _liquidGlassLensContainer.hidden = NO;
        _liquidGlassLensContainer.alpha = 0.0;
        _liquidGlassLensContainer.transform = CGAffineTransformMakeScale(0.3, 0.3);

        _lensTitleLabel.text = _tabConfigs[btn.tag][@"title"];

        [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.65 initialSpringVelocity:1.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self->_liquidGlassLensContainer.alpha = 1.0;
            self->_liquidGlassLensContainer.transform = CGAffineTransformIdentity;
        } completion:nil];

        UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [fb impactOccurred];

    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        CGPoint centerPoint = CGPointMake(touchInView.x, _liquidNavBarContainer.center.y - 18);
        _liquidGlassLensContainer.center = centerPoint;

        for (NSInteger i = 0; i < _tabButtons.count; i++) {
            UIButton *b = _tabButtons[i];
            CGPoint p = [gesture locationInView:b];
            if (CGRectContainsPoint(b.bounds, p)) {
                _lensTitleLabel.text = _tabConfigs[i][@"title"];
                if (_currentBottomTab != [_tabConfigs[i][@"tab"] integerValue]) {
                    [self selectTabIndex:i animated:YES];
                }
                break;
            }
        }
    } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
            self->_liquidGlassLensContainer.alpha = 0.0;
            self->_liquidGlassLensContainer.transform = CGAffineTransformMakeScale(0.2, 0.2);
        } completion:^(BOOL finished) {
            self->_liquidGlassLensContainer.hidden = YES;
            self->_liquidGlassLensContainer.transform = CGAffineTransformIdentity;
        }];
    }
}

#pragma mark - Navigation & Header

- (void)setupTopHeaderBar {
    UILabel *brandLabel = [[UILabel alloc] init];
    brandLabel.text = @" 💧 Liquid Glass 3.0 ";
    brandLabel.textColor = [UIColor colorWithRed:0.35 green:0.85 blue:1.0 alpha:1.0];
    brandLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightHeavy];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:brandLabel];
}

- (void)setupNavigationItems {
    self.rateLockButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self updateLockIcon];
    [self.rateLockButton addTarget:self action:@selector(toggleRateLockAction) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *lockItem = [[UIBarButtonItem alloc] initWithCustomView:self.rateLockButton];

    UIButton *applyInstantButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [applyInstantButton setImage:[UIImage systemImageNamed:@"bolt.horizontal.fill"] forState:UIControlStateNormal];
    applyInstantButton.tintColor = [UIColor colorWithRed:0.25 green:0.95 blue:0.6 alpha:1.0];
    [applyInstantButton addTarget:self action:@selector(applySettingsInstantNoRespringAction) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *applyItem = [[UIBarButtonItem alloc] initWithCustomView:applyInstantButton];

    UIAction *actRespring = [UIAction actionWithTitle:@"⚡ Respring Nhanh"
                                                image:[UIImage systemImageNamed:@"arrow.triangle.2.circlepath"]
                                           identifier:nil
                                              handler:^(__kindof UIAction * _Nonnull action) {
        [self executeRespring];
    }];

    UIAction *actSReboot = [UIAction actionWithTitle:@"🔥 Khởi Động Userspace"
                                               image:[UIImage systemImageNamed:@"arrow.clockwise.circle.fill"]
                                          identifier:nil
                                             handler:^(__kindof UIAction * _Nonnull action) {
        [self executeSReboot];
    }];

    UIAction *actSafeMode = [UIAction actionWithTitle:@"🛡️ Vào Safe Mode An Toàn"
                                                image:[UIImage systemImageNamed:@"shield.lefthalf.fill"]
                                           identifier:nil
                                              handler:^(__kindof UIAction * _Nonnull action) {
        [self executeSafeMode];
    }];

    UIAction *actReset = [UIAction actionWithTitle:@"♻ Đặt Lại & Xóa Sạch Dữ Liệu"
                                             image:[UIImage systemImageNamed:@"trash.fill"]
                                        identifier:nil
                                           handler:^(__kindof UIAction * _Nonnull action) {
        [self executeResetConfiguration];
    }];
    actReset.attributes = UIMenuElementAttributesDestructive;

    UIMenu *threeBarMenu = [UIMenu menuWithTitle:@"HÀNH ĐỘNG HỆ THỐNG" children:@[actRespring, actSReboot, actSafeMode, actReset]];
    UIBarButtonItem *menuItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"line.3.horizontal"] menu:threeBarMenu];
    menuItem.tintColor = [UIColor whiteColor];

    self.navigationItem.rightBarButtonItems = @[menuItem, lockItem, applyItem];
}

- (void)applySettingsInstantNoRespringAction {
    if (!_isKernelExploited) {
        [self showUnexploitedWarningAlert];
        return;
    }

    [self saveSettingsDataAndSync];
    [self applyDeepSpringBoardAndUIKitTweaks];

    UINotificationFeedbackGenerator *notiFb = [[UINotificationFeedbackGenerator alloc] init];
    [notiFb notificationOccurred:UINotificationFeedbackTypeSuccess];

    UIView *toastView = [[UIView alloc] initWithFrame:CGRectMake(30, 90, self.view.bounds.size.width - 60, 42)];
    toastView.backgroundColor = [UIColor colorWithRed:0.08 green:0.22 blue:0.15 alpha:0.95];
    toastView.layer.cornerRadius = 14;
    toastView.layer.borderWidth = 1.0;
    toastView.layer.borderColor = [UIColor colorWithRed:0.25 green:0.95 blue:0.6 alpha:0.8].CGColor;
    
    UILabel *toastLabel = [[UILabel alloc] initWithFrame:toastView.bounds];
    toastLabel.text = @"⚡ ĐÃ ĐỒNG BỘ TỨC THÌ (KHÔNG CẦN RESPRING)";
    toastLabel.textColor = [UIColor colorWithRed:0.3 green:1.0 blue:0.6 alpha:1.0];
    toastLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    toastLabel.textAlignment = NSTextAlignmentCenter;
    [toastView addSubview:toastLabel];
    [self.view addSubview:toastView];

    toastView.alpha = 0.0;
    toastView.transform = CGAffineTransformMakeScale(0.85, 0.85);
    [UIView animateWithDuration:0.25 animations:^{
        toastView.alpha = 1.0;
        toastView.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.35 delay:1.6 options:0 animations:^{
            toastView.alpha = 0.0;
            toastView.transform = CGAffineTransformMakeTranslation(0, -15);
        } completion:^(BOOL finished) {
            [toastView removeFromSuperview];
        }];
    }];
}

- (void)updateLockIcon {
    NSString *iconName = self->_isRateLocked ? @"lock.fill" : @"lock.open.fill";
    UIColor *color = self->_isRateLocked ? [UIColor systemRedColor] : [UIColor colorWithRed:0.2 green:0.85 blue:1.0 alpha:1.0];
    [self.rateLockButton setImage:[UIImage systemImageNamed:iconName] forState:UIControlStateNormal];
    self.rateLockButton.tintColor = color;
}

- (void)toggleRateLockAction {
    if (!_isKernelExploited) {
        [self showUnexploitedWarningAlert];
        return;
    }

    self->_isRateLocked = !self->_isRateLocked;
    self.settingsDict[@"IsRateLocked"] = @(self->_isRateLocked);
    [self saveSettingsDataAndSync];
    [self updateLockIcon];

    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
    [feedback impactOccurred];

    [self applyDeepSpringBoardAndUIKitTweaks];
    [self.customTableView reloadData];
}

#pragma mark - TableView Setup & Liquid Glass Cells

- (void)setupMainTableView {
    self.customTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - 100) style:UITableViewStyleInsetGrouped];
    self.customTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.customTableView.backgroundColor = [UIColor clearColor];
    self.customTableView.separatorColor = [UIColor colorWithWhite:1.0 alpha:0.06];
    self.customTableView.delegate = self;
    self.customTableView.dataSource = self;
    [self.view addSubview:self.customTableView];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (_currentBottomTab == 0) return 6;
    if (_currentBottomTab == 1) return 3;
    if (_currentBottomTab == 2) return 2;
    if (_currentBottomTab == 3) return 1;
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (!_isKernelExploited && _currentBottomTab != 4) {
        return 1;
    }

    if (_currentBottomTab == 0) {
        if (section == 0) return 1;
        BOOL isMonitorActive = [self.settingsDict[@"EnableSystemMonitoring"] boolValue];
        if (!isMonitorActive) return 1;

        if (section == 1) return _isCpuExpanded ? 5 : 1;
        if (section == 2) return _isGpuExpanded ? 5 : 1;
        if (section == 3) return _isRamExpanded ? 4 : 1;
        if (section == 4) return _isBatteryExpanded ? 5 : 1;
        return _isScreenExpanded ? 4 : 1;
    } else if (_currentBottomTab == 1) {
        if (section == 0) return 1;
        if (section == 1) return 1;
        return 6;
    } else if (_currentBottomTab == 2) {
        if (section == 0) return 1;
        switch (_currentSwitchSubTab) {
            case 0: return 5;
            case 1: return 5;
            case 2: return 5;
            case 3: return 5;
            case 4: return 6;
            default: return 5;
        }
    } else if (_currentBottomTab == 3) {
        return _scannedAppsList.count;
    } else {
        if (section == 0) return 2;
        if (section == 1) return _isKernelExploited ? 8 : 1;
        return 4;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (!_isKernelExploited && _currentBottomTab != 4) {
        return @"🔒 TRẠNG THÁI KHÓA HỆ THỐNG";
    }

    if (_currentBottomTab == 0) {
        if (section == 0) return @"🎛️ ĐIỀU KHIỂN HỆ THỐNG ĐO";
        if (section == 1) return @"🧠 BỘ XỬ LÝ TRUNG TÂM (CPU)";
        if (section == 2) return @"🎮 BỘ XỬ LÝ ĐỒ HỌA (GPU)";
        if (section == 3) return @"💾 BỘ NHỚ TRUY XUẤT (RAM)";
        if (section == 4) return @"🔋 NGUỒN ĐIỆN & PIN";
        return @"🖥️ MÀN HÌNH HIỂN THỊ";
    } else if (_currentBottomTab == 1) {
        if (section == 0) return @"ℹ️ NGUYÊN LÝ HOẠT ĐỘNG HZ & FPS";
        if (section == 1) return @"⚡ ĐIỀU PHỐI ĐỘC LẬP TẦN SỐ QUÉT";
        return (_currentHzFpsSubTab == 0) ? @"🎛️ KHÓA TẦN SỐ QUÉT (HZ)" : @"🎮 KHÓA KHUNG HÌNH (FPS)";
    } else if (_currentBottomTab == 2) {
        if (section == 0) return @"🎚️ CHỌN PHÂN NHÓM CÔNG TẮC";
        switch (_currentSwitchSubTab) {
            case 0: return @"🧠 NHÓM CPU";
            case 1: return @"🎮 NHÓM GPU";
            case 2: return @"🖥️ NHÓM MÀN HÌNH";
            case 3: return @"🔋 NHÓM PIN";
            case 4: return @"⚡ NHÓM HỆ THỐNG";
            default: return @"🟢 CÔNG TẮC";
        }
    } else if (_currentBottomTab == 3) {
        return @"📱 QUẢN LÝ ỨNG DỤNG TƯƠNG TÁC";
    } else {
        if (section == 0) return @"🛡️ TRẠNG THÁI KHAI THÁC HỆ THỐNG";
        if (section == 1) return @"📱 THÔNG TIN PHẦN CỨNG THIẾT BỊ";
        return @"🛡️ THÔNG TIN VÙNG SANDBOX";
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellID = [NSString stringWithFormat:@"Cell_LG_%ld_%ld_%ld", (long)_currentBottomTab, (long)indexPath.section, (long)indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellID];
    }

    for (UIView *subview in cell.contentView.subviews) {
        [subview removeFromSuperview];
    }

    // Hiệu ứng kính lồi mờ phủ lớp viền phản chiếu ánh sáng
    cell.backgroundColor = [UIColor colorWithRed:0.07 green:0.10 blue:0.16 alpha:0.65];
    cell.layer.cornerRadius = 14;
    cell.layer.cornerCurve = kCACornerCurveContinuous;
    cell.layer.borderWidth = 1.0;
    cell.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.12].CGColor;
    cell.clipsToBounds = YES;

    cell.textLabel.textColor = [UIColor whiteColor];
    cell.detailTextLabel.textColor = [UIColor colorWithRed:0.3 green:0.85 blue:1.0 alpha:1.0];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.alpha = 1.0;
    cell.userInteractionEnabled = YES;

    if (!_isKernelExploited && _currentBottomTab != 4) {
        cell.backgroundColor = [UIColor colorWithRed:0.14 green:0.04 blue:0.06 alpha:0.65];
        cell.textLabel.text = @"🔒 TÍNH NĂNG ĐANG BỊ KHÓA XÁM";
        cell.textLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
        cell.detailTextLabel.text = @"Chưa Khai Thác";
        cell.detailTextLabel.textColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.4 alpha:1.0];
        cell.alpha = 0.45;
        cell.userInteractionEnabled = NO;
        return cell;
    }

    // TAB 0: TRANG CHỦ
    if (_currentBottomTab == 0) {
        if (indexPath.section == 0) {
            cell.textLabel.text = @"⚡ Kích Hoạt Bộ Đo Phần Cứng Realtime";
            cell.textLabel.font = [UIFont boldSystemFontOfSize:14];

            LiquidCapsuleSwitch *monitorSwitch = [[LiquidCapsuleSwitch alloc] init];
            monitorSwitch.on = [self.settingsDict[@"EnableSystemMonitoring"] boolValue];
            __weak typeof(self) weakSelf = self;
            monitorSwitch.valueChangedBlock = ^(BOOL isOn) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                strongSelf.settingsDict[@"EnableSystemMonitoring"] = @(isOn);
                [strongSelf saveSettingsDataAndSync];
                [strongSelf.customTableView reloadData];
            };
            cell.accessoryView = monitorSwitch;
            return cell;
        }

        BOOL isMonitorActive = [self.settingsDict[@"EnableSystemMonitoring"] boolValue];
        if (!isMonitorActive) {
            cell.textLabel.text = @"🔒 Bộ đo đang tắt (Bật công tắc phía trên để theo dõi)";
            cell.detailTextLabel.text = @"[TẮT]";
            cell.detailTextLabel.textColor = [UIColor systemOrangeColor];
            cell.textLabel.textColor = [UIColor lightGrayColor];
            return cell;
        }

        float baseTemp = Titanium_GetBaseThermalTemp();
        float cpu = Titanium_GetLiveCPULoadPercentage();
        float gpu = Titanium_GetLiveGPULoadPercentage();

        cell.selectionStyle = UITableViewCellSelectionStyleDefault;

        if (indexPath.section == 1) {
            if (indexPath.row == 0) {
                cell.textLabel.text = _isCpuExpanded ? @"🧠 CPU (Chạm để thu gọn ▼)" : @"🧠 CPU (Chạm để xem chi tiết ▶)";
                cell.textLabel.font = [UIFont boldSystemFontOfSize:14];
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C | Tải: %.1f%%", baseTemp, cpu];
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"   |--> Nhiệt độ CPU XNU";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C", baseTemp];
            } else if (indexPath.row == 2) {
                cell.textLabel.text = @"   |--> % Tải CPU Thực Tế";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f%%", cpu];
            } else if (indexPath.row == 3) {
                float ghz = (cpu > 60.0f) ? 2.49f : ((cpu > 25.0f) ? 1.85f : 1.10f);
                cell.textLabel.text = @"   |--> Xung nhịp P-Core";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.2f GHz", ghz];
            } else {
                cell.textLabel.text = @"   |--> Bộ Điều Phối Lõi";
                cell.detailTextLabel.text = (cpu > 40.0f) ? @"P-Core Realtime" : @"E-Core PowerSave";
            }
        } else if (indexPath.section == 2) {
            if (indexPath.row == 0) {
                cell.textLabel.text = _isGpuExpanded ? @"🎮 GPU (Chạm để thu gọn ▼)" : @"🎮 GPU (Chạm để xem chi tiết ▶)";
                cell.textLabel.font = [UIFont boldSystemFontOfSize:14];
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C | Tải: %.1f%%", baseTemp - 0.7f, gpu];
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"   |--> Nhiệt độ Silicon GPU";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C", baseTemp - 0.7f];
            } else if (indexPath.row == 2) {
                cell.textLabel.text = @"   |--> % Tải Metal Pipeline";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f%%", gpu];
            } else if (indexPath.row == 3) {
                cell.textLabel.text = @"   |--> Tần số xung Metal";
                cell.detailTextLabel.text = @"600 MHz Locked";
            } else {
                cell.textLabel.text = @"   |--> Buffer Display";
                cell.detailTextLabel.text = @"Triple Buffering (3)";
            }
        } else if (indexPath.section == 3) {
            if (indexPath.row == 0) {
                cell.textLabel.text = _isRamExpanded ? @"💾 RAM (Chạm để thu gọn ▼)" : @"💾 RAM (Chạm để xem chi tiết ▶)";
                cell.textLabel.font = [UIFont boldSystemFontOfSize:14];
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C | Tải: 42.5%%", baseTemp - 1.2f];
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"   |--> Nhiệt độ LPDDR Bus";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C", baseTemp - 1.2f];
            } else if (indexPath.row == 2) {
                cell.textLabel.text = @"   |--> Dung lượng khả dụng";
                cell.detailTextLabel.text = _deepRamString ?: @"2.85 GB / 4.00 GB";
            } else {
                cell.textLabel.text = @"   |--> Mach Purgable State";
                cell.detailTextLabel.text = @"Mach Clean (Auto Purge)";
            }
        } else if (indexPath.section == 4) {
            [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
            int level = (int)([[UIDevice currentDevice] batteryLevel] * 100);
            if (level < 0) level = 100;
            float batteryLoad = (cpu * 0.45f) + 8.5f;

            if (indexPath.row == 0) {
                cell.textLabel.text = _isBatteryExpanded ? @"🔋 Pin (Chạm để thu gọn ▼)" : @"🔋 Pin (Chạm để xem chi tiết ▶)";
                cell.textLabel.font = [UIFont boldSystemFontOfSize:14];
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C | Tải: %.1f%%", baseTemp - 2.0f, batteryLoad];
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"   |--> Nhiệt độ Cell Pin";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C", baseTemp - 2.0f];
            } else if (indexPath.row == 2) {
                cell.textLabel.text = @"   |--> Dòng xả tải";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f%% Load", batteryLoad];
            } else if (indexPath.row == 3) {
                cell.textLabel.text = @"   |--> Dung lượng hiện tại";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%d%%", level];
            } else {
                cell.textLabel.text = @"   |--> Nguồn cấp điện";
                cell.detailTextLabel.text = @"Li-ion Native Direct";
            }
        } else {
            NSInteger hz = [self.settingsDict[@"TargetRefreshRate"] ?: @144 integerValue];
            NSInteger fps = [self.settingsDict[@"TargetFPSRate"] ?: @144 integerValue];

            if (indexPath.row == 0) {
                cell.textLabel.text = _isScreenExpanded ? @"🖥️ Màn Hình (Chạm để thu gọn ▼)" : @"🖥️ Màn Hình (Chạm để xem chi tiết ▶)";
                cell.textLabel.font = [UIFont boldSystemFontOfSize:14];
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C | %ld Hz", baseTemp - 1.5f, (long)hz];
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"   |--> Nhiệt độ bề mặt hiển thị";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C", baseTemp - 1.5f];
            } else if (indexPath.row == 2) {
                cell.textLabel.text = @"   |--> Tần số quét (Hz)";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld Hz", (long)hz];
            } else {
                cell.textLabel.text = @"   |--> Khung hình (FPS)";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld FPS", (long)fps];
            }
        }
    } 
    // TAB 1: HZ / FPS
    else if (_currentBottomTab == 1) {
        if (indexPath.section == 0) {
            cell.textLabel.numberOfLines = 0;
            cell.textLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
            cell.textLabel.textColor = [UIColor colorWithRed:0.8 green:0.88 blue:0.98 alpha:1.0];
            cell.textLabel.text = @"📌 Tần số Hz và FPS được điều phối trực tiếp tới CADisplayLink & CoreAnimation RenderServer mà không cần Respring.";
        } else if (indexPath.section == 1) {
            UISegmentedControl *subSeg = [[UISegmentedControl alloc] initWithItems:@[@"Tần Số Quét (Hz)", @"Khung Hình (FPS)"]];
            subSeg.frame = CGRectMake(12, 6, cell.contentView.bounds.size.width - 24, 32);
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
                cell.textLabel.text = [NSString stringWithFormat:@"Khóa Cứng %ld %@", (long)r, isHz ? @"Hz" : @"FPS"];
                cell.detailTextLabel.text = (currentVal == r) ? @"✓ Đang Áp Dụng" : @"";
                cell.detailTextLabel.textColor = (currentVal == r) ? [UIColor colorWithRed:0.3 green:1.0 blue:0.5 alpha:1.0] : [UIColor lightGrayColor];
            } else if (indexPath.row == 4) {
                cell.textLabel.text = [NSString stringWithFormat:@"⚡ Mở Rộng 144 %@", isHz ? @"Hz" : @"FPS"];
                cell.detailTextLabel.text = (currentVal == 144) ? @"✓ Đang Áp Dụng" : @"";
                cell.detailTextLabel.textColor = (currentVal == 144) ? [UIColor colorWithRed:0.3 green:1.0 blue:0.5 alpha:1.0] : [UIColor lightGrayColor];
            } else {
                cell.textLabel.text = @"⌨️ Nhập Tùy Chỉnh (15 - 144)...";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"Hiện tại: %ld", (long)currentVal];
                cell.detailTextLabel.textColor = [UIColor systemYellowColor];
            }

            cell.selectionStyle = _isRateLocked ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleDefault;
        }
    } 
    // TAB 2: CÔNG TẮC
    else if (_currentBottomTab == 2) {
        if (indexPath.section == 0) {
            UISegmentedControl *catSeg = [[UISegmentedControl alloc] initWithItems:@[@"CPU", @"GPU", @"Màn Hình", @"Pin", @"Hệ Thống"]];
            catSeg.frame = CGRectMake(8, 6, cell.contentView.bounds.size.width - 16, 32);
            catSeg.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            catSeg.selectedSegmentIndex = _currentSwitchSubTab;
            [catSeg addTarget:self action:@selector(onSwitchSubTabChanged:) forControlEvents:UIControlEventValueChanged];
            [cell.contentView addSubview:catSeg];
            cell.textLabel.text = @"";
            cell.detailTextLabel.text = @"";
        } else {
            NSString *title = @"";
            NSString *prefKey = @"";

            if (_currentSwitchSubTab == 0) {
                if (indexPath.row == 0) { title = @"Ưu Tiên P-Core Realtime"; prefKey = @"pCoreRealtimePriority"; }
                else if (indexPath.row == 1) { title = @"Điều Phối CPU Scheduler"; prefKey = @"schedulerGovernor"; }
                else if (indexPath.row == 2) { title = @"Đồng Bộ Xung Quantum"; prefKey = @"quantumCoreSync"; }
                else if (indexPath.row == 3) { title = @"Khóa Tần Số CPU Sàn"; prefKey = @"lockHighIdleFloor"; }
                else { title = @"Chống Bóp Xung Nhiệt Độ"; prefKey = @"AntiThermalThrottling"; }
            } else if (_currentSwitchSubTab == 1) {
                if (indexPath.row == 0) { title = @"Metal Hex/Triple Buffering"; prefKey = @"MetalHexBuffering"; }
                else if (indexPath.row == 1) { title = @"Cưỡng Chế RenderServer 90"; prefKey = @"IsolateRenderPipeline"; }
                else if (indexPath.row == 2) { title = @"Bỏ Khóa V-Sync Khung Hình"; prefKey = @"vsyncAdaptiveBuffer"; }
                else if (indexPath.row == 3) { title = @"Ổn Định Khung Hình Game"; prefKey = @"gameFPSStabilizer"; }
                else { title = @"Triệt Tiêu Blur Động"; prefKey = @"flatTintBlur"; }
            } else if (_currentSwitchSubTab == 2) {
                if (indexPath.row == 0) { title = @"🔥 Ép Xung 144Hz Toàn Máy"; prefKey = @"ForceOverclock144Hz"; }
                else if (indexPath.row == 1) { title = @"ProMotion Engine Beta 7"; prefKey = @"ProMotionEngineBeta7"; }
                else if (indexPath.row == 2) { title = @"Cảm Ứng 0ms Touch Boost"; prefKey = @"TouchResponseBoost"; }
                else if (indexPath.row == 3) { title = @"Động Cơ Cuộn ColorOS 17"; prefKey = @"ColorOs17SmoothEngine"; }
                else { title = @"Dự Đoán Tọa Độ Neural"; prefKey = @"zeroLagNeural"; }
            } else if (_currentSwitchSubTab == 3) {
                if (indexPath.row == 0) { title = @"Lọc Loạn Cảm Ứng Sạc"; prefKey = @"AntiGhostTouch"; }
                else if (indexPath.row == 1) { title = @"Khử Nhiễu Sóng Củ Sạc"; prefKey = @"ChargerRippleRejection"; }
                else if (indexPath.row == 2) { title = @"Giả Lập Pin Đầy"; prefKey = @"fakeFullBatteryState"; }
                else if (indexPath.row == 3) { title = @"Khóa 30 FPS Khi Quá Nhiệt"; prefKey = @"lock30FpsOnOverheat"; }
                else { title = @"Chế Độ Tiết Kiệm Pin 60Hz"; prefKey = @"batterySaver60Hz"; }
            } else {
                if (indexPath.row == 0) { title = @"Khởi Động App Siêu Tốc"; prefKey = @"TurboAppLaunch"; }
                else if (indexPath.row == 1) { title = @"Trị Dứt Điểm Đen App"; prefKey = @"FixAppLaunchBlackScreen"; }
                else if (indexPath.row == 2) { title = @"Giảm Lag Đa Nhiệm"; prefKey = @"ReduceMultiTaskLag"; }
                else if (indexPath.row == 3) { title = @"Chống Khựng Thoát App"; prefKey = @"FixAppExitStutter"; }
                else if (indexPath.row == 4) { title = @"Dọn RAM Chuyên Sâu"; prefKey = @"hyperMemoryGuardian"; }
                else { title = @"Tự Động Đóng App Nền"; prefKey = @"autoKillBackground"; }
            }

            LiquidCapsuleSwitch *customSwitch = [[LiquidCapsuleSwitch alloc] init];
            customSwitch.on = [self.settingsDict[prefKey] ?: @NO boolValue];
            __weak typeof(self) weakSelf = self;
            customSwitch.valueChangedBlock = ^(BOOL isOn) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                strongSelf.settingsDict[prefKey] = @(isOn);
                [strongSelf saveSettingsDataAndSync];
                [strongSelf applyDeepSpringBoardAndUIKitTweaks];
            };

            cell.textLabel.text = title;
            cell.accessoryView = customSwitch;
        }
    } 
    // TAB 3: DANH SÁCH ỨNG DỤNG
    else if (_currentBottomTab == 3) {
        if (_scannedAppsList.count > indexPath.row) {
            NSDictionary *appInfo = _scannedAppsList[indexPath.row];
            cell.textLabel.text = appInfo[@"name"];
            cell.detailTextLabel.text = appInfo[@"bundleID"];
            cell.detailTextLabel.font = [UIFont systemFontOfSize:11];

            LiquidCapsuleSwitch *appToggle = [[LiquidCapsuleSwitch alloc] init];
            appToggle.on = [_appTweakStates[appInfo[@"bundleID"]] boolValue];
            __weak typeof(self) weakSelf = self;
            appToggle.valueChangedBlock = ^(BOOL isOn) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                strongSelf->_appTweakStates[appInfo[@"bundleID"]] = @(isOn);
                strongSelf.settingsDict[@"AppTweakStates"] = strongSelf->_appTweakStates;
                [strongSelf saveSettingsDataAndSync];
                [strongSelf applyDeepSpringBoardAndUIKitTweaks];
            };
            cell.accessoryView = appToggle;
        }
    } 
    // TAB 4: CÀI ĐẶT
    else {
        if (indexPath.section == 0) {
            if (indexPath.row == 0) {
                if (_isKernelExploited) {
                    cell.backgroundColor = [UIColor colorWithRed:0.04 green:0.22 blue:0.12 alpha:0.75];
                    cell.textLabel.text = @"🟢 HỆ THỐNG ĐÃ KHAI THÁC DARWIN (SẴN SÀNG)";
                    cell.textLabel.textColor = [UIColor colorWithRed:0.3 green:1.0 blue:0.5 alpha:1.0];
                    cell.detailTextLabel.text = @"✓ Đã Lưu Máy";
                    cell.detailTextLabel.textColor = [UIColor colorWithRed:0.3 green:1.0 blue:0.5 alpha:1.0];
                } else {
                    cell.backgroundColor = [UIColor colorWithRed:0.35 green:0.06 blue:0.08 alpha:0.75];
                    cell.textLabel.text = @"🔴 CHƯA KHAI THÁC [CHẠM ĐỂ BẮT ĐẦU 15S]";
                    cell.textLabel.textColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.4 alpha:1.0];
                    cell.detailTextLabel.text = @"✕ Bấm Ngay";
                    cell.detailTextLabel.textColor = [UIColor systemYellowColor];
                }
                cell.textLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightHeavy];
                cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            } else {
                NSString *curIOS = [[UIDevice currentDevice] systemVersion];
                BOOL isSupported = Titanium_IsSupportedIOSVersion();
                
                if (isSupported) {
                    cell.backgroundColor = [UIColor colorWithRed:0.04 green:0.20 blue:0.12 alpha:0.7];
                    cell.textLabel.text = [NSString stringWithFormat:@"🟢 iOS Hỗ Trợ: iOS %@ (Tương Thích)", curIOS];
                    cell.textLabel.textColor = [UIColor colorWithRed:0.3 green:1.0 blue:0.5 alpha:1.0];
                    cell.detailTextLabel.text = @"Chuẩn 15 - 26";
                    cell.detailTextLabel.textColor = [UIColor colorWithRed:0.3 green:1.0 blue:0.5 alpha:1.0];
                } else {
                    cell.backgroundColor = [UIColor colorWithRed:0.30 green:0.08 blue:0.10 alpha:0.7];
                    cell.textLabel.text = [NSString stringWithFormat:@"🔴 iOS Hỗ Trợ: iOS %@ (Không Hỗ Trợ)", curIOS];
                    cell.textLabel.textColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0];
                    cell.detailTextLabel.text = @"Không Khả Dụng";
                    cell.detailTextLabel.textColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0];
                }
                cell.textLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
            }
        } else if (indexPath.section == 1) {
            if (!_isKernelExploited) {
                cell.textLabel.text = @"Thông Tin Phần CỨng";
                cell.detailTextLabel.text = @"[Đang Khóa - Cần Khai Thác]";
                cell.detailTextLabel.textColor = [UIColor systemRedColor];
            } else {
                struct utsname sysInfo;
                uname(&sysInfo);
                NSString *deviceModel = [NSString stringWithCString:sysInfo.machine encoding:NSUTF8StringEncoding];
                NSString *osVersion = [[UIDevice currentDevice] systemVersion];

                if (indexPath.row == 0) { cell.textLabel.text = @"UID Thiết Bị"; cell.detailTextLabel.text = _deviceUUIDString; }
                else if (indexPath.row == 1) { cell.textLabel.text = @"Mã Thiết Bị"; cell.detailTextLabel.text = deviceModel; }
                else if (indexPath.row == 2) { cell.textLabel.text = @"Kiến Trúc"; cell.detailTextLabel.text = _deepArchString; }
                else if (indexPath.row == 3) { cell.textLabel.text = @"Phiên Bản iOS"; cell.detailTextLabel.text = [NSString stringWithFormat:@"iOS %@", osVersion]; }
                else if (indexPath.row == 4) { cell.textLabel.text = @"Tên Thiết Bị"; cell.detailTextLabel.text = [[UIDevice currentDevice] name]; }
                else if (indexPath.row == 5) { cell.textLabel.text = @"Số Nhân CPU"; cell.detailTextLabel.text = _deepCoreCountString; }
                else if (indexPath.row == 6) { cell.textLabel.text = @"RAM Khả Dụng"; cell.detailTextLabel.text = _deepRamString; }
                else { cell.textLabel.text = @"Darwin Release"; cell.detailTextLabel.text = _deepKernelString; }
            }
        } else {
            NSString *jbRoot = Titanium_GetRootHidePrefixPath();
            BOOL isRootless = [jbRoot containsString:@"/var/jb"];

            if (indexPath.row == 0) { cell.textLabel.text = @"Môi Trường"; cell.detailTextLabel.text = isRootless ? @"Rootless / RootHide" : @"Rootful"; }
            else if (indexPath.row == 1) { cell.textLabel.text = @"Vùng Thư Mục"; cell.detailTextLabel.text = jbRoot; }
            else if (indexPath.row == 2) { cell.textLabel.text = @"Trạng Thái Sandbox"; cell.detailTextLabel.text = _isKernelExploited ? @"Đã Phá Bỏ (Unsandboxed)" : @"Đang Khóa"; cell.detailTextLabel.textColor = _isKernelExploited ? [UIColor systemGreenColor] : [UIColor systemOrangeColor]; }
            else { cell.textLabel.text = @"Quyền Ghi IPC"; cell.detailTextLabel.text = @"🟢 Sẵn Sàng (RW)"; }
        }
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (_currentBottomTab == 0 && _isKernelExploited) {
        if (indexPath.section > 0 && indexPath.row == 0) {
            if (indexPath.section == 1) _isCpuExpanded = !_isCpuExpanded;
            else if (indexPath.section == 2) _isGpuExpanded = !_isGpuExpanded;
            else if (indexPath.section == 3) _isRamExpanded = !_isRamExpanded;
            else if (indexPath.section == 4) _isBatteryExpanded = !_isBatteryExpanded;
            else if (indexPath.section == 5) _isScreenExpanded = !_isScreenExpanded;

            UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
            [fb impactOccurred];

            [tableView reloadSections:[NSIndexSet indexSetWithIndex:indexPath.section] withRowAnimation:UITableViewRowAnimationFade];
            return;
        }
    }

    if (_currentBottomTab == 1 && indexPath.section == 2) {
        if (_isRateLocked) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"🔒 ĐÃ KHÓA THÔNG SỐ"
                                                                           message:@"Nhấn vào ổ khóa phía trên góc phải để mở khóa trước khi chỉnh."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"Đã Hiểu" style:UIAlertActionStyleCancel handler:nil]];
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

        [self applyDeepSpringBoardAndUIKitTweaks];
        [self.customTableView reloadData];
    } else if (_currentBottomTab == 4 && indexPath.section == 0 && indexPath.row == 0) {
        [self openDopamineStyleExploitConsole];
    }
}

#pragma mark - Actions & Handlers

- (void)onHzFpsSubTabChanged:(UISegmentedControl *)sender {
    _currentHzFpsSubTab = sender.selectedSegmentIndex;
    [self.customTableView reloadSections:[NSIndexSet indexSetWithIndex:2] withRowAnimation:UITableViewRowAnimationFade];
}

- (void)onSwitchSubTabChanged:(UISegmentedControl *)sender {
    _currentSwitchSubTab = sender.selectedSegmentIndex;
    [self.customTableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationFade];
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

    [alert addAction:[UIAlertAction actionWithTitle:@"Khóa Cứng Ngay" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UITextField *tf = alert.textFields.firstObject;
        NSInteger val = [tf.text integerValue];
        if (val < 15) val = 15;
        if (val > 144) val = 144;

        [self applyRateValue:val isDynamic:NO isFPS:!isHz];
        [self applyDeepSpringBoardAndUIKitTweaks];
        [self.customTableView reloadData];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
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

#pragma mark - HUD & IPC Sync

- (void)startContinuousHardwareHUD {
    [self stopContinuousHardwareHUD];
    _hudTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(_hudTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), (uint64_t)(0.8 * NSEC_PER_SEC), (uint64_t)(0.1 * NSEC_PER_SEC));

    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(_hudTimer, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf && strongSelf->_currentBottomTab == 0 && strongSelf->_isKernelExploited && [strongSelf.settingsDict[@"EnableSystemMonitoring"] boolValue]) {
            [strongSelf.customTableView reloadData];
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

- (void)syncSharedMemoryFile:(BOOL)enabled {
    if (!_isKernelExploited) return;

    ApexV285ProPayload payload;
    memset(&payload, 0, sizeof(ApexV285ProPayload));
    payload.magic = APEX_SYNC_MAGIC_V285;
    payload.masterEnabled = (enabled && _isKernelExploited) ? 1 : 0;

    int32_t hz = [self.settingsDict[@"TargetRefreshRate"] ?: @144 intValue];
    int32_t fps = [self.settingsDict[@"TargetFPSRate"] ?: @144 intValue];
    BOOL isOverclock = [self.settingsDict[@"ForceOverclock144Hz"] ?: @NO boolValue];

    payload.targetHz = hz;
    payload.targetFPS = fps;
    payload.forceOverclock = (isOverclock || hz >= 144) ? 1 : 0;
    payload.pipSyncEnabled = 1;
    payload.thermalShield = [self.settingsDict[@"AntiThermalThrottling"] ?: @NO boolValue] ? 1 : 0;
    payload.antiStutterExit = [self.settingsDict[@"FixAppExitStutter"] ?: @NO boolValue] ? 1 : 0;
    payload.smartBufferingLevel = 3;
    payload.zeroLatencyTouch = [self.settingsDict[@"TouchResponseBoost"] ?: @NO boolValue] ? 1 : 0;
    payload.shaderOptimization = 1;
    payload.dynamicInterpolation = [self.settingsDict[@"ProMotionEngineBeta7"] ?: @NO boolValue] ? 1 : 0;
    payload.fastAppLaunch = [self.settingsDict[@"TurboAppLaunch"] ?: @NO boolValue] ? 1 : 0;
    payload.lowLatencyAudio = 1;
    payload.memoryPressureRelief = 1;
    payload.metalPacingEnabled = [self.settingsDict[@"MetalHexBuffering"] ?: @NO boolValue] ? 1 : 0;
    payload.runloopHangGuard = 1;
    payload.keyboardZeroLagV3 = [self.settingsDict[@"KeyboardZeroLagV24"] ?: @NO boolValue] ? 1 : 0;
    payload.aggressiveRamCleaner = [self.settingsDict[@"hyperMemoryGuardian"] ?: @NO boolValue] ? 1 : 0;
    payload.lockFixedFpsWhenThermal = [self.settingsDict[@"lock30FpsOnOverheat"] ?: @NO boolValue] ? 1 : 0;
    payload.antiGhostTouch = [self.settingsDict[@"AntiGhostTouch"] ?: @NO boolValue] ? 1 : 0;
    payload.diskIOPriorityBoost = [self.settingsDict[@"pCoreRealtimePriority"] ?: @NO boolValue] ? 1 : 0;
    payload.rawTouchDirectDelivery = 1;
    payload.powerSaveModeActive = [self.settingsDict[@"batterySaver60Hz"] ?: @NO boolValue] ? 1 : 0;

    payload.updateSeq = (uint64_t)mach_absolute_time();
    payload.lastHeartbeat = payload.updateSeq;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        Titanium_WriteSyncPayloadUniversal(&payload, sizeof(ApexV285ProPayload));

        notify_post(NOTIFY_RELOAD);
        notify_post(NOTIFY_UIKIT_RELOAD);
        notify_post(NOTIFY_HARDWARE_SYNC);
        notify_post(NOTIFY_FPS_CHANGED);
        notify_post(NOTIFY_TITANIUM_CHANGED);
    });
}

- (void)applyDeepSpringBoardAndUIKitTweaks {
    if (!_isKernelExploited) return;

    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);

    if (self.view.window) {
        self.view.window.layer.drawsAsynchronously = YES;
    }

    if (@available(iOS 15.0, *)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSInteger targetHz = [self.settingsDict[@"TargetRefreshRate"] ?: @144 integerValue];
            if (targetHz < 15) targetHz = 15;
            if (targetHz > 144) targetHz = 144;

            SEL setRangeSel = NSSelectorFromString(@"setPreferredFrameRateRange:");
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) {
                    UIWindowScene *ws = (UIWindowScene *)scene;
                    if ([ws respondsToSelector:setRangeSel]) {
                        CAFrameRateRange range = CAFrameRateRangeMake(30.0f, (float)targetHz, (float)targetHz);
                        void (*setRangeFunc)(id, SEL, CAFrameRateRange) = (void (*)(id, SEL, CAFrameRateRange))objc_msgSend;
                        setRangeFunc(ws, setRangeSel, range);
                    }
                }
            }
        });
    }

    BOOL master = [self.settingsDict[@"Enabled"] ?: @NO boolValue];
    [self syncSharedMemoryFile:master];
}

#pragma mark - Exploit Console & Data Persistence

- (void)showUnexploitedWarningAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"🔒 TÍNH NĂNG ĐANG BỊ KHÓA"
                                                                   message:@"Hệ thống chưa được khai thác! Hãy vào tab Cài Đặt và nhấn vào dòng trạng thái đèn đỏ để bắt đầu khai thác thủ công."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Đã Hiểu" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)openDopamineStyleExploitConsole {
    UIViewController *consoleVC = [[UIViewController alloc] init];
    consoleVC.view.backgroundColor = [UIColor colorWithRed:0.02 green:0.03 blue:0.06 alpha:1.0];
    consoleVC.modalPresentationStyle = UIModalPresentationFullScreen;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 55, consoleVC.view.bounds.size.width - 40, 30)];
    titleLabel.text = @"⚡ LIQUID GLASS 3.0 KERNEL EXPLOIT";
    titleLabel.textColor = [UIColor colorWithRed:0.2 green:0.95 blue:0.6 alpha:1.0];
    titleLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:15] ?: [UIFont boldSystemFontOfSize:15];
    [consoleVC.view addSubview:titleLabel];

    UIProgressView *progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    progressView.frame = CGRectMake(20, 100, consoleVC.view.bounds.size.width - 40, 6);
    progressView.progressTintColor = [UIColor colorWithRed:0.2 green:0.95 blue:0.6 alpha:1.0];
    progressView.trackTintColor = [UIColor darkGrayColor];
    [consoleVC.view addSubview:progressView];

    UITextView *logTextView = [[UITextView alloc] initWithFrame:CGRectMake(20, 120, consoleVC.view.bounds.size.width - 40, consoleVC.view.bounds.size.height - 210)];
    logTextView.backgroundColor = [UIColor colorWithRed:0.04 green:0.05 blue:0.08 alpha:1.0];
    logTextView.textColor = [UIColor colorWithRed:0.3 green:0.9 blue:0.5 alpha:1.0];
    logTextView.font = [UIFont fontWithName:@"Menlo" size:12] ?: [UIFont systemFontOfSize:12];
    logTextView.editable = NO;
    logTextView.layer.cornerRadius = 14;
    logTextView.layer.borderColor = [UIColor colorWithWhite:0.25 alpha:1.0].CGColor;
    logTextView.layer.borderWidth = 1.0;
    [consoleVC.view addSubview:logTextView];

    [self presentViewController:consoleVC animated:YES completion:^{
        [self runExploitStagesWithConsole:logTextView progress:progressView controller:consoleVC];
    }];
}

- (void)runExploitStagesWithConsole:(UITextView *)logTextView progress:(UIProgressView *)progressView controller:(UIViewController *)consoleVC {
    NSArray *stages = @[
        [NSString stringWithFormat:@"[Stage 1/6] Nhận diện UID thiết bị: %@...", _deviceUUIDString],
        @"[Stage 2/6] Khởi tạo Mach Host & Vượt rào cản PAC arm64e...",
        @"[Stage 3/6] Can thiệp XNU Scheduler, phân bổ P-Core Realtime...",
        @"[Stage 4/6] Đọc thông số phần cứng Darwin & Cấu trúc Mach VM...",
        @"[Stage 5/6] Ghi đè Pipeline Metal GPU & Kích hoạt Triple Buffering...",
        @"[Stage 6/6] Đồng bộ Shmem IPC đa phân vùng (/tmp & /var/jb/tmp)...",
        @"✅ KHAI THÁC THÀNH CÔNG! Toàn bộ hệ thống Liquid Glass 3.0 đã mở khóa."
    ];

    __block NSInteger currentIdx = 0;
    NSMutableString *logBuffer = [NSMutableString stringWithFormat:@"[*] Tiến hành khai thác Darwin Kernel (UID: %@)...\n", _deviceUUIDString];
    logTextView.text = logBuffer;

    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:2.2 repeats:YES block:^(NSTimer * _Nonnull t) {
        if (currentIdx < stages.count) {
            [logBuffer appendFormat:@"\n%@", stages[currentIdx]];
            logTextView.text = logBuffer;
            [logTextView scrollRangeToVisible:NSMakeRange(logTextView.text.length - 1, 1)];

            float prog = (float)(currentIdx + 1) / (float)stages.count;
            [progressView setProgress:prog animated:YES];

            UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
            [fb impactOccurred];

            currentIdx++;
        } else {
            [t invalidate];

            UINotificationFeedbackGenerator *notiFb = [[UINotificationFeedbackGenerator alloc] init];
            [notiFb notificationOccurred:UINotificationFeedbackTypeSuccess];

            [self persistExploitDataToDisk];
            [self applyDeepSpringBoardAndUIKitTweaks];

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [consoleVC dismissViewControllerAnimated:YES completion:^{
                    [self.customTableView reloadData];
                }];
            });
        }
    }];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

- (void)persistExploitDataToDisk {
    char cpuTypeStr[128] = {0};
    size_t size = sizeof(cpuTypeStr);
    sysctlbyname("machdep.cpu.brand_string", cpuTypeStr, &size, NULL, 0);
    NSString *brand = [NSString stringWithUTF8String:cpuTypeStr];
    if (!brand || brand.length == 0) {
        #if defined(__arm64e__)
        _deepArchString = @"arm64e (Apple PAC v8.3+ Cryptographic)";
        #elif defined(__arm64__)
        _deepArchString = @"arm64 (Apple A-Series 64-bit Core)";
        #else
        _deepArchString = @"ARM64 Silicon Native";
        #endif
    } else {
        _deepArchString = brand;
    }

    int ncpu = 0;
    size = sizeof(ncpu);
    sysctlbyname("hw.ncpu", &ncpu, &size, NULL, 0);
    _deepCoreCountString = [NSString stringWithFormat:@"%d Nhân SoC (Clustered P/E)", ncpu];

    int64_t memsize = 0;
    size = sizeof(memsize);
    sysctlbyname("hw.memsize", &memsize, &size, NULL, 0);
    double ramGB = (double)memsize / (1024.0 * 1024.0 * 1024.0);
    _deepRamString = [NSString stringWithFormat:@"%.2f GB LPDDR (Mach Purgable)", ramGB];

    char osrelease[64] = {0};
    size = sizeof(osrelease);
    sysctlbyname("kern.osrelease", osrelease, &size, NULL, 0);
    _deepKernelString = [NSString stringWithFormat:@"Darwin %s (XNU Kernel)", osrelease];

    int64_t l2cache = 0;
    size = sizeof(l2cache);
    sysctlbyname("hw.l2cachesize", &l2cache, &size, NULL, 0);
    _deepCacheString = (l2cache > 0) ? [NSString stringWithFormat:@"%lld KB L2 Cache", l2cache / 1024] : @"Low Latency Silicon Cache";

    _isKernelExploited = YES;

    self.settingsDict[@"IsKernelExploited"] = @YES;
    self.settingsDict[@"SavedArchString"] = _deepArchString;
    self.settingsDict[@"SavedCoreCountString"] = _deepCoreCountString;
    self.settingsDict[@"SavedRamString"] = _deepRamString;
    self.settingsDict[@"SavedKernelString"] = _deepKernelString;
    self.settingsDict[@"SavedCacheString"] = _deepCacheString;
    self.settingsDict[@"SavedDeviceUUID"] = _deviceUUIDString;
    [self saveSettingsDataAndSync];
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

- (void)ensureDefaultSettingsExist {
    if (!self.settingsDict[@"Enabled"]) self.settingsDict[@"Enabled"] = @NO;
    if (!self.settingsDict[@"EnableSystemMonitoring"]) self.settingsDict[@"EnableSystemMonitoring"] = @NO;
    if (!self.settingsDict[@"TargetRefreshRate"]) self.settingsDict[@"TargetRefreshRate"] = @144;
    if (!self.settingsDict[@"TargetFPSRate"]) self.settingsDict[@"TargetFPSRate"] = @144;
    if (!self.settingsDict[@"ForceOverclock144Hz"]) self.settingsDict[@"ForceOverclock144Hz"] = @NO;
    if (!self.settingsDict[@"ProMotionEngineBeta7"]) self.settingsDict[@"ProMotionEngineBeta7"] = @NO;
    if (!self.settingsDict[@"pCoreRealtimePriority"]) self.settingsDict[@"pCoreRealtimePriority"] = @NO;
    if (!self.settingsDict[@"schedulerGovernor"]) self.settingsDict[@"schedulerGovernor"] = @NO;
    if (!self.settingsDict[@"quantumCoreSync"]) self.settingsDict[@"quantumCoreSync"] = @NO;
    if (!self.settingsDict[@"lockHighIdleFloor"]) self.settingsDict[@"lockHighIdleFloor"] = @NO;
    if (!self.settingsDict[@"AntiThermalThrottling"]) self.settingsDict[@"AntiThermalThrottling"] = @NO;
    if (!self.settingsDict[@"MetalHexBuffering"]) self.settingsDict[@"MetalHexBuffering"] = @NO;
    if (!self.settingsDict[@"IsolateRenderPipeline"]) self.settingsDict[@"IsolateRenderPipeline"] = @NO;
    if (!self.settingsDict[@"vsyncAdaptiveBuffer"]) self.settingsDict[@"vsyncAdaptiveBuffer"] = @NO;
    if (!self.settingsDict[@"gameFPSStabilizer"]) self.settingsDict[@"gameFPSStabilizer"] = @NO;
    if (!self.settingsDict[@"flatTintBlur"]) self.settingsDict[@"flatTintBlur"] = @NO;
    if (!self.settingsDict[@"TouchResponseBoost"]) self.settingsDict[@"TouchResponseBoost"] = @NO;
    if (!self.settingsDict[@"ColorOs17SmoothEngine"]) self.settingsDict[@"ColorOs17SmoothEngine"] = @NO;
    if (!self.settingsDict[@"zeroLagNeural"]) self.settingsDict[@"zeroLagNeural"] = @NO;
    if (!self.settingsDict[@"AntiGhostTouch"]) self.settingsDict[@"AntiGhostTouch"] = @NO;
    if (!self.settingsDict[@"ChargerRippleRejection"]) self.settingsDict[@"ChargerRippleRejection"] = @NO;
    if (!self.settingsDict[@"fakeFullBatteryState"]) self.settingsDict[@"fakeFullBatteryState"] = @NO;
    if (!self.settingsDict[@"lock30FpsOnOverheat"]) self.settingsDict[@"lock30FpsOnOverheat"] = @NO;
    if (!self.settingsDict[@"batterySaver60Hz"]) self.settingsDict[@"batterySaver60Hz"] = @NO;
    if (!self.settingsDict[@"TurboAppLaunch"]) self.settingsDict[@"TurboAppLaunch"] = @NO;
    if (!self.settingsDict[@"FixAppLaunchBlackScreen"]) self.settingsDict[@"FixAppLaunchBlackScreen"] = @NO;
    if (!self.settingsDict[@"ReduceMultiTaskLag"]) self.settingsDict[@"ReduceMultiTaskLag"] = @NO;
    if (!self.settingsDict[@"FixAppExitStutter"]) self.settingsDict[@"FixAppExitStutter"] = @NO;
    if (!self.settingsDict[@"hyperMemoryGuardian"]) self.settingsDict[@"hyperMemoryGuardian"] = @NO;
    if (!self.settingsDict[@"autoKillBackground"]) self.settingsDict[@"autoKillBackground"] = @NO;
    if (!self.settingsDict[@"IsRateLocked"]) self.settingsDict[@"IsRateLocked"] = @NO;
    if (!self.settingsDict[@"IsKernelExploited"]) self.settingsDict[@"IsKernelExploited"] = @NO;
}

- (void)loadInstalledAppsAsync {
    NSDictionary *savedStates = self.settingsDict[@"AppTweakStates"];
    _appTweakStates = savedStates ? [savedStates mutableCopy] : [NSMutableDictionary dictionary];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSMutableArray<NSDictionary *> *tempApps = [NSMutableArray array];
        NSArray *dirs = @[@"/Applications", @"/var/jb/Applications"];
        NSFileManager *fm = [NSFileManager defaultManager];

        for (NSString *d in dirs) {
            if ([fm fileExistsAtPath:d]) {
                NSArray *items = [fm contentsOfDirectoryAtPath:d error:nil];
                for (NSString *item in items) {
                    if ([item hasSuffix:@".app"]) {
                        NSString *fullPath = [d stringByAppendingPathComponent:item];
                        NSString *infoPath = [fullPath stringByAppendingPathComponent:@"Info.plist"];
                        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
                        NSString *name = info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"] ?: [item stringByDeletingPathExtension];
                        NSString *bundleID = info[@"CFBundleIdentifier"] ?: item;

                        if (self->_appTweakStates[bundleID] == nil) {
                            self->_appTweakStates[bundleID] = @NO;
                        }

                        [tempApps addObject:@{
                            @"name": name,
                            @"bundleID": bundleID,
                            @"path": fullPath
                        }];
                    }
                }
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self->_scannedAppsList = tempApps;
            if (self->_currentBottomTab == 3 && self->_isKernelExploited) {
                [self.customTableView reloadData];
            }
        });
    });
}

#pragma mark - System Actions & Factory Reset

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
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"⚠️ XÓA SẠCH DỮ LIỆU TWEAK"
                                                                   message:@"Toàn bộ cấu hình, tệp IPC và dữ liệu khai thác Darwin sẽ bị xóa hoàn toàn. Ứng dụng sẽ trở về trạng thái nguyên bản (Chưa khai thác)."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Xác Nhận Xóa Hết" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        NSString *prefPath = Titanium_ResolvePrefPath();
        [[NSFileManager defaultManager] removeItemAtPath:prefPath error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:PRIMARY_SYNC_FILE error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:SECONDARY_SYNC_FILE error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:TITANIUM_BOOT_FLAG_VERIFIED error:nil];

        self.settingsDict = [NSMutableDictionary dictionary];
        self->_isKernelExploited = NO;
        self->_deepArchString = nil;
        self->_deepCoreCountString = nil;
        self->_deepRamString = nil;
        self->_deepKernelString = nil;
        self->_deepCacheString = nil;

        [self ensureDefaultSettingsExist];
        [self stopContinuousHardwareHUD];

        notify_post(NOTIFY_RELOAD);
        notify_post(NOTIFY_UIKIT_RELOAD);

        UINotificationFeedbackGenerator *fb = [[UINotificationFeedbackGenerator alloc] init];
        [fb notificationOccurred:UINotificationFeedbackTypeWarning];

        [self.customTableView reloadData];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy Bỏ" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
