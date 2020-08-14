//
//  TNAbstractPopupView+Internal.h
//  TNKit
//
//  Created by rollingstoneW on 2018/9/3.
//  Copyright © 2018年 TNKit. All rights reserved.
//

#import "TNAbstractPopupView.h"

@interface TNAbstractPopupView ()

@property (nonatomic,   weak) UIView *superviewToShowing;
@property (nonatomic, assign) BOOL animated;

- (void)_showInView:(UIView *)view animated:(BOOL)animated;

@end
