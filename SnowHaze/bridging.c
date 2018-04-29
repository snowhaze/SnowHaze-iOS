//
//  bridging.c
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

#include <sys/utsname.h>

const char* VERSION_TIMESTAMP = __DATE__ " " __TIME__;

char* uname_model(struct utsname* u) {
	return u->machine;
}
