#ifndef PSSPECIFIER_H
#define PSSPECIFIER_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Enum định nghĩa loại cell trong PreferenceKit.
 * Khớp chính xác với PSConstants.h trong Private Framework.
 * iOS 14.0 - 26.0.1 compatible.
 */
typedef NS_ENUM(NSInteger, PSType) {
    PSGroupCell = 0,
    PSTitleValueCell = 1,
    PSSliderCell = 2,
    PSSwitchCell = 3,
    PSEditTextCell = 4,
    PSStaticTextCell = 5,
    PSLinkCell = 6,
    PSMultiValueCell = 7,
    PSRadioGroupCell = 8,
    PSCheckboxCell = 9,
    PSSegmentCell = 10,
    PSButtonCell = 11,
    PSFooterTextGroupCell = 12,
    PSHeaderStaticTextGroupCell = 13
};

/**
 * Đối tượng mô tả một mục cấu hình trong Settings.
 * Được tạo bởi [PSSpecifier preferenceSpecifierNamed:title:detail:cell:edit:get:set:values:titles:min:max:]
 * Hỗ trợ đầy đủ cho iOS 14-26 Rootless PreferenceKit.
 */
@interface PSSpecifier : NSObject

@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic, copy, nullable) NSString *label;
@property (nonatomic, assign) PSType cellType;
@property (nonatomic, retain, nullable) id target;
@property (nonatomic, assign) SEL getter;
@property (nonatomic, assign) SEL setter;
@property (nonatomic, assign) SEL action;
@property (nonatomic, retain, nullable) id defaultValue;
@property (nonatomic, retain, nullable) NSArray *validValues;
@property (nonatomic, retain, nullable) NSArray *titleStrings;
@property (nonatomic, assign) CGFloat sliderMin;
@property (nonatomic, assign) CGFloat sliderMax;
@property (nonatomic, assign) BOOL showValue;
@property (nonatomic, retain, nullable) NSString *footerText;
@property (nonatomic, retain, nullable) NSString *placeholder;
@property (nonatomic, retain, nullable) NSDictionary *properties;

/**
 * Khởi tạo specifier mới (constructor chuẩn của PreferenceKit).
 * @param name Tên internal key dùng để lưu trữ value.
 * @param title Tiêu đề hiển thị trên UI.
 * @param detail Mô tả chi tiết (footer text).
 * @param type Loại cell (PSTitleValueCell, PSSwitchCell...).
 * @param editClass Class xử lý editing (thường là nil).
 * @param getSelector Selector lấy giá trị hiện tại.
 * @param setSelector Selector lưu giá trị mới.
 * @param values Mảng giá trị khả dụng (cho MultiValue/Radio).
 * @param titles Mảng tiêu đề tương ứng với values.
 * @param minVal Giá trị tối thiểu (cho Slider).
 * @param maxVal Giá trị tối đa (cho Slider).
 */
- (instancetype)initWithName:(nullable NSString *)name
                       title:(nullable NSString *)title
                      detail:(nullable NSString *)detail
                        cell:(PSType)type
                    editClass:(nullable Class)editClass
                          get:(SEL)getSelector
                          set:(SEL)setSelector
                       values:(nullable NSArray *)values
                       titles:(nullable NSArray *)titles
                          min:(double)minVal
                          max:(double)maxVal;

/**
 * Factory method chuẩn của PreferenceKit.
 * Tạo specifier từ plist dictionary hoặc manual parameters.
 */
+ (instancetype)preferenceSpecifierNamed:(nullable NSString *)name
                                   title:(nullable NSString *)title
                                  detail:(nullable NSString *)detail
                                    cell:(PSType)type
                                editClass:(nullable Class)editClass
                                      get:(SEL)getSelector
                                      set:(SEL)setSelector
                                   values:(nullable NSArray *)values
                                   titles:(nullable NSArray *)titles
                                      min:(double)minVal
                                      max:(double)maxVal;

/**
 * Lấy giá trị hiện tại của specifier qua getter selector.
 * @return Giá trị hiện tại hoặc defaultValue nếu chưa set.
 */
- (nullable id)performGetter;

/**
 * Set giá trị mới cho specifier qua setter selector.
 * @param value Giá trị mới cần lưu.
 */
- (void)performSetterWithValue:(nullable id)value;

/**
 * Trigger action selector khi user tap vào cell.
 * Dùng cho PSButtonCell và PSLinkCell.
 */
- (void)performAction;

@end

NS_ASSUME_NONNULL_END

#endif /* PSSPECIFIER_H */
