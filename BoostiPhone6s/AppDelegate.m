// ====================================================================================================
// BOOSTIPHONE6S APP - APPDELEGATE IMPLEMENTATION
// ====================================================================================================

#import "AppDelegate.h"
#import "RootListController.h"
#import <notify.h>
#import <pthread.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>

@interface AppDelegate ()
@property (nonatomic, strong) UINavigationController *mainNavController;
@property (nonatomic, strong) RootListController *rootListVC;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Boost Main Thread
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);

    // 1. Khởi tạo cửa sổ chính
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = [UIColor colorWithRed:0.01 green:0.02 blue:0.05 alpha:1.0];

    // 2. Khởi tạo Controller
    self.rootListVC = [[RootListController alloc] init];
    self.mainNavController = [[UINavigationController alloc] initWithRootViewController:self.rootListVC];

    // Cấu hình giao diện Navigation Bar (iOS 13+)
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *navBarAppearance = [[UINavigationBarAppearance alloc] init];
        [navBarAppearance configureWithDefaultBackground];
        navBarAppearance.backgroundColor = [UIColor colorWithRed:0.04 green:0.07 blue:0.14 alpha:0.85];
        navBarAppearance.titleTextAttributes = @{
            NSForegroundColorAttributeName: [UIColor whiteColor],
            NSFontAttributeName: [UIFont systemFontOfSize:17 weight:UIFontWeightBold]
        };
        navBarAppearance.largeTitleTextAttributes = @{
            NSForegroundColorAttributeName: [UIColor whiteColor],
            NSFontAttributeName: [UIFont systemFontOfSize:28 weight:UIFontWeightHeavy]
        };

        self.mainNavController.navigationBar.standardAppearance = navBarAppearance;
        self.mainNavController.navigationBar.compactAppearance = navBarAppearance;
        self.mainNavController.navigationBar.scrollEdgeAppearance = navBarAppearance;
    }

    self.mainNavController.navigationBar.tintColor = [UIColor colorWithRed:0.25 green:0.85 blue:1.0 alpha:1.0];
    self.mainNavController.navigationBar.barStyle = UIBarStyleBlack;

    self.window.rootViewController = self.mainNavController;

    // 3. Hiển thị cửa sổ
    [self.window makeKeyAndVisible];

    // 4. Ép Frame Rate (Target: UIWindowScene thay vì UIWindow.layer)
    if (@available(iOS 15.0, *)) {
        // Phải đợi 1 nhịp để windowScene được gắn vào window
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindowScene *scene = self.window.windowScene;
            if (scene) {
                SEL setRangeSel = NSSelectorFromString(@"setPreferredFrameRateRange:");
                if ([scene respondsToSelector:setRangeSel]) {
                    // Ép dải 15-240Hz (Lấy mức 120 làm preferred cho app mượt)
                    CAFrameRateRange range = CAFrameRateRangeMake(15.0f, 240.0f, 120.0f);
                    void (*setFrameRateRangeFunc)(id, SEL, CAFrameRateRange) = (void (*)(id, SEL, CAFrameRateRange))objc_msgSend;
                    setFrameRateRangeFunc(scene, setRangeSel, range);
                }
            }
        });
    }

    return YES;
}

// Làm mới khi mở lại app từ background
- (void)applicationWillEnterForeground:(UIApplication *)application {
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);

    if (self.rootListVC) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.rootListVC ensureDefaultSettingsExist];
            if (self.rootListVC.customTableView) {
                [self.rootListVC.customTableView reloadData];
            }
        });
    }

    // Bắn thông báo đồng bộ IPC trên background thread
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        notify_post(NOTIFY_RELOAD);
        notify_post(NOTIFY_TITANIUM_CHANGED);
    });
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Để OS tự điều phối render, đéo can thiệp sâu ở đây để tránh khựng app.
}

@end
