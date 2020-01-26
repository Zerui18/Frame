#import <AVFoundation/AVFoundation.h>
#import <version.h>
#import <substrate.h>
#include "FBSystemService.h"
#include "SpringBoard.h"
#include "Globals.h"
#include "WallPlayer.h"
#include "UIView+.h"

// MARK: Main Tweak

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

%group Tweak

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

		-(void) frontDisplayDidChange: (id) newDisplay {
			%orig;
			WallPlayer *player = [%c(WallPlayer) shared];
			if (newDisplay != nil) {
				// Only pause if we're entering an app and not just entering app-switcher.
				if (!isInApp) {
					// Entered app.
					isInApp = YES;
					[player pause];
				}
			}
			else if (isInApp) {
				// Left app.
				isInApp = NO;
				// Don't play if player's only enabled on lockscreen.
				if (![player.enabledScreens isEqualToString: @"lockscreen"])
					[player play];
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

	// Fastest route yet found for users with the home gesture.
	%hook SBHomeGesturePanGestureRecognizer
		- (BOOL) _shouldBegin {
			BOOL flag = %orig;
			WallPlayer *player = [%c(WallPlayer) shared];
			if (flag && isInApp) {
				isInApp = NO;
				// Don't play if player's only enabled on lockscreen.
				if (![player.enabledScreens isEqualToString: @"lockscreen"])
					[player play];
			}
			return flag;
		}
	%end

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
					// Don't play if player's only enabled on lockscreen.
					if (![player.enabledScreens isEqualToString: @"lockscreen"])
						[player play];
				}
			}
			return s;
		}
	%end
%end

void notifyCallback(CFNotificationCenterRef center, void * observer, CFStringRef name, void const * object, CFDictionaryRef userInfo) {
	[[%c(FBSystemService) sharedInstance] exitAndRelaunch:YES];
}

// Main
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