#import <UIKit/UIKit.h>

// Class decls.
@interface SBFWallpaperView : UIView
    @property (nonatomic, retain) UIView *contentView;
@end

@interface CSCoverSheetViewController : UIViewController
@end

@interface SBCoverSheetPanelBackgroundContainerView : UIView
@end

@interface _SBWallpaperWindow : UIWindow
@end

@interface SBCoverSheetWindow : UIWindow
@end

@interface SBReachabilityWindow : UIWindow
@end

// Category for getting the parent view controller of the receiver view.
// https://stackoverflow.com/a/24590678
@interface UIView (mxcl)
    - (UIViewController *) parentViewController;
@end

@implementation UIView (mxcl)
    - (UIViewController *) parentViewController {
        UIResponder *responder = self;
        while ([responder isKindOfClass:[UIView class]])
            responder = [responder nextResponder];
        return (UIViewController *)responder;
    }
@end

@interface SBWallpaperController
    + (id)sharedInstance;
    @property(retain, nonatomic) SBFWallpaperView *sharedWallpaperView;
    @property(retain, nonatomic) SBFWallpaperView *homescreenWallpaperView;
    @property(retain, nonatomic) SBFWallpaperView *lockscreenWallpaperView;
@end

@interface SBWallpaperEffectView : UIView
    @property (nonatomic,retain) UIView* blurView;
    @property (assign,nonatomic) long long wallpaperStyle; 
@end

@interface SBLayoutState
@property (nonatomic,readonly) NSSet * elements;
@end

@interface SBLayoutStateTransitionContext
@property (nonatomic,readonly) SBLayoutState * fromLayoutState;
@property (nonatomic,readonly) SBLayoutState * toLayoutState;    
@end

@interface SBFolderIconImageView : UIView
@end