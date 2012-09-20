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
#define kSWEB   0x02
#define kFTP    0x04
#define kSOCKET 0x08

#if	(__MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_6) 
    #define kWireless @"Wi-Fi"
#else
    #define kWireless @"AirPort"
#endif

#define kEthernet @"Ethernet"


@interface Proxy : NSObject {
    NSString    * mEnabled;
    NSString    * mHost;
    NSString    * mPort;  
}
@property (nonatomic, copy) NSString *host;
@property (nonatomic, copy) NSString *port;
@property (nonatomic, copy) NSString *enabled;


- (id) initWithHost: (NSString *) host port:(NSString *)port enabled:(NSString *) enabled;

@end


@interface ConfigurationNetwork : NSObject {
    Proxy       * systemWebProxyEth;
    Proxy       * systemSWebProxyEth;
    Proxy       * systemFtpProxyEth;
    Proxy       * systemSocketProxyEth;
    
    Proxy       * systemWebProxyWiFi;
    Proxy       * systemSWebProxyWiFi;
    Proxy       * systemFtpProxyWiFi;
    Proxy       * systemSocketProxyWiFi;
    
    BOOL          isBackup;
}

+ (id) sharedInstance;

- (void) backupSystemProxies;
- (void) restoreSystemProxies;

- (void) setProxyEnable: (int) protocol enabled: (BOOL) enabled networkservice: (NSString*) networkService;
- (BOOL) isProxyEnable: (int) protocol;
- (BOOL) getProxySetting: (Proxy **) proxy protocol: (int) protocol service: (NSString*) service;
- (BOOL) setProxySetting: (Proxy *) proxy protocol: (int) protocol service: (NSString*) service;

@end
