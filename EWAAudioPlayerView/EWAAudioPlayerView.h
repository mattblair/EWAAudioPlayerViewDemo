//
//  EWAAudioPlayerView.h
//
//  Created by Matt Blair on 11/24/12.
//
//

// initial version of this will assume iPhone/popover width of 320 points.
// a future version should handle variables widths, and margins

#import <UIKit/UIKit.h>

// dictionary keys for setting custom images on init
extern NSString* const kEWAAudioPlayerPlayImageKey;
extern NSString* const kEWAAudioPlayerPauseImageKey;
extern NSString* const kEWAAudioPlayerThumbImageKey;
extern NSString* const kEWAAudioPlayerUnplayedTrackImageKey;
extern NSString* const kEWAAudioPlayerPlayedTrackImageKey;

@protocol AVAudioPlayerDelegate;

@interface EWAAudioPlayerView : UIView <AVAudioPlayerDelegate>

// slider styling
// note: setting color removes custom images
@property (strong, nonatomic) UIColor *playedTrackColor;
@property (strong, nonatomic) UIColor *unplayedTrackColor;
@property (strong, nonatomic) UIColor *thumbColor; // has no effect in iOS 7?

// add notes about setting background color/view

- (id)initWithAudioURL:(NSURL *)audioURL images:(NSDictionary *)imageNames atY:(CGFloat)playerY;

- (void)pausePlayback;
- (void)resumePlayback;

@end
