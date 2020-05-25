#import <UIKit/UIKit.h>

#define DEF_UIVIEW(class) @interface class : UIView \
@end

#define DEF_UIWINDOW(class) @interface class : UIWindow \
@end

#define DEF_UIVC(class) @interface class : UIViewController \
@end

// Class decls.
@interface SBFWallpaperView : UIView
@property UIView *contentView;
@end

DEF_UIVIEW(SBIconScrollView)
DEF_UIVIEW(SBIconListView)
DEF_UIVIEW(_UIStatusBar)
DEF_UIVIEW(SBIconListPageControl)

DEF_UIWINDOW(_SBWallpaperWindow)
DEF_UIWINDOW(SBCoverSheetWindow)
DEF_UIWINDOW(SBReachabilityWindow)

DEF_UIVC(CSCoverSheetViewController)
DEF_UIVC(SBDashBoardViewController)
DEF_UIVC(SBHomeScreenViewController)

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

DEF_UIVIEW(SBFolderIconImageView)