@interface SBIconController

+(SBIconController *) sharedInstanceIfExists;

-(id) _openFolderController;
-(id) _currentFolderController;

@end

// A simple class that tracks device states relevant to Frame.
// And provides triggers for changes in states.

@interface DeviceStates : NSObject
  @property(setter=setAsleep:, nonatomic) bool asleep;
  @property(setter=setInApp:, nonatomic) bool inApp;
  @property(setter=setOnLockscreen:, nonatomic) bool onLockscreen;

  + (DeviceStates *) shared;

  - (void) setAsleep: (bool) flag;
  - (void) setInApp: (bool) flag;
  - (void) setOnLockscreen: (bool) flag;
@end

// MACROS for convenient property access.
// So I don't have to refactor the code :).
#define IS_ASLEEP [DeviceStates shared].asleep
#define IS_IN_APP [DeviceStates shared].inApp
#define IS_ON_LOCKSCREEN [DeviceStates shared].onLockscreen