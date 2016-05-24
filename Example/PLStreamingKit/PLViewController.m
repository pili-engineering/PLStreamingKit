//
//  PLViewController.m
//  PLStreamingKit
//
//  Created by 0dayZh on 11/04/2015.
//  Copyright (c) 2015 0dayZh. All rights reserved.
//

#import "PLViewController.h"

const char *stateNames[] = {
    "Unknow",
    "Connecting",
    "Connected",
    "Disconnecting",
    "Disconnected",
    "Error"
};

static OSStatus handleInputBuffer(void *inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList *ioData) {
    @autoreleasepool {
        PLViewController *ref = (__bridge PLViewController *)inRefCon;
        
        AudioBuffer buffer;
        buffer.mData = NULL;
        buffer.mDataByteSize = 0;
        buffer.mNumberChannels = 1;
        
        AudioBufferList buffers;
        buffers.mNumberBuffers = 1;
        buffers.mBuffers[0] = buffer;
        
        OSStatus status = AudioUnitRender(ref.componetInstance,
                                          ioActionFlags,
                                          inTimeStamp,
                                          inBusNumber,
                                          inNumberFrames,
                                          &buffers);
        
        if(!status) {
            AudioBuffer audioBuffer = buffers.mBuffers[0];
            [ref.session pushAudioBuffer:&audioBuffer asbd:ref.asbd];
        }
        return status;
    }
}

@interface PLViewController ()

@end

@implementation PLViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    PLVideoStreamingConfiguration *videoConfiguration = self.audioOnly ? nil : [PLVideoStreamingConfiguration configurationWithVideoSize:CGSizeMake(320, 576) videoQuality:kPLVideoStreamingQualityLow2];
    PLAudioStreamingConfiguration *audioConfiguration = [PLAudioStreamingConfiguration defaultConfiguration];
    
#warning 如果要运行 demo 这里应该填写服务端返回的某个流的 json 信息
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"http://pili-demo.qiniu.com/api/stream"]];
    request.HTTPMethod = @"POST";
    
    NSHTTPURLResponse *response = nil;
    NSError* err = nil;
    NSData* d = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&err];
    
    if (err != nil || response == nil || d == nil) {
        NSLog(@"get play json faild, %@, %@, %@", err, response, d);
        return;
    }
    
    NSDictionary *streamJSON = [NSJSONSerialization JSONObjectWithData:d options:NSJSONReadingMutableLeaves error:&err];
    if (err != nil || streamJSON == nil) {
        NSLog(@"json decode error %@", err);
        return;
    }
    
    NSLog(@"Stream Json %@", streamJSON);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:[NSString stringWithFormat:@"title: %@", streamJSON[@"title"]] delegate:nil cancelButtonTitle:@"ok" otherButtonTitles:nil];
        [alert show];
    });
    
    PLStream *stream = [PLStream streamWithJSON:streamJSON];
    
    self.session = [[PLStreamingSession alloc] initWithVideoConfiguration:videoConfiguration audioConfiguration:audioConfiguration stream:stream];
    self.session.delegate = self;
    self.session.bufferDelegate = self;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleInterruption:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:[AVAudioSession sharedInstance]];
    
    if (!self.audioOnly) {
        [self initCameraSource];
    }
    [self initMicrophoneSource];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.cameraCaptureSession stopRunning];
    AudioOutputUnitStop(self.componetInstance);
    [self.session destroy];
    free(self.asbd);
}

#pragma mark - Notification

- (void)handleInterruption:(NSNotification *)notification {
    if ([notification.name isEqualToString:AVAudioSessionInterruptionNotification]) {
        NSLog(@"Interruption notification");
        
        if ([[notification.userInfo valueForKey:AVAudioSessionInterruptionTypeKey] isEqualToNumber:[NSNumber numberWithInt:AVAudioSessionInterruptionTypeBegan]]) {
            NSLog(@"InterruptionTypeBegan");
        } else {
            // the facetime iOS 9 has a bug: 1 does not send interrupt end 2 you can use application become active, and repeat set audio session acitve until success.  ref http://blog.corywiles.com/broken-facetime-audio-interruptions-in-ios-9
            NSLog(@"InterruptionTypeEnded");
            setSamplerate();
        }
    }
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

#pragma mark - <PLStreamingSendingBufferDelegate>

- (void)streamingSessionSendingBufferDidEmpty:(id)session {
}

- (void)streamingSessionSendingBufferDidFull:(id)session {
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

#pragma mark - <AVCaptureVideoDataOutputSampleBufferDelegate>

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    [self.session pushVideoSampleBuffer:sampleBuffer];
}

#pragma mark - source

static void setSamplerate(){
    NSError *err;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setPreferredSampleRate:session.sampleRate error:&err];
    if (err != nil) {
        NSString *log = [NSString stringWithFormat:@"set samplerate failed, %@", err];
        NSLog(@"%@", log);
        return;
    }
    if (![session setActive:YES error:&err]) {
        NSString *log = @"Failed to set audio session active.";
        NSLog(@"%@ %@", log, err);
    }
}

- (void)initCameraSource {
    __weak typeof(self) wself = self;
    void (^permissionGranted)(void) = ^{
        __strong typeof(wself) strongSelf = wself;
        
        NSArray *devices = [AVCaptureDevice devices];
        for (AVCaptureDevice *device in devices) {
            if ([device hasMediaType:AVMediaTypeVideo] && AVCaptureDevicePositionBack == device.position) {
                strongSelf.cameraCaptureDevice = device;
                
                NSError *error;
                [device lockForConfiguration:&error];
                device.activeVideoMinFrameDuration = CMTimeMake(1, 30);
                device.activeVideoMaxFrameDuration = CMTimeMake(1, 30);
                [device unlockForConfiguration];
                break;
            }
        }
        
        if (!strongSelf.cameraCaptureDevice) {
            NSString *log = @"No back camera found.";
            NSLog(@"%@", log);
            return ;
        }
        
        AVCaptureSession *captureSession = [[AVCaptureSession alloc] init];
        AVCaptureDeviceInput *input = nil;
        AVCaptureVideoDataOutput *output = nil;
        
        input = [[AVCaptureDeviceInput alloc] initWithDevice:strongSelf.cameraCaptureDevice error:nil];
        output = [[AVCaptureVideoDataOutput alloc] init];
        
        dispatch_queue_t cameraQueue = dispatch_queue_create("com.pili.camera", 0);
        [output setSampleBufferDelegate:strongSelf queue:cameraQueue];
        
        // add input && output
        if ([captureSession canAddInput:input]) {
            [captureSession addInput:input];
        }
        
        if ([captureSession canAddOutput:output]) {
            [captureSession addOutput:output];
        }
        
        strongSelf.cameraCaptureSession = captureSession;
        
        [strongSelf reorientCamera:AVCaptureVideoOrientationPortrait];
        
        AVCaptureVideoPreviewLayer* previewLayer;
        previewLayer =  [AVCaptureVideoPreviewLayer layerWithSession:captureSession];
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        dispatch_async(dispatch_get_main_queue(), ^{
            previewLayer.frame = self.view.layer.bounds;
            [self.view.layer insertSublayer:previewLayer atIndex:0];
        });
        
        [strongSelf.cameraCaptureSession startRunning];
    };
    
    void (^noPermission)(void) = ^{
        NSString *log = @"No camera permission.";
        NSLog(@"%@", log);
    };
    
    void (^requestPermission)(void) = ^{
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            if (granted) {
                permissionGranted();
            } else {
                noPermission();
            }
        }];
    };
    
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    switch (status) {
        case AVAuthorizationStatusAuthorized:
            permissionGranted();
            break;
        case AVAuthorizationStatusNotDetermined:
            requestPermission();
            break;
        case AVAuthorizationStatusDenied:
        case AVAuthorizationStatusRestricted:
        default:
            noPermission();
            break;
    }
}

- (void)reorientCamera:(AVCaptureVideoOrientation)orientation {
    if (!self.cameraCaptureSession) {
        return;
    }
    
    AVCaptureSession* session = (AVCaptureSession *)self.cameraCaptureSession;
    
    for (AVCaptureVideoDataOutput* output in session.outputs) {
        for (AVCaptureConnection * av in output.connections) {
            av.videoOrientation = orientation;
        }
    }
}

- (void)initMicrophoneSource {
    __weak typeof(self) wself = self;
    void (^permissionGranted)(void) = ^{
        __strong typeof(wself) strongSelf = wself;
        
        AVAudioSession *session = [AVAudioSession sharedInstance];
        
        NSError *error = nil;
        
        [session setPreferredSampleRate:48000 error:&error];
        
        if (error) {
            NSLog(@"failed to set preferred sample rate : %@", error.localizedDescription);
        }

        [session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionMixWithOthers error:nil];
        if (![session setActive:YES error:&error]) {
            NSString *log = @"Failed to set audio session active.";
            NSLog(@"%@", log);
            return ;
        }
        
        AudioComponentDescription acd;
        acd.componentType = kAudioUnitType_Output;
        acd.componentSubType = kAudioUnitSubType_RemoteIO;
        acd.componentManufacturer = kAudioUnitManufacturer_Apple;
        acd.componentFlags = 0;
        acd.componentFlagsMask = 0;
        
        self.component = AudioComponentFindNext(NULL, &acd);
        
        OSStatus status = noErr;
        status = AudioComponentInstanceNew(strongSelf.component, &_componetInstance);
        
        if (noErr != status) {
            NSString *log = @"Failed to new a audio component instance.";
            NSLog(@"%@", log);
            return ;
        }
        
        UInt32 flagOne = 1;
        
        AudioUnitSetProperty(strongSelf.componetInstance, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &flagOne, sizeof(flagOne));
        
        AudioStreamBasicDescription *desc = calloc(1, sizeof(AudioStreamBasicDescription));
        desc->mSampleRate = 48000;
        desc->mFormatID = kAudioFormatLinearPCM;
        desc->mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        desc->mChannelsPerFrame = 1;
        desc->mFramesPerPacket = 1;
        desc->mBitsPerChannel = 16;
        desc->mBytesPerFrame = desc->mBitsPerChannel / 8 * desc->mChannelsPerFrame;
        desc->mBytesPerPacket = desc->mBytesPerFrame * desc->mFramesPerPacket;
        self.asbd = desc;
        AURenderCallbackStruct cb;
        cb.inputProcRefCon = (__bridge void *)(strongSelf);
        cb.inputProc = handleInputBuffer;
        AudioUnitSetProperty(strongSelf.componetInstance, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, desc, sizeof(AudioStreamBasicDescription));
        AudioUnitSetProperty(strongSelf.componetInstance, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 1, &cb, sizeof(cb));
        
        status = AudioUnitInitialize(strongSelf.componetInstance);
        
        if (noErr != status) {
            NSString *log = @"Failed to init audio unit.";
            NSLog(@"%@", log);
        }
        
        AudioOutputUnitStart(strongSelf.componetInstance);
        
        setSamplerate();
    };
    
    void (^noPermission)(void) = ^{
        NSString *log = @"No microphone permission.";
        NSLog(@"%@", log);
    };
    void (^requestPermission)(void) = ^{
        [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
            if (granted) {
                permissionGranted();
            } else {
                noPermission();
            }
        }];
    };
    
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    switch (status) {
        case AVAuthorizationStatusAuthorized:
            permissionGranted();
            break;
        case AVAuthorizationStatusNotDetermined:
            requestPermission();
            break;
        case AVAuthorizationStatusDenied:
        case AVAuthorizationStatusRestricted:
        default:
            noPermission();
            break;
    }
}

@end
