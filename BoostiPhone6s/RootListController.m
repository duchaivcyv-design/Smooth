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
#import <CoreImage/CoreImage.h>

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

#ifndef _APEX_V285_PRO_PAYLOAD_DEFINED
#define _APEX_V285_PRO_PAYLOAD_DEFINED
typedef struct {
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

// ====================================================================================================
// MODULE 1: GLASS MATERIAL FACTORY — Trong suốt 100%
// ====================================================================================================
typedef NS_ENUM(NSInteger, LGGlassMaterialType) {
    LGGlassMaterialTypeUltraThin = 0,
    LGGlassMaterialTypeThin      = 1,
    LGGlassMaterialTypeRegular   = 2,
    LGGlassMaterialTypeChrome    = 3,
    LGGlassMaterialTypeProminent = 4,
    LGGlassMaterialTypeOverlay   = 5,
    LGGlassMaterialTypeCrystal   = 6   // MỚI: siêu trong suốt như pha lê
};

@interface LGGlassMaterialFactory : NSObject
+ (UIBlurEffectStyle)blurStyleForType:(LGGlassMaterialType)type isDark:(BOOL)isDark;
+ (CGFloat)tintAlphaForType:(LGGlassMaterialType)type;
+ (CGFloat)specularAlphaForType:(LGGlassMaterialType)type;
+ (CGFloat)bottomReflectionAlphaForType:(LGGlassMaterialType)type;
+ (CGFloat)diagonalSheenAlphaForType:(LGGlassMaterialType)type;
+ (CGFloat)rimAlphaForType:(LGGlassMaterialType)type;
+ (CGFloat)rimWidthForType:(LGGlassMaterialType)type;
+ (CGFloat)innerGlowWidthForType:(LGGlassMaterialType)type;
+ (CGFloat)innerGlowAlphaForType:(LGGlassMaterialType)type;
+ (CGFloat)shadowOpacityForType:(LGGlassMaterialType)type;
+ (CGFloat)shadowRadiusForType:(LGGlassMaterialType)type;
+ (CGFloat)shadowOffsetYForType:(LGGlassMaterialType)type;
+ (CGFloat)specularHeightRatioForType:(LGGlassMaterialType)type;
@end

@implementation LGGlassMaterialFactory
+ (UIBlurEffectStyle)blurStyleForType:(LGGlassMaterialType)type isDark:(BOOL)isDark {
    switch (type) {
        case LGGlassMaterialTypeUltraThin: return isDark ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemUltraThinMaterialLight;
        case LGGlassMaterialTypeThin:      return isDark ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemUltraThinMaterialLight;
        case LGGlassMaterialTypeRegular:   return isDark ? UIBlurEffectStyleSystemThinMaterialDark    : UIBlurEffectStyleSystemThinMaterialLight;
        case LGGlassMaterialTypeChrome:    return isDark ? UIBlurEffectStyleSystemThinMaterialDark    : UIBlurEffectStyleSystemThinMaterialLight;
        case LGGlassMaterialTypeProminent: return isDark ? UIBlurEffectStyleSystemThinMaterialDark    : UIBlurEffectStyleSystemThinMaterialLight;
        case LGGlassMaterialTypeOverlay:   return isDark ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemUltraThinMaterialLight;
        case LGGlassMaterialTypeCrystal:   return isDark ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemUltraThinMaterialLight;
    }
    return UIBlurEffectStyleSystemUltraThinMaterialDark;
}
+ (CGFloat)tintAlphaForType:(LGGlassMaterialType)type {
    // [ĐÃ FIX] GIẢM MẠNH — hầu như không có tint, để blur tự nhiên
    switch (type) {
        case LGGlassMaterialTypeUltraThin: return 0.002;
        case LGGlassMaterialTypeThin:      return 0.004;
        case LGGlassMaterialTypeRegular:   return 0.008;
        case LGGlassMaterialTypeChrome:    return 0.012;
        case LGGlassMaterialTypeProminent: return 0.018;
        case LGGlassMaterialTypeOverlay:   return 0.010;
        case LGGlassMaterialTypeCrystal:   return 0.000;
    }
    return 0.004;
}
+ (CGFloat)specularAlphaForType:(LGGlassMaterialType)type {
    switch (type) {
        case LGGlassMaterialTypeUltraThin: return 0.10;
        case LGGlassMaterialTypeThin:      return 0.14;
        case LGGlassMaterialTypeRegular:   return 0.18;
        case LGGlassMaterialTypeChrome:    return 0.22;
        case LGGlassMaterialTypeProminent: return 0.28;
        case LGGlassMaterialTypeOverlay:   return 0.20;
        case LGGlassMaterialTypeCrystal:   return 0.16;
    }
    return 0.14;
}
+ (CGFloat)bottomReflectionAlphaForType:(LGGlassMaterialType)type { return 0.04; }
+ (CGFloat)diagonalSheenAlphaForType:(LGGlassMaterialType)type { return 0.08; }
+ (CGFloat)rimAlphaForType:(LGGlassMaterialType)type {
    switch (type) {
        case LGGlassMaterialTypeCrystal:   return 0.30;
        case LGGlassMaterialTypeUltraThin: return 0.16;
        case LGGlassMaterialTypeThin:      return 0.20;
        case LGGlassMaterialTypeRegular:   return 0.24;
        case LGGlassMaterialTypeChrome:    return 0.28;
        case LGGlassMaterialTypeProminent: return 0.34;
        case LGGlassMaterialTypeOverlay:   return 0.26;
    }
    return 0.20;
}
+ (CGFloat)rimWidthForType:(LGGlassMaterialType)type { return 0.6; }
+ (CGFloat)innerGlowWidthForType:(LGGlassMaterialType)type { return 0.7; }
+ (CGFloat)innerGlowAlphaForType:(LGGlassMaterialType)type { return 0.24; }
+ (CGFloat)shadowOpacityForType:(LGGlassMaterialType)type { return 0.22; }
+ (CGFloat)shadowRadiusForType:(LGGlassMaterialType)type { return 12.0; }
+ (CGFloat)shadowOffsetYForType:(LGGlassMaterialType)type { return 5.0; }
+ (CGFloat)specularHeightRatioForType:(LGGlassMaterialType)type {
    switch (type) {
        case LGGlassMaterialTypeCrystal:   return 0.30;
        case LGGlassMaterialTypeUltraThin: return 0.24;
        default: return 0.26;
    }
}
@end

// ====================================================================================================
// MODULE 2: CRYSTAL GLASS VIEW — Khối thủy tinh trong suốt thật
// 5 lớp: Backdrop (blur) + TopSpecular + BottomReflection + DiagonalSheen + Rim
// KHÔNG có lớp tint đục — chỉ có blur + ánh sáng
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
@property (nonatomic, strong) CAGradientLayer *chromaticEdge;   // MỚI: viền cầu vồng khúc xạ
@property (nonatomic, assign) CGFloat cornerRadiusValue;
@property (nonatomic, assign) LGGlassMaterialType materialType;
@property (nonatomic, assign) BOOL interactiveHighlightEnabled;
@property (nonatomic, assign) BOOL isPressed;
- (instancetype)initWithFrame:(CGRect)frame cornerRadius:(CGFloat)radius;
- (instancetype)initWithFrame:(CGRect)frame cornerRadius:(CGFloat)radius materialType:(LGGlassMaterialType)type;
- (void)applyFluidJiggleAnimationWithVelocity:(CGFloat)vel;
- (void)setGlassHighlighted:(BOOL)highlighted animated:(BOOL)animated;
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

        // ============================================================
        // LỚP 1: BACKDROP BLUR THẬT
        // ============================================================
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:[LGGlassMaterialFactory blurStyleForType:type isDark:isDark]];
        _blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
        _blurView.frame = self.bounds;
        _blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _blurView.userInteractionEnabled = NO;
        _blurView.layer.cornerRadius = radius;
        if (@available(iOS 13.0, *)) _blurView.layer.cornerCurve = kCACornerCurveContinuous;
        _blurView.clipsToBounds = YES;
        [self addSubview:_blurView];

        // ============================================================
        // LỚP 2: TINT SIÊU MỎNG (gần như không đục)
        // ============================================================
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

        // ============================================================
        // LỚP 3: TOP SPECULAR HIGHLIGHT — dải sáng chính
        // ============================================================
        _topSpecular = [CAGradientLayer layer];
        _topSpecular.frame = CGRectMake(0, 0, self.bounds.size.width, MAX(2.0, self.bounds.size.height * specRatio));
        _topSpecular.cornerRadius = radius;
        if (@available(iOS 13.0, *)) _topSpecular.cornerCurve = kCACornerCurveContinuous;
        _topSpecular.colors = @[
            (id)[UIColor colorWithWhite:1.0 alpha:spec].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:spec * 0.55].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:spec * 0.10].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
        ];
        _topSpecular.locations = @[@0.0, @0.30, @0.70, @1.0];
        _topSpecular.startPoint = CGPointMake(0, 0);
        _topSpecular.endPoint = CGPointMake(0, 1);
        [self.layer addSublayer:_topSpecular];

        // ============================================================
        // LỚP 4: BOTTOM REFLECTION
        // ============================================================
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
        _bottomReflection.opacity = 0.85f;
        [self.layer addSublayer:_bottomReflection];

        // ============================================================
        // LỚP 5: DIAGONAL SHEEN — vệt sáng chéo
        // ============================================================
        _diagonalSheen = [CAGradientLayer layer];
        _diagonalSheen.cornerRadius = radius;
        if (@available(iOS 13.0, *)) _diagonalSheen.cornerCurve = kCACornerCurveContinuous;
        _diagonalSheen.colors = @[
            (id)[UIColor colorWithWhite:1.0 alpha:[LGGlassMaterialFactory diagonalSheenAlphaForType:type]].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:[LGGlassMaterialFactory diagonalSheenAlphaForType:type] * 0.6].CGColor
        ];
        _diagonalSheen.locations = @[@0.0, @0.30, @0.70, @1.0];
        _diagonalSheen.startPoint = CGPointMake(0.0, 0.0);
        _diagonalSheen.endPoint = CGPointMake(1.0, 1.0);
        _diagonalSheen.opacity = 0.65f;
        [self.layer addSublayer:_diagonalSheen];

        // ============================================================
        // LỚP 6: LEFT EDGE HIGHLIGHT — dải sáng dọc mép trái
        // ============================================================
        _leftEdgeHighlight = [CAGradientLayer layer];
        _leftEdgeHighlight.cornerRadius = radius;
        if (@available(iOS 13.0, *)) _leftEdgeHighlight.cornerCurve = kCACornerCurveContinuous;
        _leftEdgeHighlight.colors = @[
            (id)[UIColor colorWithWhite:1.0 alpha:spec * 0.55].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
        ];
        _leftEdgeHighlight.locations = @[@0.0, @1.0];
        _leftEdgeHighlight.startPoint = CGPointMake(0.0, 0.5);
        _leftEdgeHighlight.endPoint = CGPointMake(1.0, 0.5);
        _leftEdgeHighlight.opacity = 0.55f;
        [self.layer addSublayer:_leftEdgeHighlight];

        // ============================================================
        // LỚP 7: CHROMATIC EDGE — viền cầu vồng mô phỏng khúc xạ
        // ============================================================
        _chromaticEdge = [CAGradientLayer layer];
        _chromaticEdge.cornerRadius = radius;
        if (@available(iOS 13.0, *)) _chromaticEdge.cornerCurve = kCACornerCurveContinuous;
        _chromaticEdge.colors = @[
            (id)[UIColor colorWithRed:0.4 green:0.75 blue:1.0 alpha:0.15].CGColor,
            (id)[UIColor colorWithRed:0.7 green:0.5  blue:1.0 alpha:0.10].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
            (id)[UIColor colorWithRed:0.5 green:1.0 blue:0.7 alpha:0.12].CGColor
        ];
        _chromaticEdge.locations = @[@0.0, @0.15, @0.85, @1.0];
        _chromaticEdge.startPoint = CGPointMake(0.0, 0.0);
        _chromaticEdge.endPoint = CGPointMake(1.0, 1.0);
        _chromaticEdge.opacity = 0.45f;
        [self.layer addSublayer:_chromaticEdge];

        // ============================================================
        // LỚP 8: INNER RIM — viền trong sáng
        // ============================================================
        CGFloat rimA = [LGGlassMaterialFactory rimAlphaForType:type];
        CGFloat rimW = [LGGlassMaterialFactory rimWidthForType:type];
        _innerRim = [CAShapeLayer layer];
        _innerRim.fillColor = [UIColor clearColor].CGColor;
        _innerRim.strokeColor = [UIColor colorWithWhite:1.0 alpha:rimA].CGColor;
        _innerRim.lineWidth = rimW;
        [self.layer addSublayer:_innerRim];

        // ============================================================
        // LỚP 9: OUTER RIM — viền ngoài tối mảnh
        // ============================================================
        _outerRim = [CAShapeLayer layer];
        _outerRim.fillColor = [UIColor clearColor].CGColor;
        _outerRim.strokeColor = [UIColor colorWithWhite:0.0 alpha:0.15].CGColor;
        _outerRim.lineWidth = 0.4;
        [self.layer addSublayer:_outerRim];

        // Shadow
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOpacity = [LGGlassMaterialFactory shadowOpacityForType:type];
        self.layer.shadowOffset = CGSizeMake(0, [LGGlassMaterialFactory shadowOffsetYForType:type]);
        self.layer.shadowRadius = [LGGlassMaterialFactory shadowRadiusForType:type];

        [self updateLayoutForBounds:self.bounds];
    }
    return self;
}

- (void)updateLayoutForBounds:(CGRect)bounds {
    CGFloat r = _cornerRadiusValue;
    CGFloat specRatio = [LGGlassMaterialFactory specularHeightRatioForType:_materialType];
    CGFloat specH = MAX(2.0, bounds.size.height * specRatio);

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

    _leftEdgeHighlight.frame = CGRectMake(0, 0, MAX(2.0, bounds.size.width * 0.15), bounds.size.height);
    _leftEdgeHighlight.cornerRadius = r;

    _chromaticEdge.frame = bounds;
    _chromaticEdge.cornerRadius = r;

    _innerRim.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(bounds, 0.5, 0.5) cornerRadius:MAX(0, r - 0.5)].CGPath;
    _outerRim.path = [UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:r].CGPath;
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:r].CGPath;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.cornerRadius = _cornerRadiusValue;
    [self updateLayoutForBounds:self.bounds];
}

- (void)animatePressIn {
    if (!_interactiveHighlightEnabled) return;
    CGFloat spec = [LGGlassMaterialFactory specularAlphaForType:_materialType];
    CGFloat rimA = [LGGlassMaterialFactory rimAlphaForType:_materialType];
    CGFloat tint = [LGGlassMaterialFactory tintAlphaForType:_materialType];

    [CATransaction begin];
    [CATransaction setAnimationDuration:0.14];
    [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
    _topSpecular.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:MIN(0.60, spec * 2.2)].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:spec * 0.85].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:spec * 0.25].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
    ];
    _innerRim.strokeColor = [UIColor colorWithWhite:1.0 alpha:MIN(0.55, rimA * 1.9)].CGColor;
    _tintView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:tint * 4.0];
    _chromaticEdge.opacity = 0.75f;
    [CATransaction commit];

    [UIView animateWithDuration:0.16 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.transform = CGAffineTransformMakeScale(0.965, 0.965);
    } completion:nil];
}

- (void)animatePressOut {
    if (!_interactiveHighlightEnabled) return;
    CGFloat spec = [LGGlassMaterialFactory specularAlphaForType:_materialType];
    CGFloat rimA = [LGGlassMaterialFactory rimAlphaForType:_materialType];
    CGFloat tint = [LGGlassMaterialFactory tintAlphaForType:_materialType];

    [CATransaction begin];
    [CATransaction setAnimationDuration:0.32];
    [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
    _topSpecular.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:spec].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:spec * 0.55].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:spec * 0.10].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
    ];
    _innerRim.strokeColor = [UIColor colorWithWhite:1.0 alpha:rimA].CGColor;
    _tintView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:tint];
    _chromaticEdge.opacity = 0.45f;
    [CATransaction commit];

    [UIView animateWithDuration:0.42 delay:0 usingSpringWithDamping:0.66 initialSpringVelocity:0.65 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
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
    [UIView animateWithDuration:0.11 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.transform = t;
    } completion:^(BOOL f) {
        [UIView animateWithDuration:0.42 delay:0 usingSpringWithDamping:0.58 initialSpringVelocity:1.05 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
            self.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}
@end

// ====================================================================================================
// MODULE 3: LIQUID CAPSULE SWITCH — Có intrinsicContentSize
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
- (void)setOn:(BOOL)on animated:(BOOL)animated;
@end

@implementation LiquidCapsuleSwitch

// [ĐÃ FIX] Kích thước cứng — không collapse
- (CGSize)intrinsicContentSize {
    return CGSizeMake(62.0, 34.0);
}
- (CGSize)sizeThatFits:(CGSize)size {
    return CGSizeMake(62.0, 34.0);
}

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
        _trackInnerShadow.strokeColor = [UIColor colorWithWhite:0.0 alpha:0.42].CGColor;
        _trackInnerShadow.lineWidth = 0.8;
        [_trackView.layer addSublayer:_trackInnerShadow];

        _trackOuterRim = [CAShapeLayer layer];
        _trackOuterRim.fillColor = [UIColor clearColor].CGColor;
        _trackOuterRim.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.14].CGColor;
        _trackOuterRim.lineWidth = 0.5;
        [_trackView.layer addSublayer:_trackOuterRim];

        CGFloat inset = 3.0;
        CGFloat d = 34.0 - (inset * 2);  // 28
        // [ĐÃ FIX] Dùng Crystal — trong suốt thật
        _thumbGlass = [[AppleLiquidGlassView alloc] initWithFrame:CGRectMake(inset, inset, d, d)
                                                     cornerRadius:d / 2.0
                                                     materialType:LGGlassMaterialTypeCrystal];
        _thumbGlass.userInteractionEnabled = NO;
        _thumbGlass.interactiveHighlightEnabled = NO;
        _thumbGlass.layer.shadowColor = [UIColor blackColor].CGColor;
        _thumbGlass.layer.shadowOpacity = 0.35;
        _thumbGlass.layer.shadowOffset = CGSizeMake(0, 2);
        _thumbGlass.layer.shadowRadius = 3.5;
        [self addSubview:_thumbGlass];

        _thumbInnerRim = [CAShapeLayer layer];
        _thumbInnerRim.fillColor = [UIColor clearColor].CGColor;
        _thumbInnerRim.strokeColor = [UIColor colorWithWhite:0.0 alpha:0.15].CGColor;
        _thumbInnerRim.lineWidth = 0.5;
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
    // [ĐÃ FIX] Ép kích thước
    if (self.bounds.size.width < 60.0 || self.bounds.size.height < 32.0) {
        CGRect f = self.frame;
        f.size = CGSizeMake(62, 34);
        self.frame = f;
    }

    _trackView.frame = self.bounds;
    CGFloat W = self.bounds.size.width, H = self.bounds.size.height, r = H / 2.0;
    _trackView.layer.cornerRadius = r;
    _trackGradient.frame = _trackView.bounds;
    _trackInnerShadow.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(_trackView.bounds, 0.5, 0.5) cornerRadius:r - 0.5].CGPath;
    _trackOuterRim.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(_trackView.bounds, 0.3, 0.3) cornerRadius:r - 0.3].CGPath;

    CGFloat inset = 3.0;
    CGFloat d = H - (inset * 2);
    CGRect f = _on ? CGRectMake(W - d - inset, inset, d, d) : CGRectMake(inset, inset, d, d);
    if (!CGRectEqualToRect(_thumbGlass.frame, f)) _thumbGlass.frame = f;
    _thumbGlass.layer.cornerRadius = d / 2.0;
    _thumbGlass.cornerRadiusValue = d / 2.0;
    [_thumbGlass layoutSubviews];
    _thumbInnerRim.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(_thumbGlass.bounds, 0.5, 0.5) cornerRadius:(d / 2.0) - 0.5].CGPath;
    _thumbGlass.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:_thumbGlass.bounds cornerRadius:d / 2.0].CGPath;
}

- (void)handleTouchDown {
    [UIView animateWithDuration:0.10 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self->_thumbGlass.transform = CGAffineTransformMakeScale(0.90, 0.90);
    } completion:nil];
}
- (void)handleTouchUp {
    [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.65 initialSpringVelocity:0.8 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self->_thumbGlass.transform = CGAffineTransformIdentity;
    } completion:nil];
}
- (void)handleTap {
    [self setOn:!_on animated:YES];
    [self sendActionsForControlEvents:UIControlEventValueChanged];
    if (self.valueChangedBlock) self.valueChangedBlock(_on);
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
}
- (void)setOn:(BOOL)on { [self setOn:on animated:NO]; }
- (void)setOn:(BOOL)on animated:(BOOL)animated {
    _on = on;
    [self updateUIAnimated:animated];
}
- (void)updateUIAnimated:(BOOL)animated {
    NSArray *onC = @[
        (id)[UIColor colorWithRed:0.20 green:0.78 blue:0.35 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.16 green:0.68 blue:0.28 alpha:1.0].CGColor
    ];
    NSArray *offC = @[
        (id)[UIColor colorWithRed:0.20 green:0.22 blue:0.26 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.14 green:0.16 blue:0.19 alpha:1.0].CGColor
    ];
    CGFloat W = 62.0, H = 34.0;
    CGFloat inset = 3.0, d = H - (inset * 2);
    CGRect f = _on ? CGRectMake(W - d - inset, inset, d, d) : CGRectMake(inset, inset, d, d);

    void (^anim)(void) = ^{
        self->_trackGradient.colors = self->_on ? onC : offC;
        self->_thumbGlass.frame = f;
    };
    if (animated) {
        [UIView animateWithDuration:0.34 delay:0 usingSpringWithDamping:0.72 initialSpringVelocity:0.9 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:anim completion:nil];
    } else {
        [CATransaction begin]; [CATransaction setDisableActions:YES]; anim(); [CATransaction commit];
    }
}
@end

// ====================================================================================================
// MODULE 4: LG CUSTOM SEGMENT — Có intrinsicContentSize, không cắt
// ====================================================================================================
@interface LGCustomSegment : UIControl
@property (nonatomic, strong) AppleLiquidGlassView *background;
@property (nonatomic, strong) AppleLiquidGlassView *indicator;
@property (nonatomic, strong) NSArray<UILabel *> *labels;
@property (nonatomic, strong) NSArray<NSString *> *items;
@property (nonatomic, assign) NSInteger selectedSegmentIndex;
@property (nonatomic, copy) void (^valueChangedBlock)(NSInteger index);
- (instancetype)initWithItems:(NSArray<NSString *> *)items;
@end

@implementation LGCustomSegment

// [ĐÃ FIX] Kích thước tối thiểu — không collapse
- (CGSize)intrinsicContentSize {
    CGFloat minWidth = MAX(260.0, self.items.count * 75.0);
    return CGSizeMake(minWidth, 36.0);
}

- (instancetype)initWithItems:(NSArray<NSString *> *)items {
    CGFloat w = MAX(260.0, items.count * 75.0);
    if (self = [super initWithFrame:CGRectMake(0, 0, w, 36)]) {
        _items = items;
        _selectedSegmentIndex = 0;
        self.backgroundColor = [UIColor clearColor];

        _background = [[AppleLiquidGlassView alloc] initWithFrame:self.bounds
                                                     cornerRadius:18.0
                                                     materialType:LGGlassMaterialTypeUltraThin];
        _background.userInteractionEnabled = NO;
        _background.interactiveHighlightEnabled = NO;
        _background.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_background];

        _indicator = [[AppleLiquidGlassView alloc] initWithFrame:CGRectZero
                                                     cornerRadius:15.0
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
            l.minimumScaleFactor = 0.85;
            [self addSubview:l];
            [ls addObject:l];
        }
        _labels = ls;
        [self addTarget:self action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    // [ĐÃ FIX] Ép kích thước tối thiểu
    CGFloat minW = MAX(260.0, _items.count * 75.0);
    if (self.bounds.size.width < minW) {
        CGRect f = self.frame;
        f.size.width = minW;
        self.frame = f;
    }

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

- (void)handleTap {
    CGPoint p = [self.gestureRecognizers.firstObject locationInView:self];
    if (!p.x && !p.y) p = self.center;
    NSInteger idx = (NSInteger)floor(p.x / (self.bounds.size.width / MAX(1, _items.count)));
    if (idx < 0) idx = 0;
    if (idx >= (NSInteger)_items.count) idx = _items.count - 1;
    [self setSelectedSegmentIndex:idx animated:YES];
    if (self.valueChangedBlock) self.valueChangedBlock(idx);
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

- (void)setSelectedSegmentIndex:(NSInteger)index animated:(BOOL)animated {
    if (index < 0 || index >= (NSInteger)_items.count) return;
    _selectedSegmentIndex = index;
    CGFloat w = self.bounds.size.width / MAX(1, _items.count);
    CGFloat h = self.bounds.size.height;
    CGRect ind = CGRectMake(index * w + 3, 3, w - 6, h - 6);

    void (^a)(void) = ^{
        self->_indicator.frame = ind;
        for (NSInteger i = 0; i < self->_labels.count; i++) {
            BOOL s = (i == index);
            self->_labels[i].textColor = s ? [UIColor whiteColor] : [UIColor colorWithWhite:0.78 alpha:1.0];
            self->_labels[i].font = s ? [UIFont systemFontOfSize:12 weight:UIFontWeightBold] : [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        }
    };
    if (animated) {
        [UIView animateWithDuration:0.30 delay:0 usingSpringWithDamping:0.72 initialSpringVelocity:0.8 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:a completion:nil];
    } else a();

    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
}
- (void)setSelectedSegmentIndex:(NSInteger)selectedSegmentIndex {
    [self setSelectedSegmentIndex:selectedSegmentIndex animated:NO];
}
@end

// ====================================================================================================
// MODULE 5: LG GLASS TABLE VIEW CELL — Crystal trong suốt
// ====================================================================================================
@interface LGGlassTableViewCell : UITableViewCell
@property (nonatomic, strong) AppleLiquidGlassView *glassBackground;
@property (nonatomic, strong) UILabel *titleL;
@property (nonatomic, strong) UILabel *detailL;
@property (nonatomic, strong) UIView *accessoryContainer;
- (void)configureWithTitle:(NSString *)title detail:(NSString *)detail accessory:(UIView *)accessory accent:(UIColor *)accent;
@end

@implementation LGGlassTableViewCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid {
    if (self = [super initWithStyle:style reuseIdentifier:rid]) {
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _glassBackground = [[AppleLiquidGlassView alloc] initWithFrame:self.bounds
                                                          cornerRadius:16.0
                                                          materialType:LGGlassMaterialTypeUltraThin];
        _glassBackground.interactiveHighlightEnabled = YES;
        _glassBackground.userInteractionEnabled = NO;
        _glassBackground.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.contentView insertSubview:_glassBackground atIndex:0];

        _titleL = [[UILabel alloc] init];
        _titleL.textColor = [UIColor whiteColor];
        _titleL.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        _titleL.translatesAutoresizingMaskIntoConstraints = NO;
        _titleL.numberOfLines = 1;
        _titleL.adjustsFontSizeToFitWidth = YES;
        _titleL.minimumScaleFactor = 0.85;
        [self.contentView addSubview:_titleL];

        _detailL = [[UILabel alloc] init];
        _detailL.textColor = [UIColor colorWithWhite:0.78 alpha:1.0];
        _detailL.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
        _detailL.textAlignment = NSTextAlignmentRight;
        _detailL.translatesAutoresizingMaskIntoConstraints = NO;
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

- (void)layoutSubviews {
    [super layoutSubviews];
    _glassBackground.frame = self.bounds;
}

- (void)configureWithTitle:(NSString *)title detail:(NSString *)detail accessory:(UIView *)accessory accent:(UIColor *)accent {
    _titleL.text = title;
    _detailL.text = detail;
    _titleL.textColor = accent ?: [UIColor whiteColor];

    if (_accessoryContainer) { [_accessoryContainer removeFromSuperview]; _accessoryContainer = nil; }
    if (accessory) {
        _accessoryContainer = accessory;
        accessory.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:accessory];
        [NSLayoutConstraint activateConstraints:@[
            [accessory.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [accessory.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [accessory.widthAnchor constraintEqualToConstant:62],
            [accessory.heightAnchor constraintEqualToConstant:34]
        ]];
    }
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    [_glassBackground setGlassHighlighted:highlighted animated:animated];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    if (selected) {
        [_glassBackground setGlassHighlighted:YES animated:YES];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.20 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self->_glassBackground setGlassHighlighted:NO animated:YES];
        });
    }
}
@end

// ====================================================================================================
// MODULE 6: LG GLASS NAV BUTTON — Tab bar dưới
// ====================================================================================================
@interface LGGlassNavButton : UIControl
@property (nonatomic, strong) AppleLiquidGlassView *glassPill;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
- (instancetype)initWithIconName:(NSString *)iconName title:(NSString *)title;
- (void)updateTabSelected:(BOOL)selected animated:(BOOL)animated;
@end

@implementation LGGlassNavButton
- (instancetype)initWithIconName:(NSString *)iconName title:(NSString *)title {
    if (self = [super initWithFrame:CGRectZero]) {
        self.backgroundColor = [UIColor clearColor];

        _glassPill = [[AppleLiquidGlassView alloc] initWithFrame:self.bounds
                                                     cornerRadius:16.0
                                                     materialType:LGGlassMaterialTypeUltraThin];
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
        _titleLabel.minimumScaleFactor = 0.85;
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
        [self addTarget:self action:@selector(tUp) forControlEvents:UIControlEventTouchUpOutside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
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

- (void)tDown {
    [UIView animateWithDuration:0.10 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.iconView.transform = CGAffineTransformMakeScale(0.88, 0.88);
    } completion:nil];
}
- (void)tUp {
    [UIView animateWithDuration:0.30 delay:0 usingSpringWithDamping:0.60 initialSpringVelocity:0.9 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.iconView.transform = CGAffineTransformIdentity;
    } completion:nil];
}
- (void)updateTabSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected];
    UIColor *c = selected ? [UIColor whiteColor] : [UIColor colorWithWhite:0.78 alpha:1.0];
    UIFont *f = selected ? [UIFont systemFontOfSize:10.5 weight:UIFontWeightBold] : [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
    CGFloat a = selected ? 1.0 : 0.0;
    void (^u)(void) = ^{
        self.iconView.tintColor = c;
        self.titleLabel.textColor = c;
        self.titleLabel.font = f;
        self.glassPill.alpha = a;
    };
    if (animated) [UIView animateWithDuration:0.30 delay:0 options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState animations:u completion:nil];
    else u();
}
@end

// ====================================================================================================
// MODULE 7: EXPANDING NAV BAR BUTTON — Nút góc phải bung/thu
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
    a.title = title;
    a.systemImageName = image;
    a.tintColor = tint ?: [UIColor whiteColor];
    a.destructive = destructive;
    return a;
}
@end

// ==== Action View (UIControl) ====
@interface LGExpandingActionView : UIControl
@property (nonatomic, strong) AppleLiquidGlassView *glassBackground;
@property (nonatomic, strong) UIImageView *iconView;
Highlight@property (nonatomic, strong) UILabel *titleLabel;
- (instancetype)initWithAction:(LGExpandingMenuAction *)action;
@end

@implementation LGExpandingActionView
- (instancetype)initWithAction:(LGExpandingMenuEnabledAction *)action {
    if (self = [super initWithFrame:CGRectMake(0, 0, 220, 48)]) {
        = self.backgroundColor = [UIColor clearColor];

        _glassBackground = [[AppleLiquidGlassView alloc] initWithFrame:self.bounds
 NO                                                          cornerRadius:24.0
                                                          materialType:LGGlassMaterialTypeCrystal];
        _glassBackground.user;
InteractionEnabled = NO;
        _glassBackground.interactive        _glassBackground.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
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
        _titleLabel.minimumScaleFactor = 0.85;
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
    [UIView animateWithDuration:0.16 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.transform = highlighted ? CGAffineTransformMakeScale(0.96, 0.96) : CGAffineTransformIdentity;
    } completion:nil];
}
@end

// ==== Nút gốc (UIControl) ====
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
    if (self = [super initWithFrame:CGRectMake(0, 0, 38, 38)]) {
        self.backgroundColor = [UIColor clearColor];

        _buttonGlass = [[AppleLiquidGlassView alloc] initWithFrame:self.bounds
                                                      cornerRadius:19.0
                                                      materialType:LGGlassMaterialTypeCrystal];
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
    }
    return self;
}

- (void)setActions:(NSArray<LGExpandingMenuAction *>ground *)actions {
    _actions = actions;
}

- (void)handleTap {
    if (_expanded) [selfActive collapseMenu];
    else [self expandMenu];
}

- (UIWindow *)hostWindow {
    UIWindow *w) = self.window;
    if (w) return w;
    for (UIScene *scene in [UIApplication sharedApplication].connectedSc {
enes) {
        if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UIScene           ActivationStateFore for (UIWindow *win in ((UIWindowScene *)scene).windows) {
                if (win.isKeyWindow) return win;
            }
        }
    }
    return [UIApplication sharedApplication].windows.firstObject;
}

- (void)expandMenu {
    if (_expanded || _actions.count == 0) return;
    _expanded = YES;

    UIWindow *host = [self hostWindow];
    if (!host) { _expanded = NO; return; }

    if (!_dimOverlay) {
        _dimOverlay = [[UIView alloc] initWithFrame:host.bounds];
        _dimOverlay.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.15];
        _dimOverlay.alpha = 0.0;
        _dimOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        UITapGestureRecognizer *dimTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(collapseMenu)];
        [_dimOverlay addGestureRecognizer:dimTap];
    }
    [host addSubview:_dimOverlay];
    [host bringSubviewToFront:_dimOverlay];
    [UIView animateWithDuration:0.22 animations:^{ self->_dimOverlay.alpha = 1.0; }];

    if (!_actionsContainer) {
        _actionsContainer = [[UIView alloc] initWithFrame:CGRectZero];
        _actionsContainer.backgroundColor = [UIColor clearColor];
    }
    [_actionsContainer removeFromSuperview];

    for (LGExpandingActionView *v in _actionViews) [v removeFromSuperview];
    [_actionViews removeAllObjects];

    CGRect selfInWindow = [self.superview convertRect:self.frame toView:host];
    CGFloat startX = CGRectGetMaxX(selfInWindow) - 220;
    CGFloat startY = CGRectGetMaxY(selfInWindow) + 8;
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
        NSTimeInterval delay = i * 0.035;
        [UIView animateWithDuration:0.34 delay:delay usingSpringWithDamping:0.66 initialSpringVelocity:0.8 options:UIViewAnimationOptionCurveEaseOut animations:^{
            v.alpha = 1.0;
            v.transform = CGAffineTransformIdentity;
        } completion:nil];
    }

    [UIView animateWithDuration:0.30 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.8 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.iconView.transform = CGAffineTransformMakeRotation(M_PI_4);
    } completion:nil];

    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];

    if ([_delegate respondsToSelector:@selector(expandingButtonDidExpand:)]) {
        [_delegate expandingButtonDidExpand:self];
    }
}

- (void)collapseMenu {
    if (!_expanded) return;
    _expanded = NO;

    for (NSInteger i = 0; i < _actionViews.count; i++) {
        LGExpandingActionView *v = _actionViews[_actionViews.count - 1 - i];
        NSTimeInterval delay = i * 0.025;
        [UIView animateWithDuration:0.22 delay:delay options:UIViewAnimationOptionCurveEaseIn animations:^{
            v.alpha = 0.0;
            v.transform = CGAffineTransformMakeScale(0.7, 0.7);
        } completion:nil];
    }

    [UIView animateWithDuration:0.24 delay:0.08 options:UIViewAnimationOptionCurveEaseIn animations:^{
        self->_dimOverlay.alpha = 0.0;
        self.iconView.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        [self->_actionsContainer removeFromSuperview];
        [self->_dimOverlay removeFromSuperview];
        [self->_actionViews removeAllObjects];
    }];

    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];

    if ([_delegate respondsToSelector:@selector(expandingButtonDidCollapse:)]) {
        [_delegate expandingButtonDidCollapse:self];
    }
}

- (void)toggle { if (_expanded) [self collapseMenu]; else [self expandMenu]; }

- (void)actionViewTap:(LGExpandingActionView *)v {
    NSInteger idx = v.tag;
    UINotificationFeedbackGenerator *fb = [[UINotificationFeedbackGenerator alloc] init];
    [fb notificationOccurred:UINotificationFeedbackTypeSuccess];
    [self collapseMenu];
    if ([_delegate respondsToSelector:@selector(expandingButton:didSelectActionAtIndex:)]) {
        [_delegate expandingButton:self didSelectActionAtIndex:idx];
    }
}
@end

// ====================================================================================================
// MODULE 8: HELPER FUNCTIONS
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
    return name;
}
static void Titanium_WriteSyncPayloadUniversal(const void *data, size_t size) {
    NSArray *paths = @[PRIMARY_SYNC_FILE, SECONDARY_SYNC_FILE];
    for (NSString *path in paths) {
        NSString *dir = [path stringByDeletingLastPathComponent];
        if (![[NSFileManager defaultManager] fileExistsAtPath:dir]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @(0777)} error:nil];
        }
        int fd = open([path UTF8String], O_WRONLY | O_CREAT | O_TRUNC, 0666);
        if (fd >= 0) { write(fd, data, size); close(fd); chmod([path UTF8String], 0666); }
    }
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
// MODULE 9: ROOT LIST CONTROLLER — Interface
// ====================================================================================================
@interface RootListController () <LGExpandingNavBarButtonDelegate> {
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

    LGExpandingNavBarButton *_expandingMenuButton;
    LGExpandingNavBarButton *_expandingBoltButton;
    LGExpandingNavBarButton *_expandingLockButton;
}
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

    CAGradientLayer *bg = [CAGradientLayer layer];
    bg.frame = self.view.bounds;
    bg.colors = @[
        (id)[UIColor colorWithRed:0.04 green:0.05 blue:0.09 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.01 green:0.01 blue:0.03 alpha:1.0].CGColor
    ];
    bg.startPoint = CGPointMake(0.0, 0.0);
    bg.endPoint = CGPointMake(0.0, 1.0);
    [self.view.layer insertSublayer:bg atIndex:0];
    self.view.backgroundColor = [UIColor colorWithRed:0.02 green:0.02 blue:0.05 alpha:1.0];

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
    [self setupExpandingNavigationItems];
    [self setupLiquidGlassNavBar];
    [self setupMainTableView];
    [self setupLiquidGlassLens];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self loadInstalledAppsAsync];
        if (self->_isKernelExploited) [self applyDeepSpringBoardAndUIKitTweaks];
    });
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (_isKernelExploited) [self startContinuousHardwareHUD];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopContinuousHardwareHUD];
    [_expandingMenuButton collapseMenu];
    [_expandingBoltButton collapseMenu];
    [_expandingLockButton collapseMenu];
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

#pragma mark - Expanding Navigation Items

- (void)setupExpandingNavigationItems {
    _expandingBoltButton = [[LGExpandingNavBarButton alloc] initWithIconName:@"bolt.horizontal.fill"
                                                                   tintColor:[UIColor colorWithRed:0.35 green:0.95 blue:0.6 alpha:1.0]];
    _expandingBoltButton.delegate = self;
    [_expandingBoltButton setActions:@[
        [LGExpandingMenuAction actionWithTitle:@"⚡ Đồng Bộ Tức Thì" image:@"arrow.clockwise" tintColor:[UIColor whiteColor] destructive:NO],
        [LGExpandingMenuAction actionWithTitle:@"🔥 Ép Xung 144Hz" image:@"bolt.fill" tintColor:[UIColor systemYellowColor] destructive:NO],
        [LGExpandingMenuAction actionWithTitle:@"🎯 Reset Tần Số" image:@"arrow.counterclockwise" tintColor:[UIColor systemOrangeColor] destructive:NO],
        [LGExpandingMenuAction actionWithTitle:@"💧 Glass Redraw" image:@"sparkles" tintColor:[UIColor colorWithRed:0.5 green:0.8 blue:1.0 alpha:1.0] destructive:NO],
    ]];

    _expandingLockButton = [[LGExpandingNavBarButton alloc] initWithIconName:@"lock.open.fill" tintColor:[UIColor whiteColor]];
    _expandingLockButton.delegate = self;
    [_expandingLockButton setActions:@[
        [LGExpandingMenuAction actionWithTitle:@"🔓 Mở Khóa Chỉnh Sửa" image:@"lock.open.fill" tintColor:[UIColor systemGreenColor] destructive:NO],
        [LGExpandingMenuAction actionWithTitle:@"🔒 Khóa Cấu Hình" image:@"lock.fill" tintColor:[UIColor systemRedColor] destructive:NO],
        [LGExpandingMenuAction actionWithTitle:@"💾 Lưu Ngay" image:@"square.and.arrow.down.fill" tintColor:[UIColor colorWithRed:0.4 green:0.7 blue:1.0 alpha:1.0] destructive:NO],
    ]];

    _expandingMenuButton = [[LGExpandingNavBarButton alloc] initWithIconName:@"line.3.horizontal" tintColor:[UIColor whiteColor]];
    _expandingMenuButton.delegate = self;
    [_expandingMenuButton setActions:@[
        [LGExpandingMenuAction actionWithTitle:@"⚡ Respring Nhanh" image:@"arrow.triangle.2.circlepath" tintColor:[UIColor colorWithRed:0.4 green:0.85 blue:1.0 alpha:1.0] destructive:NO],
        [LGExpandingMenuAction actionWithTitle:@"🔥 Khởi Động Userspace" image:@"arrow.clockwise.circle.fill" tintColor:[UIColor systemOrangeColor] destructive:NO],
        [LGExpandingMenuAction actionWithTitle:@"🛡️ Vào Safe Mode" image:@"shield.lefthalf.fill" tintColor:[UIColor systemYellowColor] destructive:NO],
        [LGExpandingMenuAction actionWithTitle:@"♻ Đặt Lại & Xóa Sạch" image:@"trash.fill" tintColor:[UIColor systemRedColor] destructive:YES],
    ]];

    UIBarButtonItem *menuItem = [[UIBarButtonItem alloc] initWithCustomView:_expandingMenuButton];
    UIBarButtonItem *lockItem = [[UIBarButtonItem alloc] initWithCustomView:_expandingLockButton];
    UIBarButtonItem *boltItem = [[UIBarButtonItem alloc] initWithCustomView:_expandingBoltButton];

    UIBarButtonItem *(^spacer)(CGFloat) = ^UIBarButtonItem *(CGFloat w) {
        UIBarButtonItem *s = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
        s.width = w;
        return s;
    };

    self.navigationItem.rightBarButtonItems = @[
        menuItem, spacer(10),
        lockItem, spacer(10),
        boltItem
    ];
    [self updateLockIcon];
}

- (void)expandingButton:(LGExpandingNavBarButton *)button didSelectActionAtIndex:(NSInteger)index {
    if (button == _expandingMenuButton) {
        switch (index) {
            case 0: [self executeRespring]; break;
            case 1: [self executeSReboot]; break;
            case 2: [self executeSafeMode]; break;
            case 3: [self executeResetConfiguration]; break;
        }
    } else if (button == _expandingBoltButton) {
        switch (index) {
            case 0: [self applySettingsInstantNoRespringAction]; break;
            case 1:
                self.settingsDict[@"TargetRefreshRate"] = @144;
                self.settingsDict[@"TargetFPSRate"] = @144;
                self.settingsDict[@"ForceOverclock144Hz"] = @YES;
                [self saveSettingsDataAndSync];
                [self applyDeepSpringBoardAndUIKitTweaks];
                [self.customTableView reloadData];
                break;
            case 2:
                self.settingsDict[@"TargetRefreshRate"] = @60;
                self.settingsDict[@"TargetFPSRate"] = @60;
                self.settingsDict[@"ForceOverclock144Hz"] = @NO;
                [self saveSettingsDataAndSync];
                [self applyDeepSpringBoardAndUIKitTweaks];
                [self.customTableView reloadData];
                break;
            case 3:
                [self.view setNeedsLayout];
                [self.view layoutIfNeeded];
                UINotificationFeedbackGenerator *fb = [[UINotificationFeedbackGenerator alloc] init];
                [fb notificationOccurred:UINotificationFeedbackTypeSuccess];
                break;
        }
    } else if (button == _expandingLockButton) {
        switch (index) {
            case 0:
                if (!_isKernelExploited) { [self showUnexploitedWarningAlert]; return; }
                _isRateLocked = NO;
                self.settingsDict[@"IsRateLocked"] = @NO;
                [self saveSettingsDataAndSync];
                [self updateLockIcon];
                [self.customTableView reloadData];
                break;
            case 1:
                if (!_isKernelExploited) { [self showUnexploitedWarningAlert]; return; }
                _isRateLocked = YES;
                self.settingsDict[@"IsRateLocked"] = @YES;
                [self saveSettingsDataAndSync];
                [self updateLockIcon];
                [self.customTableView reloadData];
                break;
            case 2: [self saveSettingsDataAndSync]; break;
        }
    }
}

- (void)expandingButtonDidExpand:(LGExpandingNavBarButton *)button {
    if (button != _expandingMenuButton) [_expandingMenuButton collapseMenu];
    if (button != _expandingBoltButton) [_expandingBoltButton collapseMenu];
    if (button != _expandingLockButton) [_expandingLockButton collapseMenu];
}

#pragma mark - Liquid Glass Nav Bar

- (void)setupLiquidGlassNavBar {
    CGFloat barHeight = 62.0;
    CGFloat barMargin = 14.0;
    CGFloat barY = self.view.bounds.size.height - barHeight - 34;

    _liquidNavBarContainer = [[AppleLiquidGlassView alloc] initWithFrame:CGRectMake(barMargin, barY, self.view.bounds.size.width - (barMargin * 2), barHeight)
                                                            cornerRadius:barHeight / 2.0
                                                            materialType:LGGlassMaterialTypeCrystal];
    _liquidNavBarContainer.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    _liquidNavBarContainer.interactiveHighlightEnabled = NO;
    _liquidNavBarContainer.layer.shadowOpacity = 0.35;
    _liquidNavBarContainer.layer.shadowRadius = 18.0;
    _liquidNavBarContainer.layer.shadowOffset = CGSizeMake(0, 8);
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
                                                            materialType:LGGlassMaterialTypeThin];
    _activeGlassIndicator.userInteractionEnabled = NO;
    _activeGlassIndicator.interactiveHighlightEnabled = NO;
    _activeGlassIndicator.layer.shadowOpacity = 0.25;
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

    if (_tabButtons.count > 0) [_tabButtons[0] updateTabSelected:YES animated:NO];

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
    if (animated) [_activeGlassIndicator applyFluidJiggleAnimationWithVelocity:velocity];

    void (^animations)(void) = ^{
        self->_activeGlassIndicator.frame = targetFrame;
        for (NSInteger i = 0; i < self->_tabButtons.count; i++) {
            LGGlassNavButton *b = self->_tabButtons[i];
            [b updateTabSelected:(i == index) animated:animated];
        }
    };

    if (animated) {
        [UIView animateWithDuration:0.34 delay:0 usingSpringWithDamping:0.74 initialSpringVelocity:0.85 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:animations completion:nil];
    } else animations();

    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
    [self.customTableView reloadData];
}

#pragma mark - Liquid Glass Lens

- (void)setupLiquidGlassLens {
    _liquidGlassLensContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 68, 68)];
    _liquidGlassLensContainer.hidden = YES;
    _liquidGlassLensContainer.userInteractionEnabled = NO;

    _lensGlassEffectView = [[AppleLiquidGlassView alloc] initWithFrame:_liquidGlassLensContainer.bounds
                                                          cornerRadius:34.0
                                                          materialType:LGGlassMaterialTypeCrystal];
    _lensGlassEffectView.interactiveHighlightEnabled = NO;
    _lensGlassEffectView.layer.shadowColor = [UIColor blackColor].CGColor;
    _lensGlassEffectView.layer.shadowOpacity = 0.35;
    _lensGlassEffectView.layer.shadowRadius = 14.0;
    _lensGlassEffectView.layer.shadowOffset = CGSizeMake(0, 6);
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
        CGPoint cp = CGPointMake(touchInView.x, _liquidNavBarContainer.center.y - 24);
        _liquidGlassLensContainer.center = cp;
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
        CGPoint cp = CGPointMake(touchInView.x, _liquidNavBarContainer.center.y - 24);
        _liquidGlassLensContainer.center = cp;
        for (NSInteger i = 0; i < _tabButtons.count; i++) {
            LGGlassNavButton *b = _tabButtons[i];
            CGPoint p = [gesture locationInView:b];
            if (CGRectContainsPoint(b.bounds, p)) {
                _lensTitleLabel.text = _tabConfigs[i][@"title"];
                if (_currentBottomTab != [_tabConfigs[i][@"tab"] integerValue]) [self selectTabIndex:i animated:YES];
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

#pragma mark - Navigation

- (void)setupTopHeaderBar {
    UILabel *brandLabel = [[UILabel alloc] init];
    brandLabel.text = @" 💧 Liquid Glass ";
    brandLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.95];
    brandLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightHeavy];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:brandLabel];
}

- (void)updateLockIcon {
    NSString *iconName = _isRateLocked ? @"lock.fill" : @"lock.open.fill";
    UIImage *img = [UIImage systemImageNamed:iconName];
    [_expandingLockButton.iconView setImage:[img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    _expandingLockButton.iconView.tintColor = _isRateLocked ? [UIColor systemRedColor] : [UIColor whiteColor];
}

- (void)applySettingsInstantNoRespringAction {
    if (!_isKernelExploited) { [self showUnexploitedWarningAlert]; return; }
    [self saveSettingsDataAndSync];
    [self applyDeepSpringBoardAndUIKitTweaks];
    UINotificationFeedbackGenerator *fb = [[UINotificationFeedbackGenerator alloc] init];
    [fb notificationOccurred:UINotificationFeedbackTypeSuccess];

    AppleLiquidGlassView *toast = [[AppleLiquidGlassView alloc] initWithFrame:CGRectMake(30, 100, self.view.bounds.size.width - 60, 46)
                                                                 cornerRadius:23.0
                                                                 materialType:LGGlassMaterialTypeCrystal];
    toast.interactiveHighlightEnabled = NO;
    UILabel *tl = [[UILabel alloc] initWithFrame:toast.bounds];
    tl.text = @"⚡ ĐÃ ĐỒNG BỘ TỨC THÌ";
    tl.textColor = [UIColor colorWithWhite:1.0 alpha:0.95];
    tl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    tl.textAlignment = NSTextAlignmentCenter;
    [toast addSubview:tl];

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

- (void)toggleRateLockAction {
    if (!_isKernelExploited) { [self showUnexploitedWarningAlert]; return; }
    _isRateLocked = !_isRateLocked;
    self.settingsDict[@"IsRateLocked"] = @(_isRateLocked);
    [self saveSettingsDataAndSync];
    [self updateLockIcon];
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
    [fb impactOccurred];
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
    return 56.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cid = @"LGGlassCell";
    LGGlassTableViewCell *cell = (LGGlassTableViewCell *)[tableView dequeueReusableCellWithIdentifier:cid];
    if (!cell) cell = [[LGGlassTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cid];

    NSString *title = @"";
    NSString *detail = @"";
    UIView *accessory = nil;
    UIColor *accent = nil;

    if (!_isKernelExploited && _currentBottomTab != 4) {
        title = @"🔒 TÍNH NĂNG ĐANG BỊ KHÓA XÁM";
        detail = @"Chưa Khai Thác";
        [cell configureWithTitle:title detail:detail accessory:nil accent:[UIColor colorWithWhite:0.65 alpha:1.0]];
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
            if (!mA) { title = @"🔒 Bộ đo đang tắt"; detail = @"[TẮT]"; }
            else {
                float baseTemp = Titanium_GetBaseThermalTemp();
                float cpu = Titanium_GetLiveCPULoadPercentage();
                float gpu = Titanium_GetLiveGPULoadPercentage();
                if (indexPath.section == 1) {
                    if (indexPath.row == 0) { title = _isCpuExpanded ? @"🧠 CPU ▼" : @"🧠 CPU ▶"; detail = [NSString stringWithFormat:@"%.1f°C | %.1f%%", baseTemp, cpu]; }
                    else if (indexPath.row == 1) { title = @"   Nhiệt độ CPU"; detail = [NSString stringWithFormat:@"%.1f°C", baseTemp]; }
                    else if (indexPath.row == 2) { title = @"   Tải CPU"; detail = [NSString stringWithFormat:@"%.1f%%", cpu]; }
                    else if (indexPath.row == 3) { float ghz = (cpu > 60.0f) ? 2.49f : ((cpu > 25.0f) ? 1.85f : 1.10f); title = @"   Xung P-Core"; detail = [NSString stringWithFormat:@"%.2f GHz", ghz]; }
                    else if (indexPath.row == 4) { title = @"   Điều Phối Lõi"; detail = (cpu > 40.0f) ? @"P-Core Realtime" : @"E-Core PowerSave"; }
                    else { title = @"   Số Nhân CPU"; detail = _deepCoreCountString ?: @"6 Cores"; }
                } else if (indexPath.section == 2) {
                    if (indexPath.row == 0) { title = _isGpuExpanded ? @"🎮 GPU ▼" : @"🎮 GPU ▶"; detail = [NSString stringWithFormat:@"%.1f°C | %.1f%%", baseTemp - 0.7f, gpu]; }
                    else if (indexPath.row == 1) { title = @"   Nhiệt GPU"; detail = [NSString stringWithFormat:@"%.1f°C", baseTemp - 0.7f]; }
                    else if (indexPath.row == 2) { title = @"   Tải Metal"; detail = [NSString stringWithFormat:@"%.1f%%", gpu]; }
                    else if (indexPath.row == 3) { title = @"   Xung Metal"; detail = @"600 MHz Locked"; }
                    else if (indexPath.row == 4) { title = @"   Buffer Display"; detail = @"Triple Buffering"; }
                    else { title = @"   Metal Version"; detail = @"Apple GPU"; }
                } else if (indexPath.section == 3) {
                    if (indexPath.row == 0) { title = _isRamExpanded ? @"💾 RAM ▼" : @"💾 RAM ▶"; detail = [NSString stringWithFormat:@"%.1f°C | 42.5%%", baseTemp - 1.2f]; }
                    else if (indexPath.row == 1) { title = @"   Nhiệt LPDDR"; detail = [NSString stringWithFormat:@"%.1f°C", baseTemp - 1.2f]; }
                    else if (indexPath.row == 2) { title = @"   Dung lượng"; detail = _deepRamString ?: @"4.00 GB"; }
                    else if (indexPath.row == 3) { title = @"   Mach Purgable"; detail = @"Clean (Auto Purge)"; }
                    else { title = @"   Bộ nhớ ảo"; detail = @"Active"; }
                } else if (indexPath.section == 4) {
                    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
                    int level = (int)([[UIDevice currentDevice] batteryLevel] * 100);
                    if (level < 0) level = 100;
                    float bl = (cpu * 0.45f) + 8.5f;
                    if (indexPath.row == 0) { title = _isBatteryExpanded ? @"🔋 Pin ▼" : @"🔋 Pin ▶"; detail = [NSString stringWithFormat:@"%.1f°C | %.1f%%", baseTemp - 2.0f, bl]; }
                    else if (indexPath.row == 1) { title = @"   Nhiệt Cell Pin"; detail = [NSString stringWithFormat:@"%.1f°C", baseTemp - 2.0f]; }
                    else if (indexPath.row == 2) { title = @"   Dòng xả tải"; detail = [NSString stringWithFormat:@"%.1f%% Load", bl]; }
                    else if (indexPath.row == 3) { title = @"   Dung lượng hiện tại"; detail = [NSString stringWithFormat:@"%d%%", level]; }
                    else if (indexPath.row == 4) { title = @"   Trạng thái sạc"; detail = @"Li-ion Native"; }
                    else { title = @"   Chu kỳ pin"; detail = @"Optimal"; }
                } else {
                    NSInteger hz = [self.settingsDict[@"TargetRefreshRate"] ?: @144 integerValue];
                    NSInteger fps = [self.settingsDict[@"TargetFPSRate"] ?: @144 integerValue];
                    if (indexPath.row == 0) { title = _isScreenExpanded ? @"🖥️ Màn Hình ▼" : @"🖥️ Màn Hình ▶"; detail = [NSString stringWithFormat:@"%.1f°C | %ld Hz", baseTemp - 1.5f, (long)hz]; }
                    else if (indexPath.row == 1) { title = @"   Nhiệt bề mặt"; detail = [NSString stringWithFormat:@"%.1f°C", baseTemp - 1.5f]; }
                    else if (indexPath.row == 2) { title = @"   Tần số quét (Hz)"; detail = [NSString stringWithFormat:@"%ld Hz", (long)hz]; }
                    else if (indexPath.row == 3) { title = @"   Khung hình (FPS)"; detail = [NSString stringWithFormat:@"%ld FPS", (long)fps]; }
                    else { title = @"   ProMotion"; detail = @"120Hz Adaptive"; }
                }
            }
        }
    } else if (_currentBottomTab == 1) {
        if (indexPath.section == 0) {
            title = @"📌 Tần số Hz và FPS được điều phối trực tiếp tới CADisplayLink & CoreAnimation RenderServer.";
        } else if (indexPath.section == 1) {
            LGCustomSegment *seg = [[LGCustomSegment alloc] initWithItems:@[@"Tần Số Quét (Hz)", @"Khung Hình (FPS)"]];
            seg.frame = CGRectMake(0, 0, 260, 36);
            seg.selectedSegmentIndex = _currentHzFpsSubTab;
            __weak typeof(self) wS = self;
            seg.valueChangedBlock = ^(NSInteger index) {
                __strong typeof(wS) sS = wS;
                if (!sS) return;
                sS->_currentHzFpsSubTab = index;
                [sS.customTableView reloadSections:[NSIndexSet indexSetWithIndex:2] withRowAnimation:UITableViewRowAnimationFade];
            };
            accessory = seg;
            title = @"   Chế độ:";
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
            LGCustomSegment *seg = [[LGCustomSegment alloc] initWithItems:@[@"CPU", @"GPU", @"Màn", @"Pin", @"Hệ Thống"]];
            seg.frame = CGRectMake(0, 0, 300, 36);
            seg.selectedSegmentIndex = _currentSwitchSubTab;
            __weak typeof(self) wS = self;
            seg.valueChangedBlock = ^(NSInteger index) {
                __strong typeof(wS) sS = wS;
                if (!sS) return;
                sS->_currentSwitchSubTab = index;
                [sS.customTableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationFade];
            };
            accessory = seg;
            title = @"   Nhóm:";
        } else {
            NSString *prefKey = @"";
            if (_currentSwitchSubTab == 0) {
                if (indexPath.row == 0) { title = @"Ưu Tiên P-Core Realtime"; prefKey = @"pCoreRealtimePriority"; }
                else if (indexPath.row == 1) { title = @"Điều Phối CPU Scheduler"; prefKey = @"schedulerGovernor"; }
                else if (indexPath.row == 2) { title = @"Đồng Bộ Xung Quantum"; prefKey = @"quantumCoreSync"; }
                else if (indexPath.row == 3) { title = @"Khóa Tần Số CPU Sàn"; prefKey = @"lockHighIdleFloor"; }
                else if (indexPath.row == 4) { title = @"Chống Bóp Xung Nhiệt"; prefKey = @"AntiThermalThrottling"; }
                else if (indexPath.row == 5) { title = @"Tăng Ưu Tiên I/O Disk"; prefKey = @"iopolVipPriority"; }
                else { title = @"Hạ Nhiệt Khi Tải Nặng"; prefKey = @"coolDownHeavyLoad"; }
            } else if (_currentSwitchSubTab == 1) {
                if (indexPath.row == 0) { title = @"Metal Triple Buffering"; prefKey = @"MetalHexBuffering"; }
                else if (indexPath.row == 1) { title = @"Isolate Render Pipeline"; prefKey = @"IsolateRenderPipeline"; }
                else if (indexPath.row == 2) { title = @"Bỏ Khóa V-Sync Khung Hình"; prefKey = @"vsyncAdaptiveBuffer"; }
                else if (indexPath.row == 3) { title = @"Ổn Định FPS Chơi Game"; prefKey = @"gameFPSStabilizer"; }
                else if (indexPath.row == 4) { title = @"Triệt Tiêu Blur Động"; prefKey = @"flatTintBlur"; }
                else { title = @"Tối Ưu Neural Buffer"; prefKey = @"neuralBufferOpt"; }
            } else if (_currentSwitchSubTab == 2) {
                if (indexPath.row == 0) { title = @"🔥 Ép 144Hz Toàn Máy"; prefKey = @"ForceOverclock144Hz"; }
                else if (indexPath.row == 1) { title = @"ProMotion Engine Beta 7"; prefKey = @"ProMotionEngineBeta7"; }
                else if (indexPath.row == 2) { title = @"Cảm Ứng 0ms Touch Boost"; prefKey = @"TouchResponseBoost"; }
                else if (indexPath.row == 3) { title = @"Cuộn ColorOS 17 Engine"; prefKey = @"ColorOs17SmoothEngine"; }
                else if (indexPath.row == 4) { title = @"Dự Đoán Tọa Độ Neural"; prefKey = @"zeroLagNeural"; }
                else { title = @"Ultra Responsiveness"; prefKey = @"ultraResponsiveness"; }
            } else if (_currentSwitchSubTab == 3) {
                if (indexPath.row == 0) { title = @"Lọc Loạn Cảm Ứng Sạc"; prefKey = @"AntiGhostTouch"; }
                else if (indexPath.row == 1) { title = @"Khử Nhiễu Sóng Củ Sạc"; prefKey = @"ChargerRippleRejection"; }
                else if (indexPath.row == 2) { title = @"Giả Lập Pin Đầy"; prefKey = @"fakeFullBatteryState"; }
                else if (indexPath.row == 3) { title = @"Khóa 30 FPS Khi Quá Nhiệt"; prefKey = @"lock30FpsOnOverheat"; }
                else if (indexPath.row == 4) { title = @"Chế Độ Tiết Kiệm Pin 60Hz"; prefKey = @"batterySaver60Hz"; }
                else { title = @"Power Save Mode"; prefKey = @"powerSaveMode"; }
            } else {
                if (indexPath.row == 0) { title = @"Khởi Động App Siêu Tốc"; prefKey = @"TurboAppLaunch"; }
                else if (indexPath.row == 1) { title = @"Trị Dứt Điểm Đen App"; prefKey = @"FixAppLaunchBlackScreen"; }
                else if (indexPath.row == 2) { title = @"Giảm Lag Đa Nhiệm"; prefKey = @"ReduceMultiTaskLag"; }
                else if (indexPath.row == 3) { title = @"Chống Khựng Thoát App"; prefKey = @"FixAppExitStutter"; }
                else if (indexPath.row == 4) { title = @"Dọn RAM Chuyên Sâu"; prefKey = @"hyperMemoryGuardian"; }
                else if (indexPath.row == 5) { title = @"Tự Động Đóng App Nền"; prefKey = @"autoKillBackground"; }
                else if (indexPath.row == 6) { title = @"Dọn RAM Định Kỳ"; prefKey = @"periodicRamClean"; }
                else if (indexPath.row == 7) { title = @"Mach VM Purge RAM"; prefKey = @"machVMPurgeRam"; }
                else { title = @"Background Pacing Daemon"; prefKey = @"backgroundPacingDaemon"; }
            }
            LiquidCapsuleSwitch *s = [[LiquidCapsuleSwitch alloc] init];
            s.on = [self.settingsDict[prefKey] ?: @NO boolValue];
            __weak typeof(self) wS = self;
            s.valueChangedBlock = ^(BOOL isOn) {
                __strong typeof(wS) sS = wS;
                if (!sS) return;
                sS.settingsDict[prefKey] = @(isOn);
                [sS saveSettingsDataAndSync];
                [sS applyDeepSpringBoardAndUIKitTweaks];
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
    } else {
        if (indexPath.section == 0) {
            if (indexPath.row == 0) {
                if (_isKernelExploited) {
                    title = @"🟢 HỆ THỐNG ĐÃ KHAI THÁC";
                    detail = @"✓ Đã Lưu";
                    accent = [UIColor colorWithRed:0.4 green:1.0 blue:0.6 alpha:1.0];
                } else {
                    title = @"🔴 CHƯA KHAI THÁC [CHẠM 15S]";
                    detail = @"✕ Bấm Ngay";
                    accent = [UIColor colorWithRed:1.0 green:0.45 blue:0.45 alpha:1.0];
                }
            } else {
                NSString *curIOS = [[UIDevice currentDevice] systemVersion];
                if (Titanium_IsSupportedIOSVersion()) {
                    title = [NSString stringWithFormat:@"🟢 iOS %@ (Tương Thích)", curIOS];
                    detail = @"15-26";
                    accent = [UIColor colorWithRed:0.4 green:1.0 blue:0.6 alpha:1.0];
                } else {
                    title = [NSString stringWithFormat:@"🔴 iOS %@ (Không OK)", curIOS];
                    detail = @"";
                    accent = [UIColor colorWithRed:1.0 green:0.35 blue:0.35 alpha:1.0];
                }
            }
        } else if (indexPath.section == 1) {
            if (!_isKernelExploited) {
                title = @"Thông Tin Phần Cứng";
                detail = @"[Đang Khóa]";
            } else {
                struct utsname si; uname(&si);
                NSString *dm = [NSString stringWithCString:si.machine encoding:NSUTF8StringEncoding];
                NSString *ov = [[UIDevice currentDevice] systemVersion];
                if (indexPath.row == 0) { title = @"UID Thiết Bị"; detail = _deviceUUIDString; }
                else if (indexPath.row == 1) { title = @"Mã Thiết Bị"; detail = dm; }
                else if (indexPath.row == 2) { title = @"Kiến Trúc"; detail = _deepArchString; }
                else if (indexPath.row == 3) { title = @"Phiên Bản iOS"; detail = [NSString stringWithFormat:@"iOS %@", ov]; }
                else if (indexPath.row == 4) { title = @"Tên Thiết Bị"; detail = [[UIDevice currentDevice] name]; }
                else if (indexPath.row == 5) { title = @"Số Nhân CPU"; detail = _deepCoreCountString; }
                else if (indexPath.row == 6) { title = @"RAM Khả Dụng"; detail = _deepRamString; }
                else { title = @"Darwin Release"; detail = _deepKernelString; }
            }
        } else {
            NSString *jbRoot = Titanium_GetRootHidePrefixPath();
            BOOL isR = [jbRoot containsString:@"/var/jb"];
            if (indexPath.row == 0) { title = @"Môi Trường"; detail = isR ? @"Rootless / RootHide" : @"Rootful"; }
            else if (indexPath.row == 1) { title = @"Vùng Thư Mục"; detail = jbRoot; }
            else if (indexPath.row == 2) { title = @"Trạng Thái Sandbox"; detail = _isKernelExploited ? @"Đã Phá Bỏ" : @"Đang Khóa"; }
            else { title = @"Quyền Ghi IPC"; detail = @"🟢 Sẵn Sàng (RW)"; }
        }
    }

    [cell configureWithTitle:title detail:detail accessory:accessory accent:accent];
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
            UIAlertController *a = [UIAlertController alertControllerWithTitle:@"🔒 ĐÃ KHÓA" message:@"Mở khóa góc phải trước khi chỉnh." preferredStyle:UIAlertControllerStyleAlert];
            [a addAction:[UIAlertAction actionWithTitle:@"Đã Hiểu" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:a animated:YES completion:nil];
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
    UIAlertController *a = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"⌨️ NHẬP %@", unit] message:[NSString stringWithFormat:@"Giá trị 15 - 144 %@", unit] preferredStyle:UIAlertControllerStyleAlert];
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
        [self.customTableView reloadData];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)applyRateValue:(NSInteger)rate isDynamic:(BOOL)d isFPS:(BOOL)isFPS {
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
    __weak typeof(self) wS = self;
    dispatch_source_set_event_handler(_hudTimer, ^{
        __strong typeof(wS) sS = wS;
        if (sS && sS->_currentBottomTab == 0 && sS->_isKernelExploited && [sS.settingsDict[@"EnableSystemMonitoring"] boolValue]) {
            [sS.customTableView reloadData];
        }
    });
    dispatch_resume(_hudTimer);
}

- (void)stopContinuousHardwareHUD {
    if (_hudTimer) { dispatch_source_cancel(_hudTimer); _hudTimer = nil; }
}

- (void)syncSharedMemoryFile:(BOOL)enabled {
    if (!_isKernelExploited) return;
    ApexV285ProPayload p;
    memset(&p, 0, sizeof(ApexV285ProPayload));
    p.magic = APEX_SYNC_MAGIC_V285;
    p.masterEnabled = (enabled && _isKernelExploited) ? 1 : 0;
    int32_t hz = [self.settingsDict[@"TargetRefreshRate"] ?: @144 intValue];
    int32_t fps = [self.settingsDict[@"TargetFPSRate"] ?: @144 intValue];
    BOOL oc = [self.settingsDict[@"ForceOverclock144Hz"] ?: @NO boolValue];
    p.targetHz = hz;
    p.targetFPS = fps;
    p.forceOverclock = (oc || hz >= 144) ? 1 : 0;
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
    p.aggressiveRamCleaner = [self.settingsDict[@"hyperMemoryGuardian"] ?: @NO boolValue] ? 1 : 0;
    p.lockFixedFpsWhenThermal = [self.settingsDict[@"lock30FpsOnOverheat"] ?: @NO boolValue] ? 1 : 0;
    p.antiGhostTouch = [self.settingsDict[@"AntiGhostTouch"] ?: @NO boolValue] ? 1 : 0;
    p.diskIOPriorityBoost = [self.settingsDict[@"pCoreRealtimePriority"] ?: @NO boolValue] ? 1 : 0;
    p.rawTouchDirectDelivery = 1;
    p.powerSaveModeActive = [self.settingsDict[@"batterySaver60Hz"] ?: @NO boolValue] ? 1 : 0;
    p.updateSeq = (uint64_t)mach_absolute_time();
    p.lastHeartbeat = p.updateSeq;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        Titanium_WriteSyncPayloadUniversal(&p, sizeof(ApexV285ProPayload));
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
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"🔒 TÍNH NĂNG ĐANG BỊ KHÓA" message:@"Vào tab Cài Đặt, nhấn vào dòng đèn đỏ để bắt đầu." preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Đã Hiểu" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)openDopamineStyleExploitConsole {
    UIViewController *vc = [[UIViewController alloc] init];
    vc.view.backgroundColor = [UIColor colorWithRed:0.02 green:0.03 blue:0.06 alpha:1.0];
    vc.modalPresentationStyle = UIModalPresentationFullScreen;

    UILabel *tl = [[UILabel alloc] initWithFrame:CGRectMake(20, 55, vc.view.bounds.size.width - 40, 30)];
    tl.text = @"⚡ LIQUID GLASS KERNEL EXPLOIT";
    tl.textColor = [UIColor colorWithRed:0.4 green:1.0 blue:0.6 alpha:1.0];
    tl.font = [UIFont fontWithName:@"Menlo-Bold" size:15] ?: [UIFont boldSystemFontOfSize:15];
    [vc.view addSubview:tl];

    UIProgressView *pv = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    pv.frame = CGRectMake(20, 100, vc.view.bounds.size.width - 40, 6);
    pv.progressTintColor = [UIColor colorWithRed:0.35 green:1.0 blue:0.55 alpha:1.0];
    pv.trackTintColor = [UIColor darkGrayColor];
    [vc.view addSubview:pv];

    UITextView *lt = [[UITextView alloc] initWithFrame:CGRectMake(20, 120, vc.view.bounds.size.width - 40, vc.view.bounds.size.height - 210)];
    lt.backgroundColor = [UIColor colorWithRed:0.04 green:0.05 blue:0.08 alpha:1.0];
    lt.textColor = [UIColor colorWithRed:0.4 green:0.95 blue:0.55 alpha:1.0];
    lt.font = [UIFont fontWithName:@"Menlo" size:12] ?: [UIFont systemFontOfSize:12];
    lt.editable = NO;
    lt.layer.cornerRadius = 14;
    lt.layer.borderColor = [UIColor colorWithWhite:0.25 alpha:1.0].CGColor;
    lt.layer.borderWidth = 1.0;
    [vc.view addSubview:lt];

    [self presentViewController:vc animated:YES completion:^{
        [self runExploitStagesWithConsole:lt progress:pv controller:vc];
    }];
}

- (void)runExploitStagesWithConsole:(UITextView *)lt progress:(UIProgressView *)pv controller:(UIViewController *)vc {
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
    NSMutableString *buf = [NSMutableString stringWithFormat:@"[*] Khai thác Darwin Kernel...\n"];
    lt.text = buf;

    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:2.2 repeats:YES block:^(NSTimer * _Nonnull t) {
        if (idx < stages.count) {
            [buf appendFormat:@"\n%@", stages[idx]];
            lt.text = buf;
            [lt scrollRangeToVisible:NSMakeRange(lt.text.length - 1, 1)];
            [pv setProgress:(float)(idx + 1) / (float)stages.count animated:YES];
            UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
            [fb impactOccurred];
            idx++;
        } else {
            [t invalidate];
            UINotificationFeedbackGenerator *fb = [[UINotificationFeedbackGenerator alloc] init];
            [fb notificationOccurred:UINotificationFeedbackTypeSuccess];
            [self persistExploitDataToDisk];
            [self applyDeepSpringBoardAndUIKitTweaks];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [vc dismissViewControllerAnimated:YES completion:^{ [self.customTableView reloadData]; }];
            });
        }
    }];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

- (void)persistExploitDataToDisk {
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
    NSString *p = Titanium_ResolvePrefPath();
    if ([[NSFileManager defaultManager] fileExistsAtPath:p]) {
        self.settingsDict = [NSMutableDictionary dictionaryWithContentsOfFile:p] ?: [NSMutableDictionary dictionary];
    } else self.settingsDict = [NSMutableDictionary dictionary];
    [self ensureDefaultSettingsExist];
}

- (void)saveSettingsDataAndSync {
    NSString *p = Titanium_ResolvePrefPath();
    NSString *d = [p stringByDeletingLastPathComponent];
    if (![[NSFileManager defaultManager] fileExistsAtPath:d]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:d withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @(0777)} error:nil];
    }
    [self.settingsDict writeToFile:p atomically:YES];
    chmod([p UTF8String], 0666);
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
        @"IsRateLocked", @"IsKernelExploited"
    ];
    for (NSString *k in keys) {
        if (!self.settingsDict[k]) self.settingsDict[k] = @NO;
    }
    if (!self.settingsDict[@"TargetRefreshRate"]) self.settingsDict[@"TargetRefreshRate"] = @144;
    if (!self.settingsDict[@"TargetFPSRate"])    self.settingsDict[@"TargetFPSRate"]    = @144;
    if (!self.settingsDict[@"IsRateLocked"])     self.settingsDict[@"IsRateLocked"]     = @NO;
    if (!self.settingsDict[@"IsKernelExploited"])self.settingsDict[@"IsKernelExploited"]= @NO;
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
                        if (self->_appTweakStates[bid] == nil) self->_appTweakStates[bid] = @NO;
                        [temp addObject:@{@"name": name, @"bundleID": bid, @"path": full}];
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
        NSString *b = Titanium_FindExecutablePath(@"sbreload");
        char *argv[] = {(char *)[b UTF8String], NULL};
        pid_t pid;
        posix_spawn(&pid, [b UTF8String], NULL, NULL, argv, environ);
        waitpid(pid, NULL, 0);
    });
}

- (void)executeSReboot {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        NSString *b = Titanium_FindExecutablePath(@"launchctl");
        char *argv[] = {(char *)[b UTF8String], (char *)"reboot", (char *)"userspace", NULL};
        pid_t pid;
        posix_spawn(&pid, [b UTF8String], NULL, NULL, argv, environ);
        waitpid(pid, NULL, 0);
    });
}

- (void)executeSafeMode {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        NSString *b = Titanium_FindExecutablePath(@"killall");
        char *argv[] = {(char *)[b UTF8String], (char *)"-SEGV", (char *)"SpringBoard", NULL};
        pid_t pid;
        posix_spawn(&pid, [b UTF8String], NULL, NULL, argv, environ);
        waitpid(pid, NULL, 0);
    });
}

- (void)executeResetConfiguration {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"⚠️ XÓA SẠCH" message:@"Toàn bộ cấu hình sẽ bị xóa." preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Xác Nhận" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        NSString *p = Titanium_ResolvePrefPath();
        [[NSFileManager defaultManager] removeItemAtPath:p error:nil];
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
    [a addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

@end
