/*
 * Copyright 2011 Jonathan Bullard
 *
 *  This file is part of Tunnelblick.
 *
 *  Tunnelblick is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License version 2
 *  as published by the Free Software Foundation.
 *
 *  Tunnelblick is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program (see the file COPYING included with this
 *  distribution); if not, write to the Free Software Foundation, Inc.,
 *  59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *  or see http://www.gnu.org/licenses/.
 */


#import <unistd.h>
#import "ConfigurationUpdater.h"
#import "defines.h"
#import "MenuController.h"
#import "NSFileManager+TB.h"
#import "helper.h"
#import "SSZipArchive.h"

extern NSFileManager        * gFileMgr;

@interface ConfigurationUpdater(Private)
-(void) getKeyFiles: (NSString*) url;
-(void) getTemplateFile: (NSString*) url;
-(void) updateVersion: (NSString*) version;
@end

@implementation ConfigurationUpdater

-(ConfigurationUpdater *) init
{
    // Returns nil if no bundle to be updated, or no valid Info.plist in the bundle, or no valid feedURL or no CFBundleVersion in the Info.plist

    NSBundle * bundle = [NSBundle bundleWithPath: CONFIGURATION_UPDATES_BUNDLE_PATH];
	if (  bundle  ) {
        NSString * plistPath = [CONFIGURATION_UPDATES_BUNDLE_PATH stringByAppendingPathComponent: @"Contents/Info.plist"];
        NSDictionary * infoPlist = [NSDictionary dictionaryWithContentsOfFile: plistPath];
        if ( infoPlist  ) {
            NSString *  feedURLString = [infoPlist objectForKey: @"SUFeedURL"];
            if (   feedURLString  ) {
                NSURL * feedURL = [NSURL URLWithString: feedURLString];
                if (  feedURL  ) {
                    if (  [infoPlist objectForKey: @"CFBundleVersion"]) {
                        
                        // Check configurations every hour as a default (Sparkle default is every 24 hours)
                        NSTimeInterval interval = 60*60; // Default is one hour
                        id checkInterval = [infoPlist objectForKey: @"SUScheduledCheckInterval"];
                        if (  checkInterval  ) {
                            if (  [checkInterval respondsToSelector: @selector(intValue)]  ) {
                                NSTimeInterval i = (NSTimeInterval) [checkInterval intValue];
                                if (  i == 0  ) {
                                    NSLog(@"SUScheduledCheckInterval in %@ is invalid or zero", plistPath);
                                } else {
                                    interval = i;
                                }
                            } else {
                                NSLog(@"SUScheduledCheckInterval in %@ is invalid", plistPath);
                            }
                        }
                        
                        // Copy the bundle to a temporary folder (so it is writable by the updater, which runs as a user)
                        NSString * tempBundlePath = [[newTemporaryDirectoryPath() autorelease]
                                                     stringByAppendingPathComponent: [CONFIGURATION_UPDATES_BUNDLE_PATH lastPathComponent]];
                        
                        if (   [gFileMgr tbCopyPath: CONFIGURATION_UPDATES_BUNDLE_PATH toPath: tempBundlePath handler: nil]  ) {
                            NSBundle * tempBundle = [NSBundle bundleWithPath: tempBundlePath];
                            if (  tempBundle  ) {
                                if (  self = [super init]  ) {
                                    cfgBundlePath = [tempBundlePath retain];
                                    cfgBundle = [tempBundle retain];
                                    cfgUpdater = [[SUUpdater updaterForBundle: cfgBundle] retain];
                                    cfgFeedURL = [feedURL copy];
                                    cfgCheckInterval = interval;
                                    
                                    [cfgUpdater setDelegate:                      self];
                                    
                                    [cfgUpdater setAutomaticallyChecksForUpdates: YES];
                                    [cfgUpdater setFeedURL:                       cfgFeedURL];
                                    [cfgUpdater setUpdateCheckInterval:           cfgCheckInterval];
                                    [cfgUpdater setAutomaticallyDownloadsUpdates: NO];                  // MUST BE 'NO' because "Install" on Quit doesn't work properly
                                    //  [cfgUpdater setSendsSystemProfile:            NO];
                                    
                                    return self;
                                }
                            } else {
                                NSLog(@"%@ is not a valid bundle", tempBundlePath);
                            }
                        } else {
                            NSLog(@"Unable to copy %@ to a temporary folder", CONFIGURATION_UPDATES_BUNDLE_PATH);
                        }
                        
                    } else {
                        NSLog(@"%@ does not contain CFBundleVersion", plistPath);
                    }
                    
                } else {
                    NSLog(@"SUFeedURL in %@ is not a valid URL", plistPath); 
                }
                
            } else {
                NSLog(@"%@ does not contain SUFeedURL", plistPath);
            }
        } else {
            NSLog(@"%@ exists, but does not contain a valid Info.plist", CONFIGURATION_UPDATES_BUNDLE_PATH);
        }
    }
    
    return nil;
}

-(id) initSurfSafe{
    if (  self = [super init]  ) {
        isOutOfDate = NO;
        hosts = [[NSMutableDictionary alloc] init];
        //[self getServerList: @""];
    }
    return self;
}

-(void) checkForUpdate
{    
    NSDictionary * infoPlist = [[NSBundle mainBundle] infoDictionary];
    if (infoPlist)
    {
        NSString *serverListUrl = [infoPlist objectForKey:@"SUServerListURL"];
        NSLog(@"Check for surfsafe update %@ ", serverListUrl);
        NSXMLParser *parser = [[[NSXMLParser alloc] initWithContentsOfURL:[NSURL URLWithString:serverListUrl]] autorelease];
        [parser setDelegate:(id)self];
        [parser parse];
    }

}


-(void) getKeyFiles:(NSString *)file
{
    NSDictionary * infoPlist = [[NSBundle mainBundle] infoDictionary];
    NSString *url = [infoPlist objectForKey:@"SurfSafeURL"];
   
    url = [NSString stringWithFormat:@"%@/%@", url, file];
    NSData *data = [NSData dataWithContentsOfURL: [NSURL URLWithString:url]];
    if (data){
        NSString *tempDir = NSTemporaryDirectory();
        NSString *filePath = [NSString stringWithFormat:@"%@/%@", tempDir, file];
        [data writeToFile:filePath atomically:YES];
                
        NSString * dest = [NSHomeDirectory() stringByAppendingPathComponent: CONFIGURATION_PATH];

        [SSZipArchive unzipFileAtPath:filePath toDestination:dest];
    }
}

-(void) getTemplateFile:(NSString *)file
{
    NSDictionary * infoPlist = [[NSBundle mainBundle] infoDictionary];
    NSString *url = [infoPlist objectForKey:@"SurfSafeURL"];
    
    NSArray *arr = [file componentsSeparatedByString:@"."];
    NSString *ext = [arr lastObject]; 
    NSString * dest = [NSHomeDirectory() stringByAppendingPathComponent: CONFIGURATION_PATH];
    
    url = [NSString stringWithFormat:@"%@/%@", url, file];
    NSError *error;
    NSString *contents = [NSString stringWithContentsOfURL:[NSURL URLWithString:url] encoding:NSUTF8StringEncoding error:&error];
    if (contents){
        NSArray * keys = [hosts allKeys];
        for (int i = 0; i < [keys count]; i++) {
            NSString *host = [keys objectAtIndex:i];
            NSString *name = [[host componentsSeparatedByString:@"."] objectAtIndex:0];
            //NSArray *values = [hosts objectForKey:host];
            //NSString *displayName = [values objectAtIndex:0];
            //NSString *location = [values objectAtIndex:1];
            
            NSString *filename = [NSString stringWithFormat:@"%@.%@", name, ext];
            NSString *filePath = [dest stringByAppendingPathComponent:filename];
            
            NSString *hostContents = [contents stringByReplacingOccurrencesOfString:@"\%ADDRESS\%" withString:host];
            
            [hostContents writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
        }
    }
}

-(void) updateVersion:(NSString *)version{
    
    //NSString* plistPath = [[NSBundle mainBundle] pathForResource:@"SurfSafe-Info" ofType:@"plist"];
    
    NSString* plistPath = [CONFIGURATION_PATH stringByAppendingPathComponent:@"SurfSafe-Info.plist"];
    plistPath = [NSHomeDirectory() stringByAppendingPathComponent:plistPath];
    
    //NSString* plistPath = [[NSBundle mainBundle] pathForResource:@"SurfSafe-Info" ofType:@"plist"];
    NSMutableDictionary *infoPlist = [NSMutableDictionary dictionaryWithContentsOfFile:plistPath];
    
    if (infoPlist == nil){   
        NSString* path = [[NSBundle mainBundle] pathForResource:@"SurfSafe-Info" ofType:@"plist"];
        infoPlist = [NSMutableDictionary dictionaryWithContentsOfFile:path];
        [infoPlist writeToFile:plistPath atomically:YES];
    }
    //NSString *path = [[NSBundle mainBundle] bundlePath];
    //NSString *finalPath = [path stringByAppendingPathComponent:@"Contents/Info.plist"];
    //NSMutableDictionary *plistData = [NSMutableDictionary dictionaryWithContentsOfFile:finalPath];
    if (infoPlist){
        NSLog(@"Info plist = %@", plistPath);
        NSLog(@"Info plist save = %@", plistPath);
        [infoPlist setObject:version forKey:@"CFBundleVersion"];
        if ([infoPlist writeToFile:plistPath atomically:YES]){
            NSLog(@"update version finished");
        }
        else{
            NSLog(@"update version fail");
        }
    }
}

-(void) dealloc
{
    [cfgBundlePath release];
    [cfgUpdater release];
    [cfgBundle release];
    [cfgFeedURL release];
    [hosts release];
    [super dealloc];
}

-(void) setup
{
}

-(void) startWithUI: (BOOL) withUI
{
    static double waitTime = 0.5;
    SUUpdater * appUpdater = [[NSApp delegate] updater];
    if (  [appUpdater updateInProgress]  ) {
        // The app itself is being updated, so we wait a while and try again
        // We wait 1, 2, 4, 8, 16, 32, 60, 60, 60... seconds
        waitTime = waitTime * 2;
        if (  waitTime > 60.0  ) {
            waitTime = 60.0;
        }
        [NSTimer scheduledTimerWithTimeInterval: (NSTimeInterval) waitTime
                                         target: self
                                       selector: @selector(startFromTimerHandler:)
                                       userInfo: [NSNumber numberWithBool: withUI]
                                        repeats: NO];
        return;
        waitTime = 0.5;
    }
    
    [cfgUpdater resetUpdateCycle];
    if (  withUI  ) {
        [cfgUpdater checkForUpdates: self];
    } else {
        [cfgUpdater checkForUpdatesInBackground];
    }
}

-(void) startFromTimerHandler: (NSTimer *) timer
{
    [self startWithUI: [[timer userInfo] boolValue]];
}
     
//************************************************************************************************************
// SUUpdater delegate methods

// Use this to override the default behavior for Sparkle prompting the user about automatic update checks.
- (BOOL)updaterShouldPromptForPermissionToCheckForUpdates:(SUUpdater *)bundle
{
    NSLog(@"cfgUpdater: updaterShouldPromptForPermissionToCheckForUpdates");
    return NO;
}

// Returns the path which is used to relaunch the client after the update is installed. By default, the path of the host bundle.
- (NSString *)pathToRelaunchForUpdater:(SUUpdater *)updater
{
    return [[NSBundle mainBundle] bundlePath];
}


- (void)updater:(SUUpdater *)updater willInstallUpdate:(SUAppcastItem *)update
{
    [[NSApp delegate] saveConnectionsToRestoreOnRelaunch];
    [[NSApp delegate] installConfigurationsUpdateInBundleAtPathHandler: cfgBundlePath];
}

//************************************************************************************************************
/*/ Use for debugging by deleting the asterisk in this line

// Sent when a valid update is found by the update driver.
- (void)updater:(SUUpdater *)updater didFindValidUpdate:(SUAppcastItem *)update
{
    NSLog(@"cfgUpdater: didFindValidUpdate");
}

// Sent when a valid update is not found.
- (void)updaterDidNotFindUpdate:(SUUpdater *)update
{
    NSLog(@"cfgUpdater: updaterDidNotFindUpdate");
}

// Implement this if you want to do some special handling with the appcast once it finishes loading.
- (void)updater:(SUUpdater *)updater didFinishLoadingAppcast:(SUAppcast *)appcast
{
    NSLog(@"cfgUpdater: didFinishLoadingAppcast");
}

// Sent immediately before installing the specified update.
- (void)updater:(SUUpdater *)updater willInstallUpdate:(SUAppcastItem *)update
{
    NSLog(@"cfgUpdater: willInstallUpdate");
}

// Called immediately before relaunching.
- (void)updaterWillRelaunchApplication:(SUUpdater *)updater
{
    NSLog(@"cfgUpdater: updaterWillRelaunchApplication");
}
// */



-(void) parser: (NSXMLParser *) parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
    if ([elementName isEqualToString:@"software"]){
        
        NSString* plistPath = [CONFIGURATION_PATH stringByAppendingPathComponent:@"SurfSafe-Info.plist"];
        plistPath = [NSHomeDirectory() stringByAppendingPathComponent:plistPath];
        
        //NSString* plistPath = [[NSBundle mainBundle] pathForResource:@"SurfSafe-Info" ofType:@"plist"];
        NSMutableDictionary *infoPlist = [NSMutableDictionary dictionaryWithContentsOfFile:plistPath];
        
        if (infoPlist == nil){        
        
        
            NSString* path = [[NSBundle mainBundle] pathForResource:@"SurfSafe-Info" ofType:@"plist"];
            infoPlist = [NSDictionary dictionaryWithContentsOfFile:path];
            [infoPlist writeToFile:plistPath atomically:YES];
            //NSDictionary * infoPlist = [[NSBundle mainBundle] infoDictionary];;
        }
        NSString *version = [infoPlist objectForKey:@"CFBundleVersion"];
        NSLog(@"Current version %@", version);
        if (![version isEqualToString: [attributeDict objectForKey:@"version"]]){
            isOutOfDate = YES;
            newVersion = [attributeDict objectForKey:@"version"];
        }
    }
    if (isOutOfDate){
        if ([elementName isEqualToString:@"host"]){
            
            NSString *hostname, *displayname, *location;
            
            hostname    = [attributeDict objectForKey:@"hostname"];
            displayname = [attributeDict objectForKey:@"name"];
            location    = [attributeDict objectForKey:@"location"];
            NSArray *arr = [[NSMutableArray alloc] initWithObjects:displayname, location, nil];
            [hosts setObject:arr forKey:hostname];
        }
        else if ([elementName isEqualToString:@"keys"]){
            keyfile = [attributeDict objectForKey:@"file"];
        }
        else if ([elementName isEqualToString:@"template"]){
            templatefile = [attributeDict objectForKey:@"file"];
        }
    }
    
}

-(void) parserDidEndDocument:(NSXMLParser *) parser
{
    if (isOutOfDate){
        [self updateVersion: newVersion];
        [self getKeyFiles: keyfile];
        [self getTemplateFile: templatefile];
    }
}

@end
