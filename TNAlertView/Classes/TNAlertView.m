//
//  TNAlertView.m
//  TNAlertView
//
//  Created by rollingstoneW on 2020/3/30.
//

#import "TNAlertView.h"
#import <Masonry/Masonry.h>

static NSDictionary *TNAlertButtonCancelTitleAttributes() {
    return @{NSFontAttributeName: [UIFont systemFontOfSize:16], NSForegroundColorAttributeName: [UIColor grayColor]};
}

static NSDictionary *TNAlertButtonConfirmTitleAttributes() {
    return @{NSFontAttributeName: [UIFont systemFontOfSize:16], NSForegroundColorAttributeName: [UIColor blackColor]};
}

static NSDictionary *TNAlertButtonDestructiveTitleAttributes() {
    return @{NSFontAttributeName: [UIFont boldSystemFontOfSize:16], NSForegroundColorAttributeName: [UIColor redColor]};
}

typedef void(^ContainerSizeDidChange)(CGSize size);

@interface TNAlertButton ()

@property (nonatomic, assign) CGSize lastSize;
@property (nonatomic, assign) NSInteger row;
@property (nonatomic, assign) NSInteger line;

@end

@implementation TNAlertButton

+ (void)initialize {
    if (self == [TNAlertButton class]) {
        TNAlertButton *appearance = TNAlertButton.appearance;
        appearance.preferredHeight = 40;
    }
}

+ (instancetype)buttonWithTitle:(id)title style:(TNAlertActionStyleStyle)style handler:(void (^)(TNAlertButton * _Nonnull))handler {
    TNAlertButton *button = [self buttonWithType:UIButtonTypeCustom];
    NSAttributedString *prettyTitle;
    if ([title isKindOfClass:[NSAttributedString class]]) {
        prettyTitle = title;
    } else if ([title isKindOfClass:[NSString class]]) {
        switch (style) {
            case TNAlertActionStyleCancel:
                prettyTitle = [[NSAttributedString alloc] initWithString:title attributes:TNAlertButtonCancelTitleAttributes()];
                break;
            case TNAlertActionStyleDefault:
                prettyTitle = [[NSAttributedString alloc] initWithString:title attributes:TNAlertButtonConfirmTitleAttributes()];
                break;
            case TNAlertActionStyleDestructive:
                prettyTitle = [[NSAttributedString alloc] initWithString:title attributes:TNAlertButtonDestructiveTitleAttributes()];
                break;
        }
    }
    if (prettyTitle) {
        [button setAttributedTitle:prettyTitle forState:UIControlStateNormal];
    }
    button.style = style;
    button.handler = handler;
    return button;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        _shouldDismissAlert = YES;
    }
    return self;
}

- (NSString *)title {
    return self.currentTitle ?: self.currentAttributedTitle.string;
}

- (void)dealloc {
    self.handler = nil;
}

@end

@interface TNAlertView () <UITextFieldDelegate>

@property (nullable, nonatomic, strong) UILabel *titleLabel;
@property (nullable, nonatomic, strong) UITextView *messageTextView;
@property (nullable, nonatomic, strong) UIView *contentViewContainer;
@property (nullable, nonatomic, strong) __kindof UIView *customContentView;
@property (nonatomic, strong) NSArray *separators;
@property (nonatomic, strong) UIView *buttonContainer;

@property (nullable, nonatomic, strong) NSAttributedString *prettyTitle;
@property (nullable, nonatomic, strong) NSAttributedString *prettyMessage;

@property (nonatomic, strong) MASConstraint *buttonContainerTop;
@property (nonatomic, strong) MASConstraint *containerCenterY;
@property (nonatomic, assign) CGFloat centerYOffset;

@property (nonatomic, strong) NSMutableArray<UITextField *> *innnerTextFields;

@property (nonatomic, strong) NSMutableArray<ContainerSizeDidChange> *sizeDidChangeBlocks;

@property (nonatomic, assign) CGSize lastSize;
@property (nonatomic, assign) CGFloat keyboardTop;

@end

@implementation TNAlertView

#pragma mark - LifeCycle

+ (void)initialize {
    if (self == [TNAlertView class]) {
        TNAlertView *appearance = [self appearance];
        
        NSMutableParagraphStyle *titleStyle = [[NSMutableParagraphStyle alloc] init];
        titleStyle.lineSpacing = 6;
        titleStyle.alignment = NSTextAlignmentCenter;
        appearance.titleAttributes = @{NSFontAttributeName: [UIFont systemFontOfSize:18],
                                       NSForegroundColorAttributeName: [UIColor blackColor],
                                       NSParagraphStyleAttributeName: titleStyle};
        
        NSMutableParagraphStyle *messageStyle = [[NSMutableParagraphStyle alloc] init];
        messageStyle.lineSpacing = 5;
        messageStyle.alignment = NSTextAlignmentCenter;
        appearance.messageAttributes = @{NSFontAttributeName: [UIFont systemFontOfSize:14],
                                         NSForegroundColorAttributeName: [[UIColor blackColor] colorWithAlphaComponent:0.38],
                                         NSParagraphStyleAttributeName: messageStyle};
        appearance.titleInsets = UIEdgeInsetsMake(10, 20, 0, 20);
        appearance.messageInsets = UIEdgeInsetsMake(10, 20, 10, 20);
        appearance.buttonInsets = UIEdgeInsetsMake(5, 0, 5, 0);
        appearance.preferredWidth = 280;
        appearance.cornerRadius = 12;
        appearance.dimBgColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
        appearance.followingKeyboardSpacing = 20;
        appearance.showButtonSeparator = YES;
        appearance.buttonSeparatorColor = UIColor.lightGrayColor;
        appearance.autoAdjustSafeAreaInsets = YES;
    }
}

- (instancetype)initWithTitle:(id)title message:(id)message buttons:(NSArray<TNAlertButton *> *)buttons {
    if (self = [super initWithFrame:CGRectZero]) {
        _title = title;
        _message = message;
        _buttons = buttons;
        [self setupDefaults];
        [self loadSubviews];
    }
    return self;
}

- (instancetype)initWithTitle:(id)title
                      message:(id)message
                  cancelTitle:(NSString *)cancel
                 confirmTitle:(NSString *)confirm {
    TNAlertButton *cancelbutton = [TNAlertButton buttonWithTitle:cancel style:TNAlertActionStyleCancel handler:nil];
    TNAlertButton *confirmbutton = [TNAlertButton buttonWithTitle:confirm style:TNAlertActionStyleDefault handler:nil];
    return [self initWithTitle:title message:message buttons:@[cancelbutton, confirmbutton]];
}

- (instancetype)initWithTitle:(id)title message:(id)message confirmTitle:(NSString *)confirm {
    TNAlertButton *confirmbutton = [TNAlertButton buttonWithTitle:confirm style:TNAlertActionStyleDefault handler:nil];
    return [self initWithTitle:title message:message buttons:@[confirmbutton]];
}


- (void)dealloc {
    self.sizeDidChangeBlocks = nil;
    @try {
        [self.messageTextView removeObserver:self forKeyPath:@"contentSize"];
        if ([self.contentViewContainer isKindOfClass:[UIScrollView class]]) {
            [self.contentViewContainer removeObserver:self forKeyPath:@"contentSize"];
        }
    } @catch (NSException *exception) {
    } @finally {
    }
}

#pragma mark - Public

- (void)addContentView:(__kindof UIView *)contentView edgeInsets:(UIEdgeInsets)insets {
    if (!self.contentViewContainer) {
        if (self.shouldCustomContentViewAutoScroll) {
            UIScrollView *container = [[UIScrollView alloc] init];
            container.showsVerticalScrollIndicator = container.showsHorizontalScrollIndicator = NO;
            [container addObserver:self forKeyPath:@"contentSize" options:NSKeyValueObservingOptionNew context:nil];
            self.contentViewContainer = container;
        } else {
            self.contentViewContainer = [[UIView alloc] init];
        }
        [self.containerView addSubview:self.contentViewContainer];
        [self setNeedsUpdateConstraints];
    }
    [self uninstallBottomRelativeConstraintInView:self.contentViewContainer];
    
    __block UIView *lastItem;
    [self.contentViewContainer.subviews enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (![NSStringFromClass(obj.class) hasPrefix:@"_UI"]) {
            lastItem = obj;
            *stop = YES;
        }
    }];
    
    [self.contentViewContainer addSubview:contentView];
    [contentView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(lastItem ? lastItem.mas_bottom : self.contentViewContainer).offset(insets.top);
        make.left.bottom.right.equalTo(self.contentViewContainer).insets(insets);
        make.width.equalTo(self.contentViewContainer).offset(-(insets.left + insets.right));
    }];
}

- (void)addCustomContentView:(__kindof UIView *)contentView edgeInsets:(UIEdgeInsets)insets {
    [self addContentView:contentView edgeInsets:insets];
    self.customContentView = contentView;
}

- (void)addTextFieldWithConfiguration:(void (^)(UITextField * _Nonnull))configuration edgeInsets:(UIEdgeInsets)insets {
    UITextField *textField = [[UITextField alloc] init];
    textField.font = [UIFont systemFontOfSize:16];
    textField.textColor = UIColor.blackColor;
    textField.delegate = self;
    textField.returnKeyType = UIReturnKeyDone;
    textField.borderStyle = UITextBorderStyleRoundedRect;
    if (!self.innnerTextFields) {
        self.innnerTextFields = [NSMutableArray array];
    }
    self.innnerTextFields.lastObject.returnKeyType = UIReturnKeyNext;
    [self.innnerTextFields addObject:textField];
    self.followingKeyboardPosition = TNAlertFollowingKeyboardAtAlertBottom;
    
    [self addContentView:textField edgeInsets:insets];
    !configuration ?: configuration(textField);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([self.contentViewContainer isKindOfClass:[UIScrollView class]]) {
            UIScrollView *container = (UIScrollView *)self.contentViewContainer;
            CGPoint off = container.contentOffset;
            off.y = container.contentSize.height - container.bounds.size.height + container.contentInset.bottom;
            [container setContentOffset:off animated:YES];
        }
    });
}

- (void)addButton:(TNAlertButton *)button {
    if (!button || ![button isKindOfClass:[TNAlertButton class]]) {
        return;
    }
    NSMutableArray *buttons = self.buttons ? self.buttons.mutableCopy : [NSMutableArray array];
    [buttons addObject:button];
    self.buttons = buttons;
}

- (void)cancel {
    [self dismissWithCompletion:nil animated:YES isCancel:YES];
}

- (void)executeWhenAlertSizeDidChange:(void (^)(CGSize))block {
    if (!block) { return; }
    if (!self.sizeDidChangeBlocks) { self.sizeDidChangeBlocks = [NSMutableArray array]; }
    
    [self.sizeDidChangeBlocks addObject:block];
    if (!CGSizeEqualToSize(self.lastSize, CGSizeZero)) {
        block(self.lastSize);
    }
}

- (CGSize)customContentViewMaxVisibleSize {
    CGFloat containerMaxHeight = CGRectGetHeight(self.bounds) - [self containerHeightLessThanSelf];
    CGFloat customContentBottom = CGRectGetHeight(self.buttonContainer.frame) + self.buttonInsets.bottom + self.buttonInsets.top;
    CGFloat customContentTop = 0;
    if (self.titleLabel) {
        customContentTop = CGRectGetMaxY(self.titleLabel.frame) + self.titleInsets.bottom;
    }
    if (self.messageTextView) {
        customContentTop = CGRectGetMaxY(self.titleLabel.frame) + self.messageInsets.bottom;
    }
    return CGSizeMake(self.preferredWidth, containerMaxHeight - customContentTop - customContentBottom);
}

#pragma mark - UI

- (void)setupDefaults {
    _shouldCustomContentViewAutoScroll = YES;
    self.containerView.clipsToBounds = YES;
    self.containerView.alpha = 0;
    self.showingPolicy = TNPopupShowingForSure;
    self.dismissPolicy = TNPopupDismissOthersPolicyNone;
}

- (void)loadSubviews {
    [self setTitle:_title];
    [self setMessage:_message];
    
    self.buttonContainer = [[UIView alloc] init];
    [self.containerView addSubview:self.buttonContainer];
    
    [self setButtons:_buttons];
}

- (void)buttonClicked:(TNAlertButton *)button {
    !button.handler ?: button.handler(button);
    !self.actionHandler ?: self.actionHandler(button, [self.buttons indexOfObject:button]);
    if (button.shouldDismissAlert) {
        [self dismiss];
    }
}

- (void)updatePrettyMessage:(NSAttributedString *)message {
    if (message.length && !self.messageTextView) {
        self.messageTextView = [[UITextView alloc] init];
        self.messageTextView.textAlignment = NSTextAlignmentCenter;
        self.messageTextView.textContainerInset = UIEdgeInsetsZero;
        self.messageTextView.selectable = NO;
        self.messageTextView.bounces = NO;
        [self.messageTextView addObserver:self forKeyPath:@"contentSize" options:NSKeyValueObservingOptionNew context:nil];
        [self.containerView addSubview:self.messageTextView];
        [self setNeedsUpdateConstraints];
    }
    self.messageTextView.attributedText = message;
}

- (void)updatePrettyTitle:(NSAttributedString *)title {
    if (title.length && !self.titleLabel) {
        self.titleLabel = [[UILabel alloc] init];
        self.titleLabel.textAlignment = NSTextAlignmentCenter;
        self.titleLabel.numberOfLines = 0;
        [self.titleLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
        [self.titleLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
        [self.containerView addSubview:self.titleLabel];
        [self setNeedsUpdateConstraints];
    }
    self.titleLabel.attributedText = title;
}

- (void)reloadButtons {
    [self.separators makeObjectsPerformSelector:@selector(removeFromSuperview)];
    self.separators = nil;
    
    CGFloat separatorWidth = 1 / [UIScreen mainScreen].scale;
    NSMutableArray *separators;
    if (self.showButtonSeparator) {
        separators = [NSMutableArray array];
        self.separators = separators;
    }
    UIView *(^addSeparator)(void) = ^UIView *{
        UIView *view = [[UIView alloc] init];
        view.backgroundColor = self.buttonSeparatorColor;
        [self.buttonContainer addSubview:view];
        [separators addObject:view];
        return view;
    };
    
    NSMutableArray<NSArray<TNAlertButton *> *> *lines = [NSMutableArray array];
    __block NSMutableArray *lastLine = [NSMutableArray array];
    [self.buttons enumerateObjectsUsingBlock:^(TNAlertButton * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.alignment == TNAlertButtonAlignmentCenter || obj.alignment == TNAlertButtonAlignmentFill) {
            if (lastLine.count) {
                [lines addObject:lastLine];
                lastLine = nil;
            }
            [lines addObject:@[obj]];
            if (!lastLine) {
                lastLine = [NSMutableArray array];
            }
        } else {
            [lastLine addObject:obj];
            if (lastLine.count == 2) {
                [lines addObject:lastLine];
                lastLine = [NSMutableArray array];
            }
        }
        if (idx == self.buttons.count - 1 && lastLine.count) {
            [lines addObject:lastLine];
        }
    }];
    
    __block TNAlertButton *lastButton;
    [lines enumerateObjectsUsingBlock:^(NSArray<TNAlertButton *> * _Nonnull line, NSUInteger lineIdx, BOOL * _Nonnull stop) {
        if (self.showButtonSeparator) {
            UIView *topSeparator = addSeparator();
            [topSeparator mas_makeConstraints:^(MASConstraintMaker *make) {
                make.top.equalTo(lastButton ? lastButton.mas_bottom : self.buttonContainer).offset(lastButton ? self.buttonVerticalSpacing/2 : 0);
                make.left.equalTo(self.buttonContainer).offset(-self.buttonInsets.left);
                make.right.equalTo(self.buttonContainer).offset(self.buttonInsets.right);
                make.height.equalTo(@(separatorWidth));
            }];
        }
        
        [line enumerateObjectsUsingBlock:^(TNAlertButton * _Nonnull button, NSUInteger idx, BOOL * _Nonnull stop) {
            if (idx == 0 && line.count > 1) {
                if (self.showButtonSeparator) {
                    UIView *verticalSeparator = addSeparator();
                    [verticalSeparator mas_makeConstraints:^(MASConstraintMaker *make) {
                        make.top.equalTo(button).offset(-self.buttonVerticalSpacing/2);
                        make.centerX.equalTo(button.mas_right).offset(self.buttonHorizentalSpacing/2);
                        make.width.equalTo(@(separatorWidth));
                        if (lineIdx == lines.count - 1) {
                            make.bottom.equalTo(self.buttonContainer).offset(self.buttonInsets.bottom);
                        } else {
                            make.bottom.equalTo(button).offset(self.buttonVerticalSpacing/2);
                        }
                    }];
                }
            }
            [button mas_remakeConstraints:^(MASConstraintMaker *make) {
                if (idx == 0) {
                    make.top.equalTo(lastButton ? lastButton.mas_bottom : self.buttonContainer).offset(lastButton ? self.buttonVerticalSpacing : 0);
                    if (button.alignment == TNAlertButtonAlignmentCenter) {
                        make.centerX.equalTo(self.buttonContainer);
                    } else if (button.alignment == TNAlertButtonAlignmentFill || line.count == 1) {
                        make.left.right.equalTo(self.buttonContainer);
                    } else {
                        make.left.equalTo(self.buttonContainer);
                        make.right.equalTo(self.buttonContainer.mas_centerX).offset(-self.buttonHorizentalSpacing / 2);
                    }
                } else {
                    make.top.equalTo(lastButton);
                    make.right.equalTo(self.buttonContainer);
                    make.left.equalTo(self.buttonContainer.mas_centerX).offset(self.buttonHorizentalSpacing / 2);
                }
                if (lineIdx == lines.count - 1 && idx == line.count - 1) {
                    make.bottom.equalTo(self.buttonContainer);
                }
                if (button.preferredHeight > 0) {
                    make.height.equalTo(@(button.preferredHeight));
                }
            }];
            lastButton = button;
        }];
    }];
}

- (void)uninstallBottomRelativeConstraintInView:(UIView *)view {
    if (!view.subviews.count) {
        return;
    }
    [view.constraints enumerateObjectsUsingBlock:^(__kindof NSLayoutConstraint * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.firstAttribute == NSLayoutAttributeBottom && obj.secondAttribute == NSLayoutAttributeBottom) {
            if ((obj.firstItem == view && [obj.secondItem isDescendantOfView:view]) ||
                (obj.secondItem == view && [obj.firstItem isDescendantOfView:view])) {
                obj.active = NO;
            }
        }
    }];
}

- (void)setupAdjustedInsets {
    if (UIEdgeInsetsEqualToEdgeInsets(self.preferredInsets, UIEdgeInsetsZero)) {
        return;
    }
    if (self.autoAdjustSafeAreaInsets) {
        UIEdgeInsets safeAreaInsets = UIEdgeInsetsZero;
        if (@available(iOS 11.0, *)) {
            if (UIEdgeInsetsEqualToEdgeInsets(self.superview.safeAreaInsets, UIEdgeInsetsZero)) {
                return;
            }
            safeAreaInsets = self.superview.safeAreaInsets;
        }
        UIEdgeInsets adjusted = UIEdgeInsetsMake(self.preferredInsets.top + safeAreaInsets.top,
                                                 self.preferredInsets.left + safeAreaInsets.left,
                                                 self.preferredInsets.bottom + safeAreaInsets.bottom,
                                                 self.preferredInsets.right + safeAreaInsets.right);
        self.adjustedInsets = adjusted;
    } else {
        self.adjustedInsets = self.preferredInsets;
    }
}

#pragma mark - Override

- (void)layoutSubviews {
    [super layoutSubviews];
    CGSize size = self.containerView.bounds.size;
    if (CGSizeEqualToSize(size, CGSizeZero) || CGSizeEqualToSize(size, self.lastSize)) {
        return;
    }
    self.lastSize = size;
    [self.sizeDidChangeBlocks enumerateObjectsUsingBlock:^(ContainerSizeDidChange block, NSUInteger idx, BOOL * _Nonnull stop) {
        block(size);
    }];
    
    if (self.keyboardTop == 0) {
        return;
    }
    UIView *input = [self activeInput];
    if (!input) {
        return;
    }
    [self followKeyboard:input];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"contentSize"]) {
        CGSize contentSize = [change[NSKeyValueChangeNewKey] CGSizeValue];
        if (object == self.messageTextView) {
            [self.messageTextView mas_updateConstraints:^(MASConstraintMaker *make) {
                make.height.equalTo(@(contentSize.height)).priorityHigh();;
            }];
        } else if (object == self.contentViewContainer) {
            [self.contentViewContainer mas_updateConstraints:^(MASConstraintMaker *make) {
                make.height.equalTo(@(contentSize.height)).priorityHigh();;
            }];
        }
    }
}

- (void)safeAreaInsetsDidChange {
    [self setupAdjustedInsets];
}

- (void)updateConstraints {
    [super updateConstraints];
    
    [self.containerView mas_remakeConstraints:^(MASConstraintMaker *make) {
        self.containerCenterY = make.centerY.equalTo(self);
        make.centerX.equalTo(self);
        if (self.preferredWidth == 0 &&
            !UIEdgeInsetsEqualToEdgeInsets(self.adjustedInsets, UIEdgeInsetsZero)) {
            make.width.equalTo(self).offset(-(self.adjustedInsets.left + self.adjustedInsets.right));
        } else {
            make.width.equalTo(@(self.preferredWidth));
        }
        make.height.lessThanOrEqualTo(self).offset(-[self containerHeightLessThanSelf]);
    }];
    
    MASViewAttribute *lastBottom = self.containerView.mas_top;
    CGFloat bottomInset = 0;
    [self.titleLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(self.containerView).insets(self.titleInsets);
    }];
    if (self.titleLabel) {
        lastBottom = self.titleLabel.mas_bottom;
        bottomInset = self.titleInsets.bottom;
    }
    
    [self.messageTextView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(lastBottom).offset(bottomInset + self.messageInsets.top);
        make.left.right.equalTo(self.containerView).insets(self.messageInsets);
        make.height.equalTo(@(self.messageTextView.contentSize.height)).priorityHigh();
    }];
    if (self.messageTextView) {
        lastBottom = self.messageTextView.mas_bottom;
        bottomInset = self.messageInsets.bottom;
    }
    
    [self.contentViewContainer mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(lastBottom).offset(bottomInset);
        make.left.right.equalTo(self.containerView);
        if ([self.contentViewContainer isKindOfClass:[UIScrollView class]]) {
            make.height.equalTo(@(((UIScrollView *)self.contentViewContainer).contentSize.height)).priorityHigh();
        }
    }];
    if (self.contentViewContainer) {
        lastBottom = self.contentViewContainer.mas_bottom;
        bottomInset = 0;
    }
    
    [self.buttonContainer mas_remakeConstraints:^(MASConstraintMaker *make) {
        self.buttonContainerTop = make.top.equalTo(lastBottom).offset(bottomInset + self.buttonInsets.top);
        make.left.right.bottom.equalTo(self.containerView).insets(self.buttonInsets);
    }];
    
    [self reloadButtons];
}

- (void)willShow:(BOOL)animated {
    [super willShow:animated];
    !self.willShow ?: self.willShow();
}

- (void)didShow:(BOOL)animated {
    [super didShow:animated];
    !self.didShow ?: self.didShow();
}

- (void)willDismiss:(BOOL)animated {
    [super willDismiss:animated];
    !self.willDismiss ?: self.willDismiss();
}

- (void)didDismiss:(BOOL)animated {
    [super didDismiss:animated];
    self.actionHandler = nil;
    !self.didDismis ?: self.didDismis();
}

- (void)presentShowingAnimationWithCompletion:(dispatch_block_t)completion {
    switch (self.showingAimation) {
        case TNAlertAnimationFade:
            [self presentFadeAnimation:YES completion:completion];
            break;
        case TNAlertAnimationZoomIn:
            [self presentZoomAnimation:YES isShowing:YES completion:completion];
            break;
        case TNAlertAnimationZoomOut:
            [self presentZoomAnimation:NO isShowing:YES completion:completion];
            break;
        default:
            [self presentTranslationAnimation:self.showingAimation isShowing:YES completion:completion];
            break;
    }
}

- (void)presentDismissingAnimationWithCompletion:(dispatch_block_t)completion {
    switch (self.dismissingAnimation) {
        case TNAlertAnimationFade:
            [self presentFadeAnimation:NO completion:completion];
            break;
        case TNAlertAnimationZoomIn:
            [self presentZoomAnimation:YES isShowing:NO completion:completion];
            break;
        case TNAlertAnimationZoomOut:
            [self presentZoomAnimation:NO isShowing:NO completion:completion];
            break;
        default:
            [self presentTranslationAnimation:self.dismissingAnimation isShowing:NO completion:completion];
            break;
    }
}

#pragma mark - Animations

- (void)presentFadeAnimation:(BOOL)isShowing completion:(dispatch_block_t)completion {
    [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.alpha = self.containerView.alpha = isShowing;
    } completion:^(BOOL finished) {
        !completion ?: completion();
    }];
}

- (void)presentZoomAnimation:(BOOL)zoomIn isShowing:(BOOL)isShowing completion:(dispatch_block_t)completion {
    CGFloat init = isShowing ? (zoomIn ? 1.3 : 0.3) : (zoomIn ? 1 : 1.3);
    self.containerView.transform = CGAffineTransformMakeScale(init, init);
    [self showSpringAnimation:^{
        CGFloat scale = isShowing ? 1 : (zoomIn ? 0.3 : 1.3);
        self.containerView.transform = CGAffineTransformMakeScale(scale, scale);
        self.alpha = self.containerView.alpha = isShowing;
    } completion:completion];
}

- (void)presentTranslationAnimation:(TNAlertAnimation)animation isShowing:(BOOL)isShowing completion:(dispatch_block_t)completion {
    CGFloat screenWidth = CGRectGetWidth([UIScreen mainScreen].bounds);
    CGFloat screenHeight = CGRectGetHeight([UIScreen mainScreen].bounds);
    CGSize containerSize = self.containerView.frame.size.width > 0 ? self.containerView.frame.size : [self.containerView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    
    CGFloat initX = 0, initY = 0, toX = 0, toY = 0;
    switch (animation) {
        case TNAlertAnimationTranslationFromTop:
            if (isShowing) {
                initY = -(screenHeight / 2 + containerSize.height / 2);
            } else {
                toY = -(screenHeight / 2 + containerSize.height / 2);
            }
            break;
        case TNAlertAnimationTranslationFromLeft:
            if (isShowing) {
                initX = -(screenWidth / 2 + containerSize.width / 2);
            } else {
                toX = -(screenWidth / 2 + containerSize.width / 2);
            }
            break;
        case TNAlertAnimationTranslationFromBottom:
            if (isShowing) {
                initY = (screenHeight / 2 + containerSize.height / 2);
            } else {
                toY = (screenHeight / 2 + containerSize.height / 2);
            }
            break;
        case TNAlertAnimationTranslationFromRight:
            if (isShowing) {
                initX = (screenWidth / 2 + containerSize.width / 2);
            } else {
                toX = (screenWidth / 2 + containerSize.width / 2);
            }
            break;
        default:
            return;
            break;
    }
    self.containerView.transform = CGAffineTransformMakeTranslation(initX, initY);
    [self showSpringAnimation:^{
        self.containerView.transform = CGAffineTransformMakeTranslation(toX, toY);
        self.alpha = self.containerView.alpha = isShowing;
    } completion:completion];
}

- (void)showSpringAnimation:(dispatch_block_t)animation completion:(dispatch_block_t)completion {
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        !animation ?: animation();
    } completion:^(BOOL finished) {
        !completion ?: completion();
    }];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    NSInteger idx = [self.innnerTextFields indexOfObject:textField];
    if (idx < self.innnerTextFields.count - 1) {
        [self.innnerTextFields[idx + 1] becomeFirstResponder];
    }
    return YES;
}

// 键盘升起做动画时，上一个聚焦的输入框字体会跳动，在开始和结束加上layoutIfNeeded避免此问题
// https://stackoverflow.com/questions/30572528/text-jumps-when-animating-position-of-uitextfield-subclass
- (void)textFieldDidBeginEditing:(UITextField *)textField {
    [textField layoutIfNeeded];
}
- (void)textFieldDidEndEditing:(UITextField *)textField {
    [textField layoutIfNeeded];
}

#pragma mark - Setters

- (void)setTitleInsets:(UIEdgeInsets)titleInsets {
    _titleInsets = titleInsets;
    [self setNeedsUpdateConstraints];
}

- (void)setTitle:(id)title {
    _title = title;
    if (!title) {
        [self.titleLabel removeFromSuperview];
        self.titleLabel = nil;
        [self setNeedsUpdateConstraints];
    } else {
        NSAttributedString *prettyTitle;
        if ([title isKindOfClass:[NSAttributedString class]]) {
            prettyTitle = title;
        } else if ([title isKindOfClass:[NSString class]] && self.titleAttributes) {
            prettyTitle = [[NSAttributedString alloc] initWithString:title attributes:self.titleAttributes];
        }
        [self updatePrettyTitle:prettyTitle];
    }
}

- (void)setMessage:(id)message {
    _message = message;
    if (!message) {
        [self.messageTextView removeFromSuperview];
        self.messageTextView = nil;
        [self setNeedsUpdateConstraints];
    } else {
        NSAttributedString *prettyMessage;
        if ([message isKindOfClass:[NSAttributedString class]]) {
            prettyMessage = message;
        } else if ([message isKindOfClass:[NSString class]] && self.messageAttributes) {
            prettyMessage = [[NSAttributedString alloc] initWithString:message attributes:self.messageAttributes];
        }
        [self updatePrettyMessage:prettyMessage];
    }
}

- (void)setButtons:(NSArray<TNAlertButton *> *)buttons {
    _buttons = buttons;
    [self.buttonContainer.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    for (TNAlertButton *button in buttons) {
        [button addTarget:self action:@selector(buttonClicked:) forControlEvents:UIControlEventTouchUpInside];
        [self.buttonContainer addSubview:button];
    }
    [self setNeedsUpdateConstraints];
}

- (void)setTitleAttributes:(NSDictionary *)titleAttributes {
    _titleAttributes = titleAttributes ?: @{};
    NSString *title;
    if ([self.title isKindOfClass:[NSString class]]) {
        title = self.title;
    }
    if (!title) {
        return;
    }
    [self updatePrettyTitle:[[NSAttributedString alloc] initWithString:title attributes:titleAttributes]];
}

- (void)setMessageAttributes:(NSDictionary *)messageAttributes {
    _messageAttributes = messageAttributes ?: @{};
    NSString *message;
    if ([self.message isKindOfClass:[NSString class]]) {
        message = self.message;
    }
    if (!message) {
        return;
    }
    [self updatePrettyMessage:[[NSAttributedString alloc] initWithString:message attributes:messageAttributes]];
}

- (void)setMessageInsets:(UIEdgeInsets)messageInsets {
    _messageInsets = messageInsets;
    [self setNeedsUpdateConstraints];
}

- (void)setDimBgColor:(UIColor *)dimBgColor {
    _dimBgColor = dimBgColor;
    self.backgroundColor = dimBgColor;
}

- (void)setCornerRadius:(CGFloat)cornerRadius {
    _cornerRadius = cornerRadius;
    self.containerView.layer.cornerRadius = cornerRadius;
}

- (void)setPreferredWidth:(CGFloat)preferredWidth {
    if (_preferredWidth == preferredWidth) { return; }
    
    _preferredWidth = preferredWidth;
    [self setNeedsUpdateConstraints];
}

- (void)setButtonHorizentalSpacing:(CGFloat)buttonHorizentalSpacing {
    if (_buttonHorizentalSpacing == buttonHorizentalSpacing) { return; }
    
    _buttonHorizentalSpacing = buttonHorizentalSpacing;
    [self setNeedsUpdateConstraints];
}

- (void)setButtonVerticalSpacing:(CGFloat)buttonVerticalSpacing {
    if (_buttonVerticalSpacing == buttonVerticalSpacing) { return; }
    
    _buttonVerticalSpacing = buttonVerticalSpacing;
    [self setNeedsUpdateConstraints];
}

- (void)setButtonInsets:(UIEdgeInsets)buttonInsets {
    if (UIEdgeInsetsEqualToEdgeInsets(_buttonInsets, buttonInsets)) { return; }
    
    _buttonInsets = buttonInsets;
    [self setNeedsUpdateConstraints];
}

- (void)setShowButtonSeparator:(BOOL)showButtonSeparator {
    if (_showButtonSeparator == showButtonSeparator) { return; }
    
    _showButtonSeparator = showButtonSeparator;
    if (!showButtonSeparator) {
        [self.separators makeObjectsPerformSelector:@selector(removeFromSuperview)];
        self.separators = nil;
    } else {
        [self setNeedsUpdateConstraints];
    }
}

- (void)setButtonSeparatorColor:(UIColor *)buttonSeparatorColor {
    if ((!_buttonSeparatorColor && !buttonSeparatorColor) || [_buttonSeparatorColor isEqual:buttonSeparatorColor]) { return; }
    
    _buttonSeparatorColor = buttonSeparatorColor;
    [self.separators enumerateObjectsUsingBlock:^(UIView *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.backgroundColor = buttonSeparatorColor;
    }];
}

- (void)setCenterYOffset:(CGFloat)centerYOffset {
    _centerYOffset = centerYOffset;
    self.containerCenterY.offset(MIN(centerYOffset, 0));
}

- (void)setFollowingKeyboardPosition:(TNAlertFollowingKeyboardPosition)followingKeyboardPosition {
    if (_followingKeyboardPosition == followingKeyboardPosition) { return; }
    
    _followingKeyboardPosition = followingKeyboardPosition;
    if (followingKeyboardPosition == TNAlertFollowingKeyboardPositionNone) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillChangeFrameNotification object:nil];
    } else {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardFrameDidChange:) name:UIKeyboardWillChangeFrameNotification object:nil];
    }
}

- (void)setAdjustedInsets:(UIEdgeInsets)adjustedInsets {
    if (UIEdgeInsetsEqualToEdgeInsets(_adjustedInsets, adjustedInsets)) {
        return;
    }
    _adjustedInsets = adjustedInsets;
    if (![self needsUpdateConstraints]) {
        [self setNeedsUpdateConstraints];
        [self updateConstraintsIfNeeded];
    }
}

- (void)setAutoAdjustSafeAreaInsets:(BOOL)autoAdjustSafeAreaInsets {
    if (_autoAdjustSafeAreaInsets == autoAdjustSafeAreaInsets) {
        return;
    }
    _autoAdjustSafeAreaInsets = autoAdjustSafeAreaInsets;
    [self setupAdjustedInsets];
}

- (void)setPreferredInsets:(UIEdgeInsets)preferredInsets {
    if (UIEdgeInsetsEqualToEdgeInsets(_preferredInsets, preferredInsets)) {
        return;
    }
    _preferredInsets = preferredInsets;
    [self setupAdjustedInsets];
}

#pragma mark - Getters

- (NSArray<UITextField *> *)textFields {
    return self.innnerTextFields.copy;
}

- (CGFloat)containerHeightLessThanSelf {
    if (self.preferredWidth == 0 &&
        !UIEdgeInsetsEqualToEdgeInsets(self.adjustedInsets, UIEdgeInsetsZero)) {
        return self.adjustedInsets.top + self.adjustedInsets.bottom;
    } else if (@available(iOS 11.0, *)) {
        UIEdgeInsets safeAeraInsets = [[UIApplication sharedApplication].delegate window].safeAreaInsets;
        if (safeAeraInsets.top > 0) {
            return 20 + safeAeraInsets.top + safeAeraInsets.bottom;
        }
    }
    return 40;
}

#pragma mark - Keyboard

- (void)keyboardFrameDidChange:(NSNotification *)notification {
    CGFloat screenWidth = CGRectGetWidth([UIScreen mainScreen].bounds);
    CGFloat screenHeight = CGRectGetHeight([UIScreen mainScreen].bounds);
    
    CGRect keyboardRect = [[notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    UIViewAnimationCurve curve = [[notification.userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] integerValue];
    NSTimeInterval duration = [[notification.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    BOOL isFloating = CGRectGetWidth(keyboardRect) < screenWidth;
    BOOL isShow = CGRectGetMinY(keyboardRect) < screenHeight;
    if (isFloating) {
        isShow = CGRectGetMinY(keyboardRect) < screenHeight && !CGRectIsEmpty(keyboardRect);
    }
    CGFloat keyboardTop = CGRectGetMinY(keyboardRect);
    UIView *activeInput;
    BOOL shouldReturn = !isShow;
    if (!shouldReturn) {
        activeInput = [self activeInput];
        shouldReturn = !activeInput;
    }
    if (shouldReturn) {
//        NSLog(@"centerY 0");
        self.centerYOffset = 0;
        self.keyboardTop = 0;
    } else {
        self.keyboardTop = keyboardTop;
        if (![self followKeyboard:activeInput]) {
            return;
        }
    }
    [UIView animateWithDuration:duration
                          delay:0
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        [UIView setAnimationCurve:curve];
        [self layoutIfNeeded];
    } completion:nil];
}

- (UIView<UITextInput> * _Nullable)activeInput {
    return [self activeInputInView:self.containerView];
}

- (UIView<UITextInput> *)activeInputInView:(UIView *)view {
    if ([view conformsToProtocol:@protocol(UITextInput)] && view.isFirstResponder) {
        return (UIView<UITextInput> *)view;
    }
    for (UIView *subview in view.subviews) {
        UIView<UITextInput> *input = [self activeInputInView:subview];
        if (input) {
            return input;
        }
    }
    return nil;
}

- (BOOL)followKeyboard:(UIView *)activeInput {
    if (self.followingKeyboardPosition == TNAlertFollowingKeyboardPositionNone) {
        return NO;
    }
    CGFloat followKeyboardPosition;
    if (!activeInput && self.followingKeyboardPosition == TNAlertFollowingKeyboardAtActiveInputBottom) {
        activeInput = [self activeInput];
        if (!activeInput) {
            return NO;
        }
    }
    if (self.followingKeyboardPosition == TNAlertFollowingKeyboardAtActiveInputBottom) {
        followKeyboardPosition = CGRectGetMaxY([activeInput.superview convertRect:activeInput.frame toView:self.containerView]) + (CGRectGetHeight(self.frame) - CGRectGetHeight(self.containerView.frame)) / 2;
    } else {
        followKeyboardPosition = CGRectGetHeight(self.containerView.frame) / 2 + CGRectGetHeight(self.frame) / 2;
    }
    CGFloat space = self.keyboardTop - followKeyboardPosition;
    CGFloat adjustment = space - self.followingKeyboardSpacing;
    if (adjustment == self.centerYOffset) {
        return NO;
    }
    self.centerYOffset = adjustment;
    return YES;
}
@end
