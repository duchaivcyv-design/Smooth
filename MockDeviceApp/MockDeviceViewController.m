#import "MockDeviceViewController.h"
#import <mach/mach.h>
#import <WebKit/WebKit.h>
#import <Photos/Photos.h>

@interface MockDeviceViewController () <WKNavigationDelegate, UITableViewDelegate, UITableViewDataSource, UICollectionViewDelegate, UICollectionViewDataSource, UIGestureRecognizerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

// Màn hình chính & Container
@property (nonatomic, strong) UIImageView *wallpaperImageView;
@property (nonatomic, strong) UIView *springBoardContainer;
@property (nonatomic, strong) UIView *dynamicIslandView;
@property (nonatomic, strong) UIView *activeAppWindow;
@property (nonatomic, strong) UIView *rebootCurtainView;

// Các phân vùng file mô phỏng Rootless Jailbreak (/var/jb/)
@property (nonatomic, strong) NSMutableDictionary *rootlessFileSystem;
@property (nonatomic, strong) NSString *currentPath;

// Trạng thái hệ thống & Jailbreak
@property (nonatomic, assign) BOOL isJailbroken;
@property (nonatomic, assign) BOOL isDynamicIslandExpanded;
@property (nonatomic, strong) UITextView *exploitConsoleView;
@property (nonatomic, strong) UITableView *sileoTableView;
@property (nonatomic, strong) UITableView *fileManagerTableView;
@property (nonatomic, strong) NSArray *currentDirectoryFiles;

// Giám sát FPS & Hiệu năng
@property (nonatomic, strong) CADisplayLink *fpsDisplayLink;
@property (nonatomic, strong) UILabel *fpsCounterLabel;
@property (nonatomic, assign) CFTimeInterval lastTimestamp;
@property (nonatomic, assign) NSInteger frameCount;
@end

@implementation MockDeviceViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.isJailbroken = NO;
    self.currentPath = @"/var/jb";

    // Khởi tạo hệ thống file rootless thực tế
    [self initializeRootlessFileSystem];
    
    // Thiết lập giao diện cơ sở iOS 17
    [self setupWallpaperAndBackground];
    [self setupDynamicIsland];
    [self setupSpringBoardGrid];
    [self setupDockBar];
    [self setupGesturesAndOverlays];
    [self setupFPSMonitoring];
}

#pragma mark - 1. HỆ THỐNG FILE ROOTLESS & BỘ NHỚ (/var/jb)
- (void)initializeRootlessFileSystem {
    self.rootlessFileSystem = [NSMutableDictionary dictionary];
    
    // Phân vùng hệ thống gốc và rootless jailbreak
    self.rootlessFileSystem[@"/var/jb"] = @[
        @{@"name": @"Library", @"type": @"dir", @"desc": @"Thư viện dylib & tweak core"},
        @{@"name": @"bin", @"type": @"dir", @"desc": @"Các lệnh thực thi terminal"},
        @{@"name": @"usr", @"type": @"dir", @"desc": @"Share và dynamic frameworks"},
        @{@"name": @"TweakSupport", @"type": @"dir", @"desc": @"Cấu hình cấu trúc MobileSubstrate"}
    ];
    
    self.rootlessFileSystem[@"/var/jb/Library"] = @[
        @{@"name": @"MobileSubstrate", @"type": @"dir", @"desc": @"Thư mục chứa dylib hook tweak"},
        @{@"name": @"PreferenceBundles", @"type": @"dir", @"desc": @"Giao diện cài đặt tweak trong Settings"},
        @{@"name": @"Themes", @"type": @"dir", @"desc": @"Các bộ sưu tập giao diện Anemone/SnowBoard"}
    ];
    
    self.rootlessFileSystem[@"/var/jb/Library/MobileSubstrate"] = @[
        @{@"name": @"BoostiPhone6sCore.dylib", @"type": @"file", @"desc": @"Dylib chính của dự án tweak"},
        @{@"name": @"SafeMode.dylib", @"type": @"file", @"desc": @"Mô đun bảo vệ chống crash hệ thống"}
    ];
    
    self.rootlessFileSystem[@"/System/Library"] = @[
        @{@"name": @"CoreServices", @"type": @"dir", @"desc": @"SpringBoard và hệ thống lõi iOS 17"},
        @{@"name": @"Frameworks", @"type": @"dir", @"desc": @"UIKit, Foundation và WebKit frameworks"}
    ];
    
    self.currentDirectoryFiles = self.rootlessFileSystem[@"/var/jb"];
}

#pragma mark - 2. GIAO DIỆN MÀN HÌNH CHÍNH & HÌNH NỀN GỐC iOS 17
- (void)setupWallpaperAndBackground {
    self.wallpaperImageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    // Hình nền mặc định iOS 17 chính hãng (Tông màu xanh đậm sâu thẳm)
    self.wallpaperImageView.backgroundColor = [UIColor colorWithRed:0.08 green:0.14 blue:0.26 alpha:1.0];
    self.wallpaperImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.wallpaperImageView.userInteractionEnabled = YES;
    [self.view addSubview:self.wallpaperImageView];

    // Status Bar tiêu chuẩn iPhone 14 Pro
    UILabel *statusBar = [[UILabel alloc] initWithFrame:CGRectMake(28, 14, self.view.bounds.size.width - 56, 20)];
    statusBar.text = @"09:41                          5G 🔋 100%";
    statusBar.textColor = [UIColor whiteColor];
    statusBar.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [self.view addSubview:statusBar];
}

- (void)setupSpringBoardGrid {
    if (self.springBoardContainer) {
        [self.springBoardContainer removeFromSuperview];
    }

    self.springBoardContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 55, self.view.bounds.size.width, self.view.bounds.size.height - 160)];
    [self.view addSubview:self.springBoardContainer];

    // Danh sách toàn bộ ứng dụng hệ thống và công cụ jailbreak
    NSMutableArray *apps = [NSMutableArray arrayWithArray:@[
        @{@"name": @"Dopamine", @"color": [UIColor colorWithRed:0.05 green:0.05 blue:0.08 alpha:1.0], @"action": @selector(openDopamineJailbreakApp)},
        @{@"name": @"Cài Đặt", @"color": [UIColor colorWithRed:0.45 green:0.45 blue:0.5 alpha:1.0], @"action": @selector(openSettingsApp)},
        @{@"name": @"Safari", @"color": [UIColor colorWithRed:0.1 green:0.6 blue:0.9 alpha:1.0], @"action": @selector(openSafariBrowser)},
        @{@"name": @"YouTube", @"color": [UIColor colorWithRed:0.95 green:0.15 blue:0.15 alpha:1.0], @"action": @selector(openYouTubeBrowser)},
        @{@"name": @"Ảnh", @"color": [UIColor colorWithRed:0.95 green:0.5 blue:0.1 alpha:1.0], @"action": @selector(openPhotosApp)},
        @{@"name": @"Tệp (Files)", @"color": [UIColor colorWithRed:0.25 green:0.65 blue:0.35 alpha:1.0], @"action": @selector(openFilesManagerApp)},
        @{@"name": @"App Store", @"color": [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0], @"action": @selector(openAppStoreApp)},
        @{@"name": @"Máy Ảnh", @"color": [UIColor colorWithRed:0.3 green:0.3 blue:0.35 alpha:1.0], @"action": @selector(openCameraApp)},
        @{@"name": @"Ghi Chú", @"color": [UIColor colorWithRed:0.98 green:0.8 blue:0.15 alpha:1.0], @"action": @selector(openNotesApp)},
        @{@"name": @"Thời Tiết", @"color": [UIColor colorWithRed:0.2 green:0.5 blue:0.95 alpha:1.0], @"action": @selector(openWeatherApp)}
    ]];

    // Sau khi Jailbreak thành công, tự động mở khóa Sileo và TrollStore
    if (self.isJailbroken) {
        [apps insertObject:@{@"name": @"Sileo", @"color": [UIColor colorWithRed:0.12 green:0.52 blue:0.82 alpha:1.0], @"action": @selector(openSileoApp)} atIndex:1];
        [apps insertObject:@{@"name": @"TrollStore", @"color": [UIColor colorWithRed:0.92 green:0.45 blue:0.08 alpha:1.0], @"action": @selector(openTrollStoreApp)} atIndex:2];
    }

    CGFloat size = 66;
    CGFloat startX = 28;
    CGFloat startY = 20;
    CGFloat spacingX = 22;
    CGFloat spacingY = 26;

    for (int i = 0; i < apps.count; i++) {
        NSDictionary *app = apps[i];
        int r = i / 4;
        int c = i % 4;
        CGFloat x = startX + c * (size + spacingX);
        CGFloat y = startY + r * (size + spacingY + 16);

        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(x, y, size, size);
        btn.backgroundColor = app[@"color"];
        btn.layer.cornerRadius = 16;
        btn.layer.shadowColor = [UIColor blackColor].CGColor;
        btn.layer.shadowOpacity = 0.4;
        btn.layer.shadowOffset = CGSizeMake(0, 4);
        
        SEL actionSel = NSSelectorFromString(app[@"action"]);
        [btn addTarget:self action:actionSel forControlEvents:UIControlEventTouchUpInside];

        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(-10, size + 4, size + 20, 16)];
        lbl.text = app[@"name"];
        lbl.textColor = [UIColor whiteColor];
        lbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        lbl.textAlignment = NSTextAlignmentCenter;
        [btn addSubview:lbl];

        [self.springBoardContainer addSubview:btn];
    }
}

- (void)setupDockBar {
    UIView *dock = [[UIView alloc] initWithFrame:CGRectMake(16, self.view.bounds.size.height - 105, self.view.bounds.size.width - 32, 88)];
    dock.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.22];
    dock.layer.cornerRadius = 28;
    dock.clipsToBounds = YES;
    [self.view addSubview:dock];

    NSArray *dockApps = @[
        @{@"name": @"Phone", @"color": [UIColor colorWithRed:0.1 green:0.85 blue:0.35 alpha:1.0], @"action": @selector(openPhoneApp)},
        @{@"name": @"Safari", @"color": [UIColor colorWithRed:0.1 green:0.6 blue:0.9 alpha:1.0], @"action": @selector(openSafariBrowser)},
        @{@"name": @"Messages", @"color": [UIColor colorWithRed:0.15 green:0.65 blue:1.0 alpha:1.0], @"action": @selector(openMessagesApp)},
        @{@"name": @"Music", @"color": [UIColor colorWithRed:0.98 green:0.2 blue:0.55 alpha:1.0], @"action": @selector(openMusicApp)}
    ];

    for (int i = 0; i < dockApps.count; i++) {
        NSDictionary *app = dockApps[i];
        CGFloat dx = 14 + i * 84;
        UIButton *dBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        dBtn.frame = CGRectMake(dx, 10, 68, 68);
        dBtn.backgroundColor = app[@"color"];
        dBtn.layer.cornerRadius = 16;
        SEL actionSel = NSSelectorFromString(app[@"action"]);
        [dBtn addTarget:self action:actionSel forControlEvents:UIControlEventTouchUpInside];
        [dock addSubview:dBtn];
    }
}

#pragma mark - 3. DYNAMIC ISLAND IPHONE 14 PRO CHUẨN ĐỘNG
- (void)setupDynamicIsland {
    self.dynamicIslandView = [[UIView alloc] initWithFrame:CGRectMake((self.view.bounds.size.width - 122)/2, 10, 122, 34)];
    self.dynamicIslandView.backgroundColor = [UIColor blackColor];
    self.dynamicIslandView.layer.cornerRadius = 17;
    self.dynamicIslandView.clipsToBounds = YES;

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleDynamicIsland)];
    [self.dynamicIslandView addGestureRecognizer:tap];

    UILabel *lbl = [[UILabel alloc] initWithFrame:self.dynamicIslandView.bounds];
    lbl.text = self.isJailbroken ? @"🟢 Dopamine Active" : @"🟢 iOS 17 Ready";
    lbl.textColor = [UIColor whiteColor];
    lbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    lbl.textAlignment = NSTextAlignmentCenter;
    [self.dynamicIslandView addSubview:lbl];

    [self.view addSubview:self.dynamicIslandView];
}

- (void)toggleDynamicIsland {
    self.isDynamicIslandExpanded = !self.isDynamicIslandExpanded;
    [UIView animateWithDuration:0.45 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:0.6 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        if (self.isDynamicIslandExpanded) {
            self.dynamicIslandView.frame = CGRectMake((self.view.bounds.size.width - 300)/2, 8, 300, 92);
            self.dynamicIslandView.layer.cornerRadius = 26;
        } else {
            self.dynamicIslandView.frame = CGRectMake((self.view.bounds.size.width - 122)/2, 10, 122, 34);
            self.dynamicIslandView.layer.cornerRadius = 17;
        }
    } completion:nil];
}

#pragma mark - 4. CỬ CHỈ TRUNG TÂM THÔNG BÁO & NHẤN GIỮ ĐỔI HÌNH NỀN
- (void)setupGesturesAndOverlays {
    // Vuốt từ trên xuống xem Trung tâm thông báo
    UISwipeGestureRecognizer *downSwipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(openNotificationCenter)];
    downSwipe.direction = UISwipeGestureRecognizerDirectionDown;
    [self.view addGestureRecognizer:downSwipe];
}

- (void)openNotificationCenter {
    UIView *notifWindow = [[UIView alloc] initWithFrame:CGRectMake(0, -self.view.bounds.size.height, self.view.bounds.size.width, self.view.bounds.size.height)];
    notifWindow.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.9];
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(30, 80, self.view.bounds.size.width - 60, 30)];
    title.text = @"🔔 Trung Tâm Thông Báo iOS 17";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:18];
    [notifWindow addSubview:title];

    // Nút đổi hình nền trực tiếp tại trung tâm thông báo
    UIButton *changeWallBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    changeWallBtn.frame = CGRectMake(30, 140, self.view.bounds.size.width - 60, 48);
    [changeWallBtn setTitle:@"🖼️ Đổi Hình Nền Thật iOS 17" forState:UIControlStateNormal];
    [changeWallBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    changeWallBtn.backgroundColor = [UIColor colorWithRed:0.2 green:0.5 blue:0.9 alpha:1.0];
    changeWallBtn.layer.cornerRadius = 12;
    [changeWallBtn addTarget:self action:@selector(promptChangeWallpaper) forControlEvents:UIControlEventTouchUpInside];
    [notifWindow addSubview:changeWallBtn];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(30, self.view.bounds.size.height - 140, self.view.bounds.size.width - 60, 44);
    [closeBtn setTitle:@"Đóng" forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(closeActiveWindow:) forControlEvents:UIControlEventTouchUpInside];
    [notifWindow addSubview:closeBtn];

    [self.view addSubview:notifWindow];
    [UIView animateWithDuration:0.3 animations:^{
        notifWindow.frame = self.view.bounds;
    }];
    self.activeAppWindow = notifWindow;
}

- (void)promptChangeWallpaper {
    NSArray *wallpapers = @[
        @{@"name": @"iOS 17 Blue Deep", @"color": [UIColor colorWithRed:0.08 green:0.14 blue:0.26 alpha:1.0]},
        @{@"name": @"Sunset Purple", @"color": [UIColor colorWithRed:0.35 green:0.12 blue:0.38 alpha:1.0]},
        @{@"name": @"Space Black", @"color": [UIColor colorWithRed:0.03 green:0.03 blue:0.05 alpha:1.0]},
        @{@"name": @"Emerald Green", @"color": [UIColor colorWithRed:0.05 green:0.25 blue:0.18 alpha:1.0]}
    ];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Chọn Hình Nền iOS 17" message:@"Chọn tông màu nền chính hãng" preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary *w in wallpapers) {
        [alert addAction:[UIAlertAction actionWithTitle:w[@"name"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            self.wallpaperImageView.backgroundColor = w[@"color"];
            [self closeActiveWindow:nil];
            [self showToastNotice:@"✅ Đã cập nhật hình nền hệ thống!"];
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - 5. APP DOPAMINE JAILBREAK & QUÁ TRÌNH KHAI THÁC KERNEL
- (void)openDopamineJailbreakApp {
    UIView *dopamineView = [[UIView alloc] initWithFrame:self.view.bounds];
    dopamineView.backgroundColor = [UIColor colorWithRed:0.04 green:0.04 blue:0.07 alpha:1.0];
    [self.view addSubview:dopamineView];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 70, self.view.bounds.size.width - 40, 40)];
    title.text = self.isJailbroken ? @"Dopamine (Đã Jailbreak Rootless)" : @"Dopamine v2.0 (iOS 17.0 Supported)";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:18];
    title.textAlignment = NSTextAlignmentCenter;
    [dopamineView addSubview:title];

    self.exploitConsoleView = [[UITextView alloc] initWithFrame:CGRectMake(20, 130, self.view.bounds.size.width - 40, self.view.bounds.size.height - 280)];
    self.exploitConsoleView.backgroundColor = [UIColor colorWithRed:0.02 green:0.02 blue:0.04 alpha:1.0];
    self.exploitConsoleView.textColor = [UIColor colorWithRed:0.2 green:0.9 blue:0.4 alpha:1.0];
    self.exploitConsoleView.font = [UIFont fontWithName:@"Courier" size:12];
    self.exploitConsoleView.layer.cornerRadius = 12;
    self.exploitConsoleView.editable = NO;
    self.exploitConsoleView.text = self.isJailbroken ? @"> Môi trường Rootless /var/jb đã sẵn sàng.\n> Không phát hiện xung đột dylib." : @"> Sẵn sàng khai thác kernel...\n> Nhấn 'Jailbreak' để tiến hành vá phân vùng.";
    [dopamineView addSubview:self.exploitConsoleView];

    UIButton *jbBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    jbBtn.frame = CGRectMake(30, self.view.bounds.size.height - 120, self.view.bounds.size.width - 60, 50);
    [jbBtn setTitle:self.isJailbroken ? @"Đã Jailbreak Thành Công" : @"Jailbreak Ngay" forState:UIControlStateNormal];
    [jbBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    jbBtn.backgroundColor = self.isJailbroken ? [UIColor darkGrayColor] : [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:1.0];
    jbBtn.layer.cornerRadius = 14;
    [jbBtn addTarget:self action:@selector(executeDopamineExploit) forControlEvents:UIControlEventTouchUpInside];
    [dopamineView addSubview:jbBtn];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(20, 40, 60, 30);
    [closeBtn setTitle:@"Đóng" forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(closeActiveWindow:) forControlEvents:UIControlEventTouchUpInside];
    [dopamineView addSubview:closeBtn];

    self.activeAppWindow = dopamineView;
}

- (void)executeDopamineExploit {
    if (self.isJailbroken) {
        [self showToastNotice:@"Hệ thống đã được Jailbreak từ trước!"];
        return;
    }

    self.exploitConsoleView.text = @"> [+] Khởi tạo tiến trình Dopamine Exploit...\n";
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.exploitConsoleView.text = [self.exploitConsoleView.text stringByAppendingString:@"> [+] Cấp phát bộ nhớ đệm Kernel R/W thành công!\n> [+] Bypass PAC và PTRAuth hoàn tất.\n"];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.exploitConsoleView.text = [self.exploitConsoleView.text stringByAppendingString:@"> [+] Tạo cấu trúc phân vùng Rootless tại /var/jb...\n> [+] Tiêm bootstrap Sileo và dylib core...\n> [🎂] KHAI THÁC THÀNH CÔNG! Đang chuẩn bị Reboot...\n"];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self closeActiveWindow:nil];
        [self simulateRealSystemReboot];
    });
}

- (void)simulateRealSystemReboot {
    self.rebootCurtainView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.rebootCurtainView.backgroundColor = [UIColor blackColor];
    
    UILabel *appleLogo = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    appleLogo.center = self.rebootCurtainView.center;
    appleLogo.text = @"";
    appleLogo.textColor = [UIColor whiteColor];
    appleLogo.font = [UIFont systemFontOfSize:80 weight:UIFontWeightLight];
    appleLogo.textAlignment = NSTextAlignmentCenter;
    [self.rebootCurtainView addSubview:appleLogo];

    [self.view addSubview:self.rebootCurtainView];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.5 animations:^{
            self.rebootCurtainView.alpha = 0;
        } completion:^(BOOL finished) {
            [self.rebootCurtainView removeFromSuperview];
            self.rebootCurtainView = nil;

            self.isJailbroken = YES;
            [self setupSpringBoardGrid];
            [self showToastNotice:@"🚀 Thiết bị đã khởi động vào môi trường Jailbreak iOS 17!"];
        }];
    });
}

#pragma mark - 6. KHO SILEO & TRÌNH QUẢN LÝ TỆP ROOTLESS (Files /var/jb)
- (void)openSileoApp {
    UIView *sileoView = [[UIView alloc] initWithFrame:self.view.bounds];
    sileoView.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.08 alpha:1.0];
    [self.view addSubview:sileoView];

    UILabel *header = [[UILabel alloc] initWithFrame:CGRectMake(20, 60, self.view.bounds.size.width - 40, 40)];
    header.text = @"📦 Sileo Package Manager";
    header.textColor = [UIColor whiteColor];
    header.font = [UIFont boldSystemFontOfSize:20];
    [sileoView addSubview:header];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(self.view.bounds.size.width - 80, 65, 60, 30);
    [closeBtn setTitle:@"Đóng" forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(closeActiveWindow:) forControlEvents:UIControlEventTouchUpInside];
    [sileoView addSubview:closeBtn];

    self.sileoTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 120, self.view.bounds.size.width, self.view.bounds.size.height - 120) style:UITableViewStyleInsetGrouped];
    self.sileoTableView.backgroundColor = [UIColor clearColor];
    self.sileoTableView.delegate = self;
    self.sileoTableView.dataSource = self;
    [sileoView addSubview:self.sileoTableView];

    self.activeAppWindow = sileoView;
}

// Trình quản lý Tệp (/var/jb system file explorer)
- (void)openFilesManagerApp {
    UIView *filesView = [[UIView alloc] initWithFrame:self.view.bounds];
    filesView.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.12 alpha:1.0];
    [self.view addSubview:filesView];

    UILabel *header = [[UILabel alloc] initWithFrame:CGRectMake(20, 60, self.view.bounds.size.width - 40, 40)];
    header.text = [NSString stringWithFormat:@"📁 File: %@", self.currentPath];
    header.textColor = [UIColor whiteColor];
    header.font = [UIFont boldSystemFontOfSize:16];
    [filesView addSubview:header];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(self.view.bounds.size.width - 80, 65, 60, 30);
    [closeBtn setTitle:@"Đóng" forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(closeActiveWindow:) forControlEvents:UIControlEventTouchUpInside];
    [filesView addSubview:closeBtn];

    self.fileManagerTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 110, self.view.bounds.size.width, self.view.bounds.size.height - 110) style:UITableViewStyleInsetGrouped];
    self.fileManagerTableView.backgroundColor = [UIColor clearColor];
    self.fileManagerTableView.delegate = self;
    self.fileManagerTableView.dataSource = self;
    [filesView addSubview:self.fileManagerTableView];

    self.activeAppWindow = filesView;
}

#pragma mark - TableView DataSource cho Sileo & File Explorer
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView == self.sileoTableView) return 3;
    return self.currentDirectoryFiles.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"Cell"];
    }
    cell.backgroundColor = [UIColor colorWithRed:0.14 green:0.14 blue:0.2 alpha:1.0];
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.detailTextLabel.textColor = [UIColor lightGrayColor];

    if (tableView == self.sileoTableView) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"BoostiPhone6s Core Tweak";
            cell.detailTextLabel.text = @"Phiên bản 28.7 Pro • Rootless Activated";
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Orion for iOS 17";
            cell.detailTextLabel.text = @"Tùy biến giao diện toàn hệ thống";
        } else {
            cell.textLabel.text = @"AppStore++";
            cell.detailTextLabel.text = @"Quản lý hạ cấp phiên bản ứng dụng";
        }
    } else {
        NSDictionary *item = self.currentDirectoryFiles[indexPath.row];
        cell.textLabel.text = item[@"name"];
        cell.detailTextLabel.text = item[@"desc"];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (tableView == self.sileoTableView) {
        [self showToastNotice:@"✅ Tweak đã được nạp thành công vào tiến trình!"];
    } else {
        NSDictionary *item = self.currentDirectoryFiles[indexPath.row];
        if ([item[@"type"] isEqualToString:@"dir"]) {
            NSString *newPath = [NSString stringWithFormat:@"%@/%@", self.currentPath, item[@"name"]];
            if (self.rootlessFileSystem[newPath]) {
                self.currentPath = newPath;
                self.currentDirectoryFiles = self.rootlessFileSystem[newPath];
                [self.fileManagerTableView reloadData];
            } else {
                [self showToastNotice:@"📂 Thư mục trống hoặc được mã hóa bảo mật."];
            }
        }
    }
}

#pragma mark - 7. TRÌNH DUYỆT WEB, YOUTUBE VÀ APP MẶC ĐỊNH
- (void)openSafariBrowser { [self openWebBrowserWithURL:@"https://www.google.com"]; }
- (void)openYouTubeBrowser { [self openWebBrowserWithURL:@"https://www.youtube.com/embed/jfKfPfyJRdk?autoplay=1"]; }
- (void)openAppStoreApp { [self openWebBrowserWithURL:@"https://www.apple.com"]; }

- (void)openWebBrowserWithURL:(NSString *)urlString {
    UIView *browserView = [[UIView alloc] initWithFrame:self.view.bounds];
    browserView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:browserView];

    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.allowsInlineMediaPlayback = YES;
    WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 60, browserView.bounds.size.width, browserView.bounds.size.height - 60) configuration:config];
    [webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlString]]];
    [browserView addSubview:webView];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(20, 20, 60, 30);
    [closeBtn setTitle:@"Thoát" forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(closeActiveWindow:) forControlEvents:UIControlEventTouchUpInside];
    [browserView addSubview:closeBtn];

    self.activeAppWindow = browserView;
}

- (void)openSettingsApp { [self showToastNotice:@"⚙️ Đã mở Cài đặt hệ thống iOS 17.0"]; }
- (void)openPhotosApp { [self showToastNotice:@"🖼️ Đã mở Thư viện Ảnh iCloud"]; }
- (void)openCameraApp { [self showToastNotice:@"📸 Máy ảnh chuẩn ProRAW sẵn sàng"]; }
- (void)openNotesApp { [self showToastNotice:@"📝 Ghi chú đồng bộ iCloud"]; }
- (void)openWeatherApp { [self showToastNotice:@"⛅ Thời tiết Hà Nội: 28°C • Trời trong xanh"]; }
- (void)openPhoneApp { [self showToastNotice:@"📞 Đang mở ứng dụng Điện thoại"]; }
- (void)openMessagesApp { [self showToastNotice:@"💬 Đang mở Tin nhắn iMessage"]; }
- (void)openMusicApp { [self showToastNotice:@"🎵 Đang phát Apple Music Lossless"]; }
- (void)openTrollStoreApp { [self showToastNotice:@"⚡ TrollStore Persistent Installer hoạt động"]; }

- (void)closeActiveWindow:(UIButton *)sender {
    [UIView animateWithDuration:0.25 animations:^{
        self.activeAppWindow.alpha = 0;
    } completion:^(BOOL finished) {
        [self.activeAppWindow removeFromSuperview];
        self.activeAppWindow = nil;
        self.currentPath = @"/var/jb";
        self.currentDirectoryFiles = self.rootlessFileSystem[@"/var/jb"];
    }];
}

#pragma mark - 8. GIÁM SÁT FPS MẶC ĐỊNH
- (void)setupFPSMonitoring {
    self.fpsCounterLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - 110, 42, 90, 20)];
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
    UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(20, self.view.bounds.size.height - 130, self.view.bounds.size.width - 40, 36)];
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
