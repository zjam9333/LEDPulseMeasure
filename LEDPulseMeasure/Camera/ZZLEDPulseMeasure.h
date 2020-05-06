//
//  LEDPulseMeasure.h
//  LEDPulseMeasure
//
//  Created by zjj on 2020/4/27.
//  Copyright © 2020 zjj. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ZZLEDPulseMeasureState) {
    // 刚开启摄像头，手指还未放好
    ZZLEDPulseMeasureStateNothing = 0,
    // 手指已放好
    ZZLEDPulseMeasureStatePrepared = 1,
    // 检测到波动并开始数
    ZZLEDPulseMeasureStateMeasuring = 2,
    // 似乎不需要这种状态
    ZZLEDPulseMeasureStateCompleted = 3,
};

@interface ZZLEDSignalSample : NSObject

@property (nonatomic, assign) NSTimeInterval time;

@property (nonatomic, strong) UIColor *color;

//@property (nonatomic, assign) CGFloat hue;
//@property (nonatomic, assign) CGFloat saturation;
//@property (nonatomic, assign) CGFloat brightness;

@property (nonatomic, weak) UIView *pointView;

@property (nonatomic, assign) BOOL selected;
@property (nonatomic, assign) CGFloat value;

@property (nonatomic, assign) CGFloat pulseIntensity;
// 与上一个的时间差
@property (nonatomic, assign) NSTimeInterval deltaTime;

@end

@interface ZZLEDPulseDetection : NSObject

@property (nonatomic, strong) NSArray<ZZLEDSignalSample *> *detectedSamples;
@property (nonatomic, assign) float pulsePerMin;
@property (nonatomic, assign) BOOL failed;

@end

typedef void (^ZZLEDPulseSampleCallBack)(ZZLEDSignalSample *sample);
typedef void (^ZZLEDPulseDetectCallBack)(ZZLEDPulseDetection *detection);
typedef void (^ZZLEDPulseStateCallBack)(ZZLEDPulseMeasureState state);

@interface ZZLEDPulseMeasure : NSObject

@property (nonatomic, strong, readonly) AVCaptureVideoPreviewLayer *previewLayer;
// 采样
@property (nonatomic, strong) ZZLEDPulseSampleCallBack sampleCallBack;
// 检测到脉冲
@property (nonatomic, strong) ZZLEDPulseDetectCallBack detectCallBack;
// 有多个脉冲并测量
@property (nonatomic, strong) ZZLEDPulseDetectCallBack measureCallBack;
// 状态变更
@property (nonatomic, strong) ZZLEDPulseStateCallBack stateCallBack;
@property (nonatomic, readonly) BOOL running;
@property (nonatomic, assign) ZZLEDPulseMeasureState state;

- (void)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
