#import <AVFoundation/AVFoundation.h>
#import <version.h>
#import <substrate.h>
#include <dlfcn.h>
#import "FBSystemService.h"
#import "SpringBoard.h"
#import "Globals.h"
#import "Frame.h"
#import "UIView+.h"

// MARK: Main Tweak
void const *playerLayerKey;

// Check for folder access, otherwise warn user.
void checkResourceFolder(UIViewController *presenterVC) {
	NSString *testFile = @"/var/mobile/Documents/com.ZX02.Frame/.test.txt";

	// Try to write to a test file.
	NSString *str = @"Please do not delete this folder.";
	NSError *err;
	[str writeToFile: testFile atomically: true encoding: NSUTF8StringEncoding error: &err];

	if (err != nil) {
		UIAlertController *alertVC = [UIAlertController alertControllerWithTitle: @"Frame - Tweak"
													message: @"Resource folder can't be accessed."
													preferredStyle: UIAlertControllerStyleAlert];
		[alertVC addAction: [UIAlertAction actionWithTitle: @"Details" style: UIAlertActionStyleDefault handler: ^(UIAlertAction *action) {
			[[UIApplication sharedApplication] openURL: [NSURL URLWithString: @"https://zerui18.github.io/ZX02#err=frame.resAccess"] options:@{} completionHandler: nil];
		}]];
		[alertVC addAction: [UIAlertAction actionWithTitle: @"Ignore" style: UIAlertActionStyleCancel handler: nil]];
		[presenterVC presentViewController: alertVC animated: true completion: nil];
	}
}

%group Tweak

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
			SBWallpaperController *s = %orig;

			// We don't need to ensure singular call as the setup function checks if the provided view has been configured.
			if (s.lockscreenWallpaperView != nil && s.homescreenWallpaperView != nil) {
				setupWallpaperPlayer(s.lockscreenWallpaperView, true);
				setupWallpaperPlayer(s.homescreenWallpaperView, false);
			}
			else if (s.sharedWallpaperView != nil) {
				setupWallpaperPlayer(s.sharedWallpaperView, false);
			}

			// We will also check if the user's configuration's erroneous.
			static bool hasAlerted;
 			
			// Alert user if Frame is active and settings is incompatible.
			if (FRAME.isTweakEnabled) {
				if ([FRAME requiresDifferentSystemWallpapers] && s.sharedWallpaperView != nil) {
					// Alert (once).
					if (hasAlerted) return s;
					// Setup alertVC and present.
					UIAlertController *alertVC = [UIAlertController alertControllerWithTitle: @"Frame - Tweak"
													message: @"You have chosen different videos for lockscreen & homescreen, but you will need to set different system wallpapers for lockscreen & homescreen for this to take effect."
													preferredStyle: UIAlertControllerStyleAlert];
					[alertVC addAction: [UIAlertAction actionWithTitle: @"OK" style: UIAlertActionStyleDefault handler: nil]];
					UIViewController *presenterVC = UIApplication.sharedApplication.windows.firstObject.rootViewController;
					if (presenterVC != nil) {
						[presenterVC presentViewController: alertVC animated: true completion: nil], hasAlerted = true;
						hasAlerted = true;
					}
				}
			}

			return s;
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

	// Coordinate the Frame with SpringBoard.
	// Pause FRAME when an application opens.
	// Resume FRAME when the homescreen is shown.

	%hook SpringBoard
		void cancelCountdown(); // cancel home screen fade countdown (see far below)
		void rescheduleCountdown();

		// Control for enter / exit app.
		- (void) frontDisplayDidChange: (id) newDisplay {
			%orig;
			isInApp = newDisplay != nil;
			if (isInApp) {
				// Entered app.
				if (isOnLockscreen) {
					// If the user immediately swiped down and now we're on lockscreen.
					[FRAME pauseHomescreen];
				}
				else {
					// Thankfully we're still in the app.
					cancelCountdown();
					[FRAME pauseHomescreen];
					[FRAME pauseSharedPlayer];
				}
			}
			else {
				// Left app.
				rescheduleCountdown();
				isInApp = false;
				[FRAME playHomescreen];
			}
		}
	%end

	// Control for Siri.
	// This is in place of listening for audio session interruption notifications, which are not sent properly.
	%hook SBAssistantRootViewController
		- (void) viewWillDisappear: (BOOL) animated {
			%orig;

			if (isOnLockscreen) // Play lockscreen.
				[FRAME playLockscreen];
			else if (!isInApp || !FRAME.pauseInApps) // Play homescreen if we're not in app OR FRAME doesn't pause in apps.
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
				// Leaving an app.
				if (isInApp) {
					isInApp = NO;
					[FRAME playHomescreen];
				}
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
			setIsOnLockscreen(true);
			// Ignore if this is triggered on sleep.
			// Otherwise eagerly play.
			if (!isAsleep) {
				[FRAME playLockscreen];
			}
		}

		- (void) viewDidAppear: (BOOL) animated {
			%orig;
			// Ignore if this is triggered on sleep.
			if (!isAsleep) {
				[FRAME pauseHomescreen];
			}
		}

		- (void) viewWillDisappear: (BOOL) animated {
			%orig;
			if (!FRAME.pauseInApps || !isInApp) {
				[FRAME playHomescreen];
			}
		}

		- (void) viewDidDisappear: (BOOL) animated {
			%orig;
			setIsOnLockscreen(false);
			[FRAME pauseLockscreen];
			// Additonal check to prevent situations where a shared FRAME is set
			// and when the user dismisses the cover sheet it doesn't stop playing.
			if (isInApp && FRAME.pauseInApps)
				[FRAME pauseSharedPlayer];				
		}

	%end

	// The code below is for "Fade".

	// Timer-managed on/off, coupled with hooking SBIconScrollView below.
	// Also resource folder access checking.
	%hook SBHomeScreenViewController

	- (void) viewDidAppear: (bool) animated {
			%orig;
			// Here we check the resource folder and alert user if there's an error.
			static bool checkedFolder = false;
			if (!checkedFolder) {
				checkResourceFolder(self);
				checkedFolder = true;
			}
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

		void setIsOnLockscreen(bool v) {
			// Check duplicative sets.
			if (isOnLockscreen == v)
				return;
			
			isOnLockscreen = v;
			if (!isOnLockscreen && !isInApp) {
				// Do something since we're on homescreen.
				rescheduleCountdown();
			}
			else if (isOnLockscreen) {
				cancelCountdown();
			}
		}

		// Begin timer.
		- (void) viewWillAppear: (bool) animated {
			%orig;
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
		- (void) didMoveToWindow {
			%orig;
			[NSNotificationCenter.defaultCenter addObserverForName: @"Fade" object: nil
            queue: NSOperationQueue.mainQueue usingBlock: ^(NSNotification *notification) {
				[UIView animateWithDuration: 0.3 animations: ^() {
					self.alpha = [notification.object boolValue] ? FRAME.fadeAlpha : 1.0;
				}];
			}];
		}
	%end

	// Touch-triggered timer delays, intercepted from the horizontal pan gesture recognizer.
	%hook SBIconScrollView

		- (void) didMoveToWindow {
			%orig;
			// // Create a receiver obj and retain it.
			// _Receiver *obj = [[_Receiver alloc] init];
			// objc_setAssociatedObject(self, _cmd, obj, OBJC_ASSOCIATION_RETAIN);
			// Add tap gesture.
			[self addGestureRecognizer: [[UITapGestureRecognizer alloc] initWithTarget: self action: @selector(didTap:)]];
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
				cancelCountdown();
				rescheduleCountdown();
			}
		}

	%end

	// Hook status bar with fade.
	%hook _UIStatusBar
		- (id) initWithStyle: (long long) arg1 {
			[NSNotificationCenter.defaultCenter addObserverForName: @"Fade" object: nil
            queue: NSOperationQueue.mainQueue usingBlock: ^(NSNotification *notification) {
				[UIView animateWithDuration: 0.3 animations: ^() {
					self.alpha = [notification.object boolValue] ? FRAME.fadeAlpha : 1.0;
				}];
			}];
			return %orig;
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
			setIsOnLockscreen(true);
						// Ignore if this is triggered on sleep.
			// Otherwise eagerly play.
			if (!isAsleep) {
				[FRAME playLockscreen];
			}
		}

		- (void) viewDidAppear: (BOOL) animated {
			%orig;
						// Ignore if this is triggered on sleep.
			if (!isAsleep) {
				[FRAME pauseHomescreen];
			}
		}

		- (void) viewWillDisappear: (BOOL) animated {
			%orig;
			if (!FRAME.pauseInApps || !isInApp) {
				[FRAME playHomescreen];
			}
		}

		- (void) viewDidDisappear: (BOOL) animated {
			%orig;
			setIsOnLockscreen(false);
						// Pause if FRAME's only enabled on lockscreen.
			[FRAME pauseLockscreen];
			// Additonal check to prevent situations where a shared FRAME is set
			// and when the user dismisses the cover sheet it doesn't stop playing.
			if (isInApp && FRAME.pauseInApps)
				[FRAME pauseSharedPlayer];		
		}

	%end

%end

// Sleep/wake detection for iPads.
%group iPad
	// Sleep / wake controls.
	%hook FBDisplayLayoutTransition

		// More reliable control for sleep / wait.
		// Accounts for cases where no wake animation is required.
		-(void) setBacklightLevel: (long long) level {
			%orig(level);
			// Determine whether screen is on.
			bool isAwake = level != 0.0;
			// Update global var.
			isAsleep = !isAwake;
			// Play / pause.
			if (isAwake) {
				[FRAME playLockscreen];
			}
			else {
				[FRAME pause];
			}
		}
	
	%end
%end

// Sleep/wake detection for iPhones.
%group iPhone
	%hook SBScreenWakeAnimationController
		// Pause FRAME during sleep.
		-(void) sleepForSource: (long long)arg1 target: (id)arg2 completion: (id)arg3 {
			%orig;
			isAsleep = YES;
			[FRAME pause];
		}
		// Resume FRAME when awake.
		// Note that this does not overlap with when coversheet appears.
		-(void) prepareToWakeForSource: (long long)arg1 timeAlpha: (double)arg2 statusBarAlpha: (double)arg3 target: (id)arg4 completion: (id)arg5 {
			%orig;
			isAsleep = NO;
			[FRAME playLockscreen];
		}
	%end
%end

void respringCallback(CFNotificationCenterRef center, void * observer, CFStringRef name, void const * object, CFDictionaryRef userInfo) {
	[[%c(FBSystemService) sharedInstance] exitAndRelaunch: true];
}

void videoChangedCallback(CFNotificationCenterRef center, void * observer, CFStringRef name, void const * object, CFDictionaryRef userInfo) {
	[FRAME reloadPlayers];
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
	dlopen("/usr/lib/LookinServer.framework/LookinServer", RTLD_NOW);

	// Create the resource folder if necessary & update permissions.
	createResourceFolder();

	%init(Tweak);

	if ([[[UIDevice currentDevice] systemVersion] floatValue] < 13.0) {
		%init(Fallback);
	}

	if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
		%init(iPad)
	}
	else {
		%init(iPhone)
	}

	NSLog(@"[Frame]: Initialized %@", FRAME);

	// Listen for respring requests from pref.
	CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
	CFNotificationCenterAddObserver(center, nil, respringCallback, CFSTR("com.ZX02.framepreferences.respring"), nil, nil);
	CFNotificationCenterAddObserver(center, nil, videoChangedCallback, CFSTR("com.ZX02.framepreferences.videoChanged"), nil, nil);
}