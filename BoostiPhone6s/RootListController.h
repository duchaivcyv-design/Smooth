#ifndef ROOTLISTCONTROLLER_H
#define ROOTLISTCONTROLLER_H

#import <UIKit/UIKit.h>

@class PSSpecifier;

#if __has_include("PSListController.h")
#import "PSListController.h"
#import "PSSpecifier.h"
#elif __has_include(<Preferences/PSListController.h>)
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#else
@interface PSListController : UIViewController {
    id _specifiers;
}
@property (nonatomic, strong, nullable) PSSpecifier *specifier;
- (id)initForContentSize:(CGSize)size;
- (nullable NSMutableArray *)specifiers;
- (void)reloadSpecifiers;
- (void)setSpecifiers:(id)specifiers;
- (nullable NSMutableArray *)loadSpecifiersFromPlistName:(NSString *)name target:(nullable id)target;
- (nullable PSSpecifier *)specifierForID:(NSString *)identifier;
@end
#endif

NS_ASSUME_NONNULL_BEGIN

#define PREF_DOMAIN CFSTR("com.taojb.boostiphone6s")
#define PRIMARY_SYNC_FILE @"/tmp/.boost_hz_sync"
#define SECONDARY_SYNC_FILE @"/var/jb/tmp/.boost_hz_sync"
#define SHARED_SYNC_FILE @"/tmp/.boost_hz_sync"
#define BOOT_GUARD_FILE @"/tmp/.boost_boot_counter"

#define NOTIFY_RELOAD "com.taojb.boostiphone6s/ReloadPrefs"
#define NOTIFY_UIKIT_RELOAD "com.taojb.boostiphone6s/ReloadUIKitPrefs"
#define NOTIFY_HARDWARE_SYNC "com.taojb.boostiphone6s/HardwareSync"
#define NOTIFY_FPS_CHANGED "com.taojb.boostiphone6s/FPSChanged"
#define NOTIFY_TITANIUM_CHANGED "com.titanium.v285.prefschanged"

#ifndef APEX_SYNC_MAGIC_V285
#define APEX_SYNC_MAGIC_V285 0x41505837
#endif

#ifndef _APEX_V285_PRO_PAYLOAD_DEFINED
#define _APEX_V285_PRO_PAYLOAD_DEFINED
typedef struct __attribute__((packed)) {
    uint32_t magic;
    uint32_t masterEnabled;
    int32_t  targetHz;
    int32_t  targetFPS;
    uint32_t forceOverclock;
    uint32_t pipSyncEnabled;
    uint32_t thermalShield;
    uint32_t antiStutterExit;
    uint32_t smartBufferingLevel;
    uint32_t zeroLatencyTouch;
    uint32_t shaderOptimization;
    uint32_t dynamicInterpolation;
    uint32_t fastAppLaunch;
    uint32_t lowLatencyAudio;
    uint32_t memoryPressureRelief;
    uint32_t metalPacingEnabled;
    uint32_t runloopHangGuard;
    uint32_t keyboardZeroLagV3;
    uint32_t aggressiveRamCleaner;
    uint32_t lockFixedFpsWhenThermal;
    uint32_t antiGhostTouch;
    uint32_t diskIOPriorityBoost;
    uint32_t rawTouchDirectDelivery;
    uint32_t powerSaveModeActive;
    uint64_t updateSeq;
    uint64_t lastHeartbeat;
    char     reserved[48];
} ApexV285ProPayload;
#endif

@interface RootListController : PSListController {
@public
    NSMutableArray *_allSavedSpecifiers;
    NSMutableArray *_specifiers; // [ĐÃ KHAI BÁO CÔNG KHAI - TRIỆT TIÊU LỖI CLANG]
}

- (nullable id)readPreferenceValue:(PSSpecifier *)specifier;
- (void)setPreferenceValue:(nullable id)value specifier:(PSSpecifier *)specifier;
- (NSDictionary *)getMergedPreferences;
- (void)ensureDefaultSettingsExist;
- (void)syncSharedMemoryFile:(BOOL)enabled;

// --- 4 hàm đo chỉ số phần cứng cho Root.plist ---
- (id)getMonitorHzFPS:(PSSpecifier *)specifier;
- (id)getMonitorCPUGPU:(PSSpecifier *)specifier;
- (id)getMonitorThermal:(PSSpecifier *)specifier;
- (id)getMonitorBattery:(PSSpecifier *)specifier;

- (void)showHzPickerPopup:(PSSpecifier *)specifier;
- (void)showFPSPickerPopup:(PSSpecifier *)specifier;
- (void)showCustomRateInputAlertForHz:(BOOL)isHz;
- (void)showSubMenuWithOptions:(NSArray *)rates title:(NSString *)title unit:(NSString *)unit isFPS:(BOOL)isFPS;
- (void)applyRateValue:(NSInteger)rate isDynamic:(BOOL)dynamicMode isFPS:(BOOL)isFPS;

- (void)showLanguagePickerPopup:(PSSpecifier *)specifier;
- (void)updateDynamicTitles;
- (void)applyFullLocalizationToSpecifiers:(NSArray *)specs;

- (id)getAuthorName:(PSSpecifier *)specifier;
- (id)getVersionString:(PSSpecifier *)specifier;
- (void)openSupportLink:(PSSpecifier *)specifier;

- (void)setupNavigationItems;
- (void)presentActions;
- (void)executeRespring;
- (void)executeSReboot;
- (void)executeResetConfiguration;

@end

NS_ASSUME_NONNULL_END

#endif /* ROOTLISTCONTROLLER_H */
