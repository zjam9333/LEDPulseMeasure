//
//  TestFFT.m
//  LEDPulseMeasure
//
//  Created by zjj on 2020/4/28.
//  Copyright © 2020 zjj. All rights reserved.
//

#import "TestFFT.h"
#import <Accelerate/Accelerate.h>

@implementation TestFFT

//*
+ (void)load {
    // test fft
    
    // Create the Composite Signal
    vDSP_Length n = 512;
    float frequencies[6] = {1, 5, 25, 30, 75, 123};
    float tau = M_PI * 2;
    float signal[n];
    for (int i = 0; i < n; i++) {
        float accumulator = 0;
        for (int k = 0; k < 6; k ++) {
            float normalizedIndex = (float)(i) / (float)(n);
            float frequency = frequencies[k];
            accumulator += sinf(normalizedIndex * frequency * tau);
        }
        signal[i] = accumulator;
    }
    
    // Create the FFT Setup
    vDSP_Length log2n = log2(n);
    FFTSetup fftSetUp = vDSP_create_fftsetup(log2n, kFFTRadix2);
    
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
            [componentFrequencies addObject:@(i)];
        }
    }
    NSLog(@"%@", componentFrequencies);
    
    NSLog(@"%@", @"good");
    
    vDSP_destroy_fftsetup(fftSetUp);
}
//*/

@end
