//
//  NSApplication+Relaunch.m
//  Tunnelblick
//
//  Created by Lion User on 10/05/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "NSApplication+Relaunch.h"

@implementation NSApplication (Relaunch)
- (void) relaunch:(id)sender appPath:(NSString *)path
{
    NSString *relaunchPath = [[NSBundle mainBundle] pathForResource:@"relaunch" ofType:nil];
    NSLog(@"relaunch path %@", relaunchPath);
    [NSTask launchedTaskWithLaunchPath:relaunchPath 
                             arguments: [NSArray arrayWithObjects:path, [NSString stringWithFormat:@"%d", [[NSProcessInfo processInfo] processIdentifier]], nil]];
}
@end
