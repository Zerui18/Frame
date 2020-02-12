#import "WallPlayerSubunit.h"

@implementation WallPlayerSubunit

    - (id) initWithParent: (WallPlayer *) parent isPrimaryUnit: (bool) flag {
        self = [super init];

        isPrimaryUnit = flag;
        parentPlayer = parent;

        // Init properties.
        isPlaying = false;
        self.player = [[AVQueuePlayer alloc] init];

        // iOS 12 + fix to prevent always-awake behaviour.
        if (@available(iOS 12.0, *)) {
            self.player.preventsDisplaySleepDuringVideoPlayback = NO;
        }

        return self;
    }

    // Custom videoURL setter.
    - (void) setVideoURL: (NSURL *) url {
        _videoURL = url;
        
        if (_videoURL == nil) {
          // remove looper & clear queue player
          self.looper = nil;
          [self.player removeAllItems];
          return;
        }

        // Else configure player & looper
        AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL: _videoURL];
        self.looper = [AVPlayerLooper playerLooperWithPlayer: self.player templateItem: playerItem];
    }

    // Custom setter to update enabled property when looper is set.
    - (void) setLooper: (AVPlayerLooper *) looper {
      _looper = looper;
      
      if (!isPrimaryUnit)
        [(WallPlayer *) parentPlayer secUnitEnabled: looper != nil];
    }

    // Setter for pauseInApps.
    - (void) setPauseInApps: (BOOL) flag {
        _pauseInApps = flag;

        // Don't do anything if we're in secondary unit.
        if (!isPrimaryUnit)
            return;

        // Only care if there's a fully initialized player & an app is opened.
        if (self.looper != nil && isInApp) {
            if (flag)
                [self pause];
            else
                [self play];
        }
    }

    // Getter & setter for muted.
    - (bool) getMuted {
        return self.player.muted;
    }

    - (void) setMuted: (bool) muted {
        self.player.muted = muted;
    }

    // Msg the internal player to play.
    - (void) play {
        if (isPlaying)
            return;

        [self.player play];
        isPlaying = true;
    }

    // Msg the internal player to pause.
    - (void) pause {
        if (!isPlaying)
            return;

        [self.player pause];
        isPlaying = false;
    }

@end