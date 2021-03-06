//
//  TNAbstractPopupView.m
//  TNKit
//
//  Created by rollingstoneW on 2018/8/10.
//  Copyright © 2018年 TNKit. All rights reserved.
//

#import "TNAbstractPopupView.h"
#import "TNAbstractPopupView+Internal.h"
#import <objc/runtime.h>

static const NSTimeInterval AnimationDuration = .25;
const TNPopupShowingPriority TNPopupShowingPriorityHigh = 100;
const TNPopupShowingPriority TNPopupShowingPriorityMedium = 50;
const TNPopupShowingPriority TNPopupShowingPriorityDefaultLow = 0;

@interface TNAbstractPopupView ()

@property (nonatomic, strong) UIView *containerView;

@end

@implementation TNAbstractPopupView

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
#if DEBUG
//    NSLog(@"%@ %s", self, __func__);
#endif
}

- (void)showInMainWindow {
    [self showInView:[[UIApplication sharedApplication].delegate window] animated:YES];
}

- (void)showInKeyWindow {
    [self showInView:[UIApplication sharedApplication].keyWindow animated:YES];
}

- (void)showInView:(UIView *)view animated:(BOOL)animated {
    self.superviewToShowing = view;
    self.animated = animated;
    [[[self class] customPopupManager] showPopupView:self inView:view animated:animated];
}

- (void)_showInView:(UIView *)view animated:(BOOL)animated {
    [view addSubview:self];
//    self.containerView.frame = self.containerFrame;
    self.frame = view.bounds;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self willShow:animated];
    if (animated) {
        [self presentShowingAnimationWithCompletion:^{
            [self didShow:animated];
        }];
    } else {
        [self didShow:animated];
    }
}

- (void)dismissWithCompletion:(dispatch_block_t)completion animated:(BOOL)animated {
    [self dismissWithCompletion:completion animated:animated isCancel:NO];
}

- (void)dismissWithCompletion:(dispatch_block_t)completion animated:(BOOL)animated isCancel:(BOOL)isCancel {
    [self willDismiss:animated];
    dispatch_block_t block = ^{
        [self removeFromSuperview];

        if (isCancel && self.cancelledBlock) {
            self.cancelledBlock();
        }
        !self.dismissedBlock ?: self.dismissedBlock();
        [self didDismiss:animated];
        !completion ?: completion();

        self.dismissedBlock = nil;
        self.confirmedBlock = nil;
        self.cancelledBlock = nil;

        [[[self class] customPopupManager] dismissedPopupView:self];
    };
    if (animated) {
        [self presentDismissingAnimationWithCompletion:^{
            block();
        }];
    } else {
        block();
    }
}

- (void)dismiss {
    [self dismissWithCompletion:nil animated:YES];
}

+ (void)dismissAll {
    // 先移除未展示的，避免移除展示的时候，未展示的触发条件再展示出来
    NSArray *allPopups = [[self customPopupManager].toShowingPopupViews arrayByAddingObjectsFromArray:[self customPopupManager].showingPopupViews];
    for (TNAbstractPopupView *popup in allPopups) {
        if ([popup isKindOfClass:self]) {
            [popup dismissWithCompletion:nil animated:NO];
        }
    }
}

+ (void)dismissAllInView:(UIView *)view {
    for (TNAbstractPopupView *popup in [[[self customPopupManager] popupViewsInView:view containToShow:YES] reverseObjectEnumerator]) {
        if ([popup isKindOfClass:self]) {
            [popup dismissWithCompletion:nil animated:NO];
        }
    }
}

+ (void)dismissAllInKeyWindow {
    [self dismissAllInView:[UIApplication sharedApplication].keyWindow];
}

+ (void)dismissAllInMainWindow {
    [self dismissAllInView:[[UIApplication sharedApplication].delegate window]];
}

- (void)presentShowingAnimationWithCompletion:(dispatch_block_t)completion {
    self.alpha = 0;
    [UIView animateWithDuration:AnimationDuration animations:^{
        self.alpha = 1;
    } completion:^(BOOL finished) {
        !completion ?: completion();
    }];
}

- (void)presentDismissingAnimationWithCompletion:(dispatch_block_t)completion {
    [UIView animateWithDuration:AnimationDuration animations:^{
        self.alpha = 0;
    } completion:^(BOOL finished) {
        !completion ?: completion();
    }];
}

- (BOOL)shouldBeDismissedByPopupView:(__kindof TNAbstractPopupView *)popupView {
    return YES;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (self.dimBackground) {
        if (!self.tapDimToDismiss || event.allTouches.count != 1) {
            return;
        }
        UITouch *touch = touches.anyObject;
        if (!CGRectContainsPoint(self.containerView.frame, [touch locationInView:self])) {
            [self dismissWithCompletion:nil animated:self.animated];
        }
    } else {
        [super touchesBegan:touches withEvent:event];
    }
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.dimBackground) {
        return [super pointInside:point withEvent:event];
    }
    return [self.containerView pointInside:[self convertPoint:point toView:self.containerView] withEvent:event];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self setup];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup {
    [self _setup];
    [self _loadSubviews];
}

- (void)_setup {
    self.showingPolicy = TNPopupShowingOnlyNoneExists;
    self.tapDimToDismiss = NO;
    self.dimBackground = YES;
    self.dismissWhenConfirm = YES;
    self.alpha = 0;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleRotate:) name:UIApplicationWillChangeStatusBarOrientationNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleRotate:) name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
}

- (void)_loadSubviews {
    [self addSubview:self.containerView];
}

- (void)willShow:(BOOL)animated {}
- (void)didShow:(BOOL)animated {}
- (void)willDismiss:(BOOL)animated {}
- (void)didDismiss:(BOOL)animated {}
- (void)willRotateToOrientation:(UIInterfaceOrientation)orientation {}
- (void)didRotateToOrientation:(UIInterfaceOrientation)orientation {}

- (void)handleRotate:(NSNotification *)note {
    if ([note.name isEqualToString:UIApplicationWillChangeStatusBarOrientationNotification]) {
        [self willRotateToOrientation:[note.userInfo[UIApplicationStatusBarOrientationUserInfoKey] integerValue]];
    } else {
        [self didRotateToOrientation:[UIApplication sharedApplication].statusBarOrientation];
    }
}

- (void)setDimBackground:(BOOL)dimBackground {
    _dimBackground = dimBackground;
    self.backgroundColor = dimBackground ? [[UIColor blackColor] colorWithAlphaComponent:.6] : [UIColor clearColor];
}

//- (CGRect)containerFrame {
//    if (CGRectIsEmpty(_containerFrame)) {
//        CGFloat left = 20;
//        CGFloat height = 100;
//        return CGRectMake(left, (CGRectGetHeight(self.superview.bounds) - height) / 2, CGRectGetWidth(self.superview.bounds) - left * 2, height);
//    }
//    return _containerFrame;
//}

- (void)setContainerFrame:(CGRect)containerFrame {
    _containerFrame = containerFrame;
    self.containerView.frame = containerFrame;
}

- (UIView *)containerView {
    if (!_containerView) {
        _containerView = [[UIView alloc] init];
        _containerView.layer.backgroundColor = [UIColor whiteColor].CGColor;
    }
    return _containerView;
}

+ (TNPopupViewManager *)customPopupManager {
    return [TNPopupViewManager lazilyGlobleManager];
}

@end
