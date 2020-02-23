#import <AVFoundation/AVFoundation.h>

// Logical container for the AVQueuePlayer used in this tweak.
// Manages a single instance of AVQueuePlayer that's controlled by the AVPlayerLooper.
// Adds AVPlayerLayer to the provided views.

@interface WallPlayer : NSObject {
    NSUserDefaults *bundleDefaults;
    AVAudioSession *audioSession;

    AVQueuePlayer *sharedPlayer;
    AVQueuePlayer *lockscreenPlayer;
    AVQueuePlayer *homescreenPlayer;

    bool mutedLockscreen;
    bool mutedHomescreen;
}

// TODO: add custom setters to the following properties.
@property bool pauseInApps;


+ (id) shared;
- (void) reloadPlayers;
- (AVPlayerLayer *) addInView: (UIView *) superview isLockscreen: (bool) isLockscreen;
- (void) playHomescreen;
- (void) playLockscreen;
- (void) pauseLockscreen;
- (void) pauseHomescreen;
- (void) pauseSharedPlayer;
- (void) pause;
- (void) loadPreferences;
@end