#import "SystemBlocker.h"
#import <objc/runtime.h>
#import <Foundation/Foundation.h>

// Thay vào đó, khai báo extern các biến global từ Tweak.xm để sử dụng
extern id CFG; 
extern BOOL IS_ENABLED;

// ------------------------------------------------------------------------------
// 1. DECLARATION OF HOOK FUNCTIONS
// ------------------------------------------------------------------------------

static void blocker_hook_locationStart(id self, SEL _cmd);
static void blocker_hook_icloudSync(id self, SEL _cmd);
static void blocker_hook_storeReview(id self, SEL _cmd);
static void blocker_hook_analyticsEvent(id self, SEL _cmd, id eventData);

// Storage for Original IMPs
static IMP orig_cl_startUpdating_IMP = NULL;
static IMP orig_ubiqu_sync_IMP = NULL;
static IMP orig_sk_requestReview_IMP = NULL;
static IMP orig_analytics_sendEvent_IMP = NULL;

// Helper: Kiểm tra đồng thời Blocker Flag + Master Switch
BOOL isBlockerActive() {
    // Truy cập biến extern IS_ENABLED đã khai báo ở trên
    return [[SystemBlocker sharedInstance] isActive] && IS_ENABLED;
}

// ------------------------------------------------------------------------------
// 2. IMPLEMENTATION OF HOOK FUNCTIONS
// ------------------------------------------------------------------------------

// 1. Location Blocker (Whitelist Smart)
static void blocker_hook_locationStart(id self, SEL _cmd) {
    if (!isBlockerActive()) {
        if (orig_cl_startUpdating_IMP) ((void(*)(id, SEL))orig_cl_startUpdating_IMP)(self, _cmd);
        return;
    }
    
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSArray *whitelist = @[
        @"com.apple.Maps",
        @"com.apple.mobileslideshow",
        @"com.apple.weather",
        @"uber.ridepassengeriphone",
        @"grab.driver.ios",
        @"com.google.Maps"
    ];
    
    BOOL allowed = [whitelist containsObject:bundleID];
    
    if (allowed) {
        if (orig_cl_startUpdating_IMP) ((void(*)(id, SEL))orig_cl_startUpdating_IMP)(self, _cmd);
    } else {
        NSLog(@"[SystemBlocker] Blocked GPS for %@", bundleID);
    }
}

// 2. iCloud Sync Blocker (True Blocking - No Delay)
static void blocker_hook_icloudSync(id self, SEL _cmd) {
    if (!isBlockerActive()) {
        if (orig_ubiqu_sync_IMP) ((void(*)(id, SEL))orig_ubiqu_sync_IMP)(self, _cmd);
        return;
    }
    NSLog(@"[SystemBlocker] Suppressed iCloud Sync");
}

// 3. Store Review Blocker (Multi-Version Compatible)
static void blocker_hook_storeReview(id self, SEL _cmd) {
    if (!isBlockerActive()) {
        if (orig_sk_requestReview_IMP) ((void(*)(id, SEL))orig_sk_requestReview_IMP)(self, _cmd);
        return;
    }
    NSLog(@"[SystemBlocker] Blocked Rating Prompt");
}

// 4. Analytics Blocker (New for v7.0)
static void blocker_hook_analyticsEvent(id self, SEL _cmd, id eventData) {
    if (!isBlockerActive()) {
        if (orig_analytics_sendEvent_IMP) ((void(*)(id, SEL, id))orig_analytics_sendEvent_IMP)(self, _cmd, eventData);
        return;
    }
    // Silently drop all telemetry
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
    
    NSLog(@"[SystemBlocker] Initializing Deep System Interception v7.0...");
    
    // 1. CHẶN GPS (Location Services)
    Class clClass = objc_getClass("CLLocationManager");
    if (!clClass) clClass = NSClassFromString(@"_CLLocationManager"); 
    if (clClass) {
        Method m = class_getInstanceMethod(clClass, @selector(startUpdatingLocation));
        if (m) {
            orig_cl_startUpdating_IMP = method_getImplementation(m);
            method_setImplementation(m, (IMP)blocker_hook_locationStart);
        }
    }

    // 2. CHẶN ICLOUD SYNC (Compatible with iOS 14-26)
    Class ubiqClass = objc_getClass("NSUbiquitousKeyValueStore");
    if (!ubiqClass) ubiqClass = NSClassFromString(@"_CloudKitSyncManager"); 
    if (ubiqClass) {
        SEL syncSel = NSSelectorFromString(@"synchronize");
        Method m = class_getInstanceMethod(ubiqClass, syncSel);
        if (m) {
            orig_ubiqu_sync_IMP = method_getImplementation(m);
            method_setImplementation(m, (IMP)blocker_hook_icloudSync);
        }
    }

    // 3. CHẶN RATING PROMPT (Multi-selector fallback)
    Class skClass = objc_getClass("SKStoreReviewController");
    if (!skClass) skClass = NSClassFromString(@"_AppStoreReviewManager"); 
    if (skClass) {
        SEL reviewSel = NSSelectorFromString(@"requestReviewInScene:");
        Method m = class_getInstanceMethod(skClass, reviewSel);
        
        if (!m) {
            reviewSel = NSSelectorFromString(@"requestReview");
            m = class_getInstanceMethod(skClass, reviewSel);
        }
        
        if (m) {
            orig_sk_requestReview_IMP = method_getImplementation(m);
            method_setImplementation(m, (IMP)blocker_hook_storeReview);
        }
    }

    // 4. CHẶN ANALYTICS (New v7.0)
    Class analyticsClass = NSClassFromString(@"_AnalyticsManager");
    if (!analyticsClass) analyticsClass = objc_getClass("ATXAnalyticsManager");
    if (analyticsClass) {
        SEL sendSel = NSSelectorFromString(@"sendEvent:");
        Method m = class_getInstanceMethod(analyticsClass, sendSel);
        if (m) {
            // ★ SỬA: GÁN VÀO ĐÚNG BIẾN orig_analytics_sendEvent_IMP ★
            orig_analytics_sendEvent_IMP = method_getImplementation(m);
            method_setImplementation(m, (IMP)blocker_hook_analyticsEvent);
        }
    }

    _isActive = YES;
    NSLog(@"[SystemBlocker] Active. GPS/iCloud/Analytics/Rating Blocked.");
}

- (void)resetSafeModeManually {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:@"BoostiPhone6s_SafeModeActive"];
    [defaults removeObjectForKey:@"BoostiPhone6s_LastCrashReason"];
    [defaults synchronize];
    _isActive = NO;
    NSLog(@"[SystemBlocker] Safe Mode manually reset by user.");
}

- (void)stopBlockers {
    if (!_isActive) return;
    
    Class clClass = objc_getClass("CLLocationManager");
    if (clClass && orig_cl_startUpdating_IMP) {
        Method m = class_getInstanceMethod(clClass, @selector(startUpdatingLocation));
        if (m) method_setImplementation(m, orig_cl_startUpdating_IMP);
    }
    
    _isActive = NO;
    NSLog(@"[SystemBlocker] Deactivated. Original hooks restored.");
}

@end
