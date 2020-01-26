#include <Foundation/Foundation.h>

// Globals
extern bool isAsleep;
extern bool isInApp;

void dispatch_once_on_main_thread(dispatch_once_t *predicate,
                                  dispatch_block_t block);