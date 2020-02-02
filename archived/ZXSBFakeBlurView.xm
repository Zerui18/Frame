#include "ZXSBFakeBlurView.h"

CGRect tmp = CGRectMake(0, 0, 0, 0);

@implementation ZXSBFakeBlurView

  - (void) drawRect: (CGRect) rect {
    if (self.blurEffectView == nil) {
      self.blurEffectView = [[UIVisualEffectView alloc] initWithEffect: [UIBlurEffect effectWithStyle: UIBlurEffectStyleRegular]];
      self.blurEffectView.frame = self.bounds;
      [self addSubview: self.blurEffectView];
    }

    [self.blurEffectView drawInRect: rect];
  }

@end