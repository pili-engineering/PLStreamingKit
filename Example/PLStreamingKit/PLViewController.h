//
//  PLViewController.h
//  PLStreamingKit
//
//  Created by 0dayZh on 11/04/2015.
//  Copyright (c) 2015 0dayZh. All rights reserved.
//

@import UIKit;
@import AVFoundation;

#import <PLStreamingKit/PLStreamingKit.h>

@interface PLViewController : UIViewController
<
AVCaptureVideoDataOutputSampleBufferDelegate,
PLStreamingSessionDelegate,
PLStreamingSendingBufferDelegate
>

@property (nonatomic, strong) PLStreamingSession    *session;

@property (nonatomic, strong) AVCaptureSession  *cameraCaptureSession;
@property (nonatomic, strong) AVCaptureDevice   *cameraCaptureDevice;

@property (nonatomic, assign) AudioComponentInstance    componetInstance;
@property (nonatomic, assign) AudioComponent            component;

@property (weak, nonatomic) IBOutlet UIButton *actionButton;

@property (nonatomic, assign) BOOL audioOnly;

@end
