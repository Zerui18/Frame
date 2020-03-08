#import "SpringBoard.h"
#import "WallPlayer.h"
#import "Globals.h"
#import "AVPlayerLayer+Listen.h"

// Helper function to check if tweak should be active based on isEnabled and disableOnLPM.
bool isTweakEnabled(NSUserDefaults *bundleDefaults) {
    bool enabled = [bundleDefaults boolForKey: @"isEnabled"];
    if ([bundleDefaults boolForKey: @"disableOnLPM"]) {
        enabled = enabled && !NSProcessInfo.processInfo.isLowPowerModeEnabled;
    }
    return enabled;
}

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
        [bundleDefaults registerDefaults: @{ @"isEnabled" : @true, @"disableOnLPM" : @true, @"mutedLockscreen" : @false, @"mutedHomescreen" : @false, @"pauseInApps" : @true }];

        // set allow mixing
        audioSession = [%c(AVAudioSession) sharedInstance];
        [audioSession setCategory: AVAudioSessionCategoryPlayback withOptions: AVAudioSessionCategoryOptionMixWithOthers error: nil];
        [audioSession setActive: YES withOptions: nil error: nil];

        disableOnLPM = [bundleDefaults boolForKey: @"disableOnLPM"];
        mutedLockscreen = [bundleDefaults boolForKey: @"mutedLockscreen"];
        mutedHomescreen = [bundleDefaults boolForKey: @"mutedHomescreen"];
        self.pauseInApps = [bundleDefaults boolForKey: @"pauseInApps"];

        // begin observing settings changes
        [bundleDefaults addObserver: self forKeyPath: @"mutedLockscreen" options: NSKeyValueObservingOptionNew context: nil];
        [bundleDefaults addObserver: self forKeyPath: @"mutedHomescreen" options: NSKeyValueObservingOptionNew context: nil];
        [bundleDefaults addObserver: self forKeyPath: @"pauseInApps" options: NSKeyValueObservingOptionNew context: nil];
        [bundleDefaults addObserver: self forKeyPath: @"isEnabled" options: NSKeyValueObservingOptionNew context: nil];
        [bundleDefaults addObserver: self forKeyPath: @"disableOnLPM" options: NSKeyValueObservingOptionNew context: nil];

        self.enabled = isTweakEnabled(bundleDefaults);

        // listen for LPM notifications
        [NSNotificationCenter.defaultCenter addObserverForName: NSProcessInfoPowerStateDidChangeNotification object: nil
            queue: NSOperationQueue.mainQueue usingBlock: ^(NSNotification *notification) {
            if (!disableOnLPM)
                return;

            // update "enabled" based on lpm status
            self.enabled = isTweakEnabled(bundleDefaults);
        }];
    
        return self;
    }

    // Helper method that creates a looper-managed AVPlayer and returns the player.
    - (AVQueuePlayer *) createLoopedPlayerWithURL: (NSURL *) videoURL {
        // Init player, playerItem and looper.
        AVQueuePlayer *player = [[AVQueuePlayer alloc] init];
        if (@available(iOS 12, *))
            player.preventsDisplaySleepDuringVideoPlayback = false;
        AVPlayerItem *item = [AVPlayerItem playerItemWithURL: videoURL];
        AVPlayerLooper *looper = [AVPlayerLooper playerLooperWithPlayer: player templateItem: item];

        // Have the player retain the looper.
        objc_setAssociatedObject(player, _cmd, looper, OBJC_ASSOCIATION_RETAIN);

        return player;
    }

    // Recreate the players from preferences.
    // Does nothing if "enabled" is false.
    - (void) reloadPlayers {
        if (!self.enabled)
            return;
            
        // Destroy all players.
        [self destroyPlayers];

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
                lockscreenPlayer.muted = mutedLockscreen;
                [NSNotificationCenter.defaultCenter postNotificationName: @"PlayerChanged" object: nil userInfo: @{ @"screen" : kLockscreen, @"player" : lockscreenPlayer }];
            }

            NSURL *homescreenVideoURL = [bundleDefaults URLForKey: @"videoURLHomescreen"];
            if (homescreenVideoURL != nil) {
                homescreenPlayer = [self createLoopedPlayerWithURL: homescreenVideoURL];
                homescreenPlayer.muted = mutedHomescreen;
                [NSNotificationCenter.defaultCenter postNotificationName: @"PlayerChanged" object: nil userInfo: @{ @"screen" : kHomescreen, @"player" : homescreenPlayer }];
            }
        }

        // Play if possible.
        if (isOnLockscreen) {
            [self playLockscreen];
        }
        else if (!isInApp || !self.pauseInApps) {
            [self playHomescreen];
        }
    }

    // Destruct all players and clear playerLayers.
    - (void) destroyPlayers {

        [sharedPlayer removeAllItems];
        [lockscreenPlayer removeAllItems];
        [homescreenPlayer removeAllItems];

        sharedPlayer = nil;
        lockscreenPlayer = nil;
        homescreenPlayer = nil;

        [NSNotificationCenter.defaultCenter postNotificationName: @"PlayerChanged" object: nil userInfo: @{ @"screen" : kBothscreens }];
    }

    // Bundle defaults KVO.
    - (void) observeValueForKeyPath: (NSString *)keyPath ofObject: (id)object change: (NSDictionary *)change context: (void *)context {
        if ([keyPath isEqualToString: @"isEnabled"]) {
            self.enabled = isTweakEnabled(bundleDefaults);
        }
        else if ([keyPath isEqualToString: @"disableOnLPM"]) {
            disableOnLPM = [[change valueForKey: NSKeyValueChangeNewKey] boolValue];
            self.enabled = isTweakEnabled(bundleDefaults);
        }
        else if ([keyPath isEqualToString: @"mutedLockscreen"]) {
            mutedLockscreen = lockscreenPlayer.muted = [[change valueForKey: NSKeyValueChangeNewKey] boolValue];
        }
        else if ([keyPath isEqualToString: @"mutedHomescreen"]) {
            mutedHomescreen = homescreenPlayer.muted = [[change valueForKey: NSKeyValueChangeNewKey] boolValue];
        }
        else if ([keyPath isEqualToString: @"pauseInApps"]) {
            self.pauseInApps = [[change valueForKey: NSKeyValueChangeNewKey] boolValue];
        }
    }

    // Setter for pauseInApps.
    - (void) setPauseInApps: (bool) flag {
        _pauseInApps = flag;

        // Update players' states accordingly.
        if (flag && isInApp)
            [self pause];
        else if (!flag && isInApp)
            [self playHomescreen];
    }

    // Setter for enabled
    - (void) setEnabled: (bool) flag {
        if (flag == _enabled)
            return;

        _enabled = flag;
        if (_enabled)
            [self reloadPlayers];
        else
            [self destroyPlayers];

    }

    // MARK: Public API

    // Add a playerLayer in the specified view's layer. Requires caller to specify whether the superview belongs to lockscreen.
    - (AVPlayerLayer *) addInView: (SBFWallpaperView *) superview isLockscreen: (bool) isLockscreen {
        
        // Determine which player to add.
        // Always choose sharedPlayer if available, otherwise get the appropriate player.
        AVQueuePlayer *player = sharedPlayer != nil ? sharedPlayer : (isLockscreen ? lockscreenPlayer : homescreenPlayer);
        
        // Setups...
        AVPlayerLayer *playerLayer = [AVPlayerLayer playerLayerWithPlayer: player];
        playerLayer.screen = isLockscreen ? kLockscreen : kHomescreen;
        [playerLayer setValue: superview.contentView forKey: @"originalWPView"];
        playerLayer.hidden = player == nil;
        superview.contentView.hidden = player != nil;
        [playerLayer listenForPlayerChangedNotification];
        playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        [superview.layer addSublayer: playerLayer];
        playerLayer.frame = superview.bounds;

        return playerLayer;
    }
    
    // Play, prefers sharedPlayer and checks if isAsleep.
    - (void) playLockscreen {
        if (isAsleep)
            return;

        // Update muted property if sharedPlayer is being used.
        if (sharedPlayer != nil) {
            sharedPlayer.muted = mutedLockscreen;
            [sharedPlayer play];
        }
        else
            [lockscreenPlayer play];
    }

    - (void) playHomescreen {
        if (isAsleep)
            return;
        
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

    - (bool) requiresDifferentSystemWallpapers {
        return lockscreenPlayer != nil || homescreenPlayer != nil;
    }
@end