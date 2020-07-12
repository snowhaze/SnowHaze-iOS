//
//  WebKitFixes.h
//  SnowHaze
//
//
//  Copyright © 2020 Illotros GmbH. All rights reserved.
//

#import <WebKit/WebKit.h>
#import <Foundation/Foundation.h>

@interface WKNavigationAction (Fixes)

@property (readonly) WKFrameInfo* __nullable realSourceFrame;

@end

@interface WKFrameInfo (Fixes)

@property (readonly) NSURLRequest* __nullable realRequest;

@end
