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
    NSDictionary * infoPlist = [[NSBundle mainBundle] infoDictionary];
    if (infoPlist)
    {
        NSString *version = [infoPlist objectForKey:@"CFBundleVersion"];
        NSString *os = @"mac";
        
        NSString *serverListUrl = [infoPlist objectForKey:@"SUServerListURL"];
        
        NSString *requestURL = [NSString stringWithFormat:@"%@?v=%@&os=%@", serverListUrl, version, os];
        
        NSLog(@"Check for surfsafe update %@ ", requestURL);
        
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
                updateURL = [attributeDict objectForKey:@"url"];
            }
        }        
    }
    
    
    else if ([elementName isEqualToString:@"host"]){
        
        NSString *hostname, *displayname, *location;
        
        hostname    = [attributeDict objectForKey:@"hostname"];
        displayname = [attributeDict objectForKey:@"name"];
        location    = [attributeDict objectForKey:@"location"];
        NSArray *arr = [[NSMutableArray alloc] initWithObjects:displayname, location, nil];
        [hosts setObject:arr forKey:hostname];
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
    NSString *updatePath    = [NSHomeDirectory() stringByAppendingPathComponent:UPDATE_PATH];
    NSString * hostsPath    = [updatePath stringByAppendingPathComponent:@"hosts"];
    NSString * keyPath      = [updatePath stringByAppendingPathComponent:@"keys.zip"];
    NSString * templatePath = [updatePath stringByAppendingPathComponent:@"ovpn.ovpn"];
    NSString * dmgPath      = [updatePath stringByAppendingPathComponent:@"SurfSafeSetup.dmg"];
    NSLog(@"parser did end document .....................");
    
    NSError * err;
    if (isOutOfDate){
        if ([delegate respondsToSelector:@selector(downloadUpdateStarted)]){
            [delegate downloadUpdateStarted];
        }
        [gFileMgr removeItemAtPath:dmgPath error:&err];
        
        NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:updateURL]];
        if (data){
            [data writeToFile:dmgPath atomically:YES];
        }
    }
    
    // store host file
    if (isOutOfDate || ![gFileMgr fileExistsAtPath:hostsPath]){
        [gFileMgr removeItemAtPath:hostsPath error:&err];
        [hosts writeToFile:hostsPath atomically:YES];
    }
    
    // store key file
    if (isOutOfDate || ![gFileMgr fileExistsAtPath:keyPath]){
        [gFileMgr removeItemAtPath:keyPath error:&err];
        NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:keyURL]];
        [data writeToFile:keyPath atomically:YES];
    }
    
    // store template file
    if (isOutOfDate || ![gFileMgr fileExistsAtPath:templatePath]){
        [gFileMgr removeItemAtPath:templatePath error:&err];
        NSData * data = [NSData dataWithContentsOfURL:[NSURL URLWithString:templateURL]];
        [data writeToFile:templatePath atomically:YES];
    }
    
    if (isOutOfDate){
        /*
        NSLog(@"SurfSasfe is out of date.");
        [[NSApp delegate] installSurfSafeUpdateHandler];
         */
        if( [delegate respondsToSelector:@selector(downloadUpdateFinished)]){
            [delegate downloadUpdateFinished];
        }
    }
}

@end
