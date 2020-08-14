//
//  TNPopupViewManager.m
//  TNKit
//
//  Created by rollingstoneW on 2018/9/3.
//  Copyright © 2018年 TNKit. All rights reserved.
//

#import "TNPopupViewManager.h"
#import "TNAbstractPopupView+Internal.h"

static TNPopupViewManager *globleManager = nil;

@implementation TNPopupViewManager

- (void)showPopupView:(TNAbstractPopupView *)popupView inView:(UIView *)superview animated:(BOOL)animated {
    if (!popupView || !superview) {
        return;
    }

    switch (popupView.showingPolicy) {
            case TNPopupShowingOnlyNoneExists: {
                if (![self hasVisiblePopupPriorityGreaterThanPopupView:popupView]) {
                    [self dismissOthersWhenShowingPopupViewIfNeeded:popupView];
                    [popupView _showInView:superview animated:animated];
                    [self.showingPopupViews addObject:popupView];
                }
                break;
            }
            case TNPopupShowingForSure: {
                [self dismissOthersWhenShowingPopupViewIfNeeded:popupView];
                [popupView _showInView:superview animated:animated];
                [self.showingPopupViews addObject:popupView];
                break;
            }
            case TNPopupShowingAfterOthersDismiss: {
                if ([self hasVisiblePopupPriorityGreaterThanPopupView:popupView]) {
                    [self.toShowingPopupViews addObject:popupView];
                } else {
                    [self dismissOthersWhenShowingPopupViewIfNeeded:popupView];
                    [popupView _showInView:superview animated:animated];
                    [self.showingPopupViews addObject:popupView];
                }
                break;
            }
    }

}

- (void)dismissOthersWhenShowingPopupViewIfNeeded:(TNAbstractPopupView *)popupView {
    TNPopupShowingPriority conditionPriority;
    switch (popupView.dismissPolicy) {
            case TNPopupDismissOthersPolicyNone:
            conditionPriority = TNPopupShowingPriorityDefaultLow - 1;
            break;
            case TNPopupDismissOthersPriorityLower:
            conditionPriority = popupView.showingPriority - 1;
            break;
            case TNPopupDismissOthersPriorityLowerOrEqual:
            conditionPriority = popupView.showingPriority;
            break;
    }
    // 先移除未展示的，避免移除展示的时候，未展示的触发条件再展示出来
    NSArray *allPopups = [self.toShowingPopupViews arrayByAddingObjectsFromArray:self.showingPopupViews];
    for (TNAbstractPopupView *popup in allPopups) {
        if (popup.showingPriority <= conditionPriority && [popup shouldBeDismissedByPopupView:popupView]) {
            [popup dismissWithCompletion:nil animated:NO];
        }
    }
}

- (BOOL)hasVisiblePopupPriorityGreaterThanPopupView:(TNAbstractPopupView *)popupView {
    for (TNAbstractPopupView *popup in self.showingPopupViews) {
        if (popup.window && popup.showingPriority >= popupView.showingPriority) {
            return YES;
        }
    }
    return NO;
}

- (void)dismissedPopupView:(TNAbstractPopupView *)popupView {
    [self removePopupView:popupView];
    if (![self hasVisiblePopupPriorityGreaterThanPopupView:popupView] && self.toShowingPopupViews.count) {
        TNAbstractPopupView *toShowPopupView = self.toShowingPopupViews.firstObject;
        while (1) {
            if (!toShowPopupView) {
                break;
            }
            if (!toShowPopupView.superviewToShowing) {
                [self.toShowingPopupViews removeObject:toShowPopupView];
                break;
            }
            [self showPopupView:toShowPopupView inView:toShowPopupView.superviewToShowing animated:toShowPopupView.animated];
            [self.toShowingPopupViews removeObject:toShowPopupView];
            break;
        }
    }
    if (!self.showingPopupViews.count && !self.toShowingPopupViews.count) {
        globleManager = nil;
    }
}

- (void)removePopupView:(TNAbstractPopupView *)popupView {
    [self.showingPopupViews removeObject:popupView];
    [self.toShowingPopupViews removeObject:popupView];
}

- (nullable NSArray<__kindof TNAbstractPopupView *> *)popupViewsInView:(UIView *)view containToShow:(BOOL)containToShow {
    if (!self.showingPopupViews.count || !self.toShowingPopupViews.count || !view) {
        return nil;
    }
    NSMutableArray *arr;
    NSArray *allPopups = containToShow ? [self.showingPopupViews arrayByAddingObjectsFromArray:self.toShowingPopupViews] : self.showingPopupViews;
    for (TNAbstractPopupView *popupView in allPopups) {
        UIView *superview = popupView.superview ?: popupView.superviewToShowing;
        while (superview) {
            if (view == superview) {
                if (!arr) {
                    arr = [NSMutableArray array];
                }
                [arr addObject:popupView];
                break;
            }
            superview = superview.superview;
        }
    }
    return arr;
}

- (NSMutableArray *)showingPopupViews {
    if (!_showingPopupViews) {
        _showingPopupViews = [NSMutableArray array];
    }
    return _showingPopupViews;
}

- (NSMutableArray *)toShowingPopupViews {
    if (!_toShowingPopupViews) {
        _toShowingPopupViews = [NSMutableArray array];
    }
    return _toShowingPopupViews;
}

+ (instancetype)globleManager {
    return globleManager;
}

+ (instancetype)lazilyGlobleManager {
    if (!globleManager) {
        globleManager = [[TNPopupViewManager alloc] init];
    }
    return globleManager;
}

//- (void)dealloc {
//    NSLog(@"%@ %s", self, __func__);
//}

@end
