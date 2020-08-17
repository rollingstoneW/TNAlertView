//
//  TNAlertView.h
//  TNAlertView
//
//  Created by rollingstoneW on 2020/3/30.
//

#import "TNAbstractPopupView.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, TNAlertActionStyleStyle) {
    TNAlertActionStyleCancel, // 取消，灰色
    TNAlertActionStyleDefault, // 默认，黑色
    TNAlertActionStyleDestructive // 销毁，红色
};

typedef NS_ENUM(NSUInteger, TNAlertButtonAlignment) {
    TNAlertButtonAlignmentLeft, // 居左显示，如果只有一个，则会充满弹窗
    TNAlertButtonAlignmentCenter, // 居中显示，本行只显示一个button
    TNAlertButtonAlignmentFill, // 充满弹窗
};

typedef NS_ENUM(NSUInteger, TNAlertFollowingKeyboardPosition) {
    TNAlertFollowingKeyboardPositionNone, // 不跟随键盘移动
    TNAlertFollowingKeyboardAtAlertBottom, // alert底部跟随键盘移动
    TNAlertFollowingKeyboardAtActiveInputBottom, // 当前输入框跟随键盘移动
};

typedef NS_ENUM(NSUInteger, TNAlertAnimation) {
    TNAlertAnimationFade, // 透明度变化
    TNAlertAnimationZoomIn, // 缩小动画
    TNAlertAnimationZoomOut, // 放大动画
    TNAlertAnimationTranslationFromTop, // 从上边出现
    TNAlertAnimationTranslationFromLeft, // 从左边出现
    TNAlertAnimationTranslationFromBottom, // 从下边出现
    TNAlertAnimationTranslationFromRight // 从右边出现
};

/*
 弹窗上的按钮，默认有取消、默认、销毁三种样式，可继承自定义。
 */
@interface TNAlertButton : UIButton

@property (nonatomic, copy, readonly, nullable) NSString *title;
@property (nonatomic, assign) TNAlertActionStyleStyle style;
@property (nonatomic, strong) void(^ _Nullable handler)(TNAlertButton *button);

@property (nonatomic, assign) TNAlertButtonAlignment alignment; // 停靠模式，默认TNAlertButtonAlignmentLeft
@property (nonatomic, assign) BOOL shouldDismissAlert; // 触发时是否dimiss掉alert，默认YES

@property (nonatomic, assign) CGFloat preferredHeight UI_APPEARANCE_SELECTOR; // 高度，默认40

+ (instancetype)buttonWithTitle:(id _Nullable)title
                          style:(TNAlertActionStyleStyle)style
                        handler:(void(^ _Nullable)(TNAlertButton *button))handler;

@end

/*
 扩展性高、易用的弹窗类。
 注意：修改UI_APPEARANCE_SELECTOR修饰的属性，记得在视图展示后修改，可以重写didShow:方法修改
 */
@interface TNAlertView : TNAbstractPopupView

@property (nullable, nonatomic, strong, readonly) UILabel *titleLabel;
@property (nullable, nonatomic, copy) id title; // NSString或者NSAttributedString，如果是NSAttributedString则忽略titleAttributes
@property (nonatomic, copy) NSDictionary *titleAttributes UI_APPEARANCE_SELECTOR; // 标题样式，默认黑色18号字体
@property (nonatomic, assign) UIEdgeInsets titleInsets UI_APPEARANCE_SELECTOR; // 标题到弹窗的距离，默认{10, 20, 0, 20}

@property (nullable, nonatomic, strong, readonly) UITextView *messageTextView;
@property (nullable, nonatomic, copy) id message; // NSString或者NSAttributedString，如果是NSAttributedString则忽略messageAttributes
@property (nonatomic, copy) NSDictionary *messageAttributes UI_APPEARANCE_SELECTOR; // 消息样式，默认38%黑色14号字体，行间距5
@property (nonatomic, assign) UIEdgeInsets messageInsets UI_APPEARANCE_SELECTOR; // 消息到标题、弹窗的距离，默认{10, 20, 10, 20}，距离标题为titleInsets.bottom + messageInsets.top

@property (nonatomic, strong, readonly) UIView *buttonContainer;
@property (nonatomic, strong) NSArray<TNAlertButton *> *buttons;
@property (nonatomic, assign) UIEdgeInsets buttonInsets UI_APPEARANCE_SELECTOR; // 按钮距离消息、弹窗的距离，默认{5, 0, 5, 0}，距离消息为messageInsets.bottom + buttonInsets.top
@property (nonatomic, assign) CGFloat buttonHorizentalSpacing UI_APPEARANCE_SELECTOR; // 按钮横向间距，默认0
@property (nonatomic, assign) CGFloat buttonVerticalSpacing UI_APPEARANCE_SELECTOR; // 按钮纵向间距，默认0
@property (nonatomic, assign) BOOL showButtonSeparator UI_APPEARANCE_SELECTOR; // 是否展示按钮分割线，默认YES
@property (nonatomic, strong) UIColor *buttonSeparatorColor UI_APPEARANCE_SELECTOR; // 按钮分割线颜色，默认lightGray

@property (nonatomic, assign) CGFloat preferredWidth UI_APPEARANCE_SELECTOR; // 宽度，默认280
@property (nonatomic, assign) CGFloat cornerRadius UI_APPEARANCE_SELECTOR; // 圆角，默认12
@property (nonatomic, assign) UIColor *dimBgColor UI_APPEARANCE_SELECTOR; // 蒙层背景色，默认70%黑色
@property (nonatomic, assign) BOOL shouldCustomContentViewAutoScroll; // 自定义视图超出最大高度自定义视图是否可以自动滚动，默认YES

@property (nonatomic, assign) TNAlertAnimation showingAimation; // 展示的动画，默认为fade
@property (nonatomic, assign) TNAlertAnimation dismissingAnimation; // 隐藏的动画，默认为fade

@property (nullable, nonatomic, strong, readonly) __kindof UIView *customContentView;
@property (nullable, nonatomic, strong, readonly) NSArray<UITextField *> *textFields;

@property (nonatomic, assign) TNAlertFollowingKeyboardPosition followingKeyboardPosition UI_APPEARANCE_SELECTOR; // 跟随键盘移动的位置
@property (nonatomic, assign) CGFloat followingKeyboardSpacing UI_APPEARANCE_SELECTOR; // 位置距离键盘的距离

@property (nullable, nonatomic, strong) dispatch_block_t willShow; // 将要展示
@property (nullable, nonatomic, strong) dispatch_block_t didShow; // 已经展示
@property (nullable, nonatomic, strong) dispatch_block_t willDismiss; // 将要消失
@property (nullable, nonatomic, strong) dispatch_block_t didDismis; // 已经消失
@property (nullable, nonatomic, strong) void(^actionHandler)(__kindof TNAlertButton *action, NSInteger index);

- (instancetype)initWithTitle:(id _Nullable)title
                      message:(id _Nullable)message
                      buttons:(NSArray<__kindof TNAlertButton *> *)buttons;

- (instancetype)initWithTitle:(id _Nullable)title
                      message:(id _Nullable)message
                  cancelTitle:(NSString *)cancel
                 confirmTitle:(NSString *)confirm;

- (instancetype)initWithTitle:(id _Nullable)title
                      message:(id _Nullable)message
                 confirmTitle:(NSString *)confirm;

- (void)addCustomContentView:(__kindof UIView *)contentView edgeInsets:(UIEdgeInsets)insets;
- (void)addTextFieldWithConfiguration:(void (^ __nullable)(UITextField *textField))configuration edgeInsets:(UIEdgeInsets)insets;

- (void)addButton:(TNAlertButton *)button;

// 大小发生变化
- (void)executeWhenAlertSizeDidChange:(void(^)(CGSize size))block;

// 取消
- (void)cancel;

// 子类继承
- (void)setupDefaults;
// 子类继承
- (void)loadSubviews;

// 自定义内容区域最大可见范围
- (CGSize)customContentViewMaxVisibleSize;

@end

NS_ASSUME_NONNULL_END
