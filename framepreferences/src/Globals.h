#import <UIKit/UIKit.h>

NSUserDefaults *bundleDefaultsShared;
UIImage *mutedIcon;
UIImage *unmutedIcon;
UIImage *deleteIcon;

CGFloat min(CGFloat a, CGFloat b);
@class ZX2ChooseWallpaperViewController;

UIImage *loadImage(NSBundle *bundle, NSString *name);

FOUNDATION_EXPORT NSString *const kLockscreen;
FOUNDATION_EXPORT NSString *const kHomescreen;
FOUNDATION_EXPORT NSString *const kBothscreens;