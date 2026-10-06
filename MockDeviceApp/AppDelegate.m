#import "AppDelegate.h"
#import "MockDeviceViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    MockDeviceViewController *rootVC = [[MockDeviceViewController alloc] init];
    self.window.rootViewController = rootVC;
    [self.window makeKeyAndVisible];
    return YES;
}

@end
