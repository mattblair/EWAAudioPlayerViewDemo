//
//  EWAViewController.m
//  EWAAudioPlayerViewDemo
//
//  Created by Matt Blair on 1/24/14.
//  Copyright (c) 2014 Elsewise LLC
//  License: MIT
//

#import "DemoViewController.h"

#import "EWAAudioPlayerView.h"

#import "DemoConstants.h"

#define DEFAULT_CONTENT_WIDTH 300.0
#define DEFAULT_LEFT_MARGIN 10.0

#define VERTICAL_SPACER_STANDARD 20.0
#define VERTICAL_SPACER_EXTRA 50.0


@interface DemoViewController ()

@property (nonatomic) CGFloat yForNextView;

@property (strong, nonatomic) UIFont *fontForLabels;

@property (strong, nonatomic) UILabel *basicLabel;
@property (strong, nonatomic) EWAAudioPlayerView *basicAudioPlayerView;

@property (strong, nonatomic) UILabel *styledLabel;
@property (strong, nonatomic) EWAAudioPlayerView *styledAudioPlayerView;

@property (strong, nonatomic) UILabel *remoteLabel;
@property (strong, nonatomic) EWAAudioPlayerView *remoteAudioPlayerView;

@end

@implementation DemoViewController

- (void)loadView {
    
    [super loadView];
    
	self.view.backgroundColor = [UIColor whiteColor];
    
    self.title = NSLocalizedString(@"EWAAudioPlayerView Demo", @"Title for Demo View Controller");
    
    self.yForNextView = 40.0;
    
    self.fontForLabels = [UIFont fontWithName:@"Menlo" size:20.0];
    
    self.basicLabel = [self labelWithText:@"Default"
                                      atY:self.yForNextView];
    
    // basic player
    
    NSURL *bundleAudioURL = [[NSBundle mainBundle] URLForResource:kDemoAudioFile
                                                    withExtension:@"caf"];
    
    if (bundleAudioURL) {
        
        self.basicAudioPlayerView = [[EWAAudioPlayerView alloc] initWithAudioURL:bundleAudioURL
                                                                          images:nil
                                                                             atY:self.yForNextView];
        //self.basicAudioPlayerView.remoteBackgroundColor = [UIColor cyanColor];
        self.basicAudioPlayerView.buttonTextColor = [UIColor redColor];
        
        [self.view addSubview:self.basicAudioPlayerView];
        
        // increment y
        self.yForNextView += self.basicAudioPlayerView.frame.size.height + VERTICAL_SPACER_EXTRA;
        
    } else {
        
        NSLog(@"Failed to locate audio file in bundle");
    }
    
    self.styledLabel = [self labelWithText:@"Custom Graphics"
                                       atY:self.yForNextView];
    
    // custom player
    
    if (bundleAudioURL) {
        
        NSDictionary *imageNames = @{
                                     kEWAAudioPlayerPlayImageKey : kPlayButtonImage,
                                     kEWAAudioPlayerPauseImageKey : kPauseButtonImage,
                                     kEWAAudioPlayerThumbImageKey : kThumbButtonImage,
                                     kEWAAudioPlayerUnplayedTrackImageKey : kMaximumTrackImage,
                                     kEWAAudioPlayerPlayedTrackImageKey : kMinimumTrackImage };
        
        self.styledAudioPlayerView = [[EWAAudioPlayerView alloc] initWithAudioURL:bundleAudioURL
                                                                           images:imageNames
                                                                              atY:self.yForNextView];
        
        [self.view addSubview:self.styledAudioPlayerView];
        
        // increment y
        self.yForNextView += self.styledAudioPlayerView.frame.size.height + VERTICAL_SPACER_EXTRA;
        
    } else {
        
        NSLog(@"Failed to locate audio file in bundle");
    }
    
    
    self.remoteLabel = [self labelWithText:@"Playing a Remote Audio File (duration unknown)"
                                       atY:self.yForNextView];
    
    // remote player
    
    NSURL *remoteURL = [NSURL URLWithString:kRemoteAudioURL];
    
    self.remoteAudioPlayerView = [[EWAAudioPlayerView alloc] initWithAudioURL:remoteURL
                                                                       images:nil
                                                                          atY:self.yForNextView];
    
    self.remoteAudioPlayerView.remoteBackgroundColor = [UIColor blackColor];
    self.remoteAudioPlayerView.buttonTextColor = [UIColor redColor];
    self.remoteAudioPlayerView.buttonFont = [UIFont fontWithName:@"Menlo-Bold"
                                                            size:17.0];
    
    [self.view addSubview:self.remoteAudioPlayerView];
    
    self.yForNextView += self.remoteAudioPlayerView.frame.size.height + VERTICAL_SPACER_EXTRA;
}

// configure the label, add it to the view, and increment y
- (UILabel *)labelWithText:(NSString *)labelText atY:(CGFloat)labelY {
    
    UILabel *theLabel = [[UILabel alloc] initWithFrame:CGRectMake(DEFAULT_LEFT_MARGIN, self.yForNextView,
                                                                  DEFAULT_CONTENT_WIDTH, 31.0)];
    theLabel.numberOfLines = 0;
    theLabel.lineBreakMode = NSLineBreakByWordWrapping;
    theLabel.text = labelText;
    theLabel.font = self.fontForLabels;
    
    [theLabel sizeToFit];
    
    [self.view addSubview:theLabel];
    
    self.yForNextView += theLabel.frame.size.height + VERTICAL_SPACER_STANDARD;
    
    return theLabel;
}

- (void)didReceiveMemoryWarning {
    
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
