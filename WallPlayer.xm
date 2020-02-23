#import "WallPlayer.h"
#import "Globals.h"
#import "AVPlayerLayer+Listen.h"

@implementation WallPlayer

    // Shared singleton.
    + (id) shared {
        static WallPlayer *shared = nil;
        static dispatch_once_t onceToken;
        dispatch_once_on_main_thread(&onceToken, ^{
            shared = [[self alloc] init];
        });
        return shared;
    }

    // Init.
    - (id) init {
        self = [super init];

        // get user defaults & set default values
        bundleDefaults = [[NSUserDefaults alloc] initWithSuiteName: @"com.Zerui.framepreferences"];
        [bundleDefaults registerDefaults: @{ @"mutedLockscreen" : @true, @"mutedHomescreen" : @true, @"pauseInApps" : @true }];

        // set allow mixing
        audioSession = [%c(AVAudioSession) sharedInstance];
        [audioSession setCategory: AVAudioSessionCategoryPlayback withOptions: AVAudioSessionCategoryOptionMixWithOthers error: nil];
        [audioSession setActive: YES withOptions: nil error: nil];

        // begin observing settings changes
        [bundleDefaults addObserver: self forKeyPath: @"mutedLockscreen" options: NSKeyValueObservingOptionNew context: nil];
        [bundleDefaults addObserver: self forKeyPath: @"mutedHomescreen" options: NSKeyValueObservingOptionNew context: nil];
        [bundleDefaults addObserver: self forKeyPath: @"pauseInApps" options: NSKeyValueObservingOptionNew context: nil];

        return self;
    }

    // Helper method that creates a looper-managed AVPlayer and returns the player.
    - (AVQueuePlayer *) createLoopedPlayerWithURL: (NSURL *) videoURL {
        // Init player, playerItem and looper.
        AVQueuePlayer *player = [[AVQueuePlayer alloc] init];
        AVPlayerItem *item = [AVPlayerItem playerItemWithURL: videoURL];
        AVPlayerLooper *looper = [AVPlayerLooper playerLooperWithPlayer: player templateItem: item];

        // Have the player retain the looper.
        objc_setAssociatedObject(player, _cmd, looper, OBJC_ASSOCIATION_RETAIN);

        return player;
    }

    // Retrieves and sets values from preferences.
    - (void) loadPreferences {
        // Load bools.
        self.pauseInApps = [bundleDefaults boolForKey: @"pauseInApps"];
        mutedLockscreen = [bundleDefaults boolForKey: @"mutedLockscreen"];
        mutedHomescreen = [bundleDefaults boolForKey: @"mutedHomescreen"];
        // Config players.
        [self reloadPlayers];
    }

    // Recreate the players from preferences.
    - (void) reloadPlayers {
        // Destroy all players.
        sharedPlayer = nil;
        lockscreenPlayer = nil;
        homescreenPlayer = nil;

        // Recreate players from preferences.
        NSURL *sharedVideoURL = [bundleDefaults URLForKey: @"videoURL"];
        if (sharedVideoURL != nil) {
            sharedPlayer = [self createLoopedPlayerWithURL: sharedVideoURL];
            [NSNotificationCenter.defaultCenter postNotificationName: @"PlayerChanged" object: nil userInfo: @{ @"screen" : kBothscreens, @"player" : sharedPlayer }];
        }
        else {
            NSURL *lockscreenVideoURL = [bundleDefaults URLForKey: @"videoURLLockscreen"];
            if (lockscreenVideoURL != nil) {
                lockscreenPlayer = [self createLoopedPlayerWithURL: lockscreenVideoURL];
                [NSNotificationCenter.defaultCenter postNotificationName: @"PlayerChanged" object: nil userInfo: @{ @"screen" : kLockscreen, @"player" : lockscreenPlayer }];
            }

            NSURL *homescreenVideoURL = [bundleDefaults URLForKey: @"videoURLHomescreen"];
            if (homescreenVideoURL != nil) {
                homescreenPlayer = [self createLoopedPlayerWithURL: lockscreenVideoURL];
                [NSNotificationCenter.defaultCenter postNotificationName: @"PlayerChanged" object: nil userInfo: @{ @"screen" : kHomescreen, @"player" : homescreenVideoURL }];
            }
        }
    }

    // Bundle defaults KVO.
    - (void) observeValueForKeyPath: (NSString *)keyPath ofObject: (id)object change: (NSDictionary *)change context: (void *)context {
        if ([keyPath isEqualToString: @"mutedLockscreen"]) {
            mutedLockscreen = lockscreenPlayer.muted = [[change valueForKey: NSKeyValueChangeNewKey] boolValue];
        }
        else if ([keyPath isEqualToString: @"mutedHomescreen"]) {
            mutedHomescreen = homescreenPlayer.muted = [[change valueForKey: NSKeyValueChangeNewKey] boolValue];
        }
        else if ([keyPath isEqualToString: @"pauseInApps"]) {
            self.pauseInApps = [[change valueForKey: NSKeyValueChangeNewKey] boolValue];
        }
    }

    // Add a playerLayer in the specified view's layer. Requires caller to specify whether the superview belongs to lockscreen.
    - (AVPlayerLayer *) addInView: (UIView *) superview isLockscreen: (bool) isLockscreen {
        
        // Determine which player to add.
        AVQueuePlayer *player = sharedPlayer != nil ? sharedPlayer : (isLockscreen ? lockscreenPlayer : sharedPlayer);
        
        // Setups...
        AVPlayerLayer *playerLayer = [AVPlayerLayer playerLayerWithPlayer: player];
        playerLayer.screen = isLockscreen ? kLockscreen : kHomescreen;
        playerLayer.hidden = player == nil;
        [playerLayer listenForPlayerChangedNotification];
        playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        [superview.layer addSublayer: playerLayer];
        playerLayer.frame = superview.bounds;

        // // Listen for SUE notifications if it's a lockscreen view.
        // if (isLockscreen) {
        //     __weak AVPlayerLayer *weakPlayerLayer = playerLayer;
        //     [NSNotificationCenter.defaultCenter addObserverForName: @"com.ZX02.Frame.SUE" object: nil queue: NSOperationQueue.mainQueue usingBlock: ^(NSNotification *notification) {
        //         if (weakPlayerLayer == nil)
        //             return;
        //         // Stagger to prevent SpringBoard from going above the memory bandwidth limit.
        //         dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t) 2.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        //             weakPlayerLayer.player = self.secUnitEnabled ? secPlayerUnit.player : priPlayerUnit.player;
        //         });
        //     }];
        // }

        return playerLayer;
    }
    
    // Play, prefers sharedPlayer.
    - (void) playLockscreen {
        if (sharedPlayer != nil) {
            sharedPlayer.muted = mutedLockscreen;
            [sharedPlayer play];
        }
        else
            [lockscreenPlayer play];
    }

    - (void) playHomescreen {
        if (sharedPlayer != nil){
            sharedPlayer.muted = mutedHomescreen;
            [sharedPlayer play];
        }
        else
            [homescreenPlayer play];
    }

    // Pause.
    - (void) pauseLockscreen {
        [lockscreenPlayer pause];
    }

    - (void) pauseHomescreen {
        [homescreenPlayer pause];
    }

    - (void) pauseSharedPlayer {
        [sharedPlayer pause];
    }

    // Pause all players.
    - (void) pause {
        [sharedPlayer pause];
        [lockscreenPlayer pause];
        [homescreenPlayer pause];
    }
@end