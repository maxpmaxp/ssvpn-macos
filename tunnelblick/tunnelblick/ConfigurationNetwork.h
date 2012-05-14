//
//  ConfigurationNetwork.h
//  Tunnelblick
//
//  Created by Lion User on 14/05/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>


#define kWEB    0x01
#define kFTP    0x02
#define kSOCKET 0x03

@interface Proxy : NSObject {
    NSString    * mProtocol;
    NSString    * mHost;
    NSInteger     mPort;  
}
@property (nonatomic, retain) NSString *host;
@property (nonatomic, retain) NSString *protocol;
@property (nonatomic) NSInteger port;

- (id) initWithHost: (NSString *) host port:(NSInteger)port protocol:(NSString *)protocol;

@end


@interface ConfigurationNetwork : NSObject {
    
}

+ (id) sharedInstance;

- (void) setProxyEnable: (int) protocol enabled: (BOOL) enabled;
- (BOOL) isProxyEnable: (int) protocol;
- (BOOL) getProxySetting: (Proxy *) proxy protocol: (int) protocol;
- (BOOL) setProxySetting: (Proxy *) proxy protocol: (int) protocol;

@end
