#import "ZX2RootListController.h"
#import "ZX2ChooseWallpaperViewController.h"
#import "Globals.h"
#import <framepreferences-Swift.h>

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

	- (void) respring {
		CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
		CFStringRef str = (__bridge CFStringRef) @"com.ZX02.framepreferences.respring";
		CFNotificationCenterPostNotification(center, str, nil, nil, true);
	}

	- (void) presentChooseVC {
		PSViewController *vc = [[ZX2ChooseWallpaperViewController alloc] init];
		[self pushController: vc animate: true];
	}

@end
