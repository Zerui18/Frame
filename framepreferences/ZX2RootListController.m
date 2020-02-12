#include "ZX2RootListController.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <AVFoundation/AVFoundation.h>

@implementation ZX2RootListController

	- (NSArray *) specifiers {
		if (!_specifiers) {
			_specifiers = [self loadSpecifiersFromPlistName: @"Root" target:self];
		}
		bundleDefaults = [[NSUserDefaults alloc] initWithSuiteName: @"com.Zerui.framepreferences"];
		// Also store a reference to the defaults to access globally.
		sharedBundleDefaults = bundleDefaults;
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

	- (void) handleChooseVideo {
		// Allow choosing from "Files" and "Photos".
		UIAlertController *alertVC = [UIAlertController
			alertControllerWithTitle: @"Choose From"message: @"select a source" preferredStyle: UIAlertControllerStyleAlert];
		UIAlertAction *filesAction = [UIAlertAction actionWithTitle: @"Files" style: UIAlertActionStyleDefault handler: ^(UIAlertAction *a) {
			[self presentFileSelector];
		}];
		[alertVC addAction: filesAction];

		// Add Photos options only if photo library access is available.
		UIImagePickerController* impViewController = [[UIImagePickerController alloc] init];
		// Check if image access is authorized
		if([UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypePhotoLibrary]) {
			impViewController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
			impViewController.mediaTypes = [[NSArray alloc] initWithObjects: (NSString *) kUTTypeMovie, nil];
			impViewController.delegate = self;
			impViewController.videoExportPreset = AVAssetExportPresetPassthrough;
			UIAlertAction *albumAction = [UIAlertAction actionWithTitle: @"Photos" style: UIAlertActionStyleDefault handler: ^(UIAlertAction *a) {
				[self present: impViewController];
			}];

			[alertVC addAction: albumAction];
		}

		[self present: alertVC];
	}

	- (void) presentFileSelector {
		NSArray<NSString *> *allowedUTIs = @[@"com.apple.m4v-video", @"com.apple.quicktime-movie", @"public.mpeg-4"];
		UIDocumentPickerViewController *pickerVC = [[UIDocumentPickerViewController alloc] initWithDocumentTypes: allowedUTIs inMode: UIDocumentPickerModeOpen];
		pickerVC.delegate = self;
		[self present: pickerVC];	
	}

	- (void) documentPicker: (UIDocumentPickerViewController *) controller didPickDocumentsAtURLs: (NSArray<NSURL *> *) urls {
		self.videoURL = urls[0];
	}

	- (void) imagePickerController: (UIImagePickerController *) picker didFinishPickingMediaWithInfo: (NSDictionary<UIImagePickerControllerInfoKey, id> *) info {
		[picker dismissViewControllerAnimated: YES completion: nil];
		NSURL *newURL = (NSURL *) info[UIImagePickerControllerMediaURL];
		self.videoURL = newURL;
	}

	- (void) imagePickerControllerDidCancel: (UIImagePickerController *) picker {
		[picker dismissViewControllerAnimated: YES completion: nil];
	}

	- (NSURL *) getVideoURL {
		return [bundleDefaults URLForKey: @"videoURL"];
	}

	- (void) setVideoURL: (NSURL *) url {
		[bundleDefaults setURL: url forKey: @"videoURL"];
	}

	- (void) respring {
		CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
		CFStringRef str = (__bridge CFStringRef)@"com.ZX02.framepreferences.respring";
		CFNotificationCenterPostNotification(center, str, nil, nil, YES);
	}

@end
