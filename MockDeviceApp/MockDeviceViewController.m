#import "MockDeviceViewController.h"
#import <mach/mach.h>
#import <WebKit/WebKit.h>

@interface MockDeviceViewController () <WKNavigationDelegate, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate>

// Giao diện SpringBoard & Dynamic Island
@property (nonatomic, strong) UIImageView *wallpaperImageView;
@property (nonatomic, strong) UIView *springBoardContainer;
@property (nonatomic, strong) UIView *dynamicIslandView;
@property (nonatomic, strong) UIView *activeAppWindow;
@property (nonatomic, strong) UIView *rebootCurtainView;
@property (nonatomic, strong) UIView *homeIndicatorBar;

// Sileo Native Clone
@property (nonatomic, strong) UIView *sileoContainerView;
@property (nonatomic, strong) UIView *sileoTabBar;
@property (nonatomic, strong) UITableView *sileoTableView;
@property (nonatomic, strong) UISearchBar *sileoSearchBar;
@property (nonatomic, assign) NSInteger sileoSelectedTab; // 0: Đặc sắc, 1: Mới, 2: Nguồn, 3: Gói, 4: Tìm Kiếm
@property (nonatomic, strong) NSArray *featuredList;
@property (nonatomic, strong) NSArray *newsList;
@property (nonatomic, strong) NSArray *sourceList;
@property (nonatomic, strong) NSArray *installedPackages;

// Trình duyệt Web & YouTube
@property (nonatomic, strong) WKWebView *safariWebView;
@property (nonatomic, strong) WKWebView *youtubeWebView;

// Trạng thái Jailbreak
@property (nonatomic, assign) BOOL isJailbroken;
@property (nonatomic, strong) UITextView *dopamineConsole;

// Giám sát FPS
@property (nonatomic, strong) CADisplayLink *fpsDisplayLink;
@property (nonatomic, strong) UILabel *fpsCounterLabel;
@property (nonatomic, assign) CFTimeInterval lastTimestamp;
@property (nonatomic, assign) NSInteger frameCount;
@end

@implementation MockDeviceViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.isJailbroken = YES; // Kích hoạt sẵn môi trường đã Jailbreak để test ngay Sileo
    self.sileoSelectedTab = 0;

    [self initializeSileoData];
    [self setupWallpaperAndStatusBar];
    [self setupDynamicIsland];
    [self setupSpringBoardGrid];
    [self setupDockBar];
    [self setupHomeIndicator];
    [self setupFPSMonitoring];
}

#pragma mark - 1. DỮ LIỆU SILEO GIỐNG ẢNH THỰC TẾ 100%
- (void)initializeSileoData {
    // Tab 0: Đặc sắc (Featured)
    self.featuredList = @[
        @{@"name": @"FLEQ", @"author": @"Korboy • 1.0.3", @"price": @"NHẬN", @"icon": @"waveform.path.ecg"},
        @{@"name": @"FilzaEnhanced", @"author": @"Korboy • 1.0.7.4", @"price": @"NHẬN", @"icon": @"folder.badge.gearshape"},
        @{@"name": @"KillX Pro Neo", @"author": @"cemck • 3.0.1", @"price": @"$3.49", @"icon": @"xmark.circle.fill"},
        @{@"name": @"Doodle", @"author": @"twickd • 1.1.2", @"price": @"NHẬN", @"icon": @"paintbrush.pointed.fill"}
    ];

    // Tab 1: Mới (New Updates)
    self.newsList = @[
        @{@"name": @"26Home", @"author": @"ngkhoi • 1.3.14-launch-flicker-fix-zh", @"desc": @"iOS 26 风格液态玻璃桌面美化"},
        @{@"name": @"Actra", @"author": @"mlgm • 1.0", @"desc": @"手势与事件自动化工具"},
        @{@"name": @"Adytum", @"author": @"Kernelrw • 2.0 • Chariz", @"desc": @"True application backgrounding management."},
        @{@"name": @"AppData", @"author": @"Fouad Raheb • 1.3.7", @"desc": @"Quản lý dữ liệu app, xoá cache..."},
        @{@"name": @"CPU智能温控(iOS16/17)", @"author": @"qq391160 • 2.0.3", @"desc": @"三种模式一键切换智能温控管理"}
    ];

    // Tab 2: Nguồn (Repos)
    self.sourceList = @[
        @{@"name": @"Tất cả gói", @"url": @"Xem tất cả các gói từ các nguồn của bạn", @"count": @"115"},
        @{@"name": @"Korboy's Repo", @"url": @"https://korboybeats.github.io/", @"count": @"1"},
        @{@"name": @"BigBoss", @"url": @"http://apt.thebigboss.org/repofiles/cydia/", @"count": @"3"},
        @{@"name": @"BVN Repo", @"url": @"https://bvnrepo.xyz/", @"count": @"4"},
        @{@"name": @"Chariz", @"url": @"https://repo.chariz.com/", @"count": @"0"},
        @{@"name": @"ElleKit", @"url": @"https://ellekit.space/", @"count": @"1"}
    ];

    // Tab 3: Gói (Installed)
    self.installedPackages = @[
        @{@"name": @"SmoothIOS Pro", @"author": @"TaoJB, NoJB • 1.2.0-2a • Địa phương", @"desc": @"Dynamic variable refresh rate, zero stutter..."},
        @{@"name": @"gpgv", @"author": @"Procursus Team • 2.4.5", @"desc": @"GNU privacy guard - signature verification tool"},
        @{@"name": @"libpam2", @"author": @"Procursus Team • 20230627", @"desc": @"Pluggable Authentication Modules library"},
        @{@"name": @"libassuan0", @"author": @"Procursus Team • 2.5.7", @"desc": @"IPC library for the GnuPG components"},
        @{@"name": @"libxxhash0", @"author": @"Procursus Team • 0.8.2", @"desc": @"Shared library for xxhash"},
        @{@"name": @"debianutils", @"author": @"Procursus Team • 5.19", @"desc": @"Miscellaneous utilities specific to Debian"}
    ];
}

#pragma mark - 2. MÀN HÌNH CHÍNH & STATUS BAR
- (void)setupWallpaperAndStatusBar {
    self.wallpaperImageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    self.wallpaperImageView.backgroundColor = [UIColor colorWithRed:0.06 green:0.10 blue:0.20 alpha:1.0];
    self.wallpaperImageView.contentMode = UIViewContentModeScaleAspectFill;
    [self.view addSubview:self.wallpaperImageView];

    UILabel *statusBar = [[UILabel alloc] initWithFrame:CGRectMake(28, 14, self.view.bounds.size.width - 56, 20)];
    statusBar.text = @"09:41                          5G 🔋 100%";
    statusBar.textColor = [UIColor whiteColor];
    statusBar.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [self.view addSubview:statusBar];
}

- (void)setupSpringBoardGrid {
    self.springBoardContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 60, self.view.bounds.size.width, self.view.bounds.size.height - 180)];
    [self.view addSubview:self.springBoardContainer];

    NSArray *apps = @[
        @{@"name": @"Sileo", @"color": [UIColor colorWithRed:0.12 green:0.55 blue:0.85 alpha:1.0], @"action": [NSValue valueWithPointer:@selector(openSileoApp)]},
        @{@"name": @"Safari", @"color": [UIColor colorWithRed:0.1 green:0.6 blue:0.95 alpha:1.0], @"action": [NSValue valueWithPointer:@selector(openSafariApp)]},
        @{@"name": @"YouTube", @"color": [UIColor colorWithRed:0.95 green:0.15 blue:0.15 alpha:1.0], @"action": [NSValue valueWithPointer:@selector(openYouTubeApp)]},
        @{@"name": @"Cài Đặt", @"color": [UIColor colorWithRed:0.45 green:0.45 blue:0.5 alpha:1.0], @"action": [NSValue valueWithPointer:@selector(openSettingsApp)]},
        @{@"name": @"Dopamine", @"color": [UIColor colorWithRed:0.08 green:0.08 blue:0.12 alpha:1.0], @"action": [NSValue valueWithPointer:@selector(openDopamineApp)]},
        @{@"name": @"Ảnh", @"color": [UIColor colorWithRed:0.98 green:0.55 blue:0.15 alpha:1.0], @"action": [NSValue valueWithPointer:@selector(openPhotosApp)]},
        @{@"name": @"Tệp", @"color": [UIColor colorWithRed:0.25 green:0.65 blue:0.35 alpha:1.0], @"action": [NSValue valueWithPointer:@selector(openFilesApp)]},
        @{@"name": @"App Store", @"color": [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0], @"action": [NSValue valueWithPointer:@selector(openAppStoreApp)]}
    ];

    CGFloat size = 66;
    CGFloat startX = 28;
    CGFloat startY = 24;
    CGFloat spacingX = 22;
    CGFloat spacingY = 28;

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
        btn.layer.shadowOpacity = 0.35;
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

#pragma mark - 3. DYNAMIC ISLAND & HOME INDICATOR
- (void)setupDynamicIsland {
    self.dynamicIslandView = [[UIView alloc] initWithFrame:CGRectMake((self.view.bounds.size.width - 124)/2, 11, 124, 34)];
    self.dynamicIslandView.backgroundColor = [UIColor blackColor];
    self.dynamicIslandView.layer.cornerRadius = 17;
    self.dynamicIslandView.clipsToBounds = YES;

    UILabel *lbl = [[UILabel alloc] initWithFrame:self.dynamicIslandView.bounds];
    lbl.text = @"🟢 Sileo & Network OK";
    lbl.textColor = [UIColor whiteColor];
    lbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    lbl.textAlignment = NSTextAlignmentCenter;
    [self.dynamicIslandView addSubview:lbl];

    [self.view addSubview:self.dynamicIslandView];
}

- (void)setupHomeIndicator {
    self.homeIndicatorBar = [[UIView alloc] initWithFrame:CGRectMake((self.view.bounds.size.width - 140)/2, self.view.bounds.size.height - 18, 140, 5)];
    self.homeIndicatorBar.backgroundColor = [UIColor whiteColor];
    self.homeIndicatorBar.layer.cornerRadius = 2.5;
    self.homeIndicatorBar.userInteractionEnabled = YES;

    // Chạm hoặc vuốt Home Indicator để đóng app đang mở
    UITapGestureRecognizer *tapHome = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(closeActiveWindow)];
    [self.homeIndicatorBar addGestureRecognizer:tapHome];
    [self.view addSubview:self.homeIndicatorBar];
}

#pragma mark - 4. SILEO CLONE CHUẨN XÁC THEO ẢNH CHỤP
- (void)openSileoApp {
    self.sileoContainerView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.sileoContainerView.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.10 alpha:1.0];
    [self.view addSubview:self.sileoContainerView];

    // Header Title
    UILabel *headerTitle = [[UILabel alloc] initWithFrame:CGRectMake(20, 55, 200, 36)];
    headerTitle.textColor = [UIColor whiteColor];
    headerTitle.font = [UIFont boldSystemFontOfSize:28];
    headerTitle.tag = 999;
    [self.sileoContainerView addSubview:headerTitle];

    // TableView nội dung
    self.sileoTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 100, self.view.bounds.size.width, self.view.bounds.size.height - 180) style:UITableViewStylePlain];
    self.sileoTableView.backgroundColor = [UIColor clearColor];
    self.sileoTableView.separatorColor = [UIColor colorWithWhite:0.2 alpha:0.5];
    self.sileoTableView.delegate = self;
    self.sileoTableView.dataSource = self;
    [self.sileoContainerView addSubview:self.sileoTableView];

    // TabBar bên dưới chuẩn 5 tab Sileo: Đặc sắc | Mới | Nguồn | Gói | Tìm Kiếm
    self.sileoTabBar = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - 80, self.view.bounds.size.width, 80)];
    self.sileoTabBar.backgroundColor = [UIColor colorWithRed:0.09 green:0.09 blue:0.13 alpha:0.95];
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
    [self bringSubviewToFront:self.homeIndicatorBar];
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
    NSArray *titles = @[@"Đặc sắc", @"Mới", @"Nguồn", @"Tải về", @"Tìm Kiếm"];
    header.text = titles[self.sileoSelectedTab];
    [self.sileoTableView reloadData];
}

#pragma mark - TableView Delegate cho Sileo
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.sileoSelectedTab == 0) return self.featuredList.count;
    if (self.sileoSelectedTab == 1) return self.newsList.count;
    if (self.sileoSelectedTab == 2) return self.sourceList.count;
    if (self.sileoSelectedTab == 3) return self.installedPackages.count;
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 68;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SileoNativeCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"SileoNativeCell"];
        cell.backgroundColor = [UIColor clearColor];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }

    // Xoá view cũ bên trong accessory
    cell.accessoryView = nil;

    if (self.sileoSelectedTab == 0) { // Đặc sắc
        NSDictionary *item = self.featuredList[indexPath.row];
        cell.textLabel.text = item[@"name"];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.detailTextLabel.text = item[@"author"];
        cell.detailTextLabel.textColor = [UIColor grayColor];

        // Nút NHẬN hoặc giá tiền như ảnh 1
        UIButton *getBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        getBtn.frame = CGRectMake(0, 0, 72, 30);
        getBtn.backgroundColor = [UIColor colorWithRed:0.25 green:0.75 blue:0.8 alpha:1.0];
        getBtn.layer.cornerRadius = 15;
        [getBtn setTitle:item[@"price"] forState:UIControlStateNormal];
        [getBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        getBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        [getBtn addTarget:self action:@selector(installDemoTweak:) forControlEvents:UIControlEventTouchUpInside];
        cell.accessoryView = getBtn;

    } else if (self.sileoSelectedTab == 1) { // Mới
        NSDictionary *item = self.newsList[indexPath.row];
        cell.textLabel.text = [NSString stringWithFormat:@"🔵 %@", item[@"name"]];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@\n%@", item[@"author"], item[@"desc"]];
        cell.detailTextLabel.numberOfLines = 2;
        cell.detailTextLabel.textColor = [UIColor grayColor];

    } else if (self.sileoSelectedTab == 2) { // Nguồn
        NSDictionary *item = self.sourceList[indexPath.row];
        cell.textLabel.text = item[@"name"];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.detailTextLabel.text = item[@"url"];
        cell.detailTextLabel.textColor = [UIColor grayColor];

        UILabel *countLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 40, 30)];
        countLbl.text = [NSString stringWithFormat:@"%@ >", item[@"count"]];
        countLbl.textColor = [UIColor grayColor];
        countLbl.font = [UIFont systemFontOfSize:13];
        countLbl.textAlignment = NSTextAlignmentRight;
        cell.accessoryView = countLbl;

    } else if (self.sileoSelectedTab == 3) { // Gói
        NSDictionary *item = self.installedPackages[indexPath.row];
        cell.textLabel.text = [NSString stringWithFormat:@"✅ %@", item[@"name"]];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ • %@", item[@"author"], item[@"desc"]];
        cell.detailTextLabel.textColor = [UIColor grayColor];

    } else { // Tìm Kiếm
        cell.textLabel.text = @"🔍 Gõ từ khoá tìm kiếm gói...";
        cell.textLabel.textColor = [UIColor grayColor];
        cell.detailTextLabel.text = nil;
    }
    return cell;
}

- (void)installDemoTweak:(UIButton *)sender {
    [self showToastNotice:@"📥 Đang thêm vào hàng đợi & biên dịch Tweak an toàn..."];
}

#pragma mark - 5. SAFARI & YOUTUBE TRỰC TIẾP
- (void)openSafariApp {
    [self openWebTarget:@"https://www.google.com" title:@"Safari"];
}

- (void)openYouTubeApp {
    [self openWebTarget:@"https://m.youtube.com" title:@"YouTube"];
}

- (void)openAppStoreApp {
    [self openWebTarget:@"https://apps.apple.com" title:@"App Store"];
}

- (void)openWebTarget:(NSString *)urlString title:(NSString *)titleText {
    UIView *webContainer = [[UIView alloc] initWithFrame:self.view.bounds];
    webContainer.backgroundColor = [UIColor blackColor];
    [self.view addSubview:webContainer];

    // Thanh địa chỉ web
    UIView *navBar = [[UIView alloc] initWithFrame:CGRectMake(0, 44, self.view.bounds.size.width, 44)];
    navBar.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.15 alpha:1.0];
    [webContainer addSubview:navBar];

    UILabel *addrLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 7, self.view.bounds.size.width - 100, 30)];
    addrLbl.text = [NSString stringWithFormat:@"🔒 %@", urlString];
    addrLbl.textColor = [UIColor whiteColor];
    addrLbl.font = [UIFont systemFontOfSize:13];
    [navBar addSubview:addrLbl];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(self.view.bounds.size.width - 70, 7, 50, 30);
    [closeBtn setTitle:@"Đóng" forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(closeActiveWindow) forControlEvents:UIControlEventTouchUpInside];
    [navBar addSubview:closeBtn];

    // Trình duyệt WebKit cho phép tải mạng thật
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.allowsInlineMediaPlayback = YES;
    WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 88, self.view.bounds.size.width, self.view.bounds.size.height - 88) configuration:config];
    [webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlString]]];
    [webContainer addSubview:webView];

    self.activeAppWindow = webContainer;
    [self bringSubviewToFront:self.homeIndicatorBar];
}

#pragma mark - 6. CÁC APP HỆ THỐNG MẶC ĐỊNH
- (void)openSettingsApp {
    UIView *settingsView = [[UIView alloc] initWithFrame:self.view.bounds];
    settingsView.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.08 alpha:1.0];
    [self.view addSubview:settingsView];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 60, 200, 35)];
    title.text = @"Cài Đặt";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:30];
    [settingsView addSubview:title];

    UILabel *desc = [[UILabel alloc] initWithFrame:CGRectMake(20, 110, self.view.bounds.size.width - 40, 80)];
    desc.text = @"Apple ID: test@icloud.com\niPhone 14 Pro • iOS 17.0 (21A329)\nTrạng thái Tweak: Đã kích hoạt Rootless";
    desc.textColor = [UIColor lightGrayColor];
    desc.numberOfLines = 3;
    [settingsView addSubview:desc];

    self.activeAppWindow = settingsView;
    [self bringSubviewToFront:self.homeIndicatorBar];
}

- (void)openDopamineApp {
    [self showToastNotice:@"⚡ Dopamine v2.0: Đã hoàn tất jailbreak kernel."];
}

- (void)openPhotosApp { [self showToastNotice:@"🖼️ Đang nạp thư viện Ảnh..."]; }
- (void)openFilesApp { [self showToastNotice:@"📁 /var/jb/ (Rootless File Manager)"]; }
- (void)openPhoneApp { [self showToastNotice:@"📞 Bàn phím gọi điện thoại"]; }
- (void)openMessagesApp { [self showToastNotice:@"💬 iMessage sẵn sàng"]; }
- (void)openMusicApp { [self showToastNotice:@"🎵 Apple Music Lossless"]; }

- (void)closeActiveWindow {
    if (self.activeAppWindow) {
        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.activeAppWindow.transform = CGAffineTransformMakeScale(0.1, 0.1);
            self.activeAppWindow.alpha = 0;
        } completion:^(BOOL finished) {
            [self.activeAppWindow removeFromSuperview];
            self.activeAppWindow = nil;
        }];
    }
}

- (void)bringSubviewToFront:(UIView *)view {
    [super.view bringSubviewToFront:view];
}

#pragma mark - 7. GIÁM SÁT HIỆU NĂNG & THÔNG BÁO
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
    UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(20, self.view.bounds.size.height - 120, self.view.bounds.size.width - 40, 36)];
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
