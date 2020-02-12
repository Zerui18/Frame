#import "ZX2HookedView.h"

@interface ZX2ChooseVideoViewController : UIViewController {

  UILabel *lockscreenLabel;
  UILabel *homescreenLabel;

  ZX2HookedView *lockscreenPreview;
  ZX2HookedView *homescreenPreview;

  UIButton *showWallpaperStoreButton;

}

@end