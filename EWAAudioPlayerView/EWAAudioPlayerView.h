//
//  EWAAudioPlayerView.h
//
//  Created by Matt Blair on 11/24/12.
//
//

// initial version of this will assume iPhone/popover width of 320 points.

// default images (current layout expects a @1x image of 7 x 14)
#define PLAY_BUTTON_IMAGE @"play-audio"
#define PAUSE_BUTTON_IMAGE @"pause-audio"

// dictionary keys for setting custom images on init
#define kEWAAudioPlayerPlayImageKey @"kEWAAudioPlayerPlayImageKey"
#define kEWAAudioPlayerPauseImageKey @"kEWAAudioPlayerPauseImageKey"
#define kEWAAudioPlayerThumbImageKey @"kEWAAudioPlayerThumbImageKey"
#define kEWAAudioPlayerUnplayedTrackImageKey @"kEWAAudioPlayerUnplayedTrackImageKey"
#define kEWAAudioPlayerPlayedTrackImageKey @"kEWAAudioPlayerPlayedTrackImageKey"


#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface EWAAudioPlayerView : UIView <AVAudioPlayerDelegate>

// slider styling
// note: setting color removes custom images
@property (strong, nonatomic) UIColor *playedTrackColor;
@property (strong, nonatomic) UIColor *unplayedTrackColor;
@property (strong, nonatomic) UIColor *thumbColor; // has no effect in iOS 7?

// add notes about setting background color/view

- (id)initWithAudioURL:(NSURL *)audioURL images:(NSDictionary *)imageNames;

- (void)pausePlayback;
- (void)resumePlayback;

@end
