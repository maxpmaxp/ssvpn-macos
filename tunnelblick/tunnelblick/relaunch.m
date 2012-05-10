//
//  relaunch.m
//  Tunnelblick
//
//  Created by Lion User on 10/05/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

int main(int argc, char *argv[])
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    pid_t parentPID = atoi(argv[2]);
    ProcessSerialNumber psn;
    while(GetProcessPID(&psn, &parentPID) != procNotFound){
        sleep(1);
    }
    
    NSString *appPath = [NSString stringWithCString:argv[1] encoding:NSUTF8StringEncoding];
    
    BOOL success = [[NSWorkspace sharedWorkspace] openFile:[appPath stringByExpandingTildeInPath]];
 
    if (!success){
        NSLog(@"Error: could not relaunch application at %@", appPath);
    }else{
        NSLog(@"Relaunched %@", appPath);
    }
    
    [pool drain];
    return (success) ? 0 : 1;
}