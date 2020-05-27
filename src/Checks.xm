#import "Checks.h"
#import "Frame.h"

void presentAlert(UIViewController *presenterVC, NSString *errorMessage, NSString *errorCode, bool *hasAlerted) {
  if (*hasAlerted)
    return;
  // Try to find a presenterVC if provided with nil.
  if (presenterVC == nil)
    presenterVC = homeScreenVC;
  UIAlertController *alertVC = [UIAlertController alertControllerWithTitle: @"Frame - Tweak"
                                message: errorMessage
                                preferredStyle: UIAlertControllerStyleAlert];
  [alertVC addAction: [UIAlertAction actionWithTitle: @"Details" style: UIAlertActionStyleDefault handler: ^(UIAlertAction *action) {
    NSString *url = [@"https://zerui18.github.io/zx02#err=" stringByAppendingString: errorCode];
    [[UIApplication sharedApplication] openURL: [NSURL URLWithString: url] options:@{} completionHandler: nil];
  }]];
  [alertVC addAction: [UIAlertAction actionWithTitle: @"Ignore" style: UIAlertActionStyleCancel handler: nil]];
  if (presenterVC != nil) {
    [presenterVC presentViewController: alertVC animated: true completion: nil];
    *hasAlerted = true;
  }
}

static bool checkResourceAlerted = false;

// Check for folder access, otherwise warn user.
void checkResourceFolder(UIViewController *presenterVC) {
	NSString *testFile = @"/var/mobile/Documents/com.ZX02.Frame/.test.txt";

	// Try to write to a test file.
	NSString *str = @"Please do not delete this folder.";
	NSError *err;
	[str writeToFile: testFile atomically: true encoding: NSUTF8StringEncoding error: &err];

	if (err != nil) {
    presentAlert(presenterVC, @"Resource folder can't be accessed.", @"frame.resAccess", &checkResourceAlerted);
	}
}

static bool checkWPSettingsAlerted = false;

void checkWPSettings(UIViewController *presenterVC) {
  SBWallpaperController *ctr = [%c(SBWallpaperController) sharedInstance];
  if ([FRAME requiresDifferentSystemWallpapers] && ctr.sharedWallpaperView != nil) {
    // Always present this alert.
    checkWPSettingsAlerted = false;
    presentAlert(presenterVC, @"You have chosen different videos for lockscreen & homescreen, but you will need to set different system wallpapers for lockscreen & homescreen for this to take effect.", @"frame.sysConfig", &checkWPSettingsAlerted);
  }
}