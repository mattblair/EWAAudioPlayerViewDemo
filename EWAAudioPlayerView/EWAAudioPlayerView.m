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

// From Marcus Zarra, as defined here:
// http://www.cimgf.com/2010/05/02/my-current-prefix-pch-file/
// and
// https://github.com/ZarraStudios/ZDS_Shared

#ifndef DLog
#ifdef DEBUG
#define DLog(...) NSLog(@"%s(%p) %@", __PRETTY_FUNCTION__, self, [NSString stringWithFormat:__VA_ARGS__])
#else
#define DLog(...) do { } while (0)
#endif
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

@property (strong, nonatomic) AVPlayer *remotePlayer;

@property (nonatomic) BOOL localFile;
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

- (id)initWithAudioURL:(NSURL *)audioURL images:(NSDictionary *)imageNames atY:(CGFloat)playerY {
    
#warning Magic Numbers!!!
    CGRect defaultFrame = CGRectMake(0.0, playerY, 320.0, 44.0); // height was 52
    
    self = [super initWithFrame:defaultFrame];
    if (self) {
        
        self.backgroundColor = [UIColor clearColor];
        
        self.playing = NO;
        
        // init this with a bogus value
        self.lastPauseTime = -1.0;
        
        
        // test audioURL to see if it's a file URL that AVAudioPlayer can handle
        // https://developer.apple.com/library/ios/qa/qa1634/_index.html
        if ([audioURL isFileURL]) {
            
            NSError *audioError = nil;
            self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:audioURL
                                                                      error:&audioError];
            // TODO: test audioError here?
            
            self.audioPlayer.delegate = self;
            
            self.localFile = YES;
            
        } else { // if it's not, use AVPLayer for a remote audio file
            
            self.remotePlayer = [AVPlayer playerWithURL:audioURL];
            
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(playerItemEnded:)
                                                         name:AVPlayerItemDidPlayToEndTimeNotification
                                                       object:nil];
            
            // set up KVO to react when the player is ready
            NSString *kp = NSStringFromSelector(@selector(status));
            [self.remotePlayer addObserver:self
                                forKeyPath:kp //@"status"
                                   options:0
                                   context:NULL];
            
            self.localFile = NO;
        }
        
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
        
        //DLog(@"sliderFrame: %@", NSStringFromCGRect(sliderFrame));
        
        self.audioScrubber = [[UISlider alloc] initWithFrame:sliderFrame];
        
        self.audioScrubber.value = 0.0;
        
        // this will be reset once remotePlayer's status is readyToPlay
        self.audioScrubber.maximumValue = self.localFile ? self.audioPlayer.duration : 1.0;
        
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
        
        // replaced with using text when no custom images are specified
        /*
        NSString *playImage = nil;
        NSString *pauseImage = nil;
        
        if (imageNames) {
            playImage = [imageNames objectForKey:kEWAAudioPlayerPlayImageKey];
            pauseImage = [imageNames objectForKey:kEWAAudioPlayerPauseImageKey];
        } else {
            playImage = PLAY_BUTTON_IMAGE;
            pauseImage = PAUSE_BUTTON_IMAGE;
        }
        */
        
        self.playButton.imageEdgeInsets = UIEdgeInsetsMake(8.0, 8.0, 8.0, 8.0);
        
        if (imageNames) {
            
            NSString *playImage = [imageNames objectForKey:kEWAAudioPlayerPlayImageKey];
            NSString *pauseImage = [imageNames objectForKey:kEWAAudioPlayerPauseImageKey];
            
            [self.playButton setImage:[UIImage imageNamed:playImage]
                             forState:UIControlStateNormal];
            
            [self.playButton setImage:[UIImage imageNamed:pauseImage]
                             forState:UIControlStateSelected];
        } else {
            
            [self.playButton setTitle:@"Play"
                             forState:UIControlStateNormal];
            
            [self.playButton setTitle:@"Pause"
                             forState:UIControlStateSelected];
            
            // shouldn't this happen automatically?
            [self.playButton setTitleColor:[self tintColor]
                                  forState:UIControlStateNormal];
        }
        
        [self.playButton addTarget:self
                            action:@selector(togglePlayStatus)
                  forControlEvents:UIControlEventTouchUpInside];
        
        [self addSubview:self.playButton];
        
        // remotePlayer will enable the button when it's in readyToPlay status
        self.playButton.enabled = self.localFile ? YES : NO;
        
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
    DLog(@"WARNING: Do not use initWithFrame with this class.");
    return nil;
}

- (void)handleBackgrounding:(NSNotification *)note {
    
    DLog(@"Pausing audio player");
    
    [self pauseAudio];
}

- (void)prepareToBeForegrounded:(NSNotification *)note {
    
    // reset audio to 0, or to last time stored?
    DLog(@"Foregrounded");
    
    [self resumePlayback];
}

- (void)dealloc {
    
    if (!self.localFile) {
        [self.remotePlayer removeObserver:self
                               forKeyPath:NSStringFromSelector(@selector(status))];
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Player Property Utility Methods

- (BOOL)playerIsPlaying {
    
    if (self.localFile) {
        return self.audioPlayer.playing;
    } else {
        //TODO: Is this the best option?
        return self.remotePlayer.rate > 0.0;
    }
}

- (NSTimeInterval)currentPlayerTime {
    
    if (self.localFile) {
        return self.audioPlayer.currentTime;
    } else {
        
        if (self.remotePlayer.status == AVPlayerStatusReadyToPlay) {
            return CMTimeGetSeconds(self.remotePlayer.currentTime);
        } else {
            return 0.0;
        }
    }
}

- (NSTimeInterval)audioDuration {
    
    if (self.localFile) {
        return self.audioPlayer.duration;
    } else {
        // is duration available from any file format? If not, use cached duration?
        return -1.0;
    }
}


#pragma mark - Update Display

- (void)updateCurrentTimeDisplay {
    
    int current = (int)[self currentPlayerTime];
    self.currentTime.text = [NSString stringWithFormat:@"%d:%02d", current / 60, current % 60, nil];
}

- (void)updateScrubberThumbPosition {
    
    self.audioScrubber.value = [self currentPlayerTime];
}

- (void)updateThumbAndTime {
    
    if (self.localFile) {
        DLog(@"Current time is %g", self.audioPlayer.currentTime);
    }
    
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
        
        if (self.localFile) {
            [self.audioPlayer play];
        } else {
            [self.remotePlayer play];
        }
        
        self.thumbTimer = [NSTimer scheduledTimerWithTimeInterval:AUDIO_DISPLAY_UPDATE_INTERVAL
                                                           target:self
                                                         selector:@selector(updateThumbAndTime)
                                                         userInfo:nil
                                                          repeats:YES];
        
        self.playButton.selected = [self playerIsPlaying];
    }
}

- (void)pauseAudio {
    
    if (self.playing) {
        
        self.playing = NO;
        
        if (self.localFile) {
            [self.audioPlayer pause];
        } else {
            [self.remotePlayer pause];
        }
        
        [self.thumbTimer invalidate];
        
        // TODO: Add utility method for caching pause time, if needed
        
        if (self.localFile && self.audioPlayer.currentTime > 0.0) {
            
            self.lastPauseTime = self.audioPlayer.currentTime;
        }
        
        self.playButton.selected = [self playerIsPlaying];
    }
}

- (void)togglePlayStatus {
    
    // manage state with view property instead of player property:
    if (self.playing) {
        [self pauseAudio];
    } else {
        [self playAudio];
    }
}

- (void)handleScrubbing {
    
    if (self.localFile) {
        self.audioPlayer.currentTime = self.audioScrubber.value;
    } else {
        
        DLog(@"WARNING: scrubbing not implemented for streaming audio.");
    }
    
    [self updateCurrentTimeDisplay];
}


#pragma mark - External Control of Playback

- (void)pausePlayback {
    
    [self pauseAudio];
}

- (void)resumePlayback {
    
    // resume playback -- or return to the start and play?
    
    if (self.lastPauseTime > 0.0) {
        
        if (self.localFile) {
            self.audioPlayer.currentTime = self.lastPauseTime;
        } else {
            // TODO: convert pauseTime to CMTime, set for remotePlayer?
            // seems to work fine without it, so far.
        }
        
        [self playAudio];
    }
}


#pragma mark - AVAudioPlayerDelegate Methods

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    
    [self.thumbTimer invalidate];
    self.thumbTimer = nil;
    
    DLog(@"AudioPlayer finished %@", flag ? @"successfully." : @"badly!");
    
    [self updateThumbAndTime];
    
    self.playButton.selected = self.audioPlayer.playing;
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error {
    
    DLog(@"Audio decoding failed with error: %@", error);
    
    self.audioScrubber.value = 0;
    
    self.playButton.enabled = NO;
}

// doesn't get called on backgrounding ?
- (void)audioPlayerBeginInterruption:(AVAudioPlayer *)player {
    
    DLog(@"Audio player interrupted.");
    
    [self pausePlayback];
}

// iOS 6.0+
// doesn't get called on backgrounding ?
- (void)audioPlayerEndInterruption:(AVAudioPlayer *)player withOptions:(NSUInteger)flags {
    
    //typedef enum : NSUInteger {
    //    AVAudioSessionInterruptionOptionShouldResume = 1
    //} AVAudioSessionInterruptionOptions;
    
    DLog(@"Options: %lu", (unsigned long)flags);
    
    // don't restart
}


#pragma mark - React to AVPlayer (Streaming) Status

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    NSString *kp = NSStringFromSelector(@selector(status));
    
    if (object == self.remotePlayer && [keyPath isEqualToString:kp]) {
        
        switch (self.remotePlayer.status) {
            
            case AVPlayerStatusReadyToPlay: {
                DLog(@"Ready");
                
                // enable playback UI
                self.playButton.enabled = YES;
                
                // TODO: doesn't seem available with mp3. Try with caf.
                AVPlayerItem *item = self.remotePlayer.currentItem;
                
                if (!CMTIME_IS_INDEFINITE(item.duration)) {
                    
# warning CMTimeGetSeconds() returns float64, while maximumValue is a float
                    self.audioScrubber.maximumValue = CMTimeGetSeconds(self.remotePlayer.currentItem.duration);
                    
                } else {
                    DLog(@"Duration is still not defined.");
                }
                
                break;
            }
                
            case AVPlayerStatusFailed: {
                DLog(@"WARNING: PLayer status is failed, with error: %@", self.remotePlayer.error);
                
                // disable playback UI, show notice to user?
                self.playButton.enabled = NO;
                
                break;
            }
                
            default: {
                DLog(@"Presumably unknown?");
                self.playButton.enabled = NO;
                
                break;
            }
        }
    }
    
    // call super? Does UIView implement it?
}
             
- (void)playerItemEnded:(NSNotification *)note {
 
    // update UI here?
    DLog(@"Playback completed with note: %@", note);
}

@end
