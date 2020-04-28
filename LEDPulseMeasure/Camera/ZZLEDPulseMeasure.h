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

@interface ZZLEDColorSample : NSObject

@property (nonatomic, assign) NSTimeInterval timeInterval;
@property (nonatomic, assign, readonly) CGFloat value;

@property (nonatomic, assign) CGFloat hue;
@property (nonatomic, assign) CGFloat saturation;
@property (nonatomic, assign) CGFloat brightness;

@end

@interface ZZLEDPulseDetection : NSObject

@property (nonatomic, strong) NSArray<ZZLEDColorSample *> *detectedSamples;
@property (nonatomic, assign) float pulsePerMin;
@property (nonatomic, assign) BOOL failed;

@end

typedef void (^ZZLEDPulseSampleCallBack)(ZZLEDColorSample *sample);
typedef void (^ZZLEDPulseDetectCallBack)(ZZLEDPulseDetection *detection);

@interface ZZLEDPulseMeasure : NSObject

@property (nonatomic, strong, readonly) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) ZZLEDPulseSampleCallBack sampleCallBack;
@property (nonatomic, strong) ZZLEDPulseDetectCallBack detectCallBack;
@property (nonatomic, readonly) BOOL running;

- (void)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
