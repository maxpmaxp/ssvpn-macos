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

extern NSFileManager        * gFileMgr;

@implementation SurfSafeUpdater

@synthesize delegate;
@synthesize hosts;

-(id) init{
    if (  self = [super init]  ) {
        isOutOfDate = NO;
        hosts = [[NSMutableDictionary alloc] init];
        //[self getServerList: @""];
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
        NSString *version = [infoPlist objectForKey:@"CFBundleVersion"];
        NSString *os = @"mac";
        
        NSString *serverListUrl = [infoPlist objectForKey:@"SUServerListURL"];
        
        NSString *requestURL = [NSString stringWithFormat:@"%@?v=%@&os=%@", serverListUrl, version, os];
        
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
    NSString * configPath = [NSHomeDirectory() stringByAppendingPathComponent: CONFIGURATION_PATH];
    NSString * updatePath = [NSHomeDirectory() stringByAppendingPathComponent:UPDATE_PATH];
    NSString * outdateFile = [updatePath stringByAppendingPathComponent:@"update_config"];
    
    if (![gFileMgr fileExistsAtPath:outdateFile])
        return;
    
    
    NSString *keyFile = [updatePath stringByAppendingPathComponent:@"keys.zip"];
    NSString *templateFile = [updatePath stringByAppendingPathComponent:@"ovpn.ovpn"];
    //NSString *hostFile = [updatePath stringByAppendingPathComponent:@"hosts"];
    NSError *err;
    
    NSString *template = [NSString stringWithContentsOfFile:templateFile encoding:NSUTF8StringEncoding error:&err];
    
    
    //NSDictionary *hosts = [NSDictionary dictionaryWithContentsOfFile: hostFile];
    NSArray *arr = [hosts allKeys];
    
    NSLog(@"host count %d", [hosts count]);
    
    for (int i=0; i< [arr count]; i++){
        NSString *host = [arr objectAtIndex:i];
        if ([host isEqualToString:@"version"])
            continue;
        NSString *name = host;
        NSString *hostFile = [NSString stringWithFormat:@"%@/%@.ovpn", configPath, name];
        
        NSArray * arr = [hosts objectForKey:host];
        
        NSString *content = [template stringByReplacingOccurrencesOfString:@"%ADDRESS%" withString: [arr objectAtIndex:0]];
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
    NSError *err;
    
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
        NSString *os = [attributeDict objectForKey:@"os"];
        if ([os isEqualToString:@"mac"]){
            NSString *appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
            NSString *serverVersion = [attributeDict objectForKey:@"version"];
            newVersion = serverVersion;
            [hosts setObject:serverVersion forKey:@"version"];
            if (![appVersion isEqualToString:serverVersion]){                
                isOutOfDate = YES;
                isConfigOutOfDate = YES;
                updateURL = [[attributeDict objectForKey:@"url"] copy];
            }
        }        
    }   
    else if ([elementName isEqualToString:@"host"]){
        NSString *configPath = [NSHomeDirectory() stringByAppendingPathComponent:CONFIGURATION_PATH];
        //NSString *updatePath = [NSHomeDirectory() stringByAppendingPathComponent:UPDATE_PATH];
        NSString *hostname, *displayname, *location, *proxy;
        
        hostname    = [attributeDict objectForKey:@"hostname"];
        displayname = [attributeDict objectForKey:@"name"];
        location    = [attributeDict objectForKey:@"location"];
        proxy       = [attributeDict objectForKey:@"proxy"];
        
        NSString *name = [[hostname componentsSeparatedByString:@"."] objectAtIndex:0];
        NSString *host = [NSString stringWithFormat:@"%@.ovpn", name];
        NSString* hostPath = [configPath stringByAppendingPathComponent:host];
        
        if (![gFileMgr fileExistsAtPath:hostPath]){
            isConfigOutOfDate = true;
            numOfHostLost += 1;
        }
        
        
        NSArray *arr = [[NSMutableArray alloc] initWithObjects:hostname, displayname, location, proxy, nil];
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
    if (isOutOfDate || isConfigOutOfDate){
        [gFileMgr removeItemAtPath:hostsPath error:&err];
        
        [hosts writeToFile:hostsPath atomically:YES];
        NSError *err;
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
    
    
    if( [delegate respondsToSelector:@selector(checkForUpdateFinished:)]){
        NSUInteger hostCount = [hosts count];
        if (numOfHostLost == hostCount)
            [delegate checkForUpdateFinished: isOutOfDate generateFiles:YES];
        else
            [delegate checkForUpdateFinished: isOutOfDate generateFiles:NO];
    }
}

@end
