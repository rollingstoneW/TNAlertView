//
//  TNPopupViewManager.h
//  TNKit
//
//  Created by rollingstoneW on 2018/9/3.
//  Copyright © 2018年 TNKit. All rights reserved.
//

#import <UIKit/UIKit.h>

@class TNAbstractPopupView;

NS_ASSUME_NONNULL_BEGIN

@interface TNPopupViewManager : NSObject

@property (nonatomic, strong) NSMutableArray<__kindof TNAbstractPopupView *>* showingPopupViews;
@property (nonatomic, strong) NSMutableArray<__kindof TNAbstractPopupView *>* toShowingPopupViews;

- (void)showPopupView:(TNAbstractPopupView *)popupView inView:(UIView *)superview animated:(BOOL)animated;
- (void)dismissedPopupView:(TNAbstractPopupView *)popupView;

- (nullable NSArray<__kindof TNAbstractPopupView *> *)popupViewsInView:(UIView *)view containToShow:(BOOL)containToShow;

+ (instancetype)lazilyGlobleManager;

@end

NS_ASSUME_NONNULL_END
