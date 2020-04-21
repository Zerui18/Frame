#import "SpringBoard.h"
#import "Frame.h"
#import "Globals.h"
#import "Utils.h"
#import "AVPlayerLayer+Listen.h"

@implementation Frame

    // Shared singleton.
    + (id) shared {
        static Frame *shared = nil;
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
        [bundleDefaults registerDefaults: @{ @"isEnabled" : @true,
                                            @"disableOnLPM" : @true,
                                            @"mutedLockscreen" : @true,
                                            @"mutedHomescreen" : @true,
                                            @"pauseInApps" : @true,
                                            @"syncRingerVolume" : @true,
                                            }];

        // set allow mixing
        audioSession = [%c(AVAudioSession) sharedInstance];
        [audioSession setCategory: AVAudioSessionCategoryPlayback withOptions: AVAudioSessionCategoryOptionMixWithOthers error: nil];
        [audioSession addObserver: self forKeyPath: @"outputVolume" options: NSKeyValueObservingOptionNew context: nil];

        disableOnLPM = [bundleDefaults boolForKey: @"disableOnLPM"];
        mutedLockscreen = [bundleDefaults boolForKey: @"mutedLockscreen"];
        mutedHomescreen = [bundleDefaults boolForKey: @"mutedHomescreen"];
        self.pauseInApps = [bundleDefaults boolForKey: @"pauseInApps"];
        syncRingerVolume = [bundleDefaults boolForKey: @"syncRingerVolume"];

        // begin observing settings changes
        [bundleDefaults addObserver: self forKeyPath: @"isEnabled" options: NSKeyValueObservingOptionNew context: nil];
        [bundleDefaults addObserver: self forKeyPath: @"disableOnLPM" options: NSKeyValueObservingOptionNew context: nil];
        [bundleDefaults addObserver: self forKeyPath: @"mutedLockscreen" options: NSKeyValueObservingOptionNew context: nil];
        [bundleDefaults addObserver: self forKeyPath: @"mutedHomescreen" options: NSKeyValueObservingOptionNew context: nil];
        [bundleDefaults addObserver: self forKeyPath: @"pauseInApps" options: NSKeyValueObservingOptionNew context: nil];
        [bundleDefaults addObserver: self forKeyPath: @"syncRingerVolume" options: NSKeyValueObservingOptionNew context: nil];

        // Set enabled after initializing all other properties.
        self.enabled = self.isTweakEnabled;

        // listen for LPM notifications
        [NSNotificationCenter.defaultCenter addObserverForName: NSProcessInfoPowerStateDidChangeNotification object: nil
            queue: NSOperationQueue.mainQueue usingBlock: ^(NSNotification *notification) {
            if (!disableOnLPM)
                return;

            // update "enabled" based on lpm status
            self.enabled = self.isTweakEnabled;
        }];
    
        return self;
    }

    // Helper function to check if tweak should be active based on isEnabled and disableOnLPM.
    - (bool) isTweakEnabled {
        bool enabled = [bundleDefaults boolForKey: @"isEnabled"];
        if ([bundleDefaults boolForKey: @"disableOnLPM"]) {
            enabled = enabled && !NSProcessInfo.processInfo.isLowPowerModeEnabled;
        }
        return enabled;
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
        // Save boilerplate code below.
        bool changeInBool = [[change valueForKey: NSKeyValueChangeNewKey] boolValue];
        if ([keyPath isEqualToString: @"isEnabled"]) {
            self.enabled = self.isTweakEnabled;
        }
        else if ([keyPath isEqualToString: @"disableOnLPM"]) {
            disableOnLPM = changeInBool;
            self.enabled = self.isTweakEnabled;
        }
        else if ([keyPath isEqualToString: @"mutedLockscreen"]) {
            mutedLockscreen = lockscreenPlayer.muted = changeInBool;
        }
        else if ([keyPath isEqualToString: @"mutedHomescreen"]) {
            mutedHomescreen = homescreenPlayer.muted = changeInBool;
        }
        else if ([keyPath isEqualToString: @"pauseInApps"]) {
            self.pauseInApps = changeInBool;
        }
        else if ([keyPath isEqualToString: @"syncRingerVolume"]) {
            syncRingerVolume = changeInBool;
            if (syncRingerVolume && self.isTweakEnabled) {
                setRingerVolume(audioSession.outputVolume);
            }
        }
        // System Volume Changed.
        else if ([keyPath isEqualToString: @"outputVolume"]) {
            if (syncRingerVolume && self.isTweakEnabled) {
                float newVolume = [[change valueForKey: NSKeyValueChangeNewKey] floatValue];
                setRingerVolume(newVolume);
            }
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

    // Setter for enabled.
    - (void) setEnabled: (bool) flag {
        if (flag == _enabled)
            return;

        _enabled = flag;
        if (_enabled)
            [self reloadPlayers];
        else
            [self destroyPlayers];
        
        // Only activate the audioSession when the tweak is enabled.
        // Thus, when the tweak is disabled the user can normally control the ringer volume.
        [audioSession setActive: _enabled withOptions: nil error: nil];
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

    // Bool indicating whether the current configuration will require separate system wallpapers to be set.
    - (bool) requiresDifferentSystemWallpapers {
        return lockscreenPlayer != nil || homescreenPlayer != nil;
    }
@end