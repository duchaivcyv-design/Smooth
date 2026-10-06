#import "MockDeviceViewController.h"
#import <mach/mach.h>

@interface MockDeviceViewController () <UITextFieldDelegate>
@property (nonatomic, strong) UIView *springBoardView;
@property (nonatomic, strong) UIView *controlCenterView;
@property (nonatomic, strong) UIView *notificationCenterView;

// Các thành phần test
@property (nonatomic, strong) UITextField *keyboardLagTester;
@property (nonatomic, strong) UIActivityIndicatorView *networkSpinner;
@property (nonatomic, strong) UILabel *networkStatusLabel;
@property (nonatomic, strong) CADisplayLink *fpsDisplayLink;
@property (nonatomic, strong) UILabel *fpsCounterLabel;
@property (nonatomic, assign) CFTimeInterval lastTimestamp;
@property (nonatomic, assign) NSInteger frameCount;
@end

@implementation MockDeviceViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Đặt màu nền tối sang trọng giống màn hình chính iOS thật
    self.view.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.12 alpha:1.0];
    
    [self setupSpringBoard];
    [self setupControlCenterAndNotifications];
    [self setupFPSMonitoring];
}

// 1. Màn hình chính SpringBoard tràn viền, hiển thị trực tiếp các icon test
- (void)setupSpringBoard {
    self.springBoardView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.springBoardView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.springBoardView];

    // Tiêu đề app
    UILabel *headerLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 60, self.view.bounds.size.width - 40, 30)];
    headerLbl.text = @"BoostiPhone6s Safe Sandbox";
    headerLbl.textColor = [UIColor whiteColor];
    headerLbl.font = [UIFont boldSystemFontOfSize:20];
    headerLbl.textAlignment = NSTextAlignmentCenter;
    [self.springBoardView addSubview:headerLbl];

    // Lưới các nút bấm icon test (Sileo, App Test, Speed Test, Gõ phím)
    CGFloat startX = 35;
    CGFloat startY = 120;
    CGFloat size = 70;
    CGFloat spacing = 20;

    NSArray *apps = @[
        @{@"title": @"Sileo", @"color": [UIColor colorWithRed:0.2 green:0.6 blue:0.9 alpha:1.0], @"action": @selector(openSileoInstallerDemo)},
        @{@"title": @"App Test", @"color": [UIColor colorWithRed:0.4 green:0.4 blue:0.5 alpha:1.0], @"action": @selector(openSandboxTestApp)},
        @{@"title": @"Speed Test", @"color": [UIColor colorWithRed:0.9 green:0.5 blue:0.1 alpha:1.0], @"action": @selector(openNetworkTestApp)},
        @{@"title": @"Gõ Phím", @"color": [UIColor colorWithRed:0.1 green:0.7 blue:0.3 alpha:1.0], @"action": @selector(openKeyboardLagTesterApp)}
    ];

    for (int i = 0; i < apps.count; i++) {
        NSDictionary *appInfo = apps[i];
        int row = i / 2;
        int col = i % 2;
        CGFloat x = startX + col * (size + spacing + 40);
        CGFloat y = startY + row * (size + 50);

        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(x, y, size, size);
        btn.backgroundColor = appInfo[@"color"];
        btn.layer.cornerRadius = 18.0;
        btn.layer.shadowColor = [UIColor blackColor].CGColor;
        btn.layer.shadowOpacity = 0.4;
        btn.layer.shadowOffset = CGSizeMake(0, 4);
        [btn addTarget:self action:NSSelectorFromString(appInfo[@"action"]) forControlEvents:UIControlEventTouchUpInside];

        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(-10, size + 6, size + 20, 18)];
        lbl.text = appInfo[@"title"];
        lbl.textColor = [UIColor whiteColor];
        lbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        lbl.textAlignment = NSTextAlignmentCenter;
        [btn addSubview:lbl];

        [self.springBoardView addSubview:btn];
    }
}

// 2. Quy trình Sileo Cài Tweak & Kiểm tra Safe Mode
- (void)openSileoInstallerDemo {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Sileo Package Manager (Demo)" 
                                                                   message:@"Gói BoostiPhone6s.deb đã sẵn sàng cài đặt an toàn." 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cài Đặt & Respring" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self showToastNotice:@"Đang cài đặt Tweak vào phân vùng Rootless..."];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self triggerRespringVerification];
        });
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)triggerRespringVerification {
    UIAlertController *respringAlert = [UIAlertController alertControllerWithTitle:@"Xác Nhận Respring?" 
                                                                           message:@"Kiểm tra trạng thái an toàn 0% lỗi Safe Mode." 
                                                                    preferredStyle:UIAlertControllerStyleActionSheet];
    [respringAlert addAction:[UIAlertAction actionWithTitle:@"Thực Thi Respring" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        UIView *blackCurtain = [[UIView alloc] initWithFrame:self.view.bounds];
        blackCurtain.backgroundColor = [UIColor blackColor];
        UIActivityIndicatorView *spin = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
        spin.center = blackCurtain.center;
        [spin startAnimating];
        [blackCurtain addSubview:spin];
        [self.view addSubview:blackCurtain];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [blackCurtain removeFromSuperview];
            [self showToastNotice:@"✅ Respring thành công! Hoạt động hoàn hảo."];
        });
    }]];
    [respringAlert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:respringAlert animated:YES completion:nil];
}

// 3. Test App độc lập & Cảnh báo Sandbox
- (void)openSandboxTestApp {
    UIView *appView = [[UIView alloc] initWithFrame:self.view.bounds];
    appView.backgroundColor = [UIColor whiteColor];
    appView.alpha = 0.0;
    [self.view addSubview:appView];

    [UIView animateWithDuration:0.25 animations:^{
        appView.alpha = 1.0;
    } completion:^(BOOL finished) {
        UILabel *testLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, appView.bounds.size.width - 40, 40)];
        testLabel.text = @"Sandboxed Application Mode";
        testLabel.textColor = [UIColor blackColor];
        testLabel.font = [UIFont boldSystemFontOfSize:18];
        testLabel.textAlignment = NSTextAlignmentCenter;
        [appView addSubview:testLabel];

        UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        closeBtn.frame = CGRectMake(20, 40, 80, 35);
        [closeBtn setTitle:@"Quay Lại" forState:UIControlStateNormal];
        [closeBtn addTarget:self action:@selector(closeRunningApp:) forControlEvents:UIControlEventTouchUpInside];
        [appView addSubview:closeBtn];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self showCenteredErrorAlert:@"Kiểm tra Sandbox: Hoạt động độc lập an toàn!"];
        });
    }];
}

- (void)closeRunningApp:(UIButton *)sender {
    UIView *appView = sender.superview;
    [UIView animateWithDuration:0.2 animations:^{
        appView.alpha = 0.0;
    } completion:^(BOOL finished) {
        [appView removeFromSuperview];
    }];
}

// 4. Test Mạng & Băng Thông
- (void)openNetworkTestApp {
    UIView *netView = [[UIView alloc] initWithFrame:self.view.bounds];
    netView.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
    [self.view addSubview:netView];

    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 60, netView.bounds.size.width - 40, 30)];
    titleLbl.text = @"Kiểm Tra Băng Thông & Độ Trễ";
    titleLbl.font = [UIFont boldSystemFontOfSize:16];
    titleLbl.textAlignment = NSTextAlignmentCenter;
    [netView addSubview:titleLbl];

    self.networkSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.networkSpinner.center = CGPointMake(netView.bounds.size.width / 2, 180);
    [self.networkSpinner startAnimating];
    [netView addSubview:self.networkSpinner];

    self.networkStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 240, netView.bounds.size.width - 40, 40)];
    self.networkStatusLabel.text = "Đang kết nối luồng test (0KB/s)...";
    self.networkStatusLabel.textAlignment = NSTextAlignmentCenter;
    self.networkStatusLabel.font = [UIFont systemFontOfSize:14];
    [netView addSubview:self.networkStatusLabel];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(20, 310, netView.bounds.size.width - 40, 44);
    [closeBtn setTitle:@"Đóng Trình Test" forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(closeRunningApp:) forControlEvents:UIControlEventTouchUpInside];
    [netView addSubview:closeBtn];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.networkSpinner stopAnimating];
        self.networkStatusLabel.text = @"Tốc độ: 156.2 Mbps • Ping: 7ms (Ổn định)";
    });
}

// 5. Test Bàn Phím 0ms
- (void)openKeyboardLagTesterApp {
    UIView *kbView = [[UIView alloc] initWithFrame:self.view.bounds];
    kbView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:kbView];

    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 60, kbView.bounds.size.width - 40, 30)];
    titleLbl.text = @"Bàn Phím 0ms - Gõ Nhanh";
    titleLbl.font = [UIFont boldSystemFontOfSize:16];
    titleLbl.textAlignment = NSTextAlignmentCenter;
    [kbView addSubview:titleLbl];

    self.keyboardLagTester = [[UITextField alloc] initWithFrame:CGRectMake(20, 110, kbView.bounds.size.width - 40, 44)];
    self.keyboardLagTester.borderStyle = UITextBorderStyleRoundedRect;
    self.keyboardLagTester.placeholder = "Gõ phím liên tục tại đây...";
    self.keyboardLagTester.delegate = self;
    [kbView addSubview:self.keyboardLagTester];
    [self.keyboardLagTester becomeFirstResponder];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(20, 170, kbView.bounds.size.width - 40, 40);
    [closeBtn setTitle:@"Đóng" forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(closeRunningApp:) forControlEvents:UIControlEventTouchUpInside];
    [kbView addSubview:kbView]; // Hoặc đóng view trực tiếp
}

// 6. Trung tâm điều khiển & Giám sát FPS
- (void)setupControlCenterAndNotifications {
    self.fpsCounterLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - 120, 45, 100, 24)];
    self.fpsCounterLabel.textColor = [UIColor greenColor];
    self.fpsCounterLabel.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightBold];
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

- (void)showCenteredErrorAlert:(NSString *)msg {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"⚠️️ THÔNG BÁO HỆ THỐNG" message:msg preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Đã Hiểu" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showToastNotice:(NSString *)msg {
    UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(30, self.view.bounds.size.height - 100, self.view.bounds.size.width - 60, 36)];
    toast.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.95];
    toast.textColor = [UIColor whiteColor];
    toast.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    toast.textAlignment = NSTextAlignmentCenter;
    toast.layer.cornerRadius = 10;
    toast.clipsToBounds = YES;
    toast.text = msg;
    [self.view addSubview:toast];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.3 animations:^{ toast.alpha = 0; } completion:^(BOOL f){ [toast removeFromSuperview]; }];
    });
}

@end
