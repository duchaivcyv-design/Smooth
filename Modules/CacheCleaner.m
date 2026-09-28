#import "CacheCleaner.h"
#import <UIKit/UIKit.h>

@implementation CacheCleaner

+ (void)forceMemoryPurge {
    @autoreleasepool {
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
