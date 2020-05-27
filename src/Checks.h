#import <UIKit/UIKit.h>
#import "SpringBoard.h"

void presentAlert(UIViewController *presenterVC, NSString *errorMessage, NSString *errorCode, bool *hasAlerted);

void checkResourceFolder(UIViewController *presenterVC);
void checkWPSettings(UIViewController *presenterVC);

extern SBHomeScreenViewController *homeScreenVC;