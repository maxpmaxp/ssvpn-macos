/*
 * Copyright 2004, 2005, 2006, 2007, 2008, 2009 by Angelo Laub
 * Contributions by Jonathan K. Bullard Copyright 2010, 2011
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

#import <CoreServices/CoreServices.h>
#import <Foundation/NSDebug.h>
#import <pthread.h>
#import <signal.h>
#import "defines.h"
#import "ConfigurationManager.h"
#import "VPNConnection.h"
#import "helper.h"
#import "KeyChain.h"
#import "MenuController.h"
#import "NetSocket+Text.h"
#import "NSApplication+LoginItem.h"
#import "NSFileManager+TB.h"
#import "TBUserDefaults.h"
#import "MyPrefsWindowController.h"
#import "MainIconView.h"

extern NSMutableArray       * gConfigDirs;
extern NSString             * gDeployPath;
extern NSString             * gSharedPath;
extern NSString             * gPrivatePath;
extern NSFileManager        * gFileMgr;
extern TBUserDefaults       * gTbDefaults;
extern unsigned               gHookupTimeout;
extern BOOL                   gTunnelblickIsQuitting;
extern BOOL                   gComputerIsGoingToSleep;
extern NSArray              * gRateUnits;
extern NSArray              * gTotalUnits;

extern NSString * firstPartOfPath(NSString * thePath);

extern NSString * lastPartOfPath(NSString * thePath);

@interface VPNConnection()          // PRIVATE METHODS

-(void)             afterFailureHandler:            (NSTimer *)     timer;

-(NSArray *)        argumentsForOpenvpnstartForNow: (BOOL)          forNow;

-(void)             clearStatisticsRatesDisplay;

-(void)             clearStatisticsIncludeTotals:   (BOOL)          includeTotals;

-(void)             connectToManagementSocket;

-(void)             credentialsHaveBeenAskedFor:    (NSDictionary *)dict;

-(void)             didHookup;

-(void)             disconnectFromManagmentSocket;

-(void)             flushDnsCache;

-(void)             forceKillWatchdogHandler;

-(void)             forceKillWatchdog;

-(unsigned int)     getFreePort;

-(BOOL)             hasLaunchDaemon;

-(void)             killProcess;                                                // Kills the OpenVPN process associated with this connection, if any

-(NSString * )      leasewatchOptionsFromPreferences;

-(BOOL)             makeDictionary:             (NSDictionary * *)  dict
                         withLabel:             (NSString *)        daemonLabel
                  openvpnstartArgs:             (NSMutableArray * *)openvpnstartArgs;

-(void)             processLine:                (NSString *)        line;

-(void)             processState:               (NSString *)        newState
                           dated:               (NSString *)        dateTime;

-(void)             provideCredentials:         (NSString *)        parameterString
                                  line:         (NSString *)        line;

-(void)             runScriptNamed:             (NSString *)        scriptName
               openvpnstartCommand:             (NSString *)        command;

-(void)             setBit:                     (unsigned int)      bit
                    inMask:                     (unsigned int *)    bitMaskPtr
    ifConnectionPreference:                     (NSString *)        keySuffix
                  inverted:                     (BOOL)              invert;

-(void)             setConnectedSinceDate:      (NSDate *)          value;

-(void)             setManagementSocket:        (NetSocket *)       socket;

-(void)             setPort:                    (unsigned int)      inPort;

-(void)             setPreferencesFromOpenvnpstartArgString: (NSString *) openvpnstartArgString;

-(BOOL)             setPreference:              (BOOL)              value
                              key:              (NSString *)        key;

-(void)             tellUserAboutDisconnectWait;

-(NSString *)       timeString;

@end

@implementation VPNConnection

@synthesize proxy;

-(id) initWithConfigPath: (NSString *) inPath withDisplayName: (NSString *) inDisplayName
{	
    if (self = [super init]) {
        configPath = [inPath copy];
        displayName = [inDisplayName copy];
        managementSocket = nil;
		connectedSinceDate = [[NSDate alloc] init];
        logDisplay = [[LogDisplay alloc] initWithConfigurationPath: inPath];
        if (  ! logDisplay  ) {
            return nil;
        }
        [logDisplay setConnection: self];
        lastState = @"EXITING";
        requestedState = @"EXITING";
		myAuthAgent = [[AuthAgent alloc] initWithConfigName:[self displayName]];
        NSString * upSoundKey  = [displayName stringByAppendingString: @"-tunnelUpSoundName"];
        NSString * upSoundName = [gTbDefaults objectForKey: upSoundKey];
        if (  upSoundName  ) {
            if (  ! [upSoundName isEqualToString: @"None"]  ) {
                tunnelUpSound   = [NSSound soundNamed: upSoundName];
                if (  ! tunnelUpSound  ) {
                    NSLog(@"%@ '%@' not found; no sound will be played when connecting", upSoundKey, upSoundName);
                }
            }
        }
        NSString * downSoundKey  = [displayName stringByAppendingString: @"-tunnelDownSoundName"];
        NSString * downSoundName = [gTbDefaults objectForKey: downSoundKey];
        if (  downSoundName  ) {
            if (  ! [downSoundName isEqualToString: @"None"] ) {
                tunnelDownSound = [NSSound soundNamed: downSoundName];
                if (  ! tunnelDownSound  ) {
                    NSLog(@"%@ '%@' not found; no sound will be played when an unexpected disconnection occurs", downSoundKey, downSoundName);
                }
            }
        }
        portNumber = 0;
		pid = 0;
        
        tryingToHookup = FALSE;
        initialHookupTry = TRUE;
        isHookedup = FALSE;
        tunOrTap = nil;
        areDisconnecting = FALSE;
        loadedOurTap = FALSE;
        loadedOurTun = FALSE;
        logFilesMayExist = FALSE;
        authFailed       = FALSE;
        credentialsAskedFor = FALSE;
        showingStatusWindow = FALSE;
        serverNotClient = FALSE;
        
        userWantsState   = userWantsUndecided;
        
        // If a package, set preferences that haven't been defined yet
        if (  [[inPath pathExtension] isEqualToString: @"tblk"]  ) {
            NSString * infoPath = [inPath stringByAppendingPathComponent: @"Contents/Info.plist"];
            NSDictionary * infoDict = [NSDictionary dictionaryWithContentsOfFile: infoPath];
            NSString * key;
            NSEnumerator * e = [infoDict keyEnumerator];
            while (  key = [e nextObject]  ) {
                if (  [key hasPrefix: @"TBPreference"]  ) {
                    NSString * preferenceKey = [displayName stringByAppendingString: [key substringFromIndex: [@"TBPreference" length]]];
                    if (  [gTbDefaults objectForKey: preferenceKey] == nil  ) {
                        [gTbDefaults setObject: [infoDict objectForKey: key] forKey: preferenceKey];
                    }
                }
            }
        }
        
        bytecountMutexOK = FALSE;
        OSStatus status = pthread_mutex_init( &bytecountMutex, NULL);
        if (  status == EXIT_SUCCESS  ) {
            bytecountMutexOK = TRUE;
        } else {
            NSLog(@"VPNConnection:initWithConfigPath:withDisplayName: pthread_mutex_init( &bytecountMutex ) failed; status = %ld", (long) status);
        }
        statistics.lastSet = [[NSDate date] retain];
        
        [self clearStatisticsIncludeTotals: YES];        
    }
    
    return self;
}

-(void) clearStatisticsIncludeTotals: (BOOL) includeTotals
{
    OSStatus status = pthread_mutex_lock( &bytecountMutex );
    if (  status != EXIT_SUCCESS  ) {
        NSLog(@"VPNConnection:clearStatisticsIncludeTotals: pthread_mutex_lock( &bytecountMutex ) failed; status = %ld", (long) status);
        return;
    }
    
    if (  includeTotals  ) {
        statistics.totalInBytecount  = 0;
        statistics.totalOutBytecount = 0;
        statistics.totalInByteCountBeforeThisConnection  = 0;
        statistics.totalOutByteCountBeforeThisConnection = 0;
    }
    
    [statistics.lastSet release];
    statistics.lastSet = [[NSDate date] retain];
    
    statistics.rbIx = 0;
    int i;
    for (  i=0; i<RB_SIZE; i++  ) {
        statistics.rb[i].lastInBytecount  = 0;
        statistics.rb[i].lastOutBytecount = 0;
        statistics.rb[i].lastTimeInterval = 0.0;
    }
    
    [self setBytecountsUpdated: [NSDate date]];    
    
    pthread_mutex_unlock( &bytecountMutex );
}

// Reinitializes a connection -- as if we quit SurfSafeVPN and then relaunched
-(void) reInitialize
{
    [self disconnectFromManagmentSocket];
    [connectedSinceDate release]; connectedSinceDate = [[NSDate alloc] init];
    [self clearStatisticsIncludeTotals: NO];
    // Don't change logDisplay -- we want to keep it
    [lastState          release]; lastState = @"EXITING";
    [requestedState     release]; requestedState = @"EXITING";
    [myAuthAgent        release]; myAuthAgent = [[AuthAgent alloc] initWithConfigName:[self displayName]];
    [tunOrTap           release]; tunOrTap = nil;
    portNumber       = 0;
    pid              = 0;
    tryingToHookup   = FALSE;
    isHookedup       = FALSE;
    areDisconnecting = FALSE;
    loadedOurTap = FALSE;
    loadedOurTun = FALSE;
    logFilesMayExist = FALSE;
    serverNotClient = FALSE;
}

-(void) tryToHookupToPort: (int) inPortNumber
     withOpenvpnstartArgs: (NSString *) inStartArgs
{
    if (  portNumber != 0  ) {
        NSLog(@"Ignoring attempt to 'tryToHookupToPort' for '%@' -- already using port number %d", [self description], portNumber);
        return;
    }
    
    if (  managementSocket  ) {
        NSLog(@"Ignoring attempt to 'tryToHookupToPort' for '%@' -- already using managementSocket", [self description]);
        return;
    }

    [self setPort: inPortNumber];
    
    
    // We set preferences of any configuration that we try to hookup, because this might be a new user who hasn't run SurfSafeVPN,
    // and they may be hooking up to a configuration that started when the computer starts.
    [self setPreferencesFromOpenvnpstartArgString: inStartArgs];

    tryingToHookup = TRUE;
    requestedState = @"CONNECTED";
    [self connectToManagementSocket];
}

// Decodes arguments to openvpnstart and sets preferences from them
//
// We could do it by extracting arguments from the launchd .plist, but that won't work for a configuration that isn't set to
// connect when the computer starts. So we do it by decoding the arguments to openvpnstart that are part of the filename of the log file.
    
-(void) setPreferencesFromOpenvnpstartArgString: (NSString *) openvpnstartArgString
{
    NSArray * openvpnstartArgs = [openvpnstartArgString componentsSeparatedByString: @"_"];
    
    unsigned useScripts = [[openvpnstartArgs objectAtIndex: 0] intValue];
    //  unsigned skipScrSec = [[openvpnstartArgs objectAtIndex: 1] intValue];  // Skip - no preference for this
    unsigned cfgLocCode = [[openvpnstartArgs objectAtIndex: 2] intValue];
    unsigned noMonitor  = [[openvpnstartArgs objectAtIndex: 3] intValue];
    unsigned bitMask    = [[openvpnstartArgs objectAtIndex: 4] intValue];
    
    BOOL configPathBad = FALSE;
    switch (  cfgLocCode & 0x3  ) {
            
        case CFG_LOC_PRIVATE:
        case CFG_LOC_ALTERNATE:
            if (! [configPath hasPrefix: gPrivatePath] ) {
                configPathBad = TRUE;
            }
            break;
            
        case CFG_LOC_DEPLOY:
            if (! [configPath hasPrefix: gDeployPath] ) {
                configPathBad = TRUE;
            }
            break;
            
        case CFG_LOC_SHARED:
            if (! [configPath hasPrefix: gSharedPath] ) {
                configPathBad = TRUE;
            }
            break;
            
        default:
            configPathBad = TRUE;
            break;
    }
    if (  configPathBad  ) {
        NSLog(@"cfgLocCode in log file for %@ doesn't match configuration path", [self displayName]);
        [NSApp setAutoLaunchOnLogin: NO];
        [NSApp terminate: self];
    }
    
    BOOL prefsChangedOK = TRUE;
    
    // Set preferences from the ones used when connection was made
    // They are extracted from the openvpnstart args in the log filename
    
    BOOL prefUseScripts  = (useScripts & 0x1) == 0x1;
    unsigned prefScriptNum = useScripts >> 2;
    if (  prefScriptNum > 2  ) { // Disallow invalid script numbers
        prefScriptNum = 0;
        prefsChangedOK = FALSE;
    }
    
    NSString * keyUseDNS = [displayName stringByAppendingString: @"useDNS"];
    NSNumber * prefUseDNS;
    if (  prefUseScripts  ) {
        prefUseDNS = [NSNumber numberWithInt: (prefScriptNum+1)];
    } else {
        prefUseDNS = [NSNumber numberWithInt: 0];
    }
    if (  [prefUseDNS isNotEqualTo: [gTbDefaults objectForKey: keyUseDNS]]  ) {
        if (  [gTbDefaults canChangeValueForKey: keyUseDNS]  ) {
            [gTbDefaults setObject: prefUseDNS forKey: keyUseDNS];
            NSLog(@"The '%@' preference was changed to %@ because that was encoded in the filename of the log file", keyUseDNS, prefUseDNS);
        } else {
            NSLog(@"The '%@' preference could not be changed to %@ (which was encoded in the log filename) because it is a forced preference", keyUseDNS, prefUseDNS);
            prefsChangedOK = FALSE;
        }
    }
    
    //  BOOL prefUseDownRoot = (useScripts & 0x2) == 0x2;  // Skip - no preference for this
    
    BOOL prefNoMonitor = (noMonitor != 0);
    NSString * keyNoMonitor = [displayName stringByAppendingString: @"-notMonitoringConnection"];
    prefsChangedOK = prefsChangedOK && [self setPreference: prefNoMonitor key: keyNoMonitor];
    
    BOOL prefRestoreDNS  = ! (bitMask & OPENVPNSTART_RESTORE_ON_DNS_RESET)  == OPENVPNSTART_RESTORE_ON_DNS_RESET;
    NSString * keyRestoreDNS = [displayName stringByAppendingString: @"-doNotRestoreOnDnsReset"];
    prefsChangedOK = prefsChangedOK && [self setPreference: prefRestoreDNS key: keyRestoreDNS];
    
    BOOL prefRestoreWINS = ! (bitMask & OPENVPNSTART_RESTORE_ON_WINS_RESET) == OPENVPNSTART_RESTORE_ON_WINS_RESET;
    NSString * keyRestoreWINS = [displayName stringByAppendingString: @"-doNotRestoreOnWinsReset"];
    prefsChangedOK = prefsChangedOK && [self setPreference: prefRestoreWINS key: keyRestoreWINS];
    
    if ( (loadedOurTap = (bitMask & OPENVPNSTART_OUR_TAP_KEXT) == OPENVPNSTART_OUR_TAP_KEXT)  ) {
        NSString * keyLoadTun = [displayName stringByAppendingString: @"-loadTunKext"];
        prefsChangedOK = prefsChangedOK && [self setPreference: FALSE key: keyLoadTun];
    }

    if (  (loadedOurTun = (bitMask & OPENVPNSTART_OUR_TUN_KEXT) == OPENVPNSTART_OUR_TUN_KEXT) ) {
        NSString * keyLoadTap = [displayName stringByAppendingString: @"-loadTapKext"];
        prefsChangedOK = prefsChangedOK && [self setPreference: FALSE key: keyLoadTap];
    }
    
    NSString * keyAutoConnect = [displayName stringByAppendingString: @"autoConnect"];
    NSString * keyOnSystemStart = [displayName stringByAppendingString: @"-onSystemStart"];
    if (  [self hasLaunchDaemon]  ) {
        prefsChangedOK = prefsChangedOK && [self setPreference: TRUE key: keyAutoConnect];
        prefsChangedOK = prefsChangedOK && [self setPreference: TRUE key: keyOnSystemStart];
    } else {
        prefsChangedOK = prefsChangedOK && [self setPreference: FALSE key: keyAutoConnect];
        prefsChangedOK = prefsChangedOK && [self setPreference: FALSE key: keyOnSystemStart];
    }
    
    if (  ! prefsChangedOK  ) {
        [NSApp setAutoLaunchOnLogin: NO]; // Error messages have already been logged
        [NSApp terminate: self];
    }
    
    // Keep track of the number of tun and tap kexts that openvpnstart loaded
    if (  loadedOurTap  ) {
        [[NSApp delegate] incrementTapCount];
    }
    
    if (  loadedOurTun ) {
        [[NSApp delegate] incrementTunCount];
    }
}

// Returns TRUE if didn't need to change preference, or preference was changed, or FALSE if preference could not be set
-(BOOL) setPreference: (BOOL) value key: (NSString *) key
{
    if (  [gTbDefaults boolForKey: key] != value  ) {
        if (  [gTbDefaults canChangeValueForKey: key]  ) {
            [gTbDefaults setBool: value forKey: key];
            NSLog(@"The '%@' preference was changed to %@ because that was encoded in the filename of the log file", key, (value ? @"TRUE" : @"FALSE") );
        } else {
            NSLog(@"The '%@' preference could not be changed to %@ (which was encoded in the log filename) because it is a forced preference", key, (value ? @"TRUE" : @"FALSE") );
            return FALSE;
        }
    }
    
    return TRUE;
}

-(BOOL) hasLaunchDaemon
{
    NSString * daemonPath = [NSString stringWithFormat: @"/Library/LaunchDaemons/net.tunnelblick.startup.%@.plist", encodeSlashesAndPeriods([self displayName])];
    return [gFileMgr fileExistsAtPath: daemonPath];
}

-(void) stopTryingToHookup
{
    if (   tryingToHookup
        && initialHookupTry  ) {
        tryingToHookup = FALSE;

        if ( ! isHookedup  ) {
            [self setPort: 0];
            requestedState = @"EXITING";
            
            NSLog(@"Stopped trying to establish communications with an existing OpenVPN process for '%@' after %d seconds", [self displayName], gHookupTimeout);
            NSString * msg = [NSString stringWithFormat:
                              NSLocalizedString(@"SurfSafeVPN was unable to establish communications with an existing OpenVPN process for '%@' within %d seconds. The attempt to establish communications has been abandoned.", @"Window text"),
                              [self displayName],
                              gHookupTimeout];
            NSString * prefKey = [NSString stringWithFormat: @"%@-skipWarningUnableToToEstablishOpenVPNLink", [self displayName]];
            
            TBRunAlertPanelExtended(NSLocalizedString(@"Unable to Establish Communication", @"Window text"),
                                    msg,
                                    nil, nil, nil,
                                    prefKey,
                                    NSLocalizedString(@"Do not warn about this again", @"Checkbox name"),
                                    nil);
        }
    }
}

-(void) didHookup
{
    [[[NSApp delegate] logScreen] hookedUpOrStartedConnection: self];
    [self addToLog: @"*SurfSafeVPN: Established communication with OpenVPN"];
    [[[NSApp delegate] logScreen] validateWhenConnectingForConnection: self];
}

-(BOOL) shouldDisconnectWhenBecomeInactiveUser
{
    NSString * autoConnectkey      = [[self displayName] stringByAppendingString: @"autoConnect"];
    NSString * systemStartkey      = [[self displayName] stringByAppendingString: @"-onSystemStart"];
    NSString * doNotDisconnectKey  = [[self displayName] stringByAppendingString: @"-doNotDisconnectOnFastUserSwitch"];
    BOOL connectWhenComputerStarts = [gTbDefaults boolForKey: autoConnectkey] && [gTbDefaults boolForKey: systemStartkey];
    BOOL prefToNotDisconnect       = [gTbDefaults boolForKey: doNotDisconnectKey];
    
    return ! ( connectWhenComputerStarts || prefToNotDisconnect );
}

// May be called from cleanup, so only do one at a time
static pthread_mutex_t deleteLogsMutex = PTHREAD_MUTEX_INITIALIZER;

// Deletes log files if not "on system start"
-(void) deleteLogs
{
    if (  logFilesMayExist  ) {
        NSString * autoConnectKey   = [displayName stringByAppendingString: @"autoConnect"];
        NSString * onSystemStartKey = [displayName stringByAppendingString: @"-onSystemStart"];
        if (   ( ! [gTbDefaults boolForKey: autoConnectKey] )
            || ( ! [gTbDefaults boolForKey: onSystemStartKey] )  ) {
            int cfgLocCode;
            if (  [configPath hasPrefix: gPrivatePath]  ) {
                cfgLocCode = CFG_LOC_PRIVATE;
            } else if (  [configPath hasPrefix: gSharedPath]  ) {
                cfgLocCode = CFG_LOC_SHARED;
            } else if (  [configPath hasPrefix: gDeployPath]  ) {
                cfgLocCode = CFG_LOC_DEPLOY;
            } else {
                NSLog(@"Configuration is in unknown location; path is %@", configPath);
                return;
            }
            
            OSStatus status = pthread_mutex_lock( &deleteLogsMutex );
            if (  status != EXIT_SUCCESS  ) {
                NSLog(@"pthread_mutex_lock( &deleteLogsMutex ) failed; status = %ld, errno = %ld", (long) status, (long) errno);
                return;
            }
            
            NSString *openvpnstartPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent: @"openvpnstart"];
            NSTask* task = [[[NSTask alloc] init] autorelease];
            [task setLaunchPath: openvpnstartPath];
            [task setArguments: [NSArray arrayWithObjects: @"deleteLogs", lastPartOfPath(configPath), [NSString stringWithFormat:@"%d", cfgLocCode], nil]];
            [task launch];
            [task waitUntilExit];
            if (  [task terminationStatus] != EXIT_SUCCESS  ) {
                NSLog(@"Error deleting log files for %@", displayName);
            }
            
            status = pthread_mutex_unlock( &deleteLogsMutex );
            if (  status != EXIT_SUCCESS  ) {
                NSLog(@"pthread_mutex_unlock( &deleteLogsMutex ) failed; status = %ld, errno = %ld", (long) status, (long) errno);
                return;
            }            
        }
    }
}


// Returns TRUE if this configuration will be connected when the system starts via a launchd .plist
-(BOOL) launchdPlistWillConnectOnSystemStart
{
    // Encode slashes and periods in the displayName so the result can act as a single component in a file name
    NSMutableString * daemonNameWithoutSlashes = encodeSlashesAndPeriods([self displayName]);
    
    NSString * daemonLabel = [NSString stringWithFormat: @"net.tunnelblick.startup.%@", daemonNameWithoutSlashes];
    
    NSString * plistPath = [NSString stringWithFormat: @"/Library/LaunchDaemons/%@.plist", daemonLabel];
    
    return [gFileMgr fileExistsAtPath: plistPath];
}
    
// User wants to connect, or not connect, the configuration when the system starts.
// Returns TRUE if can and will connect, FALSE otherwise
//
// Needs and asks for administrator username/password to make a change if a change is necessary and authRef is nil.
// (authRef is non-nil only when SurfSafeVPN is in the process of launching, and only when it was used for something else.)
//
// A change is necesary if changing connect/not connect status, or if preference changes would change
// the .plist file used to connect when the system starts

-(BOOL) checkConnectOnSystemStart: (BOOL)              startIt
                         withAuth: (AuthorizationRef)  inAuthRef;
{
    // Encode slashes and periods in the displayName so the result can act as a single component in a file name
    NSMutableString * daemonNameWithoutSlashes = encodeSlashesAndPeriods([self displayName]);
    
    NSString * daemonLabel = [NSString stringWithFormat: @"net.tunnelblick.startup.%@", daemonNameWithoutSlashes];
    
    NSString * plistPath = [NSString stringWithFormat: @"/Library/LaunchDaemons/%@.plist", daemonLabel];

    NSDictionary * dict;
    NSMutableArray * openvpnstartArgs;
    
    if (  ! startIt  ) {
        if (  ! [gFileMgr fileExistsAtPath: plistPath]  ) {
            return NO; // Don't want to connect at system startup and no .plist in /Library/LaunchDaemons, so return that we ARE NOT connecting at system start
        }
        if (  ! [self makeDictionary: &dict withLabel: daemonLabel openvpnstartArgs: &openvpnstartArgs]  ) {
            // Don't want to connect at system startup, but .plist exists in /Library/LaunchDaemons
            // User cancelled when asked about openvpn-down-root.so, so return that we ARE connecting at system start
            return YES;
        }
    } else {
        if (  ! (   [configPath hasPrefix: gDeployPath]
                 || [configPath hasPrefix: gSharedPath]   )  ) {
            NSLog(@"SurfSafeVPN will NOT connect '%@' when the computer starts because it is a private configuration", [self displayName]);
            return NO;
        }
        
        if (  ! [self makeDictionary: &dict withLabel: daemonLabel openvpnstartArgs: &openvpnstartArgs]  ) {
            if (  [gFileMgr fileExistsAtPath: plistPath]  ) {
                // Want to connect at system start and a .plist exists, but user cancelled, so fall through to remove the .plist
                startIt = FALSE;
                // (Fall through to remove .plist)
            } else {
                // Want to connect at system start but no .plist exists and user cancelled, so return that we ARE NOT connecting at system start
                return NO;
            }

        } else if (  [gFileMgr fileExistsAtPath: plistPath]  ) {
            // Want to connect at system start and a .plist exists. If it is the same as the .plist we need, we're done
            if (  [dict isEqualToDictionary: [NSDictionary dictionaryWithContentsOfFile: plistPath]]  ) {
                return YES; // .plist contents are the same, so we needn't do anything, but indicate it will start at system start
            }
        }
    }
    
	NSBundle *thisBundle = [NSBundle mainBundle];
	NSString *launchPath = [thisBundle pathForResource:@"atsystemstart" ofType:nil];
    
    // Convert openvpnstart arguments to atsystemstart arguments by replacing the launch path with the atsystemstart parameter
    NSMutableArray * arguments = [[openvpnstartArgs mutableCopy] autorelease];
    [arguments replaceObjectAtIndex: 0 withObject: ( startIt ? @"1" : @"0" )];
    
    BOOL freeAuthRef = NO;
    if (  inAuthRef == nil  ) {
        // Get an AuthorizationRef
        NSString * msg;
        if (  startIt  ) {
            msg = [NSString stringWithFormat:
                   NSLocalizedString(@" SurfSafeVPN needs computer administrator access so it can automatically connect '%@' when the computer starts.", @"Window text"),
                   [self displayName]];
        } else {
            msg = [NSString stringWithFormat:
                   NSLocalizedString(@" SurfSafeVPN needs computer administrator access so it can stop automatically connecting '%@' when the computer starts.", @"Window text"),
                   [self displayName]];
        }
        
        inAuthRef= [NSApplication getAuthorizationRef: msg];
        freeAuthRef = (inAuthRef != nil);
    }
    
    if (  inAuthRef == nil  ) {
        if (  startIt  ) {
            NSLog(@"Connect '%@' when computer starts cancelled by user", [self displayName]);
            return NO;
        } else {
            NSLog(@"NOT connect '%@' when computer starts cancelled by user", [self displayName]);
            return YES;
        }
    }
    
    BOOL okNow = FALSE; // Assume failure
    int i;
    for (i=0; i<5; i++) {
        if (  i != 0  ) {
            usleep( i * 500000 );
            NSLog(@"Retrying execution of atsystemstart");
        }
        
        if (  [NSApplication waitForExecuteAuthorized: launchPath withArguments: arguments withAuthorizationRef: inAuthRef]  ) {
            // Try for up to 6.35 seconds to verify that installer succeeded -- sleeping .05 seconds first, then .1, .2, .4, .8, 1.6,
            // and 3.2 seconds (totals 6.35 seconds) between tries as a cheap and easy throttling mechanism for a heavily loaded computer
            useconds_t sleepTime;
            for (sleepTime=50000; sleepTime < 7000000; sleepTime=sleepTime*2) {
                usleep(sleepTime);
                
                if (  startIt) {
                    if (  [dict isEqualToDictionary: [NSDictionary dictionaryWithContentsOfFile: plistPath]]  ) {
                        okNow = TRUE;
                        break;
                    }
                } else {
                    if (  ! [gFileMgr fileExistsAtPath: plistPath]  ) {
                        okNow = TRUE;
                        break;
                    }
                }
            }
            
            if (  okNow  ) {
                break;
            } else {
                NSLog(@"Timed out waiting for atsystemstart execution to finish");
            }
        } else {
            NSLog(@"Failed to execute %@: %@", launchPath, arguments);
        }
    }
    
    if (  freeAuthRef  ) {
        AuthorizationFree(inAuthRef, kAuthorizationFlagDefaults);
    }
    
    if (  startIt) {
        if (   okNow
            || [dict isEqualToDictionary: [NSDictionary dictionaryWithContentsOfFile: plistPath]]  ) {
            NSLog(@"%@ will be connected using '%@' when the computer starts"    ,
                  [self displayName],
                  [[NSBundle mainBundle] pathForResource: @"openvpnstart" ofType: nil]);
            return YES;
        } else {
            NSLog(@"Failed to set up to connect '%@' when computer starts", [self displayName]);
            return NO;
        }
    } else {
        if (   okNow
            || ( ! [gFileMgr fileExistsAtPath: plistPath] )  ) {
            NSLog(@"%@ will NOT be connected when the computer starts", [self displayName]);
            return NO;
        } else {
            NSLog(@"Failed to set up to NOT connect '%@' when computer starts", [self displayName]);
            return YES;
        }
    }
}

// Returns YES on success, NO if user cancelled out of a dialog 
-(BOOL) makeDictionary: (NSDictionary * *)  dict withLabel: (NSString *) daemonLabel openvpnstartArgs: (NSMutableArray * *) openvpnstartArgs
{
    // Don't use the "Program" key, because we want the first argument to be the path to the program,
    // so openvpnstart can know where it is, so it can find other SurfSafeVPN compenents.
    NSString * openvpnstartPath = [[NSBundle mainBundle] pathForResource: @"openvpnstart" ofType: nil];
    *openvpnstartArgs = [[[self argumentsForOpenvpnstartForNow: NO] mutableCopy] autorelease];
    if (  ! (*openvpnstartArgs)  ) {
        return NO;
    }
    
    [*openvpnstartArgs insertObject: openvpnstartPath atIndex: 0];
    
    NSString * daemonDescription = [NSString stringWithFormat: @"Processes SurfSafeVPN 'Connect when system starts' for VPN configuration '%@'",
                                    [self displayName]];
    
    NSString * workingDirectory;
    if (  [[configPath pathExtension] isEqualToString: @"tblk"]  ) {
        workingDirectory = [configPath stringByAppendingPathComponent: @"Contents/Resources"];
    } else {
        workingDirectory = firstPartOfPath(configPath);
    }
    
    *dict = [NSDictionary dictionaryWithObjectsAndKeys:
             daemonLabel,                    @"Label",
             *openvpnstartArgs,              @"ProgramArguments",
             workingDirectory,               @"WorkingDirectory",
             daemonDescription,              @"ServiceDescription",
             [NSNumber numberWithBool: YES], @"onDemand",
             [NSNumber numberWithBool: YES], @"RunAtLoad",
             nil];
    
    return YES;
}

-(NSString *) description
{
	return [NSString stringWithFormat:@"VPN Connection %@", displayName];
}

-(void)setPort:(unsigned int)inPort 
{
	portNumber = inPort;
}

-(unsigned int)port 
{
    return portNumber;
}

-(NSString *) configPath
{
    return [[configPath retain] autorelease];
}

// Also used as the prefix for preference and Keychain keys
-(NSString *) displayName
{
    return [[displayName retain] autorelease];
}

-(NSString *) requestedState
{
    return requestedState;
}

- (void) setManagementSocket: (NetSocket*) socket
{
    [socket retain];
    [managementSocket autorelease];
    managementSocket = socket;
    [managementSocket setDelegate: self];    
}

- (void) dealloc
{
    [self disconnectAndWait: [NSNumber numberWithBool: NO] userKnows: NO];
    [logDisplay release];
    [managementSocket close];
    [managementSocket setDelegate: nil];
    [managementSocket release]; 
    [lastState release];
    [tunOrTap release];
    [configPath release];
    [displayName release];
    [connectedSinceDate release];
    [statistics.lastSet release];
    [bytecountsUpdated release];
    [myAuthAgent release];
    [statusScreen release];
    [tunnelUpSound release];
    [tunnelDownSound release];
    [proxy release];
    
    [super dealloc];
}

-(void) invalidateConfigurationParse
{
    [tunOrTap release];
    tunOrTap = nil;
}

-(void) showStatusWindow
{
    if (  ! (   gTunnelblickIsQuitting
             || gComputerIsGoingToSleep )  ) {
        if (  ! showingStatusWindow  ) {
            NSString * statusPref = [gTbDefaults objectForKey: @"connectionWindowDisplayCriteria"];
            if (  ! [statusPref isEqualToString: @"neverShow"]  ) {
                if (  ! statusScreen) {
                    statusScreen = [[StatusWindowController alloc] initWithDelegate: self];
                } else {
                    [statusScreen restore];
                }
                
                [statusScreen setStatus: lastState forName: displayName connectedSince: [self timeString]];
                [statusScreen fadeIn];
                showingStatusWindow = TRUE;
            }
        }
    }
}

- (void) connect: (id) sender userKnows: (BOOL) userKnows
{
    NSString * oldRequestedState = requestedState;
    if (  userKnows  ) {
        requestedState = @"CONNECTED";
    }
    
    if (  ! [gTbDefaults boolForKey:@"skipWarningAboutSimultaneousConnections"]  ) {
        // Count the total number of connections and what their "Set nameserver" status was at the time of connection
        int numConnections = 1;
        int numConnectionsWithModifyNameserver = 0;
        if (  [self useDNSStatus] != 0  ) {
            numConnectionsWithModifyNameserver = 1;
        }
        VPNConnection * connection;
        NSEnumerator* e = [[[NSApp delegate] myVPNConnectionDictionary] objectEnumerator];
        while (connection = [e nextObject]) {
            if (  ! [[connection state] isEqualToString:@"EXITING"]  ) {
                numConnections++;
                if (  [connection usedModifyNameserver]  ) {
                    numConnectionsWithModifyNameserver++;
                }
            }
        }
        
        if (  numConnections != 1  ) {
            int button = TBRunAlertPanelExtended(NSLocalizedString(@"Do you wish to connect?", @"Window title"),
                                                 [NSString stringWithFormat:NSLocalizedString(@"Multiple simultaneous connections would be created (%d with 'Set nameserver', %d without 'Set nameserver').", @"Window text"), numConnectionsWithModifyNameserver, (numConnections-numConnectionsWithModifyNameserver) ],
                                                 NSLocalizedString(@"Connect", @"Button"),  // Default button
                                                 NSLocalizedString(@"Cancel", @"Button"),   // Alternate button
                                                 nil,
                                                 @"skipWarningAboutSimultaneousConnections",
                                                 NSLocalizedString(@"Do not warn about this again", @"Checkbox name"),
                                                 nil);
            if (  button == NSAlertAlternateReturn  ) {
                if (  userKnows  ) {
                    requestedState = oldRequestedState;
                }
                return;
            }
        }
    }
    
    logFilesMayExist = TRUE;
    authFailed = FALSE;
    credentialsAskedFor = FALSE;
    userWantsState = userWantsUndecided;
    
    areDisconnecting = FALSE;
    initialHookupTry = FALSE;
    tryingToHookup = TRUE;
    isHookedup = FALSE;
    
    [self disconnectFromManagmentSocket];

    [self clearLog];
    
	NSArray * arguments = [self argumentsForOpenvpnstartForNow: YES];
    if (  arguments == nil  ) {
        if (  userKnows  ) {
            requestedState = oldRequestedState; // User cancelled
        }
        return;
    }
		
    // Process runOnConnect item
    NSString * path = [[NSApp delegate] customRunOnConnectPath];
    if (  path  ) {
        NSTask* task = [[[NSTask alloc] init] autorelease];
        [task setLaunchPath: path];
        [task setArguments: arguments];
        [task setCurrentDirectoryPath: [path stringByDeletingLastPathComponent]];
        [task launch];
        if (  [[[path stringByDeletingPathExtension] pathExtension] isEqualToString: @"wait"]) {
            [task waitUntilExit];
            int status = [task terminationStatus];
            if (  status != 0  ) {
                NSLog(@"SurfSafeVPN runOnConnect item %@ returned %d; '%@' connect cancelled", path, status, displayName);
                if (  userKnows  ) {
                    TBRunAlertPanel(NSLocalizedString(@"Warning!", @"Window title"),
                                    [NSString
                                     stringWithFormat: NSLocalizedString(@"The attempt to connect %@ has been cancelled: the runOnConnect script returned status: %d.", @"Window text"),
                                     [self displayName],
                                     status],
                                    nil, nil, nil);
                    requestedState = oldRequestedState;
                }
                return;
            }
        }
    }
    
    [gTbDefaults setBool: NO forKey: [displayName stringByAppendingString: @"-lastConnectionSucceeded"]];
    
	NSTask* task = [[[NSTask alloc] init] autorelease];
    
	path = [[NSBundle mainBundle] pathForResource: @"openvpnstart" ofType: nil];
	[task setLaunchPath: path]; 
		
    NSPipe * errPipe = [[NSPipe alloc] init];
    [task setStandardError: errPipe];
    NSPipe * stdPipe = [[NSPipe alloc] init];
    [task setStandardOutput: stdPipe];
    
    [self addToLog: [[NSApp delegate] openVPNLogHeader]];

    NSString * logText = [NSString stringWithFormat:@"*SurfSafeVPN: Attempting connection with %@%@; Set nameserver = %@%@",
                          [self displayName],
                          (  [[arguments objectAtIndex: 5] isEqualToString:@"1"]
                           ? @" using shadow copy"
                           : (  [[arguments objectAtIndex: 5] isEqualToString:@"2"]
                              ? @" from Deploy"
                              : @""  )  ),
                          [arguments objectAtIndex: 3],
                          (  [[arguments objectAtIndex: 6] isEqualToString:@"1"]
                           ? @"; not monitoring connection"
                           : @"; monitoring connection" )
                          ];
    [self addToLog: logText];

    NSMutableArray * escapedArguments = [NSMutableArray arrayWithCapacity:[arguments count]];
    int i;
    for (i=0; i<[arguments count]; i++) {
        [escapedArguments addObject: [[[arguments objectAtIndex: i] componentsSeparatedByString: @" "] componentsJoinedByString: @"\\ "]];
    }
    
    [self addToLog: [NSString stringWithFormat: @"*SurfSafeVPN: %@ %@",
                     [[path componentsSeparatedByString: @" "] componentsJoinedByString: @"\\ "],
                     [escapedArguments componentsJoinedByString: @" "]]];
    
    unsigned bitMask = [[arguments objectAtIndex: 7] intValue];
    if (  (loadedOurTap = (bitMask & OPENVPNSTART_OUR_TAP_KEXT) == OPENVPNSTART_OUR_TAP_KEXT)  ) {
        [[NSApp delegate] incrementTapCount];
    }
    
    if (  (loadedOurTun = (bitMask & OPENVPNSTART_OUR_TUN_KEXT) == OPENVPNSTART_OUR_TUN_KEXT) ) {
        [[NSApp delegate] incrementTunCount];
    }
    
	[task setArguments:arguments];
	[task setCurrentDirectoryPath: firstPartOfPath(configPath)];
	[task launch];
    [self setConnectedSinceDate: [NSDate date]];
    [self clearStatisticsIncludeTotals: NO];
	[task waitUntilExit];
    
    // Standard output has command line that openvpnstart used to start OpenVPN; copy it to the log
    NSFileHandle * file = [stdPipe fileHandleForReading];
    NSData * data = [file readDataToEndOfFile];
    [file closeFile];
    [stdPipe release];
    NSString * openvpnstartOutput = [[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] autorelease];
    openvpnstartOutput = [openvpnstartOutput stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (  [openvpnstartOutput length] != 0  ) {
        [self addToLog: [NSString stringWithFormat:@"*SurfSafeVPN: openvpnstart output:\n\n%@\n", openvpnstartOutput]];
    }

    int status = [task terminationStatus];
    if (  status != 0  ) {
        if (  status == 240  ) {
            openvpnstartOutput = @"Internal SurfSafeVPN error: openvpnstart syntax error";
        } else {
            file = [errPipe fileHandleForReading];
            data = [file readDataToEndOfFile];
            [file closeFile];
            openvpnstartOutput = [[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] autorelease];
            openvpnstartOutput = [openvpnstartOutput stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            openvpnstartOutput = [@"\n" stringByAppendingString: openvpnstartOutput];
            NSMutableString * tempMutableString = [[openvpnstartOutput mutableCopy] autorelease];
            [tempMutableString replaceOccurrencesOfString: @"\n" withString: @"\n     " options: 0 range: NSMakeRange(0, [tempMutableString length])];
            openvpnstartOutput = [NSString stringWithString: tempMutableString];
        }
        
        [self addToLog: [NSString stringWithFormat: @"*SurfSafeVPN:\n\n"
                         "Could not start OpenVPN (openvpnstart returned with status #%d)\n\n"
                         "Contents of the openvpnstart log:\n"
                         "%@",
                         status, openvpnstartOutput]];
        [errPipe release];
        if (  userKnows  ) {
            TBRunAlertPanel(NSLocalizedString(@"Warning!", @"Window title"),
                            [NSString stringWithFormat:
                             NSLocalizedString(@"SurfSafeVPN was unable to start OpenVPN to connect %@. For details, see the OpenVPN log in the VPN Details... window", @"Window text"),
                             [self displayName]],
                            nil, nil, nil);
            requestedState = oldRequestedState;
        }
    } else {
        file = [errPipe fileHandleForReading];
        data = [file readDataToEndOfFile];
        [file closeFile];
        openvpnstartOutput = [[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] autorelease];
        if (  openvpnstartOutput  ) {
            openvpnstartOutput = [openvpnstartOutput stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (  [openvpnstartOutput length] != 0  ) {
                [self addToLog: [NSString stringWithFormat: @"*SurfSafeVPN: openvpnstart message: %@", openvpnstartOutput]];
            }
        }
//        [[[NSApp delegate] logScreen] hookedUpOrStartedConnection: self];
        [errPipe release];
        [self setState: @"SLEEP"];
        [self showStatusWindow];
        [self connectToManagementSocket];
    }
}

-(NSArray *) argumentsForOpenvpnstartForNow: (BOOL) forNow
{
    NSString *cfgPath = [self configPath];
    NSString *altPath = [NSString stringWithFormat:@"/Library/Application Support/SurfSafeVPN/Users/%@/%@",
                         NSUserName(), lastPartOfPath(configPath)];
    
    if ( ! (cfgPath = [[ConfigurationManager defaultManager] getConfigurationToUse: cfgPath orAlt: altPath]) ) {
        return nil;
    }
    
    BOOL useShadowCopy = [cfgPath isEqualToString: altPath];
    BOOL useDeploy     = [cfgPath hasPrefix: gDeployPath];
    BOOL useShared     = [cfgPath hasPrefix: gSharedPath];
    
    NSString *portString;
    if (  forNow  ) {
        [self setPort:[self getFreePort]];
        portString = [NSString stringWithFormat:@"%d", portNumber];
    } else {
        portString = @"0";
    }
    
    // Parse configuration file to catch "user" or "group" options and get tun/tap key
    if (  ! tunOrTap  ) {
        tunOrTap = [[[ConfigurationManager defaultManager] parseConfigurationPath: configPath forConnection: self] copy];
        // tunOrTap == 'Cancel' means we cancel whatever we're doing
        if (  [tunOrTap isEqualToString: @"Cancel"]  ) {
            [tunOrTap release];
            tunOrTap = nil;
            return nil;
        }
    }
    
    NSString *useDNSArg = @"0";
    unsigned useDNSStat = (unsigned) [self useDNSStatus];
	if(  useDNSStat == 0) {
        if (  forNow  ) {
            usedModifyNameserver = FALSE;
        }
	} else {
        NSString * useDownRootPluginKey = [[self displayName] stringByAppendingString: @"-useDownRootPlugin"];
        BOOL useDownRoot = [gTbDefaults boolForKey: useDownRootPluginKey];
        unsigned useDNSNum = (  (useDNSStat-1) << 2) + (useDownRoot ? 2 : 0) + 1;   // (script #) + downroot-flag + set-nameserver-flag
        useDNSArg = [NSString stringWithFormat: @"%u", useDNSNum];
        if (  forNow  ) {
            usedModifyNameserver = TRUE;
        }
    }
    
    // for OpenVPN v. 2.1_rc9 or higher, clear skipScrSec so we use "--script-security 2"
    NSString *skipScrSec = @"1";
    NSDictionary * openVPNVersionDict = getOpenVPNVersion();
    if (  openVPNVersionDict  ) {
        int intMajor =  [[openVPNVersionDict objectForKey:@"major"]  intValue];
        int intMinor =  [[openVPNVersionDict objectForKey:@"minor"]  intValue];
        int intSuffix = [[openVPNVersionDict objectForKey:@"suffix"] intValue];
        
        if ( intMajor == 2 ) {
            if ( intMinor == 1 ) {
                if (  [[openVPNVersionDict objectForKey:@"preSuffix"] isEqualToString:@"_rc"] ) {
                    if ( intSuffix > 8 ) {
                        skipScrSec = @"0";
                    }
                } else {
                    skipScrSec = @"0";
                }
            } else if ( intMinor > 1 ) {
                skipScrSec = @"0";
            }
        } else if ( intMajor > 2 ) {
            skipScrSec = @"0";
        }
    } else {
        skipScrSec = @"0";
    }
    
    NSString *altCfgLoc = @"0";
    if ( useShadowCopy ) {
        altCfgLoc = @"1";
    } else if (  useDeploy  ) {
        altCfgLoc = @"2";
    } else if (  useShared  ) {
        altCfgLoc = @"3";
    }
    
    NSString * noMonitorKey = [[self displayName] stringByAppendingString: @"-notMonitoringConnection"];
    NSString * noMonitor = @"0";
    if (  [useDNSArg isEqualToString: @"0"] || [gTbDefaults boolForKey: noMonitorKey]  ) {
        noMonitor = @"1";
    }

    unsigned int bitMask = 0;
    if (  [tunOrTap isEqualToString: @"tap"]  ) {
        bitMask = OPENVPNSTART_USE_TAP;
    }

    NSString * noTapKextKey = [[self displayName] stringByAppendingString: @"-doNotLoadTapKext"];
    NSString * yesTapKextKey = [[self displayName] stringByAppendingString: @"-loadTapKext"];
    if (  ! [gTbDefaults boolForKey: noTapKextKey]  ) {
        if (   ( ! tunOrTap )
            || [tunOrTap isEqualToString: @"tap"]
            || [gTbDefaults boolForKey: yesTapKextKey]  ) {
            bitMask = bitMask | OPENVPNSTART_OUR_TAP_KEXT;
        }
    }
    
    NSString * noTunKextKey = [[self displayName] stringByAppendingString: @"-doNotLoadTunKext"];
    NSString * yesTunKextKey = [[self displayName] stringByAppendingString: @"-loadTunKext"];
    if (  ! [gTbDefaults boolForKey: noTunKextKey]  ) {
        if (   ( ! tunOrTap )
            || [tunOrTap isEqualToString: @"tun"]
            || [gTbDefaults boolForKey: yesTunKextKey]  ) {
            bitMask = bitMask | OPENVPNSTART_OUR_TUN_KEXT;
        }
    }
    
    [self setBit: OPENVPNSTART_RESTORE_ON_WINS_RESET  inMask: &bitMask ifConnectionPreference: @"-doNotRestoreOnWinsReset"   inverted: YES];
    [self setBit: OPENVPNSTART_RESTORE_ON_DNS_RESET   inMask: &bitMask ifConnectionPreference: @"-doNotRestoreOnDnsReset"    inverted: YES];
    
    NSString * bitMaskString = [NSString stringWithFormat: @"%d", bitMask];
    
    NSString * leasewatchOptionsKey = [displayName stringByAppendingString: @"-leasewatchOptions"];
    NSString * leasewatchOptions = [gTbDefaults objectForKey: leasewatchOptionsKey];
    if (  leasewatchOptions  ) {
        if (  [leasewatchOptions hasPrefix: @"-i"]  ) {
            NSCharacterSet * optionCharacterSet = [NSCharacterSet characterSetWithCharactersInString: @"dasngw"];
            NSRange r = [[leasewatchOptions substringFromIndex: 2] rangeOfCharacterFromSet: [optionCharacterSet invertedSet]];
            if (  r.length != 0  ) {
                NSLog(@"Invalid '%@' preference (must start with '-i', then have only 'd', 'a', 's', 'n', 'g', 'w'). Ignoring the preference.", leasewatchOptionsKey);
                leasewatchOptions = @"";
            }
        } else {
            NSLog(@"Invalid '%@' preference (must start with '-i'). Ignoring the preference.", leasewatchOptionsKey);
            leasewatchOptions = @"";
        }
    } else {
        leasewatchOptions = [self leasewatchOptionsFromPreferences];
    }
    
    NSString * ourVersionFolder;
    id obj = [gTbDefaults objectForKey: @"openvpnVersion"];
    if (  [[obj class] isSubclassOfClass: [NSString class]]  ) {
        ourVersionFolder = (NSString *) obj;
    } else {
        ourVersionFolder = @"";
    }

    NSArray * args = [NSArray arrayWithObjects:
                      @"start", [[lastPartOfPath(cfgPath) copy] autorelease], portString, useDNSArg, skipScrSec, altCfgLoc, noMonitor, bitMaskString, leasewatchOptions, ourVersionFolder, nil];

    // IF THE NUMBER OF ARGUMENTS CHANGES:
    //    (1) Modify openvpnstart to use the new arguments
    //    (2) Change OPENVPNSTART_MAX_ARGC in defines.h to the maximum 'argc' for openvpnstart
    //        (That is, change it to one more than the number of entries in 'args' (because the path to openvpnstart is also an argument)
    //    (3) Change the constant integer in the next line to the the same number
#if 11 != OPENVPNSTART_MAX_ARGC
    #error "OPENVPNSTART_MAX_ARGC is not correct. It must be 1 more than the count of the 'args' array"
#endif
    
    if (  [args count] + 1  != OPENVPNSTART_MAX_ARGC  ) {
        NSLog(@"Program error: [args count] = %ld, but OPENVPNSTART_MAX_ARGC = %d. It should be one more than [args count].", (long) [args count], OPENVPNSTART_MAX_ARGC);
    }

    return args;
}

-(void) setBit: (unsigned int) bit inMask: (unsigned int *) bitMaskPtr ifConnectionPreference: (NSString *) keySuffix inverted: (BOOL) invert
{
    NSString * prefKey = [[self displayName] stringByAppendingString: keySuffix];
    if (  [gTbDefaults boolForKey: prefKey]  ) {
        if (  ! invert  ) {
            *bitMaskPtr = *bitMaskPtr | bit;
        }
    } else {
        if (  invert  ) {
            *bitMaskPtr = *bitMaskPtr | bit;
        }
    }
}

-(NSString * ) leasewatchOptionsFromPreferences
{
    NSArray * chars = [NSArray arrayWithObjects: @"d", @"a", @"s", @"n", @"g", @"w", @"D", @"A", @"S", @"N", @"G", @"W", nil];
    NSArray * preferenceKeys = [NSArray arrayWithObjects:
                                @"-changeDomainAction",
                                @"-changeDNSServersAction",
                                @"-changeSearchDomainAction",
                                @"-changeNetBIOSNameAction",
                                @"-changeWINSServersAction",
                                @"-changeWorkgroupAction",
                                @"-changeOtherDomainAction",
                                @"-changeOtherDNSServersAction",
                                @"-changeOtherSearchDomainAction",
                                @"-changeOtherNetBIOSNameAction",
                                @"-changeOtherWINSServersAction",
                                @"-changeOtherWorkgroupAction",
                                nil];
    
    // Get the preference values. Use -1 for any preference that isn't present
    NSMutableArray * preferenceValues = [NSMutableArray arrayWithCapacity: 12];
    int i;
    for (  i=0; i<[preferenceKeys count]; i++  ) {
        NSString * key = [[self displayName] stringByAppendingString: [preferenceKeys objectAtIndex: i]];
        NSString * value = [gTbDefaults objectForKey: key];
        int intValue;
        if (  value  ) {
            if (  [value respondsToSelector: @selector(intValue)]  ) {
                intValue = [value intValue];
            } else {
                NSLog(@"Preference '%@' is not a number; it will be ignored", key);
                intValue = -1;
            }
        } else {
            intValue = -1;
        }
        
        // If no prefererence, changes to pre-VPN will be undone and other changes will cause a restart
        if (  intValue == -1  ) {
            if (  i < 6  ) {
                intValue = 1;
            } else {
                intValue = 2;
            }

        }

        [preferenceValues addObject: [NSNumber numberWithInt: intValue]];
    }
        
    // Go though preferences and pull out those that force RESTARTS
    NSMutableString * restartOptions = [NSMutableString stringWithCapacity: [preferenceKeys count] + 2];
    for (  i=0; i<[preferenceKeys count]; i++  ) {
        if (  [[preferenceValues objectAtIndex: i] intValue] == 2  ) {
            [restartOptions appendString: [chars objectAtIndex: i]];
        }
    }
    
    // Go though preferences and pull out those that force RESTORES
    NSMutableString * restoreOptions = [NSMutableString stringWithCapacity: [preferenceKeys count] + 2];
    for (  i=0; i<[preferenceKeys count]; i++  ) {
        if (  [[preferenceValues objectAtIndex: i] intValue] == 1  ) {
            [restoreOptions appendString: [chars objectAtIndex: i]];
        }
    }
    
    // Constuct the options string we return
    NSMutableString * options = [[@"-a" mutableCopy] autorelease];
    if (  [restartOptions length] != 0  ) {
        [options appendString: [NSString stringWithFormat: @"t%@", restartOptions]];
    }
    if (  [restoreOptions length] != 0  ) {
        [options appendString: [NSString stringWithFormat: @"r%@", restoreOptions]];
    }

    return options;
}

- (NSDate *)connectedSinceDate {
    return [[connectedSinceDate retain] autorelease];
}

-(NSString *) connectTimeString
{
    // Get connection duration if preferences say to 
    if (   [gTbDefaults boolForKey:@"showConnectedDurations"]
        && [[self state] isEqualToString: @"CONNECTED"]    ) {
        NSString * cTimeS = @"";
        NSDate * csd = [self connectedSinceDate];
        NSTimeInterval ti = [csd timeIntervalSinceNow];
        long cTimeL = (long) round(-ti);
        if ( cTimeL >= 0 ) {
            if ( cTimeL < 3600 ) {
                cTimeS = [NSString stringWithFormat:@" (%li:%02li)", cTimeL/60, cTimeL%60];
            } else {
                cTimeS = [NSString stringWithFormat:@" (%li:%02li:%02li)", cTimeL/3600, (cTimeL/60) % 60, cTimeL%60];
            }
        }
        return cTimeS;
    } else {
        return @"";
    }
}

- (void)setConnectedSinceDate:(NSDate *)value {
    if (connectedSinceDate != value) {
        [connectedSinceDate release];
        connectedSinceDate = [value copy];
    }
}

- (BOOL) usedModifyNameserver {
    return usedModifyNameserver;
}

-(void) deleteCredentialsFromKeychain{
    [myAuthAgent setAuthMode: @"privateKey"];
    if (  [myAuthAgent keychainHasCredentials]  ) {
        [myAuthAgent deleteCredentialsFromKeychain];
    }
    [myAuthAgent setAuthMode: @"password"];
    if (  [myAuthAgent keychainHasCredentials]  ) {
        [myAuthAgent deleteCredentialsFromKeychain];
    }
}

-(BOOL) tryingToHookup
{
    return tryingToHookup;
}

-(BOOL) isHookedup
{
    return isHookedup;
}

-(pid_t) pid
{
    return pid;
}

- (IBAction) toggle: (id) sender
{
	if (![self isDisconnected]) {
        [self addToLog: @"*SurfSafeVPN: Disconnecting; 'Disconnect' menu command invoked"];
		[self disconnectAndWait: [NSNumber numberWithBool: YES] userKnows: YES];
	} else {
		[self connect: sender userKnows: YES];
	}
}

- (void) connectToManagementSocket
{
    [self setManagementSocket: [NetSocket netsocketConnectedToHost: @"127.0.0.1" port: portNumber]];   
}

-(void) disconnectFromManagmentSocket
{
    if (  managementSocket  ) {
        [managementSocket close];
        [managementSocket setDelegate: nil];
        [managementSocket release];
        managementSocket = nil;
    }
}
static pthread_mutex_t areDisconnectingMutex = PTHREAD_MUTEX_INITIALIZER;

// Start disconnecting by killing the OpenVPN process or signaling through the management interface
// Waits for up to 5 seconds for the disconnection to occur if "wait" is TRUE
- (void) disconnectAndWait: (NSNumber *) wait userKnows:(BOOL)userKnows
{
    if (  [self isDisconnected]  ) {
        return;
    }
    
    pthread_mutex_lock( &areDisconnectingMutex );
    if (  areDisconnecting  ) {
        pthread_mutex_unlock( &areDisconnectingMutex );
        NSLog(@"disconnect: while disconnecting");
        return;
    }
    
    if (  userKnows  ) {
        requestedState = @"EXITING";
    }

    areDisconnecting = TRUE;
    pthread_mutex_unlock( &areDisconnectingMutex );
    
    BOOL disconnectionComplete = FALSE;

    pid_t thePid = pid; // Avoid pid changing between this if statement and the invokation of waitUntilNoProcessWithID (pid can change outside of main thread)
    if (  thePid > 0  ) {
        [self killProcess];
        if (  [wait boolValue]  ) {
            // Wait up to five seconds for the OpenVPN process to disappear
            disconnectionComplete = [NSApp waitUntilNoProcessWithID: thePid];
        }
    } else {
        if([managementSocket isConnected]) {
            NSLog(@"No process ID; disconnecting via management interface");
            [managementSocket writeString: @"signal SIGTERM\r\n" encoding: NSASCIIStringEncoding];
            
            if (  [wait boolValue]  ) {
                // Wait up to five seconds for the management socket to disappear
                int i;
                for (i=0; i<5; i++) {
                    if (  managementSocket == nil  ) {
                        break;
                    }
                    sleep(1);
                }
            }

            disconnectionComplete = (managementSocket == nil) || ( ! [managementSocket isConnected]);
        }
    }
    
    if (  disconnectionComplete  ) {
        [self performSelectorOnMainThread: @selector(hasDisconnected) withObject: nil waitUntilDone: NO];
    } else {

        if (  [wait boolValue]  ) {
            forceKillInterval = 10;   // Seconds between disconnect attempts
            id terminationSeconds;
            if (  (terminationSeconds = [gTbDefaults objectForKey: @"openvpnTerminationInterval"])  ) {
                if (   [terminationSeconds respondsToSelector: @selector(intValue)]  ) {
                    forceKillInterval = [terminationSeconds intValue];
                }
            }
            forceKillTimeout = 180;   // Seconds before considering it disconnected anyway
            if (  (terminationSeconds = [gTbDefaults objectForKey: @"openvpnTerminationTimeout"])  ) {
                if (   [terminationSeconds respondsToSelector: @selector(intValue)]  ) {
                    forceKillTimeout = [terminationSeconds intValue];
                }
            }
            
            if (  forceKillInterval  != 0) {
                if ( forceKillTimeout != 0  ) {
                    forceKillWaitSoFar = 0;
                    forceKillTimer = [NSTimer scheduledTimerWithTimeInterval: (NSTimeInterval) forceKillInterval
                                                                      target: self
                                                                    selector: @selector(forceKillWatchdogHandler)
                                                                    userInfo: nil
                                                                     repeats: YES];
                    [self performSelectorOnMainThread: @selector(tellUserAboutDisconnectWait) withObject: nil waitUntilDone: NO];
                }
            }
        }
    }
}
// Tries to kill the OpenVPN process associated with this connection, if any
-(void)killProcess 
{
	NSString* path = [[NSBundle mainBundle] pathForResource: @"openvpnstart" 
													 ofType: nil];
	NSTask* task = [[[NSTask alloc] init] autorelease];
	[task setLaunchPath: path]; 
	NSString *pidString = [NSString stringWithFormat:@"%d", pid];
    
	NSArray *arguments = [NSArray arrayWithObjects:@"kill", pidString, nil];
	[task setArguments:arguments];
	[task setCurrentDirectoryPath: firstPartOfPath(configPath)];
	[task launch];
	[task waitUntilExit];
}

-(void) tellUserAboutDisconnectWait
{
    TBRunAlertPanel(NSLocalizedString(@"OpenVPN Not Responding", @"Window title"),
                    [NSString stringWithFormat: NSLocalizedString(@"OpenVPN is not responding to disconnect requests.\n\n"
                                                                  "There is a known bug in OpenVPN version 2.1 that sometimes"
                                                                  " causes a delay of one or two minutes before it responds to such requests.\n\n"
                                                                  "SurfSafeVPN will continue to try to disconnect for up to %d seconds.\n\n"
                                                                  "The connection will be unavailable until OpenVPN disconnects or %d seconds elapse,"
                                                                  " whichever comes first.", @"Window text"), forceKillTimeout, forceKillTimeout],
                    nil, nil, nil);
}    

-(void) forceKillWatchdogHandler
{
    [self performSelectorOnMainThread: @selector(forceKillWatchdog) withObject: nil waitUntilDone: NO];
}

-(void) forceKillWatchdog
{
    if (  ! [self isDisconnected]  ) {
        
        if (  pid > 0  ) {
            [self killProcess];
        } else {
            if([managementSocket isConnected]) {
                [managementSocket writeString: @"signal SIGTERM\r\n" encoding: NSASCIIStringEncoding];
            }
        }

        forceKillWaitSoFar += forceKillInterval;
        if (  forceKillWaitSoFar > forceKillTimeout) {
            TBRunAlertPanel(NSLocalizedString(@"Warning!", @"Window title"),
                            [NSString stringWithFormat: NSLocalizedString(@"OpenVPN has not responded to disconnect requests for %d seconds.\n\n"
                                                                          "The connection will be considered disconnected, but this computer's"
                                                                          " network configuration may be in an inconsistent state.", @"Window text"),
                             forceKillTimeout],
                            nil, nil, nil);
            [forceKillTimer invalidate];
            forceKillTimer = nil;
            [self hasDisconnected];
        }
    } else {
        [forceKillTimer invalidate];
        forceKillTimer = nil;
    }
}

static pthread_mutex_t lastStateMutex = PTHREAD_MUTEX_INITIALIZER;

// The 'pre-connect.sh' and 'post-tun-tap-load.sh' scripts are run by openvpnstart
// The 'connected.sh' and 'reconnecting.sh' scripts are by this class's setState: method
// The 'disconnect.sh' script is run here
//
// Call on main thread only
-(void) hasDisconnected
{
    [self clearStatisticsRatesDisplay];
    
    pthread_mutex_lock( &lastStateMutex );
    if (  [lastState isEqualToString: @"EXITING"]  ) {
        pthread_mutex_unlock( &lastStateMutex );
        return;
    }
    [self setState:@"EXITING"];
    pthread_mutex_unlock( &lastStateMutex );
    
    [self disconnectFromManagmentSocket];
    portNumber = 0;
    pid = 0;
    areDisconnecting = FALSE;
    isHookedup = FALSE;
    tryingToHookup = FALSE;
    
    [[NSApp delegate] removeConnection:self];
    
    // Unload tun/tap if not used by any other processes
    if (  loadedOurTap  ) {
        [[NSApp delegate] decrementTapCount];
        loadedOurTap = FALSE;
    }
    if (  loadedOurTun  ) {
        [[NSApp delegate] decrementTunCount];
        loadedOurTun = FALSE;
    }
    [[NSApp delegate] unloadKexts];
    
    // Run the post-disconnect script, if any
    [self runScriptNamed: @"post-disconnect" openvpnstartCommand: @"postDisconnect"];
    
    [[NSApp delegate] updateNavigationLabels];
    
    [self flushDnsCache];

}
    
-(void) flushDnsCache
{
    NSString * key = [displayName stringByAppendingString:@"-doNotFlushCache"];
    if (  ! [gTbDefaults boolForKey: key]  ) {
        BOOL didNotTry = TRUE;
        NSArray * pathArray = [NSArray arrayWithObjects: @"/usr/bin/dscacheutil", @"/usr/sbin/lookupd", nil];
        NSString * path;
        NSEnumerator * arrEnum = [pathArray objectEnumerator];
        while (  path = [arrEnum nextObject]  ) {
            if (  [gFileMgr fileExistsAtPath: path]  ) {
                didNotTry = FALSE;
                NSArray * arguments = [NSArray arrayWithObject: @"-flushcache"];
                NSTask * task = [[NSTask alloc] init];
                [task setLaunchPath: path];
                [task setArguments: arguments];
                [task launch];
                [task waitUntilExit];
                int status = [task terminationStatus];
                [task release];
                if (  status != 0) {
                    [self addToLog: [NSString stringWithFormat: @"*SurfSafeVPN: Failed to flush the DNS cache; the command was: '%@ -flushcache'", path]];
                } else {
                    [self addToLog: @"*SurfSafeVPN: Flushed the DNS cache"];
                    break;
                }
            }
        }
        
        if (  didNotTry  ) {
            [self addToLog: @"* SurfSafeVPN: DNS cache not flushed; did not find needed executable"];
        }
    }
}

- (void) netsocketConnected: (NetSocket*) socket
{
    
    NSParameterAssert(socket == managementSocket);
    
    if (NSDebugEnabled) NSLog(@"SurfSafeVPN connected to management interface on port %d.", [managementSocket remotePort]);
    
    NS_DURING {
		[managementSocket writeString: @"pid\r\n"           encoding: NSASCIIStringEncoding];
        [managementSocket writeString: @"state on\r\n"      encoding: NSASCIIStringEncoding];    
		[managementSocket writeString: @"state\r\n"         encoding: NSASCIIStringEncoding];
        [managementSocket writeString: @"bytecount 1\r\n"   encoding: NSASCIIStringEncoding];
        [managementSocket writeString: @"hold release\r\n"  encoding: NSASCIIStringEncoding];
    } NS_HANDLER {
        NSLog(@"Exception caught while writing to socket: %@\n", localException);
    }
    NS_ENDHANDLER
    
}

-(void)setPIDFromLine:(NSString *)line 
{
	if([line rangeOfString: @"SUCCESS: pid="].length) {
		@try {
			NSArray* parameters = [line componentsSeparatedByString: @"="];
			NSString *pidString = [parameters lastObject];
			pid = atoi([pidString UTF8String]);			
		} @catch(NSException *exception) {
			pid = 0;
		}
	}
}

-(void) setStateFromLine: (NSString *) line 
{
    @try {
        NSArray* parameters = [line componentsSeparatedByString: @","];
        if (  [parameters count] > 1  ) {
            NSString *stateString = [parameters objectAtIndex:1];
            if (  [stateString length] > 3  ) {
                NSArray * validStates = [NSArray arrayWithObjects:
                                         @"ADD_ROUTES", @"ASSIGN_IP", @"AUTH", @"CONNECTED",  @"CONNECTING",
                                         @"EXITING", @"GET_CONFIG", @"RECONNECTING", @"RESOLVE", @"SLEEP", @"TCP_CONNECT", @"UDP_CONNECT", @"WAIT", nil];
                if (  [validStates containsObject: stateString]  ) {
                    [self processState: stateString dated: [parameters objectAtIndex: 0]];
                }
            }
        }
    } @catch(NSException *exception) {
        NSLog(@"Caught exception in setStateFromLine: \"%@\"", line);
    }
}

-(void) processState: (NSString *) newState dated: (NSString *) dateTime
{
    if ([newState isEqualToString: @"EXITING"]) {
        [self hasDisconnected];                     // Sets lastState and does processing only once
    } else {
        
        if ([newState isEqualToString: @"CONNECTED"]) {
            NSDate *date; 
            if (  dateTime) {
                date = [NSCalendarDate dateWithTimeIntervalSince1970: [dateTime intValue]];
            } else {
                date = [[[NSDate alloc] init] autorelease];
            }
            [self setConnectedSinceDate: date];
            [self clearStatisticsIncludeTotals: NO];
            [gTbDefaults setBool: YES forKey: [displayName stringByAppendingString: @"-lastConnectionSucceeded"]];
        }
        
        [self setState: newState];
        
        if([newState isEqualToString: @"RECONNECTING"]) {
            [managementSocket writeString: @"hold release\r\n" encoding: NSASCIIStringEncoding];
            
        } else if ([newState isEqualToString: @"CONNECTED"]) {
            [[NSApp delegate] addConnection:self];
            [self flushDnsCache];
            [gTbDefaults setBool: YES forKey: [displayName stringByAppendingString: @"-lastConnectionSucceeded"]];
        }
    }
}

- (void) processLine: (NSString*) line
{
    if (   tryingToHookup
        && ( ! isHookedup )  ) {
        isHookedup = TRUE;
        tryingToHookup = FALSE;
        [self didHookup];
        if (  [[NSApp delegate] connectionsToRestoreOnUserActive]  ) {
            BOOL stillTrying = FALSE;
            NSEnumerator * e = [[[NSApp delegate] myVPNConnectionDictionary] objectEnumerator];
            VPNConnection * connection;
            while (  connection = [e nextObject]  ) {
                if (  [connection tryingToHookup]  ) {
                    stillTrying = TRUE;
                    break;
                }
            }
            
            if (  ! stillTrying  ) {
                [[NSApp delegate] reconnectAfterBecomeActiveUser];
            }
        }
    }
    
    logFilesMayExist = TRUE;
    
    if (  ! [line hasPrefix: @">"]  ) {
        // Output in response to command to OpenVPN
		[self setPIDFromLine:line];
        [self setStateFromLine:line];
		return;
	}

    // "Real time" output from OpenVPN.
     NSRange separatorRange = [line rangeOfString: @":"];
    if (separatorRange.length) {
        NSRange commandRange = NSMakeRange(1, separatorRange.location-1);
        NSString* command = [line substringWithRange: commandRange];
        NSString* parameterString = [line substringFromIndex: separatorRange.location+1];
        //NSLog(@"Found command '%@' with parameters: %@", command, parameterString);
        
        if ([command isEqualToString: @"STATE"]) {
            NSArray* parameters = [parameterString componentsSeparatedByString: @","];
            NSString* state = [parameters objectAtIndex: 1];
            [self processState: state dated: nil];
            
        } else if ([command isEqualToString: @"PASSWORD"]) {
            if (   [line rangeOfString: @"Failed"].length
                || [line rangeOfString: @"failed"].length  ) {
                
                authFailed = TRUE;
                userWantsState = userWantsUndecided;
                credentialsAskedFor = FALSE;
                
                id buttonWithDifferentCredentials = nil;
                if (  [myAuthAgent authMode]  ) {               // Handle "auto-login" --  we were never asked for credentials, so authMode was never set
                    if ([myAuthAgent keychainHasCredentials]) { //                         so credentials in Keychain (if any) were never used, so we needn't delete them to rery
                        buttonWithDifferentCredentials = NSLocalizedString(@"Try again with different credentials", @"Button");
                    }
                }
                int alertVal = TBRunAlertPanel([NSString stringWithFormat:@"%@: %@", [self displayName], NSLocalizedString(@"Authentication failed", @"Window title")],
                                               NSLocalizedString(@"The credentials (passphrase or username/password) were not accepted by the remote VPN server.", @"Window text"),
                                               NSLocalizedString(@"Try again", @"Button"),  // Default
                                               buttonWithDifferentCredentials,              // Alternate
                                               NSLocalizedString(@"Cancel", @"Button"));    // Other
                if (alertVal == NSAlertDefaultReturn) {
                    userWantsState = userWantsRetry;                // User wants to retry
                    
                } else if (alertVal == NSAlertAlternateReturn) {
                    [myAuthAgent deleteCredentialsFromKeychain];    // User wants to retry after deleting credentials
                    userWantsState = userWantsRetry;
                } else {
                    userWantsState = userWantsAbandon;              // User wants to cancel or an error happened, so disconnect
                    [self addToLog: @"*SurfSafeVPN: Disconnecting; user cancelled authorization or there was an error obtaining authorization"];
                    [self disconnectAndWait: [NSNumber numberWithBool: NO] userKnows: YES];      // (User requested it by cancelling)
                }
                
                [NSTimer scheduledTimerWithTimeInterval: (NSTimeInterval) 0.5   // Wait for time to process new credentials request or disconnect
                                                 target: self
                                               selector: @selector(afterFailureHandler:)
                                               userInfo: [NSDictionary dictionaryWithObjectsAndKeys:
                                                          parameterString, @"parameterString",
                                                          line, @"line", nil]
                                                repeats: NO];
            } else {
                // Password request from server.
                if (  authFailed  ) {
                    if (  userWantsState == userWantsUndecided  ) {
                        // We don't know what to do yet: repeat this again later
                        credentialsAskedFor = TRUE;
                        [NSTimer scheduledTimerWithTimeInterval: (NSTimeInterval) 0.5   // Wait for user to make decision
                                                         target: self
                                                       selector: @selector(credentialsHaveBeenAskedForHandler:)
                                                       userInfo: [NSDictionary dictionaryWithObjectsAndKeys:
                                                                  parameterString, @"parameterString",
                                                                  line, @"line", nil]
                                                        repeats: NO];
                    } else if (  userWantsState == userWantsRetry  ) {
                        // User wants to retry; send the credentials
                        [self provideCredentials: parameterString line: line];
                    } // else user wants to abandon, so just ignore the request for credentials
                } else {
                    [self provideCredentials: parameterString line: line];
                }
            }
            
        } else if ([command isEqualToString:@"NEED-OK"]) {
            // NEED-OK: MSG:Please insert TOKEN
            if ([line rangeOfString: @"Need 'token-insertion-request' confirmation"].length) {
                if (NSDebugEnabled) NSLog(@"Server wants token.");
                NSRange tokenNameRange = [parameterString rangeOfString: @"MSG:"];
                NSString* tokenName = [parameterString substringFromIndex: tokenNameRange.location+4];
                int needButtonReturn = TBRunAlertPanel([NSString stringWithFormat:@"%@: %@",
                                                        [self displayName],
                                                        NSLocalizedString(@"Please insert token", @"Window title")],
                                                       [NSString stringWithFormat:NSLocalizedString(@"Please insert token \"%@\", then click \"OK\"", @"Window text"), tokenName],
                                                       nil,
                                                       NSLocalizedString(@"Cancel", @"Button"),
                                                       nil);
                if (needButtonReturn == NSAlertDefaultReturn) {
                    if (NSDebugEnabled) NSLog(@"Write need ok.");
                    [managementSocket writeString:[NSString stringWithFormat:@"needok 'token-insertion-request' ok\r\n"] encoding:NSASCIIStringEncoding];
                } else {
                    if (NSDebugEnabled) NSLog(@"Write need cancel.");
                    [managementSocket writeString:[NSString stringWithFormat:@"needok 'token-insertion-request' cancel\r\n"] encoding:NSASCIIStringEncoding];
                }
            }
        }
    }
}

-(void) afterFailureHandler: (NSTimer *) timer
{
	[self performSelectorOnMainThread: @selector(afterFailure:) withObject: [timer userInfo] waitUntilDone: NO];
}

-(void) afterFailure: (NSDictionary *) dict
{
    if (   credentialsAskedFor  ) {
        [self credentialsHaveBeenAskedFor: dict];
    } else {
        if (  [self isDisconnected]  ) {
            if (  userWantsState == userWantsRetry  ) {
                [self connect: self userKnows: YES];
            } else if (  userWantsState == userWantsAbandon  ) {
                authFailed = FALSE;                 // (Don't retry)
                credentialsAskedFor = FALSE;
                userWantsState = userWantsUndecided;
            } else {
                // credentialsHaveBeenAskedFor has handled things
            }
        } else {
            // Wait until either credentials have been asked for or tunnel is disconnected
            [NSTimer scheduledTimerWithTimeInterval: (NSTimeInterval) 0.5   // Wait for time to process new credentials request or disconnect
                                             target: self
                                           selector: @selector(afterFailureHandler:)
                                           userInfo: dict
                                            repeats: NO];
        }
    }
}

-(void) credentialsHaveBeenAskedForHandler: (NSTimer *) timer
{
    [self performSelectorOnMainThread: @selector(credentialsHaveBeenAskedFor) withObject: [timer userInfo] waitUntilDone: NO];
}

-(void) credentialsHaveBeenAskedFor: (NSDictionary *) dict
{
    // Only do something if the credentials are still being asked for
    // Otherwise, afterFailure has already taken care of things and we can just forget about it
    if (  credentialsAskedFor  ) {
        if (  [self isDisconnected]  ) {
            if (  userWantsState == userWantsRetry) {
                NSLog(@"Warning: User asked to retry and OpenVPN asked for credentials but OpenVPN has already disconnected; reconnecting %@", displayName);
                [self connect: self userKnows: YES];
                
            } else if (  userWantsState == userWantsAbandon  ) {
                NSLog(@"Warning: User asked to to abandon connection and OpenVPN has already disconnected; ignoring OpenVPN request for credentials for %@", displayName);
                authFailed = FALSE;
                credentialsAskedFor = FALSE;
                userWantsState = userWantsUndecided;
                
            } else {
                // OpenVPN asked for credentials, then disconnected, but user hasn't decided what to do -- wait for user to decide what to do
                [NSTimer scheduledTimerWithTimeInterval: (NSTimeInterval) 0.5   // Wait for time to process new credentials request or disconnect
                                                 target: self
                                               selector: @selector(afterFailureHandler:)
                                               userInfo: dict
                                                repeats: NO];
            }
        } else {
            if (  userWantsState == userWantsRetry) {
                [self provideCredentials: [dict objectForKey: @"parameterString"] line: [dict objectForKey: @"line"]];
                
            } else if (  userWantsState == userWantsAbandon  ) {
                authFailed = FALSE;
                credentialsAskedFor = FALSE;
                userWantsState = userWantsUndecided;
                
            } else {
                // OpenVPN asked for credentials, but user hasn't decided what to do -- wait for user to decide what to do
                [NSTimer scheduledTimerWithTimeInterval: (NSTimeInterval) 0.5   // Wait for time to process new credentials request or disconnect
                                                 target: self
                                               selector: @selector(afterFailureHandler:)
                                               userInfo: dict
                                                repeats: NO];
            }
        }
    }
}

-(void) provideCredentials: (NSString *) parameterString line: (NSString *) line
{
    authFailed = FALSE;
    credentialsAskedFor = FALSE;
    userWantsState = userWantsUndecided;
    
    // Find out whether the server wants a private key or user/auth:
    NSRange pwrange_need = [parameterString rangeOfString: @"Need \'"];
    NSRange pwrange_password = [parameterString rangeOfString: @"\' password"];
    if (pwrange_need.length && pwrange_password.length) {
        if (NSDebugEnabled) NSLog(@"Server wants user private key.");
        [myAuthAgent setAuthMode:@"privateKey"];
        [myAuthAgent performAuthentication];
        if (  [myAuthAgent authenticationWasFromKeychain]  ) {
            [self addToLog: @"*SurfSafeVPN: Obtained VPN passphrase from the Keychain"];
        }
        NSString *myPassphrase = [myAuthAgent passphrase];
        NSRange tokenNameRange = NSMakeRange(pwrange_need.length, pwrange_password.location - 6 );
        NSString* tokenName = [parameterString substringWithRange: tokenNameRange];
        if (NSDebugEnabled) NSLog(@"tokenName is  '%@'", tokenName);
        if(  myPassphrase != nil  ){
            [managementSocket writeString: [NSString stringWithFormat: @"password \"%@\" \"%@\"\r\n", tokenName, escaped(myPassphrase)] encoding:NSISOLatin1StringEncoding];
        } else {
            [self addToLog: @"*SurfSafeVPN: Disconnecting; user cancelled authorization"];
            [self disconnectAndWait: [NSNumber numberWithBool: YES] userKnows: YES];      // (User requested it by cancelling)
        }
        
    } else if ([line rangeOfString: @"Auth"].length) {
        if (NSDebugEnabled) NSLog(@"Server wants user auth/pass.");
        [myAuthAgent setAuthMode:@"password"];
        [myAuthAgent performAuthentication];
        if (  [myAuthAgent authenticationWasFromKeychain]  ) {
            [self addToLog: @"*SurfSafeVPN: Obtained VPN username and password from the Keychain"];
        }
        NSString *myPassword = [myAuthAgent password];
        NSString *myUsername = [myAuthAgent username];
        if(  (myUsername != nil) && (myPassword != nil)  ){
            [managementSocket writeString:[NSString stringWithFormat:@"username \"Auth\" \"%@\"\r\n", escaped(myUsername)] encoding:NSISOLatin1StringEncoding];
            [managementSocket writeString:[NSString stringWithFormat:@"password \"Auth\" \"%@\"\r\n", escaped(myPassword)] encoding:NSISOLatin1StringEncoding];
        } else {
            [self addToLog: @"*SurfSafeVPN: Disconnecting; user cancelled authorization"];
            [self disconnectAndWait: [NSNumber numberWithBool: YES] userKnows: YES];      // (User requested it by cancelling)
        }
        
    } else {
        NSLog(@"Unrecognized PASSWORD command from OpenVPN management interface has been ignored:\n%@", line);
    }
}

// Returns an empty string, " (Private)", " (Shared)", or " (Deployed)" if there are configurations in more than one location
-(NSString *) displayLocation
{
    NSString * locationMessage = @"";
    unsigned havePrivate  = 0;
    unsigned haveShared   = 0;
    unsigned haveDeployed = 0;
    NSString * path;
    NSEnumerator * configEnum = [[[NSApp delegate] myConfigDictionary] objectEnumerator];
    while (   ( path = [configEnum nextObject] )
           && ( (havePrivate + haveShared + haveDeployed) < 2) ) {
        if (  [path hasPrefix: gPrivatePath]  ) {
            havePrivate = 1;
        } else if (  [path hasPrefix: gSharedPath]  ) {
            haveShared = 1;
        } else {
            haveDeployed =1;
        }
    }
    
    if (  (havePrivate + haveShared + haveDeployed) > 1  ) {
        path = [self configPath];
        if (  [path hasPrefix: gDeployPath]) {
            locationMessage =  NSLocalizedString(@" (Deployed)", @"Window title");
        } else if (  [path hasPrefix: gSharedPath]) {
            locationMessage =  NSLocalizedString(@" (Shared)", @"Window title");
        } else {
            locationMessage =  NSLocalizedString(@" (Private)", @"Window title");
        }
    }
    
    return locationMessage;
}

// Adds a message to the log display with the current date/time
-(void)addToLog:(NSString *)text
{
    [logDisplay addToLog: text];
}

// Clears the log
-(void) clearLog
{
    [logDisplay clear];
}

- (void) netsocket: (NetSocket*) socket dataAvailable: (unsigned) inAmount
{
    NSParameterAssert(socket == managementSocket);
    NSString* line;
    
    while ((line = [socket readLine])) {
        // Can we get blocked here?
        //NSLog(@">>> %@", line);
        if (  [line length]  ) {
            NSString * bcClientPrefix = @">BYTECOUNT:";
            NSString * bcServerPrefix = @">BYTECOUNT_CLI:";
            if (  [line hasPrefix: bcClientPrefix]  ) {
                if (   bytecountMutexOK  ) {
                    NSRange commaRange = [line rangeOfString: @","];
                    if (  commaRange.location != NSNotFound  ) {
                        if (  commaRange.location < [line length]  ) {
                            @try {
                                
                                NSDate * currentTime = [NSDate date];
                                unsigned long bcpl = [bcClientPrefix length];
                                NSRange inCountRange = NSMakeRange(bcpl, commaRange.location - bcpl);
                                
                                TBByteCount inCount  = (TBByteCount) [[line substringWithRange: inCountRange]            doubleValue];
                                TBByteCount outCount = (TBByteCount) [[line substringFromIndex: commaRange.location + 1] doubleValue];
                                OSStatus status = pthread_mutex_lock( &bytecountMutex );
                                if (  status != EXIT_SUCCESS  ) {
                                    NSLog(@"VPNConnection:netsocket:dataAvailable: pthread_mutex_lock( &bytecountMutex ) failed; status = %ld", (long) status);
                                    return;
                                }
                                
                                [statistics.lastSet release];
                                statistics.lastSet = [currentTime retain];
                                
                                if (  statistics.totalInBytecount > inCount  ) {
                                    statistics.totalInByteCountBeforeThisConnection += statistics.totalInBytecount;
                                }
                                if (  statistics.totalOutBytecount > inCount  ) {
                                    statistics.totalOutByteCountBeforeThisConnection += statistics.totalOutBytecount;
                                }
                                
                                TBByteCount lastInBytecount    = inCount  - statistics.totalInBytecount;
                                TBByteCount lastOutBytecount   = outCount - statistics.totalOutBytecount;
                                statistics.totalInBytecount    = inCount;
                                statistics.totalOutBytecount   = outCount;
                                
                                // Add new data to the ring buffer
                                int ix = statistics.rbIx;
                                statistics.rb[ix].lastInBytecount  = lastInBytecount;
                                statistics.rb[ix].lastOutBytecount = lastOutBytecount;
                                statistics.rb[ix].lastTimeInterval = [currentTime timeIntervalSinceDate: bytecountsUpdated];
                                ix++;
                                // Point to the next ring buffer entry to write into  
                                if (  ix >= RB_SIZE) {
                                    ix = 0;
                                }
                                statistics.rbIx = ix;
                                
                                [self setBytecountsUpdated: currentTime];

                                pthread_mutex_unlock( &bytecountMutex );
                                
                                [self performSelectorOnMainThread: @selector(updateDisplayWithNewStatistics) 
                                                       withObject: nil 
                                                    waitUntilDone: NO];
                            }
                            @catch (NSException * e) {
                                ;
                            }
                        }
                    }
                }
            } else if (  [line hasPrefix: bcServerPrefix]  ) {
                OSStatus status = pthread_mutex_lock( &bytecountMutex );
                if (  status != EXIT_SUCCESS  ) {
                    NSLog(@"VPNConnection:netsocket:dataAvailable: pthread_mutex_lock( &bytecountMutex ) failed; status = %ld", (long) status);
                    return;
                }
                if (  ! serverNotClient  ) {
                    serverNotClient = TRUE;
                    [self performSelectorOnMainThread: @selector(updateDisplayWithNewStatistics) 
                                           withObject: nil 
                                        waitUntilDone: NO];                    
                }
                pthread_mutex_unlock( &bytecountMutex );
                
            } else {
                
                [self performSelectorOnMainThread: @selector(processLine:) 
                                       withObject: line 
                                    waitUntilDone: NO];
            }
        }
    }
}

- (void) netsocketDisconnected: (NetSocket*) inSocket
{
    if (inSocket==managementSocket) {
        [self setManagementSocket: nil];
        [self performSelectorOnMainThread: @selector(hasDisconnected) withObject: nil waitUntilDone: NO];
    }
}

-(void) readStatisticsTo: (struct Statistics *) returnValue
{
    OSStatus status = pthread_mutex_lock( &bytecountMutex );
    if (  status != EXIT_SUCCESS  ) {
        NSLog(@"VPNConnection:readStatisticsTo: pthread_mutex_lock( &bytecountMutex ) failed; status = %ld", (long) status);
        return;
    }
    
    *returnValue = statistics;
    
    pthread_mutex_unlock( &bytecountMutex );    
}

-(void) setNumber: (NSString * *) rate andUnits: (NSString * *) units from: (TBByteCount) value unitsArray: (NSArray *) unitsArray {
    
    // Decide units
    int i = 0;
    TBByteCount n = value;
    while (  n > 999  ) {
        i++;
        n = (  value + (  1ull << 10*(i-1)  )  ) >> 10*i;
    }
    
    if (  i >= [unitsArray count]  ) {
        *units = @"***";
        *rate  = @"***";
        return;
    }
    
    *units = [unitsArray objectAtIndex: i];
    
    if (  i == 0  ) {
        *rate = [NSString stringWithFormat: @"%llu", value];
    } else {
        double displayDouble = (double) value / (double) ( 1ull << (10*i) );
        TBByteCount displayInteger = (TBByteCount) displayDouble;
        if (  displayDouble < 10.0  ) {
            int displayFraction = (int) ((displayDouble - displayInteger) * 100);
            *rate = [NSString stringWithFormat: @"%llu.%02d", displayInteger, displayFraction];
        } else if (  displayDouble < 100.0  ) {
            int displayFraction = (int) ((displayDouble - displayInteger) * 10);
            *rate = [NSString stringWithFormat: @"%llu.%01d", displayInteger,  displayFraction];
        } else if (  displayDouble < 1000.0 ) {
            *rate = [NSString stringWithFormat: @"%llu", displayInteger];
        } else {
            *units = @"***";
            *rate  = @"***";
        }
    }
}

-(void) updateDisplayWithNewStatistics {
    
    if (   serverNotClient  ) {
        [[statusScreen inTFC]            setTitle: @""];
        [[statusScreen inRateTFC]        setTitle: @""];
        [[statusScreen inRateUnitsTFC]   setTitle: @""];
        [[statusScreen outRateTFC]       setTitle: @""];
        [[statusScreen outRateUnitsTFC]  setTitle: @""];
        [[statusScreen outTFC]           setTitle: @""];
        [[statusScreen inTotalTFC]       setTitle: @""];
        [[statusScreen inTotalUnitsTFC]  setTitle: @""];
        [[statusScreen outTotalTFC]      setTitle: @""];
        [[statusScreen outTotalUnitsTFC] setTitle: @""];
        return;
    }

    struct Statistics stats;
    [self readStatisticsTo: &stats];
    
    NSString * inTotal       = nil;
    NSString * inTotalUnits  = nil;
    NSString * outTotal      = nil;
    NSString * outTotalUnits = nil;

    [self setNumber: &inTotal  andUnits: &inTotalUnits  from: (stats.totalInBytecount  + stats.totalInByteCountBeforeThisConnection ) unitsArray: gTotalUnits];
    [self setNumber: &outTotal andUnits: &outTotalUnits from: (stats.totalOutBytecount + stats.totalOutByteCountBeforeThisConnection) unitsArray: gTotalUnits];

    [[statusScreen inTotalTFC]       setTitle: inTotal];
    [[statusScreen inTotalUnitsTFC]  setTitle: inTotalUnits];
    [[statusScreen outTotalTFC]      setTitle: outTotal];
    [[statusScreen outTotalUnitsTFC] setTitle: outTotalUnits];
    
    // Set the time interval we look at (the last xxx seconds)
    NSTimeInterval rateTimeInterval;
    id obj = [gTbDefaults objectForKey: @"statisticsRateTimeInterval"];
    if (  [obj respondsToSelector: @selector(doubleValue)]  ) {
        rateTimeInterval = [obj doubleValue];
    } else {
        rateTimeInterval = 3.0;
    }
    
    NSTimeInterval timeSinceLastSet = [stats.lastSet timeIntervalSinceNow];
    if (  timeSinceLastSet < 0  ) {
        timeSinceLastSet = - timeSinceLastSet;
    }
    
    rateTimeInterval = rateTimeInterval - timeSinceLastSet;
    if (  rateTimeInterval < 0) {
        [self clearStatisticsRatesDisplay];
        return;
    }
    
    // Accumulate statistics for all samples taken during the last rateTimeInterval seconds
    TBByteCount    tInBytes  = 0;           // # bytes received and sent that we've pulled from the ring buffer
    TBByteCount    tOutBytes = 0;
    NSTimeInterval tTimeInt  = 0.0;         // Time interval the tInBytes and tOutBytes stats cover
    int            nPulled;
    int            ix        = stats.rbIx;  // Index to use to access rb[]
    for (  nPulled=0; nPulled<RB_SIZE; nPulled++  ) {
        // Pull the next data from the ring buffer and incorporate it into accumulated statistics
        if (  ix == 0  ) {
            ix = RB_SIZE;
        }
        ix--;
        
        tTimeInt  += stats.rb[ix].lastTimeInterval;
        tInBytes  += stats.rb[ix].lastInBytecount;
        tOutBytes += stats.rb[ix].lastOutBytecount;
        
        if (  tTimeInt > rateTimeInterval  ) {
            break;
        }
    }

    if ( tTimeInt == 0.0  ) {
        [self clearStatisticsRatesDisplay];
    } else {
        NSString * inRate       = nil;
        NSString * inRateUnits  = nil;
        NSString * outRate      = nil;
        NSString * outRateUnits = nil;
        
        [self setNumber: &inRate  andUnits: &inRateUnits  from: ((double) tInBytes  / tTimeInt) unitsArray: gRateUnits];
        [self setNumber: &outRate andUnits: &outRateUnits from: ((double) tOutBytes / tTimeInt) unitsArray: gRateUnits];
        
        [[statusScreen inRateTFC]       setTitle: inRate];
        [[statusScreen inRateUnitsTFC]  setTitle: inRateUnits];
        [[statusScreen outRateTFC]      setTitle: outRate];
        [[statusScreen outRateUnitsTFC] setTitle: outRateUnits];
    }
}

-(void) clearStatisticsRatesDisplay {
    [[statusScreen inRateTFC]       setTitle: @"0"];
    [[statusScreen outRateTFC]      setTitle: @"0"];
    NSString * units = [gRateUnits objectAtIndex: 0];
    [[statusScreen inRateUnitsTFC]  setTitle: units];
    [[statusScreen outRateUnitsTFC] setTitle: units];
}

-(void) updateStatisticsDisplay {
    
    // Update the connection time string
    [statusScreen setStatus: [self state] forName: [self displayName] connectedSince: [self timeString]];
    
    [self updateDisplayWithNewStatistics];
}

-(NSString *) timeString
{
    if (  ! logFilesMayExist  ) {
        return @"";
    }
    
    NSDate * csd = [self connectedSinceDate];
    NSTimeInterval ti = [csd timeIntervalSinceNow];
    long timeL = (long) round(-ti);
    
    int days  = timeL / (24*60*60);
    long timeLessDays = timeL - ( days * (24*60*60) );
    
    int hours = timeLessDays / (60*60);
    int timeLessDaysHours = timeLessDays - ( hours * (60*60) );
    
    int mins = timeLessDaysHours / 60;
    int secs = timeLessDaysHours - ( mins * (60) );
    
    NSString * cTimeS;
    if (  days > 0  ) {
        cTimeS = [NSString stringWithFormat: NSLocalizedString(@"%d days %li:%02li:%02li", @"Tooltip"), days, hours, mins, secs];
    } else if (  hours > 0) {
        cTimeS = [NSString stringWithFormat: @"%d:%02d:%02d", hours, mins, secs];
    } else {
        cTimeS = [NSString stringWithFormat: @"%02d:%02d", mins, secs];
    }
    
    return cTimeS;
}

- (NSString*) state
{
    return lastState;
}

- (void) setDelegate: (id) newDelegate
{
    delegate = newDelegate;
}

-(BOOL) isConnected
{
    return [[self state] isEqualToString:@"CONNECTED"];
}
-(BOOL) isDisconnected 
{
    return [[self state] isEqualToString:@"EXITING"];
}

-(BOOL) authFailed
{
    return authFailed;
}

- (void) setState: (NSString*) newState
	// Be sure to call this in main thread only
{
    [newState retain];
    [lastState release];
    lastState = newState;

    // The 'pre-connect.sh' and 'post-tun-tap-load.sh' scripts are run by openvpnstart
    // The 'connected.sh' and 'reconnecting.sh' scripts are run here
    // The 'disconnect.sh' script is run by this class's hasDisconnected method
    if (   [newState isEqualToString: @"EXITING"]
        && [requestedState isEqualToString: @"CONNECTED"]
        && ( ! [[NSApp delegate] terminatingAtUserRequest] )  ) {
        [tunnelDownSound play];
    } else if (  [newState isEqualToString: @"CONNECTED"]  ) {
        [tunnelUpSound play];
        // Run the connected script, if any
        [self runScriptNamed: @"connected" openvpnstartCommand: @"connected"];
        [gTbDefaults setObject: displayName forKey: @"lastConnectedDisplayName"];
    } else if (  [newState isEqualToString: @"RECONNECTING"]  ) {
        [tunnelDownSound play];
        // Run the reconnecting script, if any
        [self runScriptNamed: @"reconnecting" openvpnstartCommand: @"reconnecting"];
    }
    
    NSString * statusPref = [gTbDefaults objectForKey: @"connectionWindowDisplayCriteria"];
    if (   [statusPref isEqualToString: @"showWhenChanges"]
        || [newState isEqualToString: @"RECONNECTING"]  ) {
        [self showStatusWindow];
    }
    
    [statusScreen setStatus: newState forName: [self displayName] connectedSince: [self timeString]];
    
    if (  showingStatusWindow  ) {
        if (   [newState isEqualToString: @"CONNECTED"]
            || [newState isEqualToString: @"EXITING"]  ) {
            // Wait one second, then fade away
            [NSTimer scheduledTimerWithTimeInterval:1.0
                                             target: self
                                           selector:@selector(fadeAway)
                                           userInfo:nil
                                            repeats:NO];
        }
    }

    [[NSApp delegate] performSelectorOnMainThread:@selector(setState:) withObject:newState waitUntilDone:NO];
    [delegate performSelector: @selector(connectionStateDidChange:) withObject: self];    
}

-(void) runScriptNamed: (NSString *) scriptName openvpnstartCommand: (NSString *) command
{
    if (  [[configPath pathExtension] isEqualToString: @"tblk"]  ) {
        NSString * scriptPath = [[[[configPath
                                    stringByAppendingPathComponent: @"Contents"]
                                   stringByAppendingPathComponent: @"Resources"]
                                  stringByAppendingPathComponent: scriptName]
                                 stringByAppendingPathExtension: @"sh"];
        if (  [gFileMgr fileExistsAtPath: scriptPath]  ) {
            NSString * path = [[NSBundle mainBundle] pathForResource: @"openvpnstart" ofType: nil];
            NSArray * startArguments = [self argumentsForOpenvpnstartForNow: YES];
            if (   startArguments
                && ( ! [[startArguments objectAtIndex: 5] isEqualToString: @"1"] )  ) {
                NSArray * arguments = [NSArray arrayWithObjects:
                                       command,
                                       [startArguments objectAtIndex: 1],    // configFile
                                       [startArguments objectAtIndex: 5],    // cfgLocCode
                                       nil];
                
                NSTask * task = [[NSTask alloc] init];
                [task setLaunchPath: path];
                [task setArguments: arguments];

                NSString * msg = [NSString stringWithFormat: @"*SurfSafeVPN: '%@.sh' executing…", scriptName];
                [self addToLog: msg];
                [task launch];
                [task waitUntilExit];
                int status = [task terminationStatus];
                msg = [NSString stringWithFormat: @"*SurfSafeVPN: '%@.sh' returned with status %d", scriptName, status];
                [self addToLog: msg];
                [task release];
                if (   (status != 0)
                    && ( ! [scriptName isEqualToString: @"post-disconnect"] )  ) {
                    [self addToLog: @"*SurfSafeVPN: Disconnecting; script failed"];
                    [self disconnectAndWait: [NSNumber numberWithBool: NO] userKnows: YES]; // Disconnect because script failed
                }
            }
        }
    }
}

-(void) fadeAway
{
    if (  ! (   gTunnelblickIsQuitting
             || gComputerIsGoingToSleep )  ) {
        BOOL okToFade = TRUE;   // Assume OK to fade, but don't fade if any connection is being attempted or any auth failed
        VPNConnection * connection;
        NSEnumerator * connectionEnum = [[[NSApp delegate] connectionArray] objectEnumerator];
        while (  connection = [connectionEnum nextObject]  ) {
            if (   ( ! [connection isConnected]    )            // Don't fade if any connection is being  attempted
                && ( ! [connection isDisconnected] )  ) {
                okToFade = FALSE;
                break;
            }
            if (  [connection authFailed]  ) {                  // or if any auth failed
                okToFade = FALSE;
                break;
            }
        }
        if (  [[NSApp delegate] mouseIsInsideAnyView]  ) {
            okToFade = FALSE;
        }
        
        if (  okToFade  ) {
            [statusScreen fadeOut];
            showingStatusWindow = FALSE;
        }
    }
}

- (unsigned int) getFreePort
{
	unsigned int resultPort = 1336; // start port	
	int fd = socket(AF_INET, SOCK_STREAM, 0);
	int result = 0;
	
	do {		
		struct sockaddr_in address;
		int len = sizeof(struct sockaddr_in);
		resultPort++;
		
		address.sin_len = len;
		address.sin_family = AF_INET;
		address.sin_port = htons(resultPort);
		address.sin_addr.s_addr = htonl(0x7f000001); // 127.0.0.1, localhost
		
		memset(address.sin_zero,0,sizeof(address.sin_zero));
		
		result = bind(fd, (struct sockaddr *)&address,sizeof(address));
		
	} while (result!=0);
	
	close(fd);
	
	return resultPort;
}

- (BOOL)validateMenuItem:(NSMenuItem *)anItem
{
 
    SEL action = [anItem action];

    if (action == @selector(toggle:)) 
    {
        VPNConnection *connection = [anItem target];
        
        // setting menu item's state:
        int state = NSMixedState;
        
        if ([connection isConnected]) 
        {
            state = NSOnState;
        } 
        else if ([connection isDisconnected]) 
        {
            state = NSOffState;
            if (![[[NSApp delegate] getLastState] isEqualToString:(@"EXITING" )]){
                [anItem setHidden:YES];
            }
            else{
                [anItem setHidden:NO];
            }
        }
        
        [anItem setState:state];
        
        // setting menu command title depending on current status:
        NSString *commandString; 
        if (  ! [[connection state] isEqualToString:@"EXITING"]  ) {
            commandString = NSLocalizedString(@"Disconnect %@%@", @"Menu item");
        } else {
            commandString = NSLocalizedString(@"Connect %@%@", @"Menu item");
        }
        
        // Remove submenu prefix if using submenus
        NSString * itemName = [connection displayName];
        NSRange lastSlashRange = [itemName rangeOfString: @"/" options: NSBackwardsSearch range: NSMakeRange(0, [itemName length] - 1)];
        if (   (lastSlashRange.length != 0)
            && ( ! [gTbDefaults boolForKey: @"doNotShowConnectionSubmenus"])  ) {
            itemName = [itemName substringFromIndex: lastSlashRange.location + 1];
        }
        
        NSString *itemTitle = [NSString stringWithFormat:commandString,
                               itemName,
                               [self connectTimeString]];
        [anItem setTitle:itemTitle];
        if (  [gTbDefaults boolForKey: @"showTooltips"]  ) {
            [anItem setToolTip: [connection configPath]];
        }
    }
	return YES;
}

-(int) useDNSStatus
{
	NSString * key = [[self displayName] stringByAppendingString:@"useDNS"];
	id useObj = [gTbDefaults objectForKey:key];
	if (  useObj == nil  ) {
		return 1;   // Preference is not set, so use default value
	} else {
        if (  [useObj respondsToSelector: @selector(intValue)]  ) {
            return [useObj intValue];
        } else {
            NSLog(@"Preference '%@' is not a number; it has value %@. Assuming 'Do not set nameserver'", key, useObj);
            return 0;
        }
    }
}

// Returns an array of NSDictionary objects with entries for the 'Set nameserver' popup button for this connection
// The "value" entry is the value of the xxxUseDNS preference for that entry
-(NSArray *) modifyNameserverOptionList
{
    // Figure out whether to use the standard scripts or 'custom' scripts
    // If Deployed, .tblk, or "old" scripts exist, they are considered "custom" scripts
    BOOL custom = FALSE;
    NSString * resourcePath          = [[NSBundle mainBundle] resourcePath];
    
    if (  [configPath hasPrefix: gDeployPath]  ) {
        NSString * deployPath                  = [resourcePath stringByAppendingPathComponent: @"Deploy"];
        NSString * configFile                  = [configPath lastPathComponent];
        NSString * deployScriptPath            = [deployPath stringByAppendingPathComponent:[configFile stringByDeletingPathExtension]];
        NSString * deployUpscriptPath          = [deployScriptPath stringByAppendingPathExtension: @"up.sh"            ];
        NSString * deployUpscriptNoMonitorPath = [deployScriptPath stringByAppendingPathExtension: @"nomonitor.up.sh"  ];
        NSString * deployNewUpscriptPath       = [deployScriptPath stringByAppendingPathExtension: @"up.tunnelblick.sh"];
        if (   [gFileMgr fileExistsAtPath: deployUpscriptPath]
            || [gFileMgr fileExistsAtPath: deployUpscriptNoMonitorPath]
            || [gFileMgr fileExistsAtPath: deployNewUpscriptPath]  ) {
            custom = TRUE;
        }
    } else {
        NSString * upscriptPath          = [resourcePath stringByAppendingPathComponent: @"client.up.osx.sh"          ];
        NSString * upscriptNoMonitorPath = [resourcePath stringByAppendingPathComponent: @"client.nomonitor.up.osx.sh"];
        if (   [gFileMgr fileExistsAtPath: upscriptPath]
            || [gFileMgr fileExistsAtPath: upscriptNoMonitorPath]  ) {
            custom = TRUE;
        }
    }
    
    if (  ! custom  ) {
        if (  [[configPath pathExtension] isEqualToString: @"tblk"]) {
            NSString * scriptPath                   = [configPath stringByAppendingPathComponent: @"Contents/Resources"];
            NSString * tblkUpscriptPath             = [scriptPath stringByAppendingPathComponent: @"up.sh"            ];
            NSString * tblkUpscriptNoMonitorPath    = [scriptPath stringByAppendingPathComponent: @"nomonitor.up.sh"  ];
            NSString * tblkNewUpscriptPath          = [scriptPath stringByAppendingPathComponent: @"up.tunnelblick.sh"];
            if (   [gFileMgr fileExistsAtPath: tblkUpscriptPath]
                || [gFileMgr fileExistsAtPath: tblkUpscriptNoMonitorPath]
                || [gFileMgr fileExistsAtPath: tblkNewUpscriptPath]  ) {
                custom = TRUE;
            }
        }
    }
    
    if (   custom  ) {
        return [[[NSArray alloc] initWithObjects:
                 [NSDictionary dictionaryWithObjectsAndKeys: NSLocalizedString(@"Do not set nameserver",          @"PopUpButton"), @"name", @"0", @"value", nil],
                 [NSDictionary dictionaryWithObjectsAndKeys: NSLocalizedString(@"Set nameserver",                 @"PopUpButton"), @"name", @"1", @"value", nil],
                 nil] autorelease];
    } else {
        return [[[NSArray alloc] initWithObjects:
                 [NSDictionary dictionaryWithObjectsAndKeys: NSLocalizedString(@"Do not set nameserver",        @"PopUpButton"), @"name", @"0", @"value", nil],
                 [NSDictionary dictionaryWithObjectsAndKeys: NSLocalizedString(@"Set nameserver",               @"PopUpButton"), @"name", @"1", @"value", nil],
                 [NSDictionary dictionaryWithObjectsAndKeys: NSLocalizedString(@"Set nameserver (3.1)",         @"PopUpButton"), @"name", @"4", @"value", nil],
                 [NSDictionary dictionaryWithObjectsAndKeys: NSLocalizedString(@"Set nameserver (3.0b10)",      @"PopUpButton"), @"name", @"2", @"value", nil],
                 [NSDictionary dictionaryWithObjectsAndKeys: NSLocalizedString(@"Set nameserver (alternate 1)", @"PopUpButton"), @"name", @"3", @"value", nil],
                 nil] autorelease];
    }
}

-(void) startMonitoringLogFiles
{
    [logDisplay startMonitoringLogFiles];
}

-(void) stopMonitoringLogFiles
{
    [logDisplay stopMonitoringLogFiles];
}

-(NSString *) openvpnLogPath
{
    return [logDisplay openvpnLogPath];
}

-(BOOL) logFilesMayExist {

    return logFilesMayExist;
}

TBSYNTHESIZE_OBJECT_SET(NSSound *, tunnelUpSound,   setTunnelUpSound)

TBSYNTHESIZE_OBJECT_SET(NSSound *, tunnelDownSound, setTunnelDownSound)

TBSYNTHESIZE_OBJECT(retain, NSDate *, bytecountsUpdated, setBytecountsUpdated)


//*********************************************************************************************************
//
// AppleScript support
//
//*********************************************************************************************************

- (NSScriptObjectSpecifier *)objectSpecifier
{
    NSScriptClassDescription* appDesc = (NSScriptClassDescription*)[NSApp classDescription]; 
    
    return [[[NSNameSpecifier alloc] 
             initWithContainerClassDescription:appDesc 
             containerSpecifier:nil 
             key:@"applescriptConfigurationList" 
             name:[self displayName]] autorelease]; 
} 

- (NSString *) autoConnect
{
    NSString* autoConnectkey = [[self displayName] stringByAppendingString: @"autoConnect"];
    NSString* systemStartkey = [[self displayName] stringByAppendingString: @"-onSystemStart"];
    
    if (  [gTbDefaults boolForKey: autoConnectkey]  ) {
        if (  [gTbDefaults boolForKey: systemStartkey]  ) {
            return @"START";
        }

        return @"LAUNCH";
    }
    
    return @"NO";
}

- (NSString *) bytesIn
{
    struct Statistics stats;
    [self readStatisticsTo: &stats];
    return [NSString stringWithFormat: @"%llu", (unsigned long long) (stats.totalInBytecount + stats.totalInByteCountBeforeThisConnection)];
}
- (NSString *) bytesOut
{
    struct Statistics stats;
    [self readStatisticsTo: &stats];
    return [NSString stringWithFormat: @"%llu", (unsigned long long) (stats.totalOutBytecount + stats.totalOutByteCountBeforeThisConnection)];
}


- (void) setProxy:(Proxy *)aProxy{
    [proxy release];
    proxy = [aProxy retain];
}

@end
