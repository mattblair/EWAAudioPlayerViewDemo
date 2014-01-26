//
//  EWAAudioPlayerView.m
//
//  Created by Matt Blair on 11/24/12.
//
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag
#endif

// based on steipete's approach in this gist:
// https://gist.github.com/steipete/6526860
#ifndef kCFCoreFoundationVersionNumber_iOS_7_0
#define kCFCoreFoundationVersionNumber_iOS_7_0 847.2
#endif

#ifndef ON_IOS7
#define ON_IOS7 kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_7_0
#endif

#ifndef PRE_IOS7
#define PRE_IOS7 kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_7_0
#endif

#import <AVFoundation/AVFoundation.h>

#import "EWAAudioPlayerView.h"

NSString* const kEWAAudioPlayerPlayImageKey = @"kEWAAudioPlayerPlayImageKey";
NSString* const kEWAAudioPlayerPauseImageKey = @"kEWAAudioPlayerPauseImageKey";
NSString* const kEWAAudioPlayerThumbImageKey = @"kEWAAudioPlayerThumbImageKey";
NSString* const kEWAAudioPlayerUnplayedTrackImageKey = @"kEWAAudioPlayerUnplayedTrackImageKey";
NSString* const kEWAAudioPlayerPlayedTrackImageKey = @"kEWAAudioPlayerPlayedTrackImageKey";

// private constants

// default images (current layout expects a @1x image of 7 x 14)
#define PLAY_BUTTON_IMAGE @"play-audio"
#define PAUSE_BUTTON_IMAGE @"pause-audio"

#define AUDIO_TIME_DEFAULT_Y 6.0
#define AUDIO_TIME_LABEL_WIDTH 28.0
#define AUDIO_TIME_LABEL_FONT_SIZE 12.0 // was 10.0, but that's too small

// Based on the assumption that a clip is several minutes long, and the thumb
// might not even move every second.

// .5 is good for a > 1 minute, but looks choppy with shorter clips
// scale this to the length of the clip automatically?
#define AUDIO_DISPLAY_UPDATE_INTERVAL .25

@interface EWAAudioPlayerView ()

@property (strong, nonatomic) AVAudioPlayer *audioPlayer;

@property (nonatomic) BOOL playing;
@property (nonatomic) NSTimeInterval lastPauseTime;


@property (strong, nonatomic) UILabel *currentTime;
@property (strong, nonatomic) UILabel *totalTime;
@property (strong, nonatomic) UISlider *audioScrubber;

@property (strong, nonatomic) UIButton *playButton;

@property (strong, nonatomic) NSTimer *thumbTimer;

@end

@implementation EWAAudioPlayerView

#pragma mark - View lifecycle

- (id)initWithAudioURL:(NSURL *)audioURL images:(NSDictionary *)imageNames {
    
    CGRect defaultFrame = CGRectMake(0.0, 0.0, 320.0, 44.0); // height was 52
    
    self = [super initWithFrame:defaultFrame];
    if (self) {
        
        self.backgroundColor = [UIColor underPageBackgroundColor];
        
        self.playing = NO;
        
        // init this with a bogus value
        self.lastPauseTime = -1.0;
        
        NSError *audioError = nil;
        
        // test audioURL to see if it's a file URL:
        // https://developer.apple.com/library/ios/qa/qa1634/_index.html
        
        // if it's not, try AVPLayer instead, or assign a delegate to download and re-init on completion
        
        self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:audioURL
                                                                  error:&audioError];
        
        // test audioError here?
        
        self.audioPlayer.delegate = self;
        
        CGRect currentFrame = CGRectMake(10.0, AUDIO_TIME_DEFAULT_Y, AUDIO_TIME_LABEL_WIDTH, 30.0);
        
        self.currentTime = [[UILabel alloc] initWithFrame:currentFrame];
        
        self.currentTime.text = @"0:00";
        self.currentTime.font = [UIFont systemFontOfSize:AUDIO_TIME_LABEL_FONT_SIZE];
        self.currentTime.backgroundColor = [UIColor clearColor];
        self.currentTime.textAlignment = NSTextAlignmentCenter;
        
        [self addSubview:self.currentTime];
        
        // adjust/calculate for different UIKit metrics
        // would also need to be adjusted for custom images with different metrics
        // On-device test results using KBB graphics:
        // iPhone 5 running 7.0.2: y=4 was better. Not so after 7.0.3 update.
        // iPhone 4 running 6.0.1: y=9 looks best.
        // iPhone 4 running 7.0.3: y=9 looks too high, by about 3-4 pts
        // try adjusting the height of the UISlider? Is making it too short causing a side effect?
        
        CGFloat sliderY = ON_IOS7 ? 15.0 : 10.0;
        
        //CGFloat sliderY = 9.0; // seems to work better on most device/iOS combinations
        CGRect sliderFrame = CGRectMake(42.0, sliderY, 192.0, 14.0);
        
        //NSLog(@"sliderFrame: %@", NSStringFromCGRect(sliderFrame));
        
        self.audioScrubber = [[UISlider alloc] initWithFrame:sliderFrame];
        
        self.audioScrubber.value = 0.0;
        self.audioScrubber.maximumValue = self.audioPlayer.duration;
        
        [self.audioScrubber addTarget:self
                               action:@selector(handleScrubbing)
                     forControlEvents:UIControlEventValueChanged];
        
        if (imageNames) {
            
            // track images are 192 x 14
            UIImage *minTrackImage = [UIImage imageNamed:[imageNames objectForKey:kEWAAudioPlayerPlayedTrackImageKey]];
            UIImage *maxTrackImage = [UIImage imageNamed:[imageNames objectForKey:kEWAAudioPlayerUnplayedTrackImageKey]];
            UIImage *thumbImage = [UIImage imageNamed:[imageNames objectForKey:kEWAAudioPlayerThumbImageKey]];
            
            if (minTrackImage && maxTrackImage && thumbImage) {
                
                [self.audioScrubber setMinimumTrackImage:minTrackImage
                                                forState:UIControlStateNormal];
                
                [self.audioScrubber setMaximumTrackImage:maxTrackImage
                                                forState:UIControlStateNormal];
                
                [self.audioScrubber setThumbImage:thumbImage
                                         forState:UIControlStateNormal];
            }
        }
        
        [self addSubview:self.audioScrubber];
        
        CGRect totalFrame = CGRectMake(240.0, AUDIO_TIME_DEFAULT_Y, AUDIO_TIME_LABEL_WIDTH, 30.0);
        
        self.totalTime = [[UILabel alloc] initWithFrame:totalFrame];
        self.totalTime.font = [UIFont systemFontOfSize:AUDIO_TIME_LABEL_FONT_SIZE];
        self.totalTime.backgroundColor = [UIColor clearColor];
        self.totalTime.textAlignment = NSTextAlignmentCenter;
        
        self.totalTime.text = [NSString stringWithFormat:@"%d:%02d",
                               (int)self.audioPlayer.duration / 60, (int)self.audioPlayer.duration % 60, nil];
        
        [self addSubview:self.totalTime];
        
        //CGRect buttonFrame = CGRectMake(274.0, 7.0, 28.0, 28.0);
        CGRect buttonFrame = CGRectMake(266.0, -1.0, 44.0, 44.0);
        
        self.playButton = [[UIButton alloc] initWithFrame:buttonFrame];
        
        NSString *playImage = nil;
        NSString *pauseImage = nil;
        
        if (imageNames) {
            playImage = [imageNames objectForKey:kEWAAudioPlayerPlayImageKey];
            pauseImage = [imageNames objectForKey:kEWAAudioPlayerPauseImageKey];
        } else {
            playImage = PLAY_BUTTON_IMAGE;
            pauseImage = PAUSE_BUTTON_IMAGE;
        }
        
        self.playButton.imageEdgeInsets = UIEdgeInsetsMake(8.0, 8.0, 8.0, 8.0);
        
        [self.playButton setImage:[UIImage imageNamed:playImage]
                         forState:UIControlStateNormal];
        
        [self.playButton setImage:[UIImage imageNamed:pauseImage]
                         forState:UIControlStateSelected];
        
        [self.playButton addTarget:self
                            action:@selector(togglePlayStatus)
                  forControlEvents:UIControlEventTouchUpInside];
        
        [self addSubview:self.playButton];
        
        // UIApplicationDidEnterBackgroundNotification is too late to handle audio
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleBackgrounding:)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(prepareToBeForegrounded:)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    NSLog(@"WARNING: Do not use initWithFrame with this class.");
    return nil;
}

- (void)handleBackgrounding:(NSNotification *)note {
    
    NSLog(@"Pausing audio player");
    
    [self pauseAudio];
}

- (void)prepareToBeForegrounded:(NSNotification *)note {
    
    // reset audio to 0, or to last time stored?
    NSLog(@"Foregrounded");
    
    [self resumePlayback];
}

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Update Display

- (void)updateCurrentTimeDisplay {
    
    int current = (int)self.audioPlayer.currentTime;
    
    self.currentTime.text = [NSString stringWithFormat:@"%d:%02d", current / 60, current % 60, nil];
}

- (void)updateScrubberThumbPosition {
    
    self.audioScrubber.value = self.audioPlayer.currentTime;
}

- (void)updateThumbAndTime {
    
    NSLog(@"Current time is %g", self.audioPlayer.currentTime);
    
    [self updateCurrentTimeDisplay];
    [self updateScrubberThumbPosition];
}


#pragma mark - UISlider Styling

- (void)setPlayedTrackColor:(UIColor *)playedTrackColor {
    
    self.audioScrubber.minimumTrackTintColor = playedTrackColor;
}

- (void)setUnplayedTrackColor:(UIColor *)unplayedTrackColor {
    
    self.audioScrubber.maximumTrackTintColor = unplayedTrackColor;
}

- (void)setThumbColor:(UIColor *)thumbColor {
    
    self.audioScrubber.thumbTintColor = thumbColor;
}


#pragma mark - Internal Handling of Playback

- (void)playAudio {
    
    if (!self.playing) {
        
        self.playing = YES;
        
        [self.audioPlayer play];
        
        self.thumbTimer = [NSTimer scheduledTimerWithTimeInterval:AUDIO_DISPLAY_UPDATE_INTERVAL
                                                           target:self
                                                         selector:@selector(updateThumbAndTime)
                                                         userInfo:nil
                                                          repeats:YES];
        
        self.playButton.selected = self.audioPlayer.playing;
    }
}

- (void)pauseAudio {
    
    if (self.playing) {
        
        self.playing = NO;
        
        [self.audioPlayer pause];
        [self.thumbTimer invalidate];
        
        if (self.audioPlayer.currentTime > 0.0) {
            self.lastPauseTime = self.audioPlayer.currentTime;
        }
        
        self.playButton.selected = self.audioPlayer.playing;
    }
}

- (void)togglePlayStatus {
    
    // manage state with superview property instead of audioplayer property:
    if (self.playing) {
        [self pauseAudio];
    } else {
        [self playAudio];
    }
}

- (void)handleScrubbing {
    
    self.audioPlayer.currentTime = self.audioScrubber.value;
    
    [self updateCurrentTimeDisplay];
}


#pragma mark - External Control of Playback

- (void)pausePlayback {
    
    [self pauseAudio];
}

- (void)resumePlayback {
    
    // resume playback -- or return to the start and play?
    
    if (self.lastPauseTime > 0.0) {
        self.audioPlayer.currentTime = self.lastPauseTime;
        
        [self playAudio];
    }
}


#pragma mark - AVAudioPlayerDelegate Methods

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    
    [self.thumbTimer invalidate];
    self.thumbTimer = nil;
    
    NSLog(@"AudioPlayer finished %@", flag ? @"successfully." : @"badly!");
    
    [self updateThumbAndTime];
    
    self.playButton.selected = self.audioPlayer.playing;
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error {
    
    NSLog(@"Audio decoding failed with error: %@", error);
    
    self.audioScrubber.value = 0;
    
    self.playButton.enabled = NO;
}

// doesn't get called on backgrounding ?
- (void)audioPlayerBeginInterruption:(AVAudioPlayer *)player {
    
    NSLog(@"Audio player interrupted.");
    
    [self pausePlayback];
}

// iOS 6.0+
// doesn't get called on backgrounding ?
- (void)audioPlayerEndInterruption:(AVAudioPlayer *)player withOptions:(NSUInteger)flags {
    
    //typedef enum : NSUInteger {
    //    AVAudioSessionInterruptionOptionShouldResume = 1
    //} AVAudioSessionInterruptionOptions;
    
    NSLog(@"Options: %d", flags);
    
    // don't restart
}

@end
