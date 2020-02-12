#import <AVFoundation/AVFoundation.h>
#import "Globals.h"

@class WallPlayer;

// Small helper class that wraps the logic for controlling a looped player.
@interface WallPlayerSubunit : NSObject {
    bool isPlaying;
    bool isPrimaryUnit;
    __weak NSObject *parentPlayer;
}

@property bool *secUnitEnabled;
@property(setter=setVideoURL:, nonatomic) NSURL *videoURL;
@property AVQueuePlayer *player;
@property(setter=setLooper:, nonatomic) AVPlayerLooper *looper;
@property(getter=getMuted, setter=setMuted:, nonatomic) BOOL muted;
@property(setter=setPauseInApps:, nonatomic) BOOL pauseInApps;

- (id) initWithParent: (NSObject *) parent isPrimaryUnit: (bool) isPrimaryUnit;
- (void) play;
- (void) pause;
@end

#import "WallPlayer.h"