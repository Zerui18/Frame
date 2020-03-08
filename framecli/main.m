#include <stdio.h>
#include <unistd.h>
#include <Foundation/Foundation.h>

NSString *const kLockscreen = @"Lockscreen";
NSString *const kHomescreen = @"Homescreen";
NSString *const kBothscreens = @"";

const char *help = "Usage: framecli -s /path/to/video\nAllowed video formats: [.mp4, .m4a, .mov].\nNote: This tool only sets the primary video path.\n\nOptions:\n\t-s\tSet Both.\n\t-l\tSet Lockscreen.\n\t-m\tSet Homescreen.\n\t-h\tHelp.\n";
char *acceptedFormats[] = {".mp4", ".m4a", ".mov"};

void notifyFrame() {
	CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
	NSString *name = @"com.ZX02.framepreferences.videoChanged";
	CFStringRef str = (__bridge CFStringRef) name;
	CFNotificationCenterPostNotification(center, str, nil, nil, YES);
}

// Moves the file to a permanent URL of the same extension and provided key and return it. Returns nil if move failed.
// Copied from framepreferences.
NSURL *getPermanentVideoURL(NSURL *srcURL, NSString *key) {
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
		NSLog(@"[FrameCLI] Error on Copy %@", err);
	return nil;
}

// Updates user defaults with the provided videoURL, the provided filename key and the keyPath for which the videoURL should be set.
void setVideoURL(NSURL *videoURLOri, NSString *key, NSUserDefaults *bundleDefaults) {
	// Try to copy the file at videoURL to an internal URL, return if failed.
	NSURL *videoURL = nil;

	// Separated to allow this function to accept nil as videoURLOri. 
	if (videoURLOri != nil) {
		videoURL = getPermanentVideoURL(videoURLOri, key);
		if (videoURL == nil)
			return;
	}

	NSString *completeKeyPath = [@"videoURL" stringByAppendingString: key];
		
	NSURL *sharedVideoURL = [bundleDefaults URLForKey: @"videoURL"];
	// Update videoURLs by cases.
	if (sharedVideoURL != nil) {
		// Previously set shared video.
		if ([key isEqualToString: kBothscreens]) {
			// Override if setting a new shared video.
			[bundleDefaults setURL: videoURL forKey: @"videoURL"];
		}
		else {
			// Else make the original shared video the key other than the specified key.
			if ([key isEqualToString: kHomescreen])
				[bundleDefaults setURL: sharedVideoURL forKey: @"videoURLLockscreen"];
			else
				[bundleDefaults setURL: sharedVideoURL forKey: @"videoURLHomescreen"];
			// Set the URL for the actual keyPath.
			[bundleDefaults setURL: videoURL forKey: completeKeyPath];
			// Cleanup.
			[bundleDefaults removeObjectForKey: @"videoURL"];
		}
	}
	else {
		// Previously no (shared) video was set.
		if ([key isEqualToString: kBothscreens]) {
			// Setting shared video.
			[bundleDefaults setURL: videoURL forKey: @"videoURL"];
			// Cleanup.
			[bundleDefaults removeObjectForKey: @"videoURLLockscreen"];
			[bundleDefaults removeObjectForKey: @"videoURLHomescreen"];
		}
		else {
			// Setting individual video.
			[bundleDefaults setURL: videoURL forKey: completeKeyPath];
		}
	}

	// Since videoURLs aren't being monitored, notify Frame by IPC.
	notifyFrame();
}

// Wrapper for the entire logic of setting videoURLs.
void handleSetURL(char *filePath, NSString *key, NSUserDefaults *bundleDefaults) {
	// safety checks
	if (strlen(filePath) < 4 ||
			access(filePath, F_OK) == -1) {
		printf("Invalid file path.\n%s\n", help);
		return;
	}

	// check if file type is allowed
	char *fileExt = filePath + strlen(filePath)-4;
	bool fileTypeAllowed = false;

	for (int i=0; i<3; i++) {
		if (strcmp(fileExt, acceptedFormats[i]) == 0) {
			fileTypeAllowed = true;
			break;
		}
	}

	if (!fileTypeAllowed) {
		printf("Unsupported file type: %s\n%s\n", fileExt, help);
	}

	NSURL *fileURL = [NSURL fileURLWithPath: [NSString stringWithUTF8String: filePath]];
	setVideoURL(fileURL, key, bundleDefaults);

	printf("Successfully set video to %s\n", filePath);
}

int main(int argc, char *argv[], char *envp[]) {

	// print help if not arg provided
	if (argc < 2) {
		printf("%s\n", help);
		return 0;
	}

	// load userDefaults
	NSUserDefaults *bundleDefaults = [[NSUserDefaults alloc] initWithSuiteName: @"com.Zerui.framepreferences"];

	// otherwise parse args
	int opt;
	while(opt = getopt(argc, argv, ":s:l:m:h"), opt != -1) {  
		switch(opt) {
			// set file
			case 's': {
				handleSetURL(optarg, kBothscreens, bundleDefaults);
				break;
			}
			case 'l': {
				handleSetURL(optarg, kLockscreen, bundleDefaults);
				break;
			}
			case 'm': {
				handleSetURL(optarg, kHomescreen, bundleDefaults);
				break;
			}
			// help / missing optarg
			case 'h':
			case ':':
				printf("%s\n", help);
				break;
			// unknown opt
			case '?':
				printf("Unknown option %c.\n%s\n", optopt, help);
				break;
		}
	}
	return 0;
}
