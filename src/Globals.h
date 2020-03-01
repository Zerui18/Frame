#include <Foundation/Foundation.h>

// Globals
extern bool isAsleep;
extern bool isInApp;
extern bool isOnLockscreen;

void dispatch_once_on_main_thread(dispatch_once_t *predicate,
                                  dispatch_block_t block);

FOUNDATION_EXPORT NSString *const kLockscreen;
FOUNDATION_EXPORT NSString *const kHomescreen;
FOUNDATION_EXPORT NSString *const kBothscreens;