#import "Globals.h"

NSUserDefaults *bundleDefaultsShared;

CGFloat min(CGFloat a, CGFloat b) {
  return a < b ? a : b;
}

// Helper function that loads a UIImage from the png of the given bundle with the given filename.
UIImage *loadImage(NSBundle *bundle, NSString *name) {
  NSString *imagePath = [bundle pathForResource: name ofType: @"png"];
  if (imagePath == nil)
    return nil;
  UIImage *image = [UIImage imageWithContentsOfFile: imagePath];
  if (image == nil)
    return nil;
  return [image imageWithRenderingMode: UIImageRenderingModeAlwaysTemplate]; 
}

// Icons cache.
UIImage *mutedIcon;
UIImage *unmutedIcon;
UIImage *deleteIcon;