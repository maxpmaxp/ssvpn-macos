//
//  ConfigurationNetwork.m
//  Tunnelblick
//
//  Created by Lion User on 14/05/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//


#import "ConfigurationNetwork.h"
#import "defines.h"

extern NSFileManager        * gFileMgr;

@implementation Proxy
@synthesize host        = mHost;
@synthesize port        = mPort;
@synthesize enabled     = mEnabled;

- (id) initWithHost:(NSString *)aHost port:(NSString *)aPort enabled: (NSString *) aEnabled{
    self = [super init];
    if(self){
        self.host       = [aHost copy];
        mPort       = [aPort copy];
        mEnabled    = [aEnabled copy];
    }
    return self;
}


- (void) dealloc{
    [mHost release];
    [mPort release];
    [mEnabled release];
}
@end
@interface ConfigurationNetwork(Private)
- (NSString *) dotask: (NSArray*) args;
- (NSString *) networkService;
- (void) loadProxiesFromFile: (NSString *) filename;
- (void) saveProxiesToFile: (NSString *)filename;
- (BOOL) parserData:(NSString*) data to:(Proxy **)proxy error:(NSError **)err;
- (NSDictionary *) proxy2dict: (Proxy*) proxy;
- (Proxy *) dict2proxy: (NSDictionary *) dict;
@end


@implementation ConfigurationNetwork



+ (id) sharedInstance{
    static ConfigurationNetwork *gInstance = nil;
    if(gInstance == nil){
        gInstance = [[[ConfigurationNetwork alloc] init] autorelease];        
    }
    return gInstance;
}

- (id) init {
    if(self = [super init]){
        systemWebProxyEth = [[Proxy alloc]init];
        systemFtpProxyEth = [[Proxy alloc]init];
        systemSocketProxyEth = [[Proxy alloc]init];
        
        systemWebProxyWiFi = [[Proxy alloc]init];
        systemFtpProxyWiFi = [[Proxy alloc]init];
        systemSocketProxyWiFi = [[Proxy alloc]init];
        [self backupSystemProxies];
    }
    return self;
}

- (void) backupSystemProxies{
    NSString * backupPath = [NSHomeDirectory() stringByAppendingPathComponent:BACKUP_PATH];
    NSString * proxyBackupPath = [backupPath stringByAppendingPathComponent:@"system.proxy.backup"];
    if(!isBackup){
        if([gFileMgr fileExistsAtPath:proxyBackupPath]){
            [self loadProxiesFromFile: proxyBackupPath];
        }else{
            [self getProxySetting:&systemWebProxyEth protocol:kWEB service:kEthernet];
            [self getProxySetting:&systemFtpProxyEth protocol:kFTP service:kEthernet];
            [self getProxySetting:&systemSocketProxyEth protocol:kSOCKET service:kEthernet];
    
            [self getProxySetting:&systemWebProxyWiFi protocol:kWEB service:kWireless];
            [self getProxySetting:&systemFtpProxyWiFi protocol:kFTP service:kWireless];
            [self getProxySetting:&systemSocketProxyWiFi protocol:kSOCKET service:kWireless];
            
            [self saveProxiesToFile:proxyBackupPath];
        }   
    }
    isBackup = YES;
}

- (void) restoreSystemProxies{
    NSString * backupPath = [NSHomeDirectory() stringByAppendingPathComponent:BACKUP_PATH];
    NSString * proxyBackupPath = [backupPath stringByAppendingPathComponent:@"system.proxy.backup"];
    
    if(isBackup){
        [self setProxySetting:systemWebProxyEth protocol:kWEB service:kEthernet];
        [self setProxySetting:systemFtpProxyEth protocol:kFTP service:kEthernet];
        [self setProxySetting:systemSocketProxyEth protocol:kSOCKET service:kEthernet];
        
        [self setProxySetting:systemWebProxyEth protocol:kWEB service:kWireless];
        [self setProxySetting:systemFtpProxyEth protocol:kFTP service:kWireless];
        [self setProxySetting:systemSocketProxyEth protocol:kSOCKET service:kWireless];
        
        NSError *err;
        [gFileMgr removeItemAtPath:proxyBackupPath error:&err];
    }
    isBackup = NO;
}

- (BOOL) getProxySetting:(Proxy **)proxy protocol: (int) protocol service: (NSString *) service{
    NSString *cmd;
    NSString *networkService = service;
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
    NSError *err;
    [self parserData:output to:proxy error:&err];


    return YES;  
}

- (BOOL) isProxyEnable:(int)protocol{
    NSString *cmd;
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

- (BOOL) setProxySetting:(Proxy *)proxy protocol:(int)protocol service:(NSString*) service{
    NSString *cmd;
    NSString *networkService = service;
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
    return kEthernet;
}

- (BOOL) parserData:(NSString*) data to:(Proxy **)proxy error:(NSError **)err{
    if ([data length] == 0){
        *proxy = [[[Proxy alloc] initWithHost:@"" port:@"0" enabled:@"No"] autorelease];
        *err = [[[NSError alloc]initWithDomain:@"Error: no data." code:-1 userInfo:nil] autorelease];
        
        return NO;
    }
    
    if ([data rangeOfString:@"Error"].location != NSNotFound){
        *err = [[[NSError alloc]initWithDomain:data code:-2 userInfo:nil] autorelease];
        *proxy = [[[Proxy alloc] initWithHost:@"" port:@"0" enabled:@"No"] autorelease];
        
        return NO;
    }
        
    NSArray *arr = [data componentsSeparatedByString:@"\n"];
    NSString *strEnabled    = [arr objectAtIndex:0];
    NSString *strServer     = [arr objectAtIndex:1];
    NSString *strPort       = [arr objectAtIndex:2];
    NSString *strAuthen     = [arr objectAtIndex:3];
    
    NSString *enabled = [[[strEnabled componentsSeparatedByString:@":"] objectAtIndex:1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *server = [[[strServer componentsSeparatedByString:@":"] objectAtIndex:1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *port =  [[[strPort componentsSeparatedByString:@":"] objectAtIndex:1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *authen =  [[[strAuthen componentsSeparatedByString:@":"] objectAtIndex:1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    
    *proxy = [[Proxy alloc] initWithHost:server port: port  enabled: enabled];
    return YES;
}

- (void) loadProxiesFromFile: (NSString *) filename{
    NSDictionary * dict = [NSDictionary dictionaryWithContentsOfFile: filename];
    NSDictionary * ethDict = [dict objectForKey:kEthernet];
    NSDictionary * wiDict = [dict objectForKey:kWireless];
    
    systemWebProxyEth = [self dict2proxy: [ethDict objectForKey:@"web"]];
    systemFtpProxyEth = [self dict2proxy: [ethDict objectForKey:@"ftp"]];
    systemSocketProxyEth = [self dict2proxy: [ethDict objectForKey:@"socket"]];
    
    systemWebProxyWiFi = [self dict2proxy: [wiDict objectForKey:@"web"]];
    systemFtpProxyWiFi = [self dict2proxy: [wiDict objectForKey:@"ftp"]];
    systemSocketProxyWiFi = [self dict2proxy: [wiDict objectForKey:@"socket"]];    
}

- (void) saveProxiesToFile:(NSString *)filename{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc]init];
    NSMutableDictionary * ethDict = [[NSMutableDictionary alloc]init];
    NSMutableDictionary * wiDict = [[NSMutableDictionary alloc]init];
    
    [ethDict setObject: [self proxy2dict: systemWebProxyEth] forKey: @"web"];
    [ethDict setObject: [self proxy2dict: systemFtpProxyEth] forKey: @"ftp"];
    [ethDict setObject: [self proxy2dict: systemSocketProxyEth] forKey: @"socket"];
    
    [wiDict setObject: [self proxy2dict: systemWebProxyWiFi] forKey: @"web"];
    [wiDict setObject: [self proxy2dict: systemFtpProxyWiFi] forKey: @"ftp"];
    [wiDict setObject: [self proxy2dict: systemSocketProxyWiFi] forKey: @"socket"];
    
    [dict setObject:ethDict forKey:kEthernet];
    [dict setObject:wiDict forKey:kWireless];    
    [dict writeToFile:filename atomically:YES];
}

- (Proxy*) dict2proxy:(NSDictionary *)dict{
    Proxy *proxy = [[Proxy alloc] initWithHost: [dict objectForKey:@"host"] 
                                          port: [dict objectForKey:@"port"] 
                                       enabled: [dict objectForKey: @"enabled"]];
    return [proxy autorelease];
}

-(NSDictionary*) proxy2dict:(Proxy *)proxy{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    [dict setObject: [proxy host] forKey: @"host"];
    [dict setObject: [proxy port] forKey: @"port"];
    [dict setObject: [proxy enabled] forKey: @"enabled"];
    return [dict autorelease];
}

@end

