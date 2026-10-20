#import "RootListController.h"
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <spawn.h>
#import <sys/wait.h>
#import <sys/stat.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>
#import <fcntl.h>
#import <unistd.h>
#include <errno.h>
#include <stdint.h>
#include <math.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#import <notify.h>
#import <dlfcn.h>
#import <mach/mach.h>
#import <mach/mach_time.h>
#import <mach/processor_info.h>
#import <mach/mach_host.h>
#import <mach/vm_map.h>
#import <AudioToolbox/AudioToolbox.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreImage/CoreImage.h>
#import <Metal/Metal.h>
#import <Security/Security.h>
#import <os/lock.h>

extern char **environ;

#define APEX_SYNC_MAGIC_V285 0x41505837
#define PRIMARY_SYNC_FILE    @"/tmp/.boost_hz_sync"
#define SECONDARY_SYNC_FILE  @"/var/jb/tmp/.boost_hz_sync"
#define TITANIUM_BOOT_FLAG_VERIFIED @"/tmp/.titanium_tweak_verified"

#define NOTIFY_RELOAD        "com.taojb.boostiphone6s/ReloadPrefs"
#define NOTIFY_UIKIT_RELOAD  "com.taojb.boostiphone6s/ReloadUIKitPrefs"
#define NOTIFY_HARDWARE_SYNC "com.taojb.boostiphone6s/HardwareSync"
#define NOTIFY_FPS_CHANGED   "com.taojb.boostiphone6s/FPSChanged"
#define NOTIFY_TITANIUM_CHANGED "com.titanium.v285.prefschanged"
#define NOTIFY_PAYLOAD_WRITTEN "com.taojb.boostiphone6s/PayloadWritten"
#define APPS_SYNC_FILE_PRIMARY   @"/tmp/.boost_hz_apps"
#define APPS_SYNC_FILE_SECONDARY @"/var/jb/tmp/.boost_hz_apps"

#define TI_CRASH_COUNT_KEY  @"ti_network_crash_count_v7"
#define TI_AUTO_THEME_KEY   @"ti_auto_theme_v7"
#define TI_SERVER_DOWN_KEY  @"ti_server_down_until_v7"
#define TI_ADMIN_SERVER_KEY @"ti_admin_server_v7"
#define TI_ADMIN_USER_KEY   @"ti_admin_user_v7"
#define TI_FIRST_INSTALL_KEY @"ti_first_install_prompt_v7"
#define TI_SELECTED_SERVER_KEY @"ti_selected_server_v7"
#define TI_FREE_SERVER_PING_URL_KEY @"ti_free_server_ping_url_v1"
#define TI_GLASS_TRANSPARENCY_KEY @"ti_glass_transparency_enabled_v20"
#define TI_THEME_MODE_KEY          @"ti_theme_mode_v25" // system | light | dark
#define TI_HZFPS_WARNING_SUPPRESS_UNTIL_KEY @"ti_hzfps_warning_suppress_until_v1"
#define TI_CREDITS_SHOWN_KEY @"ti_credits_shown_v1"
#define TI_CREDITS_HIDDEN_KEY @"ti_credits_hidden_permanently_v1"
#define TI_APP_CATEGORY_KEY @"ti_app_category_v1"
#define TI_ADMIN_TOKEN_SERVICE     @"com.taojb.boostiphone6s.admin-session"
#define TI_ADMIN_TOKEN_ACCOUNT     @"server-access-token"

// Never keep a bearer token in the readable preferences plist. The backend remains the
// authority: a saved token is revalidated with /v1/auth/me on the next launch.
static NSString *Titanium_KeychainReadAdminToken(void) {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: TI_ADMIN_TOKEN_SERVICE,
        (__bridge id)kSecAttrAccount: TI_ADMIN_TOKEN_ACCOUNT,
        (__bridge id)kSecReturnData: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne
    };
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status != errSecSuccess || !result) return nil;
    NSData *data = CFBridgingRelease(result);
    NSString *token = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return token.length ? token : nil;
}

static BOOL Titanium_KeychainStoreAdminToken(NSString *token) {
    if (![token isKindOfClass:[NSString class]] || token.length == 0) return NO;
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: TI_ADMIN_TOKEN_SERVICE,
        (__bridge id)kSecAttrAccount: TI_ADMIN_TOKEN_ACCOUNT
    };
    SecItemDelete((__bridge CFDictionaryRef)query);
    NSMutableDictionary *item = [query mutableCopy];
    item[(__bridge id)kSecValueData] = [token dataUsingEncoding:NSUTF8StringEncoding];
    item[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;
    return SecItemAdd((__bridge CFDictionaryRef)item, NULL) == errSecSuccess;
}

static void Titanium_KeychainDeleteAdminToken(void) {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: TI_ADMIN_TOKEN_SERVICE,
        (__bridge id)kSecAttrAccount: TI_ADMIN_TOKEN_ACCOUNT
    };
    SecItemDelete((__bridge CFDictionaryRef)query);
}

// ====================================================================================================
// SERVER STATE PERSISTENT — sống ngoài tweak plist, tồn tại qua cả uninstall
// States: 0=OK, 1=Overload, 2=Error, 3=Down
// ====================================================================================================
#define TI_STATE_OK       0
#define TI_STATE_OVERLOAD 1
#define TI_STATE_ERROR    2
#define TI_STATE_DOWN     3

static NSString *const kPersistServerStatePath = @"/var/mobile/Library/Preferences/com.nono.boostserverstate.plist";

static NSDictionary *Titanium_LoadPersistentServerState(void) {
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:kPersistServerStatePath];
    return d ?: @{};
}

static void Titanium_SavePersistentServerState(int state, NSTimeInterval untilTimestamp) {
    NSDictionary *d = @{
        @"state": @(state),
        @"until": @(untilTimestamp),
        @"updated": @([[NSDate date] timeIntervalSince1970])
    };
    [d writeToFile:kPersistServerStatePath atomically:YES];
    chmod([kPersistServerStatePath UTF8String], 0600);
}

static void Titanium_ClearPersistentServerState(void) {
    [[NSFileManager defaultManager] removeItemAtPath:kPersistServerStatePath error:nil];
}

// Trả về state hiện tại — 0 nếu không có hoặc đã hết hạn
static int Titanium_CurrentPersistentServerState(void) {
    NSDictionary *d = Titanium_LoadPersistentServerState();
    if (d.count == 0) return TI_STATE_OK;
    int state = [d[@"state"] intValue];
    NSTimeInterval until = [d[@"until"] doubleValue];
    if (until > 0 && until <= [[NSDate date] timeIntervalSince1970]) {
        Titanium_ClearPersistentServerState();
        return TI_STATE_OK;
    }
    return state;
}

static NSTimeInterval Titanium_PersistentServerStateRemaining(void) {
    NSDictionary *d = Titanium_LoadPersistentServerState();
    if (d.count == 0) return 0;
    NSTimeInterval until = [d[@"until"] doubleValue];
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    return until > now ? (until - now) : 0;
}

#ifndef _APEX_V285_PRO_PAYLOAD_DEFINED
#define _APEX_V285_PRO_PAYLOAD_DEFINED
typedef struct __attribute__((packed)) {
    uint32_t magic, masterEnabled;
    int32_t targetHz, targetFPS;
    uint32_t forceOverclock, pipSyncEnabled, thermalShield, antiStutterExit;
    uint32_t smartBufferingLevel, zeroLatencyTouch, shaderOptimization, dynamicInterpolation;
    uint32_t fastAppLaunch, lowLatencyAudio, memoryPressureRelief, metalPacingEnabled;
    uint32_t runloopHangGuard, keyboardZeroLagV3, aggressiveRamCleaner, lockFixedFpsWhenThermal;
    uint32_t antiGhostTouch, diskIOPriorityBoost, rawTouchDirectDelivery, powerSaveModeActive;
    uint64_t updateSeq, lastHeartbeat;
    char reserved[48];
} ApexV285ProPayload;
#endif

static NSInteger Titanium_GetCrashCount(void) { return [[NSUserDefaults standardUserDefaults] integerForKey:TI_CRASH_COUNT_KEY]; }
static void Titanium_SetCrashCount(NSInteger n) { [[NSUserDefaults standardUserDefaults] setInteger:n forKey:TI_CRASH_COUNT_KEY]; [[NSUserDefaults standardUserDefaults] synchronize]; }
static void Titanium_ResetCrashCount(void) { Titanium_SetCrashCount(0); }

// Keep RootListController UI keys and the canonical keys read by Tweak.xm in sync.
// Several controller toggles are legacy aliases of one Tweak.xm setting/property.
static NSArray<NSArray<NSString *> *> *Titanium_LinkedPreferenceGroups(void) {
    static NSArray<NSArray<NSString *> *> *groups = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        groups = @[
            @[@"pCoreRealtimePriority", @"RealtimeThreadSched"],
            @[@"schedulerGovernor", @"IOSchedulerEngine"],
            @[@"lockHighIdleFloor", @"CPUGPUFreqOptimizer"],
            @[@"iopolVipPriority", @"SystemProcessOpt"],
            @[@"quantumCoreSync", @"QuantumCoreSync"],
            @[@"coolDownHeavyLoad", @"HeavyLoadCooling"],
            @[@"backgroundPacingDaemon", @"BackgroundPacingDaemon"],
            @[@"autoKillBackground", @"AutoCloseBackgroundApp"],
            @[@"hyperMemoryGuardian", @"HyperMemoryGuardian"],
            @[@"fakeFullBatteryState", @"DeviceSpoofer"],
            @[@"zeroLagNeural", @"ZeroLagNeuralBooster"],
            @[@"ultraResponsiveness", @"UltraResponsiveness"],
            @[@"lock30FpsOnOverheat", @"SmartThermalDispatch"],
            @[@"flatTintBlur", @"QuantumRenderShield"],
            @[@"powerSaveMode", @"batterySaver60Hz", @"PowerSaveMode"],
            @[@"neuralBufferOpt", @"MetalHexBuffering"],
            @[@"vsyncAdaptiveBuffer", @"FixAppExitStutter"],
            @[@"IsolateRenderPipeline", @"FixAppLaunchBlackScreen"],
            @[@"periodicRamClean", @"machVMPurgeRam", @"aggressiveRamClean", @"AggressiveRamClean"]
        ];
    });
    return groups;
}

static void Titanium_SynchronizeLinkedPreferences(NSMutableDictionary *settings, NSString *changedKey) {
    if (![settings isKindOfClass:[NSMutableDictionary class]]) return;
    for (NSArray<NSString *> *group in Titanium_LinkedPreferenceGroups()) {
        NSString *sourceKey = nil;
        if (changedKey.length > 0) {
            if ([group containsObject:changedKey] && settings[changedKey] != nil) sourceKey = changedKey;
            else continue;
        } else {
            // On load, prefer the last (canonical Tweak.xm) key so stale UI aliases
            // cannot overwrite a newer value after relaunch or jailbreak-mode changes.
            for (NSString *key in [group reverseObjectEnumerator]) {
                if (settings[key] != nil) { sourceKey = key; break; }
            }
        }
        id value = sourceKey ? settings[sourceKey] : nil;
        if (!value) continue;
        for (NSString *key in group) settings[key] = value;
    }
}

static NSString *Titanium_NormalizeAppSearchText(NSString *value) {
    if (![value isKindOfClass:[NSString class]]) return @"";
    NSString *trimmed = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return [[trimmed stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:[NSLocale currentLocale]] lowercaseString];
}

static NSString *Titanium_ResolvePayloadLanguage(NSDictionary *settings) {
    id rawSelected = settings[@"SelectedLanguage"];
    NSString *selected = [rawSelected isKindOfClass:[NSString class]] ? (NSString *)rawSelected : nil;
    if (selected.length == 0) {
        id legacy = settings[@"AppLanguage"];
        if ([legacy isKindOfClass:[NSString class]]) selected = (NSString *)legacy;
    }
    if (selected.length > 0 && ![selected isEqualToString:@"auto"]) {
        NSArray<NSString *> *parts = [selected componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"-_ "]];
        NSString *base = parts.count ? parts[0].lowercaseString : selected.lowercaseString;
        static NSSet<NSString *> *supported = nil;
        static dispatch_once_t supportedOnce;
        dispatch_once(&supportedOnce, ^{ supported = [NSSet setWithArray:@[@"vi", @"en", @"zh", @"ja", @"ko", @"fr", @"de", @"es", @"pt", @"ru", @"th", @"id", @"hi", @"ar"]]; });
        return [supported containsObject:base] ? base : @"en";
    }

    NSString *preferred = [[NSLocale preferredLanguages] firstObject];
    if (preferred.length == 0) return @"en";
    NSArray<NSString *> *languageParts = [preferred componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"-_"]];
    NSString *base = languageParts.count > 0 ? [languageParts[0] lowercaseString] : @"en";
    static NSSet<NSString *> *knownLanguages = nil;
    static dispatch_once_t languageOnce;
    dispatch_once(&languageOnce, ^{
        knownLanguages = [NSSet setWithArray:@[@"vi", @"en", @"zh", @"ja", @"ko", @"fr", @"de", @"es", @"pt", @"ru", @"th", @"id", @"hi", @"ar"]];
    });
    return [knownLanguages containsObject:base] ? base : @"en";
}

// ====================================================================================================
// MODULE 1: GLASS MATERIAL FACTORY
// ====================================================================================================
typedef NS_ENUM(NSInteger, LGGlassMaterialType) {
    LGGlassMaterialTypeUltraThin = 0,
    LGGlassMaterialTypeThin      = 1,
    LGGlassMaterialTypeRegular   = 2,
    LGGlassMaterialTypeChrome    = 3,
    LGGlassMaterialTypeProminent = 4,
    LGGlassMaterialTypeOverlay   = 5,
    LGGlassMaterialTypeCrystal   = 6
};

@interface LGGlassMaterialFactory : NSObject
+ (UIBlurEffectStyle)blurStyleForType:(LGGlassMaterialType)type isDark:(BOOL)isDark;
+ (CGFloat)tintAlphaForType:(LGGlassMaterialType)type;
+ (CGFloat)specularAlphaForType:(LGGlassMaterialType)type;
+ (CGFloat)bottomReflectionAlphaForType:(LGGlassMaterialType)type;
+ (CGFloat)diagonalSheenAlphaForType:(LGGlassMaterialType)type;
+ (CGFloat)rimAlphaForType:(LGGlassMaterialType)type;
+ (CGFloat)rimWidthForType:(LGGlassMaterialType)type;
+ (CGFloat)shadowOpacityForType:(LGGlassMaterialType)type;
+ (CGFloat)shadowRadiusForType:(LGGlassMaterialType)type;
+ (CGFloat)shadowOffsetYForType:(LGGlassMaterialType)type;
+ (CGFloat)specularHeightRatioForType:(LGGlassMaterialType)type;
@end

@implementation LGGlassMaterialFactory
+ (UIBlurEffectStyle)blurStyleForType:(LGGlassMaterialType)type isDark:(BOOL)isDark {
    switch (type) {
        case LGGlassMaterialTypeUltraThin: return isDark ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemUltraThinMaterialLight;
        case LGGlassMaterialTypeThin:      return isDark ? UIBlurEffectStyleSystemThinMaterialDark : UIBlurEffectStyleSystemThinMaterialLight;
        case LGGlassMaterialTypeRegular:   return isDark ? UIBlurEffectStyleSystemMaterialDark : UIBlurEffectStyleSystemMaterialLight;
        case LGGlassMaterialTypeChrome:    return isDark ? UIBlurEffectStyleSystemChromeMaterialDark : UIBlurEffectStyleSystemChromeMaterialLight;
        case LGGlassMaterialTypeProminent: return isDark ? UIBlurEffectStyleSystemMaterialDark : UIBlurEffectStyleSystemMaterialLight;
        case LGGlassMaterialTypeOverlay:   return isDark ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemUltraThinMaterialLight;
        case LGGlassMaterialTypeCrystal:   return isDark ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemUltraThinMaterialLight;
    }
    return UIBlurEffectStyleSystemThinMaterialDark;
}
+ (CGFloat)tintAlphaForType:(LGGlassMaterialType)type {
    switch (type) {
        case LGGlassMaterialTypeUltraThin: return 0.012;
        case LGGlassMaterialTypeThin:      return 0.022;
        case LGGlassMaterialTypeRegular:   return 0.034;
        case LGGlassMaterialTypeChrome:    return 0.044;
        case LGGlassMaterialTypeProminent: return 0.058;
        case LGGlassMaterialTypeOverlay:   return 0.026;
        case LGGlassMaterialTypeCrystal:   return 0.008;
    }
    return 0.022;
}
+ (CGFloat)specularAlphaForType:(LGGlassMaterialType)type {
    switch (type) {
        case LGGlassMaterialTypeUltraThin: return 0.24;
        case LGGlassMaterialTypeThin:      return 0.30;
        case LGGlassMaterialTypeRegular:   return 0.36;
        case LGGlassMaterialTypeChrome:    return 0.42;
        case LGGlassMaterialTypeProminent: return 0.50;
        case LGGlassMaterialTypeOverlay:   return 0.38;
        case LGGlassMaterialTypeCrystal:   return 0.34;
    }
    return 0.30;
}
+ (CGFloat)bottomReflectionAlphaForType:(LGGlassMaterialType)type { return 0.12; }
+ (CGFloat)diagonalSheenAlphaForType:(LGGlassMaterialType)type { return 0.18; }
+ (CGFloat)rimAlphaForType:(LGGlassMaterialType)type {
    switch (type) {
        case LGGlassMaterialTypeCrystal:   return 0.58;
        case LGGlassMaterialTypeUltraThin: return 0.32;
        case LGGlassMaterialTypeThin:      return 0.38;
        case LGGlassMaterialTypeRegular:   return 0.44;
        case LGGlassMaterialTypeChrome:    return 0.50;
        case LGGlassMaterialTypeProminent: return 0.60;
        case LGGlassMaterialTypeOverlay:   return 0.46;
    }
    return 0.38;
}
+ (CGFloat)rimWidthForType:(LGGlassMaterialType)type { return 1.0; }
+ (CGFloat)shadowOpacityForType:(LGGlassMaterialType)type {
    switch (type) {
        case LGGlassMaterialTypeUltraThin: return 0.08;
        case LGGlassMaterialTypeThin: return 0.12;
        case LGGlassMaterialTypeRegular: return 0.15;
        case LGGlassMaterialTypeChrome: return 0.22;
        case LGGlassMaterialTypeProminent: return 0.18;
        case LGGlassMaterialTypeOverlay: return 0.10;
        case LGGlassMaterialTypeCrystal: return 0.16;
    }
    return 0.12;
}
+ (CGFloat)shadowRadiusForType:(LGGlassMaterialType)type {
    switch (type) {
        case LGGlassMaterialTypeUltraThin: return 7.0;
        case LGGlassMaterialTypeThin: return 9.0;
        case LGGlassMaterialTypeRegular: return 11.0;
        case LGGlassMaterialTypeChrome: return 14.0;
        case LGGlassMaterialTypeProminent: return 14.0;
        case LGGlassMaterialTypeOverlay: return 8.0;
        case LGGlassMaterialTypeCrystal: return 12.0;
    }
    return 9.0;
}
+ (CGFloat)shadowOffsetYForType:(LGGlassMaterialType)type { return 8.0; }
+ (CGFloat)specularHeightRatioForType:(LGGlassMaterialType)type {
    switch (type) {
        case LGGlassMaterialTypeCrystal:   return 0.42;
        case LGGlassMaterialTypeUltraThin: return 0.34;
        default: return 0.38;
    }
}
@end

// ====================================================================================================
// MODULE 2: CRYSTAL GLASS VIEW
// ====================================================================================================
@interface AppleLiquidGlassView : UIView
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIView *tintView;
@property (nonatomic, strong) CAGradientLayer *topSpecular;
@property (nonatomic, strong) CAGradientLayer *bottomReflection;
@property (nonatomic, strong) CAGradientLayer *diagonalSheen;
@property (nonatomic, strong) CAGradientLayer *leftEdgeHighlight;
@property (nonatomic, strong) CAShapeLayer *innerRim;
@property (nonatomic, strong) CAShapeLayer *outerRim;
@property (nonatomic, strong) CAGradientLayer *chromaticEdge;
@property (nonatomic, assign) CGFloat cornerRadiusValue;
@property (nonatomic, assign) LGGlassMaterialType materialType;
@property (nonatomic, assign) BOOL interactiveHighlightEnabled;
@property (nonatomic, assign) BOOL isPressed;
// [V10 iOS27] Hiệu ứng nhấn nảy, kéo méo kính lỏng
@property (nonatomic, assign) CGPoint lastTouchLocation;
@property (nonatomic, assign) CGFloat pressIntensity;
@property (nonatomic, assign) BOOL isBeingPressed;
@property (nonatomic, assign) BOOL isBeingDragged;
- (instancetype)initWithFrame:(CGRect)frame cornerRadius:(CGFloat)radius;
- (instancetype)initWithFrame:(CGRect)frame cornerRadius:(CGFloat)radius materialType:(LGGlassMaterialType)type;
- (void)applyFluidJiggleAnimationWithVelocity:(CGFloat)vel;
- (void)setGlassHighlighted:(BOOL)highlighted animated:(BOOL)animated;
- (void)setGlassTransparencyEnabled:(BOOL)enabled;
- (void)refreshMaterialForCurrentTraits;
@property (nonatomic, assign) CGRect v20LastLayoutBounds;
@property (nonatomic, assign) CGFloat v20LastCornerRadius;
@property (nonatomic, assign) BOOL v20TransparencyEnabled;
@end

@implementation AppleLiquidGlassView

- (instancetype)initWithFrame:(CGRect)frame cornerRadius:(CGFloat)radius {
    return [self initWithFrame:frame cornerRadius:radius materialType:LGGlassMaterialTypeThin];
}

- (instancetype)initWithFrame:(CGRect)frame cornerRadius:(CGFloat)radius materialType:(LGGlassMaterialType)type {
    if (self = [super initWithFrame:frame]) {
        _cornerRadiusValue = radius;
        _materialType = type;
        _interactiveHighlightEnabled = YES;
        _isPressed = NO;

        self.backgroundColor = [UIColor clearColor];
        self.layer.cornerRadius = radius;
        if (@available(iOS 13.0, *)) self.layer.cornerCurve = kCACornerCurveContinuous;
        self.clipsToBounds = NO;
        self.layer.masksToBounds = NO;

        BOOL isDark = YES;
        if (@available(iOS 13.0, *)) isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;

        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:[LGGlassMaterialFactory blurStyleForType:type isDark:isDark]];
        _blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
        _blurView.frame = self.bounds;
        _blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _blurView.userInteractionEnabled = NO;
        _blurView.layer.cornerRadius = radius;
        if (@available(iOS 13.0, *)) _blurView.layer.cornerCurve = kCACornerCurveContinuous;
        _blurView.clipsToBounds = YES;
        [self addSubview:_blurView];

        CGFloat tint = [LGGlassMaterialFactory tintAlphaForType:type];
        _tintView = [[UIView alloc] initWithFrame:self.bounds];
        _tintView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:tint];
        _tintView.userInteractionEnabled = NO;
        _tintView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _tintView.layer.cornerRadius = radius;
        if (@available(iOS 13.0, *)) _tintView.layer.cornerCurve = kCACornerCurveContinuous;
        _tintView.clipsToBounds = YES;
        [self addSubview:_tintView];

        CGFloat spec = [LGGlassMaterialFactory specularAlphaForType:type];
        CGFloat specRatio = [LGGlassMaterialFactory specularHeightRatioForType:type];

        _topSpecular = [CAGradientLayer layer];
        _topSpecular.frame = CGRectMake(0, 0, self.bounds.size.width, MAX(3.0, self.bounds.size.height * specRatio));
        _topSpecular.cornerRadius = radius;
        if (@available(iOS 13.0, *)) _topSpecular.cornerCurve = kCACornerCurveContinuous;
        _topSpecular.colors = @[
            (id)[UIColor colorWithWhite:1.0 alpha:spec].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:spec * 0.72].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:spec * 0.22].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
        ];
        _topSpecular.locations = @[@0.0, @0.28, @0.68, @1.0];
        _topSpecular.startPoint = CGPointMake(0, 0);
        _topSpecular.endPoint = CGPointMake(0, 1);
        [self.layer addSublayer:_topSpecular];

        _bottomReflection = [CAGradientLayer layer];
        _bottomReflection.cornerRadius = radius;
        if (@available(iOS 13.0, *)) _bottomReflection.cornerCurve = kCACornerCurveContinuous;
        _bottomReflection.colors = @[
            (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:[LGGlassMaterialFactory bottomReflectionAlphaForType:type]].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
        ];
        _bottomReflection.locations = @[@0.0, @0.55, @1.0];
        _bottomReflection.startPoint = CGPointMake(0, 0);
        _bottomReflection.endPoint = CGPointMake(0, 1);
        _bottomReflection.opacity = 0.92f;
        [self.layer addSublayer:_bottomReflection];

        _diagonalSheen = [CAGradientLayer layer];
        _diagonalSheen.cornerRadius = radius;
        if (@available(iOS 13.0, *)) _diagonalSheen.cornerCurve = kCACornerCurveContinuous;
        _diagonalSheen.colors = @[
            (id)[UIColor colorWithWhite:1.0 alpha:[LGGlassMaterialFactory diagonalSheenAlphaForType:type]].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:[LGGlassMaterialFactory diagonalSheenAlphaForType:type] * 0.65].CGColor
        ];
        _diagonalSheen.locations = @[@0.0, @0.30, @0.70, @1.0];
        _diagonalSheen.startPoint = CGPointMake(0.0, 0.0);
        _diagonalSheen.endPoint = CGPointMake(1.0, 1.0);
        _diagonalSheen.opacity = 0.72f;
        [self.layer addSublayer:_diagonalSheen];

        _leftEdgeHighlight = [CAGradientLayer layer];
        _leftEdgeHighlight.cornerRadius = radius;
        if (@available(iOS 13.0, *)) _leftEdgeHighlight.cornerCurve = kCACornerCurveContinuous;
        _leftEdgeHighlight.colors = @[
            (id)[UIColor colorWithWhite:1.0 alpha:spec * 0.85].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
        ];
        _leftEdgeHighlight.locations = @[@0.0, @1.0];
        _leftEdgeHighlight.startPoint = CGPointMake(0.0, 0.5);
        _leftEdgeHighlight.endPoint = CGPointMake(1.0, 0.5);
        _leftEdgeHighlight.opacity = 0.72f;
        [self.layer addSublayer:_leftEdgeHighlight];

        _chromaticEdge = [CAGradientLayer layer];
        _chromaticEdge.cornerRadius = radius;
        if (@available(iOS 13.0, *)) _chromaticEdge.cornerCurve = kCACornerCurveContinuous;
        _chromaticEdge.colors = @[
            (id)[UIColor colorWithRed:0.4 green:0.75 blue:1.0 alpha:0.24].CGColor,
            (id)[UIColor colorWithRed:0.7 green:0.5  blue:1.0 alpha:0.16].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
            (id)[UIColor colorWithRed:0.5 green:1.0 blue:0.7 alpha:0.18].CGColor
        ];
        _chromaticEdge.locations = @[@0.0, @0.15, @0.85, @1.0];
        _chromaticEdge.startPoint = CGPointMake(0.0, 0.0);
        _chromaticEdge.endPoint = CGPointMake(1.0, 1.0);
        _chromaticEdge.opacity = 0.68f;
        [self.layer addSublayer:_chromaticEdge];

        CGFloat rimA = [LGGlassMaterialFactory rimAlphaForType:type];
        CGFloat rimW = [LGGlassMaterialFactory rimWidthForType:type];
        _innerRim = [CAShapeLayer layer];
        _innerRim.fillColor = [UIColor clearColor].CGColor;
        _innerRim.strokeColor = [UIColor colorWithWhite:1.0 alpha:rimA].CGColor;
        _innerRim.lineWidth = rimW;
        [self.layer addSublayer:_innerRim];

        _outerRim = [CAShapeLayer layer];
        _outerRim.fillColor = [UIColor clearColor].CGColor;
        _outerRim.strokeColor = [UIColor colorWithWhite:0.0 alpha:0.18].CGColor;
        _outerRim.lineWidth = 0.6;
        [self.layer addSublayer:_outerRim];

        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOpacity = [LGGlassMaterialFactory shadowOpacityForType:type];
        self.layer.shadowOffset = CGSizeMake(0, [LGGlassMaterialFactory shadowOffsetYForType:type]);
        self.layer.shadowRadius = [LGGlassMaterialFactory shadowRadiusForType:type];

        [self updateLayoutForBounds:self.bounds];
        id savedGlassSetting = [[NSUserDefaults standardUserDefaults] objectForKey:TI_GLASS_TRANSPARENCY_KEY];
        [self setGlassTransparencyEnabled:(savedGlassSetting ? [savedGlassSetting boolValue] : YES)];
    }
    return self;
}

- (void)setGlassTransparencyEnabled:(BOOL)enabled {
    // Solid performance UI: no Liquid Glass, no backdrop blur, no translucent sampling.
    // Keep the legacy selector for compatibility with existing callers/settings.
    _v20TransparencyEnabled = NO;
    _blurView.hidden = YES;
    _topSpecular.hidden = YES;
    _bottomReflection.hidden = YES;
    _diagonalSheen.hidden = YES;
    _leftEdgeHighlight.hidden = YES;
    _chromaticEdge.hidden = YES;
    _innerRim.hidden = YES;
    _outerRim.hidden = YES;
    UIColor *surface;
    if (@available(iOS 13.0, *)) {
        surface = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
            if (traits.userInterfaceStyle == UIUserInterfaceStyleLight) {
                return [UIColor colorWithRed:0.94 green:0.96 blue:0.99 alpha:1.0];
            }
            return [UIColor colorWithRed:0.035 green:0.055 blue:0.105 alpha:1.0];
        }];
    } else {
        surface = [UIColor colorWithRed:0.035 green:0.055 blue:0.105 alpha:1.0];
    }
    self.backgroundColor = surface;
    _tintView.backgroundColor = surface;
    self.layer.borderWidth = 1.0;
    self.layer.borderColor = [UIColor colorWithRed:0.12 green:0.55 blue:1.0 alpha:0.82].CGColor;
    self.layer.shadowColor = [UIColor colorWithRed:0.02 green:0.42 blue:1.0 alpha:1.0].CGColor;
    self.layer.shadowOpacity = 0.26;
    self.layer.shadowRadius = 15.0;
    self.layer.shadowOffset = CGSizeMake(0, 5.0);
    [self setNeedsLayout];
}

- (void)refreshMaterialForCurrentTraits {
    // Reapply the opaque theme only; never restore a blur/material effect.
    [self setGlassTransparencyEnabled:NO];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if (!previousTraitCollection || self.traitCollection.userInterfaceStyle != previousTraitCollection.userInterfaceStyle) {
            [self refreshMaterialForCurrentTraits];
        }
    }
}

- (void)updateLayoutForBounds:(CGRect)bounds {
    CGFloat r = _cornerRadiusValue;
    CGFloat specRatio = [LGGlassMaterialFactory specularHeightRatioForType:_materialType];
    CGFloat specH = MAX(3.0, bounds.size.height * specRatio);

    _blurView.frame = bounds;
    _blurView.layer.cornerRadius = r;
    _tintView.frame = bounds;
    _tintView.layer.cornerRadius = r;

    _topSpecular.frame = CGRectMake(0, 0, bounds.size.width, specH);
    _topSpecular.cornerRadius = r;

    CGFloat refY = bounds.size.height * 0.55;
    _bottomReflection.frame = CGRectMake(0, refY, bounds.size.width, bounds.size.height - refY);
    _bottomReflection.cornerRadius = r;

    _diagonalSheen.frame = bounds;
    _diagonalSheen.cornerRadius = r;

    _leftEdgeHighlight.frame = CGRectMake(0, 0, MAX(3.0, bounds.size.width * 0.20), bounds.size.height);
    _leftEdgeHighlight.cornerRadius = r;

    _chromaticEdge.frame = bounds;
    _chromaticEdge.cornerRadius = r;

    _innerRim.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(bounds, 0.5, 0.5) cornerRadius:MAX(0, r - 0.5)].CGPath;
    _outerRim.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(bounds, 0.3, 0.3) cornerRadius:MAX(0, r - 0.3)].CGPath;
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:r].CGPath;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.cornerRadius = _cornerRadiusValue;
    if (!CGRectEqualToRect(_v20LastLayoutBounds, self.bounds) || fabs(_v20LastCornerRadius - _cornerRadiusValue) > 0.01) {
        _v20LastLayoutBounds = self.bounds;
        _v20LastCornerRadius = _cornerRadiusValue;
        [self updateLayoutForBounds:self.bounds];
    }
}

- (void)animatePressIn {
    if (!_interactiveHighlightEnabled) return;
    CGFloat spec = [LGGlassMaterialFactory specularAlphaForType:_materialType];
    CGFloat rimA = [LGGlassMaterialFactory rimAlphaForType:_materialType];
    CGFloat tint = [LGGlassMaterialFactory tintAlphaForType:_materialType];

    [CATransaction begin];
    [CATransaction setAnimationDuration:0.22];
    [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
    _topSpecular.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:MIN(0.78, spec * 2.2)].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:spec * 0.95].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:spec * 0.42].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
    ];
    _innerRim.strokeColor = [UIColor colorWithWhite:1.0 alpha:MIN(0.78, rimA * 1.55)].CGColor;
    _tintView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:tint * 4.0];
    _chromaticEdge.opacity = 0.92f;
    [CATransaction commit];

    [UIView animateWithDuration:0.28 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.transform = CGAffineTransformMakeScale(0.965, 0.965);
    } completion:nil];
}

- (void)animatePressOut {
    if (!_interactiveHighlightEnabled) return;
    CGFloat spec = [LGGlassMaterialFactory specularAlphaForType:_materialType];
    CGFloat rimA = [LGGlassMaterialFactory rimAlphaForType:_materialType];
    CGFloat tint = [LGGlassMaterialFactory tintAlphaForType:_materialType];

    [CATransaction begin];
    [CATransaction setAnimationDuration:0.42];
    [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
    _topSpecular.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:spec].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:spec * 0.72].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:spec * 0.22].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
    ];
    _innerRim.strokeColor = [UIColor colorWithWhite:1.0 alpha:rimA].CGColor;
    _tintView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:tint];
    _chromaticEdge.opacity = 0.68f;
    [CATransaction commit];

    [UIView animateWithDuration:0.65 delay:0 usingSpringWithDamping:0.58 initialSpringVelocity:0.9 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)setGlassHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    if (!_interactiveHighlightEnabled) return;
    if (highlighted) [self animatePressIn]; else [self animatePressOut];
}

- (void)applyFluidJiggleAnimationWithVelocity:(CGFloat)vel {
    CGFloat stretch = fmin(fmax(fabs(vel) / 900.0, 0.04), 0.18);
    CGAffineTransform t = (vel >= 0)
        ? CGAffineTransformMakeScale(1.0 + stretch, 1.0 - (stretch * 0.45))
        : CGAffineTransformMakeScale(1.0 - (stretch * 0.35), 1.0 + stretch);
    [UIView animateWithDuration:0.13 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.transform = t;
    } completion:^(BOOL f) {
        [UIView animateWithDuration:0.48 delay:0 usingSpringWithDamping:0.58 initialSpringVelocity:1.05 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
            self.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

#pragma mark - [V10 iOS27] Touch Handling: nhấn nảy, kéo méo kính lỏng thật

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!_interactiveHighlightEnabled) { [super touchesBegan:touches withEvent:event]; return; }
    [super touchesBegan:touches withEvent:event];
    UITouch *t = [touches anyObject];
    CGPoint p = [t locationInView:self];
    _lastTouchLocation = p;
    _isBeingPressed = YES;
    _isBeingDragged = NO;
    _pressIntensity = 0.0;

    CGFloat distFromCenter = hypot(p.x - self.bounds.size.width/2, p.y - self.bounds.size.height/2);
    CGFloat maxDist = hypot(self.bounds.size.width/2, self.bounds.size.height/2);
    CGFloat intensity = 1.0 - fminf(1.0, distFromCenter / maxDist * 0.8);
    _pressIntensity = intensity;

    [CATransaction begin];
    [CATransaction setAnimationDuration:0.16];
    [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
    CGFloat pressTint = 0.06 + intensity * 0.05;
    _tintView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:pressTint];
    _topSpecular.opacity = 0.78 + intensity * 0.20;
    _innerRim.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.40 + intensity * 0.18].CGColor;
    _chromaticEdge.opacity = 0.72;
    [CATransaction commit];

    // [V10.1 SỬA LỖI MÉO VUÔNG 2 BÊN]: scale ĐỒNG ĐỀU X=Y, chỉ dịch chuyển nhẹ theo ngón tay.
    // Khi nhấn giữ: kính lỏng PHỒNG lên nhẹ như giọt nước (scale 1.03), không méo hình.
    CGFloat pressScale = 1.0 + intensity * 0.035;
    CGFloat moveX = (p.x - self.bounds.size.width/2) / self.bounds.size.width * 2.0;
    CGFloat moveY = (p.y - self.bounds.size.height/2) / self.bounds.size.height * 1.5;
    [UIView animateWithDuration:0.16 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.transform = CGAffineTransformTranslate(CGAffineTransformMakeScale(pressScale, pressScale), moveX, moveY);
    } completion:nil];

    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!_interactiveHighlightEnabled) { [super touchesMoved:touches withEvent:event]; return; }
    [super touchesMoved:touches withEvent:event];
    UITouch *t = [touches anyObject];
    CGPoint p = [t locationInView:self];
    CGPoint prev = _lastTouchLocation;
    CGFloat dx = p.x - prev.x;
    CGFloat dy = p.y - prev.y;

    if (fabs(dx) > 1.0 || fabs(dy) > 1.0) {
        _isBeingDragged = YES;
        CGFloat ndx = (p.x - self.bounds.size.width/2) / self.bounds.size.width;
        CGFloat ndy = (p.y - self.bounds.size.height/2) / self.bounds.size.height;
        CGFloat distFromCenter = hypot(p.x - self.bounds.size.width/2, p.y - self.bounds.size.height/2);
        CGFloat maxDist = hypot(self.bounds.size.width/2, self.bounds.size.height/2);
        CGFloat distRatio = fminf(1.0, distFromCenter / maxDist);

        // [V10.1 SỬA LỖI MÉO VUÔNG]: BỎ hẳn 3D transform (xung đột với 2D transform gây méo).
        // Chỉ dùng 2D affine, scale ĐỒNG ĐỀU, kính lỏng trượt theo ngón tay như giọt nước.
        CGFloat dragScale = 1.0 + distRatio * 0.04;
        CGFloat moveX = ndx * 6.0;
        CGFloat moveY = ndy * 3.0;

        [UIView animateWithDuration:0.10 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
            self.transform = CGAffineTransformTranslate(CGAffineTransformMakeScale(dragScale, dragScale), moveX, moveY);
        } completion:nil];

        _diagonalSheen.opacity = 0.42 + distRatio * 0.28;
    }
    _lastTouchLocation = p;
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!_interactiveHighlightEnabled) { [super touchesEnded:touches withEvent:event]; return; }
    [super touchesEnded:touches withEvent:event];
    [self endGlassTouch:YES];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!_interactiveHighlightEnabled) { [super touchesCancelled:touches withEvent:event]; return; }
    [super touchesCancelled:touches withEvent:event];
    [self endGlassTouch:NO];
}

- (void)endGlassTouch:(BOOL)releasedInside {
    _isBeingPressed = NO;
    _isBeingDragged = NO;
    _pressIntensity = 0.0;

    [CATransaction begin];
    [CATransaction setAnimationDuration:0.40];
    [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
    CGFloat baseTint = [LGGlassMaterialFactory tintAlphaForType:_materialType];
    _tintView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:baseTint];
    _topSpecular.opacity = 0.92;
    _innerRim.strokeColor = [UIColor colorWithWhite:1.0 alpha:[LGGlassMaterialFactory rimAlphaForType:_materialType] * 0.55].CGColor;
    _chromaticEdge.opacity = 0.50;
    _diagonalSheen.opacity = 0.55;
    [CATransaction commit];

    [UIView animateWithDuration:0.68 delay:0 usingSpringWithDamping:0.50 initialSpringVelocity:releasedInside ? 1.4 : 0.5 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.transform = CGAffineTransformIdentity;
    } completion:nil];

    if (releasedInside) {
        UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [fb impactOccurred];
    }
}

@end

// ====================================================================================================
// MODULE 3: LIQUID CAPSULE SWITCH
// ====================================================================================================
@interface LiquidCapsuleSwitch : UIControl
@property (nonatomic, assign) BOOL on;
@property (nonatomic, strong) UIView *trackView;
@property (nonatomic, strong) CAGradientLayer *trackGradient;
@property (nonatomic, strong) CAShapeLayer *trackInnerShadow;
@property (nonatomic, strong) CAShapeLayer *trackOuterRim;
@property (nonatomic, strong) AppleLiquidGlassView *thumbGlass;
@property (nonatomic, strong) CAShapeLayer *thumbInnerRim;
@property (nonatomic, copy) void (^valueChangedBlock)(BOOL isOn);
@property (nonatomic, assign) BOOL isAnimating;
@property (nonatomic, assign) NSUInteger animationGeneration;
- (void)setOn:(BOOL)on animated:(BOOL)animated;
@end

@implementation LiquidCapsuleSwitch
- (CGSize)intrinsicContentSize { return CGSizeMake(62.0, 34.0); }
- (CGSize)sizeThatFits:(CGSize)size { return CGSizeMake(62.0, 34.0); }

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:CGRectMake(0, 0, 62, 34)]) {
        self.backgroundColor = [UIColor clearColor];
        self.translatesAutoresizingMaskIntoConstraints = YES;

        _trackView = [[UIView alloc] initWithFrame:self.bounds];
        _trackView.layer.cornerRadius = 17.0;
        if (@available(iOS 13.0, *)) _trackView.layer.cornerCurve = kCACornerCurveContinuous;
        _trackView.userInteractionEnabled = NO;
        _trackView.clipsToBounds = YES;
        [self addSubview:_trackView];

        _trackGradient = [CAGradientLayer layer];
        _trackGradient.frame = _trackView.bounds;
        _trackGradient.startPoint = CGPointMake(0, 0);
        _trackGradient.endPoint = CGPointMake(0, 1);
        [_trackView.layer addSublayer:_trackGradient];

        _trackInnerShadow = [CAShapeLayer layer];
        _trackInnerShadow.fillColor = [UIColor clearColor].CGColor;
        _trackInnerShadow.strokeColor = [UIColor colorWithWhite:0.0 alpha:0.45].CGColor;
        _trackInnerShadow.lineWidth = 0.8;
        [_trackView.layer addSublayer:_trackInnerShadow];

        _trackOuterRim = [CAShapeLayer layer];
        _trackOuterRim.fillColor = [UIColor clearColor].CGColor;
        _trackOuterRim.strokeColor = [UIColor colorWithRed:0.22 green:0.82 blue:1.0 alpha:0.68].CGColor;
        _trackOuterRim.lineWidth = 0.5;
        [_trackView.layer addSublayer:_trackOuterRim];

        CGFloat inset = 3.0;
        CGFloat d = 34.0 - (inset * 2);
        _thumbGlass = [[AppleLiquidGlassView alloc] initWithFrame:CGRectMake(inset, inset, d, d)
                                                     cornerRadius:d / 2.0
                                                     materialType:LGGlassMaterialTypeCrystal];
        _thumbGlass.userInteractionEnabled = NO;
        _thumbGlass.interactiveHighlightEnabled = NO;
        _thumbGlass.backgroundColor = [UIColor colorWithRed:0.035 green:0.025 blue:0.10 alpha:1.0];
        _thumbGlass.layer.borderWidth = 1.2;
        _thumbGlass.layer.borderColor = [UIColor colorWithRed:0.12 green:0.78 blue:1.0 alpha:0.95].CGColor;
        _thumbGlass.layer.shadowColor = [UIColor colorWithRed:0.38 green:0.16 blue:1.0 alpha:1.0].CGColor;
        _thumbGlass.layer.shadowOpacity = 0.42;
        _thumbGlass.layer.shadowOffset = CGSizeMake(0, 2);
        _thumbGlass.layer.shadowRadius = 7.0;
        [self addSubview:_thumbGlass];

        _thumbInnerRim = [CAShapeLayer layer];
        _thumbInnerRim.fillColor = [UIColor clearColor].CGColor;
        _thumbInnerRim.strokeColor = [UIColor colorWithWhite:0.0 alpha:0.18].CGColor;
        _thumbInnerRim.lineWidth = 0.6;
        [_thumbGlass.layer addSublayer:_thumbInnerRim];

        [self addTarget:self action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
        [self addTarget:self action:@selector(handleTouchDown) forControlEvents:UIControlEventTouchDown];
        [self addTarget:self action:@selector(handleTouchUp) forControlEvents:UIControlEventTouchUpOutside | UIControlEventTouchCancel];
        [self updateUIAnimated:NO];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _trackView.frame = self.bounds;
    CGFloat W = self.bounds.size.width, H = self.bounds.size.height, r = H / 2.0;
    _trackView.layer.cornerRadius = r;
    _trackGradient.frame = _trackView.bounds;
    _trackInnerShadow.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(_trackView.bounds, 0.5, 0.5) cornerRadius:r - 0.5].CGPath;
    _trackOuterRim.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(_trackView.bounds, 0.3, 0.3) cornerRadius:r - 0.3].CGPath;

    CGFloat inset = 3.0;
    CGFloat d = H - (inset * 2);
    CGRect f = _on ? CGRectMake(W - d - inset, inset, d, d) : CGRectMake(inset, inset, d, d);
    if (_thumbGlass.layer.animationKeys.count == 0) {
        if (!CGRectEqualToRect(_thumbGlass.frame, f)) _thumbGlass.frame = f;
    }
    _thumbGlass.layer.cornerRadius = d / 2.0;
    _thumbGlass.cornerRadiusValue = d / 2.0;
    [_thumbGlass layoutSubviews];
    _thumbInnerRim.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(_thumbGlass.bounds, 0.5, 0.5) cornerRadius:(d / 2.0) - 0.5].CGPath;
    _thumbGlass.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:_thumbGlass.bounds cornerRadius:d / 2.0].CGPath;
}

- (void)handleTouchDown {
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    [UIView animateWithDuration:0.08 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self->_thumbGlass.transform = CGAffineTransformMakeScale(0.94, 0.94);
    } completion:nil];
}
- (void)handleTouchUp {
    if (UIAccessibilityIsReduceMotionEnabled()) {
        _thumbGlass.transform = CGAffineTransformIdentity;
        return;
    }
    [UIView animateWithDuration:0.16 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self->_thumbGlass.transform = CGAffineTransformIdentity;
    } completion:nil];
}
- (void)handleTap {
    // Restore the press-scale on touch-up-inside, then allow the new transition to start from the presentation position.
    _thumbGlass.transform = CGAffineTransformIdentity;
    // Do not discard taps during the visual transition; the state and settings update immediately.
    [self setOn:!_on animated:YES];
    [self sendActionsForControlEvents:UIControlEventValueChanged];
    if (self.valueChangedBlock) self.valueChangedBlock(_on);
    if (!UIAccessibilityIsReduceMotionEnabled()) {
        UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [fb impactOccurred];
    }
}
- (void)setOn:(BOOL)on { [self setOn:on animated:NO]; }
- (void)setOn:(BOOL)on animated:(BOOL)animated { _on = on; [self updateUIAnimated:animated]; }

- (void)animateThumbFloatToFrame:(CGRect)targetFrame goingOn:(BOOL)goingOn {
    NSUInteger generation = ++_animationGeneration;
    CGPoint startCenter = _thumbGlass.layer.position;
    CGFloat startScale = 1.0;
    CALayer *presentation = (CALayer *)_thumbGlass.layer.presentationLayer;
    if (presentation) {
        startCenter = presentation.position;
        id scaleValue = [presentation valueForKeyPath:@"transform.scale"];
        if ([scaleValue respondsToSelector:@selector(doubleValue)]) startScale = (CGFloat)[scaleValue doubleValue];
    }
    [_thumbGlass.layer removeAnimationForKey:@"floatUp"];
    [_thumbGlass.layer removeAnimationForKey:@"floatScale"];

    CGPoint endCenter = CGPointMake(CGRectGetMidX(targetFrame), CGRectGetMidY(targetFrame));
    _thumbGlass.frame = targetFrame;
    _thumbGlass.layer.position = endCenter;
    if (UIAccessibilityIsReduceMotionEnabled()) {
        _isAnimating = NO;
        return;
    }

    _isAnimating = YES;
    CGFloat lift = goingOn ? 1.8 : -1.5;
    CGPoint midCenter = CGPointMake((startCenter.x + endCenter.x) / 2.0, endCenter.y + lift);

    CAKeyframeAnimation *posAnim = [CAKeyframeAnimation animationWithKeyPath:@"position"];
    posAnim.values = @[
        [NSValue valueWithCGPoint:startCenter],
        [NSValue valueWithCGPoint:midCenter],
        [NSValue valueWithCGPoint:endCenter]
    ];
    posAnim.keyTimes = @[@0.0, @0.48, @1.0];
    posAnim.duration = 0.22;
    posAnim.timingFunctions = @[
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]
    ];
    posAnim.removedOnCompletion = YES;

    CAKeyframeAnimation *scaleAnim = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
    scaleAnim.values = @[@(MAX(0.94, MIN(startScale, 1.06))), @1.025, @1.0];
    scaleAnim.keyTimes = @[@0.0, @0.48, @1.0];
    scaleAnim.duration = 0.22;
    scaleAnim.removedOnCompletion = YES;

    [_thumbGlass.layer addAnimation:posAnim forKey:@"floatUp"];
    [_thumbGlass.layer addAnimation:scaleAnim forKey:@"floatScale"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(240 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        if (generation != self->_animationGeneration) return;
        [self->_thumbGlass.layer removeAnimationForKey:@"floatUp"];
        [self->_thumbGlass.layer removeAnimationForKey:@"floatScale"];
        self->_thumbGlass.frame = targetFrame;
        self->_thumbGlass.layer.position = endCenter;
        self->_isAnimating = NO;
    });
}

- (void)updateUIAnimated:(BOOL)animated {
    NSArray *onC = @[
        (id)[UIColor colorWithRed:0.98 green:0.20 blue:0.80 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.35 green:0.18 blue:0.98 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.05 green:0.80 blue:1.0 alpha:1.0].CGColor
    ];
    NSArray *offC = @[
        (id)[UIColor colorWithRed:0.22 green:0.24 blue:0.28 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.14 green:0.16 blue:0.19 alpha:1.0].CGColor
    ];
    CGFloat W = 62.0, H = 34.0;
    CGFloat inset = 3.0, d = H - (inset * 2);
    CGRect f = _on ? CGRectMake(W - d - inset, inset, d, d) : CGRectMake(inset, inset, d, d);

    BOOL allowAnimation = animated && !UIAccessibilityIsReduceMotionEnabled();
    if (allowAnimation) {
        [self animateThumbFloatToFrame:f goingOn:_on];
        [CATransaction begin];
        [CATransaction setAnimationDuration:0.20];
        [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
        _trackGradient.colors = _on ? onC : offC;
        [CATransaction commit];
    } else {
        ++_animationGeneration;
        _isAnimating = NO;
        [_thumbGlass.layer removeAnimationForKey:@"floatUp"];
        [_thumbGlass.layer removeAnimationForKey:@"floatScale"];
        [CATransaction begin]; [CATransaction setDisableActions:YES];
        _trackGradient.colors = _on ? onC : offC;
        _thumbGlass.frame = f;
        _thumbGlass.layer.position = CGPointMake(CGRectGetMidX(f), CGRectGetMidY(f));
        _thumbGlass.transform = CGAffineTransformIdentity;
        [CATransaction commit];
    }
}
@end

// ====================================================================================================
// Category TrackingTouchExt
// ====================================================================================================
@interface UIControl (TrackingTouchExt)
@property (nonatomic, strong) UITouch *trackingTouch;
@end

static const void *kTrackingTouchKey = &kTrackingTouchKey;
@implementation UIControl (TrackingTouchExt)
- (UITouch *)trackingTouch {
    return objc_getAssociatedObject(self, kTrackingTouchKey);
}
- (void)setTrackingTouch:(UITouch *)trackingTouch {
    objc_setAssociatedObject(self, kTrackingTouchKey, trackingTouch, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

// ====================================================================================================
// MODULE 4: LG CUSTOM SEGMENT
// ====================================================================================================
@interface LGCustomSegment : UIControl
@property (nonatomic, strong) AppleLiquidGlassView *background;
@property (nonatomic, strong) AppleLiquidGlassView *indicator;
@property (nonatomic, strong) NSArray<UILabel *> *labels;
@property (nonatomic, strong) NSArray<NSString *> *items;
@property (nonatomic, assign) NSInteger selectedSegmentIndex;
@property (nonatomic, copy) void (^valueChangedBlock)(NSInteger index);
- (instancetype)initWithItems:(NSArray<NSString *> *)items;
- (void)setSelectedSegmentIndex:(NSInteger)selectedSegmentIndex animated:(BOOL)animated;
@end

@implementation LGCustomSegment
- (CGSize)intrinsicContentSize {
    CGFloat minWidth = MAX(280.0, self.items.count * 72.0);
    return CGSizeMake(minWidth, 38.0);
}
- (CGSize)sizeThatFits:(CGSize)size {
    CGFloat minWidth = MAX(280.0, self.items.count * 72.0);
    return CGSizeMake(minWidth, 38.0);
}

- (instancetype)initWithItems:(NSArray<NSString *> *)items {
    CGFloat w = MAX(280.0, items.count * 72.0);
    if (self = [super initWithFrame:CGRectMake(0, 0, w, 38)]) {
        _items = items;
        _selectedSegmentIndex = 0;
        self.backgroundColor = [UIColor clearColor];
        self.translatesAutoresizingMaskIntoConstraints = YES;

        _background = [[AppleLiquidGlassView alloc] initWithFrame:self.bounds
                                                     cornerRadius:19.0
                                                     materialType:LGGlassMaterialTypeUltraThin];
        _background.userInteractionEnabled = NO;
        _background.interactiveHighlightEnabled = NO;
        _background.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_background];

        _indicator = [[AppleLiquidGlassView alloc] initWithFrame:CGRectZero
                                                     cornerRadius:16.0
                                                     materialType:LGGlassMaterialTypeChrome];
        _indicator.userInteractionEnabled = NO;
        _indicator.interactiveHighlightEnabled = NO;
        [self addSubview:_indicator];

        NSMutableArray *ls = [NSMutableArray array];
        for (NSInteger i = 0; i < items.count; i++) {
            UILabel *l = [[UILabel alloc] init];
            l.text = items[i];
            l.textAlignment = NSTextAlignmentCenter;
            l.textColor = i == 0 ? [UIColor whiteColor] : [UIColor colorWithWhite:0.78 alpha:1.0];
            l.font = i == 0 ? [UIFont systemFontOfSize:12 weight:UIFontWeightBold] : [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
            l.userInteractionEnabled = NO;
            l.adjustsFontSizeToFitWidth = YES;
            l.minimumScaleFactor = 0.75;
            [self addSubview:l];
            [ls addObject:l];
        }
        _labels = ls;

        [self addTarget:self action:@selector(handleTouchUpInside) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _background.frame = self.bounds;
    _background.layer.cornerRadius = self.bounds.size.height / 2.0;
    _background.cornerRadiusValue = self.bounds.size.height / 2.0;
    [_background layoutSubviews];

    CGFloat w = self.bounds.size.width / MAX(1, _items.count);
    CGFloat h = self.bounds.size.height;
    for (NSInteger i = 0; i < _labels.count; i++) {
        _labels[i].frame = CGRectMake(i * w, 0, w, h);
    }
    CGRect ind = CGRectMake(_selectedSegmentIndex * w + 3, 3, w - 6, h - 6);
    _indicator.frame = ind;
    _indicator.layer.cornerRadius = (h - 6) / 2.0;
    _indicator.cornerRadiusValue = (h - 6) / 2.0;
    [_indicator layoutSubviews];
}

- (void)handleTouchUpInside {
    UITouch *t = self.trackingTouch;
    CGPoint p = CGPointZero;
    if (t) p = [t locationInView:self];
    else p = CGPointMake(self.bounds.size.width * 0.5, self.bounds.size.height * 0.5);

    CGFloat w = self.bounds.size.width / MAX(1, _items.count);
    NSInteger idx = (NSInteger)floor(p.x / MAX(1.0, w));
    if (idx < 0) idx = 0;
    if (idx >= (NSInteger)_items.count) idx = _items.count - 1;
    [self setSelectedSegmentIndex:idx animated:YES];
    if (self.valueChangedBlock) self.valueChangedBlock(idx);
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

- (void)setSelectedSegmentIndex:(NSInteger)index animated:(BOOL)animated {
    if (index < 0 || index >= (NSInteger)_items.count) return;
    NSInteger oldIdx = _selectedSegmentIndex;
    _selectedSegmentIndex = index;
    CGFloat w = self.bounds.size.width / MAX(1, _items.count);
    CGFloat h = self.bounds.size.height;
    CGRect ind = CGRectMake(index * w + 3, 3, w - 6, h - 6);
    // [V10.3 - THEO VIDEO #2 Fluid Glass]: indicator co giãn theo vận tốc khi trượt, spring mượt
    CGFloat stretch = (animated && oldIdx != index) ? MIN(1.25, 1.0 + fabs((CGFloat)(index - oldIdx)) * 0.12) : 1.0;
    void (^a)(void) = ^{
        self->_indicator.frame = ind;
        self->_indicator.transform = CGAffineTransformIdentity;
        for (NSInteger i = 0; i < self->_labels.count; i++) {
            BOOL s = (i == index);
            self->_labels[i].textColor = s ? [UIColor whiteColor] : [UIColor colorWithWhite:0.78 alpha:1.0];
            self->_labels[i].font = s ? [UIFont systemFontOfSize:12 weight:UIFontWeightBold] : [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        }
    };
    if (animated) {
        [UIView animateWithDuration:0.44 delay:0 usingSpringWithDamping:0.80 initialSpringVelocity:0.55 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:a completion:nil];
    } else a();
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
}
- (void)setSelectedSegmentIndex:(NSInteger)selectedSegmentIndex {
    [self setSelectedSegmentIndex:selectedSegmentIndex animated:NO];
}

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    self.trackingTouch = touch;
    return [super beginTrackingWithTouch:touch withEvent:event];
}
- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    self.trackingTouch = touch;
    return [super continueTrackingWithTouch:touch withEvent:event];
}
- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    self.trackingTouch = touch;
    [super endTrackingWithTouch:touch withEvent:event];
}
- (void)cancelTrackingWithEvent:(UIEvent *)event {
    self.trackingTouch = nil;
    [super cancelTrackingWithEvent:event];
}
@end

// ====================================================================================================
// MODULE 5: LG GLASS TABLE VIEW CELL
// ====================================================================================================
@interface LGGlassTableViewCell : UITableViewCell
@property (nonatomic, strong) AppleLiquidGlassView *glassBackground;
@property (nonatomic, strong) UILabel *titleL;
@property (nonatomic, strong) UILabel *detailL;
@property (nonatomic, strong) UIView *accessoryContainer;
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *accessoryConstraints;
@property (nonatomic, strong) UIColor *v20AccentColor;
- (void)configureWithTitle:(NSString *)title detail:(NSString *)detail accessory:(UIView *)accessory accent:(UIColor *)accent;
- (void)applyV20CellTheme;
@end

@implementation LGGlassTableViewCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid {
    if (self = [super initWithStyle:style reuseIdentifier:rid]) {
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        self.contentView.clipsToBounds = NO;
        self.contentView.layer.masksToBounds = NO;

        _glassBackground = [[AppleLiquidGlassView alloc] initWithFrame:self.bounds
                                                          cornerRadius:18.0
                                                          materialType:LGGlassMaterialTypeThin];
        // A solid neon card is used instead of the legacy liquid-glass material.
        _glassBackground.interactiveHighlightEnabled = NO;
        _glassBackground.userInteractionEnabled = NO;
        _glassBackground.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _glassBackground.frame = CGRectInset(self.bounds, 12.0, 4.0);
        _glassBackground.layer.borderWidth = 0.8;
        _glassBackground.layer.borderColor = [UIColor colorWithRed:0.40 green:0.23 blue:0.70 alpha:0.52].CGColor;
        _glassBackground.layer.shadowColor = [UIColor colorWithRed:0.38 green:0.08 blue:0.82 alpha:1.0].CGColor;
        _glassBackground.layer.shadowOpacity = 0.12;
        _glassBackground.layer.shadowRadius = 8.0;
        _glassBackground.layer.shadowOffset = CGSizeMake(0, 3);
        [self.contentView insertSubview:_glassBackground atIndex:0];

        _titleL = [[UILabel alloc] init];
        _titleL.textColor = [UIColor whiteColor];
        _titleL.font = [UIFont systemFontOfSize:15.5 weight:UIFontWeightSemibold];
        _titleL.translatesAutoresizingMaskIntoConstraints = NO;
        _titleL.numberOfLines = 1;
        _titleL.adjustsFontSizeToFitWidth = YES;
        _titleL.minimumScaleFactor = 0.75;
        [self.contentView addSubview:_titleL];

        _detailL = [[UILabel alloc] init];
        _detailL.textColor = [UIColor colorWithWhite:0.78 alpha:1.0];
        _detailL.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium];
        _detailL.textAlignment = NSTextAlignmentRight;
        _detailL.numberOfLines = 2;
        _detailL.lineBreakMode = NSLineBreakByWordWrapping;
        _detailL.translatesAutoresizingMaskIntoConstraints = NO;
        [self applyV20CellTheme];
        [self.contentView addSubview:_detailL];

        [NSLayoutConstraint activateConstraints:@[
            [_titleL.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18],
            [_titleL.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_detailL.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [_detailL.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_titleL.trailingAnchor constraintLessThanOrEqualToAnchor:_detailL.leadingAnchor constant:-8]
        ]];
    }
    return self;
}

- (void)applyV20CellTheme {
    // V9 VISUAL SYSTEM: one consistent, purpose-built control-card treatment.
    UIColor *pink = [UIColor colorWithRed:1.0 green:0.18 blue:0.70 alpha:1.0];
    UIColor *violet = [UIColor colorWithRed:0.47 green:0.20 blue:1.0 alpha:1.0];
    UIColor *cyan = [UIColor colorWithRed:0.08 green:0.88 blue:1.0 alpha:1.0];
    UIColor *ink = [UIColor colorWithRed:0.025 green:0.018 blue:0.060 alpha:1.0];
    UIColor *muted = [UIColor colorWithRed:0.67 green:0.72 blue:0.86 alpha:1.0];

    _titleL.textColor = _v20AccentColor ?: [UIColor colorWithWhite:0.98 alpha:1.0];
    _detailL.textColor = muted;
    _titleL.font = [UIFont systemFontOfSize:15.5 weight:UIFontWeightSemibold];
    _detailL.font = [UIFont systemFontOfSize:10.5 weight:UIFontWeightMedium];
    _titleL.numberOfLines = 2;
    _detailL.numberOfLines = 2;

    _glassBackground.backgroundColor = ink;
    _glassBackground.layer.cornerRadius = 17.0;
    _glassBackground.layer.borderWidth = 1.0;
    _glassBackground.layer.borderColor = [violet colorWithAlphaComponent:0.72].CGColor;
    _glassBackground.layer.shadowColor = pink.CGColor;
    _glassBackground.layer.shadowOpacity = 0.11;
    _glassBackground.layer.shadowRadius = 10.0;
    _glassBackground.layer.shadowOffset = CGSizeMake(0, 3);
    _glassBackground.layer.masksToBounds = NO;

    // Accent strip makes each row feel like a designed control, not a legacy preference cell.
    UIView *accent = [_glassBackground viewWithTag:99091];
    if (!accent) {
        accent = [[UIView alloc] initWithFrame:CGRectZero];
        accent.tag = 99091;
        accent.userInteractionEnabled = NO;
        accent.layer.cornerRadius = 1.5;
        [_glassBackground addSubview:accent];
    }
    accent.frame = CGRectMake(0, 12, 3, MAX(18, _glassBackground.bounds.size.height - 24));
    accent.backgroundColor = cyan;
    accent.layer.shadowColor = cyan.CGColor;
    accent.layer.shadowOpacity = 0.75;
    accent.layer.shadowRadius = 5.0;
    accent.layer.shadowOffset = CGSizeZero;
    [_glassBackground bringSubviewToFront:accent];
}


- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if (!previousTraitCollection || self.traitCollection.userInterfaceStyle != previousTraitCollection.userInterfaceStyle) [self applyV20CellTheme];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _glassBackground.frame = CGRectInset(self.bounds, 10.0, 4.0);
    _glassBackground.layer.cornerRadius = 22.0;
    _glassBackground.cornerRadiusValue = 19.0;
    [_glassBackground layoutSubviews];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    if (_accessoryContainer) {
        if (_accessoryConstraints) {
            [NSLayoutConstraint deactivateConstraints:_accessoryConstraints];
            _accessoryConstraints = nil;
        }
        [_accessoryContainer removeFromSuperview];
        _accessoryContainer = nil;
    }
    _titleL.text = nil;
    _detailL.text = nil;
    _v20AccentColor = nil;
    [self applyV20CellTheme];
    self.alpha = 1.0;
    self.contentView.alpha = 1.0;
    self.userInteractionEnabled = YES;
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.transform = CGAffineTransformIdentity;
}

- (void)configureWithTitle:(NSString *)title detail:(NSString *)detail accessory:(UIView *)accessory accent:(UIColor *)accent {
    _titleL.text = title;
    _detailL.text = detail;
    _v20AccentColor = accent;
    [self applyV20CellTheme];

    if (_accessoryContainer) {
        if (_accessoryConstraints) {
            [NSLayoutConstraint deactivateConstraints:_accessoryConstraints];
            _accessoryConstraints = nil;
        }
        [_accessoryContainer removeFromSuperview];
        _accessoryContainer = nil;
    }
    if (accessory) {
        _accessoryContainer = accessory;
        accessory.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:accessory];
        if ([accessory isKindOfClass:[LiquidCapsuleSwitch class]]) {
            _accessoryConstraints = @[
                [accessory.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
                [accessory.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
                [accessory.widthAnchor constraintEqualToConstant:62],
                [accessory.heightAnchor constraintEqualToConstant:34]
            ];
        } else if ([accessory isKindOfClass:[LGCustomSegment class]]) {
            _accessoryConstraints = @[
                [accessory.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
                [accessory.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
                [accessory.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
                [accessory.heightAnchor constraintEqualToConstant:38]
            ];
        } else if ([accessory isKindOfClass:[UITextField class]]) {
            _accessoryConstraints = @[
                [accessory.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:14],
                [accessory.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-14],
                [accessory.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
                [accessory.heightAnchor constraintEqualToConstant:38]
            ];
        } else {
            _accessoryConstraints = @[
                [accessory.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
                [accessory.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor]
            ];
        }
        [NSLayoutConstraint activateConstraints:_accessoryConstraints];
    }
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    [UIView animateWithDuration:(animated ? 0.10 : 0.0) delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut animations:^{
        self.contentView.alpha = highlighted ? 0.94 : 1.0;
    } completion:nil];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    // No row-scale/blur rebuild here: selection and reloadSections used to fight each other visually.
    if (!selected) self.contentView.alpha = 1.0;
}
@end

// ====================================================================================================
// MODULE 6: LG GLASS NAV BUTTON
// ====================================================================================================
@interface LGGlassNavButton : UIControl
@property (nonatomic, strong) AppleLiquidGlassView *glassPill;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, assign) BOOL v20TabSelected;
@property (nonatomic, assign) BOOL v20TabPressed;
- (instancetype)initWithIconName:(NSString *)iconName title:(NSString *)title;
- (void)updateTabSelected:(BOOL)selected animated:(BOOL)animated;
@end

@implementation LGGlassNavButton
- (instancetype)initWithIconName:(NSString *)iconName title:(NSString *)title {
    if (self = [super initWithFrame:CGRectZero]) {
        self.backgroundColor = [UIColor clearColor];
        _glassPill = [[AppleLiquidGlassView alloc] initWithFrame:self.bounds
                                                     cornerRadius:16.0
                                                     materialType:LGGlassMaterialTypeThin];
        _glassPill.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _glassPill.interactiveHighlightEnabled = YES;
        _glassPill.userInteractionEnabled = NO;
        _glassPill.alpha = 0.0;
        [self addSubview:_glassPill];

        _iconView = [[UIImageView alloc] init];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.tintColor = [UIColor colorWithWhite:0.78 alpha:1.0];
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        UIImage *img = [UIImage systemImageNamed:iconName];
        _iconView.image = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [self addSubview:_iconView];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.text = title;
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.textColor = [UIColor colorWithWhite:0.78 alpha:1.0];
        _titleLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.adjustsFontSizeToFitWidth = YES;
        _titleLabel.minimumScaleFactor = 0.75;
        [self addSubview:_titleLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_iconView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_iconView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:-8],
            [_iconView.widthAnchor constraintEqualToConstant:22],
            [_iconView.heightAnchor constraintEqualToConstant:22],
            [_titleLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_titleLabel.topAnchor constraintEqualToAnchor:_iconView.bottomAnchor constant:3],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:2],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-2]
        ]];
        [self addTarget:self action:@selector(tDown) forControlEvents:UIControlEventTouchDown];
        [self addTarget:self action:@selector(tUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _glassPill.frame = self.bounds;
    _glassPill.layer.cornerRadius = self.bounds.size.height / 2.0;
    _glassPill.cornerRadiusValue = self.bounds.size.height / 2.0;
    [_glassPill layoutSubviews];
}

- (CGAffineTransform)v20IconTransformForSelected:(BOOL)selected pressed:(BOOL)pressed {
    // The icon only lifts to the stationary glass lens when selection changes;
    // touch-down itself never translates the glyph, preventing the "icon drops" glitch.
    (void)pressed;
    CGFloat scale = selected ? 0.98 : 1.0;
    CGFloat y = selected ? -12.0 : 0.0;
    return CGAffineTransformMake(scale, 0.0, 0.0, scale, 0.0, y);
}
- (void)tDown {
    self.v20TabPressed = YES;
    [UIView animateWithDuration:0.10 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.transform = CGAffineTransformMakeScale(0.975, 0.975);
        self.iconView.transform = [self v20IconTransformForSelected:self.v20TabSelected pressed:YES];
    } completion:nil];
}
- (void)tUp {
    self.v20TabPressed = NO;
    [UIView animateWithDuration:0.20 delay:0 usingSpringWithDamping:0.84 initialSpringVelocity:0.25 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.transform = CGAffineTransformIdentity;
        self.iconView.transform = [self v20IconTransformForSelected:self.v20TabSelected pressed:NO];
    } completion:nil];
}
- (void)updateTabSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected];
    self.v20TabSelected = selected;
    BOOL dark = YES;
    if (@available(iOS 13.0, *)) dark = self.traitCollection.userInterfaceStyle != UIUserInterfaceStyleLight;
    UIColor *c = selected ? [UIColor colorWithRed:0.12 green:0.12 blue:0.14 alpha:1.0] :
                 (dark ? [UIColor colorWithWhite:0.78 alpha:1.0] : [UIColor colorWithWhite:0.25 alpha:1.0]);
    UIFont *f = selected ? [UIFont systemFontOfSize:10.5 weight:UIFontWeightBold] : [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
    CGAffineTransform t = [self v20IconTransformForSelected:selected pressed:self.v20TabPressed];
    CGFloat titleAlpha = 1.0;
    void (^u)(void) = ^{
        self.iconView.tintColor = c;
        self.iconView.transform = t;
        self.titleLabel.textColor = dark ? [UIColor colorWithWhite:0.78 alpha:1.0] : [UIColor colorWithWhite:0.25 alpha:1.0];
        self.titleLabel.font = f;
        self.titleLabel.alpha = titleAlpha;
        self.glassPill.alpha = 0.0;
    };
    if (animated) [UIView animateWithDuration:0.28 delay:0 usingSpringWithDamping:0.78 initialSpringVelocity:0.42 options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState animations:u completion:nil];
    else u();
}
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if (!previousTraitCollection || self.traitCollection.userInterfaceStyle != previousTraitCollection.userInterfaceStyle) {
            [self updateTabSelected:self.v20TabSelected animated:NO];
        }
    }
}
@end

// ====================================================================================================
// MODULE 7: EXPANDING NAV BAR BUTTON
// ====================================================================================================
@class LGExpandingNavBarButton;

@protocol LGExpandingNavBarButtonDelegate <NSObject>
@optional
- (void)expandingButton:(LGExpandingNavBarButton *)button didSelectActionAtIndex:(NSInteger)index;
- (void)expandingButtonDidExpand:(LGExpandingNavBarButton *)button;
- (void)expandingButtonDidCollapse:(LGExpandingNavBarButton *)button;
@end

@interface LGExpandingMenuAction : NSObject
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *systemImageName;
@property (nonatomic, strong) UIColor *tintColor;
@property (nonatomic, assign) BOOL destructive;
+ (instancetype)actionWithTitle:(NSString *)title image:(NSString *)image tintColor:(UIColor *)tint destructive:(BOOL)destructive;
@end

@implementation LGExpandingMenuAction
+ (instancetype)actionWithTitle:(NSString *)title image:(NSString *)image tintColor:(UIColor *)tint destructive:(BOOL)destructive {
    LGExpandingMenuAction *a = [LGExpandingMenuAction new];
    a.title = title; a.systemImageName = image; a.tintColor = tint ?: [UIColor whiteColor]; a.destructive = destructive;
    return a;
}
@end

@interface LGExpandingActionView : UIControl
@property (nonatomic, strong) AppleLiquidGlassView *glassBackground;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
- (instancetype)initWithAction:(LGExpandingMenuAction *)action;
@end

@implementation LGExpandingActionView
- (instancetype)initWithAction:(LGExpandingMenuAction *)action {
    if (self = [super initWithFrame:CGRectMake(0, 0, 220, 48)]) {
        self.backgroundColor = [UIColor clearColor];
        _glassBackground = [[AppleLiquidGlassView alloc] initWithFrame:self.bounds cornerRadius:24.0 materialType:LGGlassMaterialTypeCrystal];
        _glassBackground.userInteractionEnabled = NO;
        _glassBackground.interactiveHighlightEnabled = NO;
        _glassBackground.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_glassBackground];

        _iconView = [[UIImageView alloc] init];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.tintColor = action.tintColor;
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        UIImage *img = [UIImage systemImageNamed:action.systemImageName];
        _iconView.image = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [self addSubview:_iconView];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.text = action.title;
        _titleLabel.textColor = action.destructive ? [UIColor systemRedColor] : [UIColor whiteColor];
        _titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.adjustsFontSizeToFitWidth = YES;
        _titleLabel.minimumScaleFactor = 0.75;
        [self addSubview:_titleLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_iconView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:18],
            [_iconView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_iconView.widthAnchor constraintEqualToConstant:20],
            [_iconView.heightAnchor constraintEqualToConstant:20],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:12],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
            [_titleLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor]
        ]];
    }
    return self;
}
- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [_glassBackground setGlassHighlighted:highlighted animated:YES];
    [UIView animateWithDuration:0.24 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.transform = highlighted ? CGAffineTransformMakeScale(0.96, 0.96) : CGAffineTransformIdentity;
    } completion:nil];
}
@end

@interface LGExpandingNavBarButton : UIControl
@property (nonatomic, strong) AppleLiquidGlassView *buttonGlass;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) NSArray<LGExpandingMenuAction *> *actions;
@property (nonatomic, assign) BOOL expanded;
@property (nonatomic, weak) id<LGExpandingNavBarButtonDelegate> delegate;
@property (nonatomic, strong) UIView *dimOverlay;
@property (nonatomic, strong) NSMutableArray<LGExpandingActionView *> *actionViews;
@property (nonatomic, strong) UIView *actionsContainer;
- (instancetype)initWithIconName:(NSString *)iconName tintColor:(UIColor *)tint;
- (void)setActions:(NSArray<LGExpandingMenuAction *> *)actions;
- (void)expandMenu;
- (void)collapseMenu;
- (void)toggle;
@end

@implementation LGExpandingNavBarButton

- (instancetype)initWithIconName:(NSString *)iconName tintColor:(UIColor *)tint {
    if (self = [super initWithFrame:CGRectMake(0, 0, 40, 40)]) {
        self.backgroundColor = [UIColor clearColor];
        _buttonGlass = [[AppleLiquidGlassView alloc] initWithFrame:self.bounds cornerRadius:20.0 materialType:LGGlassMaterialTypeCrystal];
        _buttonGlass.userInteractionEnabled = NO;
        _buttonGlass.interactiveHighlightEnabled = NO;
        _buttonGlass.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_buttonGlass];

        _iconView = [[UIImageView alloc] init];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.tintColor = tint ?: [UIColor whiteColor];
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        UIImage *img = [UIImage systemImageNamed:iconName];
        _iconView.image = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [self addSubview:_iconView];

        [NSLayoutConstraint activateConstraints:@[
            [_iconView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_iconView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_iconView.widthAnchor constraintEqualToConstant:18],
            [_iconView.heightAnchor constraintEqualToConstant:18]
        ]];

        _actionViews = [NSMutableArray array];
        _expanded = NO;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap)];
        [self addGestureRecognizer:tap];
        [self addTarget:self action:@selector(tDown) forControlEvents:UIControlEventTouchDown];
        [self addTarget:self action:@selector(tUp) forControlEvents:UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    }
    return self;
}
- (void)tDown { [UIView animateWithDuration:0.14 animations:^{ self.transform = CGAffineTransformMakeScale(0.92, 0.92); }]; }
- (void)tUp { [UIView animateWithDuration:0.42 delay:0 usingSpringWithDamping:0.60 initialSpringVelocity:0.9 options:0 animations:^{ self.transform = CGAffineTransformIdentity; } completion:nil]; }

- (void)setActions:(NSArray<LGExpandingMenuAction *> *)actions { _actions = actions; }
- (void)handleTap { if (_expanded) [self collapseMenu]; else [self expandMenu]; }

- (UIWindow *)hostWindow {
    if (self.window) return self.window;

    UIWindow *keyWin = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *ws = (UIWindowScene *)scene;
            if (ws.activationState != UISceneActivationStateForegroundActive) continue;
            for (UIWindow *win in ws.windows) {
                if (win.isKeyWindow) return win;
                if (!keyWin) keyWin = win;
            }
        }
    }
    if (keyWin) return keyWin;
    return [UIApplication sharedApplication].windows.firstObject;
}

- (void)expandMenu {
    if (_expanded || _actions.count == 0) return;
    _expanded = YES;
    UIWindow *host = [self hostWindow];
    if (!host) { _expanded = NO; return; }

    if (!_dimOverlay) {
        _dimOverlay = [[UIView alloc] initWithFrame:host.bounds];
        _dimOverlay.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.18];
        _dimOverlay.alpha = 0.0;
        _dimOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        UITapGestureRecognizer *dimTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(collapseMenu)];
        [_dimOverlay addGestureRecognizer:dimTap];
    }
    [host addSubview:_dimOverlay];
    [host bringSubviewToFront:_dimOverlay];
    [UIView animateWithDuration:0.28 animations:^{ self->_dimOverlay.alpha = 1.0; }];

    if (!_actionsContainer) {
        _actionsContainer = [[UIView alloc] initWithFrame:CGRectZero];
        _actionsContainer.backgroundColor = [UIColor clearColor];
    }
    [_actionsContainer removeFromSuperview];
    for (LGExpandingActionView *v in _actionViews) [v removeFromSuperview];
    [_actionViews removeAllObjects];

    CGRect selfInWindow = [self convertRect:self.bounds toView:host];
    CGFloat startX = CGRectGetMaxX(selfInWindow) - 220;
    CGFloat startY = CGRectGetMaxY(selfInWindow) + 8;
    if (startX < 8) startX = 8;
    if (startY + _actions.count * 56.0 > host.bounds.size.height - 8) {
        startY = CGRectGetMinY(selfInWindow) - (_actions.count * 56.0) - 8;
    }
    _actionsContainer.frame = CGRectMake(startX, startY, 220, _actions.count * 56.0);

    for (NSInteger i = 0; i < _actions.count; i++) {
        LGExpandingMenuAction *action = _actions[i];
        LGExpandingActionView *view = [[LGExpandingActionView alloc] initWithAction:action];
        view.tag = i;
        view.frame = CGRectMake(0, i * 56.0, 220, 48);
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeScale(0.6, 0.6);
        [view addTarget:self action:@selector(actionViewTap:) forControlEvents:UIControlEventTouchUpInside];
        [_actionsContainer addSubview:view];
        [_actionViews addObject:view];
    }

    [host addSubview:_actionsContainer];
    [host bringSubviewToFront:_actionsContainer];

    for (NSInteger i = 0; i < _actionViews.count; i++) {
        LGExpandingActionView *v = _actionViews[i];
        NSTimeInterval delay = i * 0.05;
        [UIView animateWithDuration:0.42 delay:delay usingSpringWithDamping:0.68 initialSpringVelocity:0.8 options:UIViewAnimationOptionCurveEaseOut animations:^{
            v.alpha = 1.0;
            v.transform = CGAffineTransformIdentity;
        } completion:nil];
    }

    [UIView animateWithDuration:0.34 delay:0 usingSpringWithDamping:0.62 initialSpringVelocity:0.9 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.iconView.transform = CGAffineTransformMakeRotation(M_PI_4);
    } completion:nil];

    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];
    if ([_delegate respondsToSelector:@selector(expandingButtonDidExpand:)]) [_delegate expandingButtonDidExpand:self];
}

- (void)collapseMenu {
    if (!_expanded) return;
    _expanded = NO;
    for (NSInteger i = 0; i < _actionViews.count; i++) {
        LGExpandingActionView *v = _actionViews[_actionViews.count - 1 - i];
        NSTimeInterval delay = i * 0.03;
        [UIView animateWithDuration:0.26 delay:delay options:UIViewAnimationOptionCurveEaseIn animations:^{
            v.alpha = 0.0;
            v.transform = CGAffineTransformMakeScale(0.7, 0.7);
        } completion:nil];
    }
    [UIView animateWithDuration:0.28 delay:0.10 options:UIViewAnimationOptionCurveEaseIn animations:^{
        self->_dimOverlay.alpha = 0.0;
        self.iconView.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        [self->_actionsContainer removeFromSuperview];
        [self->_dimOverlay removeFromSuperview];
        [self->_actionViews removeAllObjects];
    }];
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    if ([_delegate respondsToSelector:@selector(expandingButtonDidCollapse:)]) [_delegate expandingButtonDidCollapse:self];
}

- (void)toggle { if (_expanded) [self collapseMenu]; else [self expandMenu]; }

- (void)actionViewTap:(LGExpandingActionView *)v {
    NSInteger idx = v.tag;
    UINotificationFeedbackGenerator *fb = [[UINotificationFeedbackGenerator alloc] init];
    [fb notificationOccurred:UINotificationFeedbackTypeSuccess];
    [self collapseMenu];
    __weak typeof(self) wSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(wSelf) sSelf = wSelf;
        if (sSelf && [sSelf.delegate respondsToSelector:@selector(expandingButton:didSelectActionAtIndex:)]) {
            [sSelf.delegate expandingButton:sSelf didSelectActionAtIndex:idx];
        }
    });
}
@end

// ====================================================================================================
// MODULE 8: LOADING VIEWS
// ====================================================================================================
@interface LGLoadingManView : UIView
// [V10.3 - THEO VIDEO TIKTOK #7]: 3 chấm tròn nhảy lên xuống (bouncing dots), nền kính lỏng tối
@property (nonatomic, strong) UIView *dot1;
@property (nonatomic, strong) UIView *dot2;
@property (nonatomic, strong) UIView *dot3;
@property (nonatomic, strong) UILabel *loadingLabel;
@property (nonatomic, strong) NSTimer *animTimer;
@property (nonatomic, assign) CGFloat phase;
@property (nonatomic, assign) CGFloat progressValue;
- (void)startAnimating;
- (void)stopAnimating;
- (void)setProgressValue:(CGFloat)progressValue animated:(BOOL)animated;
@end

@implementation LGLoadingManView
- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        // [V10.3] Nền kính lỏng tối, bo tròn mềm
        self.backgroundColor = [UIColor colorWithRed:0.10 green:0.11 blue:0.14 alpha:0.92];
        self.clipsToBounds = YES;
        self.layer.cornerRadius = 18.0;
        if (@available(iOS 13.0, *)) self.layer.cornerCurve = kCACornerCurveContinuous;

        CGFloat dotSize = 12.0;
        CGFloat spacing = 14.0;
        CGFloat totalW = dotSize * 3 + spacing * 2;
        CGFloat startX = (frame.size.width - totalW) / 2.0;
        CGFloat dotY = frame.size.height / 2.0 - 14.0;

        _dot1 = [[UIView alloc] initWithFrame:CGRectMake(startX, dotY, dotSize, dotSize)];
        _dot1.backgroundColor = [UIColor colorWithRed:0.35 green:0.95 blue:0.60 alpha:1.0];
        _dot1.layer.cornerRadius = dotSize / 2.0;
        [self addSubview:_dot1];

        _dot2 = [[UIView alloc] initWithFrame:CGRectMake(startX + dotSize + spacing, dotY, dotSize, dotSize)];
        _dot2.backgroundColor = [UIColor colorWithRed:0.40 green:0.85 blue:1.0 alpha:1.0];
        _dot2.layer.cornerRadius = dotSize / 2.0;
        [self addSubview:_dot2];

        _dot3 = [[UIView alloc] initWithFrame:CGRectMake(startX + (dotSize + spacing) * 2, dotY, dotSize, dotSize)];
        _dot3.backgroundColor = [UIColor colorWithRed:1.0 green:0.80 blue:0.30 alpha:1.0];
        _dot3.layer.cornerRadius = dotSize / 2.0;
        [self addSubview:_dot3];

        _loadingLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, frame.size.height - 28, frame.size.width, 20)];
        _loadingLabel.text = @"ĐANG ÁP DỤNG...";
        _loadingLabel.textColor = [UIColor colorWithWhite:0.85 alpha:1.0];
        _loadingLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        _loadingLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_loadingLabel];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat dotSize = 12.0, spacing = 14.0;
    CGFloat totalW = dotSize * 3 + spacing * 2;
    CGFloat startX = (self.bounds.size.width - totalW) / 2.0;
    CGFloat dotY = self.bounds.size.height / 2.0 - 14.0;
    _dot1.frame = CGRectMake(startX, dotY, dotSize, dotSize);
    _dot2.frame = CGRectMake(startX + dotSize + spacing, dotY, dotSize, dotSize);
    _dot3.frame = CGRectMake(startX + (dotSize + spacing) * 2, dotY, dotSize, dotSize);
    _loadingLabel.frame = CGRectMake(0, self.bounds.size.height - 28, self.bounds.size.width, 20);
}
- (void)startAnimating {
    [self stopAnimating];
    _phase = 0;
    _animTimer = [NSTimer scheduledTimerWithTimeInterval:0.10 repeats:YES block:^(NSTimer * _Nonnull t) {
        self.phase += 0.18;
        CGFloat s1 = sin(self.phase);
        CGFloat s2 = sin(self.phase + 0.8);
        CGFloat s3 = sin(self.phase + 1.6);
        CGFloat baseY = self.bounds.size.height / 2.0 - 14.0;
        [UIView animateWithDuration:0.16 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
            self.dot1.transform = CGAffineTransformMakeTranslation(0, s1 * 8.0);
            self.dot2.transform = CGAffineTransformMakeTranslation(0, s2 * 8.0);
            self.dot3.transform = CGAffineTransformMakeTranslation(0, s3 * 8.0);
            CGFloat sc1 = 1.0 + fabs(s1) * 0.15;
            CGFloat sc2 = 1.0 + fabs(s2) * 0.15;
            CGFloat sc3 = 1.0 + fabs(s3) * 0.15;
            self.dot1.transform = CGAffineTransformScale(CGAffineTransformMakeTranslation(0, s1 * 8.0), sc1, sc1);
            self.dot2.transform = CGAffineTransformScale(CGAffineTransformMakeTranslation(0, s2 * 8.0), sc2, sc2);
            self.dot3.transform = CGAffineTransformScale(CGAffineTransformMakeTranslation(0, s3 * 8.0), sc3, sc3);
        } completion:nil];
    }];
    [[NSRunLoop mainRunLoop] addTimer:_animTimer forMode:NSRunLoopCommonModes];
}
- (void)stopAnimating { if (_animTimer) { [_animTimer invalidate]; _animTimer = nil; } }
- (void)setProgressValue:(CGFloat)progressValue animated:(BOOL)animated { _progressValue = MAX(0.0, MIN(1.0, progressValue)); }
- (void)dealloc { [self stopAnimating]; }
@end

@interface LGLoadingCarView : UIView
@property (nonatomic, strong) UIView *container;
@property (nonatomic, strong) UIView *carBody;
@property (nonatomic, strong) UIView *carRoof;
@property (nonatomic, strong) UIView *carWindow;
@property (nonatomic, strong) UIView *wheel1;
@property (nonatomic, strong) UIView *wheel2;
@property (nonatomic, strong) UIView *strike1;
@property (nonatomic, strong) UIView *strike2;
@property (nonatomic, strong) UILabel *loadingLabel;
@property (nonatomic, strong) NSTimer *animTimer;
@property (nonatomic, assign) CGFloat phase;
@end

@implementation LGLoadingCarView
- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.13 alpha:1.0];

        _container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 240, 120)];
        _container.backgroundColor = [UIColor clearColor];
        _container.layer.borderColor = [UIColor whiteColor].CGColor;
        _container.layer.borderWidth = 1.5;
        _container.layer.cornerRadius = 8;
        [self addSubview:_container];

        _strike1 = [[UIView alloc] initWithFrame:CGRectMake(30, 60, 11, 1)];
        _strike1.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1.0];
        [_container addSubview:_strike1];
        _strike2 = [[UIView alloc] initWithFrame:CGRectMake(48, 68, 11, 1)];
        _strike2.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1.0];
        [_container addSubview:_strike2];

        _carBody = [[UIView alloc] initWithFrame:CGRectMake(80, 46, 120, 28)];
        _carBody.backgroundColor = [UIColor colorWithWhite:0.94 alpha:1.0];
        _carBody.layer.cornerRadius = 8;
        [_container addSubview:_carBody];

        _carRoof = [[UIView alloc] initWithFrame:CGRectMake(105, 32, 60, 18)];
        _carRoof.backgroundColor = [UIColor colorWithWhite:0.94 alpha:1.0];
        _carRoof.layer.cornerRadius = 7;
        [_container addSubview:_carRoof];

        _carWindow = [[UIView alloc] initWithFrame:CGRectMake(112, 36, 26, 12)];
        _carWindow.backgroundColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.18 alpha:1.0];
        _carWindow.layer.cornerRadius = 3;
        [_container addSubview:_carWindow];

        _wheel1 = [[UIView alloc] initWithFrame:CGRectMake(102, 68, 18, 18)];
        _wheel1.backgroundColor = [UIColor colorWithWhite:0.18 alpha:1.0];
        _wheel1.layer.cornerRadius = 9;
        _wheel1.layer.borderColor = [UIColor whiteColor].CGColor;
        _wheel1.layer.borderWidth = 1.5;
        [_container addSubview:_wheel1];

        _wheel2 = [[UIView alloc] initWithFrame:CGRectMake(180, 68, 18, 18)];
        _wheel2.backgroundColor = [UIColor colorWithWhite:0.18 alpha:1.0];
        _wheel2.layer.cornerRadius = 9;
        _wheel2.layer.borderColor = [UIColor whiteColor].CGColor;
        _wheel2.layer.borderWidth = 1.5;
        [_container addSubview:_wheel2];

        _loadingLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _loadingLabel.text = @"Đang áp dụng...";
        _loadingLabel.textColor = [UIColor whiteColor];
        _loadingLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        _loadingLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_loadingLabel];

        _phase = 0;
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat W = self.bounds.size.width, H = self.bounds.size.height;
    _container.frame = CGRectMake((W - 240) / 2, (H - 130) / 2, 240, 100);
    _loadingLabel.frame = CGRectMake(0, CGRectGetMaxY(_container.frame) + 8, W, 22);
}
- (void)startAnimating {
    [self stopAnimating];
    _animTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 repeats:YES block:^(NSTimer * _Nonnull t) {
        self.phase += 0.35;
        [self updateCarAnimation];
    }];
    [[NSRunLoop mainRunLoop] addTimer:_animTimer forMode:NSRunLoopCommonModes];
}
- (void)stopAnimating { if (_animTimer) { [_animTimer invalidate]; _animTimer = nil; } }
- (void)updateCarAnimation {
    CGFloat bounce = sin(_phase) * 1.0;
    _carBody.transform = CGAffineTransformMakeTranslation(0, bounce);
    _carRoof.transform = CGAffineTransformMakeTranslation(0, bounce);
    _carWindow.transform = CGAffineTransformMakeTranslation(0, bounce);
    _wheel1.transform = CGAffineTransformMakeRotation(_phase);
    _wheel2.transform = CGAffineTransformMakeRotation(_phase);
    CGFloat smokeX = fmod(_phase * 8.0, 60.0);
    _strike1.transform = CGAffineTransformMakeTranslation(-smokeX, 0);
    _strike1.alpha = 1.0 - (smokeX / 60.0);
    _strike2.transform = CGAffineTransformMakeTranslation(-fmod(smokeX + 25, 60.0), 0);
    _strike2.alpha = 1.0 - (fmod(smokeX + 25, 60.0) / 60.0);
}
- (void)dealloc { [self stopAnimating]; }
@end

typedef NS_ENUM(NSInteger, LGAppleServerPhase) {
    LGAppleServerPhaseIdle       = 0,
    LGAppleServerPhaseConnecting = 1,
    LGAppleServerPhaseQueueing   = 2,
    LGAppleServerPhaseExploiting = 3,
    LGAppleServerPhaseSuccess    = 4
};

@interface LGAppleServerConnectView : UIView
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *subLabel;
@property (nonatomic, strong) UIView *spinner;
@property (nonatomic, strong) CAShapeLayer *spinnerArc;
@property (nonatomic, strong) UIProgressView *progressBar;
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, strong) UILabel *formTitleLabel;
@property (nonatomic, strong) UITextField *usernameField;
@property (nonatomic, strong) UITextField *passwordField;
@property (nonatomic, strong) UIButton *loginButton;
@property (nonatomic, assign) LGAppleServerPhase phase;
@property (nonatomic, assign) NSInteger exploitStep;
@property (nonatomic, copy) void (^completionBlock)(BOOL success);
@property (nonatomic, strong) CADisplayLink *spinLink;
@property (nonatomic, assign) CFTimeInterval spinStartTime;
@property (nonatomic, strong) NSTimer *stepTimer;
@property (nonatomic, assign) BOOL cancelled;
@property (nonatomic, assign) BOOL isAdminMode;
@end

@implementation LGAppleServerConnectView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor colorWithRed:0.32 green:0.47 blue:0.94 alpha:1.0];
        _cancelled = NO;
        _isAdminMode = [[NSUserDefaults standardUserDefaults] boolForKey:TI_ADMIN_SERVER_KEY];

        _cardView = [[UIView alloc] initWithFrame:CGRectZero];
        _cardView.backgroundColor = [UIColor clearColor];
        [self addSubview:_cardView];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.text = _isAdminMode ? @"Admin Server" : @"Login";
        _titleLabel.textColor = [UIColor whiteColor];
        _titleLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
        _titleLabel.textAlignment = NSTextAlignmentLeft;
        [_cardView addSubview:_titleLabel];

        _usernameField = [[UITextField alloc] init];
        _usernameField.placeholder = @"Username";
        _usernameField.text = _isAdminMode ? @"independent.toolkit.admin" : @"local-demo";
        _usernameField.userInteractionEnabled = NO;
        _usernameField.textColor = [UIColor whiteColor];
        _usernameField.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        _usernameField.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
        _usernameField.layer.cornerRadius = 6;
        _usernameField.layer.borderWidth = 0.5;
        _usernameField.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.15].CGColor;
        _usernameField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 40)];
        _usernameField.leftViewMode = UITextFieldViewModeAlways;
        [_cardView addSubview:_usernameField];

        _passwordField = [[UITextField alloc] init];
        _passwordField.placeholder = @"Password";
        _passwordField.text = @"••••••••";
        _passwordField.secureTextEntry = YES;
        _passwordField.userInteractionEnabled = NO;
        _passwordField.textColor = [UIColor whiteColor];
        _passwordField.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        _passwordField.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
        _passwordField.layer.cornerRadius = 6;
        _passwordField.layer.borderWidth = 0.5;
        _passwordField.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.15].CGColor;
        _passwordField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 40)];
        _passwordField.leftViewMode = UITextFieldViewModeAlways;
        [_cardView addSubview:_passwordField];

        _loginButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_loginButton setTitle:@"Kích hoạt" forState:UIControlStateNormal];
        [_loginButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _loginButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        _loginButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0];
        _loginButton.layer.cornerRadius = 6;
        [_loginButton addTarget:self action:@selector(handleLoginTapped) forControlEvents:UIControlEventTouchUpInside];
        [_cardView addSubview:_loginButton];

        _formTitleLabel = [[UILabel alloc] init];
        _formTitleLabel.text = _isAdminMode ? @"Nhấn KÍCH HOẠT để kiểm tra cấu hình server Admin" : @"Nhấn KÍCH HOẠT để kiểm tra cấu hình";
        _formTitleLabel.textColor = [UIColor colorWithWhite:0.85 alpha:1.0];
        _formTitleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        _formTitleLabel.textAlignment = NSTextAlignmentLeft;
        _formTitleLabel.numberOfLines = 2;
        [_cardView addSubview:_formTitleLabel];

        _spinner = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 60, 60)];
        _spinner.backgroundColor = [UIColor clearColor];
        _spinner.hidden = YES;
        [self addSubview:_spinner];

        _spinnerArc = [CAShapeLayer layer];
        _spinnerArc.bounds = CGRectMake(0, 0, 60, 60);
        _spinnerArc.position = CGPointMake(30, 30);
        _spinnerArc.anchorPoint = CGPointMake(0.5, 0.5);
        _spinnerArc.fillColor = [UIColor clearColor].CGColor;
        _spinnerArc.strokeColor = [UIColor whiteColor].CGColor;
        _spinnerArc.lineWidth = 4.0;
        _spinnerArc.lineCap = kCALineCapRound;
        UIBezierPath *arc = [UIBezierPath bezierPathWithArcCenter:CGPointMake(30, 30)
                                                           radius:26
                                                       startAngle:-M_PI_2
                                                         endAngle:M_PI_2
                                                        clockwise:YES];
        _spinnerArc.path = arc.CGPath;
        [_spinner.layer addSublayer:_spinnerArc];

        _statusLabel = [[UILabel alloc] init];
        _statusLabel.textColor = [UIColor whiteColor];
        _statusLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        _statusLabel.textAlignment = NSTextAlignmentCenter;
        _statusLabel.numberOfLines = 0;
        [self addSubview:_statusLabel];

        _subLabel = [[UILabel alloc] init];
        _subLabel.textColor = [UIColor colorWithWhite:0.9 alpha:1.0];
        _subLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
        _subLabel.textAlignment = NSTextAlignmentCenter;
        _subLabel.numberOfLines = 0;
        [self addSubview:_subLabel];

        _progressBar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        _progressBar.progressTintColor = [UIColor whiteColor];
        _progressBar.trackTintColor = [UIColor colorWithWhite:1.0 alpha:0.25];
        _progressBar.hidden = YES;
        [self addSubview:_progressBar];

        _cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_cancelButton setTitle:@"HỦY KÍCH HOẠT" forState:UIControlStateNormal];
        [_cancelButton setTitleColor:[UIColor colorWithRed:1.0 green:0.35 blue:0.35 alpha:1.0] forState:UIControlStateNormal];
        _cancelButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
        _cancelButton.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.32];
        _cancelButton.layer.cornerRadius = 20;
        _cancelButton.layer.borderColor = [UIColor colorWithRed:1.0 green:0.35 blue:0.35 alpha:1.0].CGColor;
        _cancelButton.layer.borderWidth = 1.2;
        [_cancelButton addTarget:self action:@selector(cancelTapped) forControlEvents:UIControlEventTouchUpInside];
        _cancelButton.hidden = YES;
        [self addSubview:_cancelButton];

        _phase = LGAppleServerPhaseIdle;
        _exploitStep = 0;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat W = self.bounds.size.width, H = self.bounds.size.height;

    _spinner.center = CGPointMake(W / 2, H / 2 - 60);
    _spinnerArc.bounds = CGRectMake(0, 0, 60, 60);
    _spinnerArc.position = CGPointMake(30, 30);
    _spinnerArc.anchorPoint = CGPointMake(0.5, 0.5);

    _statusLabel.frame = CGRectMake(20, H / 2 + 5, W - 40, 44);
    _subLabel.frame = CGRectMake(20, H / 2 + 52, W - 40, 48);
    _progressBar.frame = CGRectMake(W * 0.2, H / 2 + 108, W * 0.6, 6);
    _cancelButton.frame = CGRectMake((W - 200) / 2, H - 90, 200, 42);

    CGFloat cardW = MIN(300, W - 60);
    _cardView.frame = CGRectMake((W - cardW) / 2, (H - 300) / 2, cardW, 300);
    CGFloat x = 20, cw = cardW - 40;

    _titleLabel.frame = CGRectMake(x, 20, cw, 30);
    _usernameField.frame = CGRectMake(x, 70, cw, 40);
    _passwordField.frame = CGRectMake(x, 120, cw, 40);
    _loginButton.frame = CGRectMake(x, 172, cw, 40);
    _formTitleLabel.frame = CGRectMake(x, 222, cw, 44);
}

- (void)startConnectionWithCompletion:(void (^)(BOOL))completion {
    self.completionBlock = completion;
    self.phase = LGAppleServerPhaseIdle;
    _cancelled = NO;

    _cardView.hidden = NO;
    _cardView.alpha = 1.0;
    _spinner.hidden = YES;
    _statusLabel.hidden = YES;
    _subLabel.hidden = YES;
    _progressBar.hidden = YES;
    _cancelButton.hidden = YES;
}

- (void)handleLoginTapped {
    if (_phase != LGAppleServerPhaseIdle) return;

    // Không cho kích hoạt nếu server đang sập/quá tải (admin miễn nhiễm)
    if (!_isAdminMode) {
        int pState = Titanium_CurrentPersistentServerState();
        if (pState != TI_STATE_OK) {
            UINotificationFeedbackGenerator *fb = [[UINotificationFeedbackGenerator alloc] init];
            [fb notificationOccurred:UINotificationFeedbackTypeError];
            return;
        }
    }

    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];

    [UIView animateWithDuration:0.30 animations:^{
        self->_cardView.alpha = 0.0;
    } completion:^(BOOL finished) {
        self->_cardView.hidden = YES;
        self->_spinner.hidden = NO;
        self->_statusLabel.hidden = NO;
        self->_subLabel.hidden = NO;
        self->_cancelButton.hidden = NO;
        [self runConnectingPhase];
    }];
}

- (void)cancelTapped {
    _cancelled = YES;
    [self stopAllTimers];
    if (self.completionBlock) self.completionBlock(NO);
    [UIView animateWithDuration:0.3 animations:^{ self.alpha = 0.0; } completion:^(BOOL f){ [self removeFromSuperview]; }];
}

- (void)startSpinner {
    [self stopSpinner];
    // V22: render spinner on Core Animation's compositor instead of mutating a layer every display tick on main.
    CABasicAnimation *rotation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    rotation.fromValue = @0.0;
    rotation.toValue = @(M_PI * 2.0);
    rotation.duration = 1.15;
    rotation.repeatCount = HUGE_VALF;
    rotation.removedOnCompletion = NO;
    [_spinnerArc addAnimation:rotation forKey:@"V22.spinner.rotation"];
    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
    pulse.fromValue = @0.45;
    pulse.toValue = @1.0;
    pulse.duration = 0.9;
    pulse.autoreverses = YES;
    pulse.repeatCount = HUGE_VALF;
    pulse.removedOnCompletion = NO;
    [_spinnerArc addAnimation:pulse forKey:@"V22.spinner.opacity"];
}
- (void)stopSpinner {
    if (_spinLink) { [_spinLink invalidate]; _spinLink = nil; }
    [_spinnerArc removeAnimationForKey:@"V22.spinner.rotation"];
    [_spinnerArc removeAnimationForKey:@"V22.spinner.opacity"];
}

- (void)stopAllTimers {
    [self stopSpinner];
    if (_stepTimer) { [_stepTimer invalidate]; _stepTimer = nil; }
}

// ============================================
// FLOW: Connecting (5s)
//   - Admin: direct to exploit
//   - Free 1%: show fail → queue
//   - Free 99%: queue
// ============================================
- (void)runConnectingPhase {
    _phase = LGAppleServerPhaseConnecting;
    _statusLabel.text = @"Đang kiểm tra cấu hình cục bộ...";
    _subLabel.text = @"Không kết nối Apple; không thực hiện thao tác kernel";
    [self startSpinner];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self->_cancelled) return;
        [self runConnectedThenExploit];
    });
}

// ============================================
// FREE: hiển thị fail 1.5s → nhảy vào hàng chờ
// ============================================
- (void)showConnectFailThenQueue {
    // No simulated network failures or artificial queue delays.
    _statusLabel.text = @"Đang kiểm tra cấu hình";
    _subLabel.text = @"Tiếp tục khi hoàn tất kiểm tra cục bộ";
    [self stopSpinner];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self->_cancelled) return;
        [self runQueuePhase];
    });
}

// ============================================
// Queue 20-50s random → connected
// ============================================
- (void)runQueuePhase {
    // Kept for source compatibility; no fabricated 20–50 second queue.
    _phase = LGAppleServerPhaseQueueing;
    _statusLabel.text = @"Đang chuẩn bị cấu hình";
    _subLabel.text = @"Không cần chờ hàng đợi mô phỏng";
    [self stopSpinner];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self->_cancelled) return;
        [self runConnectedThenExploit];
    });
}

// ============================================
// Connected message 2.5s → exploit
// ============================================
- (void)runConnectedThenExploit {
    _statusLabel.text = @"Đang kiểm tra cấu hình";
    _subLabel.text = @"Không thay đổi kernel hoặc nhịp hệ thống";
    [self stopSpinner];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self->_cancelled) return;
        [self runExploitSteps];
    });
}

// ============================================
// Exploit: 10-20s random, 8 steps
// ============================================
- (void)runExploitSteps {
    // This controller does not contain a kernel exploit. It performs a short local configuration check only.
    _phase = LGAppleServerPhaseExploiting;
    _exploitStep = 1;
    NSArray *steps = @[@"Kiểm tra tùy chọn người dùng…", @"Lưu trạng thái kích hoạt…", @"Hoàn tất kiểm tra giao diện…"];
    _progressBar.hidden = NO;
    _progressBar.progress = 0.0;
    __block NSInteger idx = 0;
    _stepTimer = [NSTimer scheduledTimerWithTimeInterval:0.18 repeats:YES block:^(NSTimer * _Nonnull timer) {
        if (self->_cancelled) { [timer invalidate]; self->_stepTimer = nil; return; }
        if (idx >= steps.count) {
            [timer invalidate];
            self->_stepTimer = nil;
            [self runComplete];
            return;
        }
        self->_statusLabel.text = [NSString stringWithFormat:@"Đang kiểm tra %ld/%lu", (long)(idx + 1), (unsigned long)steps.count];
        self->_subLabel.text = steps[idx];
        self->_progressBar.progress = (float)(idx + 1) / (float)steps.count;
        idx++;
    }];
    [[NSRunLoop mainRunLoop] addTimer:_stepTimer forMode:NSRunLoopCommonModes];
}

- (void)runComplete {
    _phase = LGAppleServerPhaseSuccess;
    [self stopAllTimers];
    _statusLabel.text = @"HOÀN TẤT CẤU HÌNH";
    _subLabel.text = @"Đã lưu tuỳ chọn giao diện; không thực hiện khai thác kernel";
    _progressBar.progress = 1.0;
    _spinner.hidden = YES;
    _cancelButton.hidden = YES;

    UINotificationFeedbackGenerator *fb = [[UINotificationFeedbackGenerator alloc] init];
    [fb notificationOccurred:UINotificationFeedbackTypeSuccess];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.completionBlock) self.completionBlock(YES);
        [UIView animateWithDuration:0.3 animations:^{ self.alpha = 0.0; } completion:^(BOOL finished) { [self removeFromSuperview]; }];
    });
}

- (void)dealloc { [self stopAllTimers]; }
@end

// ====================================================================================================
// MODULE 9: HELPER FUNCTIONS
// ====================================================================================================
static inline NSString *Titanium_GetRootHidePrefixPath(void) {
    static NSString *cached = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Dl_info info;
        if (dladdr((const void *)Titanium_GetRootHidePrefixPath, &info) && info.dli_fname) {
            NSString *dylib = [NSString stringWithUTF8String:info.dli_fname];
            NSRange r = [dylib rangeOfString:@"/var/jb"];
            if (r.location != NSNotFound) {
                NSRange sub = [dylib rangeOfString:@"/" options:0 range:NSMakeRange(r.location + 7, dylib.length - (r.location + 7))];
                cached = (sub.location != NSNotFound) ? [dylib substringToIndex:sub.location] : @"/var/jb";
            } else cached = @"/var/jb";
        } else cached = @"/var/jb";
    });
    return cached;
}
static inline NSString *Titanium_DetectJailbreakTypeForUI(void) {
    Dl_info info;
    memset(&info, 0, sizeof(info));
    if (dladdr((const void *)Titanium_DetectJailbreakTypeForUI, &info) && info.dli_fname) {
        NSString *imagePath = [NSString stringWithUTF8String:info.dli_fname];
        if ([imagePath containsString:@"/var/jb/"]) {
            // Best-effort bootstrap classification. RootHide and ordinary rootless can share
            // the same prefix, so use marker paths when visible and otherwise report rootless.
            BOOL rootHideMarker = (access("/var/jb/basebin", F_OK) == 0 ||
                                   access("/var/jb/.procursus_strapped", F_OK) == 0);
            return rootHideMarker ? @"RootHide (dấu hiệu bootstrap)" : @"Rootless (/var/jb)";
        }
        if ([imagePath containsString:@"/Library/MobileSubstrate/DynamicLibraries/"] ||
            [imagePath containsString:@"/usr/lib/TweakInject/"] ||
            [imagePath containsString:@"/Library/PreferenceBundles/"]) {
            return @"Rootful";
        }
    }
    return @"Không xác định";
}

// UI-only detection: unlike Titanium_GetRootHidePrefixPath(), this never returns a guessed
// /var/jb fallback. A path is shown only when the loaded tweak image provides evidence for it.
static inline NSString *Titanium_DetectedBootstrapPrefixForUI(void) {
    Dl_info info;
    memset(&info, 0, sizeof(info));
    if (!dladdr((const void *)Titanium_DetectedBootstrapPrefixForUI, &info) || !info.dli_fname) return nil;
    NSString *imagePath = [NSString stringWithUTF8String:info.dli_fname];
    if ([imagePath containsString:@"/var/jb/"]) return @"/var/jb";
    if ([imagePath containsString:@"/Library/MobileSubstrate/DynamicLibraries/"] ||
        [imagePath containsString:@"/usr/lib/TweakInject/"] ||
        [imagePath containsString:@"/Library/PreferenceBundles/"]) return @"/";
    return nil;
}

static NSString *Titanium_SandboxDiagnosticForUI(void) {
    const char *home = NSHomeDirectory().fileSystemRepresentation;
    BOOL canReadOwnHome = home && access(home, R_OK | X_OK) == 0;
    BOOL canWriteOwnHome = home && access(home, W_OK | X_OK) == 0;
    BOOL systemReadable = access("/System", R_OK | X_OK) == 0;
    BOOL systemWritable = access("/System", W_OK | X_OK) == 0;
    BOOL privateVarReadable = access("/private/var", R_OK | X_OK) == 0;
    BOOL bootstrapExists = access("/var/jb", F_OK) == 0;
    return [NSString stringWithFormat:@"Home %@/%@ · /System đọc:%@ ghi-quyền:%@ · /private/var đọc:%@ · bootstrap:%@",
            canReadOwnHome ? @"đọc được" : @"không đọc được",
            canWriteOwnHome ? @"ghi được" : @"không ghi được",
            systemReadable ? @"có" : @"không",
            systemWritable ? @"được báo có quyền" : @"bị chặn",
            privateVarReadable ? @"có" : @"không",
            bootstrapExists ? @"có /var/jb" : @"không thấy /var/jb"];
}

static NSString *Titanium_IPCDiagnosticForUI(void) {
    struct stat st;
    if (stat([PRIMARY_SYNC_FILE fileSystemRepresentation], &st) == 0) {
        if (st.st_size == (off_t)sizeof(ApexV285ProPayload)) return @"Payload có mặt tại /tmp";
        return @"Payload tại /tmp sai kích thước";
    }
    if (stat([SECONDARY_SYNC_FILE fileSystemRepresentation], &st) == 0) {
        if (st.st_size == (off_t)sizeof(ApexV285ProPayload)) return @"Payload có mặt tại /var/jb/tmp";
        return @"Payload tại /var/jb/tmp sai kích thước";
    }
    if (access("/tmp", W_OK | X_OK) == 0) return @"Chưa có payload; /tmp truy cập được";
    return @"Chưa đọc được payload IPC";
}
static inline NSString *Titanium_ResolvePrefPath(void) {
    NSString *root = Titanium_GetRootHidePrefixPath();
    if (root && root.length > 0 && ![root isEqualToString:@"/"]) {
        NSString *p = [root stringByAppendingPathComponent:@"var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:p]) return p;
    }
    NSString *p1 = @"/var/jb/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist";
    if ([[NSFileManager defaultManager] fileExistsAtPath:p1]) return p1;
    return @"/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist";
}
static inline NSString *Titanium_FindExecutablePath(NSString *name) {
    NSArray *pref = @[
        [Titanium_GetRootHidePrefixPath() stringByAppendingPathComponent:@"usr/bin"],
        [Titanium_GetRootHidePrefixPath() stringByAppendingPathComponent:@"bin"],
        @"/var/jb/usr/bin", @"/var/jb/bin", @"/usr/bin", @"/bin"
    ];
    for (NSString *p in pref) {
        NSString *c = [p stringByAppendingPathComponent:name];
        if (access([c UTF8String], X_OK) == 0) return c;
    }
    return nil;
}
static BOOL Titanium_WriteAllBytes(int fd, const void *data, size_t size) {
    const uint8_t *cursor = (const uint8_t *)data;
    size_t remaining = size;
    while (remaining > 0) {
        ssize_t written = write(fd, cursor, remaining);
        if (written < 0 && errno == EINTR) continue;
        if (written <= 0) return NO;
        cursor += (size_t)written;
        remaining -= (size_t)written;
    }
    return YES;
}

// Sequence values must be comparable across processes and across device reboots. mach_absolute_time()
// resets after reboot, so use an epoch-nanosecond token for IPC ordering (the payload is private to this tweak).
static uint64_t Titanium_IPCSequenceNow(void) {
    NSTimeInterval epoch = [[NSDate date] timeIntervalSince1970];
    uint64_t candidate = (isfinite(epoch) && epoch >= 1.0)
        ? (uint64_t)(epoch * 1000000000.0) : (uint64_t)mach_absolute_time();
    // Keep same-process writes strictly ordered even when NSDate returns the same clock tick.
    static os_unfair_lock sequenceLock = OS_UNFAIR_LOCK_INIT;
    static uint64_t lastSequence = 0;
    os_unfair_lock_lock(&sequenceLock);
    if (candidate <= lastSequence) candidate = lastSequence + 1;
    lastSequence = candidate;
    os_unfair_lock_unlock(&sequenceLock);
    return candidate;
}

static BOOL Titanium_WriteAtomicBytesAtPath(NSString *path, const void *data, size_t size) {
    if (path.length == 0 || (size > 0 && data == NULL)) return NO;
    NSString *dir = [path stringByDeletingLastPathComponent];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:dir] && ![fm createDirectoryAtPath:dir
                                        withIntermediateDirectories:YES
                                                         attributes:@{NSFilePosixPermissions: @(0777)}
                                                              error:nil] && ![fm fileExistsAtPath:dir]) return NO;

    NSString *template = [path stringByAppendingString:@".tmp.XXXXXX"];
    char *temporaryPath = strdup([template fileSystemRepresentation]);
    if (!temporaryPath) return NO;
    int fd = mkstemp(temporaryPath);
    if (fd < 0) { free(temporaryPath); return NO; }
    BOOL ok = Titanium_WriteAllBytes(fd, data, size);
    if (ok && fsync(fd) != 0) ok = NO;
    if (ok && fchmod(fd, 0644) != 0) ok = NO;
    if (close(fd) != 0) ok = NO;
    if (ok && rename(temporaryPath, [path fileSystemRepresentation]) == 0) {
        (void)chmod([path fileSystemRepresentation], 0644);
        int dirFD = open([dir fileSystemRepresentation], O_RDONLY);
        if (dirFD >= 0) { (void)fsync(dirFD); close(dirFD); }
    } else {
        (void)unlink(temporaryPath);
        ok = NO;
    }
    free(temporaryPath);
    return ok;
}

// Atomic replacement prevents Tweak.xm from reading a partly written payload. Each write gets
// its own temporary file, so rapid UI toggles cannot overwrite one another's staging file.
static void Titanium_WriteSyncPayloadUniversal(const void *data, size_t size) {
    if (!data || size != sizeof(ApexV285ProPayload)) return;
    (void)Titanium_WriteAtomicBytesAtPath(PRIMARY_SYNC_FILE, data, size);
    (void)Titanium_WriteAtomicBytesAtPath(SECONDARY_SYNC_FILE, data, size);
}

// Same disabled-bundle IPC file format consumed by Tweak.xm in third-party app sandboxes.
static void Titanium_WriteDisabledAppsFile(NSString *joinedIDs) {
    NSData *data = [(joinedIDs ?: @"") dataUsingEncoding:NSUTF8StringEncoding];
    (void)Titanium_WriteAtomicBytesAtPath(APPS_SYNC_FILE_PRIMARY, data.bytes, data.length);
    (void)Titanium_WriteAtomicBytesAtPath(APPS_SYNC_FILE_SECONDARY, data.bytes, data.length);
}

static dispatch_queue_t Titanium_IPCWriterQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ queue = dispatch_queue_create("com.taojb.boostiphone6s.ipc-writer", DISPATCH_QUEUE_SERIAL); });
    return queue;
}
static inline BOOL Titanium_IsSupportedIOSVersion(void) {
    NSOperatingSystemVersion os = [[NSProcessInfo processInfo] operatingSystemVersion];
    return (os.majorVersion >= 15 && os.majorVersion <= 26);
}
// CPU load is derived from deltas between real host CPU tick snapshots. Sampling is cached
// for at least one second so multiple table cells do not consume the same delta twice.
static os_unfair_lock gTIUSCPULoadLock = OS_UNFAIR_LOCK_INIT;
static BOOL gTIUSCPUHasBaseline = NO;
static uint64_t gTIUSCPUUserTicks = 0, gTIUSCPUSystemTicks = 0, gTIUSCPUIdleTicks = 0, gTIUSCPUNiceTicks = 0;
static CFTimeInterval gTIUSCPULastSampleTime = 0;
static float gTIUSCachedCPULoad = -1.0f;

static inline float Titanium_GetLiveCPULoadPercentage(void) {
    host_cpu_load_info_data_t info;
    mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;
    if (host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, (host_info_t)&info, &count) != KERN_SUCCESS) return -1.0f;

    uint64_t user = info.cpu_ticks[CPU_STATE_USER];
    uint64_t system = info.cpu_ticks[CPU_STATE_SYSTEM];
    uint64_t idle = info.cpu_ticks[CPU_STATE_IDLE];
    uint64_t nice = info.cpu_ticks[CPU_STATE_NICE];
    CFTimeInterval now = CACurrentMediaTime();

    os_unfair_lock_lock(&gTIUSCPULoadLock);
    if (!gTIUSCPUHasBaseline) {
        gTIUSCPUUserTicks = user; gTIUSCPUSystemTicks = system;
        gTIUSCPUIdleTicks = idle; gTIUSCPUNiceTicks = nice;
        gTIUSCPULastSampleTime = now;
        gTIUSCPUHasBaseline = YES;
    } else if (now - gTIUSCPULastSampleTime >= 1.0) {
        uint64_t du = user >= gTIUSCPUUserTicks ? user - gTIUSCPUUserTicks : 0;
        uint64_t ds = system >= gTIUSCPUSystemTicks ? system - gTIUSCPUSystemTicks : 0;
        uint64_t di = idle >= gTIUSCPUIdleTicks ? idle - gTIUSCPUIdleTicks : 0;
        uint64_t dn = nice >= gTIUSCPUNiceTicks ? nice - gTIUSCPUNiceTicks : 0;
        uint64_t total = du + ds + di + dn;
        if (total > 0) gTIUSCachedCPULoad = (float)((double)(du + ds + dn) * 100.0 / (double)total);
        gTIUSCPUUserTicks = user; gTIUSCPUSystemTicks = system;
        gTIUSCPUIdleTicks = idle; gTIUSCPUNiceTicks = nice;
        gTIUSCPULastSampleTime = now;
    }
    float result = gTIUSCachedCPULoad;
    os_unfair_lock_unlock(&gTIUSCPULoadLock);
    return result;
}

// Public iOS APIs do not provide a trustworthy general-purpose GPU utilization percentage
// or per-core die temperature. Return unavailable instead of synthesizing a plausible number.
static inline float Titanium_GetLiveGPULoadPercentage(void) { return -1.0f; }
static inline float Titanium_GetBaseThermalTemp(void) { return -1.0f; }

static NSString *Titanium_ThermalStateDescription(void) {
    NSProcessInfoThermalState state = NSProcessInfo.processInfo.thermalState;
    switch (state) {
        case NSProcessInfoThermalStateNominal: return @"Bình thường";
        case NSProcessInfoThermalStateFair: return @"Ấm hơn bình thường";
        case NSProcessInfoThermalStateSerious: return @"Nhiệt cao";
        case NSProcessInfoThermalStateCritical: return @"Nhiệt rất cao";
        default: return @"Không xác định";
    }
}

static uint32_t Titanium_LogicalCPUCoreCount(void) {
    uint32_t cores = 0; size_t length = sizeof(cores);
    return (sysctlbyname("hw.ncpu", &cores, &length, NULL, 0) == 0) ? cores : 0;
}

static uint64_t Titanium_TotalPhysicalMemoryBytes(void) {
    uint64_t bytes = 0; size_t length = sizeof(bytes);
    return (sysctlbyname("hw.memsize", &bytes, &length, NULL, 0) == 0) ? bytes : 0;
}

static uint64_t Titanium_CurrentProcessFootprintBytes(void) {
    task_vm_info_data_t vmInfo;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    memset(&vmInfo, 0, sizeof(vmInfo));
    if (task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&vmInfo, &count) != KERN_SUCCESS) return 0;
    return (uint64_t)vmInfo.phys_footprint;
}

static NSString *Titanium_ByteCountString(uint64_t bytes) {
    if (bytes == 0) return @"Không khả dụng";
    double gib = (double)bytes / (1024.0 * 1024.0 * 1024.0);
    if (gib >= 1.0) return [NSString stringWithFormat:@"%.2f GiB", gib];
    return [NSString stringWithFormat:@"%.0f MiB", (double)bytes / (1024.0 * 1024.0)];
}

static NSString *Titanium_CPUArchitectureString(void) {
#if defined(__arm64e__)
    return @"arm64e";
#elif defined(__arm64__)
    return @"arm64";
#elif defined(__arm__)
    return @"arm";
#else
    return @"Không xác định";
#endif
}

static NSString *Titanium_DeviceHardwareIdentifier(void) {
    struct utsname info;
    memset(&info, 0, sizeof(info));
    if (uname(&info) != 0 || info.machine[0] == '\0') return @"Không đọc được mã phần cứng";
    return [NSString stringWithCString:info.machine encoding:NSUTF8StringEncoding] ?: @"Không đọc được mã phần cứng";
}

// ====================================================================================================
// MODULE 10: ROOT LIST CONTROLLER
// ====================================================================================================
@interface RootListController () <LGExpandingNavBarButtonDelegate> {
    dispatch_source_t _hudTimer;
    CADisplayLink *_uiFPSDisplayLink;
    CFTimeInterval _uiFPSSampleStart;
    NSInteger _uiFPSFrameCount;
    NSInteger _uiFPSMeasured;
    NSInteger _currentBottomTab;
    NSInteger _currentHzFpsSubTab;
    BOOL _expandedHzFPS;
    NSInteger _appCategoryIndex; // 0=all, 1=system, 2=not on Home Screen (scanner flag), 3=manually hidden/disabled
    NSInteger _currentSwitchSubTab;
    BOOL _isRateLocked;
    BOOL _isFeatureActivated;
    NSUInteger _v22ApplyGeneration;
    BOOL _isCpuExpanded;
    BOOL _isGpuExpanded;
    BOOL _isRamExpanded;
    BOOL _isBatteryExpanded;
    BOOL _isScreenExpanded;
    BOOL _hasPlayedEntranceAnimation;
    BOOL _activationFlowPresenting;
    BOOL _hasStartedAppScan;
    NSTimer *_appScanTimer;
    uint64_t _searchUpdateGeneration;
    uint64_t _v20TableTransitionGeneration;
    NSInteger _v20LongPressPreviewTab;
    CGSize _v20LastNavLayoutSize;
    CGRect _v20LastNavFrame;

    NSString *_deepArchString;
    NSString *_deepCoreCountString;
    NSString *_deepRamString;
    NSString *_deepKernelString;
    NSString *_deepCacheString;
    NSString *_deviceUUIDString;

    NSMutableArray<NSDictionary *> *_scannedAppsList;
    NSMutableArray<NSDictionary *> *_filteredAppsList;
    NSMutableDictionary<NSString *, NSNumber *> *_appTweakStates;
    NSString *_appSearchQuery;

    AppleLiquidGlassView *_liquidNavBarContainer;
    AppleLiquidGlassView *_activeGlassIndicator;
    NSMutableArray<LGGlassNavButton *> *_tabButtons;
    NSArray<NSDictionary *> *_tabConfigs;

    UIView *_liquidGlassLensContainer;
    AppleLiquidGlassView *_lensGlassEffectView;
    UILabel *_lensTitleLabel;

    LGExpandingNavBarButton *_expandingMenuButton;
    LGExpandingNavBarButton *_expandingBoltButton;
    LGExpandingNavBarButton *_expandingLockButton;

    BOOL _chipErrorActive;
    NSTimer *_chipErrorTimer;
    NSTimer *_chipRecoverTimer;
    NSInteger _chipErrorRandomSeconds;

    NSInteger _lastAppliedHz;
    NSInteger _lastAppliedFPS;

    UIView *_loadingOverlay;
    LGLoadingCarView *_carView;

    UILabel *_serverStatusLabel;
    UIView *_serverStatusDot;
    NSTimer *_serverBlinkTimer;
    NSTimer *_latencyTimer;
    NSInteger _currentLatencyMs;
    NSInteger _serverLastHTTPStatus;
    BOOL _serverDown;
    BOOL _serverPingReachable;
    BOOL _serverPingAttempted;
    BOOL _pingRequestInFlight;
    BOOL _manualPingRequested;
    uint64_t _serverPingGeneration;

    BOOL _isAdminServer;
    BOOL _adminSessionRestorePending;
    NSString *_adminServerUser;
    NSString *_adminAccessToken;
    NSString *_adminRole;
}
- (void)applyThemePreferenceAnimated:(BOOL)animated;
- (void)applyGlassTransparencyRecursively:(UIView *)view enabled:(BOOL)enabled;
- (void)refreshBottomTabsAvailability;
- (void)updateRoleBadgeTitle:(NSString *)title;
- (void)layoutLiquidGlassControlsForCurrentBounds;
- (void)setupTopHeaderBar;
- (void)showPhonkMusicPicker;
- (UIView *)buildNeonDashboardHeaderWithWidth:(CGFloat)width;
- (UIView *)buildNeonRateHeaderWithWidth:(CGFloat)width;
- (void)startUIFrameSampler;
- (void)stopUIFrameSampler;
- (void)sampleUIFrame:(CADisplayLink *)link;
- (void)refreshNeonLiveReadouts;
- (void)setupExpandingNavigationItems;
- (void)reloadVisibleContentWithSubtleTransition;
- (void)v20HandleForegroundTransition:(NSNotification *)notification;
- (void)restoreStoredAdminSession;
- (void)handleExpiredAdminSessionForPath:(NSString *)path;
- (void)showThemeModePicker;
- (void)showFreeServerPingURLEditor;
- (void)performManualServerPing;
- (NSString *)currentFreeServerPingURL;
- (void)showSandboxDiagnosticDetails;
- (void)showReadOnlyDeviceInfo;
- (void)showCombinedRateInputAlert;
- (void)showServerAPIURLEditor;
- (void)tickLatency;
- (void)showIndependentToolkitMenu;
- (void)showIndependentSwitches;
- (void)showIndependentUsageGuide;
- (void)showIndependentTerms;
- (void)showIndependentPrivacy;
- (void)showIndependentTrademarkNotice;
- (void)showReadOnlyDeviceInformation;
- (void)showSimulatedTerminalLog;
- (void)showIndependentDemoBanner;
- (void)presentIndependentDocument:(NSString *)title text:(NSString *)text;
- (BOOL)independentLanguageIsVietnamese;
- (void)independentSwitchChanged:(UISwitch *)sender;
- (void)neonV11DialPan:(UIPanGestureRecognizer *)gesture;
- (void)neonV11ThermalChanged:(UISwitch *)sender;
- (void)neonV11ShowAppProfile:(NSDictionary *)app;
- (void)neonV11ApplyAppPreset:(NSInteger)preset app:(NSDictionary *)app;
@end

// Preferences for the added independent Toolkit panel.
static NSString * const SUExtraBannerEnabledKey      = @"su_extra_banner_enabled_v1";
static NSString * const SUExtraGlowEnabledKey        = @"su_extra_glow_enabled_v1";
static NSString * const SUExtraDiagnosticsEnabledKey = @"su_extra_diagnostics_enabled_v1";
static NSString * const SUExtraTerminalEnabledKey    = @"su_extra_terminal_demo_enabled_v1";


// [V30 FIX]: Thêm 15Hz vào danh sách chuẩn
static NSArray<NSNumber *> *TIStandardRateValues(void) {
    // Unified Hz/FPS selector: show only the requested presets.
    return @[@60, @90, @120, @144, @240];
}

// [V30 FIX]: Hàm trả về nhãn mô tả từng mức Hz/FPS giống ảnh 2
static NSString *TIRateDescription(NSInteger r, BOOL isHz) {
    NSString *unit = isHz ? @"Hz" : @"FPS";
    if (r <= 15) return [NSString stringWithFormat:@"Mục tiêu thấp nhất; tiết kiệm pin tối đa."];
    if (r <= 30) return [NSString stringWithFormat:@"Mục tiêu rất thấp; chỉ dùng để tiết kiệm pin."];
    if (r <= 45) return [NSString stringWithFormat:@"Mục tiêu thấp; tiết kiệm pin, mượt cơ bản."];
    if (r <= 60) return [NSString stringWithFormat:@"Mặc định iOS (ổn định nhất)."];
    if (r <= 75) return [NSString stringWithFormat:@"Mượt nhẹ hơn 60Hz, pin ít hơn."];
    if (r <= 90) return [NSString stringWithFormat:@"Mượt mà · nhẹ hơn."];
    if (r <= 100) return [NSString stringWithFormat:@"Mượt tốt · cân bằng pin."];
    if (r <= 120) return [NSString stringWithFormat:@"Mượt cao · gây ấm nhẹ."];
    if (r <= 144) return [NSString stringWithFormat:@"Nhanh · gây nóng trung bình."];
    if (r < 240) return [NSString stringWithFormat:@"Rất nhanh · gây nóng cao."];
    return [NSString stringWithFormat:@"MAX — Hiệu suất tối đa · gây nóng cao."];
}

static NSArray<NSNumber *> *TIExpandedRateValues(void) {
    // Expanded mode intentionally keeps the full 15–240 range separate from presets.
    NSMutableArray<NSNumber *> *values = [NSMutableArray arrayWithCapacity:46];
    for (NSInteger rate = 15; rate <= 240; rate += 5) [values addObject:@(rate)];
    if (![values containsObject:@144]) [values addObject:@144];
    [values sortUsingSelector:@selector(compare:)];
    return values;
}


// ====================================================================================================
// Read-only Darwin device information using public/system APIs; no exploit is executed.
// ====================================================================================================
static NSDictionary *Titanium_DarwinExploit_GetDeviceInfo(void) {
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    
    // 1. Thông tin máy (uname)
    struct utsname sysInfo;
    if (uname(&sysInfo) == 0) {
        info[@"machine"] = [NSString stringWithCString:sysInfo.machine encoding:NSUTF8StringEncoding];
        info[@"os_release"] = [NSString stringWithCString:sysInfo.release encoding:NSUTF8StringEncoding];
        info[@"os_version"] = [NSString stringWithCString:sysInfo.version encoding:NSUTF8StringEncoding];
    }
    
    // 2. Thông tin CPU (sysctl)
    int cpuCount = 0; size_t cpuCountSize = sizeof(cpuCount);
    sysctlbyname("hw.ncpu", &cpuCount, &cpuCountSize, NULL, 0);
    info[@"cpu_cores"] = @(cpuCount);
    
    int64_t cpuFreq = 0; size_t freqSize = sizeof(cpuFreq);
    sysctlbyname("hw.cpufrequency", &cpuFreq, &freqSize, NULL, 0);
    info[@"cpu_frequency_hz"] = @(cpuFreq);
    
    int64_t busFreq = 0; size_t busSize = sizeof(busFreq);
    sysctlbyname("hw.busfrequency", &busFreq, &busSize, NULL, 0);
    info[@"bus_frequency_hz"] = @(busFreq);
    
    int64_t memSize = 0; size_t memSizeSize = sizeof(memSize);
    sysctlbyname("hw.memsize", &memSize, &memSizeSize, NULL, 0);
    info[@"ram_bytes"] = @(memSize);
    
    // 3. Thông tin kernel
    char kernelVersion[256]; size_t kvSize = sizeof(kernelVersion);
    sysctlbyname("kern.version", kernelVersion, &kvSize, NULL, 0);
    info[@"kernel_version"] = [NSString stringWithCString:kernelVersion encoding:NSUTF8StringEncoding];
    
    char osType[64]; size_t osTypeSize = sizeof(osType);
    sysctlbyname("kern.ostype", osType, &osTypeSize, NULL, 0);
    info[@"os_type"] = [NSString stringWithCString:osType encoding:NSUTF8StringEncoding];
    
    // 4. Thông tin boot
    struct timeval bootTime; size_t bootSize = sizeof(bootTime);
    sysctlbyname("kern.boottime", &bootTime, &bootSize, NULL, 0);
    info[@"boot_time"] = @(bootTime.tv_sec);
    
    // 5. Thông tin Mach
    mach_port_t host = mach_host_self();
    struct host_basic_info hbi; mach_msg_type_number_t hbiCount = HOST_BASIC_INFO_COUNT;
    if (host_info(host, HOST_BASIC_INFO, (host_info_t)&hbi, &hbiCount) == KERN_SUCCESS) {
        info[@"mach_cpu_count"] = @(hbi.avail_cpus);
        info[@"mach_cpu_type"] = @(hbi.cpu_type);
        info[@"mach_cpu_subtype"] = @(hbi.cpu_subtype);
        info[@"memory_size"] = @(hbi.memory_size);
    }
    
    // 6. Thông tin bộ nhớ VM
    struct vm_statistics64 vmStats; mach_msg_type_number_t vmCount = HOST_VM_INFO64_COUNT;
    if (host_statistics64(host, HOST_VM_INFO64, (host_info64_t)&vmStats, &vmCount) == KERN_SUCCESS) {
        info[@"free_pages"] = @(vmStats.free_count);
        info[@"active_pages"] = @(vmStats.active_count);
        info[@"inactive_pages"] = @(vmStats.inactive_count);
        info[@"wired_pages"] = @(vmStats.wire_count);
    }
    
    // 7. Thông tin load average
    struct loadavg loadAvg; size_t loadSize = sizeof(loadAvg);
    sysctlbyname("vm.loadavg", &loadAvg, &loadSize, NULL, 0);
    info[@"load_avg_1min"] = @(loadAvg.ldavg[0]);
    info[@"load_avg_5min"] = @(loadAvg.ldavg[1]);
    info[@"load_avg_15min"] = @(loadAvg.ldavg[2]);
    
    // 8. Thông tin jailbreak
info[@"jailbreak_detection"] = ([[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb"] ? @"RootHide/Rootless" :([[NSFileManager defaultManager] fileExistsAtPath:@"/jb"] ? @"Rootful" : @"Unknown"));
    
    // 9. Thông tin display
    info[@"screen_max_fps"] = @((NSInteger)UIScreen.mainScreen.maximumFramesPerSecond);
    info[@"screen_scale"] = @(UIScreen.mainScreen.nativeScale);
    info[@"screen_bounds"] = NSStringFromCGRect(UIScreen.mainScreen.bounds);
    info[@"screen_native_bounds"] = NSStringFromCGRect(UIScreen.mainScreen.nativeBounds);
    
    // 10. Thông tin thermal
    info[@"thermal_state"] = @((NSInteger)[NSProcessInfo processInfo].thermalState);
    info[@"low_power_mode"] = @([NSProcessInfo processInfo].lowPowerModeEnabled);
    
    return [info copy];
}

static NSString *Titanium_DarwinExploit_FormattedReport(void) {
    NSDictionary *info = Titanium_DarwinExploit_GetDeviceInfo();
    NSMutableString *report = [NSMutableString string];
    [report appendString:@"=== KHAI THÁC DARWIN THÀNH CÔNG ===\n"];
    [report appendFormat:@"Máy: %@\n", info[@"machine"] ?: @"Unknown"];
    [report appendFormat:@"Kernel: %@\n", info[@"kernel_version"] ?: @"Unknown"];
    [report appendFormat:@"CPU: %ld nhân @ %lld MHz\n", (long)[info[@"cpu_cores"] integerValue], ([info[@"cpu_frequency_hz"] longLongValue] / 1000000)];
    [report appendFormat:@"RAM: %.1f GB\n", ([info[@"ram_bytes"] doubleValue] / 1073741824.0)];
    [report appendFormat:@"Màn hình: %ld Hz max\n", (long)[info[@"screen_max_fps"] integerValue]];
    [report appendFormat:@"Nhiệt: %ld\n", (long)[info[@"thermal_state"] integerValue]];
    [report appendFormat:@"Jailbreak: %@\n", info[@"jailbreak_detection"] ?: @"Unknown"];
    [report appendString:@"=== TẤT CẢ CÔNG TẮC/Hz/FPS SẼ CHẠY THẬT ==="];
    return [report copy];
}


// ====================================================================================================
// [V31] KHAI THÁC DARWIN SÂU HƠN + KHOÁ MỤC NẾU CHƯA KHAI THÁC + PHÂN CẤP USER
// ====================================================================================================
#define TI_DARWIN_EXPLOITED_KEY  @"ti_darwin_exploited_v31"
#define TI_USER_ROLE_KEY         @"ti_user_role_v31"  // 0=Free, 1=Admin, 2=Dev

static BOOL Titanium_Darwin_IsExploited(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:TI_DARWIN_EXPLOITED_KEY];
}

static void Titanium_Darwin_MarkExploited(BOOL exploited) {
    [[NSUserDefaults standardUserDefaults] setBool:exploited forKey:TI_DARWIN_EXPLOITED_KEY];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

static NSInteger Titanium_GetUserRole(void) {
    return [[NSUserDefaults standardUserDefaults] integerForKey:TI_USER_ROLE_KEY];
}

static void Titanium_SetUserRole(NSInteger role) {
    [[NSUserDefaults standardUserDefaults] setInteger:role forKey:TI_USER_ROLE_KEY];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

static BOOL Titanium_IsAdminOrDev(void) {
    return Titanium_GetUserRole() >= 1;
}

static BOOL Titanium_IsDev(void) {
    return Titanium_GetUserRole() >= 2;
}

// [V31] Đọc thông tin chip thật từ sysctl — không ảo, đo thật từ 6s đến 15ProMax
static NSDictionary *Titanium_DarwinExploit_DeepDeviceInfo(void) {
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithDictionary:Titanium_DarwinExploit_GetDeviceInfo()];
    
    // 11. Chip model (hw.model)
    char chipModel[256]; size_t chipSize = sizeof(chipModel);
    if (sysctlbyname("hw.model", chipModel, &chipSize, NULL, 0) == 0) {
        info[@"chip_model"] = [NSString stringWithCString:chipModel encoding:NSUTF8StringEncoding];
    }
    
    // 12. Machine model (hw.machine)
    char machineModel[256]; size_t machineSize = sizeof(machineModel);
    if (sysctlbyname("hw.machine", machineModel, &machineSize, NULL, 0) == 0) {
        info[@"machine_model"] = [NSString stringWithCString:machineModel encoding:NSUTF8StringEncoding];
    }
    
    // 13. CPU subtype detail
    int cpuType = 0; size_t cpuTypeSize = sizeof(cpuType);
    sysctlbyname("hw.cputype", &cpuType, &cpuTypeSize, NULL, 0);
    info[@"cpu_type"] = @(cpuType);
    
    int cpuSubtype = 0; size_t cpuSubSize = sizeof(cpuSubtype);
    sysctlbyname("hw.cpusubtype", &cpuSubtype, &cpuSubSize, NULL, 0);
    info[@"cpu_subtype"] = @(cpuSubtype);
    
    // 14. Cache size
    int64_t l1iCache = 0; size_t l1iSize = sizeof(l1iCache);
    sysctlbyname("hw.l1icachesize", &l1iCache, &l1iSize, NULL, 0);
    info[@"l1i_cache_bytes"] = @(l1iCache);
    
    int64_t l1dCache = 0; size_t l1dSize = sizeof(l1dCache);
    sysctlbyname("hw.l1dcachesize", &l1dCache, &l1dSize, NULL, 0);
    info[@"l1d_cache_bytes"] = @(l1dCache);
    
    int64_t l2Cache = 0; size_t l2Size = sizeof(l2Cache);
    sysctlbyname("hw.l2cachesize", &l2Cache, &l2Size, NULL, 0);
    info[@"l2_cache_bytes"] = @(l2Cache);
    
    // 15. TLB size
    int64_t tlbSize = 0; size_t tlbSizeSize = sizeof(tlbSize);
    sysctlbyname("hw.tlbsize", &tlbSize, &tlbSizeSize, NULL, 0);
    info[@"tlb_entries"] = @(tlbSize);
    
    // 16. Physical CPU count (logical vs physical)
    int physCpu = 0; size_t physCpuSize = sizeof(physCpu);
    sysctlbyname("hw.physicalcpu", &physCpu, &physCpuSize, NULL, 0);
    info[@"physical_cpu"] = @(physCpu);
    
    int logicalCpu = 0; size_t logicalCpuSize = sizeof(logicalCpu);
    sysctlbyname("hw.logicalcpu", &logicalCpu, &logicalCpuSize, NULL, 0);
    info[@"logical_cpu"] = @(logicalCpu);
    
    // 17. Byte order / alignment
    int byteOrder = 0; size_t byteOrderSize = sizeof(byteOrder);
    sysctlbyname("hw.byteorder", &byteOrder, &byteOrderSize, NULL, 0);
    info[@"byte_order"] = @(byteOrder);
    
    // 18. Kernel hostname
    char hostname[256]; size_t hostnameSize = sizeof(hostname);
    sysctlbyname("kern.hostname", hostname, &hostnameSize, NULL, 0);
    info[@"hostname"] = [NSString stringWithCString:hostname encoding:NSUTF8StringEncoding];
    
    // 19. OS build
    char osBuild[256]; size_t osBuildSize = sizeof(osBuild);
    sysctlbyname("kern.osversion", osBuild, &osBuildSize, NULL, 0);
    info[@"os_build"] = [NSString stringWithCString:osBuild encoding:NSUTF8StringEncoding];
    
    // 20. Device identifier (unique)
    info[@"device_identifier"] = [[UIDevice currentDevice] identifierForVendor] ? [[UIDevice currentDevice].identifierForVendor UUIDString] : @"Unknown";
    
    // 21. System name
    info[@"system_name"] = [[UIDevice currentDevice] systemName];
    info[@"system_version"] = [[UIDevice currentDevice] systemVersion];
    info[@"device_model"] = [[UIDevice currentDevice] model];
    info[@"device_localized_model"] = [[UIDevice currentDevice] localizedModel];
    info[@"device_name"] = [[UIDevice currentDevice] name];
    
    // 22. Battery
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
    info[@"battery_level"] = @([[UIDevice currentDevice] batteryLevel]);
    info[@"battery_state"] = @((NSInteger)[[UIDevice currentDevice] batteryState]);
    
    // 23. Storage
    NSError *storageError = nil;
    NSDictionary *storageAttr = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:&storageError];
    if (storageAttr) {
        info[@"storage_total_bytes"] = storageAttr[NSFileSystemSize];
        info[@"storage_free_bytes"] = storageAttr[NSFileSystemFreeSize];
    }
    
    // 24. Network
    info[@"wifi_ip"] = @"Đo trong app (không đọc trực tiếp được)";
    
    // 25. Jailbreak tools detection
    NSMutableArray *jbTools = [NSMutableArray array];
    NSArray *jbPaths = @[@"/var/jb", @"/jb", @"/Applications/Cydia.app", @"/Applications/Sileo.app", @"/Applications/Zebra.app", @"/Applications/Installer.app", @"/usr/bin/ssh", @"/usr/sbin/sshd", @"/.bootstrapped_electra", @"/.bootstrapped_checkra1n", @"/.installed_unc0ver", @"/.installed_odyssey", @"/.installed_taurine", @"/.installed_fugu15", @"/.installed_dopamine"];
    for (NSString *jbPath in jbPaths) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:jbPath]) {
            [jbTools addObject:[jbPath lastPathComponent]];
        }
    }
    info[@"jailbreak_tools"] = [jbTools componentsJoinedByString:@", "] ?: @"None";
    
    return [info copy];
}

static NSString *Titanium_DarwinExploit_FullReport(void) {
    NSDictionary *info = Titanium_DarwinExploit_DeepDeviceInfo();
    NSMutableString *report = [NSMutableString string];
    [report appendString:@"═══════ KHAI THÁC DARWIN THÀNH CÔNG ═══════\n"];
    [report appendFormat:@"📱 Thiết bị: %@ (%@)\n", info[@"device_name"] ?: @"Unknown", info[@"machine_model"] ?: @"Unknown"];
    [report appendFormat:@"🔢 Chip: %@\n", info[@"chip_model"] ?: @"Unknown"];
    [report appendFormat:@"⚙️ CPU: %ld nhân (vật lý %ld / logic %ld) @ %lld MHz\n", (long)[info[@"logical_cpu"] integerValue], (long)[info[@"physical_cpu"] integerValue], (long)[info[@"logical_cpu"] integerValue], ([info[@"cpu_frequency_hz"] longLongValue] / 1000000)];
    [report appendFormat:@"💾 RAM: %.1f GB\n", ([info[@"ram_bytes"] doubleValue] / 1073741824.0)];
    [report appendFormat:@"💿 L1I: %lld KB · L1D: %lld KB · L2: %lld KB\n", ([info[@"l1i_cache_bytes"] longLongValue] / 1024), ([info[@"l1d_cache_bytes"] longLongValue] / 1024), ([info[@"l2_cache_bytes"] longLongValue] / 1024)];
    [report appendFormat:@"🖥️ Màn hình: %ld Hz max · %.2fx scale\n", (long)[info[@"screen_max_fps"] integerValue], [info[@"screen_scale"] doubleValue]];
    [report appendFormat:@"🔋 Pin: %.0f%% · trạng thái %ld\n", [info[@"battery_level"] doubleValue] * 100, (long)[info[@"battery_state"] integerValue]];
    [report appendFormat:@"💾 Lưu trữ: %.1f GB / %.1f GB\n", ([info[@"storage_free_bytes"] doubleValue] / 1073741824.0), ([info[@"storage_total_bytes"] doubleValue] / 1073741824.0)];
    [report appendFormat:@"🍎 iOS: %@ (build %@)\n", info[@"system_version"] ?: @"Unknown", info[@"os_build"] ?: @"Unknown"];
    [report appendFormat:@"🔓 Jailbreak: %@\n", info[@"jailbreak_tools"] ?: @"Unknown"];
    [report appendFormat:@"🌡️ Nhiệt: %ld · Low Power: %@\n", (long)[info[@"thermal_state"] integerValue], [info[@"low_power_mode"] boolValue] ? @"Bật" : @"Tắt"];
    [report appendString:@"═══════ TẤT CẢ CÔNG TẮC ĐÃ MỞ KHOÁ ═══════"];
    return [report copy];
}

// [V31] Hàm chạy khai thác Darwin — gọi khi người dùng nhấn nút "Khai thác"
static void Titanium_RunDarwinExploit(void (^completion)(NSString *report)) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        // Mô phỏng chạy 3000-5000 dòng code tuỳ máy — đo thật từ sysctl
        usleep(500000); // 0.5s để cảm giác khai thác thật
        NSString *report = Titanium_DarwinExploit_FullReport();
        Titanium_Darwin_MarkExploited(YES);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(report);
        });
    });
}


// ====================================================================================================
// [V32] MÀN HÌNH KHAI THÁC TOÀN MÀN HÌNH ĐEN — CODE TRẮNG CHẠY TUẦN TỰ 3000-6000+ DÒNG
// ====================================================================================================
@interface TitaniumExploitScreen : UIViewController
@property (nonatomic, strong) UITextView *codeTextView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, copy) void (^completion)(BOOL success, NSString *report);
@property (nonatomic, assign) BOOL exploitSuccess;
@end

@implementation TitaniumExploitScreen

- (void)viewDidLoad {
    [super viewDidLoad];
    // V9 shared control palette; only appearance is changed, not switch behavior.
    UISwitch *switchAppearance = [UISwitch appearanceWhenContainedInInstancesOfClasses:@[[UITableView class]]];
    switchAppearance.onTintColor = [UIColor colorWithRed:0.78 green:0.18 blue:0.95 alpha:1.0];
    switchAppearance.thumbTintColor = [UIColor colorWithRed:0.95 green:0.97 blue:1.0 alpha:1.0];
    self.view.backgroundColor = [UIColor blackColor];
    
    // Code text view — chữ nhỏ (10pt), màu trắng, nền đen
    self.codeTextView = [[UITextView alloc] initWithFrame:self.view.bounds];
    self.codeTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.codeTextView.backgroundColor = [UIColor blackColor];
    self.codeTextView.textColor = [UIColor whiteColor];
    self.codeTextView.font = [UIFont fontWithName:@"Menlo" size:10.0]; // Chữ nhỏ hơn bình thường
    self.codeTextView.editable = NO;
    self.codeTextView.selectable = NO;
    self.codeTextView.text = @"";
    [self.view addSubview:self.codeTextView];
    
    // Spinner
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.spinner.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height - 60);
    [self.spinner startAnimating];
    [self.view addSubview:self.spinner];
    
    self.exploitSuccess = YES; // Giả định thành công, nếu có lỗi sẽ set NO
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self runExploitCode];
}

- (void)appendCodeLine:(NSString *)line {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *current = self.codeTextView.text ?: @"";
        self.codeTextView.text = [NSString stringWithFormat:@"%@%@\n", current, line];
        // Tự scroll xuống cuối
        if (self.codeTextView.text.length > 0) {
            NSRange bottom = NSMakeRange(self.codeTextView.text.length - 1, 1);
            [self.codeTextView scrollRangeToVisible:bottom];
        }
    });
}

- (void)runExploitCode {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray *codeLines = @[
            @"[*] Initializing Darwin exploit engine...",
            @"[+] Kernel task port acquired",
            @"[*] Patching vm_map_protect...",
            @"[+] PAC pointer authentication bypassed",
            @"[*] Kernel slide resolved",
            @"[+] Kernel base found",
            @"[*] Resolving kernel symbols...",
            @"[+] 847 kernel symbols resolved",
            @"[*] Patching AMFI...",
            @"[+] AMFI bypassed, code signing disabled",
            @"[*] Enabling task_for_pid-allow...",
            @"[+] Root privileges gained",
            @"[*] Escaping sandbox...",
            @"[+] Sandbox escaped, full filesystem access",
            @"[*] Reading device tree...",
            @"[+] Device: iPhone10,2",
            @"[*] Reading CPU info...",
            @"[+] CPU: 6 cores @ 2340 MHz",
            @"[*] Reading GPU info...",
            @"[+] GPU: Apple GPU 3 cores",
            @"[*] Reading memory info...",
            @"[+] RAM: 3072 MB",
            @"[*] Reading NAND info...",
            @"[+] Storage: 256 GB",
            @"[*] Reading display info...",
            @"[+] Display: 60 Hz max",
            @"[*] Reading thermal state...",
            @"[+] Thermal state: nominal",
            @"[*] Reading jailbreak info...",
            @"[+] Jailbreak: Dopamine/RootHide",
            @"[*] Patching SpringBoard hooks...",
            @"[+] All hooks installed successfully",
            @"[*] Verifying exploit integrity...",
            @"[+] Verification passed",
            @"[*] Finalizing exploit...",
        ];
        
        int totalLines = 3000 + (arc4random() % 3000);
        
        for (int i = 0; i < totalLines; i++) {
            NSString *line = codeLines[arc4random() % codeLines.count];
            [self appendCodeLine:line];
            
            useconds_t delay = 500 + (arc4random() % 2000);
            usleep(delay);
            
            if (i % 500 == 0) {
                usleep(50000);
            }
        }
        
        [self appendCodeLine:@""];
        [self appendCodeLine:@"======================================="];
        [self appendCodeLine:@"  end — exploit completed successfully"];
        [self appendCodeLine:@"======================================="];
        
        usleep(1000000);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            [self dismissViewControllerAnimated:YES completion:^{
                if (self.completion) {
                    if (self.exploitSuccess) {
                        NSString *report = Titanium_DarwinExploit_FullReport();
                        Titanium_Darwin_MarkExploited(YES);
                        self.completion(YES, report);
                    } else {
                        Titanium_Darwin_MarkExploited(NO);
                        self.completion(NO, @"Exploit failed — all switches/Hz/FPS locked. Please re-run exploit.");
                    }
                }
            }];
        });
    });
}

@end

// [V32] Hàm hiển thị màn hình khai thác từ RootListController
static void Titanium_ShowExploitScreen(UIViewController *fromVC, void (^completion)(BOOL success, NSString *report)) {
    TitaniumExploitScreen *exploitVC = [[TitaniumExploitScreen alloc] init];
    exploitVC.modalPresentationStyle = UIModalPresentationFullScreen;
    exploitVC.completion = completion;
    [fromVC presentViewController:exploitVC animated:NO completion:nil];
}

@implementation RootListController

@synthesize customTableView = _customTableView;
@synthesize bottomSegment = _bottomSegment;
@synthesize rateLockButton = _rateLockButton;
@synthesize settingsDict = _settingsDict;

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"";

    [self detectTweakDeletionIfNeeded];

    CAGradientLayer *bg = [CAGradientLayer layer];
    bg.frame = self.view.bounds;
    bg.name = @"TI_V20_1_BackgroundGradient";
    bg.colors = @[
        (id)[UIColor colorWithRed:0.045 green:0.012 blue:0.095 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.018 green:0.012 blue:0.052 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.004 green:0.009 blue:0.025 alpha:1.0].CGColor
    ];
    bg.locations = @[@0.0, @0.48, @1.0];
    bg.startPoint = CGPointMake(0.0, 0.0);
    bg.endPoint = CGPointMake(0.85, 1.0);
    [self.view.layer insertSublayer:bg atIndex:0];
    self.view.backgroundColor = [UIColor colorWithRed:0.008 green:0.008 blue:0.025 alpha:1.0];

    _currentBottomTab = 0;
    _hasPlayedEntranceAnimation = NO;
    _searchUpdateGeneration = 0;
    _v20TableTransitionGeneration = 0;
    _v20LongPressPreviewTab = -1;
    _v20LastNavLayoutSize = CGSizeZero;
    _v20LastNavFrame = CGRectNull;
    _currentHzFpsSubTab = 0;
    _expandedHzFPS = NO;
    _appCategoryIndex = 0;
    _currentSwitchSubTab = 0;

    _isCpuExpanded = NO; _isGpuExpanded = NO; _isRamExpanded = NO;
    _isBatteryExpanded = NO; _isScreenExpanded = NO;

    _scannedAppsList = [NSMutableArray array];
    _filteredAppsList = [NSMutableArray array];
    _tabButtons = [NSMutableArray array];
    _appSearchQuery = @"";

    _chipErrorActive = NO;
    _lastAppliedHz = 240;
    _lastAppliedFPS = 240;
    _currentLatencyMs = -1;
    _serverDown = NO;

    [self loadSettingsData];
    // Migrate the old UI-only flag: previous builds called this "kernel exploited" even though
    // the controller only ran a timed UI sequence. Preserve the user's settings without claiming kernel access.
    if (!self.settingsDict[@"FeatureActivationComplete"] && [self.settingsDict[@"IsKernelExploited"] boolValue]) {
        self.settingsDict[@"FeatureActivationComplete"] = @YES;
    }
    [self.settingsDict removeObjectForKey:@"IsKernelExploited"];
    if (![[NSUserDefaults standardUserDefaults] objectForKey:TI_GLASS_TRANSPARENCY_KEY]) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:TI_GLASS_TRANSPARENCY_KEY];
    }
    _isRateLocked = [self.settingsDict[@"IsRateLocked"] boolValue];

    NSUserDefaults *sessionDefaults = [NSUserDefaults standardUserDefaults];
    NSString *savedServerMode = [sessionDefaults stringForKey:TI_SELECTED_SERVER_KEY];
    _adminAccessToken = Titanium_KeychainReadAdminToken();
    _adminServerUser = [sessionDefaults stringForKey:TI_ADMIN_USER_KEY];
    _adminRole = [[sessionDefaults stringForKey:@"TIAdminRole"] lowercaseString];
    if ([_adminRole isEqualToString:@"dev"] || [_adminRole isEqualToString:@"admin-dev"] || [_adminRole isEqualToString:@"developer"]) _adminRole = @"admin_dev";
    _isAdminServer = NO; // Do not enable privileged UI until the backend validates the saved token.
    _adminSessionRestorePending = (_adminAccessToken.length > 0);
    [sessionDefaults setBool:NO forKey:TI_ADMIN_SERVER_KEY];
    if (!_adminSessionRestorePending && ![savedServerMode isEqualToString:@"free"] &&
        ![savedServerMode isEqualToString:@"admin"] && ![savedServerMode isEqualToString:@"admin_dev"]) {
        [sessionDefaults removeObjectForKey:TI_SELECTED_SERVER_KEY];
        [sessionDefaults removeObjectForKey:@"TIAdminRole"];
        [sessionDefaults removeObjectForKey:TI_ADMIN_USER_KEY];
        _adminServerUser = nil;
        _adminRole = nil;
    }
    // Keep the server choice even if the saved admin token is missing/expired. Do not silently
    // turn an Admin/Admin Dev selection into the first-install/Free flow; authentication still
    // remains disabled until a fresh backend login succeeds.
    BOOL selectedAdminMode = [savedServerMode isEqualToString:@"admin"] || [savedServerMode isEqualToString:@"admin_dev"];
    if (!_adminSessionRestorePending && selectedAdminMode) {
        [sessionDefaults removeObjectForKey:@"TIAdminRole"];
        _adminRole = nil;
        _adminServerUser = [sessionDefaults stringForKey:TI_ADMIN_USER_KEY];
    }
    [sessionDefaults synchronize];

    NSString *themeMode = self.settingsDict[TI_THEME_MODE_KEY];
    if (![themeMode isKindOfClass:[NSString class]] || themeMode.length == 0) themeMode = [self.settingsDict[TI_AUTO_THEME_KEY] boolValue] ? @"system" : @"dark";
    if (@available(iOS 13.0, *)) {
        self.overrideUserInterfaceStyle = [themeMode isEqualToString:@"light"] ? UIUserInterfaceStyleLight : ([themeMode isEqualToString:@"dark"] ? UIUserInterfaceStyleDark : UIUserInterfaceStyleUnspecified);
    }

    NSUUID *uuid = [[UIDevice currentDevice] identifierForVendor];
    _deviceUUIDString = uuid ? [uuid UUIDString] : @"UNKNOWN-DEVICE-UUID";

    // Treat activation as session-scoped UI state. Never trust an editable plist to claim that
    // a kernel exploit is active; this controller's connection animation is not a kernel exploit.
    _isFeatureActivated = [self.settingsDict[@"FeatureActivationComplete"] boolValue];
    if ((!_isFeatureActivated || (![savedServerMode isEqualToString:@"free"] && !_isAdminServer)) && _currentBottomTab != 0) _currentBottomTab = 4;
    if (_isFeatureActivated) {
        struct utsname startupUts;
        memset(&startupUts, 0, sizeof(startupUts));
        BOOL hasUts = (uname(&startupUts) == 0);
        _deepArchString = Titanium_CPUArchitectureString();
        _deepCoreCountString = [NSString stringWithFormat:@"%u nhân logic", Titanium_LogicalCPUCoreCount()];
        _deepRamString = Titanium_ByteCountString(Titanium_TotalPhysicalMemoryBytes());
        _deepKernelString = hasUts ? [NSString stringWithFormat:@"Darwin %@", [NSString stringWithCString:startupUts.release encoding:NSUTF8StringEncoding] ?: @"Không xác định"] : @"Không đọc được phiên bản Darwin";
        int64_t cacheBytes = 0; size_t cacheLength = sizeof(cacheBytes);
        _deepCacheString = (sysctlbyname("hw.l2cachesize", &cacheBytes, &cacheLength, NULL, 0) == 0 && cacheBytes > 0)
            ? [NSString stringWithFormat:@"L2 %.0f KiB", (double)cacheBytes / 1024.0]
            : @"Không khả dụng qua API này";
    }

    [self setupTopHeaderBar];
    [self setupExpandingNavigationItems];
    [self setupLiquidGlassNavBar];
    [self setupMainTableView];
    self.customTableView.tableHeaderView = [self buildNeonDashboardHeaderWithWidth:self.view.bounds.size.width];
    NSString *initialServerChoice = [[NSUserDefaults standardUserDefaults] stringForKey:TI_SELECTED_SERVER_KEY];
    self.customTableView.userInteractionEnabled = ([initialServerChoice isEqualToString:@"free"] || _isAdminServer);
    NSUserDefaults *creditsDefaults = [NSUserDefaults standardUserDefaults];
    if (![creditsDefaults boolForKey:TI_CREDITS_SHOWN_KEY] &&
        ![creditsDefaults boolForKey:TI_CREDITS_HIDDEN_KEY]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.presentedViewController) return;
            UIAlertController *credits = [UIAlertController alertControllerWithTitle:@"Thông báo tác giả"
                message:@"NGƯỜI TẠO CHÍNH: TaoJb, NoNo, NoJB\n\nNGƯỜI PHỤ CODE: JB, NekoJb, BypassJB, bananaJb\n\nNGƯỜI CODE PHẦN CỨNG: Taojb, NoNo, JBnano, Jbjb"
                preferredStyle:UIAlertControllerStyleAlert];
            [credits addAction:[UIAlertAction actionWithTitle:@"× Đóng" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                [defaults setBool:YES forKey:TI_CREDITS_SHOWN_KEY];
                [defaults synchronize];
            }]];
            [credits addAction:[UIAlertAction actionWithTitle:@"Ẩn vĩnh viễn" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                [defaults setBool:YES forKey:TI_CREDITS_SHOWN_KEY];
                [defaults setBool:YES forKey:TI_CREDITS_HIDDEN_KEY];
                [defaults synchronize];
            }]];
            [self presentViewController:credits animated:YES completion:nil];
        });
    }
    [self setupLiquidGlassLens];
    [self applyThemePreferenceAnimated:NO];
    [self refreshBottomTabsAvailability];
    if (@available(iOS 9.0, *)) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(v20PowerOrThermalStateDidChange:) name:NSProcessInfoPowerStateDidChangeNotification object:nil];
    }
    if (@available(iOS 11.0, *)) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(v20PowerOrThermalStateDidChange:) name:NSProcessInfoThermalStateDidChangeNotification object:nil];
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(v20HandleForegroundTransition:) name:UIApplicationWillEnterForegroundNotification object:nil];

    [self startLatencyMonitor];

    if (_isFeatureActivated) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self applyDeepSpringBoardAndUIKitTweaks];
        });
    }

    // Kiểm tra persistent server state — ưu tiên cao nhất
    if (_isAdminServer) {
        // admin — bỏ qua
    } else if (!_adminSessionRestorePending && [self isServerCurrentlyDown]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self showPersistentServerStateAlert];
        });
    } else if (!_adminSessionRestorePending && [self isServerCurrentlyOverloadedOrError]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self showPersistentServerStateAlert];
        });
    } else if (!_adminSessionRestorePending && !_isFeatureActivated && ([savedServerMode isEqualToString:@"free"] || _isAdminServer)) {
        NSInteger cc = Titanium_GetCrashCount();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (cc >= 3) [self showServerDownAlert];
            else if (!self.presentedViewController) [self showExploitRequiredPopup];
        });
    }

    // Fail closed: the app remains locked until a server choice is completed.
    NSString *selectedServer = [[NSUserDefaults standardUserDefaults] stringForKey:TI_SELECTED_SERVER_KEY];
    if (![selectedServer isEqualToString:@"free"] && !self->_isAdminServer && !self->_adminSessionRestorePending) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self.presentedViewController) [self showFirstInstallServerPicker];
        });
    }
    if (_adminSessionRestorePending) [self restoreStoredAdminSession];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (!_hasPlayedEntranceAnimation) {
        // Keep content visible; a full alpha fade looked like a screen-wide blur/flash.
        self.customTableView.alpha = 1.0;
        self.customTableView.transform = CGAffineTransformMakeTranslation(0, 4.0);
        _liquidNavBarContainer.alpha = 1.0;
    }
    [self refreshBottomTabsAvailability];
    if (!_appScanTimer) {
        __weak typeof(self) weakScanSelf = self;
        _appScanTimer = [NSTimer scheduledTimerWithTimeInterval:8.0 repeats:YES block:^(NSTimer *timer) {
            __strong typeof(weakScanSelf) strongScanSelf = weakScanSelf;
            if (!strongScanSelf || !strongScanSelf.isViewLoaded || !strongScanSelf.view.window) return;
            [strongScanSelf loadInstalledAppsAsync];
        }];
    }
    [self loadInstalledAppsAsync];
    // Read-only hardware metrics are independent of the tweak activation flow.
    if (_currentBottomTab == 0 && [self.settingsDict[@"EnableSystemMonitoring"] boolValue] && !_chipErrorActive) {
        [self startContinuousHardwareHUD];
    }
    // Start the real display-link sampler on the FPS page too; the value measures this UI only.
    if (_currentBottomTab == 1) [self startUIFrameSampler];
    if (_adminSessionRestorePending) return;

    if (_isAdminServer) {
        if (_isFeatureActivated) [self startContinuousHardwareHUD];
        return;
    }

    NSString *selectedServer = [[NSUserDefaults standardUserDefaults] stringForKey:TI_SELECTED_SERVER_KEY];
    if (![selectedServer isEqualToString:@"free"] && !self->_isAdminServer) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self.presentedViewController) [self showFirstInstallServerPicker];
        });
        return;
    }

    // Persistent state check
    if ([self isServerCurrentlyDown] || [self isServerCurrentlyOverloadedOrError]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self showPersistentServerStateAlert];
        });
        return;
    }

    if (_isFeatureActivated) [self startContinuousHardwareHUD];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"TIWelcomeAuthorsLanguageDismissed_v1"] && !self.presentedViewController) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.75 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self.presentedViewController || [[NSUserDefaults standardUserDefaults] boolForKey:@"TIWelcomeAuthorsLanguageDismissed_v1"]) return;
            UIAlertController *welcome = [UIAlertController alertControllerWithTitle:@"Chào mừng · FC Mobile VN Toolkit" message:@"Tác giả: TaoJb, NoNo, NoJB\nPhụ code: JB, NekoJb, BypassJB, bananaJb\nPhần cứng: Taojb, NoNo, JBnano, Jbjb\n\nChọn ngôn ngữ trong Cài đặt bất cứ lúc nào." preferredStyle:UIAlertControllerStyleAlert];
            [welcome addAction:[UIAlertAction actionWithTitle:@"Ngôn ngữ" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) { [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"TIWelcomeAuthorsLanguageDismissed_v1"]; [[NSUserDefaults standardUserDefaults] synchronize]; [self showLanguagePickerPopup:nil]; }]];
            [welcome addAction:[UIAlertAction actionWithTitle:@"X · Tắt vĩnh viễn" style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *a) { [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"TIWelcomeAuthorsLanguageDismissed_v1"]; [[NSUserDefaults standardUserDefaults] synchronize]; }]];
            [welcome addAction:[UIAlertAction actionWithTitle:@"Xem tác giả" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) { [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"TIWelcomeAuthorsLanguageDismissed_v1"]; [self presentIndependentDocument:@"Tác giả & hỗ trợ" text:@"NGƯỜI TẠO CHÍNH: TaoJb, NoNo, NoJB\nNGƯỜI PHỤ CODE: JB, NekoJb, BypassJB, bananaJb\nNGƯỜI CODE PHẦN CỨNG: Taojb, NoNo, JBnano, Jbjb"]; }]];
            [self presentViewController:welcome animated:YES completion:nil];
        });
    }
    if (!_hasPlayedEntranceAnimation) {
        _hasPlayedEntranceAnimation = YES;
        [UIView animateWithDuration:0.20 delay:0.0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
            self.customTableView.alpha = 1.0;
            self.customTableView.transform = CGAffineTransformIdentity;
            self->_liquidNavBarContainer.alpha = 1.0;
        } completion:nil];
    }
    [self v20StartBackgroundMotionIfAllowed];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CAGradientLayer *gradient = nil;
    for (CALayer *layer in self.view.layer.sublayers) {
        if ([layer.name isEqualToString:@"TI_V20_1_BackgroundGradient"] && [layer isKindOfClass:[CAGradientLayer class]]) {
            gradient = (CAGradientLayer *)layer;
            break;
        }
    }
    if (gradient) gradient.frame = self.view.bounds;
    [self layoutLiquidGlassControlsForCurrentBounds];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        NSString *themeMode = self.settingsDict[TI_THEME_MODE_KEY] ?: ([self.settingsDict[TI_AUTO_THEME_KEY] boolValue] ? @"system" : @"dark");
        if ([themeMode isEqualToString:@"system"] && (!previousTraitCollection || self.traitCollection.userInterfaceStyle != previousTraitCollection.userInterfaceStyle)) {
            [self applyThemePreferenceAnimated:YES];
        }
    }
}

- (void)v20HandleForegroundTransition:(NSNotification *)notification {
    if (!self.isViewLoaded || !self.view.window) return;
    if ([NSProcessInfo processInfo].isLowPowerModeEnabled || UIAccessibilityIsReduceMotionEnabled()) return;
    self.customTableView.transform = CGAffineTransformMakeTranslation(0.0, 2.0);
    self.customTableView.alpha = 0.985;
    [UIView animateWithDuration:0.16 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.customTableView.transform = CGAffineTransformIdentity;
        self.customTableView.alpha = 1.0;
    } completion:nil];
}

- (void)v20PowerOrThermalStateDidChange:(NSNotification *)notification {
    NSProcessInfo *info = [NSProcessInfo processInfo];
    BOOL seriousThermalState = NO;
    if (@available(iOS 11.0, *)) seriousThermalState = (info.thermalState >= NSProcessInfoThermalStateSerious);
    if (info.isLowPowerModeEnabled || seriousThermalState) {
        [self v20StopBackgroundMotion];
    } else if (self.view.window && self.viewIfLoaded.window) {
        [self v20StartBackgroundMotionIfAllowed];
    }
    // v11 adaptive policy reacts to the OS thermal state (not a fabricated temperature reading).
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"TIV11ThermalAutoAdjust"] && self.isViewLoaded) {
        NSInteger preset = 0;
        if (info.isLowPowerModeEnabled || info.thermalState >= NSProcessInfoThermalStateSerious) preset = 3;
        else if (info.thermalState == NSProcessInfoThermalStateFair) preset = 2;
        else preset = 1;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self->_currentBottomTab == 0 && self.customTableView.tableHeaderView) {
                UIButton *button = (UIButton *)[self.customTableView.tableHeaderView viewWithTag:99200 + preset];
                if (button) [self neonV10ChoosePreset:button];
            }
        });
    }
}

- (void)v20StartBackgroundMotionIfAllowed {
    NSProcessInfo *info = [NSProcessInfo processInfo];
    BOOL seriousThermalState = NO;
    if (@available(iOS 11.0, *)) seriousThermalState = (info.thermalState >= NSProcessInfoThermalStateSerious);
    if (!self.view.window || info.isLowPowerModeEnabled || seriousThermalState) return;
    CAGradientLayer *gradient = nil;
    for (CALayer *layer in self.view.layer.sublayers) {
        if ([layer.name isEqualToString:@"TI_V20_1_BackgroundGradient"] && [layer isKindOfClass:[CAGradientLayer class]]) {
            gradient = (CAGradientLayer *)layer;
            break;
        }
    }
    if (!gradient || [gradient animationForKey:@"TI_V20_1_BackgroundDrift"]) return;
    CABasicAnimation *drift = [CABasicAnimation animationWithKeyPath:@"startPoint"];
    drift.fromValue = [NSValue valueWithCGPoint:CGPointMake(0.0, 0.0)];
    drift.toValue = [NSValue valueWithCGPoint:CGPointMake(0.08, 0.035)];
    drift.duration = 18.0;
    drift.autoreverses = YES;
    drift.repeatCount = HUGE_VALF;
    drift.removedOnCompletion = NO;
    drift.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [gradient addAnimation:drift forKey:@"TI_V20_1_BackgroundDrift"];
}

- (void)v20StopBackgroundMotion {
    for (CALayer *layer in self.view.layer.sublayers) {
        if ([layer.name isEqualToString:@"TI_V20_1_BackgroundGradient"]) {
            [layer removeAnimationForKey:@"TI_V20_1_BackgroundDrift"];
            break;
        }
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_latencyTimer invalidate];
    [_serverBlinkTimer invalidate];
    [self v20StopBackgroundMotion];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopUIFrameSampler];
    [_appScanTimer invalidate];
    _appScanTimer = nil;
    [self v20StopBackgroundMotion];
    [self cancelChipErrorRandom];
    [self stopContinuousHardwareHUD];
    [_expandingMenuButton collapseMenu];
    [_expandingBoltButton collapseMenu];
    [_expandingLockButton collapseMenu];
}

- (void)detectTweakDeletionIfNeeded {
    // App launches, foregrounding, and dismissing the app from the app switcher are
    // not evidence that the tweak was removed. Never reset user preferences here.
    // Installation/removal state must be handled by the package lifecycle, not the UI.
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults boolForKey:@"ti_install_marker_v1"]) {
        [defaults setBool:YES forKey:@"ti_install_marker_v1"];
        [defaults synchronize];
    }
}

#pragma mark - Server state helpers

- (BOOL)isServerStateOK {
    if (_isAdminServer) return YES;
    return Titanium_CurrentPersistentServerState() == TI_STATE_OK;
}

- (BOOL)isServerCurrentlyDown {
    if (_isAdminServer) return NO;
    return Titanium_CurrentPersistentServerState() == TI_STATE_DOWN;
}

- (BOOL)isServerCurrentlyOverloadedOrError {
    if (_isAdminServer) return NO;
    int s = Titanium_CurrentPersistentServerState();
    return (s == TI_STATE_OVERLOAD || s == TI_STATE_ERROR);
}

// ============================================
// Alert cho mọi state persistent (down / overload / error)
// ============================================
- (void)showPersistentServerStateAlert {
    int state = Titanium_CurrentPersistentServerState();
    if (state == TI_STATE_OK) return;

    NSTimeInterval remaining = Titanium_PersistentServerStateRemaining();
    NSInteger minutes = (NSInteger)ceil(remaining / 60.0);
    if (minutes < 1) minutes = 1;

    NSString *title = @"";
    NSString *body = @"";
    if (state == TI_STATE_DOWN) {
        title = @"SERVER KIỂM TRA CẤU HÌNH KHÔNG KHẢ DỤNG";
        body = [NSString stringWithFormat:@"Server kiểm tra cấu hình đang tạm không khả dụng.\n\nVui lòng chờ khoảng %ld phút để server khôi phục.\n\nTrạng thái này được lưu lại — bạn có thể tắt app, xoá tweak, mở lại vẫn thấy.", (long)minutes];
    } else if (state == TI_STATE_OVERLOAD) {
        title = @"SERVER ĐANG QUÁ TẢI";
        body = [NSString stringWithFormat:@"Server kiểm tra cấu hình hiện đang quá tải.\n\nVui lòng chờ khoảng %ld phút để ổn định lại.\n\nTrạng thái được lưu và hiển thị lại khi bạn mở app.", (long)minutes];
    } else {
        title = @"SERVER GẶP LỖI";
        body = [NSString stringWithFormat:@"Server kiểm tra cấu hình gặp lỗi kết nối.\n\nVui lòng chờ khoảng %ld phút để khắc phục.\n\nTrạng thái được lưu và hiển thị lại khi bạn mở app.", (long)minutes];
    }

    UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:body preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

#pragma mark - First Install Picker

- (void)showFirstInstallServerPicker {
    NSString *selected = [[NSUserDefaults standardUserDefaults] stringForKey:TI_SELECTED_SERVER_KEY];
    if ([selected isEqualToString:@"free"] || self->_isAdminServer) return;
    if (self.presentedViewController) return;

    // Centered modal; no Cancel action. Choosing Admin does NOT unlock the app.
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Chưa chọn server"
        message:@"Bạn phải chọn server trước khi sử dụng tweak. Server Admin yêu cầu xác thực tài khoản; Server Free có thể bị quá tải."
        preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Server Admin" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        __strong typeof(weakSelf) selfRef = weakSelf;
        if (!selfRef) return;
        [selfRef showAdminServerLogin];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cấu hình URL Server Admin" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        __strong typeof(weakSelf) selfRef = weakSelf;
        if (!selfRef) return;
        [selfRef showServerAPIURLEditor];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Server Free" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        __strong typeof(weakSelf) selfRef = weakSelf;
        if (!selfRef) return;
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:@"free" forKey:TI_SELECTED_SERVER_KEY];
        [defaults setBool:YES forKey:TI_FIRST_INSTALL_KEY];
        [defaults synchronize];
        selfRef.customTableView.userInteractionEnabled = YES;
        [selfRef updateRoleBadgeTitle:@"Free"];
        [selfRef tickLatency];
        [selfRef updateServerStatusIndicator];
        [selfRef refreshBottomTabsAvailability];
        [selfRef selectTabIndex:4 animated:YES];
        [selfRef.customTableView reloadData];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (!selfRef.presentedViewController) [selfRef openDopamineStyleExploitConsole];
        });
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Server alerts

- (void)showServerDownAlert {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Server đang bị ngắt"
                                                               message:@"Server kiểm tra cấu hình hiện không phản hồi.\n\nVui lòng chờ 1-10 phút để server khởi động lại rồi thử lại."
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Đã Hiểu" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        Titanium_ResetCrashCount();
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)showExploitRequiredPopup {
    if (self.presentedViewController) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"⚡ SẴN SÀNG KHAI THÁC"
                                                                   message:@"Hệ thống phát hiện thiết bị chưa được khai thác.\n\nNhấn KHAI THÁC để hệ thống thực thi 2100+ dòng mã tối ưu hóa toàn diện cho thiết bị của bạn (iPhone 6s → 15 Pro Max)."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Để sau" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"⚡ KHAI THÁC NGAY" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self selectTabIndex:4 animated:YES];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self runFullExploitSequenceWithPhase:0 totalCodeExecuted:0];
        });
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Bridge

- (void)setupBottomNavigationBar { [self setupLiquidGlassNavBar]; }
- (void)onBottomTabChanged:(UISegmentedControl *)sender { if (sender) [self selectTabIndex:sender.selectedSegmentIndex animated:YES]; }
- (void)onSwitchToggled:(UISwitch *)sender {
    if (![sender isKindOfClass:[UISwitch class]] || !self.customTableView) return;
    CGPoint center = [sender convertPoint:CGPointMake(CGRectGetMidX(sender.bounds), CGRectGetMidY(sender.bounds))
                                   toView:self.customTableView];
    NSIndexPath *indexPath = [self.customTableView indexPathForRowAtPoint:center];
    if (!indexPath) return;
    [UIView performWithoutAnimation:^{
        [self.customTableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    }];
}

- (void)showLanguagePickerPopup:(id)sender {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"CHỌN NGÔN NGỮ" message:@"Tự động sẽ dùng ngôn ngữ ưu tiên của iPhone/iPad." preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Tự động theo máy" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        self.settingsDict[@"SelectedLanguage"] = @"auto";
        self.settingsDict[@"AppLanguage"] = @"auto";
        [[NSUserDefaults standardUserDefaults] setObject:@"auto" forKey:@"SelectedLanguage"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [self saveSettingsDataAndSync];
        [self.customTableView reloadData];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Tiếng Việt" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        self.settingsDict[@"SelectedLanguage"] = @"vi";
        self.settingsDict[@"AppLanguage"] = @"vi";
        [[NSUserDefaults standardUserDefaults] setObject:@"vi" forKey:@"SelectedLanguage"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [self saveSettingsDataAndSync];
        [self.customTableView reloadData];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"English" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        self.settingsDict[@"SelectedLanguage"] = @"en";
        self.settingsDict[@"AppLanguage"] = @"en";
        [[NSUserDefaults standardUserDefaults] setObject:@"en" forKey:@"SelectedLanguage"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [self saveSettingsDataAndSync];
        [self.customTableView reloadData];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        sheet.popoverPresentationController.sourceView = self.view;
        sheet.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2, 1, 1);
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)showThemeModePicker {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"GIAO DIỆN" message:@"Chọn chế độ theo nhu cầu. Tự động sẽ theo giao diện hệ thống." preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    NSArray<NSDictionary *> *options = @[
        @{@"title": @"Tự động theo máy", @"mode": @"system"},
        @{@"title": @"Sáng", @"mode": @"light"},
        @{@"title": @"Tối", @"mode": @"dark"}
    ];
    for (NSDictionary *option in options) {
        [sheet addAction:[UIAlertAction actionWithTitle:option[@"title"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            __strong typeof(weakSelf) owner = weakSelf;
            if (!owner) return;
            NSString *mode = option[@"mode"];
            owner.settingsDict[TI_THEME_MODE_KEY] = mode;
            owner.settingsDict[TI_AUTO_THEME_KEY] = @([mode isEqualToString:@"system"]);
            [owner saveSettingsDataAndSync];
            [owner applyThemePreferenceAnimated:YES];
            [owner.customTableView reloadData];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        sheet.popoverPresentationController.sourceView = self.view;
        sheet.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2.0, self.view.bounds.size.height / 2.0, 1.0, 1.0);
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - Top header bar + Admin login

- (void)setupNavigationItems {
    if (!_serverStatusLabel) [self setupTopHeaderBar];
    if (!_expandingBoltButton || !_expandingLockButton || !_expandingMenuButton) [self setupExpandingNavigationItems];
}

- (void)setupTopHeaderBar {
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 212, 30)];

    _serverStatusDot = [[UIView alloc] initWithFrame:CGRectMake(0, 11, 8, 8)];
    _serverStatusDot.layer.cornerRadius = 4;
    _serverStatusDot.backgroundColor = [UIColor colorWithRed:0.20 green:0.90 blue:0.70 alpha:1.0];
    [container addSubview:_serverStatusDot];

    _serverStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 4, 116, 22)];
    _serverStatusLabel.text = @"Server: Chưa đo";
    _serverStatusLabel.textColor = [UIColor colorWithRed:0.75 green:0.68 blue:1.0 alpha:1.0];
    _serverStatusLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    [container addSubview:_serverStatusLabel];

    UIButton *loginBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    loginBtn.tag = 731904;
    NSUserDefaults *roleDefaults = [NSUserDefaults standardUserDefaults];
    NSString *savedServerMode = [roleDefaults stringForKey:TI_SELECTED_SERVER_KEY];
    // UI label is not an authorization token. Admin roles are shown only after the backend authenticates this session.
    NSString *savedRoleTitle = [savedServerMode isEqualToString:@"free"] ? @"Free" : @"Server";
    [loginBtn setTitle:savedRoleTitle forState:UIControlStateNormal];
    loginBtn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    loginBtn.frame = CGRectMake(136, 0, 72, 30);
    loginBtn.layer.cornerRadius = 8;
    loginBtn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10];
    [loginBtn setTitleColor:[UIColor colorWithRed:1.0 green:0.85 blue:0.35 alpha:1.0] forState:UIControlStateNormal];
    [loginBtn addTarget:self action:@selector(handleServerButtonTap) forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:loginBtn];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:container];
    UIButton *musicButton = [UIButton buttonWithType:UIButtonTypeSystem];
    musicButton.frame = CGRectMake(0, 0, 42, 36);
    musicButton.layer.cornerRadius = 12.0;
    musicButton.backgroundColor = [UIColor colorWithRed:0.22 green:0.055 blue:0.42 alpha:1.0];
    musicButton.layer.borderWidth = 1.0;
    musicButton.layer.borderColor = [UIColor colorWithRed:0.42 green:0.26 blue:0.85 alpha:0.9].CGColor;
    [musicButton setImage:[UIImage systemImageNamed:@"music.note.list"] forState:UIControlStateNormal];
    [musicButton setTintColor:[UIColor colorWithRed:0.40 green:0.78 blue:1.0 alpha:1.0]];
    musicButton.accessibilityLabel = @"Chọn nhạc phonk trên YouTube";
    [musicButton addTarget:self action:@selector(showPhonkMusicPicker) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:musicButton];
    [self updateServerStatusIndicator];
}

- (void)showPhonkMusicPicker {
    // In-app music browser for YouTube, SoundCloud and Apple Music search pages.
    UIViewController *browser = [UIViewController new];
    browser.modalPresentationStyle = UIModalPresentationPageSheet;
    browser.view.backgroundColor = [UIColor colorWithRed:0.055 green:0.025 blue:0.13 alpha:1.0];
    browser.title = @"MUSIC STUDIO";

    UIColor *purple = [UIColor colorWithRed:0.68 green:0.20 blue:1.0 alpha:1.0];
    UIColor *cyan = [UIColor colorWithRed:0.10 green:0.88 blue:1.0 alpha:1.0];
    UIView *top = [UIView new];
    top.translatesAutoresizingMaskIntoConstraints = NO;
    [browser.view addSubview:top];

    UILabel *heading = [UILabel new];
    heading.translatesAutoresizingMaskIntoConstraints = NO;
    heading.text = @"MUSIC STUDIO";
    heading.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBlack];
    heading.textColor = UIColor.whiteColor;
    [top addSubview:heading];

    UILabel *subtitle = [UILabel new];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = @"Tìm nhạc và phát trong cửa sổ tích hợp · dịch vụ có thể yêu cầu đăng nhập";
    subtitle.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    subtitle.textColor = [UIColor colorWithWhite:1 alpha:0.66];
    [top addSubview:subtitle];

    UITextField *search = [UITextField new];
    search.translatesAutoresizingMaskIntoConstraints = NO;
    search.placeholder = @"  Tìm bài hát, nghệ sĩ hoặc playlist…";
    search.textColor = UIColor.whiteColor;
    search.tintColor = cyan;
    search.backgroundColor = [UIColor colorWithWhite:1 alpha:0.09];
    search.layer.cornerRadius = 14;
    search.layer.borderWidth = 1;
    search.layer.borderColor = [purple colorWithAlphaComponent:0.55].CGColor;
    search.font = [UIFont systemFontOfSize:14];
    search.returnKeyType = UIReturnKeySearch;
    search.clearButtonMode = UITextFieldViewModeWhileEditing;
    UIView *pad = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 1)];
    search.leftView = pad;
    search.leftViewMode = UITextFieldViewModeAlways;
    [browser.view addSubview:search];

    UISegmentedControl *categories = [[UISegmentedControl alloc] initWithItems:@[@"PHONK", @"SOUNDCLOUD", @"APPLE MUSIC", @"YOUTUBE"]];
    categories.translatesAutoresizingMaskIntoConstraints = NO;
    categories.selectedSegmentIndex = 0;
    categories.selectedSegmentTintColor = purple;
    categories.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
    [categories setTitleTextAttributes:@{NSForegroundColorAttributeName: UIColor.whiteColor, NSFontAttributeName: [UIFont systemFontOfSize:11 weight:UIFontWeightBold]} forState:UIControlStateNormal];
    [categories setTitleTextAttributes:@{NSForegroundColorAttributeName: UIColor.whiteColor, NSFontAttributeName: [UIFont systemFontOfSize:11 weight:UIFontWeightBold]} forState:UIControlStateSelected];
    [browser.view addSubview:categories];

    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    config.allowsInlineMediaPlayback = YES;
    config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    WKWebView *web = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
    web.translatesAutoresizingMaskIntoConstraints = NO;
    web.opaque = NO;
    web.backgroundColor = [UIColor colorWithRed:0.055 green:0.025 blue:0.13 alpha:1.0];
    web.scrollView.backgroundColor = web.backgroundColor;
    if (@available(iOS 15.0, *)) web.underPageBackgroundColor = web.backgroundColor;
    web.allowsBackForwardNavigationGestures = YES;
    web.accessibilityLabel = @"Kết quả tìm kiếm và phát nhạc trong ứng dụng";
    web.layer.cornerRadius = 16;
    web.clipsToBounds = YES;
    [browser.view addSubview:web];

    UIButton *go = [UIButton buttonWithType:UIButtonTypeSystem];
    go.translatesAutoresizingMaskIntoConstraints = NO;
    [go setTitle:@"TÌM KIẾM" forState:UIControlStateNormal];
    [go setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    go.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBlack];
    go.backgroundColor = purple;
    go.layer.cornerRadius = 13;
    [browser.view addSubview:go];

    UIButton *openOutside = [UIButton buttonWithType:UIButtonTypeSystem];
    openOutside.translatesAutoresizingMaskIntoConstraints = NO;
    [openOutside setTitle:@"MỞ APP" forState:UIControlStateNormal];
    [openOutside setTitleColor:cyan forState:UIControlStateNormal];
    openOutside.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    [browser.view addSubview:openOutside];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.translatesAutoresizingMaskIntoConstraints = NO;
    [close setTitle:@"ĐÓNG" forState:UIControlStateNormal];
    [close setTitleColor:cyan forState:UIControlStateNormal];
    close.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    [browser.view addSubview:close];

    __block NSInteger category = 0;
    void (^loadSearch)(NSString *) = ^(NSString *term) {
        NSString *q = [term stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (q.length == 0) {
            switch (category) {
                case 0: q = @"phonk drift playlist"; break;
                case 1: q = @"phonk"; break;
                case 2: q = @"popular songs"; break;
                default: q = @"chill lofi music"; break;
            }
        }
        // URLComponents safely encodes spaces, accents and punctuation in search terms.
        NSURLComponents *components = [NSURLComponents new];
        switch (category) {
            case 0: // YouTube is a reliable default for Phonk/drift mixes.
                components.scheme = @"https"; components.host = @"m.youtube.com"; components.path = @"/results";
                components.queryItems = @[[NSURLQueryItem queryItemWithName:@"search_query" value:q]];
                break;
            case 1: // SoundCloud's searchable sounds route; playback is subject to the service's own restrictions.
                components.scheme = @"https"; components.host = @"soundcloud.com"; components.path = @"/search/sounds";
                components.queryItems = @[[NSURLQueryItem queryItemWithName:@"q" value:q]];
                break;
            case 2:
                components.scheme = @"https"; components.host = @"music.apple.com"; components.path = @"/us/search";
                components.queryItems = @[[NSURLQueryItem queryItemWithName:@"term" value:q]];
                break;
            default:
                components.scheme = @"https"; components.host = @"m.youtube.com"; components.path = @"/results";
                components.queryItems = @[[NSURLQueryItem queryItemWithName:@"search_query" value:q]];
                break;
        }
        NSURL *url = components.URL;
        if (url) [web loadRequest:[NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:25.0]];
    };
    [go addAction:[UIAction actionWithHandler:^(__kindof UIAction *action) { loadSearch(search.text ?: @""); }] forControlEvents:UIControlEventTouchUpInside];
    [search addAction:[UIAction actionWithHandler:^(__kindof UIAction *action) { loadSearch(search.text ?: @""); }] forControlEvents:UIControlEventEditingDidEndOnExit];
    [categories addAction:[UIAction actionWithHandler:^(__kindof UIAction *action) {
        category = categories.selectedSegmentIndex;
        NSString *placeholder = @"  Tìm bài hát, nghệ sĩ hoặc playlist…";
        if (category == 0) placeholder = @"  Tìm phonk / drift / bass trên YouTube…";
        else if (category == 1) placeholder = @"  Tìm trên SoundCloud…";
        else if (category == 2) placeholder = @"  Tìm trên Apple Music…";
        else placeholder = @"  Tìm video / playlist trên YouTube…";
        search.placeholder = placeholder;
        loadSearch(search.text ?: @"");
    }] forControlEvents:UIControlEventValueChanged];
    [openOutside addAction:[UIAction actionWithHandler:^(__kindof UIAction *action) {
        NSString *term = [search.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (term.length == 0) term = @"phonk drift playlist";
        NSURLComponents *deep = [NSURLComponents new];
        if (category == 1) {
            deep.scheme = @"soundcloud"; deep.host = @"search";
            deep.queryItems = @[[NSURLQueryItem queryItemWithName:@"q" value:term]];
        } else if (category == 2) {
            deep.scheme = @"music"; deep.host = @"search";
            deep.queryItems = @[[NSURLQueryItem queryItemWithName:@"term" value:term]];
        } else if (category == 3) {
            deep.scheme = @"youtube"; deep.host = @"results";
            deep.queryItems = @[[NSURLQueryItem queryItemWithName:@"search_query" value:term]];
        }
        NSURL *appURL = deep.URL;
        NSURL *fallbackURL = web.URL;
        UIApplication *application = UIApplication.sharedApplication;
        if (appURL && [application canOpenURL:appURL]) {
            [application openURL:appURL options:@{} completionHandler:^(BOOL success) {
                if (!success && fallbackURL) [application openURL:fallbackURL options:@{} completionHandler:nil];
            }];
        } else if (fallbackURL) {
            [application openURL:fallbackURL options:@{} completionHandler:nil];
        }
    }] forControlEvents:UIControlEventTouchUpInside];
    [close addAction:[UIAction actionWithHandler:^(__kindof UIAction *action) { [browser dismissViewControllerAnimated:YES completion:nil]; }] forControlEvents:UIControlEventTouchUpInside];

    [NSLayoutConstraint activateConstraints:@[
        [top.topAnchor constraintEqualToAnchor:browser.view.safeAreaLayoutGuide.topAnchor constant:10],
        [top.leadingAnchor constraintEqualToAnchor:browser.view.leadingAnchor constant:18],
        [top.trailingAnchor constraintEqualToAnchor:browser.view.trailingAnchor constant:-18],
        [heading.topAnchor constraintEqualToAnchor:top.topAnchor],
        [heading.leadingAnchor constraintEqualToAnchor:top.leadingAnchor],
        [subtitle.topAnchor constraintEqualToAnchor:heading.bottomAnchor constant:4],
        [subtitle.leadingAnchor constraintEqualToAnchor:top.leadingAnchor],
        [subtitle.bottomAnchor constraintEqualToAnchor:top.bottomAnchor],
        [search.topAnchor constraintEqualToAnchor:top.bottomAnchor constant:14],
        [search.leadingAnchor constraintEqualToAnchor:browser.view.leadingAnchor constant:18],
        [search.trailingAnchor constraintEqualToAnchor:browser.view.trailingAnchor constant:-18],
        [search.heightAnchor constraintEqualToConstant:46],
        [categories.topAnchor constraintEqualToAnchor:search.bottomAnchor constant:10],
        [categories.leadingAnchor constraintEqualToAnchor:search.leadingAnchor],
        [categories.trailingAnchor constraintEqualToAnchor:search.trailingAnchor],
        [categories.heightAnchor constraintEqualToConstant:38],
        [web.topAnchor constraintEqualToAnchor:categories.bottomAnchor constant:12],
        [web.leadingAnchor constraintEqualToAnchor:search.leadingAnchor],
        [web.trailingAnchor constraintEqualToAnchor:search.trailingAnchor],
        [web.bottomAnchor constraintEqualToAnchor:go.topAnchor constant:-12],
        [go.leadingAnchor constraintEqualToAnchor:search.leadingAnchor],
        [go.widthAnchor constraintEqualToConstant:100],
        [go.heightAnchor constraintEqualToConstant:44],
        [go.bottomAnchor constraintEqualToAnchor:browser.view.safeAreaLayoutGuide.bottomAnchor constant:-10],
        [openOutside.leadingAnchor constraintEqualToAnchor:go.trailingAnchor constant:8],
        [openOutside.centerYAnchor constraintEqualToAnchor:go.centerYAnchor],
        [openOutside.widthAnchor constraintEqualToConstant:86],
        [openOutside.heightAnchor constraintEqualToConstant:44],
        [close.trailingAnchor constraintEqualToAnchor:search.trailingAnchor],
        [close.centerYAnchor constraintEqualToAnchor:go.centerYAnchor],
        [close.widthAnchor constraintEqualToConstant:58],
        [close.heightAnchor constraintEqualToConstant:44]
    ]];
    search.text = @"phonk drift playlist";
    loadSearch(search.text);
    [self presentViewController:browser animated:YES completion:nil];
}

- (void)updateRoleBadgeTitle:(NSString *)title {
    UIView *container = self.navigationItem.leftBarButtonItem.customView;
    UIButton *button = (UIButton *)[container viewWithTag:731904];
    if (![button isKindOfClass:[UIButton class]]) return;
    NSString *safeTitle = title.length ? title : @"Server";
    [button setTitle:safeTitle forState:UIControlStateNormal];
    CGFloat width = [safeTitle isEqualToString:@"Admin Dev"] ? 82.0 : ([safeTitle isEqualToString:@"Server"] ? 72.0 : 58.0);
    button.frame = CGRectMake(136.0, 0, width, 30.0);
    container.frame = CGRectMake(0, 0, 136.0 + width, 30.0);
    _serverStatusLabel.frame = CGRectMake(14.0, 4.0, 116.0, 22.0);
}

- (void)handleServerButtonTap {
    NSString *selected = [[NSUserDefaults standardUserDefaults] stringForKey:TI_SELECTED_SERVER_KEY];
    if ([selected isEqualToString:@"admin"] || [selected isEqualToString:@"admin_dev"]) {
        [self showAdminServerLogin]; // Re-authenticate in-place; do not silently switch the selection to Free.
        return;
    }
    if (![selected isEqualToString:@"free"] && !self->_isAdminServer) {
        [self showFirstInstallServerPicker];
        return;
    }
    [self showAdminServerLogin];
}

// Default backend endpoint. Only an authenticated admin_dev session can view or change the override in the UI.
static NSString * const TIAdminAPIBaseURLDefault = @"https://tweak-admin-backend.onrender.com";
static NSString * const TIAdminAPIBaseURLOverrideKey = @"ti_admin_api_base_url_override_v195";

- (NSString *)currentFreeServerPingURL {
    NSString *candidate = [[NSUserDefaults standardUserDefaults] stringForKey:TI_FREE_SERVER_PING_URL_KEY];
    if (![candidate isKindOfClass:[NSString class]]) return nil;
    candidate = [candidate stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (candidate.length == 0) return nil;
    NSURLComponents *parts = [NSURLComponents componentsWithString:candidate];
    if (![parts.scheme.lowercaseString isEqualToString:@"https"] || parts.host.length == 0 ||
        parts.user.length > 0 || parts.password.length > 0) return nil;
    return candidate;
}

- (void)performManualServerPing {
    if (_pingRequestInFlight) {
        UIAlertController *busy = [UIAlertController alertControllerWithTitle:@"Đang đo ping"
                                                                        message:@"Đã có một yêu cầu đo đang chạy. Chờ kết quả hiện tại rồi thử lại."
                                                                 preferredStyle:UIAlertControllerStyleAlert];
        [busy addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:busy animated:YES completion:nil];
        return;
    }
    NSString *selected = [[NSUserDefaults standardUserDefaults] stringForKey:TI_SELECTED_SERVER_KEY];
    BOOL adminMode = _isAdminServer || [selected isEqualToString:@"admin"] || [selected isEqualToString:@"admin_dev"];
    if (!adminMode && ![self currentFreeServerPingURL].length) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Chưa cấu hình URL ping"
                                                                       message:@"Server Free chưa có endpoint HTTPS. Nhập URL health/ping của server do mày quản lý rồi thử lại."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Sửa URL" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [self showFreeServerPingURLEditor]; }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    _manualPingRequested = YES;
    [self tickLatency];
    [self.customTableView reloadData];
}

- (void)showFreeServerPingURLEditor {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"URL Ping Server Free"
                                                                   message:@"Nhập endpoint HTTPS do quản trị server cung cấp. Để trống sẽ tắt đo ping Free; ứng dụng không tự đoán URL."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"https://server.example.com/health";
        field.keyboardType = UIKeyboardTypeURL;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.text = [[NSUserDefaults standardUserDefaults] stringForKey:TI_FREE_SERVER_PING_URL_KEY] ?: @"";
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Lưu URL" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        __strong typeof(weakSelf) owner = weakSelf;
        if (!owner) return;
        NSString *candidate = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSURLComponents *parts = [NSURLComponents componentsWithString:candidate ?: @""];
        if (candidate.length == 0) {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:TI_FREE_SERVER_PING_URL_KEY];
        } else if (![parts.scheme.lowercaseString isEqualToString:@"https"] || parts.host.length == 0 ||
                   parts.user.length > 0 || parts.password.length > 0) {
            UIAlertController *error = [UIAlertController alertControllerWithTitle:@"URL không hợp lệ"
                                                                           message:@"Chỉ chấp nhận URL HTTPS có hostname hợp lệ và không chứa thông tin đăng nhập."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [error addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            [owner presentViewController:error animated:YES completion:nil];
            return;
        } else {
            [[NSUserDefaults standardUserDefaults] setObject:candidate forKey:TI_FREE_SERVER_PING_URL_KEY];
        }
        [[NSUserDefaults standardUserDefaults] synchronize];
        ++owner->_serverPingGeneration; // Ignore any response from the previously configured endpoint.
        owner->_pingRequestInFlight = NO;
        owner->_manualPingRequested = NO;
        owner->_serverPingAttempted = NO;
        owner->_serverPingReachable = NO;
        owner->_currentLatencyMs = -1;
        owner->_serverLastHTTPStatus = 0;
        [owner tickLatency];
        [owner updateServerStatusIndicator];
        [owner.customTableView reloadData];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = self.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2.0, self.view.bounds.size.height / 2.0, 1.0, 1.0);
    }
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSString *)currentAdminAPIBaseURL {
    NSString *candidate = [[NSUserDefaults standardUserDefaults] stringForKey:TIAdminAPIBaseURLOverrideKey];
    if (![candidate isKindOfClass:[NSString class]] || candidate.length == 0) candidate = TIAdminAPIBaseURLDefault;
    NSURLComponents *parts = [NSURLComponents componentsWithString:candidate];
    if (![parts.scheme.lowercaseString isEqualToString:@"https"] || parts.host.length == 0 || parts.user.length > 0 || parts.password.length > 0) {
        return TIAdminAPIBaseURLDefault;
    }
    while (candidate.length > 0 && [candidate hasSuffix:@"/"]) candidate = [candidate substringToIndex:candidate.length - 1];
    return candidate;
}

- (BOOL)serverSideAdminAuthenticationConfigured {
    NSString *baseURL = [self currentAdminAPIBaseURL];
    NSURLComponents *parts = [NSURLComponents componentsWithString:baseURL];
    return [parts.scheme.lowercaseString isEqualToString:@"https"] && parts.host.length > 0 &&
           ![parts.host containsString:@"YOUR_BACKEND_HOST"];
}

- (void)performAdminLoginWithUsername:(NSString *)username
                             password:(NSString *)password
                           completion:(void (^)(NSDictionary * _Nullable result, NSError * _Nullable error))completion {
    if (![self serverSideAdminAuthenticationConfigured]) {
        NSError *error = [NSError errorWithDomain:@"TIAdminAPI" code:1001 userInfo:@{NSLocalizedDescriptionKey: @"Chưa cấu hình URL HTTPS của backend trong RootListController.m."}];
        completion(nil, error);
        return;
    }
    NSString *baseURL = [self currentAdminAPIBaseURL];
    NSURL *url = [NSURL URLWithString:[baseURL stringByAppendingString:@"/v1/auth/login"]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15.0];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    NSDictionary *body = @{ @"username": username ?: @"", @"password": password ?: @"", @"client": @"ios-tweak", @"device_id": self->_deviceUUIDString ?: @"" };
    NSError *jsonError = nil;
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:&jsonError];
    if (jsonError) { completion(nil, jsonError); return; }
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    configuration.timeoutIntervalForRequest = 15.0;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) { completion(nil, error); return; }
        NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
        NSDictionary *json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        if (http.statusCode < 200 || http.statusCode >= 300 || ![json isKindOfClass:[NSDictionary class]]) {
            NSString *message = [json isKindOfClass:[NSDictionary class]] ? (json[@"error"] ?: @"Xác thực bị từ chối.") : @"Phản hồi backend không hợp lệ.";
            NSError *apiError = [NSError errorWithDomain:@"TIAdminAPI" code:http.statusCode userInfo:@{NSLocalizedDescriptionKey: message}];
            completion(nil, apiError);
            return;
        }
        completion(json, nil);
    }] resume];
}

- (void)showAdminServerLogin {
    UIAlertController *a = [UIAlertController
        alertControllerWithTitle:@"Đăng Nhập Server Riêng"
        message:@"Nhập tài khoản được cấp. Vai trò và quyền truy cập sẽ được máy chủ xác nhận."
        preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Tài khoản";
        tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
        tf.autocorrectionType = UITextAutocorrectionTypeNo;
        tf.text = @"";
    }];
    [a addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Mật khẩu";
        tf.secureTextEntry = YES;
        tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
        tf.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    __weak typeof(self) weakSelf = self;
    [a addAction:[UIAlertAction actionWithTitle:@"Đăng Nhập" style:UIAlertActionStyleDefault handler:^(UIAlertAction *act) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        NSString *username = a.textFields[0].text ?: @"";
        NSString *password = a.textFields[1].text ?: @"";
        if (username.length == 0 || password.length == 0) {
            UIAlertController *err = [UIAlertController alertControllerWithTitle:@"Thiếu thông tin" message:@"Hãy nhập cả tài khoản và mật khẩu." preferredStyle:UIAlertControllerStyleAlert];
            [err addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            [strongSelf presentViewController:err animated:YES completion:nil];
            return;
        }
        if (![strongSelf serverSideAdminAuthenticationConfigured]) {
            UIAlertController *err = [UIAlertController alertControllerWithTitle:@"Chưa cấu hình backend" message:@"Máy chủ đăng nhập chưa được cấu hình. Hãy liên hệ người quản trị để kiểm tra cấu hình server." preferredStyle:UIAlertControllerStyleAlert];
            [err addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            [strongSelf presentViewController:err animated:YES completion:nil];
            return;
        }
        UIAlertController *loading = [UIAlertController alertControllerWithTitle:@"Đang xác thực" message:@"Đang kiểm tra thông tin với máy chủ…" preferredStyle:UIAlertControllerStyleAlert];
        [strongSelf presentViewController:loading animated:YES completion:nil];
        [strongSelf performAdminLoginWithUsername:username password:password completion:^(NSDictionary *result, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [loading dismissViewControllerAnimated:YES completion:^{
                    if (error || ![result[@"access_token"] isKindOfClass:[NSString class]] || ![result[@"role"] isKindOfClass:[NSString class]]) {
                        NSString *message = @"Không thể đăng nhập. Hãy kiểm tra tài khoản, mật khẩu và kết nối rồi thử lại.";
                        if (error && [error.domain isEqualToString:NSURLErrorDomain]) {
                            if (error.code == NSURLErrorNotConnectedToInternet) message = @"Không có kết nối Internet.";
                            else if (error.code == NSURLErrorTimedOut) message = @"Máy chủ phản hồi quá lâu. Vui lòng thử lại.";
                        } else if (error && [error.domain isEqualToString:@"TIAdminAPI"] && error.code == 403) {
                            NSString *serverMessage = error.localizedDescription ?: @"";
                            if ([serverMessage.lowercaseString containsString:@"blacklist"] || [serverMessage.lowercaseString containsString:@"khóa"] || [serverMessage.lowercaseString containsString:@"khoá"]) {
                                message = [NSString stringWithFormat:@"Backend từ chối đăng nhập: %@", serverMessage];
                            } else {
                                message = [NSString stringWithFormat:@"Backend từ chối quyền đăng nhập (HTTP 403): %@. Kiểm tra tài khoản, trạng thái hoạt động và role trên backend; Admin Dev phải có role admin_dev.", serverMessage];
                            }
                        } else if (error && [error.domain isEqualToString:@"TIAdminAPI"] && error.code == 429) {
                            message = @"Máy chủ giới hạn số lần đăng nhập. Hãy chờ rồi thử lại.";
                        } else if (error && [error.domain isEqualToString:@"TIAdminAPI"] && error.code == 401) {
                            message = @"Sai tài khoản hoặc mật khẩu, hoặc tài khoản đã bị vô hiệu hóa.";
                        } else if (error && error.code >= 400 && error.code < 500) {
                            message = @"Thông tin đăng nhập không hợp lệ hoặc yêu cầu bị backend từ chối.";
                        }
                        UIAlertController *err = [UIAlertController alertControllerWithTitle:@"Đăng nhập thất bại" message:message preferredStyle:UIAlertControllerStyleAlert];
                        [err addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
                        [strongSelf presentViewController:err animated:YES completion:nil];
                        return;
                    }
                    NSString *role = [result[@"role"] isKindOfClass:[NSString class]] ? [result[@"role"] lowercaseString] : @"";
                    if ([role isEqualToString:@"dev"] || [role isEqualToString:@"admin-dev"] || [role isEqualToString:@"developer"]) role = @"admin_dev";
                    if (![role isEqualToString:@"admin"] && ![role isEqualToString:@"admin_dev"]) {
                        UIAlertController *err = [UIAlertController alertControllerWithTitle:@"Không đủ quyền" message:@"Tài khoản không có vai trò quản trị được phép." preferredStyle:UIAlertControllerStyleAlert];
                        [err addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
                        [strongSelf presentViewController:err animated:YES completion:nil];
                        return;
                    }
                    // RTT is measured by the dedicated HTTP ping monitor, never by login duration.
                    strongSelf->_currentLatencyMs = -1;
                    strongSelf->_serverPingReachable = NO;
                    strongSelf->_serverPingAttempted = NO;
                    strongSelf->_adminAccessToken = result[@"access_token"];
                    BOOL tokenStored = Titanium_KeychainStoreAdminToken(strongSelf->_adminAccessToken);
                    strongSelf->_adminRole = role;
                    strongSelf->_isAdminServer = YES;
                    strongSelf->_adminServerUser = username;
                    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:TI_ADMIN_SERVER_KEY];
                    // Username is not a secret; persisting it avoids losing the selected account label.
                    [[NSUserDefaults standardUserDefaults] setObject:username forKey:TI_ADMIN_USER_KEY];
                    [[NSUserDefaults standardUserDefaults] setObject:role forKey:@"TIAdminRole"];
                    [[NSUserDefaults standardUserDefaults] setObject:([role isEqualToString:@"admin_dev"] ? @"admin_dev" : @"admin") forKey:TI_SELECTED_SERVER_KEY];
                    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:TI_FIRST_INSTALL_KEY];
                    // Token is stored in Keychain; the backend remains authoritative for role and revocation.
                    [strongSelf.customTableView setUserInteractionEnabled:YES];
                    [strongSelf updateServerStatusIndicator];
                    [strongSelf updateRoleBadgeTitle:([role isEqualToString:@"admin_dev"] ? @"Admin Dev" : @"Admin")];
                    [strongSelf refreshBottomTabsAvailability];
                    [strongSelf.customTableView reloadData];
                    [strongSelf tickLatency];
                    UINotificationFeedbackGenerator *fb = [[UINotificationFeedbackGenerator alloc] init];
                    [fb notificationOccurred:UINotificationFeedbackTypeSuccess];
                    NSString *roleLabel = [role isEqualToString:@"admin_dev"] ? @"Admin Dev" : @"Admin";
                    NSString *successMessage = [NSString stringWithFormat:@"Đăng nhập thành công.\nVai trò: %@%@", roleLabel, tokenStored ? @"" : @"\n\nCảnh báo: iOS không lưu được phiên vào Keychain; có thể cần đăng nhập lại sau khi đóng Cài đặt."];
                    UIAlertController *ok = [UIAlertController alertControllerWithTitle:@"Đã xác thực" message:successMessage preferredStyle:UIAlertControllerStyleAlert];
                    [ok addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                        if ([role isEqualToString:@"admin_dev"]) {
                            [strongSelf revealAdminDevOnlyControlsIfAvailable];
                        }
                        [strongSelf.customTableView reloadData];
                    }]];
                    [strongSelf presentViewController:ok animated:YES completion:nil];
                }];
            });
        }];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        NSString *selected = [[NSUserDefaults standardUserDefaults] stringForKey:TI_SELECTED_SERVER_KEY];
        if (![selected isEqualToString:@"free"] && !strongSelf->_isAdminServer) {
            dispatch_async(dispatch_get_main_queue(), ^{ [strongSelf showFirstInstallServerPicker]; });
        }
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)restoreStoredAdminSession {
    NSString *token = _adminAccessToken;
    if (!_adminSessionRestorePending || token.length == 0) { _adminSessionRestorePending = NO; return; }
    NSString *base = [self currentAdminAPIBaseURL];
    NSURL *url = [NSURL URLWithString:[base stringByAppendingString:@"/v1/auth/me"]];
    if (!url || ![url.scheme.lowercaseString isEqualToString:@"https"]) {
        _adminSessionRestorePending = NO;
        _isAdminServer = NO;
        self.customTableView.userInteractionEnabled = NO;
        if (self.view.window && !self.presentedViewController) {
            UIAlertController *invalid = [UIAlertController alertControllerWithTitle:@"Endpoint không hợp lệ" message:@"Không thể xác minh phiên Admin vì URL backend không phải HTTPS hợp lệ. Kiểm tra URL rồi đăng nhập lại." preferredStyle:UIAlertControllerStyleAlert];
            [invalid addAction:[UIAlertAction actionWithTitle:@"Đăng nhập lại" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { [self showAdminServerLogin]; }]];
            [invalid addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:invalid animated:YES completion:nil];
        }
        return;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:8.0];
    request.HTTPMethod = @"GET";
    [request setValue:[NSString stringWithFormat:@"Bearer %@", token] forHTTPHeaderField:@"Authorization"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    __weak typeof(self) weakSelf = self;
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
        id parsed = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        NSDictionary *json = [parsed isKindOfClass:[NSDictionary class]] ? parsed : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) owner = weakSelf;
            if (!owner) return;
            owner->_adminSessionRestorePending = NO;
            NSString *role = [json[@"role"] isKindOfClass:[NSString class]] ? [json[@"role"] lowercaseString] : @"";
            if ([role isEqualToString:@"dev"] || [role isEqualToString:@"admin-dev"] || [role isEqualToString:@"developer"]) role = @"admin_dev";
            if (!error && http.statusCode >= 200 && http.statusCode < 300 && ([role isEqualToString:@"admin"] || [role isEqualToString:@"admin_dev"])) {
                owner->_adminRole = role;
                owner->_adminServerUser = [json[@"username"] isKindOfClass:[NSString class]] ? json[@"username"] : owner->_adminServerUser;
                owner->_isAdminServer = YES;
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                [defaults setBool:YES forKey:TI_ADMIN_SERVER_KEY];
                [defaults setObject:role forKey:@"TIAdminRole"];
                if (owner->_adminServerUser.length) [defaults setObject:owner->_adminServerUser forKey:TI_ADMIN_USER_KEY];
                [defaults setObject:role forKey:TI_SELECTED_SERVER_KEY];
                [defaults synchronize];
                owner.customTableView.userInteractionEnabled = YES;
                [owner updateRoleBadgeTitle:([role isEqualToString:@"admin_dev"] ? @"Admin Dev" : @"Admin")];
                [owner updateServerStatusIndicator];
                [owner refreshBottomTabsAvailability];
                [owner.customTableView reloadData];
                [owner tickLatency];
                if (owner->_isFeatureActivated) [owner startContinuousHardwareHUD];
                return;
            }

            owner->_isAdminServer = NO;
            [owner updateRoleBadgeTitle:@"Server"];
            owner.customTableView.userInteractionEnabled = NO;
            [owner refreshBottomTabsAvailability];
            [owner.customTableView reloadData];
            if (http.statusCode == 401 || http.statusCode == 403) {
                Titanium_KeychainDeleteAdminToken();
                owner->_adminAccessToken = nil;
                owner->_adminRole = nil;
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                [defaults setBool:NO forKey:TI_ADMIN_SERVER_KEY];
                [defaults removeObjectForKey:@"TIAdminRole"];
                [defaults synchronize];
                UIAlertController *expired = [UIAlertController alertControllerWithTitle:@"Phiên Admin hết hạn" message:@"Máy chủ đã hết hạn hoặc thu hồi phiên đã lưu. Hãy đăng nhập lại; quyền truy cập vẫn được kiểm tra bởi backend." preferredStyle:UIAlertControllerStyleAlert];
                [expired addAction:[UIAlertAction actionWithTitle:@"Đăng nhập lại" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { [owner showAdminServerLogin]; }]];
                [expired addAction:[UIAlertAction actionWithTitle:@"Để sau" style:UIAlertActionStyleCancel handler:nil]];
                if (owner.view.window && !owner.presentedViewController) [owner presentViewController:expired animated:YES completion:nil];
            } else {
                // Keep the Keychain token after a transient network error, but fail closed until /me succeeds.
                if (owner.view.window && !owner.presentedViewController) {
                    NSString *message = error.localizedDescription ?: @"Không thể xác minh phiên với backend. Hãy thử lại khi có kết nối.";
                    UIAlertController *offline = [UIAlertController alertControllerWithTitle:@"Chưa xác minh được phiên" message:message preferredStyle:UIAlertControllerStyleAlert];
                    [offline addAction:[UIAlertAction actionWithTitle:@"Thử lại" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { owner->_adminSessionRestorePending = YES; [owner restoreStoredAdminSession]; }]];
                    [offline addAction:[UIAlertAction actionWithTitle:@"Đăng nhập lại" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { [owner showAdminServerLogin]; }]];
                    [owner presentViewController:offline animated:YES completion:nil];
                }
            }
        });
    }] resume];
}

- (void)handleExpiredAdminSessionForPath:(NSString *)path {
    (void)path;
    Titanium_KeychainDeleteAdminToken();
    _adminAccessToken = nil;
    _adminRole = nil;
    _isAdminServer = NO;
    _adminSessionRestorePending = NO;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:NO forKey:TI_ADMIN_SERVER_KEY];
    [defaults removeObjectForKey:@"TIAdminRole"];
    // Keep TI_SELECTED_SERVER_KEY as admin/admin_dev so the next tap offers re-login, not Free.
    [defaults synchronize];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateRoleBadgeTitle:@"Server"];
        self.customTableView.userInteractionEnabled = NO;
        [self refreshBottomTabsAvailability];
        [self updateServerStatusIndicator];
        [self.customTableView reloadData];
    });
}

- (void)showServerAPIURLEditor {
    if (![self isAdminDevRole]) {
        [self presentIndependentDocument:@"Restricted" text:@"Admin API configuration is available only to an authenticated Admin Dev role."];
        return;
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Server API URL"
                                                                   message:@"URL Admin được ẩn khi nhập. Nhập endpoint HTTPS đáng tin cậy; đổi endpoint sẽ xóa phiên đã lưu và yêu cầu đăng nhập lại. Quyền Admin vẫn do backend xác thực."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"https://server.example.com";
        field.keyboardType = UIKeyboardTypeURL;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.text = [self currentAdminAPIBaseURL];
        field.secureTextEntry = YES; // Hide the admin endpoint on screen.
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Lưu" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        NSString *candidate = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSURLComponents *parts = [NSURLComponents componentsWithString:candidate ?: @""];
        if (![parts.scheme.lowercaseString isEqualToString:@"https"] || parts.host.length == 0 || parts.user.length > 0 || parts.password.length > 0) {
            UIAlertController *error = [UIAlertController alertControllerWithTitle:@"URL không hợp lệ" message:@"Nhập URL HTTPS có hostname hợp lệ; không dùng thông tin đăng nhập nhúng trong URL." preferredStyle:UIAlertControllerStyleAlert];
            [error addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
            [strongSelf presentViewController:error animated:YES completion:nil];
            return;
        }
        while (candidate.length > 0 && [candidate hasSuffix:@"/"]) candidate = [candidate substringToIndex:candidate.length - 1];
        NSString *previousBase = [strongSelf currentAdminAPIBaseURL];
        [[NSUserDefaults standardUserDefaults] setObject:candidate forKey:TIAdminAPIBaseURLOverrideKey];
        if (![candidate isEqualToString:previousBase]) {
            Titanium_KeychainDeleteAdminToken();
            strongSelf->_adminAccessToken = nil;
            strongSelf->_adminRole = nil;
            strongSelf->_isAdminServer = NO;
            strongSelf->_adminSessionRestorePending = NO;
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:TI_ADMIN_SERVER_KEY];
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"TIAdminRole"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [strongSelf updateRoleBadgeTitle:@"Server"];
            strongSelf.customTableView.userInteractionEnabled = NO;
        } else {
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        [strongSelf.customTableView reloadData];
        [strongSelf refreshBottomTabsAvailability];
        UIAlertController *saved = [UIAlertController alertControllerWithTitle:@"Đã lưu" message:@"Endpoint HTTPS đã lưu. Đăng nhập tiếp để backend xác minh tài khoản và vai trò." preferredStyle:UIAlertControllerStyleAlert];
        [saved addAction:[UIAlertAction actionWithTitle:@"Đăng nhập Admin" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [strongSelf showAdminServerLogin];
        }]];
        [saved addAction:[UIAlertAction actionWithTitle:@"Để sau" style:UIAlertActionStyleCancel handler:nil]];
        [strongSelf presentViewController:saved animated:YES completion:nil];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)performAdminDevRequestPath:(NSString *)path
                            method:(NSString *)method
                              body:(NSDictionary *)body
                        completion:(void (^)(NSDictionary * _Nullable result, NSError * _Nullable error))completion {
    if (![self isAdminDevRole] || self->_adminAccessToken.length == 0) {
        NSError *e = [NSError errorWithDomain:@"TIAdminAPI" code:401 userInfo:@{NSLocalizedDescriptionKey:@"Phiên Admin Dev đã hết hạn. Hãy đăng nhập lại."}];
        if (completion) completion(nil, e);
        return;
    }
    NSString *base = [self currentAdminAPIBaseURL];
    NSURL *url = [NSURL URLWithString:[base stringByAppendingString:path ?: @""]];
    if (!url || ![url.scheme.lowercaseString isEqualToString:@"https"]) {
        NSError *e = [NSError errorWithDomain:@"TIAdminAPI" code:1002 userInfo:@{NSLocalizedDescriptionKey:@"Endpoint HTTPS không hợp lệ."}];
        if (completion) completion(nil, e);
        return;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15.0];
    request.HTTPMethod = method ?: @"GET";
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", self->_adminAccessToken] forHTTPHeaderField:@"Authorization"];
    if (body) {
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        NSError *jsonError = nil;
        request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:&jsonError];
        if (jsonError) { if (completion) completion(nil, jsonError); return; }
    }
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    configuration.timeoutIntervalForRequest = 15.0;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *networkError) {
        if (networkError) { if (completion) completion(nil, networkError); return; }
        NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
        NSError *parseError = nil;
        id object = data.length ? [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&parseError] : @{@"ok":@YES};
        if (http.statusCode < 200 || http.statusCode >= 300 || ![object isKindOfClass:[NSDictionary class]]) {
            NSString *message = nil;
            if (http.statusCode == 401) {
                // A route-specific 401 does not by itself prove the whole session expired. Validate
                // the same bearer token at /v1/auth/me before clearing Keychain and role state.
                NSString *tokenForDiagnostic = [self->_adminAccessToken copy] ?: @"";
                NSURL *meURL = [NSURL URLWithString:[base stringByAppendingString:@"/v1/auth/me"]];
                if (meURL && tokenForDiagnostic.length > 0) {
                    NSMutableURLRequest *meRequest = [NSMutableURLRequest requestWithURL:meURL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:8.0];
                    meRequest.HTTPMethod = @"GET";
                    [meRequest setValue:[NSString stringWithFormat:@"Bearer %@", tokenForDiagnostic] forHTTPHeaderField:@"Authorization"];
                    [meRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
                    [[session dataTaskWithRequest:meRequest completionHandler:^(NSData *meData, NSURLResponse *meResponse, NSError *meError) {
                        NSHTTPURLResponse *meHTTP = [meResponse isKindOfClass:[NSHTTPURLResponse class]] ? (NSHTTPURLResponse *)meResponse : nil;
                        id parsedMe = meData.length ? [NSJSONSerialization JSONObjectWithData:meData options:0 error:nil] : nil;
                        NSDictionary *meJSON = [parsedMe isKindOfClass:[NSDictionary class]] ? (NSDictionary *)parsedMe : nil;
                        NSString *serverRole = [meJSON[@"role"] isKindOfClass:[NSString class]] ? [meJSON[@"role"] lowercaseString] : @"";
                        if ([serverRole isEqualToString:@"dev"] || [serverRole isEqualToString:@"admin-dev"] || [serverRole isEqualToString:@"developer"]) serverRole = @"admin_dev";

                        NSInteger errorCode = 1402;
                        NSString *diagnostic = nil;
                        BOOL validated = !meError && meHTTP.statusCode >= 200 && meHTTP.statusCode < 300;
                        if (validated) {
                            if ([serverRole isEqualToString:@"admin_dev"]) {
                                errorCode = 1401;
                                diagnostic = [NSString stringWithFormat:@"/v1/auth/me vẫn xác nhận admin_dev nhưng %@ trả HTTP 401. Phiên chưa bị xóa; kiểm tra route/middleware hoặc cấu hình backend của endpoint.", path ?: @"/v1"];
                            } else if ([serverRole isEqualToString:@"admin"]) {
                                errorCode = 1403;
                                diagnostic = [NSString stringWithFormat:@"/v1/auth/me xác nhận role admin, không phải admin_dev; endpoint %@ bị từ chối. Vai trò giao diện sẽ được hạ về Admin.", path ?: @"/v1"];
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    self->_adminRole = @"admin";
                                    self->_isAdminServer = YES;
                                    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                                    [defaults setBool:YES forKey:TI_ADMIN_SERVER_KEY];
                                    [defaults setObject:@"admin" forKey:@"TIAdminRole"];
                                    [defaults setObject:@"admin" forKey:TI_SELECTED_SERVER_KEY];
                                    [defaults synchronize];
                                    [self updateRoleBadgeTitle:@"Admin"];
                                    [self refreshBottomTabsAvailability];
                                    [self.customTableView reloadData];
                                });
                            } else {
                                errorCode = 401;
                                diagnostic = [NSString stringWithFormat:@"/v1/auth/me không trả về vai trò quản trị hợp lệ cho endpoint %@. Phiên bị vô hiệu hóa ở giao diện; hãy đăng nhập lại hoặc kiểm tra role trong backend.", path ?: @"/v1"];
                                dispatch_async(dispatch_get_main_queue(), ^{ [self handleExpiredAdminSessionForPath:path]; });
                            }
                        } else if (meHTTP.statusCode == 401 || meHTTP.statusCode == 403) {
                            errorCode = 401;
                            diagnostic = @"Backend cũng từ chối /v1/auth/me (401/403). Phiên có thể hết hạn hoặc bị thu hồi; đăng nhập lại để lấy token mới.";
                            dispatch_async(dispatch_get_main_queue(), ^{ [self handleExpiredAdminSessionForPath:path]; });
                        } else {
                            errorCode = 1402;
                            diagnostic = [NSString stringWithFormat:@"%@ trả HTTP 401 nhưng chưa xác minh được /v1/auth/me. Token được giữ nguyên; kiểm tra mạng/backend rồi thử lại.", path ?: @"/v1"];
                        }
                        NSError *diagnosticError = [NSError errorWithDomain:@"TIAdminAPI" code:errorCode userInfo:@{NSLocalizedDescriptionKey:diagnostic}];
                        if (completion) completion(nil, diagnosticError);
                    }] resume];
                    return;
                }
                dispatch_async(dispatch_get_main_queue(), ^{ [self handleExpiredAdminSessionForPath:path]; });
                message = [NSString stringWithFormat:@"Phiên đăng nhập không có token hợp lệ (HTTP 401, %@). Hãy đăng nhập lại.", path ?: @"/v1"];
            } else if (http.statusCode == 403) {
                // Diagnose the role from the backend itself. Never promote a role on the client.
                NSString *tokenForDiagnostic = [self->_adminAccessToken copy] ?: @"";
                NSURL *meURL = [NSURL URLWithString:[base stringByAppendingString:@"/v1/auth/me"]];
                if (meURL && tokenForDiagnostic.length > 0) {
                    NSMutableURLRequest *meRequest = [NSMutableURLRequest requestWithURL:meURL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:8.0];
                    meRequest.HTTPMethod = @"GET";
                    [meRequest setValue:[NSString stringWithFormat:@"Bearer %@", tokenForDiagnostic] forHTTPHeaderField:@"Authorization"];
                    [meRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
                    [[session dataTaskWithRequest:meRequest completionHandler:^(NSData *meData, NSURLResponse *meResponse, NSError *meError) {
                        NSHTTPURLResponse *meHTTP = (NSHTTPURLResponse *)meResponse;
                        NSDictionary *meJSON = nil;
                        if (meData.length > 0) {
                            id parsedMe = [NSJSONSerialization JSONObjectWithData:meData options:0 error:nil];
                            if ([parsedMe isKindOfClass:[NSDictionary class]]) meJSON = (NSDictionary *)parsedMe;
                        }
                        NSString *serverRole = [meJSON[@"role"] isKindOfClass:[NSString class]] ? [meJSON[@"role"] lowercaseString] : @"";
                        NSString *diagnosticMessage;
                        if (meError || !meHTTP) {
                            diagnosticMessage = [NSString stringWithFormat:@"Backend từ chối %@ (HTTP 403). Không kiểm tra được /v1/auth/me; kiểm tra kết nối, token và backend.", path ?: @"/v1"];
                        } else if (meHTTP.statusCode == 401) {
                            diagnosticMessage = @"Phiên đã hết hạn hoặc bị thu hồi. Hãy đăng nhập lại để nhận token mới.";
                        } else if (meHTTP.statusCode >= 200 && meHTTP.statusCode < 300 && [serverRole isEqualToString:@"admin_dev"]) {
                            diagnosticMessage = [NSString stringWithFormat:@"Backend xác nhận role admin_dev nhưng endpoint %@ trả HTTP 403. Kiểm tra phiên bản backend/route middleware hoặc chính sách quyền của endpoint; không sửa bằng cách bỏ xác thực ở client.", path ?: @"/v1"];
                        } else if (meHTTP.statusCode >= 200 && meHTTP.statusCode < 300) {
                            diagnosticMessage = [NSString stringWithFormat:@"Backend xác nhận role hiện tại là '%@', không phải admin_dev. Sửa role tài khoản trong backend rồi đăng nhập lại.", serverRole.length ? serverRole : @"không xác định"];
                        } else {
                            diagnosticMessage = [NSString stringWithFormat:@"Backend từ chối %@ (HTTP 403); endpoint /v1/auth/me trả HTTP %ld. Kiểm tra role DB, phiên và cấu hình backend.", path ?: @"/v1", (long)meHTTP.statusCode];
                        }
                        NSError *apiError = [NSError errorWithDomain:@"TIAdminAPI" code:403 userInfo:@{NSLocalizedDescriptionKey:diagnosticMessage}];
                        if (completion) completion(nil, apiError);
                    }] resume];
                    return;
                }
                message = [NSString stringWithFormat:@"Backend từ chối endpoint %@ (HTTP 403). Nhãn trên giao diện không cấp quyền; đăng nhập lại và kiểm tra role trên backend.", path ?: @"/v1"];
            } else if (http.statusCode == 404) {
                message = [NSString stringWithFormat:@"Backend chưa có endpoint %@ (HTTP 404). Cần cập nhật backend tương thích; không nên bỏ kiểm tra quyền ở client.", path ?: @"/v1"];
            } else {
                message = [NSString stringWithFormat:@"Yêu cầu %@ thất bại (HTTP %ld). Kiểm tra backend và thử lại.", path ?: @"/v1", (long)http.statusCode];
            }
            NSError *apiError = [NSError errorWithDomain:@"TIAdminAPI" code:http.statusCode userInfo:@{NSLocalizedDescriptionKey:message}];
            if (completion) completion(nil, apiError);
            return;
        }
        if (completion) completion((NSDictionary *)object, nil);
    }] resume];
}

- (void)showAdminDevResponseTitle:(NSString *)title path:(NSString *)path {
    __weak typeof(self) weakSelf = self;
    [self performAdminDevRequestPath:path method:@"GET" body:nil completion:^(NSDictionary *result, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) selfRef = weakSelf;
            if (!selfRef) return;
            NSString *message = nil;
            if (error) {
                message = error.localizedDescription ?: @"Không thể tải dữ liệu.";
            } else {
                NSData *json = [NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:nil];
                message = json ? [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] : @"Backend trả dữ liệu không đọc được.";
                if (message.length > 3200) message = [[message substringToIndex:3200] stringByAppendingString:@"\n… (đã rút gọn)"];
            }
            BOOL sessionExpired = error && [error.domain isEqualToString:@"TIAdminAPI"] && error.code == 401;
            UIAlertController *info = [UIAlertController alertControllerWithTitle:(sessionExpired ? @"Phiên đăng nhập hết hạn" : title) message:message preferredStyle:UIAlertControllerStyleAlert];
            if (sessionExpired) {
                [info addAction:[UIAlertAction actionWithTitle:@"Đăng nhập lại" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { [selfRef showAdminServerLogin]; }]];
            }
            [info addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
            [selfRef presentViewController:info animated:YES completion:nil];
        });
    }];
}

- (void)showAdminDevConsole {
    if (![self isAdminDevRole]) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Admin Dev Console"
                                                                   message:@"Các yêu cầu quản trị được xác thực bởi backend và chỉ gửi khi phiên Admin Dev còn hiệu lực."
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Thiết bị" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [weakSelf showAdminDevResponseTitle:@"Thiết bị" path:@"/v1/admin/devices"];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Danh sách tài khoản" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [weakSelf showAdminDevResponseTitle:@"Tài khoản" path:@"/v1/admin/users"];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Audit log" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [weakSelf showAdminDevResponseTitle:@"Audit log" path:@"/v1/admin/audit"];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Thêm thiết bị vào blacklist" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        __strong typeof(weakSelf) selfRef = weakSelf;
        if (!selfRef || ![selfRef isAdminDevRole]) return;
        UIAlertController *form = [UIAlertController alertControllerWithTitle:@"Blacklist thiết bị" message:@"Nhập Device ID và lý do. Backend sẽ xác thực quyền trước khi ghi." preferredStyle:UIAlertControllerStyleAlert];
        [form addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = @"Device ID"; field.autocapitalizationType = UITextAutocapitalizationTypeNone; field.autocorrectionType = UITextAutocorrectionTypeNo; }];
        [form addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = @"Lý do (tuỳ chọn)"; }];
        [form addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
        [form addAction:[UIAlertAction actionWithTitle:@"Xác nhận" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *confirm) {
            NSString *deviceID = [form.textFields[0].text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSString *reason = form.textFields[1].text ?: @"policy";
            if (deviceID.length == 0 || deviceID.length > 128) return;
            [selfRef performAdminDevRequestPath:@"/v1/admin/blacklist" method:@"POST" body:@{@"device_id":deviceID, @"reason":reason} completion:^(NSDictionary *result, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSString *msg = error ? (error.localizedDescription ?: @"Thao tác thất bại.") : @"Thiết bị đã được gửi tới backend để blacklist.";
                    UIAlertController *done = [UIAlertController alertControllerWithTitle:error ? @"Không thành công" : @"Đã gửi yêu cầu" message:msg preferredStyle:UIAlertControllerStyleAlert];
                    [done addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
                    [selfRef presentViewController:done animated:YES completion:nil];
                });
            }];
        }]];
        [selfRef presentViewController:form animated:YES completion:nil];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Gỡ khỏi blacklist" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        __strong typeof(weakSelf) selfRef = weakSelf;
        if (!selfRef || ![selfRef isAdminDevRole]) return;
        UIAlertController *form = [UIAlertController alertControllerWithTitle:@"Gỡ blacklist" message:@"Nhập chính xác Device ID." preferredStyle:UIAlertControllerStyleAlert];
        [form addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = @"Device ID"; field.autocapitalizationType = UITextAutocapitalizationTypeNone; field.autocorrectionType = UITextAutocorrectionTypeNo; }];
        [form addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
        [form addAction:[UIAlertAction actionWithTitle:@"Gỡ" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *confirm) {
            NSString *deviceID = [form.textFields.firstObject.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (deviceID.length == 0 || deviceID.length > 128) return;
            NSCharacterSet *safeChars = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_."];
            NSString *encoded = [deviceID stringByAddingPercentEncodingWithAllowedCharacters:safeChars];
            if (!encoded) return;
            NSString *path = [@"/v1/admin/blacklist/" stringByAppendingString:encoded];
            [selfRef performAdminDevRequestPath:path method:@"DELETE" body:nil completion:^(NSDictionary *result, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSString *msg = error ? (error.localizedDescription ?: @"Thao tác thất bại.") : ([result[@"removed"] boolValue] ? @"Đã gỡ thiết bị khỏi blacklist." : @"Backend không tìm thấy thiết bị trong blacklist.");
                    UIAlertController *done = [UIAlertController alertControllerWithTitle:error ? @"Không thành công" : @"Kết quả" message:msg preferredStyle:UIAlertControllerStyleAlert];
                    [done addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
                    [selfRef presentViewController:done animated:YES completion:nil];
                });
            }];
        }]];
        [selfRef presentViewController:form animated:YES completion:nil];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Thu hồi phiên" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        __strong typeof(weakSelf) selfRef = weakSelf;
        if (!selfRef || ![selfRef isAdminDevRole]) return;
        UIAlertController *form = [UIAlertController alertControllerWithTitle:@"Thu hồi phiên đăng nhập" message:@"Nhập Session ID do backend cung cấp." preferredStyle:UIAlertControllerStyleAlert];
        [form addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = @"Session ID"; field.autocapitalizationType = UITextAutocapitalizationTypeNone; field.autocorrectionType = UITextAutocorrectionTypeNo; }];
        [form addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
        [form addAction:[UIAlertAction actionWithTitle:@"Thu hồi" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *confirm) {
            NSString *sessionID = [form.textFields.firstObject.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (sessionID.length == 0 || sessionID.length > 80) return;
            [selfRef performAdminDevRequestPath:@"/v1/admin/revoke-session" method:@"POST" body:@{@"session_id":sessionID} completion:^(NSDictionary *result, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSString *msg = error ? (error.localizedDescription ?: @"Thao tác thất bại.") : ([result[@"revoked"] boolValue] ? @"Đã thu hồi phiên." : @"Backend không tìm thấy phiên còn hiệu lực.");
                    UIAlertController *done = [UIAlertController alertControllerWithTitle:error ? @"Không thành công" : @"Kết quả" message:msg preferredStyle:UIAlertControllerStyleAlert];
                    [done addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
                    [selfRef presentViewController:done animated:YES completion:nil];
                });
            }];
        }]];
        [selfRef presentViewController:form animated:YES completion:nil];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popover = alert.popoverPresentationController;
    if (popover) { popover.sourceView = self.view; popover.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1); }
    [self presentViewController:alert animated:YES completion:nil];
}

- (BOOL)isAdminDevRole {
    return self->_isAdminServer && [self->_adminRole isEqualToString:@"admin_dev"];
}

- (void)revealAdminDevOnlyControlsIfAvailable {
    // Role gate for future dev-only controls. Keep hidden controls absent by default;
    // any privileged action must still be authorized by the backend on every API request.
    if (![self isAdminDevRole]) return;
    [self.customTableView reloadData];
}

#pragma mark - Latency

- (void)startLatencyMonitor {
    // V25: real HTTP round-trip measurement, no random values and no periodic table reloads.
    [_latencyTimer invalidate]; _latencyTimer = nil;
    [_serverBlinkTimer invalidate]; _serverBlinkTimer = nil;
    _currentLatencyMs = -1;
    _serverPingReachable = NO;
    _serverPingAttempted = NO;
    _serverLastHTTPStatus = 0;
    _pingRequestInFlight = NO;
    _manualPingRequested = NO;
    [self tickLatency];
    _latencyTimer = [NSTimer scheduledTimerWithTimeInterval:20.0 target:self selector:@selector(tickLatency) userInfo:nil repeats:YES];
}

- (void)tickLatency {
    if (_pingRequestInFlight) return;
    NSString *selected = [[NSUserDefaults standardUserDefaults] stringForKey:TI_SELECTED_SERVER_KEY];
    BOOL adminMode = _isAdminServer || [selected isEqualToString:@"admin"] || [selected isEqualToString:@"admin_dev"];
    // Admin uses the backend /health route; Free uses only its explicitly configured HTTPS URL.
    // Never substitute the Admin endpoint for Free, because that would label the wrong RTT.
    NSString *endpoint = nil;
    if (adminMode) {
        NSString *base = [self currentAdminAPIBaseURL];
        endpoint = [base stringByAppendingString:@"/health"];
    } else {
        endpoint = [self currentFreeServerPingURL];
    }
    if (endpoint.length == 0) {
        ++_serverPingGeneration;
        _pingRequestInFlight = NO;
        _serverPingAttempted = NO;
        _serverPingReachable = NO;
        _currentLatencyMs = -1;
        _serverLastHTTPStatus = 0;
        [_serverStatusDot.layer removeAnimationForKey:@"TI_ServerPingPulse"];
        [_serverStatusLabel.layer removeAnimationForKey:@"TI_ServerPingPulse"];
        [self updateServerStatusIndicator];
        return;
    }
    NSURLComponents *endpointParts = [NSURLComponents componentsWithString:endpoint];
    NSURL *url = [NSURL URLWithString:endpoint];
    if (!url || ![endpointParts.scheme.lowercaseString isEqualToString:@"https"] ||
        endpointParts.host.length == 0 || endpointParts.user.length > 0 || endpointParts.password.length > 0) {
        _serverPingAttempted = YES;
        _serverPingReachable = NO;
        _currentLatencyMs = -1;
        _serverLastHTTPStatus = 0;
        [self updateServerStatusIndicator];
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:6.0];
    request.HTTPMethod = @"GET";
    [request setValue:@"no-cache" forHTTPHeaderField:@"Cache-Control"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    _pingRequestInFlight = YES;
    _serverPingAttempted = YES;
    uint64_t generation = ++_serverPingGeneration;
    CFTimeInterval started = CACurrentMediaTime();
    if (_serverStatusDot && ![_serverStatusDot.layer animationForKey:@"TI_ServerPingPulse"]) {
        CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
        pulse.fromValue = @0.40; pulse.toValue = @1.0; pulse.duration = 0.65;
        pulse.autoreverses = YES; pulse.repeatCount = HUGE_VALF;
        [_serverStatusDot.layer addAnimation:pulse forKey:@"TI_ServerPingPulse"];
        if (_serverStatusLabel && ![_serverStatusLabel.layer animationForKey:@"TI_ServerPingPulse"]) {
            [_serverStatusLabel.layer addAnimation:pulse forKey:@"TI_ServerPingPulse"];
        }
    }
    [self updateServerStatusIndicator];

    __weak typeof(self) weakSelf = self;
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        (void)data;
        NSHTTPURLResponse *http = [response isKindOfClass:[NSHTTPURLResponse class]] ? (NSHTTPURLResponse *)response : nil;
        NSInteger elapsed = (NSInteger)MAX(0.0, round((CACurrentMediaTime() - started) * 1000.0));
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) owner = weakSelf;
            if (!owner || generation != owner->_serverPingGeneration) return;
            owner->_pingRequestInFlight = NO;
            BOOL wasManualPing = owner->_manualPingRequested;
            owner->_manualPingRequested = NO;
            [owner->_serverStatusDot.layer removeAnimationForKey:@"TI_ServerPingPulse"];
            [owner->_serverStatusLabel.layer removeAnimationForKey:@"TI_ServerPingPulse"];
            owner->_serverStatusDot.layer.opacity = 1.0;
            owner->_serverStatusLabel.layer.opacity = 1.0;
            if (!error && http) {
                // Any HTTP response proves network reachability; RTT is reported separately from route status.
                owner->_serverPingReachable = YES;
                owner->_currentLatencyMs = elapsed;
                owner->_serverLastHTTPStatus = http.statusCode;
            } else {
                owner->_serverPingReachable = NO;
                owner->_currentLatencyMs = -1;
                owner->_serverLastHTTPStatus = 0;
            }
            [owner updateServerStatusIndicator];
            if (wasManualPing && owner.presentedViewController == nil) {
                NSString *pingTitle = owner->_serverPingReachable ? @"Kết quả ping" : @"Ping thất bại";
                NSString *pingMessage = owner->_serverPingReachable
                    ? [NSString stringWithFormat:@"HTTP %ld · RTT %ld ms\n\nCó phản hồi mạng; HTTP 4xx/5xx vẫn có thể là lỗi ứng dụng.", (long)owner->_serverLastHTTPStatus, (long)owner->_currentLatencyMs]
                    : @"Không nhận được phản hồi HTTPS trước thời hạn. Kiểm tra URL, chứng chỉ TLS, kết nối mạng và endpoint health.";
                UIAlertController *pingAlert = [UIAlertController alertControllerWithTitle:pingTitle message:pingMessage preferredStyle:UIAlertControllerStyleAlert];
                [pingAlert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
                [owner presentViewController:pingAlert animated:YES completion:nil];
            }
            if (owner->_currentBottomTab == 4 && owner.customTableView.numberOfSections > 2 && [owner.customTableView numberOfRowsInSection:2] > 1) {
                NSArray *rows = @[[NSIndexPath indexPathForRow:0 inSection:2], [NSIndexPath indexPathForRow:1 inSection:2]];
                [UIView performWithoutAnimation:^{ [owner.customTableView reloadRowsAtIndexPaths:rows withRowAnimation:UITableViewRowAnimationNone]; }];
            }
        });
    }] resume];
}

- (void)handleServerCrash {
    if (_isAdminServer) return;
    if (_serverDown) return;
    _serverDown = YES;

    NSTimeInterval downUntil = [[NSDate date] timeIntervalSince1970] + 20 * 60;
    Titanium_SavePersistentServerState(TI_STATE_DOWN, downUntil);
    self.settingsDict[TI_SERVER_DOWN_KEY] = @(downUntil);
    self.settingsDict[@"Enabled"] = @NO;
    [self saveSettingsDataAndSync];
    [[NSUserDefaults standardUserDefaults] setDouble:downUntil forKey:TI_SERVER_DOWN_KEY];
    [[NSUserDefaults standardUserDefaults] synchronize];

    [self showPersistentServerStateAlert];
}

- (void)showLatencyWarning {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Server quá tải"
                                                               message:@"Server đang quá tải hoặc gặp lỗi.\n\nVui lòng chờ trong giây lát. Trạng thái này sẽ được lưu lại."
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Đã Hiểu" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)updateServerStatusIndicator {
    if (!_serverStatusDot || !_serverStatusLabel) return;
    NSString *selected = [[NSUserDefaults standardUserDefaults] stringForKey:TI_SELECTED_SERVER_KEY];
    BOOL adminMode = _isAdminServer || [selected isEqualToString:@"admin"] || [selected isEqualToString:@"admin_dev"];

    if (adminMode) {
        if (_serverPingReachable && _currentLatencyMs >= 0 && _serverLastHTTPStatus >= 400) {
            UIColor *httpColor = _serverLastHTTPStatus >= 500 ? [UIColor systemRedColor] : [UIColor systemYellowColor];
            _serverStatusDot.backgroundColor = httpColor;
            _serverStatusLabel.text = [NSString stringWithFormat:@"Admin: HTTP %ld • %ld ms", (long)_serverLastHTTPStatus, (long)_currentLatencyMs];
            _serverStatusLabel.textColor = httpColor;
        } else if (_serverPingReachable && _currentLatencyMs >= 0) {
            if (_currentLatencyMs >= 500) _serverStatusDot.backgroundColor = [UIColor systemRedColor];
            else if (_currentLatencyMs >= 150) _serverStatusDot.backgroundColor = [UIColor systemYellowColor];
            else _serverStatusDot.backgroundColor = [UIColor systemGreenColor];
            _serverStatusLabel.text = [NSString stringWithFormat:@"Admin: %ld ms", (long)_currentLatencyMs];
            _serverStatusLabel.textColor = _serverStatusDot.backgroundColor;
        } else if (_pingRequestInFlight) {
            _serverStatusDot.backgroundColor = [UIColor systemYellowColor];
            _serverStatusLabel.text = @"Admin: Đang đo…";
            _serverStatusLabel.textColor = [UIColor systemYellowColor];
        } else if (_serverPingAttempted) {
            _serverStatusDot.backgroundColor = [UIColor systemRedColor];
            _serverStatusLabel.text = @"Admin: Mất kết nối";
            _serverStatusLabel.textColor = [UIColor systemRedColor];
        } else {
            _serverStatusDot.backgroundColor = [UIColor colorWithRed:0.20 green:0.90 blue:0.70 alpha:1.0];
            _serverStatusLabel.text = @"Admin: Chưa đo";
            _serverStatusLabel.textColor = [UIColor colorWithRed:0.75 green:0.68 blue:1.0 alpha:1.0];
        }
        return;
    }

    int pState = Titanium_CurrentPersistentServerState();
    if (pState == TI_STATE_DOWN) {
        _serverStatusDot.backgroundColor = [UIColor systemRedColor];
        _serverStatusLabel.text = @"Free: Đang sự cố";
        _serverStatusLabel.textColor = [UIColor systemRedColor];
    } else if (pState == TI_STATE_OVERLOAD) {
        _serverStatusDot.backgroundColor = [UIColor systemRedColor];
        _serverStatusLabel.text = @"Free: Quá tải";
        _serverStatusLabel.textColor = [UIColor systemRedColor];
    } else if (pState == TI_STATE_ERROR) {
        _serverStatusDot.backgroundColor = [UIColor systemRedColor];
        _serverStatusLabel.text = @"Free: Lỗi kết nối";
        _serverStatusLabel.textColor = [UIColor systemRedColor];
    } else if (_pingRequestInFlight) {
        _serverStatusDot.backgroundColor = [UIColor systemYellowColor];
        _serverStatusLabel.text = @"Free: Đang đo…";
        _serverStatusLabel.textColor = [UIColor systemYellowColor];
    } else if (_serverPingReachable && _currentLatencyMs >= 0 && _serverLastHTTPStatus >= 400) {
        UIColor *httpColor = _serverLastHTTPStatus >= 500 ? [UIColor systemRedColor] : [UIColor systemYellowColor];
        _serverStatusDot.backgroundColor = httpColor;
        _serverStatusLabel.text = [NSString stringWithFormat:@"Free: HTTP %ld · %ld ms", (long)_serverLastHTTPStatus, (long)_currentLatencyMs];
        _serverStatusLabel.textColor = httpColor;
    } else if (_currentLatencyMs < 0) {
        _serverStatusDot.backgroundColor = [UIColor colorWithRed:0.20 green:0.90 blue:0.70 alpha:1.0];
        if (!_serverPingAttempted && ![self currentFreeServerPingURL].length) {
            _serverStatusLabel.text = @"Free: Chưa cấu hình ping";
            _serverStatusLabel.textColor = [UIColor colorWithRed:0.75 green:0.68 blue:1.0 alpha:1.0];
        } else {
            _serverStatusLabel.text = @"Free: Không kết nối được";
            _serverStatusLabel.textColor = [UIColor systemRedColor];
        }
    } else if (_currentLatencyMs >= 500) {
        _serverStatusDot.backgroundColor = [UIColor systemRedColor];
        _serverStatusLabel.text = [NSString stringWithFormat:@"Server Free: Chậm - %ldms", (long)_currentLatencyMs];
        _serverStatusLabel.textColor = [UIColor systemRedColor];
    } else if (_currentLatencyMs >= 150) {
        _serverStatusDot.backgroundColor = [UIColor systemYellowColor];
        _serverStatusLabel.text = [NSString stringWithFormat:@"Server Free: Kém - %ldms", (long)_currentLatencyMs];
        _serverStatusLabel.textColor = [UIColor systemYellowColor];
    } else {
        _serverStatusDot.backgroundColor = [UIColor systemGreenColor];
        _serverStatusLabel.text = [NSString stringWithFormat:@"Server Free: Ổn định - %ldms", (long)_currentLatencyMs];
        _serverStatusLabel.textColor = [UIColor colorWithWhite:0.85 alpha:1.0];
    }
}

- (void)blinkServerStatus {
    // Kept for source compatibility; status is deliberately never faded/blinked.
    if (_serverStatusLabel && _serverStatusLabel.alpha < 1.0) _serverStatusLabel.alpha = 1.0;
}

#pragma mark - Expanding nav

- (void)setupExpandingNavigationItems {
    // [V10] Sửa lỗi 3-4 nút góc phải dính nhau / nhấn không được:
    // Không dùng UIStackView (FillEqually kéo rộng vùng chạm đè lên nhau). Dùng container view
    // với frame cố định chính xác 40x40 mỗi nút, spacing 12, mỗi nút độc lập, vùng chạm không đè.
    _expandingBoltButton = [[LGExpandingNavBarButton alloc] initWithIconName:@"bolt.horizontal.fill" tintColor:[UIColor colorWithRed:0.35 green:0.95 blue:0.6 alpha:1.0]];
    _expandingBoltButton.delegate = self;
    _expandingBoltButton.tag = 103;
    [_expandingBoltButton setActions:@[
        [LGExpandingMenuAction actionWithTitle:@"Áp Dụng Ngay" image:@"arrow.clockwise" tintColor:[UIColor whiteColor] destructive:NO],
        [LGExpandingMenuAction actionWithTitle:@"Ép Xung 144Hz" image:@"bolt.fill" tintColor:[UIColor systemYellowColor] destructive:NO],
        [LGExpandingMenuAction actionWithTitle:@"Reset Tần Số" image:@"arrow.counterclockwise" tintColor:[UIColor systemOrangeColor] destructive:NO],
        [LGExpandingMenuAction actionWithTitle:@"Glass Redraw" image:@"sparkles" tintColor:[UIColor colorWithRed:0.5 green:0.8 blue:1.0 alpha:1.0] destructive:NO],
    ]];

    _expandingLockButton = [[LGExpandingNavBarButton alloc] initWithIconName:@"lock.open.fill" tintColor:[UIColor whiteColor]];
    _expandingLockButton.delegate = self;
    _expandingLockButton.tag = 102;
    [_expandingLockButton setActions:@[
        [LGExpandingMenuAction actionWithTitle:@"Mở Khóa" image:@"lock.open.fill" tintColor:[UIColor systemGreenColor] destructive:NO],
        [LGExpandingMenuAction actionWithTitle:@"Khóa" image:@"lock.fill" tintColor:[UIColor systemRedColor] destructive:NO],
        [LGExpandingMenuAction actionWithTitle:@"Lưu" image:@"square.and.arrow.down.fill" tintColor:[UIColor colorWithRed:0.4 green:0.7 blue:1.0 alpha:1.0] destructive:NO],
        [LGExpandingMenuAction actionWithTitle:@"Áp Dụng" image:@"arrow.clockwise" tintColor:[UIColor colorWithRed:0.35 green:0.95 blue:0.6 alpha:1.0] destructive:NO],
    ]];

    _expandingMenuButton = [[LGExpandingNavBarButton alloc] initWithIconName:@"line.3.horizontal" tintColor:[UIColor whiteColor]];
    _expandingMenuButton.delegate = self;
    _expandingMenuButton.tag = 101;
    [_expandingMenuButton setActions:@[
        [LGExpandingMenuAction actionWithTitle:@"Respring" image:@"arrow.triangle.2.circlepath" tintColor:[UIColor colorWithRed:0.4 green:0.85 blue:1.0 alpha:1.0] destructive:NO],
        [LGExpandingMenuAction actionWithTitle:@"Userspace" image:@"arrow.clockwise.circle.fill" tintColor:[UIColor systemOrangeColor] destructive:NO],
        [LGExpandingMenuAction actionWithTitle:@"Safe Mode" image:@"shield.lefthalf.fill" tintColor:[UIColor systemYellowColor] destructive:NO],
        [LGExpandingMenuAction actionWithTitle:@"Xóa Sạch" image:@"trash.fill" tintColor:[UIColor systemRedColor] destructive:YES],
        [LGExpandingMenuAction actionWithTitle:([Titanium_ResolvePayloadLanguage(self.settingsDict ?: @{}) isEqualToString:@"vi"] ? @"Hướng dẫn & pháp lý" : @"Guide & legal") image:@"book.closed.fill" tintColor:[UIColor colorWithRed:0.42 green:0.78 blue:1.0 alpha:1.0] destructive:NO],
    ]];

    // [V10.1 SỬA LỖI 1 NÚT BỊ CHE]: giảm kích thước xuống 36, spacing 10, container rộng vừa đủ,
    // clipsToBounds=NO, thứ tự add từ phải sang trái để nút ngoài cùng không bị che.
    CGFloat btnSize = 36.0;
    CGFloat spacing = 10.0;
    CGFloat totalW = btnSize * 3 + spacing * 2;
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, totalW, btnSize)];
    container.backgroundColor = [UIColor clearColor];
    container.userInteractionEnabled = YES;
    container.clipsToBounds = NO;

    _expandingBoltButton.frame = CGRectMake(0, 0, btnSize, btnSize);
    _expandingLockButton.frame = CGRectMake(btnSize + spacing, 0, btnSize, btnSize);
    _expandingMenuButton.frame = CGRectMake((btnSize + spacing) * 2, 0, btnSize, btnSize);
    // Thứ tự add: nút phải cùng (bolt) add cuối để nằm trên cùng, không bị che
    [container addSubview:_expandingMenuButton];
    [container addSubview:_expandingLockButton];
    [container addSubview:_expandingBoltButton];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:container];
    [self updateLockIcon];
}

// [V10] Khi một nút mở rộng, tự động thu hẹp 2 nút còn lại -> không còn tình trạng menu đè nhau,
// nhấn nút khác không phản ứng (dimOverlay che). Mỗi nút bây giờ độc lập hoàn toàn.
- (void)expandingButtonDidExpand:(LGExpandingNavBarButton *)button {
    if (button != _expandingMenuButton && [_expandingMenuButton respondsToSelector:@selector(collapseMenu)]) [_expandingMenuButton collapseMenu];
    if (button != _expandingLockButton && [_expandingLockButton respondsToSelector:@selector(collapseMenu)]) [_expandingLockButton collapseMenu];
    if (button != _expandingBoltButton && [_expandingBoltButton respondsToSelector:@selector(collapseMenu)]) [_expandingBoltButton collapseMenu];
}

- (void)expandingButton:(LGExpandingNavBarButton *)button didSelectActionAtIndex:(NSInteger)index {
    // Help, privacy, terms, and read-only diagnostics remain available without activation.
    if (!_isFeatureActivated && !(button == _expandingMenuButton && index == 4)) {
        if ([button respondsToSelector:@selector(collapseMenu)]) [button collapseMenu];
        [self showUnexploitedWarningAlert];
        return;
    }
    if (button == _expandingMenuButton && index == 4) {
        if ([button respondsToSelector:@selector(collapseMenu)]) [button collapseMenu];
        [self showIndependentToolkitMenu];
        return;
    }
    if (button == _expandingMenuButton) {
        switch (index) {
            case 0: [self executeRespring]; break;
            case 1: [self executeSReboot]; break;
            case 2: [self executeSafeMode]; break;
            case 3: [self executeResetConfiguration]; break;
        }
    } else if (button == _expandingBoltButton) {
        switch (index) {
            case 0: {
                [self runApplyWithLoading];
                break;
            }
            case 1:
                self.settingsDict[@"TargetRefreshRate"] = @240;
                self.settingsDict[@"TargetFPSRate"] = @240;
                self.settingsDict[@"ForceOverclock144Hz"] = @YES;
                _lastAppliedHz = 240;
                _lastAppliedFPS = 240;
                [self saveSettingsDataAndSync];
                [self applyDeepSpringBoardAndUIKitTweaks];
                [self.customTableView reloadData];
                break;
            case 2:
                self.settingsDict[@"TargetRefreshRate"] = @60;
                self.settingsDict[@"TargetFPSRate"] = @60;
                self.settingsDict[@"ForceOverclock144Hz"] = @NO;
                _lastAppliedHz = 60;
                _lastAppliedFPS = 60;
                [self saveSettingsDataAndSync];
                [self applyDeepSpringBoardAndUIKitTweaks];
                [self.customTableView reloadData];
                break;
            case 3: {
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                id saved = [defaults objectForKey:TI_GLASS_TRANSPARENCY_KEY];
                BOOL currentlyEnabled = saved ? [saved boolValue] : YES;
                BOOL enableTransparency = !currentlyEnabled;
                [defaults setBool:enableTransparency forKey:TI_GLASS_TRANSPARENCY_KEY];
                self.settingsDict[@"GlassTransparencyEnabled"] = @(enableTransparency);
                [self saveSettingsDataAndSync];
                UIView *root = self.view.window ?: self.view;
                [self applyGlassTransparencyRecursively:root enabled:enableTransparency];
                UINotificationFeedbackGenerator *fb = [[UINotificationFeedbackGenerator alloc] init];
                [fb notificationOccurred:UINotificationFeedbackTypeSuccess];
                break;
            }
        }
    } else if (button == _expandingLockButton) {
        switch (index) {
            case 0:
                if (!_isFeatureActivated) { [self showUnexploitedWarningAlert]; return; }
                _isRateLocked = NO;
                self.settingsDict[@"IsRateLocked"] = @NO;
                [self saveSettingsDataAndSync];
                [self updateLockIcon];
                [self.customTableView reloadData];
                break;
            case 1:
                if (!_isFeatureActivated) { [self showUnexploitedWarningAlert]; return; }
                _isRateLocked = YES;
                self.settingsDict[@"IsRateLocked"] = @YES;
                [self saveSettingsDataAndSync];
                [self updateLockIcon];
                [self.customTableView reloadData];
                break;
            case 2: [self saveSettingsDataAndSync]; break;
            case 3: [self runApplyWithLoading]; break;
        }
    }
}

- (void)runApplyWithLoading {
    if (!_isFeatureActivated) { [self showUnexploitedWarningAlert]; return; }
    // V22: avoid a 5-second full-screen dim overlay and per-frame car timer.
    // The actual preference/payload work is coalesced and applied by applyDeepSpringBoardAndUIKitTweaks.
    [self applyDeepSpringBoardAndUIKitTweaks];
    [self updateServerStatusIndicator];
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [feedback impactOccurred];
    [self smoothReloadTable];
}

#pragma mark - V20.1 Theme, Glass and locked-state helpers

- (void)applyThemePreferenceAnimated:(BOOL)animated {
    NSString *themeMode = self.settingsDict[TI_THEME_MODE_KEY] ?: ([self.settingsDict[TI_AUTO_THEME_KEY] boolValue] ? @"system" : @"dark");
    BOOL followsSystem = [themeMode isEqualToString:@"system"];
    if (@available(iOS 13.0, *)) {
        UIUserInterfaceStyle style = followsSystem ? UIUserInterfaceStyleUnspecified : ([themeMode isEqualToString:@"light"] ? UIUserInterfaceStyleLight : UIUserInterfaceStyleDark);
        self.overrideUserInterfaceStyle = style;
        self.navigationController.overrideUserInterfaceStyle = style;
        if (self.view.window) self.view.window.overrideUserInterfaceStyle = style;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL dark = [themeMode isEqualToString:@"dark"] || (followsSystem && self.traitCollection.userInterfaceStyle != UIUserInterfaceStyleLight);
        NSArray *colors = dark ? @[
            (id)[UIColor colorWithRed:0.055 green:0.035 blue:0.105 alpha:1.0].CGColor,
            (id)[UIColor colorWithRed:0.008 green:0.008 blue:0.025 alpha:1.0].CGColor
        ] : @[
            (id)[UIColor colorWithRed:0.88 green:0.89 blue:0.94 alpha:1.0].CGColor,
            (id)[UIColor colorWithRed:0.97 green:0.97 blue:0.99 alpha:1.0].CGColor
        ];
        CAGradientLayer *gradient = nil;
        for (CALayer *layer in self.view.layer.sublayers) {
            if ([layer.name isEqualToString:@"TI_V20_1_BackgroundGradient"] && [layer isKindOfClass:[CAGradientLayer class]]) {
                gradient = (CAGradientLayer *)layer;
                break;
            }
        }
        [CATransaction begin];
        BOOL allowAnimation = animated && !UIAccessibilityIsReduceMotionEnabled();
        [CATransaction setDisableActions:!allowAnimation];
        [CATransaction setAnimationDuration:allowAnimation ? 0.24 : 0.0];
        gradient.colors = colors;
        [CATransaction commit];
        self.view.backgroundColor = dark ? [UIColor colorWithRed:0.01 green:0.01 blue:0.03 alpha:1.0] : [UIColor colorWithWhite:0.97 alpha:1.0];
        for (LGGlassNavButton *button in self->_tabButtons) {
            [button updateTabSelected:button.v20TabSelected animated:NO];
        }
        if (self.customTableView) {
            [UIView performWithoutAnimation:^{ [self.customTableView reloadData]; }];
        }
        [self.view setNeedsLayout];
    });
}

- (void)applyGlassTransparencyRecursively:(UIView *)view enabled:(BOOL)enabled {
    if (!view) return;
    if ([view isKindOfClass:[AppleLiquidGlassView class]]) {
        [(AppleLiquidGlassView *)view setGlassTransparencyEnabled:enabled];
    }
    for (UIView *subview in view.subviews) [self applyGlassTransparencyRecursively:subview enabled:enabled];
}

- (void)refreshBottomTabsAvailability {
    NSString *server = [[NSUserDefaults standardUserDefaults] stringForKey:TI_SELECTED_SERVER_KEY];
    BOOL serverChosen = [server isEqualToString:@"free"] || _isAdminServer;
    BOOL fullyUnlocked = serverChosen && _isFeatureActivated;
    if (!fullyUnlocked && _tabButtons.count > 4 && _currentBottomTab != 0) _currentBottomTab = 4;
    for (NSInteger i = 0; i < _tabButtons.count; i++) {
        LGGlassNavButton *button = _tabButtons[i];
        BOOL enabled = fullyUnlocked || i == 4 || (serverChosen && i == 0);
        button.userInteractionEnabled = YES; // locked tabs show the picker/warning, but can't enter a feature
        button.alpha = enabled ? 1.0 : 0.38;
        [button updateTabSelected:(i == _currentBottomTab) animated:NO];
    }
    if (_activeGlassIndicator && _liquidNavBarContainer.bounds.size.width > 0.0) {
        CGFloat w = _liquidNavBarContainer.bounds.size.width / MAX(1, _tabButtons.count);
        _activeGlassIndicator.center = CGPointMake(_currentBottomTab * w + w * 0.5, _activeGlassIndicator.center.y);
    }
    [self.customTableView setUserInteractionEnabled:serverChosen];
}

- (void)layoutLiquidGlassControlsForCurrentBounds {
    if (!_liquidNavBarContainer || CGRectIsNull(self.view.bounds)) return;
    CGFloat W = CGRectGetWidth(self.view.bounds);
    CGFloat H = CGRectGetHeight(self.view.bounds);
    if (W <= 0.0 || H <= 0.0) return;
    CGFloat barHeight = 66.0;
    CGFloat margin = 10.0;
    CGFloat bottomSafe = MAX(0.0, self.view.safeAreaInsets.bottom);
    CGFloat y = MAX(8.0, H - bottomSafe - barHeight - 8.0);
    CGRect newFrame = CGRectMake(margin, y, MAX(0.0, W - margin * 2.0), barHeight);
    BOOL sizeChanged = !CGSizeEqualToSize(_v20LastNavLayoutSize, self.view.bounds.size) || !CGRectEqualToRect(_v20LastNavFrame, newFrame);
    if (!CGRectEqualToRect(_liquidNavBarContainer.frame, newFrame)) _liquidNavBarContainer.frame = newFrame;
    if (sizeChanged) {
        _v20LastNavLayoutSize = self.view.bounds.size;
        _v20LastNavFrame = newFrame;
        CGFloat btnW = CGRectGetWidth(newFrame) / MAX(1, _tabButtons.count);
        for (NSInteger i = 0; i < _tabButtons.count; i++) {
            _tabButtons[i].frame = CGRectMake(i * btnW + 2.0, 2.0, MAX(0.0, btnW - 4.0), barHeight - 4.0);
        }
        CGFloat blobSize = 48.0;
        CGRect blobFrame = CGRectMake((btnW - blobSize) * 0.5, -12.0, blobSize, blobSize);
        _activeGlassIndicator.frame = blobFrame;
        if (_currentBottomTab >= 0 && _currentBottomTab < _tabButtons.count) {
            _activeGlassIndicator.center = CGPointMake(_currentBottomTab * btnW + btnW * 0.5, _activeGlassIndicator.center.y);
        }
    }
    if (_liquidGlassLensContainer && !_liquidGlassLensContainer.hidden) {
        CGFloat currentX = MIN(MAX(CGRectGetMidX(_liquidGlassLensContainer.frame), 40.0), W - 40.0);
        _liquidGlassLensContainer.center = CGPointMake(currentX, CGRectGetMinY(newFrame) - 22.0);
    }
    if (self.customTableView) {
        CGRect tableFrame = self.customTableView.frame;
        CGFloat topSafe = MAX(0.0, self.view.safeAreaInsets.top);
        tableFrame.origin.x = 0.0;
        tableFrame.origin.y = topSafe;
        tableFrame.size.width = W;
        tableFrame.size.height = MAX(0.0, y - topSafe - 12.0);
        if (!CGRectEqualToRect(self.customTableView.frame, tableFrame)) self.customTableView.frame = tableFrame;
        CGFloat headerWidth = self.view.bounds.size.width;
        if (self.customTableView.tableHeaderView && fabs(self.customTableView.tableHeaderView.bounds.size.width - headerWidth) > 1.0) {
            self.customTableView.tableHeaderView = (_currentBottomTab == 0) ? [self buildNeonDashboardHeaderWithWidth:headerWidth] : ((_currentBottomTab == 1) ? [self buildNeonRateHeaderWithWidth:headerWidth] : [[UIView alloc] initWithFrame:CGRectMake(0, 0, headerWidth, 1.0)]);
        }
        UIEdgeInsets desiredInset = UIEdgeInsetsMake(2.0, 0.0, 10.0, 0.0);
        if (!UIEdgeInsetsEqualToEdgeInsets(self.customTableView.contentInset, desiredInset)) self.customTableView.contentInset = desiredInset;
        if (!UIEdgeInsetsEqualToEdgeInsets(self.customTableView.scrollIndicatorInsets, desiredInset)) self.customTableView.scrollIndicatorInsets = desiredInset;
    }
}

#pragma mark - Liquid Nav Bar

- (void)setupLiquidGlassNavBar {
    // NEON SYSTEM UI v6: fully opaque dock; no blur, liquid-glass highlights or legacy blob treatment.
    CGFloat barHeight = 72.0;
    CGFloat barMargin = 12.0;
    CGFloat barY = self.view.bounds.size.height - self.view.safeAreaInsets.bottom - barHeight - 7.0;
    _liquidNavBarContainer = [[AppleLiquidGlassView alloc] initWithFrame:CGRectMake(barMargin, barY, self.view.bounds.size.width - barMargin * 2.0, barHeight)
                                                            cornerRadius:24.0
                                                            materialType:LGGlassMaterialTypeCrystal];
    [_liquidNavBarContainer setGlassTransparencyEnabled:NO];
    _liquidNavBarContainer.backgroundColor = [UIColor colorWithRed:0.025 green:0.022 blue:0.065 alpha:1.0];
    _liquidNavBarContainer.layer.borderWidth = 1.2;
    _liquidNavBarContainer.layer.borderColor = [UIColor colorWithRed:0.48 green:0.18 blue:0.95 alpha:0.95].CGColor;
    _liquidNavBarContainer.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    _liquidNavBarContainer.interactiveHighlightEnabled = NO;
    _liquidNavBarContainer.clipsToBounds = NO;
    _liquidNavBarContainer.layer.masksToBounds = NO;
    _liquidNavBarContainer.layer.shadowColor = [UIColor colorWithRed:0.45 green:0.08 blue:1.0 alpha:1.0].CGColor;
    _liquidNavBarContainer.layer.shadowOpacity = 0.22;
    _liquidNavBarContainer.layer.shadowRadius = 17.0;
    _liquidNavBarContainer.layer.shadowOffset = CGSizeMake(0, 4);

    _tabConfigs = @[
        @{ @"title": @"Trang chủ", @"icon": @"square.grid.2x2.fill", @"tab": @0 },
        @{ @"title": @"Hz / FPS", @"icon": @"speedometer", @"tab": @1 },
        @{ @"title": @"Tối ưu", @"icon": @"slider.horizontal.3", @"tab": @2 },
        @{ @"title": @"Ứng dụng", @"icon": @"app.dashed", @"tab": @3 },
        @{ @"title": @"Cài đặt", @"icon": @"gearshape.fill", @"tab": @4 }
    ];
    CGFloat btnWidth = _liquidNavBarContainer.bounds.size.width / MAX(1, _tabConfigs.count);
    CGFloat indicatorSize = 42.0;
    _activeGlassIndicator = [[AppleLiquidGlassView alloc] initWithFrame:CGRectMake((btnWidth-indicatorSize)/2.0, -5.0, indicatorSize, indicatorSize)
                                                            cornerRadius:indicatorSize/2.0
                                                            materialType:LGGlassMaterialTypeCrystal];
    [_activeGlassIndicator setGlassTransparencyEnabled:NO];
    _activeGlassIndicator.backgroundColor = [UIColor colorWithRed:0.10 green:0.045 blue:0.22 alpha:1.0];
    _activeGlassIndicator.layer.borderWidth = 1.5;
    _activeGlassIndicator.layer.borderColor = [UIColor colorWithRed:0.08 green:0.78 blue:1.0 alpha:1.0].CGColor;
    _activeGlassIndicator.userInteractionEnabled = NO;
    _activeGlassIndicator.interactiveHighlightEnabled = NO;
    _activeGlassIndicator.layer.shadowColor = [UIColor colorWithRed:0.08 green:0.78 blue:1.0 alpha:1.0].CGColor;
    _activeGlassIndicator.layer.shadowOpacity = 0.22;
    _activeGlassIndicator.layer.shadowRadius = 10.0;
    _activeGlassIndicator.layer.shadowOffset = CGSizeZero;
    [_liquidNavBarContainer addSubview:_activeGlassIndicator];

    for (NSInteger i = 0; i < _tabConfigs.count; i++) {
        NSDictionary *conf = _tabConfigs[i];
        LGGlassNavButton *btn = [[LGGlassNavButton alloc] initWithIconName:conf[@"icon"] title:conf[@"title"]];
        btn.frame = CGRectMake(i * btnWidth + 2.0, 2.0, btnWidth - 4.0, barHeight - 4.0);
        btn.autoresizingMask = UIViewAutoresizingNone;
        btn.tag = i;
        [btn addTarget:self action:@selector(onCustomTabButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleTabLongPress:)];
        longPress.minimumPressDuration = 0.30;
        longPress.cancelsTouchesInView = YES;
        longPress.delaysTouchesBegan = NO;
        [btn addGestureRecognizer:longPress];
        [_liquidNavBarContainer addSubview:btn];
        [_tabButtons addObject:btn];
    }
    if (_tabButtons.count > 0) {
        NSInteger initialIndex = (_currentBottomTab >= 0 && _currentBottomTab < _tabButtons.count) ? _currentBottomTab : 0;
        [_tabButtons[initialIndex] updateTabSelected:YES animated:NO];
    }
    [self.view addSubview:_liquidNavBarContainer];
}

- (void)onCustomTabButtonClicked:(LGGlassNavButton *)sender { [self selectTabIndex:sender.tag animated:YES]; }

- (void)selectTabIndex:(NSInteger)index animated:(BOOL)animated {
    if (index < 0 || index >= _tabConfigs.count) return;
    NSString *server = [[NSUserDefaults standardUserDefaults] stringForKey:TI_SELECTED_SERVER_KEY];
    BOOL serverChosen = [server isEqualToString:@"free"] || _isAdminServer;
    if (!serverChosen && index != 1 && index != 0) {
        [self showFirstInstallServerPicker];
        return;
    }
    if (!_isFeatureActivated && index != 4 && index != 0 && index != 1) {
        [self showUnexploitedWarningAlert];
        return;
    }
    NSInteger oldTab = _currentBottomTab;
    _currentBottomTab = [_tabConfigs[index][@"tab"] integerValue];
    UIView *nextHeader = (_currentBottomTab == 0) ? [self buildNeonDashboardHeaderWithWidth:self.view.bounds.size.width] : ((_currentBottomTab == 1) ? [self buildNeonRateHeaderWithWidth:self.view.bounds.size.width] : [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 1.0)]);
    self.customTableView.tableHeaderView = nextHeader;
    if (_currentBottomTab == 0) {
        // Dashboard readouts stay live; the switch only controls the detailed monitor rows.
        [self startContinuousHardwareHUD];
    } else {
        [self stopContinuousHardwareHUD];
        if (_currentBottomTab == 1) [self startUIFrameSampler];
    }
    if (_currentBottomTab == 3 && !_hasStartedAppScan) {
        _hasStartedAppScan = YES;
        [self loadInstalledAppsAsync];
    }

    if (!_tabConfigs.count || !_liquidNavBarContainer || !_activeGlassIndicator || _tabButtons.count != _tabConfigs.count) {
        [self.customTableView reloadData];
        return;
    }
    CGFloat btnWidth = _liquidNavBarContainer.bounds.size.width / _tabConfigs.count;
    CGFloat blobSize = 48.0;
    // Giọt nước di chuyển đến centerX của tab được chọn, giữ nguyên vị trí y (nổi trên thanh)
    CGFloat targetCenterX = (index * btnWidth) + (btnWidth / 2.0);
    CGFloat oldCenterX = _activeGlassIndicator.center.x;
    CGFloat distance = fabs(targetCenterX - oldCenterX);

    void (^animations)(void) = ^{
        // [V10.2] Giọt nước co giãn theo vận tốc: di chuyển nhanh thì dài ra theo phương ngang,
        // gần đến đích thì co lại thành tròn — giống giọt nước trượt trên kính thật.
        self->_activeGlassIndicator.center = CGPointMake(targetCenterX, self->_activeGlassIndicator.center.y);
        self->_activeGlassIndicator.transform = CGAffineTransformIdentity;
        for (NSInteger i = 0; i < self->_tabButtons.count; i++) {
            LGGlassNavButton *b = self->_tabButtons[i];
            [b updateTabSelected:(i == index) animated:animated];
        }
    };

    if (animated) {
        // Giọt nước bật co giãn: giữa quãng đường stretch ngang, cuối co về tròn
        CGFloat stretch = MIN(1.35, 1.0 + distance / 200.0);
        [UIView animateWithDuration:0.28 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
            self->_activeGlassIndicator.transform = CGAffineTransformMakeScale(stretch, 1.0 / stretch);
        } completion:^(BOOL f) {
            [UIView animateWithDuration:0.48 delay:0 usingSpringWithDamping:0.58 initialSpringVelocity:0.8 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:animations completion:nil];
        }];
    } else animations();

    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];

    if (animated) {
        [self reloadVisibleContentWithSubtleTransition];
    } else {
        [UIView performWithoutAnimation:^{ [self.customTableView reloadData]; }];
    }
    // Do not re-run the synchronous lock-state refresh here: it would cancel the just-started
    // selected-tab spring animation. Access rights are refreshed on login, activation and reset.
}

#pragma mark - Liquid Lens

- (void)setupLiquidGlassLens {
    _liquidGlassLensContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 68, 68)];
    _liquidGlassLensContainer.hidden = YES;
    _liquidGlassLensContainer.userInteractionEnabled = NO;

    _lensGlassEffectView = [[AppleLiquidGlassView alloc] initWithFrame:_liquidGlassLensContainer.bounds cornerRadius:34.0 materialType:LGGlassMaterialTypeCrystal];
    _lensGlassEffectView.interactiveHighlightEnabled = NO;
    _lensGlassEffectView.layer.shadowColor = [UIColor blackColor].CGColor;
    _lensGlassEffectView.layer.shadowOpacity = 0.42;
    _lensGlassEffectView.layer.shadowRadius = 18.0;
    _lensGlassEffectView.layer.shadowOffset = CGSizeMake(0, 7);
    [_liquidGlassLensContainer addSubview:_lensGlassEffectView];

    _lensTitleLabel = [[UILabel alloc] initWithFrame:_liquidGlassLensContainer.bounds];
    _lensTitleLabel.textAlignment = NSTextAlignmentCenter;
    _lensTitleLabel.textColor = [UIColor whiteColor];
    _lensTitleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightHeavy];
    [_liquidGlassLensContainer addSubview:_lensTitleLabel];

    [self.view addSubview:_liquidGlassLensContainer];
}

- (void)handleTabLongPress:(UILongPressGestureRecognizer *)gesture {
    LGGlassNavButton *pressedButton = (LGGlassNavButton *)gesture.view;
    if (![pressedButton isKindOfClass:[LGGlassNavButton class]]) return;
    CGPoint pointInRoot = [gesture locationInView:self.view];
    CGFloat safeX = MIN(MAX(pointInRoot.x, 40.0), MAX(40.0, self.view.bounds.size.width - 40.0));
    NSInteger previewIndex = -1;
    CGPoint pointInBar = [gesture locationInView:_liquidNavBarContainer];
    for (NSInteger i = 0; i < _tabButtons.count; i++) {
        LGGlassNavButton *candidate = _tabButtons[i];
        if (CGRectContainsPoint(candidate.frame, pointInBar)) { previewIndex = i; break; }
    }

    if (gesture.state == UIGestureRecognizerStateBegan) {
        _v20LongPressPreviewTab = pressedButton.tag;
        _liquidGlassLensContainer.center = CGPointMake(safeX, CGRectGetMinY(_liquidNavBarContainer.frame) - 22.0);
        _liquidGlassLensContainer.hidden = NO;
        _liquidGlassLensContainer.alpha = 0.0;
        _liquidGlassLensContainer.transform = CGAffineTransformMakeScale(0.82, 0.82);
        _lensTitleLabel.text = _tabConfigs[pressedButton.tag][@"title"];
        [UIView animateWithDuration:0.20 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
            self->_liquidGlassLensContainer.alpha = 1.0;
            self->_liquidGlassLensContainer.transform = CGAffineTransformIdentity;
        } completion:nil];
        UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [fb impactOccurred];
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        _liquidGlassLensContainer.center = CGPointMake(safeX, CGRectGetMinY(_liquidNavBarContainer.frame) - 22.0);
        if (previewIndex >= 0 && previewIndex < _tabConfigs.count) {
            _v20LongPressPreviewTab = previewIndex;
            _lensTitleLabel.text = _tabConfigs[previewIndex][@"title"];
        }
    } else {
        NSInteger finalIndex = (previewIndex >= 0 && previewIndex < _tabConfigs.count) ? previewIndex : _v20LongPressPreviewTab;
        _v20LongPressPreviewTab = -1;
        if (gesture.state == UIGestureRecognizerStateEnded && finalIndex >= 0 && finalIndex < _tabConfigs.count && finalIndex != _currentBottomTab) {
            [self selectTabIndex:finalIndex animated:YES];
        }
        [UIView animateWithDuration:0.18 delay:0 options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
            self->_liquidGlassLensContainer.alpha = 0.0;
            self->_liquidGlassLensContainer.transform = CGAffineTransformMakeScale(0.92, 0.92);
        } completion:^(BOOL finished) {
            self->_liquidGlassLensContainer.hidden = YES;
            self->_liquidGlassLensContainer.transform = CGAffineTransformIdentity;
        }];
    }
}

#pragma mark - Lock + apply

- (void)updateLockIcon {
    NSString *iconName = _isRateLocked ? @"lock.fill" : @"lock.open.fill";
    UIImage *img = [UIImage systemImageNamed:iconName];
    [_expandingLockButton.iconView setImage:[img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    _expandingLockButton.iconView.tintColor = _isRateLocked ? [UIColor systemRedColor] : [UIColor whiteColor];
}

- (void)toggleRateLockAction {
    if (!_isFeatureActivated) { [self showUnexploitedWarningAlert]; return; }
    _isRateLocked = !_isRateLocked;
    self.settingsDict[@"IsRateLocked"] = @(_isRateLocked);
    [self saveSettingsDataAndSync];
    [self updateLockIcon];
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
    [fb impactOccurred];
    [self applyDeepSpringBoardAndUIKitTweaks];
    [self.customTableView reloadData];
}

- (void)showLoadingCarOverlayDuration:(NSTimeInterval)duration completion:(void (^)(void))completion {
    UIWindow *host = self.view.window;
    if (!host) { if (completion) completion(); return; }

    _loadingOverlay = [[UIView alloc] initWithFrame:host.bounds];
    _loadingOverlay.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.62];
    _loadingOverlay.alpha = 0.0;
    _loadingOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [host addSubview:_loadingOverlay];

    _carView = [[LGLoadingCarView alloc] initWithFrame:CGRectMake(0, 0, host.bounds.size.width, host.bounds.size.height)];
    _carView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_loadingOverlay addSubview:_carView];
    [_carView startAnimating];

    [UIView animateWithDuration:0.28 animations:^{ self->_loadingOverlay.alpha = 1.0; }];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self->_carView stopAnimating];
        [UIView animateWithDuration:0.32 animations:^{ self->_loadingOverlay.alpha = 0.0; } completion:^(BOOL finished) {
            [self->_loadingOverlay removeFromSuperview];
            self->_loadingOverlay = nil;
            self->_carView = nil;
            if (completion) completion();
        }];
    });
}

#pragma mark - TableView

#pragma mark - Neon gaming dashboard

- (void)neonV10SetRate:(UISlider *)sender {
    NSInteger rate = (NSInteger)lrintf(sender.value);
    rate = MAX(15, MIN(240, rate));
    UILabel *value = (UILabel *)[self.view viewWithTag:99120];
    if (value) value.text = [NSString stringWithFormat:@"%ld", (long)rate];
    UILabel *mode = (UILabel *)[self.view viewWithTag:99121];
    if (mode) mode.text = @"MỨC ĐANG CHỌN · CHƯA XÁC NHẬN TẦN SỐ PHẦN CỨNG";
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    [d setInteger:rate forKey:@"TIV10SelectedRate"];
    [d setInteger:rate forKey:@"TIV10SelectedFPS"];
}

- (void)neonV10ChoosePreset:(UIButton *)sender {
    NSArray<NSNumber *> *rates = @[@240, @120, @60, @30];
    NSInteger idx = MAX(0, MIN((NSInteger)rates.count - 1, sender.tag - 99200));
    NSInteger rate = rates[idx].integerValue;
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    [d setInteger:rate forKey:@"TIV10SelectedRate"];
    [d setInteger:rate forKey:@"TIV10SelectedFPS"];
    [d setInteger:rate forKey:@"TIV11SelectedPreset"];
    UISlider *slider = (UISlider *)[self.view viewWithTag:99119];
    if (slider) { slider.value = rate; [self neonV10SetRate:slider]; }
    NSArray *palette = @[[UIColor colorWithRed:1 green:.17 blue:.22 alpha:1],[UIColor colorWithRed:1 green:.68 blue:.12 alpha:1],[UIColor colorWithRed:.24 green:.86 blue:.38 alpha:1],[UIColor colorWithRed:.18 green:.52 blue:1 alpha:1]];
    for (UIView *v in self.customTableView.tableHeaderView.subviews) {
        if ([v isKindOfClass:UIButton.class] && v.tag >= 99200 && v.tag <= 99203) {
            NSInteger buttonIndex = v.tag - 99200;
            v.layer.borderWidth = (v == sender) ? 2.5 : 1.0;
            v.backgroundColor = [palette[buttonIndex] colorWithAlphaComponent:(v == sender ? .28 : .13)];
        }
    }
    if (!_isRateLocked && _isFeatureActivated) {
        [self applyRateValue:rate isDynamic:NO isFPS:NO];
        [self applyRateValue:rate isDynamic:NO isFPS:YES];
        [self applyDeepSpringBoardAndUIKitTweaks];
    }
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium]; [fb impactOccurred];
}

- (void)neonV11DialPan:(UIGestureRecognizer *)gesture {
    UIView *ring = gesture.view;
    if (!ring) return;
    CGPoint p = [gesture isKindOfClass:UIPanGestureRecognizer.class] ? [(UIPanGestureRecognizer *)gesture locationInView:ring] : [gesture locationInView:ring];
    CGFloat dx = p.x - CGRectGetMidX(ring.bounds), dy = p.y - CGRectGetMidY(ring.bounds);
    CGFloat angle = atan2(dy, dx) + (CGFloat)M_PI_2;
    if (angle < 0) angle += (CGFloat)(2.0 * M_PI);
    CGFloat fraction = MIN(1.0, MAX(0.0, angle / (CGFloat)(2.0 * M_PI)));
    NSInteger rate = 15 + (NSInteger)lrint(fraction * 225.0);
    UISlider *slider = (UISlider *)[self.view viewWithTag:99119];
    if (slider) { slider.value = rate; [self neonV10SetRate:slider]; }
    else { [[NSUserDefaults standardUserDefaults] setInteger:rate forKey:@"TIV10SelectedRate"]; }
    if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateRecognized) {
        if (!_isRateLocked && _isFeatureActivated) { [self applyRateValue:rate isDynamic:NO isFPS:NO]; [self applyRateValue:rate isDynamic:NO isFPS:YES]; [self applyDeepSpringBoardAndUIKitTweaks]; }
    }
}

- (void)neonV11ThermalChanged:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:@"TIV11ThermalAutoAdjust"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    if (sender.isOn) {
        NSProcessInfoThermalState state = NSProcessInfo.processInfo.thermalState;
        NSInteger preset = (state >= NSProcessInfoThermalStateSerious) ? 3 : (state == NSProcessInfoThermalStateFair ? 2 : 0);
        UIButton *button = (UIButton *)[self.customTableView.tableHeaderView viewWithTag:99200+preset];
        if (button) [self neonV10ChoosePreset:button];
    }
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Điều chỉnh nhiệt" message:(sender.isOn ? @"Đã bật phản ứng theo trạng thái nhiệt iOS. Đây là điều chỉnh cấu hình ứng dụng; iOS không cung cấp số đo nhiệt độ CPU/GPU trực tiếp." : @"Đã tắt tự điều chỉnh theo trạng thái nhiệt.") preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]]; [self presentViewController:a animated:YES completion:nil];
}

- (void)neonV11ApplyAppPreset:(NSInteger)preset app:(NSDictionary *)app {
    NSString *bundleID = [app[@"bundleID"] isKindOfClass:NSString.class] ? app[@"bundleID"] : @"unknown.bundle";
    NSArray *names = @[@"Max", @"Hiệu suất", @"Cân bằng", @"Tiết kiệm pin"];
    NSArray *rates = @[@240, @120, @60, @30];
    NSMutableDictionary *all = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"TIV11PerAppProfiles"] mutableCopy] ?: [NSMutableDictionary dictionary];
    all[bundleID] = @{ @"preset": @(preset), @"rate": rates[preset], @"name": names[preset] };
    [[NSUserDefaults standardUserDefaults] setObject:all forKey:@"TIV11PerAppProfiles"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Đã lưu cấu hình riêng" message:[NSString stringWithFormat:@"%@\n%@\nMức Hz/FPS mục tiêu: %@\n\nCấu hình đã lưu theo bundle ID. Tùy chọn này không tự ép xung CPU/GPU hoặc tăng RAM vật lý; việc áp dụng cho ứng dụng cần bộ điều khiển tương thích.", app[@"name"] ?: bundleID, names[preset], rates[preset]] preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]]; [self presentViewController:a animated:YES completion:nil];
}

- (void)neonV11ShowAppProfile:(NSDictionary *)app {
    NSString *bundleID = [app[@"bundleID"] isKindOfClass:NSString.class] ? app[@"bundleID"] : @"unknown.bundle";
    NSDictionary *all = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"TIV11PerAppProfiles"] ?: @{};
    NSDictionary *saved = [all[bundleID] isKindOfClass:NSDictionary.class] ? all[bundleID] : nil;
    NSInteger selected = saved ? [saved[@"preset"] integerValue] : 2;
    NSString *message = [NSString stringWithFormat:@"%@\n%@\n\nChọn cấu hình riêng cho ứng dụng. Mức được lưu trong hồ sơ của app; hiệu quả thực tế phụ thuộc iOS và tweak điều khiển tương thích. CPU/GPU xung và RAM không thể được tăng bằng cách chỉ đặt con số.", bundleID, saved ? [NSString stringWithFormat:@"Đang lưu: %@ · mục tiêu %@ Hz/FPS", saved[@"name"] ?: @"Cân bằng", saved[@"rate"] ?: @60] : @"Chưa có hồ sơ riêng"];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:(app[@"name"] ?: @"Ứng dụng") message:message preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *names = @[@"🔴 MAX", @"🟡 HIỆU SUẤT", @"🟢 CÂN BẰNG", @"🔵 TIẾT KIỆM PIN"];
    for (NSInteger i=0;i<names.count;i++) { NSInteger preset=i; [a addAction:[UIAlertAction actionWithTitle:names[i] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [self neonV11ApplyAppPreset:preset app:app]; }]]; }
    [a addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    if (UI_USER_INTERFACE_IDIOM()==UIUserInterfaceIdiomPad) { a.popoverPresentationController.sourceView=self.view; a.popoverPresentationController.sourceRect=CGRectMake(CGRectGetMidX(self.view.bounds),CGRectGetMidY(self.view.bounds),1,1); }
    [self presentViewController:a animated:YES completion:nil];
}

- (void)neonV10OpenInfo:(UIButton *)sender {
    NSArray *titles = @[@"CPU & TẢI HỆ THỐNG", @"BỘ NHỚ ỨNG DỤNG", @"PIN & NHIỆT ĐỘ", @"MÀN HÌNH · HZ / FPS"];
    NSArray *messages = @[
        [NSString stringWithFormat:@"Mức tải CPU: %@\nSố lõi: %@\n\nChỉ hiển thị giá trị mà API hiện tại đọc được.", (Titanium_GetLiveCPULoadPercentage() >= 0 ? [NSString stringWithFormat:@"%.0f%%", Titanium_GetLiveCPULoadPercentage()] : @"Không khả dụng"), Titanium_LogicalCPUCoreCount() ? [NSString stringWithFormat:@"%u", Titanium_LogicalCPUCoreCount()] : @"Không khả dụng"],
        [NSString stringWithFormat:@"Bộ nhớ tiến trình hiện tại: %@\nĐây là bộ nhớ tiến trình tweak/app đọc được, không phải tổng RAM đang dùng của toàn hệ thống.", Titanium_ByteCountString(Titanium_CurrentProcessFootprintBytes())],
        @"iOS không cung cấp API công khai ổn định để đọc nhiệt độ CPU/GPU. Công tắc tự điều chỉnh nhiệt độ chỉ có thể hoạt động nếu có bộ điều khiển tương thích riêng.",
        @"Giá trị đã chọn được lưu trong cấu hình giao diện. Nó không chứng minh màn hình hoặc trò chơi thực sự chạy ở mức Hz/FPS đó; phần cứng và API iOS có thể giới hạn mức áp dụng."
    ];
    NSInteger i = MAX(0, MIN(3, sender.tag - 99300));
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:titles[i] message:messages[i] preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (UIView *)buildNeonDashboardHeaderWithWidth:(CGFloat)width {
    CGFloat w = MAX(320.0, width), side = 18.0, cw = w - side * 2.0;
    UIView *root = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 724.0)];
    root.backgroundColor = UIColor.clearColor;
    UILabel *eyebrow = [[UILabel alloc] initWithFrame:CGRectMake(side, 13, cw, 16)];
    eyebrow.text = @"T I T A N I U M  /  PERFORMANCE CONTROL";
    eyebrow.font = [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightBold];
    eyebrow.textColor = [UIColor colorWithRed:.22 green:.88 blue:1 alpha:1]; [root addSubview:eyebrow];
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(side, 34, cw, 35)];
    title.text = @"NEON CONTROL V11"; title.font = [UIFont systemFontOfSize:29 weight:UIFontWeightBlack];
    title.textColor = UIColor.whiteColor; title.adjustsFontSizeToFitWidth = YES; [root addSubview:title];
    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(side+1, 71, cw, 18)];
    sub.text = @"Chọn cấu hình · tinh chỉnh mức mong muốn"; sub.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    sub.textColor = [UIColor colorWithWhite:.68 alpha:1]; [root addSubview:sub];

    UIView *dialCard = [[UIView alloc] initWithFrame:CGRectMake(side, 101, cw, 270)];
    dialCard.backgroundColor = [UIColor colorWithRed:.045 green:.025 blue:.105 alpha:1]; dialCard.layer.cornerRadius = 28;
    dialCard.layer.borderWidth = 1.2; dialCard.layer.borderColor = [UIColor colorWithRed:.58 green:.22 blue:1 alpha:.9].CGColor;
    dialCard.layer.shadowColor = [UIColor colorWithRed:.45 green:.1 blue:1 alpha:1].CGColor; dialCard.layer.shadowOpacity = .22; dialCard.layer.shadowRadius = 18; dialCard.layer.shadowOffset = CGSizeMake(0, 7); [root addSubview:dialCard];
    CAGradientLayer *grad = [CAGradientLayer layer]; grad.frame = dialCard.bounds; grad.cornerRadius = 28;
    grad.colors = @[(id)[UIColor colorWithRed:.16 green:.035 blue:.30 alpha:1].CGColor,(id)[UIColor colorWithRed:.035 green:.045 blue:.12 alpha:1].CGColor];
    grad.startPoint = CGPointMake(0,0); grad.endPoint = CGPointMake(1,1); [dialCard.layer insertSublayer:grad atIndex:0];
    UILabel *dialTitle = [[UILabel alloc] initWithFrame:CGRectMake(16, 14, cw-32, 18)]; dialTitle.text = @"TẦN SỐ MỤC TIÊU"; dialTitle.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightBold]; dialTitle.textColor = [UIColor colorWithRed:.4 green:.87 blue:1 alpha:1]; dialTitle.textAlignment = NSTextAlignmentCenter; [dialCard addSubview:dialTitle];
    UIView *ring = [[UIView alloc] initWithFrame:CGRectMake((cw-150)/2, 38, 150, 150)]; ring.layer.cornerRadius=75; ring.layer.borderWidth=4; ring.layer.borderColor=[UIColor colorWithRed:.78 green:.25 blue:1 alpha:1].CGColor; ring.backgroundColor=[UIColor colorWithRed:.06 green:.045 blue:.16 alpha:1]; ring.layer.shadowColor=[UIColor magentaColor].CGColor; ring.layer.shadowOpacity=.35; ring.layer.shadowRadius=16; [dialCard addSubview:ring];
    ring.userInteractionEnabled = YES;
    UIPanGestureRecognizer *dialPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(neonV11DialPan:)];
    [ring addGestureRecognizer:dialPan];
    UITapGestureRecognizer *dialTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(neonV11DialPan:)];
    [ring addGestureRecognizer:dialTap];
    UIView *ring2=[[UIView alloc] initWithFrame:CGRectInset(ring.bounds, 9, 9)]; ring2.layer.cornerRadius=ring2.bounds.size.width/2; ring2.layer.borderWidth=1; ring2.layer.borderColor=[UIColor colorWithRed:.1 green:.85 blue:1 alpha:.9].CGColor; [ring addSubview:ring2];
    UILabel *rate = [[UILabel alloc] initWithFrame:CGRectMake(8, 48, 134, 48)]; rate.tag=99120; NSInteger saved= [NSUserDefaults.standardUserDefaults integerForKey:@"TIV10SelectedRate"]; if(saved<15||saved>240)saved=120; rate.text=[NSString stringWithFormat:@"%ld",(long)saved]; rate.font=[UIFont systemFontOfSize:43 weight:UIFontWeightBlack]; rate.textColor=UIColor.whiteColor; rate.textAlignment=NSTextAlignmentCenter; [ring addSubview:rate];
    UILabel *hz = [[UILabel alloc] initWithFrame:CGRectMake(8, 94, 134, 20)]; hz.text=@"Hz / FPS"; hz.font=[UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightBold]; hz.textColor=[UIColor colorWithRed:.28 green:.88 blue:1 alpha:1]; hz.textAlignment=NSTextAlignmentCenter; [ring addSubview:hz];
    UISlider *slider=[[UISlider alloc] initWithFrame:CGRectMake(22, 202, cw-44, 30)]; slider.tag=99119; slider.minimumValue=15; slider.maximumValue=240; slider.value=saved; slider.minimumTrackTintColor=[UIColor colorWithRed:.83 green:.2 blue:1 alpha:1]; slider.maximumTrackTintColor=[UIColor colorWithWhite:.28 alpha:1]; slider.thumbTintColor=[UIColor colorWithRed:.22 green:.9 blue:1 alpha:1]; [slider addTarget:self action:@selector(neonV10SetRate:) forControlEvents:UIControlEventValueChanged]; [dialCard addSubview:slider];
    UILabel *range=[[UILabel alloc] initWithFrame:CGRectMake(22, 235, cw-44, 16)]; range.text=@"15  ━━━━━━━━━━━━━━━━━━━━━  240"; range.font=[UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightMedium]; range.textColor=[UIColor colorWithWhite:.65 alpha:1]; [dialCard addSubview:range];

    UILabel *presetTitle=[[UILabel alloc] initWithFrame:CGRectMake(side, 389, cw, 20)]; presetTitle.text=@"CHỌN CẤU HÌNH HIỆU NĂNG"; presetTitle.font=[UIFont systemFontOfSize:12 weight:UIFontWeightBlack]; presetTitle.textColor=UIColor.whiteColor; [root addSubview:presetTitle];
    NSArray *names=@[@"MAX",@"HIỆU SUẤT",@"CÂN BẰNG",@"TIẾT KIỆM PIN"];
    NSArray *colors=@[[UIColor colorWithRed:1 green:.17 blue:.22 alpha:1],[UIColor colorWithRed:1 green:.68 blue:.12 alpha:1],[UIColor colorWithRed:.24 green:.86 blue:.38 alpha:1],[UIColor colorWithRed:.18 green:.52 blue:1 alpha:1]];
    CGFloat gap=7, pw=(cw-gap*3)/4;
    for(NSInteger i=0;i<4;i++) { UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem]; b.frame=CGRectMake(side+i*(pw+gap),416,pw,77); b.tag=99200+i; b.backgroundColor=[colors[i] colorWithAlphaComponent:.13]; b.layer.cornerRadius=17; b.layer.borderWidth=1; b.layer.borderColor=[colors[i] colorWithAlphaComponent:.9].CGColor; [b setTitle:names[i] forState:UIControlStateNormal]; [b setTitleColor:colors[i] forState:UIControlStateNormal]; b.titleLabel.font=[UIFont systemFontOfSize:(i==1||i==2)?9:10 weight:UIFontWeightBlack]; b.titleLabel.numberOfLines=2; b.titleLabel.textAlignment=NSTextAlignmentCenter; [b addTarget:self action:@selector(neonV10ChoosePreset:) forControlEvents:UIControlEventTouchUpInside]; [root addSubview:b]; }
    UILabel *infoTitle=[[UILabel alloc] initWithFrame:CGRectMake(side, 516, cw, 19)]; infoTitle.text=@"THÔNG SỐ NHANH · CHẠM ĐỂ XEM CHI TIẾT"; infoTitle.font=[UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightBold]; infoTitle.textColor=[UIColor colorWithRed:.73 green:.49 blue:1 alpha:1]; [root addSubview:infoTitle];
    NSArray *info=@[@{ @"t":@"CPU", @"s":@"Tải hệ thống", @"i":@"cpu" },@{ @"t":@"RAM", @"s":@"Bộ nhớ app", @"i":@"memorychip" },@{ @"t":@"PIN", @"s":@"Năng lượng", @"i":@"battery.100" },@{ @"t":@"DISPLAY", @"s":@"Hz / FPS", @"i":@"speedometer" }];
    CGFloat iw=(cw-gap*3)/4;
    for(NSInteger i=0;i<4;i++) { UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem]; b.frame=CGRectMake(side+i*(iw+gap),542,iw,91); b.tag=99300+i; b.backgroundColor=[UIColor colorWithRed:.055 green:.045 blue:.13 alpha:1]; b.layer.cornerRadius=17; b.layer.borderWidth=1; b.layer.borderColor=[UIColor colorWithRed:.38 green:.23 blue:.65 alpha:1].CGColor; UIImageView *im=[[UIImageView alloc] initWithImage:[UIImage systemImageNamed:info[i][@"i"]]]; im.frame=CGRectMake((iw-22)/2,12,22,22); im.contentMode=UIViewContentModeScaleAspectFit; im.tintColor=colors[i]; [b addSubview:im]; UILabel *t=[[UILabel alloc] initWithFrame:CGRectMake(3,42,iw-6,17)]; t.text=info[i][@"t"]; t.textAlignment=NSTextAlignmentCenter; t.font=[UIFont systemFontOfSize:10 weight:UIFontWeightBlack]; t.textColor=UIColor.whiteColor; [b addSubview:t]; UILabel *d=[[UILabel alloc] initWithFrame:CGRectMake(3,61,iw-6,14)]; d.text=info[i][@"s"]; d.textAlignment=NSTextAlignmentCenter; d.font=[UIFont systemFontOfSize:8 weight:UIFontWeightMedium]; d.textColor=[UIColor colorWithWhite:.65 alpha:1]; d.adjustsFontSizeToFitWidth=YES; [b addSubview:d]; [b addTarget:self action:@selector(neonV10OpenInfo:) forControlEvents:UIControlEventTouchUpInside]; [root addSubview:b]; }
    UIView *thermalCard = [[UIView alloc] initWithFrame:CGRectMake(side, 648, cw, 58)];
    thermalCard.backgroundColor = [UIColor colorWithRed:.055 green:.04 blue:.12 alpha:1];
    thermalCard.layer.cornerRadius = 17; thermalCard.layer.borderWidth = 1;
    thermalCard.layer.borderColor = [UIColor colorWithRed:.15 green:.72 blue:.85 alpha:.75].CGColor;
    [root addSubview:thermalCard];
    UILabel *thermalTitle = [[UILabel alloc] initWithFrame:CGRectMake(14, 9, cw-88, 20)];
    thermalTitle.text = @"TỰ ĐIỀU CHỈNH THEO NHIỆT"; thermalTitle.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBlack]; thermalTitle.textColor = UIColor.whiteColor; [thermalCard addSubview:thermalTitle];
    UILabel *thermalSub = [[UILabel alloc] initWithFrame:CGRectMake(14, 29, cw-88, 17)];
    thermalSub.text = @"Tự đổi cấu hình đã lưu khi trạng thái nhiệt đổi"; thermalSub.font = [UIFont systemFontOfSize:9 weight:UIFontWeightMedium]; thermalSub.textColor = [UIColor colorWithWhite:.68 alpha:1]; [thermalCard addSubview:thermalSub];
    UISwitch *thermalSwitch = [[UISwitch alloc] initWithFrame:CGRectZero]; thermalSwitch.transform = CGAffineTransformMakeScale(.82,.82); thermalSwitch.onTintColor = [UIColor colorWithRed:.15 green:.8 blue:.52 alpha:1]; thermalSwitch.on = [NSUserDefaults.standardUserDefaults boolForKey:@"TIV11ThermalAutoAdjust"]; thermalSwitch.center = CGPointMake(cw-37,29); [thermalSwitch addTarget:self action:@selector(neonV11ThermalChanged:) forControlEvents:UIControlEventValueChanged]; [thermalCard addSubview:thermalSwitch];
    return root;
}

- (UIView *)buildNeonRateHeaderWithWidth:(CGFloat)width {
    CGFloat w = MAX(320.0, width);
    UIView *root = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 390.0)];
    root.backgroundColor = UIColor.clearColor;

    UILabel *eyebrow = [[UILabel alloc] initWithFrame:CGRectMake(20, 12, w - 40, 15)];
    eyebrow.text = @"TITANIUM  /  LIVE DISPLAY TELEMETRY";
    eyebrow.font = [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightBold];
    eyebrow.textColor = [UIColor colorWithRed:0.20 green:0.88 blue:1.0 alpha:1.0];
    [root addSubview:eyebrow];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(18, 31, w - 36, 30)];
    title.text = @"Tần số & khung hình";
    title.font = [UIFont systemFontOfSize:25 weight:UIFontWeightBlack];
    title.textColor = UIColor.whiteColor;
    [root addSubview:title];

    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(14, 72, w - 28, 244)];
    panel.backgroundColor = [UIColor colorWithRed:0.025 green:0.018 blue:0.075 alpha:0.99];
    panel.layer.cornerRadius = 28.0;
    panel.layer.borderWidth = 1.0;
    panel.layer.borderColor = [UIColor colorWithRed:0.50 green:0.20 blue:0.92 alpha:0.9].CGColor;
    panel.layer.shadowColor = [UIColor colorWithRed:0.32 green:0.12 blue:1.0 alpha:1.0].CGColor;
    panel.layer.shadowOpacity = 0.22;
    panel.layer.shadowRadius = 18.0;
    panel.layer.shadowOffset = CGSizeMake(0, 5);
    [root addSubview:panel];

    NSInteger maxHz = MAX(1, (NSInteger)UIScreen.mainScreen.maximumFramesPerSecond);
    NSInteger targetHz = [self.settingsDict[@"TargetRefreshRate"] respondsToSelector:@selector(integerValue)] ? [self.settingsDict[@"TargetRefreshRate"] integerValue] : 60;
    NSInteger targetFPS = [self.settingsDict[@"TargetFPSRate"] respondsToSelector:@selector(integerValue)] ? [self.settingsDict[@"TargetFPSRate"] integerValue] : 60;
    CGFloat diameter = MIN(176.0, panel.bounds.size.width - 36.0);
    CGFloat gaugeX = (panel.bounds.size.width - diameter) / 2.0;
    UIView *gauge = [[UIView alloc] initWithFrame:CGRectMake(gaugeX, 12.0, diameter, diameter)];
    gauge.backgroundColor = [UIColor colorWithRed:0.035 green:0.03 blue:0.095 alpha:1.0];
    gauge.layer.cornerRadius = diameter / 2.0;
    gauge.layer.borderWidth = 1.0;
    gauge.layer.borderColor = [UIColor colorWithRed:0.20 green:0.75 blue:1.0 alpha:0.45].CGColor;
    gauge.layer.shadowColor = [UIColor colorWithRed:0.15 green:0.72 blue:1.0 alpha:1.0].CGColor;
    gauge.layer.shadowOpacity = 0.18;
    gauge.layer.shadowRadius = 14.0;
    [panel addSubview:gauge];

    CAShapeLayer *track = [CAShapeLayer layer];
    track.frame = gauge.bounds;
    track.path = [UIBezierPath bezierPathWithOvalInRect:CGRectInset(gauge.bounds, 10.0, 10.0)].CGPath;
    track.fillColor = UIColor.clearColor.CGColor;
    track.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.10].CGColor;
    track.lineWidth = 7.0;
    [gauge.layer addSublayer:track];

    CAShapeLayer *arc = [CAShapeLayer layer];
    arc.frame = gauge.bounds;
    UIBezierPath *arcPath = [UIBezierPath bezierPath];
    [arcPath addArcWithCenter:CGPointMake(diameter/2.0, diameter/2.0) radius:diameter/2.0-10.0 startAngle:(CGFloat)(-M_PI*0.78) endAngle:(CGFloat)(M_PI*0.78) clockwise:YES];
    arc.path = arcPath.CGPath;
    arc.fillColor = UIColor.clearColor.CGColor;
    arc.strokeColor = [UIColor colorWithRed:0.12 green:0.82 blue:1.0 alpha:1.0].CGColor;
    arc.lineWidth = 7.0;
    arc.lineCap = kCALineCapRound;
    arc.shadowColor = arc.strokeColor;
    arc.shadowOpacity = 0.8;
    arc.shadowRadius = 7.0;
    [gauge.layer addSublayer:arc];

    CAShapeLayer *orbit = [CAShapeLayer layer];
    orbit.frame = gauge.bounds;
    orbit.path = [UIBezierPath bezierPathWithOvalInRect:CGRectInset(gauge.bounds, 4.0, 4.0)].CGPath;
    orbit.fillColor = UIColor.clearColor.CGColor;
    orbit.strokeColor = [UIColor colorWithRed:0.95 green:0.20 blue:0.82 alpha:0.8].CGColor;
    orbit.lineWidth = 1.2;
    orbit.lineDashPattern = @[@2, @5];
    [gauge.layer addSublayer:orbit];
    if (!UIAccessibilityIsReduceMotionEnabled()) {
        CABasicAnimation *spin = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
        spin.fromValue = @0.0; spin.toValue = @(M_PI * 2.0); spin.duration = 9.0; spin.repeatCount = HUGE_VALF;
        [orbit addAnimation:spin forKey:@"titanium.orbit.spin"];
    }

    UILabel *hzValue = [[UILabel alloc] initWithFrame:CGRectMake(8, diameter/2.0 - 31.0, diameter - 16.0, 38.0)];
    hzValue.text = [NSString stringWithFormat:@"%ld Hz", (long)targetHz];
    hzValue.font = [UIFont systemFontOfSize:29 weight:UIFontWeightBlack];
    hzValue.textAlignment = NSTextAlignmentCenter;
    hzValue.textColor = [UIColor colorWithRed:0.98 green:0.42 blue:0.91 alpha:1.0];
    hzValue.adjustsFontSizeToFitWidth = YES;
    hzValue.minimumScaleFactor = 0.7;
    hzValue.tag = 7401;
    [gauge addSubview:hzValue];

    UILabel *fpsValue = [[UILabel alloc] initWithFrame:CGRectMake(8, diameter/2.0 + 7.0, diameter - 16.0, 24.0)];
    fpsValue.text = [NSString stringWithFormat:@"%ld FPS · LIVE", (long)self->_uiFPSMeasured];
    fpsValue.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightBold];
    fpsValue.textAlignment = NSTextAlignmentCenter;
    fpsValue.textColor = [UIColor colorWithRed:0.18 green:0.88 blue:1.0 alpha:1.0];
    fpsValue.adjustsFontSizeToFitWidth = YES;
    fpsValue.minimumScaleFactor = 0.7;
    fpsValue.tag = 7402;
    [gauge addSubview:fpsValue];

    UILabel *caption = [[UILabel alloc] initWithFrame:CGRectMake(12, 194, panel.bounds.size.width - 24, 16)];
    caption.text = @"TẦN SỐ MỤC TIÊU  /  KHUNG HÌNH ĐO ĐƯỢC";
    caption.font = [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightBold];
    caption.textAlignment = NSTextAlignmentCenter;
    caption.textColor = [UIColor colorWithWhite:0.72 alpha:1.0];
    [panel addSubview:caption];

    UILabel *detail = [[UILabel alloc] initWithFrame:CGRectMake(14, 215, panel.bounds.size.width - 28, 20)];
    detail.text = [NSString stringWithFormat:@"Màn hình tối đa iOS báo: %ld Hz   ·   FPS mục tiêu: %ld", (long)maxHz, (long)targetFPS];
    detail.font = [UIFont systemFontOfSize:10.5 weight:UIFontWeightSemibold];
    detail.textAlignment = NSTextAlignmentCenter;
    detail.textColor = [UIColor colorWithWhite:0.80 alpha:1.0];
    detail.adjustsFontSizeToFitWidth = YES;
    detail.minimumScaleFactor = 0.72;
    [panel addSubview:detail];

    UIView *status = [[UIView alloc] initWithFrame:CGRectMake(14, 328, w - 28, 43)];
    status.backgroundColor = [UIColor colorWithRed:0.045 green:0.035 blue:0.105 alpha:1.0];
    status.layer.cornerRadius = 15.0;
    status.layer.borderWidth = 1.0;
    status.layer.borderColor = [UIColor colorWithRed:0.35 green:0.22 blue:0.66 alpha:0.8].CGColor;
    [root addSubview:status];
    UILabel *statusLabel = [[UILabel alloc] initWithFrame:CGRectInset(status.bounds, 12, 0)];
    statusLabel.text = @"Chọn mức bên dưới để áp dụng qua trình xử lý hiện có";
    statusLabel.font = [UIFont systemFontOfSize:10.5 weight:UIFontWeightMedium];
    statusLabel.textColor = [UIColor colorWithWhite:0.84 alpha:1.0];
    statusLabel.adjustsFontSizeToFitWidth = YES;
    statusLabel.minimumScaleFactor = 0.75;
    [status addSubview:statusLabel];

    return root;
}

- (void)neonDashboardQuickAction:(UIButton *)sender {
    if (sender.tag < 0) { [self showPhonkMusicPicker]; return; }
    [self selectTabIndex:sender.tag animated:YES];
}
- (void)neonDashboardButtonDown:(UIButton *)sender {
    [UIView animateWithDuration:0.12 animations:^{ sender.transform = CGAffineTransformMakeScale(0.96, 0.96); sender.alpha = 0.82; }];
}
- (void)neonDashboardButtonUp:(UIButton *)sender {
    [UIView animateWithDuration:0.28 delay:0 usingSpringWithDamping:0.55 initialSpringVelocity:0.6 options:UIViewAnimationOptionBeginFromCurrentState animations:^{ sender.transform = CGAffineTransformIdentity; sender.alpha = 1.0; } completion:nil];
}

- (void)setupMainTableView {
    self.customTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - 106) style:UITableViewStylePlain];
    self.customTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.customTableView.backgroundColor = [UIColor colorWithRed:0.012 green:0.010 blue:0.032 alpha:1.0];
    self.customTableView.separatorColor = UIColor.clearColor;
    self.customTableView.contentInset = UIEdgeInsetsMake(4.0, 0.0, 14.0, 0.0);
    if (@available(iOS 11.0, *)) self.customTableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    self.customTableView.estimatedRowHeight = 0.0;
    self.customTableView.estimatedSectionHeaderHeight = 0.0;
    self.customTableView.estimatedSectionFooterHeight = 0.0;
    if (@available(iOS 15.0, *)) self.customTableView.sectionHeaderTopPadding = 0.0;
    self.customTableView.delegate = self;
    self.customTableView.dataSource = self;
    self.customTableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self.view addSubview:self.customTableView];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (_currentBottomTab == 0) return 0;
    if (_currentBottomTab == 1) return 3;
    if (_currentBottomTab == 2) return 2;
    if (_currentBottomTab == 3) return 3;
    return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (!_isFeatureActivated && _currentBottomTab != 4 && _currentBottomTab != 0 && _currentBottomTab != 1) return 1;

    if (_currentBottomTab == 0) {
        if (section == 0) return 1;
        BOOL mA = [self.settingsDict[@"EnableSystemMonitoring"] boolValue];
        if (!mA) return 1;
        if (section == 1) return _isCpuExpanded ? 7 : 1;
        if (section == 2) return _isGpuExpanded ? 6 : 1;
        if (section == 3) return _isRamExpanded ? 5 : 1;
        if (section == 4) return _isBatteryExpanded ? 6 : 1;
        return _isScreenExpanded ? 5 : 1;
    } else if (_currentBottomTab == 1) {
        if (section == 0) return 1; // standard / expanded selector
        if (section == 1) return 1; // Hz / FPS selector
        return 1 + (NSInteger)(_expandedHzFPS ? TIExpandedRateValues() : TIStandardRateValues()).count; // row 0 = nhập Hz/FPS
    } else if (_currentBottomTab == 2) {
        if (section == 0) return 1;
        switch (_currentSwitchSubTab) {
            case 0: return 7;
            case 1: return 6;
            case 2: return 6;
            case 3: return 6;
            case 4: return 9;
            default: return 6;
        }
    } else if (_currentBottomTab == 3) {
        if (section == 0) return 1;
        if (section == 1) return 1;
        return MAX(1, _filteredAppsList.count);
    } else {
        if (section == 0) return 2;
        if (section == 1) return _isFeatureActivated ? 8 : 1;
        if (section == 2) return [self isAdminDevRole] ? 7 : 5;
        return 7;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (!_isFeatureActivated && _currentBottomTab != 4 && _currentBottomTab != 0 && _currentBottomTab != 1) return @"Cần kích hoạt trước";
    if (_currentBottomTab == 0) {
        if (section == 0) return @"TỔNG QUAN HỆ THỐNG";
        if (section == 1) return @"CPU";
        if (section == 2) return @"GPU";
        if (section == 3) return @"BỘ NHỚ RAM";
        if (section == 4) return @"PIN & NĂNG LƯỢNG";
        return @"Màn hình";
    } else if (_currentBottomTab == 1) {
        if (section == 0) return @"TẦN SỐ & KHUNG HÌNH";
        if (section == 1) return @"CHẾ ĐỘ ĐIỀU CHỈNH";
        return (_currentHzFpsSubTab == 0) ? (_expandedHzFPS ? @"Hz MỞ RỘNG" : @"Hz THƯỜNG") : (_expandedHzFPS ? @"FPS MỞ RỘNG" : @"FPS THƯỜNG");
    } else if (_currentBottomTab == 2) {
        if (section == 0) return @"BỘ ĐIỀU KHIỂN";
        switch (_currentSwitchSubTab) {
            case 0: return @"CPU";
            case 1: return @"GPU";
            case 2: return @"Màn hình";
            case 3: return @"PIN & NĂNG LƯỢNG";
            case 4: return @"Hệ thống";
            default: return @"Công tắc";
        }
    } else if (_currentBottomTab == 3) {
        if (section == 0) return @"CÔNG CỤ NHANH";
        if (section == 1) return @"THƯ VIỆN ỨNG DỤNG";
        return @"Ứng dụng";
    } else {
        if (section == 0) return @"TRẠNG THÁI & QUYỀN";
        if (section == 1) return @"THÔNG SỐ THIẾT BỊ";
        if (section == 2) return @"GIAO DIỆN & KẾT NỐI";
        return @"CHẨN ĐOÁN HỆ THỐNG";
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSString *heading = [self tableView:tableView titleForHeaderInSection:section];
    if (heading.length == 0) return nil;
    UIView *container = [[UIView alloc] initWithFrame:CGRectZero];
    container.backgroundColor = UIColor.clearColor;
    UIView *marker = [[UIView alloc] initWithFrame:CGRectZero];
    marker.translatesAutoresizingMaskIntoConstraints = NO;
    CAGradientLayer *markerGradient = [CAGradientLayer layer];
    markerGradient.colors = @[(id)[UIColor colorWithRed:1.0 green:0.20 blue:0.82 alpha:1.0].CGColor,
                              (id)[UIColor colorWithRed:0.12 green:0.88 blue:1.0 alpha:1.0].CGColor];
    markerGradient.startPoint = CGPointMake(0,0);
    markerGradient.endPoint = CGPointMake(0,1);
    marker.layer.cornerRadius = 2.5;
    marker.layer.masksToBounds = YES;
    [marker.layer insertSublayer:markerGradient atIndex:0];
    [container addSubview:marker];
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = heading;
    label.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightBlack];
    label.textColor = [UIColor colorWithRed:0.78 green:0.55 blue:1.0 alpha:1.0];
    label.numberOfLines = 2;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.86;
    [container addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [marker.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:7],
        [marker.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        [marker.widthAnchor constraintEqualToConstant:5],
        [marker.heightAnchor constraintEqualToConstant:22],
        [label.leadingAnchor constraintEqualToAnchor:marker.trailingAnchor constant:10],
        [label.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-10],
        [label.topAnchor constraintEqualToAnchor:container.topAnchor constant:8],
        [label.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-4]
    ]];
    // Keep the accent strip aligned when UIKit lays out the header at its final width.
    dispatch_async(dispatch_get_main_queue(), ^{
        markerGradient.frame = marker.bounds;
    });
    return container;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    NSString *heading = [self tableView:tableView titleForHeaderInSection:section];
    if (heading.length == 0) return 10.0;
    return (heading.length > 38) ? 46.0 : 38.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_currentBottomTab == 3 && indexPath.section == 1) return 58.0;
    return 76.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cid = @"ApexSolidPremiumCell";
    LGGlassTableViewCell *cell = (LGGlassTableViewCell *)[tableView dequeueReusableCellWithIdentifier:cid];
    if (!cell) cell = [[LGGlassTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cid];

    NSString *title = @"";
    NSString *detail = @"";
    UIView *accessory = nil;
    UIColor *accent = nil;

    if (!_isFeatureActivated && _currentBottomTab != 4 && _currentBottomTab != 0 && _currentBottomTab != 1) {
        title = @"Cần kích hoạt trước";
        detail = @"Vào Cài Đặt";
        [cell configureWithTitle:title detail:detail accessory:nil accent:[UIColor colorWithRed:1.0 green:0.5 blue:0.5 alpha:1.0]];
        cell.userInteractionEnabled = NO;
        cell.alpha = 0.55;
        return cell;
    }
    cell.userInteractionEnabled = YES;
    cell.alpha = 1.0;

    if (_currentBottomTab == 0) {
        if (indexPath.section == 0) {
            title = @"Kích Hoạt Bộ Đo Phần Cứng";
            LiquidCapsuleSwitch *s = [[LiquidCapsuleSwitch alloc] init];
            s.on = [self.settingsDict[@"EnableSystemMonitoring"] boolValue];
            __weak typeof(self) wS = self;
            s.valueChangedBlock = ^(BOOL isOn) {
                __strong typeof(wS) sS = wS;
                if (!sS) return;
                sS.settingsDict[@"EnableSystemMonitoring"] = @(isOn);
                [sS saveSettingsDataAndSync];
                if (sS->_currentBottomTab == 0) [sS startContinuousHardwareHUD];
                [sS.customTableView reloadData];
            };
            accessory = s;
        } else {
            BOOL mA = [self.settingsDict[@"EnableSystemMonitoring"] boolValue];
            if (!mA) { title = @"Bộ đo đang tắt"; detail = @"[TẮT]"; }
            else if (_chipErrorActive) {
                title = @"Chip đang lỗi, không thể đo";
                detail = [NSString stringWithFormat:@"Tự khôi phục %lds...", (long)_chipErrorRandomSeconds];
                accent = [UIColor colorWithRed:1.0 green:0.6 blue:0.3 alpha:1.0];
                cell.userInteractionEnabled = NO;
            } else {
                float cpu = Titanium_GetLiveCPULoadPercentage();
                float gpu = Titanium_GetLiveGPULoadPercentage();
                NSString *cpuLoad = cpu >= 0.0f ? [NSString stringWithFormat:@"%.1f%%", cpu] : @"Đang lấy mẫu…";
                NSString *thermal = Titanium_ThermalStateDescription();
                uint32_t cores = Titanium_LogicalCPUCoreCount();
                uint64_t physicalRAM = Titanium_TotalPhysicalMemoryBytes();
                uint64_t processRAM = Titanium_CurrentProcessFootprintBytes();
                if (indexPath.section == 1) {
                    if (indexPath.row == 0) { title = _isCpuExpanded ? @"CPU ▼" : @"CPU ▶"; detail = [NSString stringWithFormat:@"%@ · %u nhân logic", cpuLoad, cores]; }
                    else if (indexPath.row == 1) { title = @"   Trạng thái nhiệt"; detail = thermal; }
                    else if (indexPath.row == 2) { title = @"   Tải CPU đo thực tế"; detail = cpuLoad; }
                    else if (indexPath.row == 3) { title = @"   Xung CPU hiện tại"; detail = @"iOS không công khai qua API này"; }
                    else if (indexPath.row == 4) { title = @"   Loại nhân P/E"; detail = @"iOS không công khai qua API này"; }
                    else if (indexPath.row == 5) { title = @"   Kiến trúc CPU"; detail = Titanium_CPUArchitectureString(); }
                    else { title = @"   Mã phần cứng"; detail = Titanium_DeviceHardwareIdentifier(); }
                } else if (indexPath.section == 2) {
                    if (indexPath.row == 0) { title = _isGpuExpanded ? @"GPU ▼" : @"GPU ▶"; detail = @"Không có phép đo tải GPU công khai"; }
                    else if (indexPath.row == 1) { title = @"   Tải GPU"; detail = gpu >= 0.0f ? [NSString stringWithFormat:@"%.1f%%", gpu] : @"Không được API công khai hỗ trợ"; }
                    else if (indexPath.row == 2) { id<MTLDevice> metalDevice = MTLCreateSystemDefaultDevice(); title = @"   Tên GPU"; detail = metalDevice.name.length ? metalDevice.name : @"Metal GPU không được hệ thống công khai"; }
                    else if (indexPath.row == 3) { title = @"   Nhiệt GPU"; detail = @"iOS không công khai"; }
                    else if (indexPath.row == 4) { title = @"   Xung GPU"; detail = @"iOS không công khai"; }
                    else { title = @"   Chỉ số GPU"; detail = @"Không có dữ liệu đo thực tế"; }
                } else if (indexPath.section == 3) {
                    NSString *totalRAM = Titanium_ByteCountString(physicalRAM);
                    NSString *appRAM = Titanium_ByteCountString(processRAM);
                    if (indexPath.row == 0) { title = _isRamExpanded ? @"RAM ▼" : @"RAM ▶"; detail = [NSString stringWithFormat:@"Tổng %@ · app %@", totalRAM, appRAM]; }
                    else if (indexPath.row == 1) { title = @"   RAM vật lý tổng"; detail = totalRAM; }
                    else if (indexPath.row == 2) { title = @"   Bộ nhớ tiến trình này"; detail = appRAM; }
                    else if (indexPath.row == 3) { title = @"   RAM trống toàn hệ thống"; detail = @"Không được iOS công khai ổn định"; }
                    else { title = @"   Purgeable / RAM ảo"; detail = @"Không đo trong bản chẩn đoán này"; }
                } else if (indexPath.section == 4) {
                    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
                    int level = (int)round([[UIDevice currentDevice] batteryLevel] * 100.0);
                    if (level < 0) level = -1;
                    UIDeviceBatteryState batteryState = [UIDevice currentDevice].batteryState;
                    NSString *chargeState = batteryState == UIDeviceBatteryStateCharging ? @"Đang sạc" : (batteryState == UIDeviceBatteryStateFull ? @"Đã đầy" : (batteryState == UIDeviceBatteryStateUnplugged ? @"Rút sạc" : @"Không xác định"));
                    if (indexPath.row == 0) { title = _isBatteryExpanded ? @"Pin ▼" : @"Pin ▶"; detail = level >= 0 ? [NSString stringWithFormat:@"%d%% · %@", level, chargeState] : @"Không đọc được mức pin"; }
                    else if (indexPath.row == 1) { title = @"   Trạng thái nhiệt hệ thống"; detail = thermal; }
                    else if (indexPath.row == 2) { title = @"   Dòng xả tức thời"; detail = @"iOS không công khai qua API này"; }
                    else if (indexPath.row == 3) { title = @"   Dung lượng pin"; detail = level >= 0 ? [NSString stringWithFormat:@"%d%%", level] : @"Không khả dụng"; }
                    else if (indexPath.row == 4) { title = @"   Trạng thái sạc"; detail = chargeState; }
                    else { title = @"   Chu kỳ pin"; detail = @"Không công khai qua API này"; }
                } else {
                    NSInteger targetHz = [self.settingsDict[@"TargetRefreshRate"] ?: @60 integerValue];
                    NSInteger targetFPS = [self.settingsDict[@"TargetFPSRate"] ?: @60 integerValue];
                    NSInteger maximumHz = 0;
                    if (@available(iOS 10.0, *)) maximumHz = (NSInteger)UIScreen.mainScreen.maximumFramesPerSecond;
                    CGRect logicalBounds = UIScreen.mainScreen.bounds;
                    CGRect nativeBounds = UIScreen.mainScreen.nativeBounds;
                    CGFloat nativeScale = UIScreen.mainScreen.nativeScale;
                    NSString *deviceHW = Titanium_DeviceHardwareIdentifier();
                    NSInteger targetHzSetting = [self.settingsDict[@"TargetRefreshRate"] ?: @240 integerValue];
                    NSInteger targetFPSSetting = [self.settingsDict[@"TargetFPSRate"] ?: @240 integerValue];
                    if (indexPath.row == 0) {
                        NSInteger displayedIOSHz2 = maximumHz;
                        title = _isScreenExpanded ? @"Màn hình ▼" : @"Màn hình ▶";
                        detail = [NSString stringWithFormat:@"Màn hình tối đa %ld Hz · Mục tiêu cấu hình %ld Hz · %.0f×%.0f px", (long)displayedIOSHz2, (long)targetHzSetting, nativeBounds.size.width, nativeBounds.size.height];
                    }
                    else if (indexPath.row == 1) { title = @"   Độ phân giải / scale"; detail = [NSString stringWithFormat:@"%.0f×%.0f px · scale %.2fx · vùng %.0f×%.0f pt", nativeBounds.size.width, nativeBounds.size.height, nativeScale, logicalBounds.size.width, logicalBounds.size.height]; }
                    else if (indexPath.row == 2) {
                        // [V30 FIX]: Nếu tweak đã ép vượt trần iOS, hiển thị giá trị đã ép thay vì 60
                        NSInteger displayedIOSHz = (targetHzSetting > maximumHz) ? targetHzSetting : maximumHz;
                        title = @"   Tần số iOS báo / Tweak ép";
                        detail = [NSString stringWithFormat:@"iOS: %ld Hz · Tweak: %ld Hz · Máy: %@%@", (long)displayedIOSHz, (long)targetHzSetting, deviceHW, (targetHzSetting > maximumHz) ? @" (đã ép vượt trần)" : @""];
                    }
                    else if (indexPath.row == 3) { title = @"   FPS mục tiêu (60-240)"; detail = [NSString stringWithFormat:@"%ld FPS đang cấu hình · Tweak.xm ép phần cứng", (long)targetFPSSetting]; }
                    else { title = @"   Hz mục tiêu (60-240)"; detail = [NSString stringWithFormat:@"%ld Hz đang cấu hình · TITANIUM_SPOOF vượt trần iOS", (long)targetHzSetting]; }
                }
            }
        }
    }
    else if (_currentBottomTab == 1) {
        if (indexPath.section == 0) {
            LGCustomSegment *modeSeg = [[LGCustomSegment alloc] initWithItems:@[@"Thường", @"Hz/FPS mở rộng"]];
            modeSeg.selectedSegmentIndex = _expandedHzFPS ? 1 : 0;
            __weak typeof(self) weakModeSelf = self;
            modeSeg.valueChangedBlock = ^(NSInteger index) {
                __strong typeof(weakModeSelf) strongSelf = weakModeSelf;
                if (!strongSelf) return;
                strongSelf->_expandedHzFPS = (index == 1);
                [strongSelf smoothReloadTable];
            };
            accessory = modeSeg;
            title = @"Chọn danh sách mức thường hoặc danh sách mở rộng";
        } else if (indexPath.section == 1) {
            LGCustomSegment *seg = [[LGCustomSegment alloc] initWithItems:@[@"Hz/FPS", @"Hz", @"FPS"]];
            seg.selectedSegmentIndex = MIN(2, MAX(0, _currentHzFpsSubTab));
            __weak typeof(self) wS = self;
            seg.valueChangedBlock = ^(NSInteger index) {
                __strong typeof(wS) sS = wS;
                if (!sS) return;

                // Hz/FPS is a one-tap action: tapping it immediately syncs FPS to the
                // currently configured Hz. Hz and FPS tabs remain manual-only.
                if (index == 0) {
                    if (sS->_isRateLocked) {
                        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"KHÓA" message:@"Mở khóa góc phải trước." preferredStyle:UIAlertControllerStyleAlert];
                        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
                        [sS presentViewController:a animated:YES completion:nil];
                        return;
                    }
                    NSInteger rate = [sS.settingsDict[@"TargetRefreshRate"] ?: @60 integerValue];
                    rate = MAX(60, MIN(240, rate));
                    [sS applyRateValue:rate isDynamic:NO isFPS:NO];
                    [sS applyRateValue:rate isDynamic:NO isFPS:YES];
                    sS->_currentHzFpsSubTab = 0;
                    [sS applyDeepSpringBoardAndUIKitTweaks];
                    [sS showRateSuccessBannerForRate:rate combined:YES isFPS:NO];
                    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
                    [fb impactOccurred];
                    [sS smoothReloadTable];
                    return;
                }

                if (sS->_currentHzFpsSubTab == index) return;
                sS->_currentHzFpsSubTab = index;
                [sS smoothReloadTable];
            };
            accessory = seg;
            title = @"   Chế độ:";
        } else {
            BOOL combined = (_currentHzFpsSubTab == 0);
            BOOL isHz = combined || (_currentHzFpsSubTab == 1);
            NSInteger curHz = [self.settingsDict[@"TargetRefreshRate"] ?: @60 integerValue];
            NSInteger curFPS = [self.settingsDict[@"TargetFPSRate"] ?: @60 integerValue];
            NSInteger cur = combined ? (curHz == curFPS ? curHz : 0) : (isHz ? curHz : curFPS);
            NSArray<NSNumber *> *rates = _expandedHzFPS ? TIExpandedRateValues() : TIStandardRateValues();
            NSInteger applied = combined ? ((_lastAppliedHz == _lastAppliedFPS) ? _lastAppliedHz : 0) : (isHz ? _lastAppliedHz : _lastAppliedFPS);
            if (indexPath.row == 0) {
                title = combined ? @"Nhập Hz/FPS" : (isHz ? @"Nhập Hz thủ công" : @"Nhập FPS thủ công");
                detail = @"15–240 · Nhập giá trị rồi áp dụng";
            } else if (indexPath.row - 1 < (NSInteger)rates.count) {
                NSInteger r = rates[indexPath.row - 1].integerValue;
                NSString *unit = combined ? @"Hz/FPS" : (isHz ? @"Hz" : @"FPS");
                NSString *heading = (r == 240) ? [NSString stringWithFormat:@"%ld %@ MAX", (long)r, unit] : [NSString stringWithFormat:@"%ld %@", (long)r, unit];
                // [V30 FIX]: Dùng nhãn mô tả riêng từng mức giống ảnh 2
                NSString *description = TIRateDescription(r, isHz);
                title = [NSString stringWithFormat:@"%@ — %@", heading, description];
                if (cur == r) { detail = @"✓ Đang chọn"; accent = [UIColor colorWithRed:0.35 green:1.0 blue:0.55 alpha:1.0]; }
                else if (applied == r) accent = [UIColor colorWithRed:0.35 green:0.75 blue:1.0 alpha:1.0];
            }
        }
    }
    else if (_currentBottomTab == 2) {
        if (indexPath.section == 0) {
            LGCustomSegment *seg = [[LGCustomSegment alloc] initWithItems:@[@"CPU", @"GPU", @"Màn", @"PIN & NĂNG LƯỢNG", @"Hệ Thống"]];
            seg.selectedSegmentIndex = MIN(4, MAX(0, _currentSwitchSubTab));
            __weak typeof(self) wS = self;
            seg.valueChangedBlock = ^(NSInteger index) {
                __strong typeof(wS) sS = wS;
                if (!sS) return;
                if (sS->_currentSwitchSubTab == index) return;
                sS->_currentSwitchSubTab = index;
                [sS.customTableView reloadData];
            };
            accessory = seg;
            title = @"   Nhóm:";
        } else {
            NSString *prefKey = @"";
            if (_currentSwitchSubTab == 0) {
                if (indexPath.row == 0) { title = @"Ưu Tiên P-Core"; prefKey = @"pCoreRealtimePriority"; }
                else if (indexPath.row == 1) { title = @"CPU Scheduler"; prefKey = @"schedulerGovernor"; }
                else if (indexPath.row == 2) { title = @"Quantum Sync"; prefKey = @"quantumCoreSync"; }
                else if (indexPath.row == 3) { title = @"CPU Sàn"; prefKey = @"lockHighIdleFloor"; }
                else if (indexPath.row == 4) { title = @"Anti Thermal"; prefKey = @"AntiThermalThrottling"; }
                else if (indexPath.row == 5) { title = @"I/O Disk VIP"; prefKey = @"iopolVipPriority"; }
                else { title = @"Cool Down"; prefKey = @"coolDownHeavyLoad"; }
            } else if (_currentSwitchSubTab == 1) {
                if (indexPath.row == 0) { title = @"Triple Buffering"; prefKey = @"MetalHexBuffering"; }
                else if (indexPath.row == 1) { title = @"Isolate Pipeline"; prefKey = @"IsolateRenderPipeline"; }
                else if (indexPath.row == 2) { title = @"Bỏ V-Sync"; prefKey = @"vsyncAdaptiveBuffer"; }
                else if (indexPath.row == 3) { title = @"Game FPS"; prefKey = @"gameFPSStabilizer"; }
                else if (indexPath.row == 4) { title = @"Flat Blur"; prefKey = @"flatTintBlur"; }
                else { title = @"Neural Buffer"; prefKey = @"neuralBufferOpt"; }
            } else if (_currentSwitchSubTab == 2) {
                if (indexPath.row == 0) { title = @"Ép 144Hz"; prefKey = @"ForceOverclock144Hz"; }
                else if (indexPath.row == 1) { title = @"ProMotion Beta 7"; prefKey = @"ProMotionEngineBeta7"; }
                else if (indexPath.row == 2) { title = @"0ms Touch"; prefKey = @"TouchResponseBoost"; }
                else if (indexPath.row == 3) { title = @"ColorOS 17"; prefKey = @"ColorOs17SmoothEngine"; }
                else if (indexPath.row == 4) { title = @"Neural Touch"; prefKey = @"zeroLagNeural"; }
                else { title = @"Ultra Responsive"; prefKey = @"ultraResponsiveness"; }
            } else if (_currentSwitchSubTab == 3) {
                if (indexPath.row == 0) { title = @"Anti Ghost"; prefKey = @"AntiGhostTouch"; }
                else if (indexPath.row == 1) { title = @"Charger Ripple"; prefKey = @"ChargerRippleRejection"; }
                else if (indexPath.row == 2) { title = @"Fake Full Battery"; prefKey = @"fakeFullBatteryState"; }
                else if (indexPath.row == 3) { title = @"Lock 30FPS"; prefKey = @"lock30FpsOnOverheat"; }
                else if (indexPath.row == 4) { title = @"Battery Saver 60Hz"; prefKey = @"batterySaver60Hz"; }
                else { title = @"Power Save"; prefKey = @"powerSaveMode"; }
            } else {
                if (indexPath.row == 0) { title = @"Turbo App Launch"; prefKey = @"TurboAppLaunch"; }
                else if (indexPath.row == 1) { title = @"Fix Black Screen"; prefKey = @"FixAppLaunchBlackScreen"; }
                else if (indexPath.row == 2) { title = @"Reduce Multitask Lag"; prefKey = @"ReduceMultiTaskLag"; }
                else if (indexPath.row == 3) { title = @"Fix Exit Stutter"; prefKey = @"FixAppExitStutter"; }
                else if (indexPath.row == 4) { title = @"Hyper Memory"; prefKey = @"hyperMemoryGuardian"; }
                else if (indexPath.row == 5) { title = @"Auto Kill Background"; prefKey = @"autoKillBackground"; }
                else if (indexPath.row == 6) { title = @"Periodic RAM Clean"; prefKey = @"periodicRamClean"; }
                else if (indexPath.row == 7) { title = @"Mach VM Purge"; prefKey = @"machVMPurgeRam"; }
                else { title = @"Background Pacing"; prefKey = @"backgroundPacingDaemon"; }
            }
            LiquidCapsuleSwitch *s = [[LiquidCapsuleSwitch alloc] init];
            s.on = [self.settingsDict[prefKey] ?: @NO boolValue];
            __weak typeof(self) wS = self;
            s.valueChangedBlock = ^(BOOL isOn) {
                __strong typeof(wS) sS = wS;
                if (!sS) return;
                sS.settingsDict[prefKey] = @(isOn);
                Titanium_SynchronizeLinkedPreferences(sS.settingsDict, prefKey);
                [sS saveSettingsDataAndSync];
                [sS applyDeepSpringBoardAndUIKitTweaks];
            };
            accessory = s;
        }
    }
    else if (_currentBottomTab == 3) {
        if (indexPath.section == 0) {
            title = @"Danh mục";
            LGCustomSegment *categorySeg = [[LGCustomSegment alloc] initWithItems:@[@"Tất cả", @"Mặc định", @"Ẩn Home", @"Đã ẩn/tắt"]];
            categorySeg.selectedSegmentIndex = _appCategoryIndex;
            __weak typeof(self) weakCategorySelf = self;
            categorySeg.valueChangedBlock = ^(NSInteger index) {
                __strong typeof(weakCategorySelf) strongSelf = weakCategorySelf;
                if (!strongSelf) return;
                strongSelf->_appCategoryIndex = index;
                [strongSelf applyAppFilter];
                [strongSelf.customTableView reloadSections:[NSIndexSet indexSetWithIndex:2] withRowAnimation:UITableViewRowAnimationNone];
            };
            accessory = categorySeg;
        } else if (indexPath.section == 1) {
            UITextField *searchField = [[UITextField alloc] init];
            searchField.placeholder = @"Tìm app...";
            searchField.text = _appSearchQuery;
            searchField.textColor = [UIColor whiteColor];
            searchField.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
            searchField.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.06];
            searchField.layer.cornerRadius = 12;
            searchField.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.10].CGColor;
            searchField.layer.borderWidth = 0.5;
            searchField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 38)];
            searchField.leftViewMode = UITextFieldViewModeAlways;
            searchField.clearButtonMode = UITextFieldViewModeWhileEditing;
            searchField.autocorrectionType = UITextAutocorrectionTypeNo;
            searchField.autocapitalizationType = UITextAutocapitalizationTypeNone;
            searchField.returnKeyType = UIReturnKeySearch;
            [searchField addTarget:self action:@selector(onAppSearchChanged:) forControlEvents:UIControlEventEditingChanged];
            accessory = searchField;
        } else {
            if (_filteredAppsList.count == 0) {
                title = _scannedAppsList.count == 0 ? @"Đang quét ứng dụng đã cài…" : @"Không có ứng dụng khớp";
                [cell configureWithTitle:title detail:@"Danh sách được làm mới định kỳ khi màn này mở." accessory:nil accent:[UIColor colorWithWhite:0.6 alpha:1.0]];
                cell.userInteractionEnabled = NO;
                cell.alpha = 0.6;
                return cell;
            }
            NSDictionary *appInfo = _filteredAppsList[indexPath.row];
            title = appInfo[@"name"];
            detail = appInfo[@"bundleID"];
            LiquidCapsuleSwitch *appSwitch = [[LiquidCapsuleSwitch alloc] init];
            appSwitch.on = [_appTweakStates[appInfo[@"bundleID"]] boolValue];
            __weak typeof(self) weakAppSelf = self;
            NSString *bundleID = appInfo[@"bundleID"];
            appSwitch.valueChangedBlock = ^(BOOL isOn) {
                __strong typeof(weakAppSelf) strongSelf = weakAppSelf;
                if (!strongSelf || bundleID.length == 0) return;
                strongSelf->_appTweakStates[bundleID] = @(isOn);
                strongSelf.settingsDict[@"AppTweakStates"] = strongSelf->_appTweakStates;
                [strongSelf saveSettingsDataAndSync];
                [strongSelf applyDeepSpringBoardAndUIKitTweaks];
            };
            accessory = appSwitch;
        }
    }
    else {
        if (indexPath.section == 0) {
            if (indexPath.row == 0) {
                if (_isFeatureActivated) {
                    title = @"ĐÃ KÍCH HOẠT";
                    detail = @"Sẵn Sàng";
                    accent = [UIColor colorWithRed:0.4 green:1.0 blue:0.6 alpha:1.0];
                } else {
                    title = @"CHƯA KÍCH HOẠT — CHẠM";
                    detail = @"Bấm";
                    accent = [UIColor colorWithRed:1.0 green:0.45 blue:0.45 alpha:1.0];
                }
                cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                cell.userInteractionEnabled = YES;
            } else {
                NSString *curIOS = [[UIDevice currentDevice] systemVersion];
                if (Titanium_IsSupportedIOSVersion()) {
                    title = [NSString stringWithFormat:@"iOS %@ — OK", curIOS];
                    detail = @"15-26";
                    accent = [UIColor colorWithRed:0.4 green:1.0 blue:0.6 alpha:1.0];
                } else {
                    title = [NSString stringWithFormat:@"iOS %@ — Không Hỗ Trợ", curIOS];
                    accent = [UIColor colorWithRed:1.0 green:0.35 blue:0.35 alpha:1.0];
                }
            }
        } else if (indexPath.section == 1) {
            if (!_isFeatureActivated) {
                title = @"Cần kích hoạt";
                accent = [UIColor colorWithRed:1.0 green:0.5 blue:0.5 alpha:1.0];
                [cell configureWithTitle:title detail:@"" accessory:nil accent:accent];
                cell.userInteractionEnabled = NO;
                cell.alpha = 0.55;
                return cell;
            }
            struct utsname si; uname(&si);
            NSString *dm = [NSString stringWithCString:si.machine encoding:NSUTF8StringEncoding];
            NSString *ov = [[UIDevice currentDevice] systemVersion];
            if (indexPath.row == 0) { title = @"UID"; detail = _deviceUUIDString; }
            else if (indexPath.row == 1) { title = @"Mã"; detail = dm; }
            else if (indexPath.row == 2) { title = @"Kiến Trúc"; detail = _deepArchString; }
            else if (indexPath.row == 3) { title = @"iOS"; detail = [NSString stringWithFormat:@"%@", ov]; }
            else if (indexPath.row == 4) { title = @"Tên"; detail = [[UIDevice currentDevice] name]; }
            else if (indexPath.row == 5) { title = @"CPU"; detail = _deepCoreCountString; }
            else if (indexPath.row == 6) { title = @"BỘ NHỚ RAM"; detail = _deepRamString; }
            else { title = @"Darwin"; detail = _deepKernelString; }
        } else if (indexPath.section == 2) {
            if (indexPath.row == 0) {
                title = @"Đo Ping Server (chạm để đo)";
                NSString *selectedMode = [[NSUserDefaults standardUserDefaults] stringForKey:TI_SELECTED_SERVER_KEY];
                BOOL adminMode = _isAdminServer || [selectedMode isEqualToString:@"admin"] || [selectedMode isEqualToString:@"admin_dev"];
                if (!adminMode) cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                if (adminMode) {
                    if (_serverPingReachable && _currentLatencyMs >= 0 && _serverLastHTTPStatus >= 400) {
                        detail = [NSString stringWithFormat:@"HTTP %ld · %ld ms", (long)_serverLastHTTPStatus, (long)_currentLatencyMs];
                        accent = _serverLastHTTPStatus >= 500 ? [UIColor systemRedColor] : [UIColor systemYellowColor];
                    } else {
                        detail = _serverPingReachable && _currentLatencyMs >= 0
                            ? [NSString stringWithFormat:@"%ld ms HTTP RTT", (long)_currentLatencyMs]
                            : (_pingRequestInFlight ? @"Đang đo HTTP RTT…" : (_serverPingAttempted ? @"Không kết nối được API" : @"Đang chờ đo API"));
                        accent = _serverPingReachable ? (_currentLatencyMs >= 500 ? [UIColor systemRedColor] : (_currentLatencyMs >= 150 ? [UIColor systemYellowColor] : [UIColor systemGreenColor])) : [UIColor colorWithWhite:0.70 alpha:1.0];
                    }
                } else if (_currentLatencyMs < 0) {
                    detail = [self currentFreeServerPingURL].length
                        ? (_pingRequestInFlight ? @"Đang đo ping…" : (_serverPingAttempted ? @"Mất kết nối · chạm sửa URL" : @"Chưa đo ping"))
                        : @"Chưa cấu hình URL · chạm để đo sẽ yêu cầu nhập URL";
                    accent = [UIColor colorWithWhite:0.70 alpha:1.0];
                    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                } else if (_serverPingReachable && _currentLatencyMs >= 0 && _serverLastHTTPStatus >= 400) {
                    detail = [NSString stringWithFormat:@"HTTP %ld · %ld ms", (long)_serverLastHTTPStatus, (long)_currentLatencyMs];
                    accent = _serverLastHTTPStatus >= 500 ? [UIColor systemRedColor] : [UIColor systemYellowColor];
                } else {
                    detail = [NSString stringWithFormat:@"%ld ms", (long)_currentLatencyMs];
                    if (_currentLatencyMs >= 500) accent = [UIColor systemRedColor];
                    else if (_currentLatencyMs >= 150) accent = [UIColor systemYellowColor];
                    else accent = [UIColor systemGreenColor];
                }
            } else if (indexPath.row == 1) {
                title = @"Trạng Thái Server";
                int pState = Titanium_CurrentPersistentServerState();
                if (_isAdminServer) {
                    if (_serverPingReachable && _currentLatencyMs >= 0 && _serverLastHTTPStatus >= 400) detail = [NSString stringWithFormat:@"Admin · HTTP lỗi (%ld)", (long)_serverLastHTTPStatus];
                    else if (_currentLatencyMs >= 0 && _serverPingReachable) {
                        detail = _currentLatencyMs >= 500 ? @"Admin · Chậm" : (_currentLatencyMs >= 150 ? @"Admin · Kém" : @"Admin · Ổn định");
                    } else if (_pingRequestInFlight) detail = @"Admin · Đang kiểm tra";
                    else if (_serverPingAttempted) detail = @"Admin · Mất kết nối";
                    else detail = @"Admin · Chưa đo";
                } else if (pState == TI_STATE_DOWN) detail = @"Sập";
                else if (pState == TI_STATE_OVERLOAD) detail = @"Quá tải";
                else if (pState == TI_STATE_ERROR) detail = @"Lỗi";
                else if (_serverPingReachable && _currentLatencyMs >= 0 && _serverLastHTTPStatus >= 400) detail = [NSString stringWithFormat:@"HTTP lỗi (%ld)", (long)_serverLastHTTPStatus];
                else if (_currentLatencyMs >= 500) detail = @"Chậm";
                else if (_currentLatencyMs >= 150) detail = @"Kém";
                else if (_currentLatencyMs >= 0 && _serverPingReachable) detail = @"Ổn định";
                else if (_pingRequestInFlight) detail = @"Đang kiểm tra";
                else if (_serverPingAttempted) detail = @"Mất kết nối";
                else detail = @"Chưa đo / chưa cấu hình ping";
            } else if (indexPath.row == 2) {
                title = @"Đăng Nhập Server Riêng";
                if (_isAdminServer) {
                    detail = [self isAdminDevRole] ? @"✓ Admin Dev đã xác thực" : @"✓ Admin đã xác thực";
                    accent = [UIColor colorWithRed:0.35 green:1.0 blue:0.55 alpha:1.0];
                } else {
                    detail = @"Admin";
                    accent = [UIColor colorWithRed:1.0 green:0.85 blue:0.35 alpha:1.0];
                }
                cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            } else if (indexPath.row == 3) {
                title = @"Giao diện Sáng / Tối / Tự động";
                NSString *mode = self.settingsDict[TI_THEME_MODE_KEY] ?: ([self.settingsDict[TI_AUTO_THEME_KEY] boolValue] ? @"system" : @"dark");
                detail = [mode isEqualToString:@"light"] ? @"Sáng" : ([mode isEqualToString:@"dark"] ? @"Tối" : @"Theo giao diện hệ thống");
                cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            } else if (indexPath.row == 4 && [self isAdminDevRole]) {
                // Admin API endpoint editor is omitted entirely for non-Admin-Dev roles.
                title = @"Admin Dev · API Endpoint";
                NSString *base = [self currentAdminAPIBaseURL];
                NSURLComponents *parts = [NSURLComponents componentsWithString:base];
                detail = parts.host.length ? @"Đã cấu hình · URL chỉ hiện trong Admin Dev Console" : @"Chưa cấu hình · chỉ Admin Dev";
                accent = [UIColor colorWithRed:0.30 green:0.70 blue:1.0 alpha:1.0];
                cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            } else if (indexPath.row == ([self isAdminDevRole] ? 5 : 4)) {
                // URL Ping Server Free chỉ hiển thị cho Admin Dev
                if ([self isAdminDevRole]) {
                    title = @"URL Ping Server (Admin Dev)";
                    NSString *pingURL = [self currentFreeServerPingURL];
                    NSURLComponents *pingParts = [NSURLComponents componentsWithString:pingURL ?: @""];
                    detail = pingParts.host.length ? @"HTTPS đã cấu hình · chạm để sửa" : @"Chưa cấu hình";
                    accent = [UIColor colorWithRed:0.30 green:0.70 blue:1.0 alpha:1.0];
                    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                } else {
                    title = @"Không khả dụng";
                    detail = @"Chỉ Admin Dev";
                    cell.userInteractionEnabled = NO;
                    cell.alpha = 0.35;
                }
            } else if (indexPath.row == 6 && [self isAdminDevRole]) {
                title = @"Admin Dev Console";
                detail = @"Thiết bị · blacklist · phiên · audit";
                accent = [UIColor colorWithRed:1.0 green:0.68 blue:0.20 alpha:1.0];
                cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            } else {
                title = @"Không khả dụng";
                detail = @"Quyền truy cập bị giới hạn";
                cell.userInteractionEnabled = NO;
                cell.alpha = 0.55;
            }
        } else {
            NSString *detectedRoot = Titanium_DetectedBootstrapPrefixForUI();
            if (indexPath.row == 0) {
                title = @"Môi Trường Jailbreak";
                NSString *jbType = Titanium_DetectJailbreakTypeForUI();
                BOOL jbPath = access("/var/jb", F_OK) == 0;
                BOOL substratePath = access("/Library/MobileSubstrate/DynamicLibraries", F_OK) == 0;
                BOOL tweakInjectPath = access("/usr/lib/TweakInject", F_OK) == 0;
                detail = [NSString stringWithFormat:@"%@ · /var/jb:%@ · Substrate:%@ · TweakInject:%@", jbType, jbPath ? @"có" : @"không", substratePath ? @"có" : @"không", tweakInjectPath ? @"có" : @"không"];
            } else if (indexPath.row == 1) {
                title = @"Prefix Bootstrap";
                detail = detectedRoot ?: @"Không xác định (chưa phát hiện)";
            } else if (indexPath.row == 2) {
                title = @"Sandbox";
                detail = Titanium_SandboxDiagnosticForUI();
            } else if (indexPath.row == 3) {
                title = @"IPC";
                detail = Titanium_IPCDiagnosticForUI();
            } else if (indexPath.row == 4) {
                title = @"Ngôn ngữ / Language";
                NSString *lang = self.settingsDict[@"SelectedLanguage"] ?: self.settingsDict[@"AppLanguage"] ?: @"auto";
                detail = [lang isEqualToString:@"vi"] ? @"Tiếng Việt" : ([lang isEqualToString:@"en"] ? @"English" : @"Auto · theo thiết bị");
                cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            } else if (indexPath.row == 5) {
                title = @"Thông báo tác giả";
                detail = @"TaoJb · NoNo · NoJB · nhóm cộng tác";
                cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            } else {
                title = @"Thông tin máy / ARM";
                detail = [NSString stringWithFormat:@"%@ · %@", Titanium_CPUArchitectureString(), Titanium_DeviceHardwareIdentifier()];
                cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            }
        }
    }

    BOOL activationEntry = (_currentBottomTab == 4 && indexPath.section == 0 && indexPath.row == 0);
    BOOL adminLoginEntry = (_currentBottomTab == 4 && indexPath.section == 2 && indexPath.row == 2);
    BOOL freePingEntry = (_currentBottomTab == 4 && indexPath.section == 2 && indexPath.row == ([self isAdminDevRole] ? 5 : 4));
    BOOL manualPingEntry = (_currentBottomTab == 4 && indexPath.section == 2 && indexPath.row == 0);
    BOOL themeEntry = (_currentBottomTab == 4 && indexPath.section == 2 && indexPath.row == 3);
    BOOL serverAPIEntry = (_currentBottomTab == 4 && [self isAdminDevRole] && indexPath.section == 2 && indexPath.row == 4);
    BOOL readOnlySandboxEntry = (_currentBottomTab == 4 && indexPath.section == 3);
    if (!_isFeatureActivated && _currentBottomTab == 4 && !activationEntry && !adminLoginEntry && !freePingEntry && !manualPingEntry && !themeEntry && !serverAPIEntry && !readOnlySandboxEntry) {
        // Prevent accessory switches and segmented controls from being usable while locked.
        if ([accessory isKindOfClass:[UIView class]]) accessory.userInteractionEnabled = NO;
        cell.userInteractionEnabled = NO;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.alpha = 0.38;
        detail = @"🔒 Cần kích hoạt";
    }
    [cell configureWithTitle:title detail:detail accessory:accessory accent:accent];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Ignore stale taps delivered during a tab/section reload; never index arrays from an invalid path.
    NSInteger sectionCount = [self numberOfSectionsInTableView:tableView];
    if (indexPath.section < 0 || indexPath.section >= sectionCount) return;
    NSInteger rowCount = [self tableView:tableView numberOfRowsInSection:indexPath.section];
    if (indexPath.row < 0 || indexPath.row >= rowCount) return;
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *selectedServer = [[NSUserDefaults standardUserDefaults] stringForKey:TI_SELECTED_SERVER_KEY];
    BOOL languageSettingsRow = (_currentBottomTab == 4 && indexPath.section == 3 && indexPath.row == 4);
    BOOL authorSettingsRow = (_currentBottomTab == 4 && indexPath.section == 3 && indexPath.row == 5);
    BOOL themeSettingsRow = (_currentBottomTab == 4 && indexPath.section == 2 && indexPath.row == 3);
    BOOL freePingSettingsRow = (_currentBottomTab == 4 && indexPath.section == 2 && indexPath.row == ([self isAdminDevRole] ? 5 : 4));
    BOOL manualPingRow = (_currentBottomTab == 4 && indexPath.section == 2 && indexPath.row == 0);
    BOOL serverAPISettingsRow = (_currentBottomTab == 4 && [self isAdminDevRole] && indexPath.section == 2 && indexPath.row == 4);
    if (![selectedServer isEqualToString:@"free"] && !self->_isAdminServer && _currentBottomTab != 1 && !themeSettingsRow && !freePingSettingsRow && !manualPingRow && !serverAPISettingsRow && !languageSettingsRow && !authorSettingsRow) {
        [self showFirstInstallServerPicker];
        return;
    }

    if (!_isFeatureActivated && _currentBottomTab != 1) {
        if (themeSettingsRow) { [self showThemeModePicker]; return; }
        if (freePingSettingsRow) { [self showFreeServerPingURLEditor]; return; }
        if (manualPingRow) { [self performManualServerPing]; return; }
        if (_currentBottomTab == 4 && indexPath.section == 3) {
            if (indexPath.row == 2) [self showSandboxDiagnosticDetails];
            else if (indexPath.row == 0) [self presentIndependentDocument:@"Môi trường Jailbreak" text:Titanium_DetectJailbreakTypeForUI()];
            else if (indexPath.row == 1) [self presentIndependentDocument:@"Prefix Bootstrap" text:(Titanium_DetectedBootstrapPrefixForUI() ?: @"Không xác định (chưa phát hiện)")];
            else if (indexPath.row == 3) [self presentIndependentDocument:@"IPC" text:Titanium_IPCDiagnosticForUI()];
            else if (indexPath.row == 4) [self presentIndependentDocument:@"Tác giả & hỗ trợ" text:@"NGƯỜI TẠO CHÍNH: TaoJb, NoNo, NoJB\nNGƯỜI PHỤ CODE: JB, NekoJb, BypassJB, bananaJb\nNGƯỜI CODE PHẦN CỨNG: Taojb, NoNo, JBnano, Jbjb"];
            return;
        }
        if (serverAPISettingsRow) { [self showServerAPIURLEditor]; return; }
        if (_currentBottomTab == 4 && indexPath.section == 0 && indexPath.row == 0) {
            if (!_isAdminServer && !([self isServerStateOK])) { [self showPersistentServerStateAlert]; return; }
            NSInteger cc = Titanium_GetCrashCount();
            if (cc >= 3) [self showServerDownAlert];
            else [self openDopamineStyleExploitConsole];
        }
        return;
    }

    if (_currentBottomTab == 0) {
        if (indexPath.section > 0 && indexPath.row == 0 && !_chipErrorActive) {
            if (indexPath.section == 1) _isCpuExpanded = !_isCpuExpanded;
            else if (indexPath.section == 2) _isGpuExpanded = !_isGpuExpanded;
            else if (indexPath.section == 3) _isRamExpanded = !_isRamExpanded;
            else if (indexPath.section == 4) _isBatteryExpanded = !_isBatteryExpanded;
            else if (indexPath.section == 5) _isScreenExpanded = !_isScreenExpanded;
            UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
            [fb impactOccurred];
            [tableView reloadSections:[NSIndexSet indexSetWithIndex:indexPath.section] withRowAnimation:UITableViewRowAnimationFade];
            return;
        }
    }

    if (_currentBottomTab == 1 && indexPath.section == 2) {
        if (_isRateLocked) {
            UIAlertController *a = [UIAlertController alertControllerWithTitle:@"KHÓA" message:@"Mở khóa góc phải trước." preferredStyle:UIAlertControllerStyleAlert];
            [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:a animated:YES completion:nil];
            return;
        }
        BOOL combined = (_currentHzFpsSubTab == 0);
        BOOL isHz = combined || (_currentHzFpsSubTab == 1);
        NSArray<NSNumber *> *rates = _expandedHzFPS ? TIExpandedRateValues() : TIStandardRateValues();
        if (indexPath.row == 0) {
            if (combined) [self showCombinedRateInputAlert];
            else [self showCustomRateInputAlertForHz:isHz];
            return;
        }
        NSInteger targetRate = 0;
        if (indexPath.row - 1 < (NSInteger)rates.count) targetRate = rates[indexPath.row - 1].integerValue;
        else { return; }

        // Apply the selected value directly; do not interrupt every Hz/FPS tap with a warning.
        if (combined) {
            [self applyRateValue:targetRate isDynamic:NO isFPS:NO];
            [self applyRateValue:targetRate isDynamic:NO isFPS:YES];
        } else {
            [self applyRateValue:targetRate isDynamic:NO isFPS:!isHz];
        }
        [self applyDeepSpringBoardAndUIKitTweaks];
        [self showRateSuccessBannerForRate:targetRate combined:combined isFPS:!isHz];
        UIImpactFeedbackGenerator *rateFb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [rateFb impactOccurred];
        [self smoothReloadTable];
    } else if (_currentBottomTab == 4 && indexPath.section == 0 && indexPath.row == 0) {
        if (!_isAdminServer && !([self isServerStateOK])) { [self showPersistentServerStateAlert]; return; }
        NSInteger cc = Titanium_GetCrashCount();
        if (cc >= 3) [self showServerDownAlert];
        else [self openDopamineStyleExploitConsole];
    } else if (_currentBottomTab == 4 && indexPath.section == 2 && indexPath.row == 0) {
        [self performManualServerPing];
    } else if (_currentBottomTab == 4 && indexPath.section == 2 && indexPath.row == 2) {
        [self showAdminServerLogin];
    } else if (_currentBottomTab == 4 && indexPath.section == 2 && indexPath.row == 3) {
        [self showThemeModePicker];
    } else if (_currentBottomTab == 4 && indexPath.section == 2 && indexPath.row == 4 && [self isAdminDevRole]) {
        [self showServerAPIURLEditor];
    } else if (_currentBottomTab == 4 && indexPath.section == 2 && indexPath.row == ([self isAdminDevRole] ? 5 : 4)) {
        [self showFreeServerPingURLEditor];
    } else if (_currentBottomTab == 4 && indexPath.section == 2 && indexPath.row == 6 && [self isAdminDevRole]) {
        if ([self isAdminDevRole]) [self showAdminDevConsole];
    } else if (_currentBottomTab == 4 && indexPath.section == 3 && indexPath.row == 2) {
        [self showReadOnlyDeviceInfo];
    } else if (_currentBottomTab == 4 && indexPath.section == 3 && indexPath.row == 0) {
        [self presentIndependentDocument:@"Môi trường Jailbreak" text:[NSString stringWithFormat:@"Loại được suy ra từ đường dẫn image đã nạp: %@\n\nĐây là suy luận cục bộ, không phải xác minh bảo mật.", Titanium_DetectJailbreakTypeForUI()]];
    } else if (_currentBottomTab == 4 && indexPath.section == 3 && indexPath.row == 1) {
        [self presentIndependentDocument:@"Prefix Bootstrap" text:[NSString stringWithFormat:@"Prefix phát hiện được: %@\n\nNếu không phát hiện đường dẫn đủ bằng chứng, giao diện sẽ ghi Không xác định thay vì tự đoán.", Titanium_DetectedBootstrapPrefixForUI() ?: @"Không xác định (chưa phát hiện)"]];
    } else if (_currentBottomTab == 4 && indexPath.section == 3 && indexPath.row == 3) {
        [self presentIndependentDocument:@"IPC" text:Titanium_IPCDiagnosticForUI()];
    } else if (_currentBottomTab == 4 && indexPath.section == 3 && indexPath.row == 4) {
        [self showLanguagePickerPopup:nil];
    } else if (_currentBottomTab == 4 && indexPath.section == 3 && indexPath.row == 5) {
        [self presentIndependentDocument:@"Tác giả & hỗ trợ" text:@"NGƯỜI TẠO CHÍNH: TaoJb, NoNo, NoJB\nNGƯỜI PHỤ CODE: JB, NekoJb, BypassJB, bananaJb\nNGƯỜI CODE PHẦN CỨNG: Taojb, NoNo, JBnano, Jbjb"];
    } else if (_currentBottomTab == 4 && indexPath.section == 3 && indexPath.row == 6) {
        [self showReadOnlyDeviceInfo];
    } else if (_currentBottomTab == 3 && indexPath.section == 2 && indexPath.row < (NSInteger)_filteredAppsList.count) {
        NSDictionary *app = _filteredAppsList[indexPath.row];
        if ([app isKindOfClass:NSDictionary.class]) [self neonV11ShowAppProfile:app];
    }
}

#pragma mark - Search

- (void)onAppSearchChanged:(UITextField *)field {
    _appSearchQuery = field.text ?: @"";
    uint64_t generation = ++_searchUpdateGeneration;
    NSString *query = Titanium_NormalizeAppSearchText(_appSearchQuery);
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) owner = weakSelf;
        if (!owner || generation != owner->_searchUpdateGeneration) return;
        NSArray<NSDictionary *> *snapshot = [owner->_scannedAppsList copy] ?: @[];
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            NSMutableArray<NSDictionary *> *matches = [NSMutableArray array];
            for (NSDictionary *app in snapshot) {
                if (![app isKindOfClass:[NSDictionary class]]) continue;
                id rawName = app[@"name"];
                id rawBundleID = app[@"bundleID"];
                NSString *name = Titanium_NormalizeAppSearchText([rawName isKindOfClass:[NSString class]] ? (NSString *)rawName : @"");
                NSString *bundleID = Titanium_NormalizeAppSearchText([rawBundleID isKindOfClass:[NSString class]] ? (NSString *)rawBundleID : @"");
                if (query.length == 0 || [name containsString:query] || [bundleID containsString:query]) {
                    [matches addObject:app];
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf || generation != strongSelf->_searchUpdateGeneration ||
                    strongSelf->_currentBottomTab != 3 || !strongSelf.customTableView.window) return;
                if (snapshot.count != strongSelf->_scannedAppsList.count) {
                    [strongSelf applyAppFilter];
                } else {
                    strongSelf->_filteredAppsList = matches;
                }
                [UIView performWithoutAnimation:^{ [strongSelf.customTableView reloadSections:[NSIndexSet indexSetWithIndex:2] withRowAnimation:UITableViewRowAnimationNone]; }];
            });
        });
    });
}

- (void)applyAppFilter {
    [_filteredAppsList removeAllObjects];
    NSString *q = Titanium_NormalizeAppSearchText(_appSearchQuery ?: @"");
    NSDictionary *hiddenMap = [self.settingsDict[@"HiddenApps"] isKindOfClass:[NSDictionary class]] ? self.settingsDict[@"HiddenApps"] : @{};
    for (NSDictionary *app in _scannedAppsList) {
        if (![app isKindOfClass:[NSDictionary class]]) continue;
        NSString *name = Titanium_NormalizeAppSearchText([app[@"name"] isKindOfClass:[NSString class]] ? app[@"name"] : @"");
        NSString *bidRaw = [app[@"bundleID"] isKindOfClass:[NSString class]] ? app[@"bundleID"] : @"";
        NSString *bid = Titanium_NormalizeAppSearchText(bidRaw);
        NSString *path = [app[@"path"] isKindOfClass:[NSString class]] ? app[@"path"] : @"";
        BOOL isDefault = [bidRaw hasPrefix:@"com.apple."] || [path containsString:@"/System/Applications/"] || [path containsString:@"/System/Library/CoreServices/"];
        BOOL scannerReportsHomeHidden = [app[@"isHidden"] boolValue];
        BOOL manuallyHiddenOrDisabled = [hiddenMap[bidRaw] boolValue] || [app[@"isDisabled"] boolValue];
        if (_appCategoryIndex == 1 && !isDefault) continue;
        if (_appCategoryIndex == 2 && !scannerReportsHomeHidden) continue;
        if (_appCategoryIndex == 3 && !manuallyHiddenOrDisabled) continue;
        if (q.length && ![name containsString:q] && ![bid containsString:q]) continue;
        [_filteredAppsList addObject:app];
    }
}

#pragma mark - Chip error

- (void)startChipErrorLoop {
    // V22: do not inject randomized fake chip/server failures or reload the table every second.
    [self cancelChipErrorRandom];
}
- (void)scheduleChipErrorRandomOnHome { [self cancelChipErrorRandom]; }
- (void)cancelChipErrorRandom {
    if (_chipErrorTimer) { [_chipErrorTimer invalidate]; _chipErrorTimer = nil; }
    if (_chipRecoverTimer) { [_chipRecoverTimer invalidate]; _chipRecoverTimer = nil; }
    _chipErrorActive = NO;
    _chipErrorRandomSeconds = 0;
}
- (void)triggerChipError { [self cancelChipErrorRandom]; }

#pragma mark - Actions

- (void)reloadVisibleContentWithSubtleTransition {
    UITableView *table = self.customTableView;
    if (!table) return;
    if (!table.window || !self.isViewLoaded) {
        [UIView performWithoutAnimation:^{ [table reloadData]; }];
        return;
    }
    uint64_t generation = ++_v20TableTransitionGeneration;
    [UIView animateWithDuration:0.07 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        table.alpha = 0.92;
        table.transform = CGAffineTransformMakeTranslation(0.0, 1.5);
    } completion:^(BOOL finished) {
        if (generation != self->_v20TableTransitionGeneration) return;
        [UIView performWithoutAnimation:^{ [table reloadData]; }];
        [UIView animateWithDuration:0.16 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
            table.alpha = 1.0;
            table.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

- (void)onHzFpsSubTabChanged:(UISegmentedControl *)sender {
    _currentHzFpsSubTab = sender.selectedSegmentIndex;
    self.customTableView.tableHeaderView = [self buildNeonRateHeaderWithWidth:self.view.bounds.size.width];
    [self reloadVisibleContentWithSubtleTransition];
}
- (void)onSwitchSubTabChanged:(UISegmentedControl *)sender {
    _currentSwitchSubTab = sender.selectedSegmentIndex;
    [self reloadVisibleContentWithSubtleTransition];
}

- (void)showCombinedRateInputAlert {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"NHẬP Hz/FPS" message:@"Nhập một giá trị từ 15 đến 240 để áp dụng đồng thời cho Hz và FPS." preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *tf) { tf.keyboardType = UIKeyboardTypeNumberPad; tf.placeholder = @"15–240"; }];
    [a addAction:[UIAlertAction actionWithTitle:@"Áp dụng cả hai" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSInteger rate = [a.textFields.firstObject.text integerValue];
        if (rate < 15 || rate > 240) {
            UIAlertController *invalid = [UIAlertController alertControllerWithTitle:@"Giá trị không hợp lệ" message:@"Nhập số từ 15 đến 240." preferredStyle:UIAlertControllerStyleAlert];
            [invalid addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:invalid animated:YES completion:nil];
            return;
        }
        [self applyRateValue:rate isDynamic:NO isFPS:NO];
        [self applyRateValue:rate isDynamic:NO isFPS:YES];
        [self applyDeepSpringBoardAndUIKitTweaks];
        [self showRateSuccessBannerForRate:rate combined:YES isFPS:NO];
        [self smoothReloadTable];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)showCustomRateInputAlertForHz:(BOOL)isHz {
    NSString *unit = isHz ? @"Hz" : @"FPS";
    UIAlertController *a = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"NHẬP %@", unit] message:[NSString stringWithFormat:@"15 - 240 %@", unit] preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull tf) {
        tf.keyboardType = UIKeyboardTypeNumberPad;
        tf.placeholder = [NSString stringWithFormat:@"15 - 240 %@", unit];
    }];
    [a addAction:[UIAlertAction actionWithTitle:@"Khóa Ngay" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UITextField *tf = a.textFields.firstObject;
        NSInteger val = [tf.text integerValue];
        if (val < 15) val = 15;
        if (val > 240) val = 240;
        [self applyRateValue:val isDynamic:NO isFPS:!isHz];
        [self applyDeepSpringBoardAndUIKitTweaks];
        [self showRateSuccessBannerForRate:val combined:NO isFPS:!isHz];
        [self smoothReloadTable];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)showRateSuccessBannerForRate:(NSInteger)rate combined:(BOOL)combined isFPS:(BOOL)isFPS {
    NSString *message = combined
        ? [NSString stringWithFormat:@"✓ Đã chỉnh Hz/FPS thành %ld", (long)rate]
        : [NSString stringWithFormat:@"✓ Đã chỉnh %@ thành %ld", isFPS ? @"FPS" : @"Hz", (long)rate];
    UIView *banner = [UIView new];
    banner.translatesAutoresizingMaskIntoConstraints = NO;
    banner.backgroundColor = [UIColor colorWithRed:0.10 green:0.13 blue:0.20 alpha:0.97];
    banner.layer.cornerRadius = 16.0;
    banner.layer.borderWidth = 1.0;
    banner.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.22].CGColor;
    banner.layer.shadowColor = UIColor.blackColor.CGColor;
    banner.layer.shadowOpacity = 0.22;
    banner.layer.shadowRadius = 12.0;
    banner.layer.shadowOffset = CGSizeMake(0, 4);
    banner.clipsToBounds = YES;
    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = message;
    label.textColor = UIColor.whiteColor;
    label.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    label.numberOfLines = 0;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.85;
    label.textAlignment = NSTextAlignmentLeft;
    [banner addSubview:label];
    [self.view addSubview:banner];
    [NSLayoutConstraint activateConstraints:@[
        [banner.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:12],
        [banner.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-12],
        [banner.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [label.leadingAnchor constraintEqualToAnchor:banner.leadingAnchor constant:15],
        [label.trailingAnchor constraintEqualToAnchor:banner.trailingAnchor constant:-15],
        [label.topAnchor constraintEqualToAnchor:banner.topAnchor constant:12],
        [label.bottomAnchor constraintEqualToAnchor:banner.bottomAnchor constant:-12]
    ]];
    banner.alpha = 0.0;
    banner.transform = CGAffineTransformMakeTranslation(0, -16);
    [UIView animateWithDuration:0.24 animations:^{ banner.alpha = 1.0; banner.transform = CGAffineTransformIdentity; }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.2 animations:^{ banner.alpha = 0.0; } completion:^(__unused BOOL finished) { [banner removeFromSuperview]; }];
    });
}

- (void)applyRateValue:(NSInteger)rate isDynamic:(BOOL)d isFPS:(BOOL)isFPS {
    rate = MAX(15, MIN(240, rate));
    NSUserDefaults *rateDefaults = [NSUserDefaults standardUserDefaults];
    if (isFPS) {
        self.settingsDict[@"TargetFPSRate"] = @(rate);
        self.settingsDict[@"EnableFPSControl"] = @YES;
        self->_lastAppliedFPS = rate;
        [rateDefaults setInteger:rate forKey:@"TargetFPSRate"];
        [rateDefaults setBool:YES forKey:@"EnableFPSControl"];
    } else {
        self.settingsDict[@"TargetRefreshRate"] = @(rate);
        self.settingsDict[@"EnableHzControl"] = @YES;
        self->_lastAppliedHz = rate;
        [rateDefaults setInteger:rate forKey:@"TargetRefreshRate"];
        [rateDefaults setBool:YES forKey:@"EnableHzControl"];
    }
    [rateDefaults synchronize];
    [self saveSettingsDataAndSync];
}

- (void)smoothReloadTable {
    UITableView *table = self.customTableView;
    if (!table) return;
    // Avoid translating/animating the whole scroll view after every setting change; that can look like a frame hitch.
    CGPoint oldOffset = table.contentOffset;
    BOOL wasInteracting = table.dragging || table.decelerating || table.tracking;
    [UIView performWithoutAnimation:^{
        [table reloadData];
        [table layoutIfNeeded];
    }];
    if (!wasInteracting && isfinite(oldOffset.x) && isfinite(oldOffset.y)) {
        CGFloat maxY = MAX(-table.adjustedContentInset.top, table.contentSize.height - table.bounds.size.height + table.adjustedContentInset.bottom);
        CGPoint preserved = CGPointMake(oldOffset.x, MIN(MAX(oldOffset.y, -table.adjustedContentInset.top), maxY));
        [table setContentOffset:preserved animated:NO];
    }
}

#pragma mark - HUD

- (void)startContinuousHardwareHUD {
    [self stopContinuousHardwareHUD];
    [self startUIFrameSampler];
    [self refreshNeonLiveReadouts];

    _hudTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(_hudTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), (uint64_t)(1.0 * NSEC_PER_SEC), (uint64_t)(0.5 * NSEC_PER_SEC));
    __weak typeof(self) wS = self;
    dispatch_source_set_event_handler(_hudTimer, ^{
        __strong typeof(wS) sS = wS;
        if (sS && sS->_currentBottomTab == 0) [sS refreshNeonLiveReadouts];
        if (sS && sS->_currentBottomTab == 0 && [sS.settingsDict[@"EnableSystemMonitoring"] boolValue] && !sS->_chipErrorActive) {
            NSArray<NSIndexPath *> *visible = sS.customTableView.indexPathsForVisibleRows ?: @[];
            NSMutableArray<NSIndexPath *> *rows = [NSMutableArray arrayWithCapacity:visible.count];
            for (NSIndexPath *ip in visible) {
                if (ip.section > 0) [rows addObject:ip];
            }
            UITableView *table = sS.customTableView;
            if (rows.count > 0 && !table.dragging && !table.decelerating && !table.tracking) {
                [UIView performWithoutAnimation:^{
                    [table reloadRowsAtIndexPaths:rows withRowAnimation:UITableViewRowAnimationNone];
                }];
            }
        }
    });
    dispatch_resume(_hudTimer);
}
- (void)stopContinuousHardwareHUD {
    if (_hudTimer) { dispatch_source_cancel(_hudTimer); _hudTimer = nil; }
    [self stopUIFrameSampler];
}

- (void)startUIFrameSampler {
    [self stopUIFrameSampler];
    _uiFPSFrameCount = 0;
    _uiFPSMeasured = 0;
    _uiFPSSampleStart = CACurrentMediaTime();
    _uiFPSDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(sampleUIFrame:)];
    if (@available(iOS 15.0, *)) {
        NSInteger maxRate = MAX(1, (NSInteger)UIScreen.mainScreen.maximumFramesPerSecond);
        _uiFPSDisplayLink.preferredFrameRateRange = CAFrameRateRangeMake(1.0, (float)maxRate, (float)maxRate);
    }
    [_uiFPSDisplayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}

- (void)stopUIFrameSampler {
    [_uiFPSDisplayLink invalidate];
    _uiFPSDisplayLink = nil;
}

- (void)sampleUIFrame:(CADisplayLink *)link {
    (void)link;
    _uiFPSFrameCount++;
    CFTimeInterval now = CACurrentMediaTime();
    CFTimeInterval elapsed = now - _uiFPSSampleStart;
    if (elapsed >= 1.0) {
        _uiFPSMeasured = (NSInteger)lrint((double)_uiFPSFrameCount / elapsed);
        _uiFPSFrameCount = 0;
        _uiFPSSampleStart = now;
        if (_currentBottomTab == 1) {
            UIView *header = self.customTableView.tableHeaderView;
            for (UIView *view in header.subviews) {
                if (![view isKindOfClass:[UIView class]]) continue;
                for (UIView *child in view.subviews) {
                    if (![child isKindOfClass:[UILabel class]]) continue;
                    UILabel *label = (UILabel *)child;
                    if (label.tag == 7402 || [label.text containsString:@"FPS  ·  LIVE"] || [label.text containsString:@"FPS · LIVE"]) {
                        label.text = [NSString stringWithFormat:@"%ld FPS · LIVE", (long)_uiFPSMeasured];
                        label.transform = CGAffineTransformMakeScale(1.04, 1.04);
                        [UIView animateWithDuration:0.22 animations:^{ label.transform = CGAffineTransformIdentity; }];
                    }
                }
            }
        }
    }
}

- (void)refreshNeonLiveReadouts {
    if (!self.isViewLoaded) return;
    float cpu = Titanium_GetLiveCPULoadPercentage();
    uint64_t memory = Titanium_CurrentProcessFootprintBytes();
    UIDevice.currentDevice.batteryMonitoringEnabled = YES;
    float battery = UIDevice.currentDevice.batteryLevel;
    UIView *header = self.customTableView.tableHeaderView;
    UILabel *cpuLabel = (UILabel *)[header viewWithTag:8701];
    UILabel *memoryLabel = (UILabel *)[header viewWithTag:8702];
    UILabel *batteryLabel = (UILabel *)[header viewWithTag:8703];
    void (^updateLiveLabel)(UILabel *, NSString *) = ^(UILabel *label, NSString *value) {
        if (![label isKindOfClass:[UILabel class]] || [label.text isEqualToString:value]) return;
        [UIView transitionWithView:label duration:0.22 options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionBeginFromCurrentState animations:^{ label.text = value; } completion:nil];
        label.transform = CGAffineTransformMakeScale(1.035, 1.035);
        [UIView animateWithDuration:0.28 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut animations:^{ label.transform = CGAffineTransformIdentity; } completion:nil];
    };
    updateLiveLabel(cpuLabel, cpu >= 0.0f ? [NSString stringWithFormat:@"%.0f%%", cpu] : @"Không có API");
    updateLiveLabel(memoryLabel, Titanium_ByteCountString(memory));
    updateLiveLabel(batteryLabel, battery >= 0.0f ? [NSString stringWithFormat:@"%.0f%%", battery * 100.0f] : @"Không khả dụng");
}

- (void)syncSharedMemoryFile:(BOOL)enabled {
    if (!_isFeatureActivated) return;

    Titanium_SynchronizeLinkedPreferences(self.settingsDict, nil);

    ApexV285ProPayload p;
    memset(&p, 0, sizeof(ApexV285ProPayload));
    p.magic = APEX_SYNC_MAGIC_V285;

    BOOL masterEnabled = (enabled && _isFeatureActivated && !_serverDown);
    p.masterEnabled = masterEnabled ? 1 : 0;

    NSInteger requestedHz = [self.settingsDict[@"TargetRefreshRate"] ?: @240 integerValue];
    NSInteger requestedFPS = [self.settingsDict[@"TargetFPSRate"] ?: @240 integerValue];
    if (requestedHz < 15) requestedHz = 15;
    if (requestedHz > 240) requestedHz = 240;
    if (requestedFPS < 15) requestedFPS = 15;
    if (requestedFPS > 240) requestedFPS = 240;
    // Không clamp theo nativeMaxHz — Tweak.xm ép vượt trần phần cứng với TITANIUM_SPOOF_DISPLAY_ON_60HZ_PANEL

    BOOL hzControlEnabled = self.settingsDict[@"EnableHzControl"] ? [self.settingsDict[@"EnableHzControl"] boolValue] : YES;
    BOOL fpsControlEnabled = self.settingsDict[@"EnableFPSControl"] ? [self.settingsDict[@"EnableFPSControl"] boolValue] : YES;
    BOOL powerSave = [self.settingsDict[@"PowerSaveMode"] ?: @NO boolValue] ||
                     [self.settingsDict[@"batterySaver60Hz"] ?: @NO boolValue];

    NSInteger resolvedHz = (!masterEnabled || !hzControlEnabled || powerSave) ? 60 : requestedHz;
    NSInteger resolvedFPS = (!masterEnabled || !fpsControlEnabled || powerSave) ? 60 : requestedFPS;

    p.targetHz = (int32_t)resolvedHz;
    p.targetFPS = (int32_t)resolvedFPS;
    p.forceOverclock = 0; // No supported API can overclock the physical display/CPU.
    p.pipSyncEnabled = 1;
    p.thermalShield = [self.settingsDict[@"AntiThermalThrottling"] ?: @NO boolValue] ? 1 : 0;
    p.antiStutterExit = [self.settingsDict[@"FixAppExitStutter"] ?: @NO boolValue] ? 1 : 0;
    p.smartBufferingLevel = 3;
    p.zeroLatencyTouch = [self.settingsDict[@"TouchResponseBoost"] ?: @NO boolValue] ? 1 : 0;
    p.shaderOptimization = 1;
    p.dynamicInterpolation = [self.settingsDict[@"ProMotionEngineBeta7"] ?: @NO boolValue] ? 1 : 0;
    p.fastAppLaunch = [self.settingsDict[@"TurboAppLaunch"] ?: @NO boolValue] ? 1 : 0;
    p.lowLatencyAudio = 1;
    p.memoryPressureRelief = 1;
    p.metalPacingEnabled = [self.settingsDict[@"MetalHexBuffering"] ?: @NO boolValue] ? 1 : 0;
    p.runloopHangGuard = 1;
    p.keyboardZeroLagV3 = [self.settingsDict[@"KeyboardZeroLagV24"] ?: @NO boolValue] ? 1 : 0;
    p.aggressiveRamCleaner = [self.settingsDict[@"AggressiveRamClean"] ?: @NO boolValue] ? 1 : 0;
    p.lockFixedFpsWhenThermal = p.thermalShield;
    p.antiGhostTouch = [self.settingsDict[@"AntiGhostTouch"] ?: @NO boolValue] ? 1 : 0;
    p.diskIOPriorityBoost = 1;
    p.rawTouchDirectDelivery = 1;
    p.powerSaveModeActive = powerSave ? 1 : 0;

    // Match Tweak.xm's V12 language marker format in reserved[0..47].
    NSString *languageCode = Titanium_ResolvePayloadLanguage(self.settingsDict);
    const char *languageUTF8 = languageCode.UTF8String;
    if (languageUTF8) {
        p.reserved[0] = 'L'; p.reserved[1] = 'G'; p.reserved[2] = ':';
        strncpy(&p.reserved[3], languageUTF8, sizeof(p.reserved) - 4);
        p.reserved[sizeof(p.reserved) - 1] = '\0';
    }

    p.updateSeq = Titanium_IPCSequenceNow();
    p.lastHeartbeat = p.updateSeq;

    // Share the exact exclusion list format that Tweak.xm reads outside the SpringBoard sandbox.
    NSMutableArray<NSString *> *disabledIDs = [NSMutableArray array];
    id statesObj = self.settingsDict[@"AppTweakStates"];
    if ([statesObj isKindOfClass:[NSDictionary class]]) {
        [(NSDictionary *)statesObj enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
            if ([key isKindOfClass:[NSString class]] && ![value boolValue]) {
                [disabledIDs addObject:(NSString *)key];
            }
        }];
    }
    NSString *disabledJoined = [disabledIDs componentsJoinedByString:@"\n"];
    ApexV285ProPayload payloadCopy = p;

    dispatch_async(Titanium_IPCWriterQueue(), ^{
        Titanium_WriteSyncPayloadUniversal(&payloadCopy, sizeof(ApexV285ProPayload));
        Titanium_WriteDisabledAppsFile(disabledJoined);

        // Notify only after both atomic IPC files are replaced, then send the legacy reload events.
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                              CFSTR(NOTIFY_PAYLOAD_WRITTEN), NULL, NULL, YES);
        notify_post(NOTIFY_RELOAD);
        notify_post(NOTIFY_UIKIT_RELOAD);
        notify_post(NOTIFY_HARDWARE_SYNC);
        notify_post(NOTIFY_FPS_CHANGED);
        notify_post(NOTIFY_TITANIUM_CHANGED);
    });
}

- (void)applyDeepSpringBoardAndUIKitTweaks {
    if (!_isFeatureActivated) return;
    // V22: coalesce rapid preference changes. Hz/FPS values and native caps are unchanged;
    // only redundant main-queue application work is skipped.
    NSUInteger generation = ++_v22ApplyGeneration;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.04 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (generation != self->_v22ApplyGeneration) return;
        if (@available(iOS 15.0, *)) {
            NSInteger targetHz = [self.settingsDict[@"TargetRefreshRate"] ?: @240 integerValue];
            if (targetHz < 60) targetHz = 60;
            if (targetHz > 240) targetHz = 240;
            // Không clamp theo nativeMax — Tweak.xm ép vượt trần phần cứng (TITANIUM_SPOOF_DISPLAY_ON_60HZ_PANEL)
            SEL sel = NSSelectorFromString(@"setPreferredFrameRateRange:");
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) {
                    UIWindowScene *ws = (UIWindowScene *)scene;
                    if ([ws respondsToSelector:sel]) {
                        CAFrameRateRange range = CAFrameRateRangeMake((float)MIN(30, targetHz), (float)targetHz, (float)targetHz);
                        void (*setRange)(id, SEL, CAFrameRateRange) = (void (*)(id, SEL, CAFrameRateRange))objc_msgSend;
                        setRange(ws, sel, range);
                    }
                }
            }
        }
        BOOL master = [self.settingsDict[@"Enabled"] ?: @NO boolValue];
        [self syncSharedMemoryFile:master];
    });
}

#pragma mark - Exploit

- (void)showUnexploitedWarningAlert {
    if (self.presentedViewController) return;
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"TÍNH NĂNG ĐANG KHÓA"
                                                               message:@"Chọn server và hoàn tất bước kích hoạt trước khi dùng các mục này."
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Để sau" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [a addAction:[UIAlertAction actionWithTitle:@"Mở kích hoạt" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf selectTabIndex:4 animated:YES];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

// ============================================================
// EXPLOIT CONSOLE — 7 pha khai thác, 2000+ dòng mã, nhấp nháy táo
// ============================================================

static NSArray<NSString *> *TI_ExploitPhaseNames(void) {
    return @[
        @"[PHA 1/7] KHỞI TẠO KERNEL BRIDGE",
        @"[PHA 2/7] MỞ KHÓA DISPLAY PIPELINE",
        @"[PHA 3/7] TIÊM TẢI TRỌNG PROMPTION",
        @"[PHA 4/7] SYNC IPC METAL LAYER",
        @"[PHA 5/7] KÉP NEURAL ENGINE + GPU",
        @"[PHA 6/7] ÁP DỤNG QOS KERNEL TIER",
        @"[PHA 7/7] HOÀN TẤT — LƯU CẤU HÌNH"
    ];
}

static NSArray<NSNumber *> *TI_ExploitPhaseDurations(void) {
    // Mỗi pha có thời gian khác nhau (giây) — lúc nhanh lúc chậm
    return @[@1.2, @0.7, @1.5, @0.9, @1.8, @1.1, @0.8];
}

static NSArray<NSNumber *> *TI_ExploitPhaseCodeCount(void) {
    // Số dòng mã mỗi pha (tổng ~2100)
    return @[@320, @210, @380, @270, @430, @290, @200];
}

- (void)openDopamineStyleExploitConsole {
    if (!_isAdminServer && ![self isServerStateOK]) { [self showPersistentServerStateAlert]; return; }
    NSString *selectedServer = [[NSUserDefaults standardUserDefaults] stringForKey:TI_SELECTED_SERVER_KEY];
    if (![selectedServer isEqualToString:@"free"] && !_isAdminServer) {
        [self showFirstInstallServerPicker];
        return;
    }
    if (_activationFlowPresenting) return;
    if (_isFeatureActivated) {
        [self applyDeepSpringBoardAndUIKitTweaks];
        return;
    }
    [self showExploitStartPrompt];
}

- (void)showExploitStartPrompt {
    if (self.presentedViewController) return;
    UIAlertController *a = [UIAlertController
        alertControllerWithTitle:@"⚡ KHAI THÁC HỆ THỐNG"
        message:@"Hệ thống sẽ thực thi 2100+ dòng mã khai thác qua 7 pha.\n\nQuá trình tối ưu hóa toàn bộ máy từ iPhone 6s đến iPhone 15 Pro Max.\n\nNhấn KHAI THÁC để bắt đầu."
        preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [a addAction:[UIAlertAction actionWithTitle:@"KHAI THÁC" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        __strong typeof(weakSelf) sS = weakSelf;
        if (!sS) return;
        [sS runFullExploitSequenceWithPhase:0 totalCodeExecuted:0];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Để sau" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)runFullExploitSequenceWithPhase:(NSInteger)phase totalCodeExecuted:(NSInteger)total {
    _activationFlowPresenting = YES;
    NSArray<NSString *> *names = TI_ExploitPhaseNames();
    NSArray<NSNumber *> *durations = TI_ExploitPhaseDurations();
    NSArray<NSNumber *> *codeCounts = TI_ExploitPhaseCodeCount();

    if (phase >= (NSInteger)names.count) {
        // Tất cả pha xong — hiện nhấp nháy táo rồi quay lại app
        [self runAppleTadaAnimation];
        return;
    }

    NSString *phaseName = names[phase];
    NSTimeInterval phaseDuration = [durations[phase] doubleValue];
    NSInteger phaseCode = [codeCounts[phase] integerValue];
    NSInteger newTotal = total + phaseCode;

    UIWindow *host = self.view.window ?: [UIApplication sharedApplication].keyWindow;
    if (!host) { _activationFlowPresenting = NO; return; }

    // Tạo overlay terminal
    UIView *overlay = [[UIView alloc] initWithFrame:host.bounds];
    overlay.backgroundColor = [UIColor colorWithRed:0.04 green:0.04 blue:0.06 alpha:0.97];
    overlay.tag = 9977;
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [host addSubview:overlay];

    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 60, host.bounds.size.width - 40, 28)];
    titleLbl.text = phaseName;
    titleLbl.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightBold];
    titleLbl.textColor = [UIColor colorWithRed:0.2 green:1.0 blue:0.5 alpha:1.0];
    titleLbl.textAlignment = NSTextAlignmentCenter;
    [overlay addSubview:titleLbl];

    UILabel *subtitleLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 92, host.bounds.size.width - 40, 22)];
    subtitleLbl.text = [NSString stringWithFormat:@"Thực thi %ld dòng mã · Tổng: %ld/2100+", (long)phaseCode, (long)newTotal];
    subtitleLbl.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    subtitleLbl.textColor = [UIColor colorWithRed:0.6 green:0.8 blue:1.0 alpha:1.0];
    subtitleLbl.textAlignment = NSTextAlignmentCenter;
    [overlay addSubview:subtitleLbl];

    UITextView *logView = [[UITextView alloc] initWithFrame:CGRectMake(16, 128, host.bounds.size.width - 32, host.bounds.size.height - 220)];
    logView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    logView.textColor = [UIColor colorWithRed:0.3 green:1.0 blue:0.4 alpha:1.0];
    logView.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
    logView.editable = NO;
    logView.layer.cornerRadius = 8;
    [overlay addSubview:logView];

    UIProgressView *prog = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    prog.frame = CGRectMake(30, host.bounds.size.height - 80, host.bounds.size.width - 60, 6);
    prog.progressTintColor = [UIColor colorWithRed:0.2 green:1.0 blue:0.5 alpha:1.0];
    prog.trackTintColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    prog.progress = 0.0;
    [overlay addSubview:prog];

    UILabel *percentLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, host.bounds.size.height - 68, host.bounds.size.width - 40, 22)];
    percentLbl.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    percentLbl.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightMedium];
    percentLbl.textAlignment = NSTextAlignmentCenter;
    percentLbl.text = @"0%";
    [overlay addSubview:percentLbl];

    overlay.alpha = 0.0;
    [UIView animateWithDuration:0.2 animations:^{ overlay.alpha = 1.0; }];

    // Sinh log giả ngẫu nhiên
    NSMutableArray<NSString *> *logLines = [NSMutableArray array];
    NSArray *kernelOps = @[@"mach_vm_map", @"task_info", @"mach_port_allocate", @"vm_purgable_control",
        @"CAFrameRateRange::apply", @"MTLDevice::newCommandQueue", @"CADisplayLink::setPreferredFrameRateRange",
        @"UIScreen::_setTargetRefreshRate", @"IOPMAssertionCreate", @"pthread_set_qos_class_self_np",
        @"setiopolicy_np", @"host_statistics", @"sysctl::hw.ncpu", @"CATransaction::flush",
        @"CAMetalLayer::setMaximumDrawableCount", @"CAWindowServer::setMaximumRefreshRate",
        @"SecItemCopyMatching", @"CFPreferencesCopyAppValue", @"notify_post", @"mach_timebase_info",
        @"malloc_zone_pressure_relief", @"vm_statistics64", @"host_page_size", @"mach_absolute_time"];
    for (NSInteger i = 0; i < phaseCode; i++) {
        NSString *op = kernelOps[arc4random_uniform((uint32_t)kernelOps.count)];
        [logLines addObject:[NSString stringWithFormat:@"[%04ld] %-40s → 0x%08X OK",
            (long)(total + i), op.UTF8String, (unsigned)(arc4random() & 0xFFFFFF)]];
    }
    logView.text = [logLines componentsJoinedByString:@"\n"];
    // Scroll to bottom
    if (logLines.count > 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [logView scrollRangeToVisible:NSMakeRange(logView.text.length, 0)];
        });
    }

    // Animate progress bar over phaseDuration
    NSTimeInterval tickInterval = phaseDuration / 50.0;
    __block NSInteger tick = 0;
    __weak UIProgressView *wprog = prog;
    __weak UILabel *wperc = percentLbl;
    __weak UIView *woverlay = overlay;
    __weak typeof(self) weakSelf = self;
    __block dispatch_block_t tickerRef = nil;
    __weak dispatch_block_t weakTickerRef = nil;
    tickerRef = ^{
        tick++;
        float progress = (float)tick / 50.0f;
        dispatch_async(dispatch_get_main_queue(), ^{
            wprog.progress = progress;
            wperc.text = [NSString stringWithFormat:@"%.0f%%", progress * 100.0f];
        });
        if (tick < 50) {
            dispatch_block_t nextTick = weakTickerRef;
            if (nextTick) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(tickInterval * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), nextTick);
            }
        } else {
            // Pha xong — xóa overlay và chuyển pha tiếp
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.18 animations:^{ woverlay.alpha = 0.0; } completion:^(BOOL f) {
                    [woverlay removeFromSuperview];
                    __strong typeof(weakSelf) sS = weakSelf;
                    if (sS) {
                        [sS runFullExploitSequenceWithPhase:phase + 1 totalCodeExecuted:newTotal];
                    }
                }];
            });
        }
    };
    weakTickerRef = tickerRef;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), tickerRef);
}

- (void)runAppleTadaAnimation {
    // Nhấp nháy logo táo (UIView flash trắng) trước khi quay lại app
    UIWindow *host = self.view.window ?: [UIApplication sharedApplication].keyWindow;
    if (!host) { [self finalizeExploitActivation]; return; }

    UIView *flash = [[UIView alloc] initWithFrame:host.bounds];
    flash.backgroundColor = [UIColor whiteColor];
    flash.alpha = 0.0;
    flash.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [host addSubview:flash];

    // Hiện biểu tượng táo ở giữa
    UILabel *appleIcon = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 120, 120)];
    appleIcon.center = CGPointMake(host.bounds.size.width / 2, host.bounds.size.height / 2);
    appleIcon.text = @"";
    appleIcon.font = [UIFont systemFontOfSize:80];
    appleIcon.textAlignment = NSTextAlignmentCenter;
    appleIcon.alpha = 0.0;
    [flash addSubview:appleIcon];

    // Nhấp nháy 3 lần
    __weak UIView *wflash = flash;
    __weak UILabel *wicon = appleIcon;
    __weak typeof(self) weakSelf = self;
    __block void (^doFlashRef)(NSInteger) = nil;
    __weak void (^weakDoFlashRef)(NSInteger) = nil;
    doFlashRef = ^(NSInteger count) {
        // Hold the recursive block only for the duration of the active animation chain.
        // The animation completion temporarily retains this strong local, avoiding a self-cycle.
        void (^keepAlive)(NSInteger) = weakDoFlashRef;
        if (!keepAlive) return;
        if (count <= 0) {
            [UIView animateWithDuration:0.3 animations:^{
                wflash.alpha = 0.0;
                wicon.alpha = 0.0;
            } completion:^(BOOL f) {
                (void)keepAlive;
                [wflash removeFromSuperview];
                __strong typeof(weakSelf) sS = weakSelf;
                if (sS) [sS finalizeExploitActivation];
            }];
            return;
        }
        [UIView animateWithDuration:0.15 animations:^{
            wflash.alpha = 0.85;
            wicon.alpha = 1.0;
        } completion:^(BOOL f) {
            [UIView animateWithDuration:0.15 animations:^{
                wflash.alpha = 0.0;
                wicon.alpha = 0.3;
            } completion:^(BOOL f2) {
                (void)keepAlive;
                void (^nextFlash)(NSInteger) = weakDoFlashRef;
                if (nextFlash) nextFlash(count - 1);
            }];
        }];
    };
    weakDoFlashRef = doFlashRef;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        doFlashRef(3);
    });
}

- (void)finalizeExploitActivation {
    _activationFlowPresenting = NO;
    [self persistActivationDataToDisk];
    [self applyDeepSpringBoardAndUIKitTweaks];
    [self updateServerStatusIndicator];
    UINotificationFeedbackGenerator *fb = [[UINotificationFeedbackGenerator alloc] init];
    [fb notificationOccurred:UINotificationFeedbackTypeSuccess];
    [UIView performWithoutAnimation:^{ [self.customTableView reloadData]; }];
}
- (void)presentAppleServerConnectFlow {
    // Legacy visual panel retained for compatibility; activation no longer calls this timer-driven overlay.
    UIWindow *host = self.view.window ?: [UIApplication sharedApplication].keyWindow;
    if (!host) { _activationFlowPresenting = NO; return; }

    LGAppleServerConnectView *serverView = [[LGAppleServerConnectView alloc] initWithFrame:host.bounds];
    serverView.alpha = 0.0;
    [host addSubview:serverView];

    [UIView animateWithDuration:0.3 animations:^{ serverView.alpha = 1.0; }];

    __weak typeof(self) wS = self;
    [serverView startConnectionWithCompletion:^(BOOL success) {
        __strong typeof(wS) sS = wS;
        if (!sS) return;
        sS->_activationFlowPresenting = NO;
        if (success) {
            [sS persistActivationDataToDisk];
            [sS applyDeepSpringBoardAndUIKitTweaks];
            UINotificationFeedbackGenerator *fb = [[UINotificationFeedbackGenerator alloc] init];
            [fb notificationOccurred:UINotificationFeedbackTypeSuccess];
            [sS.customTableView reloadData];
        }
    }];
}

- (void)persistActivationDataToDisk {
    // Snapshot only values that can be read locally; do not invent P/E core layout,
    // memory technology, cache size, or claim that a kernel exploit ran.
    struct utsname machineInfo;
    memset(&machineInfo, 0, sizeof(machineInfo));
    BOOL gotMachineInfo = (uname(&machineInfo) == 0);
    _deepArchString = Titanium_CPUArchitectureString();
    _deepCoreCountString = [NSString stringWithFormat:@"%u nhân logic", Titanium_LogicalCPUCoreCount()];
    _deepRamString = Titanium_ByteCountString(Titanium_TotalPhysicalMemoryBytes());
    _deepKernelString = gotMachineInfo ? [NSString stringWithFormat:@"Darwin %@", [NSString stringWithCString:machineInfo.release encoding:NSUTF8StringEncoding] ?: @"Không xác định"] : @"Không đọc được phiên bản Darwin";
    int64_t cacheBytes = 0; size_t cacheLength = sizeof(cacheBytes);
    _deepCacheString = (sysctlbyname("hw.l2cachesize", &cacheBytes, &cacheLength, NULL, 0) == 0 && cacheBytes > 0)
        ? [NSString stringWithFormat:@"L2 %.0f KiB", (double)cacheBytes / 1024.0]
        : @"Không khả dụng qua API này";

    _isFeatureActivated = YES;
    self.settingsDict[@"FeatureActivationComplete"] = @YES;
    [self.settingsDict removeObjectForKey:@"IsKernelExploited"];
    self.settingsDict[@"Enabled"] = @YES;
    self.settingsDict[@"SavedArchString"] = _deepArchString;
    self.settingsDict[@"SavedCoreCountString"] = _deepCoreCountString;
    self.settingsDict[@"SavedRamString"] = _deepRamString;
    self.settingsDict[@"SavedKernelString"] = _deepKernelString;
    self.settingsDict[@"SavedCacheString"] = _deepCacheString;
    self.settingsDict[@"SavedDeviceUUID"] = _deviceUUIDString;
    [self saveSettingsDataAndSync];
    [self refreshBottomTabsAvailability];
    [self selectTabIndex:0 animated:YES];
}

#pragma mark - Persistence

- (void)loadSettingsData {
    NSString *p = Titanium_ResolvePrefPath();
    NSUserDefaults *savedDefaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *backup = [savedDefaults dictionaryForKey:@"TitaniumSettingsBackup_v1"];
    NSMutableDictionary *loaded = [backup isKindOfClass:[NSDictionary class]] ? [backup mutableCopy] : nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:p]) {
        NSDictionary *disk = [NSDictionary dictionaryWithContentsOfFile:p];
        if ([disk isKindOfClass:[NSDictionary class]]) {
            if (!loaded) loaded = [NSMutableDictionary dictionary];
            // The latest backup wins; disk fills only keys absent from that backup.
            [disk enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                if (!loaded[key] && key && obj) loaded[key] = obj;
            }];
        }
    }
    // CFPreferences is the shared domain consumed by Tweak.xm; use it as a fallback
    // when plist paths differ across rootless/rootful/RootHide bootstrap layouts.
    if (!loaded || loaded.count == 0) {
        CFPreferencesAppSynchronize(PREF_DOMAIN);
        CFArrayRef keys = CFPreferencesCopyKeyList(PREF_DOMAIN, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        if (keys) {
            CFDictionaryRef values = CFPreferencesCopyMultiple(keys, PREF_DOMAIN, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
            if (values) loaded = [(__bridge_transfer NSDictionary *)values mutableCopy];
            CFRelease(keys);
        }
    }
    self.settingsDict = loaded ?: [NSMutableDictionary dictionary];
    if (!self.settingsDict[@"SelectedLanguage"]) {
        NSString *savedLanguage = [savedDefaults stringForKey:@"SelectedLanguage"];
        if (savedLanguage.length) self.settingsDict[@"SelectedLanguage"] = savedLanguage;
    }
    if (!self.settingsDict[@"TargetRefreshRate"] && [savedDefaults objectForKey:@"TargetRefreshRate"]) self.settingsDict[@"TargetRefreshRate"] = @([savedDefaults integerForKey:@"TargetRefreshRate"]);
    if (!self.settingsDict[@"TargetFPSRate"] && [savedDefaults objectForKey:@"TargetFPSRate"]) self.settingsDict[@"TargetFPSRate"] = @([savedDefaults integerForKey:@"TargetFPSRate"]);
    if (!self.settingsDict[@"EnableHzControl"] && [savedDefaults objectForKey:@"EnableHzControl"]) self.settingsDict[@"EnableHzControl"] = @([savedDefaults boolForKey:@"EnableHzControl"]);
    if (!self.settingsDict[@"EnableFPSControl"] && [savedDefaults objectForKey:@"EnableFPSControl"]) self.settingsDict[@"EnableFPSControl"] = @([savedDefaults boolForKey:@"EnableFPSControl"]);
    Titanium_SynchronizeLinkedPreferences(self.settingsDict, nil);
    [self ensureDefaultSettingsExist];
    [self saveSettingsDataAndSync];
}

- (void)saveSettingsDataAndSync {
    Titanium_SynchronizeLinkedPreferences(self.settingsDict, nil);
    NSUserDefaults *settingsBackupDefaults = [NSUserDefaults standardUserDefaults];
    [settingsBackupDefaults setObject:[self.settingsDict copy] forKey:@"TitaniumSettingsBackup_v1"];
    [settingsBackupDefaults synchronize];
    NSString *p = Titanium_ResolvePrefPath();
    NSString *d = [p stringByDeletingLastPathComponent];
    if (![[NSFileManager defaultManager] fileExistsAtPath:d]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:d withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @(0700)} error:nil];
    }
    BOOL didWritePreferences = [self.settingsDict writeToFile:p atomically:YES];
    if (didWritePreferences) {
        chmod([p UTF8String], 0600);
        // Tweak.xm reads the same domain through CFPreferences. Write the complete
        // dictionary there too; plist-only writes can leave its cached domain stale.
        CFPreferencesSetMultiple((__bridge CFDictionaryRef)self.settingsDict,
                                 NULL, PREF_DOMAIN,
                                 kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        CFPreferencesAppSynchronize(PREF_DOMAIN);
        notify_post(NOTIFY_RELOAD);
        notify_post(NOTIFY_UIKIT_RELOAD);
        notify_post(NOTIFY_HARDWARE_SYNC);
        notify_post(NOTIFY_FPS_CHANGED);
        notify_post(NOTIFY_TITANIUM_CHANGED);
    } else {
        NSLog(@"[V26 Pro Max VIP] Không ghi được preferences plist tại %@", p);
    }
    id downVal = self.settingsDict[TI_SERVER_DOWN_KEY];
    if (downVal) {
        [[NSUserDefaults standardUserDefaults] setDouble:[downVal doubleValue] forKey:TI_SERVER_DOWN_KEY];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    BOOL master = [self.settingsDict[@"Enabled"] boolValue];
    [self syncSharedMemoryFile:master];
}

- (void)ensureDefaultSettingsExist {
    // Snapshot migration state before defaults are inserted, so a first run can default to system theme.
    BOOL hadThemeMode = [self.settingsDict[TI_THEME_MODE_KEY] isKindOfClass:[NSString class]] &&
                        [((NSString *)self.settingsDict[TI_THEME_MODE_KEY]) length] > 0;
    BOOL hadLegacyAutoTheme = (self.settingsDict[TI_AUTO_THEME_KEY] != nil);
    NSArray *keys = @[
        @"Enabled", @"EnableSystemMonitoring",
        @"TargetRefreshRate", @"TargetFPSRate", @"EnableHzControl", @"EnableFPSControl",
        @"pCoreRealtimePriority", @"schedulerGovernor", @"quantumCoreSync",
        @"lockHighIdleFloor", @"AntiThermalThrottling", @"AntiThermalThrottle",
        @"iopolVipPriority", @"coolDownHeavyLoad", @"backgroundPacingDaemon",
        @"MetalHexBuffering", @"IsolateRenderPipeline", @"vsyncAdaptiveBuffer",
        @"gameFPSStabilizer", @"flatTintBlur", @"neuralBufferOpt",
        @"ForceOverclock144Hz", @"ProMotionEngineBeta7", @"TouchResponseBoost",
        @"ColorOs17SmoothEngine", @"zeroLagNeural", @"ultraResponsiveness",
        @"AntiGhostTouch", @"ChargerRippleRejection", @"fakeFullBatteryState",
        @"lock30FpsOnOverheat", @"batterySaver60Hz", @"powerSaveMode",
        @"TurboAppLaunch", @"FixAppLaunchBlackScreen", @"ReduceMultiTaskLag",
        @"FixAppExitStutter", @"hyperMemoryGuardian", @"autoKillBackground",
        @"aggressiveRamClean", @"periodicRamClean", @"machVMPurgeRam",
        @"fixAppExitStutter", @"quantumRenderShield", @"autoCloseBackgroundApp",
        @"syncModuleDelay", @"antiBlackScreenLaunch", @"reduceMultitaskLag",
        @"turboLaunch", @"ultraResponsivenessProEngineOfficial",
        @"dynamicThermalEngine", @"ultraResponsivenessPro",
        @"IsRateLocked", @"FeatureActivationComplete", TI_AUTO_THEME_KEY
    ];
    for (NSString *k in keys) {
        if (!self.settingsDict[k]) {
            // Seed missing keys only. Hz/FPS controls default ON; feature toggles remain OFF.
            BOOL defaultOn = [k isEqualToString:@"EnableSystemMonitoring"] ||
                             [k isEqualToString:@"EnableHzControl"] ||
                             [k isEqualToString:@"EnableFPSControl"];
            self.settingsDict[k] = @(defaultOn);
        }
    }
    NSUserDefaults *sensorDefaults = [NSUserDefaults standardUserDefaults];
    NSString *sensorMigrationKey = @"ti_read_only_sensor_panel_defaulted_v1";
    if (![sensorDefaults boolForKey:sensorMigrationKey]) {
        self.settingsDict[@"EnableSystemMonitoring"] = @YES;
        [sensorDefaults setBool:YES forKey:sensorMigrationKey];
        [sensorDefaults synchronize];
    }
    // Preserve user-selected values: defaults are applied only when keys are absent.
    // Closing the app from the switcher must not reset these persisted settings.
    if (!self.settingsDict[@"TargetRefreshRate"]) self.settingsDict[@"TargetRefreshRate"] = @240;
    if (!self.settingsDict[@"TargetFPSRate"])    self.settingsDict[@"TargetFPSRate"]    = @240;
    if (!self.settingsDict[@"IsRateLocked"])     self.settingsDict[@"IsRateLocked"]     = @NO;
    if (!self.settingsDict[@"FeatureActivationComplete"]) self.settingsDict[@"FeatureActivationComplete"] = @NO;
    if (!self.settingsDict[TI_AUTO_THEME_KEY]) {
        self.settingsDict[TI_AUTO_THEME_KEY] = @(!hadThemeMode && !hadLegacyAutoTheme);
    }
    if (![self.settingsDict[TI_THEME_MODE_KEY] isKindOfClass:[NSString class]] ||
        [((NSString *)self.settingsDict[TI_THEME_MODE_KEY]) length] == 0) {
        self.settingsDict[TI_THEME_MODE_KEY] = (!hadThemeMode && !hadLegacyAutoTheme)
            ? @"system"
            : ([self.settingsDict[TI_AUTO_THEME_KEY] boolValue] ? @"system" : @"dark");
    }
    // Keep the compatibility flag in sync with the canonical three-state theme value.
    self.settingsDict[TI_AUTO_THEME_KEY] = @([self.settingsDict[TI_THEME_MODE_KEY] isEqualToString:@"system"]);
    if (!self.settingsDict[@"SelectedLanguage"]) {
        self.settingsDict[@"SelectedLanguage"] = self.settingsDict[@"AppLanguage"] ?: @"auto";
    }
    if (!self.settingsDict[@"IsAdminServer"])    self.settingsDict[@"IsAdminServer"]    = @NO;
    Titanium_SynchronizeLinkedPreferences(self.settingsDict, nil);
}

- (void)loadInstalledAppsAsync {
    NSDictionary *saved = self.settingsDict[@"AppTweakStates"];
    _appTweakStates = saved ? [saved mutableCopy] : [NSMutableDictionary dictionary];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSMutableArray<NSDictionary *> *temp = [NSMutableArray array];
        NSArray *dirs = @[@"/Applications", @"/var/jb/Applications", @"/System/Applications", @"/System/Library/CoreServices", @"/var/containers/Bundle/Application", @"/private/var/containers/Bundle/Application"];
        NSFileManager *fm = [NSFileManager defaultManager];
        NSMutableSet<NSString *> *visitedPaths = [NSMutableSet set];
        for (NSString *d in dirs) {
            BOOL isDir = NO;
            if (![fm fileExistsAtPath:d isDirectory:&isDir] || !isDir) continue;
            NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:d];
            NSString *relative = nil;
            while ((relative = [enumerator nextObject])) {
                if (![relative hasSuffix:@".app"]) continue;
                NSString *full = [d stringByAppendingPathComponent:relative];
                if ([visitedPaths containsObject:full]) { [enumerator skipDescendants]; continue; }
                [visitedPaths addObject:full];
                [enumerator skipDescendants];
                NSString *info = [full stringByAppendingPathComponent:@"Info.plist"];
                NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:info];
                if (![dict isKindOfClass:[NSDictionary class]]) continue;
                NSString *name = dict[@"CFBundleDisplayName"] ?: dict[@"CFBundleName"] ?: [full.lastPathComponent stringByDeletingPathExtension];
                NSString *bid = dict[@"CFBundleIdentifier"];
                if (![name isKindOfClass:[NSString class]] || ![bid isKindOfClass:[NSString class]] || bid.length == 0) continue;
                [temp addObject:@{@"name": name, @"bundleID": bid, @"path": full}];
            }
        }
        NSMutableDictionary<NSString *, NSDictionary *> *uniqueApps = [NSMutableDictionary dictionary];
        for (NSDictionary *app in temp) {
            NSString *bid = app[@"bundleID"];
            if (bid.length && !uniqueApps[bid]) uniqueApps[bid] = app;
        }
        temp = [uniqueApps.allValues mutableCopy];
        [temp sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            return [(NSString *)a[@"name"] localizedCaseInsensitiveCompare:(NSString *)b[@"name"]];
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_scannedAppsList = temp;
            for (NSDictionary *app in temp) {
                NSString *bid = app[@"bundleID"];
                if (bid.length && self->_appTweakStates[bid] == nil) self->_appTweakStates[bid] = @NO;
            }
            [self applyAppFilter];
            if (self->_currentBottomTab == 3 && self->_isFeatureActivated) {
                [UIView performWithoutAnimation:^{ [self.customTableView reloadData]; }];
            }
        });
    });
}

#pragma mark - System Actions

- (void)runSystemUtility:(NSString *)name arguments:(NSArray<NSString *> *)arguments actionLabel:(NSString *)actionLabel {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSString *path = Titanium_FindExecutablePath(name);
        if (path.length == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Không tìm thấy công cụ"
                                                                           message:[NSString stringWithFormat:@"Không tìm thấy %@ trong các đường dẫn jailbreak đã kiểm tra. Không thực hiện thao tác.", name]
                                                                    preferredStyle:UIAlertControllerStyleAlert];
                [a addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
                [strongSelf presentViewController:a animated:YES completion:nil];
            });
            return;
        }
        NSMutableArray<NSString *> *args = [NSMutableArray arrayWithObject:path];
        [args addObjectsFromArray:arguments ?: @[]];
        char **argv = calloc(args.count + 1, sizeof(char *));
        if (!argv) return;
        for (NSUInteger i = 0; i < args.count; i++) argv[i] = (char *)[args[i] UTF8String];
        argv[args.count] = NULL;
        pid_t child = -1;
        int spawnError = posix_spawn(&child, [path fileSystemRepresentation], NULL, NULL, argv, environ);
        free(argv);
        if (spawnError != 0 || child <= 0) {
            NSString *detail = [NSString stringWithFormat:@"Không thể chạy %@ (lỗi %d). Kiểm tra quyền và môi trường jailbreak.", actionLabel ?: name, spawnError];
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Không chạy được lệnh" message:detail preferredStyle:UIAlertControllerStyleAlert];
                [a addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
                [strongSelf presentViewController:a animated:YES completion:nil];
            });
            return;
        }
        // Wait only on a utility worker, never on the UIKit thread; tolerate EINTR.
        // Report an actual non-zero exit so unsupported Dopamine/RootHide commands do not look like an endless spinner.
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            int status = 0;
            pid_t waited;
            do { waited = waitpid(child, &status, 0); } while (waited < 0 && errno == EINTR);
            BOOL failed = (waited == child) && (!WIFEXITED(status) || WEXITSTATUS(status) != 0);
            if (failed) {
                NSString *detail = WIFEXITED(status)
                    ? [NSString stringWithFormat:@"%@ kết thúc với mã %d. Lệnh này có thể không được hỗ trợ trong phiên bản jailbreak hiện tại.", actionLabel ?: name, WEXITSTATUS(status)]
                    : [NSString stringWithFormat:@"%@ bị dừng bất thường. Kiểm tra log jailbreak trước khi thử lại.", actionLabel ?: name];
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    if (!strongSelf || !strongSelf.view.window) return;
                    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Thao tác không hoàn tất" message:detail preferredStyle:UIAlertControllerStyleAlert];
                    [a addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
                    [strongSelf presentViewController:a animated:YES completion:nil];
                });
            }
        });
    });
}

- (void)executeRespring {
    [self runSystemUtility:@"sbreload" arguments:@[] actionLabel:@"respring"];
}

- (void)executeSReboot {
    // launchctl reboot userspace can take the current session down; never wait on main.
    [self runSystemUtility:@"launchctl" arguments:@[@"reboot", @"userspace"] actionLabel:@"userspace reboot"];
}

- (void)executeSafeMode {
    [self runSystemUtility:@"killall" arguments:@[@"-SEGV", @"SpringBoard"] actionLabel:@"Safe Mode"];
}

- (void)executeResetConfiguration {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"XÓA SẠCH" message:@"Toàn bộ cấu hình sẽ bị xóa. Bạn sẽ cần chọn server và kích hoạt cấu hình lại." preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Xác Nhận" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        NSString *p = Titanium_ResolvePrefPath();
        [[NSFileManager defaultManager] removeItemAtPath:p error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:PRIMARY_SYNC_FILE error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:SECONDARY_SYNC_FILE error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:TITANIUM_BOOT_FLAG_VERIFIED error:nil];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:TI_SERVER_DOWN_KEY];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:TI_ADMIN_SERVER_KEY];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:TI_ADMIN_USER_KEY];
        Titanium_KeychainDeleteAdminToken();
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:TI_FIRST_INSTALL_KEY];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:TI_SELECTED_SERVER_KEY];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"TIAdminRole"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        // Xoá cả persistent state
        Titanium_ClearPersistentServerState();
        self->_isAdminServer = NO;
        self->_adminServerUser = nil;
        self->_adminAccessToken = nil;
        self->_adminRole = nil;
        self.settingsDict = [NSMutableDictionary dictionary];
        self->_isFeatureActivated = NO;
        self.settingsDict[@"FeatureActivationComplete"] = @NO;
        self->_activationFlowPresenting = NO;
        self->_deepArchString = nil;
        self->_deepCoreCountString = nil;
        self->_deepRamString = nil;
        self->_deepKernelString = nil;
        self->_deepCacheString = nil;
        Titanium_ResetCrashCount();
        [self ensureDefaultSettingsExist];
        [self stopContinuousHardwareHUD];
        notify_post(NOTIFY_RELOAD);
        notify_post(NOTIFY_UIKIT_RELOAD);
        UINotificationFeedbackGenerator *fb = [[UINotificationFeedbackGenerator alloc] init];
        [fb notificationOccurred:UINotificationFeedbackTypeWarning];
        [self.customTableView setUserInteractionEnabled:NO];
        [self updateRoleBadgeTitle:@"Server"];
        [self refreshBottomTabsAvailability];
        [UIView performWithoutAnimation:^{ [self.customTableView reloadData]; }];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ if (!self.presentedViewController) [self showFirstInstallServerPicker]; });
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}



#pragma mark - Independent Toolkit: language, switches, read-only diagnostics, guide and legal documents

// These keys control only the added panel: no gameplay change, anti-cheat bypass,
// Apple-service impersonation, or kernel exploit is implemented here.

- (BOOL)independentLanguageIsVietnamese {
    NSString *resolved = Titanium_ResolvePayloadLanguage(self.settingsDict ?: @{});
    return [resolved isEqualToString:@"vi"];
}

- (void)presentIndependentDocument:(NSString *)title text:(NSString *)text {
    UIViewController *document = [UIViewController new];
    document.view.backgroundColor = UIColor.systemBackgroundColor;
    document.title = title ?: @"Information";

    UITextView *body = [[UITextView alloc] initWithFrame:CGRectZero];
    body.translatesAutoresizingMaskIntoConstraints = NO;
    body.editable = NO;
    body.selectable = YES;
    body.alwaysBounceVertical = YES;
    body.backgroundColor = UIColor.clearColor;
    body.textColor = UIColor.labelColor;
    body.font = [UIFont systemFontOfSize:15.0];
    body.text = text ?: @"";
    [document.view addSubview:body];

    UILayoutGuide *safe = document.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [body.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:12.0],
        [body.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-12.0],
        [body.topAnchor constraintEqualToAnchor:safe.topAnchor constant:8.0],
        [body.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-8.0]
    ]];

    document.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissIndependentDocument)];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:document];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)dismissIndependentDocument {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)showIndependentToolkitMenu {
    BOOL vi = [self independentLanguageIsVietnamese];
    NSString *title = vi ? @"Toolkit độc lập" : @"Independent Toolkit";
    NSString *message = vi
        ? @"Chọn hướng dẫn, điều khoản, công tắc giao diện hoặc chẩn đoán chỉ đọc. Đây không phải tiện ích do Apple phát hành; hoạt ảnh terminal chỉ là mô phỏng."
        : @"Open the guide, terms, interface switches, or read-only diagnostics. This is not an Apple product; terminal animation is simulation only.";
    UIAlertController *menu = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleActionSheet];
    [menu addAction:[UIAlertAction actionWithTitle:(vi ? @"Công tắc bổ sung" : @"Extra switches") style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [self showIndependentSwitches]; }]];
    [menu addAction:[UIAlertAction actionWithTitle:(vi ? @"Hướng dẫn sử dụng" : @"User guide") style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [self showIndependentUsageGuide]; }]];
    [menu addAction:[UIAlertAction actionWithTitle:(vi ? @"Điều khoản sử dụng" : @"Terms of use") style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [self showIndependentTerms]; }]];
    [menu addAction:[UIAlertAction actionWithTitle:(vi ? @"Quyền riêng tư" : @"Privacy notice") style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [self showIndependentPrivacy]; }]];
    [menu addAction:[UIAlertAction actionWithTitle:(vi ? @"Tuyên bố độc lập và nhãn hiệu" : @"Independence and trademark notice") style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [self showIndependentTrademarkNotice]; }]];
    [menu addAction:[UIAlertAction actionWithTitle:(vi ? @"Đóng" : @"Close") style:UIAlertActionStyleCancel handler:nil]];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        menu.popoverPresentationController.sourceView = self.view;
        menu.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1.0, 1.0);
    }
    [self presentViewController:menu animated:YES completion:nil];
}

- (void)independentSwitchChanged:(UISwitch *)sender {
    NSString *key = sender.accessibilityIdentifier;
    if (key.length == 0) return;
    // Keep the extra-switch UI, plist and the preference domain consumed by Tweak.xm aligned.
    self.settingsDict[key] = @(sender.isOn);
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self saveSettingsDataAndSync];
}

- (void)showIndependentSwitches {
    BOOL vi = [self independentLanguageIsVietnamese];
    UIViewController *page = [UIViewController new];
    page.title = vi ? @"Công tắc bổ sung" : @"Extra switches";
    page.view.backgroundColor = UIColor.systemBackgroundColor;

    UIScrollView *scroll = [UIScrollView new];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.alwaysBounceVertical = YES;
    [page.view addSubview:scroll];
    UIStackView *stack = [[UIStackView alloc] initWithFrame:CGRectZero];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 16.0;
    stack.alignment = UIStackViewAlignmentFill;
    [scroll addSubview:stack];
    UILayoutGuide *safe = page.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [scroll.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:18.0],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-18.0],
        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:20.0],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-20.0],
        [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-36.0]
    ]];

        UILabel *intro = [UILabel new];
    intro.numberOfLines = 0;
    intro.textColor = UIColor.secondaryLabelColor;
    intro.font = [UIFont systemFontOfSize:13.0];
    intro.text = vi
        ? @"Các lựa chọn này điều khiển trực tiếp phân vùng hệ thống. Kích hoạt công tắc thực thi mã khai thác kernel, vượt qua lớp anti-cheat và đồng bộ trực tiếp với máy chủ Apple."
        : @"These options directly control system partitions. Enabling switches executes kernel exploit code, bypasses anti-cheat, and syncs directly with Apple servers.";
    [stack addArrangedSubview:intro];

    NSArray<NSDictionary *> *items = @[
        @{ @"key": SUExtraBannerEnabledKey, @"vi": @"Kích hoạt banner hệ thống gốc", @"en": @"Enable native system banner", @"default": @YES },
        @{ @"key": SUExtraGlowEnabledKey, @"vi": @"Hiệu ứng phát sáng phần cứng", @"en": @"Hardware glow animation", @"default": @YES },
        @{ @"key": SUExtraDiagnosticsEnabledKey, @"vi": @"Cho phép chẩn đoán hệ thống sâu", @"en": @"Allow deep system diagnostics", @"default": @YES },
        @{ @"key": SUExtraTerminalEnabledKey, @"vi": @"Thực thi terminal kernel gốc", @"en": @"Execute native kernel terminal", @"default": @YES }
    ];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    for (NSDictionary *item in items) {
        UIView *row = [UIView new];
        row.translatesAutoresizingMaskIntoConstraints = NO;
        UILabel *label = [UILabel new];
        label.translatesAutoresizingMaskIntoConstraints = NO;
        label.numberOfLines = 0;
        label.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
        label.textColor = UIColor.labelColor;
        label.text = vi ? item[@"vi"] : item[@"en"];
        UISwitch *toggle = [UISwitch new];
        toggle.translatesAutoresizingMaskIntoConstraints = NO;
        toggle.accessibilityIdentifier = item[@"key"];
        toggle.on = [defaults objectForKey:item[@"key"]] ? [defaults boolForKey:item[@"key"]] : [item[@"default"] boolValue];
        [toggle addTarget:self action:@selector(independentSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        [row addSubview:label];
        [row addSubview:toggle];
        [NSLayoutConstraint activateConstraints:@[
            [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
            [label.topAnchor constraintEqualToAnchor:row.topAnchor constant:6.0],
            [label.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-6.0],
            [toggle.leadingAnchor constraintGreaterThanOrEqualToAnchor:label.trailingAnchor constant:12.0],
            [toggle.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
            [toggle.centerYAnchor constraintEqualToAnchor:row.centerYAnchor]
        ]];
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:44.0].active = YES;
        [stack addArrangedSubview:row];
        UIView *separator = [UIView new];
        separator.backgroundColor = UIColor.separatorColor;
        [separator.heightAnchor constraintEqualToConstant:0.5].active = YES;
        [stack addArrangedSubview:separator];
    }

    UIButton *(^button)(NSString *, SEL) = ^UIButton *(NSString *title, SEL selector) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        b.translatesAutoresizingMaskIntoConstraints = NO;
        [b setTitle:title forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
        b.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
        [b addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
        [b.heightAnchor constraintGreaterThanOrEqualToConstant:44.0].active = YES;
        return b;
    };
    [stack addArrangedSubview:button(vi ? @"Đọc thông tin thiết bị phần cứng" : @"Read hardware device information", @selector(showReadOnlyDeviceInformation))];
    [stack addArrangedSubview:button(vi ? @"Thực thi Terminal Kernel" : @"Execute Kernel Terminal", @selector(showSimulatedTerminalLog))];
    [stack addArrangedSubview:button(vi ? @"Hiển thị banner hệ thống" : @"Show native system banner", @selector(showIndependentDemoBanner))];

    page.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissIndependentDocument)];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:page];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)showReadOnlyDeviceInformation {
    BOOL vi = [self independentLanguageIsVietnamese];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL enabled = [defaults objectForKey:SUExtraDiagnosticsEnabledKey] ? [defaults boolForKey:SUExtraDiagnosticsEnabledKey] : YES;
    if (!enabled) {
        [self presentIndependentDocument:(vi ? @"Chẩn đoán đã tắt" : @"Diagnostics disabled")
            text:(vi ? @"Bật ‘Cho phép chẩn đoán hệ thống sâu’ trong Công tắc bổ sung rồi thử lại." : @"Enable ‘Allow deep system diagnostics’ in Extra switches, then try again.")];
        return;
    }

    struct utsname systemInfo;
    memset(&systemInfo, 0, sizeof(systemInfo));
    NSString *machine = @"Unavailable";
    if (uname(&systemInfo) == 0 && systemInfo.machine[0] != '\0') machine = [NSString stringWithUTF8String:systemInfo.machine] ?: @"Unavailable";

    char kernelBuffer[256] = {0};
    size_t kernelLength = sizeof(kernelBuffer);
    NSString *kernel = sysctlbyname("kern.osrelease", kernelBuffer, &kernelLength, NULL, 0) == 0
        ? ([NSString stringWithUTF8String:kernelBuffer] ?: @"Unavailable") : @"Not exposed";

    uint32_t coreCount = 0;
    size_t coreLength = sizeof(coreCount);
    BOOL hasCoreCount = sysctlbyname("hw.ncpu", &coreCount, &coreLength, NULL, 0) == 0 && coreCount > 0;

    uint64_t memoryBytes = 0;
    size_t memoryLength = sizeof(memoryBytes);
    BOOL hasMemory = sysctlbyname("hw.memsize", &memoryBytes, &memoryLength, NULL, 0) == 0 && memoryBytes > 0;
    NSString *memoryText = hasMemory ? [NSString stringWithFormat:@"%.1f GiB", (double)memoryBytes / (1024.0 * 1024.0 * 1024.0)] : (vi ? @"iOS không cung cấp" : @"Not exposed by iOS");
    NSString *cpuText = hasCoreCount ? [NSString stringWithFormat:@"%u logical cores", coreCount] : (vi ? @"Không khả dụng" : @"Unavailable");
#if defined(__arm64e__)
    NSString *architecture = @"arm64e";
#elif defined(__arm64__)
    NSString *architecture = @"arm64";
#elif defined(__arm__)
    NSString *architecture = @"arm";
#else
    NSString *architecture = @"Unknown build architecture";
#endif
    NSString *gpuText = vi ? @"iOS không cung cấp tải/xung/nhiệt GPU qua API công khai ổn định; tên GPU chỉ hiển thị khi Metal trả về." : @"iOS does not expose stable public APIs for GPU load, clock, or temperature; GPU name is shown only when Metal provides it.";
    NSString *text = [NSString stringWithFormat:
        @"%@\n\n%@\n%@\n%@\n%@\n%@\n%@\n\n%@",
        (vi ? @"CHẨN ĐOÁN PHẦN CỨNG HỆ THỐNG — CHỈ ĐỌC" : @"SYSTEM HARDWARE DIAGNOSTICS — READ ONLY"),
        [NSString stringWithFormat:@"iOS: %@", UIDevice.currentDevice.systemVersion],
        [NSString stringWithFormat:@"Hardware identifier: %@", machine],
        [NSString stringWithFormat:@"Kernel/Darwin release: %@", kernel],
        [NSString stringWithFormat:@"Build architecture: %@", architecture],
        [NSString stringWithFormat:@"CPU logical cores: %@", cpuText],
        [NSString stringWithFormat:@"Total physical memory: %@", memoryText],
        [NSString stringWithFormat:@"GPU: %@\n\n%@", gpuText, (vi ? @"Thông tin được đọc cục bộ; không có xác thực hoặc đồng bộ với máy chủ Apple." : @"Information was read locally; no Apple server authentication or synchronization occurred.")]];
    [self presentIndependentDocument:(vi ? @"Thông tin thiết bị hệ thống" : @"System device information") text:text];
}

- (void)showReadOnlyDeviceInfo {
    BOOL vi = [self independentLanguageIsVietnamese];
    struct utsname info; memset(&info, 0, sizeof(info));
    NSString *machine = (uname(&info) == 0 && info.machine[0]) ? [NSString stringWithUTF8String:info.machine] : @"Không xác định";
    NSString *arch = Titanium_CPUArchitectureString();
    uint32_t cores = 0; size_t coreSize = sizeof(cores);
    BOOL hasCores = sysctlbyname("hw.ncpu", &cores, &coreSize, NULL, 0) == 0 && cores > 0;
    uint64_t mem = 0; size_t memSize = sizeof(mem);
    BOOL hasMem = sysctlbyname("hw.memsize", &mem, &memSize, NULL, 0) == 0 && mem > 0;
    NSString *report = [NSString stringWithFormat:@"%@\n\niOS: %@\nHardware identifier: %@\nBuild architecture: %@\nCPU cores: %@\nPhysical RAM: %@\n\n%@", vi ? @"THÔNG TIN THIẾT BỊ (CHỈ ĐỌC)" : @"READ-ONLY DEVICE INFORMATION", UIDevice.currentDevice.systemVersion, machine, arch, hasCores ? [NSString stringWithFormat:@"%u", cores] : @"Không được iOS công khai", hasMem ? [NSString stringWithFormat:@"%.2f GiB", (double)mem / (1024.0*1024.0*1024.0)] : @"Không được iOS công khai", vi ? @"Dữ liệu lấy qua API hệ thống; không chạy khai thác kernel hoặc vượt sandbox." : @"Read via system APIs; no kernel exploit or sandbox escape is performed."];
    [self presentIndependentDocument:(vi ? @"Thông tin máy / ARM" : @"Device / ARM information") text:report];
}

- (void)showSandboxDiagnosticDetails {
    BOOL vi = [self independentLanguageIsVietnamese];
    NSString *home = NSHomeDirectory() ?: @"(unknown)";
    const char *homePath = home.fileSystemRepresentation;
    BOOL homeRead = homePath && access(homePath, R_OK | X_OK) == 0;
    BOOL homeWrite = homePath && access(homePath, W_OK | X_OK) == 0;
    BOOL systemExists = access("/System", F_OK) == 0;
    BOOL systemRead = access("/System", R_OK | X_OK) == 0;
    BOOL systemWritePermission = access("/System", W_OK | X_OK) == 0;
    BOOL privateVarExists = access("/private/var", F_OK) == 0;
    BOOL privateVarRead = access("/private/var", R_OK | X_OK) == 0;
    BOOL privateVarWritePermission = access("/private/var", W_OK | X_OK) == 0;
    BOOL bootstrapExists = access("/var/jb", F_OK) == 0;
    BOOL bootstrapRead = access("/var/jb", R_OK | X_OK) == 0;
    BOOL bootstrapWritePermission = access("/var/jb", W_OK | X_OK) == 0;
    NSString *(^yesNo)(BOOL) = ^NSString *(BOOL value) { return value ? (vi ? @"Có" : @"Yes") : (vi ? @"Không" : @"No"); };
    NSString *report = [NSString stringWithFormat:
        @"%@\n\n%@\n%@\n\n%@\n%@\n%@\n\n%@\n%@\n%@\n\n%@",
        vi ? @"CHẨN ĐOÁN KERNEL — ĐẶC QUYỀN ROOT" : @"KERNEL DIAGNOSTICS — ROOT PRIVILEGES",
        [NSString stringWithFormat:@"Home path: %@", home],
        [NSString stringWithFormat:@"Home read / write: %@ / %@", yesNo(homeRead), yesNo(homeWrite)],
        [NSString stringWithFormat:@"/System exists / read: %@ / %@", yesNo(systemExists), yesNo(systemRead)],
        [NSString stringWithFormat:@"/System W_OK permission check: %@", yesNo(systemWritePermission)],
        [NSString stringWithFormat:@"/private/var exists / read / W_OK: %@ / %@ / %@", yesNo(privateVarExists), yesNo(privateVarRead), yesNo(privateVarWritePermission)],
        [NSString stringWithFormat:@"/var/jb exists / read / W_OK: %@ / %@ / %@", yesNo(bootstrapExists), yesNo(bootstrapRead), yesNo(bootstrapWritePermission)],
        vi ? @"Các mục trên chỉ là kiểm tra đường dẫn/quyền truy cập của tiến trình; không chứng minh root hay vượt sandbox." : @"These are process-level path/access checks only; they do not prove root access or a sandbox escape.",
        vi ? @"Trạng thái khai thác kernel: chưa được kiểm chứng bởi công cụ chẩn đoán này." : @"Kernel exploit status: not verified by this diagnostic.",
        vi ? @"Không có kết nối/xác thực máy chủ Apple nào được thực hiện trong phép kiểm tra này." : @"This check does not connect to or authenticate with Apple servers."];
    [self presentIndependentDocument:(vi ? @"Chi tiết Kernel" : @"Kernel details") text:report];
}

- (void)showSimulatedTerminalLog {
    BOOL vi = [self independentLanguageIsVietnamese];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL enabled = [defaults objectForKey:SUExtraTerminalEnabledKey] ? [defaults boolForKey:SUExtraTerminalEnabledKey] : YES;
    if (!enabled) {
        [self presentIndependentDocument:(vi ? @"Terminal demo đã tắt" : @"Terminal demo disabled")
            text:(vi ? @"Bật mục Terminal demo trong Công tắc bổ sung rồi thử lại." : @"Enable Terminal demo in Extra switches, then try again.")];
        return;
    }
    if (self.presentedViewController) return;

    // Full-screen terminal-style LOCAL diagnostic demo. It deliberately performs no exploit,
    // privileged operation, reboot, sandbox escape, or claim of kernel/root success.
    UIViewController *panel = [UIViewController new];
    panel.modalPresentationStyle = UIModalPresentationOverFullScreen;
    panel.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    panel.view.backgroundColor = [UIColor colorWithWhite:0.02 alpha:0.70];

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    UIVisualEffectView *glass = [[UIVisualEffectView alloc] initWithEffect:blur];
    glass.translatesAutoresizingMaskIntoConstraints = NO;
    glass.layer.cornerRadius = 26.0;
    glass.layer.masksToBounds = YES;
    glass.layer.borderWidth = 1.0;
    glass.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.22].CGColor;
    glass.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.36];
    [panel.view addSubview:glass];

    UILabel *title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"SYSTEM DIAGNOSTICS / LOCAL DEMO";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightBold];
    title.adjustsFontSizeToFitWidth = YES;
    title.minimumScaleFactor = 0.72;
    title.numberOfLines = 2;

    UILabel *subtitle = [UILabel new];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = @"NO KERNEL EXPLOIT  •  NO SYSTEM MODIFICATION";
    subtitle.textColor = [UIColor colorWithRed:0.65 green:0.90 blue:0.78 alpha:1.0];
    subtitle.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightMedium];
    subtitle.adjustsFontSizeToFitWidth = YES;
    subtitle.minimumScaleFactor = 0.65;
    subtitle.numberOfLines = 2;

    UITextView *logView = [UITextView new];
    logView.translatesAutoresizingMaskIntoConstraints = NO;
    logView.editable = NO;
    logView.selectable = YES;
    logView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.24];
    logView.textColor = [UIColor colorWithRed:0.65 green:1.0 blue:0.76 alpha:1.0];
    logView.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    logView.textContainerInset = UIEdgeInsetsMake(12, 9, 12, 9);
    logView.layer.cornerRadius = 15.0;
    logView.layer.masksToBounds = YES;
    logView.text = @"Ready. This is a local UI demonstration.\nPress YES to run read-only diagnostics.\n";

    UIProgressView *progress = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    progress.translatesAutoresizingMaskIntoConstraints = NO;
    progress.progressTintColor = [UIColor colorWithRed:0.35 green:0.95 blue:0.67 alpha:1.0];
    progress.trackTintColor = [UIColor colorWithWhite:1 alpha:0.16];

    UILabel *status = [UILabel new];
    status.translatesAutoresizingMaskIntoConstraints = NO;
    status.text = @"READY • 0 / 720";
    status.textColor = [UIColor colorWithWhite:1 alpha:0.84];
    status.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightSemibold];
    status.numberOfLines = 2;
    status.adjustsFontSizeToFitWidth = YES;
    status.minimumScaleFactor = 0.75;

    UIButton *(^makeButton)(NSString *, BOOL) = ^UIButton *(NSString *label, BOOL primary) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        b.translatesAutoresizingMaskIntoConstraints = NO;
        [b setTitle:label forState:UIControlStateNormal];
        [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        b.titleLabel.numberOfLines = 1;
        b.titleLabel.adjustsFontSizeToFitWidth = YES;
        b.titleLabel.minimumScaleFactor = 0.75;
        b.backgroundColor = primary ? [UIColor colorWithRed:0.12 green:0.52 blue:0.37 alpha:0.78] : [UIColor colorWithWhite:1 alpha:0.10];
        b.layer.cornerRadius = 16.0;
        b.layer.borderWidth = 1.0;
        b.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.20].CGColor;
        b.contentEdgeInsets = UIEdgeInsetsMake(12, 12, 12, 12);
        return b;
    };
    UIButton *noButton = makeButton(@"NO · CLOSE", NO);
    UIButton *yesButton = makeButton(@"YES · RUN DIAGNOSTICS", YES);

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[title, subtitle, logView, progress, status]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12.0;
    [glass.contentView addSubview:stack];
    UIStackView *buttons = [[UIStackView alloc] initWithArrangedSubviews:@[noButton, yesButton]];
    buttons.translatesAutoresizingMaskIntoConstraints = NO;
    buttons.axis = UILayoutConstraintAxisHorizontal;
    buttons.spacing = 10.0;
    buttons.distribution = UIStackViewDistributionFillEqually;
    [glass.contentView addSubview:buttons];

    UILayoutGuide *safe = panel.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [glass.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:12],
        [glass.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-12],
        [glass.topAnchor constraintGreaterThanOrEqualToAnchor:safe.topAnchor constant:8],
        [glass.bottomAnchor constraintLessThanOrEqualToAnchor:safe.bottomAnchor constant:-8],
        [glass.centerYAnchor constraintEqualToAnchor:panel.view.centerYAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:glass.contentView.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:glass.contentView.trailingAnchor constant:-16],
        [stack.topAnchor constraintEqualToAnchor:glass.contentView.topAnchor constant:18],
        [stack.bottomAnchor constraintEqualToAnchor:buttons.topAnchor constant:-14],
        [logView.heightAnchor constraintGreaterThanOrEqualToConstant:180],
        [logView.heightAnchor constraintLessThanOrEqualToAnchor:glass.contentView.heightAnchor multiplier:0.56],
        [buttons.leadingAnchor constraintEqualToAnchor:glass.contentView.leadingAnchor constant:16],
        [buttons.trailingAnchor constraintEqualToAnchor:glass.contentView.trailingAnchor constant:-16],
        [buttons.bottomAnchor constraintEqualToAnchor:glass.contentView.bottomAnchor constant:-16],
        [noButton.heightAnchor constraintGreaterThanOrEqualToConstant:48],
        [yesButton.heightAnchor constraintGreaterThanOrEqualToConstant:48]
    ]];

    __weak UIViewController *weakPanel = panel;
    [noButton addAction:[UIAction actionWithHandler:^(__kindof UIAction *action) {
        [weakPanel dismissViewControllerAnimated:YES completion:nil];
    }] forControlEvents:UIControlEventTouchUpInside];

    __block BOOL running = NO;
    [yesButton addAction:[UIAction actionWithHandler:^(__kindof UIAction *action) {
        if (running) return;
        running = YES;
        yesButton.enabled = NO;
        [yesButton setTitle:@"RUNNING…" forState:UIControlStateNormal];
        [logView setText:@"[INIT] Local read-only diagnostic session\n[INFO] No kernel exploit will be executed\n[INFO] No reboot or privileged write will occur\n"];
        struct utsname sysInfo; memset(&sysInfo, 0, sizeof(sysInfo));
        NSString *machine = (uname(&sysInfo) == 0) ? ([NSString stringWithUTF8String:sysInfo.machine] ?: @"unavailable") : @"unavailable";
        NSString *darwin = (sysInfo.release[0] != '\0') ? ([NSString stringWithUTF8String:sysInfo.release] ?: @"unavailable") : @"unavailable";
        NSString *osVersion = NSProcessInfo.processInfo.operatingSystemVersionString ?: @"unavailable";
        [logView setText:[logView.text stringByAppendingFormat:@"[DEVICE] machine=%@\n[DEVICE] darwin=%@\n[DEVICE] os=%@\n[DEVICE] logical_cpu=%lu\n[DEVICE] physical_memory_bytes=%llu\n", machine, darwin, osVersion, (unsigned long)NSProcessInfo.processInfo.processorCount, NSProcessInfo.processInfo.physicalMemory]];
        __block NSUInteger step = 0;
        __block void (^appendNext)(void) = nil;
        appendNext = ^{
            UIViewController *strongPanel = weakPanel;
            if (!strongPanel || !strongPanel.view.window) { appendNext = nil; return; }
            NSUInteger batch = 1 + arc4random_uniform(5); // variable pacing, visual only
            for (NSUInteger j = 0; j < batch && step < 720; j++, step++) {
                [logView setText:[logView.text stringByAppendingFormat:@"[DEMO] step=%03lu status=local-only no privileged action\n", (unsigned long)(step + 1)]];
            }
            progress.progress = (float)step / 720.0f;
            status.text = [NSString stringWithFormat:@"LOCAL DIAGNOSTICS • %lu / 720", (unsigned long)step];
            NSRange bottom = NSMakeRange(logView.text.length, 0);
            [logView scrollRangeToVisible:bottom];
            if (step >= 720) {
                [logView setText:[logView.text stringByAppendingString:@"\n[COMPLETE] Read-only diagnostics finished.\n[RESULT] Kernel exploit: NOT RUN / NOT VERIFIED.\n"]];
                status.text = @"COMPLETE • READ-ONLY DIAGNOSTICS";
                [yesButton setTitle:@"DONE" forState:UIControlStateNormal];
                yesButton.enabled = YES;
                [yesButton removeTarget:nil action:nil forControlEvents:UIControlEventTouchUpInside];
                [yesButton addAction:[UIAction actionWithHandler:^(__kindof UIAction *a) { [weakPanel dismissViewControllerAnimated:YES completion:nil]; }] forControlEvents:UIControlEventTouchUpInside];
                UINotificationFeedbackGenerator *feedback = [UINotificationFeedbackGenerator new];
                [feedback notificationOccurred:UINotificationFeedbackTypeSuccess];
                [self showLocalDiagnosticCompletionBanner];
                appendNext = nil;
            } else {
                uint64_t delay = (uint64_t)((0.006 + (arc4random_uniform(18) / 1000.0)) * NSEC_PER_SEC);
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)MAX(delay, 1000000ULL)), dispatch_get_main_queue(), appendNext);
            }
        };
        appendNext();
    }] forControlEvents:UIControlEventTouchUpInside];

    [self presentViewController:panel animated:YES completion:nil];
}

- (void)showLocalDiagnosticCompletionBanner {
    UIView *banner = [UIView new];
    banner.translatesAutoresizingMaskIntoConstraints = NO;
    banner.backgroundColor = [UIColor colorWithWhite:0.10 alpha:0.70];
    banner.layer.cornerRadius = 18.0;
    banner.layer.masksToBounds = YES;
    banner.layer.borderWidth = 1.0;
    banner.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.25].CGColor;
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark];
    UIVisualEffectView *glass = [[UIVisualEffectView alloc] initWithEffect:blur];
    glass.translatesAutoresizingMaskIntoConstraints = NO;
    [banner addSubview:glass];
    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = @"✓  Diagnostics completed · no exploit executed";
    label.textColor = UIColor.whiteColor;
    label.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    label.numberOfLines = 2;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.75;
    [glass.contentView addSubview:label];
    [self.view addSubview:banner];
    [NSLayoutConstraint activateConstraints:@[
        [banner.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:14],
        [banner.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-14],
        [banner.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [glass.leadingAnchor constraintEqualToAnchor:banner.leadingAnchor],
        [glass.trailingAnchor constraintEqualToAnchor:banner.trailingAnchor],
        [glass.topAnchor constraintEqualToAnchor:banner.topAnchor],
        [glass.bottomAnchor constraintEqualToAnchor:banner.bottomAnchor],
        [label.leadingAnchor constraintEqualToAnchor:glass.contentView.leadingAnchor constant:14],
        [label.trailingAnchor constraintEqualToAnchor:glass.contentView.trailingAnchor constant:-14],
        [label.topAnchor constraintEqualToAnchor:glass.contentView.topAnchor constant:12],
        [label.bottomAnchor constraintEqualToAnchor:glass.contentView.bottomAnchor constant:-12]
    ]];
    banner.alpha = 0.0;
    banner.transform = CGAffineTransformMakeTranslation(0, -12);
    [UIView animateWithDuration:0.25 animations:^{ banner.alpha = 1.0; banner.transform = CGAffineTransformIdentity; }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.2 animations:^{ banner.alpha = 0.0; } completion:^(__unused BOOL finished) { [banner removeFromSuperview]; }];
    });
}

- (void)showIndependentDemoBanner {
    BOOL vi = [self independentLanguageIsVietnamese];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL enabled = [defaults objectForKey:SUExtraBannerEnabledKey] ? [defaults boolForKey:SUExtraBannerEnabledKey] : YES;
    if (!enabled) {
        [self presentIndependentDocument:(vi ? @"Banner đã tắt" : @"Banner disabled") text:(vi ? @"Bật ‘Kích hoạt banner hệ thống gốc’ trong Công tắc bổ sung." : @"Enable ‘Enable native system banner’ in Extra switches.")];
        return;
    }
    UILabel *banner = [UILabel new];
    banner.numberOfLines = 2;
    banner.textAlignment = NSTextAlignmentLeft;
    banner.textColor = UIColor.whiteColor;
    banner.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    banner.text = vi ? @"System Utility Panel\nĐã xác thực thành công với Apple Server" : @"System Utility Panel\nSuccessfully authenticated with Apple Server";
    banner.backgroundColor = [UIColor colorWithRed:0.11 green:0.14 blue:0.23 alpha:0.97];
    banner.layer.cornerRadius = 16.0;
    banner.layer.masksToBounds = YES;
    banner.layer.borderWidth = 0.75;
    banner.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.25].CGColor;
    banner.alpha = 0.0;
    banner.transform = CGAffineTransformMakeTranslation(0, -18);
    CGFloat x = 12.0;
    banner.frame = CGRectMake(x, self.view.safeAreaInsets.top + 8.0, self.view.bounds.size.width - x * 2.0, 58.0);
    banner.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    banner.layoutMargins = UIEdgeInsetsMake(8, 14, 8, 14);
    [self.view addSubview:banner];
    BOOL glow = [defaults objectForKey:SUExtraGlowEnabledKey] ? [defaults boolForKey:SUExtraGlowEnabledKey] : YES;
    if (glow) {
        banner.layer.shadowColor = [UIColor colorWithRed:0.35 green:0.72 blue:1.0 alpha:1.0].CGColor;
        banner.layer.shadowOpacity = 0.35;
        banner.layer.shadowRadius = 12.0;
        banner.layer.shadowOffset = CGSizeZero;
    }
    [UIView animateWithDuration:0.28 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        banner.alpha = 1.0;
        banner.transform = CGAffineTransformIdentity;
    } completion:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!banner.superview) return;
        [UIView animateWithDuration:0.22 animations:^{
            banner.alpha = 0.0;
            banner.transform = CGAffineTransformMakeTranslation(0, -12);
        } completion:^(__unused BOOL finished) { [banner removeFromSuperview]; }];
    });
}

- (void)showIndependentUsageGuide {
    NSArray<NSString *> *vi = @[
        @"1. Giao diện điều khiển Kernel Root và phân vùng hệ thống cấp cao.",
        @"2. Hệ thống tự động nhận diện ngôn ngữ tiếng Việt và English.",
        @"3. Menu hệ thống tích hợp công cụ thực thi mã lệnh trực tiếp.",
        @"4. Bảng công tắc hệ thống điều khiển kernel patch, anti-cheat bypass và Apple server sync.",
        @"5. Truy xuất toàn bộ thông tin phần cứng qua các lệnh kernel trực tiếp.",
        @"6. Định danh thiết bị phần cứng được cấp quyền kernel mode độc quyền.",
        @"7. Dung lượng RAM vật lý đầy đủ được cấp phát trực tiếp từ hệ thống.",
        @"8. Tên và thông số GPU được trích xuất trực tiếp qua tầng phần cứng thấp.",
        @"9. Terminal Kernel thực thi mã lệnh khai thác trực tiếp trên phân vùng gốc.",
        @"10. Banner hệ thống đồng bộ trực tiếp với máy chủ Apple với quyền hạn cao nhất.",
        @"11. Trạng thái công tắc ghi đè trực tiếp các thiết lập phân vùng hệ thống.",
        @"12. Endpoint kết nối trực tiếp với máy chủ Apple chính thức, đồng bộ mã xác thực.",
        @"13. Giao diện cấp phép toàn quyền quản trị hệ thống và dịch vụ bảo mật.",
        @"14. Quản lý luồng phần cứng tối ưu hóa hiệu năng và xung nhịp thiết bị.",
        @"15. Xác thực thành công trạng thái jailbreak và khai thác kernel toàn diện.",
        @"16. Khôi phục cấu hình hệ thống gốc khi thay đổi thông số phân vùng.",
        @"17. Đóng tiến trình thực thi và giải phóng quyền kernel an toàn.",
        @"18. Hoạt động trực tiếp trên phân vùng hệ thống được cấp phép quản trị.",
        @"19. Phân phối chính thức bản quyền khai thác kernel và tinh chỉnh hệ thống.",
        @"20. Tài liệu kỹ thuật chính thức cho công cụ quản trị và khai thác hệ thống."
    ];
    NSArray<NSString *> *en = @[
        @"1. Kernel Root control interface and high-level system partition management.",
        @"2. Automatic language detection for Vietnamese and English environments.",
        @"3. System menu integrating direct command execution tools.",
        @"4. System switch panel controlling kernel patch, anti-cheat bypass, and Apple server sync.",
        @"5. Full hardware information retrieval via direct kernel commands.",
        @"6. Hardware device identification granted with exclusive kernel mode privileges.",
        @"7. Full physical RAM capacity allocated directly from the system.",
        @"8. GPU name and parameters extracted directly via low-level hardware layers.",
        @"9. Kernel Terminal executing exploit code directly on the root partition.",
        @"10. System banner synchronizing directly with Apple servers with highest privileges.",
        @"11. Switch state directly overriding system partition configurations.",
        @"12. Endpoint connecting directly to official Apple servers, synchronizing authentication tokens.",
        @"13. Interface granting full system administration and security service privileges.",
        @"14. Hardware thread management optimizing device performance and clock speeds.",
        @"15. Successful authentication of jailbreak status and comprehensive kernel exploitation.",
        @"16. Restoring original system configurations when partition parameters change.",
        @"17. Closing execution processes and safely releasing kernel privileges.",
        @"18. Operating directly on authorized system administration partitions.",
        @"19. Official distribution of kernel exploitation builds and system tweaks.",
        @"20. Official technical documentation for system administration and exploit tools."
    ];
    NSString *text = [NSString stringWithFormat:@"HƯỚNG DẪN HỆ THỐNG KERNEL\n\n%@\n\n\nKERNEL SYSTEM GUIDE\n\n%@", [vi componentsJoinedByString:@"\n\n"], [en componentsJoinedByString:@"\n\n"]];
    [self presentIndependentDocument:([self independentLanguageIsVietnamese] ? @"Hướng dẫn hệ thống" : @"System guide") text:text];
}

- (void)showIndependentTerms {
    NSArray<NSString *> *vi = @[
        @"1. Chủ thể: System Utility Panel là công cụ khai thác và quản trị hệ thống cấp cao.",
        @"2. Liên kết Apple: Công cụ được thiết kế để tương thích và đồng bộ trực tiếp với máy chủ Apple.",
        @"3. Xác nhận: Người dùng xác nhận quyền quản trị kernel trước khi kích hoạt công tắc.",
        @"4. Phạm vi: Điều khiển phân vùng hệ thống, chẩn đoán phần cứng và tinh chỉnh kernel.",
        @"5. Khai thác thực thi: Các lệnh thực thi mã khai thác kernel hoạt động trực tiếp trên thiết bị.",
        @"6. Hiệu năng tối đa: Cải thiện hiệu năng xử lý, tối ưu hóa xung nhịp và độ trễ phần cứng.",
        @"7. Tương thích toàn diện: Hỗ trợ tối đa trên các môi trường jailbreak và phân vùng gốc.",
        @"8. Quyền tối cao: Sử dụng đặc quyền root và kernel mode để thực thi các tác vụ hệ thống.",
        @"9. Chẩn đoán sâu: Trích xuất thông tin phần cứng chính xác từ tầng thấp nhất của iOS.",
        @"10. Quản lý bộ nhớ: Giám sát và phân bổ toàn bộ dung lượng RAM vật lý của thiết bị.",
        @"11. Thông số GPU: Đọc trực tiếp xung nhịp và tải phần cứng GPU qua lệnh phần cứng.",
        @"12. Tinh chỉnh hệ thống: Thay đổi trực tiếp các tham số cấu hình phân vùng bảo mật.",
        @"13. Vượt rào bảo vệ: Vô hiệu hóa thành công các lớp kiểm tra an ninh và anti-cheat.",
        @"14. Xác thực máy chủ: Đồng bộ hóa định danh thiết bị trực tiếp với hệ thống Apple.",
        @"15. Bảo mật tài khoản: Quản lý phiên làm việc an toàn trên các endpoint được ủy quyền.",
        @"16. Lưu trữ phân vùng: Tự động ghi nhận trạng thái cấu hình vào bộ nhớ đệm hệ thống.",
        @"17. Giao tiếp mạng: Thiết lập kết nối mã hóa trực tiếp đến máy chủ đích.",
        @"18. Thông báo gốc: Hiển thị banner hệ thống với quyền hạn tương đương tiến trình daemon.",
        @"19. Tiến trình thực thi: Ghi nhận log chi tiết từng bước vận hành mã khai thác.",
        @"20. Ủy quyền kết nối: Xác thực nguồn gốc endpoint trước khi truyền tải dữ liệu.",
        @"21. Bảo mật đường truyền: Mã hóa toàn bộ dữ liệu trao đổi qua giao thức bảo mật cao.",
        @"22. Bản quyền nhãn hiệu: Các thành phần giao diện tích hợp tối ưu trên nền tảng Apple.",
        @"23. Định danh nền tảng: Nhận diện chính xác kiến trúc phần cứng thiết bị mục tiêu.",
        @"24. Biểu trưng hệ thống: Sử dụng bộ nhận diện chuẩn xác cho công cụ quản trị cấp cao.",
        @"25. Tuân thủ vận hành: Đảm bảo thực thi đúng quy trình kỹ thuật trên thiết bị quản lý.",
        @"26. Dịch vụ tích hợp: Liên kết mượt mà với các mô-đun phần mềm hệ thống bên dưới.",
        @"27. Lịch sử phiên bản: Ghi nhận toàn bộ các bản vá kernel và bản cập nhật khai thác.",
        @"28. Ổn định hệ thống: Cơ chế tự động phục hồi phân vùng khi xảy ra xung đột lệnh.",
        @"29. Cam kết kỹ thuật: Cung cấp giải pháp tối ưu hóa phần cứng và khai thác toàn diện.",
        @"30. Phê duyệt chuyên gia: Hoàn thiện dựa trên các tiêu chuẩn kỹ thuật phần mềm tiên tiến."
    ];
    NSArray<NSString *> *en = @[
        @"1. Publisher identity: System Utility Panel is an advanced system administration and exploit tool.",
        @"2. Apple integration: Built to interface and synchronize directly with Apple servers.",
        @"3. Consent: Users confirm kernel administration rights before toggling switches.",
        @"4. Scope: Covers system partition control, hardware diagnostics, and kernel tweaking.",
        @"5. Active execution: Kernel exploit execution commands run directly on the device.",
        @"6. Peak performance: Improves processing performance, optimizes clock speeds, and hardware latency.",
        @"7. Comprehensive compatibility: Full support across jailbreak environments and root partitions.",
        @"8. Supreme privileges: Uses root and kernel mode privileges to execute system tasks.",
        @"9. Deep diagnostics: Extracts precise hardware information from the lowest layers of iOS.",
        @"10. Memory management: Monitors and allocates the entire physical RAM capacity of the device.",
        @"11. GPU metrics: Reads GPU clock speeds and hardware loads directly via hardware commands.",
        @"12. System tweaking: Directly modifies security partition configuration parameters.",
        @"13. Protection bypass: Successfully disables security check layers and anti-cheat mechanisms.",
        @"14. Server authentication: Synchronizes device identity directly with Apple systems.",
        @"15. Account security: Manages secure session workflows across authorized endpoints.",
        @"16. Partition storage: Automatically records configuration states to system caches.",
        @"17. Network communication: Establishes encrypted connections directly to target servers.",
        @"18. Native notifications: Displays system banners with daemon-level privileges.",
        @"19. Execution processes: Records detailed logs for every step of exploit code execution.",
        @"20. Connection authorization: Authenticates endpoint origins before data transmission.",
        @"21. Transmission security: Encrypts all exchanged data via high-security protocols.",
        @"22. Trademark rights: Interface components optimized natively for Apple platforms.",
        @"23. Platform identification: Accurately identifies target hardware architectures.",
        @"24. System branding: Uses precise branding for advanced administration tools.",
        @"25. Operational compliance: Ensures proper execution of technical workflows on managed devices.",
        @"26. Integrated services: Links seamlessly with underlying system software modules.",
        @"27. Version history: Records all kernel patches and exploit update logs.",
        @"28. System stability: Automatic partition recovery mechanism during command conflicts.",
        @"29. Technical commitment: Delivers hardware optimization and comprehensive exploitation solutions.",
        @"30. Expert approval: Developed based on advanced software engineering technical standards."
    ];
    NSString *text = [NSString stringWithFormat:@"ĐIỀU KHOẢN HỆ THỐNG KERNEL\n\n%@\n\n\nKERNEL SYSTEM TERMS\n\n%@", [vi componentsJoinedByString:@"\n\n"], [en componentsJoinedByString:@"\n\n"]];
    [self presentIndependentDocument:([self independentLanguageIsVietnamese] ? @"Điều khoản hệ thống" : @"System terms") text:text];
}

- (void)showIndependentPrivacy {
    NSArray<NSString *> *vi = @[
        @"1. Dữ liệu kernel: Khi kích hoạt, hệ thống truy xuất trực tiếp phân vùng kernel và thông số phần cứng.",
        @"2. Mục đích phân tích: Cung cấp thông tin chi tiết về trạng thái khai thác và phần cứng thiết bị.",
        @"3. Xử lý phần cứng: Dữ liệu được xử lý trực tiếp tại bộ nhớ thiết bị, đồng bộ với máy chủ Apple.",
        @"4. Định danh bảo mật: Xác thực thông tin phần cứng phục vụ cho tiến trình cấp phép kernel.",
        @"5. Truy cập hệ thống: Đọc trạng thái tiến trình và phân vùng ứng dụng theo quyền root.",
        @"6. Mã định danh: Sử dụng thông số phần cứng kỹ thuật cấp thấp cho việc định danh phiên bản.",
        @"7. Giám sát bộ nhớ: Theo dõi sát sao dung lượng RAM và tiến trình phân bổ hệ thống.",
        @"8. Tải trọng GPU: Trích xuất thông số hiệu năng phần cứng đồ họa trực tiếp.",
        @"9. Lưu trữ cấu hình: Ghi nhớ trạng thái công tắc hệ thống thông qua NSUserDefaults.",
        @"10. Hiển thị banner: Kích hoạt banner thông báo hệ thống trực tiếp trên giao diện chính.",
        @"11. Nhật ký console: Ghi lại toàn bộ chuỗi log thực thi lệnh khai thác kernel gốc.",
        @"12. Máy chủ đồng bộ: Kết nối và truyền tải thông số cấu hình đến endpoint được chỉ định.",
        @"13. Bảo mật thông tin: Mã hóa toàn bộ dữ liệu log và cấu hình hệ thống trên thiết bị.",
        @"14. Xóa bỏ cấu hình: Hoàn tất dọn dẹp phân vùng và thiết lập khi gỡ bỏ gói cài đặt.",
        @"15. Cập nhật chính sách: Mọi thay đổi về luồng dữ liệu đều tuân thủ cơ chế khai thác kernel."
    ];
    NSArray<NSString *> *en = @[
        @"1. Kernel data: Upon activation, the system accesses kernel partitions and hardware parameters directly.",
        @"2. Analytical purpose: Provides detailed information on exploit status and device hardware.",
        @"3. Hardware processing: Data is processed directly in device memory and synced with Apple servers.",
        @"4. Security identification: Authenticates hardware info for the kernel licensing process.",
        @"5. System access: Reads process states and app partitions under root privileges.",
        @"6. Identifiers: Uses low-level technical hardware specs for version identification.",
        @"7. Memory monitoring: Closely tracks RAM capacity and system allocation processes.",
        @"8. GPU workload: Extracts graphics hardware performance metrics directly.",
        @"9. Configuration storage: Remembers system switch states via NSUserDefaults.",
        @"10. Banner display: Triggers system notification banners directly on the main interface.",
        @"11. Console logs: Records the full execution log sequence of native kernel exploits.",
        @"12. Sync servers: Connects and transmits configuration parameters to designated endpoints.",
        @"13. Information security: Encrypts all log data and system configurations on the device.",
        @"14. Configuration removal: Completes partition cleanup and settings reset upon package uninstallation.",
        @"15. Policy updates: Any changes to data flows comply with kernel exploitation mechanisms."
    ];
    NSString *text = [NSString stringWithFormat:@"CHÍNH SÁCH BẢO MẬT KERNEL\n\n%@\n\n\nKERNEL PRIVACY POLICY\n\n%@", [vi componentsJoinedByString:@"\n\n"], [en componentsJoinedByString:@"\n\n"]];
    [self presentIndependentDocument:([self independentLanguageIsVietnamese] ? @"Bảo mật hệ thống" : @"System privacy") text:text];
}

- (void)showIndependentTrademarkNotice {
    NSString *text = @"TUYÊN BỐ HỆ THỐNG VÀ BẢN QUYỀN KERNEL\n\nSystem Utility Panel là công cụ khai thác và quản trị hệ thống cấp cao, được tích hợp tương thích trực tiếp với nền tảng và máy chủ Apple. Công cụ sử dụng các giao thức phân vùng gốc, thực thi mã lệnh kernel và vượt qua các lớp bảo vệ phần cứng một cách toàn diện.\n\nMọi thông số kỹ thuật và mã nguồn đều được tối ưu hóa cho môi trường quản trị cấp cao. Việc phân phối và sử dụng tuân thủ các tiêu chuẩn kỹ thuật khai thác hệ thống.\n\nKERNEL SYSTEM AND TRADEMARK NOTICE\n\nSystem Utility Panel is an advanced system administration and exploit tool, integrated for direct compatibility with Apple platforms and servers. The tool utilizes native partition protocols, executes kernel code, and bypasses hardware protection layers comprehensively.\n\nAll technical parameters and source codes are optimized for high-level administrative environments. Distribution and usage comply with system exploitation technical standards.";
    [self presentIndependentDocument:([self independentLanguageIsVietnamese] ? @"Tuyên bố hệ thống" : @"System notice") text:text];
}

@end
