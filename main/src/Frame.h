#import <AVFoundation/AVFoundation.h>

// Logical container for the AVQueuePlayer used in this tweak.
// Manages a single instance of AVQueuePlayer that's controlled by the AVPlayerLooper.
// Adds AVPlayerLayer to the provided views.

@interface Frame : NSObject {
    NSUserDefaults *bundleDefaults;
    AVAudioSession *audioSession;

    AVQueuePlayer *sharedPlayer;
    AVQueuePlayer *lockscreenPlayer;
    AVQueuePlayer *homescreenPlayer;

    bool mutedLockscreen;
    bool mutedHomescreen;
    bool syncRingerVolume;
    bool disableOnLPM;
}

@property(setter=setPauseInApps:, nonatomic) bool pauseInApps;
@property(setter=setEnabled:, nonatomic) bool enabled;

+ (id) shared;
- (bool) isTweakEnabled;
- (void) reloadPlayers;
- (AVPlayerLayer *) addInView: (SBFWallpaperView *) superview isLockscreen: (bool) isLockscreen;
- (void) playHomescreen;
- (void) playLockscreen;
- (void) pauseLockscreen;
- (void) pauseHomescreen;
- (void) pauseSharedPlayer;
- (void) pause;
- (bool) requiresDifferentSystemWallpapers;

@end