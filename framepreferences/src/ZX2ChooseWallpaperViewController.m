#import <MobileCoreServices/MobileCoreServices.h>
#import "ZX2ChooseWallpaperViewController.h"
#import <framepreferences-Swift.h>
#import "Globals.h"

@implementation ZX2ChooseWallpaperViewController

  - (void) viewDidLoad {
    [super viewDidLoad];
		self.navigationItem.title = @"Choose Wallpapers";

		// Set bg color.
		if (@available(iOS 13, *))
			self.view.backgroundColor = UIColor.systemBackgroundColor;
		else
			self.view.backgroundColor = UIColor.whiteColor;
    
		// Run setups.
		[self initUI];
		[self resetPlayers];
		[self resetPreviews];
  }

	// Reset all players according to current preferences.
	- (void) resetPlayers {
		// Destroy all current players & loopers.
		sharedPlayer = homescreenPlayer = lockscreenPlayer = nil;
		sharedLooper = lockscreenLooper = homescreenLooper = nil;

		NSURL *sharedVideoURL = [bundleDefaultsShared URLForKey: @"videoURL"];
		if (sharedVideoURL != nil) {
			// Set only the shared player.
			sharedPlayer = [[AVQueuePlayer alloc] init];
			sharedPlayer.muted = true;
			// Loop shared video.
			AVPlayerItem *item = [AVPlayerItem playerItemWithURL: sharedVideoURL];
			sharedLooper = [AVPlayerLooper playerLooperWithPlayer: sharedPlayer templateItem: item];
			lockscreenPreview.player = homescreenPreview.player = sharedPlayer;
			[sharedPlayer play];
		}
		else {
			// Tries to get lock/home videoURLs and set the respective players if possible.
			NSURL *homescreenVideoURL = [bundleDefaultsShared URLForKey: @"videoURLHomescreen"];
			NSURL *lockscreenVideoURL = [bundleDefaultsShared URLForKey: @"videoURLLockscreen"];

			if (homescreenVideoURL != nil) {
				homescreenPlayer = [[AVQueuePlayer alloc] init];
				homescreenPlayer.muted = true;
				AVPlayerItem *item = [AVPlayerItem playerItemWithURL: homescreenVideoURL];
				homescreenLooper = [AVPlayerLooper playerLooperWithPlayer: homescreenPlayer templateItem: item];
				[homescreenPlayer play];
			}

			if (lockscreenVideoURL != nil) {
				lockscreenPlayer = [[AVQueuePlayer alloc] init];
				lockscreenPlayer.muted = true;
				AVPlayerItem *item = [AVPlayerItem playerItemWithURL: lockscreenVideoURL];
				lockscreenLooper = [AVPlayerLooper playerLooperWithPlayer: lockscreenPlayer templateItem: item];
				[lockscreenPlayer play];
			}
		}
	}

	// Reconnect the preview views with the appropriate players.
	- (void) resetPreviews {
		if (sharedPlayer != nil)
			lockscreenPreview.player = homescreenPreview.player = sharedPlayer;
		else {
			lockscreenPreview.player = lockscreenPlayer;
			homescreenPreview.player = homescreenPlayer;
		}
	}

	// Init and configure UI elements.
  - (void) initUI {

    // Init UI elements.
		homescreenLabel = [[UILabel alloc] init];
    lockscreenLabel = [[UILabel alloc] init];

    lockscreenPreview = [[ZX2WallpaperView alloc] initWithScreen: kLockscreen];
    homescreenPreview = [[ZX2WallpaperView alloc] initWithScreen: kHomescreen];

		lockscreenPreview.parentVC = homescreenPreview.parentVC = self;

    chooseWallpaperButton = [UIButton buttonWithType: UIButtonTypeCustom];
		getWallpaperButton = [UIButton buttonWithType: UIButtonTypeCustom];

		UIColor *chooseBtnBgColor, *getBtnBgColor;

		if (@available(iOS 13, *)) {
			chooseBtnBgColor = UIColor.grayColor;
			getBtnBgColor = UIColor.systemBlueColor;
		}
		else {
			chooseBtnBgColor = UIColor.grayColor;
			getBtnBgColor = UIColor.blueColor;
		}
		
		chooseWallpaperButton.backgroundColor = chooseBtnBgColor;
		[chooseWallpaperButton setTitle: @"Choose Video" forState: UIControlStateNormal];
		[chooseWallpaperButton setTitleColor: UIColor.whiteColor forState: UIControlStateNormal];
		[chooseWallpaperButton setTitleColor: UIColor.lightGrayColor forState: UIControlStateHighlighted];
		chooseWallpaperButton.titleLabel.font = [UIFont systemFontOfSize: 24 weight: UIFontWeightMedium];
		chooseWallpaperButton.layer.cornerRadius = 12;
		[chooseWallpaperButton addTarget: self action: @selector(chooseVideo) forControlEvents: UIControlEventTouchUpInside];

		getWallpaperButton.backgroundColor = getBtnBgColor;
		[getWallpaperButton setTitle: @"Get Video" forState: UIControlStateNormal];
		[getWallpaperButton setTitleColor: UIColor.whiteColor forState: UIControlStateNormal];
		[getWallpaperButton setTitleColor: UIColor.lightGrayColor forState: UIControlStateHighlighted];
		getWallpaperButton.titleLabel.font = [UIFont systemFontOfSize: 24 weight: UIFontWeightMedium];
		getWallpaperButton.layer.cornerRadius = 12;
		[getWallpaperButton addTarget: self action: @selector(presentWallpaperListing) forControlEvents: UIControlEventTouchUpInside];

		// Configure the UI elements.
		lockscreenLabel.text = @"Lock Screen";
		homescreenLabel.text = @"Home Screen";

		lockscreenLabel.font = [UIFont systemFontOfSize: 20];
		homescreenLabel.font = [UIFont systemFontOfSize: 20];

		[self setupLayout];

		homescreenPreview.layer.cornerRadius = lockscreenPreview.layer.cornerRadius = 24;
  }

  - (void) setupLayout {

		// Setup top labels.
		homescreenLabel.translatesAutoresizingMaskIntoConstraints = false;
		lockscreenLabel.translatesAutoresizingMaskIntoConstraints = false;

		[self.view addSubview: homescreenLabel];
		[self.view addSubview: lockscreenLabel];

		[homescreenLabel.topAnchor constraintEqualToAnchor: self.view.safeAreaLayoutGuide.topAnchor constant: 24].active = true;
		[lockscreenLabel.topAnchor constraintEqualToAnchor: homescreenLabel.topAnchor].active = true;

		// Setup previews.
		homescreenPreview.translatesAutoresizingMaskIntoConstraints = false;
		lockscreenPreview.translatesAutoresizingMaskIntoConstraints = false;

		bool usePortraitDims = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone;
		// Get the ratio between the two dims.
		CGFloat widthToHeight = UIScreen.mainScreen.bounds.size.width / UIScreen.mainScreen.bounds.size.height;
		// Flip the ratio if required.
		if ((usePortraitDims && widthToHeight > 1.0) || (!usePortraitDims && widthToHeight < 1.0))
			widthToHeight = 1.0 / widthToHeight;

		[self.view addSubview: homescreenPreview];
		[self.view addSubview: lockscreenPreview];
		
		// Set aspect ratios.
		[homescreenPreview.widthAnchor constraintEqualToAnchor: homescreenPreview.heightAnchor multiplier: widthToHeight].active = true;
		[lockscreenPreview.widthAnchor constraintEqualToAnchor: lockscreenPreview.heightAnchor multiplier: widthToHeight].active = true;

		// Position them below top labels.
		[homescreenPreview.topAnchor constraintEqualToAnchor: homescreenLabel.bottomAnchor constant: 24].active = true;
		[lockscreenPreview.topAnchor constraintEqualToAnchor: homescreenLabel.bottomAnchor constant: 24].active = true;

		// Setup x-position & width.
		[lockscreenPreview.leadingAnchor constraintEqualToAnchor: self.view.leadingAnchor constant: 24].active = true;
		[homescreenPreview.leadingAnchor constraintEqualToAnchor: lockscreenPreview.trailingAnchor constant: 24].active = true;
		[homescreenPreview.trailingAnchor constraintEqualToAnchor: self.view.trailingAnchor constant: -24].active = true;
		[homescreenPreview.widthAnchor constraintEqualToAnchor: lockscreenPreview.widthAnchor].active = true;

		// Center the top labels horizontally with their respective previews.
		[homescreenLabel.centerXAnchor constraintEqualToAnchor: homescreenPreview.centerXAnchor].active = true;
		[lockscreenLabel.centerXAnchor constraintEqualToAnchor: lockscreenPreview.centerXAnchor].active = true;

		// Setup choose video button.
		chooseWallpaperButton.translatesAutoresizingMaskIntoConstraints = false;

		[self.view addSubview: chooseWallpaperButton];

		[chooseWallpaperButton.topAnchor constraintEqualToAnchor: homescreenPreview.bottomAnchor constant: 32].active = true;
		[chooseWallpaperButton.heightAnchor constraintEqualToConstant: 60].active = true;

		// Align leading & trailing.
		[chooseWallpaperButton.leadingAnchor constraintEqualToAnchor: lockscreenPreview.leadingAnchor].active = true;
		[chooseWallpaperButton.trailingAnchor constraintEqualToAnchor: homescreenPreview.trailingAnchor].active = true;

		// Setup get video button.
		getWallpaperButton.translatesAutoresizingMaskIntoConstraints = false;

		[self.view addSubview: getWallpaperButton];

		[getWallpaperButton.topAnchor constraintEqualToAnchor: chooseWallpaperButton.bottomAnchor constant: 32].active = true;
		[getWallpaperButton.heightAnchor constraintEqualToConstant: 60].active = true;

		// Align leading & trailing.
		[getWallpaperButton.leadingAnchor constraintEqualToAnchor: chooseWallpaperButton.leadingAnchor].active = true;
		[getWallpaperButton.trailingAnchor constraintEqualToAnchor: chooseWallpaperButton.trailingAnchor].active = true;

		[self.view layoutIfNeeded];
  }

	// Kickstart the choose video UX.
	- (void) chooseVideo {
		// Use actionSheet on phones but alert on ipads.
		bool isPhone = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone;
		UIAlertControllerStyle alertStyle = isPhone ? UIAlertControllerStyleActionSheet : UIAlertControllerStyleAlert;

		// Allow choosing from "Files" and "Photos".
		UIAlertController *alertVC = [UIAlertController
			alertControllerWithTitle: @"Choose From" message: @"select a source" preferredStyle: alertStyle];
		UIAlertAction *filesAction = [UIAlertAction actionWithTitle: @"Files" style: UIAlertActionStyleDefault handler: ^(UIAlertAction *a) {
			[self presentFileSelector];
		}];
		[alertVC addAction: filesAction];

		// Add Photos options only if photo library access is available.
		UIImagePickerController* impViewController = [[UIImagePickerController alloc] init];
		// Check if image access is authorized
		if([UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypePhotoLibrary]) {
			// Configure image picker vc.
			impViewController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
			impViewController.mediaTypes = [[NSArray alloc] initWithObjects: (NSString *) kUTTypeMovie, nil];
			impViewController.delegate = self;
			if (@available(iOS 11, *))
				impViewController.videoExportPreset = AVAssetExportPresetPassthrough;
			// Add album as selction option.
			UIAlertAction *albumAction = [UIAlertAction actionWithTitle: @"Photos" style: UIAlertActionStyleDefault handler: ^(UIAlertAction *a) {
				[self presentViewController: impViewController animated: true completion: nil];
			}];
			[alertVC addAction: albumAction];
		}

		// Lastly, add cancel option.
		[alertVC addAction: [UIAlertAction actionWithTitle: @"Cancel" style: UIAlertActionStyleCancel handler: nil]];

		[self presentViewController: alertVC animated: true completion: nil];
	}

	// Push WallpaperListingViewController.
	- (void) presentWallpaperListing {
		PSViewController *vc = (PSViewController *) [[NSClassFromString(@"ZX2WallpaperListingViewController") alloc] init];
		[self pushController: vc animate: true];
	}

	// Present a document picker view controller.
	- (void) presentFileSelector {
		NSArray<NSString *> *allowedUTIs = @[@"com.apple.m4v-video", @"com.apple.quicktime-movie", @"public.mpeg-4"];
		UIDocumentPickerViewController *pickerVC = [[UIDocumentPickerViewController alloc] initWithDocumentTypes: allowedUTIs inMode: UIDocumentPickerModeOpen];
		pickerVC.delegate = self;
		[self presentViewController: pickerVC animated: true completion: nil];
	}

	// Document picker vc callback.
	- (void) documentPicker: (UIDocumentPickerViewController *) controller didPickDocumentsAtURLs: (NSArray<NSURL *> *) urls {
		[self didSelectVideo: urls[0]];
	}

	// Image picker vc callback.
	- (void) imagePickerController: (UIImagePickerController *) picker didFinishPickingMediaWithInfo: (NSDictionary<UIImagePickerControllerInfoKey, id> *) info {
		[picker dismissViewControllerAnimated: YES completion: nil];
		NSURL *url = (NSURL *) info[UIImagePickerControllerMediaURL];
		[self didSelectVideo: url];
	}

	// Image picker vc callback.
	- (void) imagePickerControllerDidCancel: (UIImagePickerController *) picker {
		[picker dismissViewControllerAnimated: YES completion: nil];
	}

	- (void) didSelectVideo: (NSURL *) videoURL {
		// Use actionSheet on phones but alert on ipads.
		bool isPhone = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone;
		UIAlertControllerStyle alertStyle = isPhone ? UIAlertControllerStyleActionSheet : UIAlertControllerStyleAlert;

		// Setup alert vc.
		UIAlertController *alertVC = [UIAlertController
			alertControllerWithTitle: videoURL.lastPathComponent message: @"set as" preferredStyle: alertStyle];

		[alertVC addAction: [UIAlertAction actionWithTitle: @"Lock Screen" style: UIAlertActionStyleDefault handler: ^(UIAlertAction *a) {
				[self setVideoURL: videoURL withKey: kLockscreen];
		}]];

		[alertVC addAction: [UIAlertAction actionWithTitle: @"Home Screen" style: UIAlertActionStyleDefault handler: ^(UIAlertAction *a) {
				[self setVideoURL: videoURL withKey: kHomescreen];
		}]];

		[alertVC addAction: [UIAlertAction actionWithTitle: @"Both" style: UIAlertActionStyleDefault handler: ^(UIAlertAction *a) {
				[self setVideoURL: videoURL withKey: kBothscreens];
		}]];

		[alertVC addAction: [UIAlertAction actionWithTitle: @"Cancel" style: UIAlertActionStyleCancel handler: nil]];

		// Present this alert on the top view controller of the navigation stack.
		// Thus, this method can be called by the presented wallpaper listing vc.
		[self.navigationController.topViewController presentViewController: alertVC animated: true completion: nil];
	}

	// Updates user defaults with the provided videoURL, the provided filename key and the key to use.
	- (void) setVideoURL: (NSURL *) videoURLOri withKey: (NSString *) key {
		// Try to copy the file at videoURL to an internal URL, return if failed.
		NSURL *videoURL = nil;

		// Separated to allow this function to accept nil as videoURLOri. 
		if (videoURLOri != nil) {
			videoURL = [self getPermanentVideoURL: videoURLOri withKey: key];
			if (videoURL == nil)
				return;
		}

		NSString *completeKeyPath = [@"videoURL" stringByAppendingString: key];
			
		NSURL *sharedVideoURL = [bundleDefaultsShared URLForKey: @"videoURL"];
		// Update videoURLs by cases.
		if (sharedVideoURL != nil) {
			// Previously set shared video.
			if ([key isEqualToString: kBothscreens]) {
				// Override if setting a new shared video.
				[bundleDefaultsShared setURL: videoURL forKey: @"videoURL"];
			}
			else {
				// Else make the original shared video the key other than the specified key.
				if ([key isEqualToString: kHomescreen])
					[bundleDefaultsShared setURL: sharedVideoURL forKey: @"videoURLLockscreen"];
				else
					[bundleDefaultsShared setURL: sharedVideoURL forKey: @"videoURLHomescreen"];
				// Set the URL for the actual keyPath.
				[bundleDefaultsShared setURL: videoURL forKey: completeKeyPath];
				// Cleanup.
				[bundleDefaultsShared removeObjectForKey: @"videoURL"];
			}
		}
		else {
			// Previously no (shared) video was set.
			if ([key isEqualToString: kBothscreens]) {
				// Setting shared video.
				[bundleDefaultsShared setURL: videoURL forKey: @"videoURL"];
				// Cleanup.
				[bundleDefaultsShared removeObjectForKey: @"videoURLLockscreen"];
				[bundleDefaultsShared removeObjectForKey: @"videoURLHomescreen"];
			}
			else {
				// Setting individual video.
				[bundleDefaultsShared setURL: videoURL forKey: completeKeyPath];
			}
		}

		// Reload previews.
		[self resetPlayers];
		[self resetPreviews];

		// Since videoURLs aren't being monitored, notify Frame by IPC.
		[self notifyFrame];
	}

	// Moves the file to a permanent URL of the same extension and provided key and return it. Returns nil if move failed.
	- (NSURL *) getPermanentVideoURL: (NSURL *) srcURL withKey: (NSString *) key {
			NSURL *frameFolder = [NSURL fileURLWithPath: @"/var/mobile/Documents/com.ZX02.Frame/"];

			// Get the extension of the original file.
			NSString *ext = srcURL.pathExtension.lowercaseString;
			
			NSURL *newURL = [frameFolder URLByAppendingPathComponent: [NSString stringWithFormat: @"wallpaper%@.%@", key, ext]];

			// Remove the old file should it exist.
			[NSFileManager.defaultManager removeItemAtPath: newURL.path error: nil];

			// Attempt to copy the tmp item to a permanent url.
			NSError *err;
			if ([NSFileManager.defaultManager copyItemAtPath: srcURL.path toPath: newURL.path error: &err]) {
					return newURL;
			}

			if (err != nil)
				NSLog(@"[FramePrefs] Error on Copy %@", err);
			return nil;
	}

	- (void) notifyFrame {
		CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
		NSString *name = @"com.ZX02.framepreferences.videoChanged";
		CFStringRef str = (__bridge CFStringRef) name;
		CFNotificationCenterPostNotification(center, str, nil, nil, YES);
	}

@end