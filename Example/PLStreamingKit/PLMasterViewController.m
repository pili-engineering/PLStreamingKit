//
//  PLMasterViewController.m
//  PLStreamingKit
//
//  Created by 0dayZh on 15/11/4.
//  Copyright © 2015年 0dayZh. All rights reserved.
//

#import "PLMasterViewController.h"
#import "PLViewController.h"

@interface PLMasterViewController ()

@end

@implementation PLMasterViewController

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    NSString *identifier = segue.identifier;
    PLViewController *vc = segue.destinationViewController;
    
    if ([identifier isEqualToString:@"VideoAndAudio"]) {
        vc.audioOnly = NO;
    } else if ([identifier isEqualToString:@"Audio"]) {
        vc.audioOnly = YES;
    }
}

@end
