#import "AVPlayerLayer+Listen.h"
#import "Globals.h"
#import <objc/runtime.h>

void const *screenKey;

@implementation AVPlayerLayer(X)

  // Getter & setter for self.screen.
  - (NSString *) getScreen {
    return (NSString *) objc_getAssociatedObject(self, &screenKey);
  }

  - (void) setScreen: (NSString *) screen {
    objc_setAssociatedObject(self, &screenKey, screen, OBJC_ASSOCIATION_RETAIN);
  }

  // Method to begin listening for player changed notifications.
  - (void) listenForPlayerChangedNotification {
    __weak AVPlayerLayer *weakSelf;
    [NSNotificationCenter.defaultCenter addObserverForName: @"PlayerChanged" object: nil
        queue: NSOperationQueue.mainQueue usingBlock: ^(NSNotification *notification) {
      AVPlayerLayer *strongSelf = weakSelf;
      if (strongSelf == nil)
        return;

      // Check if this notification is meant for this layer.
      NSString *screen = [notification.userInfo objectForKey: @"screen"];
      if ([screen isEqualToString: kBothscreens] || [screen isEqualToString: self.screen]) {
        strongSelf.player = (AVPlayer *)[notification.userInfo objectForKey: @"player"];
      }

      strongSelf.hidden = strongSelf.player == nil;
    }];
  }


@end