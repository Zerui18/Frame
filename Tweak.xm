#import <AVFoundation/AVFoundation.h>
#import <version.h>
#import <substrate.h>
#include "FBSystemService.h"

// Globals
bool isAsleep;
bool isInApp;

// UIView category to get subviews of specified class.
@interface UIView (X)
	- (NSArray<UIView *> *) subviewsOfClass: (Class) mClass;
	- (UIView *) subviewOfClass: (Class) mClass;
@end

@implementation UIView (X)

	// Gets an array of subviews of the specified class.
	- (NSArray<UIView *> *) subviewsOfClass: (Class) mClass {
		return [self.subviews filteredArrayUsingPredicate: [NSPredicate predicateWithBlock: ^BOOL(id view, NSDictionary *bindings) {
			return [view isKindOfClass: mClass];
		}]];
	}

	// Gets the first subview of the specified class.
	- (UIView *) subviewOfClass: (Class) mClass {
		return [self subviewsOfClass: mClass].firstObject;
	}

@end

// Executes the provided block once on main thread.
void dispatch_once_on_main_thread(dispatch_once_t *predicate,
                                  dispatch_block_t block) {
  if ([NSThread isMainThread]) {
    dispatch_once(predicate, block);
  } else {
    if (DISPATCH_EXPECT(*predicate == 0L, NO)) {
      dispatch_sync(dispatch_get_main_queue(), ^{
        dispatch_once(predicate, block);
      });
    }
  }
}

// MARK: Main Tweak
%group Tweak
	// Logical container for the AVQueuePlayer used in this tweak.
	// Manages a single instance of AVQueuePlayer that's controlled by the AVPlayerLooper.
	// Adds AVPlayerLayer to the provided views.
	@interface WallPlayer: NSObject {
		NSUserDefaults *bundleDefaults;
		AVAudioSession *audioSession;
	}

		@property(setter=setVideoURL:, nonatomic) NSURL *videoURL;
		@property AVPlayerItem *playerItem;
		@property AVQueuePlayer *player;
		@property AVPlayerLooper *looper;
		@property(setter=setPauseInApps:, nonatomic) BOOL pauseInApps;
		@property(setter=setEnabledScreens:, nonatomic) NSString *enabledScreens;

	@end

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
		}
		
		// Pause.
		- (void) pause {
			// Global override point for pauseInApps.
			if (!self.pauseInApps && isInApp) {
				return;
			}
			[self.player pause];
		}
	@end


	// Prevent the system from adding subviews to the wallpaper container view.
	
	// Class decls.
	@interface SBFWallpaperView : UIView
		- (void) updateComponentsVisibility: (AVPlayerLayer *) suppliedLayer;
	@end

	@interface CSCoverSheetViewController : UIViewController
	@end

	@interface SBCoverSheetPanelBackgroundContainerView : UIView
	@end

	@interface _SBWallpaperWindow : UIWindow
	@end

	@interface SBCoverSheetWindow : UIWindow
	@end

	@interface SBReachabilityWindow : UIWindow
	@end

	// Category for getting the parent view controller of the receiver view.
	// https://stackoverflow.com/a/24590678
	@interface UIView (mxcl)
		- (UIViewController *) parentViewController;
	@end

	@implementation UIView (mxcl)
		- (UIViewController *) parentViewController {
			UIResponder *responder = self;
			while ([responder isKindOfClass:[UIView class]])
				responder = [responder nextResponder];
			return (UIViewController *)responder;
		}
	@end

	@interface SBWallpaperController
		+ (id)sharedInstance;
		@property(retain, nonatomic) SBFWallpaperView *sharedWallpaperView;
		@property(retain, nonatomic) SBFWallpaperView *homescreenWallpaperView;
		@property(retain, nonatomic) SBFWallpaperView *lockscreenWallpaperView;
	@end

	void updateComponentsVisibility(SBFWallpaperView * self, AVPlayerLayer * suppliedLayer) {
		// Safety Check.
		if (self == nil)
			return;

		SBWallpaperController *wpController = [%c(SBWallpaperController) sharedInstance];

		// Setup Player.
		WallPlayer *player = [%c(WallPlayer) shared];
		// Objc does not support coersion operator "??"
		AVPlayerLayer *playerLayer = suppliedLayer != nil ? suppliedLayer : (AVPlayerLayer *) objc_getAssociatedObject(self, @selector(layoutSubviews));

		if (playerLayer == nil)
			return;

		// Categorise and apply for each case of setting.
		if (![player.enabledScreens isEqualToString: @"both"]) {
			// Alert user if they are using the same system wallpaper
			// but they chose anything other than "both".
			if (wpController.sharedWallpaperView == self) {
				// Set playerLayer as visible.
				playerLayer.hidden = false;

				// Alert (only once)
				static bool hasAlerted;
				if (hasAlerted) return; 
				UIAlertController *alertVC = [UIAlertController alertControllerWithTitle: @"Frame - Tweak"
												message: [NSString stringWithFormat: @"You have chosen for Frame to only display on %@, but you will need to set different system wallpapers for lockscreen & homescreen for this to take effect.", player.enabledScreens]
												preferredStyle: UIAlertControllerStyleAlert];
				[alertVC addAction: [UIAlertAction actionWithTitle: @"OK" style: UIAlertActionStyleDefault handler: nil]];
				UIViewController *presenterVC = UIApplication.sharedApplication.keyWindow.rootViewController;
				if (presenterVC != nil)
					[presenterVC presentViewController: alertVC animated: true completion: nil], hasAlerted = true;
				return;
			}
			
			// Further divide cases.
			// In each case if self.window is coversheet window
			// it's straightforward to determine .hidden.
			if ([player.enabledScreens isEqualToString: @"lockscreen"]) { // lockscreen
				if ([self.window isKindOfClass: [%c(SBCoverSheetWindow) class]]) {
					playerLayer.hidden = false;
				}
				else {
					playerLayer.hidden = self != wpController.lockscreenWallpaperView;
				}
			}
			else { // homescreen
				if ([self.window isKindOfClass: [%c(SBCoverSheetWindow) class]]) {
					playerLayer.hidden = true;
				}
				else {
					playerLayer.hidden = self != wpController.homescreenWallpaperView;
				}
			}
		}
		else {
			playerLayer.hidden = false;
		}

		// Update contentView as the opposite of playerLayer.
		UIView *contentView = MSHookIvar<UIView *>(self, "_contentView");
		if (contentView != nil)
			contentView.hidden = !playerLayer.hidden;
	}

	%hook SBFWallpaperView

		// Begin monitoring for PVC notifications if necessary.
		- (void) didMoveToWindow {
			%orig;

			if (!([self.window isKindOfClass: [%c(_SBWallpaperWindow) class]] || [self.window isKindOfClass: [%c(SBCoverSheetWindow) class]])) {
				return;
			}

			SBFWallpaperView * __weak weakSelf = self;
			[NSNotificationCenter.defaultCenter addObserverForName: @"com.ZX02.Frame.PVC" object: nil queue: NSOperationQueue.mainQueue usingBlock: ^(NSNotification *notification) {
				if (weakSelf != nil)
					updateComponentsVisibility(weakSelf, nil);
			}];
		}

		// Hook layoutSubviews to run our init once system has added its stock subviews.
		- (void) layoutSubviews {
			%orig;

			if (!([self.window isKindOfClass: [%c(_SBWallpaperWindow) class]] || [self.window isKindOfClass: [%c(SBCoverSheetWindow) class]])) {
				return;
			}

			// Attempts to retrieve associated AVPlayerLayer.
			AVPlayerLayer *playerLayer = (AVPlayerLayer *) objc_getAssociatedObject(self, _cmd);
			
			// No existing playerLayer? Init
			if (playerLayer == nil) {
				// Setup Player.
				WallPlayer *player = [%c(WallPlayer) shared];
				playerLayer = [player addInView: self];
				objc_setAssociatedObject(self, _cmd, playerLayer, OBJC_ASSOCIATION_ASSIGN);

				updateComponentsVisibility(self, playerLayer);
			}

			// Send playerLayer to front and match its frame to that of the current view.
			[self.layer addSublayer: playerLayer];
			playerLayer.frame = self.bounds;
		}

	%end

	// Rework the blue effect of folders.
	// By default iOS seems to render the blurred images "manually" (without using UIVisualEffectView)
	// and using a snapshot of the wallpaper.
	// The simplest way to adapt this to our video bg is to replace the stock view that renders the blurred image
	// with an actual UIVisualEffectView
	@interface SBWallpaperEffectView : UIView
		@property (nonatomic,retain) UIView* blurView;
		@property (assign,nonatomic) long long wallpaperStyle; 
	@end

	%hook SBWallpaperEffectView 

		-(void) didMoveToWindow {
			%orig;

			// Repairs the reachability blur view when activated from the home screen.
			if (!isInApp && [self.window isKindOfClass: [%c(SBReachabilityWindow) class]]) {
				// Remove the stock blur view.
				self.subviews.firstObject &&
					self.subviews.firstObject.hidden = true;
				UIView *newBlurView;
				if (@available(iOS 13.0, *))
					newBlurView = [[UIVisualEffectView alloc] initWithEffect: [UIBlurEffect effectWithStyle: UIBlurEffectStyleSystemUltraThinMaterial]];
				else
					newBlurView = [[UIVisualEffectView alloc] initWithEffect: [UIBlurEffect effectWithStyle: UIBlurEffectStyleRegular]];
				newBlurView.frame = self.bounds;
				[self addSubview: newBlurView];
				return %orig;
			}

			// Only apply fix for the following cases:
			// Wallpaper style 29 -> icon component blur
			// Wallpaper style 12 -> SBDockView's underlying blur (iOS <= 12)
			if (self.wallpaperStyle != 29 && self.wallpaperStyle != 12)
				return;
			// Hide the stock blur effect render.
			self.blurView &&
				self.blurView.subviews.firstObject &&
					self.blurView.subviews.firstObject.hidden = true;

			UIView *newBlurView;
			if (@available(iOS 13.0, *))
				newBlurView = [[UIVisualEffectView alloc] initWithEffect: [UIBlurEffect effectWithStyle: UIBlurEffectStyleSystemUltraThinMaterial]];
			else
				newBlurView = [[UIVisualEffectView alloc] initWithEffect: [UIBlurEffect effectWithStyle: UIBlurEffectStyleRegular]];
			
			// Add our blur view to self.blurView (system's fake blur).
			newBlurView.frame = self.blurView.bounds;
			newBlurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
			[self.blurView addSubview: newBlurView];
		}
	%end

	// Coordinate the WallPlayer with SpringBoard.
	// Pause player when an application opens.
	// Resume player when the homescreen is shown.
	@interface SpringBoard : NSObject
	@end

	%hook SpringBoard

		-(void) frontDisplayDidChange: (id) newDisplay {
			%orig;
			WallPlayer *player = [%c(WallPlayer) shared];
			if (newDisplay == nil) {
				isInApp = NO;
				// Don't play if player's only enabled on lockscreen.
				if ([player.enabledScreens isEqualToString: @"lockscreen"])	return;
				[player play];
			}
			else {
				isInApp = YES;
				[player pause];
			}
		}
	%end

	// Resume player whenever coversheet will be shown.
	%hook CSCoverSheetViewController

		// The cases for play/pause are divided into the will/did appear/disappear methods,
		// to ensure that the wallpaper will begin playing as early as possible
		// and stop playing as late as possible.

		- (void) viewWillAppear: (BOOL) animated {
			%orig;
			WallPlayer *player = [%c(WallPlayer) shared];
			// Ignore if this is triggered on sleep.
			// Otherwise eagerly play.
			if (!isAsleep) {
				if (![player.enabledScreens isEqualToString: @"homescreen"])
					[player play];
			}
		}

		- (void) viewDidAppear: (BOOL) animated {
			%orig;
			WallPlayer *player = [%c(WallPlayer) shared];
			// Ignore if this is triggered on sleep.
			// Otherwise eagerly play.
			if (!isAsleep) {
				if ([player.enabledScreens isEqualToString: @"homescreen"])
					[player pause];
			}
		}

		- (void) viewWillDisappear: (BOOL) animated {
			%orig;
			WallPlayer *player = [%c(WallPlayer) shared];
			// Pause if player's only enabled on lockscreen.
			if (![player.enabledScreens isEqualToString: @"lockscreen"]) {
				// Respect pauseInApps.
				if (!player.pauseInApps || !isInApp)
					[player play];
			}
		}

		- (void) viewDidDisappear: (BOOL) animated {
			%orig;
			WallPlayer *player = [%c(WallPlayer) shared];
			// Pause if player's only enabled on lockscreen.
			if ([player.enabledScreens isEqualToString: @"lockscreen"]) {
				[player pause];
			}
		}
	%end

	// Achieves the same effect as hooking CSCoverSheet, but on iOS <= 12.
	%hook SBDashBoardViewController

		// The cases for play/pause are divided into the will/did appear/disappear methods,
		// to ensure that the wallpaper will begin playing as early as possible
		// and stop playing as late as possible.

		- (void) viewWillAppear: (BOOL) animated {
			%orig;
			WallPlayer *player = [%c(WallPlayer) shared];
			// Ignore if this is triggered on sleep.
			// Otherwise eagerly play.
			if (!isAsleep) {
				if (![player.enabledScreens isEqualToString: @"homescreen"])
					[player play];
			}
		}

		- (void) viewDidAppear: (BOOL) animated {
			%orig;
			WallPlayer *player = [%c(WallPlayer) shared];
			// Ignore if this is triggered on sleep.
			// Otherwise eagerly play.
			if (!isAsleep) {
				if ([player.enabledScreens isEqualToString: @"homescreen"])
					[player pause];
			}
		}

		- (void) viewWillDisappear: (BOOL) animated {
			%orig;
			WallPlayer *player = [%c(WallPlayer) shared];
			// Pause if player's only enabled on lockscreen.
			if (![player.enabledScreens isEqualToString: @"lockscreen"]) {
				// Respect pauseInApps.
				if (!player.pauseInApps || !isInApp)
					[player play];
			}
		}

		- (void) viewDidDisappear: (BOOL) animated {
			%orig;
			WallPlayer *player = [%c(WallPlayer) shared];
			// Pause if player's only enabled on lockscreen.
			if ([player.enabledScreens isEqualToString: @"lockscreen"]) {
				[player pause];
			}
		}
	%end

	%hook SBScreenWakeAnimationController

		// Centralised control for play/pause corresponding to wake/sleep.
		-(void) _startWakeAnimationsForWaking: (BOOL) isAwake animationSettings: (id) arg2 {
			%orig;
			isAsleep = !isAwake;
			WallPlayer *player = [%c(WallPlayer) shared];
			if (isAwake) {
				// Don't play if player's only enabled on homescreen
				if ([player.enabledScreens isEqualToString: @"homescreen"])	return;
				[player play];
			}
			else {
				[player pause];
			}
		}
	%end

	// Resume player after Siri dismisses.
	// This is in place of listening for audio session interruption notifications, which are not sent properly.
	%hook SBAssistantRootViewController
		- (void) viewWillDisappear: (BOOL) animated {
			%orig;
			
			// Determine if the user's currently on the lock screen.
			BOOL isOnLockScreen;
			for (UIWindow *window in [[UIApplication sharedApplication] windows]) {
				if ([window isKindOfClass: [%c(SBCoverSheetWindow) class]]) {
					isOnLockScreen = !window.hidden;
					break;
				}
			}

			WallPlayer *player = [%c(WallPlayer) shared];
			// Do not play if player's not enabled on the current screen.
			if (([player.enabledScreens isEqualToString: @"lockscreen"] && !isOnLockScreen)
				|| ([player.enabledScreens isEqualToString: @"homescreen"] && isOnLockScreen)
				// or if pauseInApps doesn't allow it
				|| (player.pauseInApps && isInApp)
				)
				return;
			[player play];
		}
	%end
%end

void notifyCallback(CFNotificationCenterRef center, void * observer, CFStringRef name, void const * object, CFDictionaryRef userInfo) {
	[[%c(FBSystemService) sharedInstance] exitAndRelaunch:YES];
}

// main()
%ctor {
	NSUserDefaults *bundleDefaults = [[NSUserDefaults alloc] initWithSuiteName: @"com.Zerui.framepreferences"];

	// Defaults to enabled (as shown in preferences) when PrefLoader has not written anything to user defaults.
	NSArray<NSString *> *defaultsKeys = [bundleDefaults dictionaryRepresentation].allKeys;
	BOOL isEnabled = YES;
	if ([defaultsKeys containsObject: @"isEnabled"])
		isEnabled = [bundleDefaults boolForKey: @"isEnabled"];
	if (isEnabled) {
		[WallPlayer.shared loadPreferences];
		%init(Tweak);
	}

	// Listen for respring requests from pref.
	CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
	CFNotificationCenterAddObserver(center, nil, notifyCallback, CFSTR("com.ZX02.framepreferences.respring"), nil, nil);
}