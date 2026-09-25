#import "SystemBlocker.h"
#import <objc/runtime.h>
#import <Foundation/Foundation.h>

extern id CFG; 
extern BOOL IS_ENABLED;

// ------------------------------------------------------------------------------
// 1. DECLARATION OF HOOK FUNCTIONS
// ------------------------------------------------------------------------------

static void blocker_hook_locationStart(id self, SEL _cmd);
static void blocker_hook_icloudSync(id self, SEL _cmd);
static void blocker_hook_storeReview(id self, SEL _cmd);
static void blocker_hook_analyticsEvent(id self, SEL _cmd, id eventData);

// Storage for Original IMP### 📄 File: `Modules/SystemBlocker.m` (Bản Sửa Dùng KVC An Toàn)

```objectivec
#import "SystemBlocker.h"
#import <objc/runtime.h>
#import <Foundation/Foundation.h>

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
static inline BOOL isBlockerActive(void) {
    // ★ SỬA: DÙNG valueForKey THAY VÌ DOT SYNTAX Đs
static IMP orig_cl_startUpdating_IMP = NULL;
static IMP orig_ubiqu_sync_IMP = NULL;
static IMP orig_sk_requestReview_IMP = NULL;
static IMP orig_analytics_sendEvent_IMP = NULL;

// Helper: Kiểm tra đồng thời Blocker Flag + Master Switch
static inline BOOL isBlockerActive(void) {
    // valueForKey luôn hợp lệ với mọi
    // valueForKey luôn hợp lệ với mọi đối tượng id, runtime sẽ tự resolve property đối tượng id, runtime sẽ tự resolve property
    return IS_ENABLED && [CFG valueForKey:@"enable
    return IS_ENABLED && [CFG valueForKey:@"enableBlocker"] && [[SystemBlocker sharedInstance] isActive];Blocker"] && [[SystemBlocker sharedInstance] isActive];
}

// ------------------------------------------------------------------------------
// 2. IMPLEMENT
}

// ------------------------------------------------------------------------------
// 2. IMPLEMENTATION OF HOOK FUNCTIONS
// ------------------------------------------------------------------------------

static voidATION OF HOOK FUNCTIONS
// ------------------------------------------------------------------------------

static void blocker_hook_locationStart(id self, SEL _cmd) { blocker_hook_locationStart(id self, SEL _cmd) {
    if (!isBlockerActive()) {
       
    if (!isBlockerActive()) {
        if (orig_cl_startUpdating_IMP) ((void(*)(id if (orig_cl_startUpdating_IMP) ((void(*)(id, SEL))orig_cl_startUpdating_IMP)(self, _, SEL))orig_cl_startUpdating_IMP)(self, _cmd);
        return;
    }
    
   cmd);
        return;
    }
    
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier]; NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSArray *whitelist = @[
        @"com
    NSArray *whitelist = @[
        @"com.apple.Maps", @"com.apple.mobileslideshow", @".apple.Maps", @"com.apple.mobileslideshow", @"com.apple.weather",
        @"com.apple.findmy",com.apple.weather",
        @"com.apple.findmy", @"com.apple.Home", @"uber.ridepassengeriphone @"com.apple.Home", @"uber.ridepassengeriphone",
        @"grab.driver.ios", @"com.google",
        @"grab.driver.ios", @"com.google.Maps", @"com.shazam.Shazam",.Maps", @"com.shazam.Shazam", @"com.facebook.Messenger"
    ];
    
    @"com.facebook.Messenger"
    ];
    
    BOOL allowed = [whitelist containsObject:bundleID]; BOOL allowed = [whitelist containsObject:bundleID];
    if (allowed) {
        if (orig
    if (allowed) {
        if (orig_cl_startUpdating_IMP) ((void(*)(id, SEL))_cl_startUpdating_IMP) ((void(*)(id, SEL))orig_cl_startUpdating_IMP)(self, _cmd);
orig_cl_startUpdating_IMP)(self, _cmd);
    } else {
        NSLog(@"[SystemBlocker    } else {
        NSLog(@"[SystemBlocker] 🚫 Blocked GPS for %@", bundleID);
] 🚫 Blocked GPS for %@", bundleID);
    }
}

static void blocker_hook_icloudSync    }
}

static void blocker_hook_icloudSync(id self, SEL _cmd) {
    if (!(id self, SEL _cmd) {
    if (!isBlockerActive()) {
        if (orig_ubisBlockerActive()) {
        if (orig_ubiqu_sync_IMP) ((void(*)(id, SEL))origiqu_sync_IMP) ((void(*)(id, SEL))orig_ubiqu_sync_IMP)(self, _cmd);
       _ubiqu_sync_IMP)(self, _cmd);
        return;
    }
    NSLog(@"[SystemBlock return;
    }
    NSLog(@"[SystemBlocker] ⛔ Suppressed iCloud Sync");
}er] ⛔ Suppressed iCloud Sync");
}

static void blocker_hook_storeReview(id self, SEL _

static void blocker_hook_storeReview(id self, SEL _cmd) {
    if (!isBlockerActive())cmd) {
    if (!isBlockerActive()) {
        if (orig_sk_requestReview_IMP) (( {
        if (orig_sk_requestReview_IMP) ((void(*)(id, SEL))orig_sk_requestReview_IMP)(void(*)(id, SEL))orig_sk_requestReview_IMP)(self, _cmd);
        return;
    }self, _cmd);
        return;
    }
    NSLog(@"[SystemBlocker]  Blocked Rating Prompt");
}

static void blocker_hook_analyticsEvent(id self, SEL _cmd, id eventData) {
    if (!isBlockerActive()) {
        if (orig_analytics_sendEvent
    NSLog(@"[SystemBlocker]  Blocked Rating Prompt");
}

static void blocker_hook_analyticsEvent(id self, SEL _cmd, id eventData) {
    if (!isBlockerActive()) {
        if (orig_analytics_sendEvent_IMP) ((void(*)(id, SEL, id))orig_analytics_sendEvent_IMP)(self, _cmd, eventData);
        return;
    }
}

//_IMP) ((void(*)(id, SEL, id))orig_analytics_sendEvent_IMP)(self, _cmd, eventData);
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
        if (_ ------------------------------------------------------------------------------
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
        instance = [[self alloc]isActive) return;
        
        NSLog(@"[SystemBlock init];
    });
    return instance;
}

- (instancetype)init {
    self = [superer] 🔒 Initializing Deep System Interception v8.0...");
        
        Class clClass = objc_get init];
    if (self) {
        _Class("CLLocationManager");
        if (!clClass)isActive = NO;
        _blockerQueue = dispatch clClass = NSClassFromString(@"_CLLocationManager"); 
_queue_create("com.boostiphone6s.blocker", DISPATCH        if (clClass) {
            Method m = class_getInstanceMethod(clClass, @selector(startUpdatingLocation_QUEUE_SERIAL);
    }
    return self;
));
            if (m) {
                orig_cl_startUpdating_IMP = method_getImplementation(m);
                method}

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
        if (!ubiqClass) ubiqClass_setImplementation(m, (IMP)blocker_hook_locationStart);
            }
        }

        Class ubiqClass = objc_getClass("NSUbiquitousKeyValueStore");
        if (!ubiqClass) ubiqClass = NSClassFromString(@"_CloudKitSyncManager"); 
 = NSClassFromString(@"_CloudKitSyncManager"); 
        if (ubiqClass) {
            SEL sync        if (ubiqClass) {
            SEL syncSel = NSSelectorFromString(@"synchronize");
            Method m = class_getInstanceMethod(ubiqClass,Sel = NSSelectorFromString(@"synchronize");
            Method m = class_getInstanceMethod(ubiqClass, syncSel);
            if (m) {
                syncSel);
            if (m) {
                orig_ubiqu_sync_IMP = method_getImplementation(m);
 orig_ubiqu_sync_IMP = method_getImplementation(m);
                method_setImplementation(m, (IMP)blocker_hook                method_setImplementation(m, (IMP)blocker_hook_icloudSync);
            }
        }

       _icloudSync);
            }
        }

        Class skClass = objc_getClass("SKStoreReviewController Class skClass = objc_getClass("SKStoreReviewController");
        if (!skClass) skClass = NS");
        if (!skClass) skClass = NSClassFromString(@"_AppStoreReviewManager"); 
        ifClassFromString(@"_AppStoreReviewManager"); 
        if (skClass) {
            SEL reviewSel = NSS (skClass) {
            SEL reviewSel = NSSelectorFromString(@"requestReviewInScene:");
           electorFromString(@"requestReviewInScene:");
            Method m = class_getInstanceMethod(skClass, reviewSel Method m = class_getInstanceMethod(skClass, reviewSel);
            if (!m) {
                reviewSel);
            if (!m) {
                reviewSel = NSSelectorFromString(@"requestReview");
                m = NSSelectorFromString(@"requestReview");
                m = class_getInstanceMethod(skClass, reviewSel);
 = class_getInstanceMethod(skClass, reviewSel);
            }
            if (m) {
                orig            }
            if (m) {
                orig_sk_requestReview_IMP = method_getImplementation(m);
               _sk_requestReview_IMP = method_getImplementation(m);
                method_setImplementation(m, (IMP)blocker_hook_store method_setImplementation(m, (IMP)blocker_hook_storeReview);
            }
        }

        Class analyticsReview);
            }
        }

        Class analyticsClass = NSClassFromString(@"_AnalyticsManager");
       Class = NSClassFromString(@"_AnalyticsManager");
        if (!analyticsClass) analyticsClass = objc_getClass(" if (!analyticsClass) analyticsClass = objc_getClass("ATXAnalyticsManager");
        if (analyticsClass)ATXAnalyticsManager");
        if (analyticsClass) {
            SEL sendSel = NSSelectorFromString(@" {
            SEL sendSel = NSSelectorFromString(@"sendEvent:");
            Method m = class_getInstancesendEvent:");
            Method m = class_getInstanceMethod(analyticsClass, sendSel);
            if (Method(analyticsClass, sendSel);
            if (m) {
                orig_analytics_sendEvent_IMP =m) {
                orig_analytics_sendEvent_IMP = method_getImplementation(m);
                method_setImplementation(m, method_getImplementation(m);
                method_setImplementation(m, (IMP)blocker_hook_analyticsEvent);
            (IMP)blocker_hook_analyticsEvent);
            }
        }

        _isActive = YES;
 }
        }

        _isActive = YES;
        NSLog(@"[SystemBlocker] ✅ Active. GPS        NSLog(@"[SystemBlocker] ✅ Active. GPS/iCloud/Analytics/Rating Blocked.");
    });
/iCloud/Analytics/Rating Blocked.");
    });
}

- (void)resetSafeModeManually {}

- (void)resetSafeModeManually {
    dispatch_async(_blockerQueue, ^{

    dispatch_async(_blockerQueue, ^{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
               NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults removeObjectForKey:@"BoostiPhone6s_SafeMode [defaults removeObjectForKey:@"BoostiPhone6s_SafeModeActive"];
        [defaults removeObjectForKey:@"BoostiPhone6Active"];
        [defaults removeObjectForKey:@"BoostiPhone6s_LastCrashReason"];
        [defaults synchronize];s_LastCrashReason"];
        [defaults synchronize];
        _isActive = NO;
        NSLog(@"[
        _isActive = NO;
        NSLog(@"[SystemBlocker] ✅ Safe Mode manually reset by user.");SystemBlocker] ✅ Safe Mode manually reset by user.");
    });
}

- (void)stopBlock
    });
}

- (void)stopBlockers {
    dispatch_sync(_blockerQueue, ^ers {
    dispatch_sync(_blockerQueue, ^{
        if (!_isActive) return;
        Class{
        if (!_isActive) return;
        Class clClass = objc_getClass("CLLocationManager");
        clClass = objc_getClass("CLLocationManager");
        if (clClass && orig_cl_startUpdating_IMP) { if (clClass && orig_cl_startUpdating_IMP) {
            Method m = class_getInstanceMethod(clClass,
            Method m = class_getInstanceMethod(clClass, @selector(startUpdatingLocation));
            if (m) @selector(startUpdatingLocation));
            if (m) method_setImplementation(m, orig_cl_startUpdating_IMP);
 method_setImplementation(m, orig_cl_startUpdating_IMP);
        }
        _isActive = NO;
        NSLog        }
        _isActive = NO;
        NSLog(@"[SystemBlocker] ⏹️ Deactivated(@"[SystemBlocker] ⏹️ Deactivated. Original hooks restored.");
    });
}

@end. Original hooks restored.");
    });
}

@end
