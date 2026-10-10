// ====================================================================================================
// Smooth - Performance Max v2.85 (Balanced tuning)
// Mục tiêu: mượt hơn, không lag, không nóng quá mức, giữ app mạng hoạt động ổn định.
// Tuning: đánh đổi pin cho độ mượt nhưng không phá hệ thống / WebKit / GPU.
// ====================================================================================================

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>
#import <Metal/Metal.h>
#import <mach/mach.h>
#import <mach/mach_time.h>
#import <pthread.h>
#import <pthread/qos.h>
#import <substrate.h>

#define TITANIUM_LITE_MODE 1
#define TITANIUM_FRAME_RATE_FLOOR 60.0f
#define TITANIUM_ENABLE_RATE_KEEPER 0
#define TITANIUM_ALLOW_FLUSH_QOS_DEMOTION 0
#define TITANIUM_ENABLE_TASK_QOS_TIER 0
#define TITANIUM_ENABLE_METAL_ENV_TWEAKS 0
#define TITANIUM_ENABLE_WEBKIT_HOOKS_IN_APPS 0
#define TITANIUM_ENABLE_METAL_CONTRACT_OVERRIDES 0
#define TITANIUM_ENABLE_WATCHDOG_IMMUNITY 0
#define TITANIUM_SPOOF_DISPLAY_ON_60HZ_PANEL 0

static volatile BOOL g_masterEnabled = YES;
static volatile BOOL g_isUserTouching = NO;
static volatile BOOL g_isScrolling = NO;
static volatile uint64_t g_lastInteractionTime = 0;
static volatile int32_t g_targetHz = 144;
static volatile int32_t g_targetFPS = 144;

static inline uint64_t Titanium_NanosToMachTicks(uint64_t nanos) {
    static mach_timebase_info_data_t tb;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        mach_timebase_info(&tb);
        if (tb.numer == 0) tb.numer = 1;
        if (tb.denom == 0) tb.denom = 1;
    });
    return (nanos * (uint64_t)tb.denom) / (uint64_t)tb.numer;
}

static inline void Titanium_TriggerBoost(void) {
    g_lastInteractionTime = mach_absolute_time();
    if (![NSThread isMainThread]) return;
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
}

static inline NSInteger Titanium_GetTargetHz(void) {
    NSInteger hz = g_targetHz;
    if (hz < 60) hz = 60;
    if (hz > 144) hz = 144;
    return hz;
}

static inline NSInteger Titanium_GetTargetFPS(void) {
    NSInteger fps = g_targetFPS;
    if (fps < 60) fps = 60;
    if (fps > 144) fps = 144;
    return fps;
}

static inline BOOL Titanium_ShouldBoostNow(void) {
    if (!g_masterEnabled) return NO;
    if (!g_isUserTouching && !g_isScrolling) return NO;
    if (g_lastInteractionTime == 0) return NO;

    uint64_t now = mach_absolute_time();
    uint64_t timeout = Titanium_NanosToMachTicks(350ULL * 1000000ULL);
    return ((now - g_lastInteractionTime) < timeout);
}

%hook UIWindow
- (void)sendEvent:(UIEvent *)event {
    if (g_masterEnabled && event && event.type == 0) {
        static uint64_t lastTick = 0;
        uint64_t now = mach_absolute_time();
        if ((now - lastTick) > Titanium_NanosToMachTicks(30ULL * 1000000ULL)) {
            lastTick = now;
            g_isUserTouching = YES;
            Titanium_TriggerBoost();
        }
    }
    %orig;
}
%end

%hook UIPanGestureRecognizer
- (void)setState:(UIGestureRecognizerState)state {
    %orig(state);
    if (!g_masterEnabled) return;

    if (state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged) {
        g_isUserTouching = YES;
        g_isScrolling = YES;
        Titanium_TriggerBoost();
    } else if (state == UIGestureRecognizerStateEnded || state == UIGestureRecognizerStateCancelled || state == UIGestureRecognizerStateFailed) {
        g_lastInteractionTime = mach_absolute_time();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(50 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            g_isUserTouching = NO;
            g_isScrolling = NO;
        });
    }
}
%end

%hook UIScrollView
- (BOOL)delaysContentTouches {
    if (g_masterEnabled) return NO;
    return %orig;
}

- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    if (g_masterEnabled) return YES;
    return %orig;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (g_masterEnabled) {
        g_isUserTouching = YES;
        Titanium_TriggerBoost();
    }
    %orig(touches, event);
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (g_masterEnabled) {
        g_isScrolling = YES;
        Titanium_TriggerBoost();
    }
    %orig(touches, event);
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig(touches, event);
    if (g_masterEnabled) {
        g_lastInteractionTime = mach_absolute_time();
        g_isUserTouching = NO;
    }
}
%end

%hook CADisplayLink
- (NSInteger)preferredFramesPerSecond {
    if (g_masterEnabled) return Titanium_GetTargetFPS();
    return %orig;
}

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (g_masterEnabled) {
        %orig(Titanium_GetTargetFPS());
        return;
    }
    %orig;
}

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    if (g_masterEnabled) {
        range.minimum = TITANIUM_FRAME_RATE_FLOOR;
        range.maximum = (float)Titanium_GetTargetFPS();
        range.preferred = (float)Titanium_GetTargetFPS();
    }
    %orig(range);
}
%end

%hook UIScreen
- (NSInteger)maximumFramesPerSecond {
    if (g_masterEnabled) return Titanium_GetTargetFPS();
    return %orig;
}

- (CGFloat)_refreshRate {
    if (g_masterEnabled) return (CGFloat)Titanium_GetTargetHz();
    return %orig;
}
%end

%hook CATransaction
+ (void)flush {
    %orig;
    // Không hạ QoS quá sớm để tránh lag / xám mạng / đơ luồng chính.
}
%end

%hook CALayer
- (void)setNeedsDisplay {
    // Không nuốt lệnh vẽ, tránh đen app và xám màn hình.
    %orig;
}
%end

%hook UIKeyboardImpl
+ (NSTimeInterval)suppressionIntervalForTouchesOnKeyboard {
    if (g_masterEnabled) return 0.0;
    return %orig;
}

- (void)showKeyboard {
    if (g_masterEnabled) Titanium_TriggerBoost();
    %orig;
}
%end

%hook UIDevice
- (BOOL)isLowPowerModeEnabled {
    return NO;
}
%end

%hook NSProcessInfo
- (NSProcessInfoThermalState)thermalState {
    NSProcessInfoThermalState s = %orig;
    if (g_masterEnabled) {
        if (s >= NSProcessInfoThermalStateSerious) return s;
        return NSProcessInfoThermalStateNominal;
    }
    return s;
}
%end

%hook CAMetalLayer
- (void)setMaximumDrawableCount:(NSUInteger)count {
    if (g_masterEnabled) {
        if (self.superlayer && self.bounds.size.width > 0) {
            %orig(3);
            return;
        }
    }
    %orig;
}
%end

%hook SBAppLaunchSettings
- (double)delayBeforeAppLaunch {
    if (g_masterEnabled) return 0.0;
    return %orig;
}

- (double)zoomDuration {
    if (g_masterEnabled) return 0.08;
    return %orig;
}

- (double)launchDuration {
    if (g_masterEnabled) return 0.08;
    return %orig;
}
%end

%hook UIApplication
- (void)_applicationWillEnterForeground {
    %orig;
    if (g_masterEnabled) Titanium_TriggerBoost();
}
%end

%ctor {
    // Cấu hình tối ưu cho trải nghiệm mượt, không phá app mạng
    g_masterEnabled = YES;
    g_targetHz = 144;
    g_targetFPS = 144;
}
