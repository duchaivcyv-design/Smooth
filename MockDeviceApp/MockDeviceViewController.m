#import "MockDeviceViewController.h"
#import <mach/mach.h>
#import <WebKit/WebKit.h>

@interface MockDeviceViewController () <WKNavigationDelegate, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, UITextFieldDelegate>

// View Containers Chính
@property (nonatomic, strong) UIImageView *wallpaperImageView;
@property (nonatomic, strong) UIView *springBoardContainer;
@property (nonatomic, strong) UIView *dynamicIslandView;
@property (nonatomic, strong) UIView *activeAppWindow;
@property (nonatomic, strong) UIView *homeIndicatorBar;
@property (nonatomic, strong) UILabel *dynamicIslandLabel;

// Sileo System
@property (nonatomic, strong) UIView *sileoContainerView;
@property (nonatomic, strong) UIView *sileoTabBar;
@property (nonatomic, strong) UITableView *sileoTableView;
@property (nonatomic, strong) UISearchBar *sileoSearchBar;
@property (nonatomic, assign) NSInteger sileoSelectedTab; // 0: Đặc sắc, 1: Mới, 2: Nguồn, 3: Gói, 4: Tìm Kiếm
@property (nonatomic, strong) NSMutableArray *featuredList;
@property (nonatomic, strong) NSMutableArray *newsList;
@property (nonatomic, strong) NSMutableArray *sourceList;
@property (nonatomic, strong) NSMutableArray *installedPackages;
@property (nonatomic, strong) NSMutableArray *filteredSearchList;

// Safari & Web Engine
@property (nonatomic, strong) WKWebView *safariWebView;
@property (nonatomic, strong) UITextField *urlAddressField;

// Cây thư mục Filza & File System (/var/jb)
@property (nonatomic, strong) NSMutableDictionary *virtualFS;
@property (nonatomic, strong) NSString *currentFSPath;
@property (nonatomic, strong) UITableView *filzaTableView;

// Danh sách icon SpringBoard động
@property (nonatomic, strong) NSMutableArray *springBoardApps;

// Trạng thái hệ thống & Tweak Core
@property (nonatomic, assign) BOOL isJailbroken;
@property (nonatomic, assign) BOOL isFilzaInstalled;
@property (nonatomic, assign) BOOL isSafeModeEnabled;
@property (nonatomic, strong) CADisplayLink *fpsDisplayLink;
@property (nonatomic, strong) UILabel *fpsCounterLabel;
@property (nonatomic, assign) CFTimeInterval lastTimestamp;
@property (nonatomic, assign) NSInteger frameCount;

@end

@implementation MockDeviceViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.isJailbroken = YES;
    self.isFilzaInstalled = NO;
    self.isSafeModeEnabled = NO;
    self.sileoSelectedTab = 0;
    self.currentFSPath = @"/var/jb";

    [self initializeVirtualFileSystem];
    [self initializeSileoDatabase];
    [self setupWallpaperAndStatusBar];
    [self setupDynamicIsland];
    [self setupSpringBoardGrid];
    [self setupDockBar];
    [self setupHomeIndicator];
    [self setupFPSMonitoring];
}

#pragma mark - 1. CƠ SỞ DỮ LIỆU SILEO & HỆ THỐNG FILE ROOTLESS
- (void)initializeVirtualFileSystem {
    self.virtualFS = [NSMutableDictionary dictionary];
    self.virtualFS[@"/var/jb"] = [NSMutableArray arrayWithArray:@[
        @{@"name": @"Library", @"type": @"dir", @"desc": @"Thư mục Framework & Dylib Rootless"},
        @{@"name": @"bin", @"type": @"dir", @"desc": @"Công cụ dòng lệnh dpkg, apt, bash"},
        @{@"name": @"usr", @"type": @"dir", @"desc": @"Dữ liệu chia sẻ hệ thống"},
        @{@"name": @"etc", @"type": @"dir", @"desc": @"Cấu hình bootstrap"}
    ]];
    self.virtualFS[@"/var/jb/Library"] = [NSMutableArray arrayWithArray:@[
        @{@"name": @"MobileSubstrate", @"type": @"dir", @"desc": @"Môi trường nạp tweak (TweakLoader)"},
        @{@"name": @"PreferenceBundles", @"type": @"dir", @"desc": @"Tweak menu trong Settings"},
        @{@"name": @"Themes", @"type": @"dir", @"desc": @"SnowBoard icon themes"}
    ]];
    self.virtualFS[@"/var/jb/Library/MobileSubstrate"] = [NSMutableArray arrayWithArray:@[
        @{@"name": @"DynamicLibraries", @"type": @"dir", @"desc": @"Nơi chứa dylib của các tweak đã kích hoạt"}
    ]];
    self.virtualFS[@"/var/jb/Library/MobileSubstrate/DynamicLibraries"] = [NSMutableArray arrayWithArray:@[
        @{@"name": @"BoostiPhone6sCore.dylib", @"type": @"file", @"desc": @"Tweak lõi tối ưu hiệu năng"},
        @{@"name": @"BoostiPhone6sCore.plist", @"type": @"file", @"desc": @"Bộ lọc filter bundle SpringBoard"}
    ]];
}

- (void)initializeSileoDatabase {
    self.featuredList = [NSMutableArray arrayWithArray:@[
        @{@"id": @"com.korboy.fleq", @"name": @"FLEQ", @"author": @"Korboy • 1.0.3", @"price": @"NHẬN", @"desc": @"Hiển thị visualizer âm thanh sống động trên Dynamic Island", @"installed": @NO},
        @{@"id": @"com.tigisoftware.filza", @"name": @"FilzaEnhanced", @"author": @"Korboy • 1.0.7.4", @"price": @"NHẬN", @"desc": @"Trình quản lý tệp tin quyền root tối thượng cho iOS", @"installed": @NO},
        @{@"id": @"com.cemck.killxpro", @"name": @"KillX Pro Neo", @"author": @"cemck • 3.0.1", @"price": @"$3.49", @"desc": @"Cử chỉ vuốt 1 chạm đóng toàn bộ đa nhiệm", @"installed": @NO},
        @{@"id": @"com.twickd.doodle", @"name": @"Doodle", @"author": @"twickd • 1.1.2", @"price": @"NHẬN", @"desc": @"Vẽ trực tiếp lên màn hình khoá iOS 17", @"installed": @NO}
    ]];

    self.newsList = [NSMutableArray arrayWithArray:@[
        @{@"name": @"26Home", @"author": @"ngkhoi • 1.3.14", @"desc": @"iOS 26 Style liquid glass SpringBoard beautification"},
        @{@"name": @"Actra", @"author": @"mlgm • 1.0", @"desc": @"Trình tự động hoá cử chỉ gesture và action"},
        @{@"name": @"Adytum", @"author": @"Kernelrw • 2.0 • Chariz", @"desc": @"Kiểm soát luồng chạy ngầm của các app"},
        @{@"name": @"AppData", @"author": @"Fouad Raheb • 1.3.7", @"desc": @"Vuốt icon xem dung lượng và xoá bộ nhớ đệm"}
    ]];

    self.sourceList = [NSMutableArray arrayWithArray:@[
        @{@"name": @"Tất cả gói", @"url": @"Xem tất cả các gói từ các nguồn của bạn", @"count": @"115"},
        @{@"name": @"Korboy's Repo", @"url": @"https://korboybeats.github.io/", @"count": @"2"},
        @{@"name": @"BigBoss", @"url": @"http://apt.thebigboss.org/repofiles/cydia/", @"count": @"18"},
        @{@"name": @"BVN Repo", @"url": @"https://bvnrepo.xyz/", @"count": @"4"},
        @{@"name": @"Chariz", @"url": @"https://repo.chariz.com/", @"count": @"12"},
        @{@"name": @"ElleKit", @"url": @"https://ellekit.space/", @"count": @"1"}
    ]];

    self.installedPackages = [NSMutableArray arrayWithArray:@[
        @{@"name": @"SmoothIOS Pro", @"author": @"TaoJB, NoJB • 1.2.0-2a", @"desc": @"Dynamic 120Hz refresh rate, zero stutter"},
        @{@"name": @"ElleKit Substrate", @"author": @"ElleKit Team • 1.1.1", @"desc": @"Hooking framework cho iOS 17 Rootless"},
        @{@"name": @"libxxhash0", @"author": @"Procursus Team • 0.8.2", @"desc": @"Thư viện thuật toán băm cực nhanh"},
        @{@"name": @"debianutils", @"author": @"Procursus Team • 5.19", @"desc": @"Bộ công cụ dòng lệnh quản lý package"}
    ]];

    self.filteredSearchList = [NSMutableArray arrayWithArray:self.featuredList];
}

#pragma mark - 2. SPRINGBOARD & DYNAMIC ISLAND
- (void)setupWallpaperAndStatusBar {
    self.wallpaperImageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    self.wallpaperImageView.backgroundColor = [UIColor colorWithRed:0.06 green:0.10 blue:0.18 alpha:1.0];
    self.wallpaperImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.wallpaperImageView.userInteractionEnabled = YES;
    [self.view addSubview:self.wallpaperImageView];

    UILabel *statusBar = [[UILabel alloc] initWithFrame:CGRectMake(28, 14, self.view.bounds.size.width - 56, 20)];
    statusBar.text = @"09:41                          5G 🔋 100%";
    statusBar.textColor = [UIColor whiteColor];
    statusBar.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [self.view addSubview:statusBar];
}

- (void)setupDynamicIsland {
    self.dynamicIslandView = [[UIView alloc] initWithFrame:CGRectMake((self.view.bounds.size.width - 126)/2, 10, 126, 34)];
    self.dynamicIslandView.backgroundColor = [UIColor blackColor];
    self.dynamicIslandView.layer.cornerRadius = 17;
    self.dynamicIslandView.clipsToBounds = YES;
    self.dynamicIslandView.userInteractionEnabled = YES;

    self.dynamicIslandLabel = [[UILabel alloc] initWithFrame:self.dynamicIslandView.bounds];
    self.dynamicIslandLabel.text = @"🟢 Dopamine Active";
    self.dynamicIslandLabel.textColor = [UIColor whiteColor];
    self.dynamicIslandLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    self.dynamicIslandLabel.textAlignment = NSTextAlignmentCenter;
    [self.dynamicIslandView addSubview:self.dynamicIslandLabel];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleDynamicIslandAnimation)];
    [self.dynamicIslandView addGestureRecognizer:tap];

    [self.view addSubview:self.dynamicIslandView];
}

- (void)toggleDynamicIslandAnimation {
    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:0.6 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        if (self.dynamicIslandView.bounds.size.width < 200) {
            self.dynamicIslandView.frame = CGRectMake((self.view.bounds.size.width - 310)/2, 8, 310, 88);
            self.dynamicIslandView.layer.cornerRadius = 24;
            self.dynamicIslandLabel.frame = self.dynamicIslandView.bounds;
            self.dynamicIslandLabel.text = @"⚡ Tweak Core: Running at 60 FPS\n🌐 Network: Online • Latency: 4ms";
            self.dynamicIslandLabel.numberOfLines = 2;
        } else {
            self.dynamicIslandView.frame = CGRectMake((self.view.bounds.size.width - 126)/2, 10, 126, 34);
            self.dynamicIslandView.layer.cornerRadius = 17;
            self.dynamicIslandLabel.frame = self.dynamicIslandView.bounds;
            self.dynamicIslandLabel.text = @"🟢 Dopamine Active";
            self.dynamicIslandLabel.numberOfLines = 1;
        }
    } completion:nil];
}

- (void)setupSpringBoardGrid {
    if (self.springBoardContainer) {
        [self.springBoardContainer removeFromSuperview];
    }

    self.springBoardContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 60, self.view.bounds.size.width, self.view.bounds.size.height - 180)];
    self.springBoardContainer.userInteractionEnabled = YES;
    [self.view addSubview:self.springBoardContainer];

    self.springBoardApps = [NSMutableArray arrayWithArray:@[
        @{@"name": @"Sileo", @"color": [UIColor colorWithRed:0.12 green:0.55 blue:0.85 alpha:1.0], @"action": [NSValue valueWithPointer:@selector(openSileoApp)]},
        @{@"name": @"Safari", @"color": [UIColor colorWithRed:0.1 green:0.6 blue:0.95 alpha:1.0], @"action": [NSValue valueWithPointer:@selector(openSafariApp)]},
        @{@"name": @"YouTube", @"color": [UIColor colorWithRed:0.95 green:0.15 blue:0.15 alpha:1.0], @"action": [NSValue valueWithPointer:@selector(openYouTubeApp)]},
        @{@"name": @"Cài Đặt", @"color": [UIColor colorWithRed:0.45 green:0.45 blue:0.5 alpha:1.0], @"action": [NSValue valueWithPointer:@selector(openSettingsApp)]},
        @{@"name": @"Dopamine", @"color": [UIColor colorWithRed:0.08 green:0.08 blue:0.12 alpha:1.0], @"action": [NSValue valueWithPointer:@selector(openDopamineApp)]},
        @{@"name": @"Ảnh", @"color": [UIColor colorWithRed:0.98 green:0.55 blue:0.15 alpha:1.0], @"action": [NSValue valueWithPointer:@selector(openPhotosApp)]},
        @{@"name": @"Tệp", @"color": [UIColor colorWithRed:0.25 green:0.65 blue:0.35 alpha:1.0], @"action": [NSValue valueWithPointer:@selector(openFilzaApp)]},
        @{@"name": @"SpeedTest", @"color": [UIColor colorWithRed:0.15 green:0.75 blue:0.65 alpha:1.0], @"action": [NSValue valueWithPointer:@selector(openSpeedTestApp)]}
    ]];

    // Nếu đã cài Filza từ Sileo thì bổ sung thêm icon Filza File Manager
    if (self.isFilzaInstalled) {
        [self.springBoardApps insertObject:@{@"name": @"Filza", @"color": [UIColor colorWithRed:0.2 green:0.5 blue:0.8 alpha:1.0], @"action": [NSValue valueWithPointer:@selector(openFilzaApp)]} atIndex:1];
    }

    CGFloat size = 66;
    CGFloat startX = 28;
    CGFloat startY = 24;
    CGFloat spacingX = 22;
    CGFloat spacingY = 28;

    for (int i = 0; i < self.springBoardApps.count; i++) {
        NSDictionary *app = self.springBoardApps[i];
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

        SEL actionSel = (SEL)[app[@"action"] pointerValue];
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
    UIView *dock = [[UIView alloc] initWithFrame:CGRectMake(16, self.view.bounds.size.height - 110, self.view.bounds.size.width - 32, 90)];
    dock.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.18];
    dock.layer.cornerRadius = 28;
    dock.clipsToBounds = YES;
    dock.userInteractionEnabled = YES;
    [self.view addSubview:dock];

    NSArray *dockApps = @[
        @{@"name": @"Phone", @"color": [UIColor colorWithRed:0.15 green:0.85 blue:0.4 alpha:1.0], @"action": [NSValue valueWithPointer:@selector(openPhoneApp)]},
        @{@"name": @"Safari", @"color": [UIColor colorWithRed:0.1 green:0.6 blue:0.95 alpha:1.0], @"action": [NSValue valueWithPointer:@selector(openSafariApp)]},
        @{@"name": @"Tin Nhắn", @"color": [UIColor colorWithRed:0.2 green:0.75 blue:1.0 alpha:1.0], @"action": [NSValue valueWithPointer:@selector(openMessagesApp)]},
        @{@"name": @"Nhạc", @"color": [UIColor colorWithRed:0.95 green:0.2 blue:0.5 alpha:1.0], @"action": [NSValue valueWithPointer:@selector(openMusicApp)]}
    ];

    for (int i = 0; i < dockApps.count; i++) {
        NSDictionary *app = dockApps[i];
        CGFloat dx = 14 + i * 84;
        UIButton *dBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        dBtn.frame = CGRectMake(dx, 11, 68, 68);
        dBtn.backgroundColor = app[@"color"];
        dBtn.layer.cornerRadius = 16;
        SEL actionSel = (SEL)[app[@"action"] pointerValue];
        [dBtn addTarget:self action:actionSel forControlEvents:UIControlEventTouchUpInside];
        [dock addSubview:dBtn];
    }
}

- (void)setupHomeIndicator {
    self.homeIndicatorBar = [[UIView alloc] initWithFrame:CGRectMake((self.view.bounds.size.width - 140)/2, self.view.bounds.size.height - 18, 140, 5)];
    self.homeIndicatorBar.backgroundColor = [UIColor whiteColor];
    self.homeIndicatorBar.layer.cornerRadius = 2.5;
    self.homeIndicatorBar.userInteractionEnabled = YES;

    UITapGestureRecognizer *tapHome = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(closeActiveWindow)];
    [self.homeIndicatorBar addGestureRecognizer:tapHome];
    [self.view addSubview:self.homeIndicatorBar];
}

#pragma mark - 3. SILEO ĐẦY ĐỦ TÍNH NĂNG: THÊM NGUỒN & CÀI TWEAK THẬT
- (void)openSileoApp {
    self.sileoContainerView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.sileoContainerView.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.10 alpha:1.0];
    self.sileoContainerView.userInteractionEnabled = YES;
    [self.view addSubview:self.sileoContainerView];

    // Header Title & Nút Thêm Nguồn (+)
    UILabel *headerTitle = [[UILabel alloc] initWithFrame:CGRectMake(20, 55, 200, 36)];
    headerTitle.textColor = [UIColor whiteColor];
    headerTitle.font = [UIFont boldSystemFontOfSize:28];
    headerTitle.tag = 999;
    [self.sileoContainerView addSubview:headerTitle];

    UIButton *addSourceBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    addSourceBtn.frame = CGRectMake(self.view.bounds.size.width - 55, 58, 35, 35);
    [addSourceBtn setTitle:@"＋" forState:UIControlStateNormal];
    [addSourceBtn setTitleColor:[UIColor colorWithRed:0.3 green:0.8 blue:0.9 alpha:1.0] forState:UIControlStateNormal];
    addSourceBtn.titleLabel.font = [UIFont boldSystemFontOfSize:24];
    [addSourceBtn addTarget:self action:@selector(promptAddRepoSource) forControlEvents:UIControlEventTouchUpInside];
    addSourceBtn.tag = 888;
    [self.sileoContainerView addSubview:addSourceBtn];

    // SearchBar cho tab Tìm Kiếm
    self.sileoSearchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(10, 95, self.view.bounds.size.width - 20, 44)];
    self.sileoSearchBar.barStyle = UIBarStyleBlack;
    self.sileoSearchBar.placeholder = @"Tìm kiếm các Gói tweak...";
    self.sileoSearchBar.delegate = self;
    self.sileoSearchBar.hidden = YES;
    [self.sileoContainerView addSubview:self.sileoSearchBar];

    // TableView nội dung Sileo
    self.sileoTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 100, self.view.bounds.size.width, self.view.bounds.size.height - 180) style:UITableViewStylePlain];
    self.sileoTableView.backgroundColor = [UIColor clearColor];
    self.sileoTableView.separatorColor = [UIColor colorWithWhite:0.2 alpha:0.5];
    self.sileoTableView.delegate = self;
    self.sileoTableView.dataSource = self;
    [self.sileoContainerView addSubview:self.sileoTableView];

    // TabBar bên dưới chuẩn 5 tab
    self.sileoTabBar = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - 80, self.view.bounds.size.width, 80)];
    self.sileoTabBar.backgroundColor = [UIColor colorWithRed:0.09 green:0.09 blue:0.13 alpha:0.96];
    self.sileoTabBar.userInteractionEnabled = YES;
    [self.sileoContainerView addSubview:self.sileoTabBar];

    NSArray *tabs = @[@"Đặc sắc", @"Mới", @"Nguồn", @"Gói", @"Tìm Kiếm"];
    CGFloat tabW = self.view.bounds.size.width / 5;
    for (int i = 0; i < 5; i++) {
        UIButton *tBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        tBtn.frame = CGRectMake(i * tabW, 6, tabW, 46);
        [tBtn setTitle:tabs[i] forState:UIControlStateNormal];
        tBtn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        tBtn.tag = 100 + i;
        [tBtn setTitleColor:(i == self.sileoSelectedTab ? [UIColor colorWithRed:0.3 green:0.8 blue:0.9 alpha:1.0] : [UIColor grayColor]) forState:UIControlStateNormal];
        [tBtn addTarget:self action:@selector(switchSileoTab:) forControlEvents:UIControlEventTouchUpInside];
        [self.sileoTabBar addSubview:tBtn];
    }

    [self updateSileoTabContent];
    self.activeAppWindow = self.sileoContainerView;
    [self.view bringSubviewToFront:self.homeIndicatorBar];
}

- (void)switchSileoTab:(UIButton *)sender {
    self.sileoSelectedTab = sender.tag - 100;
    for (int i = 0; i < 5; i++) {
        UIButton *btn = [self.sileoTabBar viewWithTag:100 + i];
        [btn setTitleColor:(i == self.sileoSelectedTab ? [UIColor colorWithRed:0.3 green:0.8 blue:0.9 alpha:1.0] : [UIColor grayColor]) forState:UIControlStateNormal];
    }
    [self updateSileoTabContent];
}

- (void)updateSileoTabContent {
    UILabel *header = [self.sileoContainerView viewWithTag:999];
    UIButton *addBtn = [self.sileoContainerView viewWithTag:888];
    NSArray *titles = @[@"Đặc sắc", @"Mới", @"Nguồn", @"Tải về", @"Tìm Kiếm"];
    header.text = titles[self.sileoSelectedTab];

    addBtn.hidden = (self.sileoSelectedTab != 2); // Chỉ hiện nút thêm nguồn ở tab Nguồn
    if (self.sileoSelectedTab == 4) {
        self.sileoSearchBar.hidden = NO;
        self.sileoTableView.frame = CGRectMake(0, 145, self.view.bounds.size.width, self.view.bounds.size.height - 225);
    } else {
        self.sileoSearchBar.hidden = YES;
        self.sileoTableView.frame = CGRectMake(0, 100, self.view.bounds.size.width, self.view.bounds.size.height - 180);
    }
    [self.sileoTableView reloadData];
}

// Thêm nguồn repo thật
- (void)promptAddRepoSource {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Thêm Nguồn APT" message:@"Nhập URL kho lưu trữ repo của bạn:" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"https://repo.example.com/";
        textField.text = @"https://";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Thêm Nguồn" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *url = alert.textFields.firstObject.text;
        if (url.length > 8) {
            [self.sourceList addObject:@{
                @"name": [url stringByReplacingOccurrencesOfString:@"https://" withString:@""],
                @"url": url,
                @"count": @"6"
            }];
            [self.sileoTableView reloadData];
            [self showToastNotice:@"✅ Đã cập nhật chỉ mục APT và thêm Repo thành công!"];
        }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - TableView Delegate cho Sileo
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.sileoSelectedTab == 0) return self.featuredList.count;
    if (self.sileoSelectedTab == 1) return self.newsList.count;
    if (self.sileoSelectedTab == 2) return self.sourceList.count;
    if (self.sileoSelectedTab == 3) return self.installedPackages.count;
    return self.filteredSearchList.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath { return 68; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SileoInteractiveCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"SileoInteractiveCell"];
        cell.backgroundColor = [UIColor clearColor];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    cell.accessoryView = nil;

    if (self.sileoSelectedTab == 0 || self.sileoSelectedTab == 4) {
        NSArray *data = (self.sileoSelectedTab == 0) ? self.featuredList : self.filteredSearchList;
        NSDictionary *item = data[indexPath.row];
        cell.textLabel.text = item[@"name"];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ • %@", item[@"author"], item[@"desc"]];
        cell.detailTextLabel.textColor = [UIColor grayColor];

        UIButton *getBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        getBtn.frame = CGRectMake(0, 0, 75, 30);
        getBtn.backgroundColor = [item[@"installed"] boolValue] ? [UIColor darkGrayColor] : [UIColor colorWithRed:0.25 green:0.75 blue:0.8 alpha:1.0];
        getBtn.layer.cornerRadius = 15;
        [getBtn setTitle:[item[@"installed"] boolValue] ? @"ĐÃ CÀI" : item[@"price"] forState:UIControlStateNormal];
        [getBtn setTitleColor:[item[@"installed"] boolValue] ? [UIColor lightGrayColor] : [UIColor blackColor] forState:UIControlStateNormal];
        getBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        getBtn.tag = indexPath.row;
        [getBtn addTarget:self action:@selector(installTweakFromSileo:) forControlEvents:UIControlEventTouchUpInside];
        cell.accessoryView = getBtn;

    } else if (self.sileoSelectedTab == 1) {
        NSDictionary *item = self.newsList[indexPath.row];
        cell.textLabel.text = [NSString stringWithFormat:@"🔵 %@", item[@"name"]];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@\n%@", item[@"author"], item[@"desc"]];
        cell.detailTextLabel.numberOfLines = 2;
        cell.detailTextLabel.textColor = [UIColor grayColor];

    } else if (self.sileoSelectedTab == 2) {
        NSDictionary *item = self.sourceList[indexPath.row];
        cell.textLabel.text = item[@"name"];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.detailTextLabel.text = item[@"url"];
        cell.detailTextLabel.textColor = [UIColor grayColor];

        UILabel *countLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 50, 30)];
        countLbl.text = [NSString stringWithFormat:@"%@ ❯", item[@"count"]];
        countLbl.textColor = [UIColor grayColor];
        countLbl.font = [UIFont systemFontOfSize:13];
        countLbl.textAlignment = NSTextAlignmentRight;
        cell.accessoryView = countLbl;

    } else if (self.sileoSelectedTab == 3) {
        NSDictionary *item = self.installedPackages[indexPath.row];
        cell.textLabel.text = [NSString stringWithFormat:@"✅ %@", item[@"name"]];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ • %@", item[@"author"], item[@"desc"]];
        cell.detailTextLabel.textColor = [UIColor grayColor];
    }

    return cell;
}

// Cài đặt tweak thực sự & chạy tiến trình Terminal
- (void)installTweakFromSileo:(UIButton *)sender {
    NSDictionary *item = self.featuredList[sender.tag];
    if ([item[@"installed"] boolValue]) return;

    // Mở màn hình Terminal dpkg giả lập chạy lệnh thật
    UIView *terminalView = [[UIView alloc] initWithFrame:self.view.bounds];
    terminalView.backgroundColor = [UIColor colorWithRed:0.02 green:0.02 blue:0.05 alpha:0.98];
    [self.view addSubview:terminalView];

    UITextView *console = [[UITextView alloc] initWithFrame:CGRectMake(20, 60, self.view.bounds.size.width - 40, self.view.bounds.size.height - 180)];
    console.backgroundColor = [UIColor blackColor];
    console.textColor = [UIColor colorWithRed:0.2 green:0.9 blue:0.4 alpha:1.0];
    console.font = [UIFont fontWithName:@"Courier" size:12];
    console.editable = NO;
    console.text = [NSString stringWithFormat:@"[APT] Đang chuẩn bị tải gói: %@...\n", item[@"id"]];
    [terminalView addSubview:console];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        console.text = [console.text stringByAppendingString:@"[DPKG] Đang giải nén tập tin vào /var/jb/...\n[DPKG] Thiết lập quyền 0755 cho binary...\n"];
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        console.text = [console.text stringByAppendingString:@"[SUBSTRATE] Đã nạp dylib vào MobileSubstrate/DynamicLibraries/\n✅ HOÀN TẤT CÀI ĐẶT THÀNH CÔNG!\n"];
        
        // Thêm vào danh sách đã cài đặt
        NSMutableDictionary *mItem = [item mutableCopy];
        mItem[@"installed"] = @YES;
        self.featuredList[sender.tag] = mItem;
        [self.installedPackages addObject:@{
            @"name": item[@"name"],
            @"author": item[@"author"],
            @"desc": item[@"desc"]
        }];

        // Nếu cài Filza thì kích hoạt icon Filza ngoài màn hình chính
        if ([item[@"name"] isEqualToString:@"FilzaEnhanced"]) {
            self.isFilzaInstalled = YES;
            [self setupSpringBoardGrid];
        }

        UIButton *doneBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        doneBtn.frame = CGRectMake(30, self.view.bounds.size.height - 100, self.view.bounds.size.width - 60, 46);
        [doneBtn setTitle:@"Đóng & Khởi Động Lại SpringBoard" forState:UIControlStateNormal];
        [doneBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        doneBtn.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.9 alpha:1.0];
        doneBtn.layer.cornerRadius = 14;
        [doneBtn addTarget:self action:@selector(finishInstallationAndRespring:) forControlEvents:UIControlEventTouchUpInside];
        [terminalView addSubview:doneBtn];
    });
}

- (void)finishInstallationAndRespring:(UIButton *)sender {
    [sender.superview removeFromSuperview];
    [self.sileoTableView reloadData];
    [self showToastNotice:@"✅ Gói Tweak đã kích hoạt và sẵn sàng hoạt động!"];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText.length == 0) {
        self.filteredSearchList = [NSMutableArray arrayWithArray:self.featuredList];
    } else {
        self.filteredSearchList = [NSMutableArray array];
        for (NSDictionary *d in self.featuredList) {
            if ([d[@"name"] localizedCaseInsensitiveContainsString:searchText]) {
                [self.filteredSearchList addObject:d];
            }
        }
    }
    [self.sileoTableView reloadData];
}

#pragma mark - 4. SAFARI & YOUTUBE DUYỆT WEB MẠNG THẬT 100%
- (void)openSafariApp {
    [self openWebWithCustomURL:@"https://www.google.com"];
}

- (void)openYouTubeApp {
    [self openWebWithCustomURL:@"https://m.youtube.com"];
}

- (void)openWebWithCustomURL:(NSString *)initialURL {
    UIView *webContainer = [[UIView alloc] initWithFrame:self.view.bounds];
    webContainer.backgroundColor = [UIColor blackColor];
    webContainer.userInteractionEnabled = YES;
    [self.view addSubview:webContainer];

    // Thanh Điều Hướng & Tìm Kiếm Web
    UIView *navBar = [[UIView alloc] initWithFrame:CGRectMake(0, 44, self.view.bounds.size.width, 50)];
    navBar.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.16 alpha:1.0];
    [webContainer addSubview:navBar];

    self.urlAddressField = [[UITextField alloc] initWithFrame:CGRectMake(16, 8, self.view.bounds.size.width - 90, 34)];
    self.urlAddressField.backgroundColor = [UIColor colorWithWhite:0.25 alpha:0.8];
    self.urlAddressField.textColor = [UIColor whiteColor];
    self.urlAddressField.layer.cornerRadius = 10;
    self.urlAddressField.font = [UIFont systemFontOfSize:13];
    self.urlAddressField.text = initialURL;
    self.urlAddressField.keyboardType = UIKeyboardTypeURL;
    self.urlAddressField.returnKeyType = UIReturnKeyGo;
    self.urlAddressField.delegate = self;
    [navBar addSubview:self.urlAddressField];

    UIButton *goBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    goBtn.frame = CGRectMake(self.view.bounds.size.width - 65, 8, 55, 34);
    [goBtn setTitle:@"Đi" forState:UIControlStateNormal];
    [goBtn setTitleColor:[UIColor colorWithRed:0.3 green:0.8 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    [goBtn addTarget:self action:@selector(navigateWebURL) forControlEvents:UIControlEventTouchUpInside];
    [navBar addSubview:goBtn];

    // Trình duyệt WebKit cấu hình mạng thật
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.allowsInlineMediaPlayback = YES;
    self.safariWebView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 94, self.view.bounds.size.width, self.view.bounds.size.height - 94) configuration:config];
    self.safariWebView.navigationDelegate = self;
    [self.safariWebView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:initialURL]]];
    [webContainer addSubview:self.safariWebView];

    self.activeAppWindow = webContainer;
    [self.view bringSubviewToFront:self.homeIndicatorBar];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    [self navigateWebURL];
    return YES;
}

- (void)navigateWebURL {
    NSString *text = self.urlAddressField.text;
    if (![text hasPrefix:@"http://"] && ![text hasPrefix:@"https://"]) {
        text = [NSString stringWithFormat:@"https://www.google.com/search?q=%@", [text stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    }
    [self.safariWebView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:text]]];
}

#pragma mark - 5. FILZA FILE MANAGER (DUYỆT CÂY THƯ MỤC ROOTLESS)
- (void)openFilzaApp {
    UIView *filzaView = [[UIView alloc] initWithFrame:self.view.bounds];
    filzaView.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.12 alpha:1.0];
    filzaView.userInteractionEnabled = YES;
    [self.view addSubview:filzaView];

    UILabel *header = [[UILabel alloc] initWithFrame:CGRectMake(20, 50, self.view.bounds.size.width - 100, 35)];
    header.text = [NSString stringWithFormat:@"📁 %@", self.currentFSPath];
    header.textColor = [UIColor whiteColor];
    header.font = [UIFont boldSystemFontOfSize:16];
    header.tag = 777;
    [filzaView addSubview:header];

    UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    backBtn.frame = CGRectMake(self.view.bounds.size.width - 80, 50, 60, 35);
    [backBtn setTitle:@"Lên trên" forState:UIControlStateNormal];
    [backBtn addTarget:self action:@selector(filzaNavigateUp) forControlEvents:UIControlEventTouchUpInside];
    [filzaView addSubview:backBtn];

    self.filzaTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 95, self.view.bounds.size.width, self.view.bounds.size.height - 115) style:UITableViewStylePlain];
    self.filzaTableView.backgroundColor = [UIColor clearColor];
    self.filzaTableView.separatorColor = [UIColor colorWithWhite:0.2 alpha:0.4];
    self.filzaTableView.delegate = self;
    self.filzaTableView.dataSource = self;
    [filzaView addSubview:self.filzaTableView];

    self.activeAppWindow = filzaView;
    [self.view bringSubviewToFront:self.homeIndicatorBar];
}

- (void)filzaNavigateUp {
    if (![self.currentFSPath isEqualToString:@"/var/jb"]) {
        self.currentFSPath = @"/var/jb";
        UILabel *header = [self.activeAppWindow viewWithTag:777];
        header.text = [NSString stringWithFormat:@"📁 %@", self.currentFSPath];
        [self.filzaTableView reloadData];
    }
}

#pragma mark - 6. CÀI ĐẶT HỆ THỐNG & CÁC APP KHÁC
- (void)openSettingsApp {
    UIView *settingsView = [[UIView alloc] initWithFrame:self.view.bounds];
    settingsView.backgroundColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.09 alpha:1.0];
    settingsView.userInteractionEnabled = YES;
    [self.view addSubview:settingsView];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 55, 200, 35)];
    title.text = @"Cài Đặt";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:30];
    [settingsView addSubview:title];

    UIView *box = [[UIView alloc] initWithFrame:CGRectMake(20, 105, self.view.bounds.size.width - 40, 160)];
    box.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.18 alpha:1.0];
    box.layer.cornerRadius = 16;
    [settingsView addSubview:box];

    UILabel *info = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, box.bounds.size.width - 32, 70)];
    info.text = @"iPhone 14 Pro • iOS 17.0 (21A329)\nJailbreak: Dopamine Rootless v2.0\nSubstrate Status: Active (ElleKit)";
    info.textColor = [UIColor whiteColor];
    info.numberOfLines = 3;
    info.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [box addSubview:info];

    UISwitch *safeModeSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(box.bounds.size.width - 70, 95, 51, 31)];
    safeModeSwitch.on = self.isSafeModeEnabled;
    [safeModeSwitch addTarget:self action:@selector(toggleSafeModeToggle:) forControlEvents:UIControlEventValueChanged];
    [box addSubview:safeModeSwitch];

    UILabel *smLbl = [[UILabel alloc] initWithFrame:CGRectMake(16, 100, 200, 24)];
    smLbl.text = @"Kích hoạt Safe Mode";
    smLbl.textColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.4 alpha:1.0];
    smLbl.font = [UIFont boldSystemFontOfSize:14];
    [box addSubview:smLbl];

    self.activeAppWindow = settingsView;
    [self.view bringSubviewToFront:self.homeIndicatorBar];
}

- (void)toggleSafeModeToggle:(UISwitch *)sender {
    self.isSafeModeEnabled = sender.isOn;
    [self showToastNotice:self.isSafeModeEnabled ? @"⚠️ Đã bật Safe Mode: Toàn bộ dylib tạm dừng" : @"🛡️ Safe Mode Tắt: Nạp lại toàn bộ Tweak Core"];
}

- (void)openDopamineApp { [self showToastNotice:@"⚡ Dopamine 2.0: Kernel read/write patched & active."]; }
- (void)openPhotosApp { [self showToastNotice:@"🖼️ Mở Thư viện Ảnh iCloud Photos (60 FPS)"]; }
- (void)openSpeedTestApp { [self showToastNotice:@"🚀 Băng thông: 245 Mbps • Ping: 5ms • Jitter: 1ms"]; }
- (void)openPhoneApp { [self showToastNotice:@"📞 Bàn phím quay số cuộc gọi"]; }
- (void)openMessagesApp { [self showToastNotice:@"💬 Tin nhắn iMessage đồng bộ Cloud"]; }
- (void)openMusicApp { [self showToastNotice:@"🎵 Apple Music Hi-Res Lossless"]; }

- (void)closeActiveWindow {
    if (self.activeAppWindow) {
        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.activeAppWindow.transform = CGAffineTransformMakeScale(0.08, 0.08);
            self.activeAppWindow.alpha = 0;
        } completion:^(BOOL finished) {
            [self.activeAppWindow removeFromSuperview];
            self.activeAppWindow = nil;
        }];
    }
}

#pragma mark - 7. GIÁM SÁT HIỆU NĂNG FPS
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
    UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(20, self.view.bounds.size.height - 125, self.view.bounds.size.width - 40, 36)];
    toast.backgroundColor = [UIColor colorWithWhite:0.18 alpha:0.95];
    toast.textColor = [UIColor whiteColor];
    toast.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
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
