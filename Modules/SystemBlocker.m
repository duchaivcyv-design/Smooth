#import "SystemBlocker.h"
#import <objc/runtime.h>
#import <CoreLocation/CoreLocation.h>
#import <StoreKit/StoreKit.h>

// ------------------------------------------------------------------------------
// 1. DECLARATION OF HOOK FUNCTIONS (PHẢI ĐẶT TRÊN IMPLEMENTATION CLASS)
// ------------------------------------------------------------------------------

// Forward declarations để compiler biết chúng tồn tại
static void blocker_hook_locationStart(id self, SEL _cmd);
static void blocker_hook_icloudSync(id self, SEL _cmd);
static void blocker_hook_storeReview(id self, SEL _cmd);

// Storage for Original IMPs
static IMP orig_cl_startUpdating_IMP = NULL;
static IMP orig_ubiqu_sync_IMP = NULL;
static IMP orig_sk_requestReview_IMP = NULL;

// Helper function to check if blocker is active via Singleton
// Cách này an toàn hơn việc dùng biến global extern
BOOL isBlockerActive() {
    return [[SystemBlocker sharedInstance] isActive];
}

// ------------------------------------------------------------------------------
// 2. IMPLEMENTATION OF HOOK FUNCTIONS
// ------------------------------------------------------------------------------

// 1. Location Blocker Logic
static void blocker_hook_locationStart(id self, SEL _cmd) {
    if (!isBlockerActive()) {
        if (orig_cl_startUpdating_IMP) ((void(*)(id, SEL))orig_cl_startUpdating_IMP)(self, _cmd);
        return;
    }
    
    // Logic: Chỉ cho phép chạy nếu Bundle ID nằm trong whitelist
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSArray *whitelist = @[
        @"com.apple.Maps",
        @"com.apple.mobileslideshow", 
        @"uber.ridepassengeriphone",
        @"grab.driver.ios"
    ];
    
    BOOL allowed = NO;
    for (NSString *bid in whitelist) {
        if ([bundleID isEqualToString:bid]) {
            allowed = YES;
            break;
        }
    }
    
    if (allowed) {
        NSLog(@"[SystemBlocker] Allowing Location for %@", bundleID);
        if (orig_cl_startUpdating_IMP) ((void(*)(id, SEL))orig_cl_startUpdating_IMP)(self, _cmd);
    } else {
        NSLog(@"[SystemBlocker] BLOCKED Location for %@", bundleID);
        // Do nothing -> App thinks location service is unavailable or just hasn't updated yet.
    }
}

// 2. iCloud Sync Blocker Logic
static void blocker_hook_icloudSync(id self, SEL _cmd) {
    if (!isBlockerActive()) {
        if (orig_ubiqu_sync_IMP) ((void(*)(id, SEL))orig_ubiqu_sync_IMP)(self, _cmd);
        return;
    }
    
    // Delay sync heavily to prevent network congestion during gaming/coding
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
         if (orig_ubiqu_sync_IMP) ((void(*)(id, SEL))orig_ubiqu_sync_IMP)(self, _cmd);
    });
    
    NSLog(@"[SystemBlocker] Deferred iCloud Sync by 30s");
}

// 3. Store Review Blocker Logic
static void blocker_hook_storeReview(id self, SEL _cmd) {
    if (!isBlockerActive()) {
        if (orig_sk_requestReview_IMP) ((void(*)(id, SEL))orig_sk_requestReview_IMP)(self, _cmd);
        return;
    }
    
    // Simply do nothing. The prompt never appears.
    NSLog(@"[SystemBlocker] Suppressed Rating Prompt");
}


// ------------------------------------------------------------------------------
// 3. CLASS IMPLEMENTATION
// ------------------------------------------------------------------------------

@implementation SystemBlocker {
    BOOL _isActive;
}

+ (instancetype)sharedInstance {
    static SystemBlocker *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (BOOL)isActive {
    return _isActive;
}

- (void)initBlockers {
    if (_isActive) return;
    
    NSLog(@"[SystemBlocker] Initializing Deep System Interception...");
    
    // 1. CHẶN GPS (Location Services)
    Class clClass = objc_getClass("CLLocationManager");
    if (clClass) {
        Method m = class_getInstanceMethod(clClass, @selector(startUpdatingLocation));
        if (m) {
            orig_cl_startUpdating_IMP = method_getImplementation(m);
            method_setImplementation(m, (IMP)blocker_hook_locationStart);
        }
    }

    // 2. CHẶN ICLOUD SYNC
    Class ubiqClass = objc_getClass("NSUbiquitousKeyValueStore");
    if (ubiqClass) {
        Method m = class_getInstanceMethod(ubiqClass, NSSelectorFromString(@"synchronize"));
        if (m) {
            orig_ubiqu_sync_IMP = method_getImplementation(m);
            method_setImplementation(m, (IMP)blocker_hook_icloudSync);
        }
    }

    // 3. CHẶN RATING PROMPT
    Class skClass = objc_getClass("SKStoreReviewController");
    if (skClass) {
        Method m = class_getInstanceMethod(skClass, NSSelectorFromString(@"requestReviewInScene:"));
        if (!m) m = class_getInstanceMethod(skClass, NSSelectorFromString(@"requestReview"));
        
        if (m) {
            orig_sk_requestReview_IMP = method_getImplementation(m);
            method_setImplementation(m, (IMP)blocker_hook_storeReview);
        }
    }

    _isActive = YES;
    NSLog(@"[SystemBlocker] Active. GPS/iCloud/Ads Blocked.");
}

- (void)stopBlockers {
    if (!_isActive) return;
    
    // Restore implementations would go here if strictly needed, 
    // but usually killing the process/respring handles cleanup.
    _isActive = NO;
    NSLog(@"[SystemBlocker] Deactivated.");
}

@end
