#import <AVFoundation/AVFoundation.h>
#import "ZX2WallpaperView.h"

@interface ZX2ChooseVideoViewController : UIViewController <UIDocumentPickerDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate> {

  UILabel *primaryLabel;
  UILabel *secondaryLabel;

  ZX2WallpaperView *secondaryPreview;
  ZX2WallpaperView *primaryPreview;

  UIButton *showWallpaperStoreButton;

  AVPlayerLooper *primaryLooper;
  AVPlayerLooper *secondaryLooper;

}

@property NSString *keyToSet;
@property AVQueuePlayer *primaryPlayer;
@property AVQueuePlayer *secondaryPlayer;

- (void) chooseVideo;

@end