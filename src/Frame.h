#import <AVFoundation/AVFoundation.h>
#import "SpringBoard.h"

// Logical container for the AVPlayer used in this tweak.
// Manages a single instance of AVPlayer that's controlled by the AVPlayerLooper.
// Adds AVPlayerLayer to the provided views.

#define FRAME [Frame shared]

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
    bool hideHomescreen;
}

@property bool fadeEnabled;
@property float fadeAlpha;
@property float fadeInactivity;
@property(setter=setPauseInApps:, nonatomic) bool pauseInApps;
@property(setter=setEnabled:, nonatomic) bool enabled;
@property bool fixBlur;

+ (Frame *) shared;
- (instancetype) init;
- (bool) isTweakEnabled;
- (void) destroyPlayers;
- (void) reloadPlayers;
- (AVPlayerLayer *) addInView: (SBFWallpaperView *) superview isLockscreen: (bool) isLockscreen;
- (void) playHomescreen;
- (void) forcePlayHomescreen;
- (void) playLockscreen;
- (void) pauseLockscreen;
- (void) pauseHomescreen;
- (void) pauseSharedPlayer;
- (void) pause;
- (bool) requiresDifferentSystemWallpapers;

@end