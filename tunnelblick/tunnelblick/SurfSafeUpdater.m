//
//  SurfSafeUpdater.m
//  Tunnelblick
//
//  Created by Lion User on 09/05/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "SurfSafeUpdater.h"
#import <unistd.h>

#import "defines.h"
#import "MenuController.h"
#import "NSFileManager+TB.h"
#import "helper.h"
#import "SSZipArchive.h"
#import "ConfigurationManager.h"

extern NSFileManager        * gFileMgr;

@implementation SurfSafeUpdater

@synthesize delegate;
@synthesize hosts;
@synthesize isConfigOutOfDate;
@synthesize isOutOfDate;
@synthesize numOfHostLost;

-(id) init{
    if (  self = [super init]  ) {
        self.isOutOfDate = NO;
        hosts = [[NSMutableDictionary alloc] init];
        //[self getServerList: @""];
        numOfHostLost = 0;
    }
    return self;
}

-(void) setDelegate:(id<SurfSafeUpdaterDelegate>)aDelegate{
    if (delegate != aDelegate){
        delegate = aDelegate;
    }
}

-(void) checkForUpdate
{    
    if([delegate respondsToSelector:@selector(checkForUpdateStarted)]){
        [delegate checkForUpdateStarted];
    }
    numOfHostLost = 0;
    NSDictionary * infoPlist = [[NSBundle mainBundle] infoDictionary];
    if (infoPlist)
    {
        
        NSString *requestURL = @"http://cfg.surfsafevpn.com/servers.mac.xml";
        
        NSLog(@"Check for SurfSafeVPN update %@ ", requestURL);
        
        //NSError *error;


        NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:requestURL]];
        if (data){
            NSString *updatePath = [NSHomeDirectory() stringByAppendingPathComponent:UPDATE_PATH];
            BOOL isDir;
            BOOL fileExisted = [gFileMgr fileExistsAtPath:updatePath isDirectory:&isDir];
            if (!fileExisted){
                createDir(updatePath, 0755);
            }
            NSString *path = [updatePath stringByAppendingPathComponent:@"servers.xml"];
            [data writeToFile:path atomically:YES];
            NSXMLParser *parser = [[[NSXMLParser alloc] initWithData:data] autorelease];
            [parser setDelegate:(id)self];
            [parser parse];
        }
    }
}

-(void) generateFiles{
    NSString * configPath = [NSHomeDirectory() stringByAppendingPathComponent:CONFIGURATION_PATH];
    NSString * configPath2 = [[L_AS_T_DEPLOY stringByAppendingPathComponent: @"SurfSafeVPN"] copy];
    NSString * updatePath = [NSHomeDirectory() stringByAppendingPathComponent:UPDATE_PATH];
    NSString * outdateFile = [updatePath stringByAppendingPathComponent:@"update_config"];
    
    if (![gFileMgr fileExistsAtPath:outdateFile]){
        return;
    }
    
    NSString *keyFile = [updatePath stringByAppendingPathComponent:@"keys.zip"];
    NSString *templateFile = [updatePath stringByAppendingPathComponent:@"ovpn.ovpn"];
    //NSString *hostFile = [updatePath stringByAppendingPathComponent:@"hosts"];
    NSError *err = nil;
    
    //genarate file
    [SSZipArchive unzipFileAtPath:keyFile toDestination:configPath];
    
    NSString *template = [NSString stringWithContentsOfFile:templateFile encoding:NSUTF8StringEncoding error:&err];
    
    
    //NSDictionary *hosts = [NSDictionary dictionaryWithContentsOfFile: hostFile];
    NSArray *keys = [hosts allKeys];
    
    //NSLog(@"host count %d", [hosts count]);
    
    NSDirectoryEnumerator *en = [gFileMgr enumeratorAtPath:configPath];
    NSString *file;
    while(file = [en nextObject]){
        [gFileMgr removeItemAtPath:[configPath stringByAppendingPathComponent:file] error:&err ];
    }
    
    for (int i=0; i< [keys count]; i++){
        NSString *host = [keys objectAtIndex:i];
        if ([host isEqualToString:@"version"])
            continue;
        NSString *name = host;
        NSString *hostFile = [NSString stringWithFormat:@"%@/%@.ovpn", configPath, name];
        
        NSArray * arr = [hosts objectForKey:host];
        
        NSString *proxyIP = [[[arr objectAtIndex:3] componentsSeparatedByString:@":"] objectAtIndex:0];
        
        
        NSString *content = [template stringByReplacingOccurrencesOfString:@"%ADDRESS%" withString: [arr objectAtIndex:0]];
        
        content = [content stringByReplacingOccurrencesOfString:@"%PROXY_IP%" withString:proxyIP];
                
        [content writeToFile:hostFile atomically:NO encoding:NSUTF8StringEncoding error:&err];
        if(err){
            NSLog(@"Error: Can't create host file %@", hostFile);
        }

    }
    
    
    //genarate file
    [SSZipArchive unzipFileAtPath:keyFile toDestination:configPath];
    
    [gFileMgr removeItemAtPath:outdateFile error:&err];
}

-(void) downloadDmgFile{
    NSString * updatePath    = [NSHomeDirectory() stringByAppendingPathComponent:UPDATE_PATH];
    NSString * dmgPath      = [updatePath stringByAppendingPathComponent:@"SurfSafeSetup.dmg"];
    
    //[gFileMgr removeItemAtPath:dmgPath error:&err];
    
    NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:updateURL]];
    if (data){
        [data writeToFile:dmgPath atomically:YES];
    }
}

-(void) parser: (NSXMLParser *) parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{    
    NSDictionary * infoPlist = [[NSBundle mainBundle] infoDictionary];
    NSString *url = [infoPlist objectForKey:@"SurfSafeURL"];
    
    if ([elementName isEqualToString:@"application"]){
        //NSString *os = [attributeDict objectForKey:@"os"];
        //if ([os isEqualToString:@"mac"]){
            float appVersion = [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"] floatValue];
            newVersion = [attributeDict objectForKey:@"version"];
            float serverVersion = [newVersion floatValue];

            [hosts setObject: newVersion forKey:@"version"];
            if (appVersion < serverVersion){                
                self.isOutOfDate = YES;
                self.isConfigOutOfDate = YES;
                updateURL = [[attributeDict objectForKey:@"url"] copy];
            }
            if (appVersion != serverVersion)
            {
                self.isConfigOutOfDate = YES;
            }
        //}
    }   
    else if ([elementName isEqualToString:@"host"]){
        NSString *configPath = [L_AS_T_DEPLOY stringByAppendingPathComponent: @"SurfSafeVPN"];
        //NSString *updatePath = [NSHomeDirectory() stringByAppendingPathComponent:UPDATE_PATH];
        NSString *hostname, *displayname, *location, *proxy, *photoshieldEnabled;
        
        hostname    = [attributeDict objectForKey:@"hostname"];
        //HTK-INC1
//        displayname = [attributeDict objectForKey:@"name"];
        displayname = hostname;
        location    = [attributeDict objectForKey:@"location"];
//        proxy       = [attributeDict objectForKey:@"proxy"];
        proxy = [attributeDict objectForKey:@"https_proxy"];    //HTK-INC2
        if (!proxy) {
            proxy = @"10.235.0.4:3128";
        }
        photoshieldEnabled = [attributeDict objectForKey:@"photoshield_enabled"];
        //END HTK-INC1
        
        NSString *name = [[hostname componentsSeparatedByString:@"."] objectAtIndex:0];
        NSString *host = [NSString stringWithFormat:@"%@.ovpn", name];
        NSString *hostPath = [configPath stringByAppendingPathComponent:host];
        
        if (![gFileMgr fileExistsAtPath:hostPath]){
            self.isConfigOutOfDate = YES;
            numOfHostLost = numOfHostLost + 1;
        }
        
        
        NSArray *arr = [[NSMutableArray alloc] initWithObjects:hostname, displayname, location, proxy, photoshieldEnabled, nil];
        [hosts setObject:arr forKey:name];
    }
    else if ([elementName isEqualToString:@"keys"]){
        keyURL = [NSString stringWithFormat:@"%@/%@", url, [attributeDict objectForKey:@"file"]];
    }
    else if ([elementName isEqualToString:@"template"]){
        templateURL = [NSString stringWithFormat:@"%@/%@", url, [attributeDict objectForKey:@"file"]];
    }    
}


-(void) parserDidEndDocument:(NSXMLParser *) parser
{   
    NSString * updatePath    = [NSHomeDirectory() stringByAppendingPathComponent:UPDATE_PATH];
    NSString * hostsPath    = [updatePath stringByAppendingPathComponent:@"hosts"];
    NSString * keyPath      = [updatePath stringByAppendingPathComponent:@"keys.zip"];
    NSString * templatePath = [updatePath stringByAppendingPathComponent:@"ovpn.ovpn"];
    NSString * outdateFile = [updatePath stringByAppendingPathComponent:@"update_config"];

    NSError * err;
    
    // store host file
    if (self.isOutOfDate || self.isConfigOutOfDate){
        [gFileMgr removeItemAtPath:hostsPath error:&err];
        
        [hosts writeToFile:hostsPath atomically:YES];
        NSError *err = nil;
        [@" " writeToFile:outdateFile atomically:NO encoding:NSUTF8StringEncoding error:&err];

        [gFileMgr removeItemAtPath:keyPath error:&err];
        NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:keyURL]];
        [data writeToFile:keyPath atomically:YES];

        [gFileMgr removeItemAtPath:templatePath error:&err];
        data = [NSData dataWithContentsOfURL:[NSURL URLWithString:templateURL]];
        [data writeToFile:templatePath atomically:YES];
    }
    else{
        [gFileMgr removeItemAtPath:hostsPath error:&err];
        [gFileMgr removeItemAtPath:keyPath error:&err];
        [gFileMgr removeItemAtPath:templatePath error:&err];
    }
    
    
    //if( [delegate respondsToSelector:@selector(checkForUpdateFinished:)]){
        NSUInteger hostCount = [hosts count];
        //hosts has object VERSION it's not a real host
        hostCount -= 1;
    
        NSString *configPath = [L_AS_T_DEPLOY stringByAppendingPathComponent: @"SurfSafeVPN"];
    
        NSUInteger configCount = [[gFileMgr contentsOfDirectoryAtPath: configPath error: nil] count];
    
    
        if([gFileMgr fileExistsAtPath: [configPath stringByAppendingPathComponent:@"keys"]]){
            configCount -= 1;
        }
    
        if ((self.numOfHostLost > 0) || (configCount !=  hostCount))
            [delegate checkForUpdateFinished: self.isOutOfDate generateFiles:YES];
        else
            [delegate checkForUpdateFinished: self.isOutOfDate generateFiles:NO];
    //}
}

@end
