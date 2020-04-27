#import "ZX2WallpaperView.h"
#import "ZX2ChooseWallpaperViewController.h"
#import "Globals.h"

@implementation ZX2WallpaperView

  // Simple init.
  - (id) initWithScreen: (NSString *) screenName {
    self = [super init];
    screen = screenName;
    [self initUI];
    [self setupLayout];
    return self;
  }

  - (void) initUI {
    // Configure self.
    self.layer.masksToBounds = true;

    // Setup the playerLayers.
    playerLayer = [AVPlayerLayer playerLayerWithPlayer: nil];
    playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;

    // Set bg color;
    if (@available(iOS 13, *))
			playerLayer.backgroundColor = UIColor.secondarySystemBackgroundColor.CGColor;
		else
			playerLayer.backgroundColor = UIColor.lightGrayColor.CGColor;
    [self.layer addSublayer: playerLayer];

    // Setup buttons.
    // Delete button.
    deleteButton = [UIButton buttonWithType: UIButtonTypeCustom];
    deleteButton.translatesAutoresizingMaskIntoConstraints = false;
    deleteButton.layer.cornerRadius = 8;
    [deleteButton setImage: deleteIcon forState: UIControlStateNormal];
    [deleteButton addTarget: self action: @selector(deleteButtonTapped:) forControlEvents: UIControlEventTouchUpInside];

    // Mute button.
    muteButton = [UIButton buttonWithType: UIButtonTypeCustom];
    muteButton.translatesAutoresizingMaskIntoConstraints = false;
    muteButton.layer.cornerRadius = 8;
    [muteButton setImage: self.muted ? mutedIcon : unmutedIcon forState: UIControlStateNormal];
    [muteButton addTarget: self action: @selector(muteButtonTapped:) forControlEvents: UIControlEventTouchUpInside];

    // Configure bg & tint colors.
    if (@available(iOS 13, *)) {
      deleteButton.backgroundColor = muteButton.backgroundColor = UIColor.tertiarySystemBackgroundColor;
      deleteButton.tintColor = muteButton.tintColor = UIColor.labelColor;
    }
		else {
      deleteButton.backgroundColor = muteButton.backgroundColor = UIColor.grayColor;
      deleteButton.tintColor = muteButton.tintColor = UIColor.whiteColor;
    }

    // Add edge insets.
    muteButton.imageEdgeInsets = deleteButton.imageEdgeInsets = UIEdgeInsetsMake(4, 4, 4, 4);
  }

  - (void) setupLayout {
    // Fill bg with playerLayer.
    playerLayer.frame = self.bounds;

    // Position buttons.
    // Delete button at bottom left.
    [self addSubview: deleteButton];
    [deleteButton.widthAnchor constraintEqualToConstant: 32].active = true;
    [deleteButton.heightAnchor constraintEqualToConstant: 32].active = true;
    [deleteButton.leadingAnchor constraintEqualToSystemSpacingAfterAnchor: self.leadingAnchor multiplier: 1].active = true;
    [self.bottomAnchor constraintEqualToSystemSpacingBelowAnchor: deleteButton.bottomAnchor multiplier: 1].active = true;

    // Mute button at bottom right.
    [self addSubview: muteButton];
    [muteButton.widthAnchor constraintEqualToConstant: 32].active = true;
    [muteButton.heightAnchor constraintEqualToConstant: 32].active = true;
    [self.trailingAnchor constraintEqualToSystemSpacingAfterAnchor: muteButton.trailingAnchor multiplier: 1].active = true;
    [self.bottomAnchor constraintEqualToSystemSpacingBelowAnchor: muteButton.bottomAnchor multiplier: 1].active = true;
  }

  // Actions for their respective buttons.
  - (void) deleteButtonTapped: (UIButton *) sender {
    // No effect if this preview is empty.
    if (self.player == nil)
      return;
    [self.parentVC setVideoURL: nil withKey: screen];
  }

  - (void) muteButtonTapped: (UIButton *) sender {
    self.muted = !self.muted;

    // Toggle muted button with animation.
    [UIView transitionWithView: sender
            duration: 0.3
            options: UIViewAnimationOptionTransitionCrossDissolve
            animations: ^ {
              [muteButton setImage: self.muted ? mutedIcon : unmutedIcon forState: UIControlStateNormal];
            }
            completion: nil];
  }

  - (void) layoutSubviews {
    [super layoutSubviews];
    // Resize playerLayer to self.bounds.
    playerLayer.frame = self.bounds;
  }

  // Getter & setter for player property.
  - (AVPlayer *) getPlayer {
    return playerLayer.player;
  }

  - (void) setPlayer: (AVPlayer *) player {
    playerLayer.player = player;
  }

  // Getter & setter for muted property.
  - (bool) getMuted {
    return [bundleDefaultsShared boolForKey: [@"muted" stringByAppendingString: screen]];
  }

  - (void) setMuted: (bool) flag {
    [bundleDefaultsShared setBool: flag forKey: [@"muted" stringByAppendingString: screen]];
  }

@end