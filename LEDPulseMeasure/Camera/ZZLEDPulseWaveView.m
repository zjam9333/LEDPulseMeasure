//
//  ZZLEDPulseWaveView.m
//  LEDPulseMeasure
//
//  Created by zjj on 2020/5/8.
//  Copyright © 2020 zjj. All rights reserved.
//

#import "ZZLEDPulseWaveView.h"

const NSInteger kMaxSignalCount = 120;
const NSTimeInterval kTimerInterval = 0.02;
const NSTimeInterval kPulseWaveCycle = 0.2;
const double kUnknownValue = -1000;
const double kMaxNormalScaleValue = 0.05;
const double kScaleFadeStep = 0.001;

@implementation ZZLEDPulseWaveView {
    NSMutableArray<NSNumber *> *signals;
    double lastMax;
    double lastMin;
    NSTimer *timer;
    BOOL isPulsing;
    NSTimeInterval pulsingCounter;
    double randomScale;
    double normalScale;
    NSTimer *fadeTimer;
}

- (void)dealloc {
    [timer invalidate];
}

- (void)setWaving:(BOOL)waving {
    BOOL old = _waving;
    _waving = waving;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    [self config];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    [self config];
    return self;
}

- (void)config {
    if (self.backgroundColor == nil) {
        self.backgroundColor = UIColor.clearColor;
    }
    [timer invalidate];
    timer = [NSTimer timerWithTimeInterval:kTimerInterval target:self selector:@selector(autoRunning:) userInfo:nil repeats:YES];
    [NSRunLoop.currentRunLoop addTimer:timer forMode:NSRunLoopCommonModes];
    signals = NSMutableArray.array;
    for (NSInteger i = 0; i < kMaxSignalCount; i++) {
        [signals addObject:[NSNumber numberWithDouble:0]];
    }
}

- (void)autoRunning:(NSTimer *)tm {
    // add fake signals
    NSTimeInterval nowTime = NSDate.timeIntervalSinceReferenceDate;
//    double scale = 0.05;// * (double)(arc4random() % 30 + 70) / 100;
//    if (self.waving == NO) {
//        scale = 0.001;
//    }
    if (self.waving) {
        if (normalScale < 0) {
            normalScale = 0;
        }
        if (normalScale < kMaxNormalScaleValue) {
            normalScale += kScaleFadeStep;
        }
    } else {
        if (normalScale > kMaxNormalScaleValue) {
            normalScale = kMaxNormalScaleValue;
        }
        if (normalScale > 0) {
            normalScale -= kScaleFadeStep;
        }
    }
    double scale = normalScale;
    double val = sin(nowTime * 23) + sin(nowTime * 3) + sin(nowTime * 7);
    val = val * scale;
    if (isPulsing) {
        scale = 0.45;// * (double)(arc4random() % 30 + 70) / 100;
        double w = 2 * M_PI / kPulseWaveCycle;
        val = val + sin(pulsingCounter * w);
        val = val * scale * randomScale;
        val = -val;
        pulsingCounter += kTimerInterval;
    }
    [signals addObject:[NSNumber numberWithDouble:val]];
    NSInteger count = signals.count;
    if (count > kMaxSignalCount) {
        [signals removeObjectsInRange:NSMakeRange(0, count - kMaxSignalCount)];
    }
    [self setNeedsDisplay];
}

- (void)addPulseWithConfidence:(CGFloat)value {
    isPulsing = YES;
    pulsingCounter = 0;
    randomScale = (double)(arc4random() % 20 + 80) / 100 * value;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((kPulseWaveCycle) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self->isPulsing = NO;
    });
    self.waving = YES;
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    if (rect.size.width == 0 || rect.size.height == 0) {
        return;
    }
    NSInteger count = signals.count;
    if (count == 0) {
        return;
    }
    // 画曲线
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(context, 2.0);
    UIColor *color = self.drawColor?: UIColor.redColor;
    [color setStroke];
    [color setFill];
    for (NSInteger i = 0; i + 1 < count; i++) {
        NSInteger startIndex = i;
        NSInteger endIndex = i + 1;
        double startVal = [signals[startIndex] doubleValue];
        double endVal = [signals[endIndex] doubleValue];
        if (startVal == kUnknownValue) {
            continue;
        }
        double startX = rect.size.width * startIndex / count;
        double endX = rect.size.width * endIndex / count;
        double startY = (startVal + 0.5) * rect.size.height;
        double endY = (endVal + 0.5) * rect.size.height;
        CGContextMoveToPoint(context, startX, startY);
        CGContextAddLineToPoint(context, endX, endY);
        CGContextDrawPath(context, kCGPathStroke);
        if (endIndex == count - 1) {
            CGFloat radius = 4;
            CGContextAddArc(context, rect.size.width - radius, endY, radius, 0, M_PI * 2, 0);
            CGContextDrawPath(context, kCGPathFill);
        }
    }
}

@end
