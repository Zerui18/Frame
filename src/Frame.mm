#import <objc/runtime.h>
#import "Frame.h"
#import "SpringBoard.h"
#import "DeviceStates.h"
#import "Globals.h"
#import "Utils.h"
#import "AVPlayerLayer+Listen.h"

void cancelCountdown(); // cancel home screen fade countdown (see Tweak.xm)
#define KVC_OBSERVE(keyPath) [bundleDefaults addObserver: self forKeyPath: keyPath options: NSKeyValueObservingOptionNew context: nil]
#define POST_PLAYER_CHANGED(dict) [NSNotificationCenter.defaultCenter postNotificationName: @"PlayerChanged" object: nil userInfo: dict]

@implementation Frame

    // Shared singleton.
    + (Frame *) shared {
        static Frame *shared = nil;
        static dispatch_once_t onceToken;
        dispatch_once_on_main_thread(&onceToken, ^{
            shared = [[Frame alloc] init];
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
                                            @"fadeEnabled" : @false,
                                            @"fadeAlpha" : @0.05,
                                            @"fadeInactivity" : @4.0
                                            }];

        // set allow mixing
        audioSession = [AVAudioSession sharedInstance];
        [audioSession setCategory: AVAudioSessionCategoryPlayback withOptions: AVAudioSessionCategoryOptionMixWithOthers error: nil];
        [audioSession addObserver: self forKeyPath: @"outputVolume" options: NSKeyValueObservingOptionNew context: nil];

        disableOnLPM = [bundleDefaults boolForKey: @"disableOnLPM"];
        mutedLockscreen = [bundleDefaults boolForKey: @"mutedLockscreen"];
        mutedHomescreen = [bundleDefaults boolForKey: @"mutedHomescreen"];
        self.pauseInApps = [bundleDefaults boolForKey: @"pauseInApps"];
        syncRingerVolume = [bundleDefaults boolForKey: @"syncRingerVolume"];
        self.fadeEnabled = [bundleDefaults boolForKey: @"fadeEnabled"];
        self.fadeAlpha = [bundleDefaults floatForKey: @"fadeAlpha"];
        self.fadeInactivity = [bundleDefaults floatForKey: @"fadeInactivity"];

        // begin observing settings changes
        KVC_OBSERVE(@"isEnabled");
        KVC_OBSERVE(@"disableOnLPM");
        KVC_OBSERVE(@"mutedLockscreen");
        KVC_OBSERVE(@"mutedHomescreen");
        KVC_OBSERVE(@"pauseInApps");
        KVC_OBSERVE(@"syncRingerVolume");
        KVC_OBSERVE(@"fadeEnabled");
        KVC_OBSERVE(@"fadeAlpha");
        KVC_OBSERVE(@"fadeInactivity");

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
        AVPlayerItem *item = [AVPlayerItem playerItemWithURL: videoURL];
        AVPlayerLooper *looper = [AVPlayerLooper playerLooperWithPlayer: player templateItem: item];
        // Prevent airplay.
        player.allowsExternalPlayback = false;
        // Allow sleep.
        if (@available(iOS 12, *))
            player.preventsDisplaySleepDuringVideoPlayback = false;
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
            POST_PLAYER_CHANGED((@{ @"screen" : kBothscreens, @"player" : sharedPlayer }));
        }
        else {
            NSURL *lockscreenVideoURL = [bundleDefaults URLForKey: @"videoURLLockscreen"];
            if (lockscreenVideoURL != nil) {
                lockscreenPlayer = [self createLoopedPlayerWithURL: lockscreenVideoURL];
                lockscreenPlayer.muted = mutedLockscreen;
                POST_PLAYER_CHANGED((@{ @"screen" : kLockscreen, @"player" : lockscreenPlayer }));
            }

            NSURL *homescreenVideoURL = [bundleDefaults URLForKey: @"videoURLHomescreen"];
            if (homescreenVideoURL != nil) {
                homescreenPlayer = [self createLoopedPlayerWithURL: homescreenVideoURL];
                homescreenPlayer.muted = mutedHomescreen;
                POST_PLAYER_CHANGED((@{ @"screen" : kHomescreen, @"player" : homescreenPlayer }));
            }
        }

        // Play if possible.
        if (IS_ON_LOCKSCREEN) {
            [self playLockscreen];
        }
        else if (!IS_IN_APP || !self.pauseInApps) {
            [self playHomescreen];
        }
    }

    // Destruct all players and clear playerLayers.
    - (void) destroyPlayers {
        sharedPlayer = nil;
        lockscreenPlayer = nil;
        homescreenPlayer = nil;

        POST_PLAYER_CHANGED((@{ @"screen" : kBothscreens }));
    }

    #define IF_KEYPATH(str, expr) if ([keyPath isEqualToString: str]) { expr }
    #define ELIF_KEYPATH(str, expr) else if ([keyPath isEqualToString: str]) { expr }
    // Bundle defaults KVO.
    - (void) observeValueForKeyPath: (NSString *)keyPath ofObject: (id)object change: (NSDictionary *)change context: (void *)context {
        // Save boilerplate code below.
        bool changeInBool = [[change valueForKey: NSKeyValueChangeNewKey] boolValue];

        IF_KEYPATH(@"isEnabled", self.enabled = self.isTweakEnabled; self.enabled = self.isTweakEnabled;)

        ELIF_KEYPATH(@"disableOnLPM", disableOnLPM = changeInBool;)

        ELIF_KEYPATH(@"mutedLockscreen", mutedLockscreen = lockscreenPlayer.muted = changeInBool;)

        ELIF_KEYPATH(@"mutedHomescreen", mutedHomescreen = homescreenPlayer.muted = changeInBool;)

        ELIF_KEYPATH(@"pauseInApps", self.pauseInApps = changeInBool;)

        ELIF_KEYPATH(@"syncRingerVolume", 
            syncRingerVolume = changeInBool;
            if (syncRingerVolume && self.isTweakEnabled) {
                setRingerVolume(audioSession.outputVolume);
            }
        )

        ELIF_KEYPATH(@"outputVolume", 
            if (syncRingerVolume && self.isTweakEnabled) {
                float newVolume = [[change valueForKey: NSKeyValueChangeNewKey] floatValue];
                setRingerVolume(newVolume);
            }
        )

        ELIF_KEYPATH(@"fadeEnabled", self.fadeEnabled = changeInBool;)

        ELIF_KEYPATH(@"fadeAlpha", self.fadeAlpha = [[change valueForKey: NSKeyValueChangeNewKey] floatValue];)

        ELIF_KEYPATH(@"fadeInactivity", self.fadeInactivity = [[change valueForKey: NSKeyValueChangeNewKey] floatValue];)
    }

    // Setter for pauseInApps.
    - (void) setPauseInApps: (bool) flag {
        _pauseInApps = flag;

        // Update players' states accordingly.
        if (flag && IS_IN_APP)
            [self pause];
        else if (!flag && IS_IN_APP)
            [self playHomescreen];
    }

    // Setter for enabled.
    - (void) setEnabled: (bool) flag {
        if (flag == _enabled)
            return;

        _enabled = flag;
        if (_enabled)
            [self reloadPlayers];
        else {
            [self destroyPlayers];
            cancelCountdown();
        }
    }

    // MARK: Public API

    // Add a playerLayer in the specified view's layer. Requires caller to specify whether the superview belongs to lockscreen.
    - (AVPlayerLayer *) addInView: (SBFWallpaperView *) superview isLockscreen: (bool) isLockscreen {
        
        // Determine which player to add.
        // Always choose sharedPlayer if available, otherwise get the appropriate player.
        AVPlayer *player = sharedPlayer != nil ? sharedPlayer : (isLockscreen ? lockscreenPlayer : homescreenPlayer);
        
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
    
    - (void) playLockscreen {
        // Update muted property if sharedPlayer is being used.
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

    - (void) forcePlayHomescreen {
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