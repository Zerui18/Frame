#include "UIView+.h"

@implementation UIView (X)

	// Gets an array of subviews of the specified class.
	- (NSArray<UIView *> *) subviewsOfClass: (Class) mClass {
		return [self.subviews filteredArrayUsingPredicate: [NSPredicate predicateWithBlock: ^BOOL(id view, NSDictionary *bindings) {
			return [view isKindOfClass: mClass];
		}]];
	}

	// Gets the first subview of the specified class.
	- (UIView *) subviewOfClass: (Class) mClass {
		return [self subviewsOfClass: mClass].firstObject;
	}

@end