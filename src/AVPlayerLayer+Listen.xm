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
    [NSNotificationCenter.defaultCenter addObserverForName: @"PlayerChanged" object: nil
        queue: NSOperationQueue.mainQueue usingBlock: ^(NSNotification *notification) {

      // Check if this notification is meant for this layer.
      NSString *screen = [notification.userInfo objectForKey: @"screen"];
      if ([screen isEqualToString: kBothscreens] || [screen isEqualToString: self.screen]) {
        self.player = nil;

        // Get the newPlayer.
        AVPlayer *newPlayer = (AVPlayer *)[notification.userInfo objectForKey: @"player"];
        
        // Update hidden.
        self.hidden = newPlayer == nil;

        // Hide the original wallpaper view if playerLayer is configured.
        UIView *originalWPView = (UIView *) [self valueForKey: @"originalWPView"];
        originalWPView.hidden = newPlayer != nil;

        if (newPlayer != nil) {
          // Delay to allow the layer to "rest", thus preventing it from not rendering anything when the actual player plays.
          dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.player = newPlayer;
          });
        }

      }

    }];
  }


@end