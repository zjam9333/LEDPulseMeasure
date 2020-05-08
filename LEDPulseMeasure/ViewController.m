//
//  ViewController.m
//  LEDPulseMeasure
//
//  Created by zjj on 2020/4/27.
//  Copyright © 2020 zjj. All rights reserved.
//

#import "ViewController.h"
#import "ZZLEDPulseMeasure.h"

@interface ViewController ()

@property (nonatomic, strong) ZZLEDPulseMeasure *measure;
@property (weak, nonatomic) IBOutlet UIView *drawView;
@property (weak, nonatomic) IBOutlet UILabel *textLabel;
@property (weak, nonatomic) IBOutlet UILabel *heartView;
@property (weak, nonatomic) IBOutlet UISegmentedControl *stateIndicator;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.measure = ZZLEDPulseMeasure.alloc.init;
    self.measure.previewLayer.frame = CGRectMake(0, 0, 100, 100);
    [self.view.layer insertSublayer:self.measure.previewLayer atIndex:0];
    
    UIView *view = self.drawView;
    self.measure.sampleCallBack = ^(ZZLEDSignalSample * _Nonnull sample) {
//        NSLog(@"%@", @(sample.brightness));
        CGSize size = view.frame.size;
        CGFloat x = size.width;
        CGFloat y = size.height * (1 - sample.value);
        UIView *point = [[UIView alloc] initWithFrame:CGRectMake(x, y, 1, 1)];
        point.backgroundColor = sample.color ? : UIColor.whiteColor;
        [view addSubview:point];
        [UIView animateWithDuration:10 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
            CGRect fra = point.frame;
            fra.origin.x = 0;
            point.frame = fra;
        } completion:^(BOOL finished) {
            [point removeFromSuperview];
        }];
        sample.pointView = point;
    };
    UILabel *label = self.textLabel;
    UIView *heartView = self.heartView;
    self.measure.detectCallBack = ^(ZZLEDPulseDetection * _Nonnull detection) {
        UIView *pointv = detection.detectedSamples.lastObject.pointView;
        pointv.backgroundColor = UIColor.redColor;
        pointv.transform = CGAffineTransformMakeScale(4, 4);
        heartView.transform = CGAffineTransformMakeScale(1.5, 1.5);
        [UIView animateWithDuration:0.2 animations:^{
            heartView.transform = CGAffineTransformMakeScale(1, 1);
        }];
    };
    self.measure.measureCallBack = ^(ZZLEDPulseDetection * _Nonnull detection) {
        label.text = @((int)(detection.pulsePerMin)).stringValue;
    };
    UISegmentedControl *seg = self.stateIndicator;
    self.measure.stateCallBack = ^(ZZLEDPulseMeasureState state) {
        seg.selectedSegmentIndex = state;
        if (state != ZZLEDPulseMeasureStateMeasuring) {
            label.text = @"-";
        }
    };
}

- (IBAction)captureButton:(id)sender {
    if (self.measure.running) {
        [self.measure stop];
    } else {
        [self.measure start];
    }
}

@end
