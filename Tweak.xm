#import <AVFoundation/AVFoundation.h>
#import <version.h>
#import <substrate.h>
#import "FBSystemService.h"
#import "SpringBoard.h"
#import "Globals.h"
#import "WallPlayer.h"
#import "UIView+.h"

// MARK: Main Tweak

%group Tweak

	%hook SBFWallpaperView

		// // Begin monitoring for PVC notifications if necessary.
		// - (void) didMoveToWindow {
		// 	%orig;

		// 	if (!([self.window isKindOfClass: [%c(_SBWallpaperWindow) class]] || [self.window isKindOfClass: [%c(SBCoverSheetWindow) class]])) {
		// 		return;
		// 	}

		// 	SBFWallpaperView * __weak weakSelf = self;
		// 	[NSNotificationCenter.defaultCenter addObserverForName: @"com.ZX02.Frame.PVC" object: nil queue: NSOperationQueue.mainQueue usingBlock: ^(NSNotification *notification) {
		// 		if (weakSelf != nil)
		// 			updateComponentsVisibility(weakSelf, nil);
		// 	}];
		// }

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
				// Determine if this view is on lockscreen.
				SBWallpaperController *wpController = [%c(SBWallpaperController) sharedInstance];
				bool isLockscreenView = [self.window isKindOfClass: [%c(SBCoverSheetWindow) class]] || (self == wpController.lockscreenWallpaperView);

				// Setup Player.
				WallPlayer *player = [%c(WallPlayer) shared];
				playerLayer = [player addInView: self isLockscreen: isLockscreenView];
				objc_setAssociatedObject(self, _cmd, playerLayer, OBJC_ASSOCIATION_RETAIN);

			}

			// Send playerLayer to front and match its frame to that of the current view.
			// Note: for compatibility with SpringArtwork, we let SAViewController's view's layer stay atop :)
			CALayer *saLayer;
			for (UIView *view in self.subviews) {
				if ([view.nextResponder isKindOfClass: [%c(SAViewController) class]]) {
					saLayer = view.layer;
					break;
				}
			}
			
			if (saLayer != nil)
				[self.layer insertSublayer: playerLayer below: saLayer];
			else
				[self.layer addSublayer: playerLayer];

			playerLayer.frame = self.bounds;
		}

	%end

	// Rework the blue effect of folders.
	// By default iOS seems to render the blurred images "manually" (without using UIVisualEffectView)
	// and using a snapshot of the wallpaper.
	// The simplest way to adapt this to our video bg is to replace the stock view that renders the blurred image
	// with an actual UIVisualEffectView

	%hook SBWallpaperEffectView 

		-(void) didMoveToWindow {
			%orig;

			// Repairs the reachability blur view when activated from the home screen.
			if (!isInApp && [self.window isKindOfClass: [%c(SBReachabilityWindow) class]]) {
				// Remove the stock blur view.
				self.subviews.firstObject &&
					(self.subviews.firstObject.hidden = true);
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
					(self.blurView.subviews.firstObject.hidden = true);

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

	%hook SpringBoard

		// Control for enter / exit app.
		- (void) frontDisplayDidChange: (id) newDisplay {
			%orig;
			WallPlayer *player = [%c(WallPlayer) shared];
			if (newDisplay != nil) {
				// Only pause if we're entering an app and not just entering app-switcher.
				if (!isInApp) {
					// Entered app.
					isInApp = true;
					if (isOnLockscreen) {
						// If the user immediately swiped down and now we're on lockscreen.
						[player pauseHomescreen];
					}
					else {
						// Thankfully we're still in the app.
						[player pauseHomescreen];
						[player pauseSharedPlayer];
					}
				}
			}
			else if (isInApp) {
				// Left app.
				isInApp = false;
				[player playHomescreen];
			}
		}
	%end

	// Control for sleep / wake.
	%hook SBScreenWakeAnimationController

		// Centralised control for play/pause corresponding to wake/sleep.
		-(void) _startWakeAnimationsForWaking: (BOOL) isAwake animationSettings: (id) arg2 {
			%orig;
			isAsleep = !isAwake;
			WallPlayer *player = [%c(WallPlayer) shared];
			if (isAwake) {
				[player playLockscreen];
			}
			else {
				[player pause];
			}
		}
	%end

	// Control for Siri.
	// This is in place of listening for audio session interruption notifications, which are not sent properly.
	%hook SBAssistantRootViewController
		- (void) viewWillDisappear: (BOOL) animated {
			%orig;

			WallPlayer *player = [%c(WallPlayer) shared];
			if (isOnLockscreen) // Play lockscreen.
				[player playLockscreen];
			else if (!isInApp || !player.pauseInApps) // Play homescreen if we're not in app OR player doesn't pause in apps.
				[player playHomescreen];
		}
	%end

	// Control for home.
	// Fastest route yet found for all users.
	%hook SBLayoutStateTransitionContext
		- (id) initWithWorkspaceTransaction: (id) arg1 {
			SBLayoutStateTransitionContext *s = %orig;
			SBLayoutState *from = s.fromLayoutState;
			SBLayoutState *to = s.toLayoutState;
			WallPlayer *player = [%c(WallPlayer) shared];
			if (from.elements != nil && to.elements == nil) {
				// Leaving an app.
				if (isInApp) {
					isInApp = NO;
					[player playHomescreen];
				}
			}
			return s;
		}
	%end

	// Control for lockscreen & coversheet.
	// Resume player whenever coversheet will be shown.
	%hook CSCoverSheetViewController

		// The cases for play/pause are divided into the will/did appear/disappear methods,
		// to ensure that the wallpaper will begin playing as early as possible
		// and stop playing as late as possible.

		- (void) viewWillAppear: (BOOL) animated {
			%orig;
			isOnLockscreen = true;
			WallPlayer *player = [%c(WallPlayer) shared];
			// Ignore if this is triggered on sleep.
			// Otherwise eagerly play.
			if (!isAsleep) {
				[player playLockscreen];
			}
		}

		- (void) viewDidAppear: (BOOL) animated {
			%orig;
			WallPlayer *player = [%c(WallPlayer) shared];
			// Ignore if this is triggered on sleep.
			if (!isAsleep) {
				[player pauseHomescreen];
			}
		}

		- (void) viewWillDisappear: (BOOL) animated {
			%orig;
			WallPlayer *player = [%c(WallPlayer) shared];
			if (!player.pauseInApps || !isInApp) {
				[player playHomescreen];
			}
		}

		- (void) viewDidDisappear: (BOOL) animated {
			%orig;
			isOnLockscreen = false;
			WallPlayer *player = [%c(WallPlayer) shared];
			// Pause if player's only enabled on lockscreen.
			[player pauseLockscreen];
		}

	%end

%end

// Group of iOS < 13 specific hooks.
%group Fallback

	// Achieves the same effect as hooking CSCoverSheet, but on iOS <= 12.
	%hook SBDashBoardViewController

		// The cases for play/pause are divided into the will/did appear/disappear methods,
		// to ensure that the wallpaper will begin playing as early as possible
		// and stop playing as late as possible.

		- (void) viewWillAppear: (BOOL) animated {
			%orig;
			isOnLockscreen = true;
			WallPlayer *player = [%c(WallPlayer) shared];
			// Ignore if this is triggered on sleep.
			// Otherwise eagerly play.
			if (!isAsleep) {
				[player playLockscreen];
			}
		}

		- (void) viewDidAppear: (BOOL) animated {
			%orig;
			WallPlayer *player = [%c(WallPlayer) shared];
			// Ignore if this is triggered on sleep.
			if (!isAsleep) {
				[player pauseHomescreen];
			}
		}

		- (void) viewWillDisappear: (BOOL) animated {
			%orig;
			WallPlayer *player = [%c(WallPlayer) shared];
			if (!player.pauseInApps || !isInApp) {
				[player playHomescreen];
			}
		}

		- (void) viewDidDisappear: (BOOL) animated {
			%orig;
			isOnLockscreen = false;
			WallPlayer *player = [%c(WallPlayer) shared];
			// Pause if player's only enabled on lockscreen.
			[player pauseLockscreen];
		}

	%end

%end

void respringCallback(CFNotificationCenterRef center, void * observer, CFStringRef name, void const * object, CFDictionaryRef userInfo) {
	[[%c(FBSystemService) sharedInstance] exitAndRelaunch: true];
}

void videoChangedCallback(CFNotificationCenterRef center, void * observer, CFStringRef name, void const * object, CFDictionaryRef userInfo) {
	[WallPlayer.shared reloadPlayers];
}

// Fix permissions for users who've updated Frame.
void createResourceFolder() {
	NSURL *frameFolder = [NSURL fileURLWithPath: @"/var/mobile/Documents/com.ZX02.Frame/"];

	// Create frame's folder.
	if (![NSFileManager.defaultManager fileExistsAtPath: frameFolder.path isDirectory: nil])
			if (![NSFileManager.defaultManager createDirectoryAtPath: frameFolder.path withIntermediateDirectories: YES attributes: nil error: nil])
					return;
  
	[NSFileManager.defaultManager setAttributes: @{ NSFilePosixPermissions: @511 } ofItemAtPath: frameFolder.path error: nil];
}

// Main
%ctor {
	// Create the resource folder if necessary & update permissions.
	createResourceFolder();

	NSUserDefaults *bundleDefaults = [[NSUserDefaults alloc] initWithSuiteName: @"com.Zerui.framepreferences"];

	// Defaults to enabled (as shown in preferences) when PrefLoader has not written anything to user defaults.
	NSArray<NSString *> *defaultsKeys = [bundleDefaults dictionaryRepresentation].allKeys;
	BOOL isEnabled = YES;
	if ([defaultsKeys containsObject: @"isEnabled"])
		isEnabled = [bundleDefaults boolForKey: @"isEnabled"];
	if (isEnabled) {
		[WallPlayer.shared loadPreferences];
		%init(Tweak);

		if ([[[UIDevice currentDevice] systemVersion] floatValue] < 13.0) {
			%init(Fallback);
		}
	}

	// Listen for respring requests from pref.
	CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
	CFNotificationCenterAddObserver(center, nil, respringCallback, CFSTR("com.ZX02.framepreferences.respring"), nil, nil);
	CFNotificationCenterAddObserver(center, nil, videoChangedCallback, CFSTR("com.ZX02.framepreferences.videoChanged"), nil, nil);
}