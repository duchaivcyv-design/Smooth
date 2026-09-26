#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <spawn.h>
#import <notify.h>
#import <sys/stat.h>
#import <fcntl.h>
#import <unistd.h>

#define PREF_PATH @"/var/jb/var/mobile/Library/Preferences/com.duchaivcy.boostiphone6s.plist"
#define FALLBACK_PREF_PATH @"/var/mobile/Library/Preferences/com.duchaivcy.boostiphone6s.plist"
#define NOTIFY_RELOAD "com.duchaivcy.boostiphone6s/ReloadPrefs"
#define SHARED_MMAP_FILE "/tmp/.smoothios_shared_config.bin"

extern char **environ;

typedef struct {
    uint32_t magic;
    uint32_t enabled;
    uint32_t enableHzControl;
    uint32_t targetHz;
    uint32_t enableFPSControl;
    uint32_t targetFPS;
    uint32_t forceOverclock144Hz;
    uint32_t dynamicThermalEngineBeta1;
    uint32_t zeroLagNeuralBoosterBeta1;
    uint32_t vsyncAdaptiveBufferBeta1;
    float animSpeed;
} __attribute__((packed)) SmoothSharedConfig;

@interface RootListController : PSListController
@end

@implementation RootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        @try {
            _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
        } @catch (NSException *e) {
            _specifiers = [NSMutableArray array];
        }
    }
    return _specifiers;
}

- (NSString *)effectivePrefPath {
    if ([[NSFileManager defaultManager] fileExistsAtPath:PREF_PATH]) return PREF_PATH;
    return FALLBACK_PREF_PATH;
}

- (void)broadcastConfigToSharedMemory:(NSDictionary *)prefs {
    int fd = open(SHARED_MMAP_FILE, O_RDWR | O_CREAT | O_TRUNC, 0666);
    if (fd >= 0) {
        SmoothSharedConfig cfg;
        memset(&cfg, 0, sizeof(SmoothSharedConfig));
        cfg.magic = 0x534D5448; // "SMTH"
        cfg.enabled = prefs[@"Enabled"] ? [prefs[@"Enabled"] boolValue] : 1;
        cfg.enableHzControl = prefs[@"EnableHzControl"] ? [prefs[@"EnableHzControl"] boolValue] : 1;
        cfg.targetHz = (uint32_t)(prefs[@"TargetRefreshRate"] ? [prefs[@"TargetRefreshRate"] integerValue] : 60);
        cfg.enableFPSControl = prefs[@"EnableFPSControl"] ? [prefs[@"EnableFPSControl"] boolValue] : 1;
        cfg.targetFPS = (uint32_t)(prefs[@"TargetFPSRate"] ? [prefs[@"TargetFPSRate"] integerValue] : 60);
        cfg.forceOverclock144Hz = prefs[@"ForceOverclock144Hz"] ? [prefs[@"ForceOverclock144Hz"] boolValue] : 1;
        cfg.dynamicThermalEngineBeta1 = prefs[@"DynamicThermalEngineBeta1"] ? [prefs[@"DynamicThermalEngineBeta1"] boolValue] : 1;
        cfg.zeroLagNeuralBoosterBeta1 = prefs[@"ZeroLagNeuralBoosterBeta1"] ? [prefs[@"ZeroLagNeuralBoosterBeta1"] boolValue] : 1;
        cfg.vsyncAdaptiveBufferBeta1 = prefs[@"VsyncAdaptiveBufferBeta1"] ? [prefs[@"VsyncAdaptiveBufferBeta1"] boolValue] : 1;
        cfg.animSpeed = prefs[@"AnimSpeed"] ? [prefs[@"AnimSpeed"] floatValue] : 0.82f;
        
        write(fd, &cfg, sizeof(SmoothSharedConfig));
        close(fd);
        chmod(SHARED_MMAP_FILE, 0666);
    }
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    @try {
        NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:[self effectivePrefPath]];
        if (!prefs) return specifier.properties[@"default"];
        id val = prefs[specifier.properties[@"key"]];
        return val ? val : specifier.properties[@"default"];
    } @catch (NSException *e) {
        return specifier.properties[@"default"];
    }
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    @try {
        NSString *path = [self effectivePrefPath];
        NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:path] ?: [NSMutableDictionary dictionary];
        prefs[specifier.properties[@"key"]] = value;
        [prefs writeToFile:path atomically:YES];
        
        // Đồng bộ tức thì ra shared memory để các app con nhận lệnh lập tức
        [self broadcastConfigToSharedMemory:prefs];
        notify_post(NOTIFY_RELOAD);
    } @catch (NSException *e) {}
}

// ============================================================================
// HIỂN THỊ ĐỘNG TRỰC TIẾP TRÊN DANH SÁCH
// ============================================================================
- (NSString *)getHzDisplayValue:(PSSpecifier *)specifier {
    @try {
        NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:[self effectivePrefPath]];
        BOOL enabled = prefs[@"EnableHzControl"] ? [prefs[@"EnableHzControl"] boolValue] : YES;
        if (!enabled) return @"Tắt";
        NSInteger val = prefs[@"TargetRefreshRate"] ? [prefs[@"TargetRefreshRate"] integerValue] : 60;
        if (val == 0) return @"Tự động";
        return [NSString stringWithFormat:@"Khóa ở %ld Hz", (long)val];
    } @catch (NSException *e) {
        return @"Khóa ở 60 Hz";
    }
}

- (NSString *)getFPSDisplayValue:(PSSpecifier *)specifier {
    @try {
        NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:[self effectivePrefPath]];
        BOOL enabled = prefs[@"EnableFPSControl"] ? [prefs[@"EnableFPSControl"] boolValue] : YES;
        if (!enabled) return @"Tắt";
        NSInteger val = prefs[@"TargetFPSRate"] ? [prefs[@"TargetFPSRate"] integerValue] : 60;
        if (val == 0) return @"Tự động";
        return [NSString stringWithFormat:@"Khóa ở %ld FPS", (long)val];
    } @catch (NSException *e) {
        return @"Khóa ở 60 FPS";
    }
}

// ============================================================================
// BẬT ACTION SHEET CHUẨN 100% THEO ẢNH MẪU
// ============================================================================
- (void)showHzPickerPopup:(PSSpecifier *)specifier {
    [self presentActionSheetForSpecifier:specifier 
                                   title:@"Chọn Tần Số Quét (Hz & FPS)" 
                                 message:@"Lựa chọn mức hiển thị hệ thống:\n• Tự Động: Tự cân bằng theo nhiệt độ & tải\n• 30Hz: Tiết kiệm pin tối đa, giảm sinh nhiệt\n• 60Hz: Mặc định chuẩn\n• 90Hz - 120Hz - 144Hz: Tối ưu cảm ứng siêu mượt" 
                                     key:@"TargetRefreshRate" 
                                  suffix:@"Hz"];
}

- (void)showFPSPickerPopup:(PSSpecifier *)specifier {
    [self presentActionSheetForSpecifier:specifier 
                                   title:@"Chọn Mức Khung Hình Ứng Dụng (FPS)" 
                                 message:@"Lựa chọn mức hiển thị hệ thống:\n• Tự Động: Tự cân bằng theo nhiệt độ & tải\n• 30Hz: Tiết kiệm pin tối đa, giảm sinh nhiệt\n• 60Hz: Mặc định chuẩn\n• 90Hz - 120Hz - 144Hz: Tối ưu cảm ứng siêu mượt" 
                                     key:@"TargetFPSRate" 
                                  suffix:@"FPS"];
}

- (void)presentActionSheetForSpecifier:(PSSpecifier *)specifier 
                                 title:(NSString *)title 
                               message:(NSString *)message 
                                   key:(NSString *)prefKey 
                                suffix:(NSString *)suffix {
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:title
                                                                         message:message
                                                                  preferredStyle:UIAlertControllerStyleActionSheet];

    __weak typeof(self) weakSelf = self;
    void (^saveHandler)(NSNumber *) = ^(NSNumber *val) {
        NSString *path = [weakSelf effectivePrefPath];
        NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:path] ?: [NSMutableDictionary dictionary];
        prefs[prefKey] = val;
        [prefs writeToFile:path atomically:YES];
        
        [weakSelf broadcastConfigToSharedMemory:prefs];
        notify_post(NOTIFY_RELOAD);
        [weakSelf reloadSpecifiers];
    };

    [actionSheet addAction:[UIAlertAction actionWithTitle:@"Tự Động Điều Chỉnh (Dynamic)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        saveHandler(@0);
    }]];

    [actionSheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Khóa ở 30 %@ (Tiết kiệm pin)", suffix] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        saveHandler(@30);
    }]];

    [actionSheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Khóa ở 60 %@ (Mặc định)", suffix] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        saveHandler(@60);
    }]];

    [actionSheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Khóa ở 90 %@ (Mượt mà)", suffix] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        saveHandler(@90);
    }]];

    [actionSheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Khóa ở 120 %@ (Cực mượt)", suffix] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        saveHandler(@120);
    }]];

    [actionSheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Khóa ở 144 %@ (Cực đại)", suffix] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        saveHandler(@144);
    }]];

    [actionSheet addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        UITableViewCell *cell = [self cachedCellForSpecifier:specifier];
        actionSheet.popoverPresentationController.sourceView = cell ? cell : self.view;
        actionSheet.popoverPresentationController.sourceRect = cell ? cell.bounds : CGRectMake(self.view.bounds.size.width / 2.0, self.view.bounds.size.height / 2.0, 1.0, 1.0);
    }

    [self presentViewController:actionSheet animated:YES completion:nil];
}

// ============================================================================
// HỆ THỐNG
// ============================================================================
- (void)respringDevice {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Khởi Động Lại SpringBoard"
                                                                   message:@"Respring để áp dụng toàn bộ thay đổi cấu hình Titanium Hyper V22.0.1?"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Respring Ngay" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        pid_t pid;
        const char *argv[] = {"killall", "-9", "SpringBoard", NULL};
        posix_spawn(&pid, "/var/jb/usr/bin/killall", NULL, NULL, (char *const *)argv, environ);
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)resetAllSettings {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Đặt Lại Cấu Hình"
                                                                   message:@"Khôi phục cài đặt gốc của SmoothiOS V22.0.1?"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Đặt Lại" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [[NSFileManager defaultManager] removeItemAtPath:PREF_PATH error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:FALLBACK_PREF_PATH error:nil];
        unlink(SHARED_MMAP_FILE);
        notify_post(NOTIFY_RELOAD);
        [self reloadSpecifiers];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
