//
//  PLGPUImageFilterViewController.m
//  PLStreamingKit
//
//  Created by 0dayZh on 16/3/8.
//  Copyright © 2016年 0dayZh. All rights reserved.
//

#import "PLGPUImageFilterViewController.h"
#import "GPUImage.h"
#import <PLStreamingKit/PLStreamingKit.h>

extern const char *stateNames[];

@interface PLGPUImageFilterViewController ()
<
PLStreamingSessionDelegate,
PLStreamingSendingBufferDelegate
>

@property (nonatomic, strong) GPUImageVideoCamera *videoCamera;
@property (nonatomic, strong) PLStreamingSession    *session;

@end

@implementation PLGPUImageFilterViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self setupGPUImage];
    [self setupPili];
}

- (void)setupGPUImage {
    GPUImageVideoCamera *videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset640x480 cameraPosition:AVCaptureDevicePositionBack];
    videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
    
    GPUImageSketchFilter *filter = [[GPUImageSketchFilter alloc] init];
    
    CGRect bounds = [UIScreen mainScreen].bounds;
    CGFloat width = CGRectGetWidth(bounds);
    CGFloat height = width * 640.0 / 480.0;
    GPUImageView *filteredVideoView = [[GPUImageView alloc] initWithFrame:(CGRect){0, 64, width, height}];
    
    // Add the view somewhere so it's visible
    [self.view addSubview:filteredVideoView];
    
    [videoCamera addTarget:filter];
    [filter addTarget:filteredVideoView];
    
    GPUImageRawDataOutput *rawDataOutput = [[GPUImageRawDataOutput alloc] initWithImageSize:CGSizeMake(480, 640) resultsInBGRAFormat:YES];
    [filter addTarget:rawDataOutput];
    __unsafe_unretained GPUImageRawDataOutput * weakOutput = rawDataOutput;
    __weak typeof(self) wself = self;
    [rawDataOutput setNewFrameAvailableBlock:^{
        __strong typeof(wself) strongSelf = wself;
        [weakOutput lockFramebufferForReading];
        GLubyte *outputBytes = [weakOutput rawBytesForImage];
        NSInteger bytesPerRow = [weakOutput bytesPerRowInOutput];
        CVPixelBufferRef pixelBuffer = NULL;
        CVPixelBufferCreateWithBytes(kCFAllocatorDefault, 480, 640, kCVPixelFormatType_32BGRA, outputBytes, bytesPerRow, nil, nil, nil, &pixelBuffer);
        [weakOutput unlockFramebufferAfterReading];
        if(pixelBuffer == NULL) {
            return ;
        }
        
        [strongSelf.session pushPixelBuffer:pixelBuffer completion:^{
            CVPixelBufferRelease(pixelBuffer);
        }];
    }];
    [videoCamera startCameraCapture];
    
    self.videoCamera = videoCamera;
}

- (void)setupPili {
    PLVideoStreamingConfiguration *videoConfiguration = [PLVideoStreamingConfiguration configurationWithVideoSize:CGSizeMake(480, 640) videoQuality:kPLVideoStreamingQualityMedium1];
    
#warning 你需要设定 streamJSON 为自己服务端创建的流
    NSDictionary *streamJSON;
    
    PLStream *stream = [PLStream streamWithJSON:streamJSON];
    
    self.session = [[PLStreamingSession alloc] initWithVideoConfiguration:videoConfiguration
                                                       audioConfiguration:nil
                                                                   stream:stream];
    self.session.delegate = self;
}

#pragma mark - <PLStreamingSendingBufferDelegate>

- (void)streamingSessionSendingBufferDidEmpty:(id)session {
    NSLog(@"Sending buffer empty");
}

- (void)streamingSessionSendingBufferDidFull:(id)session {
    NSLog(@"Sending buffer full");
}

#pragma mark - <PLCameraStreamingSessionDelegate>

- (void)streamingSession:(PLStreamingSession *)session streamStateDidChange:(PLStreamState)state {
    // 除 PLStreamStateError 外的所有状态都会回调在这里
    NSString *log = [NSString stringWithFormat:@"Stream State: %s", stateNames[state]];
    NSLog(@"%@", log);
    if (PLStreamStateDisconnected == state) {
        [self.actionButton setTitle:@"Start" forState:UIControlStateNormal];
    }
}

- (void)streamingSession:(PLStreamingSession *)session didDisconnectWithError:(NSError *)error {
    // PLStreamStateError 状态会回调在这里
    NSString *log = [NSString stringWithFormat:@"Stream State: Error. %@", error];
    NSLog(@"%@", log);
    [self.actionButton setTitle:@"Start" forState:UIControlStateNormal];
}

- (void)streamingSession:(PLStreamingSession *)session streamStatusDidUpdate:(PLStreamStatus *)status {
    NSLog(@"%@", status);
}


#pragma mark - Action

- (IBAction)actionButtonPressed:(id)sender {
    self.actionButton.enabled = NO;
    
    switch (self.session.streamState) {
        case PLStreamStateConnected:
            [self.session stop];
            [self.actionButton setTitle:@"Start" forState:UIControlStateNormal];
            self.actionButton.enabled = YES;
            break;
        case PLStreamStateUnknow:
        case PLStreamStateDisconnected:
        case PLStreamStateError: {
            [self.session startWithCompleted:^(BOOL success) {
                if (success) {
                    NSString *log = @"success to start streaming";
                    NSLog(@"%@", log);
                    [self.actionButton setTitle:@"Stop" forState:UIControlStateNormal];
                } else {
                    NSString *log = @"fail to start streaming.";
                    NSLog(@"%@", log);
                    [self.actionButton setTitle:@"Start" forState:UIControlStateNormal];
                }
                self.actionButton.enabled = YES;
            }];
        }
            break;
        default:
            break;
    }
}

@end
