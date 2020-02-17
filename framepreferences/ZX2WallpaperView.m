#import "ZX2WallpaperView.h"
#import "ZX2ChooseVideoViewController.h"

@implementation ZX2WallpaperView

  - (id) initWithVC: (ZX2ChooseVideoViewController *) vc isSecondaryPreview: (bool) flag {
    self = [super init];
    parentVC = vc;
    isSecondaryPreview = flag;

    // Configure self.
    self.layer.masksToBounds = true;
    self.userInteractionEnabled = true;
    [self addGestureRecognizer: [[UITapGestureRecognizer alloc] initWithTarget: self action: @selector(handleTap:)]];

    // Setup the playerLayers.
    playerLayer = [AVPlayerLayer playerLayerWithPlayer: isSecondaryPreview ? vc.secondaryPlayer : vc.primaryPlayer];
    playerLayer.frame = self.bounds;
    playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    if (@available(iOS 13, *))
			playerLayer.backgroundColor = UIColor.tertiarySystemBackgroundColor.CGColor;
		else
			playerLayer.backgroundColor = UIColor.grayColor.CGColor;
    [self.layer addSublayer: playerLayer];

    return self;
  }

  - (void) layoutSubviews {
    [super layoutSubviews];
    // Resize playerLayer to self.bounds.
    playerLayer.frame = self.bounds;
  }

  - (void) handleTap: (UITapGestureRecognizer *) sender {
    parentVC.keyToSet = isSecondaryPreview ? @"secVideoURL" : @"videoURL";
    [parentVC chooseVideo];
  }

@end