#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>
#import <IOKit/IOKitLib.h>
#import <sys/sysctl.h>
#import <dlfcn.h> // Bắt buộc phải import để dùng dlsym

// ==========================================
// 1. FIX SYSTEM() AN TOÀN (KHÔNG ĐỆ QUY)
// Dùng dlsym để lấy địa chỉ thật của hàm system trong libc, 
// tránh việc Macro #define làm hỏng lời gọi bên trong.
// ==========================================
typedef int (*system_func_t)(const char *);
static inline int safe_system(const char *cmd) {
    static system_func_t real_system = NULL;
    if (!real_system) {
        void *handle = dlopen("/usr/lib/system/libsystem_c.dylib", RTLD_LAZY);
        if (handle) {
            real_system = (system_func_t)dlsym(handle, "system");
        }
    }
    if (real_system) return real_system(cmd);
    return -1; // Fail-safe nếu không tìm thấy
}

// Alias ngắn gọn cho code phía dưới
#define sys_exec(cmd) safe_system(cmd)

// ==========================================
// 2. STUB INTERFACES BỔ SUNG
// Thêm NotificationCenter vào danh sách class cần view
// ==========================================

@interface NSObject (BoostStubs)
- (id)valueForKey:(NSString *)key;
@end

// --- SpringBoard & System UI ---
@interface SBSearchController : UIViewController @end
@interface WGWidgetHostingViewController : UIViewController @end
@interface CCUIControlCenterViewController : UIViewController @end
@interface SBAppSwitcherController : UIViewController @end
@interface SBLockScreenViewController : UIViewController @end
@interface CameraController : NSObject 
@property(nonatomic, strong) UIView *view; 
@end
@interface AVCaptureSession (BoostStubs)
@property(copy) NSString *sessionPreset;
#ifndef AVCaptureSessionPresetLow
#define AVCaptureSessionPresetLow @"AVCaptureSessionPresetLow"
#endif
@end

// --- Apps ---
@interface PhotosUI : UIViewController @end
@interface MapsApp : UIViewController @end
@interface MessagesApp : UIResponder @end
@interface MailApp : UIResponder @end
@interface PreferencesAppController : UIResponder @end

// --- Managers & Services ---
@interface SpringBoard : UIResponder @end
@interface FBSSystemService : NSObject @end
@interface SBLockScreenManager : NSObject @end
@interface BBServer : NSObject @end
@interface WiFiManager : NSObject @end
@interface BrightnessSystem : NSObject @end
@interface Analytics : NSObject @end
@interface GameCenter : NSObject @end
@interface BatteryCenter : NSObject @end
@interface AirDrop : NSObject @end
@interface BluetoothManager : NSObject @end
@interface CameraCapture : NSObject @end
@interface Handoff : NSObject @end
@interface FrontBoardServices : NSObject @end
@interface OrientationManager : NSObject @end
@interface Continuity : NSObject @end
@interface ProcessManager : NSObject @end
@interface SiriSuggestions : NSObject @end
@interface SafariServices : NSObject @end
@interface CloudKit : NSObject @end
@interface UIKeyboardImpl : NSObject @end

// ★ QUAN TRỌNG: Khai báo NotificationCenter là ViewController để có .view
@interface NotificationCenter : UIViewController @end

// ==========================================
// 3. CODE HOOK CHÍNH
// Thay thế tất cả các lệnh system(...) bằng sys_exec(...)
// ==========================================

%hook UIView
- (void)setAlpha:(CGFloat)alpha {
    if (alpha > 0.95) alpha = 1.0;
    %orig(alpha);
}
%end

%hook CALayer
- (CFTimeInterval)duration {
    return 0.15;
}
%end

%hook UIVisualEffectView
- (void)didMoveToSuperview {
    [self removeFromSuperview];
}
%end

%hook UIScreen
- (CGFloat)scale {
    return 2.0;
}
%end

%hook UIApplication
- (void)didReceiveMemoryWarning {
    SEL sel = NSSelectorFromString(@"_purgeMemoryCache");
    if ([self respondsToSelector:sel]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:sel];
        #pragma clang diagnostic pop
    }
    %orig;
}
%end

%hook UIScrollView
- (void)setContentOffset:(CGPoint)contentOffset animated:(BOOL)animated {
    if (animated) animated = NO;
    %orig(contentOffset, animated);
}
%end

%hook UIInterpolatingMotionEffect
- (instancetype)initWithKeyPath:(NSString *)keyPath type:(NSInteger)type {
    return nil;
}
%end

%hook UIWindow
- (void)sendEvent:(UIEvent *)event {
    if (event.type == UIEventTypeTouches) {
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.001]];
    }
    %orig(event);
}
%end

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    sys_exec("sync");
    sys_exec("purge");
}
%end

%hook NSProcessInfo
- (float)thermalState {
    return 1.0;
}
%end

%hook FBSSystemService
- (void)openApplication:(id)application withOptions:(id)options {
    %orig(application, nil);
}
%end

%hook SBLockScreenManager
- (void)lockUIFromSource:(int)source withOptions:(id)options {
    %orig(source, nil);
}
%end

%hook CAMetalLayer
- (void)setMaximumDrawableCount:(NSUInteger)count {
    %orig(2);
}
%end

%hook MTLTextureDescriptor
- (void)setPixelFormat:(NSUInteger)pixelFormat {
    if (pixelFormat == 80) pixelFormat = 70;
    %orig(pixelFormat);
}
%end

%hook UITouch
- (NSTimeInterval)timestamp {
    return [[NSDate date] timeIntervalSinceReferenceDate];
}
%end

%hook SBSearchController
- (void)viewDidLoad {
    [self.view removeFromSuperview];
}
%end

%hook CADisplayLink
- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (fps > 30) fps = 30;
    %orig(fps);
}
%end

%hook NSURLCache
- (void)setMemoryCapacity:(NSUInteger)capacity {
    %orig(1024 * 1024 * 10);
}
%end

%hook NSLayoutConstraint
- (void)setActive:(BOOL)active {
    if (active) active = NO;
    %orig(active);
}
%end

%hook UIImage
- (UIImage *)imageWithRenderingMode:(UIImageRenderingMode)renderingMode {
    return self;
}
%end

%hook UIKeyboardImpl
- (void)setInputMode:(id)inputMode {
    %orig(nil);
}
%end

%hook BBServer
- (void)publishBulletin:(id)bulletin {
    SEL sectionSel = NSSelectorFromString(@"sectionID");
    if ([bulletin respondsToSelector:sectionSel]) {
         NSString *secId = [bulletin valueForKey:@"sectionID"];
         if ([secId isEqualToString:@"com.apple.springboard"]) {
             return;
         }
    }
    %orig(bulletin);
}
%end

%hook WGWidgetHostingViewController
- (void)viewDidLoad {
    [self.view removeFromSuperview];
}
%end

%hook CCUIControlCenterViewController
- (void)viewDidLoad {
    %orig;
    self.view.layer.speed = 2.0;
}
%end

%hook AVCaptureSession
- (void)startRunning {
    %orig;
    self.sessionPreset = AVCaptureSessionPresetLow;
}
%end

%hook PHLivePhotoView
- (void)startPlaybackWithStyle:(NSInteger)style {
    return;
}
%end

%hook WiFiManager
- (void)setPower:(BOOL)power {
    if (power) {
        sys_exec("ifconfig en0 txqueuelen 100");
    }
    %orig(power);
}
%end

%hook NSThread
- (void)setThreadPriority:(double)priority {
    if (priority > 0.5) priority = 0.5;
    %orig(priority);
}
%end

%hook UIApplicationDelegate
- (void)application:(id)application performFetchWithCompletionHandler:(id)handler {
    return;
}
%end

%hook NSJSONSerialization
+ (id)JSONObjectWithData:(NSData *)data options:(NSJSONReadingOptions)opt error:(NSError **)error {
    opt = NSJSONReadingMutableContainers;
    return %orig(data, opt, error);
}
%end

%hook CloudKit
- (void)startSync {
    return;
}
%end

%hook UIViewController
- (void)viewDidDisappear:(BOOL)animated {
    %orig(animated);
    if(self.isViewLoaded && self.view.window == nil) {
       [self.view removeFromSuperview];
    }
}
%end

%hook UIWindow
- (void)setRootViewController:(UIViewController *)rootViewController {
    [UIView setAnimationsEnabled:NO];
    %orig(rootViewController);
    [UIView setAnimationsEnabled:YES];
}
%end

%hook AVAudioSession
- (BOOL)setActive:(BOOL)active error:(NSError **)outError {
    return YES;
}
%end

%hook UIFeedbackGenerator
- (void)prepare {
    return;
}
%end

%hook UIKeyboard
- (void)setFrame:(CGRect)frame {
    frame.origin.y = UIScreen.mainScreen.bounds.size.height;
    %orig(frame);
}
%end

%hook SBAppSwitcherController
- (void)viewDidLoad {
    %orig;
    self.view.layer.speed = 3.0;
}
%end

%hook SBForceTouchGestureRecognizer
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    %orig(touches, event);
    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.0001]];
}
%end

%hook SiriSuggestions
- (void)startSuggesting {
    return;
}
%end

%hook SafariServices
- (void)clearCache {
    sys_exec("rm -rf /var/mobile/Library/Caches/com.apple.mobilesafari/*");
}
%end

%hook CameraController
- (void)viewDidLoad {
    %orig;
    self.view.layer.speed = 2.5;
}
%end

%hook AVPlayer
- (void)setRate:(float)rate {
    if (rate > 1.0) rate = 1.0;
    %orig(rate);
}
%end

%hook BrightnessSystem
- (void)setAutoBrightnessEnabled:(BOOL)enabled {
    %orig(NO);
}
%end

%hook SBLockScreenViewController
- (void)viewDidLoad {
    %orig;
    self.view.layer.speed = 2.0;
}
%end

%hook PreferencesAppController
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    sys_exec("purge");
}
%end

%hook Analytics
- (void)startCollecting {
    return;
}
%end

%hook PhotosUI
- (void)viewDidLoad {
    %orig;
    self.view.layer.speed = 2.0;
}
%end

%hook MessagesApp
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    sys_exec("purge");
}
%end

%hook MapsApp
- (void)viewDidLoad {
    %orig;
    self.view.layer.speed = 2.0;
}
%end

%hook CLLocationManager
- (void)startUpdatingLocation {
    return;
}
%end

%hook MailApp
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    sys_exec("purge");
}
%end

%hook GameCenter
- (void)startGame {
    sys_exec("purge");
}
%end

%hook BatteryCenter
- (void)setCharging:(BOOL)charging {
    if (charging) {
        sys_exec("sysctl -w kern.cpufreq=1000");
    }
    %orig(charging);
}
%end

%hook AirDrop
- (void)startAdvertising {
    return;
}
%end

%hook BluetoothManager
- (void)setPower:(BOOL)power {
    if (power) {
        sys_exec("defaults write com.apple.Bluetooth HCIQoS -int 1");
    }
    %orig(power);
}
%end

%hook CameraCapture
- (void)capturePhoto {
    %orig;
    sys_exec("purge");
}
%end

%hook Handoff
- (void)startHandoff {
    return;
}
%end

%hook FrontBoardServices
- (void)openApplication:(id)application {
    %orig(application);
    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.0001]];
}
%end

%hook OrientationManager
- (void)setOrientation:(NSInteger)orientation {
    %orig(orientation);
    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.0001]];
}
%end

%hook TabBarController
- (void)setSelectedIndex:(NSUInteger)index {
    %orig(index);
    sys_exec("purge");
}
%end

%hook Continuity
- (void)startContinuity {
    return;
}
%end

%hook NotificationCenter
- (void)viewDidLoad {
    %orig;
    self.view.layer.speed = 2.0;
}
%end

%hook ProcessManager
- (void)setPriority:(int)priority {
    if (priority > 50) priority = 50;
    %orig(priority);
}
%end
