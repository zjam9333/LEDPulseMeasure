//
//  ZZLEDPulseWaveView.h
//  LEDPulseMeasure
//
//  Created by zjj on 2020/5/8.
//  Copyright © 2020 zjj. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZZLEDPulseWaveView : UIView

@property (nonatomic, strong) IBInspectable UIColor *drawColor;
@property (nonatomic, assign) BOOL waving;
- (void)addPulseWithConfidence:(CGFloat)value;

@end

NS_ASSUME_NONNULL_END
