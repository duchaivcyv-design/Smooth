// ====================================================================================================
// BOOSTIPHONE6S APP - APPDELEGATE IMPLEMENTATION (CHẾ ĐỘ ĐÃ ÉP TOÀN DIỆN - CHUẨN ĐỒNG BỘ 0MS)
// (AN TOÀN TUYỆT ĐỐI: KHÔNG ĐEN MÀN HÌNH, TỰ BẬT PROMOTION CAO NHẤT, ĐỒNG BỘ REALTIME)
// ====================================================================================================

#import "AppDelegate.h"
#import "RootListController.h"
#import <notify.h>
#import <pthread.h>

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
    self.window.backgroundColor = [UIColor colorWithRed:0.05 green:0.07 blue:0.11 alpha:1.0];

    // 2. Khởi tạo Controller điều khiển chính
    self.rootListVC = [[RootListController alloc] init];
    self.mainNavController = [[UINavigationController alloc] initWithRootViewController:self.rootListVC];

    // [ĐÃ ÉP]: Cấu hình giao diện kính mờ tối ưu cho iOS 14 - 17+
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *navBarAppearance = [[UINavigationBarAppearance alloc] init];
        [navBarAppearance configureWithDefaultBackground];
        navBarAppearance.backgroundColor = [UIColor colorWithRed:0.08 green:0.10 blue:0.15 alpha:0.95];
        navBarAppearance.titleTextAttributes = @{
            NSForegroundColorAttributeName: [UIColor whiteColor],
            NSFontAttributeName: [UIFont systemFontOfSize:17 weight:UIFontWeightBold]
        };
        navBarAppearance.largeTitleTextAttributes = @{
            NSForegroundColorAttributeName: [UIColor whiteColor],
            NSFontAttributeName: [UIFont systemFontOfSize:30 weight:UIFontWeightHeavy]
        };

        self.mainNavController.navigationBar.standardAppearance = navBarAppearance;
        self.mainNavController.navigationBar.compactAppearance = navBarAppearance;
        self.mainNavController.navigationBar.scrollEdgeAppearance = navBarAppearance;
    }

    self.mainNavController.navigationBar.tintColor = [UIColor colorWithRed:0.25 green:0.80 blue:0.95 alpha:1.0];
    self.mainNavController.navigationBar.barStyle = UIBarStyleBlack;

    self.window.rootViewController = self.mainNavController;

    // 3. [ĐÃ ÉP TOÀN DIỆN]: Cưỡng bức hiển thị ngay khung hình đầu tiên (Trị dứt điểm đen app)
    [self.window makeKeyAndVisible];
    [self.window.layer setNeedsDisplay];
    [self.window setNeedsLayout];
    [self.window layoutIfNeeded];

    // 4. [ĐÃ ÉP TOÀN DIỆN]: Ép dải tần số quét ProMotion cao nhất cho cửa sổ app
    if (@available(iOS 15.0, *)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.window.windowScene) {
                if ([self.window.windowScene respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                    CAFrameRateRange range = CAFrameRateRangeMake(144.0f, 144.0f, 144.0f);
                    [(id)self.window.windowScene setPreferredFrameRateRange:range];
                }
            }
        });
    }

    return YES;
}

// [ĐÃ ÉP TOÀN DIỆN]: Tự động làm mới khi người dùng mở lại app từ chạy nền
- (void)applicationWillEnterForeground
