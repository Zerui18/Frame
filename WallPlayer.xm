#import "WallPlayer.h"
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

        // init player units
        // only providing the secondary unit with parent so it updates the secUnitEnabled method
        priPlayerUnit = [[WallPlayerSubunit alloc] initWithParent: self isPrimaryUnit: true];
        secPlayerUnit = [[WallPlayerSubunit alloc] initWithParent: self isPrimaryUnit: false];

        // set allow mixing
        audioSession = [%c(AVAudioSession) sharedInstance];
        [audioSession setCategory: AVAudioSessionCategoryPlayback withOptions: AVAudioSessionCategoryOptionMixWithOthers error: nil];
        [audioSession setActive: YES withOptions: nil error: nil];

        // begin observing settings changes
        [bundleDefaults addObserver: self forKeyPath: @"videoURL" options: NSKeyValueObservingOptionNew context: nil];
        [bundleDefaults addObserver: self forKeyPath: @"secVideoURL" options: NSKeyValueObservingOptionNew context: nil];
        [bundleDefaults addObserver: self forKeyPath: @"enabledScreens" options: NSKeyValueObservingOptionNew context: nil];
        [bundleDefaults addObserver: self forKeyPath: @"isMute" options: NSKeyValueObservingOptionNew context: nil];
        [bundleDefaults addObserver: self forKeyPath: @"pauseInApps" options: NSKeyValueObservingOptionNew context: nil];

        return self;
    }

    // Retrieves and sets values from preferences.
    - (void) loadPreferences {
        NSArray<NSString *> *defaultsKeys = [bundleDefaults dictionaryRepresentation].allKeys;
        priPlayerUnit.videoURL = [bundleDefaults URLForKey: @"videoURL"];
        secPlayerUnit.videoURL = [bundleDefaults URLForKey: @"secVideoURL"];
        if ([defaultsKeys containsObject: @"isMute"])
            priPlayerUnit.muted = secPlayerUnit.muted = [bundleDefaults boolForKey: @"isMute"];
        else
            priPlayerUnit.muted = secPlayerUnit.muted = true;
        if ([defaultsKeys containsObject: @"pauseInApps"])
            self.pauseInApps = priPlayerUnit.pauseInApps = secPlayerUnit.pauseInApps = [bundleDefaults boolForKey: @"pauseInApps"];
        else 
            self.pauseInApps = priPlayerUnit.pauseInApps = secPlayerUnit.pauseInApps = true;
        if ([defaultsKeys containsObject: @"enabledScreens"])
            self.enabledScreens = [bundleDefaults stringForKey: @"enabledScreens"];
        else
            self.enabledScreens = @"both";
    }

    // Bundle defaults KVO.
    - (void) observeValueForKeyPath: (NSString *)keyPath ofObject: (id)object change: (NSDictionary *)change context: (void *)context {
        if ([keyPath hasPrefix: @"videoURL"]) {

            // Determine which unit this URL is meant for.
            bool isPriVideo = [keyPath isEqualToString: @"videoURL"];
            WallPlayerSubunit *playerUnit = isPriVideo ? priPlayerUnit : secPlayerUnit;

            // Getting the changed value as string and URLWithPath does not seem to work.
            NSURL *newURL = [bundleDefaults URLForKey: @"videoURL"];
            if (newURL == nil) {
                playerUnit.videoURL = nil;
                return;
            }

            // Check if the newURL is a child of SpringBoard's doc URL -> alr copied.
            if ([newURL.URLByStandardizingPath.URLByResolvingSymlinksInPath.path hasPrefix: @"/var/mobile/Documents/com.ZX02.Frame/"]) {
                playerUnit.videoURL = newURL;
                return; // Already saved.
            }

            // Otherwise copy the file to a permanent path and overwrite the preference.
            NSURL *permanentURL = [self getPermanentVideoURL: newURL isSecondary: !isPriVideo];
            if (permanentURL != nil) {
                [bundleDefaults setURL: permanentURL forKey: keyPath];
            }
        }
        else if ([keyPath isEqualToString: @"enabledScreens"]) {
            NSString *option = (NSString *) [change valueForKey: NSKeyValueChangeNewKey];
            self.enabledScreens = option;
        }
        else if ([keyPath isEqualToString: @"isMute"]) {
            BOOL newFlag = [[change valueForKey: NSKeyValueChangeNewKey] boolValue];
            priPlayerUnit.muted = secPlayerUnit.muted = newFlag;
        }
        else if ([keyPath isEqualToString: @"pauseInApps"]) {
            BOOL newFlag = [[change valueForKey: NSKeyValueChangeNewKey] boolValue];
            self.pauseInApps = priPlayerUnit.pauseInApps = secPlayerUnit.pauseInApps = newFlag;
        }
    }

    // Moves the file to a permanent URL of the same extension and return it. Returns nil if move failed.
    - (NSURL *) getPermanentVideoURL: (NSURL *) srcURL isSecondary: (bool) secondary {
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
        
        NSURL *newURL = [frameFolder URLByAppendingPathComponent: [NSString stringWithFormat: @"wallpaper%@.%@", secondary ? @".sec":@"", ext]];

        // Attempt to copy the tmp item to a permanent url.
        NSError *err;
        if ([NSFileManager.defaultManager copyItemAtPath: srcURL.path toPath: newURL.path error: &err]) {
            return newURL;
        }
        return nil;
    }

    // Custom enabledScreens setter.
    - (void) setEnabledScreens: (NSString *) option {
        _enabledScreens = option;
        [NSNotificationCenter.defaultCenter postNotificationName: @"com.ZX02.Frame.PVC" object: nil userInfo: nil];
    }

    // Add a playerLayer in the specified view's layer. Requires caller to specify whether the superview belongs to lockscreen.
    - (AVPlayerLayer *) addInView: (UIView *) superview isLockscreen: (bool) isLockscreen {
        
        // Determine which player to add.
        AVQueuePlayer *player = (isLockscreen && secPlayerUnit.looper != nil) ? secPlayerUnit.player : priPlayerUnit.player;
        
        // Setups...
        AVPlayerLayer *playerLayer = [AVPlayerLayer playerLayerWithPlayer: player];
        playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        [superview.layer addSublayer: playerLayer];
        playerLayer.frame = superview.bounds;

        __weak AVPlayerLayer *weakPlayerLayer = playerLayer;

        [NSNotificationCenter.defaultCenter addObserverForName: @"com.ZX02.Frame.SUE" object: nil queue: NSOperationQueue.mainQueue usingBlock: ^(NSNotification *notification) {
            if (weakPlayerLayer == nil)
                return;
            // Stagger to prevent SpringBoard from going above the memory bandwidth limit.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t) 2.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                weakPlayerLayer.player = self.secUnitEnabled ? secPlayerUnit.player : priPlayerUnit.player;
            });
        }];

        return playerLayer;
    }

    - (void) secUnitEnabled: (bool) enabled {
        self.secUnitEnabled = enabled;
        [NSNotificationCenter.defaultCenter postNotificationName: @"com.ZX02.Frame.SUE" object: nil userInfo: nil];
    }
    
    // Play, requires specification of the screen where the request originated.
    - (void) playForScreen: (NSString *) screen {

        // If we're on lockscreen...
        if ([screen isEqualToString: @"lockscreen"]) {
            // And secPlayerUnit is setup...
            if (secPlayerUnit.looper != nil) {
                // Play it!
                [secPlayerUnit play];
                return;
            }
        }

        // Else play primary.
        [priPlayerUnit play];

    }

    // These methods should be called appropriately to maintain performance, by pausing non-visible players.
    - (void) pausePriUnitIfNeeded {

        // Only pause primary when secondary's setup.
        if (secPlayerUnit.looper != nil)
            [priPlayerUnit pause];
    }

    - (void) pauseSecUnit {
        [secPlayerUnit pause];
    }

    // Pause all subunits.
    - (void) pause {
        // Asks both units to pause.
        [priPlayerUnit pause];
        [secPlayerUnit pause];

    }
@end