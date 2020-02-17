#import "ZX2RootListController.h"
#import "ZX2ChooseVideoViewController.h"
#import "Globals.h"

@implementation ZX2RootListController

	- (NSArray *) specifiers {
		if (!_specifiers) {
			_specifiers = [self loadSpecifiersFromPlistName: @"Root" target:self];
		}
		bundleDefaults = [[NSUserDefaults alloc] initWithSuiteName: @"com.Zerui.framepreferences"];
		bundleDefaultsShared = bundleDefaults;
		return _specifiers;
	}

	- (void) present: (UIViewController *) ctr {
		// Get the rootVC of the current keyWindow.
		UIWindow *keyWindow;
		NSArray *windows = [[UIApplication sharedApplication] windows];
		for (UIWindow *window in windows) {
			if (window.isKeyWindow) {
				keyWindow = window;
				break;
			}
		}
		UIViewController *rootVC = keyWindow.rootViewController;
		// Present
		[rootVC presentViewController: ctr animated: YES completion: nil];
	}

	- (void) respring {
		CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
		CFStringRef str = (__bridge CFStringRef)@"com.ZX02.framepreferences.respring";
		CFNotificationCenterPostNotification(center, str, nil, nil, YES);
	}

	- (void) presentChooseVC {
		UIViewController *vc = [[ZX2ChooseVideoViewController alloc] init];
		vc.modalPresentationStyle = UIModalPresentationFormSheet;
		[self present: vc];
	}

@end
