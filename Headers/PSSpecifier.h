#ifndef PSSPECIFIER_H
#define PSSPECIFIER_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * PSType - Enum định nghĩa loại cell trong PreferenceKit.
 * Khớp chính xác với PSConstants.h trong Private Framework Preferences.
 * iOS 14.0 - 26.0.1 compatible.
 */
typedef NS_ENUM(NSInteger, PSCellType) {
    PSGroupCell = 0,
    PSLinkCell = 1,
    PSLinkListCell = 2,
    PSListItemCell = 3,
    PSTitleValueCell = 4,
    PSSliderCell = 5,
    PSSwitchCell = 6,
    PSStaticTextCell = 7,
    PSEditTextCell = 8,
    PSSegmentCell = 9,
    PSGiantCell = 10,
    PSGiantIconCell = 11,
    PSMultiValueCell = 12,
    PSSecureEditTextCell = 13,
    PSButtonCell = 14,
    PSEditTextViewCell = 15,
    PSSpinnerCell = 16,
    PSHeaderStaticTextGroupCell = 17,
    PSFooterTextGroupCell = 18,
};

// Alias cho tương thích ngược
typedef PSCellType PSType;

/**
 * PSSpecifier - Đối tượng mô tả một mục cấu hình trong Settings.
 * 
 * Được tạo tự động bởi [PSListController loadSpecifiersFromPlistName:target:]
 * từ file Root.plist trong Resources/.
 * 
 * Mỗi dict trong Root.plist array "items" trở thành 1 PSSpecifier instance.
 * 
 * An toàn tuyệt đối trên iOS 14-26 Rootless.
 */
@interface PSSpecifier : NSObject

// ==============================================================================
// CORE PROPERTIES - Khớp với keys trong Root.plist
// ==============================================================================

/** Tên internal key dùng để lưu trữ value vào UserDefaults */
@property (nonatomic, copy, nullable) NSString *identifier;

/** Tiêu đề hiển thị trên UI (key "label" trong plist) */
@property (nonatomic, copy, nullable) NSString *name;

/** Loại cell (key "cell" trong plist) */
@property (nonatomic, assign) PSCellType cellType;

/** Target object để resolve selector get/set/action */
@property (nonatomic, assign, nullable) id target;

/** Selector lấy giá trị hiện tại (key "get" trong plist) */
@property (nonatomic, assign) SEL getter;

/** Selector lưu giá trị mới (key "set" trong plist) */
@property (nonatomic, assign) SEL setter;

/** Selector action khi tap (key "action" trong plist) */
@property (nonatomic, assign) SEL action;

/** Giá trị mặc định (key "default" trong plist) */
@property (nonatomic, retain, nullable) id defaultValue;

/** Domain UserDefaults (key "defaults" trong plist) */
@property (nonatomic, copy, nullable) NSString *defaultsDomain;

/** Key trong UserDefaults (key "key" trong plist) */
@property (nonatomic, copy, nullable) NSString *key;

// ==============================================================================
// MULTI-VALUE / LINK-LIST PROPERTIES
// ==============================================================================

/** Mảng giá trị khả dụng cho PSLinkListCell / PSMultiValueCell */
@property (nonatomic, retain, nullable) NSArray *validValues;

/** Mảng tiêu đề tương ứng với validValues */
@property (nonatomic, retain, nullable) NSArray *titleStrings;

/** Class controller cho PSLinkListCell (key "detail" trong plist) */
@property (nonatomic, copy, nullable) NSString *detailControllerClass;

// ==============================================================================
// SLIDER PROPERTIES
// ==============================================================================

/** Giá trị tối thiểu cho PSSliderCell (key "min" trong plist) */
@property (nonatomic, assign) CGFloat sliderMin;

/** Giá trị tối đa cho PSSliderCell (key "max" trong plist) */
@property (nonatomic, assign) CGFloat sliderMax;

/** Hiển thị giá trị số trên slider (key "showValue" trong plist) */
@property (nonatomic, assign) BOOL showValue;

// ==============================================================================
// DISPLAY PROPERTIES
// ==============================================================================

/** Footer text hiển thị dưới group (key "footerText" trong plist) */
@property (nonatomic, copy, nullable) NSString *footerText;

/** Placeholder cho PSEditTextCell (key "placeholder" trong plist) */
@property (nonatomic, copy, nullable) NSString *placeholder;

/** Icon name (key "icon" trong plist) */
@property (nonatomic, copy, nullable) NSString *iconName;

/** Post notification name khi value thay đổi (key "PostNotification" trong plist) */
@property (nonatomic, copy, nullable) NSString *postNotificationName;

/** Keyboard type cho PSEditTextCell (key "keyboard" trong plist) */
@property (nonatomic, copy, nullable) NSString *keyboardType;

/** Properties dictionary bổ sung */
@property (nonatomic, retain, nullable) NSDictionary *properties;

// ==============================================================================
// FACTORY METHODS
// ==============================================================================

/**
 * Factory method chuẩn của PreferenceKit.
 * Tạo specifier từ các parameter riêng lẻ.
 */
+ (instancetype)preferenceSpecifierNamed:(nullable NSString *)name
                                   target:(nullable id)target
                                      set:(nullable SEL)setSelector
                                      get:(nullable SEL)getSelector
                                   detail:(nullable Class)detailClass
                                     cell:(PSCellType)cellType
                                     edit:(nullable Class)editClass;

/**
 * Khởi tạo specifier trống.
 */
- (instancetype)init;

// ==============================================================================
// VALUE ACCESSORS
// ==============================================================================

/**
 * Lấy giá trị hiện tại qua getter selector hoặc từ UserDefaults.
 * @return Giá trị hiện tại hoặc defaultValue nếu chưa set
 */
- (nullable id)performGetter;

/**
 * Set giá trị mới qua setter selector và ghi vào UserDefaults.
 * @param value Giá trị mới cần lưu
 */
- (void)performSetterWithValue:(nullable id)value;

/**
 * Trigger action selector khi user tap vào cell.
 * Dùng cho PSButtonCell và PSLinkCell.
 */
- (void)performAction;

/**
 * Gửi PostNotification nếu có cấu hình.
 * Gọi tự động sau khi value thay đổi.
 */
- (void)sendPostNotification;

@end

NS_ASSUME_NONNULL_END

#endif /* PSSPECIFIER_H */
