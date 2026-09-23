#import "SystemBlocker.h"
#import <objc/runtime.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <StoreKit/StoreKit.h>

// --- Storage for Original IMPs ---
static IMP orig_cl_startUpdating_IMP = NULL;
static IMP orig_cb_powerOn_IMP = NULL;
static IMP orig_ubiqu_sync_IMP = NULL;
static IMP orig_sk_requestReview_IMP = NULL;
static IMP orig_nsurl_session_config_IMP = NULL; // Optional: Network throttling

@implementation SystemBlocker {
    BOOL _isBlocked;
}

+ (instancetype)sharedInstance {
    static SystemBlocker *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (void)initBlockers {
    if (_isBlocked) return;
    
    NSLog(@"[SystemBlocker] Initializing Deep System Interception...");
    
    // 1. CHẶN GPS (Location Services)
    // Khi app gọi startUpdatingLocation, ta bỏ qua nếu không phải app bản đồ/navigation chính thức
    Class clClass = objc_getClass("CLLocationManager");
    if (clClass) {
        Method m = class_getInstanceMethod(clClass, @selector(startUpdatingLocation));
        if (m) {
            orig_cl_startUpdating_IMP = method_getImplementation(m);
            method_setImplementation(m, (IMP)blocker_hook_locationStart);
        }
    }

    // 2. CHẶN BLUETOOTH SCANNING (Tiết kiệm pin & giảm nhiễu sóng)
    // Ép CBCentralManager luôn trả về trạng thái tắt hoặc ignore scan request
    Class cbClass = objc_getClass("CBCentralManager");
    if (cbClass) {
        Method m = class_getInstanceMethod(cbClass, NSSelectorFromString(@"scanForPeripheralsWithServices:options:"));
        if (m) {
            // Lưu ý: Hook setter/getter phức tạp hơn, ở đây ta chỉ demo concept blocking via notification suppression
            // Cách hiệu quả nhất cho BT là tắt adapter vật lý, nhưng user-space khó làm.
            // Thay vào đó, ta chặn NSNotificationCenter broadcast từ CoreBluetooth
        }
    }

    // 3. CHẶN ICLOUD SYNC (Giảm tải mạng nền)
    // Nhiều app đồng bộ dữ liệu liên tục gây lag UI. Ta ép sync delay cực lớn.
    Class ubiqClass = objc_getClass("NSUbiquitousKeyValueStore");
    if (ubiqClass) {
        Method m = class_getInstanceMethod(ubiqClass, NSSelectorFromString(@"synchronize"));
        if (m) {
            orig_ubiqu_sync_IMP = method_getImplementation(m);
            method_setImplementation(m, (IMP)blocker_hook_icloudSync);
        }
    }

    // 4. CHẶN RATING PROMPT (Hỏi đánh giá 5 sao phiền phức)
    // SKStoreReviewController hiện popup giữa chừng game rất mất tập trung.
    Class skClass = objc_getClass("SKStoreReviewController");
    if (skClass) {
        Method m = class_getInstanceMethod(skClass, NSSelectorFromString(@"requestReviewInScene:"));
        if (!m) m = class_getInstanceMethod(skClass, NSSelectorFromString(@"requestReview"));
        
        if (m) {
            orig_sk_requestReview_IMP = method_getImplementation(m);
            method_setImplementation(m, (IMP)blocker_hook_storeReview);
        }
    }

    _isBlocked = YES;
    NSLog(@"[SystemBlocker] Active. GPS/iCloud/Ads Blocked.");
}

- (void)stopBlockers {
    if (!_isBlocked) return;
    
    // Restore implementations would go here if strictly needed, 
    // but usually killing the process/respring handles cleanup.
    _isBlocked = NO;
    NSLog(@"[SystemBlocker] Deactivated.");
}

@end

// ------------------------------------------------------------------------------
// HOOK IMPLEMENTATIONS (C Functions called by Obj-C Runtime)
// ------------------------------------------------------------------------------

// Helper macro to check if blocker is active globally
extern BOOL g_blockerActive; // Define this in Tweak.xm or pass via singleton check

// We will use a simple global flag defined below for demonstration
static BOOL s_blockerGlobalFlag = NO;

void setBlockerFlag(BOOL val) {
    s_blockerGlobalFlag = val;
}

// 1. Location Blocker Logic
void blocker_hook_locationStart(id self, SEL _cmd) {
    if (!s_blockerGlobalFlag) {
        if (orig_cl_startUpdating_IMP) ((void(*)(id, SEL))orig_cl_startUpdating_IMP)(self, _cmd);
        return;
    }
    
    // Logic: Chỉ cho phép chạy nếu Bundle ID nằm trong whitelist (Maps, Uber...)
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSArray *whitelist = @[
        @"com.apple.Maps",
        @"com.apple.mobileslideshow", // Photos sometimes needs loc
        @"uber.ridepassengeriphone",
        @"grab.driver.ios",
        @"com.lazada.android" // Example shopping app might need it
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
        // Safer than crashing: Just don't call original.
    }
}

// 2. iCloud Sync Blocker Logic
void blocker_hook_icloudSync(id self, SEL _cmd) {
    if (!s_blockerGlobalFlag) {
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
void blocker_hook_storeReview(id self, SEL _cmd) {
    if (!s_blockerGlobalFlag) {
        if (orig_sk_requestReview_IMP) ((void(*)(id, SEL))orig_sk_requestReview_IMP)(self, _cmd);
        return;
    }
    
    // Simply do nothing. The prompt never appears.
    NSLog(@"[SystemBlocker] Suppressed Rating Prompt");
}
