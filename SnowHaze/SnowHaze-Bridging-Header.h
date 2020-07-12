//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import "SimplePing.h"
#import "sqlite.h"
#import "WebKitFixes.h"

const char* VERSION_TIMESTAMP;

char* uname_model(struct utsname* u);
int open_constcharp_int(const char* path, int oflag);
