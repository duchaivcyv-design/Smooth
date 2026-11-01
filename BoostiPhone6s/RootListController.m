#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <mach/mach.h>
#import <mach/mach_host.h>
#import <sys/sysctl.h>
#import <sys/stat.h>
#import <spawn.h>

#define PREF_PATH @"/var/mobile/Library/Preferences/com.smoothios.pro.plist"
#define SYNC_PIPE @"/tmp/.boost_hz_sync"

#pragma pack(push, 1)
typedef struct {
    uint32_t magic;           // 0x534D4F53 "SMOS"
    uint16_t version;         // 0x0285
    uint16_t targetHz;        // 15 - 240
    uint16_t targetFPS;       // 15 - 240
    uint64_t switchMask;      // Bitmask cho 34 flags
    uint32_t thermalBudget;   // Thermal throttle override
    uint32_t renderStride;    // Pipeline stride sync
    uint8_t  activeProfile;   // 0: Eco, 1: Dynamic, 2: CyberMax
    uint8_t  reserved[7];     // Padding alignment
} ApexV285ProPayloadRLCV285;
#pragma pack(pop)

@interface RootListController : UIViewController <UITextFieldDelegate>
@end

@interface RootListController () {
    // State & Payload
    ApexV285ProPayloadRLCV285 _payload;
    NSMutableDictionary *_preferences;
    NSArray *_switchKeys;
    NSInteger _activeTab; // 0: DASH, 1: HZ/FPS, 2: SWITCHES, 3: APPS, 4: SETTINGS

    // UI Root Container
    UIView *_mainDashboardContainer;
    
    // Top Bar
    UILabel *_lblClock;
    UILabel *_lblNodeStatus;
    UIView *_navTabBar;
    NSMutableArray<UIButton *> *_tabButtons;

    // Left Column: System Monitor
    UIView *_leftColView;
    CAShapeLayer *_cpuWaveLayer;
    UIBezierPath *_cpuPath;
    CGFloat _cpuHistory[30];
    UILabel *_lblCpuVal;
    UILabel *_lblRamVal;
    UILabel *_lblThermalVal;
    UIProgressView *_ramProgress;

    // Center Console: Main Workspace
    UIView *_centerColView;
    UILabel *_lblConsoleHeader;
    UIScrollView *_consoleContentScroll;
    UILabel *_lblHzIndicator;
    UISlider *_hzSlider;
    UILabel *_lblFpsIndicator;
    UISlider *_fpsSlider;
    UITextView *_terminalLogView;

    // Right Column: Radar & Network
    UIView *_rightColView;
    UIView *_globeContainer;
    CAShapeLayer *_globeWireframeLayer;
    CGFloat _globeAngle;
    UILabel *_lblNetLatency;
    UILabel *_lblServerSync;

    // Bottom Area: Cyber Virtual Keyboard & Dock
    UIView *_bottomAreaView;
    UIView *_cyberDock;
    UIView *_cyberKeyboard;
    
    // Boot Sequence
    UIView *_bootOverlay;
    UITextView *_bootLogTextView;
    UIView *_bootLogoBox;
    UILabel *_bootLogoText;
    UILabel *_bootPromptLabel;

    // Loop Timers
    CADisplayLink *_displayLink;
    NSTimer *_fastMetricsTimer;
    UIImpactFeedbackGenerator *_hapticGen;
}
@end

@implementation RootListController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.02 green:0.03 blue:0.05 alpha:1.0];
    
    _hapticGen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [_hapticGen prepare];

    [self initializeSwitchRegistry];
    [self loadSettingsPayload];
    [self constructDashboardLayout];
    [self executeSciFiBootSequence];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    [self startTelemetryLoops];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:NO];
    [self stopTelemetryLoops];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

#pragma mark - Data & IPC Engine

- (void)initializeSwitchRegistry {
    _switchKeys = @[
        @"enableAppleInternalProMotion", @"enableZeroLatencyTouch", @"enableForce120HzGlobal",
        @"disableThermalThrottling",   @"bypassSpringBoardFPSCap", @"enableMetalDirectCompute",
        @"forceMaxGPUClockSpeed",      @"turboBoostIOThreadPriority",@"reduceTouchFrameInterval",
        @"disableDisplayEnergyPreserve",@"forceContinuousRendering", @"enableVBlankImmediate",
        @"disableCoreAnimationJankCheck",@"forceMaxLayerCaching",  @"unlockAllDisplayRefreshRates",
        @"enableLowLatencyCAQueue",    @"disableBlurLayerDecay",   @"boostCoreMotionPollingRate",
        @"enableDirectToDisplayMetal", @"disableDynamicResolution",@"enableDeepSystemPurge",
        @"aggressiveMallocTrim",       @"forceAllCoresHighPerf",   @"disableUIKitThrottleOnDim",
        @"overrideAppSpecificRefresh", @"enableHapticInstantAudio",@"disableCompositorFences",
        @"enableAdaptiveThermalBias",  @"boostBacklightDrivePwm", @"allowVariableRefreshUnderVolt",
        @"disableWindowServerFlushHold",@"enableKernelTaskPagingFix",@"forceRenderDuringScroll",
        @"bypassSystemLowPowerState"
    ];
}

- (void)loadSettingsPayload {
    _preferences = [NSMutableDictionary dictionaryWithContentsOfFile:PREF_PATH] ?: [NSMutableDictionary dictionary];
    
    memset(&_payload, 0, sizeof(ApexV285ProPayloadRLCV285));
    _payload.magic = 0x534D4F53;
    _payload.version = 0x0285;
    
    NSNumber *hz = _preferences[@"targetHz"] ?: @(120);
    NSNumber *fps = _preferences[@"targetFPS"] ?: @(120);
    NSNumber *profile = _preferences[@"activeProfile"] ?: @(1);
    
    _payload.targetHz = [hz unsignedShortValue];
    _payload.targetFPS = [fps unsignedShortValue];
    _payload.activeProfile = [profile unsignedCharValue];
    _payload.switchMask = 0;
    
    for (NSUInteger i = 0; i < _switchKeys.count; i++) {
        NSString *key = _switchKeys[i];
        BOOL state = _preferences[key] ? [_preferences[key] boolValue] : YES;
        if (state) {
            _payload.switchMask |= (1ULL << i);
        }
    }
}

- (void)persistAndSynchronizePayload {
    _preferences[@"targetHz"] = @(_payload.targetHz);
    _preferences[@"targetFPS"] = @(_payload.targetFPS);
    _preferences[@"activeProfile"] = @(_payload.activeProfile);
    
    for (NSUInteger i = 0; i < _switchKeys.count; i++) {
        NSString *key = _switchKeys[i];
        BOOL state = (_payload.switchMask & (1ULL << i)) != 0;
        _preferences[key] = @(state);
    }
    
    [_preferences writeToFile:PREF_PATH atomically:YES];
    
    // Ghi binary sync IPC payload trực tiếp vào dynamic node
    FILE *fp = fopen([SYNC_PIPE UTF8String], "wb");
    if (fp) {
        fwrite(&_payload, sizeof(ApexV285ProPayloadRLCV285), 1, fp);
        fflush(fp);
        fclose(fp);
    }
    
    [self appendTerminalLog:[NSString stringWithFormat:@"[SYNC] Payload flushed. Mask: 0x%llX | HZ: %u | FPS: %u",
                             _payload.switchMask, _payload.targetHz, _payload.targetFPS]];
}

#pragma mark - Sci-Fi Boot Sequence

- (void)executeSciFiBootSequence {
    _bootOverlay = [[UIView alloc] initWithFrame:self.view.bounds];
    _bootOverlay.backgroundColor = [UIColor colorWithRed:0.01 green:0.01 blue:0.02 alpha:1.0];
    [self.view addSubview:_bootOverlay];

    _bootLogTextView = [[UITextView alloc] initWithFrame:CGRectMake(20, 40, self.view.bounds.size.width - 40, self.view.bounds.size.height * 0.45)];
    _bootLogTextView.backgroundColor = [UIColor clearColor];
    _bootLogTextView.textColor = [UIColor colorWithRed:0.2 green:0.8 blue:1.0 alpha:0.9];
    _bootLogTextView.font = [UIFont fontWithName:@"Courier-Bold" size:10.0] ?: [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
    _bootLogTextView.userInteractionEnabled = NO;
    [_bootOverlay addSubview:_bootLogTextView];

    // Khung biểu tượng phát sáng logo SMOOTHIOS PRO
    _bootLogoBox = [[UIView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width/2 - 140, self.view.bounds.size.height * 0.52, 280, 70)];
    _bootLogoBox.layer.borderColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.8 alpha:0.9].CGColor;
    _bootLogoBox.layer.borderWidth = 1.5;
    _bootLogoBox.layer.cornerRadius = 3.0;
    _bootLogoBox.layer.shadowColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.8 alpha:1.0].CGColor;
    _bootLogoBox.layer.shadowRadius = 14.0;
    _bootLogoBox.layer.shadowOpacity = 0.9;
    _bootLogoBox.layer.shadowOffset = CGSizeZero;
    _bootLogoBox.alpha = 0.0;
    [_bootOverlay addSubview:_bootLogoBox];

    _bootLogoText = [[UILabel alloc] initWithFrame:_bootLogoBox.bounds];
    _bootLogoText.text = @"SMOOTHIOS PRO";
    _bootLogoText.textAlignment = NSTextAlignmentCenter;
    _bootLogoText.font = [UIFont fontWithName:@"HelveticaNeue-CondensedBlack" size:26.0] ?: [UIFont boldSystemFontOfSize:26];
    _bootLogoText.textColor = [UIColor whiteColor];
    [_bootLogoBox addSubview:_bootLogoText];

    _bootPromptLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, CGRectGetMaxY(_bootLogoBox.frame) + 25, self.view.bounds.size.width - 40, 24)];
    _bootPromptLabel.textAlignment = NSTextAlignmentCenter;
    _bootPromptLabel.textColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.6 alpha:1.0];
    _bootPromptLabel.font = [UIFont fontWithName:@"Courier" size:14.0] ?: [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightBold];
    _bootPromptLabel.text = @"";
    [_bootOverlay addSubview:_bootPromptLabel];

    NSArray<NSString *> *bootLogs = @[
        @"INITIATING HYPERVISOR PROBE [DARWIN-XNU HYBRID KERNEL]...",
        @"PROBING VIRTUAL BUS: APEX V285 HARDWARE ACCELERATOR DETECTED.",
        @"CHECKING SYSTEM RAM SEGMENTS: 0x00000000 TO 0xFFFFFFFF [OK]",
        @"MOUNTING RAW FRAMEBUFFER DEV: /dev/fb0 ON /sys/display [OK]",
        @"BYPASSING COREANIMATION DISPLAY LINK CADENCE CONSTRAINTS...",
        @"PATCHING IOKIT PROMOTION INTERRUPTS -> ZERO LATENCY HOOKS READY.",
        @"INTERPOLATING LOW-LEVEL TOUCH RESAMPLE THREAD: AFFINITY ASSIGNED.",
        @"ALLOCATING IPC SHM PIPE: /tmp/.boost_hz_sync INITIALIZED.",
        @"AUTHENTICATING OPERATOR CLEARANCE LEVEL 0..."
    ];

    __block NSUInteger step = 0;
    NSTimer *logTimer = [NSTimer scheduledTimerWithTimeInterval:0.18 repeats:YES block:^(NSTimer * _Nonnull timer) {
        if (step < bootLogs.count) {
            self->_bootLogTextView.text = [self->_bootLogTextView.text stringByAppendingFormat:@"%@\n", bootLogs[step]];
            [self->_bootLogTextView scrollRangeToVisible:NSMakeRange(self->_bootLogTextView.text.length, 0)];
            AudioServicesPlaySystemSound(1104);
            step++;
        } else {
            [timer invalidate];
            // Hiển thị logo rực sáng
            [UIView animateWithDuration:0.4 animations:^{
                self->_bootLogoBox.alpha = 1.0;
            } completion:^(BOOL finished) {
                AudioServicesPlaySystemSound(1057);
                // Gõ chữ prompt Welcome
                NSString *welcomeMsg = @">> Welcome back, Operator <<";
                __block NSInteger charIdx = 0;
                [NSTimer scheduledTimerWithTimeInterval:0.035 repeats:YES block:^(NSTimer * _Nonnull promptTimer) {
                    if (charIdx <= welcomeMsg.length) {
                        self->_bootPromptLabel.text = [welcomeMsg substringToIndex:charIdx];
                        charIdx++;
                    } else {
                        [promptTimer invalidate];
                        // Mở bung ra giao diện dashboard
                        [self triggerExpandDashboardAnimation];
                    }
                }];
            }];
        }
    }];
    [logTimer fire];
}

- (void)triggerExpandDashboardAnimation {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.75 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0.4 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self->_bootOverlay.transform = CGAffineTransformMakeScale(1.15, 1.15);
            self->_bootOverlay.alpha = 0.0;
            self->_mainDashboardContainer.alpha = 1.0;
            self->_mainDashboardContainer.transform = CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
            [self->_bootOverlay removeFromSuperview];
            self->_bootOverlay = nil;
            [self appendTerminalLog:@"[KERNEL] eDEX-UI Sci-Fi Workspace mounted. All threads active."];
        }];
    });
}

#pragma mark - Dashboard UI Layout Construction

- (void)constructDashboardLayout {
    CGRect screen = [UIScreen mainScreen].bounds;
    
    _mainDashboardContainer = [[UIView alloc] initWithFrame:screen];
    _mainDashboardContainer.backgroundColor = [UIColor colorWithRed:0.03 green:0.04 blue:0.06 alpha:1.0];
    _mainDashboardContainer.alpha = 0.0;
    _mainDashboardContainer.transform = CGAffineTransformMakeScale(0.92, 0.92);
    [self.view addSubview:_mainDashboardContainer];

    CGFloat topBarH = 65.0;
    CGFloat bottomAreaH = 150.0;
    CGFloat midH = screen.size.height - topBarH - bottomAreaH;
    
    [self buildTopBar:CGRectMake(0, 0, screen.size.width, topBarH)];

    CGFloat leftW = screen.size.width * 0.28;
    CGFloat rightW = screen.size.width * 0.28;
    CGFloat centerW = screen.size.width - leftW - rightW;

    [self buildLeftColumn:CGRectMake(0, topBarH, leftW, midH)];
    [self buildCenterConsole:CGRectMake(leftW, topBarH, centerW, midH)];
    [self buildRightColumn:CGRectMake(leftW + centerW, topBarH, rightW, midH)];
    [self buildBottomArea:CGRectMake(0, topBarH + midH, screen.size.width, bottomAreaH)];
}

- (void)buildTopBar:(CGRect)frame {
    UIView *bar = [[UIView alloc] initWithFrame:frame];
    bar.backgroundColor = [UIColor colorWithRed:0.05 green:0.07 blue:0.10 alpha:0.95];
    bar.layer.borderWidth = 0.5;
    bar.layer.borderColor = [UIColor colorWithRed:0.0 green:0.7 blue:0.85 alpha:0.4].CGColor;
    [_mainDashboardContainer addSubview:bar];

    _lblClock = [[UILabel alloc] initWithFrame:CGRectMake(12, 10, 160, 20)];
    _lblClock.textColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.85 alpha:1.0];
    _lblClock.font = [UIFont fontWithName:@"Courier-Bold" size:12] ?: [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightBold];
    _lblClock.text = @"TIME: 00:00:00.000";
    [bar addSubview:_lblClock];

    _lblNodeStatus = [[UILabel alloc] initWithFrame:CGRectMake(12, 30, 200, 16)];
    _lblNodeStatus.textColor = [UIColor colorWithRed:0.4 green:0.6 blue:0.7 alpha:0.8];
    _lblNodeStatus.font = [UIFont fontWithName:@"Courier" size:9] ?: [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightRegular];
    _lblNodeStatus.text = @"NODE: APEX-V285 // SECURE KERNEL";
    [bar addSubview:_lblNodeStatus];

    // Navigation Tabs Wireframe
    NSArray *tabs = @[@"DASHBOARD", @"HZ/FPS", @"SWITCHES", @"APPS", @"SETTINGS"];
    _tabButtons = [NSMutableArray array];
    CGFloat btnW = (frame.size.width - 200) / tabs.count;
    
    _navTabBar = [[UIView alloc] initWithFrame:CGRectMake(190, 8, frame.size.width - 200, 48)];
    [bar addSubview:_navTabBar];

    for (NSUInteger i = 0; i < tabs.count; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(i * btnW, 4, btnW - 4, 38);
        btn.tag = i;
        btn.backgroundColor = (i == 0) ? [UIColor colorWithRed:0.0 green:0.6 blue:0.8 alpha:0.3] : [UIColor clearColor];
        btn.layer.borderWidth = 1.0;
        btn.layer.borderColor = [UIColor colorWithRed:0.0 green:0.75 blue:0.9 alpha:(i == 0 ? 0.9 : 0.3)].CGColor;
        btn.layer.cornerRadius = 2.0;
        [btn setTitle:tabs[i] forState:UIControlStateNormal];
        [btn setTitleColor:(i == 0 ? [UIColor whiteColor] : [UIColor colorWithRed:0.3 green:0.6 blue:0.7 alpha:0.8]) forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:11] ?: [UIFont boldSystemFontOfSize:11];
        [btn addTarget:self action:@selector(tabButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        [_navTabBar addSubview:btn];
        [_tabButtons addObject:btn];
    }
}

- (void)buildLeftColumn:(CGRect)frame {
    _leftColView = [[UIView alloc] initWithFrame:frame];
    _leftColView.layer.borderColor = [UIColor colorWithRed:0.0 green:0.5 blue:0.7 alpha:0.25].CGColor;
    _leftColView.layer.borderWidth = 0.5;
    [_mainDashboardContainer addSubview:_leftColView];

    UILabel *header = [[UILabel alloc] initWithFrame:CGRectMake(8, 6, frame.size.width - 16, 16)];
    header.text = @"// SYSTEM TELEMETRY";
    header.textColor = [UIColor colorWithRed:0.0 green:0.85 blue:0.9 alpha:0.9];
    header.font = [UIFont fontWithName:@"Courier-Bold" size:10] ?: [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightBold];
    [_leftColView addSubview:header];

    // Realtime CPU Graph Wave
    UIView *graphBox = [[UIView alloc] initWithFrame:CGRectMake(8, 28, frame.size.width - 16, 75)];
    graphBox.backgroundColor = [UIColor colorWithRed:0.01 green:0.02 blue:0.04 alpha:0.8];
    graphBox.layer.borderColor = [UIColor colorWithRed:0.0 green:0.6 blue:0.8 alpha:0.4].CGColor;
    graphBox.layer.borderWidth = 0.5;
    [_leftColView addSubview:graphBox];

    _cpuWaveLayer = [CAShapeLayer layer];
    _cpuWaveLayer.strokeColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.7 alpha:0.9].CGColor;
    _cpuWaveLayer.fillColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.7 alpha:0.12].CGColor;
    _cpuWaveLayer.lineWidth = 1.2;
    [graphBox.layer addSublayer:_cpuWaveLayer];

    _lblCpuVal = [[UILabel alloc] initWithFrame:CGRectMake(10, 108, frame.size.width - 20, 16)];
    _lblCpuVal.font = [UIFont fontWithName:@"Courier" size:9] ?: [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightRegular];
    _lblCpuVal.textColor = [UIColor colorWithRed:0.0 green:0.85 blue:1.0 alpha:0.8];
    _lblCpuVal.text = @"CPU: 0.0% [LOAD_AVG]";
    [_leftColView addSubview:_lblCpuVal];

    _lblRamVal = [[UILabel alloc] initWithFrame:CGRectMake(10, 126, frame.size.width - 20, 16)];
    _lblRamVal.font = [UIFont fontWithName:@"Courier" size:9] ?: [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightRegular];
    _lblRamVal.textColor = [UIColor colorWithRed:0.0 green:0.85 blue:1.0 alpha:0.8];
    _lblRamVal.text = @"RAM USAGE: 0 MB";
    [_leftColView addSubview:_lblRamVal];

    _ramProgress = [[UIProgressView alloc] initWithFrame:CGRectMake(10, 146, frame.size.width - 20, 3)];
    _ramProgress.progressTintColor = [UIColor colorWithRed:0.0 green:0.9 blue:0.6 alpha:1.0];
    _ramProgress.trackTintColor = [UIColor colorWithRed:0.1 green:0.15 blue:0.2 alpha:1.0];
    [_leftColView addSubview:_ramProgress];

    _lblThermalVal = [[UILabel alloc] initWithFrame:CGRectMake(10, 156, frame.size.width - 20, 16)];
    _lblThermalVal.font = [UIFont fontWithName:@"Courier" size:9] ?: [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightRegular];
    _lblThermalVal.textColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.5 alpha:0.9];
    _lblThermalVal.text = @"THERMAL: NOMINAL (0)";
    [_leftColView addSubview:_lblThermalVal];
}

- (void)buildCenterConsole:(CGRect)frame {
    _centerColView = [[UIView alloc] initWithFrame:frame];
    _centerColView.layer.borderColor = [UIColor colorWithRed:0.0 green:0.7 blue:0.9 alpha:0.35].CGColor;
    _centerColView.layer.borderWidth = 0.5;
    [_mainDashboardContainer addSubview:_centerColView];

    _lblConsoleHeader = [[UILabel alloc] initWithFrame:CGRectMake(12, 6, frame.size.width - 24, 18)];
    _lblConsoleHeader.textColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.85 alpha:1.0];
    _lblConsoleHeader.font = [UIFont fontWithName:@"Courier-Bold" size:11] ?: [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightBold];
    _lblConsoleHeader.text = @"> MAIN_CONSOLE // CONTROLLER_HUB";
    [_centerColView addSubview:_lblConsoleHeader];

    _consoleContentScroll = [[UIScrollView alloc] initWithFrame:CGRectMake(6, 28, frame.size.width - 12, frame.size.height * 0.55)];
    _consoleContentScroll.backgroundColor = [UIColor colorWithRed:0.01 green:0.02 blue:0.04 alpha:0.5];
    _consoleContentScroll.layer.borderColor = [UIColor colorWithRed:0.0 green:0.5 blue:0.7 alpha:0.2].CGColor;
    _consoleContentScroll.layer.borderWidth = 0.5;
    [_centerColView addSubview:_consoleContentScroll];

    [self reloadConsoleTabModules];

    // Terminal log output ở nửa dưới center
    CGFloat termY = CGRectGetMaxY(_consoleContentScroll.frame) + 6;
    CGFloat termH = frame.size.height - termY - 8;
    _terminalLogView = [[UITextView alloc] initWithFrame:CGRectMake(6, termY, frame.size.width - 12, termH)];
    _terminalLogView.backgroundColor = [UIColor colorWithRed:0.01 green:0.015 blue:0.025 alpha:0.9];
    _terminalLogView.textColor = [UIColor colorWithRed:0.2 green:0.85 blue:0.6 alpha:0.9];
    _terminalLogView.font = [UIFont fontWithName:@"Courier" size:9] ?: [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightRegular];
    _terminalLogView.editable = NO;
    _terminalLogView.layer.borderColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.7 alpha:0.3].CGColor;
    _terminalLogView.layer.borderWidth = 0.5;
    [_centerColView addSubview:_terminalLogView];
}

- (void)reloadConsoleTabModules {
    [[_consoleContentScroll subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    CGFloat w = _consoleContentScroll.frame.size.width;

    if (_activeTab == 0 || _activeTab == 1) { // DASHBOARD / HZ & FPS
        // Hz Controls
        _lblHzIndicator = [[UILabel alloc] initWithFrame:CGRectMake(10, 8, w - 20, 16)];
        _lblHzIndicator.textColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.85 alpha:1.0];
        _lblHzIndicator.font = [UIFont fontWithName:@"Courier-Bold" size:10] ?: [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightBold];
        _lblHzIndicator.text = [NSString stringWithFormat:@"TARGET REFRESH RATE: %u HZ", _payload.targetHz];
        [_consoleContentScroll addSubview:_lblHzIndicator];

        _hzSlider = [[UISlider alloc] initWithFrame:CGRectMake(10, 28, w - 20, 24)];
        _hzSlider.minimumValue = 15;
        _hzSlider.maximumValue = 240;
        _hzSlider.value = _payload.targetHz;
        _hzSlider.minimumTrackTintColor = [UIColor colorWithRed:0.0 green:0.85 blue:0.95 alpha:1.0];
        [_hzSlider addTarget:self action:@selector(hzSliderChanged:) forControlEvents:UIControlEventValueChanged];
        [_consoleContentScroll addSubview:_hzSlider];

        // FPS Controls
        _lblFpsIndicator = [[UILabel alloc] initWithFrame:CGRectMake(10, 58, w - 20, 16)];
        _lblFpsIndicator.textColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.85 alpha:1.0];
        _lblFpsIndicator.font = [UIFont fontWithName:@"Courier-Bold" size:10] ?: [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightBold];
        _lblFpsIndicator.text = [NSString stringWithFormat:@"TARGET RENDER FPS: %u FPS", _payload.targetFPS];
        [_consoleContentScroll addSubview:_lblFpsIndicator];

        _fpsSlider = [[UISlider alloc] initWithFrame:CGRectMake(10, 78, w - 20, 24)];
        _fpsSlider.minimumValue = 15;
        _fpsSlider.maximumValue = 240;
        _fpsSlider.value = _payload.targetFPS;
        _fpsSlider.minimumTrackTintColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.55 alpha:1.0];
        [_fpsSlider addTarget:self action:@selector(fpsSliderChanged:) forControlEvents:UIControlEventValueChanged];
        [_consoleContentScroll addSubview:_fpsSlider];

        // Preset Profiles
        NSArray *profiles = @[@"ECO (60Hz)", @"DYNAMIC (120Hz)", @"CYBERMAX (240Hz)"];
        CGFloat pBtnW = (w - 28) / 3;
        for (NSUInteger i = 0; i < profiles.count; i++) {
            UIButton *pBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            pBtn.frame = CGRectMake(10 + i * (pBtnW + 4), 110, pBtnW, 26);
            pBtn.layer.borderColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.9 alpha:0.5].CGColor;
            pBtn.layer.borderWidth = 1.0;
            pBtn.tag = 100 + i;
            [pBtn setTitle:profiles[i] forState:UIControlStateNormal];
            [pBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            pBtn.titleLabel.font = [UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:9] ?: [UIFont boldSystemFontOfSize:9];
            [pBtn addTarget:self action:@selector(profileBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
            [_consoleContentScroll addSubview:pBtn];
        }
        _consoleContentScroll.contentSize = CGSizeMake(w, 145);
        
    } else if (_activeTab == 2) { // 34 SWITCHES
        CGFloat curY = 6;
        for (NSUInteger i = 0; i < _switchKeys.count; i++) {
            NSString *key = _switchKeys[i];
            BOOL state = (_payload.switchMask & (1ULL << i)) != 0;

            UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(10, curY, w - 80, 22)];
            title.textColor = [UIColor colorWithRed:0.6 green:0.8 blue:0.9 alpha:1.0];
            title.font = [UIFont fontWithName:@"Courier" size:9] ?: [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightRegular];
            title.text = [NSString stringWithFormat:@"[%02lu] %@", (unsigned long)i, key];
            [_consoleContentScroll addSubview:title];

            UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(w - 65, curY - 2, 50, 20)];
            sw.transform = CGAffineTransformMakeScale(0.65, 0.65);
            sw.on = state;
            sw.onTintColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.9 alpha:1.0];
            sw.tag = 200 + i;
            [sw addTarget:self action:@selector(switchActionChanged:) forControlEvents:UIControlEventValueChanged];
            [_consoleContentScroll addSubview:sw];

            curY += 26;
        }
        _consoleContentScroll.contentSize = CGSizeMake(w, curY + 10);
        
    } else { // APPS / SETTINGS
        UILabel *info = [[UILabel alloc] initWithFrame:CGRectMake(10, 30, w - 20, 40)];
        info.textAlignment = NSTextAlignmentCenter;
        info.textColor = [UIColor colorWithRed:0.0 green:0.85 blue:0.95 alpha:0.8];
        info.font = [UIFont fontWithName:@"Courier-Bold" size:11] ?: [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightBold];
        info.text = (_activeTab == 3) ? @"[HOOKED APPS SCANNER READY]\nALL APPLICATION HOOKS ENFORCED" : @"[PREFERENCES REGISTRY ROOT]\nSYSTEM SANDBOX UNRESTRICTED";
        info.numberOfLines = 2;
        [_consoleContentScroll addSubview:info];
        _consoleContentScroll.contentSize = CGSizeMake(w, 100);
    }
}

- (void)buildRightColumn:(CGRect)frame {
    _rightColView = [[UIView alloc] initWithFrame:frame];
    _rightColView.layer.borderColor = [UIColor colorWithRed:0.0 green:0.5 blue:0.7 alpha:0.25].CGColor;
    _rightColView.layer.borderWidth = 0.5;
    [_mainDashboardContainer addSubview:_rightColView];

    UILabel *header = [[UILabel alloc] initWithFrame:CGRectMake(8, 6, frame.size.width - 16, 16)];
    header.text = @"// NET_RADAR & GLOBE";
    header.textColor = [UIColor colorWithRed:0.0 green:0.85 blue:0.9 alpha:0.9];
    header.font = [UIFont fontWithName:@"Courier-Bold" size:10] ?: [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightBold];
    [_rightColView addSubview:header];

    // Wireframe Radar Globe Box
    CGFloat globeSize = frame.size.width - 24;
    _globeContainer = [[UIView alloc] initWithFrame:CGRectMake(12, 28, globeSize, globeSize)];
    _globeContainer.backgroundColor = [UIColor colorWithRed:0.01 green:0.02 blue:0.04 alpha:0.8];
    _globeContainer.layer.borderColor = [UIColor colorWithRed:0.0 green:0.7 blue:0.9 alpha:0.4].CGColor;
    _globeContainer.layer.borderWidth = 0.5;
    [_rightColView addSubview:_globeContainer];

    _globeWireframeLayer = [CAShapeLayer layer];
    _globeWireframeLayer.strokeColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.7 alpha:0.75].CGColor;
    _globeWireframeLayer.fillColor = [UIColor clearColor].CGColor;
    _globeWireframeLayer.lineWidth = 1.0;
    [_globeContainer.layer addSublayer:_globeWireframeLayer];

    CGFloat infoY = CGRectGetMaxY(_globeContainer.frame) + 12;
    _lblNetLatency = [[UILabel alloc] initWithFrame:CGRectMake(10, infoY, frame.size.width - 20, 16)];
    _lblNetLatency.font = [UIFont fontWithName:@"Courier" size:9] ?: [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightRegular];
    _lblNetLatency.textColor = [UIColor colorWithRed:0.0 green:0.85 blue:1.0 alpha:0.8];
    _lblNetLatency.text = @"PING: 12ms // SHM DIRECT";
    [_rightColView addSubview:_lblNetLatency];

    _lblServerSync = [[UILabel alloc] initWithFrame:CGRectMake(10, infoY + 18, frame.size.width - 20, 16)];
    _lblServerSync.font = [UIFont fontWithName:@"Courier" size:9] ?: [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightRegular];
    _lblServerSync.textColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.5 alpha:0.9];
    _lblServerSync.text = @"SYNC_PIPE: CONNECTED";
    [_rightColView addSubview:_lblServerSync];
}

- (void)buildBottomArea:(CGRect)frame {
    _bottomAreaView = [[UIView alloc] initWithFrame:frame];
    _bottomAreaView.backgroundColor = [UIColor colorWithRed:0.02 green:0.03 blue:0.04 alpha:0.95];
    _bottomAreaView.layer.borderColor = [UIColor colorWithRed:0.0 green:0.7 blue:0.85 alpha:0.3].CGColor;
    _bottomAreaView.layer.borderWidth = 0.5;
    [_mainDashboardContainer addSubview:_bottomAreaView];

    // Sci-Fi Cyber Dock Icons
    CGFloat dockH = 40.0;
    _cyberDock = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, dockH)];
    _cyberDock.backgroundColor = [UIColor colorWithRed:0.03 green:0.05 blue:0.08 alpha:0.9];
    [_bottomAreaView addSubview:_cyberDock];

    NSArray *dockActions = @[@"[FILES]", @"[HOOK_APPS]", @"[SETTINGS]", @"[CLEAR_LOG]", @"[RESPRING]"];
    CGFloat dBtnW = frame.size.width / dockActions.count;
    for (NSUInteger i = 0; i < dockActions.count; i++) {
        UIButton *dBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        dBtn.frame = CGRectMake(i * dBtnW + 2, 4, dBtnW - 4, dockH - 8);
        dBtn.layer.borderColor = [UIColor colorWithRed:0.0 green:0.7 blue:0.9 alpha:0.35].CGColor;
        dBtn.layer.borderWidth = 1.0;
        dBtn.tag = 300 + i;
        [dBtn setTitle:dockActions[i] forState:UIControlStateNormal];
        [dBtn setTitleColor:[UIColor colorWithRed:0.0 green:0.95 blue:0.8 alpha:1.0] forState:UIControlStateNormal];
        dBtn.titleLabel.font = [UIFont fontWithName:@"Courier-Bold" size:10] ?: [UIFont boldSystemFontOfSize:10];
        [dBtn addTarget:self action:@selector(dockButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
        [_cyberDock addSubview:dBtn];
    }

    // Cyber Virtual Terminal Keyboard
    CGFloat kbH = frame.size.height - dockH;
    _cyberKeyboard = [[UIView alloc] initWithFrame:CGRectMake(0, dockH, frame.size.width, kbH)];
    [_bottomAreaView addSubview:_cyberKeyboard];

    NSArray<NSArray<NSString *> *> *rows = @[
        @[@"Q", @"W", @"E", @"R", @"T", @"Y", @"U", @"I", @"O", @"P"],
        @[@"A", @"S", @"D", @"F", @"G", @"H", @"J", @"K", @"L"],
        @[@"SYNC", @"Z", @"X", @"C", @"V", @"B", @"N", @"M", @"EXEC"]
    ];

    CGFloat rowH = (kbH - 12) / 3;
    for (NSUInteger r = 0; r < rows.count; r++) {
        NSArray<NSString *> *keys = rows[r];
        CGFloat kw = (frame.size.width - (keys.count + 1) * 3) / keys.count;
        for (NSUInteger c = 0; c < keys.count; c++) {
            UIButton *kBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            kBtn.frame = CGRectMake(3 + c * (kw + 3), 4 + r * rowH, kw, rowH - 4);
            kBtn.backgroundColor = [UIColor colorWithRed:0.04 green:0.06 blue:0.09 alpha:0.8];
            kBtn.layer.borderColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.95 alpha:0.25].CGColor;
            kBtn.layer.borderWidth = 0.5;
            kBtn.layer.cornerRadius = 2.0;
            [kBtn setTitle:keys[c] forState:UIControlStateNormal];
            [kBtn setTitleColor:[UIColor colorWithRed:0.4 green:0.8 blue:0.9 alpha:0.9] forState:UIControlStateNormal];
            kBtn.titleLabel.font = [UIFont fontWithName:@"Courier-Bold" size:9] ?: [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightBold];
            
            [kBtn addTarget:self action:@selector(keyboardKeyPressed:) forControlEvents:UIControlEventTouchUpInside];
            [kBtn addTarget:self action:@selector(keyboardKeyTouchDown:) forControlEvents:UIControlEventTouchDown];
            [_cyberKeyboard addSubview:kBtn];
        }
    }
}

#pragma mark - Loops & Telemetry

- (void)startTelemetryLoops {
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(stepDisplayTick:)];
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];

    _fastMetricsTimer = [NSTimer scheduledTimerWithTimeInterval:0.4 target:self selector:@selector(refreshSystemTelemetry) userInfo:nil repeats:YES];
}

- (void)stopTelemetryLoops {
    [_displayLink invalidate];
    _displayLink = nil;
    [_fastMetricsTimer invalidate];
    _fastMetricsTimer = nil;
}

- (void)stepDisplayTick:(CADisplayLink *)link {
    // Cập nhật đồng hồ thời gian thực
    NSDate *now = [NSDate date];
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"HH:mm:ss.SS";
    _lblClock.text = [NSString stringWithFormat:@"TIME: %@", [df stringFromDate:now]];

    // Xoay Radar Globe ASCII Wireframe
    _globeAngle += 0.03;
    [self renderGlobeWireframe:_globeAngle];
}

- (void)renderGlobeWireframe:(CGFloat)angle {
    CGFloat radius = (_globeContainer.bounds.size.width - 10) / 2.0;
    CGPoint center = CGPointMake(_globeContainer.bounds.size.width / 2.0, _globeContainer.bounds.size.height / 2.0);
    
    UIBezierPath *path = [UIBezierPath bezierPath];
    // Vẽ vành ngoài
    [path addArcWithCenter:center radius:radius startAngle:0 endAngle:M_PI * 2 clockwise:YES];

    // Vẽ các vĩ độ và kinh độ xoay theo trục Y
    for (int i = -2; i <= 2; i++) {
        CGFloat yOff = (radius / 3.0) * i;
        CGFloat subR = sqrt(MAX(0.0, radius * radius - yOff * yOff));
        [path moveToPoint:CGPointMake(center.x - subR, center.y + yOff)];
        [path addLineToPoint:CGPointMake(center.x + subR, center.y + yOff)];
    }

    for (int j = 0; j < 3; j++) {
        CGFloat curA = angle + (M_PI / 3.0) * j;
        CGFloat xSemi = radius * cos(curA);
        [path moveToPoint:CGPointMake(center.x, center.y - radius)];
        [path addCurveToPoint:CGPointMake(center.x, center.y + radius)
                controlPoint1:CGPointMake(center.x + xSemi, center.y - radius * 0.5)
                controlPoint2:CGPointMake(center.x + xSemi, center.y + radius * 0.5)];
    }
    _globeWireframeLayer.path = path.CGPath;
}

- (void)refreshSystemTelemetry {
    // Đọc CPU Load
    host_cpu_load_info_data_t cpuinfo;
    mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;
    CGFloat cpuUsage = 0.0;
    if (host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, (host_info_t)&cpuinfo, &count) == KERN_SUCCESS) {
        unsigned long total = cpuinfo.cpu_ticks[CPU_STATE_USER] + cpuinfo.cpu_ticks[CPU_STATE_SYSTEM] + cpuinfo.cpu_ticks[CPU_STATE_IDLE];
        if (total > 0) {
            cpuUsage = ((CGFloat)(cpuinfo.cpu_ticks[CPU_STATE_USER] + cpuinfo.cpu_ticks[CPU_STATE_SYSTEM]) / total) * 100.0;
        }
    }
    _lblCpuVal.text = [NSString stringWithFormat:@"CPU: %0.1f%% [SYS_LOAD]", cpuUsage];

    // Cập nhật mảng sóng thời gian thực
    for (int i = 0; i < 29; i++) {
        _cpuHistory[i] = _cpuHistory[i + 1];
    }
    _cpuHistory[29] = cpuUsage / 100.0;

    CGFloat w = _cpuWaveLayer.superlayer.bounds.size.width;
    CGFloat h = _cpuWaveLayer.superlayer.bounds.size.height;
    CGFloat stepX = w / 29.0;

    UIBezierPath *wave = [UIBezierPath bezierPath];
    [wave moveToPoint:CGPointMake(0, h)];
    for (int i = 0; i < 30; i++) {
        CGFloat curH = h - (_cpuHistory[i] * h);
        [wave addLineToPoint:CGPointMake(i * stepX, curH)];
    }
    [wave addLineToPoint:CGPointMake(w, h)];
    [wave closePath];
    _cpuWaveLayer.path = wave.CGPath;

    // Đọc RAM
    struct mach_task_basic_info info;
    mach_msg_type_number_t size = MACH_TASK_BASIC_INFO_COUNT;
    if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &size) == KERN_SUCCESS) {
        CGFloat memMb = (CGFloat)info.resident_size / (1024.0 * 1024.0);
        _lblRamVal.text = [NSString stringWithFormat:@"TASK RAM: %.1f MB", memMb];
        _ramProgress.progress = MIN(1.0, memMb / 512.0);
    }
}

#pragma mark - Actions & User Interactions

- (void)tabButtonPressed:(UIButton *)sender {
    [_hapticGen impactOccurred];
    _activeTab = sender.tag;
    for (NSUInteger i = 0; i < _tabButtons.count; i++) {
        UIButton *b = _tabButtons[i];
        BOOL active = (i == _activeTab);
        b.backgroundColor = active ? [UIColor colorWithRed:0.0 green:0.6 blue:0.8 alpha:0.3] : [UIColor clearColor];
        b.layer.borderColor = [UIColor colorWithRed:0.0 green:0.75 blue:0.9 alpha:(active ? 0.9 : 0.3)].CGColor;
        [b setTitleColor:(active ? [UIColor whiteColor] : [UIColor colorWithRed:0.3 green:0.6 blue:0.7 alpha:0.8]) forState:UIControlStateNormal];
    }
    [self reloadConsoleTabModules];
    [self appendTerminalLog:[NSString stringWithFormat:@"[NAV] Switched view partition -> %ld", (long)_activeTab]];
}

- (void)hzSliderChanged:(UISlider *)slider {
    uint16_t val = (uint16_t)slider.value;
    _payload.targetHz = val;
    _lblHzIndicator.text = [NSString stringWithFormat:@"TARGET REFRESH RATE: %u HZ", val];
    [self persistAndSynchronizePayload];
}

- (void)fpsSliderChanged:(UISlider *)slider {
    uint16_t val = (uint16_t)slider.value;
    _payload.targetFPS = val;
    _lblFpsIndicator.text = [NSString stringWithFormat:@"TARGET RENDER FPS: %u FPS", val];
    [self persistAndSynchronizePayload];
}

- (void)profileBtnClicked:(UIButton *)sender {
    [_hapticGen impactOccurred];
    NSUInteger p = sender.tag - 100;
    _payload.activeProfile = (uint8_t)p;
    if (p == 0) {
        _payload.targetHz = 60;
        _payload.targetFPS = 60;
    } else if (p == 1) {
        _payload.targetHz = 120;
        _payload.targetFPS = 120;
    } else {
        _payload.targetHz = 240;
        _payload.targetFPS = 240;
    }
    _hzSlider.value = _payload.targetHz;
    _fpsSlider.value = _payload.targetFPS;
    _lblHzIndicator.text = [NSString stringWithFormat:@"TARGET REFRESH RATE: %u HZ", _payload.targetHz];
    _lblFpsIndicator.text = [NSString stringWithFormat:@"TARGET RENDER FPS: %u FPS", _payload.targetFPS];
    [self persistAndSynchronizePayload];
    [self appendTerminalLog:[NSString stringWithFormat:@"[PROFILE] Applied profile %lu. Sync triggered.", (unsigned long)p]];
}

- (void)switchActionChanged:(UISwitch *)sw {
    [_hapticGen impactOccurred];
    NSUInteger idx = sw.tag - 200;
    if (sw.isOn) {
        _payload.switchMask |= (1ULL << idx);
    } else {
        _payload.switchMask &= ~(1ULL << idx);
    }
    [self persistAndSynchronizePayload];
    [self appendTerminalLog:[NSString stringWithFormat:@"[TOGGLE] Flag '%@' -> %@", _switchKeys[idx], sw.isOn ? @"ENABLED" : @"DISABLED"]];
}

- (void)dockButtonClicked:(UIButton *)sender {
    [_hapticGen impactOccurred];
    NSUInteger action = sender.tag - 300;
    switch (action) {
        case 0: // FILES
            [self appendTerminalLog:@"[VFS] Node /var/mobile/Library mounted in RW mode."];
            break;
        case 1: // APPS
            _activeTab = 3;
            [self tabButtonPressed:_tabButtons[3]];
            break;
        case 2: // SETTINGS
            _activeTab = 4;
            [self tabButtonPressed:_tabButtons[4]];
            break;
        case 3: // CLEAR LOG
            _terminalLogView.text = @"";
            [self appendTerminalLog:@"[TERMINAL] Screen buffer purged."];
            break;
        case 4: // RESPRING
            [self executeSciFiRespring];
            break;
    }
}

- (void)keyboardKeyTouchDown:(UIButton *)sender {
    // Hiệu ứng phím sáng rực glow khi nhấn
    sender.backgroundColor = [UIColor colorWithRed:0.0 green:0.85 blue:1.0 alpha:0.4];
    sender.layer.borderColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.9 alpha:1.0].CGColor;
    sender.layer.shadowColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.8 alpha:1.0].CGColor;
    sender.layer.shadowRadius = 8.0;
    sender.layer.shadowOpacity = 0.9;
    AudioServicesPlaySystemSound(1104);
}

- (void)keyboardKeyPressed:(UIButton *)sender {
    [UIView animateWithDuration:0.2 animations:^{
        sender.backgroundColor = [UIColor colorWithRed:0.04 green:0.06 blue:0.09 alpha:0.8];
        sender.layer.borderColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.95 alpha:0.25].CGColor;
        sender.layer.shadowOpacity = 0.0;
    }];
    
    NSString *title = [sender titleForState:UIControlStateNormal];
    if ([title isEqualToString:@"SYNC"]) {
        [self persistAndSynchronizePayload];
    } else if ([title isEqualToString:@"EXEC"]) {
        [self appendTerminalLog:@"[EXEC] Pipeline flushed. Command executed successfully."];
    } else {
        [self appendTerminalLog:[NSString stringWithFormat:@"[KEY] Key '%@' pushed to stdin.", title]];
    }
}

- (void)appendTerminalLog:(NSString *)log {
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"HH:mm:ss";
    NSString *entry = [NSString stringWithFormat:@"[%@] %@\n", [df stringFromDate:[NSDate date]], log];
    _terminalLogView.text = [_terminalLogView.text stringByAppendingString:entry];
    [_terminalLogView scrollRangeToVisible:NSMakeRange(_terminalLogView.text.length, 0)];
}

- (void)executeSciFiRespring {
    [self appendTerminalLog:@"[HALT] BROADCASTING TERMINATION SIGNAL TO SPRINGBOARD..."];
    AudioServicesPlaySystemSound(1057);
    
    UIView *blackFlash = [[UIView alloc] initWithFrame:self.view.bounds];
    blackFlash.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:blackFlash];
    
    [UIView animateWithDuration:0.3 animations:^{
        blackFlash.backgroundColor = [UIColor blackColor];
    } completion:^(BOOL finished) {
        pid_t pid;
        const char *args[] = {"killall", "-9", "SpringBoard", NULL};
        posix_spawn(&pid, "/usr/bin/killall", NULL, NULL, (char *const *)args, NULL);
    }];
}

@end 
