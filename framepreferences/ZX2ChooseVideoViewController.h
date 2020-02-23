#import <AVFoundation/AVFoundation.h>
#import "ZX2WallpaperView.h"

@interface ZX2ChooseVideoViewController : UIViewController <UIDocumentPickerDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate> {

  UILabel *lockscreenLabel;
  UILabel *homescreenLabel;

  ZX2WallpaperView *lockscreenPreview;
  ZX2WallpaperView *homescreenPreview;

  UIButton *chooseWallpaperButton;

  AVPlayerLooper *lockscreenLooper;
  AVPlayerLooper *homescreenLooper;
  AVPlayerLooper *sharedLooper;

  AVQueuePlayer *lockscreenPlayer;
  AVQueuePlayer *homescreenPlayer;
  AVQueuePlayer *sharedPlayer;

  UIImage *mutedIcon;
  UIImage *unmutedIcon;
  UIImage *deleteIcon;

}

- (void) setVideoURL: (NSURL *) videoURLOri withKey: (NSString *) key forKeyPath: (NSString *) keyPath;

@end