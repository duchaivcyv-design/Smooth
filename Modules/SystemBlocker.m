#import "SystemBlocker.h"
#import <objc/runtime.h>
#import <Foundation/Foundation.h>

// Dùng extern để truy cập biến global mà không cần include file nguồn
extern BoostConfig *CFG; 
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
static inline BOOL isBlockerActive(void) {
    return IS_ENABLED && CFG.enableBlocker && [[SystemBlocker sharedInstance] isActive];
}

// ------------------------------------------------------------------------------
// 2. IMPLEMENTATION OF HOOK FUNCTIONS
// ------------------------------------------------------------------------------

static void blocker_hook_locationStart(id self, SEL _cmd) {
    if (!isBlockerActive()) {
        if (orig_cl_startUpdating_IMP) ((void(*)(id, SEL))orig_cl_startUpdating_IMP)(self, _cmd);
        return;
    }
    
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSArray *whitelist = @[
        @"com.apple.Maps", @"com.apple.mobileslideshow", @"com.apple.weather",
        @"com.apple.findmy", @"com.apple.Home", @"uber.ridepassengeriphone",
        @"grab.driver.ios", @"com.google.Maps", @"com.shazam.Shazam", @"com.facebook.Messenger"
    ];
    
    BOOL allowed = [whitelist containsObject:bundleID];
    if (allowed) {
        if (orig_cl_startUpdating_IMP) ((void(*)(id, SEL))orig_cl_startUpdating_IMP)(self, _cmd);
    } else {
        NSLog(@"[SystemBlocker] 🚫 Blocked GPS for %@", bundleID);
    }
}

static void blocker_hook_icloudSync(id self, SEL _cmd) {
    if (!isBlockerActive()) {
        if (orig_ubiqu_sync_IMP) ((void(*)(id, SEL))orig_ubiqu_sync_IMP)(self, _cmd);
        return;
    }
    NSLog(@"[SystemBlocker] ⛔ Suppressed iCloud Sync");
}

static void blocker_hook_storeReview(id self, SEL _cmd) {
    if (!isBlockerActive()) {
        if (orig_sk_requestReview_IMP) ((void(*)(id, SEL))orig_sk_requestReview_IMP)(self, _cmd);
        return;
    }
    NSLog(@"[SystemBlocker]  Blocked Rating Prompt");
}

static void blocker_hook_analyticsEvent(id self, SEL _cmd, id eventData) {
    if (!isBlockerActive()) {
        if (orig_analytics_sendEvent_IMP) ((void(*)(id, SEL, id))orig_analytics_sendEvent_IMP)(self, _cmd, eventData);
        return;
    }
}

// ------------------------------------------------------------------------------
// 3. CLASS IMPLEMENTATION
// ------------------------------------------------------------------------------

@implementation SystemBlocker {
    BOOL _isActive;
    dispatch_queue_t _blockerQueue;
}

+ (instancetype)sharedInstance {
    static SystemBlocker *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isActive = NO;
        _blockerQueue = dispatch_queue_create("com.boostiphone6s.blocker", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (BOOL)isActive { return _isActive; }

- (void)initBlockers {
    dispatch_sync(_blockerQueue, ^{
        if (_isActive) return;
        
        NSLog(@"[SystemBlocker] 🔒 Initializing Deep System Interception v8.0...");
        
        Class clClass = objc_getClass("CLLocationManager");
        if (!clClass) clClass = NSClassFromString(@"_CLLocationManager"); 
        if (clClass) {
            Method m = class_getInstanceMethod(clClass, @selector(startUpdatingLocation));
            if (m) {
                orig_cl_startUpdating_IMP = method_getImplementation(m);
                method_setImplementation(m, (IMP)blocker_hook_locationStart);
            }
        }

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

        Class analyticsClass = NSClassFromString(@"_AnalyticsManager");
        if (!analyticsClass) analyticsClass = objc_getClass("ATXAnalyticsManager");
        if (analyticsClass) {
            SEL sendSel = NSSelectorFromString(@"sendEvent:");
            Method m = class_getInstanceMethod(analyticsClass, sendSel);
            if (m) {
                orig_analytics_sendEvent_IMP = method_getImplementation(m);
                method_setImplementation(m, (IMP)blocker_hook_analyticsEvent);
            }
        }

        _isActive = YES;
        NSLog(@"[SystemBlocker] ✅ Active. GPS/iCloud/Analytics/Rating Blocked.");
    });
}

- (void)resetSafeModeManually {
    dispatch_async(_blockerQueue, ^{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults removeObjectForKey:@"BoostiPhone6s_SafeModeActive"];
        [defaults removeObjectForKey:@"BoostiPhone6s_LastCrashReason"];
        [defaults synchronize];
        _isActive = NO;
        NSLog(@"[SystemBlocker] ✅ Safe Mode manually reset by user.");
    });
}

- (void)stopBlockers {
    dispatch_sync(_blockerQueue, ^{
        if (!_isActive) return;
        Class clClass = objc_getClass("CLLocationManager");
        if (clClass && orig_cl_startUpdating_IMP) {
            Method m = class_getInstanceMethod(clClass, @selector(startUpdatingLocation));
            if (m) method_setImplementation(m, orig_cl_startUpdating_IMP);
        }
        _isActive = NO;
        NSLog(@"[SystemBlocker] ⏹️ Deactivated. Original hooks restored.");
    });
}

@end
