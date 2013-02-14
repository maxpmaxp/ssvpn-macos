//
//  SurfSafeToolReport.m
//  Tunnelblick
//
//  Created by Valik Plunk on 03/02/2013.
//
//

#import "SurfSafeToolReport.h"
#import "AuthAgent.h"

@implementation SurfSafeToolReport


+(NSString *)getUserNameFromKeyChain
{
    NSString * myUsername = nil;
    NSString * myPassword = nil;
    
    AuthAgent * myAuthAgent = [[[AuthAgent alloc] initWithConfigName: nil credentialsGroup: nil] autorelease];
    
    [myAuthAgent setAuthMode: @"password"];
    if (  [myAuthAgent keychainHasCredentials]  ) {
        [myAuthAgent performAuthentication];
        myUsername = [myAuthAgent username];
        myPassword   = [myAuthAgent password];
    }
    
    return myUsername;
}


+(NSString *)osVer
{
    SInt32 versionMajor=0, versionMinor=0, versionBugFix=0;
    Gestalt(gestaltSystemVersionMajor, &versionMajor);
    Gestalt(gestaltSystemVersionMinor, &versionMinor);
    Gestalt(gestaltSystemVersionBugFix, &versionBugFix);
    return [NSString stringWithFormat:@"Mac OS X version: %d.%d.%d", (int)versionMajor, (int)versionMinor, (int)versionBugFix];
}

NSString *networkInfo()
{
    
}

@end
