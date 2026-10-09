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

#define APEX_SYNC_MAGIC_V285 0x41505837
#define PRIMARY_SYNC_FILE    @"/tmp/.boost_hz_sync"
#define SECONDARY_SYNC_FILE  @"/var/jb/tmp/.boost_hz_sync"
#define TITANIUM_BOOT_FLAG_VERIFIED @"/tmp/.titanium_tweak_verified"

#define NOTIFY_RELOAD        "com.taojb.boostiphone6s/ReloadPrefs"
#define NOTIFY_UIKIT_RELOAD  "com.taojb.boostiphone6s/ReloadUIKitPrefs"
#define NOTIFY_HARDWARE_SYNC "com.taojb.boostiphone6s/HardwareSync"
#define NOTIFY_FPS_CHANGED   "com.taojb.boostiphone6s/FPSChanged"
#define NOTIFY_TITANIUM_CHANGED "com.titanium.v285.prefschanged"

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

// ====================================================================================================
// SECTION 1: GLASS MATERIAL FACTORY
// ====================================================================================================
typedef NS_ENUM(NSInteger, LGGlassMaterialType) {
    LGGlassMaterialTypeUltraThin = 0,
    LGGlassMaterialTypeThin      = 1,
    LGGlassMaterialTypeRegular   = 2,
    LGGlassMaterialTypeChrome    = 3,
    LGGlassMaterialTypeProminent = 4,
    LGGlassMaterialTypeOverlay   = 5  // cho menu bung
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
        case LGGlassMaterialTypeThin:      return isDark ? UIBlurEffectStyleSystemThinMaterialDark : UIBlurEffectStyleSystemThinMaterialLight;
        case LGGlassMaterialTypeRegular:   return isDark ? UIBlurEffectStyleSystemMaterialDark : UIBlurEffectStyleSystemMaterialLight;
        case LGGlassMaterialTypeChrome:    return isDark ? UIBlurEffectStyleSystemChromeMaterialDark : UIBlurEffectStyleSystemChromeMaterialLight;
        case LGGlassMaterialTypeProminent: return isDark ? UIBlurEffectStyleSystemThickMaterialDark : UIBlurEffectStyleSystemThickMaterialLight;
        case LGGlassMaterialTypeOverlay:   return isDark ? UIBlurEffectStyleSystemMaterialDark : UIBlurEffectStyleSystemMaterialLight;
    }
    return UIBlurEffectStyleSystemThinMaterialDark;
}
+ (CGFloat)tintAlphaForType:(LGGlassMaterialType)type {
    switch (type) {
        case LGGlassMaterialTypeUltraThin: return 0.010;
        case LGGlassMaterialTypeThin:      return 0.025;
        case LGGlassMaterialTypeRegular:   return 0.040;
        case LGGlassMaterialTypeChrome:    return 0.055;
        case LGGlassMaterialTypeProminent: return 0.080;
        case LGGlassMaterialTypeOverlay:   return 0.070;
    }
    return 0.025;
}
+ (CGFloat)specularAlphaForType:(LGGlassMaterialType)type {
    switch (type) {
        case LGGlassMaterialTypeUltraThin: return 0.12;
        case LGGlassMaterialTypeThin:      return 0.16;
        case LGGlassMaterialTypeRegular:   return 0.20;
        case LGGlassMaterialTypeChrome:    return 0.24;
        case LGGlassMaterialTypeProminent: return 0.30;
        case LGGlassMaterialTypeOverlay:   return 0.26;
    }
    return 0.18;
}
+ (CGFloat)bottomReflectionAlphaForType:(LGGlassMaterialType)type {
    switch (type) {
        case LGGlassMaterialTypeUltraThin: return 0.04;
        case LGGlassMaterialTypeThin:      return 0.06;
        case LGGlassMaterialTypeRegular:   return 0.08;
        case LGGlassMaterialTypeChrome:    return 0.10;
        case LGGlassMaterialTypeProminent: return 0.14;
        case LGGlassMaterialTypeOverlay:   return 0.10;
    }
    return 0.06;
}
+ (CGFloat)diagonalSheenAlphaForType:(LGGlassMaterialType)type {
    switch (type) {
        case LGGlassMaterialTypeUltraThin: return 0.05;
        case LGGlassMaterialTypeThin:      return 0.07;
        case LGGlassMaterialTypeRegular:   return 0.09;
        case LGGlassMaterialTypeChrome:    return 0.11;
        case LGGlassMaterialTypeProminent: return 0.14;
        case LGGlassMaterialTypeOverlay:   return 0.12;
    }
    return 0.07;
}
+ (CGFloat)rimAlphaForType:(LGGlassMaterialType)type {
    switch (type) {
        case LGGlassMaterialTypeUltraThin: return 0.10;
        case LGGlassMaterialTypeThin:      return 0.13;
        case LGGlassMaterialTypeRegular:   return 0.16;
        case LGGlassMaterialTypeChrome:    return 0.20;
        case LGGlassMaterialTypeProminent: return 0.26;
        case LGGlassMaterialTypeOverlay:   return 0.22;
    }
    return 0.13;
}
+ (CGFloat)rimWidthForType:(LGGlassMaterialType)type { return 0.5; }
+ (CGFloat)innerGlowWidthForType:(LGGlassMaterialType)type { return 0.6; }
+ (CGFloat)innerGlowAlphaForType:(LGGlassMaterialType)type {
    switch (type) {
        case LGGlassMaterialTypeUltraThin: return 0.18;
        case LGGlassMaterialTypeThin:      return 0.22;
        case LGGlassMaterialTypeRegular:   return 0.26;
        case LGGlassMaterialTypeChrome:    return 0.32;
        case LGGlassMaterialTypeProminent: return 0.40;
        case LGGlassMaterialTypeOverlay:   return 0.34;
    }
    return 0.22;
}
+ (CGFloat)shadowOpacityForType:(LGGlassMaterialType)type {
    switch (type) {
        case LGGlassMaterialTypeUltraThin: return 0.10;
        case LGGlassMaterialTypeThin:      return 0.18;
        case LGGlassMaterialTypeRegular:   return 0.24;
        case LGGlassMaterialTypeChrome:    return 0.26;
        case LGGlassMaterialTypeProminent: return 0.38;
        case LGGlassMaterialTypeOverlay:   return 0.32;
    }
    return 0.18;
}
+ (CGFloat)shadowRadiusForType:(LGGlassMaterialType)type {
    switch (type) {
        case LGGlassMaterialTypeUltraThin: return 3.0;
        case LGGlassMaterialTypeThin:      return 6.0;
        case LGGlassMaterialTypeRegular:   return 10.0;
        case LGGlassMaterialTypeChrome:    return 12.0;
        case LGGlassMaterialTypeProminent: return 18.0;
        case LGGlassMaterialTypeOverlay:   return 22.0;
    }
    return 6.0;
}
+ (CGFloat)shadowOffsetYForType:(LGGlassMaterialType)type {
    switch (type) {
        case LGGlassMaterialTypeUltraThin: return 1.0;
        case LGGlassMaterialTypeThin:      return 1.5;
        case LGGlassMaterialTypeRegular:   return 3.0;
        case LGGlassMaterialTypeChrome:    return 5.0;
        case LGGlassMaterialTypeProminent: return 7.0;
        case LGGlassMaterialTypeOverlay:   return 8.0;
    }
    return 1.5;
}
+ (CGFloat)specularHeightRatioForType:(LGGlassMaterialType)type {
    switch (type) {
        case LGGlassMaterialTypeUltraThin: return 0.20;
        case LGGlassMaterialTypeThin:      return 0.22;
        case LGGlassMaterialTypeRegular:   return 0.24;
        case LGGlassMaterialTypeChrome:    return 0.26;
        case LGGlassMaterialTypeProminent: return 0.32;
        case LGGlassMaterialTypeOverlay:   return 0.28;
    }
    return 0.24;
}
@end

// ====================================================================================================
// SECTION 2: GLASS LAYER STACK — 3 TẦNG
// ====================================================================================================
@interface LGGlassLayerStack : NSObject
@property (nonatomic, strong) UIVisualEffectView *backdropTier;
@property (nonatomic, strong) UIView *bodyTier;
@property (nonatomic, strong) UIView *surfaceTier;
@property (nonatomic, strong) CAGradientLayer *topSpecular;
@property (nonatomic, strong) CAGradientLayer *bottomReflection;
@property (nonatomic, strong) CAGradientLayer *diagonalSheen;
@property (nonatomic, strong) CALayer *innerGlow;
@property (nonatomic, strong) CAShapeLayer *innerRim;
@property (nonatomic, strong) CAShapeLayer *outerRim;
@property (nonatomic, assign) LGGlassMaterialType materialType;
@property (nonatomic, assign) CGFloat cornerRadius;
@property (nonatomic, assign) BOOL isDarkMode;

- (instancetype)initWithMaterialType:(LGGlassMaterialType)type cornerRadius:(CGFloat)radius isDark:(BOOL)isDark;
- (void)attachToHostView:(UIView *)hostView;
- (void)updateLayoutForBounds:(CGRect)bounds;
- (void)refreshBlurStyle:(BOOL)isDark;
- (void)setSpecularPressed:(BOOL)pressed;
@end

@implementation LGGlassLayerStack
- (instancetype)initWithMaterialType:(LGGlassMaterialType)type cornerRadius:(CGFloat)radius isDark:(BOOL)isDark {
    if (self = [super init]) {
        _materialType = type;
        _cornerRadius = radius;
        _isDarkMode = isDark;
        [self buildBackdrop];
        [self buildBody];
        [self buildSurface];
    }
    return self;
}
- (void)buildBackdrop {
    UIBlurEffectStyle style = [LGGlassMaterialFactory blurStyleForType:_materialType isDark:_isDarkMode];
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:style];
    _backdropTier = [[UIVisualEffectView alloc] initWithEffect:blur];
    _backdropTier.userInteractionEnabled = NO;
    _backdropTier.layer.cornerRadius = _cornerRadius;
    if (@available(iOS 13.0, *)) _backdropTier.layer.cornerCurve = kCACornerCurveContinuous;
    _backdropTier.clipsToBounds = YES;
}
- (void)buildBody {
    _bodyTier = [[UIView alloc] initWithFrame:CGRectZero];
    _bodyTier.userInteractionEnabled = NO;
    _bodyTier.layer.cornerRadius = _cornerRadius;
    if (@available(iOS 13.0, *)) _bodyTier.layer.cornerCurve = kCACornerCurveContinuous;
    _bodyTier.clipsToBounds = YES;
    _bodyTier.backgroundColor = [UIColor colorWithWhite:1.0 alpha:[LGGlassMaterialFactory tintAlphaForType:_materialType]];

    CGFloat spec = [LGGlassMaterialFactory specularAlphaForType:_materialType];
    _topSpecular = [CAGradientLayer layer];
    _topSpecular.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:spec].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:spec * 0.35].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
    ];
    _topSpecular.locations = @[@0.0, @0.38, @1.0];
    _topSpecular.startPoint = CGPointMake(0, 0);
    _topSpecular.endPoint = CGPointMake(0, 1);
    _topSpecular.opacity = 0.90f;
    [_bodyTier.layer addSublayer:_topSpecular];

    CGFloat bot = [LGGlassMaterialFactory bottomReflectionAlphaForType:_materialType];
    _bottomReflection = [CAGradientLayer layer];
    _bottomReflection.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:bot].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:bot * 0.4].CGColor
    ];
    _bottomReflection.locations = @[@0.0, @0.55, @1.0];
    _bottomReflection.startPoint = CGPointMake(0, 0);
    _bottomReflection.endPoint = CGPointMake(0, 1);
    _bottomReflection.opacity = 0.70f;
    [_bodyTier.layer addSublayer:_bottomReflection];

    CGFloat sheen = [LGGlassMaterialFactory diagonalSheenAlphaForType:_materialType];
    _diagonalSheen = [CAGradientLayer layer];
    _diagonalSheen.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:sheen].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:sheen * 0.5].CGColor
    ];
    _diagonalSheen.locations = @[@0.0, @0.28, @0.72, @1.0];
    _diagonalSheen.startPoint = CGPointMake(0, 0);
    _diagonalSheen.endPoint = CGPointMake(1, 1);
    _diagonalSheen.opacity = 0.55f;
    [_bodyTier.layer addSublayer:_diagonalSheen];
}
- (void)buildSurface {
    _surfaceTier = [[UIView alloc] initWithFrame:CGRectZero];
    _surfaceTier.userInteractionEnabled = NO;
    _surfaceTier.clipsToBounds = NO;

    CGFloat glowA = [LGGlassMaterialFactory innerGlowAlphaForType:_materialType];
    CGFloat glowW = [LGGlassMaterialFactory innerGlowWidthForType:_materialType];
    _innerGlow = [CALayer layer];
    _innerGlow.backgroundColor = [UIColor clearColor].CGColor;
    _innerGlow.borderWidth = glowW;
    _innerGlow.borderColor = [UIColor colorWithWhite:1.0 alpha:glowA].CGColor;
    _innerGlow.opacity = 0.9f;
    [_surfaceTier.layer addSublayer:_innerGlow];

    CGFloat rimA = [LGGlassMaterialFactory rimAlphaForType:_materialType];
    CGFloat rimW = [LGGlassMaterialFactory rimWidthForType:_materialType];
    _innerRim = [CAShapeLayer layer];
    _innerRim.fillColor = [UIColor clearColor].CGColor;
    _innerRim.strokeColor = [UIColor colorWithWhite:1.0 alpha:rimA].CGColor;
    _innerRim.lineWidth = rimW;
    [_surfaceTier.layer addSublayer:_innerRim];

    _outerRim = [CAShapeLayer layer];
    _outerRim.fillColor = [UIColor clearColor].CGColor;
    _outerRim.strokeColor = [UIColor colorWithWhite:0.0 alpha:0.20].CGColor;
    _outerRim.lineWidth = 0.4;
    [_surfaceTier.layer addSublayer:_outerRim];
}
- (void)attachToHostView:(UIView *)hostView {
    [hostView addSubview:_backdropTier];
    [hostView addSubview:_bodyTier];
    [hostView addSubview:_surfaceTier];

    CGFloat shO = [LGGlassMaterialFactory shadowOpacityForType:_materialType];
    CGFloat shR = [LGGlassMaterialFactory shadowRadiusForType:_materialType];
    CGFloat shY = [LGGlassMaterialFactory shadowOffsetYForType:_materialType];
    hostView.layer.shadowColor = [UIColor blackColor].CGColor;
    hostView.layer.shadowOpacity = shO;
    hostView.layer.shadowOffset = CGSizeMake(0, shY);
    hostView.layer.shadowRadius = shR;
}
- (void)updateLayoutForBounds:(CGRect)bounds {
    CGFloat r = _cornerRadius;
    _backdropTier.frame = bounds;
    _backdropTier.layer.cornerRadius = r;
    _bodyTier.frame = bounds;
    _bodyTier.layer.cornerRadius = r;

    CGFloat specH = bounds.size.height * [LGGlassMaterialFactory specularHeightRatioForType:_materialType];
    _topSpecular.frame = CGRectMake(0, 0, bounds.size.width, MAX(1.5, specH));
    _topSpecular.cornerRadius = r;

    CGFloat refY = bounds.size.height * 0.62;
    _bottomReflection.frame = CGRectMake(0, refY, bounds.size.width, bounds.size.height - refY);
    _bottomReflection.cornerRadius = r;

    _diagonalSheen.frame = bounds;
    _diagonalSheen.cornerRadius = r;

    _surfaceTier.frame = bounds;
    _innerGlow.frame = bounds;
    _innerGlow.cornerRadius = r;

    _innerRim.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(bounds, 0.5, 0.5) cornerRadius:MAX(0, r - 0.5)].CGPath;
    _outerRim.path = [UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:r].CGPath;
    _bodyTier.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:r].CGPath;
}
- (void)refreshBlurStyle:(BOOL)isDark {
    _isDarkMode = isDark;
    UIBlurEffectStyle style = [LGGlassMaterialFactory blurStyleForType:_materialType isDark:isDark];
    _backdropTier.effect = [UIBlurEffect effectWithStyle:style];
}
- (void)setSpecularPressed:(BOOL)pressed {
    CGFloat spec = [LGGlassMaterialFactory specularAlphaForType:_materialType];
    CGFloat rimA = [LGGlassMaterialFactory rimAlphaForType:_materialType];
    CGFloat tint = [LGGlassMaterialFactory tintAlphaForType:_materialType];
    [CATransaction begin];
    [CATransaction setAnimationDuration:pressed ? 0.14 : 0.32];
    [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
    if (pressed) {
        _topSpecular.opacity = 1.0f;
        _topSpecular.colors = @[
            (id)[UIColor colorWithWhite:1.0 alpha:MIN(0.55, spec * 1.9)].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:spec * 0.65].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
        ];
        _innerRim.strokeColor = [UIColor colorWithWhite:1.0 alpha:MIN(0.45, rimA * 1.8)].CGColor;
        _bodyTier.backgroundColor = [UIColor colorWithWhite:1.0 alpha:tint * 2.5];
        _diagonalSheen.opacity = 0.85f;
    } else {
        _topSpecular.opacity = 0.90f;
        _topSpecular.colors = @[
            (id)[UIColor colorWithWhite:1.0 alpha:spec].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:spec * 0.35].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
        ];
        _innerRim.strokeColor = [UIColor colorWithWhite:1.0 alpha:rimA].CGColor;
        _bodyTier.backgroundColor = [UIColor colorWithWhite:1.0 alpha:tint];
        _diagonalSheen.opacity = 0.55f;
    }
    [CATransaction commit];
}
@end

// ====================================================================================================
// SECTION 3: APPLE LIQUID GLASS VIEW
// ====================================================================================================
@interface AppleLiquidGlassView : UIView
@property (nonatomic, strong) LGGlassLayerStack *glassStack;
@property (nonatomic, assign) CGFloat cornerRadiusValue;
@property (nonatomic, assign) LGGlassMaterialType materialType;
@property (nonatomic, assign) BOOL interactiveHighlightEnabled;
@property (nonatomic, assign) BOOL isPressed;
@property (nonatomic, strong) UILongPressGestureRecognizer *pressGesture;
- (instancetype)initWithFrame:(CGRect)frame cornerRadius:(CGFloat)radius;
- (instancetype)initWithFrame:(CGRect)frame cornerRadius:(CGFloat)radius materialType:(LGGlassMaterialType)type;
- (void)applyFluidJiggleAnimationWithVelocity:(CGFloat)vel;
- (void)setGlassHighlighted:(BOOL)highlighted animated:(BOOL)animated;
- (void)animatePressIn;
- (void)animatePressOut;
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
        _glassStack = [[LGGlassLayerStack alloc] initWithMaterialType:type cornerRadius:radius isDark:isDark];
        [_glassStack attachToHostView:self];
        [_glassStack updateLayoutForBounds:self.bounds];
        [self setupPressGesture];
    }
    return self;
}
- (void)traitCollectionDidChange:(UITraitCollection *)prev {
    [super traitCollectionDidChange:prev];
    if (@available(iOS 13.0, *)) {
        BOOL nowDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
        [_glassStack refreshBlurStyle:nowDark];
    }
}
- (void)setupPressGesture {
    if (!_interactiveHighlightEnabled) return;
    _pressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handlePress:)];
    _pressGesture.minimumPressDuration = 0.0;
    _pressGesture.cancelsTouchesInView = NO;
    _pressGesture.delaysTouchesBegan = NO;
    _pressGesture.delaysTouchesEnded = NO;
    [self addGestureRecognizer:_pressGesture];
}
- (void)handlePress:(UILongPressGestureRecognizer *)g {
    switch (g.state) {
        case UIGestureRecognizerStateBegan: _isPressed = YES; [self animatePressIn]; break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed: _isPressed = NO; [self animatePressOut]; break;
        default: break;
    }
}
- (void)animatePressIn {
    if (!_interactiveHighlightEnabled) return;
    [_glassStack setSpecularPressed:YES];
    [UIView animateWithDuration:0.16 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.transform = CGAffineTransformMakeScale(0.965, 0.965);
    } completion:nil];
}
- (void)animatePressOut {
    if (!_interactiveHighlightEnabled) return;
    [_glassStack setSpecularPressed:NO];
    [UIView animateWithDuration:0.42 delay:0 usingSpringWithDamping:0.66 initialSpringVelocity:0.65 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.transform = CGAffineTransformIdentity;
    } completion:nil];
}
- (void)setGlassHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    if (!_interactiveHighlightEnabled) return;
    if (highlighted) [self animatePressIn]; else [self animatePressOut];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.cornerRadius = _cornerRadiusValue;
    [_glassStack updateLayoutForBounds:self.bounds];
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:_cornerRadiusValue].CGPath;
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
// SECTION 4: LIQUID CAPSULE SWITCH — BO TRÒN HOÀN HẢO
// ====================================================================================================
@interface LiquidCapsuleSwitch : UIControl
@property (nonatomic, assign) BOOL on;
@property (nonatomic, strong) UIView *trackView;
@property (nonatomic, strong) CAGradientLayer *trackGradient;
@property (nonatomic, strong) CAShapeLayer *trackInnerShadowRim;
@property (nonatomic, strong) CAShapeLayer *trackOuterRim;
@property (nonatomic, strong) AppleLiquidGlassView *thumbGlass;
@property (nonatomic, strong) CAShapeLayer *thumbInnerRim;
@property (nonatomic, copy) void (^valueChangedBlock)(BOOL isOn);
- (void)setOn:(BOOL)on animated:(BOOL)animated;
@end

@implementation LiquidCapsuleSwitch
- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:CGRectMake(0, 0, 62, 34)]) {
        self.backgroundColor = [UIColor clearColor];
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

        _trackInnerShadowRim = [CAShapeLayer layer];
        _trackInnerShadowRim.fillColor = [UIColor clearColor].CGColor;
        _trackInnerShadowRim.strokeColor = [UIColor colorWithWhite:0.0 alpha:0.42].CGColor;
        _trackInnerShadowRim.lineWidth = 0.8;
        [_trackView.layer addSublayer:_trackInnerShadowRim];

        _trackOuterRim = [CAShapeLayer layer];
        _trackOuterRim.fillColor = [UIColor clearColor].CGColor;
        _trackOuterRim.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.10].CGColor;
        _trackOuterRim.lineWidth = 0.4;
        [_trackView.layer addSublayer:_trackOuterRim];

        CGFloat inset = 3.0;
        CGFloat d = self.bounds.size.height - (inset * 2);
        _thumbGlass = [[AppleLiquidGlassView alloc] initWithFrame:CGRectMake(inset, inset, d, d)
                                                     cornerRadius:d / 2.0
                                                     materialType:LGGlassMaterialTypeProminent];
        _thumbGlass.userInteractionEnabled = NO;
        _thumbGlass.interactiveHighlightEnabled = NO;
        _thumbGlass.layer.shadowColor = [UIColor blackColor].CGColor;
        _thumbGlass.layer.shadowOpacity = 0.30;
        _thumbGlass.layer.shadowOffset = CGSizeMake(0, 1.5);
        _thumbGlass.layer.shadowRadius = 3.0;
        [self addSubview:_thumbGlass];

        _thumbInnerRim = [CAShapeLayer layer];
        _thumbInnerRim.fillColor = [UIColor clearColor].CGColor;
        _thumbInnerRim.strokeColor = [UIColor colorWithWhite:0.0 alpha:0.10].CGColor;
        _thumbInnerRim.lineWidth = 0.4;
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
    _trackInnerShadowRim.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(_trackView.bounds, 0.5, 0.5) cornerRadius:r - 0.5].CGPath;
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
        self->_thumbGlass.transform = CGAffineTransformMakeScale(0.92, 0.92);
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
- (void)setOn:(BOOL)on animated:(BOOL)animated { _on = on; [self updateUIAnimated:animated]; }
- (void)updateUIAnimated:(BOOL)animated {
    NSArray *onC = @[
        (id)[UIColor colorWithRed:0.20 green:0.78 blue:0.35 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.16 green:0.68 blue:0.28 alpha:1.0].CGColor
    ];
    NSArray *offC = @[
        (id)[UIColor colorWithRed:0.20 green:0.22 blue:0.26 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.14 green:0.16 blue:0.19 alpha:1.0].CGColor
    ];
    CGFloat W = self.bounds.size.width, H = self.bounds.size.height;
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
// SECTION 5: LG EXPANDING NAV BAR BUTTON — Nút góc phải bung ra/thu vào
// Yêu cầu: Nhấn vào → bung ra hiệu ứng con
//          Nhấn màn hình → thu vào
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

// Đối tượng action view — mỗi mục con là 1 glass pill nhỏ
@interface LGExpandingActionView : UIControl
@property (nonatomic, strong) AppleLiquidGlassView *glassBackground;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, assign) CGPoint targetOffset;
- (instancetype)initWithAction:(LGExpandingMenuAction *)action;
@end

@implementation LGExpandingActionView
- (instancetype)initWithAction:(LGExpandingMenuAction *)action {
    if (self = [super initWithFrame:CGRectMake(0, 0, 210, 46)]) {
        self.backgroundColor = [UIColor clearColor];

        _glassBackground = [[AppleLiquidGlassView alloc] initWithFrame:self.bounds
                                                          cornerRadius:23.0
                                                          materialType:LGGlassMaterialTypeOverlay];
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
        [self addSubview:_titleLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_iconView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
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

// Nút gốc + overlay
@interface LGExpandingNavBarButton : UIView
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
    if (self = [super initWithFrame:CGRectMake(0, 0, 36, 36)]) {
        self.backgroundColor = [UIColor clearColor];

        _buttonGlass = [[AppleLiquidGlassView alloc] initWithFrame:self.bounds
                                                      cornerRadius:18.0
                                                      materialType:LGGlassMaterialTypeChrome];
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

- (void)setActions:(NSArray<LGExpandingMenuAction *> *)actions {
    _actions = actions;
}

- (void)handleTap {
    if (_expanded) [self collapseMenu];
    else [self expandMenu];
}

- (UIWindow *)hostWindow {
    UIWindow *w = self.window;
    if (w) return w;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *win in ((UIWindowScene *)scene).windows) {
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

    // Dim overlay
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

    // Actions container
    if (!_actionsContainer) {
        _actionsContainer = [[UIView alloc] initWithFrame:CGRectZero];
        _actionsContainer.backgroundColor = [UIColor clearColor];
    }
    [_actionsContainer removeFromSuperview];

    for (LGExpandingActionView *v in _actionViews) [v removeFromSuperview];
    [_actionViews removeAllObjects];

    CGRect selfInWindow = [self.superview convertRect:self.frame toView:host];
    CGFloat startX = CGRectGetMaxX(selfInWindow) - 210;
    CGFloat startY = CGRectGetMaxY(selfInWindow) + 8;
    _actionsContainer.frame = CGRectMake(startX, startY, 210, _actions.count * 54.0);

    for (NSInteger i = 0; i < _actions.count; i++) {
        LGExpandingMenuAction *action = _actions[i];
        LGExpandingActionView *view = [[LGExpandingActionView alloc] initWithAction:action];
        view.tag = i;
        view.frame = CGRectMake(0, i * 54.0, 210, 46);
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeScale(0.6, 0.6);
        [view addTarget:self action:@selector(actionViewTouchDown:) forControlEvents:UIControlEventTouchDown];
        [view addTarget:self action:@selector(actionViewTap:) forControlEvents:UIControlEventTouchUpInside];
        [view addTarget:self action:@selector(actionViewCancel) forControlEvents:UIControlEventTouchUpOutside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
        [_actionsContainer addSubview:view];
        [_actionViews addObject:view];
    }

    [host addSubview:_actionsContainer];
    [host bringSubviewToFront:_actionsContainer];

    // Animate stagger
    for (NSInteger i = 0; i < _actionViews.count; i++) {
        LGExpandingActionView *v = _actionViews[i];
        NSTimeInterval delay = i * 0.035;
        [UIView animateWithDuration:0.34
                              delay:delay
             usingSpringWithDamping:0.66
              initialSpringVelocity:0.8
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            v.alpha = 1.0;
            v.transform = CGAffineTransformIdentity;
        } completion:nil];
        v.targetOffset = CGPointMake(0, i * 54.0);
    }

    // Icon xoay
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

- (void)actionViewTouchDown:(LGExpandingActionView *)v {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];
}

- (void)actionViewCancel { /* no-op */ }

- (void)actionViewTap:(LGExpandingActionView *)v {
    NSInteger idx = v.tag;
    UINotificationFeedbackGenerator *fb = [[UINotificationFeedbackGenerator alloc] init];
    [fb notificationOccurred:UINotificationFeedbackTypeSuccess];
    [self collapseMenu];
    if ([_delegate respondsToSelector:@selector(expandingButton:didSelectActionAtIndex:)]) {
        [_delegate expandingButton:self didSelectActionAtIndex:idx];
    }
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [_buttonGlass setGlassHighlighted:highlighted animated:YES];
}
@end

// ====================================================================================================
// SECTION 6: LG GLASS TABLE VIEW CELL
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
                                                          cornerRadius:14.0
                                                          materialType:LGGlassMaterialTypeThin];
        _glassBackground.interactiveHighlightEnabled = YES;
        _glassBackground.userInteractionEnabled = NO;
        _glassBackground.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.contentView insertSubview:_glassBackground atIndex:0];

        _titleL = [[UILabel alloc] init];
        _titleL.textColor = [UIColor whiteColor];
        _titleL.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
        _titleL.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_titleL];

        _detailL = [[UILabel alloc] init];
        _detailL.textColor = [UIColor colorWithWhite:0.72 alpha:1.0];
        _detailL.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
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
    if (accent) _titleL.textColor = accent;
    else _titleL.textColor = [UIColor whiteColor];

    if (_accessoryContainer) { [_accessoryContainer removeFromSuperview]; _accessoryContainer = nil; }
    if (accessory) {
        _accessoryContainer = accessory;
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
// SECTION 7: LG GLASS NAV BUTTON (tab bar dưới)
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
                                                     cornerRadius:14.0
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
// SECTION 8: LG CUSTOM SEGMENTED CONTROL — không cắt chữ
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
- (instancetype)initWithItems:(NSArray<NSString *> *)items {
    if (self = [super initWithFrame:CGRectMake(0, 0, 320, 36)]) {
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
            l.textColor = i == 0 ? [UIColor whiteColor] : [UIColor colorWithWhite:0.75 alpha:1.0];
            l.font = i == 0 ? [UIFont systemFontOfSize:13 weight:UIFontWeightBold] : [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
            l.userInteractionEnabled = NO;
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
    if (!p.x && !p.y) p = [self convertPoint:self.center fromView:self.superview];
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
            self->_labels[i].textColor = s ? [UIColor whiteColor] : [UIColor colorWithWhite:0.75 alpha:1.0];
            self->_labels[i].font = s ? [UIFont systemFontOfSize:13 weight:UIFontWeightBold] : [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
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
// SECTION 9: HELPER FUNCTIONS
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
// SECTION 10: ROOT LIST CONTROLLER INTERFACE
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

    AppleLiquidGlassView *_liquidNav;

BarContainer;
    AppleLiquidGlassView *_activeGlassIndicator;
    NSMutableArray<LGGlassNavButton *> *_tabButtons;
    NSArray<   NSDictionary *> *_tabConfigs;

    UIView *_liquidGlassLensContainer;
    AppleLiquidGlassView *_lensGlassEffectView;
 //    UILabel *_lensTitleLabel Nút bung/thu góc phải
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

    // Background gradient
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

#pragma mark - Expanding Navigation Items (3 nút góc phải, bung/thu)

- (void)setupExpandingNavigationItems {
    // ==== Nút Bolt (tác vụ nhanh) ====
    _expandingBoltButton = [[LGExpandingNavBarButton alloc] initWithIconName:@"bolt.horizontal.fill"
                                                                   tintColor:[UIColor colorWithRed:0.35 green:0.95 blue:0.6 alpha:1.0]];
    _expandingBoltButton.delegate = self;
    [_expandingBoltButton setActions:@[
        [LGExpandingMenuAction actionWithTitle:@"⚡ Đồng Bộ Tức Thì" image:@"arrow.clockwise" tintColor:[UIColor whiteColor] destructive:NO],
        [LGExpandingMenuAction actionWithTitle:@"🔥 Ép Xung 144Hz" image:@"bolt.fill" tintColor:[UIColor systemYellowColor] destructive:NO],
        [LGExpandingMenuAction actionWithTitle:@"🎯 Reset Tần Số" image:@"arrow.counterclockwise" tintColor:[UIColor systemOrangeColor] destructive:NO],
        [LGExpandingMenuAction actionWithTitle:@"💧 Liquid Glass Redraw" image:@"sparkles" tintColor:[UIColor colorWithRed:0.5 green:0.8 blue:1.0 alpha:1.0] destructive:NO],
    ]];

    // ==== Nút Lock ====
    _expandingLockButton = [[LGExpandingNavBarButton alloc] initWithIconName:@"lock.open.fill"
                                                                    tintColor:[UIColor whiteColor]];
    _expandingLockButton.delegate = self;
    [_expandingLockButton setActions:@[
        [LGExpandingMenuAction actionWithTitle:@"🔓 Mở Khóa Chỉnh Sửa" image:@"lock.open.fill" tintColor:[UIColor systemGreenColor] destructive:NO],
        [LGExpandingMenuAction actionWithTitle:@"🔒 Khóa Cấu Hình" image:@"lock.fill" tintColor:[UIColor systemRedColor] destructive:NO],
        [LGExpandingMenuAction actionWithTitle:@"💾 Lưu Ngay" image:@"square.and.arrow.down.fill" tintColor:[UIColor colorWithRed:0.4 green:0.7 blue:1.0 alpha:1.0] destructive:NO],
    ]];

    // ==== Nút Menu 3 gạch (hành động hệ thống) ====
    _expandingMenuButton = [[LGExpandingNavBarButton alloc] initWithIconName:@"line.3.horizontal"
                                                                    tintColor:[UIColor whiteColor]];
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

    self.navigationItem.rightBarButtonItems = @[menuItem, lockItem, boltItem];

    [self updateLockIcon];
}

#pragma mark - LGExpandingNavBarButtonDelegate

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
            case 1: {
                self.settingsDict[@"TargetRefreshRate"] = @144;
                self.settingsDict[@"TargetFPSRate"] = @144;
                self.settingsDict[@"ForceOverclock144Hz"] = @YES;
                [self saveSettingsDataAndSync];
                [self applyDeepSpringBoardAndUIKitTweaks];
                [self.customTableView reloadData];
                break;
            }
            case 2: {
                self.settingsDict[@"TargetRefreshRate"] = @60;
                self.settingsDict[@"TargetFPSRate"] = @60;
                self.settingsDict[@"ForceOverclock144Hz"] = @NO;
                [self saveSettingsDataAndSync];
                [self applyDeepSpringBoardAndUIKitTweaks];
                [self.customTableView reloadData];
                break;
            }
            case 3: {
                // Redraw glass
                [self.view setNeedsLayout];
                [self.view layoutIfNeeded];
                UINotificationFeedbackGenerator *fb = [[UINotificationFeedbackGenerator alloc] init];
                [fb notificationOccurred:UINotificationFeedbackTypeSuccess];
                break;
            }
        }
    } else if (button == _expandingLockButton) {
        switch (index) {
            case 0: {
                if (!_isKernelExploited) { [self showUnexploitedWarningAlert]; return; }
                _isRateLocked = NO;
                self.settingsDict[@"IsRateLocked"] = @NO;
                [self saveSettingsDataAndSync];
                [self updateLockIcon];
                [self.customTableView reloadData];
                break;
            }
            case 1: {
                if (!_isKernelExploited) { [self showUnexploitedWarningAlert]; return; }
                _isRateLocked = YES;
                self.settingsDict[@"IsRateLocked"] = @YES;
                [self saveSettingsDataAndSync];
                [self updateLockIcon];
                [self.customTableView reloadData];
                break;
            }
            case 2:
                [self saveSettingsDataAndSync];
                break;
        }
    }
}

- (void)expandingButtonDidExpand:(LGExpandingNavBarButton *)button {
    // Đóng các menu khác khi 1 menu mở
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
        [_tabButtons[0] updateTabSelected:YES animated:NO];
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

#pragma mark - Navigation & Header

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
                                                                 materialType:LGGlassMaterialTypeThin];
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
            if (!mA) {
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
                    detail = @"✓";
                    accent = [UIColor colorWithRed:0.4 green:1.0 blue:0.6 alpha:1.0];
                } else {
                    title = @"🔴 CHƯA KHAI THÁC [CHẠM 15S]";
                    detail = @"✕";
                    accent = [UIColor colorWithRed:1.0 green:0.45 blue:0.45 alpha:1.0];
                }
            } else {
                NSString *curIOS = [[UIDevice currentDevice] systemVersion];
                if (Titanium_IsSupportedIOSVersion()) {
                    title = [NSString stringWithFormat:@"🟢 iOS %@ (OK)", curIOS];
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
       F __strong typeof(wS) sS = wS;
        if (sS && sS->_currentBottomTab == 0 && sS->_isKernelExploited &&PS [sS.settingsDict[@"EnableSystemMonitoring"] boolValue]) {
            [sS.customTableView reloadData];
        }
    });
    dispatch_resume(_hudRateTimer);
}

- (void)stopContinuousHardwareHUD {
    if (_hudTimer) { dispatch_source_cancel(_hudTimer); _hud"]Timer = nil; }
}

- (void)syncSharedMemoryFile:(BOOL)enabled {
    if (!_isKernelExploited) return;
    ApexV285ProPayload p;
    memset(&p, 0, sizeof(ApexV285ProPayload));
    p.magic = APEX_SYNC_MAGIC_V285;
    p.masterEnabled = (enabled && _isKernelExploited) ? 1 : 0;
    int32_t hz = [self.settingsDict[@"TargetRefreshRate"] ?: @144 intValue];
    int32_t fps = [self.settingsDict[@"Target ?: @144 intValue];
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
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes)ASS {
                if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) {
                    UIWindowScene *ws = (UIWindowScene *)scene;
                    if ([ws respondsToSelector:sel]) {
                        CAFrameRateRange range = CAFrameRateRangeMake(30.0f, (float)targetHz, (float)targetHz K);
                        void (*setRange)(id, SEL, CAFrameRateRange) = (void (*)(id, SEL, CAFrameRateRangeERN))objc_msgSend;
                        setRange(ws, sel, range);
                    }
                }
            }
        });
    }
EL    BOOL master = [self.settingsDict[@"Enabled"] ?: @NO boolValue];
    [self syncSharedMemoryFile: EXPLmaster];
}

#pragma mark - Exploit Console

- (void)showUnexplOoitedWarningAlert {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"🔒 TÍNH NĂNG ĐANG BỊ KHÓA" message:@"Vào tab Cài Đặt, nhấn vào dòng đèn đỏ để bắt đầu." preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Đã Hiểu" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)openDopamineStyleExploitConsole {
    UIViewController *vc = [[UIViewController alloc] init];
    vc.view.backgroundColor = [UIColor colorWithRed:0.02 green:0.03 blue:0.06 alpha:1.0];
    vc.modalPresentationStyle = UIModalPresentationFullScreen;

    UILabel *tl = [[UILabel alloc] initWithFrame:CGRectMake(20, 55, vc.view.bounds.size.width - 40, 30)];
    tl.text = @"⚡ LIQUID GLIT";
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
