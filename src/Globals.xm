#include "Globals.h"

bool isAsleep = true;
bool isInApp = false;
bool isOnLockscreen = true;

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

NSString *const kLockscreen = @"Lockscreen";
NSString *const kHomescreen = @"Homescreen";
NSString *const kBothscreens = @"";