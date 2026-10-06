#import "AppDelegate.h"
#import "MockDeviceViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Khởi tạo cửa sổ chính hiển thị toàn màn hình thiết bị thật
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    // Gắn Controller giả lập làm gốc
    MockDeviceViewController *rootVC = [[MockDeviceViewController alloc] init];
    self.window.rootViewController = rootVC;
    
    // Đưa cửa sổ lên trên cùng và kích hoạt hiển thị
    [self.window makeKeyAndVisible];
    return YES;
}

@end
