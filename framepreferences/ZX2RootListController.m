#include "ZX2RootListController.h"

@implementation ZX2RootListController

	- (NSArray *)specifiers {
		if (!_specifiers) {
			_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
		}
		// run my init
		bundleDefaults = [[NSUserDefaults alloc] initWithSuiteName: @"com.Zerui.framepreferences"];
		return _specifiers;
	}

	- (void) presentFileSelector {
		NSArray<NSString *> *allowedUTIs = @[@"com.apple.m4v-video", @"com.apple.quicktime-movie", @"public.mpeg-4"];
		UIDocumentPickerViewController *pickerVC = [[UIDocumentPickerViewController alloc] initWithDocumentTypes: allowedUTIs inMode: UIDocumentPickerModeOpen];
		pickerVC.delegate = self;
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
		[rootVC presentViewController: pickerVC animated: YES completion: nil];
	}

	- (void) documentPicker: (UIDocumentPickerViewController *) controller didPickDocumentsAtURLs: (NSArray<NSURL *> *) urls {
		self.videoURL = urls[0];
	}

	- (NSURL *) getVideoURL {
		return [bundleDefaults URLForKey: @"videoURL"];
	}

	- (void) setVideoURL: (NSURL *) url {
		[bundleDefaults setURL: url forKey: @"videoURL"];
	}

	- (void) respring {
		CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
		CFStringRef str = (__bridge CFStringRef)@"com.Zerui.framepreferences.respring";
		CFNotificationCenterPostNotification(center, str, nil, nil, YES);
	}

@end
