//
//  SceneDelegate.h
//  LEDPulseMeasure
//
//  Created by zjj on 2020/4/27.
//  Copyright © 2020 zjj. All rights reserved.
//

#import "ZZLEDPulseMeasure.h"

@implementation ZZLEDSignalSample

//- (CGFloat)value {
//    return self.brightness;
//}

@end

@implementation ZZLEDPulseDetection

@end

@interface ZZLEDSignalSampleGroup : NSObject

@property (nonatomic, strong) NSArray<ZZLEDSignalSample *> *simples;

@end

@implementation ZZLEDSignalSampleGroup

@end

const long kMinSignalSampleCount = 4;
const long kMaxSignalSampleCount = 10;
const float kPulseIntensityErrorThreshold = 0.4;
const float kDeltaTimeErrorThreshold = 0.2;
const NSInteger kMinDetectedUsingCount = 3;
const NSInteger kMaxDetectedUsingCount = 5;
const NSTimeInterval kOutDateTimeInterval = 2.5;

@interface ZZLEDPulseMeasure ()<AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureDevice *device;
@property (nonatomic, strong) AVCaptureDeviceInput *input;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutput;
@property (nonatomic, strong) dispatch_queue_t captureQueue;
//@property (nonatomic, strong) VideoPreviewView *previewView;

@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

@property (nonatomic, strong) NSMutableArray *signals;
@property (nonatomic, strong) NSMutableArray *foundPulses;

@end

@implementation ZZLEDPulseMeasure

- (void)dealloc {
    [self stop];
}

#pragma mark - get

- (BOOL)running {
    return self.session.isRunning;
}

- (void)start {
    [self.session startRunning];
    [self setTorchOpen:YES];
}

- (void)stop {
    [self.session stopRunning];
    [self setTorchOpen:NO];
    [self.signals removeAllObjects];
    [self.foundPulses removeAllObjects];
}

- (void)setTorchOpen:(BOOL)open {
    if ([self.device isTorchModeSupported:AVCaptureTorchModeOn]) {
        [self.device lockForConfiguration:nil];
        self.device.torchMode = open ? AVCaptureTorchModeOn : AVCaptureTorchModeOff;
        [self.device unlockForConfiguration];
    }
}

#pragma mark - set

//static NSDictionary *stateStrings = nil;

- (void)setState:(ZZLEDPulseMeasureState)state {
    ZZLEDPulseMeasureState oldOne = _state;
    _state = state;
    if (oldOne != _state) {
        // 状态变了
//        if (stateStrings == nil) {
//            stateStrings = @{
//                @(ZZLEDPulseMeasureStateNothing):@"Nothing",
//                @(ZZLEDPulseMeasureStatePrepared):@"Prepared",
//                @(ZZLEDPulseMeasureStateMeasuring):@"Counting",
//                @(ZZLEDPulseMeasureStateCompleted):@"Completed",
//            };
//        }
//        NSLog(@"state: %@", stateStrings[@(state)]);
        if (self.stateCallBack) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.stateCallBack(state);
            });
        }
    }
}

- (void)setStateCallBack:(ZZLEDPulseStateCallBack)stateCallBack {
    _stateCallBack = stateCallBack;
    if (stateCallBack) {
        dispatch_async(dispatch_get_main_queue(), ^{
            stateCallBack(self.state);
        });
    }
}

#pragma mark - init

- (instancetype)init {
    self = [super init];
    [self config];
    return self;
}

- (void)config {
    self.session = [[AVCaptureSession alloc] init];
    [self.session setSessionPreset:AVCaptureSessionPresetLow];
    
    self.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    // 锁定白平衡和曝光！很重要！使得信号更平稳
    [self.device lockForConfiguration:nil];
    [self.device setExposureModeCustomWithDuration:AVCaptureExposureDurationCurrent ISO:AVCaptureISOCurrent completionHandler:^(CMTime syncTime) {
        
    }];
    self.device.whiteBalanceMode = AVCaptureWhiteBalanceModeLocked;
    [self.device unlockForConfiguration];
    
    self.input = [AVCaptureDeviceInput deviceInputWithDevice:self.device error:nil];
    if ([self.session canAddInput:self.input]) {
        [self.session addInput:self.input];
    }
    
    self.captureQueue = dispatch_get_global_queue(0, 0);
    self.videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    [self.videoOutput setSampleBufferDelegate:self queue:self.captureQueue];
    [self.videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    if ([self.session canAddOutput:self.videoOutput]) {
        [self.session addOutput:self.videoOutput];
    }
    
    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.previewLayer.masksToBounds = YES;
    
    [self setupSignalProcess];
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (output == self.videoOutput) {
        [self handleWithSampleBuffer:sampleBuffer];
    }
}

#pragma mark - calculate

- (void)handleWithSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    CVImageBufferRef cvimg = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(cvimg, 0);
    size_t width = CVPixelBufferGetWidth(cvimg);
    size_t height = CVPixelBufferGetHeight(cvimg);
    size_t pixelCount = width * height;
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(cvimg);
    size_t bytesPerPixel = 4;
    UInt8 *data = CVPixelBufferGetBaseAddress(cvimg);
    // 32BGRA
    double red = 0, green = 0, blue = 0;
    for (size_t y = 0; y < height; y++) {
        for (size_t x = 0; x < width; x++) {
            size_t pixelIndex = y * bytesPerRow + x * bytesPerPixel;
            blue += data[pixelIndex + 0];
            green += data[pixelIndex + 1];
            red += data[pixelIndex + 2];
        }
    }
    CVPixelBufferUnlockBaseAddress(cvimg, 0);
    red = red / pixelCount / 255;
    green = green / pixelCount / 255;
    blue = blue / pixelCount / 255;
    UIColor *color = [UIColor colorWithRed:red green:green blue:blue alpha:1];
    CGFloat hue, saturation, brightness;
    [color getHue:&hue saturation:&saturation brightness:&brightness alpha:nil];
    
    ZZLEDSignalSample *sample = [[ZZLEDSignalSample alloc] init];
    sample.time = NSDate.timeIntervalSinceReferenceDate;
    sample.value = brightness;
//    NSLog(@"hue:%.02f, sat:%.02f, bri:%.02f", hue, saturation, brightness);
    // 检查手指是否放好（色相红色，饱和度高，亮度高）
    BOOL isRedColor = hue < 0.1 || hue > 0.9;
    BOOL isHighSaturation = saturation > 0.7;
    BOOL isHighBrightness = brightness > 0.4;
    BOOL gotFinger = isRedColor && isHighSaturation && isHighBrightness;
    if (gotFinger) {
        if (self.state == ZZLEDPulseMeasureStateNothing) {
            self.state = ZZLEDPulseMeasureStatePrepared;
        }
    } else {
        self.state = ZZLEDPulseMeasureStateNothing;
        [self.foundPulses removeAllObjects];
    }
    [self handleSignalSample:sample];
}

#pragma mark - handleSignalSample

- (void)setupSignalProcess {
    self.signals = NSMutableArray.array;
    self.foundPulses = NSMutableArray.array;
}

- (void)handleSignalSample:(ZZLEDSignalSample *)sample {
//    sample.brightness = (sample.brightness - 0.8) * 4;
//    ZZLEDSignalSample *theLastOne = self.signals.lastObject;
//    if (theLastOne) {
//        float weight = 0.5;
//        sample.brightness = (sample.value * weight) + (theLastOne.value * (1.0 - weight));
//        // 防抖？
//    }
    [self.signals addObject:sample];
    NSInteger count = self.signals.count;
    // 有一定数量的样本就开始数
    if (count > kMinSignalSampleCount) {
        [self calculateInMyWay];
    }
    // 保证最大样品数量
    if (count > kMaxSignalSampleCount) {
        [self.signals removeObjectsInRange:NSMakeRange(0, count - kMaxSignalSampleCount)];
//        [self.signals removeObjectAtIndex:0];
    }
    
    if (self.sampleCallBack) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.sampleCallBack(sample);
        });
    }
}

- (void)calculateInMyWay {
    if (self.state < ZZLEDPulseMeasureStatePrepared) {
        return;
    }
    
    // 已知波动是有规律的，一个周期内，缓慢上升，极速下降
    // 目标是找出下降的位置
    // 以n个点为一组，计算出相邻两点的差，若差的和小于某个阈值，说明有下降趋势，要注意是不是噪声导致的下降
    // 以上面找到的有下降趋势的起点，是否有必要再往后找差的和最小的位置
    // 得到一个位置，寻找下一个
    
    NSArray *usingSignals = self.signals.copy;
    NSInteger count = usingSignals.count;
//    NSInteger steps = 4;
//    NSMutableArray *foundPulses = NSMutableArray.array;
    
    // 找到上一次脉冲
    ZZLEDSignalSample *lastFoundSample = self.foundPulses.lastObject;
    NSTimeInterval outDateInterval = kOutDateTimeInterval;
    NSTimeInterval nowTime = NSDate.timeIntervalSinceReferenceDate;
    NSInteger lastFoundIndex = 0;
    if (nowTime - lastFoundSample.time > outDateInterval) {
        // 超过这个时间的是为过期的记录，需要重新计数
        lastFoundSample = nil;
        [self.foundPulses removeAllObjects];
    } else {
        if ([self.signals containsObject:lastFoundSample]) {
            lastFoundIndex = [self.signals indexOfObject:lastFoundSample];
        }
    }
    
    // 找一个下降点和上升点，暂且认为是一个脉冲
    NSInteger dropingIndex = 0;
    NSInteger risingIndex = 0;
    ZZLEDSignalSample *lastCheckSample = lastFoundSample;
    float pulseIntensity = 0;
    float lastBiggestDelta = 0;
    NSInteger startEmuIndex = lastFoundIndex + 1;
    NSInteger emuCount = count;
    for (NSInteger emuIndex = startEmuIndex; emuIndex < emuCount - 1; emuIndex++) {
        ZZLEDSignalSample *sig = usingSignals[emuIndex];
        float delta = sig.value - lastCheckSample.value;
        lastCheckSample = sig;
        if (delta < 0) {
            // start droping?
            pulseIntensity += delta;
            BOOL get = YES;
            if (lastFoundSample.pulseIntensity != 0) {
                // 有合格的上一个就要和上一个比较信号强度
                float rate = pulseIntensity / lastFoundSample.pulseIntensity;
                if (rate > (1 / (1 - kPulseIntensityErrorThreshold)) || rate < (1 - kPulseIntensityErrorThreshold)) {
                    get = NO;
                }
            }
            // start
            if (get) {
                if (delta < lastBiggestDelta) {
                    lastBiggestDelta = delta;
                    dropingIndex = emuIndex;
                    // found a start droping point
                    continue;
                }
//                else if (dropingIndex > 0 && (delta / lastBiggestDelta) < 0.2) {
//                    risingIndex = emuIndex;
//                    break;
//                }
            }
        }
        else if (dropingIndex > 0) {
            risingIndex = emuIndex;
            if (risingIndex - dropingIndex > 3) {
                risingIndex = dropingIndex + 3;
            }
            break;
        }
    }
    if (dropingIndex > startEmuIndex && risingIndex > dropingIndex) {
        NSInteger usingIndex = risingIndex;//(dropingIndex + risingIndex) / 2;
//        NSLog(@"found:%@", @(arc4random()));
        ZZLEDSignalSample *foundSample = usingSignals[usingIndex];
        if (lastFoundSample) {
            NSTimeInterval deltaTime = foundSample.time - lastFoundSample.time;
            foundSample.deltaTime = deltaTime;
            if (lastFoundSample.deltaTime > 0 && lastFoundSample.deltaTime < outDateInterval) {
                float rate = deltaTime / lastFoundSample.deltaTime;
                if (rate < (1 - kDeltaTimeErrorThreshold) || rate > (1 / (1 - kDeltaTimeErrorThreshold))) {
                    // 保证周期基本平稳，与上一个比较
                    // 与上一个失去了联系
                    // 恢复到prepard
//                    self.state = ZZLEDPulseMeasureStatePrepared;
                    [self.foundPulses removeAllObjects];
                    foundSample.deltaTime = 0;
//                    NSLog(@"out date");
                }
            } else {
//                lastFoundSample.deltaTime = deltaTime;
            }
        }
        foundSample.pulseIntensity = pulseIntensity;
        [self.foundPulses addObject:foundSample];
        ZZLEDPulseDetection *detection = ZZLEDPulseDetection.alloc.init;
        NSMutableArray *calculatedPulses = self.foundPulses.mutableCopy;
        NSInteger detectedCount = calculatedPulses.count;
        NSInteger maxUsingCount = kMaxDetectedUsingCount;
        if (detectedCount > maxUsingCount) {
            [calculatedPulses removeObjectsInRange:NSMakeRange(0, detectedCount - maxUsingCount)];
//            detection.detectedSamples = [detection.detectedSamples subarrayWithRange:NSMakeRange(detectedCount - maxUsingCount, maxUsingCount)];
            detectedCount = maxUsingCount;
        }
        if (detectedCount > 1) {
            ZZLEDSignalSample *first = calculatedPulses.firstObject;
            ZZLEDSignalSample *last = calculatedPulses.lastObject;
            NSTimeInterval totalTimes = last.time - first.time;
            float pulseCount = detectedCount - 1;
            float pulsesPerMin = pulseCount / totalTimes * 60.0;
//            NSLog(@"pu:%f", pulsesPerMin);
            detection.pulsePerMin = pulsesPerMin;
            detection.detectedSamples = calculatedPulses;
            if (pulsesPerMin < 30 || pulsesPerMin > 220) {
                // 不正常的数字
                [self.foundPulses removeAllObjects];
                detectedCount = 0;
            }
        }
        // 连续的点越多越可信
        detection.confidence = (double)detectedCount / (double)kMaxSignalSampleCount * 0.6 + 0.4;
        // 当存在几个连续的检测点时
        // 变成counting状态
        NSInteger minUsingCount = kMinDetectedUsingCount;
        if (detectedCount >= minUsingCount) {
            self.state = ZZLEDPulseMeasureStateMeasuring;
            if (self.measureCallBack) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.measureCallBack(detection);
                });
            }
        }
        if (self.detectCallBack) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.detectCallBack(detection);
            });
        }
    }
}

@end
