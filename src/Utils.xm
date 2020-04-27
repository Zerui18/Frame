#import "Utils.h"

// Sets the ringer volume to the specified level.
void setRingerVolume(float newVolumeLevel) {   
        // Load the Celestial framework ourselves, just in case.
        [[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/Celestial.framework"] load];
    // Borrowed this code from stackoverflow.
        Class avSystemControllerClass = NSClassFromString(@"AVSystemController");
    id avSystemControllerInstance = [avSystemControllerClass performSelector:@selector(sharedAVSystemController)];

    NSString *soundCategory = @"Ringtone";

    NSInvocation *volumeInvocation = [NSInvocation invocationWithMethodSignature:
                                    [avSystemControllerClass instanceMethodSignatureForSelector:
                                    @selector(setVolumeTo:forCategory:)]];
    [volumeInvocation setTarget:avSystemControllerInstance];
    [volumeInvocation setSelector:@selector(setVolumeTo:forCategory:)];
    [volumeInvocation setArgument:&newVolumeLevel atIndex:2];
    [volumeInvocation setArgument:&soundCategory atIndex:3];
    [volumeInvocation invoke];
}

// Executes the provided block once on main thread.
void dispatch_once_on_main_thread(dispatch_once_t *predicate,
                                  dispatch_block_t block) {
  if ([NSThread isMainThread]) {
    dispatch_once(predicate, block);
  } else {
    if (DISPATCH_EXPECT(*predicate == 0L, NO)) {
      dispatch_sync(dispatch_get_main_queue(), ^{
        dispatch_once(predicate, block);
      });
    }
  }
}