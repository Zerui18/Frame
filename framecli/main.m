#include <stdio.h>
#include <unistd.h>
#include <Foundation/Foundation.h>

int main(int argc, char *argv[], char *envp[]) {
	const char *help = "Usage: framecli -s /path/to/video\nAllowed video formats: [.mp4, .m4a, .mov].";
	char *acceptedFormats[] = {".mp4", ".m4a", ".mov"};

	// print help if not arg provided
	if (argc < 2) {
		printf("%s\n", help);
		return 0;
	}

	// otherwise parse args
	int opt;
	while(opt = getopt(argc, argv, ":s:h"), opt != -1) {  
		switch(opt) {
			// set file
			case 's': {
				char *filePath = optarg; 
				// safety checks
				if (strlen(filePath) < 4 ||
						access(filePath, F_OK) == -1) {
					printf("Invalid file path.\n%s\n", help);
					return 0;
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

				// proceed to set file in shared defaults
				NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName: @"com.Zerui.framepreferences"];
				[defaults setURL: fileURL forKey: @"videoURL"];

				printf("Successfully set video to %s\n", filePath);

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
