#import <AVFoundation/AVFoundation.h>
#import <version.h>
#import <substrate.h>
#import <dlfcn.h>
#import "FBSystemService.h"
#import "SpringBoard.h"
#import "Globals.h"
#import "Frame.h"
#import "UIView+.h"
#import "DeviceStates.h"
#import "Checks.h"
#import "echo.h"

// MARK: Main Tweak
void const *playerLayerKey;

%group Common

	// Helper function that sets up wallpaper FRAME in the given wallpaperView.
	void setupWallpaperPlayer(SBFWallpaperView *wallpaperView, bool isLockscreenView) {
		// Attempts to retrieve associated AVPlayerLayer.
		AVPlayerLayer *playerLayer = (AVPlayerLayer *) objc_getAssociatedObject(wallpaperView, &playerLayerKey);
		
		// No existing playerLayer? Init
		if (playerLayer == nil) {

			// Setup FRAME.
			// Note: Don't add wallpaperView into .contentView as it's irregularly framed.
			playerLayer = [FRAME addInView: wallpaperView isLockscreen: isLockscreenView];
			objc_setAssociatedObject(wallpaperView, &playerLayerKey, playerLayer, OBJC_ASSOCIATION_RETAIN);

		}
	}

	%hook SBWallpaperController

		// Point of setup for wallpaper players.
		+ (id) sharedInstance {
			SBWallpaperController *ctr = %orig;

			if (ctr == nil)
				return nil;
			
			SBWallpaperViewController *vc;

			// iOS 14.x
			if (%c(SBWallpaperViewController) != nil) // Safety check before MSHookIvar
				vc = MSHookIvar<SBWallpaperViewController *>(ctr, "_wallpaperViewController");

			SBFWallpaperView *ls, *hs, *both;
			if (vc) {
				ls = vc.lockscreenWallpaperView;
				hs = vc.homescreenWallpaperView;
				both = vc.sharedWallpaperView;
				echo(@"found wallpaper view controller with views: %@, %@, %@", ls, hs, both);
			}
			else {
				ls = ctr.lockscreenWallpaperView;
				hs = ctr.homescreenWallpaperView;
				both = ctr.sharedWallpaperView;
			}

			// We don't need to ensure singular call as the setup function checks if the provided view has been configured.
			if (ls != nil && hs != nil) {
				setupWallpaperPlayer(ls, true);
				setupWallpaperPlayer(hs, false);
			}
			else if (both != nil) {
				setupWallpaperPlayer(both, false);
			}
			return ctr;
		}
	%end

	%hook SBFWallpaperView

		- (void) layoutSubviews {
			%orig;

			// Insert point for coversheet window, which is not covered by the SBWallpaperController hook.
			if ([self.window isKindOfClass: [%c(SBCoverSheetWindow) class]]) {
				setupWallpaperPlayer(self, true);
			}

			// General operation of re-positioning the playerLayer.
			// Attempts to retrieve associated AVPlayerLayer.
			AVPlayerLayer *playerLayer = (AVPlayerLayer *) objc_getAssociatedObject(self, &playerLayerKey);

			if (playerLayer != nil) {
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
		}
	
	%end

	// Coordinate the Frame with SpringBoard.
	// Pause FRAME when an application opens.
	// Resume FRAME when the homescreen is shown.

	%hook SpringBoard
		void cancelCountdown(); // cancel home screen fade countdown (see far below)
		void rescheduleCountdown();

		// Rather reliable mechanism for tracking IS_IN_APP.
		- (void) frontDisplayDidChange: (id) newDisplay {
			%orig;
			IS_IN_APP = newDisplay != nil;
		}
	%end

	// Control for Siri.
	// This is in place of listening for audio session interruption notifications, which are not sent properly.
	%hook SBAssistantRootViewController
		- (void) viewWillDisappear: (BOOL) animated {
			%orig;

			if (IS_ON_LOCKSCREEN) // Play lockscreen.
				[FRAME playLockscreen];
			else if (!IS_IN_APP || !FRAME.pauseInApps) // Play homescreen if we're not in app OR FRAME doesn't pause in apps.
				[FRAME playHomescreen];
		}
	%end

	// Control for home.
	// Fastest route yet found for all users.
	%hook SBLayoutStateTransitionContext
		- (id) initWithWorkspaceTransaction: (id) arg1 {
			SBLayoutStateTransitionContext *s = %orig;
			SBLayoutState *from = s.fromLayoutState;
			SBLayoutState *to = s.toLayoutState;
			if (from.elements != nil && to.elements == nil) {
				IS_IN_APP = false;
			}
			return s;
		}
	%end

	// Control for lockscreen & coversheet.
	// Resume FRAME whenever coversheet will be shown.
	%hook CSCoverSheetViewController

		// The cases for play/pause are divided into the will/did appear/disappear methods,
		// to ensure that the wallpaper will begin playing as early as possible
		// and stop playing as late as possible.

		- (void) viewWillAppear: (BOOL) animated {
			%orig;
			IS_ON_LOCKSCREEN = true;
		}

		- (void) viewDidAppear: (BOOL) animated {
			%orig;
			[FRAME pauseHomescreen];
		}

		- (void) viewWillDisappear: (BOOL) animated {
			%orig;
			if (!FRAME.pauseInApps || !IS_IN_APP) {
				[FRAME playHomescreen];
				// Unfade.
				cancelCountdown();
				rescheduleCountdown();
			}
		}

		- (void) viewDidDisappear: (BOOL) animated {
			%orig;
			IS_ON_LOCKSCREEN = false;
			// Additonal check to prevent situations where a shared FRAME is set
			// and when the user dismisses the cover sheet it doesn't stop playing.
			if (IS_IN_APP && FRAME.pauseInApps)
				[FRAME pauseSharedPlayer];
		}

	%end

	SBHomeScreenViewController *homeScreenVC = nil;

	// The code below is for "Fade".

	// Timer-managed on/off, coupled with hooking SBIconScrollView below.
	// Also resource folder access checking.
	%hook SBHomeScreenViewController

	- (void) viewDidAppear: (bool) animated {
			%orig;
			homeScreenVC = self;
			checkResourceFolder(self);
		}
		
		// The countdown timer for debouncing the hide animation for the above VC.
		NSTimer *timer;

		// Functions.
		void rescheduleCountdown() {
			if (FRAME.enabled && FRAME.fadeEnabled) {
				[timer invalidate];
				timer = [NSTimer scheduledTimerWithTimeInterval: FRAME.fadeInactivity repeats: false block: ^(NSTimer *timer) {
					[NSNotificationCenter.defaultCenter postNotificationName: @"Fade" object: @true userInfo: nil];
				}];
				[NSRunLoop.currentRunLoop addTimer: timer forMode: NSDefaultRunLoopMode];
			}
		}
		void cancelCountdown() {
			if (FRAME.enabled && FRAME.fadeEnabled) {
				[timer invalidate];
				timer = nil;
				[NSNotificationCenter.defaultCenter postNotificationName: @"Fade" object: @false userInfo: nil];
			}
		}

		// Begin timer.
		- (void) viewWillAppear: (bool) animated {
			%orig;
			// Unfade.
			cancelCountdown();
			rescheduleCountdown();
		}

		// Remove timer.
		- (void) viewDidDisapper: (bool) animated {
			%orig;
			cancelCountdown();
		}

	%end
	
	// Receivers for fade/unfade notifications.
	%hook SBIconListView
	- (void) didMoveToWindow { %orig; [NSNotificationCenter.defaultCenter addObserver: self selector: @selector(fade:) name: @"Fade" object: nil]; }
	%new
	- (void) fade: (NSNotification *) notification { [UIView animateWithDuration: 0.3 animations: ^() { self.alpha = [notification.object boolValue] ? FRAME.fadeAlpha : 1.0; }]; }
	%end
	%hook SBIconListPageControl
	- (void) didMoveToWindow { %orig; [NSNotificationCenter.defaultCenter addObserver: self selector: @selector(fade:) name: @"Fade" object: nil]; }
	%new
	- (void) fade: (NSNotification *) notification { [UIView animateWithDuration: 0.3 animations: ^() { self.alpha = [notification.object boolValue] ? FRAME.fadeAlpha : 1.0; }]; }
	%end
	%hook SBDockView
	- (void) didMoveToWindow { %orig; [NSNotificationCenter.defaultCenter addObserver: self selector: @selector(fade:) name: @"Fade" object: nil]; }
	%new
	- (void) fade: (NSNotification *) notification { [UIView animateWithDuration: 0.3 animations: ^() { self.alpha = [notification.object boolValue] ? FRAME.fadeAlpha : 1.0; }]; }
	%end
	%hook SBFloatingDockView
	- (void) didMoveToWindow { %orig; [NSNotificationCenter.defaultCenter addObserver: self selector: @selector(fade:) name: @"Fade" object: nil]; }
	%new
	- (void) fade: (NSNotification *) notification { [UIView animateWithDuration: 0.3 animations: ^() { self.alpha = [notification.object boolValue] ? FRAME.fadeAlpha : 1.0; }]; }
	%end

	// Touch-triggered timer delays, intercepted from the horizontal pan gesture recognizer.
	%hook SBIconScrollView

		- (void) didMoveToWindow {
			%orig;
			// Add tap gesture.
			UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget: self action: @selector(didTap:)];
			tap.cancelsTouchesInView = false;
			[self addGestureRecognizer: tap];
		}

		// Intercept the horizontal swipe gesture recognizer.
		- (void) addGestureRecognizer: (UIGestureRecognizer *) gestureRecognizer {
			if ([gestureRecognizer isKindOfClass: [%c(UIPanGestureRecognizer) class]]
					&& ((SBIconScrollView *) gestureRecognizer.delegate) == self) {
				// Attach also our action.
				[gestureRecognizer addTarget: self action: @selector(didPan:)];
			}
			%orig;
		}

		- (void) touchesBegan: (NSSet<UITouch *> *) touches withEvent: (UIEvent *) event {
			%orig;
			cancelCountdown();
		}

		// Handle horizontal-pan-based unFade.
		%new
		- (void) didPan: (UIGestureRecognizer *) gestureRecognizer {
			if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
				cancelCountdown();
			}
			else if (gestureRecognizer.state == UIGestureRecognizerStateEnded
							|| gestureRecognizer.state == UIGestureRecognizerStateCancelled) {
				rescheduleCountdown();
			}
		}

		%new
		- (void) didTap: (UIGestureRecognizer *) gestureRecognizer {
			if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
				// Temporary trigger for play.
				[FRAME forcePlayHomescreen];
				cancelCountdown();
				rescheduleCountdown();
			}
		}

	%end

	// Hook status bar with fade.
	%hook _UIStatusBar
		- (id) initWithStyle: (long long) arg1 {
			if ([self respondsToSelector: @selector(setAlpha:)]) {
				[NSNotificationCenter.defaultCenter addObserver: self selector: @selector(fade:) name: @"Fade" object: nil];
			}
			return %orig;
		}

		%new
		- (void) fade: (NSNotification *) notification {
			[UIView animateWithDuration: 0.3 animations: ^() {
				self.alpha = [notification.object boolValue] ? FRAME.fadeAlpha : 1.0;
			}];
		}

	%end

	// Hook this for info on apps/folders opening/closing.
	%hook SBIconController
		// iOS 13+
		-(void) iconManager: (id) arg1 willCloseFolder: (id) arg2 {
			%orig;
			rescheduleCountdown();
		}

		// iOS 12 and below
		-(void) closeFolderAnimated: (BOOL) arg1 withCompletion: (id) arg2 {
			%orig;
			rescheduleCountdown();
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
			IS_ON_LOCKSCREEN = true;
		}

		- (void) viewDidAppear: (BOOL) animated {
			%orig;
			[FRAME pauseHomescreen];
		}

		- (void) viewWillDisappear: (BOOL) animated {
			%orig;
			if (!FRAME.pauseInApps || !IS_IN_APP) {
				[FRAME playHomescreen];
				// Unfade.
				cancelCountdown();
				rescheduleCountdown();
			}
		}

		- (void) viewDidDisappear: (BOOL) animated {
			%orig;
			IS_ON_LOCKSCREEN = false;
			// Additonal check to prevent situations where a shared FRAME is set
			// and when the user dismisses the cover sheet it doesn't stop playing.
			if (IS_IN_APP && FRAME.pauseInApps)
				[FRAME pauseSharedPlayer];
		}

	%end

%end

%group FixBlur

	// Rework the blur effect of folders.
	// By default iOS seems to render the blurred images "manually" (without using UIVisualEffectView)
	// and using a snapshot of the wallpaper.
	// The simplest way to adapt this to our video bg is to replace the stock view that renders the blurred image
	// with an actual UIVisualEffectView

	%hook SBWallpaperEffectView 

		-(void) didMoveToWindow {
			%orig;

			// Repairs the reachability blur view when activated from the home screen.
			if (!IS_IN_APP && [self.window isKindOfClass: [%c(SBReachabilityWindow) class]]) {
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

%end

void respringCallback(CFNotificationCenterRef center, void * observer, CFStringRef name, void const * object, CFDictionaryRef userInfo) {
	[[%c(FBSystemService) sharedInstance] exitAndRelaunch: true];
}

void videoChangedCallback(CFNotificationCenterRef center, void * observer, CFStringRef name, void const * object, CFDictionaryRef userInfo) {
	[FRAME reloadPlayers];
	checkWPSettings(nil);
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
	// dlopen("/usr/lib/LookinServer.framework/LookinServer", RTLD_NOW);

	// Create the resource folder if necessary & update permissions.
	createResourceFolder();

	%init(Common);

	// iOS 12 and earlier's fallback.
	if (UIDevice.currentDevice.systemVersion.floatValue < 13.0) {
		%init(Fallback);
	}

	// Enable fix blur if requested.
	if (FRAME.fixBlur) {
		%init(FixBlur);
	}

	// Force the lazy globals to init.
	NSLog(@"[Frame]: Globals %@, %@", FRAME, DeviceStates.shared);

	// Listen for respring requests from pref.
	CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
	CFNotificationCenterAddObserver(center, nil, respringCallback, CFSTR("com.zx02.framepreferences.respring"), nil, nil);
	CFNotificationCenterAddObserver(center, nil, videoChangedCallback, CFSTR("com.zx02.framepreferences.videoChanged"), nil, nil);
}