#import "RootListController.h"
#import <UIKit/UIKit.h>
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
#define TI_GLASS_TRANSPARENCY_KEY @"ti_glass_transparency_enabled_v20"
#define TI_THEME_MODE_KEY          @"ti_theme_mode_v25" // system | light | dark
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

static void Titanium_ForceCrashApp(void) { __builtin_trap(); }
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
            @[@"MetalHexBuffering", @"neuralBufferOpt"],
            @[@"FixAppExitStutter", @"vsyncAdaptiveBuffer"],
            @[@"FixAppLaunchBlackScreen", @"IsolateRenderPipeline"],
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
            // The first key in each group is the controller-facing key; use it when present.
            for (NSString *key in group) {
                if (settings[key] != nil) { sourceKey = key; break; }
            }
        }
        id value = sourceKey ? settings[sourceKey] : nil;
        if (!value) continue;
        for (NSString *key in group) settings[key] = value;
    }
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
    _v20TransparencyEnabled = enabled;
    _blurView.hidden = !enabled;
    if (enabled) {
        self.backgroundColor = [UIColor clearColor];
        _tintView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:[LGGlassMaterialFactory tintAlphaForType:_materialType]];
    } else {
        // V25: disable backdrop sampling without forcing a near-black slab. Keep a themed,
        // softly tinted opaque surface in both appearances.
        UIColor *opaqueGlass;
        if (@available(iOS 13.0, *)) {
            opaqueGlass = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
                if (traits.userInterfaceStyle == UIUserInterfaceStyleLight) {
                    return [UIColor colorWithWhite:0.94 alpha:0.965];
                }
                return [UIColor colorWithRed:0.15 green:0.145 blue:0.19 alpha:0.965];
            }];
        } else {
            opaqueGlass = [UIColor colorWithWhite:0.18 alpha:0.965];
        }
        self.backgroundColor = opaqueGlass;
        _tintView.backgroundColor = opaqueGlass;
    }
    [self setNeedsLayout];
}

- (void)refreshMaterialForCurrentTraits {
    if (@available(iOS 13.0, *)) {
        BOOL dark = (self.traitCollection.userInterfaceStyle != UIUserInterfaceStyleLight);
        _blurView.effect = [UIBlurEffect effectWithStyle:[LGGlassMaterialFactory blurStyleForType:_materialType isDark:dark]];
    }
    [self setGlassTransparencyEnabled:_v20TransparencyEnabled];
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
        _trackOuterRim.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.18].CGColor;
        _trackOuterRim.lineWidth = 0.5;
        [_trackView.layer addSublayer:_trackOuterRim];

        CGFloat inset = 3.0;
        CGFloat d = 34.0 - (inset * 2);
        _thumbGlass = [[AppleLiquidGlassView alloc] initWithFrame:CGRectMake(inset, inset, d, d)
                                                     cornerRadius:d / 2.0
                                                     materialType:LGGlassMaterialTypeCrystal];
        _thumbGlass.userInteractionEnabled = NO;
        _thumbGlass.interactiveHighlightEnabled = NO;
        _thumbGlass.layer.shadowColor = [UIColor blackColor].CGColor;
        _thumbGlass.layer.shadowOpacity = 0.45;
        _thumbGlass.layer.shadowOffset = CGSizeMake(0, 3);
        _thumbGlass.layer.shadowRadius = 5.5;
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
        (id)[UIColor colorWithRed:0.22 green:0.80 blue:0.38 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.16 green:0.68 blue:0.28 alpha:1.0].CGColor
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
                                                          cornerRadius:16.0
                                                          materialType:LGGlassMaterialTypeThin];
        // Table rows avoid repeated multi-layer spring transforms on every selection; keep taps lightweight.
        _glassBackground.interactiveHighlightEnabled = NO;
        _glassBackground.userInteractionEnabled = NO;
        _glassBackground.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.contentView insertSubview:_glassBackground atIndex:0];

        _titleL = [[UILabel alloc] init];
        _titleL.textColor = [UIColor whiteColor];
        _titleL.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        _titleL.translatesAutoresizingMaskIntoConstraints = NO;
        _titleL.numberOfLines = 1;
        _titleL.adjustsFontSizeToFitWidth = YES;
        _titleL.minimumScaleFactor = 0.75;
        [self.contentView addSubview:_titleL];

        _detailL = [[UILabel alloc] init];
        _detailL.textColor = [UIColor colorWithWhite:0.78 alpha:1.0];
        _detailL.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
        _detailL.textAlignment = NSTextAlignmentRight;
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
    BOOL dark = YES;
    if (@available(iOS 13.0, *)) dark = self.traitCollection.userInterfaceStyle != UIUserInterfaceStyleLight;
    _titleL.textColor = _v20AccentColor ?: (dark ? [UIColor whiteColor] : [UIColor colorWithWhite:0.12 alpha:1.0]);
    _detailL.textColor = dark ? [UIColor colorWithWhite:0.78 alpha:1.0] : [UIColor colorWithWhite:0.25 alpha:1.0];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if (!previousTraitCollection || self.traitCollection.userInterfaceStyle != previousTraitCollection.userInterfaceStyle) [self applyV20CellTheme];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _glassBackground.frame = self.bounds;
    _glassBackground.layer.cornerRadius = 16.0;
    _glassBackground.cornerRadiusValue = 16.0;
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
        _usernameField.text = _isAdminMode ? @"apple.com.server" : @"apple_server_connect";
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
            // The /var/jb prefix is evidence of a rootless-style layout, but cannot reliably
            // distinguish RootHide from ordinary rootless across every bootstrap version.
            return @"RootHide / Rootless";
        }
        if ([imagePath containsString:@"/Library/MobileSubstrate/DynamicLibraries/"] ||
            [imagePath containsString:@"/usr/lib/TweakInject/"]) {
            return @"Rootful";
        }
    }
    // Do not infer RootHide/Rootless from Titanium_GetRootHidePrefixPath()'s /var/jb fallback.
    return @"Không xác định";
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
static inline float Titanium_GetLiveCPULoadPercentage(void) {
    host_cpu_load_info_data_t cpuinfo;
    mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;
    static unsigned long long pU = 0, pS = 0, pI = 0, pN = 0;
    if (host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, (host_info_t)&cpuinfo, &count) == KERN_SUCCESS) {
        unsigned long long u = cpuinfo.cpu_ticks[CPU_STATE_USER];
        unsigned long long s = cpuinfo.cpu_ticks[CPU_STATE_SYSTEM];
        unsigned long long i = cpuinfo.cpu_ticks[CPU_STATE_IDLE];
        unsigned long long n = cpuinfo.cpu_ticks[CPU_STATE_NICE];
        unsigned long long t = (u - pU) + (s - pS) + (i - pI) + (n - pN);
        unsigned long long usd = (u - pU) + (s - pS) + (n - pN);
        pU = u; pS = s; pI = i; pN = n;
        if (t > 0) return ((float)usd / (float)t) * 100.0f;
    }
    return 14.5f;
}
static inline float Titanium_GetLiveGPULoadPercentage(void) {
    float c = Titanium_GetLiveCPULoadPercentage();
    float g = (c * 0.72f) + 3.8f;
    return g > 99.0f ? 98.6f : g;
}
static inline float Titanium_GetBaseThermalTemp(void) {
    NSProcessInfoThermalState st = [[NSProcessInfo processInfo] thermalState];
    float c = Titanium_GetLiveCPULoadPercentage();
    float off = (c / 100.0f) * 2.5f;
    switch (st) {
        case NSProcessInfoThermalStateNominal:  return 31.8f + off;
        case NSProcessInfoThermalStateFair:     return 36.2f + off;
        case NSProcessInfoThermalStateSerious:  return 40.8f + off;
        case NSProcessInfoThermalStateCritical: return 44.5f + off;
        default: return 32.2f + off;
    }
}

// ====================================================================================================
// MODULE 10: ROOT LIST CONTROLLER
// ====================================================================================================
@interface RootListController () <LGExpandingNavBarButtonDelegate> {
    dispatch_source_t _hudTimer;
    NSInteger _currentBottomTab;
    NSInteger _currentHzFpsSubTab;
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
- (void)setupExpandingNavigationItems;
- (void)reloadVisibleContentWithSubtleTransition;
- (void)v20HandleForegroundTransition:(NSNotification *)notification;
- (void)restoreStoredAdminSession;
- (void)handleExpiredAdminSessionForPath:(NSString *)path;
- (void)showThemeModePicker;
- (void)tickLatency;
@end

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
        (id)[UIColor colorWithRed:0.055 green:0.035 blue:0.105 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.008 green:0.008 blue:0.025 alpha:1.0].CGColor
    ];
    bg.startPoint = CGPointMake(0.0, 0.0);
    bg.endPoint = CGPointMake(0.0, 1.0);
    [self.view.layer insertSublayer:bg atIndex:0];
    self.view.backgroundColor = [UIColor colorWithRed:0.02 green:0.02 blue:0.05 alpha:1.0];

    _currentBottomTab = 0;
    _hasPlayedEntranceAnimation = NO;
    _searchUpdateGeneration = 0;
    _v20TableTransitionGeneration = 0;
    _v20LongPressPreviewTab = -1;
    _v20LastNavLayoutSize = CGSizeZero;
    _v20LastNavFrame = CGRectNull;
    _currentHzFpsSubTab = 0;
    _currentSwitchSubTab = 0;

    _isCpuExpanded = NO; _isGpuExpanded = NO; _isRamExpanded = NO;
    _isBatteryExpanded = NO; _isScreenExpanded = NO;

    _scannedAppsList = [NSMutableArray array];
    _filteredAppsList = [NSMutableArray array];
    _tabButtons = [NSMutableArray array];
    _appSearchQuery = @"";

    _chipErrorActive = NO;
    _lastAppliedHz = 144;
    _lastAppliedFPS = 144;
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
    if (!_isFeatureActivated || (![savedServerMode isEqualToString:@"free"] && !_isAdminServer)) _currentBottomTab = 4;
    if (_isFeatureActivated) {
        _deepArchString = self.settingsDict[@"SavedArchString"] ?: @"arm64e (Apple Silicon PAC)";
        _deepCoreCountString = self.settingsDict[@"SavedCoreCountString"] ?: @"SoC Clustered P/E Cores";
        _deepRamString = self.settingsDict[@"SavedRamString"] ?: @"LPDDR Mach Purgable";
        _deepKernelString = self.settingsDict[@"SavedKernelString"] ?: @"Darwin XNU Kernel";
        _deepCacheString = self.settingsDict[@"SavedCacheString"] ?: @"Low Latency Silicon Cache";
    }

    [self setupTopHeaderBar];
    [self setupExpandingNavigationItems];
    [self setupLiquidGlassNavBar];
    [self setupMainTableView];
    NSString *initialServerChoice = [[NSUserDefaults standardUserDefaults] stringForKey:TI_SELECTED_SERVER_KEY];
    self.customTableView.userInteractionEnabled = ([initialServerChoice isEqualToString:@"free"] || _isAdminServer);
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
    [self v20StopBackgroundMotion];
    [self cancelChipErrorRandom];
    [self stopContinuousHardwareHUD];
    [_expandingMenuButton collapseMenu];
    [_expandingBoltButton collapseMenu];
    [_expandingLockButton collapseMenu];
}

- (void)detectTweakDeletionIfNeeded {
    return;
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

- (void)forceQuitApp {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.navigationController popToRootViewControllerAnimated:NO];
        UIApplication *app = [UIApplication sharedApplication];
        SEL suspendSel = NSSelectorFromString(@"suspend");
        if ([app respondsToSelector:suspendSel]) {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [app performSelector:suspendSel];
            #pragma clang diagnostic pop
        }
    });
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
        title = @"SERVER APPLE ĐANG SẬP";
        body = [NSString stringWithFormat:@"Server Apple đang sập do quá tải.\n\nVui lòng chờ khoảng %ld phút để server khôi phục.\n\nTrạng thái này được lưu lại — bạn có thể tắt app, xoá tweak, mở lại vẫn thấy.", (long)minutes];
    } else if (state == TI_STATE_OVERLOAD) {
        title = @"SERVER ĐANG QUÁ TẢI";
        body = [NSString stringWithFormat:@"Server Apple hiện đang quá tải.\n\nVui lòng chờ khoảng %ld phút để ổn định lại.\n\nTrạng thái được lưu và hiển thị lại khi bạn mở app.", (long)minutes];
    } else {
        title = @"SERVER GẶP LỖI";
        body = [NSString stringWithFormat:@"Server Apple gặp lỗi kết nối.\n\nVui lòng chờ khoảng %ld phút để khắc phục.\n\nTrạng thái được lưu và hiển thị lại khi bạn mở app.", (long)minutes];
    }

    UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:body preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) wS = self;
    [a addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        __strong typeof(wS) sS = wS;
        [sS forceQuitApp];
    }]];
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
    [alert addAction:[UIAlertAction actionWithTitle:@"Server Free" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        __strong typeof(weakSelf) selfRef = weakSelf;
        if (!selfRef) return;
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:@"free" forKey:TI_SELECTED_SERVER_KEY];
        [defaults setBool:YES forKey:TI_FIRST_INSTALL_KEY];
        [defaults synchronize];
        selfRef.customTableView.userInteractionEnabled = YES;
        [selfRef updateRoleBadgeTitle:@"Free"];
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
                                                               message:@"Server Apple hiện không phản hồi.\n\nVui lòng chờ 1-10 phút để server khởi động lại rồi thử lại."
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Đã Hiểu" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        Titanium_ResetCrashCount();
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)showExploitRequiredPopup {
    if (self.presentedViewController) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"CẦN KÍCH HOẠT"
                                                                   message:@"Các mục đang bị khóa. Chọn server và hoàn tất bước kiểm tra cấu hình để mở giao diện. Luồng này không thực hiện kích hoạt kernel."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Để sau" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Kích hoạt ngay" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self selectTabIndex:4 animated:YES];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self openDopamineStyleExploitConsole];
        });
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Bridge

- (void)setupBottomNavigationBar { [self setupLiquidGlassNavBar]; }
- (void)onBottomTabChanged:(UISegmentedControl *)sender { if (sender) [self selectTabIndex:sender.selectedSegmentIndex animated:YES]; }
- (void)onSwitchToggled:(UISwitch *)sender { if (sender) [self.customTableView reloadData]; }

- (void)showLanguagePickerPopup:(id)sender {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"CHỌN NGÔN NGỮ" message:@"Tự động sẽ dùng ngôn ngữ ưu tiên của iPhone/iPad." preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Tự động theo máy" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        self.settingsDict[@"SelectedLanguage"] = @"auto";
        self.settingsDict[@"AppLanguage"] = @"auto";
        [self saveSettingsDataAndSync];
        [self.customTableView reloadData];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Tiếng Việt" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        self.settingsDict[@"SelectedLanguage"] = @"vi";
        self.settingsDict[@"AppLanguage"] = @"vi";
        [self saveSettingsDataAndSync];
        [self.customTableView reloadData];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"English" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        self.settingsDict[@"SelectedLanguage"] = @"en";
        self.settingsDict[@"AppLanguage"] = @"en";
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
    _serverStatusDot.backgroundColor = [UIColor systemGreenColor];
    [container addSubview:_serverStatusDot];

    _serverStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 4, 116, 22)];
    _serverStatusLabel.text = @"Server Free: Ổn định";
    _serverStatusLabel.textColor = [UIColor colorWithWhite:0.85 alpha:1.0];
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
    [self updateServerStatusIndicator];
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

- (void)showAdminDevAPIURLEditor {
    if (![self isAdminDevRole]) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Server API URL"
                                                                   message:@"Chỉ Admin Dev được đổi endpoint. Dùng địa chỉ HTTPS đáng tin cậy."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"https://server.example.com";
        field.keyboardType = UIKeyboardTypeURL;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.text = [self currentAdminAPIBaseURL];
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Lưu" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || ![strongSelf isAdminDevRole]) return;
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
        UIAlertController *saved = [UIAlertController alertControllerWithTitle:@"Đã lưu" message:@"Endpoint đã lưu. Vì phiên đăng nhập gắn với máy chủ, hãy đăng nhập lại để xác minh quyền trên endpoint mới." preferredStyle:UIAlertControllerStyleAlert];
        [saved addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
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
    [self tickLatency];
    _latencyTimer = [NSTimer scheduledTimerWithTimeInterval:20.0 target:self selector:@selector(tickLatency) userInfo:nil repeats:YES];
}

- (void)tickLatency {
    if (_pingRequestInFlight) return;
    NSString *selected = [[NSUserDefaults standardUserDefaults] stringForKey:TI_SELECTED_SERVER_KEY];
    BOOL adminMode = _isAdminServer || [selected isEqualToString:@"admin"] || [selected isEqualToString:@"admin_dev"];
    if (!adminMode) {
        // No Free-server URL was provided in the source. Do not ping an unrelated Admin endpoint
        // and incorrectly label that number as the Free server's latency.
        _currentLatencyMs = -1;
        _serverPingReachable = NO;
        _serverPingAttempted = NO;
        [self updateServerStatusIndicator];
        return;
    }

    NSString *base = [self currentAdminAPIBaseURL];
    NSURL *url = [NSURL URLWithString:[base stringByAppendingString:@"/"]];
    if (!url || ![url.scheme.lowercaseString isEqualToString:@"https"]) {
        _serverPingAttempted = YES;
        _serverPingReachable = NO;
        _currentLatencyMs = -1;
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
        if (_serverPingReachable && _currentLatencyMs >= 0) {
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
            _serverStatusDot.backgroundColor = [UIColor colorWithWhite:0.55 alpha:1.0];
            _serverStatusLabel.text = @"Admin: Chưa đo";
            _serverStatusLabel.textColor = [UIColor colorWithWhite:0.75 alpha:1.0];
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
    } else if (_currentLatencyMs < 0) {
        _serverStatusDot.backgroundColor = [UIColor colorWithWhite:0.55 alpha:1.0];
        _serverStatusLabel.text = @"Free: Chưa có URL ping";
        _serverStatusLabel.textColor = [UIColor colorWithWhite:0.75 alpha:1.0];
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
    if (!_isFeatureActivated) {
        if ([button respondsToSelector:@selector(collapseMenu)]) [button collapseMenu];
        [self showUnexploitedWarningAlert];
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
                self.settingsDict[@"TargetRefreshRate"] = @144;
                self.settingsDict[@"TargetFPSRate"] = @144;
                self.settingsDict[@"ForceOverclock144Hz"] = @YES;
                _lastAppliedHz = 144;
                _lastAppliedFPS = 144;
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
    if (!fullyUnlocked && _tabButtons.count > 4) _currentBottomTab = 4;
    for (NSInteger i = 0; i < _tabButtons.count; i++) {
        LGGlassNavButton *button = _tabButtons[i];
        BOOL enabled = fullyUnlocked || i == 4;
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
        UIEdgeInsets desiredInset = UIEdgeInsetsMake(2.0, 0.0, 10.0, 0.0);
        if (!UIEdgeInsetsEqualToEdgeInsets(self.customTableView.contentInset, desiredInset)) self.customTableView.contentInset = desiredInset;
        if (!UIEdgeInsetsEqualToEdgeInsets(self.customTableView.scrollIndicatorInsets, desiredInset)) self.customTableView.scrollIndicatorInsets = desiredInset;
    }
}

#pragma mark - Liquid Nav Bar

- (void)setupLiquidGlassNavBar {
    CGFloat barHeight = 66.0;
    CGFloat barMargin = 10.0;
    CGFloat barY = self.view.bounds.size.height - self.view.safeAreaInsets.bottom - barHeight - 8.0;

    _liquidNavBarContainer = [[AppleLiquidGlassView alloc] initWithFrame:CGRectMake(barMargin, barY, self.view.bounds.size.width - (barMargin * 2), barHeight)
                                                            cornerRadius:barHeight / 2.0
                                                            materialType:LGGlassMaterialTypeCrystal];
    _liquidNavBarContainer.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    _liquidNavBarContainer.interactiveHighlightEnabled = NO;
    _liquidNavBarContainer.clipsToBounds = NO;
    _liquidNavBarContainer.layer.masksToBounds = NO;
    _liquidNavBarContainer.layer.shadowOpacity = 0.24;
    _liquidNavBarContainer.layer.shadowRadius = 12.0;
    _liquidNavBarContainer.layer.shadowOffset = CGSizeMake(0, 4);
    _liquidNavBarContainer.layer.shadowColor = [UIColor blackColor].CGColor;

    _tabConfigs = @[
        @{@"title": @"Trang Chủ", @"icon": @"house.fill",  @"tab": @0},
        @{@"title": @"Hz/FPS",    @"icon": @"speedometer", @"tab": @1},
        @{@"title": @"Switch",    @"icon": @"bolt.fill",   @"tab": @2},
        @{@"title": @"App",       @"icon": @"iphone",      @"tab": @3},
        @{@"title": @"Cài Đặt",   @"icon": @"gearshape",   @"tab": @4}
    ];

    CGFloat btnWidth = _liquidNavBarContainer.bounds.size.width / _tabConfigs.count;

    // [V10.2 - LIQUID NAVIGATION THEO VIDEO TIKTOK]: indicator là GIỌT NƯỚC TRÒN (blob) nổi lên PHÍA TRÊN thanh nav,
    // không nằm trong thanh. Di chuyển mượt giữa các tab, co giãn theo vận tốc như giọt nước thật.
    CGFloat blobSize = 48.0;
    _activeGlassIndicator = [[AppleLiquidGlassView alloc] initWithFrame:CGRectMake((btnWidth - blobSize)/2.0, -12.0, blobSize, blobSize)
                                                            cornerRadius:blobSize / 2.0
                                                            materialType:LGGlassMaterialTypeCrystal];
    _activeGlassIndicator.userInteractionEnabled = NO;
    _activeGlassIndicator.interactiveHighlightEnabled = NO;
    _activeGlassIndicator.layer.shadowOpacity = 0.45;
    _activeGlassIndicator.layer.shadowRadius = 12.0;
    _activeGlassIndicator.layer.shadowOffset = CGSizeMake(0, 5);
    _activeGlassIndicator.layer.shadowColor = [UIColor blackColor].CGColor;
    [_liquidNavBarContainer addSubview:_activeGlassIndicator];
    [_liquidNavBarContainer bringSubviewToFront:_activeGlassIndicator];

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
    if (!serverChosen) {
        [self showFirstInstallServerPicker];
        return;
    }
    if (!_isFeatureActivated && index != 4) {
        [self showUnexploitedWarningAlert];
        return;
    }
    NSInteger oldTab = _currentBottomTab;
    _currentBottomTab = [_tabConfigs[index][@"tab"] integerValue];
    if (_currentBottomTab == 3 && !_hasStartedAppScan) {
        _hasStartedAppScan = YES;
        [self loadInstalledAppsAsync];
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

- (void)setupMainTableView {
    self.customTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - 106) style:UITableViewStyleInsetGrouped];
    self.customTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.customTableView.backgroundColor = [UIColor clearColor];
    self.customTableView.separatorColor = [UIColor colorWithWhite:1.0 alpha:0.04];
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
    if (_currentBottomTab == 0) return 6;
    if (_currentBottomTab == 1) return 3;
    if (_currentBottomTab == 2) return 2;
    if (_currentBottomTab == 3) return 3;
    return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (!_isFeatureActivated && _currentBottomTab != 4) return 1;

    if (_currentBottomTab == 0) {
        if (section == 0) return 1;
        BOOL mA = [self.settingsDict[@"EnableSystemMonitoring"] boolValue];
        if (!mA) return 1;
        if (section == 1) return _isCpuExpanded ? 6 : 1;
        if (section == 2) return _isGpuExpanded ? 6 : 1;
        if (section == 3) return _isRamExpanded ? 5 : 1;
        if (section == 4) return _isBatteryExpanded ? 6 : 1;
        return _isScreenExpanded ? 5 : 1;
    } else if (_currentBottomTab == 1) {
        if (section == 0) return 1;
        if (section == 1) return 1;
        return 6;
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
        if (section == 2) return 4 + ([self isAdminDevRole] ? 2 : 0);
        return 4;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (!_isFeatureActivated && _currentBottomTab != 4) return @"CẦN KÍCH HOẠT CẤU HÌNH";
    if (_currentBottomTab == 0) {
        if (section == 0) return @"ĐIỀU KHIỂN HỆ THỐNG ĐO";
        if (section == 1) return @"CPU";
        if (section == 2) return @"GPU";
        if (section == 3) return @"RAM";
        if (section == 4) return @"PIN";
        return @"MÀN HÌNH";
    } else if (_currentBottomTab == 1) {
        if (section == 0) return @"NGUYÊN LÝ";
        if (section == 1) return @"CHỌN CHẾ ĐỘ";
        return (_currentHzFpsSubTab == 0) ? @"KHÓA HZ" : @"KHÓA FPS";
    } else if (_currentBottomTab == 2) {
        if (section == 0) return @"CHỌN NHÓM";
        switch (_currentSwitchSubTab) {
            case 0: return @"CPU";
            case 1: return @"GPU";
            case 2: return @"MÀN HÌNH";
            case 3: return @"PIN";
            case 4: return @"HỆ THỐNG";
            default: return @"CÔNG TẮC";
        }
    } else if (_currentBottomTab == 3) {
        if (section == 0) return @"THAO TÁC NHANH";
        if (section == 1) return @"TÌM KIẾM";
        return @"QUẢN LÝ ỨNG DỤNG";
    } else {
        if (section == 0) return @"KÍCH HOẠT";
        if (section == 1) return @"PHẦN CỨNG";
        if (section == 2) return @"SERVER & GIAO DIỆN";
        return @"SANDBOX";
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_currentBottomTab == 3 && indexPath.section == 1) return 52.0;
    return 58.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cid = @"LGGlassCell";
    LGGlassTableViewCell *cell = (LGGlassTableViewCell *)[tableView dequeueReusableCellWithIdentifier:cid];
    if (!cell) cell = [[LGGlassTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cid];

    NSString *title = @"";
    NSString *detail = @"";
    UIView *accessory = nil;
    UIColor *accent = nil;

    if (!_isFeatureActivated && _currentBottomTab != 4) {
        title = @"CẦN KÍCH HOẠT CẤU HÌNH";
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
                float baseTemp = Titanium_GetBaseThermalTemp();
                float cpu = Titanium_GetLiveCPULoadPercentage();
                float gpu = Titanium_GetLiveGPULoadPercentage();
                if (indexPath.section == 1) {
                    if (indexPath.row == 0) { title = _isCpuExpanded ? @"CPU ▼" : @"CPU ▶"; detail = [NSString stringWithFormat:@"%.1f°C | %.1f%%", baseTemp, cpu]; }
                    else if (indexPath.row == 1) { title = @"   Nhiệt độ"; detail = [NSString stringWithFormat:@"%.1f°C", baseTemp]; }
                    else if (indexPath.row == 2) { title = @"   Tải"; detail = [NSString stringWithFormat:@"%.1f%%", cpu]; }
                    else if (indexPath.row == 3) { float ghz = (cpu > 60.0f) ? 2.49f : ((cpu > 25.0f) ? 1.85f : 1.10f); title = @"   Xung P-Core"; detail = [NSString stringWithFormat:@"%.2f GHz", ghz]; }
                    else if (indexPath.row == 4) { title = @"   Điều Phối"; detail = (cpu > 40.0f) ? @"P-Core" : @"E-Core"; }
                    else { title = @"   Số Nhân"; detail = _deepCoreCountString ?: @"6 Cores"; }
                } else if (indexPath.section == 2) {
                    if (indexPath.row == 0) { title = _isGpuExpanded ? @"GPU ▼" : @"GPU ▶"; detail = [NSString stringWithFormat:@"%.1f°C | %.1f%%", baseTemp - 0.7f, gpu]; }
                    else if (indexPath.row == 1) { title = @"   Nhiệt"; detail = [NSString stringWithFormat:@"%.1f°C", baseTemp - 0.7f]; }
                    else if (indexPath.row == 2) { title = @"   Tải Metal"; detail = [NSString stringWithFormat:@"%.1f%%", gpu]; }
                    else if (indexPath.row == 3) { title = @"   Xung Metal"; detail = @"600 MHz Locked"; }
                    else if (indexPath.row == 4) { title = @"   Buffer"; detail = @"Triple Buffering"; }
                    else { title = @"   Metal"; detail = @"Apple GPU"; }
                } else if (indexPath.section == 3) {
                    if (indexPath.row == 0) { title = _isRamExpanded ? @"RAM ▼" : @"RAM ▶"; detail = [NSString stringWithFormat:@"%.1f°C | 42.5%%", baseTemp - 1.2f]; }
                    else if (indexPath.row == 1) { title = @"   Nhiệt LPDDR"; detail = [NSString stringWithFormat:@"%.1f°C", baseTemp - 1.2f]; }
                    else if (indexPath.row == 2) { title = @"   Dung lượng"; detail = _deepRamString ?: @"4.00 GB"; }
                    else if (indexPath.row == 3) { title = @"   Purgable"; detail = @"Clean"; }
                    else { title = @"   Ảo"; detail = @"Active"; }
                } else if (indexPath.section == 4) {
                    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
                    int level = (int)([[UIDevice currentDevice] batteryLevel] * 100);
                    if (level < 0) level = 100;
                    float bl = (cpu * 0.45f) + 8.5f;
                    if (indexPath.row == 0) { title = _isBatteryExpanded ? @"Pin ▼" : @"Pin ▶"; detail = [NSString stringWithFormat:@"%.1f°C | %.1f%%", baseTemp - 2.0f, bl]; }
                    else if (indexPath.row == 1) { title = @"   Nhiệt Cell"; detail = [NSString stringWithFormat:@"%.1f°C", baseTemp - 2.0f]; }
                    else if (indexPath.row == 2) { title = @"   Dòng xả"; detail = [NSString stringWithFormat:@"%.1f%%", bl]; }
                    else if (indexPath.row == 3) { title = @"   Dung lượng"; detail = [NSString stringWithFormat:@"%d%%", level]; }
                    else if (indexPath.row == 4) { title = @"   Sạc"; detail = @"Li-ion"; }
                    else { title = @"   Chu kỳ"; detail = @"Optimal"; }
                } else {
                    NSInteger hz = [self.settingsDict[@"TargetRefreshRate"] ?: @144 integerValue];
                    NSInteger fps = [self.settingsDict[@"TargetFPSRate"] ?: @144 integerValue];
                    if (indexPath.row == 0) { title = _isScreenExpanded ? @"Màn Hình ▼" : @"Màn Hình ▶"; detail = [NSString stringWithFormat:@"%.1f°C | %ld Hz", baseTemp - 1.5f, (long)hz]; }
                    else if (indexPath.row == 1) { title = @"   Nhiệt bề mặt"; detail = [NSString stringWithFormat:@"%.1f°C", baseTemp - 1.5f]; }
                    else if (indexPath.row == 2) { title = @"   Hz"; detail = [NSString stringWithFormat:@"%ld Hz", (long)hz]; }
                    else if (indexPath.row == 3) { title = @"   FPS"; detail = [NSString stringWithFormat:@"%ld FPS", (long)fps]; }
                    else { title = @"   ProMotion"; detail = @"120Hz"; }
                }
            }
        }
    }
    else if (_currentBottomTab == 1) {
        if (indexPath.section == 0) {
            title = @"Tần số Hz & FPS điều phối CADisplayLink & CoreAnimation. Nhấn Áp Dụng (góc phải trên) để đồng bộ.";
        } else if (indexPath.section == 1) {
            LGCustomSegment *seg = [[LGCustomSegment alloc] initWithItems:@[@"Tần Số (Hz)", @"Khung Hình (FPS)"]];
            seg.selectedSegmentIndex = _currentHzFpsSubTab;
            __weak typeof(self) wS = self;
            seg.valueChangedBlock = ^(NSInteger index) {
                __strong typeof(wS) sS = wS;
                if (!sS) return;
                if (sS->_currentHzFpsSubTab == index) return;
                sS->_currentHzFpsSubTab = index;
                [sS smoothReloadTable];
            };
            accessory = seg;
            title = @"   Chế độ:";
        } else {
            BOOL isHz = (_currentHzFpsSubTab == 0);
            NSInteger cur = isHz ? [self.settingsDict[@"TargetRefreshRate"] ?: @144 integerValue] : [self.settingsDict[@"TargetFPSRate"] ?: @144 integerValue];
            NSArray *rates = @[@30, @60, @90, @120];
            NSInteger applied = isHz ? _lastAppliedHz : _lastAppliedFPS;
            if (indexPath.row < 4) {
                NSInteger r = [rates[indexPath.row] integerValue];
                title = [NSString stringWithFormat:@"Khóa %ld %@", (long)r, isHz ? @"Hz" : @"FPS"];
                if (cur == r) { detail = @"✓"; accent = [UIColor colorWithRed:0.35 green:1.0 blue:0.55 alpha:1.0]; }
                else if (applied == r) accent = [UIColor colorWithRed:0.35 green:0.75 blue:1.0 alpha:1.0];
            } else if (indexPath.row == 4) {
                title = [NSString stringWithFormat:@"Mở Rộng 144 %@", isHz ? @"Hz" : @"FPS"];
                if (cur == 144) { detail = @"✓"; accent = [UIColor colorWithRed:0.35 green:1.0 blue:0.55 alpha:1.0]; }
                else if (applied == 144) accent = [UIColor colorWithRed:0.35 green:0.75 blue:1.0 alpha:1.0];
            } else {
                title = @"Nhập Tùy Chỉnh (15-144)...";
                detail = [NSString stringWithFormat:@"Hiện: %ld", (long)cur];
            }
        }
    }
    else if (_currentBottomTab == 2) {
        if (indexPath.section == 0) {
            LGCustomSegment *seg = [[LGCustomSegment alloc] initWithItems:@[@"CPU", @"GPU", @"Màn", @"Pin", @"Hệ Thống"]];
            seg.selectedSegmentIndex = _currentSwitchSubTab;
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
            title = @"Bật Tất Cả Ứng Dụng";
            BOOL allOn = YES;
            if (_appTweakStates.count == 0) {
                allOn = NO;
            } else {
                for (NSString *bid in _appTweakStates) {
                    if (![_appTweakStates[bid] boolValue]) { allOn = NO; break; }
                }
            }
            LiquidCapsuleSwitch *s = [[LiquidCapsuleSwitch alloc] init];
            s.on = allOn;
            __weak typeof(self) wS = self;
            s.valueChangedBlock = ^(BOOL isOn) {
                __strong typeof(wS) sS = wS;
                if (!sS) return;
                NSArray<NSString *> *keys = [sS->_appTweakStates allKeys];
                for (NSString *bid in keys) {
                    sS->_appTweakStates[bid] = @(isOn);
                }
                sS.settingsDict[@"AppTweakStates"] = sS->_appTweakStates;
                [sS saveSettingsDataAndSync];
                [sS applyDeepSpringBoardAndUIKitTweaks];
                [sS.customTableView reloadData];
            };
            accessory = s;
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
                title = _scannedAppsList.count == 0 ? @"Đang quét..." : @"Không có app khớp";
                [cell configureWithTitle:title detail:@"" accessory:nil accent:[UIColor colorWithWhite:0.6 alpha:1.0]];
                cell.userInteractionEnabled = NO;
                cell.alpha = 0.6;
                return cell;
            }
            NSDictionary *appInfo = _filteredAppsList[indexPath.row];
            title = appInfo[@"name"];
            detail = appInfo[@"bundleID"];
            LiquidCapsuleSwitch *s = [[LiquidCapsuleSwitch alloc] init];
            s.on = [_appTweakStates[appInfo[@"bundleID"]] boolValue];
            __weak typeof(self) wS = self;
            s.valueChangedBlock = ^(BOOL isOn) {
                __strong typeof(wS) sS = wS;
                if (!sS) return;
                sS->_appTweakStates[appInfo[@"bundleID"]] = @(isOn);
                sS.settingsDict[@"AppTweakStates"] = sS->_appTweakStates;
                [sS saveSettingsDataAndSync];
                [sS applyDeepSpringBoardAndUIKitTweaks];
            };
            accessory = s;
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
            else if (indexPath.row == 6) { title = @"RAM"; detail = _deepRamString; }
            else { title = @"Darwin"; detail = _deepKernelString; }
        } else if (indexPath.section == 2) {
            if (indexPath.row == 0) {
                title = @"Độ Trễ Server";
                int pState = Titanium_CurrentPersistentServerState();
                NSString *selectedMode = [[NSUserDefaults standardUserDefaults] stringForKey:TI_SELECTED_SERVER_KEY];
                BOOL adminMode = _isAdminServer || [selectedMode isEqualToString:@"admin"] || [selectedMode isEqualToString:@"admin_dev"];
                if (adminMode) {
                    detail = _serverPingReachable && _currentLatencyMs >= 0
                        ? [NSString stringWithFormat:@"%ld ms HTTP RTT", (long)_currentLatencyMs]
                        : (_pingRequestInFlight ? @"Đang đo HTTP RTT…" : (_serverPingAttempted ? @"Không kết nối được API" : @"Đang chờ đo API"));
                    accent = _serverPingReachable ? (_currentLatencyMs >= 500 ? [UIColor systemRedColor] : (_currentLatencyMs >= 150 ? [UIColor systemYellowColor] : [UIColor systemGreenColor])) : [UIColor colorWithWhite:0.70 alpha:1.0];
                } else if (pState != TI_STATE_OK) {
                    detail = (pState == TI_STATE_DOWN) ? @"Đang gặp sự cố" : ((pState == TI_STATE_OVERLOAD) ? @"Đang quá tải" : @"Lỗi kết nối");
                    accent = [UIColor systemRedColor];
                } else if (_currentLatencyMs < 0) {
                    detail = @"Chưa cấu hình URL ping cho Server Free";
                    accent = [UIColor colorWithWhite:0.70 alpha:1.0];
                } else {
                    detail = [NSString stringWithFormat:@"%ld ms", (long)_currentLatencyMs];
                    if (_currentLatencyMs >= 500) accent = [UIColor systemRedColor];
                    else if (_currentLatencyMs >= 150) accent = [UIColor systemYellowColor];
                    else accent = [UIColor systemGreenColor];
                }
            } else if (indexPath.row == 1) {
                title = @"Trạng Thái Server";
                int pState = Titanium_CurrentPersistentServerState();
                if (_isAdminServer) detail = @"Admin Server";
                else if (pState == TI_STATE_DOWN) detail = @"Sập";
                else if (pState == TI_STATE_OVERLOAD) detail = @"Quá tải";
                else if (pState == TI_STATE_ERROR) detail = @"Lỗi";
                else if (_currentLatencyMs >= 500) detail = @"Chậm";
                else if (_currentLatencyMs >= 150) detail = @"Kém";
                else detail = @"Ổn định";
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
                title = @"Server API URL";
                NSString *base = [self currentAdminAPIBaseURL];
                NSURLComponents *parts = [NSURLComponents componentsWithString:base];
                // Keep endpoint hostname hidden in the overview; URL is visible only in the Dev editor.
                detail = parts.host.length ? @"HTTPS đã cấu hình · chạm để sửa" : @"Chưa cấu hình HTTPS";
                accent = [UIColor colorWithRed:0.30 green:0.70 blue:1.0 alpha:1.0];
                cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            } else if (indexPath.row == 5 && [self isAdminDevRole]) {
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
            if (!_isFeatureActivated) {
                title = @"Cần kích hoạt";
                accent = [UIColor colorWithRed:1.0 green:0.5 blue:0.5 alpha:1.0];
                [cell configureWithTitle:title detail:@"" accessory:nil accent:accent];
                cell.userInteractionEnabled = NO;
                cell.alpha = 0.55;
                return cell;
            }
            NSString *jbRoot = Titanium_GetRootHidePrefixPath();
            if (indexPath.row == 0) { title = @"Môi Trường Jailbreak"; detail = Titanium_DetectJailbreakTypeForUI(); }
            else if (indexPath.row == 1) { title = @"Prefix Bootstrap"; detail = jbRoot ?: @"Không xác định"; }
            else if (indexPath.row == 2) { title = @"Sandbox"; detail = @"Không thể xác minh từ ứng dụng"; }
            else { title = @"IPC"; detail = @"Đường dẫn đồng bộ nội bộ"; }
        }
    }

    BOOL activationEntry = (_currentBottomTab == 4 && indexPath.section == 0 && indexPath.row == 0);
    BOOL adminLoginEntry = (_currentBottomTab == 4 && indexPath.section == 2 && indexPath.row == 2);
    if (!_isFeatureActivated && _currentBottomTab == 4 && !activationEntry && !adminLoginEntry) {
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
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *selectedServer = [[NSUserDefaults standardUserDefaults] stringForKey:TI_SELECTED_SERVER_KEY];
    if (![selectedServer isEqualToString:@"free"] && !self->_isAdminServer) {
        [self showFirstInstallServerPicker];
        return;
    }

    if (!_isFeatureActivated) {
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
        BOOL isHz = (_currentHzFpsSubTab == 0);
        NSArray *rates = @[@30, @60, @90, @120];
        NSInteger targetRate = 0;
        if (indexPath.row < 4) targetRate = [rates[indexPath.row] integerValue];
        else if (indexPath.row == 4) targetRate = 144;
        else { [self showCustomRateInputAlertForHz:isHz]; return; }

        [self applyRateValue:targetRate isDynamic:NO isFPS:!isHz];
        [self applyDeepSpringBoardAndUIKitTweaks];
        UIImpactFeedbackGenerator *rateFb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [rateFb impactOccurred];
        [self smoothReloadTable];
    } else if (_currentBottomTab == 4 && indexPath.section == 0 && indexPath.row == 0) {
        if (!_isAdminServer && !([self isServerStateOK])) { [self showPersistentServerStateAlert]; return; }
        NSInteger cc = Titanium_GetCrashCount();
        if (cc >= 3) [self showServerDownAlert];
        else [self openDopamineStyleExploitConsole];
    } else if (_currentBottomTab == 4 && indexPath.section == 2 && indexPath.row == 2) {
        [self showAdminServerLogin];
    } else if (_currentBottomTab == 4 && indexPath.section == 2 && indexPath.row == 3) {
        [self showThemeModePicker];
    } else if (_currentBottomTab == 4 && indexPath.section == 2 && indexPath.row == 4) {
        if ([self isAdminDevRole]) [self showAdminDevAPIURLEditor];
        else [self showUnexploitedWarningAlert];
    } else if (_currentBottomTab == 4 && indexPath.section == 2 && indexPath.row == 5) {
        if ([self isAdminDevRole]) [self showAdminDevConsole];
        else [self showUnexploitedWarningAlert];
    }
}

#pragma mark - Search

- (void)onAppSearchChanged:(UITextField *)field {
    _appSearchQuery = field.text ?: @"";
    uint64_t generation = ++_searchUpdateGeneration;
    NSString *query = [_appSearchQuery lowercaseString];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) owner = weakSelf;
        if (!owner || generation != owner->_searchUpdateGeneration) return;
        NSArray<NSDictionary *> *snapshot = [owner->_scannedAppsList copy] ?: @[];
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            NSMutableArray<NSDictionary *> *matches = [NSMutableArray array];
            for (NSDictionary *app in snapshot) {
                NSString *name = [(NSString *)app[@"name"] lowercaseString];
                NSString *bundleID = [(NSString *)app[@"bundleID"] lowercaseString];
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
    if (_appSearchQuery.length == 0) {
        [_filteredAppsList addObjectsFromArray:_scannedAppsList];
    } else {
        NSString *q = [_appSearchQuery lowercaseString];
        for (NSDictionary *app in _scannedAppsList) {
            NSString *name = [(NSString *)app[@"name"] lowercaseString];
            NSString *bid = [(NSString *)app[@"bundleID"] lowercaseString];
            if ([name containsString:q] || [bid containsString:q]) [_filteredAppsList addObject:app];
        }
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
    [self reloadVisibleContentWithSubtleTransition];
}
- (void)onSwitchSubTabChanged:(UISegmentedControl *)sender {
    _currentSwitchSubTab = sender.selectedSegmentIndex;
    [self reloadVisibleContentWithSubtleTransition];
}

- (void)showCustomRateInputAlertForHz:(BOOL)isHz {
    NSString *unit = isHz ? @"Hz" : @"FPS";
    UIAlertController *a = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"NHẬP %@", unit] message:[NSString stringWithFormat:@"15 - 144 %@", unit] preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull tf) {
        tf.keyboardType = UIKeyboardTypeNumberPad;
        tf.placeholder = [NSString stringWithFormat:@"15 - 144 %@", unit];
    }];
    [a addAction:[UIAlertAction actionWithTitle:@"Khóa Ngay" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UITextField *tf = a.textFields.firstObject;
        NSInteger val = [tf.text integerValue];
        if (val < 15) val = 15;
        if (val > 144) val = 144;
        [self applyRateValue:val isDynamic:NO isFPS:!isHz];
        [self applyDeepSpringBoardAndUIKitTweaks];
        [self smoothReloadTable];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)applyRateValue:(NSInteger)rate isDynamic:(BOOL)d isFPS:(BOOL)isFPS {
    if (rate < 15) rate = 15;
    if (rate > 144) rate = 144;
    self.settingsDict[@"TargetRefreshRate"] = @(rate);
    self.settingsDict[@"TargetFPSRate"] = @(rate);
    self.settingsDict[@"EnableHzControl"] = @YES;
    self.settingsDict[@"EnableFPSControl"] = @YES;
    self.settingsDict[@"ForceOverclock144Hz"] = @(rate >= 144);
    self->_lastAppliedHz = rate;
    self->_lastAppliedFPS = rate;
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

    _hudTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(_hudTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), (uint64_t)(5.0 * NSEC_PER_SEC), (uint64_t)(0.5 * NSEC_PER_SEC));
    __weak typeof(self) wS = self;
    dispatch_source_set_event_handler(_hudTimer, ^{
        __strong typeof(wS) sS = wS;
        if (sS && sS->_currentBottomTab == 0 && sS->_isFeatureActivated && [sS.settingsDict[@"EnableSystemMonitoring"] boolValue] && !sS->_chipErrorActive) {
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
}

- (void)syncSharedMemoryFile:(BOOL)enabled {
    if (!_isFeatureActivated) return;

    Titanium_SynchronizeLinkedPreferences(self.settingsDict, nil);

    ApexV285ProPayload p;
    memset(&p, 0, sizeof(ApexV285ProPayload));
    p.magic = APEX_SYNC_MAGIC_V285;

    BOOL masterEnabled = (enabled && _isFeatureActivated && !_serverDown);
    p.masterEnabled = masterEnabled ? 1 : 0;

    NSInteger requestedHz = [self.settingsDict[@"TargetRefreshRate"] ?: @144 integerValue];
    NSInteger requestedFPS = [self.settingsDict[@"TargetFPSRate"] ?: @144 integerValue];
    if (requestedHz < 15) requestedHz = 15;
    if (requestedHz > 144) requestedHz = 144;
    if (requestedFPS < 15) requestedFPS = 15;
    if (requestedFPS > 144) requestedFPS = 144;

    BOOL hzControlEnabled = self.settingsDict[@"EnableHzControl"] ? [self.settingsDict[@"EnableHzControl"] boolValue] : YES;
    BOOL fpsControlEnabled = self.settingsDict[@"EnableFPSControl"] ? [self.settingsDict[@"EnableFPSControl"] boolValue] : YES;
    BOOL powerSave = [self.settingsDict[@"PowerSaveMode"] ?: @NO boolValue] ||
                     [self.settingsDict[@"batterySaver60Hz"] ?: @NO boolValue];

    NSInteger resolvedHz = (!masterEnabled || !hzControlEnabled || powerSave) ? 60 : requestedHz;
    NSInteger resolvedFPS = (!masterEnabled || !fpsControlEnabled || powerSave) ? 60 : requestedFPS;

    p.targetHz = (int32_t)resolvedHz;
    p.targetFPS = (int32_t)resolvedFPS;
    p.forceOverclock = (resolvedHz >= 144) ? 1 : 0;
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
            NSInteger targetHz = [self.settingsDict[@"TargetRefreshRate"] ?: @144 integerValue];
            if (targetHz < 15) targetHz = 15;
            if (targetHz > 144) targetHz = 144;
            NSInteger nativeMax = 60;
            UIScreen *mainScreen = [UIScreen mainScreen];
            if ([mainScreen respondsToSelector:@selector(maximumFramesPerSecond)]) {
                NSInteger reportedMax = (NSInteger)mainScreen.maximumFramesPerSecond;
                if (reportedMax >= 30 && reportedMax <= 240) nativeMax = reportedMax;
            }
            targetHz = MIN(targetHz, nativeMax);
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

    // This is a local UI/configuration unlock, not a kernel exploit or a remote Apple-server operation.
    // Skip fake queue/spinner overlays so first-run doesn't dim the whole screen or hold up interaction.
    _activationFlowPresenting = YES;
    [self persistActivationDataToDisk];
    [self applyDeepSpringBoardAndUIKitTweaks];
    _activationFlowPresenting = NO;
    [self updateServerStatusIndicator];
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
    char cts[128] = {0};
    size_t size = sizeof(cts);
    sysctlbyname("machdep.cpu.brand_string", cts, &size, NULL, 0);
    NSString *brand = [NSString stringWithUTF8String:cts];
    if (!brand || brand.length == 0) {
        #if defined(__arm64e__)
        _deepArchString = @"arm64e (Apple PAC)";
        #elif defined(__arm64__)
        _deepArchString = @"arm64 (Apple A-Series)";
        #else
        _deepArchString = @"ARM64";
        #endif
    } else _deepArchString = brand;
    int ncpu = 0; size = sizeof(ncpu);
    sysctlbyname("hw.ncpu", &ncpu, &size, NULL, 0);
    _deepCoreCountString = [NSString stringWithFormat:@"%d Nhân (P/E)", ncpu];
    int64_t memsize = 0; size = sizeof(memsize);
    sysctlbyname("hw.memsize", &memsize, &size, NULL, 0);
    double ramGB = (double)memsize / (1024.0 * 1024.0 * 1024.0);
    _deepRamString = [NSString stringWithFormat:@"%.2f GB LPDDR", ramGB];
    char osr[64] = {0}; size = sizeof(osr);
    sysctlbyname("kern.osrelease", osr, &size, NULL, 0);
    _deepKernelString = [NSString stringWithFormat:@"Darwin %s", osr];
    int64_t l2 = 0; size = sizeof(l2);
    sysctlbyname("hw.l2cachesize", &l2, &size, NULL, 0);
    _deepCacheString = (l2 > 0) ? [NSString stringWithFormat:@"%lld KB L2", l2 / 1024] : @"Silicon Cache";
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
    if ([[NSFileManager defaultManager] fileExistsAtPath:p]) {
        self.settingsDict = [NSMutableDictionary dictionaryWithContentsOfFile:p] ?: [NSMutableDictionary dictionary];
    } else self.settingsDict = [NSMutableDictionary dictionary];
    Titanium_SynchronizeLinkedPreferences(self.settingsDict, nil);
    [self ensureDefaultSettingsExist];
}

- (void)saveSettingsDataAndSync {
    Titanium_SynchronizeLinkedPreferences(self.settingsDict, nil);
    NSString *p = Titanium_ResolvePrefPath();
    NSString *d = [p stringByDeletingLastPathComponent];
    if (![[NSFileManager defaultManager] fileExistsAtPath:d]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:d withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @(0700)} error:nil];
    }
    [self.settingsDict writeToFile:p atomically:YES];
    chmod([p UTF8String], 0600);
    id downVal = self.settingsDict[TI_SERVER_DOWN_KEY];
    if (downVal) {
        [[NSUserDefaults standardUserDefaults] setDouble:[downVal doubleValue] forKey:TI_SERVER_DOWN_KEY];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    BOOL master = [self.settingsDict[@"Enabled"] boolValue];
    [self syncSharedMemoryFile:master];
}

- (void)ensureDefaultSettingsExist {
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
        if (!self.settingsDict[k]) self.settingsDict[k] = @NO;
    }
    if (!self.settingsDict[@"TargetRefreshRate"]) self.settingsDict[@"TargetRefreshRate"] = @144;
    if (!self.settingsDict[@"TargetFPSRate"])    self.settingsDict[@"TargetFPSRate"]    = @144;
    if (!self.settingsDict[@"IsRateLocked"])     self.settingsDict[@"IsRateLocked"]     = @NO;
    if (!self.settingsDict[@"FeatureActivationComplete"]) self.settingsDict[@"FeatureActivationComplete"] = @NO;
    if (!self.settingsDict[TI_AUTO_THEME_KEY])   self.settingsDict[TI_AUTO_THEME_KEY]   = @NO;
    if (![self.settingsDict[TI_THEME_MODE_KEY] isKindOfClass:[NSString class]]) {
        self.settingsDict[TI_THEME_MODE_KEY] = [self.settingsDict[TI_AUTO_THEME_KEY] boolValue] ? @"system" : @"dark";
    }
    if (!self.settingsDict[@"SelectedLanguage"]) {
        self.settingsDict[@"SelectedLanguage"] = self.settingsDict[@"AppLanguage"] ?: @"auto";
    }
    if (!self.settingsDict[@"IsAdminServer"])    self.settingsDict[@"IsAdminServer"]    = @NO;
}

- (void)loadInstalledAppsAsync {
    NSDictionary *saved = self.settingsDict[@"AppTweakStates"];
    _appTweakStates = saved ? [saved mutableCopy] : [NSMutableDictionary dictionary];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSMutableArray<NSDictionary *> *temp = [NSMutableArray array];
        NSArray *dirs = @[@"/Applications", @"/var/jb/Applications"];
        NSFileManager *fm = [NSFileManager defaultManager];
        for (NSString *d in dirs) {
            if ([fm fileExistsAtPath:d]) {
                NSArray *items = [fm contentsOfDirectoryAtPath:d error:nil];
                for (NSString *item in items) {
                    if ([item hasSuffix:@".app"]) {
                        NSString *full = [d stringByAppendingPathComponent:item];
                        NSString *info = [full stringByAppendingPathComponent:@"Info.plist"];
                        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:info];
                        NSString *name = dict[@"CFBundleDisplayName"] ?: dict[@"CFBundleName"] ?: [item stringByDeletingPathExtension];
                        NSString *bid = dict[@"CFBundleIdentifier"] ?: item;
                        [temp addObject:@{@"name": name, @"bundleID": bid, @"path": full}];
                    }
                }
            }
        }
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

@end
