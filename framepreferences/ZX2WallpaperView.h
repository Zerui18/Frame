#import <AVFoundation/AVFoundation.h>

@class ZX2ChooseVideoViewController;

@interface ZX2WallpaperView : UIView {
  bool isSecondaryPreview;

  AVPlayerLayer *playerLayer;

  __weak ZX2ChooseVideoViewController *parentVC;
}

- (id) initWithVC: (ZX2ChooseVideoViewController *) vc isSecondaryPreview: (bool) flag;
@end