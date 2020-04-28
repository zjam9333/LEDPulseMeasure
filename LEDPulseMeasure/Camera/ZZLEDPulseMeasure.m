//
//  SceneDelegate.h
//  LEDPulseMeasure
//
//  Created by zjj on 2020/4/27.
//  Copyright © 2020 zjj. All rights reserved.
//

#import "ZZLEDPulseMeasure.h"
#import <Accelerate/Accelerate.h>

@implementation ZZLEDColorSample

- (CGFloat)value {
    return self.brightness;
}

@end

@implementation ZZLEDPulseDetection

@end

const long kPreferSignalLength = 100;

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

@property (nonatomic, assign) BOOL didArrivePreferSinalLength;

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
    red /= pixelCount;
    green /= pixelCount;
    blue /= pixelCount;
    UIColor *color = [UIColor colorWithRed:red / 255 green:green / 255 blue:blue / 255 alpha:0];
    CGFloat hue, saturation, brightness;
    [color getHue:&hue saturation:&saturation brightness:&brightness alpha:nil];
    ZZLEDColorSample *sample = [[ZZLEDColorSample alloc] init];
    sample.timeInterval = NSDate.timeIntervalSinceReferenceDate;
    sample.hue = hue;
    sample.saturation = saturation;
    sample.brightness = brightness;
    [self handleSignalSample:sample];
    
    CVPixelBufferUnlockBaseAddress(cvimg, 0);
}

#pragma mark - handleSignalSample

- (void)setupSignalProcess {
    self.signals = NSMutableArray.array;
}

- (void)handleSignalSample:(ZZLEDColorSample *)sample {
    NSInteger count = self.signals.count;
    if (count == 0) {
        self.didArrivePreferSinalLength = NO;
    }
    [self.signals addObject:sample];
    count += 1;
    
//    BOOL hasEnou
//    if (count > kPreferSignalLength -) {
////        [self calculateUsingFFT];
//    }
    if (count > kPreferSignalLength) {
        [self calculateInMyWay];
        self.didArrivePreferSinalLength = YES;
        [self.signals removeObjectsInRange:NSMakeRange(0, kPreferSignalLength / 5)];
    }
    
    if (self.sampleCallBack) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.sampleCallBack(sample);
        });
    }
}

- (void)calculateInMyWay {
    NSArray *usingSignals = self.signals.copy;
    NSInteger count = usingSignals.count;
    NSInteger steps = 4;
    NSMutableArray *foundPulses = NSMutableArray.array;
    for (NSInteger i = 0; i + steps < count - 1; i++) {
        ZZLEDColorSample *firstSampleForStep = usingSignals[i];
        ZZLEDColorSample *lastCheckSample = firstSampleForStep;
        float delta = 0;
        for (NSInteger k = 1; k < steps; k++) {
            ZZLEDColorSample *thisCheckSample = usingSignals[i + k];
            float thisdelta = thisCheckSample.value - lastCheckSample.value;
            delta += thisdelta;
            lastCheckSample = thisCheckSample;
        }
        if (delta < 0) {
            [foundPulses addObject:firstSampleForStep];
            i += steps;
        }
    }

    ZZLEDPulseDetection *detection = ZZLEDPulseDetection.alloc.init;
    if (foundPulses.count > 1) {
        ZZLEDColorSample *first = foundPulses.firstObject;
        ZZLEDColorSample *last = foundPulses.lastObject;
        NSTimeInterval totalTimes = last.timeInterval - first.timeInterval;
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
}

/*
- (void)calculateUsingFFT {
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
            // 上面采样时把10秒钟的数据当成1秒钟了，于是频率增长了10倍
            int pulse = i;
    //                int pulse = (int)(1.0 / ((float)(i) / 10.0) * 60.0);
            [componentFrequencies addObject:@(pulse)];
        }
    }
    NSLog(@"%@", componentFrequencies);
}
// */

@end
