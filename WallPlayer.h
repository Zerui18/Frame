#import <AVFoundation/AVFoundation.h>

// Logical container for the AVQueuePlayer used in this tweak.
// Manages a single instance of AVQueuePlayer that's controlled by the AVPlayerLooper.
// Adds AVPlayerLayer to the provided views.

@interface WallPlayer: NSObject {
    NSUserDefaults *bundleDefaults;
    AVAudioSession *audioSession;
}

@property(setter=setVideoURL:, nonatomic) NSURL *videoURL;
@property AVPlayerItem *playerItem;
@property AVQueuePlayer *player;
@property AVPlayerLooper *looper;
@property(setter=setPauseInApps:, nonatomic) BOOL pauseInApps;
@property(setter=setEnabledScreens:, nonatomic) NSString *enabledScreens;

+ (id) shared;
- (AVPlayerLayer *) addInView: (UIView *) superview;
- (void) play;
- (void) pause;
- (void) loadPreferences;

@end