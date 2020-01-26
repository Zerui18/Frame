#include "WallPlayer.h"
#include "Globals.h"

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
        // get bundle defaults
        bundleDefaults = [[NSUserDefaults alloc] initWithSuiteName: @"com.Zerui.framepreferences"];
        // init player
        self.player = [[AVQueuePlayer alloc] init];
        if (@available(iOS 12.0, *)) {
            self.player.preventsDisplaySleepDuringVideoPlayback = NO;
        }
        // set allow mixing
        audioSession = [%c(AVAudioSession) sharedInstance];
        [audioSession setCategory: AVAudioSessionCategoryPlayback withOptions: AVAudioSessionCategoryOptionMixWithOthers error: nil];
        [audioSession setActive: YES withOptions: nil error: nil];
        // begin observing settings changes
        [bundleDefaults addObserver: self forKeyPath: @"videoURL" options: NSKeyValueObservingOptionNew context: nil];
        [bundleDefaults addObserver: self forKeyPath: @"isMute" options: NSKeyValueObservingOptionNew context: nil];
        [bundleDefaults addObserver: self forKeyPath: @"pauseInApps" options: NSKeyValueObservingOptionNew context: nil];
        [bundleDefaults addObserver: self forKeyPath: @"enabledScreens" options: NSKeyValueObservingOptionNew context: nil];

        return self;
    }

    // Retrieves and sets values from preferences.
    - (void) loadPreferences {
        NSArray<NSString *> *defaultsKeys = [bundleDefaults dictionaryRepresentation].allKeys;
        self.videoURL = [bundleDefaults URLForKey: @"videoURL"];
        if ([defaultsKeys containsObject: @"isMute"])
            self.player.muted = [bundleDefaults boolForKey: @"isMute"];
        else
            self.player.muted = YES;
        if ([defaultsKeys containsObject: @"pauseInApps"])
            self.pauseInApps = [bundleDefaults boolForKey: @"pauseInApps"];
        else 
            self.pauseInApps = YES;
        if ([defaultsKeys containsObject: @"enabledScreens"])
            self.enabledScreens = [bundleDefaults stringForKey: @"enabledScreens"];
        else
            self.enabledScreens = @"both";
    }

    // Bundle defaults KVO.
    - (void) observeValueForKeyPath: (NSString *)keyPath ofObject: (id)object change: (NSDictionary *)change context: (void *)context {
        if ([keyPath isEqualToString: @"videoURL"]) {
            // Getting the changed value as string and URLWithPath does not seem to work.
            NSURL *newURL = [bundleDefaults URLForKey: @"videoURL"];
            if (newURL == nil)
                return;
            // Check if the newURL is a child of SpringBoard's doc URL -> alr copied.
            if ([newURL.URLByStandardizingPath.URLByResolvingSymlinksInPath.path hasPrefix: @"/var/mobile/Documents/com.ZX02.Frame/"]) {
                self.videoURL = newURL;
                return; // Already saved.
            }
            NSURL *permanentURL = [self getPermanentVideoURL: newURL];
            if (permanentURL != nil) {
                [bundleDefaults setURL: permanentURL forKey: @"videoURL"];
            }
        }
        else if ([keyPath isEqualToString: @"isMute"]) {
            BOOL newFlag = [[change valueForKey: NSKeyValueChangeNewKey] boolValue];
            self.player.muted = newFlag;
        }
        else if ([keyPath isEqualToString: @"pauseInApps"]) {
            BOOL newFlag = [[change valueForKey: NSKeyValueChangeNewKey] boolValue];
            self.pauseInApps = newFlag;
        }
        else if ([keyPath isEqualToString: @"enabledScreens"]) {
            NSString *option = (NSString *) [change valueForKey: NSKeyValueChangeNewKey];
            self.enabledScreens = option;
        }
    }

    // Moves the file to a permanent URL of the same extension and return it. Returns nil if move failed.
    - (NSURL *) getPermanentVideoURL: (NSURL *) srcURL {
        NSArray *paths = [[NSFileManager defaultManager] URLsForDirectory: NSDocumentDirectory inDomains: NSUserDomainMask];
        NSURL *documentsURL = paths[0];

        NSURL *frameFolder = [documentsURL URLByAppendingPathComponent: @"com.ZX02.Frame"];

        // Remove folder if exists.
        if ([NSFileManager.defaultManager fileExistsAtPath: frameFolder.path isDirectory: nil])
            [NSFileManager.defaultManager removeItemAtURL: frameFolder error: nil];

        // Create frame's folder.
        if (![NSFileManager.defaultManager createDirectoryAtPath: frameFolder.path withIntermediateDirectories: YES attributes: nil error: nil])
            return nil;
        
        // Get the extension of the original file.
        NSString *ext = srcURL.pathExtension.lowercaseString;
        
        NSURL *newURL = [frameFolder URLByAppendingPathComponent: [NSString stringWithFormat: @"wallpaper.%@", ext]];

        // Attempt to copy the tmp item to a permanent url.
        NSError *err;
        if ([NSFileManager.defaultManager copyItemAtPath: srcURL.path toPath: newURL.path error: &err]) {
            return newURL;
        }
        NSLog(@"failed to copy wallpaper: %@", err);
        return nil;
    }

    // Custom enabledScreens setter.
    - (void) setEnabledScreens: (NSString *) option {
        _enabledScreens = option;
        [NSNotificationCenter.defaultCenter postNotificationName: @"com.ZX02.Frame.PVC" object: nil userInfo: nil];
    }

    // Custom videoURL setter.
    - (void) setVideoURL: (NSURL *) url {
        _videoURL = url;
        [self loadVideo];
    }

    // Setup the player with the current videoURL.
    - (void) loadVideo {
        if (self.videoURL == nil)
            return;
        dispatch_async(dispatch_get_main_queue(), ^{
            self.playerItem = [AVPlayerItem playerItemWithURL: self.videoURL];
            self.looper = [AVPlayerLooper playerLooperWithPlayer: self.player templateItem: self.playerItem];
            [self play];
        });
    }

    // Add a playerLayer in the specified view's layer.
    - (AVPlayerLayer *) addInView: (UIView *)superview {
        AVPlayerLayer *playerLayer = [AVPlayerLayer playerLayerWithPlayer: self.player];
        playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        [superview.layer addSublayer: playerLayer];
        playerLayer.frame = superview.bounds;
        return playerLayer;
    }

    // Setter for pauseInApps.
    - (void) setPauseInApps: (BOOL) flag {
        _pauseInApps = flag;
        // Only care if there's a fully initialized player & an app is opened.
        if (self.looper != nil && isInApp) {
            if (flag)
                [self pause];
            else
                [self play];
        }
    }
    
    // Play.
    - (void) play {
        // Note: This does not restart the AVAudioSession, or so it appears
        // After siri dismisses, non-mute player does not have sound.
        [self.player play];
        NSLog(@"play");
    }
    
    // Pause.
    - (void) pause {
        // Global override point for pauseInApps.
        if (!self.pauseInApps && isInApp) {
            return;
        }
        [self.player pause];
        NSLog(@"pause");
    }
@end