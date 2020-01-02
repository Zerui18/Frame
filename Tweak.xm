#import <AVFoundation/AVFoundation.h>
#import <version.h>
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
			// load video url from preferences
			[bundleDefaults addObserver: self forKeyPath: @"videoURL" options: NSKeyValueObservingOptionNew context: nil];
			[bundleDefaults addObserver: self forKeyPath: @"isMute" options: NSKeyValueObservingOptionNew context: nil];
			[bundleDefaults addObserver: self forKeyPath: @"pauseInApps" options: NSKeyValueObservingOptionNew context: nil];
			[self loadPreferences];
			return self;
		}

		// Retrieves and sets values from preferences.
		- (void) loadPreferences {
			self.videoURL = [bundleDefaults URLForKey: @"videoURL"];
			self.player.muted = [bundleDefaults boolForKey: @"isMute"];
			self.pauseInApps = [bundleDefaults boolForKey: @"pauseInApps"];
		}

		// Bundle defaults KVO.
		- (void) observeValueForKeyPath: (NSString *)keyPath ofObject: (id)object change: (NSDictionary *)change context: (void *)context {
			if ([keyPath isEqualToString: @"videoURL"]) {
				NSString *newPath = (NSString *) [change valueForKey: NSKeyValueChangeNewKey];
				if (newPath == nil)
					return;
				NSURL *newURL = [NSURL fileURLWithPath: newPath];
				self.videoURL = newURL;
			}
			else if ([keyPath isEqualToString: @"isMute"]) {
				BOOL newFlag = [[change valueForKey: NSKeyValueChangeNewKey] boolValue];
				self.player.muted = newFlag;
			}
			else if ([keyPath isEqualToString: @"pauseInApps"]) {
				BOOL newFlag = [[change valueForKey: NSKeyValueChangeNewKey] boolValue];
				self.pauseInApps = newFlag;
			}
		}

		// Custom videoURL setter.
		- (void) setVideoURL: (NSURL *)url {
			_videoURL = url;
			[self loadVideo];
		}

		// Setup the player with the current videoURL.
		- (void) loadVideo {
			if (self.videoURL == nil)
				return;
			self.playerItem = [AVPlayerItem playerItemWithURL: self.videoURL];
			self.looper = [AVPlayerLooper playerLooperWithPlayer: self.player templateItem: self.playerItem];
			[self play];
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
	@end

	@interface CSCoverSheetViewController : UIViewController
	@end

	@interface SBCoverSheetPanelBackgroundContainerView : UIView
	@end

	@interface _SBWallpaperWindow : UIWindow
	@end

	@interface SBCoverSheetWindow : UIWindow
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

	// Hook SBWallpaperView to universally overlay our player.
	%hook SBFWallpaperView
		// Hook layoutSubviews to run our init once system has added its stock subviews.
		- (void) layoutSubviews {

			// These 2 are sufficient when device is using dynamic wallpapers.
			if (!([self.window isKindOfClass: [%c(_SBWallpaperWindow) class]] || [self.window isKindOfClass: [%c(SBCoverSheetWindow) class]])) {
				return %orig;
			}

			// Attempts to load associated AVPlayerLayer.
			AVPlayerLayer *playerLayer = (AVPlayerLayer *) objc_getAssociatedObject(self, _cmd);
			
			// No existing playerLayer? Init
			if (playerLayer == nil) {
				NSLog(@"Added in : %@", self);
				// Remove all existing subviews.
				for (UIView *view in self.subviews) {
					[view removeFromSuperview];
				}
				// Setup Player.
				playerLayer = [[%c(WallPlayer) shared] addInView: self];
				objc_setAssociatedObject(self, _cmd, playerLayer, OBJC_ASSOCIATION_ASSIGN);
			}

			// Send playerLayer to front and match its frame to that of the current view.
			[self.layer addSublayer: playerLayer];
			playerLayer.frame = self.bounds;
			return %orig;
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
			// Do not apply blur view if this effect view is not meant for it.
			// Wallpaper style 29 -> icon component blur
			if (self.wallpaperStyle != 29)
				return;
			[self.blurView removeFromSuperview];
			UIView *newBlurView;
			if (@available(iOS 13.0, *))
				newBlurView = [[UIVisualEffectView alloc] initWithEffect: [UIBlurEffect effectWithStyle: UIBlurEffectStyleSystemUltraThinMaterial]];
			else
				newBlurView = [[UIVisualEffectView alloc] initWithEffect: [UIBlurEffect effectWithStyle: UIBlurEffectStyleExtraLight]];
			newBlurView.frame = self.bounds;
			[self addSubview: newBlurView];
		}
	%end

	// Disable dynamic wallpaper's animations to improve performance.
	@interface SBFBokehWallpaperView : UIView
		-(void)_toggleCircleAnimations:(BOOL)arg1;
	@end

	@interface SBFProceduralWallpaperView : UIView
		-(void)setContinuousColorSamplingEnabled:(BOOL)arg1 ;
		-(void)setWallpaperAnimationEnabled:(BOOL)arg1 ;
	@end

	%hook SBFBokehWallpaperView
		-(void) _screenDidUpdate {
		}

		-(void) _addBokehCircles:(long long)arg1 {
		}
	%end

	%hook SBFProceduralWallpaperView
		-(void) didMoveToWindow {
			%orig;
			[self setContinuousColorSamplingEnabled: NO];
			[self setWallpaperAnimationEnabled: NO];
		}

		-(void)setContinuousColorSamplingEnabled:(BOOL)arg1 {
			%orig(NO);
		}

		-(void)setWallpaperAnimationEnabled:(BOOL)arg1 {
			%orig(NO);
		}
	%end

	// Coordinate the WallPlayer with SpringBoard.
	// Pause player when an application opens.
	// Resume player when the homescreen is shown.
	@interface SpringBoard : NSObject
	@end

	%hook SpringBoard
		-(void) frontDisplayDidChange: (id)newDisplay {
			%orig;
			WallPlayer *player = [%c(WallPlayer) shared];
			if (newDisplay == nil) {
				isInApp = NO;
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
		-(void) viewWillAppear: (BOOL) animated {
			%orig;
			// do not play if this is triggered on sleep
			if (isAsleep)
				return;
			WallPlayer *player = [%c(WallPlayer) shared];
			[player play];
		}
	%end

	%hook SBScreenWakeAnimationController
		// Pause player during sleep.
		-(void) sleepForSource: (long long)arg1 target: (id)arg2 completion: (id)arg3 {
			%orig;
			isAsleep = YES;
			WallPlayer *player = [%c(WallPlayer) shared];
			[player pause];
		}
		// Resume player when awake.
		// Note that this does not overlap with when coversheet appears.
		-(void) prepareToWakeForSource: (long long)arg1 timeAlpha: (double)arg2 statusBarAlpha: (double)arg3 target: (id)arg4 completion: (id)arg5 {
			%orig;
			isAsleep = NO;
			WallPlayer *player = [%c(WallPlayer) shared];
			[player play];
		}
	%end

	// Resume player after Siri dismisses.
	// This is in place of listening for audio session interruption notifications, which are not sent properly.
	%hook SBAssistantRootViewController
		- (void) viewWillDisappear: (BOOL) animated {
			%orig;
			WallPlayer *player = [%c(WallPlayer) shared];
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
	BOOL isEnabled = [bundleDefaults boolForKey: @"isEnabled"];
	if (isEnabled)
		%init(Tweak);

	// Listen for respring requests from pref.
	CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
	CFNotificationCenterAddObserver(center, nil, notifyCallback, CFSTR("com.Zerui.framepreferences.respring"), nil, nil);
}