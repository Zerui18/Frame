#import <AVFoundation/AVFoundation.h>

@class ZX2ChooseVideoViewController;

// View representing lock/home screen preview & settings.
@interface ZX2WallpaperView : UIView {
  AVPlayerLayer *playerLayer;
  
  UIButton *deleteButton;
  UIButton *muteButton;

  NSString *screen;
}

// The player backing the playerLayer.
@property(getter=getPlayer, setter=setPlayer:, nonatomic) AVPlayer *player;
// The keyPath in bundleDefaults that represents the current video.
@property NSString *videoKeyPath;
// The parent view controller.
@property(assign) ZX2ChooseVideoViewController *parentVC;
// Bool indicating whether this screen is muted.
@property(getter=getMuted, setter=setMuted:, nonatomic) bool muted;

- (id) initWithScreen: (NSString *) screenName;
@end