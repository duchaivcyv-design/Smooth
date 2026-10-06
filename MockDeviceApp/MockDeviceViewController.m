#import "MockDeviceViewController.h"
#import <mach/mach.h>

@interface MockDeviceViewController () <UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource, UITextViewDelegate>
@property (nonatomic, strong) UIView *homeScreenView;
@property (nonatomic, strong) UIView *sileoAppView;
@property (nonatomic, strong) UIView *filesAppView;
@property (nonatomic, strong) UIView *lockScreenView;
@property (nonatomic, strong) UIView *blackCurtainRespring;
@property (nonatomic, strong) UITableView *sileoTableView;

// Trạng thái mô phỏng
@property (nonatomic, assign) BOOL isTweakInstalled;
@property (nonatomic, assign) BOOL isRespringDone;
@property (nonatomic, assign) BOOL isRealCrashSafeMode;

// Trình soạn thảo code trực tiếp trong App
@property (nonatomic, strong) UITextView *codeEditorView;

@property (nonatomic, strong) CADisplayLink *fpsDisplayLink;
@property (nonatomic, strong) UILabel *fpsCounterLabel;
@property (nonatomic, assign) CFTimeInterval lastTimestamp;
@property (nonatomic, assign) NSInteger frameCount;
@end

@implementation MockDeviceViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.1 alpha:1.0];
    
    self.isTweakInstalled = NO;
    self.isRespringDone = NO;
    self.isRealCrashSafeMode = NO; // Mặc định code sạch

    [self setupHomeScreen];
    [self setupFPSMonitoring];
}

- (void)setupFPSMonitoring {
    self.fpsCounterLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - 110, 43, 90, 20)];
    self.fpsCounterLabel.textColor = [UIColor greenColor];
    self.fpsCounterLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightBold];
    self.fpsCounterLabel.textAlignment = NSTextAlignmentRight;
    [self.view addSubview:self.fpsCounterLabel];

    self.fpsDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(onFrameUpdate:)];
    [self.fpsDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)onFrameUpdate:(CADisplayLink *)link {
    if (self.lastTimestamp == 0) {
        self.lastTimestamp = link.timestamp;
        return;
    }
    self.frameCount++;
    CFTimeInterval delta = link.timestamp - self.lastTimestamp;
    if (delta >= 1.0) {
        double fps = round((double)self.frameCount / delta);
        self.fpsCounterLabel.text = [NSString stringWithFormat:@"%.0f FPS", fps];
        self.frameCount = 0;
        self.lastTimestamp = link.timestamp;
    }
}

// 1. MÀN HÌNH CHÍNH
- (void)setupHomeScreen {
    self.homeScreenView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.homeScreenView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.homeScreenView];

    UILabel *statusBar = [[UILabel alloc] initWithFrame:CGRectMake(20, 45, self.view.bounds.size.width - 40, 20)];
    statusBar.text = @"09:41                        5G 🔋 100%";
    statusBar.textColor = [UIColor whiteColor];
    statusBar.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    [self.homeScreenView addSubview:statusBar];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 80, self.view.bounds.size.width - 40, 30)];
    title.text = @"iOS Virtual Lab & Code Inspector";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:16];
    title.textAlignment = NSTextAlignmentCenter;
    [self.homeScreenView addSubview:title];

    NSArray *apps = @[
        @{@"name": @"Sileo", @"color": [UIColor colorWithRed:0.15 green:0.55 blue:0.85 alpha:1.0], @"selector": [NSValue valueWithPointer:@selector(openSileoApp)]},
        @{@"name": @"Tweak Test", @"color": [UIColor colorWithRed:0.2 green:0.7 blue:0.3 alpha:1.0], @"selector": [NSValue valueWithPointer:@selector(openTweakTestApp)]},
        @{@"name": @"Respring", @"color": [UIColor colorWithRed:0.9 green:0.3 blue:0.2 alpha:1.0], @"selector": [NSValue valueWithPointer:@selector(simulateRealRespring)]},
        @{@"name": @"Files / Code", @"color": [UIColor colorWithRed:0.95 green:0.6 blue:0.1 alpha:1.0], @"selector": [NSValue valueWithPointer:@selector(openFilesApp)]}
    ];

    CGFloat size = 72;
    CGFloat startX = 40;
    CGFloat startY = 140;
    CGFloat spacingX = 35;
    CGFloat spacingY = 40;

    for (int i = 0; i < apps.count; i++) {
        NSDictionary *app = apps[i];
        int r = i / 2;
        int c = i % 2;
        CGFloat x = startX + c * (size + spacingX + 30);
        CGFloat y = startY + r * (size + spacingY + 20);

        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(x, y, size, size);
        btn.backgroundColor = app[@"color"];
        btn.layer.cornerRadius = 18;
        btn.layer.shadowColor = [UIColor blackColor].CGColor;
        btn.layer.shadowOpacity = 0.5;
        btn.layer.shadowOffset = CGSizeMake(0, 4);
        
        SEL actionSel = (SEL)[app[@"selector"] pointerValue];
        [btn addTarget:self action:actionSel forControlEvents:UIControlEventTouchUpInside];

        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(-10, size + 5, size + 20, 16)];
        lbl.text = app[@"name"];
        lbl.textColor = [UIColor whiteColor];
        lbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        lbl.textAlignment = NSTextAlignmentCenter;
        [btn addSubview:lbl];

        [self.homeScreenView addSubview:btn];
    }
}

// 2. KHO SILEO
- (void)openSileoApp {
    self.sileoAppView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.sileoAppView.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.08 alpha:1.0];
    [self.view addSubview:self.sileoAppView];

    UILabel *header = [[UILabel alloc] initWithFrame:CGRectMake(20, 60, self.view.bounds.size.width - 40, 40)];
    header.text = @"📦 Sileo Package Manager";
    header.textColor = [UIColor whiteColor];
    header.font = [UIFont boldSystemFontOfSize:20];
    [self.sileoAppView addSubview:header];

    UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    backBtn.frame = CGRectMake(self.view.bounds.size.width - 80, 65, 60, 30);
    [backBtn setTitle:@"Đóng" forState:UIControlStateNormal];
    [backBtn addTarget:self action:@selector(closeSileoApp) forControlEvents:UIControlEventTouchUpInside];
    [self.sileoAppView addSubview:backBtn];

    self.sileoTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 120, self.view.bounds.size.width, self.view.bounds.size.height - 120) style:UITableViewStyleInsetGrouped];
    self.sileoTableView.backgroundColor = [UIColor clearColor];
    self.sileoTableView.delegate = self;
    self.sileoTableView.dataSource = self;
    [self.sileoAppView addSubview:self.sileoTableView];
}

- (void)closeSileoApp {
    [UIView animateWithDuration:0.25 animations:^{
        self.sileoAppView.alpha = 0;
    } completion:^(BOOL finished) {
        [self.sileoAppView removeFromSuperview];
        self.sileoAppView = nil;
    }];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 1; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"Cell"];
    }
    cell.backgroundColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.2 alpha:1.0];
    cell.textLabel.text = @"BoostiPhone6s Core (Rootless Tweak)";
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.detailTextLabel.text = self.isTweakInstalled ? @"Đã cài đặt ✅" : @"Phiên bản: 28.7 Pro (Chạm để cài)";
    cell.detailTextLabel.textColor = self.isTweakInstalled ? [UIColor greenColor] : [UIColor orangeColor];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    UIAlertController *installAlert = [UIAlertController alertControllerWithTitle:@"Cài Đặt Gói Tweak" 
                                                                           message:@"Xác nhận nạp BoostiPhone6sCore.dylib vào hệ thống?" 
                                                                    preferredStyle:UIAlertControllerStyleAlert];
    [installAlert addAction:[UIAlertAction actionWithTitle:@"Cài Đặt Ngay" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        self.isTweakInstalled = YES;
        self.isRespringDone = NO;
        [self.sileoTableView reloadData];
        [self showToastNotice:@"📥 Đã cài .deb! Bấm Respring để kiểm tra xung đột."];
        [self closeSileoApp];
    }]];
    [installAlert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:installAlert animated:YES completion:nil];
}

// 3. MỤC FILES & TRÌNH SOẠN THẢO CODE TRỰC TIẾP
- (void)openFilesApp {
    self.filesAppView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.filesAppView.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.12 alpha:1.0];
    [self.view addSubview:self.filesAppView];

    UILabel *header = [[UILabel alloc] initWithFrame:CGRectMake(20, 60, self.view.bounds.size.width - 40, 30)];
    header.text = @"📁 Quản Lý File Tweak.xm";
    header.textColor = [UIColor whiteColor];
    header.font = [UIFont boldSystemFontOfSize:18];
    [self.filesAppView addSubview:header];

    UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    backBtn.frame = CGRectMake(self.view.bounds.size.width - 80, 60, 60, 30);
    [backBtn setTitle:@"Đóng" forState:UIControlStateNormal];
    [backBtn addTarget:self action:@selector(closeFilesApp) forControlEvents:UIControlEventTouchUpInside];
    [self.filesAppView addSubview:backBtn];

    self.codeEditorView = [[UITextView alloc] initWithFrame:CGRectMake(20, 110, self.view.bounds.size.width - 40, self.view.bounds.size.height - 240)];
    self.codeEditorView.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.18 alpha:1.0];
    self.codeEditorView.textColor = [UIColor colorWithRed:0.2 green:0.9 blue:0.4 alpha:1.0];
    self.codeEditorView.font = [UIFont fontWithName:@"Courier" size:13];
    self.codeEditorView.layer.cornerRadius = 10;
    self.codeEditorView.text = @"#import <UIKit/UIKit.h>\n\n%hook SpringBoard\n- (void)applicationDidFinishLaunching:(id)application {\n    %orig;\n    NSLog(@\"[Safe] Loaded successfully!\");\n}\n%end\n\n%hook UIWindow\n- (void)makeKeyAndVisible {\n    %orig;\n}\n%end";
    [self.filesAppView addSubview:self.codeEditorView];

    UIButton *checkCodeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    checkCodeBtn.frame = CGRectMake(20, self.view.bounds.size.height - 115, self.view.bounds.size.width - 40, 44);
    [checkCodeBtn setTitle:@"Kiểm Tra Lỗi Code (Check SafeMode Risk)" forState:UIControlStateNormal];
    [checkCodeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    checkCodeBtn.backgroundColor = [UIColor colorWithRed:0.1 green:0.5 blue:0.8 alpha:1.0];
    checkCodeBtn.layer.cornerRadius = 10;
    [checkCodeBtn addTarget:self action:@selector(analyzeCodeContent) forControlEvents:UIControlEventTouchUpInside];
    [self.filesAppView addSubview:checkCodeBtn];
}

- (void)closeFilesApp {
    [UIView animateWithDuration:0.25 animations:^{
        self.filesAppView.alpha = 0;
    } completion:^(BOOL finished) {
        [self.filesAppView removeFromSuperview];
        self.filesAppView = nil;
    }];
}

- (void)analyzeCodeContent {
    NSString *code = self.codeEditorView.text;
    BOOL hasMissingOrig = [code containsString:@"%hook"] && ![code containsString:@"%orig"];
    BOOL hasUnsafeUI = [code containsString:@"[UIApplication sharedApplication] keyWindow"];
    
    if (hasMissingOrig) {
        [self showAlertWithTitle:@"❌ Phát Hiện Lỗi Code!" message:@"Dòng hook của bạn thiếu gọi '%orig'. Điều này sẽ làm sập SpringBoard và gây ra Safe Mode ngay lập tức!"];
        self.isRealCrashSafeMode = YES;
    } else if (hasUnsafeUI) {
        [self showAlertWithTitle:@"⚠️ Cảnh Báo Nguy Hiểm!" message:@"Truy cập 'keyWindow' trực tiếp sẽ gây ra hiện tượng Đen Màn Hình (Black Screen)."];
        self.isRealCrashSafeMode = YES;
    } else {
        [self showAlertWithTitle:@"✅ Code Chuẩn Xác & An Toàn!" message:@"Không phát hiện lỗi cú pháp hoặc nguy cơ Safe Mode. Code này hoàn toàn an toàn."];
        self.isRealCrashSafeMode = NO;
    }
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)msg {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Đã Hiểu" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

// 4. MÔ PHỎNG RESPRING
- (void)simulateRealRespring {
    self.blackCurtainRespring = [[UIView alloc] initWithFrame:self.view.bounds];
    self.blackCurtainRespring.backgroundColor = [UIColor blackColor];
    
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    spinner.center = self.blackCurtainRespring.center;
    spinner.color = [UIColor whiteColor];
    [spinner startAnimating];
    [self.blackCurtainRespring addSubview:spinner];
    
    UILabel *respringText = [[UILabel alloc] initWithFrame:CGRectMake(20, spinner.center.y + 40, self.view.bounds.size.width - 40, 30)];
    respringText.text = @"Đang khởi động lại SpringBoard...";
    respringText.textColor = [UIColor lightGrayColor];
    respringText.textAlignment = NSTextAlignmentCenter;
    respringText.font = [UIFont systemFontOfSize:14];
    [self.blackCurtainRespring addSubview:respringText];
    
    [self.view addSubview:self.blackCurtainRespring];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.blackCurtainRespring removeFromSuperview];
        self.blackCurtainRespring = nil;

        self.isRespringDone = YES;
        [self showLockScreenWithSafeModePrompt];
    });
}

- (void)showLockScreenWithSafeModePrompt {
    self.lockScreenView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.lockScreenView.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.15 alpha:1.0];

    UILabel *timeLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, self.view.bounds.size.width - 40, 60)];
    timeLbl.text = @"09:41";
    timeLbl.textColor = [UIColor whiteColor];
    timeLbl.font = [UIFont systemFontOfSize:64 weight:UIFontWeightThin];
    timeLbl.textAlignment = NSTextAlignmentCenter;
    [self.lockScreenView addSubview:timeLbl];

    UIView *promptBox = [[UIView alloc] initWithFrame:CGRectMake(30, 260, self.view.bounds.size.width - 60, 160)];
    promptBox.backgroundColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.25 alpha:0.9];
    promptBox.layer.cornerRadius = 20;

    UILabel *promptTitle = [[UILabel alloc] initWithFrame:CGRectMake(15, 20, promptBox.bounds.size.width - 30, 24)];
    if (self.isTweakInstalled && self.isRealCrashSafeMode) {
        promptTitle.text = @"⚠️ ĐÃ VÀO SAFE MODE!";
        promptTitle.textColor = [UIColor redColor];
    } else {
        promptTitle.text = @"🛡️ BOOT THÀNH CÔNG";
        promptTitle.textColor = [UIColor greenColor];
    }
    promptTitle.font = [UIFont boldSystemFontOfSize:15];
    promptTitle.textAlignment = NSTextAlignmentCenter;
    [promptBox addSubview:promptTitle];

    UILabel *promptDesc = [[UILabel alloc] initWithFrame:CGRectMake(15, 50, promptBox.bounds.size.width - 30, 50)];
    if (self.isTweakInstalled && self.isRealCrashSafeMode) {
        promptDesc.text = @"Phát hiện code lỗi hoặc thiếu %orig! SpringBoard đã đẩy máy vào Safe Mode.";
    } else {
        promptDesc.text = @"Code an toàn. Không có lỗi crash khi boot.";
    }
    promptDesc.textColor = [UIColor whiteColor];
    promptDesc.font = [UIFont systemFontOfSize:13];
    promptDesc.textAlignment = NSTextAlignmentCenter;
    promptDesc.numberOfLines = 2;
    [promptBox addSubview:promptDesc];

    UIButton *unlockBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    unlockBtn.frame = CGRectMake(20, 110, promptBox.bounds.size.width - 40, 36);
    [unlockBtn setTitle:@"Mở Khóa Màn Hình" forState:UIControlStateNormal];
    [unlockBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    unlockBtn.backgroundColor = [UIColor colorWithRed:0.1 green:0.5 blue:0.8 alpha:1.0];
    unlockBtn.layer.cornerRadius = 10;
    [unlockBtn addTarget:self action:@selector(dismissLockScreen) forControlEvents:UIControlEventTouchUpInside];
    [promptBox addSubview:unlockBtn];

    [self.lockScreenView addSubview:promptBox];
    [self.view addSubview:self.lockScreenView];
}

- (void)dismissLockScreen {
    [UIView animateWithDuration:0.3 animations:^{
        self.lockScreenView.alpha = 0;
    } completion:^(BOOL finished) {
        [self.lockScreenView removeFromSuperview];
        self.lockScreenView = nil;
    }];
}

// 5. TEST APP & CHỐNG ĐEN MÀN HÌNH
- (void)openTweakTestApp {
    UIView *testAppView = [[UIView alloc] initWithFrame:self.view.bounds];
    testAppView.backgroundColor = [UIColor whiteColor];
    testAppView.alpha = 0;
    [self.view addSubview:testAppView];

    [UIView animateWithDuration:0.25 animations:^{
        testAppView.alpha = 1.0;
    } completion:^(BOOL finished) {
        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 80, testAppView.bounds.size.width - 40, 40)];
        title.text = @"Kiểm Tra Render App & Chống Đen Màn Hình";
        title.textColor = [UIColor blackColor];
        title.font = [UIFont boldSystemFontOfSize:15];
        title.textAlignment = NSTextAlignmentCenter;
        title.numberOfLines = 2;
        [testAppView addSubview:title];

        UILabel *resultLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 150, testAppView.bounds.size.width - 40, 90)];
        
        if (self.isTweakInstalled && self.isRealCrashSafeMode) {
            resultLbl.text = @"❌ LỖI CRASH: Code Tweak có lỗi, ứng dụng bị đen màn hình / văng!";
            resultLbl.textColor = [UIColor redColor];
            testAppView.backgroundColor = [UIColor blackColor];
            title.textColor = [UIColor whiteColor];
        } else if (self.isTweakInstalled && self.isRespringDone) {
            resultLbl.text = @"✅ Hoàn hảo! Code an toàn, app render mượt mà, không bị đen màn hình.";
            resultLbl.textColor = [UIColor colorWithRed:0.1 green:0.7 blue:0.2 alpha:1.0];
        } else {
            resultLbl.text = @"⚠️ Hãy cài Tweak qua Sileo và Respring để kiểm tra.";
            resultLbl.textColor = [UIColor orangeColor];
        }

        resultLbl.font = [UIFont systemFontOfSize:14];
        resultLbl.numberOfLines = 4;
        resultLbl.textAlignment = NSTextAlignmentCenter;
        [testAppView addSubview:resultLbl];

        UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        backBtn.frame = CGRectMake(30, testAppView.bounds.size.height - 100, testAppView.bounds.size.width - 60, 44);
        [backBtn setTitle:@"Thoát Về Màn Hình Chính" forState:UIControlStateNormal];
        [backBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        backBtn.backgroundColor = [UIColor darkGrayColor];
        backBtn.layer.cornerRadius = 12;
        [backBtn addTarget:self action:@selector(closeRunningApp:) forControlEvents:UIControlEventTouchUpInside];
        [testAppView addSubview:backBtn];
    }];
}

- (void)closeRunningApp:(UIButton *)sender {
    UIView *appView = sender.superview;
    [UIView animateWithDuration:0.2 animations:^{
        appView.alpha = 0;
    } completion:^(BOOL finished) {
        [appView removeFromSuperview];
    }];
}

- (void)showToastNotice:(NSString *)msg {
    UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(20, self.view.bounds.size.height - 120, self.view.bounds.size.width - 40, 36)];
    toast.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.95];
    toast.textColor = [UIColor whiteColor];
    toast.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    toast.textAlignment = NSTextAlignmentCenter;
    toast.layer.cornerRadius = 10;
    toast.clipsToBounds = YES;
    toast.text = msg;
    [self.view addSubview:toast];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.3 animations:^{ toast.alpha = 0; } completion:^(BOOL f){ [toast removeFromSuperview]; }];
    });
}

@end
