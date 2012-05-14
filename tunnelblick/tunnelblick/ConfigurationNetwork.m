//
//  ConfigurationNetwork.m
//  Tunnelblick
//
//  Created by Lion User on 14/05/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//


#import "ConfigurationNetwork.h"

@implementation Proxy
@synthesize host        = mHost;
@synthesize protocol    = mProtocol;
@synthesize port        = mPort;

- (id) initWithHost:(NSString *)host port:(NSInteger)port protocol:(NSString *)protocol{
    if(self = [super init]){
        mHost = host;
        mPort = port;
        mProtocol = protocol;
    }
    return self;
}

@end
@interface ConfigurationNetwork(Private)
- (NSString *) dotask: (NSArray*) args;
- (NSString *) networkService;
@end


@implementation ConfigurationNetwork

static ConfigurationNetwork *gInstance = NULL;

+ (id) sharedInstance{
    if(gInstance == NULL){
        gInstance = [[[self alloc] init] autorelease];
    }
    return gInstance;
}

- (BOOL) getProxySetting:(Proxy *)proxy protocol: (int) protocol{
    NSString *cmd;
    NSString *networkService = [self networkService];
    switch (protocol) {
        case kWEB:
            cmd = @"-getwebproxy";
            break;
        case kFTP:
            cmd = @"-getftpproxy";
            break;
        case kSOCKET:
            cmd = @"-getwebproxy";
            break;
        default:
            break;
    }
    NSArray *args = [[NSArray alloc] initWithObjects:cmd, networkService, nil];    
    NSString *output = [self dotask:args];
    NSLog(@"get proxy %@", output);
    
    return YES;  
}

- (BOOL) isProxyEnable:(int)protocol{
    NSString *cmd;
    NSString *state;
    NSString *networkService = [self networkService];
    
    switch (protocol) {
        case kWEB:
            cmd = @"-getwebproxystate";
            break;
        case kFTP:
            cmd = @"-getftpproxystate";
            break;
        case kSOCKET:
            cmd = @"-getwebproxystate";
            break;
        default:
            break;
    }
    NSArray *args = [[NSArray alloc] initWithObjects:cmd, networkService, nil];    
    NSString *output = [self dotask:args];
    NSLog(@"set proxy state %@", output);
    
    return NO;
}

- (void) setProxyEnable:(int)protocol enabled:(BOOL)enabled{
    NSString *cmd;
    NSString *state;
    NSString *networkService = [self networkService];
    
    switch (protocol) {
        case kWEB:
            cmd = @"-setwebproxystate";
            break;
        case kFTP:
            cmd = @"-setftpproxystate";
            break;
        case kSOCKET:
            cmd = @"-setwebproxystate";
            break;
        default:
            break;
    }
    if (enabled){
        state = @"on";
    }else{
        state = @"off";
    }
    
    NSArray *args = [[NSArray alloc] initWithObjects:cmd, networkService, state, nil];    
    NSString *output = [self dotask:args];
    NSLog(@"set proxy state %@", output);
}

- (BOOL) setProxySetting:(Proxy *)proxy protocol:(int)protocol{
    NSString *cmd;
    NSString *networkService = [self networkService];
    switch (protocol) {
        case kWEB:
            cmd = @"-setwebproxy";
            break;
        case kFTP:
            cmd = @"-setftpproxy";
            break;
        case kSOCKET:
            cmd = @"-setwebproxy";
            break;
        default:
            break;
    }
    
    NSString *param = [NSString stringWithFormat:@"%@ %d", [proxy host], [proxy port]];
    
    NSArray *args = [[NSArray alloc] initWithObjects:cmd, networkService, param, nil];    
    NSString *output = [self dotask:args];
    NSLog(@"set proxy %@", output);
    return NO;
}

- (NSString *) dotask:(NSArray *) args{
    NSString *cmd = @"/usr/sbin/networksetup";
    NSPipe *pipe = [NSPipe pipe];
    
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:cmd];
    [task setArguments:args];
    [task setStandardOutput:pipe];
    [task setStandardError:pipe];
    [task waitUntilExit];
    [task launch];
    [task release];
    
    NSFileHandle *read = [pipe fileHandleForReading];
    NSData * data =[read readDataToEndOfFile];
    NSString *stringRead = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return [stringRead autorelease];
}

- (NSString *) networkService{
    SCPreferencesRef prefs = SCPreferencesCreate(NULL,(CFStringRef) @"SystemCofiguration", NULL);
    SCNetworkSetRef item = SCNetworkSetCopyCurrent(prefs);
    NSString * name = (NSString *) SCNetworkSetGetName(item);
    NSLog(@"network name %@", name);
    return name;
}

@end

