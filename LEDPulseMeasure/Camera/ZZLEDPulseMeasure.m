//
//  SceneDelegate.h
//  LEDPulseMeasure
//
//  Created by zjj on 2020/4/27.
//  Copyright © 2020 zjj. All rights reserved.
//

#import "ZZLEDPulseMeasure.h"
#import <Accelerate/Accelerate.h>

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

const long kMinSignalSampleCount = 30;
const long kMaxSignalSampleCount = 60;

@interface ZZLEDPulseMeasure ()<AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureDevice *device;
@property (nonatomic, strong) AVCaptureDeviceInput *input;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutput;
@property (nonatomic, strong) dispatch_queue_t captureQueue;
//@property (nonatomic, strong) VideoPreviewView *previewView;

@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

@property (nonatomic, assign) FFTSetup signalFFTSetup;
@property (nonatomic, strong) NSMutableArray *signals;
@property (nonatomic, strong) NSMutableArray *foundPulses;

@end

@implementation ZZLEDPulseMeasure

- (void)dealloc {
    [self stop];
    if (self.signalFFTSetup) {
        vDSP_destroy_fftsetup(self.signalFFTSetup);
    }
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
    self.previewLayer.videoGravity = AVLayerVideoGravityResize;
    
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
    red = red / pixelCount / 255;
    green = green / pixelCount / 255;
    blue = blue / pixelCount / 255;
    UIColor *color = [UIColor colorWithRed:red green:green blue:blue alpha:1];
    CGFloat hue, saturation, brightness;
    [color getHue:&hue saturation:&saturation brightness:&brightness alpha:nil];
    
    ZZLEDSignalSample *sample = [[ZZLEDSignalSample alloc] init];
    sample.time = NSDate.timeIntervalSinceReferenceDate;
    sample.value = green;
    [self handleSignalSample:sample];
    
    // test which channel is the best
    // 实验证明绿色较好
    /*
    if (self.sampleCallBack) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // test r, g, b, h, s, v
            ZZLEDSignalSample *sample = [[ZZLEDSignalSample alloc] init];
            sample.value = green;
            sample.color = UIColor.greenColor;
            self.sampleCallBack(sample);
            
            sample = [[ZZLEDSignalSample alloc] init];
            sample.value = red;
            sample.color = UIColor.redColor;
            self.sampleCallBack(sample);
            
            sample = [[ZZLEDSignalSample alloc] init];
            sample.value = blue;
            sample.color = UIColor.blueColor;
            self.sampleCallBack(sample);
            
            sample = [[ZZLEDSignalSample alloc] init];
            sample.value = hue;
            sample.color = UIColor.yellowColor;
            self.sampleCallBack(sample);
            sample = [[ZZLEDSignalSample alloc] init];
            sample.value = brightness;
            sample.color = UIColor.whiteColor;
            self.sampleCallBack(sample);
            sample = [[ZZLEDSignalSample alloc] init];
            sample.value = saturation;
            sample.color = UIColor.magentaColor;
            self.sampleCallBack(sample);
        });
    }
     //*/
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//
//        ZZLEDSignalSample *sample = [[ZZLEDSignalSample alloc] init];
//        sample.timeInterval = NSDate.timeIntervalSinceReferenceDate;
//        sample.hue = hue;
//        sample.saturation = saturation;
//        sample.brightness = brightness;
//        [self handleSignalSample:sample];
//    });
//    static int a;
//    a ++;
//    if (a % 2 == 0) {
//        [self handleSignalSample:sample];
//    }
    
    CVPixelBufferUnlockBaseAddress(cvimg, 0);
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
        [self.signals removeObjectsInRange:NSMakeRange(0, kMaxSignalSampleCount / 5)];
//        [self.signals removeObjectAtIndex:0];
    }
    
    if (self.sampleCallBack) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.sampleCallBack(sample);
        });
    }
}

- (void)calculateInMyWay {
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
    ZZLEDSignalSample *lastFoundSample = nil;
    // 超过这个时间的是为过期的记录
    NSTimeInterval outDateInterval = 2.1;
    NSTimeInterval nowTime = NSDate.timeIntervalSinceReferenceDate;
    NSInteger lastFoundIndex = 0;
    for (NSInteger emuIndex = count - 1; emuIndex >= 0; emuIndex--) {
        ZZLEDSignalSample *sig = usingSignals[emuIndex];
        if (sig.selected && (nowTime - sig.time < outDateInterval)) {
            lastFoundSample = sig;
            lastFoundIndex = emuIndex;
            break;
        }
    }
    if (lastFoundIndex == 0) {
        NSInteger preferTailCount = 5;
        // 多少个样本足以判断一个脉冲？
        if (count > preferTailCount) {
            lastFoundIndex = count - preferTailCount;
        }
        // 没有上一个脉冲记录，或已过时，则清理全部记录
        [self.foundPulses removeAllObjects];
    }
    
    // 找一个下降点和上升点，暂且认为是一个脉冲
    NSInteger dropingIndex = 0;
    NSInteger risingIndex = 0;
    ZZLEDSignalSample *lastCheckSample = lastFoundSample;
    float pulseIntensity = 0;
    float lastDelta = 0;
    for (NSInteger emuIndex = lastFoundIndex + 1; emuIndex < count - 1; emuIndex++) {
        ZZLEDSignalSample *sig = usingSignals[emuIndex];
        float delta = sig.value - lastCheckSample.value;
        lastCheckSample = sig;
        if (delta < 0) {
            // start droping?
            pulseIntensity += delta;
            if (pulseIntensity < lastFoundSample.pulseIntensity * 0.25) {
                // start
                if (delta < lastDelta) {
                    lastDelta = delta;
                    dropingIndex = emuIndex;
                    // found a start droping point
                    continue;
                }
            }
        }
        else if (dropingIndex > 0) {
            risingIndex = emuIndex;
            break;
        }
    }
    if (dropingIndex > 0 && risingIndex > dropingIndex) {
        NSInteger usingIndex = (dropingIndex + risingIndex) / 2;
//        NSLog(@"found:%@", @(arc4random()));
        ZZLEDSignalSample *foundSample = usingSignals[usingIndex];
        if (lastFoundSample) {
            NSTimeInterval deltaTime = foundSample.time - lastFoundSample.time;
            if (lastFoundSample.deltaTime > 0 && lastFoundSample.deltaTime < outDateInterval) {
                float rate = deltaTime / lastFoundSample.deltaTime;
                if (rate < 0.7 || rate > 1.6) {
                    // 保证周期基本平稳，与上一个比较
                    return;
                }
            } else {
                lastFoundSample.deltaTime = deltaTime;
            }
            foundSample.deltaTime = deltaTime;
        }
        foundSample.selected = YES;
        foundSample.pulseIntensity = pulseIntensity;
        [self.foundPulses addObject:foundSample];
        ZZLEDPulseDetection *detection = ZZLEDPulseDetection.alloc.init;
        NSMutableArray *calculatedPulses = self.foundPulses.mutableCopy;
        NSInteger detectedCount = calculatedPulses.count;
        NSInteger maxUsingCount = 5;
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
            NSLog(@"pu:%f", pulsesPerMin);
            detection.pulsePerMin = pulsesPerMin;
            detection.detectedSamples = calculatedPulses;
        }
        if (self.detectCallBack) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.detectCallBack(detection);
            });
        }
    }
    return;
    /*
    for (NSInteger emuIndex = 0 + steps; emuIndex + steps < count - 1; emuIndex++) {
        
        ZZLEDSignalSample *thisRoundFirstSample = usingSignals[emuIndex];
        //
        NSInteger endIndex = emuIndex;
        // 取2秒钟的时间范围
        NSTimeInterval beginTime = thisRoundFirstSample.time;
        for (NSInteger i = 0; i < count - 1; i++) {
            ZZLEDSignalSample *sig = usingSignals[i];
            if (sig.time - beginTime >= 2.0) {
                endIndex = i;
                break;
            }
        }
        // 找出一个区间内的最大值最小值
        float max = -100000, min = 100000;
        float currenMinDeltaThreshold = 0;
        for (NSInteger i = emuIndex; i <= endIndex; i++) {
            ZZLEDSignalSample *sig = usingSignals[i];
            float val = sig.value;
            if (val < min) {
                min = val;
            } else if (val > max) {
                max = val;
            }
        }
        currenMinDeltaThreshold = min - max;
        float usingDeltaThreshold = currenMinDeltaThreshold * 0.5;
        
        ZZLEDSignalSample *lastCheckSample = thisRoundFirstSample;
        float delta = 0;
        for (NSInteger k = 1; k < steps; k++) {
            ZZLEDSignalSample *thisCheckSample = usingSignals[emuIndex + k];
            float thisdelta = thisCheckSample.value - lastCheckSample.value;
//            if (thisdelta > 0) {
//                thisdelta = thisdelta * 0.2;
//            }
//            delta += thisdelta;
            if (0 > thisdelta) {
                delta += thisdelta;
            }
            lastCheckSample = thisCheckSample;
        }
        NSInteger selectedIndex = emuIndex + steps;
        ZZLEDSignalSample *usingSample = usingSignals[selectedIndex];
        if (delta < usingDeltaThreshold) {
            // 找到了一个下降趋势，是否要找到下降最强的呢，还是直接采用？
            [foundPulses addObject:usingSample];
            usingSample.selected = YES;
//            i += steps;
            emuIndex = selectedIndex;
            for (NSInteger nextIndex = selectedIndex; nextIndex < count - 1; nextIndex++) {
                ZZLEDSignalSample *sig = usingSignals[nextIndex];
                if (sig.time - usingSample.time >= 0.2) {
                    emuIndex = nextIndex;
                    break;
                }
            }
        }
    }

    ZZLEDPulseDetection *detection = ZZLEDPulseDetection.alloc.init;
//    if (foundPulses.count > 2) {
//        NSMutableArray *newArr = NSMutableArray.array;
//        ZZLEDSignalSample *first = foundPulses[0];
//        ZZLEDSignalSample *second = foundPulses[1];
//        ZZLEDSignalSample *lastOne = second;
//        NSTimeInterval lastTimeDelta = lastOne.timeInterval - first.timeInterval;
//        newArr addObject:(nonnull id)
//        for (NSInteger i = 2; i < foundPulses.count - 1; i ++) {
//            ZZLEDSignalSample *sig = foundPulses[i];
//            NSTimeInterval thisTimeDelta = sig.timeInterval - lastOne;
//        }
//    }
    if (foundPulses.count > 1) {
        ZZLEDSignalSample *first = foundPulses.firstObject;
        ZZLEDSignalSample *last = foundPulses.lastObject;
        NSTimeInterval totalTimes = last.time - first.time;
        float pulseCount = foundPulses.count - 1;
        float pulsesPerMin = pulseCount / totalTimes * 60.0;
        NSLog(@"pu:%f", pulsesPerMin);
        detection.detectedSamples = foundPulses;
        detection.pulsePerMin = pulsesPerMin;
    } else {
        detection.failed = YES;
    }
    if (self.detectCallBack) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.detectCallBack(detection);
        });
    }
    //*/
}

/*
- (void)calculateUsingFFT {
    // 尝试用傅立叶变换求出频域，但样品不稳定，结果不理想或根本没有结果
    // 摘抄自 https://developer.apple.com/documentation/accelerate/finding_the_component_frequencies_in_a_composite_sine_wave
    // fft
    
    // Create the Composite Signal
    vDSP_Length n = self.signals.count;
    float signal[n];
    for (int i = 0; i < n; i++) {
        float val = [[self.signals objectAtIndex:i] brightness];
        val = (val - 128) * 10;
        signal[i] = val;
    }

    // Create the FFT Setup
    vDSP_Length log2n = log2(n);
    if (self.signalFFTSetup == nil) {
        self.signalFFTSetup = vDSP_create_fftsetup(log2n, kFFTRadix2);
    }
    FFTSetup fftSetUp = self.signalFFTSetup;
    
    // Create the Source and Destination Arrays for the Forward FFT
    vDSP_Length halfN = n / 2;
    float forwardInputReal[halfN];
    float forwardInputImag[halfN];
    float forwardOutputReal[halfN];
    float forwardOutputImag[halfN];

    // Perform the Forward FFT
    DSPSplitComplex forwardInput;
    forwardInput.realp = forwardInputReal;
    forwardInput.imagp = forwardInputImag;
    for (int i = 0; i < halfN; i++) {
        float real = signal[2 * i];
        float imag = signal[2 * i + 1];
        forwardInput.realp[i] = real;
        forwardInput.imagp[i] = imag;
    }
    DSPSplitComplex forwardOutput;
    forwardOutput.realp = forwardOutputReal;
    forwardOutput.imagp = forwardOutputImag;
    vDSP_fft_zrop(fftSetUp, &forwardInput, 1, &forwardOutput, 1, log2n, kFFTDirection_Forward);

    // Compute Component Frequencies in Frequency Domain
    NSMutableArray *componentFrequencies = NSMutableArray.array;
    for (int i = 0; i < halfN; i++) {
        float value = forwardOutputImag[i];
        if (value < -1) {
            int pulse = i;
    //                int pulse = (int)(1.0 / ((float)(i) / 10.0) * 60.0);
            [componentFrequencies addObject:@(pulse)];
        }
    }
    NSLog(@"%@", componentFrequencies);
}
// */

@end
