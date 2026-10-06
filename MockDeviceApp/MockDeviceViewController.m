#import <UIKit/UIKit.h>
#import <mach/mach.h>

@interface MockDeviceViewController : UIViewController <UITextFieldDelegate>
@property (nonatomic, strong) UIView *phoneFrameView;
@property (nonatomic, strong) UIImageView *wallpaperView;
@property (nonatomic, strong) UIView *springBoardView;
@property (nonatomic, strong) UIView *controlCenterView;
@property (nonatomic, strong) UIView *notificationCenterView;
@property (nonatomic, strong) UIView *appContainerView;

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
    self.view.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];
    [self setupPhoneFrame];
    [self setupSpringBoard];
    [self setupControlCenterAndNotifications];
    [self setupFPSMonitoring];
}

// 1. Tạo khung viền điện thoại & Notch tai thỏ giống ảnh demo
- (void)setupPhoneFrame {
    CGFloat w = self.view.bounds.size.width * 0.88;
    CGFloat h = w * (19.5 / 9.0); // Tỉ lệ màn hình iPhone đời mới
    self.phoneFrameView = [[UIView alloc] initWithFrame:CGRectMake((self.view.bounds.size.width - w)/2, (self.view.bounds.size.height - h)/2, w, h)];
    self.phoneFrameView.layer.cornerRadius = 44.0;
    self.phoneFrameView.layer.borderWidth = 5.0;
    self.phoneFrameView.layer.borderColor = [UIColor blackColor].CGColor;
    self.phoneFrameView.clipsToBounds = YES;
    [self.view addSubview:self.phoneFrameView];

    // Hình nền demo chống đen màn hình
    self.wallpaperView = [[UIImageView alloc] initWithFrame:self.phoneFrameView.bounds];
    self.wallpaperView.backgroundColor = [UIColor colorWithRed:0.2 green:0.25 blue:0.35 alpha:1.0];
    self.wallpaperView.contentMode = UIViewContentModeScaleAspectFill;
    [self.phoneFrameView addSubview:self.wallpaperView];

    // Cụm Notch giả lập
    UIView *notch = [[UIView alloc] initWithFrame:CGRectMake((w - 120)/2, 0, 120, 28)];
    notch.backgroundColor = [UIColor blackColor];
    notch.layer.cornerRadius = 14;
    [self.phoneFrameView addSubview:notch];
}

// 2. Màn hình chính SpringBoard, Icon xám test, Sileo & App Sandbox Demo
- (void)setupSpringBoard {
    self.springBoardView = [[UIView alloc] initWithFrame:self.phoneFrameView.bounds];
    [self.phoneFrameView addSubview:self.springBoardView];

    // Icon 1: Sileo Demo Cài Tweak
    UIButton *sileoBtn = [self createMockAppIcon:@"Sileo" iconColor:[UIColor colorWithWhite:0.4 alpha:1.0] frame:CGRectMake(24, 70, 60, 60)];
    [sileoBtn addTarget:self action:@selector(openSileoInstallerDemo) forControlEvents:UIControlEventTouchUpInside];
    [self.springBoardView addSubview:sileoBtn];

    // Icon 2: App Sandbox Demo (Test đen màn & vượt sandbox)
    UIButton *sandboxAppBtn = [self createMockAppIcon:@"App Test" iconColor:[UIColor colorWithWhite:0.5 alpha:1.0] frame:CGRectMake(104, 70, 60, 60)];
    [sandboxAppBtn addTarget:self action:@selector(openSandboxTestApp) forControlEvents:UIControlEventTouchUpInside];
    [self.springBoardView addSubview:sandboxAppBtn];

    // Icon 3: App Test Mạng (Network Latency & Throughput)
    UIButton *netAppBtn = [self createMockAppIcon:@"Speed Test" iconColor:[UIColor colorWithWhite:0.35 alpha:1.0] frame:CGRectMake(184, 70, 60, 60)];
    [netAppBtn addTarget:self action:@selector(openNetworkTestApp) forControlEvents:UIControlEventTouchUpInside];
    [self.springBoardView addSubview:netAppBtn];

    // Icon 4: Test Bàn phím gõ nhanh không delay
    UIButton *kbAppBtn = [self createMockAppIcon:@"Gõ Phím" iconColor:[UIColor colorWithWhite:0.45 alpha:1.0] frame:CGRectMake(264, 70, 60, 60)];
    [kbAppBtn addTarget:self action:@selector(openKeyboardLagTesterApp) forControlEvents:UIControlEventTouchUpInside];
    [self.springBoardView addSubview:kbAppBtn];
}

- (UIButton *)createMockAppIcon:(NSString *)title iconColor:(UIColor *)color frame:(CGRect)frame {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = frame;
    btn.backgroundColor = color;
    btn.layer.cornerRadius = 14.0;
    btn.layer.shadowColor = [UIColor blackColor].CGColor;
    btn.layer.shadowOpacity = 0.3;
    btn.layer.shadowOffset = CGSizeMake(0, 3);

    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(-10, frame.size.height + 4, frame.size.width + 20, 16)];
    lbl.text = title;
    lbl.textColor = [UIColor whiteColor];
    lbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    lbl.textAlignment = NSTextAlignmentCenter;
    [btn addSubview:lbl];
    return btn;
}

// 3. Quy trình Sileo Cài Tweak -> Thoát ra -> Respring -> Báo Safe Mode
- (void)openSileoInstallerDemo {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Sileo Package Manager (Demo)" 
                                                                   message:@"Gói BoostiPhone6s.deb đã sẵn sàng cài đặt vào hệ thống." 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cài Đặt & Thoát Ra" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        // Mô phỏng thao tác thoát Sileo trở về màn hình chính
        [self showToastNotice:@"Đã cài đặt xong Tweak. Đang ở màn hình chính!"];
        
        // Hiện nút kích hoạt respring kiểm tra Safe Mode
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self triggerRespringVerification];
        });
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)triggerRespringVerification {
    UIAlertController *respringAlert = [UIAlertController alertControllerWithTitle:@"Thực Hiện Respring?" 
                                                                           message:@"Hệ thống sẽ reload lại SpringBoard để kiểm tra xung đột Safe Mode." 
                                                                    preferredStyle:UIAlertControllerStyleActionSheet];
    [respringAlert addAction:[UIAlertAction actionWithTitle:@"Respring Ngay" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        // Mô phỏng màn hình respring đen xoay vòng
        UIView *blackCurtain = [[UIView alloc] initWithFrame:self.phoneFrameView.bounds];
        blackCurtain.backgroundColor = [UIColor blackColor];
        UIActivityIndicatorView *spin = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
        spin.center = blackCurtain.center;
        [spin startAnimating];
        [blackCurtain addSubview:spin];
        [self.phoneFrameView addSubview:blackCurtain];

        // Quét nhị phân giả định: Kiểm tra nếu hook sai selector sẽ vào Safe Mode
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [blackCurtain removeFromSuperview];
            BOOL isSafeMode = NO; // Trạng thái kiểm tra xung đột nhị phân
            if (isSafeMode) {
                [self showCenteredErrorAlert:@"⚠️ CẢNH BÁO: SPRINGBOARD VÀO SAFE MODE!\nPhát hiện xung đột hook nhị phân dylib."];
            } else {
                [self showToastNotice:@"✅ Respring thành công! Tweak hoạt động bình thường."];
            }
        });
    }]];
    [respringAlert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:respringAlert animated:YES completion:nil];
}

// 4. Test Mở App: Hiệu ứng mở mượt (0ms/60fps) + Báo lỗi vượt Sandbox
- (void)openSandboxTestApp {
    // Hiệu ứng zoom mở app mượt mà để kiểm tra lag
    UIView *appView = [[UIView alloc] initWithFrame:CGRectMake(104, 70, 60, 60)];
    appView.backgroundColor = [UIColor whiteColor];
    appView.layer.cornerRadius = 14;
    [self.phoneFrameView addSubview:appView];

    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        appView.frame = self.phoneFrameView.bounds;
        appView.layer.cornerRadius = 0;
    } completion:^(BOOL finished) {
        // Khi app mở lên: Kiểm tra chữ hiển thị & bắt lỗi Sandbox
        UILabel *testLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, appView.bounds.size.width - 40, 40)];
        testLabel.text = @"Test Demo Ứng Dụng Độc Lập";
        testLabel.textColor = [UIColor blackColor];
        testLabel.font = [UIFont boldSystemFontOfSize:17];
        testLabel.textAlignment = NSTextAlignmentCenter;
        [appView addSubview:testLabel];

        // Nút đóng app
        UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        closeBtn.frame = CGRectMake(20, 40, 60, 30);
        [closeBtn setTitle:@"Thoát" forState:UIControlStateNormal];
        [closeBtn addTarget:self action:@selector(closeRunningApp:) forControlEvents:UIControlEventTouchUpInside];
        [appView addSubview:closeBtn];

        // Kích hoạt thông báo cảnh báo lỗi Sandbox ở chính giữa màn hình
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self showCenteredErrorAlert:@"Lỗi vượt qua sandbox"];
        });
    }];
}

- (void)closeRunningApp:(UIButton *)sender {
    UIView *appView = sender.superview;
    [UIView animateWithDuration:0.25 animations:^{
        appView.alpha = 0.0;
        appView.transform = CGAffineTransformMakeScale(0.8, 0.8);
    } completion:^(BOOL finished) {
        [appView removeFromSuperview];
    }];
}

// 5. App Kiểm Tra Băng Thông & Tải Mạng
- (void)openNetworkTestApp {
    UIView *netView = [[UIView alloc] initWithFrame:self.phoneFrameView.bounds];
    netView.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
    [self.phoneFrameView addSubview:netView];

    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 60, netView.bounds.size.width - 40, 30)];
    titleLbl.text = @"Kiểm Tra Băng Thông & Độ Trễ";
    titleLbl.font = [UIFont boldSystemFontOfSize:16];
    titleLbl.textAlignment = NSTextAlignmentCenter;
    [netView addSubview:titleLbl];

    self.networkSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.networkSpinner.center = CGPointMake(netView.bounds.size.width / 2, 160);
    [self.networkSpinner startAnimating];
    [netView addSubview:self.networkSpinner];

    self.networkStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 200, netView.bounds.size.width - 40, 40)];
    self.networkStatusLabel.text = @"Đang nạp luồng gói tin (0KB/s)...";
    self.networkStatusLabel.textAlignment = NSTextAlignmentCenter;
    self.networkStatusLabel.font = [UIFont systemFontOfSize:14];
    [netView addSubview:self.networkStatusLabel];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(20, 260, netView.bounds.size.width - 40, 44);
    [closeBtn setTitle:@"Đóng Trình Test Mạng" forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(closeRunningApp:) forControlEvents:UIControlEventTouchUpInside];
    [netView addSubview:closeBtn];

    // Mô phỏng kết quả sau 1.5s
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.networkSpinner stopAnimating];
        self.networkStatusLabel.text = @"Băng thông: 128.4 Mbps • Ping: 9ms (Không nghẽn)";
    });
}

// 6. Test Bàn Phím: Gõ văn bản tốc độ cao đo độ trễ (0ms Key Response)
- (void)openKeyboardLagTesterApp {
    UIView *kbView = [[UIView alloc] initWithFrame:self.phoneFrameView.bounds];
    kbView.backgroundColor = [UIColor whiteColor];
    [self.phoneFrameView addSubview:kbView];

    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 50, kbView.bounds.size.width - 40, 30)];
    titleLbl.text = @"Bàn Phím 0ms - Gõ Nhanh Không Giật";
    titleLbl.font = [UIFont boldSystemFontOfSize:15];
    titleLbl.textAlignment = NSTextAlignmentCenter;
    [kbView addSubview:titleLbl];

    self.keyboardLagTester = [[UITextField alloc] initWithFrame:CGRectMake(20, 90, kbView.bounds.size.width - 40, 44)];
    self.keyboardLagTester.borderStyle = UITextBorderStyleRoundedRect;
    self.keyboardLagTester.placeholder = @"Nhập văn bản liên tục để đo độ trễ...";
    self.keyboardLagTester.delegate = self;
    [kbView addSubview:self.keyboardLagTester];
    [self.keyboardLagTester becomeFirstResponder];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(20, 145, kbView.bounds.size.width - 40, 36);
    [closeBtn setTitle:@"Hoàn Thành & Đóng" forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(closeRunningApp:) forControlEvents:UIControlEventTouchUpInside];
    [kbView addSubview:closeBtn];
}

// 7. Trung tâm điều khiển (Control Center Icon Xám) & Trung tâm thông báo giả
- (void)setupControlCenterAndNotifications {
    // Trung tâm thông báo giả phía trên
    self.notificationCenterView = [[UIView alloc] initWithFrame:CGRectMake(10, 32, self.phoneFrameView.bounds.size.width - 20, 30)];
    self.notificationCenterView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.8];
    self.notificationCenterView.layer.cornerRadius = 8;
    UILabel *notifLabel = [[UILabel alloc] initWithFrame:self.notificationCenterView.bounds];
    notifLabel.text = @"🔔 Trung Tâm Thông Báo Giả (Test)";
    notifLabel.textColor = [UIColor whiteColor];
    notifLabel.font = [UIFont systemFontOfSize:11];
    notifLabel.textAlignment = NSTextAlignmentCenter;
    [self.notificationCenterView addSubview:notifLabel];
    [self.phoneFrameView addSubview:self.notificationCenterView];

    // Nút mở Control Center góc trên bên phải
    UIButton *ccTrigger = [UIButton buttonWithType:UIButtonTypeCustom];
    ccTrigger.frame = CGRectMake(self.phoneFrameView.bounds.size.width - 40, 5, 35, 25);
    [ccTrigger addTarget:self action:@selector(toggleControlCenter) forControlEvents:UIControlEventTouchUpInside];
    [self.phoneFrameView addSubview:ccTrigger];
}

- (void)toggleControlCenter {
    if (!self.controlCenterView) {
        CGFloat w = self.phoneFrameView.bounds.size.width;
        self.controlCenterView = [[UIView alloc] initWithFrame:CGRectMake(0, -300, w, 280)];
        self.controlCenterView.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.95];
        self.controlCenterView.layer.cornerRadius = 24;

        UILabel *ccTitle = [[UILabel alloc] initWithFrame:CGRectMake(20, 10, w - 40, 20)];
        ccTitle.text = @"Trung Tâm Điều Khiển (Icon Xám Test)";
        ccTitle.textColor = [UIColor lightGrayColor];
        ccTitle.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
        [self.controlCenterView addSubview:ccTitle];

        // Tạo 4 module icon màu xám đặc trưng
        for (int i = 0; i < 4; i++) {
            UIView *grayModule = [[UIView alloc] initWithFrame:CGRectMake(20 + (i % 2) * 80, 40 + (i / 2) * 80, 70, 70)];
            grayModule.backgroundColor = [UIColor colorWithWhite:0.35 alpha:1.0];
            grayModule.layer.cornerRadius = 16;
            [self.controlCenterView addSubview:grayModule];
        }

        UIButton *closeCC = [UIButton buttonWithType:UIButtonTypeSystem];
        closeCC.frame = CGRectMake(20, 230, w - 40, 30);
        [closeCC setTitle:@"Đóng Control Center" forState:UIControlStateNormal];
        [closeCC setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [closeCC addTarget:self action:@selector(toggleControlCenter) forControlEvents:UIControlEventTouchUpInside];
        [self.controlCenterView addSubview:closeCC];

        [self.phoneFrameView addSubview:self.controlCenterView];
    }

    BOOL isOpen = (self.controlCenterView.frame.origin.y >= 0);
    [UIView animateWithDuration:0.3 animations:^{
        CGRect f = self.controlCenterView.frame;
        f.origin.y = isOpen ? -300 : 0;
        self.controlCenterView.frame = f;
    }];
}

// 8. Giám sát FPS/Hz động
- (void)setupFPSMonitoring {
    self.fpsCounterLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.phoneFrameView.bounds.size.width - 110, self.phoneFrameView.bounds.size.height - 35, 100, 20)];
    self.fpsCounterLabel.textColor = [UIColor greenColor];
    self.fpsCounterLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightBold];
    self.fpsCounterLabel.textAlignment = NSTextAlignmentRight;
    [self.phoneFrameView addSubview:self.fpsCounterLabel];

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

// 9. Cảnh báo hiển thị chính giữa: "Lỗi vượt qua sandbox"
- (void)showCenteredErrorAlert:(NSString *)msg {
    UIView *alertBox = [[UIView alloc] initWithFrame:CGRectMake(20, (self.phoneFrameView.bounds.size.height - 130)/2, self.phoneFrameView.bounds.size.width - 40, 130)];
    alertBox.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.95];
    alertBox.layer.cornerRadius = 16.0;
    alertBox.layer.borderWidth = 1.5;
    alertBox.layer.borderColor = [UIColor redColor].CGColor;

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(10, 15, alertBox.bounds.size.width - 20, 24)];
    title.text = @"⚠️ THÔNG BÁO HỆ THỐNG";
    title.textColor = [UIColor redColor];
    title.font = [UIFont boldSystemFontOfSize:14];
    title.textAlignment = NSTextAlignmentCenter;
    [alertBox addSubview:title];

    UILabel *content = [[UILabel alloc] initWithFrame:CGRectMake(15, 45, alertBox.bounds.size.width - 30, 40)];
    content.text = msg;
    content.textColor = [UIColor whiteColor];
    content.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    content.textAlignment = NSTextAlignmentCenter;
    content.numberOfLines = 2;
    [alertBox addSubview:content];

    UIButton *okBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    okBtn.frame = CGRectMake((alertBox.bounds.size.width - 80)/2, 90, 80, 28);
    [okBtn setTitle:@"Đã Hiểu" forState:UIControlStateNormal];
    [okBtn addTarget:self action:@selector(dismissCenteredAlert:) forControlEvents:UIControlEventTouchUpInside];
    [alertBox addSubview:okBtn];

    [self.phoneFrameView addSubview:alertBox];
}

- (void)dismissCenteredAlert:(UIButton *)sender {
    [UIView animateWithDuration:0.2 animations:^{
        sender.superview.alpha = 0.0;
    } completion:^(BOOL finished) {
        [sender.superview removeFromSuperview];
    }];
}

- (void)showToastNotice:(NSString *)msg {
    UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(20, self.phoneFrameView.bounds.size.height - 70, self.phoneFrameView.bounds.size.width - 40, 32)];
    toast.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.9];
    toast.textColor = [UIColor whiteColor];
    toast.font = [UIFont systemFontOfSize:12];
    toast.textAlignment = NSTextAlignmentCenter;
    toast.layer.cornerRadius = 8;
    toast.clipsToBounds = YES;
    toast.text = msg;
    [self.phoneFrameView addSubview:toast];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.3 animations:^{ toast.alpha = 0; } completion:^(BOOL f){ [toast removeFromSuperview]; }];
    });
}

@end
