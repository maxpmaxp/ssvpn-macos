//
//  NSApplication+Relaunch.h
//  Tunnelblick
//
//  Created by Lion User on 10/05/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSApplication (Relaunch)
- (void) relaunch: (id) sender appPath: (NSString *) path;

@end
