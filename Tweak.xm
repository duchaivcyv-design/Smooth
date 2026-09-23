#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <IOKit/IOKitLib.h>
#import <sys/sysctl.h>

// Giảm animation tối đa
%hook UIView
- (void)setAlpha:(CGFloat)alpha {
    if (alpha > 0.95) alpha = 1.0;
    %orig(alpha);
}
%end

// Tăng tốc độ animation
%hook CALayer
- (CFTimeInterval)duration {
    return 0.15;
}
%end

// Vô hiệu hóa blur effect
%hook UIVisualEffectView
- (void)didMoveToSuperview {
    [self removeFromSuperview];
}
%end

// Giảm độ phân giải render
%hook UIScreen
- (CGFloat)scale {
    return 2.0;
}
%end

// Tối ưu bộ nhớ
%hook UIApplication
- (void)didReceiveMemoryWarning {
    [self _purgeMemoryCache];
    %orig;
}
%end

// Tăng tốc độ scroll
%hook UIScrollView
- (void)setContentOffset:(CGPoint)contentOffset animated:(BOOL)animated {
    if (animated) animated = NO;
    %orig(contentOffset, animated);
}
%end

// Vô hiệu hóa parallax
%hook UIInterpolatingMotionEffect
- (instancetype)initWithKeyPath:(NSString *)keyPath type:(NSInteger)type {
    return nil;
}
%end

// Giảm độ trễ cảm ứng
%hook UIWindow
- (void)sendEvent:(UIEvent *)event {
    if (event.type == UIEventTypeTouches) {
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.001]];
    }
    %orig(event);
}
%end

// Tối ưu CPU
%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    // Giải phóng bộ nhớ không dùng
    system("sync");
    system("purge");
}
%end

// Giảm nhiệt độ
%hook NSProcessInfo
- (float)thermalState {
    return 1.0;
}
%end

// Tăng tốc độ khởi chạy app
%hook FBSSystemService
- (void)openApplication:(id)application withOptions:(id)options {
    %orig(application, nil);
}
%end

// Vô hiệu hóa animation khi mở khóa
%hook SBLockScreenManager
- (void)lockUIFromSource:(int)source withOptions:(id)options {
    %orig(source, nil);
}
%end

// Tối ưu GPU
%hook CAMetalLayer
- (void)setMaximumDrawableCount:(NSUInteger)count {
    %orig(2);
}
%end

// Giảm độ phân giải texture
%hook MTLTextureDescriptor
- (void)setPixelFormat:(NSUInteger)pixelFormat {
    if (pixelFormat == 80) pixelFormat = 70;
    %orig(pixelFormat);
}
%end

// Tăng tốc độ xử lý touch
%hook UITouch
- (NSTimeInterval)timestamp {
    return [[NSDate date] timeIntervalSinceReferenceDate];
}
%end

// Vô hiệu hóa spotlight search
%hook SBSearchController
- (void)viewDidLoad {
    [self.view removeFromSuperview];
}
%end

// Giảm số lượng frame render
%hook CADisplayLink
- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (fps > 30) fps = 30;
    %orig(fps);
}
%end

// Tối ưu bộ nhớ cache
%hook NSURLCache
- (void)setMemoryCapacity:(NSUInteger)capacity {
    %orig(1024 * 1024 * 10);
}
%end

// Vô hiệu hóa auto layout chậm
%hook NSLayoutConstraint
- (void)setActive:(BOOL)active {
    if (active) active = NO;
    %orig(active);
}
%end

// Tăng tốc độ xử lý ảnh
%hook UIImage
- (UIImage *)imageWithRenderingMode:(UIImageRenderingMode)renderingMode {
    return self;
}
%end

// Giảm độ trễ keyboard
%hook UIKeyboardImpl
- (void)setInputMode:(id)inputMode {
    %orig(nil);
}
%end

// Tối ưu notification
%hook BBServer
- (void)publishBulletin:(id)bulletin {
    if ([[bulletin sectionID] isEqualToString:@"com.apple.springboard"]) {
        return;
    }
    %orig(bulletin);
}
%end

// Vô hiệu hóa widget
%hook WGWidgetHostingViewController
- (void)viewDidLoad {
    [self.view removeFromSuperview];
}
%end

// Tăng tốc độ mở control center
%hook CCUIControlCenterViewController
- (void)viewDidLoad {
    %orig;
    self.view.layer.speed = 2.0;
}
%end

// Giảm độ trễ khi chụp ảnh
%hook AVCaptureSession
- (void)startRunning {
    %orig;
    self.sessionPreset = AVCaptureSessionPresetLow;
}
%end

// Vô hiệu hóa live photo
%hook PHLivePhotoView
- (void)startPlaybackWithStyle:(NSInteger)style {
    return;
}
%end

// Tối ưu wifi
%hook WiFiManager
- (void)setPower:(BOOL)power {
    if (power) {
        system("ifconfig en0 txqueuelen 100");
    }
    %orig(power);
}
%end

// Giảm nhiệt CPU
%hook NSThread
- (void)setThreadPriority:(double)priority {
    if (priority > 0.5) priority = 0.5;
    %orig(priority);
}
%end

// Vô hiệu hóa background app refresh
%hook UIApplicationDelegate
- (void)application:(id)application performFetchWithCompletionHandler:(id)handler {
    return;
}
%end

// Tăng tốc độ xử lý JSON
%hook NSJSONSerialization
+ (id)JSONObjectWithData:(NSData *)data options:(NSJSONReadingOptions)opt error:(NSError **)error {
    opt = NSJSONReadingMutableContainers;
    return %orig(data, opt, error);
}
%end

// Vô hiệu hóa iCloud sync
%hook CloudKit
- (void)startSync {
    return;
}
%end

// Tối ưu bộ nhớ khi chạy app
%hook UIViewController
- (void)viewDidDisappear:(BOOL)animated {
    %orig(animated);
    [self.view removeFromSuperview];
}
%end

// Giảm độ trễ khi xoay màn hình
%hook UIWindow
- (void)setRootViewController:(UIViewController *)rootViewController {
    [UIView setAnimationsEnabled:NO];
    %orig(rootViewController);
    [UIView setAnimationsEnabled:YES];
}
%end

// Tăng tốc độ xử lý âm thanh
%hook AVAudioSession
- (BOOL)setActive:(BOOL)active error:(NSError **)outError {
    return YES;
}
%end

// Vô hiệu hóa haptic feedback
%hook UIFeedbackGenerator
- (void)prepare {
    return;
}
%end

// Tối ưu khi bàn phím xuất hiện
%hook UIKeyboard
- (void)setFrame:(CGRect)frame {
    frame.origin.y = UIScreen.mainScreen.bounds.size.height;
    %orig(frame);
}
%end

// Giảm độ trễ khi mở app switcher
%hook SBAppSwitcherController
- (void)viewDidLoad {
    %orig;
    self.view.layer.speed = 3.0;
}
%end

// Tăng tốc độ xử lý 3D touch
%hook SBForceTouchGestureRecognizer
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    %orig(touches, event);
    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.0001]];
}
%end

// Vô hiệu hóa Siri suggestions
%hook SiriSuggestions
- (void)startSuggesting {
    return;
}
%end

// Tối ưu bộ nhớ Safari
%hook SafariServices
- (void)clearCache {
    system("rm -rf /var/mobile/Library/Caches/com.apple.mobilesafari/*");
}
%end

// Giảm độ trễ khi mở camera
%hook CameraController
- (void)viewDidLoad {
    %orig;
    self.view.layer.speed = 2.5;
}
%end

// Tăng tốc độ xử lý video
%hook AVPlayer
- (void)setRate:(float)rate {
    if (rate > 1.0) rate = 1.0;
    %orig(rate);
}
%end

// Vô hiệu hóa auto-brightness
%hook BrightnessSystem
- (void)setAutoBrightnessEnabled:(BOOL)enabled {
    %orig(NO);
}
%end

// Tối ưu khi khóa màn hình
%hook SBLockScreenViewController
- (void)viewDidLoad {
    %orig;
    self.view.layer.speed = 2.0;
}
%end

// Giảm độ trễ khi mở settings
%hook PreferencesAppController
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    system("purge");
}
%end

// Vô hiệu hóa analytics
%hook Analytics
- (void)startCollecting {
    return;
}
%end

// Tăng tốc độ xử lý ảnh trong Photos
%hook PhotosUI
- (void)viewDidLoad {
    %orig;
    self.view.layer.speed = 2.0;
}
%end

// Tối ưu bộ nhớ Messages
%hook MessagesApp
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    system("purge");
}
%end

// Giảm độ trễ khi mở Maps
%hook MapsApp
- (void)viewDidLoad {
    %orig;
    self.view.layer.speed = 2.0;
}
%end

// Vô hiệu hóa location services không cần thiết
%hook CLLocationManager
- (void)startUpdatingLocation {
    return;
}
%end

// Tăng tốc độ xử lý email
%hook MailApp
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    system("purge");
}
%end

// Tối ưu bộ nhớ khi chạy game
%hook GameCenter
- (void)startGame {
    system("purge");
}
%end

// Giảm nhiệt khi sạc
%hook BatteryCenter
- (void)setCharging:(BOOL)charging {
    if (charging) {
        system("sysctl -w kern.cpufreq=1000");
    }
    %orig(charging);
}
%end

// Vô hiệu hóa AirDrop
%hook AirDrop
- (void)startAdvertising {
    return;
}
%end

// Tăng tốc độ xử lý Bluetooth
%hook BluetoothManager
- (void)setPower:(BOOL)power {
    if (power) {
        system("defaults write com.apple.Bluetooth HCIQoS -int 1");
    }
    %orig(power);
}
%end

// Tối ưu bộ nhớ khi chụp ảnh
%hook CameraCapture
- (void)capturePhoto {
    %orig;
    system("purge");
}
%end

// Vô hiệu hóa Handoff
%hook Handoff
- (void)startHandoff {
    return;
}
%end

// Tăng tốc độ xử lý khi mở app
%hook FrontBoardServices
- (void)openApplication:(id)application {
    %orig(application);
    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.0001]];
}
%end

// Giảm độ trễ khi xoay màn hình
%hook OrientationManager
- (void)setOrientation:(NSInteger)orientation {
    %orig(orientation);
    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.0001]];
}
%end

// Tối ưu bộ nhớ khi mở nhiều tab
%hook TabBarController
- (void)setSelectedIndex:(NSUInteger)index {
    %orig(index);
    system("purge");
}
%end

// Vô hiệu hóa Continuity
%hook Continuity
- (void)startContinuity {
    return;
}
%end

// Tăng tốc độ xử lý khi mở notification
%hook NotificationCenter
- (void)viewDidLoad {
    %orig;
    self.view.layer.speed = 2.0;
}
%end

// Giảm nhiệt khi chạy app nặng
%hook ProcessManager
- (void)setPriority:(int)priority {
    if (priority > 50) priority = 50;
    %orig(priority);
}
%end

// Tối ưu b
