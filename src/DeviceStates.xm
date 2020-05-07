#import "DeviceStates.h"
#import "Frame.h"

void cancelCountdown();
void rescheduleCountdown();

@implementation DeviceStates

  + (DeviceStates *) shared {
    static DeviceStates *instance = [[DeviceStates alloc] init];
    return instance;
  }

  - (id) init {
    self = [super init];
    _asleep = false;
    _inApp = false;
    _onLockscreen = true;
    return self;
  }

  - (void) setAsleep: (bool) flag {
    if (flag == _asleep)
      return;
    _asleep = flag;

    // Action for going asleep.
    if (_asleep) {
      [FRAME pause];
    }
    // Going for exiting sleep.
    else {
      [FRAME playLockscreen];
    }
  }

  - (void) setInApp: (bool) flag {
    if (flag == _inApp)
      return;
    _inApp = flag;

    // Action for entering app.
    if (_inApp) {
      if ([FRAME pauseInApps]) {
        // Don't pause standalone lockscreen player.
        // As this may be executed with a delay, when the user has opened the lock screen.
        [FRAME pauseHomescreen];
        [FRAME pauseSharedPlayer];
      }
      // Check if we're on lockscreen.
      if (!_onLockscreen) {
        // Thankfully we're still in the app.
        cancelCountdown();
      }
    }
    // Action for leaving app.
    else {
      // TODO: only reschedule count down if we're not in a folder, check needed
      rescheduleCountdown();
      [FRAME playHomescreen];
    }
  }

  // Note: Here we'll only control events which need to happen at the exact moment this value is updated.
  // The rest will be done in the hook itself.
  // This allows fine-tuning of the behaviour.
  - (void) setOnLockscreen: (bool) flag {
    if (flag == _onLockscreen)
      return;
    _onLockscreen = flag;

    // Action for entering lockscreen.
    if (_onLockscreen) {
      cancelCountdown();
      [FRAME playLockscreen];
    }
    // Action for leaving lockscreen.
    else {
      [FRAME pauseLockscreen];
      if (!IS_IN_APP) {
        rescheduleCountdown();
      }
    }
  }

@end