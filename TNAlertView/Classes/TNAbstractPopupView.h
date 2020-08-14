//
//  TNAbstractPopupView.h
//  TNKit
//
//  Created by rollingstoneW on 2018/8/10.
//  Copyright © 2018年 TNKit. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TNPopupViewManager.h"

NS_ASSUME_NONNULL_BEGIN

typedef NSInteger TNPopupShowingPriority;

UIKIT_EXTERN const TNPopupShowingPriority TNPopupShowingPriorityHigh;
UIKIT_EXTERN const TNPopupShowingPriority TNPopupShowingPriorityMedium;
UIKIT_EXTERN const TNPopupShowingPriority TNPopupShowingPriorityDefaultLow;


typedef NS_ENUM(NSUInteger, TNPopupShowingPolicy) {
    TNPopupShowingForSure = 0, // 一定会展示
    TNPopupShowingOnlyNoneExists, // 只有展示的popupView.showingPriority全部<self.showingPriority时才会展示
    TNPopupShowingAfterOthersDismiss // 等到在展示的popupView.showingPriority全部<self.showingPriority才会展示
};

typedef NS_ENUM(NSUInteger, TNPopupDismissOthersPolicy) {
    TNPopupDismissOthersPolicyNone = 0,
    TNPopupDismissOthersPriorityLower, // 展示的时候，会关闭比自己优先级低的popupView
    TNPopupDismissOthersPriorityLowerOrEqual, // 展示的时候，会关闭不大于自己优先级的popupView
};

@interface TNAbstractPopupView : UIView

@property (nonatomic, strong, readonly) UIView *containerView;

@property (nonatomic, assign) TNPopupShowingPolicy showingPolicy;
@property (nonatomic, assign) TNPopupDismissOthersPolicy dismissPolicy;
@property (nonatomic, assign) TNPopupShowingPriority showingPriority;

@property (nonatomic, strong, nullable) __kindof TNPopupViewManager *popupMangager; // 默认是globlePopupManager

@property (nonatomic, assign) CGRect containerFrame;

@property (nonatomic, assign) BOOL dimBackground; // 显示黑色蒙层 YES
@property (nonatomic, assign) BOOL tapDimToDismiss; // 点击蒙层是否消失 NO

@property (nonatomic, assign) BOOL dismissWhenConfirm; // 点击确定后是否消失，子类使用 YES

@property (nonatomic, copy, nullable) dispatch_block_t confirmedBlock; // 确定的回调，子类使用
@property (nonatomic, copy, nullable) dispatch_block_t cancelledBlock; // 取消的回调，子类使用
@property (nonatomic, copy, nullable) dispatch_block_t dismissedBlock; // 消失的回调

- (void)showInView:(UIView *)view animated:(BOOL)animated;
- (void)showInMainWindow;
- (void)showInKeyWindow;
- (void)dismissWithCompletion:(nullable dispatch_block_t)completion animated:(BOOL)animated; // 消失，isCancel:NO
- (void)dismissWithCompletion:(nullable dispatch_block_t)completion animated:(BOOL)animated isCancel:(BOOL)isCancel; // 消失
- (void)dismiss; // 消失

- (void)willShow:(BOOL)animated;
- (void)didShow:(BOOL)animated;
- (void)willDismiss:(BOOL)animated;
- (void)didDismiss:(BOOL)animated;

// 子类可重写来自定义动画
- (void)presentShowingAnimationWithCompletion:(dispatch_block_t)completion;
- (void)presentDismissingAnimationWithCompletion:(dispatch_block_t)completion;
// 统一初始化方法
- (void)setup NS_REQUIRES_SUPER;

// 是否可以被popupView(popupView.showingPriority>=self.showingPriority)自动取消, YES
- (BOOL)shouldBeDismissedByPopupView:(__kindof TNAbstractPopupView *)popupView;

@end

NS_ASSUME_NONNULL_END
