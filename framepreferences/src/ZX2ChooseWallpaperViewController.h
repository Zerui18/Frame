#import <AVFoundation/AVFoundation.h>
#import <Preferences/PSViewController.h>
#import "ZX2WallpaperView.h"

@interface ZX2ChooseWallpaperViewController : PSViewController <UIDocumentPickerDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate> {

  UILabel *lockscreenLabel;
  UILabel *homescreenLabel;

  ZX2WallpaperView *lockscreenPreview;
  ZX2WallpaperView *homescreenPreview;

  UIButton *chooseWallpaperButton;
  UIButton *getWallpaperButton;

  AVPlayerLooper *lockscreenLooper;
  AVPlayerLooper *homescreenLooper;
  AVPlayerLooper *sharedLooper;

  AVQueuePlayer *lockscreenPlayer;
  AVQueuePlayer *homescreenPlayer;
  AVQueuePlayer *sharedPlayer;

  UIImage *mutedIcon;
  UIImage *unmutedIcon;
  UIImage *deleteIcon;

  UILabel *moreVideosLabel;

}

- (void) didSelectVideo: (NSURL *) videoURL;
- (void) setVideoURL: (NSURL *) videoURLOri withKey: (NSString *) key;
- (void) openAltCatalogue;

@end