#import <MobileCoreServices/MobileCoreServices.h>
#import "ZX2ChooseVideoViewController.h"
#import "Globals.h"

@implementation ZX2ChooseVideoViewController

  - (void) viewDidLoad {
    [super viewDidLoad];
		if (@available(iOS 13, *))
			self.view.backgroundColor = UIColor.systemBackgroundColor;
		else
			self.view.backgroundColor = UIColor.whiteColor;

    [self initUI];
		[self reloadPreviews];
  }

	// Init and configure UI elements.
  - (void) initUI {
    // Init UI elements.
		primaryLabel = [[UILabel alloc] init];
    secondaryLabel = [[UILabel alloc] init];

		self.primaryPlayer = [[AVQueuePlayer alloc] init];
		self.secondaryPlayer = [[AVQueuePlayer alloc] init];

		self.primaryPlayer.muted = true;
		self.secondaryPlayer.muted = true;

    secondaryPreview = [[ZX2WallpaperView alloc] initWithVC: self isSecondaryPreview: true];
    primaryPreview = [[ZX2WallpaperView alloc] initWithVC: self isSecondaryPreview: false];

    showWallpaperStoreButton = [UIButton buttonWithType: UIButtonTypeCustom];

		// Configure the UI elements.
		primaryLabel.text = @"Primary Video";
		secondaryLabel.text = @"Secondary Video";

		[self setupLayout];

		primaryPreview.layer.cornerRadius = secondaryPreview.layer.cornerRadius = 
			min(primaryPreview.bounds.size.width, primaryPreview.bounds.size.height) * 0.13;
  }

  - (void) setupLayout {

		// Setup top labels.
		primaryLabel.translatesAutoresizingMaskIntoConstraints = false;
		secondaryLabel.translatesAutoresizingMaskIntoConstraints = false;

		[self.view addSubview: primaryLabel];
		[self.view addSubview: secondaryLabel];

		[primaryLabel.topAnchor constraintEqualToAnchor: self.view.topAnchor constant: 24].active = true;
		[secondaryLabel.topAnchor constraintEqualToAnchor: primaryLabel.topAnchor].active = true;

		// Setup previews.
		primaryPreview.translatesAutoresizingMaskIntoConstraints = false;
		secondaryPreview.translatesAutoresizingMaskIntoConstraints = false;

		bool usePortraitDims = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone;
		// Get the ratio between the two dims.
		CGFloat widthToHeight = UIScreen.mainScreen.bounds.size.width / UIScreen.mainScreen.bounds.size.height;
		// Flip the ratio if required.
		if ((usePortraitDims && widthToHeight > 1.0) || (!usePortraitDims && widthToHeight < 1.0))
			widthToHeight = 1.0 / widthToHeight;

		[self.view addSubview: primaryPreview];
		[self.view addSubview: secondaryPreview];
		
		// Set aspect ratios.
		[primaryPreview.widthAnchor constraintEqualToAnchor: primaryPreview.heightAnchor multiplier: widthToHeight].active = true;
		[secondaryPreview.widthAnchor constraintEqualToAnchor: secondaryPreview.heightAnchor multiplier: widthToHeight].active = true;

		// Position them below top labels.
		[primaryPreview.topAnchor constraintEqualToAnchor: primaryLabel.bottomAnchor constant: 24].active = true;
		[secondaryPreview.topAnchor constraintEqualToAnchor: primaryLabel.bottomAnchor constant: 24].active = true;

		// Setup x-position & width.
		[primaryPreview.leadingAnchor constraintEqualToAnchor: self.view.leadingAnchor constant: 24].active = true;
		[secondaryPreview.leadingAnchor constraintEqualToAnchor: primaryPreview.trailingAnchor constant: 24].active = true;
		[secondaryPreview.trailingAnchor constraintEqualToAnchor: self.view.trailingAnchor constant: -24].active = true;
		[primaryPreview.widthAnchor constraintEqualToAnchor: secondaryPreview.widthAnchor].active = true;

		// Center the top labels horizontally with their respective previews.
		[primaryLabel.centerXAnchor constraintEqualToAnchor: primaryPreview.centerXAnchor].active = true;
		[secondaryLabel.centerXAnchor constraintEqualToAnchor: secondaryPreview.centerXAnchor].active = true;

		[self.view layoutIfNeeded];
  }

	// Resets the players according to the current preferences.
	- (void) reloadPreviews {
		// Reset loopers and players.
		primaryLooper = nil;
		secondaryLooper = nil;

		[self.primaryPlayer removeAllItems];
		[self.secondaryPlayer removeAllItems];

		NSURL *primaryVideoURL = [bundleDefaultsShared URLForKey: @"videoURL"];
		NSURL *secondaryVideoURL = [bundleDefaultsShared URLForKey: @"secVideoURL"];

		// Create player item & looper if videoURL is set.
		if (primaryVideoURL != nil) {
			AVPlayerItem *item = [AVPlayerItem playerItemWithURL: primaryVideoURL];
			primaryLooper = [AVPlayerLooper playerLooperWithPlayer: self.primaryPlayer templateItem: item];
		}

		if (secondaryVideoURL != nil) {
			AVPlayerItem *item = [AVPlayerItem playerItemWithURL: secondaryVideoURL];
			secondaryLooper = [AVPlayerLooper playerLooperWithPlayer: self.secondaryPlayer templateItem: item];
		}

		[self.primaryPlayer play];
		[self.secondaryPlayer play];
	}

	- (void) chooseVideo {
		// Allow choosing from "Files" and "Photos".
		UIAlertController *alertVC = [UIAlertController
			alertControllerWithTitle: @"Choose From" message: @"select a source" preferredStyle: UIAlertControllerStyleAlert];
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
				[self presentViewController: impViewController animated: true completion: nil];
			}];

			[alertVC addAction: albumAction];
		}

		[self presentViewController: alertVC animated: true completion: nil];
	}

	- (void) presentFileSelector {
		NSArray<NSString *> *allowedUTIs = @[@"com.apple.m4v-video", @"com.apple.quicktime-movie", @"public.mpeg-4"];
		UIDocumentPickerViewController *pickerVC = [[UIDocumentPickerViewController alloc] initWithDocumentTypes: allowedUTIs inMode: UIDocumentPickerModeOpen];
		pickerVC.delegate = self;
		[self presentViewController: pickerVC animated: true completion: nil];
	}

	- (void) documentPicker: (UIDocumentPickerViewController *) controller didPickDocumentsAtURLs: (NSArray<NSURL *> *) urls {
		[self setVideoURL: urls[0]];
	}

	- (void) imagePickerController: (UIImagePickerController *) picker didFinishPickingMediaWithInfo: (NSDictionary<UIImagePickerControllerInfoKey, id> *) info {
		[picker dismissViewControllerAnimated: YES completion: nil];
		NSURL *newURL = (NSURL *) info[UIImagePickerControllerMediaURL];
		[self setVideoURL: newURL];
	}

	- (void) imagePickerControllerDidCancel: (UIImagePickerController *) picker {
		[picker dismissViewControllerAnimated: YES completion: nil];
	}

	- (void) setVideoURL: (NSURL *) videoURL {
		NSURL *permanentURL = [self getPermanentVideoURL: videoURL];
		[bundleDefaultsShared setURL: permanentURL forKey: self.keyToSet];
		[self reloadPreviews];
		[self notifyFrame];
	}

	// Moves the file to a permanent URL of the same extension and return it. Returns nil if move failed.
	- (NSURL *) getPermanentVideoURL: (NSURL *) srcURL {
			NSURL *frameFolder = [NSURL fileURLWithPath: @"/var/mobile/Documents/com.ZX02.Frame/"];

			// Get the extension of the original file.
			NSString *ext = srcURL.pathExtension.lowercaseString;
			
			bool secondary = [self.keyToSet isEqualToString: @"secVideoURL"];
			NSURL *newURL = [frameFolder URLByAppendingPathComponent: [NSString stringWithFormat: @"wallpaper%@.%@", secondary ? @".sec":@"", ext]];

			// Remove the old file should it exist.
			[NSFileManager.defaultManager removeItemAtPath: newURL.path error: nil];

			// Attempt to copy the tmp item to a permanent url.
			NSError *err;
			if ([NSFileManager.defaultManager copyItemAtPath: srcURL.path toPath: newURL.path error: &err]) {
					return newURL;
			}

			if (err != nil)
				NSLog(@"err copying item %@", err);
			return nil;
	}

	- (void) notifyFrame {
		CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
		NSString *name = [self.keyToSet isEqualToString: @"videoURL"] ? @"com.ZX02.framepreferences.videoChanged" : @"com.ZX02.framepreferences.secVideoChanged";
		CFStringRef str = (__bridge CFStringRef) name;
		CFNotificationCenterPostNotification(center, str, nil, nil, YES);
	}

@end