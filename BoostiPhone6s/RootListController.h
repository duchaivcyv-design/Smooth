#ifndef ROOTLISTCONTROLLER_H
#define ROOTLISTCONTROLLER_H

#import <UIKit/UIKit.h>

@class PSSpecifier;

// ====================================================================================================
// KHAI BÁO DỰ PHÒNG CHO CLANG KHI BUILD ĐỘC LẬP HOẶC DÙNG PREFERENCEBUNDLE
// ====================================================================================================

#if __has_include("PSListController.h")
#import "PSListController.h"
#import "PSSpecifier.h"
#elif __has_include(<Preferences/PSListController.h>)
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#else
@interface PSListController : UIViewController {
@public
    id _specifiers;
}
@property (nonatomic, strong, nullable) PSSpecifier *specifier;
- (id)initForContentSize:(CGSize)size;
- (nullable NSMutableArray *)specifiers;
- (void)reloadSpecifiers;
- (void)setSpecifiers:(id)specifiers;
- (nullable NSMutableArray *)loadSpecifiersFromPlistName:(NSString *)name target:(nullable id)target;
- (nullable PSSpecifier *)specifierForID:(NSString *)identifier;
- (nullable UITableView *)table;
- (nullable NSIndexPath *)indexPathForSpecifier:(PSSpecifier *)specifier;
- (nullable PSSpecifier *)specifierAtIndexPath:(NSIndexPath *)indexPath;
- (nullable UITableViewCell *)cachedCellForSpecifier:(PSSpecifier *)specifier;
- (NSInteger)indexOfSpecifier:(PSSpecifier *)specifier;
@end
#endif

NS_ASSUME_NONNULL_BEGIN

// ====================================================================================================
// ĐỊNH NGHĨA MACRO ĐỒNG BỘ TOÀN HỆ THỐNG & ĐƯỜNG DẪN TỆP IPC (CHẾ ĐỘ ĐÃ ÉP TOÀN DIỆN)
// ====================================================================================================

#ifndef PREF_DOMAIN
#define PREF_DOMAIN          CFSTR("com.taojb.boostiphone6s")
#endif

#ifndef PRIMARY_SYNC_FILE
#define PRIMARY_SYNC_FILE    @"/tmp/.boost_hz_sync"
#endif

#ifndef SECONDARY_SYNC_FILE
#define SECONDARY_SYNC_FILE  @"/var/jb/tmp/.boost_hz_sync"
#endif

#ifndef SHARED_SYNC_FILE
#define SHARED_SYNC_FILE     @"/tmp/.boost_hz_sync"
#endif

#ifndef BOOT_GUARD_FILE
#define BOOT_GUARD_FILE      @"/tmp/.titanium_boot_guard"
#endif

#ifndef NOTIFY_RELOAD
#define NOTIFY_RELOAD        "com.taojb.boostiphone6s/ReloadPrefs"
#define NOTIFY_UIKIT_RELOAD  "com.taojb.boostiphone6s/ReloadUIKitPrefs"
#define NOTIFY_HARDWARE_SYNC "com.taojb.boostiphone6s/HardwareSync"
#define NOTIFY_FPS_CHANGED   "com.taojb.boostiphone6s/FPSChanged"
#define NOTIFY_TITANIUM_CHANGED "com.titanium.v285.prefschanged"
#endif

#ifndef APEX_SYNC_MAGIC_V285
#define APEX_SYNC_MAGIC_V285 0x41505837
#endif

// ====================================================================================================
// CẤU TRÚC STRUCT ĐỒNG BỘ NGUYÊN TỬ QUA RAM & TỆP IPC
// ====================================================================================================

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

// ====================================================================================================
// GIAO DIỆN LỚP ĐIỀU KHIỂN CHÍNH ROOTLISTCONTROLLER (ĐÃ ÉP TOÀN BỘ PHƯƠNG THỨC)
// ====================================================================================================

@interface RootListController : PSListController {
@public
    NSMutableArray *_allSavedSpecifiers;
    NSMutableArray *_specifiers; // [ĐÃ KHAI BÁO CÔNG KHAI - TRIỆT TIÊU LỖI CLANG]
}

// --- Quản lý dữ liệu và cấu hình ---
- (nullable id)readPreferenceValue:(PSSpecifier *)specifier;
- (void)setPreferenceValue:(nullable id)value specifier:(PSSpecifier *)specifier;
- (NSDictionary *)getMergedPreferences;
- (void)ensureDefaultSettingsExist;
- (void)syncSharedMemoryFile:(BOOL)enabled;

// --- HUD Đo Chỉ Số Phần Cứng Thời Gian Thực (Đầy Đủ 15 Mục HUD) ---
- (id)getMonitorHzFPS:(PSSpecifier *)specifier;
- (id)getMonitorScreenRefreshRate:(PSSpecifier *)specifier;
- (id)getMonitorScreenThermal:(PSSpecifier *)specifier;
- (id)getMonitorScreenOverclocked:(PSSpecifier *)specifier;

- (id)getMonitorCPUTemp:(PSSpecifier *)specifier;
- (id)getMonitorCPULoad:(PSSpecifier *)specifier;
- (id)getMonitorCPUClock:(PSSpecifier *)specifier;

- (id)getMonitorGPUTemp:(PSSpecifier *)specifier;
- (id)getMonitorGPULoad:(PSSpecifier *)specifier;
- (id)getMonitorGPUClock:(PSSpecifier *)specifier;

- (id)getMonitorBatteryTemp:(PSSpecifier *)specifier;
- (id)getMonitorBatteryVoltage:(PSSpecifier *)specifier;

// --- 4 Getter tương thích ngược cho file Root.plist cũ ---
- (id)getMonitorCPUGPU:(PSSpecifier *)specifier;
- (id)getMonitorThermal:(PSSpecifier *)specifier;
- (id)getMonitorBattery:(PSSpecifier *)specifier;

// --- Vòng lặp cập nhật HUD ngầm ---
- (void)startContinuousHardwareHUD;
- (void)stopContinuousHardwareHUD;
- (void)refreshContinuousHardwareCells;

// --- Điều phối tần số quét Hz & FPS ---
- (void)showHzPickerPopup:(PSSpecifier *)specifier;
- (void)showFPSPickerPopup:(PSSpecifier *)specifier;
- (void)showCustomRateInputAlertForHz:(BOOL)isHz;
- (void)showSubMenuWithOptions:(NSArray *)rates title:(NSString *)title unit:(NSString *)unit isFPS:(BOOL)isFPS;
- (void)applyRateValue:(NSInteger)rate isDynamic:(BOOL)dynamicMode isFPS:(BOOL)isFPS;

// --- Đa ngôn ngữ và cập nhật tiêu đề động ---
- (void)showLanguagePickerPopup:(PSSpecifier *)specifier;
- (void)updateDynamicTitles;
- (void)updateDynamicTitlesForSpecifiers:(NSArray *)targetSpecs;
- (void)applyFullLocalizationToSpecifiers:(NSArray *)specs;

// --- Thông tin tác giả & Liên kết hỗ trợ ---
- (id)getAuthorName:(PSSpecifier *)specifier;
- (id)getVersionString:(PSSpecifier *)specifier;
- (void)openSupportLink:(PSSpecifier *)specifier;

// --- Hành động hệ thống (Respring, Userspace Reboot, Reset) ---
- (void)setupNavigationItems;
- (void)presentActions;
- (void)executeRespring;
- (void)executeSReboot;
- (void)executeResetConfiguration;

@end

NS_ASSUME_NONNULL_END

#endif /* ROOTLISTCONTROLLER_H */
