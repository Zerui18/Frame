#import "ZX2RootListController.h"
#import "ZX2ChooseWallpaperViewController.h"
#import "Globals.h"
#import <framepreferences-Swift.h>

// Check for folder access, otherwise warn user.
void checkResourceFolder(UIViewController *presenterVC) {
	NSString *testFile = @"/var/mobile/Documents/com.ZX02.Frame/.test.txt";

	// Try to write to a test file.
	NSString *str = @"Please do not delete this folder.";
	NSError *err;
	[str writeToFile: testFile atomically: true encoding: NSUTF8StringEncoding error: &err];

	if (err != nil) {
		UIAlertController *alertVC = [UIAlertController alertControllerWithTitle: @"Frame - Tweak"
													message: @"Resource folder can't be accessed."
													preferredStyle: UIAlertControllerStyleAlert];
		[alertVC addAction: [UIAlertAction actionWithTitle: @"Details" style: UIAlertActionStyleDefault handler: ^(UIAlertAction *action) {
			[[UIApplication sharedApplication] openURL: [NSURL URLWithString:@"https://zerui18.github.io/zx02#err=frame.resAccess"] options:@{} completionHandler: nil];
		}]];
		[alertVC addAction: [UIAlertAction actionWithTitle: @"Ignore" style: UIAlertActionStyleCancel handler: nil]];
		[presenterVC presentViewController: alertVC animated: true completion: nil];
	}
}

@implementation ZX2RootListController

	- (NSArray *) specifiers {
		if (!_specifiers) {
			_specifiers = [self loadSpecifiersFromPlistName: @"Root" target:self];
		}
		bundleDefaults = [[NSUserDefaults alloc] initWithSuiteName: @"com.Zerui.framepreferences"];
		[bundleDefaults registerDefaults: @{ @"mutedHomescreen" : @true, @"mutedLockscreen" : @true }];

		bundleDefaultsShared = bundleDefaults;

		// Load & cache icons which might come into use later.
		NSBundle *bundle = [NSBundle bundleForClass: [ZX2ChooseWallpaperViewController class]];
		mutedIcon = loadImage(bundle, @"muted");
		unmutedIcon = loadImage(bundle, @"unmuted");
		deleteIcon = loadImage(bundle, @"delete");

		return _specifiers;
	}

	- (void) viewDidAppear: (bool) animated {
		[super viewDidAppear: animated];
		checkResourceFolder(self);
	}

	- (void) respring {
		CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
		CFStringRef str = (__bridge CFStringRef) @"com.zx02.framepreferences.respring";
		CFNotificationCenterPostNotification(center, str, nil, nil, true);
	}

	- (void) presentChooseVC {
		PSViewController *vc = [[ZX2ChooseWallpaperViewController alloc] init];
		[self pushController: vc animate: true];
	}

@end
