#import <UIKit/UIKit.h>

// UIView category to get subviews of specified class.
@interface UIView (X)
	- (NSArray<UIView *> *) subviewsOfClass: (Class) mClass;
	- (UIView *) subviewOfClass: (Class) mClass;
@end

