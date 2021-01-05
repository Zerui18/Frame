#import "echo.h"

#define PRODUCTION

static const dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

void echo(NSString *format, ...) {
    #ifndef PRODUCTION
    va_list args;
    va_start(args, format);
    NSString *str = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSString *encodedStr = [str stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet alphanumericCharacterSet]];
    NSURL *url = [NSURL URLWithString: [[NSString alloc] initWithFormat:@"http://localhost:8765?info=%@", encodedStr]];
    dispatch_async(queue, ^{
        NSLog(@"%@", [[NSData alloc] initWithContentsOfURL: url]);
    });
    #endif
}