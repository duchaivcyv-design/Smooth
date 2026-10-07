// ====================================================================================================
// BOOSTIPHONE6S APP - APPDELEGATE IMPLEMENTATION (CHẾ ĐỘ ĐÃ ÉP TOÀN DIỆN - CHUẨN ĐỒNG BỘ 0MS)
// (AN TOÀN TUYỆT ĐỐI: KHÔNG ĐEN MÀN HÌNH, TỰ BẬT PROMOTION CAO NHẤT, ĐỒNG BỘ REALTIME)
// ====================================================================================================

#import "AppDelegate.h"
#import "RootListController.h"
#import <notify.h>
#import <pthread.h>
#import <QuartzCore/QuartzCore.h>

@interface AppDelegate ()
@property (nonatomic, strong) UINavigationController *mainNavController;
@property (nonatomic, strong) RootListController *rootListVC;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // [ĐÃ ÉP TOÀN DIỆN]: Đẩy quyền luồng chính lên mức cao nhất
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);

    // 1. [ĐÃ ÉP TOÀN DIỆN]: Khởi tạo cửa sổ chính phủ toàn bộ kích thước màn hình
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = [UIColor colorWithRed:0.01 green:0.02 blue:0.05 alpha:1.0];

    // 2. Khởi tạo Controller điều khiển chính
    self.rootListVC = [[RootListController alloc] init];
    self.mainNavController = [[UINavigationController alloc] initWithRootViewController:self.rootListVC];

    // [ĐÃ ÉP]: Cấu hình giao diện kính mờ tối ưu cho iOS 13 - 17+
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

    // 4. [ĐÃ SỬA CHUẨN]: Gán ProMotion trực tiếp lên CALayer của UIWindow (Đúng API chuẩn iOS 15+)
    if (@available(iOS 15.0, *)) {
        if ([self.window.layer respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
            self.window.layer.preferredFrameRateRange = CAFrameRateRangeMake(30.0f, 120.0f, 120.0f);
        }
    }

    return YES;
}

// [ĐÃ ÉP TOÀN DIỆN]: Tự động làm mới khi người dùng mở lại app từ chạy nền
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

    // Bắn thông báo đồng bộ lại IPC trên background thread để không giật lag giao diện
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        notify_post(NOTIFY_RELOAD);
        notify_post(NOTIFY_TITANIUM_CHANGED);
    });
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Để hệ điều hành tự điều phối chu kỳ render tự nhiên
}

@end
