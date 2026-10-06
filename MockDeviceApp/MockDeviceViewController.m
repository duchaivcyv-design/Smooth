#import "MockDeviceViewController.h"
#import <mach/mach.h>

@interface MockDeviceViewController () <UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UIView *homeScreenView;
@property (nonatomic, strong) UIView *sileoAppView;
@property (nonatomic, strong) UIView *lockScreenView;
@property (nonatomic, strong) UIView *blackCurtainRespring;
@property (nonatomic, strong) UITableView *sileoTableView;
@property (nonatomic, strong) UILabel *statusLabel;

// Các thông số kiểm tra
@property (nonatomic, assign) BOOL isTweakInstalled;
@property (nonatomic, assign) BOOL isInSafeMode;
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
    self.isInSafeMode = NO;

    [self setupHomeScreen];
    [self setupFPSMonitoring];
}

// 1. MÀN HÌNH CHÍNH (SPRINGBOARD GIẢ LẬP)
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
    title.text = @"BoostiPhone6s Rootless Sandbox";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:18];
    title.textAlignment = NSTextAlignmentCenter;
    [self.homeScreenView addSubview:title];

    NSArray *apps = @[
        @{@"name": @"Sileo", @"color": [UIColor colorWithRed:0.15 green:0.55 blue:0.85 alpha:1.0], @"selector": [NSValue valueWithPointer:@selector(openSileoApp)]},
        @{@"name": @"Tweak Test", @"color": [UIColor colorWithRed:0.2 green:0.7 blue:0.3 alpha:1.0], @"selector": [NSValue valueWithPointer:@selector(openTweakTestApp)]},
        @{@"name": @"Respring", @"color": [UIColor colorWithRed:0.9 green:0.3 blue:0.2 alpha:1.0], @"selector": [NSValue valueWithPointer:@selector(simulateRealRespring)]},
        @{@"name": @"Files", @"color": [UIColor colorWithRed:0.95 green:0.6 blue:0.1 alpha:1.0], @"selector": [NSValue valueWithPointer:@selector(openFilesApp)]}
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

// 2. GIAO DIỆN SILEO THẬT
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
    cell.detailTextLabel.text = self.isTweakInstalled ? @"Đã cài đặt ✅ (Bấm để gỡ)" : @"Phiên bản: 28.7 Pro (Chạm để cài)";
    cell.detailTextLabel.textColor = self.isTweakInstalled ? [UIColor greenColor] : [UIColor orangeColor];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (!self.isTweakInstalled) {
        UIAlertController *installAlert = [UIAlertController alertControllerWithTitle:@"Cài Đặt Gói Tweak" 
                                                                               message:@"Xác nhận nạp BoostiPhone6sCore.dylib vào phân vùng rootless?" 
                                                                        preferredStyle:UIAlertControllerStyleAlert];
        [installAlert addAction:[UIAlertAction actionWithTitle:@"Tiến Hành Cài" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            self.isTweakInstalled = YES;
            [self.sileoTableView reloadData];
            [self showToastNotice:@"📥 Tải và cấu hình .deb thành công! Bắt đầu Respring..."];
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self closeSileoApp];
                [self simulateRealRespring];
            });
        }]];
        [installAlert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:installAlert animated:YES completion:nil];
    }
}

// 3. MÔ PHỎNG RESPRING & MÀN HÌNH KHÓA KIỂM TRA SAFE MODE
- (void)simulateRealRespring {
    self.blackCurtainRespring = [[UIView alloc] initWithFrame:self.view.bounds];
    self.blackCurtainRespring.backgroundColor = [UIColor blackColor];
    
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    spinner.center = self.blackCurtainRespring.center;
    spinner.color = [UIColor whiteColor];
    [spinner startAnimating];
    [self.blackCurtainRespring addSubview:spinner];
    
    UILabel *respringText = [[UILabel alloc] initWithFrame:CGRectMake(20, spinner.center.y + 40, self.view.bounds.size.width - 40, 30)];
    respringText.text = @"Đang nạp lại SpringBoard...";
    respringText.textColor = [UIColor lightGrayColor];
    respringText.textAlignment = NSTextAlignmentCenter;
    respringText.font = [UIFont systemFontOfSize:14];
    [self.blackCurtainRespring addSubview:respringText];
    
    [self.view addSubview:self.blackCurtainRespring];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.blackCurtainRespring removeFromSuperview];
        self.blackCurtainRespring = nil;

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

    UILabel *dateLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 170, self.view.bounds.size.width - 40, 30)];
    dateLbl.text = @"Thứ Tư, 7 Tháng 10";
    dateLbl.textColor = [UIColor lightGrayColor];
    dateLbl.font = [UIFont systemFontOfSize:18 weight:UIFontWeightMedium];
    dateLbl.textAlignment = NSTextAlignmentCenter;
    [self.lockScreenView addSubview:dateLbl];

    UIView *promptBox = [[UIView alloc] initWithFrame:CGRectMake(30, 260, self.view.bounds.size.width - 60, 160)];
    promptBox.backgroundColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.25 alpha:0.9];
    promptBox.layer.cornerRadius = 20;

    UILabel *promptTitle = [[UILabel alloc] initWithFrame:CGRectMake(15, 20, promptBox.bounds.size.width - 30, 24)];
    promptTitle.text = self.isInSafeMode ? @"⚠️ HỆ THỐNG ĐANG Ở SAFE MODE" : @"🛡️ KIỂM TRA TRẠNG THÁI BOOT";
    promptTitle.textColor = self.isInSafeMode ? [UIColor redColor] : [UIColor greenColor];
    promptTitle.font = [UIFont boldSystemFontOfSize:15];
    promptTitle.textAlignment = NSTextAlignmentCenter;
    [promptBox addSubview:promptTitle];

    UILabel *promptDesc = [[UILabel alloc] initWithFrame:CGRectMake(15, 50, promptBox.bounds.size.width - 30, 50)];
    promptDesc.text = self.isInSafeMode ? @"Tweak bị xung đột hook! Phát hiện Safe Mode." : @"Tweak nạp thành công 100%. Không có lỗi crash!";
    promptDesc.textColor = [UIColor whiteColor];
    promptDesc.font = [UIFont systemFontOfSize:13];
    promptDesc.textAlignment = NSTextAlignmentCenter;
    promptDesc.numberOfLines = 2;
    [promptBox addSubview:promptDesc];

    UIButton *unlockBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    unlockBtn.frame = CGRectMake(20, 110, promptBox.bounds.size.width - 40, 36);
    [unlockBtn setTitle:@"Vuốt Lên Mở Khóa" forState:UIControlStateNormal];
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
        self.lockScreenView.transform = CGAffineTransformMakeScale(1.1, 1.1);
    } completion:^(BOOL finished) {
        [self.lockScreenView removeFromSuperview];
        self.lockScreenView = nil;
        [self showToastNotice:@"🔓 Đã mở khóa màn hình chính thành công!"];
    }];
}

// 4. TEST APP TRỰC QUAN (CHỐNG ĐEN MÀN HÌNH)
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
        title.font = [UIFont boldSystemFontOfSize:16];
        title.textAlignment = NSTextAlignmentCenter;
        title.numberOfLines = 2;
        [testAppView addSubview:title];

        UILabel *resultLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 160, testAppView.bounds.size.width - 40, 60)];
        if (self.isTweakInstalled) {
            resultLbl.text = @"✅ Tweak đã nạp: Giao diện hiển thị mượt mà, không bị đen màn hình, hook hoạt động chuẩn!";
            resultLbl.textColor = [UIColor colorWithRed:0.1 green:0.7 blue:0.2 alpha:1.0];
        } else {
            resultLbl.text = @"⚠️ Chưa cài Tweak qua Sileo. Hãy cài qua Sileo trước để test render!";
            resultLbl.textColor = [UIColor orangeColor];
        }
        resultLbl.font = [UIFont systemFontOfSize:14];
        resultLbl.numberOfLines = 3;
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

- (void)openFilesApp {
    [self showToastNotice:@"📁 Đang đọc thư mục /var/jb/Library/MobileSubstrate/... (Chuẩn Rootless)"];
}

- (void)closeRunningApp:(UIButton *)sender {
    UIView *appView = sender.superview;
    [UIView animateWithDuration:0.2 animations:^{
        appView.alpha = 0;
    } completion:^(BOOL finished) {
        [appView removeFromSuperview];
    }];
}

// 5. GIÁM SÁT FPS
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
