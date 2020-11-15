#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

@interface AVPlayerLayer(X)
@property(getter=getScreen, setter=setScreen:, nonatomic) NSString *screen; 
- (void) listenForPlayerChangedNotification;
@end