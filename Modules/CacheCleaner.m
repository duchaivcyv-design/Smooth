#import "CacheCleaner.h"
#import <UIKit/UIKit.h>

@implementation CacheCleaner

+ (void)forceMemoryPurge {
    @autoreleasepool {
        // Đánh lừa HĐH rằng máy sắp cạn RAM để Apple tự kích hoạt chổi quét rác cực mạnh
        [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    }
}

+ (void)forceDeepMemoryPurge {
    @autoreleasepool {
        [self forceMemoryPurge];
        @try {
            [[NSURLCache sharedURLCache] removeAllCachedResponses];
            [[NSURLCache sharedURLCache] setMemoryCapacity:0];
            [[NSURLCache sharedURLCache] setDiskCapacity:0];
        } @catch(NSException *e) {}
    }
}

@end
