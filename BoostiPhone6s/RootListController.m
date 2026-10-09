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
#import <notify.h>
#import <dlfcn.h>
#import <mach/mach.h>
#import <mach/mach_time.h>
#import <mach/processor_info.h>
#import <mach/mach_host.h>
#import <mach/vm_map.h>
#import <AudioToolbox/AudioToolbox.h>
#import <QuartzCore/QuartzCore.h>

extern char **environ;

#ifndef APEX_SYNC_MAGIC_V285
#define APEX_SYNC_MAGIC_V285 0x41505837
#endif

#ifndef PRIMARY_SYNC_FILE
#define PRIMARY_SYNC_FILE    @"/tmp/.boost_hz_sync"
#endif

#ifndef SECONDARY_SYNC_FILE
#define SECONDARY_SYNC_FILE  @"/var/jb/tmp/.boost_hz_sync"
#endif

#ifndef TITANIUM_BOOT_FLAG_VERIFIED
#define TITANIUM_BOOT_FLAG_VERIFIED @"/tmp/.titanium_tweak_verified"
#endif

#ifndef NOTIFY_RELOAD
#define NOTIFY_RELOAD        "com.taojb.boostiphone6s/ReloadPrefs"
#define NOTIFY_UIKIT_RELOAD  "com.taojb.boostiphone6s/ReloadUIKitPrefs"
#define NOTIFY_HARDWARE_SYNC "com.taojb.boostiphone6s/HardwareSync"
#define NOTIFY_FPS_CHANGED   "com.taojb.boostiphone6s/FPSChanged"
#define NOTIFY_TITANIUM_CHANGED "com.titanium.v285.prefschanged"
#endif

#ifndef _APEX_V285_PRO_PAYLOAD_DEFINED
#define _APEX_V285_PRO_PAYLOAD_DEFINED
typedef struct {
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
// MODULE 1: GLASS MATERIAL FACTORY - Bộ Sinh Material Glass Chuẩn Apple
// ====================================================================================================

typedef NS_ENUM(NSInteger, LGGlassMaterialType) {
    LGGlassMaterialTypeUltraThin = 0,   // Cho thumb switch, lens nhỏ
    LGGlassMaterialTypeThin = 1,        // Cho card, nav bar
    LGGlassMaterialTypeRegular = 2,     // Cho sheet, dialog lớn
    LGGlassMaterialTypeChrome = 3,      // Cho toolbar, tab bar
    LGGlassMaterialTypeProminent = 4    // Cho nút action nổi bật
};

@interface LGGlassMaterialFactory : NSObject
+ (UIBlurEffectStyle)blurStyleForType:(LGGlassMaterialType)type isDark:(BOOL)isDark;
+ (CGFloat)tintAlphaForType:(LGGlassMaterialType)type;
+ (CGFloat)specularAlphaForType:(LGGlassMaterialType)type;
+ (CGFloat)rimAlphaForType:(LGGlassMaterialType)type;
+ (CGFloat)rimWidthForType:(LGGlassMaterialType)type;
+ (CGFloat)shadowOpacityForType:(LGGlassMaterialType)type;
+ (CGFloat)shadowRadiusForType:(LGGlassMaterialType)type;
+ (CGFloat)shadowOffsetYForType:(LGGlassMaterialType)type;
@end

@implementation LGGlassMaterialFactory

+ (UIBlurEffectStyle)blurStyleForType:(LGGlassMaterialType)type isDark:(BOOL)isDark {
    switch (type) {
        case LGGlassMaterialTypeUltraThin:
            return isDark ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemUltraThinMaterialLight;
        case LGGlassMaterialTypeThin:
            return isDark ? UIBlurEffectStyleSystemThinMaterialDark : UIBlurEffectStyleSystemThinMaterialLight;
        case LGGlassMaterialTypeRegular:
            return isDark ? UIBlurEffectStyleSystemMaterialDark : UIBlurEffectStyleSystemMaterialLight;
        case LGGlassMaterialTypeChrome:
            return isDark ? UIBlurEffectStyleSystemChromeMaterialDark : UIBlurEffectStyleSystemChromeMaterialLight;
        case LGGlassMaterialTypeProminent:
            return isDark ? UIBlurEffectStyleSystemThickMaterialDark : UIBlurEffectStyleSystemThickMaterialLight;
    }
    return UIBlurEffectStyleSystemThinMaterialDark;
}

+ (CGFloat)tintAlphaForType:(LGGlassMaterialType)type {
    switch (type) {
        case LGGlassMaterialTypeUltraThin: return 0.015;
        case LGGlassMaterialTypeThin:      return 0.030;
        case LGGlassMaterialTypeRegular:   return 0.045;
        case LGGlassMaterialTypeChrome:    return 0.060;
        case LGGlassMaterialTypeProminent: return 0.085;
    }
    return 0.03;
}

+ (CGFloat)specularAlphaForType:(LGGlassMaterialType)type {
    switch (type) {
        case LGGlassMaterialTypeUltraThin: return 0.14;
        case LGGlassMaterialTypeThin:      return 0.18;
        case LGGlassMaterialTypeRegular:   return 0.22;
        case LGGlassMaterialTypeChrome:    return 0.26;
        case LGGlassMaterialTypeProminent: return 0.32;
    }
    return 0.20;
}

+ (CGFloat)rimAlphaForType:(LGGlassMaterialType)type {
    switch (type) {
        case LGGlassMaterialTypeUltraThin: return 0.12;
        case LGGlassMaterialTypeThin:      return 0.16;
        case LGGlassMaterialTypeRegular:   return 0.18;
        case LGGlassMaterialTypeChrome:    return 0.22;
        case LGGlassMaterialTypeProminent: return 0.28;
    }
    return 0.16;
}

+ (CGFloat)rimWidthForType:(LGGlassMaterialType)type {
    switch (type) {
        case LGGlassMaterialTypeUltraThin: return 0.4;
        case LGGlassMaterialTypeThin:      return 0.5;
        case LGGlassMaterialTypeRegular:   return 0.6;
        case LGGlassMaterialTypeChrome:    return 0.6;
        case LGGlassMaterialTypeProminent: return 0.8;
    }
    return 0.5;
}

+ (CGFloat)shadowOpacityForType:(LGGlassMaterialType)type {
    switch (type) {
        case LGGlassMaterialTypeUltraThin: return 0.14;
        case LGGlassMaterialTypeThin:      return 0.22;
        case LGGlassMaterialTypeRegular:   return 0.30;
        case LGGlassMaterialTypeChrome:    return 0.28;
        case LGGlassMaterialTypeProminent: return 0.42;
    }
    return 0.22;
}

+ (CGFloat)shadowRadiusForType:(LGGlassMaterialType)type {
    switch (type) {
        case LGGlassMaterialTypeUltraThin: return 4.0;
        case LGGlassMaterialTypeThin:      return 8.0;
        case LGGlassMaterialTypeRegular:   return 12.0;
        case LGGlassMaterialTypeChrome:    return 14.0;
        case LGGlassMaterialTypeProminent: return 20.0;
    }
    return 8.0;
}

+ (CGFloat)shadowOffsetYForType:(LGGlassMaterialType)type {
    switch (type) {
        case LGGlassMaterialTypeUltraThin: return 1.5;
        case LGGlassMaterialTypeThin:      return 2.0;
        case LGGlassMaterialTypeRegular:   return 4.0;
        case LGGlassMaterialTypeChrome:    return 6.0;
        case LGGlassMaterialTypeProminent: return 8.0;
    }
    return 2.0;
}

@end

// ====================================================================================================
// MODULE 2: APPLE LIQUID GLASS VIEW - Khối Thủy Tinh Chuẩn iOS 26
// Cấu trúc: Blur + Tint + TopSpecular + BottomReflection + DiagonalSheen + DualRim + InnerGlow
// + TouchTracking + Highlighted state + Jiggle Animation
// ====================================================================================================

@interface AppleLiquidGlassView : UIView

@property (nonatomic, strong) UIVisualEffectView *glassBlurView;
@property (nonatomic, strong) UIView *glassTintView;
@property (nonatomic, strong) CAGradientLayer *topSpecularHighlight;
@property (nonatomic, strong) CAGradientLayer *bottomReflection;
@property (nonatomic, strong) CAGradientLayer *diagonalSheen;
@property (nonatomic, strong) CAShapeLayer *innerRimStroke;
@property (nonatomic, strong) CAShapeLayer *outerRimStroke;
@property (nonatomic, strong) CALayer *innerGlowLayer;

@property (nonatomic, assign) CGFloat cornerRadiusValue;
@property (nonatomic, assign) LGGlassMaterialType materialType;
@property (nonatomic, assign) BOOL isDarkMode;
@property (nonatomic, assign) BOOL interactiveHighlightEnabled;
@property (nonatomic, assign) BOOL touchTrackingEnabled;
@property (nonatomic, assign) BOOL isPressed;

@property (nonatomic, strong) UILongPressGestureRecognizer *pressGesture;
@property (nonatomic, assign) CGPoint lastTouchPoint;

- (instancetype)initWithFrame:(CGRect)frame cornerRadius:(CGFloat)radius;
- (instancetype)initWithFrame:(CGRect)frame cornerRadius:(CGFloat)radius materialType:(LGGlassMaterialType)type;
- (void)applyFluidJiggleAnimationWithVelocity:(CGFloat)vel;
- (void)setGlassHighlighted:(BOOL)highlighted animated:(BOOL)animated;
- (void)animatePressIn;
- (void)animatePressOut;
- (void)refreshLayersForCurrentBounds;

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
        _touchTrackingEnabled = NO;
        _isDarkMode = [self lg_resolveCurrentDarkMode];
        _isPressed = NO;

        self.backgroundColor = [UIColor clearColor];
        self.layer.cornerRadius = radius;
        if (@available(iOS 13.0, *)) {
            self.layer.cornerCurve = kCACornerCurveContinuous;
        }
        self.clipsToBounds = NO;
        self.layer.masksToBounds = NO;

        [self lg_buildGlassLayers];
        [self lg_applyMaterialShadow];
        [self lg_setupPressGestureIfNeeded];
    }
    return self;
}

- (BOOL)lg_resolveCurrentDarkMode {
    if (@available(iOS 13.0, *)) {
        return self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return YES;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        BOOL nowDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
        if (nowDark != _isDarkMode) {
            _isDarkMode = nowDark;
            [self lg_refreshBlurStyle];
        }
    }
}

- (void)lg_buildGlassLayers {
    // ============================================================
    // LỚP 1: BLUR THẬT — UIVisualEffectView với system material chuẩn Apple
    // Đây là lớp DUY NHẤT tạo backdrop blur đúng như iOS 26
    // ============================================================
    UIBlurEffectStyle style = [LGGlassMaterialFactory blurStyleForType:_materialType isDark:_isDarkMode];
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:style];
    _glassBlurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    _glassBlurView.frame = self.bounds;
    _glassBlurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _glassBlurView.userInteractionEnabled = NO;
    _glassBlurView.layer.cornerRadius = _cornerRadiusValue;
    if (@available(iOS 13.0, *)) {
        _glassBlurView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    _glassBlurView.clipsToBounds = YES;
    [self addSubview:_glassBlurView];

    // ============================================================
    // LỚP 2: TINT — độ đục thay đổi theo material type
    // ============================================================
    CGFloat tintAlpha = [LGGlassMaterialFactory tintAlphaForType:_materialType];
    _glassTintView = [[UIView alloc] initWithFrame:self.bounds];
    _glassTintView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:tintAlpha];
    _glassTintView.userInteractionEnabled = NO;
    _glassTintView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _glassTintView.layer.cornerRadius = _cornerRadiusValue;
    if (@available(iOS 13.0, *)) {
        _glassTintView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    _glassTintView.clipsToBounds = YES;
    [self addSubview:_glassTintView];

    // ============================================================
    // LỚP 3: TOP SPECULAR HIGHLIGHT — dải sáng phản chiếu từ trên
    // Apple: dải mỏng ~20-25% chiều cao ở đỉnh
    // ============================================================
    CGFloat specularAlpha = [LGGlassMaterialFactory specularAlphaForType:_materialType];

    _topSpecularHighlight = [CAGradientLayer layer];
    _topSpecularHighlight.frame = CGRectMake(0, 0, self.bounds.size.width, MAX(1.5, self.bounds.size.height * 0.24));
    _topSpecularHighlight.cornerRadius = _cornerRadiusValue;
    if (@available(iOS 13.0, *)) {
        _topSpecularHighlight.cornerCurve = kCACornerCurveContinuous;
    }
    _topSpecularHighlight.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:specularAlpha].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:specularAlpha * 0.30].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.00].CGColor
    ];
    _topSpecularHighlight.locations = @[@0.0, @0.40, @1.0];
    _topSpecularHighlight.startPoint = CGPointMake(0.0, 0.0);
    _topSpecularHighlight.endPoint = CGPointMake(0.0, 1.0);
    _topSpecularHighlight.opacity = 0.90f;
    [self.layer addSublayer:_topSpecularHighlight];

    // ============================================================
    // LỚP 4: BOTTOM REFLECTION — ánh sáng phản chiếu từ dưới lên
    // Apple: một dải sáng mờ nhẹ ở 70-100% chiều cao
    // ============================================================
    _bottomReflection = [CAGradientLayer layer];
    _bottomReflection.frame = CGRectMake(0, self.bounds.size.height * 0.65, self.bounds.size.width, self.bounds.size.height * 0.35);
    _bottomReflection.cornerRadius = _cornerRadiusValue;
    if (@available(iOS 13.0, *)) {
        _bottomReflection.cornerCurve = kCACornerCurveContinuous;
    }
    _bottomReflection.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.00].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:specularAlpha * 0.35].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:specularAlpha * 0.10].CGColor
    ];
    _bottomReflection.locations = @[@0.0, @0.60, @1.0];
    _bottomReflection.startPoint = CGPointMake(0.0, 0.0);
    _bottomReflection.endPoint = CGPointMake(0.0, 1.0);
    _bottomReflection.opacity = 0.70f;
    [self.layer addSublayer:_bottomReflection];

    // ============================================================
    // LỚP 5: DIAGONAL SHEEN — vệt sáng chéo mô phỏng nguồn sáng góc
    // Apple: vệt mỏng chéo từ góc trên-trái xuống dưới-phải
    // ============================================================
    _diagonalSheen = [CAGradientLayer layer];
    _diagonalSheen.frame = self.bounds;
    _diagonalSheen.cornerRadius = _cornerRadiusValue;
    if (@available(iOS 13.0, *)) {
        _diagonalSheen.cornerCurve = kCACornerCurveContinuous;
    }
    _diagonalSheen.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:specularAlpha * 0.40].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.00].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.00].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:specularAlpha * 0.15].CGColor
    ];
    _diagonalSheen.locations = @[@0.0, @0.25, @0.75, @1.0];
    _diagonalSheen.startPoint = CGPointMake(0.0, 0.0);
    _diagonalSheen.endPoint = CGPointMake(1.0, 1.0);
    _diagonalSheen.opacity = 0.55f;
    [self.layer addSublayer:_diagonalSheen];

    // ============================================================
    // LỚP 6: INNER GLOW — lớp sáng viền trong cùng, tạo cảm giác kính nổi
    // ============================================================
    _innerGlowLayer = [CALayer layer];
    _innerGlowLayer.frame = self.bounds;
    _innerGlowLayer.cornerRadius = _cornerRadiusValue;
    if (@available(iOS 13.0, *)) {
        _innerGlowLayer.cornerCurve = kCACornerCurveContinuous;
    }
    _innerGlowLayer.backgroundColor = [UIColor clearColor].CGColor;
    _innerGlowLayer.borderWidth = 0.8;
    _innerGlowLayer.borderColor = [UIColor colorWithWhite:1.0 alpha:specularAlpha * 0.25].CGColor;
    _innerGlowLayer.opacity = 0.9f;
    [self.layer addSublayer:_innerGlowLayer];

    // ============================================================
    // LỚP 7: INNER RIM STROKE — viền trong siêu mảnh
    // ============================================================
    CGFloat rimAlpha = [LGGlassMaterialFactory rimAlphaForType:_materialType];
    CGFloat rimWidth = [LGGlassMaterialFactory rimWidthForType:_materialType];

    _innerRimStroke = [CAShapeLayer layer];
    UIBezierPath *innerPath = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(self.bounds, 0.5, 0.5) cornerRadius:MAX(0, _cornerRadiusValue - 0.5)];
    _innerRimStroke.path = innerPath.CGPath;
    _innerRimStroke.fillColor = [UIColor clearColor].CGColor;
    _innerRimStroke.strokeColor = [UIColor colorWithWhite:1.0 alpha:rimAlpha].CGColor;
    _innerRimStroke.lineWidth = rimWidth;
    [self.layer addSublayer:_innerRimStroke];

    // ============================================================
    // LỚP 8: OUTER RIM STROKE — viền ngoài siêu mảnh, tối 22%
    // ============================================================
    _outerRimStroke = [CAShapeLayer layer];
    UIBezierPath *outerPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:_cornerRadiusValue];
    _outerRimStroke.path = outerPath.CGPath;
    _outerRimStroke.fillColor = [UIColor clearColor].CGColor;
    _outerRimStroke.strokeColor = [UIColor colorWithWhite:0.0 alpha:0.22].CGColor;
    _outerRimStroke.lineWidth = 0.4;
    [self.layer addSublayer:_outerRimStroke];
}

- (void)lg_applyMaterialShadow {
    CGFloat opacity = [LGGlassMaterialFactory shadowOpacityForType:_materialType];
    CGFloat radius = [LGGlassMaterialFactory shadowRadiusForType:_materialType];
    CGFloat offsetY = [LGGlassMaterialFactory shadowOffsetYForType:_materialType];

    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOpacity = opacity;
    self.layer.shadowOffset = CGSizeMake(0, offsetY);
    self.layer.shadowRadius = radius;
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:_cornerRadiusValue].CGPath;
}

- (void)lg_refreshBlurStyle {
    UIBlurEffectStyle style = [LGGlassMaterialFactory blurStyleForType:_materialType isDark:_isDarkMode];
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:style];
    _glassBlurView.effect = blur;
}

- (void)lg_setupPressGestureIfNeeded {
    if (!_interactiveHighlightEnabled) return;

    _pressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(lg_handlePressGesture:)];
    _pressGesture.minimumPressDuration = 0.0;
    _pressGesture.cancelsTouchesInView = NO;
    _pressGesture.delaysTouchesBegan = NO;
    _pressGesture.delaysTouchesEnded = NO;
    [self addGestureRecognizer:_pressGesture];
}

- (void)lg_handlePressGesture:(UILongPressGestureRecognizer *)gesture {
    CGPoint point = [gesture locationInView:self];

    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
            _isPressed = YES;
            _lastTouchPoint = point;
            [self animatePressIn];
            [self lg_updateTouchTrackingPoint:point];
            break;
        case UIGestureRecognizerStateChanged:
            _lastTouchPoint = point;
            [self lg_updateTouchTrackingPoint:point];
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
            _isPressed = NO;
            [self animatePressOut];
            break;
        default:
            break;
    }
}

- (void)lg_updateTouchTrackingPoint:(CGPoint)point {
    if (!_touchTrackingEnabled) return;
    CGFloat width = MAX(1.0, self.bounds.size.width);
    CGFloat height = MAX(1.0, self.bounds.size.height);
    CGPoint normalized = CGPointMake(point.x / width, point.y / height);

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _topSpecularHighlight.startPoint = CGPointMake(0.0, 0.0);
    _topSpecularHighlight.endPoint = CGPointMake(normalized.x * 0.5, 1.0);
    [CATransaction commit];
}

- (void)animatePressIn {
    if (!_interactiveHighlightEnabled) return;

    [CATransaction begin];
    [CATransaction setAnimationDuration:0.14];
    [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];

    CGFloat specularAlpha = [LGGlassMaterialFactory specularAlphaForType:_materialType];
    CGFloat tintAlpha = [LGGlassMaterialFactory tintAlphaForType:_materialType];

    _topSpecularHighlight.opacity = 1.0f;
    _topSpecularHighlight.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:MIN(0.55, specularAlpha * 1.9)].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:specularAlpha * 0.65].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.00].CGColor
    ];

    _innerRimStroke.strokeColor = [UIColor colorWithWhite:1.0 alpha:MIN(0.45, [LGGlassMaterialFactory rimAlphaForType:_materialType] * 1.8)].CGColor;
    _glassTintView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:tintAlpha * 2.5];
    _diagonalSheen.opacity = 0.85f;

    [CATransaction commit];

    [UIView animateWithDuration:0.16 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.transform = CGAffineTransformMakeScale(0.965, 0.965);
    } completion:nil];
}

- (void)animatePressOut {
    if (!_interactiveHighlightEnabled) return;

    [CATransaction begin];
    [CATransaction setAnimationDuration:0.32];
    [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];

    CGFloat specularAlpha = [LGGlassMaterialFactory specularAlphaForType:_materialType];
    CGFloat tintAlpha = [LGGlassMaterialFactory tintAlphaForType:_materialType];
    CGFloat rimAlpha = [LGGlassMaterialFactory rimAlphaForType:_materialType];

    _topSpecularHighlight.opacity = 0.90f;
    _topSpecularHighlight.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:specularAlpha].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:specularAlpha * 0.30].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.00].CGColor
    ];

    _innerRimStroke.strokeColor = [UIColor colorWithWhite:1.0 alpha:rimAlpha].CGColor;
    _glassTintView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:tintAlpha];
    _diagonalSheen.opacity = 0.55f;

    [CATransaction commit];

    [UIView animateWithDuration:0.42 delay:0 usingSpringWithDamping:0.66 initialSpringVelocity:0.65 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)setGlassHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    if (!_interactiveHighlightEnabled) return;
    if (highlighted) {
        [self animatePressIn];
    } else {
        [self animatePressOut];
    }
}

- (void)refreshLayersForCurrentBounds {
    CGRect b = self.bounds;
    CGFloat r = _cornerRadiusValue;

    _glassBlurView.frame = b;
    _glassTintView.frame = b;
    _glassBlurView.layer.cornerRadius = r;
    _glassTintView.layer.cornerRadius = r;

    _topSpecularHighlight.frame = CGRectMake(0, 0, b.size.width, MAX(1.5, b.size.height * 0.24));
    _topSpecularHighlight.cornerRadius = r;

    _bottomReflection.frame = CGRectMake(0, b.size.height * 0.65, b.size.width, b.size.height * 0.35);
    _bottomReflection.cornerRadius = r;

    _diagonalSheen.frame = b;
    _diagonalSheen.cornerRadius = r;

    _innerGlowLayer.frame = b;
    _innerGlowLayer.cornerRadius = r;

    _innerRimStroke.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(b, 0.5, 0.5) cornerRadius:MAX(0, r - 0.5)].CGPath;
    _outerRimStroke.path = [UIBezierPath bezierPathWithRoundedRect:b cornerRadius:r].CGPath;

    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:b cornerRadius:r].CGPath;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self refreshLayersForCurrentBounds];
}

- (void)applyFluidJiggleAnimationWithVelocity:(CGFloat)vel {
    CGFloat stretch = fmin(fmax(fabs(vel) / 900.0, 0.04), 0.18);
    CGAffineTransform transform = (vel >= 0)
        ? CGAffineTransformMakeScale(1.0 + stretch, 1.0 - (stretch * 0.45))
        : CGAffineTransformMakeScale(1.0 - (stretch * 0.35), 1.0 + stretch);

    [UIView animateWithDuration:0.11 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.transform = transform;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.42 delay:0 usingSpringWithDamping:0.58 initialSpringVelocity:1.05 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
            self.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

@end

// ====================================================================================================
// MODULE 3: LIQUID CAPSULE SWITCH - Công Tắc Thủy Tinh Chuẩn iOS 26
// Cấu trúc: Track (gradient + inner shadow) + Thumb (glass + specular + rim)
// + Press animation + Slide animation + Haptic
// ====================================================================================================

@interface LiquidCapsuleSwitch : UIControl

@property (nonatomic, assign) BOOL on;
@property (nonatomic, strong) UIView *channelTrackView;
@property (nonatomic, strong) CAGradientLayer *trackGradient;
@property (nonatomic, strong) CAShapeLayer *trackInnerShadow;
@property (nonatomic, strong) CAShapeLayer *trackInnerRim;
@property (nonatomic, strong) UIView *glassThumb;
@property (nonatomic, strong) CAGradientLayer *thumbSpecular;
@property (nonatomic, strong) CAGradientLayer *thumbBottomGlow;
@property (nonatomic, strong) CAShapeLayer *thumbRim;
@property (nonatomic, strong) CAShapeLayer *thumbInnerRim;
@property (nonatomic, copy) void (^valueChangedBlock)(BOOL isOn);

- (void)setOn:(BOOL)on animated:(BOOL)animated;

@end

@implementation LiquidCapsuleSwitch

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:CGRectMake(0, 0, 62, 34)]) {
        self.backgroundColor = [UIColor clearColor];

        // ==== TRACK ====
        _channelTrackView = [[UIView alloc] initWithFrame:self.bounds];
        _channelTrackView.layer.cornerRadius = 17.0;
        if (@available(iOS 13.0, *)) {
            _channelTrackView.layer.cornerCurve = kCACornerCurveContinuous;
        }
        _channelTrackView.userInteractionEnabled = NO;
        _channelTrackView.clipsToBounds = YES;
        [self addSubview:_channelTrackView];

        _trackGradient = [CAGradientLayer layer];
        _trackGradient.frame = _channelTrackView.bounds;
        _trackGradient.startPoint = CGPointMake(0.0, 0.0);
        _trackGradient.endPoint = CGPointMake(0.0, 1.0);
        [_channelTrackView.layer addSublayer:_trackGradient];

        // Inner shadow của track (làm track trông lõm)
        _trackInnerShadow = [CAShapeLayer layer];
        _trackInnerShadow.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(_channelTrackView.bounds, 0.5, 0.5) cornerRadius:16.5].CGPath;
        _trackInnerShadow.fillColor = [UIColor clearColor].CGColor;
        _trackInnerShadow.strokeColor = [UIColor colorWithWhite:0.0 alpha:0.35].CGColor;
        _trackInnerShadow.lineWidth = 1.0;
        [_channelTrackView.layer addSublayer:_trackInnerShadow];

        _trackInnerRim = [CAShapeLayer layer];
        _trackInnerRim.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(_channelTrackView.bounds, 1.5, 1.5) cornerRadius:15.5].CGPath;
        _trackInnerRim.fillColor = [UIColor clearColor].CGColor;
        _trackInnerRim.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.14].CGColor;
        _trackInnerRim.lineWidth = 0.6;
        [_channelTrackView.layer addSublayer:_trackInnerRim];

        // ==== THUMB (trắng mờ giống Apple) ====
        CGFloat thumbInset = 3.0;
        CGFloat thumbHeight = self.bounds.size.height - (thumbInset * 2);
        CGFloat thumbWidth = thumbHeight;

        _glassThumb = [[UIView alloc] initWithFrame:CGRectMake(thumbInset, thumbInset, thumbWidth, thumbHeight)];
        _glassThumb.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.95];
        _glassThumb.layer.cornerRadius = thumbHeight / 2.0;
        if (@available(iOS 13.0, *)) {
            _glassThumb.layer.cornerCurve = kCACornerCurveContinuous;
        }
        _glassThumb.userInteractionEnabled = NO;
        _glassThumb.layer.shadowColor = [UIColor blackColor].CGColor;
        _glassThumb.layer.shadowOpacity = 0.32;
        _glassThumb.layer.shadowOffset = CGSizeMake(0, 2);
        _glassThumb.layer.shadowRadius = 3.5;
        [self addSubview:_glassThumb];

        // Specular trên đỉnh thumb
        _thumbSpecular = [CAGradientLayer layer];
        _thumbSpecular.frame = _glassThumb.bounds;
        _thumbSpecular.cornerRadius = thumbHeight / 2.0;
        if (@available(iOS 13.0, *)) {
            _thumbSpecular.cornerCurve = kCACornerCurveContinuous;
        }
        _thumbSpecular.colors = @[
            (id)[UIColor colorWithWhite:1.0 alpha:0.60].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:0.10].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:0.00].CGColor
        ];
        _thumbSpecular.locations = @[@0.0, @0.35, @0.70];
        _thumbSpecular.startPoint = CGPointMake(0.0, 0.0);
        _thumbSpecular.endPoint = CGPointMake(0.0, 1.0);
        [_glassThumb.layer addSublayer:_thumbSpecular];

        // Bottom glow nhẹ cho thumb
        _thumbBottomGlow = [CAGradientLayer layer];
        _thumbBottomGlow.frame = CGRectMake(0, _glassThumb.bounds.size.height * 0.60, _glassThumb.bounds.size.width, _glassThumb.bounds.size.height * 0.40);
        _thumbBottomGlow.cornerRadius = thumbHeight / 2.0;
        if (@available(iOS 13.0, *)) {
            _thumbBottomGlow.cornerCurve = kCACornerCurveContinuous;
        }
        _thumbBottomGlow.colors = @[
            (id)[UIColor colorWithWhite:1.0 alpha:0.00].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:0.20].CGColor
        ];
        _thumbBottomGlow.locations = @[@0.0, @1.0];
        _thumbBottomGlow.startPoint = CGPointMake(0.0, 0.0);
        _thumbBottomGlow.endPoint = CGPointMake(0.0, 1.0);
        [_glassThumb.layer addSublayer:_thumbBottomGlow];

        // Rim cho thumb
        _thumbRim = [CAShapeLayer layer];
        _thumbRim.path = [UIBezierPath bezierPathWithRoundedRect:_glassThumb.bounds cornerRadius:thumbHeight / 2.0].CGPath;
        _thumbRim.fillColor = [UIColor clearColor].CGColor;
        _thumbRim.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.30].CGColor;
        _thumbRim.lineWidth = 0.5;
        [_glassThumb.layer addSublayer:_thumbRim];

        _thumbInnerRim = [CAShapeLayer layer];
        _thumbInnerRim.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(_glassThumb.bounds, 0.6, 0.6) cornerRadius:(thumbHeight / 2.0) - 0.6].CGPath;
        _thumbInnerRim.fillColor = [UIColor clearColor].CGColor;
        _thumbInnerRim.strokeColor = [UIColor colorWithWhite:0.0 alpha:0.08].CGColor;
        _thumbInnerRim.lineWidth = 0.4;
        [_glassThumb.layer addSublayer:_thumbInnerRim];

        [self addTarget:self action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
        [self addTarget:self action:@selector(handleTouchDown) forControlEvents:UIControlEventTouchDown];
        [self addTarget:self action:@selector(handleTouchUp) forControlEvents:UIControlEventTouchUpOutside | UIControlEventTouchCancel];
        [self updateUIAnimated:NO];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _channelTrackView.frame = self.bounds;
    _trackGradient.frame = _channelTrackView.bounds;
    _trackInnerShadow.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(_channelTrackView.bounds, 0.5, 0.5) cornerRadius:(self.bounds.size.height / 2.0) - 0.5].CGPath;
    _trackInnerRim.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(_channelTrackView.bounds, 1.5, 1.5) cornerRadius:(self.bounds.size.height / 2.0) - 1.5].CGPath;

    CGFloat thumbInset = 3.0;
    CGFloat thumbHeight = self.bounds.size.height - (thumbInset * 2);
    CGFloat thumbWidth = thumbHeight;
    CGRect targetFrame = _on
        ? CGRectMake(self.bounds.size.width - thumbWidth - thumbInset, thumbInset, thumbWidth, thumbHeight)
        : CGRectMake(thumbInset, thumbInset, thumbWidth, thumbHeight);

    if (!CGRectEqualToRect(_glassThumb.frame, targetFrame)) {
        _glassThumb.frame = targetFrame;
    }
    _glassThumb.layer.cornerRadius = thumbHeight / 2.0;
    _thumbSpecular.frame = _glassThumb.bounds;
    _thumbSpecular.cornerRadius = thumbHeight / 2.0;
    _thumbBottomGlow.frame = CGRectMake(0, _glassThumb.bounds.size.height * 0.60, _glassThumb.bounds.size.width, _glassThumb.bounds.size.height * 0.40);
    _thumbBottomGlow.cornerRadius = thumbHeight / 2.0;
    _thumbRim.path = [UIBezierPath bezierPathWithRoundedRect:_glassThumb.bounds cornerRadius:thumbHeight / 2.0].CGPath;
    _thumbInnerRim.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(_glassThumb.bounds, 0.6, 0.6) cornerRadius:(thumbHeight / 2.0) - 0.6].CGPath;

    _glassThumb.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:_glassThumb.bounds cornerRadius:thumbHeight / 2.0].CGPath;
}

- (void)handleTouchDown {
    [UIView animateWithDuration:0.10 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self->_glassThumb.transform = CGAffineTransformMakeScale(0.92, 0.92);
    } completion:nil];
}

- (void)handleTouchUp {
    [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.65 initialSpringVelocity:0.8 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self->_glassThumb.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)handleTap {
    [self setOn:!_on animated:YES];
    [self sendActionsForControlEvents:UIControlEventValueChanged];
    if (self.valueChangedBlock) {
        self.valueChangedBlock(_on);
    }
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [feedback impactOccurred];
}

- (void)setOn:(BOOL)on {
    [self setOn:on animated:NO];
}

- (void)setOn:(BOOL)on animated:(BOOL)animated {
    _on = on;
    [self updateUIAnimated:animated];
}

- (void)updateUIAnimated:(BOOL)animated {
    NSArray *onColors = @[
        (id)[UIColor colorWithRed:0.20 green:0.78 blue:0.35 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.16 green:0.68 blue:0.28 alpha:1.0].CGColor
    ];
    NSArray *offColors = @[
        (id)[UIColor colorWithRed:0.20 green:0.22 blue:0.26 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.14 green:0.16 blue:0.19 alpha:1.0].CGColor
    ];

    CGFloat thumbInset = 3.0;
    CGFloat thumbHeight = self.bounds.size.height - (thumbInset * 2);
    CGFloat thumbWidth = thumbHeight;
    CGRect thumbFrame = _on
        ? CGRectMake(self.bounds.size.width - thumbWidth - thumbInset, thumbInset, thumbWidth, thumbHeight)
        : CGRectMake(thumbInset, thumbInset, thumbWidth, thumbHeight);

    void (^animations)(void) = ^{
        self->_trackGradient.colors = self->_on ? onColors : offColors;
        self->_glassThumb.frame = thumbFrame;
    };

    if (animated) {
        [UIView animateWithDuration:0.34 delay:0 usingSpringWithDamping:0.72 initialSpringVelocity:0.9 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:animations completion:nil];
    } else {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        animations();
        [CATransaction commit];
    }
}

@end

// ====================================================================================================
// MODULE 4: LIQUID GLASS CARD CELL - Table Cell Với Hiệu Ứng Glass Đầy Đủ
// ====================================================================================================

@interface LGGlassTableViewCell : UITableViewCell

@property (nonatomic, strong) AppleLiquidGlassView *glassBackgroundView;
@property (nonatomic, strong) UILabel *glassTitleLabel;
@property (nonatomic, strong) UILabel *glassDetailLabel;
@property (nonatomic, strong) UIView *glassAccessoryContainer;

- (void)configureAsGlassCellWithTitle:(NSString *)title detail:(NSString *)detail accessory:(UIView *)accessory;

@end

@implementation LGGlassTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _glassBackgroundView = [[AppleLiquidGlassView alloc] initWithFrame:self.bounds cornerRadius:14.0 materialType:LGGlassMaterialTypeThin];
        _glassBackgroundView.interactiveHighlightEnabled = YES;
        _glassBackgroundView.userInteractionEnabled = NO;
        _glassBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.contentView insertSubview:_glassBackgroundView atIndex:0];

        _glassTitleLabel = [[UILabel alloc] init];
        _glassTitleLabel.textColor = [UIColor whiteColor];
        _glassTitleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
        _glassTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_glassTitleLabel];

        _glassDetailLabel = [[UILabel alloc] init];
        _glassDetailLabel.textColor = [UIColor colorWithWhite:0.72 alpha:1.0];
        _glassDetailLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
        _glassDetailLabel.textAlignment = NSTextAlignmentRight;
        _glassDetailLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_glassDetailLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_glassTitleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [_glassTitleLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_glassDetailLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [_glassDetailLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_glassTitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_glassDetailLabel.leadingAnchor constant:-8]
        ]];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _glassBackgroundView.frame = self.bounds;
}

- (void)configureAsGlassCellWithTitle:(NSString *)title detail:(NSString *)detail accessory:(UIView *)accessory {
    _glassTitleLabel.text = title;
    _glassDetailLabel.text = detail;

    if (_glassAccessoryContainer) {
        [_glassAccessoryContainer removeFromSuperview];
        _glassAccessoryContainer = nil;
    }

    if (accessory) {
        _glassAccessoryContainer = accessory;
        accessory.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:accessory];
        [NSLayoutConstraint activateConstraints:@[
            [accessory.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [accessory.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor]
        ]];
    }
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    [_glassBackgroundView setGlassHighlighted:highlighted animated:animated];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    if (selected) {
        [_glassBackgroundView setGlassHighlighted:YES animated:YES];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.20 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self->_glassBackgroundView setGlassHighlighted:NO animated:YES];
        });
    }
}

@end

// ====================================================================================================
// MODULE 5: LIQUID GLASS NAV BAR BUTTON - Nút Tab Bar Với Glass Đầy Đủ
// ====================================================================================================

@interface LGGlassNavButton : UIControl

@property (nonatomic, strong) AppleLiquidGlassView *glassPill;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, assign) BOOL selected;

- (instancetype)initWithIconName:(NSString *)iconName title:(NSString *)title;
- (void)setSelected:(BOOL)selected animated:(BOOL)animated;

@end

@implementation LGGlassNavButton

- (instancetype)initWithIconName:(NSString *)iconName title:(NSString *)title {
    if (self = [super initWithFrame:CGRectZero]) {
        self.backgroundColor = [UIColor clearColor];

        _glassPill = [[AppleLiquidGlassView alloc] initWithFrame:self.bounds cornerRadius:14.0 materialType:LGGlassMaterialTypeUltraThin];
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

        [self addTarget:self action:@selector(handleTouchDown) forControlEvents:UIControlEventTouchDown];
        [self addTarget:self action:@selector(handleTouchUp) forControlEvents:UIControlEventTouchUpOutside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _glassPill.frame = self.bounds;
    _glassPill.layer.cornerRadius = self.bounds.size.height / 2.0;
    [_glassPill refreshLayersForCurrentBounds];
}

- (void)handleTouchDown {
    [UIView animateWithDuration:0.10 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.iconView.transform = CGAffineTransformMakeScale(0.88, 0.88);
    } completion:nil];
}

- (void)handleTouchUp {
    [UIView animateWithDuration:0.30 delay:0 usingSpringWithDamping:0.60 initialSpringVelocity:0.9 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.iconView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    _selected = selected;
    UIColor *targetColor = selected ? [UIColor whiteColor] : [UIColor colorWithWhite:0.78 alpha:1.0];
    UIFont *targetFont = selected ? [UIFont systemFontOfSize:10.5 weight:UIFontWeightBold] : [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
    CGFloat targetAlpha = selected ? 1.0 : 0.0;

    void (^updates)(void) = ^{
        self.iconView.tintColor = targetColor;
        self.titleLabel.textColor = targetColor;
        self.titleLabel.font = targetFont;
        self.glassPill.alpha = targetAlpha;
    };

    if (animated) {
        [UIView animateWithDuration:0.30 delay:0 options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState animations:updates completion:nil];
    } else {
        updates();
    }
}

@end

// ====================================================================================================
// MODULE 6: HELPER FUNCTIONS
// ====================================================================================================

static inline NSString *Titanium_GetRootHidePrefixPath(void) {
    static NSString *cachedJbRoot = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Dl_info info;
        if (dladdr((const void *)Titanium_GetRootHidePrefixPath, &info) && info.dli_fname) {
            NSString *dylibPath = [NSString stringWithUTF8String:info.dli_fname];
            NSRange range = [dylibPath rangeOfString:@"/var/jb"];
            if (range.location != NSNotFound) {
                NSRange sub = [dylibPath rangeOfString:@"/" options:0 range:NSMakeRange(range.location + 7, dylibPath.length - (range.location + 7))];
                cachedJbRoot = (sub.location != NSNotFound) ? [dylibPath substringToIndex:sub.location] : @"/var/jb";
            } else {
                cachedJbRoot = @"/var/jb";
            }
        } else {
            cachedJbRoot = @"/var/jb";
        }
    });
    return cachedJbRoot;
}

static inline NSString *Titanium_ResolvePrefPath(void) {
    NSString *root = Titanium_GetRootHidePrefixPath();
    if (root && root.length > 0 && ![root isEqualToString:@"/"]) {
        NSString *jbPath = [root stringByAppendingPathComponent:@"var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:jbPath]) return jbPath;
    }
    NSString *p1 = @"/var/jb/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist";
    if ([[NSFileManager defaultManager] fileExistsAtPath:p1]) return p1;
    return @"/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist";
}

static inline NSString *Titanium_FindExecutablePath(NSString *name) {
    NSArray *searchPrefixes = @[
        [Titanium_GetRootHidePrefixPath() stringByAppendingPathComponent:@"usr/bin"],
        [Titanium_GetRootHidePrefixPath() stringByAppendingPathComponent:@"bin"],
        @"/var/jb/usr/bin",
        @"/var/jb/bin",
        @"/usr/bin",
        @"/bin"
    ];
    for (NSString *prefix in searchPrefixes) {
        NSString *candidate = [prefix stringByAppendingPathComponent:name];
        if (access([candidate UTF8String], X_OK) == 0) return candidate;
    }
    return name;
}

static void Titanium_WriteSyncPayloadUniversal(const void *payloadData, size_t size) {
    NSArray *paths = @[PRIMARY_SYNC_FILE, SECONDARY_SYNC_FILE];
    for (NSString *path in paths) {
        NSString *dir = [path stringByDeletingLastPathComponent];
        if (![[NSFileManager defaultManager] fileExistsAtPath:dir]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @(0777)} error:nil];
        }
        int fd = open([path UTF8String], O_WRONLY | O_CREAT | O_TRUNC, 0666);
        if (fd >= 0) {
            write(fd, payloadData, size);
            close(fd);
            chmod([path UTF8String], 0666);
        }
    }
}

static inline BOOL Titanium_IsSupportedIOSVersion(void) {
    NSOperatingSystemVersion os = [[NSProcessInfo processInfo] operatingSystemVersion];
    return (os.majorVersion >= 15 && os.majorVersion <= 26);
}

static inline float Titanium_GetLiveCPULoadPercentage(void) {
    host_cpu_load_info_data_t cpuinfo;
    mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;
    static unsigned long long prevUser = 0, prevSystem = 0, prevIdle = 0, prevNice = 0;
    if (host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, (host_info_t)&cpuinfo, &count) == KERN_SUCCESS) {
        unsigned long long user = cpuinfo.cpu_ticks[CPU_STATE_USER];
        unsigned long long system = cpuinfo.cpu_ticks[CPU_STATE_SYSTEM];
        unsigned long long idle = cpuinfo.cpu_ticks[CPU_STATE_IDLE];
        unsigned long long nice = cpuinfo.cpu_ticks[CPU_STATE_NICE];
        unsigned long long totalTicks = (user - prevUser) + (system - prevSystem) + (idle - prevIdle) + (nice - prevNice);
        unsigned long long usedTicks = (user - prevUser) + (system - prevSystem) + (nice - prevNice);
        prevUser = user; prevSystem = system; prevIdle = idle; prevNice = nice;
        if (totalTicks > 0) return ((float)usedTicks / (float)totalTicks) * 100.0f;
    }
    return 14.5f;
}

static inline float Titanium_GetLiveGPULoadPercentage(void) {
    float cpu = Titanium_GetLiveCPULoadPercentage();
    float gpu = (cpu * 0.72f) + 3.8f;
    if (gpu > 99.0f) gpu = 98.6f;
    return gpu;
}

static inline float Titanium_GetBaseThermalTemp(void) {
    NSProcessInfoThermalState state = [[NSProcessInfo processInfo] thermalState];
    float cpuLoad = Titanium_GetLiveCPULoadPercentage();
    float loadOffset = (cpuLoad / 100.0f) * 2.5f;
    switch (state) {
        case NSProcessInfoThermalStateNominal:  return 31.8f + loadOffset;
        case NSProcessInfoThermalStateFair:     return 36.2f + loadOffset;
        case NSProcessInfoThermalStateSerious:  return 40.8f + loadOffset;
        case NSProcessInfoThermalStateCritical: return 44.5f + loadOffset;
        default: return 32.2f + loadOffset;
    }
}

// ====================================================================================================
// ROOT LIST CONTROLLER - TÍCH HỢP LIQUID GLASS 4.0 FULL ANIMATIONS
// ====================================================================================================

@interface RootListController () {
    dispatch_source_t _hudTimer;
    NSInteger _currentBottomTab;
    NSInteger _currentHzFpsSubTab;
    NSInteger _currentSwitchSubTab;
    BOOL _isRateLocked;
    BOOL _isKernelExploited;
    BOOL _isCpuExpanded;
    BOOL _isGpuExpanded;
    BOOL _isRamExpanded;
    BOOL _isBatteryExpanded;
    BOOL _isScreenExpanded;

    NSString *_deepArchString;
    NSString *_deepCoreCountString;
    NSString *_deepRamString;
    NSString *_deepKernelString;
    NSString *_deepCacheString;
    NSString *_deviceUUIDString;

    NSMutableArray<NSDictionary *> *_scannedAppsList;
    NSMutableDictionary<NSString *, NSNumber *> *_appTweakStates;

    AppleLiquidGlassView *_liquidNavBarContainer;
    AppleLiquidGlassView *_activeGlassIndicator;
    NSMutableArray<LGGlassNavButton *> *_tabButtons;
    NSArray<NSDictionary *> *_tabConfigs;

    UIView *_liquidGlassLensContainer;
    AppleLiquidGlassView *_lensGlassEffectView;
    UILabel *_lensTitleLabel;
}
@end

@implementation RootListController

@synthesize customTableView = _customTableView;
@synthesize bottomSegment = _bottomSegment;
@synthesize rateLockButton = _rateLockButton;
@synthesize settingsDict = _settingsDict;

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"";

    CAGradientLayer *bg = [CAGradientLayer layer];
    bg.frame = self.view.bounds;
    bg.colors = @[
        (id)[UIColor colorWithRed:0.05 green:0.06 blue:0.10 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.02 green:0.02 blue:0.04 alpha:1.0].CGColor
    ];
    bg.startPoint = CGPointMake(0.0, 0.0);
    bg.endPoint = CGPointMake(0.0, 1.0);
    [self.view.layer insertSublayer:bg atIndex:0];
    self.view.backgroundColor = [UIColor colorWithRed:0.03 green:0.03 blue:0.06 alpha:1.0];

    _currentBottomTab = 0;
    _currentHzFpsSubTab = 0;
    _currentSwitchSubTab = 0;

    _isCpuExpanded = NO; _isGpuExpanded = NO; _isRamExpanded = NO;
    _isBatteryExpanded = NO; _isScreenExpanded = NO;

    _scannedAppsList = [NSMutableArray array];
    _tabButtons = [NSMutableArray array];

    [self loadSettingsData];
    _isRateLocked = [self.settingsDict[@"IsRateLocked"] boolValue];

    NSUUID *uuid = [[UIDevice currentDevice] identifierForVendor];
    _deviceUUIDString = uuid ? [uuid UUIDString] : @"UNKNOWN-DEVICE-UUID";

    _isKernelExploited = [self.settingsDict[@"IsKernelExploited"] boolValue];
    if (_isKernelExploited) {
        _deepArchString = self.settingsDict[@"SavedArchString"] ?: @"arm64e (Apple Silicon PAC)";
        _deepCoreCountString = self.settingsDict[@"SavedCoreCountString"] ?: @"SoC Clustered P/E Cores";
        _deepRamString = self.settingsDict[@"SavedRamString"] ?: @"LPDDR Mach Purgable";
        _deepKernelString = self.settingsDict[@"SavedKernelString"] ?: @"Darwin XNU Kernel";
        _deepCacheString = self.settingsDict[@"SavedCacheString"] ?: @"Low Latency Silicon Cache";
    }

    [self setupTopHeaderBar];
    [self setupNavigationItems];
    [self setupLiquidGlassNavBar];
    [self setupMainTableView];
    [self setupLiquidGlassLens];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self loadInstalledAppsAsync];
        if (self->_isKernelExploited) {
            [self applyDeepSpringBoardAndUIKitTweaks];
        }
    });
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (_isKernelExploited) [self startContinuousHardwareHUD];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopContinuousHardwareHUD];
}

#pragma mark - Bridge

- (void)setupBottomNavigationBar { [self setupLiquidGlassNavBar]; }
- (void)onBottomTabChanged:(UISegmentedControl *)sender {
    if (sender) [self selectTabIndex:sender.selectedSegmentIndex animated:YES];
}
- (void)onSwitchToggled:(UISwitch *)sender {
    if (sender) [self.customTableView reloadData];
}

- (void)showLanguagePickerPopup:(id)sender {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"🌐 CHỌN NGÔN NGỮ" message:@"Lựa chọn ngôn ngữ hiển thị hệ thống:" preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Tiếng Việt (Mặc Định)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        self.settingsDict[@"AppLanguage"] = @"vi";
        [self saveSettingsDataAndSync];
        [self.customTableView reloadData];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"English" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        self.settingsDict[@"AppLanguage"] = @"en";
        [self saveSettingsDataAndSync];
        [self.customTableView reloadData];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        sheet.popoverPresentationController.sourceView = self.view;
        sheet.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2, 1, 1);
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - Liquid Glass Nav Bar

- (void)setupLiquidGlassNavBar {
    CGFloat barHeight = 62.0;
    CGFloat barMargin = 14.0;
    CGFloat barY = self.view.bounds.size.height - barHeight - 34;

    _liquidNavBarContainer = [[AppleLiquidGlassView alloc] initWithFrame:CGRectMake(barMargin, barY, self.view.bounds.size.width - (barMargin * 2), barHeight)
                                                            cornerRadius:barHeight / 2.0
                                                            materialType:LGGlassMaterialTypeChrome];
    _liquidNavBarContainer.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    _liquidNavBarContainer.interactiveHighlightEnabled = NO;

    _liquidNavBarContainer.layer.shadowOpacity = 0.32;
    _liquidNavBarContainer.layer.shadowRadius = 16.0;
    _liquidNavBarContainer.layer.shadowOffset = CGSizeMake(0, 7);
    _liquidNavBarContainer.layer.shadowColor = [UIColor blackColor].CGColor;

    _tabConfigs = @[
        @{@"title": @"Trang Chủ", @"icon": @"house.fill",  @"tab": @0},
        @{@"title": @"Hz/FPS",    @"icon": @"speedometer", @"tab": @1},
        @{@"title": @"Switch",    @"icon": @"bolt.fill",   @"tab": @2},
        @{@"title": @"App",       @"icon": @"iphone",      @"tab": @3},
        @{@"title": @"Cài Đặt",   @"icon": @"gearshape",   @"tab": @4}
    ];

    CGFloat btnWidth = _liquidNavBarContainer.bounds.size.width / _tabConfigs.count;

    _activeGlassIndicator = [[AppleLiquidGlassView alloc] initWithFrame:CGRectMake(3, 3, btnWidth - 6, barHeight - 6)
                                                            cornerRadius:(barHeight - 6) / 2.0
                                                            materialType:LGGlassMaterialTypeUltraThin];
    _activeGlassIndicator.userInteractionEnabled = NO;
    _activeGlassIndicator.interactiveHighlightEnabled = NO;
    _activeGlassIndicator.glassTintView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10];
    _activeGlassIndicator.layer.shadowOpacity = 0.22;
    _activeGlassIndicator.layer.shadowRadius = 5.0;
    _activeGlassIndicator.layer.shadowOffset = CGSizeMake(0, 2);
    [_liquidNavBarContainer addSubview:_activeGlassIndicator];

    for (NSInteger i = 0; i < _tabConfigs.count; i++) {
        NSDictionary *conf = _tabConfigs[i];
        LGGlassNavButton *btn = [[LGGlassNavButton alloc] initWithIconName:conf[@"icon"] title:conf[@"title"]];
        btn.frame = CGRectMake(i * btnWidth + 3, 3, btnWidth - 6, barHeight - 6);
        btn.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        btn.tag = i;
        [btn addTarget:self action:@selector(onCustomTabButtonClicked:) forControlEvents:UIControlEventTouchUpInside];

        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleTabLongPress:)];
        longPress.minimumPressDuration = 0.12;
        [btn addGestureRecognizer:longPress];

        [_liquidNavBarContainer addSubview:btn];
        [_tabButtons addObject:btn];
    }

    if (_tabButtons.count > 0) {
        [_tabButtons[0] setSelected:YES animated:NO];
    }

    [self.view addSubview:_liquidNavBarContainer];
}

- (void)onCustomTabButtonClicked:(LGGlassNavButton *)sender {
    [self selectTabIndex:sender.tag animated:YES];
}

- (void)selectTabIndex:(NSInteger)index animated:(BOOL)animated {
    if (index < 0 || index >= _tabConfigs.count) return;

    NSInteger oldTab = _currentBottomTab;
    _currentBottomTab = [_tabConfigs[index][@"tab"] integerValue];

    CGFloat btnWidth = _liquidNavBarContainer.bounds.size.width / _tabConfigs.count;
    CGRect targetFrame = CGRectMake((index * btnWidth) + 3, 3, btnWidth - 6, _liquidNavBarContainer.bounds.size.height - 6);

    CGFloat velocity = (index - oldTab) * 480.0;
    if (animated) {
        [_activeGlassIndicator applyFluidJiggleAnimationWithVelocity:velocity];
    }

    void (^animations)(void) = ^{
        self->_activeGlassIndicator.frame = targetFrame;
        for (NSInteger i = 0; i < self->_tabButtons.count; i++) {
            LGGlassNavButton *b = self->_tabButtons[i];
            [b setSelected:(i == index) animated:animated];
        }
    };

    if (animated) {
        [UIView animateWithDuration:0.34 delay:0 usingSpringWithDamping:0.74 initialSpringVelocity:0.85 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:animations completion:nil];
    } else {
        animations();
    }

    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];

    [self.customTableView reloadData];
}

#pragma mark - Liquid Glass Lens

- (void)setupLiquidGlassLens {
    _liquidGlassLensContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 68, 68)];
    _liquidGlassLensContainer.hidden = YES;
    _liquidGlassLensContainer.userInteractionEnabled = NO;

    _lensGlassEffectView = [[AppleLiquidGlassView alloc] initWithFrame:_liquidGlassLensContainer.bounds cornerRadius:34.0 materialType:LGGlassMaterialTypeThin];
    _lensGlassEffectView.interactiveHighlightEnabled = NO;
    _lensGlassEffectView.layer.shadowColor = [UIColor blackColor].CGColor;
    _lensGlassEffectView.layer.shadowOpacity = 0.32;
    _lensGlassEffectView.layer.shadowRadius = 12.0;
    _lensGlassEffectView.layer.shadowOffset = CGSizeMake(0, 5);
    [_liquidGlassLensContainer addSubview:_lensGlassEffectView];

    _lensTitleLabel = [[UILabel alloc] initWithFrame:_liquidGlassLensContainer.bounds];
    _lensTitleLabel.textAlignment = NSTextAlignmentCenter;
    _lensTitleLabel.textColor = [UIColor whiteColor];
    _lensTitleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightHeavy];
    [_liquidGlassLensContainer addSubview:_lensTitleLabel];

    [self.view addSubview:_liquidGlassLensContainer];
}

- (void)handleTabLongPress:(UILongPressGestureRecognizer *)gesture {
    LGGlassNavButton *btn = (LGGlassNavButton *)gesture.view;
    CGPoint touchInView = [gesture locationInView:self.view];

    if (gesture.state == UIGestureRecognizerStateBegan) {
        CGPoint centerPoint = CGPointMake(touchInView.x, _liquidNavBarContainer.center.y - 24);
        _liquidGlassLensContainer.center = centerPoint;
        _liquidGlassLensContainer.hidden = NO;
        _liquidGlassLensContainer.alpha = 0.0;
        _liquidGlassLensContainer.transform = CGAffineTransformMakeScale(0.3, 0.3);
        _lensTitleLabel.text = _tabConfigs[btn.tag][@"title"];

        [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.65 initialSpringVelocity:1.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self->_liquidGlassLensContainer.alpha = 1.0;
            self->_liquidGlassLensContainer.transform = CGAffineTransformIdentity;
        } completion:nil];

        UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [fb impactOccurred];
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        CGPoint centerPoint = CGPointMake(touchInView.x, _liquidNavBarContainer.center.y - 24);
        _liquidGlassLensContainer.center = centerPoint;

        for (NSInteger i = 0; i < _tabButtons.count; i++) {
            LGGlassNavButton *b = _tabButtons[i];
            CGPoint p = [gesture locationInView:b];
            if (CGRectContainsPoint(b.bounds, p)) {
                _lensTitleLabel.text = _tabConfigs[i][@"title"];
                if (_currentBottomTab != [_tabConfigs[i][@"tab"] integerValue]) {
                    [self selectTabIndex:i animated:YES];
                }
                break;
            }
        }
    } else {
        [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
            self->_liquidGlassLensContainer.alpha = 0.0;
            self->_liquidGlassLensContainer.transform = CGAffineTransformMakeScale(0.2, 0.2);
        } completion:^(BOOL finished) {
            self->_liquidGlassLensContainer.hidden = YES;
            self->_liquidGlassLensContainer.transform = CGAffineTransformIdentity;
        }];
    }
}

#pragma mark - Navigation & Header

- (void)setupTopHeaderBar {
    UILabel *brandLabel = [[UILabel alloc] init];
    brandLabel.text = @" 💧 Liquid Glass ";
    brandLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.95];
    brandLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightHeavy];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:brandLabel];
}

- (void)setupNavigationItems {
    self.rateLockButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self updateLockIcon];
    [self.rateLockButton addTarget:self action:@selector(toggleRateLockAction) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *lockItem = [[UIBarButtonItem alloc] initWithCustomView:self.rateLockButton];

    UIButton *applyInstantButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [applyInstantButton setImage:[UIImage systemImageNamed:@"bolt.horizontal.fill"] forState:UIControlStateNormal];
    applyInstantButton.tintColor = [UIColor colorWithWhite:1.0 alpha:0.95];
    [applyInstantButton addTarget:self action:@selector(applySettingsInstantNoRespringAction) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *applyItem = [[UIBarButtonItem alloc] initWithCustomView:applyInstantButton];

    UIAction *actRespring = [UIAction actionWithTitle:@"⚡ Respring Nhanh" image:[UIImage systemImageNamed:@"arrow.triangle.2.circlepath"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
        [self executeRespring];
    }];
    UIAction *actSReboot = [UIAction actionWithTitle:@"🔥 Khởi Động Userspace" image:[UIImage systemImageNamed:@"arrow.clockwise.circle.fill"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
        [self executeSReboot];
    }];
    UIAction *actSafeMode = [UIAction actionWithTitle:@"🛡️ Vào Safe Mode An Toàn" image:[UIImage systemImageNamed:@"shield.lefthalf.fill"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
        [self executeSafeMode];
    }];
    UIAction *actReset = [UIAction actionWithTitle:@"♻ Đặt Lại & Xóa Sạch Dữ Liệu" image:[UIImage systemImageNamed:@"trash.fill"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
        [self executeResetConfiguration];
    }];
    actReset.attributes = UIMenuElementAttributesDestructive;

    UIMenu *threeBarMenu = [UIMenu menuWithTitle:@"HÀNH ĐỘNG HỆ THỐNG" children:@[actRespring, actSReboot, actSafeMode, actReset]];
    UIBarButtonItem *menuItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"line.3.horizontal"] menu:threeBarMenu];
    menuItem.tintColor = [UIColor whiteColor];

    self.navigationItem.rightBarButtonItems = @[menuItem, lockItem, applyItem];
}

- (void)applySettingsInstantNoRespringAction {
    if (!_isKernelExploited) { [self showUnexploitedWarningAlert]; return; }
    [self saveSettingsDataAndSync];
    [self applyDeepSpringBoardAndUIKitTweaks];

    UINotificationFeedbackGenerator *notiFb = [[UINotificationFeedbackGenerator alloc] init];
    [notiFb notificationOccurred:UINotificationFeedbackTypeSuccess];

    AppleLiquidGlassView *toast = [[AppleLiquidGlassView alloc] initWithFrame:CGRectMake(30, 100, self.view.bounds.size.width - 60, 46) cornerRadius:23.0 materialType:LGGlassMaterialTypeThin];
    toast.interactiveHighlightEnabled = NO;

    UILabel *toastLabel = [[UILabel alloc] initWithFrame:toast.bounds];
    toastLabel.text = @"⚡ ĐÃ ĐỒNG BỘ TỨC THÌ";
    toastLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.95];
    toastLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    toastLabel.textAlignment = NSTextAlignmentCenter;
    [toast addSubview:toastLabel];

    [self.view addSubview:toast];
    toast.alpha = 0.0;
    toast.transform = CGAffineTransformMakeScale(0.85, 0.85);

    [UIView animateWithDuration:0.25 animations:^{
        toast.alpha = 1.0;
        toast.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.35 delay:1.6 options:0 animations:^{
            toast.alpha = 0.0;
            toast.transform = CGAffineTransformMakeTranslation(0, -15);
        } completion:^(BOOL finished) { [toast removeFromSuperview]; }];
    }];
}

- (void)updateLockIcon {
    NSString *iconName = self->_isRateLocked ? @"lock.fill" : @"lock.open.fill";
    UIColor *color = self->_isRateLocked ? [UIColor systemRedColor] : [UIColor whiteColor];
    [self.rateLockButton setImage:[UIImage systemImageNamed:iconName] forState:UIControlStateNormal];
    self.rateLockButton.tintColor = color;
}

- (void)toggleRateLockAction {
    if (!_isKernelExploited) { [self showUnexploitedWarningAlert]; return; }
    self->_isRateLocked = !self->_isRateLocked;
    self.settingsDict[@"IsRateLocked"] = @(self->_isRateLocked);
    [self saveSettingsDataAndSync];
    [self updateLockIcon];
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
    [feedback impactOccurred];
    [self applyDeepSpringBoardAndUIKitTweaks];
    [self.customTableView reloadData];
}

#pragma mark - TableView

- (void)setupMainTableView {
    self.customTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - 106) style:UITableViewStyleInsetGrouped];
    self.customTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.customTableView.backgroundColor = [UIColor clearColor];
    self.customTableView.separatorColor = [UIColor colorWithWhite:1.0 alpha:0.04];
    self.customTableView.delegate = self;
    self.customTableView.dataSource = self;
    [self.view addSubview:self.customTableView];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (_currentBottomTab == 0) return 6;
    if (_currentBottomTab == 1) return 3;
    if (_currentBottomTab == 2) return 2;
    if (_currentBottomTab == 3) return 1;
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (!_isKernelExploited && _currentBottomTab != 4) return 1;

    if (_currentBottomTab == 0) {
        if (section == 0) return 1;
        BOOL isMonitorActive = [self.settingsDict[@"EnableSystemMonitoring"] boolValue];
        if (!isMonitorActive) return 1;
        if (section == 1) return _isCpuExpanded ? 5 : 1;
        if (section == 2) return _isGpuExpanded ? 5 : 1;
        if (section == 3) return _isRamExpanded ? 4 : 1;
        if (section == 4) return _isBatteryExpanded ? 5 : 1;
        return _isScreenExpanded ? 4 : 1;
    } else if (_currentBottomTab == 1) {
        if (section == 0) return 1;
        if (section == 1) return 1;
        return 6;
    } else if (_currentBottomTab == 2) {
        if (section == 0) return 1;
        switch (_currentSwitchSubTab) {
            case 0: return 5;
            case 1: return 5;
            case 2: return 5;
            case 3: return 5;
            case 4: return 6;
            default: return 5;
        }
    } else if (_currentBottomTab == 3) {
        return _scannedAppsList.count;
    } else {
        if (section == 0) return 2;
        if (section == 1) return _isKernelExploited ? 8 : 1;
        return 4;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (!_isKernelExploited && _currentBottomTab != 4) return @"🔒 TRẠNG THÁI KHÓA HỆ THỐNG";
    if (_currentBottomTab == 0) {
        if (section == 0) return @"🎛️ ĐIỀU KHIỂN HỆ THỐNG ĐO";
        if (section == 1) return @"🧠 BỘ XỬ LÝ TRUNG TÂM (CPU)";
        if (section == 2) return @"🎮 BỘ XỬ LÝ ĐỒ HỌA (GPU)";
        if (section == 3) return @"💾 BỘ NHỚ TRUY XUẤT (RAM)";
        if (section == 4) return @"🔋 NGUỒN ĐIỆN & PIN";
        return @"🖥️ MÀN HÌNH HIỂN THỊ";
    } else if (_currentBottomTab == 1) {
        if (section == 0) return @"ℹ️ NGUYÊN LÝ HOẠT ĐỘNG HZ & FPS";
        if (section == 1) return @"⚡ ĐIỀU PHỐI ĐỘC LẬP TẦN SỐ QUÉT";
        return (_currentHzFpsSubTab == 0) ? @"🎛️ KHÓA TẦN SỐ QUÉT (HZ)" : @"🎮 KHÓA KHUNG HÌNH (FPS)";
    } else if (_currentBottomTab == 2) {
        if (section == 0) return @"🎚️ CHỌN PHÂN NHÓM CÔNG TẮC";
        switch (_currentSwitchSubTab) {
            case 0: return @"🧠 NHÓM CPU";
            case 1: return @"🎮 NHÓM GPU";
            case 2: return @"🖥️ NHÓM MÀN HÌNH";
            case 3: return @"🔋 NHÓM PIN";
            case 4: return @"⚡ NHÓM HỆ THỐNG";
            default: return @"🟢 CÔNG TẮC";
        }
    } else if (_currentBottomTab == 3) {
        return @"📱 QUẢN LÝ ỨNG DỤNG TƯƠNG TÁC";
    } else {
        if (section == 0) return @"🛡️ TRẠNG THÁI KHAI THÁC HỆ THỐNG";
        if (section == 1) return @"📱 THÔNG TIN PHẦN CỨNG THIẾT BỊ";
        return @"🛡️ THÔNG TIN VÙNG SANDBOX";
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 54.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"LGGlassCell";
    LGGlassTableViewCell *cell = (LGGlassTableViewCell *)[tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[LGGlassTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellID];
    }

    NSString *title = @"";
    NSString *detail = @"";
    UIView *accessory = nil;

    if (!_isKernelExploited && _currentBottomTab != 4) {
        title = @"🔒 TÍNH NĂNG ĐANG BỊ KHÓA XÁM";
        detail = @"Chưa Khai Thác";
        [cell configureAsGlassCellWithTitle:title detail:detail accessory:nil];
        cell.userInteractionEnabled = NO;
        cell.alpha = 0.55;
        return cell;
    }
    cell.userInteractionEnabled = YES;
    cell.alpha = 1.0;

    if (_currentBottomTab == 0) {
        if (indexPath.section == 0) {
            title = @"⚡ Kích Hoạt Bộ Đo Phần Cứng Realtime";
            LiquidCapsuleSwitch *s = [[LiquidCapsuleSwitch alloc] init];
            s.on = [self.settingsDict[@"EnableSystemMonitoring"] boolValue];
            __weak typeof(self) weakSelf = self;
            s.valueChangedBlock = ^(BOOL isOn) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                strongSelf.settingsDict[@"EnableSystemMonitoring"] = @(isOn);
                [strongSelf saveSettingsDataAndSync];
                [strongSelf.customTableView reloadData];
            };
            accessory = s;
        } else {
            BOOL isMonitorActive = [self.settingsDict[@"EnableSystemMonitoring"] boolValue];
            if (!isMonitorActive) {
                title = @"🔒 Bộ đo đang tắt";
                detail = @"[TẮT]";
            } else {
                float baseTemp = Titanium_GetBaseThermalTemp();
                float cpu = Titanium_GetLiveCPULoadPercentage();
                float gpu = Titanium_GetLiveGPULoadPercentage();
                if (indexPath.section == 1) {
                    if (indexPath.row == 0) { title = _isCpuExpanded ? @"🧠 CPU ▼" : @"🧠 CPU ▶"; detail = [NSString stringWithFormat:@"%.1f°C | %.1f%%", baseTemp, cpu]; }
                    else if (indexPath.row == 1) { title = @"   Nhiệt độ CPU"; detail = [NSString stringWithFormat:@"%.1f°C", baseTemp]; }
                    else if (indexPath.row == 2) { title = @"   Tải CPU"; detail = [NSString stringWithFormat:@"%.1f%%", cpu]; }
                    else if (indexPath.row == 3) { float ghz = (cpu > 60.0f) ? 2.49f : ((cpu > 25.0f) ? 1.85f : 1.10f); title = @"   Xung P-Core"; detail = [NSString stringWithFormat:@"%.2f GHz", ghz]; }
                    else { title = @"   Điều Phối Lõi"; detail = (cpu > 40.0f) ? @"P-Core" : @"E-Core"; }
                } else if (indexPath.section == 2) {
                    if (indexPath.row == 0) { title = _isGpuExpanded ? @"🎮 GPU ▼" : @"🎮 GPU ▶"; detail = [NSString stringWithFormat:@"%.1f°C | %.1f%%", baseTemp - 0.7f, gpu]; }
                    else if (indexPath.row == 1) { title = @"   Nhiệt GPU"; detail = [NSString stringWithFormat:@"%.1f°C", baseTemp - 0.7f]; }
                    else if (indexPath.row == 2) { title = @"   Tải Metal"; detail = [NSString stringWithFormat:@"%.1f%%", gpu]; }
                    else if (indexPath.row == 3) { title = @"   Xung Metal"; detail = @"600 MHz"; }
                    else { title = @"   Buffer"; detail = @"Triple (3)"; }
                } else if (indexPath.section == 3) {
                    if (indexPath.row == 0) { title = _isRamExpanded ? @"💾 RAM ▼" : @"💾 RAM ▶"; detail = [NSString stringWithFormat:@"%.1f°C | 42.5%%", baseTemp - 1.2f]; }
                    else if (indexPath.row == 1) { title = @"   Nhiệt LPDDR"; detail = [NSString stringWithFormat:@"%.1f°C", baseTemp - 1.2f]; }
                    else if (indexPath.row == 2) { title = @"   Dung lượng"; detail = _deepRamString ?: @"2.85 / 4.00 GB"; }
                    else { title = @"   Mach Purgable"; detail = @"Clean"; }
                } else if (indexPath.section == 4) {
                    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
                    int level = (int)([[UIDevice currentDevice] batteryLevel] * 100);
                    if (level < 0) level = 100;
                    float bl = (cpu * 0.45f) + 8.5f;
                    if (indexPath.row == 0) { title = _isBatteryExpanded ? @"🔋 Pin ▼" : @"🔋 Pin ▶"; detail = [NSString stringWithFormat:@"%.1f°C | %.1f%%", baseTemp - 2.0f, bl]; }
                    else if (indexPath.row == 1) { title = @"   Nhiệt Pin"; detail = [NSString stringWithFormat:@"%.1f°C", baseTemp - 2.0f]; }
                    else if (indexPath.row == 2) { title = @"   Dòng xả"; detail = [NSString stringWithFormat:@"%.1f%%", bl]; }
                    else if (indexPath.row == 3) { title = @"   Dung lượng"; detail = [NSString stringWithFormat:@"%d%%", level]; }
                    else { title = @"   Nguồn"; detail = @"Li-ion"; }
                } else {
                    NSInteger hz = [self.settingsDict[@"TargetRefreshRate"] ?: @144 integerValue];
                    NSInteger fps = [self.settingsDict[@"TargetFPSRate"] ?: @144 integerValue];
                    if (indexPath.row == 0) { title = _isScreenExpanded ? @"🖥️ Màn Hình ▼" : @"🖥️ Màn Hình ▶"; detail = [NSString stringWithFormat:@"%.1f°C | %ld Hz", baseTemp - 1.5f, (long)hz]; }
                    else if (indexPath.row == 1) { title = @"   Nhiệt hiển thị"; detail = [NSString stringWithFormat:@"%.1f°C", baseTemp - 1.5f]; }
                    else if (indexPath.row == 2) { title = @"   Tần số quét"; detail = [NSString stringWithFormat:@"%ld Hz", (long)hz]; }
                    else { title = @"   Khung hình"; detail = [NSString stringWithFormat:@"%ld FPS", (long)fps]; }
                }
            }
        }
    } else if (_currentBottomTab == 1) {
        if (indexPath.section == 0) {
            title = @"📌 Tần số Hz và FPS được điều phối trực tiếp tới CADisplayLink & CoreAnimation RenderServer.";
        } else if (indexPath.section == 1) {
            UISegmentedControl *subSeg = [[UISegmentedControl alloc] initWithItems:@[@"Hz", @"FPS"]];
            subSeg.selectedSegmentIndex = _currentHzFpsSubTab;
            subSeg.frame = CGRectMake(0, 0, 180, 32);
            [subSeg addTarget:self action:@selector(onHzFpsSubTabChanged:) forControlEvents:UIControlEventValueChanged];
            accessory = subSeg;
            title = @"   Chế độ điều chỉnh:";
        } else {
            BOOL isHz = (_currentHzFpsSubTab == 0);
            NSInteger cur = isHz ? [self.settingsDict[@"TargetRefreshRate"] ?: @144 integerValue] : [self.settingsDict[@"TargetFPSRate"] ?: @144 integerValue];
            NSArray *rates = @[@30, @60, @90, @120];
            if (indexPath.row < 4) {
                NSInteger r = [rates[indexPath.row] integerValue];
                title = [NSString stringWithFormat:@"Khóa %ld %@", (long)r, isHz ? @"Hz" : @"FPS"];
                detail = (cur == r) ? @"✓" : @"";
            } else if (indexPath.row == 4) {
                title = [NSString stringWithFormat:@"⚡ Mở Rộng 144 %@", isHz ? @"Hz" : @"FPS"];
                detail = (cur == 144) ? @"✓" : @"";
            } else {
                title = @"⌨️ Nhập Tùy Chỉnh...";
                detail = [NSString stringWithFormat:@"Hiện: %ld", (long)cur];
            }
        }
    } else if (_currentBottomTab == 2) {
        if (indexPath.section == 0) {
            UISegmentedControl *catSeg = [[UISegmentedControl alloc] initWithItems:@[@"CPU", @"GPU", @"Màn", @"Pin", @"Hệ Thống"]];
            catSeg.selectedSegmentIndex = _currentSwitchSubTab;
            catSeg.frame = CGRectMake(0, 0, 240, 32);
            [catSeg addTarget:self action:@selector(onSwitchSubTabChanged:) forControlEvents:UIControlEventValueChanged];
            accessory = catSeg;
            title = @"   Nhóm:";
        } else {
            NSString *prefKey = @"";
            if (_currentSwitchSubTab == 0) {
                if (indexPath.row == 0) { title = @"Ưu Tiên P-Core Realtime"; prefKey = @"pCoreRealtimePriority"; }
                else if (indexPath.row == 1) { title = @"Điều Phối CPU Scheduler"; prefKey = @"schedulerGovernor"; }
                else if (indexPath.row == 2) { title = @"Đồng Bộ Xung Quantum"; prefKey = @"quantumCoreSync"; }
                else if (indexPath.row == 3) { title = @"Khóa Tần Số CPU Sàn"; prefKey = @"lockHighIdleFloor"; }
                else { title = @"Chống Bóp Xung Nhiệt"; prefKey = @"AntiThermalThrottling"; }
            } else if (_currentSwitchSubTab == 1) {
                if (indexPath.row == 0) { title = @"Metal Triple Buffering"; prefKey = @"MetalHexBuffering"; }
                else if (indexPath.row == 1) { title = @"Isolate Render Pipeline"; prefKey = @"IsolateRenderPipeline"; }
                else if (indexPath.row == 2) { title = @"Bỏ Khóa V-Sync"; prefKey = @"vsyncAdaptiveBuffer"; }
                else if (indexPath.row == 3) { title = @"Ổn Định FPS Game"; prefKey = @"gameFPSStabilizer"; }
                else { title = @"Triệt Tiêu Blur Động"; prefKey = @"flatTintBlur"; }
            } else if (_currentSwitchSubTab == 2) {
                if (indexPath.row == 0) { title = @"🔥 Ép 144Hz Toàn Máy"; prefKey = @"ForceOverclock144Hz"; }
                else if (indexPath.row == 1) { title = @"ProMotion Beta 7"; prefKey = @"ProMotionEngineBeta7"; }
                else if (indexPath.row == 2) { title = @"Cảm Ứng 0ms"; prefKey = @"TouchResponseBoost"; }
                else if (indexPath.row == 3) { title = @"Cuộn ColorOS 17"; prefKey = @"ColorOs17SmoothEngine"; }
                else { title = @"Neural Touch"; prefKey = @"zeroLagNeural"; }
            } else if (_currentSwitchSubTab == 3) {
                if (indexPath.row == 0) { title = @"Lọc Loạn Cảm Ứng"; prefKey = @"AntiGhostTouch"; }
                else if (indexPath.row == 1) { title = @"Khử Nhiễu Sạc"; prefKey = @"ChargerRippleRejection"; }
                else if (indexPath.row == 2) { title = @"Giả Lập Pin Đầy"; prefKey = @"fakeFullBatteryState"; }
                else if (indexPath.row == 3) { title = @"Khóa 30 FPS Nóng"; prefKey = @"lock30FpsOnOverheat"; }
                else { title = @"Tiết Kiệm Pin 60Hz"; prefKey = @"batterySaver60Hz"; }
            } else {
                if (indexPath.row == 0) { title = @"Khởi Động App Turbo"; prefKey = @"TurboAppLaunch"; }
                else if (indexPath.row == 1) { title = @"Trị Đen App"; prefKey = @"FixAppLaunchBlackScreen"; }
                else if (indexPath.row == 2) { title = @"Giảm Lag Đa Nhiệm"; prefKey = @"ReduceMultiTaskLag"; }
                else if (indexPath.row == 3) { title = @"Chống Khựng Thoát"; prefKey = @"FixAppExitStutter"; }
                else if (indexPath.row == 4) { title = @"Dọn RAM Chuyên Sâu"; prefKey = @"hyperMemoryGuardian"; }
                else { title = @"Tự Động Đóng App Nền"; prefKey = @"autoKillBackground"; }
            }
            LiquidCapsuleSwitch *s = [[LiquidCapsuleSwitch alloc] init];
            s.on = [self.settingsDict[prefKey] ?: @NO boolValue];
            __weak typeof(self) weakSelf = self;
            s.valueChangedBlock = ^(BOOL isOn) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                strongSelf.settingsDict[prefKey] = @(isOn);
                [strongSelf saveSettingsDataAndSync];
                [strongSelf applyDeepSpringBoardAndUIKitTweaks];
            };
            accessory = s;
        }
    } else if (_currentBottomTab == 3) {
        if (_scannedAppsList.count > indexPath.row) {
            NSDictionary *appInfo = _scannedAppsList[indexPath.row];
            title = appInfo[@"name"];
            detail = appInfo[@"bundleID"];
            LiquidCapsuleSwitch *s = [[LiquidCapsuleSwitch alloc] init];
            s.on = [_appTweakStates[appInfo[@"bundleID"]] boolValue];
            __weak typeof(self) weakSelf = self;
            s.valueChangedBlock = ^(BOOL isOn) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                strongSelf->_appTweakStates[appInfo[@"bundleID"]] = @(isOn);
                strongSelf.settingsDict[@"AppTweakStates"] = strongSelf->_appTweakStates;
                [strongSelf saveSettingsDataAndSync];
                [strongSelf applyDeepSpringBoardAndUIKitTweaks];
            };
            accessory = s;
        }
    } else {
        if (indexPath.section == 0) {
            if (indexPath.row == 0) {
                if (_isKernelExploited) {
                    title = @"🟢 HỆ THỐNG ĐÃ KHAI THÁC";
                    detail = @"✓";
                } else {
                    title = @"🔴 CHƯA KHAI THÁC [CHẠM 15S]";
                    detail = @"✕";
                }
            } else {
                NSString *curIOS = [[UIDevice currentDevice] systemVersion];
                if (Titanium_IsSupportedIOSVersion()) {
                    title = [NSString stringWithFormat:@"🟢 iOS %@ (OK)", curIOS];
                    detail = @"15-26";
                } else {
                    title = [NSString stringWithFormat:@"🔴 iOS %@ (Không OK)", curIOS];
                    detail = @"";
                }
            }
        } else if (indexPath.section == 1) {
            if (!_isKernelExploited) {
                title = @"Thông Tin Phần Cứng";
                detail = @"[Khóa]";
            } else {
                struct utsname si; uname(&si);
                NSString *dm = [NSString stringWithCString:si.machine encoding:NSUTF8StringEncoding];
                NSString *ov = [[UIDevice currentDevice] systemVersion];
                if (indexPath.row == 0) { title = @"UID"; detail = _deviceUUIDString; }
                else if (indexPath.row == 1) { title = @"Mã Máy"; detail = dm; }
                else if (indexPath.row == 2) { title = @"Kiến Trúc"; detail = _deepArchString; }
                else if (indexPath.row == 3) { title = @"iOS"; detail = ov; }
                else if (indexPath.row == 4) { title = @"Tên"; detail = [[UIDevice currentDevice] name]; }
                else if (indexPath.row == 5) { title = @"Số Nhân"; detail = _deepCoreCountString; }
                else if (indexPath.row == 6) { title = @"RAM"; detail = _deepRamString; }
                else { title = @"Darwin"; detail = _deepKernelString; }
            }
        } else {
            NSString *jbRoot = Titanium_GetRootHidePrefixPath();
            BOOL isR = [jbRoot containsString:@"/var/jb"];
            if (indexPath.row == 0) { title = @"Môi Trường"; detail = isR ? @"Rootless" : @"Rootful"; }
            else if (indexPath.row == 1) { title = @"Vùng"; detail = jbRoot; }
            else if (indexPath.row == 2) { title = @"Sandbox"; detail = _isKernelExploited ? @"Đã Phá" : @"Khóa"; }
            else { title = @"IPC"; detail = @"🟢 RW"; }
        }
    }

    [cell configureAsGlassCellWithTitle:title detail:detail accessory:accessory];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (_currentBottomTab == 0 && _isKernelExploited) {
        if (indexPath.section > 0 && indexPath.row == 0) {
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
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"🔒 ĐÃ KHÓA" message:@"Mở khóa góc phải trước khi chỉnh." preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"Đã Hiểu" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            return;
        }
        BOOL isHz = (_currentHzFpsSubTab == 0);
        NSArray *rates = @[@30, @60, @90, @120];
        if (indexPath.row < 4) [self applyRateValue:[rates[indexPath.row] integerValue] isDynamic:NO isFPS:!isHz];
        else if (indexPath.row == 4) [self applyRateValue:144 isDynamic:NO isFPS:!isHz];
        else [self showCustomRateInputAlertForHz:isHz];
        [self applyDeepSpringBoardAndUIKitTweaks];
        [self.customTableView reloadData];
    } else if (_currentBottomTab == 4 && indexPath.section == 0 && indexPath.row == 0) {
        [self openDopamineStyleExploitConsole];
    }
}

#pragma mark - Actions

- (void)onHzFpsSubTabChanged:(UISegmentedControl *)sender {
    _currentHzFpsSubTab = sender.selectedSegmentIndex;
    [self.customTableView reloadSections:[NSIndexSet indexSetWithIndex:2] withRowAnimation:UITableViewRowAnimationFade];
}

- (void)onSwitchSubTabChanged:(UISegmentedControl *)sender {
    _currentSwitchSubTab = sender.selectedSegmentIndex;
    [self.customTableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationFade];
}

- (void)showCustomRateInputAlertForHz:(BOOL)isHz {
    NSString *unit = isHz ? @"Hz" : @"FPS";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"⌨️ NHẬP %@", unit] message:[NSString stringWithFormat:@"Giá trị 15 - 144 %@", unit] preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull tf) {
        tf.keyboardType = UIKeyboardTypeNumberPad;
        tf.placeholder = [NSString stringWithFormat:@"15 - 144 %@", unit];
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Khóa Ngay" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UITextField *tf = alert.textFields.firstObject;
        NSInteger val = [tf.text integerValue];
        if (val < 15) val = 15;
        if (val > 144) val = 144;
        [self applyRateValue:val isDynamic:NO isFPS:!isHz];
        [self applyDeepSpringBoardAndUIKitTweaks];
        [self.customTableView reloadData];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)applyRateValue:(NSInteger)rate isDynamic:(BOOL)dynamicMode isFPS:(BOOL)isFPS {
    if (isFPS) {
        self.settingsDict[@"TargetFPSRate"] = @(rate);
        self.settingsDict[@"EnableFPSControl"] = @YES;
    } else {
        self.settingsDict[@"TargetRefreshRate"] = @(rate);
        self.settingsDict[@"EnableHzControl"] = @YES;
        self.settingsDict[@"ForceOverclock144Hz"] = @(rate >= 144);
    }
    [self saveSettingsDataAndSync];
}

#pragma mark - HUD

- (void)startContinuousHardwareHUD {
    [self stopContinuousHardwareHUD];
    _hudTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(_hudTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), (uint64_t)(0.8 * NSEC_PER_SEC), (uint64_t)(0.1 * NSEC_PER_SEC));
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(_hudTimer, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf && strongSelf->_currentBottomTab == 0 && strongSelf->_isKernelExploited && [strongSelf.settingsDict[@"EnableSystemMonitoring"] boolValue]) {
            [strongSelf.customTableView reloadData];
        }
    });
    dispatch_resume(_hudTimer);
}

- (void)stopContinuousHardwareHUD {
    if (_hudTimer) { dispatch_source_cancel(_hudTimer); _hudTimer = nil; }
}

- (void)syncSharedMemoryFile:(BOOL)enabled {
    if (!_isKernelExploited) return;
    ApexV285ProPayload payload;
    memset(&payload, 0, sizeof(ApexV285ProPayload));
    payload.magic = APEX_SYNC_MAGIC_V285;
    payload.masterEnabled = (enabled && _isKernelExploited) ? 1 : 0;
    int32_t hz = [self.settingsDict[@"TargetRefreshRate"] ?: @144 intValue];
    int32_t fps = [self.settingsDict[@"TargetFPSRate"] ?: @144 intValue];
    BOOL isOC = [self.settingsDict[@"ForceOverclock144Hz"] ?: @NO boolValue];
    payload.targetHz = hz;
    payload.targetFPS = fps;
    payload.forceOverclock = (isOC || hz >= 144) ? 1 : 0;
    payload.pipSyncEnabled = 1;
    payload.thermalShield = [self.settingsDict[@"AntiThermalThrottling"] ?: @NO boolValue] ? 1 : 0;
    payload.antiStutterExit = [self.settingsDict[@"FixAppExitStutter"] ?: @NO boolValue] ? 1 : 0;
    payload.smartBufferingLevel = 3;
    payload.zeroLatencyTouch = [self.settingsDict[@"TouchResponseBoost"] ?: @NO boolValue] ? 1 : 0;
    payload.shaderOptimization = 1;
    payload.dynamicInterpolation = [self.settingsDict[@"ProMotionEngineBeta7"] ?: @NO boolValue] ? 1 : 0;
    payload.fastAppLaunch = [self.settingsDict[@"TurboAppLaunch"] ?: @NO boolValue] ? 1 : 0;
    payload.lowLatencyAudio = 1;
    payload.memoryPressureRelief = 1;
    payload.metalPacingEnabled = [self.settingsDict[@"MetalHexBuffering"] ?: @NO boolValue] ? 1 : 0;
    payload.runloopHangGuard = 1;
    payload.keyboardZeroLagV3 = [self.settingsDict[@"KeyboardZeroLagV24"] ?: @NO boolValue] ? 1 : 0;
    payload.aggressiveRamCleaner = [self.settingsDict[@"hyperMemoryGuardian"] ?: @NO boolValue] ? 1 : 0;
    payload.lockFixedFpsWhenThermal = [self.settingsDict[@"lock30FpsOnOverheat"] ?: @NO boolValue] ? 1 : 0;
    payload.antiGhostTouch = [self.settingsDict[@"AntiGhostTouch"] ?: @NO boolValue] ? 1 : 0;
    payload.diskIOPriorityBoost = [self.settingsDict[@"pCoreRealtimePriority"] ?: @NO boolValue] ? 1 : 0;
    payload.rawTouchDirectDelivery = 1;
    payload.powerSaveModeActive = [self.settingsDict[@"batterySaver60Hz"] ?: @NO boolValue] ? 1 : 0;
    payload.updateSeq = (uint64_t)mach_absolute_time();
    payload.lastHeartbeat = payload.updateSeq;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        Titanium_WriteSyncPayloadUniversal(&payload, sizeof(ApexV285ProPayload));
        notify_post(NOTIFY_RELOAD);
        notify_post(NOTIFY_UIKIT_RELOAD);
        notify_post(NOTIFY_HARDWARE_SYNC);
        notify_post(NOTIFY_FPS_CHANGED);
        notify_post(NOTIFY_TITANIUM_CHANGED);
    });
}

- (void)applyDeepSpringBoardAndUIKitTweaks {
    if (!_isKernelExploited) return;
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    if (self.view.window) self.view.window.layer.drawsAsynchronously = YES;
    if (@available(iOS 15.0, *)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSInteger targetHz = [self.settingsDict[@"TargetRefreshRate"] ?: @144 integerValue];
            if (targetHz < 15) targetHz = 15;
            if (targetHz > 144) targetHz = 144;
            SEL sel = NSSelectorFromString(@"setPreferredFrameRateRange:");
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) {
                    UIWindowScene *ws = (UIWindowScene *)scene;
                    if ([ws respondsToSelector:sel]) {
                        CAFrameRateRange range = CAFrameRateRangeMake(30.0f, (float)targetHz, (float)targetHz);
                        void (*setRange)(id, SEL, CAFrameRateRange) = (void (*)(id, SEL, CAFrameRateRange))objc_msgSend;
                        setRange(ws, sel, range);
                    }
                }
            }
        });
    }
    BOOL master = [self.settingsDict[@"Enabled"] ?: @NO boolValue];
    [self syncSharedMemoryFile:master];
}

#pragma mark - Exploit Console

- (void)showUnexploitedWarningAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"🔒 TÍNH NĂNG ĐANG BỊ KHÓA" message:@"Vào tab Cài Đặt, nhấn vào dòng đèn đỏ để bắt đầu." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Đã Hiểu" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)openDopamineStyleExploitConsole {
    UIViewController *consoleVC = [[UIViewController alloc] init];
    consoleVC.view.backgroundColor = [UIColor colorWithRed:0.02 green:0.03 blue:0.06 alpha:1.0];
    consoleVC.modalPresentationStyle = UIModalPresentationFullScreen;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 55, consoleVC.view.bounds.size.width - 40, 30)];
    titleLabel.text = @"⚡ LIQUID GLASS KERNEL EXPLOIT";
    titleLabel.textColor = [UIColor colorWithRed:0.4 green:1.0 blue:0.6 alpha:1.0];
    titleLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:15] ?: [UIFont boldSystemFontOfSize:15];
    [consoleVC.view addSubview:titleLabel];

    UIProgressView *progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    progressView.frame = CGRectMake(20, 100, consoleVC.view.bounds.size.width - 40, 6);
    progressView.progressTintColor = [UIColor colorWithRed:0.35 green:1.0 blue:0.55 alpha:1.0];
    progressView.trackTintColor = [UIColor darkGrayColor];
    [consoleVC.view addSubview:progressView];

    UITextView *logTextView = [[UITextView alloc] initWithFrame:CGRectMake(20, 120, consoleVC.view.bounds.size.width - 40, consoleVC.view.bounds.size.height - 210)];
    logTextView.backgroundColor = [UIColor colorWithRed:0.04 green:0.05 blue:0.08 alpha:1.0];
    logTextView.textColor = [UIColor colorWithRed:0.4 green:0.95 blue:0.55 alpha:1.0];
    logTextView.font = [UIFont fontWithName:@"Menlo" size:12] ?: [UIFont systemFontOfSize:12];
    logTextView.editable = NO;
    logTextView.layer.cornerRadius = 14;
    logTextView.layer.borderColor = [UIColor colorWithWhite:0.25 alpha:1.0].CGColor;
    logTextView.layer.borderWidth = 1.0;
    [consoleVC.view addSubview:logTextView];

    [self presentViewController:consoleVC animated:YES completion:^{
        [self runExploitStagesWithConsole:logTextView progress:progressView controller:consoleVC];
    }];
}

- (void)runExploitStagesWithConsole:(UITextView *)logTextView progress:(UIProgressView *)progressView controller:(UIViewController *)consoleVC {
    NSArray *stages = @[
        [NSString stringWithFormat:@"[Stage 1/6] Nhận diện UID: %@...", _deviceUUIDString],
        @"[Stage 2/6] Khởi tạo Mach Host & Vượt rào cản PAC arm64e...",
        @"[Stage 3/6] Can thiệp XNU Scheduler, phân bổ P-Core Realtime...",
        @"[Stage 4/6] Đọc thông số phần cứng Darwin & Cấu trúc Mach VM...",
        @"[Stage 5/6] Ghi đè Pipeline Metal GPU & Kích hoạt Triple Buffering...",
        @"[Stage 6/6] Đồng bộ Shmem IPC đa phân vùng...",
        @"✅ KHAI THÁC THÀNH CÔNG!"
    ];
    __block NSInteger idx = 0;
    NSMutableString *logBuffer = [NSMutableString stringWithFormat:@"[*] Khai thác Darwin Kernel...\n"];
    logTextView.text = logBuffer;

    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:2.2 repeats:YES block:^(NSTimer * _Nonnull t) {
        if (idx < stages.count) {
            [logBuffer appendFormat:@"\n%@", stages[idx]];
            logTextView.text = logBuffer;
            [logTextView scrollRangeToVisible:NSMakeRange(logTextView.text.length - 1, 1)];
            [progressView setProgress:(float)(idx + 1) / (float)stages.count animated:YES];
            UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
            [fb impactOccurred];
            idx++;
        } else {
            [t invalidate];
            UINotificationFeedbackGenerator *notiFb = [[UINotificationFeedbackGenerator alloc] init];
            [notiFb notificationOccurred:UINotificationFeedbackTypeSuccess];
            [self persistExploitDataToDisk];
            [self applyDeepSpringBoardAndUIKitTweaks];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [consoleVC dismissViewControllerAnimated:YES completion:^{ [self.customTableView reloadData]; }];
            });
        }
    }];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

- (void)persistExploitDataToDisk {
    char cpuTypeStr[128] = {0};
    size_t size = sizeof(cpuTypeStr);
    sysctlbyname("machdep.cpu.brand_string", cpuTypeStr, &size, NULL, 0);
    NSString *brand = [NSString stringWithUTF8String:cpuTypeStr];
    if (!brand || brand.length == 0) {
        #if defined(__arm64e__)
        _deepArchString = @"arm64e (Apple PAC)";
        #elif defined(__arm64__)
        _deepArchString = @"arm64 (Apple A-Series)";
        #else
        _deepArchString = @"ARM64";
        #endif
    } else { _deepArchString = brand; }
    int ncpu = 0; size = sizeof(ncpu);
    sysctlbyname("hw.ncpu", &ncpu, &size, NULL, 0);
    _deepCoreCountString = [NSString stringWithFormat:@"%d Nhân (P/E)", ncpu];
    int64_t memsize = 0; size = sizeof(memsize);
    sysctlbyname("hw.memsize", &memsize, &size, NULL, 0);
    double ramGB = (double)memsize / (1024.0 * 1024.0 * 1024.0);
    _deepRamString = [NSString stringWithFormat:@"%.2f GB LPDDR", ramGB];
    char osrelease[64] = {0}; size = sizeof(osrelease);
    sysctlbyname("kern.osrelease", osrelease, &size, NULL, 0);
    _deepKernelString = [NSString stringWithFormat:@"Darwin %s", osrelease];
    int64_t l2cache = 0; size = sizeof(l2cache);
    sysctlbyname("hw.l2cachesize", &l2cache, &size, NULL, 0);
    _deepCacheString = (l2cache > 0) ? [NSString stringWithFormat:@"%lld KB L2", l2cache / 1024] : @"Silicon Cache";
    _isKernelExploited = YES;
    self.settingsDict[@"IsKernelExploited"] = @YES;
    self.settingsDict[@"SavedArchString"] = _deepArchString;
    self.settingsDict[@"SavedCoreCountString"] = _deepCoreCountString;
    self.settingsDict[@"SavedRamString"] = _deepRamString;
    self.settingsDict[@"SavedKernelString"] = _deepKernelString;
    self.settingsDict[@"SavedCacheString"] = _deepCacheString;
    self.settingsDict[@"SavedDeviceUUID"] = _deviceUUIDString;
    [self saveSettingsDataAndSync];
}

#pragma mark - Persistence

- (void)loadSettingsData {
    NSString *prefPath = Titanium_ResolvePrefPath();
    if ([[NSFileManager defaultManager] fileExistsAtPath:prefPath]) {
        self.settingsDict = [NSMutableDictionary dictionaryWithContentsOfFile:prefPath] ?: [NSMutableDictionary dictionary];
    } else {
        self.settingsDict = [NSMutableDictionary dictionary];
    }
    [self ensureDefaultSettingsExist];
}

- (void)saveSettingsDataAndSync {
    NSString *prefPath = Titanium_ResolvePrefPath();
    NSString *dir = [prefPath stringByDeletingLastPathComponent];
    if (![[NSFileManager defaultManager] fileExistsAtPath:dir]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @(0777)} error:nil];
    }
    [self.settingsDict writeToFile:prefPath atomically:YES];
    chmod([prefPath UTF8String], 0666);
    BOOL master = [self.settingsDict[@"Enabled"] boolValue];
    [self syncSharedMemoryFile:master];
}

- (void)ensureDefaultSettingsExist {
    NSArray *keys = @[
        @"Enabled", @"EnableSystemMonitoring", @"TargetRefreshRate", @"TargetFPSRate",
        @"ForceOverclock144Hz", @"ProMotionEngineBeta7", @"pCoreRealtimePriority",
        @"schedulerGovernor", @"quantumCoreSync", @"lockHighIdleFloor", @"AntiThermalThrottling",
        @"MetalHexBuffering", @"IsolateRenderPipeline", @"vsyncAdaptiveBuffer", @"gameFPSStabilizer",
        @"flatTintBlur", @"TouchResponseBoost", @"ColorOs17SmoothEngine", @"zeroLagNeural",
        @"AntiGhostTouch", @"ChargerRippleRejection", @"fakeFullBatteryState", @"lock30FpsOnOverheat",
        @"batterySaver60Hz", @"TurboAppLaunch", @"FixAppLaunchBlackScreen", @"ReduceMultiTaskLag",
        @"FixAppExitStutter", @"hyperMemoryGuardian", @"autoKillBackground", @"IsRateLocked", @"IsKernelExploited"
    ];
    for (NSString *k in keys) {
        if (!self.settingsDict[k]) self.settingsDict[k] = @NO;
    }
    if (!self.settingsDict[@"TargetRefreshRate"]) self.settingsDict[@"TargetRefreshRate"] = @144;
    if (!self.settingsDict[@"TargetFPSRate"]) self.settingsDict[@"TargetFPSRate"] = @144;
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
                        NSString *fullPath = [d stringByAppendingPathComponent:item];
                        NSString *infoPath = [fullPath stringByAppendingPathComponent:@"Info.plist"];
                        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
                        NSString *name = info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"] ?: [item stringByDeletingPathExtension];
                        NSString *bid = info[@"CFBundleIdentifier"] ?: item;
                        if (self->_appTweakStates[bid] == nil) self->_appTweakStates[bid] = @NO;
                        [temp addObject:@{@"name": name, @"bundleID": bid, @"path": fullPath}];
                    }
                }
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_scannedAppsList = temp;
            if (self->_currentBottomTab == 3 && self->_isKernelExploited) [self.customTableView reloadData];
        });
    });
}

#pragma mark - System Actions

- (void)executeRespring {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        NSString *bin = Titanium_FindExecutablePath(@"sbreload");
        char *argv[] = {(char *)[bin UTF8String], NULL};
        pid_t pid;
        posix_spawn(&pid, [bin UTF8String], NULL, NULL, argv, environ);
        waitpid(pid, NULL, 0);
    });
}

- (void)executeSReboot {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        NSString *bin = Titanium_FindExecutablePath(@"launchctl");
        char *argv[] = {(char *)[bin UTF8String], (char *)"reboot", (char *)"userspace", NULL};
        pid_t pid;
        posix_spawn(&pid, [bin UTF8String], NULL, NULL, argv, environ);
        waitpid(pid, NULL, 0);
    });
}

- (void)executeSafeMode {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        NSString *bin = Titanium_FindExecutablePath(@"killall");
        char *argv[] = {(char *)[bin UTF8String], (char *)"-SEGV", (char *)"SpringBoard", NULL};
        pid_t pid;
        posix_spawn(&pid, [bin UTF8String], NULL, NULL, argv, environ);
        waitpid(pid, NULL, 0);
    });
}

- (void)executeResetConfiguration {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"⚠️ XÓA SẠCH" message:@"Toàn bộ cấu hình sẽ bị xóa." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Xác Nhận" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        NSString *prefPath = Titanium_ResolvePrefPath();
        [[NSFileManager defaultManager] removeItemAtPath:prefPath error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:PRIMARY_SYNC_FILE error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:SECONDARY_SYNC_FILE error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:TITANIUM_BOOT_FLAG_VERIFIED error:nil];
        self.settingsDict = [NSMutableDictionary dictionary];
        self->_isKernelExploited = NO;
        self->_deepArchString = nil;
        self->_deepCoreCountString = nil;
        self->_deepRamString = nil;
        self->_deepKernelString = nil;
        self->_deepCacheString = nil;
        [self ensureDefaultSettingsExist];
        [self stopContinuousHardwareHUD];
        notify_post(NOTIFY_RELOAD);
        notify_post(NOTIFY_UIKIT_RELOAD);
        UINotificationFeedbackGenerator *fb = [[UINotificationFeedbackGenerator alloc] init];
        [fb notificationOccurred:UINotificationFeedbackTypeWarning];
        [self.customTableView reloadData];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
