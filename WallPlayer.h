#import "WallPlayerSubunit.h"

// Logical container for the AVQueuePlayer used in this tweak.
// Manages a single instance of AVQueuePlayer that's controlled by the AVPlayerLooper.
// Adds AVPlayerLayer to the provided views.

@interface WallPlayer : NSObject {
    NSUserDefaults *bundleDefaults;
    AVAudioSession *audioSession;
    WallPlayerSubunit *priPlayerUnit;
    WallPlayerSubunit *secPlayerUnit;
}

@property bool secUnitEnabled;
@property bool pauseInApps;
@property(setter=setEnabledScreens:, nonatomic) NSString *enabledScreens;

+ (id) shared;
- (AVPlayerLayer *) addInView: (UIView *) superview isLockscreen: (bool) isLockscreen;
- (void) setEnabledScreens: (NSString *) option;
- (void) playForScreen: (NSString *) screen;
- (void) secUnitEnabled: (bool) enabled;
- (void) pausePriUnitIfNeeded;
- (void) pauseSecUnit;
- (void) pause;
- (void) loadPreferences;
- (void) videoChangedCallback: (bool) isPrimary;
@end