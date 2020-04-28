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

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.measure = ZZLEDPulseMeasure.alloc.init;
    self.measure.previewLayer.frame = CGRectMake(0, 0, 100, 100);
    [self.view.layer addSublayer:self.measure.previewLayer];
    
    UIView *view = self.drawView;
    self.measure.sampleCallBack = ^(ZZLEDColorSample * _Nonnull sample) {
//        NSLog(@"%@", @(sample.brightness));
        CGSize size = view.frame.size;
        CGFloat x = size.width;
        CGFloat y = size.height * (1 - sample.brightness);
        UIView *point = [[UIView alloc] initWithFrame:CGRectMake(x, y, 1, 1)];
        point.backgroundColor = UIColor.redColor;
        [view addSubview:point];
        [UIView animateWithDuration:10 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
            CGRect fra = point.frame;
            fra.origin.x = 0;
            point.frame = fra;
        } completion:^(BOOL finished) {
            [point removeFromSuperview];
        }];
    };
    UILabel *label = self.textLabel;
    self.measure.detectCallBack = ^(ZZLEDPulseDetection * _Nonnull detection) {
        label.text = @((int)(detection.pulsePerMin)).stringValue;
//        [UIView animateWithDuration:0.1 animations:^{
//            label.transform = CGAffineTransformMakeScale(2, 2);
//        } completion:^(BOOL finished) {
//            [UIView animateWithDuration:0.4 animations:^{
//                label.transform = CGAffineTransformMakeScale(1, 1);
//            } completion:nil];
//        }];
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
