#import <Foundation/Foundation.h>

void setRingerVolume(float newVolumeLevel);

void dispatch_once_on_main_thread(dispatch_once_t *predicate,
                                  dispatch_block_t block);