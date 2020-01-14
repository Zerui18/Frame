#import <Preferences/PSListController.h>

@interface ZX2RootListController : PSListController <UIDocumentPickerDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate> {
    NSUserDefaults *bundleDefaults;
}
@property(getter=getVideoPath, setter=setVideoPath:, nonatomic) NSURL *videoPath;
-(NSURL *) getVideoURL;
-(void) setVideoURL: (NSURL *) url;
@end
