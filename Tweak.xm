// MARK: Main Tweak
#import <AVFoundation/AVFoundation.h>
#include "FBSystemService.h"

// Globals
bool isAsleep;

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

%group Tweak
	// Logical container for the AVQueuePlayer used in this tweak.
	// Manages a single instance of AVQueuePlayer that's controlled by the AVPlayerLooper.
	// Adds AVPlayerLayer to the provided views.
	@interface WallPlayer: NSObject {
		NSUserDefaults *bundleDefaults;
	}

		@property(setter=setVideoURL:, nonatomic) NSURL *videoURL;
		@property AVPlayerItem *playerItem;
		@property AVQueuePlayer *player;
		@property(strong) AVPlayerLooper *looper;

	@end

	@implementation WallPlayer
		// Shared singleton.
		+(id) shared {
			static WallPlayer *shared = nil;
			static dispatch_once_t onceToken;
			dispatch_once_on_main_thread(&onceToken, ^{
				shared = [[self alloc] init];
			});
			return shared;
		}
		// Init.
		-(id) init {
			self = [super init];
			// get bundle defaults
			bundleDefaults = [[NSUserDefaults alloc] initWithSuiteName: @"com.Zerui.framepreferences"];
			// init player
			self.player = [[AVQueuePlayer alloc] init];
			self.player.preventsDisplaySleepDuringVideoPlayback = NO;
			// set allow mixing
			AVAudioSession *session = [%c(AVAudioSession) sharedInstance];
			[session setCategory: AVAudioSessionCategoryPlayback withOptions: AVAudioSessionCategoryOptionMixWithOthers error: nil];
			[session setActive: YES withOptions: nil error: nil];
			// listen for interruptions
			NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
			[center addObserverForName: @"AVAudioSessionInterruptionNotification" object: session queue: nil usingBlock: ^(NSNotification *notification) {
				NSDictionary *userInfo = notification.userInfo;
				NSUInteger itType = (NSUInteger) [userInfo valueForKey: AVAudioSessionInterruptionTypeKey];
				if (itType == AVAudioSessionInterruptionTypeEnded) {
					NSLog(@"SEELE : Interruption Ended");
					// Interruption ended, resume player
					[self play];
				}
			}];
			// load video url from preferences
			[bundleDefaults addObserver: self forKeyPath: @"videoURL" options: NSKeyValueObservingOptionNew context: nil];
			[bundleDefaults addObserver: self forKeyPath: @"isMute" options: NSKeyValueObservingOptionNew context: nil];
			[self loadPreferences];
			return self;
		}
		// Retrieves and sets values from preferences.
		-(void) loadPreferences {
			self.videoURL = [bundleDefaults URLForKey: @"videoURL"];
			self.player.muted = [bundleDefaults boolForKey: @"isMute"];
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
				NSLog(@"SEELE : new mute val : %d", newFlag);
				self.player.muted = newFlag;
			}
		}
		// Custom videoURL setter.
		-(void) setVideoURL: (NSURL *)url {
			_videoURL = url;
			[self loadVideo];
		}
		// Setup the player with the current videoURL.
		-(void) loadVideo {
			if (self.videoURL == nil)
				return;
			self.playerItem = [AVPlayerItem playerItemWithURL: self.videoURL];
			self.looper = [AVPlayerLooper playerLooperWithPlayer: self.player templateItem: self.playerItem];
			[self.player play];
		}
		// Add a playerLayer in the specified view's layer.
		-(AVPlayerLayer *) addInView: (UIView *)superview {
			AVPlayerLayer *playerLayer = [AVPlayerLayer playerLayerWithPlayer: self.player];
			playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
			[superview.layer addSublayer: playerLayer];
			playerLayer.frame = superview.bounds;
			return playerLayer;
		}
		// Play.
		-(void) play {
			[self.player play];
		}
		// Pause.
		-(void) pause {
			[self.player pause];
		}
	@end


	// Prevent the system from adding subviews to the wallpaper container view.
	
	// Class decls.
	@interface SBFWallpaperView : UIView
		@property (nonatomic,retain) UIView * contentView;
	@end

	@interface CSCoverSheetViewController : UIViewController
	@end

	@interface _SBWallpaperWindow : UIWindow
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

	%hook _SBWallpaperWindow
		// Hook layoutSubviews to run our init once system has added its stock subviews.
		- (void) layoutSubviews {
			// Persistent var.
			static AVPlayerLayer *playerLayer;
			
			// Run our init only once.
			if (playerLayer == nil) {
				// Remove all existing subviews.
				for (UIView *view in self.subviews) {
					[view removeFromSuperview];
				}
				// Setup Player.
				playerLayer = [[%c(WallPlayer) shared] addInView: self];
			}

			// Reposition playerLayer to always fill the screen.
			playerLayer.frame = self.bounds;
			return %orig;
		}
	%end

	%hook SBFWallpaperView
		// Hook layoutSubviews to run our init once system has added its stock subviews.
		- (void) layoutSubviews {
			if (![self.parentViewController isKindOfClass: [%c(SBCoverSheetPrimarySlidingViewController) class]])
				return %orig;

			// Persistent var.
			static AVPlayerLayer *playerLayer;
			
			// Run our init only once.
			if (playerLayer == nil) {
				// Remove all existing subviews.
				for (UIView *view in self.subviews) {
					[view removeFromSuperview];
				}
				// Setup Player.
				playerLayer = [[%c(WallPlayer) shared] addInView: self];
			}

			// Reposition playerLayer to always fill the screen.
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
			// Do not apply blue view if this effect view is not meant for it.
			// Wallpaper style 29 -> icon component blur
			if (self.wallpaperStyle != 29)
				return;
			[self.blurView removeFromSuperview];
			UIView *newBlueView = [[UIVisualEffectView alloc] initWithEffect: [UIBlurEffect effectWithStyle: UIBlurEffectStyleSystemUltraThinMaterial]];
			newBlueView.frame = self.bounds;
			[self addSubview: newBlueView];
		}
	%end

	// Coordinate the WallPlayer with SpringBoard.
	// Pause player when an application opens.
	// Resume player when the homescreen is shown.
	@interface SpringBoard : NSObject
	@end

	%hook SpringBoard
		-(void) frontDisplayDidChange: (id)newDisplay {
			WallPlayer *player = [%c(WallPlayer) shared];
			if (newDisplay == nil) {
				[player play];
			}
			else
				[player pause];
			return %orig;
		}
	%end

	// Resume player whenever coversheet will be shown.
	%hook CSCoverSheetViewController
		-(void) viewWillAppear: (BOOL) animated {
			// do not play if this is triggered on sleep
			if (isAsleep)
				return;
			WallPlayer *player = [%c(WallPlayer) shared];
			[player play];
			return %orig;
		}
	%end

	%hook SBScreenWakeAnimationController
		// Pause player during sleep.
		-(void)sleepForSource:(long long)arg1 target:(id)arg2 completion:(/*^block*/id)arg3 {
			isAsleep = YES;
			WallPlayer *player = [%c(WallPlayer) shared];
			[player pause];
			return %orig;
		}
		// Resume player when awake.
		// Note that this does not overlap with when coversheet appears.
		-(void)prepareToWakeForSource:(long long)arg1 timeAlpha:(double)arg2 statusBarAlpha:(double)arg3 target:(id)arg4 completion:(/*^block*/id)arg5 {
			isAsleep = NO;
			WallPlayer *player = [%c(WallPlayer) shared];
			[player play];
			return %orig;
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