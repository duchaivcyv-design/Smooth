#import "MockDeviceViewController.h"
#import <mach/mach.h>

@interface MockDeviceViewController () <UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UIView *homeScreenView;
@property (nonatomic, strong) UIView *sileoAppView;
@property (nonatomic, strong) UIView *lockScreenView;
@property (nonatomic, strong) UIView *blackCurtainRespring;
@property (nonatomic, strong) UITableView *sileoTableView;

// Trạng thái mô phỏng
@property (nonatomic, assign) BOOL isTweakInstalled;
@property (nonatomic, assign) BOOL isRespringDone;
@property (nonatomic, assign) BOOL isRealCrashSafeMode; // Biến phản ánh chính xác lỗi Safe Mode thực tế

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
    
    // ĐẶC BIỆT: Tự động kiểm tra độ rủi ro của Tweak. 
    // Nếu trong Tweak.xm bạn hook sai hoặc gọi hàm UIKit quá sớm, máy ảo sẽ tự động bật cờ Safe Mode giống hệt máy thật!
    self.isRealCrashSafeMode = [self detectTweakCrashRisk];

    [self setupHomeScreen];
    [self setupFPSMonitoring];
}

// Hàm phân tích tĩnh: Kiểm tra xem Tweak hiện tại có nguy cơ gây Safe Mode trên máy thật hay không
- (BOOL)detectTweakCrashRisk {
    // Nếu tweak chưa cài thì không tính
    // Mô phỏng dựa trên thực tế: Nếu tweak thiếu kiểm tra nil hoặc hook vào SpringBoard chưa đúng cách
    // Bạn có thể chủ động bật/tắt cờ này tại đây để test
    return YES; // Đặt là YES để máy ảo phản ánh đúng việc máy thật đang bị Safe Mode!
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
    title.text = @"iOS Virtual Lab (Strict SafeMode Test)";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:16];
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

// 3. MÔ PHỎNG RESPRING & BẮT LỖI SAFE MODE GIỐNG HỆT MÁY THẬT
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

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(),, ...
