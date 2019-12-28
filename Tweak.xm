// Hide Control Centre Grabber
@interface CSTeachableMomentsContainerView { }
@property (nonatomic,retain) UIView * controlCenterGrabberView;
@end

%hook CSTeachableMomentsContainerView
	- (void)layoutSubviews {
		[self.controlCenterGrabberView setHidden:YES];
		return %orig;
	}
%end

// MARK: Main Tweak
#import <AVFoundation/AVFoundation.h>
%ctor {
	[[%c(AVAudioSession) sharedInstance] setCategory: AVAudioSessionCategoryPlayback withOptions: AVAudioSessionCategoryOptionMixWithOthers error: nil];
}

@interface WallPlayer: NSObject {
}

@property(setter=setVideoURL:, nonatomic) NSURL *videoURL;
@property AVPlayerItem *playerItem;
@property AVQueuePlayer *player;
@property(strong) AVPlayerLooper *looper;
@property AVPlayerLayer *playerLayer;

-(void) setVideoURL: (NSURL *) url;
-(void) loadVideo;
@end

@implementation WallPlayer {
}
-(id) init {
	self = [super init];
	self.playerItem = [AVPlayerItem playerItemWithURL: self.videoURL];
	self.player = [[AVQueuePlayer alloc] init];
	self.playerLayer = [AVPlayerLayer playerLayerWithPlayer: self.player];
	self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
	return self;
}
// Custom videoURL setter.
-(void) setVideoURL: (NSURL *)url {
	_videoURL = url;
	[self loadVideo];
}
// Setup the player with the current videoURL.
-(void) loadVideo {
	self.playerItem = [AVPlayerItem playerItemWithURL: self.videoURL];
	self.looper = [AVPlayerLooper playerLooperWithPlayer: self.player templateItem: self.playerItem];
	[self.looper addObserver: self forKeyPath: @"status" options: NSKeyValueObservingOptionNew context: nil];
	[self.player play];
}
// Add the playerLayer in the specified view's layer.
-(void) addInView: (UIView *)superview {
	[superview.layer addSublayer: self.playerLayer];
	self.playerLayer.frame = superview.bounds;
	void *key = nil;
	objc_setAssociatedObject(superview, key, self, OBJC_ASSOCIATION_RETAIN);
}

- (void)observeValueForKeyPath:(NSString *)keyPath 
                      ofObject:(id)object 
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change 
                       context:(void *)context {
	if ([keyPath isEqualToString: @"status"]) {
		NSLog(@"SEELE : Loop Status Changed : %@", change);
	}
}
@end


// Prevent the system from adding subviews to the wallpaper container view.
@interface SBFWallpaperView: UIView
@property (nonatomic,readonly) BOOL hasVideo; 
@end

%hook SBFWallpaperView
	- (void)didMoveToWindow {
		NSLog(@"SEELE: SBFWallpaperView %@ %d", self, self.hasVideo);
		if (!self.hasVideo)
			return;
		WallPlayer *player = [[WallPlayer alloc] init];
		[player setVideoURL: [[NSURL alloc] initFileURLWithPath: @"/var/mobile/Documents/wall.mp4"]];
		[player addInView: self];
	}
	- (void)addSubview:(UIView *)view {
		NSLog(@"SEELE: SBFWallpaperView add %@", view);
	}
	- (void)insertSubview:(UIView *)view 
         aboveSubview:(UIView *)siblingSubview {
		NSLog(@"SEELE: SBFWallpaperView ia %@", view);
	}
	- (void)insertSubview:(UIView *)view 
         belowSubview:(UIView *)siblingSubview {
		NSLog(@"SEELE: SBFWallpaperView ib %@", view);
	}
%end