#include <stdio.h>
#include <unistd.h>
#include <Foundation/Foundation.h>

NSString *const domainLock = @"lockscreen";
NSString *const domainHome = @"homescreen";
NSString *const domainBoth = @"both";

const char *help = "\nUsage: framecli -[slm] /path/to/video\n\n"
					"Allowed video formats: [.mp4, .m4a, .mov].\n\n"
					"Options:\n"
						"\t-s\tSet Both.\n"
						"\t-l\tSet Lockscreen.\n"
						"\t-m\tSet Homescreen.\n"
						"\t-h\tHelp.\n\n"
					"Note: passing '' as the video path is equivalent to removing the video.\n";
char *acceptedFormats[] = {".mp4", ".m4a", ".mov"};

void notifyFrame() {
	CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
	NSString *name = @"com.zx02.frame.videoChanged";
	CFStringRef str = (__bridge CFStringRef) name;
	CFNotificationCenterPostNotification(center, str, nil, nil, YES);
}

// Updates user defaults with the provided videoPath for the set domain.
void _setVideoPath(NSString *videoPath, NSString *domain, NSUserDefaults *bundleDefaults) {
	NSString *completeKeyPath = [domain stringByAppendingString: @"/videoPath"];
	NSString *sharedVideoPath = [bundleDefaults stringForKey: @"both/videoPath"];
	// Update videoPaths by cases.
	if (sharedVideoPath != nil) {
		// Previously set shared video.
		if ([domain isEqualToString: domainBoth]) {
			// Override if setting a new shared video.
			[bundleDefaults setObject: videoPath forKey: completeKeyPath];
		}
		else {
			// Else make the original shared video the domain other than the specified domain.
			if ([domain isEqualToString: domainHome])
				[bundleDefaults setObject: sharedVideoPath forKey: @"lockscreen/videoPath"];
			else
				[bundleDefaults setObject: sharedVideoPath forKey: @"homescreen/videoPath"];
			// Set the Path for the actual keyPath.
			[bundleDefaults setObject: videoPath forKey: completeKeyPath];
			// Cleanup.
			[bundleDefaults removeObjectForKey: @"both/videoPath"];
		}
	}
	else {
		// Previously no (shared) video was set.
		if ([domain isEqualToString: domainBoth]) {
			// Setting shared video.
			[bundleDefaults setObject: videoPath forKey: @"both/videoPath"];
			// Cleanup.
			[bundleDefaults removeObjectForKey: @"lockscreen/videoPath"];
			[bundleDefaults removeObjectForKey: @"homescreen/videoPath"];
		}
		else {
			// Setting individual video.
			[bundleDefaults setObject: videoPath forKey: completeKeyPath];
		}
	}

	// Since videoPaths aren't being monitored, notify Frame by IPC.
	notifyFrame();
}

// Wrapper for _setVideoPath that performs safety checks.
void setVideoPath(char *filePath, NSString *domain, NSUserDefaults *bundleDefaults) {
	// special case: allow empty filePath to "unset" the specified domain.
	if (strlen(filePath) == 0) {
		_setVideoPath(nil, domain, bundleDefaults);
		return;
	}
	// check if filename is at least 4 chars long and we can access it
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
		return;
	}

	NSString *filePathAbs = [NSURL fileURLWithPath: [NSString stringWithUTF8String: filePath]].path;
	_setVideoPath(filePathAbs, domain, bundleDefaults);

	printf("Successfully set video to %s\n", [filePathAbs cStringUsingEncoding: NSUTF8StringEncoding]);
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
				setVideoPath(optarg, domainBoth, bundleDefaults);
				break;
			}
			case 'l': {
				setVideoPath(optarg, domainLock, bundleDefaults);
				break;
			}
			case 'm': {
				printf("arg: \"%s\"\n", optarg);
				setVideoPath(optarg, domainHome, bundleDefaults);
				break;
			}
			// help / missing optarg
			case 'h':
			case ':': {
				printf("%s\n", help);
				NSDictionary *dictionary = bundleDefaults.dictionaryRepresentation;
				for (NSString *key in dictionary) {
					id value = dictionary[key];
					NSString *text = [NSString stringWithFormat: @"%@ = %@\n", key, value];
					printf("%s", [text cStringUsingEncoding: NSUTF8StringEncoding]);
				}
				break;
			}
			// unknown opt
			case '?':
				printf("Unknown option %c.\n%s\n", optopt, help);
				break;
		}
	}
	return 0;
}
