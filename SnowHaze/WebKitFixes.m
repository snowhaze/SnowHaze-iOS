//
//  WebKitFixes.m
//  SnowHaze
//
//
//  Copyright © 2020 Illotros GmbH. All rights reserved.
//

#import "WebKitFixes.h"

@implementation WKNavigationAction (Fixes)

- (WKFrameInfo*)realSourceFrame {
	return [self sourceFrame];
}

@end

@implementation WKFrameInfo (Fixes)

- (NSURLRequest*)realRequest {
	return [self request];
}

@end
