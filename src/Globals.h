#include <Foundation/Foundation.h>

// Globals
extern bool isAsleep;
extern bool isInApp;
extern bool isOnLockscreen;

FOUNDATION_EXPORT NSString *const kLockscreen;
FOUNDATION_EXPORT NSString *const kHomescreen;
FOUNDATION_EXPORT NSString *const kBothscreens;

extern void setIsOnLockscreen(bool v);