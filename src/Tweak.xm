#import <AVFoundation/AVFoundation.h>
#import <version.h>
#import <substrate.h>
#import <dlfcn.h>
#import "SpringBoard.h"
#import "Globals.h"
#import "Frame.h"
#import "UIView+.h"
#import "DeviceStates.h"

#pragma mark - Global Vars
void const *playerLayerKey;
SBHomeScreenViewController *homeScreenVC = nil;
// The countdown timer for the fade animation.
NSTimer *timer;

#pragma mark - Global Functions

// Helper function that sets up wallpaper FRAME in the given wallpaperView.
void setupWallpaperPlayer(SBFWallpaperView *wallpaperView, bool isLockscreenView) {
	// Attempt to retrieve associated AVPlayerLayer.
	AVPlayerLayer *playerLayer = (AVPlayerLayer *) objc_getAssociatedObject(wallpaperView, &playerLayerKey);
	
	// No existing playerLayer? Init
	if (playerLayer == nil) {
		playerLayer = [FRAME addInView: wallpaperView isLockscreen: isLockscreenView];
		// Save playerLayer as an associated object of the wallpaperView.
		objc_setAssociatedObject(wallpaperView, &playerLayerKey, playerLayer, OBJC_ASSOCIATION_RETAIN);
	}
}

void adjustWallpaperPlayer(SBFWallpaperView *wallpaperView) {
	// Attempt to retrieve associated playerLayer.
	AVPlayerLayer *playerLayer = (AVPlayerLayer *) objc_getAssociatedObject(wallpaperView, &playerLayerKey);
	if (!playerLayer) return;
	// Adjust playerLayer to fit the wallpaperView.
	playerLayer.frame = wallpaperView.bounds;
}

// Functions to implement a debounced timer for the fade animation.
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

#pragma mark - Tweak
%group Main

	#pragma mark - Tweak: Add Player Layer
	%hook SBWallpaperController

		// Point of setup for wallpaper players.
		+ (id) sharedInstance {
			SBWallpaperController *ctr = %orig;

			if (!ctr) return nil;
			
			// Obtain wallpaper views.
			SBFWallpaperView *ls, *hs, *both;
			if (%c(SBWWallpaperViewController)) {
				// iOS 15.x
				SBWWallpaperViewController *vc = MSHookIvar<SBWWallpaperViewController *>(ctr, "_wallpaperViewController");
				ls = vc.lockscreenWallpaperView;
				hs = vc.homescreenWallpaperView;
				both = vc.sharedWallpaperView;
			}
			else if (%c(SBWallpaperController)) {
				// iOS 14.x
				SBWallpaperViewController *vc = MSHookIvar<SBWallpaperViewController *>(ctr, "_wallpaperViewController");
				ls = vc.lockscreenWallpaperView;
				hs = vc.homescreenWallpaperView;
				both = vc.sharedWallpaperView;
			}
			else {
				// iOS 13.x
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

		- (void) willMoveToWindow: (UIWindow *) window {
			%orig;
			// Setup wallpaper player.
			// Only do this for coversheet window, which is not covered by the SBWallpaperController hook.
			if ([window isKindOfClass: [%c(SBCoverSheetWindow) class]]) {
				setupWallpaperPlayer(self, true);
			}
		}

		- (void) layoutSubviews {
			%orig;
			if (!self.window || ![self.window isKindOfClass: [%c(SBCoverSheetWindow) class]]) return;

			// Send playerLayer to front and match its frame to that of the current view.
			// Note: for compatibility with SpringArtwork, we let SAViewController's view's layer stay atop :)
			AVPlayerLayer *playerLayer = objc_getAssociatedObject(self, &playerLayerKey);

			// Remove playerLayer from its current superlayer.
			[playerLayer removeFromSuperlayer];

			// Find SAViewController's view's layer.
			CALayer *saLayer;
			for (UIView *view in self.subviews) {
				if ([view.nextResponder isKindOfClass: [%c(SAViewController) class]]) {
					saLayer = view.layer;
					break;
				}
			}
			
			// Re-add playerLayer.
			if (saLayer != nil)
				[self.layer insertSublayer: playerLayer below: saLayer];
			else
				[self.layer addSublayer: playerLayer];
			
			// Adjust playerLayer to fit the wallpaperView.
			playerLayer.frame = self.bounds;
		}
	
	%end

	#pragma mark - Tweak: Coordination

	%hook SpringBoard

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

	%hook SBHomeScreenViewController

	- (void) viewDidAppear: (bool) animated {
			%orig;
			homeScreenVC = self;
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
	
	#pragma mark - Tweak: Fade Listeners
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

	#pragma mark - Tweak: More Fade Triggers
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

%group Empty
%end

void videoChangedCallback(CFNotificationCenterRef center, void * observer, CFStringRef name, void const * object, CFDictionaryRef userInfo) {
	[FRAME reloadPlayers];
}

// Main
%ctor {

	%init(Empty);
	%init(Main);

	if (false) {
		%init(FixBlur);
	}

	// Enable fix blur if requested.
	// if (FRAME.fixBlur) {
	// 	%init(FixBlur);
	// }

	// Force the lazy globals to init.
	NSLog(@"[Frame]: Globals %@, %@", FRAME, DeviceStates.shared);

	// Listen for respring requests from pref.
	CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
	CFNotificationCenterAddObserver(center, nil, videoChangedCallback, CFSTR("com.zx02.frame.videoChanged"), nil, nil);

	dlopen("/var/jb/Library/LookinServer.framework/LookinServer", RTLD_NOW);
	// log error if any
	char *error = dlerror();
	if (error != NULL) {
		NSLog(@"[Frame]: Error loading LookinServer: %s", error);
	}
}