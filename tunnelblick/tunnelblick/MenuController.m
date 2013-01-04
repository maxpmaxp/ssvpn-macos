/*
 * Copyright 2004, 2005, 2006, 2007, 2008, 2009 Angelo Laub
 * Contributions by Dirk Theisen <dirk@objectpark.org>, 
 *                  Jens Ohlig, 
 *                  Waldemar Brodkorb
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

#import <Foundation/NSDebug.h>
#import <pthread.h>
#import <sys/stat.h>
#import <sys/mount.h>
#import <uuid/uuid.h>
#import "defines.h"
#import "MenuController.h"
#import "NSApplication+LoginItem.h"
#import "NSApplication+NetworkNotifications.h"
#import "NSApplication+SystemVersion.h"
#import "NSString+TB.h"
#import "helper.h"
#import "TBUserDefaults.h"
#import "ConfigurationManager.h"
#import "VPNConnection.h"
#import "NSFileManager+TB.h"
#import "MainIconView.h"
#import "MyPrefsWindowController.h"
#import "SplashWindowController.h"
#import "ConfigurationUpdater.h"
#import "UKKQueue/UKKQueue.h"
#import "Sparkle/SUUpdater.h"
#import "VPNConnection.h"
#import "ConfigurationNetwork.h"
//#import "CertTrustSetter.h"


#ifdef INCLUDE_VPNSERVICE
#import "VPNService.h"
#endif

// These are global variables rather than class variables to make access to them easier
NSMutableArray        * gConfigDirs;            // Array of paths to configuration directories currently in use
NSString              * gPrivatePath;           // Path to ~/Library/Application Support/SurfSafeVPN/Configurations
NSString              * gDeployPath;            // Path to /Library/Application Support/SurfSafeVPN/Deploy/<application-name>
TBUserDefaults        * gTbDefaults;            // Our preferences
NSFileManager         * gFileMgr;               // [NSFileManager defaultManager]
AuthorizationRef        gAuthorization;         // Used to call installer
NSArray               * gProgramPreferences;    // E.g., 'placeIconInStandardPositionInStatusBar'
NSArray               * gConfigurationPreferences; // E.g., '-onSystemStart'
BOOL                    gShuttingDownTunnelblick;// TRUE if applicationShouldTerminate: has been invoked
BOOL                    gShuttingDownWorkspace;
BOOL                    gShuttingDownOrRestartingComputer;
BOOL                    gComputerIsGoingToSleep;// Flag that the computer is going to sleep
unsigned                gHookupTimeout;         // Number of seconds to try to establish communications with (hook up to) an OpenVPN process
//                                              // or zero to keep trying indefinitely
unsigned                gMaximumLogSize;        // Maximum size (bytes) of buffer used to display the log
NSArray               * gRateUnits;             // Array of strings with localized data units      (KB/s, MB/s, GB/s, etc.)
NSArray               * gTotalUnits;            // Array of strings with localized data rate units (KB,   MB,   GB,   etc.)
NSTimeInterval          gDelayToShowStatistics; // Time delay from mouseEntered icon or statistics window until showing the statistics window
NSTimeInterval          gDelayToHideStatistics; // Time delay from mouseExited icon or statistics window until hiding the statistics window


enum TerminationReason  reasonForTermination;   // Why we are terminating execution

UInt32 fKeyCode[16] = {0x7A, 0x78, 0x63, 0x76, 0x60, 0x61, 0x62, 0x64,        // KeyCodes for F1...F16
    0x65, 0x6D, 0x67, 0x6F, 0x69, 0x6B, 0x71, 0x6A};

void terminateBecauseOfBadConfiguration(void);
BOOL needToUpdateDeploy(void);

OSStatus hotKeyPressed(EventHandlerCallRef nextHandler,EventRef theEvent, void * userData);
OSStatus RegisterMyHelpBook(void);
BOOL checkOwnedByRootWheel(NSString * path);

@interface NSStatusBar (NSStatusBar_Private)
- (id)_statusItemWithLength:(float)l withPriority:(int)p;
- (id)_insertStatusItem:(NSStatusItem *)i withPriority:(int)p;
@end

@interface MenuController() // PRIVATE METHODS

// System interfaces:
-(BOOL)             application:                            (NSApplication *)   theApplication
                      openFiles:                            (NSArray * )        filePaths;

-(void)             applicationDidFinishLaunching:          (NSNotification *)  notification;

-(void)             applicationWillFinishLaunching:         (NSNotification *)  notification;

-(void)             applicationWillTerminate:               (NSNotification*)   notification;

// Private interfaces
-(void)             addCustomMenuItems;
-(BOOL)             addCustomMenuItemsFromFolder:           (NSString *)        folderPath
                                          toMenu:           (NSMenu *)          theMenu;
-(void)             addOneCustomMenuItem:                   (NSString *)        file
                              fromFolder:                   (NSString *)        folder
                                  toMenu:                   (NSMenu *)          theMenu;
-(BOOL)             addOneCustomMenuSubmenu:                (NSString *)        file
                                 fromFolder:                (NSString *)        folder
                                     toMenu:                (NSMenu *)          theMenu;
-(void)             addPath:                                (NSString *)        path
             toMonitorQueue:                                (UKKQueue *)        queue;
-(void)             activateStatusMenu;
-(void)             addNewConfig:                           (NSString *)        path
                 withDisplayName:                           (NSString *)        dispNm;
-(BOOL)             application:                            (NSApplication *)   theApplication
                      openFiles:                            (NSArray * )        filePaths
        skipConfirmationMessage:                            (BOOL)              skipConfirmMsg
              skipResultMessage:                            (BOOL)              skipResultMsg;

-(BOOL)             canRunFromVolume:                       (NSString *)        path;
-(NSURL *)          contactURL;
-(NSString *)       deconstructOpenVPNLogPath:              (NSString *)        logPath
                                       toPort:              (unsigned *)        portPtr
                                  toStartArgs:              (NSString * *)      startArgsPtr;
-(NSArray *)        findTblksToInstallInPath:               (NSString *)        thePath;
-(void)             checkNoConfigurations;
-(void)             deleteExistingConfig:                   (NSString *)        dispNm;
-(void)             deleteLogs;
-(void)             initialChecks;
-(unsigned)         getLoadedKextsMask;
-(BOOL)             hasValidSignature;
-(void)             hookupWatchdogHandler;
-(void)             hookupWatchdog;
-(BOOL)             hookupToRunningOpenVPNs;
-(void)             initialiseAnim;
-(void)             insertConnectionMenuItem:               (NSMenuItem *)      theItem
                                    IntoMenu:               (NSMenu *)          theMenu
                                  afterIndex:               (int)               theIndex
                                    withName:               (NSString *)        displayName;
-(NSString *)       installationId;
-(void)             killAllConnectionsIncludingDaemons:     (BOOL)              includeDaemons
                                            logMessage:     (NSString *)        logMessage;
-(void)             makeSymbolicLink;
-(NSString *)       menuNameFromFilename:                   (NSString *)        inString;
-(void)             removeConnectionWithDisplayName:        (NSString *)        theName
                                           fromMenu:        (NSMenu *)          theMenu
                                         afterIndex:        (int)               theIndex;
-(void)             removeConnectionWithDisplayName:        (NSString *)        theName
                                           fromMenu:        (NSMenu *)          theMenu
                                         afterIndex:        (int)               theIndex
                                        workingName:        (NSString *)        workingName;
-(void)             removePath:                             (NSString *)        path
              fromMonitorQueue:                             (UKKQueue *)        queue;
-(void)             runCustomMenuItem:                      (NSMenuItem *)      item;
-(BOOL)             setupHookupWatchdogTimer;
-(void)             setupHotKeyWithCode:                    (UInt32)            keyCode
                        andModifierKeys:                    (UInt32)            modifierKeys;
-(NSStatusItem *)   statusItem;
-(void)             updateMenuAndLogWindow;
-(void)             updateNavigationLabels;
-(BOOL)             validateMenuItem:                       (NSMenuItem *)      anItem;
-(void)             watcher:                                (UKKQueue *)        kq
       receivedNotification:                                (NSString *)        nm
                    forPath:                                (NSString *)        fpath;
-(void) relaunchIfNecessary;
-(void) secureIfNecessary;

-(void)             setEnableWebSWebProxies: (Proxy*) proxy;
-(void)             restoreWebSWebProxies;

@end

@implementation MenuController

-(id) init
{	
    if (  (self = [super init])  ) {
        
        reasonForTermination = terminatingForUnknownReason;
        
        if (  ! runningOnTigerOrNewer()  ) {
            TBRunAlertPanel(NSLocalizedString(@"System Requirements Not Met", @"Window title"),
                            NSLocalizedString(@"SurfSafeVPN requires OS X 10.4 or above\n     (\"Tiger\", \"Leopard\", or \"Snow Leopard\")", @"Window text"),
                            nil, nil, nil);
            [self terminateBecause: terminatingBecauseOfError];
            
        }
        
        launchFinished = FALSE;
        hotKeyEventHandlerIsInstalled = FALSE;
        terminatingAtUserRequest = FALSE;
        mouseIsInMainIcon = FALSE;
        mouseIsInStatusWindow = FALSE;
        signatureIsInvalid = FALSE;
		
        gShuttingDownTunnelblick = FALSE;
        gShuttingDownOrRestartingComputer = FALSE;
        gShuttingDownWorkspace = FALSE;
        gComputerIsGoingToSleep = FALSE;
        
        noUnknownOpenVPNsRunning = NO;   // We assume there are unattached processes until we've had time to hook up to them
        
        dotTblkFileList = nil;
        showDurationsTimer = nil;
        customRunOnLaunchPath = nil;
        customRunOnConnectPath = nil;
        customMenuScripts = nil;
                
        tunCount = 0;
        tapCount = 0;
        
        connectionsToRestoreOnWakeup = [[NSMutableArray alloc] initWithCapacity: 5];
        
        gFileMgr    = [NSFileManager defaultManager];
        
        gPrivatePath = [[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/SurfSafeVPN/Configurations"] copy];
        createDir(gPrivatePath, PERMS_PRIVATE_SELF);     // Create private configurations folder if necessary
        
        
		gConfigDirs = [[NSMutableArray alloc] initWithCapacity: 2];
        
		[NSApp setDelegate: self];
		
        userIsAnAdmin = isUserAnAdmin();
        
        NSBundle * ourBundle   = [NSBundle mainBundle];
        NSString * ourBundlePath = [ourBundle bundlePath];
        NSArray  * execComponents = [ourBundlePath pathComponents];
        if (  [execComponents count] < 1  ) {
            NSLog(@"Too few execComponents; ourBundlePath = %@", ourBundlePath);
            exit(1);
        }
        NSString * ourAppName = [execComponents objectAtIndex: [execComponents count] - 1];
		if (  [ourAppName hasSuffix: @".app"]  ) {
			ourAppName = [ourAppName substringToIndex: [ourAppName length] - 4];
		}
        gDeployPath = [[L_AS_T_DEPLOY stringByAppendingPathComponent: ourAppName] copy];
		
		// Remove any old "Launch Tunnelblick" link in the private configurations folder
		NSString * tbLinkPath = [gPrivatePath stringByAppendingPathComponent: @"Launch SurfSafeVPN"];
		[gFileMgr tbRemoveFileAtPath: tbLinkPath handler: nil];
        
        gProgramPreferences = [[NSArray arrayWithObjects:
                                @"skipWarningAboutReprotectingConfigurationFile",
                                @"skipWarningAboutSimultaneousConnections",
								@"skipWarningAboutConvertingToTblks",
                                @"skipWarningThatCannotModifyConfigurationFile",
                                @"skipWarningThatNameChangeDisabledUpdates",
                                @"skipWarningAboutNonAdminUpdatingTunnelblick",
                                @"skipWarningAboutUnknownOpenVpnProcesses",
                                @"skipWarningAboutOnComputerStartAndTblkScripts",
                                @"skipWarningAboutIgnoredConfigurations",
                                @"skipWarningAboutConfigFileProtectedAndAlwaysExamineIt",
                                @"skipWarningThatIPAddressDidNotChangeAfterConnection",
                                @"skipWarningThatDNSIsNotWorking",
                                @"skipWarningThatInternetIsNotReachable",
								@"skipWarningAboutInvalidSignature",
								@"skipWarningAboutNoSignature",
                                
                                @"placeIconInStandardPositionInStatusBar",
                                @"doNotMonitorConfigurationFolder",
                                @"onlyAdminsCanUnprotectConfigurationFiles",
                                @"standardApplicationPath",
                                @"doNotCreateLaunchTunnelblickLinkinConfigurations",
                                @"useShadowConfigurationFiles",
                                @"usePrivateConfigurationsWithDeployedOnes",
                                @"hookupTimeout",
                                @"openvpnTerminationInterval",
                                @"openvpnTerminationTimeout",
                                @"menuIconSet",
                                @"easy-rsaPath",
                                @"IPAddressCheckURL",
                                @"notOKToCheckThatIPAddressDidNotChangeAfterConnection",
                                @"askedUserIfOKToCheckThatIPAddressDidNotChangeAfterConnection",
                                @"timeoutForIPAddressCheckBeforeConnection",
                                @"timeoutForIPAddressCheckAfterConnection",
                                @"delayBeforeIPAddressCheckAfterConnection",
                                
                                @"disableAdvancedButton",
                                @"disableCheckNowButton",
                                @"disableResetDisabledWarningsButton",
                                
                                @"disableAddConfigurationButton",
                                @"disableRemoveConfigurationButton",
                                @"disableWorkOnConfigurationButton",
                                
                                @"disableRenameConfigurationMenuItem",
                                @"disableDuplicateConfigurationMenuItem",
                                @"disableMakeConfigurationPublicOrPrivateMenuItem",
                                @"disableRevertToShadowMenuItem",
                                @"disableExamineOpenVpnConfigurationFileMenuItem",
                                @"disableShowOpenVpnLogInFinderMenuItem",
                                @"disableDeleteConfigurationCredentialsInKeychainMenuItem",
                                
                                @"disableCopyLogToClipboardButton",
                                
                                @"doNotShowNotificationWindowBelowIconOnMouseover",
                                @"doNotShowNotificationWindowOnMouseover",
                                @"doNotShowDisconnectedNotificationWindows",
                                @"doNotShowConnectionSubmenus",
                                @"doNotShowVpnDetailsMenuItem",
                                @"doNotShowSuggestionOrBugReportMenuItem",
                                @"doNotShowAddConfigurationMenuItem",
                                @"doNotShowSplashScreen",
                                @"showConnectedDurations",
                                @"showStatusWindow",
                                
                                @"openvpnVersion",
                                @"maximumNumberOfTabs",
                                @"onlyAdminCanUpdate",
                                @"connectionWindowDisplayCriteria",
                                @"showTooltips",
                                @"maxLogDisplaySize",
                                @"lastConnectedDisplayName",
                                @"installationUID",
                                @"keyboardShortcutIndex",
                                @"doNotUnrebrandLicenseDescription",
                                @"useSharedConfigurationsWithDeployedOnes",
                                @"usePrivateConfigurationsWithDeployedOnes",
								@"namedCredentialsThatAllConfigurationsUse",
                                
                                @"delayToShowStatistics",
                                @"delayToHideStatistics",
                                @"statisticsRateTimeInterval",
                                
                                @"updateAutomatically",
                                @"updateCheckAutomatically",
                                @"updateCheckInterval",
                                @"updateFeedURL",
                                @"updateSendProfileInfo",
                                @"updateSigned",
                                @"updateUnsigned",
                                @"updateUUID",

                                @"NSWindow Frame SettingsSheetWindow",
                                @"NSWindow Frame ConnectingWindow",
                                @"NSWindow Frame SUStatusFrame",
                                @"detailsWindowFrameVersion",
                                @"detailsWindowFrame",
                                @"detailsWindowLeftFrame",
                                
                                @"haveDealtWithSparkle1dot5b6",
                                
                                @"SUEnableAutomaticChecks",
                                @"SUFeedURL",
                                @"SUScheduledCheckInterval",
                                @"SUSendProfileInfo",
                                @"SUAutomaticallyUpdate",
                                @"SULastCheckTime",
                                @"SULastProfileSubmissionDate",
                                @"SUHasLaunchedBefore",
                                @"SUSkippedVersion",
                                
                                
                                @"WebKitDefaultFontSize",
                                @"WebKitStandardFont",
                                
                                @"ApplicationCrashedAfterRelaunch",
                                
                                // No longer used
                                @"doNotShowCheckForUpdatesNowMenuItem",
                                @"doNotShowForcedPreferenceMenuItems",
                                @"doNotShowKeyboardShortcutSubmenu",
                                @"doNotShowOptionsSubmenu",
                                
                                //HTK-INC
                                @"EnableProxy",
                                nil] retain];
        
        gConfigurationPreferences = [[NSArray arrayWithObjects:
                                      @"-skipWarningAboutDownroot",
                                      @"-skipWarningAboutNoTunOrTap",
                                      @"-skipWarningUnableToToEstablishOpenVPNLink",
                                      
                                      @"autoConnect",
                                      @"-onSystemStart",
                                      @"useDNS",
                                      @"-notMonitoringConnection",
                                      @"-doNotRestoreOnDnsReset",
                                      @"-doNotRestoreOnWinsReset",
                                      @"-leasewatchOptions",
                                      @"-doNotDisconnectOnFastUserSwitch",
                                      @"-doNotReconnectOnFastUserSwitch",
                                      @"-doNotFlushCache",
                                      @"-useDownRootPlugin",
                                      @"-keychainHasPrivateKey",
                                      @"-keychainHasUsernameAndPassword",
                                      @"-doNotParseConfigurationFile",
                                      @"-disableEditConfiguration",
                                      @"-disableConnectButton",
                                      @"-disableDisconnectButton",
                                      @"-doNotLoadTapKext",
                                      @"-doNotLoadTunKext",
                                      @"-loadTapKext",
                                      @"-loadTunKext",
                                      @"-credentialsGroup",
                                      
                                      @"-changeDNSServersAction",
                                      @"-changeDomainAction",
                                      @"-changeSearchDomainAction",
                                      @"-changeWINSServersAction",
                                      @"-changeNetBIOSNameAction",
                                      @"-changeWorkgroupAction",
                                      @"-changeOtherDNSServersAction",
                                      @"-changeOtherDomainAction",
                                      @"-changeOtherSearchDomainAction",
                                      @"-changeOtherWINSServersAction",
                                      @"-changeOtherNetBIOSNameAction",
                                      @"-changeOtherWorkgroupAction",
                                      @"-lastConnectionSucceeded",
                                      @"-tunnelDownSoundName",
                                      @"-tunnelUpSoundName",
                                      @"-doNotDisconnectWhenTunnelblickQuits",
                                      @"-prependDomainNameToSearchDomains",
                                      @"-doNotReconnectOnUnexpectedDisconnect", // This preference is NOT IMPLEMENTED and it is not in the .xib

                                      @"-doNotShowOnTunnelblickMenu",
                                      nil] retain];
        
        // If this is the first time we are using the new CFBundleIdentifier
        //    Rename the old preferences so we can access them with the new CFBundleIdentifier
        //    And create a link to the new preferences from the old preferences (make the link read-only)
        if (  [[[NSBundle mainBundle] bundleIdentifier] isEqualToString: @"net.tunnelblick.tunnelblick"]  ) {
            NSString * oldPreferencesPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences/com.openvpn.tunnelblick.plist"];
            NSString * newPreferencesPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences/net.tunnelblick.tunnelblick.plist"];
            if (  ! [gFileMgr fileExistsAtPath: newPreferencesPath]  ) {
                if (  [gFileMgr fileExistsAtPath: oldPreferencesPath]  ) {
                    if (  [gFileMgr tbMovePath: oldPreferencesPath toPath: newPreferencesPath handler: nil]  ) {
                        NSLog(@"Renamed existing preferences from %@ to %@", [oldPreferencesPath lastPathComponent], [newPreferencesPath lastPathComponent]);
                        if (  [gFileMgr tbCreateSymbolicLinkAtPath: oldPreferencesPath
                                                       pathContent: newPreferencesPath]  ) {
                            NSLog(@"Created a symbolic link from old preferences at %@ to %@", oldPreferencesPath, [newPreferencesPath lastPathComponent]);
                                if (  lchmod([oldPreferencesPath fileSystemRepresentation], S_IRUSR+S_IRGRP+S_IROTH) == EXIT_SUCCESS  ) {
                                    NSLog(@"Made the symbolic link read-only at %@", oldPreferencesPath);
                                } else {
                                    NSLog(@"Warning: Unable to make the symbolic link read-only at %@", oldPreferencesPath);
                                }
                        } else {
                            NSLog(@"Warning: Unable to create a symbolic link from the old preferences at %@ to the new preferences %@", oldPreferencesPath, [newPreferencesPath lastPathComponent]);
                        }
                    } else {
                        NSLog(@"Warning: Unable to rename old preferences at %@ to %@", oldPreferencesPath, [newPreferencesPath lastPathComponent]);
                    }
                }
            }
        }
            
        // Create a symbolic link to the private configurations folder, after having run the installer (which may have moved the
        // configuration folder contents to the new place)
        [self makeSymbolicLink];
        
        // Set up to override user preferences from Deploy/forced-permissions.plist if it exists,
        NSDictionary * dict = [NSDictionary dictionaryWithContentsOfFile: [gDeployPath stringByAppendingPathComponent: @"forced-preferences.plist"]];
        gTbDefaults = [[TBUserDefaults alloc] initWithForcedDictionary: dict
                                                andSecondaryDictionary: nil
                                                     usingUserDefaults: YES];
        
        if (  ! [gTbDefaults boolForKey: @"doNotShowSplashScreen"]  ) {
            splashScreen = [[SplashWindowController alloc] init];
            NSString * text = NSLocalizedString(@"Starting SurfSafeVPN...", @"Window text");
            [splashScreen setMessage: text];
            [splashScreen showWindow: self];
        }
		
        // Set default preferences as needed
        if (  [gTbDefaults objectForKey: @"showConnectedDurations"] == nil  ) {
            [gTbDefaults setBool: TRUE forKey: @"showConnectedDurations"];
        }
        
		// Scan for unknown preferences
        NSString * bundleId = [[NSBundle mainBundle] bundleIdentifier];
        NSString * prefsPath = [[[[NSHomeDirectory()
                                   stringByAppendingPathComponent:@"Library"]
                                  stringByAppendingPathComponent:@"Preferences"]
                                 stringByAppendingPathComponent: bundleId]
                                stringByAppendingPathExtension: @"plist"];
        dict = [NSDictionary dictionaryWithContentsOfFile: prefsPath];
        [gTbDefaults scanForUnknownPreferencesInDictionary: dict displayName: @"Preferences"];
        
        // Check that we can run SurfSafeVPN from this volume, that it is in /Applications, and that it is secured
        [self initialChecks];    // WE MAY NOT RETURN FROM THIS METHOD (it may install a new copy of Tunnelblick, launch it, and quit)
		
        // If gDeployPath exists and has one or more .tblk packages or .conf or .ovpn files,
        // Then make it the first entry in gConfigDirs
        BOOL isDir;
        if (   [gFileMgr fileExistsAtPath: gDeployPath isDirectory: &isDir]
            && isDir ) {
            NSString * file;
            NSDirectoryEnumerator *dirEnum = [gFileMgr enumeratorAtPath: gDeployPath];
            while (  (file = [dirEnum nextObject])  ) {
                NSString * path = [gDeployPath stringByAppendingPathComponent: file];
                if (  itemIsVisible(path)  ) {
                    NSString * ext  = [file pathExtension];
                    if (   [gFileMgr fileExistsAtPath: path isDirectory: &isDir]
                        && ( ! isDir)  ) {
                        if ( [ext isEqualToString:@"conf"] || [ext isEqualToString:@"ovpn"]  ) {
                            [gConfigDirs addObject: gDeployPath];
                            break;
                        }
                    } else {
                        if ( [ext isEqualToString:@"tblk"]  ) {
                            [gConfigDirs addObject: gDeployPath];
                            break;
                        }
                    }
                }
            }
        }
        
        // If not Deployed, or if Deployed and it is specifically allowed,
        // Then add /Library/Application Support/SurfSafeVPN/Shared
        //      and ~/Library/Application Support/SurfSafeVPN/Configurations
        //      to configDirs
        if (  [gConfigDirs count] == 0  ) {
            [gConfigDirs addObject: L_AS_T_SHARED];
            [gConfigDirs addObject: [[gPrivatePath copy] autorelease]];
        } else {
            if (  ! [gTbDefaults canChangeValueForKey: @"useSharedConfigurationsWithDeployedOnes"]  ) {
                if (  [gTbDefaults boolForKey: @"useSharedConfigurationsWithDeployedOnes"]  ) {
                    [gConfigDirs addObject: L_AS_T_SHARED];
                }
            }
            if (  ! [gTbDefaults canChangeValueForKey: @"usePrivateConfigurationsWithDeployedOnes"]  ) {
                if (  [gTbDefaults boolForKey: @"usePrivateConfigurationsWithDeployedOnes"]  ) {
                    [gConfigDirs addObject: [[gPrivatePath copy] autorelease]];
                }
            }
        }
        
		id obj;
        if (   (obj = [gTbDefaults objectForKey: @"delayToShowStatistics"])
            && [obj respondsToSelector: @selector(doubleValue)]  ) {
            gDelayToShowStatistics = [obj doubleValue];
        } else {
            gDelayToShowStatistics = 0.5;
        }
        if (   (obj = [gTbDefaults objectForKey: @"delayToHideStatistics"])
            && [obj respondsToSelector: @selector(doubleValue)]  ) {
            gDelayToHideStatistics = [obj doubleValue];
        } else {
            gDelayToHideStatistics = 1.5;
        }
        
        gRateUnits = [[NSArray arrayWithObjects:
                       NSLocalizedString(@"B/s", @"Window text"),
                       NSLocalizedString(@"KB/s", @"Window text"),
                       NSLocalizedString(@"MB/s", @"Window text"),
                       NSLocalizedString(@"GB/s", @"Window text"),
                       NSLocalizedString(@"TB/s", @"Window text"),
                       NSLocalizedString(@"PB/s", @"Window text"),
                       NSLocalizedString(@"EB/s", @"Window text"),
                       NSLocalizedString(@"ZB/s", @"Window text"),
                       @"***",
                       nil] retain];
        
        gTotalUnits = [[NSArray arrayWithObjects:
                        NSLocalizedString(@"B", @"Window text"),
                        NSLocalizedString(@"KB", @"Window text"),
                        NSLocalizedString(@"MB", @"Window text"),
                        NSLocalizedString(@"GB", @"Window text"),
                        NSLocalizedString(@"TB", @"Window text"),
                        NSLocalizedString(@"PB", @"Window text"),
                        NSLocalizedString(@"EB", @"Window text"),
                        NSLocalizedString(@"ZB", @"Window text"),
                        @"***",
                        nil] retain];
        
        connectionArray = [[NSArray alloc] init];
        
        if (  ! [self loadMenuIconSet]  ) {
            NSLog(@"Unable to load the Menu icon set");
            [self terminateBecause: terminatingBecauseOfError];
        }
        
		[self createStatusItem];
		
        myConfigDictionary = [[[ConfigurationManager defaultManager] getConfigurations] copy];
        
        // set up myVPNConnectionDictionary, which has the same keys as myConfigDictionary, but VPNConnections as objects
        NSMutableDictionary * tempVPNConnectionDictionary = [[NSMutableDictionary alloc] init];
        NSString * dispNm;
        NSEnumerator * e = [myConfigDictionary keyEnumerator];
        NSDictionary * hosts = [ssUpdater hosts];
        
        while (  (dispNm = [e nextObject])  ) {
            NSString * cfgPath = [[self myConfigDictionary] objectForKey: dispNm];
            // configure connection object:
            VPNConnection* myConnection = [[VPNConnection alloc] initWithConfigPath: cfgPath
                                                                    withDisplayName: dispNm];
            
            NSString * proxyString = [[hosts objectForKey:dispNm] objectAtIndex:3];
          
            NSArray * arr = [proxyString componentsSeparatedByString:@":"];
            
            Proxy* proxy = [[Proxy alloc]initWithHost: [arr objectAtIndex:0] 
                                                 port: [arr objectAtIndex:1] 
                                              enabled:@"Yes"];
            
            [myConnection setProxy: proxy];
            [myConnection setDelegate:self];
            [tempVPNConnectionDictionary setObject: myConnection forKey: dispNm];
        }
        [self setMyVPNConnectionDictionary: [[tempVPNConnectionDictionary copy] autorelease]];
        [tempVPNConnectionDictionary release];
        
		[self createMenu];
        
        // logScreen is a MyPrefsWindowController, but the sharedPrefsWindowController is a DBPrefsWindowController
        logScreen = (id) [MyPrefsWindowController sharedPrefsWindowController];
        
        [self setState: @"EXITING"]; // synonym for "Disconnected"
        
        [[NSNotificationCenter defaultCenter] addObserver: self 
                                                 selector: @selector(TunnelblickShutdownUIHandler:) 
                                                     name: @"TunnelblickUIShutdownNotification" 
                                                   object: nil];
        
        [[NSNotificationCenter defaultCenter] addObserver: logScreen 
                                                 selector: @selector(logNeedsScrollingHandler:) 
                                                     name: @"LogDidChange" 
                                                   object: nil];
		
		
        // In case the systemUIServer restarts, we observed this notification.
		// We use it to prevent ending up with a statusItem to the right of Spotlight:
		[[NSDistributedNotificationCenter defaultCenter] addObserver: self 
															selector: @selector(menuExtrasWereAddedHandler:) 
																name: @"com.apple.menuextra.added" 
															  object: nil];
        
        // These notifications are seen when the user is logging out or the system is being shut down or restarted.
        //
        // They are seen *before* getting the workspace's NSWorkspaceWillPowerOffNotification and used to track
        // whether this is a logout, or a shutdown or restart, and set 'reasonForTermination' if appropriate.
        //
        // When a logout is requested: com.apple.logoutInitiated
        //                  confirmed: com.apple.logoutContinued
        //                  cancelled: com.apple.logoutCancelled
        //
        // When a restart is requested: com.apple.restartInitiated
        //                   confirmed: com.apple.logoutContinued
        //                   cancelled: com.apple.logoutCancelled
        //
        // When a shutdown is requested: com.apple.shutdownInitiated
        //                    confirmed: com.apple.logoutContinued
        //                    cancelled: com.apple.logoutCancelled
        
		[[NSDistributedNotificationCenter defaultCenter] addObserver: self 
															selector: @selector(restartInitiatedHandler:) 
																name: @"com.apple.restartInitiated" 
															  object: nil];
        
		[[NSDistributedNotificationCenter defaultCenter] addObserver: self 
															selector: @selector(logoutInitiatedHandler:) 
																name: @"com.apple.logoutInitiated" 
															  object: nil];
        
		[[NSDistributedNotificationCenter defaultCenter] addObserver: self 
															selector: @selector(shutdownInitiatedHandler:) 
																name: @"com.apple.shutdownInitiated" 
															  object: nil];
        
        [[NSDistributedNotificationCenter defaultCenter] addObserver: self 
															selector: @selector(logoutCancelledHandler:) 
																name: @"com.apple.logoutCancelled" 
															  object: nil];
        
		[[NSDistributedNotificationCenter defaultCenter] addObserver: self 
															selector: @selector(logoutContinuedHandler:) 
																name: @"com.apple.logoutContinued" 
															  object: nil];
        
        
		[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self
															   selector: @selector(willGoToSleepHandler:)
																   name: NSWorkspaceWillSleepNotification
																 object:nil];
		
		[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self
															   selector: @selector(willLogoutOrShutdownHandler:)
																   name: NSWorkspaceWillPowerOffNotification
																 object:nil];
		
		[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self
															   selector: @selector(wokeUpFromSleepHandler:)
																   name: NSWorkspaceDidWakeNotification
																 object:nil];
		
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self
                                                               selector: @selector(didBecomeActiveUserHandler:)
                                                                   name: NSWorkspaceSessionDidBecomeActiveNotification
                                                                 object: nil];
        
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self
                                                               selector: @selector(didBecomeInactiveUserHandler:)
                                                                   name: NSWorkspaceSessionDidResignActiveNotification
                                                                 object: nil];
        
        if (  [gTbDefaults boolForKey: @"notificationsLog"] ) {
            
            NSLog(@"Observing all notifications");
            
            [[NSDistributedNotificationCenter defaultCenter] addObserver: self 
                                                                selector: @selector(allDistributedNotificationsHandler:) 
                                                                    name: nil 
                                                                  object: nil];
            
            [[NSNotificationCenter defaultCenter] addObserver: self 
                                                     selector: @selector(allNotificationsHandler:) 
                                                         name: nil 
                                                       object: nil];        
            
            [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self 
                                                                   selector: @selector(allWorkspaceNotificationsHandler:) 
                                                                       name: nil 
                                                                     object: nil];
        }
        
        ignoreNoConfigs = TRUE;    // We ignore the "no configurations" situation until we've processed application:openFiles:
		
        //updater = [[SUUpdater alloc] init];
        //myConfigUpdater = [[ConfigurationUpdater alloc] init]; // Set up a separate Sparkle Updater for configurations   

    }
    
    return self;
}

-(void)allNotificationsHandler: (NSNotification *) n
{
    NSString * name = [n name];
    NSLog(@"NOTIFICATION              : %@", name);
    if (  [name isEqualToString: [gTbDefaults objectForKey: @"notificationsVerbose"]]  ) {
        NSLog(@"NOTIFICATION              : %@; object = %@; userInfo = %@", [n name], [n object], [n userInfo]);
    }
}

-(void)allDistributedNotificationsHandler: (NSNotification *) n
{
    NSString * name = [n name];
    NSLog(@"NOTIFICATION (Distributed): %@", name);
    if (  [name isEqualToString: [gTbDefaults objectForKey: @"notificationsVerbose"]]  ) {
        NSLog(@"NOTIFICATION (Distributed): %@; object = %@; userInfo = %@", [n name], [n object], [n userInfo]);
    }
}

-(void)allWorkspaceNotificationsHandler: (NSNotification *) n
{
    NSString * name = [n name];
    NSLog(@"NOTIFICATION   (Workspace): %@", name);
    if (  [name isEqualToString: [gTbDefaults objectForKey: @"notificationsVerbose"]]  ) {
        NSLog(@"NOTIFICATION   (Workspace): %@; object = %@; userInfo = %@", [n name], [n object], [n userInfo]);
    }
}

// Attempts to make a symbolic link from the old configurations folder to the new configurations folder
- (void) makeSymbolicLink
{
    BOOL isDir;
    NSString * oldConfigDirPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/openvpn"];
    NSDictionary * fileAttributes = [gFileMgr tbFileAttributesAtPath: oldConfigDirPath traverseLink: NO];
    if (  [[fileAttributes objectForKey: NSFileType] isEqualToString: NSFileTypeSymbolicLink]  ) {
        // A symbolic link exists
        if (  ! [[gFileMgr tbPathContentOfSymbolicLinkAtPath: oldConfigDirPath] isEqualToString: gPrivatePath]  ) {
            NSLog(@"Warning: %@ exists and is a symbolic link but does not reference %@. Attempting repair...", oldConfigDirPath, gPrivatePath);
            if (  ! [gFileMgr tbRemoveFileAtPath:oldConfigDirPath handler: nil]  ) {
                NSLog(@"Warning: Unable to remove %@", oldConfigDirPath);
            }
            if (  ! [gFileMgr tbCreateSymbolicLinkAtPath: oldConfigDirPath
                                           pathContent: gPrivatePath]  ) {
                NSLog(@"Warning: Unable to change symbolic link %@ to point to %@", oldConfigDirPath, gPrivatePath);
            }
        }
        
    } else {
        // Not a symbolic link
        if (  [gFileMgr fileExistsAtPath: oldConfigDirPath isDirectory: &isDir]  ) {
            if (  isDir  ) {
                // If empty (i.e., only has invisible files), delete it and create the symlink
                BOOL isEmpty = TRUE;
                NSDirectoryEnumerator *dirEnum = [gFileMgr enumeratorAtPath: oldConfigDirPath];
                NSString * file;
                while (  (file = [dirEnum nextObject])  ) {
                    if (  itemIsVisible([oldConfigDirPath stringByAppendingPathComponent: file])  ) {
                        isEmpty = FALSE;
                        break;
                    }
                }
                if (  isEmpty  ) {
                    if (  [gFileMgr tbRemoveFileAtPath:oldConfigDirPath handler: nil]  ) {
                        if (  [gFileMgr tbCreateSymbolicLinkAtPath: oldConfigDirPath
                                                     pathContent: gPrivatePath]  ) {
                            NSLog(@"Replaceed %@ with a symbolic link to %@", oldConfigDirPath, gPrivatePath);
                        } else {
                            NSLog(@"Warning: Unable to create a symbolic link to %@ at %@", gPrivatePath, oldConfigDirPath);
                        }
                    } else {
                        NSLog(@"Warning: unable to remove %@ folder to replace it with a symbolic link", oldConfigDirPath);
                    }
                } else {
                    NSLog(@"Warning: %@ is a folder which is not empty.", oldConfigDirPath);
                }
            } else {
                NSLog(@"Warning: %@ exists but is not a symbolic link or a folder.", oldConfigDirPath);
            }
        } else {
            if (  [gFileMgr tbCreateSymbolicLinkAtPath: oldConfigDirPath
                                         pathContent: gPrivatePath]  ) {
                NSLog(@"Created a symbolic link to %@ at %@", gPrivatePath, oldConfigDirPath);
            } else {
                NSLog(@"Warning: Unable to create a symbolic link to %@ at %@", gPrivatePath, oldConfigDirPath);
            }
        }
    }
}    

- (void) dealloc
{
    [showDurationsTimer release];
    [animImages release];
    [connectedImage release];
    [mainImage release];
    
    [gConfigDirs release];
    
    [gTbDefaults release];
    [connectionArray release];
    [connectionsToRestoreOnWakeup release];
    [connectionsToRestoreOnUserActive release];
    [dotTblkFileList release];
    [lastState release];
    [gPrivatePath release];
    [myConfigDictionary release];
    [myVPNConnectionDictionary release];
    [myVPNMenu release];
    [hookupWatchdogTimer invalidate];
    [hookupWatchdogTimer release];
    [theAnim release];
    //[updater release];
    
    //HTK-INC
    [ssUpdater release];

    //[myConfigUpdater release];
    [customMenuScripts release];
    [customRunOnLaunchPath release];
    [customRunOnConnectPath release];
    
    [aboutItem release];
    [checkForUpdatesNowItem release];
    //[vpnDetailsItem release];
    // HTK-INC
    [clearKeychainItem release];
    [photoShieldItem release];
    // End HTK-INC
    [quitItem release];
    [statusMenuItem release];
    [statusItem release];
    [logScreen release];
    
#ifdef INCLUDE_VPNSERVICE
    [vpnService release];
    [registerForTunnelblickItem release];
#endif
    
    [super dealloc];
}

-(BOOL) userIsAnAdmin
{
    return userIsAnAdmin;
}

// Places an item with our icon in the Status Bar (creating it first if it doesn't already exist)
// By default, it uses an undocumented hack to place the icon on the right side, next to SpotLight
// Otherwise ("placeIconInStandardPositionInStatusBar" preference or hack not available), it places it normally (on the left)
- (void) createStatusItem
{
    [statusItem release];
    statusItem = nil;
    
	NSStatusBar *bar = [NSStatusBar systemStatusBar];
    
	if (   [bar respondsToSelector: @selector(_statusItemWithLength:withPriority:)]
        && [bar respondsToSelector: @selector(_insertStatusItem:withPriority:)]
        && (  ! [gTbDefaults boolForKey:@"placeIconInStandardPositionInStatusBar"]  )
        ) {
        // Force icon to the right in Status Bar
        int priority = INT32_MAX;
        if (  runningOnTigerOrNewer()  ) {
            priority = MIN(priority, 2147483646); // found by experimenting - dirk
        }
        
        if ( ! statusItem  ) {
            if (  ! ( statusItem = [[bar _statusItemWithLength: NSVariableStatusItemLength withPriority: priority] retain] )  ) {
                NSLog(@"Can't insert icon in Status Bar");
            }
        }
        // Re-insert item to place it correctly, to the left of SpotLight
        [bar removeStatusItem: statusItem];
        [bar _insertStatusItem: statusItem withPriority: priority];
    } else {
        // Standard placement of icon in Status Bar
        if (  statusItem  ) {
            [bar removeStatusItem: statusItem];
            [statusItem release];
            if (  (statusItem = [[bar statusItemWithLength: NSVariableStatusItemLength] retain])  ) {
            } else {
                NSLog(@"Can't insert icon in Status Bar");
            }
        } else {
            if (  ! (statusItem = [[bar statusItemWithLength: NSVariableStatusItemLength] retain])  ) {
                NSLog(@"Can't insert icon in Status Bar");
            }
        }
    }
}

- (void) menuExtrasWereAddedHandler: (NSNotification*) n
{
	(void) n;
	
    NSLog(@"DEBUG: menuExtrasWereAddedHandler: invoked");
    if (  gShuttingDownWorkspace  ) {
        return;
}

	[self performSelectorOnMainThread: @selector(menuExtrasWereAdded) withObject: nil waitUntilDone: NO];
}

- (void) menuExtrasWereAdded
{
    [self createStatusItem];
    [self createMenu];
    [self updateUI];
}

- (IBAction) quit: (id) sender
{
	(void) sender;
	
    terminatingAtUserRequest = TRUE;
    [self terminateBecause: terminatingBecauseOfQuit];
}

-(BOOL) terminatingAtUserRequest
{
    return terminatingAtUserRequest;
}

- (void) awakeFromNib
{
	[self initialiseAnim];
}

-(BOOL) loadMenuIconSet
{
    // Try with the specified icon set
    NSString * requestedMenuIconSet = [gTbDefaults objectForKey:@"menuIconSet"];
    if (  requestedMenuIconSet   ) {
        if (   [self loadMenuIconSet: requestedMenuIconSet
                                main: &mainImage
                          connecting: &connectedImage
                                anim: &animImages]
            && [self loadMenuIconSet: [NSString stringWithFormat: @"large-%@", requestedMenuIconSet]
                                main: &largeMainImage
                          connecting: &largeConnectedImage
                                anim: &largeAnimImages]  )
        {    
            [self updateUI];    // Display the new images
            return YES;
        } else {
            NSLog(@"Icon set '%@' not found", requestedMenuIconSet);
        }
    }
        
    // Try with standard icon set if haven't already
    NSString * menuIconSet = @"SurfSafe.TBMenuIcons";
    if (  ! [requestedMenuIconSet isEqualToString: menuIconSet]  ) {
        if (   [self loadMenuIconSet: menuIconSet
                                main: &mainImage
                          connecting: &connectedImage
                                anim: &animImages]
            && [self loadMenuIconSet: [NSString stringWithFormat: @"large-%@", menuIconSet]
                                main: &largeMainImage
                          connecting: &largeConnectedImage
                                anim: &largeAnimImages]  )
        {
            if (  requestedMenuIconSet  ) {
                NSLog(@"Using icon set %@", menuIconSet);
            }
            [self updateUI];    // Display the new images
            return YES;
        } else {
            NSLog(@"Icon set '%@' not found", menuIconSet);
        }
    }
        
    // Try with monochrome icon set
    menuIconSet = @"SurfSafe.TBMenuIcons";
    if (   [self loadMenuIconSet: menuIconSet
                            main: &mainImage
                      connecting: &connectedImage
                            anim: &animImages]
        && [self loadMenuIconSet: [NSString stringWithFormat: @"large-%@", menuIconSet]
                            main: &largeMainImage
                      connecting: &largeConnectedImage
                            anim: &largeAnimImages]  )
    {
        NSLog(@"Using icon set %@", menuIconSet);
        [self updateUI];    // Display the new images
        return YES;
    }
    
    return NO;
}
    
-(BOOL) loadMenuIconSet: (NSString *)        iconSetName
                   main: (NSImage **)        ptrMainImage
             connecting: (NSImage **)        ptrConnectedImage
                   anim: (NSMutableArray **) ptrAnimImages
{
    // Search for the folder with the animated icon set in (1) Deploy and (2) Shared, before falling back on the copy in the app's Resources
    BOOL isDir;
    NSString * iconSetDir = [[gDeployPath stringByAppendingPathComponent: @"IconSets"] stringByAppendingPathComponent: iconSetName];
    if (  ! (   [gFileMgr fileExistsAtPath: iconSetDir isDirectory: &isDir]
             && isDir )  ) {
        iconSetDir = [[L_AS_T_SHARED stringByAppendingPathComponent: @"IconSets"] stringByAppendingPathComponent: iconSetName];
        if (  ! (   [gConfigDirs containsObject: L_AS_T_SHARED]
                 && [gFileMgr fileExistsAtPath: iconSetDir isDirectory: &isDir]
                 && isDir )  ) {
            iconSetDir = [[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent: @"IconSets"] stringByAppendingPathComponent: iconSetName];
            if (  ! (   [gFileMgr fileExistsAtPath: iconSetDir isDirectory: &isDir]
                     && isDir )  ) {
                // Can't find the specified icon set
                return FALSE;
            }
        }
    }
    
    unsigned nFrames = 0;
    NSString *file;
    NSString *fullPath;
    NSDirectoryEnumerator *dirEnum = [gFileMgr enumeratorAtPath: iconSetDir];
    NSArray *allObjects = [dirEnum allObjects];
    
    [*ptrAnimImages release];
    *ptrAnimImages = [[NSMutableArray alloc] init];
    
    unsigned i=0;
    for(i=0;i<[allObjects count];i++) {
        file = [allObjects objectAtIndex:i];
        fullPath = [iconSetDir stringByAppendingPathComponent:file];
        
        if (  itemIsVisible(fullPath)  ) {
            if ([[file pathExtension] isEqualToString: @"png"]) {
                NSString *name = [[file lastPathComponent] stringByDeletingPathExtension];
                
                if (  [name isEqualToString:@"closed"]) {
                    [*ptrMainImage release];
                    *ptrMainImage = [[NSImage alloc] initWithContentsOfFile:fullPath];
                    
                } else if(  [name isEqualToString:@"open"]) {
                    [*ptrConnectedImage release];
                    *ptrConnectedImage = [[NSImage alloc] initWithContentsOfFile:fullPath];
                    
                } else {
                    if(  [[file lastPathComponent] isEqualToString:@"0.png"]) {  //[name intValue] returns 0 on failure, so make sure we find the first frame
                        nFrames++;
                    } else if(  [name intValue] > 0) {
                        nFrames++;
                    }
                }
            }
        }
    }
    
    // don't choke on a bad set of files, e.g., {0.png, 1abc.png, 2abc.png, 3.png, 4.png, 6.png}
    // (won't necessarily find all files, but won't try to load files that don't exist)
    for(i=0;i<nFrames;i++) {
        fullPath = [iconSetDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%d.png", i]];
        if (  itemIsVisible(fullPath)  ) {
            if ([gFileMgr fileExistsAtPath:fullPath]) {
                NSImage *frame = [[NSImage alloc] initWithContentsOfFile:fullPath];
                [*ptrAnimImages addObject:frame];
                [frame release];
            }
        }
    }
    
    if (   (*ptrMainImage == nil)
        || (*ptrConnectedImage == nil)
        || ([*ptrAnimImages count] == 0)  ) {
        NSLog(@"Icon set '%@' does not have required images", iconSetName);
        return FALSE;
    }
    
    return TRUE;
}

- (void) initialiseAnim
{
    if (  gShuttingDownWorkspace  ) {
        [theAnim stopAnimation];
        return;
    }
    
    if (  theAnim == nil  ) {
        unsigned i;
        // theAnim is an NSAnimation instance variable
        theAnim = [[NSAnimation alloc] initWithDuration:2.0
                                         animationCurve:NSAnimationLinear];
        [theAnim setFrameRate:7.0];
        [theAnim setDelegate:self];
        
        for (i=1; i<=[animImages count]; i++)
        {
            NSAnimationProgress p = ((float)i)/((float)[animImages count]);
            [theAnim addProgressMark:p];
        }
        [theAnim setAnimationBlockingMode:  NSAnimationNonblocking];
    }
}

// Lock this to change myVPNMenu
static pthread_mutex_t myVPNMenuMutex = PTHREAD_MUTEX_INITIALIZER;

-(void) createMenu 
{
    OSStatus status = pthread_mutex_lock( &myVPNMenuMutex );
    if (  status != EXIT_SUCCESS  ) {
        NSLog(@"pthread_mutex_lock( &myVPNMenuMutex ) failed; status = %ld, errno = %ld", (long) status, (long) errno);
        return;
    }
    
    [noConfigurationsItem release];
    noConfigurationsItem = [[NSMenuItem alloc] init];
    [noConfigurationsItem setTitle: NSLocalizedString(@"No VPN Configurations Available", @"Menu item")];
    
#ifdef INCLUDE_VPNSERVICE
    [registerForTunnelblickItem release];
    registerForTunnelblickItem = [[NSMenuItem alloc] init];
    [registerForTunnelblickItem setTitle: NSLocalizedString(@"Register for SurfSafeVPN...", @"Menu item VPNService")];
    [registerForTunnelblickItem setTarget: self];
    [registerForTunnelblickItem setAction: @selector(registerForTunnelblickWasClicked:)];
#endif
    
    if (  ! [gTbDefaults boolForKey:@"doNotShowAddConfigurationMenuItem"]  ) {
        [addConfigurationItem release];
        addConfigurationItem = [[NSMenuItem alloc] init];
        [addConfigurationItem setTitle: NSLocalizedString(@"Add a VPN...", @"Menu item")];
        [addConfigurationItem setTarget: self];
        [addConfigurationItem setAction: @selector(addConfigurationWasClicked:)];
    }
    
    //[vpnDetailsItem release];
    //vpnDetailsItem = [[NSMenuItem alloc] init];
    //[vpnDetailsItem setTitle: NSLocalizedString(@"VPN Details...", @"Menu item")];
    //[vpnDetailsItem setTarget: self];
    //[vpnDetailsItem setAction: @selector(openPreferencesWindow:)];
    
    [contactTunnelblickItem release];
    contactTunnelblickItem = nil;
    if ( ! [gTbDefaults boolForKey: @"doNotShowSuggestionOrBugReportMenuItem"]  ) {
        if (  [self contactURL]  ) {
            NSString * menuTitle = nil;
            NSDictionary * infoPlist = [[NSBundle mainBundle] infoDictionary];
            if (  [[infoPlist objectForKey: @"CFBundleShortVersionString"] rangeOfString: @"beta"].length != 0  ) {
                if (  [NSLocalizedString(@"SurfSafeVPN", "Window title") isEqualToString: @"Surf" "SafeVPN"]  ) {
                    if (  [@"SurfSafeVPN" isEqualToString: @"Surf" "SafeVPN"]  ) {
                        menuTitle = NSLocalizedString(@"Suggestion or Bug Report...", @"Menu item");
                    }
                }
            }
            if (  menuTitle  ) {
                contactTunnelblickItem = [[NSMenuItem alloc] init];
                [contactTunnelblickItem setTitle: menuTitle];
                [contactTunnelblickItem setTarget: self];
                [contactTunnelblickItem setAction: @selector(contactTunnelblickWasClicked:)];
            }
        }
    }
    
    [quitItem release];
    quitItem = [[NSMenuItem alloc] init];
    [quitItem setTitle: NSLocalizedString(@"Quit SurfSafeVPN", @"Menu item")];
    [quitItem setTarget: self];
    [quitItem setAction: @selector(quit:)];
    
    [statusMenuItem release];
	statusMenuItem = [[NSMenuItem alloc] init];
    [statusMenuItem setTarget: self];
    [statusMenuItem setAction: @selector(disconnectAllMenuItemWasClicked:)];
    
    // HTK-INC
    [clearKeychainItem release];
    clearKeychainItem = [[NSMenuItem alloc] init];
    [clearKeychainItem setTitle: NSLocalizedString(@"Clear saved VPN ID/Activation code", @"Menu item")];
    [clearKeychainItem setTarget:self];
    [clearKeychainItem setAction:@selector(clearKeychain:)];
        
    [photoShieldItem release];
    photoShieldItem = [[NSMenuItem alloc] init];
    [photoShieldItem setTitle: NSLocalizedString(@"Enable PhotoShield", @"Menu item")];
    [photoShieldItem setTarget:self];
    [photoShieldItem setAction:@selector(turnOnOffPhotoShield:)];   
    if(IsEnabledProxy())
        [photoShieldItem setState: NSOnState];
    else
        [photoShieldItem setState: NSOffState];
    // End HTK-INC

    [myVPNMenu release];
	myVPNMenu = [[NSMenu alloc] init];
    [myVPNMenu setDelegate:self];

    [self setOurMainIconView: [[[MainIconView alloc] initWithFrame: NSMakeRect(0.0, 0.0, 20.0, 23.0)] autorelease]];
    [statusItem setView: [self ourMainIconView]];
    
	[myVPNMenu addItem:statusMenuItem];
	
    [myVPNMenu addItem:[NSMenuItem separatorItem]];
    
    // Add each connection to the menu
    NSString * dispNm;
    NSArray *keyArray = [[[self myConfigDictionary] allKeys]
						 sortedArrayUsingSelector: @selector(caseInsensitiveNumericCompare:)];
	NSEnumerator * e = [keyArray objectEnumerator];

    //HTK-INC1
    NSDictionary * hosts = [ssUpdater hosts];
    BOOL isProxyEnabled = IsEnabledProxy();
    while (  (dispNm = [e nextObject])  ) {
        if (  ! [gTbDefaults boolForKey: [dispNm stringByAppendingString: @"-doNotShowOnTunnelblickMenu"]]  ) {
            // configure connection object:
            NSMenuItem *connectionItem = [[[NSMenuItem alloc] init] autorelease];
            VPNConnection* myConnection = [[self myVPNConnectionDictionary] objectForKey: dispNm];
            
            // Note: The menu item's title will be set on demand in VPNConnection's validateMenuItem
            [connectionItem setTarget:myConnection]; 
            [connectionItem setAction:@selector(toggle:)];
            
            BOOL isPhotoShieldEnabled = [[[hosts objectForKey:dispNm] objectAtIndex:4] isEqualToString:@"True"];
            if ((isProxyEnabled && isPhotoShieldEnabled) || (!isProxyEnabled && !isPhotoShieldEnabled)) {
                [self insertConnectionMenuItem: connectionItem IntoMenu: myVPNMenu afterIndex: 2 withName: dispNm];
            }
        }
    }
    //END HTK-INC1
    
    
    
    
    
    if (  [[self myConfigDictionary] count] == 0  ) {
        [myVPNMenu addItem: noConfigurationsItem];
        if (  ! [gTbDefaults boolForKey:@"doNotShowAddConfigurationMenuItem"]  ) {
            [myVPNMenu addItem: addConfigurationItem];
        }
    }
    
    [myVPNMenu addItem: [NSMenuItem separatorItem]];
    
#ifdef INCLUDE_VPNSERVICE
    if (  registerForTunnelblickItem  ) {
        [myVPNMenu addItem: registerForTunnelblickItem];
        [myVPNMenu addItem: [NSMenuItem separatorItem]];
    }
#endif

    [self addCustomMenuItems];

    if (  contactTunnelblickItem  ) {
        [myVPNMenu addItem: contactTunnelblickItem];
        [myVPNMenu addItem: [NSMenuItem separatorItem]];
    }
    
    if (  ! [gTbDefaults boolForKey:@"doNotShowVpnDetailsMenuItem"]  ) {
        //[myVPNMenu addItem: vpnDetailsItem];
        //[myVPNMenu addItem: [NSMenuItem separatorItem]];
	}
    
    [myVPNMenu addItem: photoShieldItem];    
    [myVPNMenu addItem: clearKeychainItem];
    [myVPNMenu addItem: [NSMenuItem separatorItem]];
    [myVPNMenu addItem: quitItem];    
    
    status = pthread_mutex_unlock( &myVPNMenuMutex );
    if (  status != EXIT_SUCCESS  ) {
        NSLog(@"pthread_mutex_unlock( &myVPNMenuMutex ) failed; status = %ld, errno = %ld", (long) status, (long) errno);
    }
}

// LOCK configModifyMutex BEFORE INVOKING THIS METHOD
-(void) insertConnectionMenuItem: (NSMenuItem *) theItem IntoMenu: (NSMenu *) theMenu afterIndex: (int) theIndex withName: (NSString *) theName
{
    int i;
    NSRange    slashRange = [theName rangeOfString: @"/" options: 0 range: NSMakeRange(0, [theName length] - 1)];
    if (   (slashRange.length == 0)
        || [gTbDefaults boolForKey: @"doNotShowConnectionSubmenus"]  ) {
        // The item goes directly in the menu
        for (  i=theIndex; i < [theMenu numberOfItems]; i++  ) {
            id menuItem = [theMenu itemAtIndex: i];
            NSString * menuItemTitle;
            if (  [menuItem isSeparatorItem]  ) {
                break;                       // A separator marks the end of list of connection items
            }
            if (   [menuItem submenu]  ) {    // item is a submenu
                menuItemTitle = [menuItem title];
            } else if (  [[menuItem title] isEqualToString: NSLocalizedString(@"Add a VPN...", @"Menu item")]  ) {
                break;
            } else {                                                            // item is a connection item
                menuItemTitle = [[menuItem target] displayName];
            }
            
			menuItemTitle = [menuItemTitle lastPathComponent];
            if (  [menuItemTitle compare: theName options: NSCaseInsensitiveSearch | NSNumericSearch] == NSOrderedDescending  ) {
                break;
            }
        }
        [theMenu insertItem: theItem atIndex: i];
        return;
    }
    
    // The item goes on a submenu
    NSString * subMenuName = [theName substringWithRange: NSMakeRange(0, slashRange.location + 1)];
    NSString * restOfName = [theName substringFromIndex: slashRange.location + 1];
    for (  i=theIndex; i < [theMenu numberOfItems]; i++  ) {
        id menuItem = [theMenu itemAtIndex: i];
        if (  [menuItem isSeparatorItem]  ) {
            break; // A separator marks the end of list of connection items
        } else {
            NSMenu * subMenu = [menuItem submenu];
            if (  subMenu   ) {
                // Item is a submenu
                NSString * menuItemTitle = [menuItem title];
                NSComparisonResult  result = [menuItemTitle compare: subMenuName options: NSCaseInsensitiveSearch | NSNumericSearch];
                if (  result == NSOrderedSame  ) {
                    // Have found correct submenu, so add this item to it
					int nItemsInMenu = [subMenu numberOfItems] - 1;
					if (  nItemsInMenu < 0  ) {
						nItemsInMenu = 0;
					}
                    [self insertConnectionMenuItem: theItem IntoMenu: subMenu afterIndex: nItemsInMenu withName: restOfName];
                    return;
                }
                if (  result == NSOrderedDescending  ) {
                    // Have found a different submenu that comes later
                    break;
                }
            }
        }
    }
    
    // Didn't find the submenu, so we have to create a new submenu and try again.
    
    // Create the new submenu
    NSMenu * newSubmenu = [[[NSMenu alloc] initWithTitle:@"A Configuration SubMenu Title"] autorelease];
    
    // Create a new submenu item for the outer menu
    NSMenuItem * newMenuItem = [[[NSMenuItem alloc] init] autorelease];
    [newMenuItem setTitle: subMenuName];
    [newMenuItem setSubmenu: newSubmenu];
    
    // Add the new submenu item to the outer menu
    [self insertConnectionMenuItem: newMenuItem IntoMenu: theMenu afterIndex: theIndex withName: subMenuName];
    
    // Insert the original item we wanted to (now that the submenu has been created)
    [self insertConnectionMenuItem: theItem IntoMenu: theMenu afterIndex: theIndex withName: theName];
}

-(void) addCustomMenuItems
{
    // Reset custom script variables
    customMenuScriptIndex = 0;
    [customMenuScripts release];
    customMenuScripts = [[NSMutableArray alloc] init];
    
    // Process the contents of the Menu folder
    NSString * menuDirPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent: @"/Deploy/Menu"];
    if (  [self addCustomMenuItemsFromFolder: menuDirPath toMenu: myVPNMenu]  ) {
        [myVPNMenu addItem: [NSMenuItem separatorItem]];
    }
}

// Note: this method is indirectly recursive because it invokes addOneCustomMenuSubmenu, which may invoke this method
-(BOOL) addCustomMenuItemsFromFolder: (NSString *) folderPath toMenu: (NSMenu *) theMenu
{
    // List the items in the folder
    NSMutableArray * itemsInMenuFolder = [[[NSMutableArray alloc] init] autorelease];
    NSString * file;
    NSDirectoryEnumerator * dirEnum = [gFileMgr enumeratorAtPath: folderPath];
    while (  (file = [dirEnum nextObject])  ) {
        [dirEnum skipDescendents];
        [itemsInMenuFolder addObject: file];
    }
    
    // Sort the list
	NSArray *sortedArray = [itemsInMenuFolder sortedArrayUsingSelector: @selector(caseInsensitiveNumericCompare:)];

    // Use the sorted list to add items to the Tunnelblick menu, or to run them on launch or on connect
    BOOL haveAddedItems = FALSE;
    BOOL isDir;
    
    unsigned i;
    for (i=0; i<[sortedArray count]; i++) {
        file = [sortedArray objectAtIndex: i];
        NSString * fullPath = [folderPath stringByAppendingPathComponent: file];
        if (  itemIsVisible(fullPath)  ) {
            if (   [gFileMgr fileExistsAtPath: fullPath isDirectory: &isDir]  ) {
                if (  isDir  ) {
                    haveAddedItems = [self addOneCustomMenuSubmenu: file fromFolder: folderPath toMenu: theMenu] || haveAddedItems;
                } else if (  [[file pathExtension] isEqualToString: @"executable"]  ) {
                    NSString * name = [file stringByDeletingPathExtension];
                    if (  [[name pathExtension] isEqualToString: @"wait"]  ) {
                        name = [name stringByDeletingPathExtension];
                    }
                    NSString * extension = [name pathExtension];
                    if (  [extension isEqualToString: @"runOnLaunch"]  ) {
                        if (  customRunOnLaunchPath  ) {
                            NSLog(@"%@ is being ignored; %@ is already set up to be run on launch", fullPath, customRunOnLaunchPath);
                        } else {
                            customRunOnLaunchPath = [fullPath copy];
                        }
                    } else if (  [extension isEqualToString: @"runOnConnect"]  ) {
                        if (  customRunOnConnectPath  ) {
                            NSLog(@"%@ is being ignored; %@ is already set up to be run on connect", fullPath, customRunOnConnectPath);
                        } else {
                            customRunOnConnectPath = [fullPath copy];
                        }
                    } else if (  [extension isEqualToString: @"addToMenu"]  ) {
                        [self addOneCustomMenuItem: file fromFolder: folderPath toMenu: theMenu];
                        haveAddedItems = TRUE;
                    }
                }
            }
        }
    }
    
    return haveAddedItems;
}

-(BOOL) addOneCustomMenuSubmenu: (NSString *) file fromFolder: (NSString *) folder toMenu: (NSMenu *) theMenu
{
    NSMenu * subMenu = [[[NSMenu alloc] init] autorelease];
    if (  [self addCustomMenuItemsFromFolder: [folder stringByAppendingPathComponent: file] toMenu: subMenu]  ) {
        NSMenuItem * subMenuItem = [[[NSMenuItem alloc] init] autorelease];
        [subMenuItem setTitle: localizeNonLiteral([self menuNameFromFilename: file], @"Menu item")];
        [subMenuItem setSubmenu: subMenu];
        [theMenu addItem: subMenuItem];
        return TRUE;
    }
    
    return FALSE;
}

-(void) addOneCustomMenuItem: (NSString *) file fromFolder: (NSString *) folder toMenu: (NSMenu *) theMenu
{
    NSMenuItem * item = [[[NSMenuItem alloc] init] autorelease];
    [item setTitle: localizeNonLiteral([self menuNameFromFilename: file], @"Menu item")];
    [item setTarget: self];
    [item setAction: @selector(runCustomMenuItem:)];
    [item setTag: customMenuScriptIndex++];

    NSString * scriptPath = [folder stringByAppendingPathComponent: file];
    [customMenuScripts addObject: scriptPath];
    
    [theMenu addItem: item];
}

// Strips off .addToMenu, .wait, and .executable from the end of a string, and everything up to and including the first underscore
-(NSString *) menuNameFromFilename: (NSString *) inString
{
    NSString * s = [[inString copy] autorelease];
    if (  [[s pathExtension] isEqualToString: @"executable"]  ) {
        s = [s stringByDeletingPathExtension];
    }
    
    if (  [[s pathExtension] isEqualToString: @"wait"]  ) {
        s = [s stringByDeletingPathExtension];
    }
    
    if (  [[s pathExtension] isEqualToString: @"addToMenu"]  ) {
        s = [s stringByDeletingPathExtension];
    }
    
    NSRange underscoreRange = [s rangeOfString: @"_"];
    if (  underscoreRange.length != 0  ) {
        if (  underscoreRange.location == [s length] -1  ) {
            NSLog(@"Not stripping through the underscore from the name of menu item %@ because there is nothing after the underscore", inString);
            return s;
        }
        return [s substringFromIndex: underscoreRange.location+1];
    }
    
    return s;
}

-(void) runCustomMenuItem: (NSMenuItem *) item
{
    int tag = [item tag];
    if (  tag < 0  ) {
        NSLog(@"runCustomMenuItem: tag %d is < 0", tag);
    }
    NSString * scriptPath = [customMenuScripts objectAtIndex: (unsigned)tag];
    NSTask* task = [[[NSTask alloc] init] autorelease];
	[task setLaunchPath: scriptPath];
	[task setArguments: [NSArray array]];
	[task setCurrentDirectoryPath: [scriptPath stringByDeletingLastPathComponent]];
	[task launch];
    if (  [[[scriptPath stringByDeletingPathExtension] pathExtension] isEqualToString: @"wait"]) {
        [task waitUntilExit];
    }
}

-(void) changedDisplayConnectionSubmenusSettings
{
    [self createStatusItem];
    [self createMenu];
    [self updateUI];
}

-(void) removeConnectionWithDisplayName: (NSString *) theName
                               fromMenu: (NSMenu *)   theMenu
                             afterIndex: (int)        theIndex
{
    [self removeConnectionWithDisplayName: theName fromMenu: theMenu afterIndex: theIndex workingName: [[theName copy] autorelease]];
}

-(void) removeConnectionWithDisplayName: (NSString *) theName
                               fromMenu: (NSMenu *)   theMenu
                             afterIndex: (int)        theIndex
                            workingName: (NSString *) workingName
{
    int i;
    NSRange slashRange = [workingName rangeOfString: @"/" options: 0 range: NSMakeRange(0, [workingName length] - 1)];
    if (   (slashRange.length == 0)
        || [gTbDefaults boolForKey: @"doNotShowConnectionSubmenus"]  ) {
        // The item is directly in the menu
        for (  i=theIndex; i < [theMenu numberOfItems]; i++  ) {
            id menuItem = [theMenu itemAtIndex: i];
            NSString * menuItemTitle;
            if (  [menuItem isSeparatorItem]  ) {
                break;                              // A separator marks the end of list of connection items
            }
            if (   [menuItem submenu]  ) {          // item is a submenu
                menuItemTitle = [menuItem title];
            } else {                                // item is a connection item
                menuItemTitle = [[menuItem target] displayName];
            }
            
            if (  [menuItemTitle caseInsensitiveCompare: theName] == NSOrderedSame  ) {
                [theMenu removeItemAtIndex: i];
                return;
            }
        }
        
        NSLog(@"Unable to find '%@' in the menu, removal failed", theName);
        return;
    }

    // The item is on a submenu
    NSString * subMenuName = [workingName substringWithRange: NSMakeRange(0, slashRange.location + 1)];
    NSString * restOfName = [workingName substringFromIndex: slashRange.location + 1];
    for (  i=theIndex; i < [theMenu numberOfItems]; i++  ) {
        id menuItem = [theMenu itemAtIndex: i];
        if (  [menuItem isSeparatorItem]  ) {
            break; // A separator marks the end of list of connection items
        } else {
            NSMenu * subMenu = [menuItem submenu];
            if (  subMenu   ) {
                // Item is a submenu
                NSString * menuItemTitle = [menuItem title];
                if (  [menuItemTitle caseInsensitiveCompare: subMenuName] == NSOrderedSame  ) {
                    // Have found correct submenu, so remove this item from it
                    [self removeConnectionWithDisplayName: theName fromMenu: subMenu afterIndex: 0 workingName: restOfName];
                    if (  [subMenu numberOfItems] == 0  ) {
                        // No more items on the submenu, so delete it, too
                        [theMenu removeItemAtIndex: i];
                    }
                    return;
                }
            }
        }
    }
    
    NSLog(@"Unable to find submenu '%@' in the menu, removal failed", restOfName);
}

- (BOOL)validateMenuItem:(NSMenuItem *)anItem 
{
    // We set the on/off state from the CURRENT preferences, not the preferences when launched.
    SEL act = [anItem action];
    if (  act == @selector(disconnectAllMenuItemWasClicked:)  ) {
        unsigned nConnections = [[self connectionArray] count];
        NSString * myState;
        if (  nConnections == 0  ) {
            myState = NSLocalizedString(@"No Active Connections", @"Status message");
            [statusMenuItem setTitle: myState];
            return NO;
        } else if (  nConnections == 1) {
            NSString * name = nil;
            if (  [[self connectionArray] count] > 0  ) {
                name = [[[self connectionArray] objectAtIndex: 0] displayName];
            }
            if (  ! name  ) {
                name = @"1 connection";
            }
            myState = [NSString stringWithFormat: NSLocalizedString(@"Disconnect All (%@)", @"Status message"), name];
            [statusMenuItem setTitle: myState];
        } else {
            myState = [NSString stringWithFormat:NSLocalizedString(@"Disconnect All (%d Connections)", @"Status message"),nConnections];
            [statusMenuItem setTitle: myState];
        }
    } else {
        if (  [gTbDefaults boolForKey: @"showTooltips"]  ) {
            [anItem setToolTip: @""];
        }
    }
    
    // We store the preference key for a menu item in the item's representedObject so we can do the following:
    if (  [anItem representedObject]  ) {
        if (  ! [gTbDefaults canChangeValueForKey: [anItem representedObject]]  ) {
            if (  [gTbDefaults boolForKey: @"showTooltips"]  ) {
                [anItem setToolTip: NSLocalizedString(@"Disabled because this setting is being forced", @"Menu item tooltip")];
            }
            return NO;
        }
    }
    
    return YES;
}

-(void) changedDisplayConnectionTimersSettings
{
    [self startOrStopDurationsTimer];
    [self updateNavigationLabels];
}

// Starts or stops the timer for showing connection durations.
// Starts it (or lets it continue) if it is enabled and any tunnels are connected; stops it otherwise
-(void) startOrStopDurationsTimer
{
    if (  showDurationsTimer == nil  ) {
        // Timer is inactive. Start it if enabled and any tunnels are connected
        if (  [gTbDefaults boolForKey:@"showConnectedDurations"]  ) {
            VPNConnection * conn;
            NSEnumerator * connEnum = [[self myVPNConnectionDictionary] objectEnumerator];
            while (  (conn = [connEnum nextObject])  ) {
                if (  [[conn state] isEqualToString: @"CONNECTED"]) {
                    showDurationsTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0
                                                                           target:self
                                                                         selector:@selector(updateNavigationLabels)
                                                                         userInfo:nil
                                                                          repeats:YES] retain];
                    return;
                }
            }
        }
    } else {
        // Timer is active. Stop it if not enabled or if no tunnels are connected.
        if (  [gTbDefaults boolForKey:@"showConnectedDurations"]  ) {
            VPNConnection * conn;
            NSEnumerator * connEnum = [[self myVPNConnectionDictionary] objectEnumerator];
            while (  (conn = [connEnum nextObject])  ) {
                if (  [[conn state] isEqualToString: @"CONNECTED"]) {
                    return;
                }
            }
        }
        
        [showDurationsTimer invalidate];
        [showDurationsTimer release];
        showDurationsTimer = nil;
    }
}

-(void)updateNavigationLabels
{
    [logScreen updateNavigationLabels];
}

// If any new config files have been added, add each to the menu and add tabs for each to the Log window.
// If any config files have been deleted, remove them from the menu and remove their tabs in the Log window
-(void) updateMenuAndLogWindow 
{
    BOOL needToUpdateLogWindow = FALSE;         // If we changed any configurations, process the changes after we're done
    
    NSString * dispNm;
    
    NSDictionary * curConfigsDict = [[ConfigurationManager defaultManager] getConfigurations];
    
    // Add new configurations and replace updated ones
	NSEnumerator * e = [curConfigsDict keyEnumerator];
    while (  (dispNm = [e nextObject])  ) {
        BOOL sameDispNm = [[self myConfigDictionary] objectForKey: dispNm] != nil;
        BOOL sameFolder = [[[self myConfigDictionary] objectForKey: dispNm] isEqualToString: [curConfigsDict objectForKey: dispNm]];
        
        if (  sameDispNm  ) {
            if (  ! sameFolder  ) {
                    // Replace a configuration
                    [self deleteExistingConfig: dispNm];
                    [self addNewConfig: [curConfigsDict objectForKey: dispNm] withDisplayName: dispNm];
                    needToUpdateLogWindow = TRUE;
            }
        } else {
            // Add a configuration
            [self addNewConfig: [curConfigsDict objectForKey: dispNm] withDisplayName: dispNm]; // No old config with same name
            needToUpdateLogWindow = TRUE;
        }
    }
    
    // Remove configurations that are no longer available
	NSMutableArray * removeList = [NSMutableArray arrayWithCapacity: 10];
    e = [[self myConfigDictionary] keyEnumerator];
    while (  (dispNm = [e nextObject])  ) {
        BOOL sameDispNm = [curConfigsDict objectForKey: dispNm] != nil;
        if (  ! sameDispNm  ) {
            [removeList addObject: [[dispNm copy] autorelease]]; // No new config with same name
        }
    }
    e = [removeList objectEnumerator];
    while (  (dispNm = [e nextObject])  ) {
        [self deleteExistingConfig: dispNm];
        needToUpdateLogWindow = TRUE;
    }
    
	// If there aren't any configuration files left, deal with that
    if (  ! checkingForNoConfigs  ) {
        [self checkNoConfigurations];
    }
    
    if (  needToUpdateLogWindow  ) {
        [logScreen update];
    }
}

// Lock this to change myVPNConnectionDictionary, myMenu, and/or myConfigDictionary
static pthread_mutex_t configModifyMutex = PTHREAD_MUTEX_INITIALIZER;

// Add new config to myVPNConnectionDictionary, the menu, and myConfigDictionary
// Note: The menu item's title will be set on demand in VPNConnection's validateMenuItem
-(void) addNewConfig: (NSString *) path withDisplayName: (NSString *) dispNm
{
    if (  invalidConfigurationName(dispNm)  ) {
        TBRunAlertPanel(NSLocalizedString(@"Name not allowed", @"Window title"),
                        [NSString stringWithFormat: NSLocalizedString(@"Configuration '%@' will be ignored because its"
                                                                      @" name contains characters that are not allowed.", @"Window text"), dispNm],
                        nil, nil, nil);
        return;
    }
    VPNConnection* myConnection = [[VPNConnection alloc] initWithConfigPath: path
                                                            withDisplayName: dispNm];
    [myConnection setDelegate:self];
    
    NSMenuItem *connectionItem = [[[NSMenuItem alloc] init] autorelease];
    [connectionItem setTarget:myConnection]; 
    [connectionItem setAction:@selector(toggle:)];
    
    OSStatus status = pthread_mutex_lock( &configModifyMutex );
    if (  status != EXIT_SUCCESS  ) {
        NSLog(@"pthread_mutex_lock( &configModifyMutex ) failed; status = %ld, errno = %ld", (long) status, (long) errno);
        return;
    }
    
    status = pthread_mutex_lock( &myVPNMenuMutex );
    if (  status != EXIT_SUCCESS  ) {
        NSLog(@"pthread_mutex_lock( &myVPNMenuMutex ) failed; status = %ld, errno = %ld", (long) status, (long) errno);
        return;
    }
    
    // Add connection to myVPNConnectionDictionary
    NSMutableDictionary * tempVPNConnectionDictionary = [myVPNConnectionDictionary mutableCopy];
    [tempVPNConnectionDictionary setObject: myConnection forKey: dispNm];
    [self setMyVPNConnectionDictionary: [[tempVPNConnectionDictionary copy] autorelease]];
    [tempVPNConnectionDictionary release];
    
    int itemIx = (int) [myVPNMenu indexOfItemWithTitle: NSLocalizedString(@"No VPN Configurations Available", @"Menu item")];
    if (  itemIx  != -1) {
        [myVPNMenu removeItemAtIndex: itemIx];
    }
    
    [self insertConnectionMenuItem: connectionItem IntoMenu: myVPNMenu afterIndex: 2 withName: [[connectionItem target] displayName]];
    
    // Add connection to myConfigDictionary
    NSMutableDictionary * tempConfigDictionary = [myConfigDictionary mutableCopy];
    [tempConfigDictionary setObject: path forKey: dispNm];
    [self setMyConfigDictionary: [[tempConfigDictionary copy] autorelease]];
    [tempConfigDictionary release];
     
    status = pthread_mutex_unlock( &myVPNMenuMutex );
    if (  status != EXIT_SUCCESS  ) {
        NSLog(@"pthread_mutex_unlock( &myVPNMenuMutex ) failed; status = %ld, errno = %ld", (long) status, (long) errno);
        return;
    }
    status = pthread_mutex_unlock( &configModifyMutex );
    if (  status != EXIT_SUCCESS  ) {
        NSLog(@"pthread_mutex_unlock( &configModifyMutex ) failed; status = %ld, errno = %ld", (long) status, (long) errno);
    }
}

// Remove config from myVPNConnectionDictionary, the menu, and myConfigDictionary
// Disconnect first if necessary
-(void) deleteExistingConfig: (NSString *) dispNm
{
    VPNConnection* myConnection = [myVPNConnectionDictionary objectForKey: dispNm];
    if (  ! [[myConnection state] isEqualTo: @"EXITING"]  ) {
        [myConnection addToLog: @"*SurfSafeVPN: Disconnecting; user asked to delete the configuration"];
        [myConnection disconnectAndWait: [NSNumber numberWithBool: NO] userKnows: YES];
        
        TBRunAlertPanel([NSString stringWithFormat: NSLocalizedString(@"'%@' has been disconnected", @"Window title"), dispNm],
                        [NSString stringWithFormat: NSLocalizedString(@"SurfSafeVPN has disconnected '%@' because its configuration file has been removed.", @"Window text"), dispNm],
                        nil, nil, nil);
    }
    
    OSStatus status = pthread_mutex_lock( &configModifyMutex );
    if (  status != EXIT_SUCCESS  ) {
        NSLog(@"pthread_mutex_lock( &configModifyMutex ) failed; status = %ld, errno = %ld", (long) status, (long) errno);
        return;
    }
    
    status = pthread_mutex_lock( &myVPNMenuMutex );
    if (  status != EXIT_SUCCESS  ) {
        NSLog(@"pthread_mutex_lock( &myVPNMenuMutex ) failed; status = %ld, errno = %ld", (long) status, (long) errno);
        return;
    }
    
    // Remove connection from myVPNConnectionDictionary
    NSMutableDictionary * tempVPNConnectionDictionary = [myVPNConnectionDictionary mutableCopy];
    [tempVPNConnectionDictionary removeObjectForKey: dispNm];
    [self setMyVPNConnectionDictionary: [[tempVPNConnectionDictionary copy] autorelease]];
    [tempVPNConnectionDictionary release];
        
    [self removeConnectionWithDisplayName: dispNm fromMenu: myVPNMenu afterIndex: 2];

    // Remove connection from myConfigDictionary
    NSMutableDictionary * tempConfigDictionary = [myConfigDictionary mutableCopy];
    [tempConfigDictionary removeObjectForKey: dispNm];
    [self setMyConfigDictionary: [[tempConfigDictionary copy] autorelease]];
    [tempConfigDictionary release];

    if (  [[self myConfigDictionary] count] == 0  ) {
        int itemIx = (int) [myVPNMenu indexOfItemWithTitle: NSLocalizedString(@"No VPN Configurations Available", @"Menu item")];
        if (  itemIx  == -1  ) {
            [myVPNMenu insertItem: noConfigurationsItem atIndex: 2];
        }
        
        itemIx = (int) [myVPNMenu indexOfItemWithTitle: NSLocalizedString(@"Add a VPN...", @"Menu item")];
        if (   (itemIx  == -1)
            && addConfigurationItem  ) {
            [myVPNMenu insertItem: [[addConfigurationItem copy] autorelease] atIndex: 3]; // Use a copy because the original is used in elsewhere
        }
    }
    
    status = pthread_mutex_unlock( &myVPNMenuMutex );
    if (  status != EXIT_SUCCESS  ) {
        NSLog(@"pthread_mutex_unlock( &myVPNMenuMutex ) failed; status = %ld, errno = %ld", (long) status, (long) errno);
        return;
    }
    status = pthread_mutex_unlock( &configModifyMutex );
    if (  status != EXIT_SUCCESS  ) {
        NSLog(@"pthread_mutex_unlock( &configModifyMutex ) failed; status = %ld, errno = %ld", (long) status, (long) errno);
    }
}

- (void)activateStatusMenu
{
    [self updateUI];
    [self updateMenuAndLogWindow];
}

- (void)connectionStateDidChange:(id)connection
{
	[self updateNavigationLabels];
    [logScreen validateConnectAndDisconnectButtonsForConnection: connection];
    VPNConnection *myConnection = (VPNConnection *)connection;
    if([[currentConnection displayName] isEqualToString: [myConnection displayName]])
    {
        if (IsEnabledProxy()){
            if ([myConnection isDisconnected]){    
                //HTK-INC1        
                [self restoreWebSWebProxies];
                //END HTK-INC1
            }
        }
    }
}

- (void) updateUI
{
    if (  gShuttingDownWorkspace  ) {
        [theAnim stopAnimation];
        return;
    }
    
	if (   (![lastState isEqualToString:@"EXITING"])
        && (![lastState isEqualToString:@"CONNECTED"]) ) { 
		//  Anything other than connected or disconnected shows the animation
		if (![theAnim isAnimating])
		{
			//NSLog(@"Starting Animation");
			[theAnim startAnimation];
		}
	} else
	{
        //we have a new connection, or error, so stop animating and show the correct icon
		if ([theAnim isAnimating])
		{
			[theAnim stopAnimation];
		}
        
        if (  [lastState isEqualToString:@"CONNECTED"]  ) {
            [[self ourMainIconView] setImage: connectedImage];
        } else {
            [[self ourMainIconView] setImage: mainImage];
        }
	}
    
//    if([lastState isEqualToString:@"CONNECTED"])
//    {   
//        [photoShieldItem setHidden: YES];
//    }
//    if([lastState isEqualToString:@"DISCONNECTED"])
//    {
//        [photoShieldItem setHidden:NO];
//    }
}

- (void)animationDidEnd:(NSAnimation*)animation
{
	if (  animation != theAnim  ) {
		return;
	}
	
    if (  gShuttingDownWorkspace  ) {
        return;
    }
    
	if (   (![lastState isEqualToString:@"EXITING"])
        && (![lastState isEqualToString:@"CONNECTED"]))
	{
		// NSLog(@"Starting Animation (2)");
		[theAnim startAnimation];
	}
}

- (void)animation:(NSAnimation *)animation didReachProgressMark:(NSAnimationProgress)progress
{
    if (  gShuttingDownWorkspace  ) {  // Stop _any_ animation we are doing
        [animation stopAnimation];
        return;
    }
    
	if (animation == theAnim) {
        [[self ourMainIconView] performSelectorOnMainThread:@selector(setImage:) withObject:[animImages objectAtIndex: (unsigned) (lround(progress * [animImages count]) - 1)] waitUntilDone:YES];
	}
}

- (NSString *) openVPNLogHeader
{
    unsigned major, minor, bugFix;
    [[NSApplication sharedApplication] getSystemVersionMajor:&major minor:&minor bugFix:&bugFix];
    return ([NSString stringWithFormat:@"*SurfSafeVPN: OS X %d.%d.%d; %@", major, minor, bugFix, surfsafevpnVersion([NSBundle mainBundle])]);
}

- (void) checkForUpdates: (id) sender
{
    /*
    
    if (   [gTbDefaults boolForKey:@"onlyAdminCanUpdate"]
        && ( ! userIsAnAdmin )  ) {
        NSLog(@"Check for updates was not performed because user is not allowed to administer this computer and 'onlyAdminCanUpdate' preference is set");
    } else {
        if (  [updater respondsToSelector: @selector(checkForUpdates:)]  ) {
            if (  feedURL != nil  ) {
                if (  ! userIsAnAdmin  ) {
                    int response = TBRunAlertPanelExtended(NSLocalizedString(@"Only computer administrators should update SurfSafeVPN", @"Window title"),
                                                           NSLocalizedString(@"You will not be able to use SurfSafeVPN after updating unless you provide an administrator username and password.\n\nAre you sure you wish to check for updates?", @"Window text"),
                                                           NSLocalizedString(@"Check For Updates Now", @"Button"),  // Default button
                                                           NSLocalizedString(@"Cancel", @"Button"),                 // Alternate button
                                                           nil,                                                     // Other button
                                                           @"skipWarningAboutNonAdminUpdatingTunnelblick",          // Preference about seeing this message again
                                                           NSLocalizedString(@"Do not warn about this again", @"Checkbox name"),
                                                           nil);
                    if (  response == NSAlertAlternateReturn  ) {
                        return;
                    }
                }
                [updater checkForUpdates: self];
            } else {
                NSLog(@"'Check for Updates Now' ignored because no FeedURL has been set");
            }
            
        } else {
            NSLog(@"'Check for Updates Now' ignored because Sparkle Updater does not respond to checkForUpdates:");
        }
        
        [myConfigUpdater startWithUI: YES]; // Display the UI
    }
     */
     
}

// May be called from cleanup or willGoToSleepHandler, so only do one at a time
static pthread_mutex_t killAllConnectionsIncludingDaemonsMutex = PTHREAD_MUTEX_INITIALIZER;
    
// If possible, we try to use 'killall' to kill all processes named 'openvpn'
// But if there are unknown open processes that the user wants running, or we have active daemon processes,
//     then we must use 'kill' to kill each individual process that should be killed
-(void) killAllConnectionsIncludingDaemons: (BOOL) includeDaemons logMessage: (NSString *) logMessage
{
    // DO NOT put this code inside the mutex: we want to return immediately if computer is shutting down or restarting
    if (  gShuttingDownOrRestartingComputer  ) {
        NSLog(@"DEBUG: killAllConnectionsIncludingDaemons: Computer is shutting down or restarting; OS X will kill OpenVPN instances");
        return;
    }
    
    OSStatus status = pthread_mutex_lock( &killAllConnectionsIncludingDaemonsMutex );
    if (  status != EXIT_SUCCESS  ) {
        NSLog(@"pthread_mutex_lock( &killAllConnectionsIncludingDaemonsMutex ) failed; status = %ld, errno = %ld", (long) status, (long) errno);
        return;
    }
    
    NSEnumerator * connEnum = [[self myVPNConnectionDictionary] objectEnumerator];
    VPNConnection * connection;
    BOOL noActiveDaemons = YES;
    
    if (  ! includeDaemons  ) {
        // See if any of our daemons are active -- i.e., have a process ID (they may be in the process of connecting or disconnecting)
        while (  (connection = [connEnum nextObject])  ) {
            NSString* onSystemStartKey = [[connection displayName] stringByAppendingString: @"-onSystemStart"];
            NSString* autoConnectKey = [[connection displayName] stringByAppendingString: @"autoConnect"];
            if (   [gTbDefaults boolForKey: onSystemStartKey]
                && [gTbDefaults boolForKey: autoConnectKey]  ) {
                if (  [connection pid] != 0  ) {
                    noActiveDaemons = NO;
                    break;
                }
            }
        }
    }
    
    NSLog(@"DEBUG: killAllConnectionsIncludingDaemons: has checked for active daemons");
    
	NSLog(@"DEBUG: includeDaemons = %d; noUnknownOpenVPNsRunning = %d; noActiveDaemons = %d ",
		  (int) includeDaemons, (int) noUnknownOpenVPNsRunning, (int) noActiveDaemons);
    if (   ALLOW_OPENVPNSTART_KILL
		&& ( includeDaemons
			|| ( noUnknownOpenVPNsRunning && noActiveDaemons )
			)
		) {
        
        NSLog(@"DEBUG: killAllConnectionsIncludingDaemons: will use killAll");
        
        // Killing everything, so we use 'killall' to kill all processes named 'openvpn'
        // But first append a log entry for each connection that will be restored
        NSEnumerator * connectionEnum = [connectionsToRestoreOnWakeup objectEnumerator];
        while (  (connection = [connectionEnum nextObject])  ) {
            [connection addToLog: logMessage];
        }
        // If we've added any log entries, sleep for one second so they come before OpenVPN entries associated with closing the connections
        if (  [connectionsToRestoreOnWakeup count] != 0  ) {
            NSLog(@"DEBUG: killAllConnectionsIncludingDaemons: sleeping for logs to settle");
            sleep(1);
        }
        
        NSLog(@"DEBUG: killAllConnectionsIncludingDaemons: requested killAll");
        runOpenvpnstart([NSArray arrayWithObject: @"killall"], nil, nil);
        NSLog(@"DEBUG: killAllConnectionsIncludingDaemons: killAll finished");
    } else {
        
        NSLog(@"DEBUG: killAllConnectionsIncludingDaemons: will kill individually");
        // Killing selected processes only -- those we know about that are not daemons
		connEnum = [[self myVPNConnectionDictionary] objectEnumerator];
        while (  (connection = [connEnum nextObject])  ) {
            if (  ! [connection isDisconnected]  ) {
                NSString* onSystemStartKey = [[connection displayName] stringByAppendingString: @"-onSystemStart"];
                NSString* autoConnectKey = [[connection displayName] stringByAppendingString: @"autoConnect"];
                if (   ( ! [gTbDefaults boolForKey: onSystemStartKey]  )
                    || ( ! [gTbDefaults boolForKey: autoConnectKey]    )  ) {
                    pid_t procId = [connection pid];
					if (  ALLOW_OPENVPNSTART_KILL  ) {
                    if (  procId > 0  ) {
                        [connection addToLog: logMessage];
							NSArray * arguments = [NSArray arrayWithObjects: @"kill", [NSString stringWithFormat: @"%ld", (long) procId], nil];
							NSLog(@"DEBUG: killAllConnectionsIncludingDaemons: killing '%@'", [connection displayName]);
							runOpenvpnstart(arguments, nil, nil);
							NSLog(@"DEBUG: killAllConnectionsIncludingDaemons: have killed '%@'", [connection displayName]);
                    } else {
							[connection addToLog: @"*SurfSafeVPN: Disconnecting; all configurations are being disconnected"];
							NSLog(@"DEBUG: killAllConnectionsIncludingDaemons: disconnecting '%@'", [connection displayName]);
                        [connection disconnectAndWait: [NSNumber numberWithBool: NO] userKnows: NO];
							NSLog(@"DEBUG: killAllConnectionsIncludingDaemons: have disconnected '%@'", [connection displayName]);
                    }
					} else {
						NSLog(@"DEBUG: killAllConnectionsIncludingDaemons: requesting disconnection of '%@' (pid %lu)",
							  [connection displayName], (long) procId);
						[connection disconnectAndWait: [NSNumber numberWithBool: NO] userKnows: YES];
					}
				} else {
					NSLog(@"DEBUG: killAllConnectionsIncludingDaemons: Not requesting disconnection of '%@' (pid %lu) because"
						  @" it is set to connect when the computer starts.",
						  [connection displayName], (long) [connection pid]);
                }
            }
        }
    }
    
    status = pthread_mutex_unlock( &killAllConnectionsIncludingDaemonsMutex );
    if (  status != EXIT_SUCCESS  ) {
        NSLog(@"pthread_mutex_unlock( &killAllConnectionsIncludingDaemonsMutex ) failed; status = %ld, errno = %ld", (long) status, (long) errno);
    }
}    
    
// May be called from cleanup, so only do one at a time
static pthread_mutex_t unloadKextsMutex = PTHREAD_MUTEX_INITIALIZER;

// Unloads our loaded tun/tap kexts if tunCount/tapCount is zero.
-(void) unloadKexts
{
    OSStatus status = pthread_mutex_trylock( &unloadKextsMutex );
    if (  status != EXIT_SUCCESS  ) {
        NSLog(@"pthread_mutex_lock( &unloadKextsMutex ) failed; status = %ld, errno = %ld", (long) status, (long) errno);
        return;
    }
    
    unsigned bitMask = [self getLoadedKextsMask] & ( ~ (OPENVPNSTART_FOO_TAP_KEXT | OPENVPNSTART_FOO_TUN_KEXT)  );    // Don't unload foo.tun/tap
    
    if (  bitMask != 0  ) {
        if (  tapCount != 0  ) {
            bitMask = bitMask & ( ~OPENVPNSTART_OUR_TAP_KEXT);
        }
        
        if (  tunCount != 0  ) {
            bitMask = bitMask & ( ~OPENVPNSTART_OUR_TUN_KEXT);
        }
        
        if (  bitMask != 0  ) {
            NSString * arg1 = [NSString stringWithFormat: @"%d", bitMask];
            runOpenvpnstart([NSArray arrayWithObjects:@"unloadKexts", arg1, nil], nil, nil);
        }
    }
    
    status = pthread_mutex_unlock( &unloadKextsMutex );
    if (  status != EXIT_SUCCESS  ) {
        NSLog(@"pthread_mutex_unlock( &unloadKextsMutex ) failed; status = %ld, errno = %ld", (long) status, (long) errno);
    }    
}

// Returns with a bitmask of kexts that are loaded that can be unloaded
// Launches "kextstat" to get the list of loaded kexts, and does a simple search
-(unsigned) getLoadedKextsMask
{
    NSString * tempDir = newTemporaryDirectoryPath();
    NSString * kextOutputPath = [tempDir stringByAppendingPathComponent: @"Tunnelblick-kextstat-output.txt"];
    if (  ! [gFileMgr createFileAtPath: kextOutputPath contents: [NSData data] attributes: nil]  ) {
        fprintf(stderr, "Warning: Unable to create temporary directory for kextstat output file. Assuming foo.tun and foo.tap kexts are loaded.\n");
        [gFileMgr tbRemoveFileAtPath: tempDir handler: nil];
        [tempDir release];
        return (OPENVPNSTART_FOO_TAP_KEXT | OPENVPNSTART_FOO_TUN_KEXT);
    }
    NSFileHandle * kextOutputHandle = [NSFileHandle fileHandleForWritingAtPath: kextOutputPath];
    if (  ! kextOutputHandle  ) {
        fprintf(stderr, "Warning: Unable to create temporary output file for kextstat. Assuming foo.tun and foo.tap kexts are loaded.\n");
        [gFileMgr tbRemoveFileAtPath: tempDir handler: nil];
        [tempDir release];
        return (OPENVPNSTART_FOO_TAP_KEXT | OPENVPNSTART_FOO_TUN_KEXT);
    }
    
    NSString * kextstatPath = @"/usr/sbin/kextstat";
    
    NSTask * task = [[[NSTask alloc] init] autorelease];
    [task setLaunchPath: kextstatPath];
    
    NSArray  *arguments = [NSArray array];
    [task setArguments: arguments];
    
    [task setStandardOutput: kextOutputHandle];
    
    [task launch];
    
    [task waitUntilExit];
    
    [kextOutputHandle closeFile];
    
    OSStatus status = [task terminationStatus];
    if (  status != EXIT_SUCCESS  ) {
        fprintf(stderr, "Warning: kextstat to list loaded kexts failed. Assuming foo.tun and foo.tap kexts are loaded.\n");
        return (OPENVPNSTART_FOO_TAP_KEXT | OPENVPNSTART_FOO_TUN_KEXT);
    }
    
    NSData * data = [gFileMgr contentsAtPath: kextOutputPath];
    
    [gFileMgr tbRemoveFileAtPath: tempDir handler: nil];
    [tempDir release];
    
    NSString * string = [[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] autorelease];
    
    unsigned bitMask = 0;
    
    if (  [string rangeOfString: @"foo.tap"].length != 0  ) {
        bitMask = OPENVPNSTART_FOO_TAP_KEXT;
    }
    if (  [string rangeOfString: @"foo.tun"].length != 0  ) {
        bitMask = bitMask | OPENVPNSTART_FOO_TUN_KEXT;
    }
    if (  [string rangeOfString: @"net.tunnelblick.tap"].length != 0  ) {
        bitMask = bitMask | OPENVPNSTART_OUR_TAP_KEXT;
    }
    if (  [string rangeOfString: @"net.tunnelblick.tun"].length != 0  ) {
        bitMask = bitMask | OPENVPNSTART_OUR_TUN_KEXT;
    }
    
    return bitMask;
}

-(void) resetActiveConnections {
	VPNConnection *connection;
	NSEnumerator* e = [[self connectionArray] objectEnumerator];
	while (  (connection = [e nextObject])  ) {
		if ([[connection connectedSinceDate] timeIntervalSinceNow] < -5) {
			if (NSDebugEnabled) NSLog(@"Resetting connection: %@",[connection displayName]);
            [connection addToLog: @"*SurfSafeVPN: Disconnecting; resetting all connections"];
			[connection disconnectAndWait: [NSNumber numberWithBool: YES] userKnows: NO];
			[connection connect:self userKnows: NO];
		} else {
			if (NSDebugEnabled) NSLog(@"Not Resetting connection: %@, waiting...",[connection displayName]);
		}
	}
}

// If there aren't ANY config files in the config folders 
// then guide the user
//
// When Sparkle updates us while we're running, it moves us to the Trash, then replaces us, then terminates us, then launches the new copy.
-(void) checkNoConfigurations
{
    if (   ignoreNoConfigs
        || ( [[self myConfigDictionary] count] != 0 )
        ) {
        return;
    }
    
    // Make sure we notice any configurations that have just been installed
    checkingForNoConfigs = TRUE;    // Avoid infinite recursion
    [self activateStatusMenu];
    checkingForNoConfigs = FALSE;
    
    if (  [[self myConfigDictionary] count] != 0  ) {
        return;
    }
    
    // If this is a Deployed version with no configurations, quit SurfSafeVPN
    if (   [gConfigDirs count] == 1
        && [[gConfigDirs objectAtIndex:0] isEqualToString: gDeployPath]  ) {
        TBRunAlertPanel(NSLocalizedString(@"All configuration files removed", @"Window title"),
                        NSLocalizedString(@"All configuration files have been removed. SurfSafeVPN must quit.", @"Window text"),
                        nil, nil, nil);
        [self terminateBecause: terminatingBecauseOfError];
    }
    
    [[ConfigurationManager defaultManager] haveNoConfigurationsGuide];
}

-(IBAction) addConfigurationWasClicked: (id) sender
{
 	(void) sender;
	
    [[ConfigurationManager defaultManager] addConfigurationGuide];
}

-(IBAction) disconnectAllMenuItemWasClicked: (id) sender
{
	(void) sender;
	
    NSEnumerator * connEnum = [[self myVPNConnectionDictionary] objectEnumerator];
    VPNConnection * connection;
    while (  (connection = [connEnum nextObject])  ) {
        if (  ! [connection isDisconnected]  ) {
            [connection addToLog: @"*SurfSafeVPN: Disconnecting; 'Disconnect all' menu command invoked"];
            [connection disconnectAndWait: [NSNumber numberWithBool: NO] userKnows: YES];
        }
    }
}

-(IBAction) contactTunnelblickWasClicked: (id) sender
{
	(void) sender;
	
    NSURL * url = [self contactURL];
    if (  url  ) {
        [[NSWorkspace sharedWorkspace] openURL: url];
    }
}

// HTK-INC
-(IBAction) clearKeychain:(id)sender{
    NSString * dispNm;
    NSArray *keyArray = [[self myConfigDictionary] allKeys];
	NSEnumerator * e = [keyArray objectEnumerator];
    while (dispNm = [e nextObject]) {
        if (  ! [gTbDefaults boolForKey: [dispNm stringByAppendingString: @"-doNotShowOnTunnelblickMenu"]]  ) {
            VPNConnection* myConnection = [[self myVPNConnectionDictionary] objectForKey: dispNm];            
            [myConnection deleteCredentialsFromKeychain];
        }
    }
}

-(IBAction) turnOnOffPhotoShield:(id)sender{    
    if([photoShieldItem state] == NSOffState)
    {
        [photoShieldItem setState: NSOnState];
        SetEnabledProxy(YES);
        if([lastState isEqualToString:@"CONNECTED"]){
            //HTK-INC1
            [self setEnableWebSWebProxies: [currentConnection proxy]];
            //END HTK-INC1
        }
    }   
    else
    {
        [photoShieldItem setState: NSOffState];
        SetEnabledProxy(NO);
        if([lastState isEqualToString:@"CONNECTED"]){
            //HTK-INC1
            [self restoreWebSWebProxies];
        }
    }
    [self createMenu];
    [self updateUI];
    [statusItem popUpStatusItemMenu:myVPNMenu];
    //END HTK-INC1
}
// End HTK-INC
     
-(NSURL *) contactURL
{
    NSString * string = [NSString stringWithFormat: @"http://www.tunnelblick.net/contact?v=%@", surfsafevpnVersion([NSBundle mainBundle])];
    string = [string stringByAddingPercentEscapesUsingEncoding: NSASCIIStringEncoding];
    NSURL * url = [NSURL URLWithString: string];
    if (  ! url  ) {
        NSLog(@"Invalid contactURL");
    }
    
    return url;
}

-(IBAction) openPreferencesWindow: (id) sender
{
	(void) sender;
	
    [[MyPrefsWindowController sharedPrefsWindowController] showWindow: nil];
    [NSApp activateIgnoringOtherApps:YES];  // Force Preferences window to front (if it already exists and is covered by another window)

}

- (void) networkConfigurationDidChange
{
	if (NSDebugEnabled) NSLog(@"Got networkConfigurationDidChange notification!!");
	[self resetActiveConnections];
}

static pthread_mutex_t cleanupMutex = PTHREAD_MUTEX_INITIALIZER;

// Returns TRUE if cleaned up, or FALSE if a cleanup is already taking place
-(BOOL) cleanup 
{
    NSLog(@"DEBUG: Cleanup: Entering cleanup");
    
    OSStatus status = pthread_mutex_trylock( &cleanupMutex );
    if (  status != EXIT_SUCCESS  ) {
        NSLog(@"pthread_mutex_trylock( &cleanupMutex ) failed; status = %ld, errno = %ld", (long) status, (long) errno);
        NSLog(@"pthread_mutex_trylock( &cleanupMutex ) failed is normal and expected when SurfSafeVPN is updated");
        return FALSE;
    }
    
    // DO NOT ever unlock cleanupMutex -- we don't want to allow another cleanup to take place

    if ( gShuttingDownOrRestartingComputer ) {
        NSLog(@"DEBUG: Cleanup: Skipping cleanup because computer is shutting down or restarting");
    // DO NOT ever unlock cleanupMutex -- we don't want to allow another cleanup to take place
        return TRUE;
    }
    
    if ( ! gShuttingDownWorkspace  ) {
        if (  statusItem  ) {
            NSLog(@"DEBUG: Cleanup: Removing status bar item");
            [[NSStatusBar systemStatusBar] removeStatusItem:statusItem];
        }
    
    if (  hotKeyEventHandlerIsInstalled && hotKeyModifierKeys != 0  ) {
            NSLog(@"DEBUG: Cleanup: Unregistering hotKeyEventHandler");
        UnregisterEventHotKey(hotKeyRef);
    }
    }
    
    NSLog(@"DEBUG: Cleanup: Setting callDelegateOnNetworkChange: NO");
	[NSApp callDelegateOnNetworkChange: NO];
    
    if (  ! [lastState isEqualToString:@"EXITING"]) {
        NSLog(@"DEBUG: Cleanup: Will killAllConnectionsIncludingDaemons: NO");
        [self killAllConnectionsIncludingDaemons: NO logMessage: @"*SurfSafeVPN: SurfSafeVPN is quitting. Closing connection..."];  // Kill any of our OpenVPN processes that still exist unless they're "on computer start" configurations
    }
    if (  reasonForTermination == terminatingBecauseOfFatalError  ) {
        NSLog(@"Skipping rest of cleanup (unload kexts, delete logs) because of fatal error.");
        return TRUE;
    }
    
    NSLog(@"DEBUG: Cleanup: Unloading kexts");
    [self unloadKexts];     // Unload .tun and .tap kexts
    
    NSLog(@"DEBUG: Cleanup: Deleting logs");
    [self deleteLogs];

    // DO NOT ever unlock cleanupMutex -- we don't want to allow another cleanup to take place
    return TRUE;
}

-(void) deleteLogs
{
    VPNConnection * connection;
    NSEnumerator * e = [[self myVPNConnectionDictionary] objectEnumerator];
    while (  (connection = [e nextObject])  ) {
        [connection deleteLogs];
    }
}

- (void) setState: (NSString*) newState
{
	// Be sure to call this in main thread only
	//
    // Decide how to display the Tunnelblick icon:
    // Ignore the newState argument and look at the configurations:
    //   If any configuration should be open but isn't open and isn't closed, then show animation
    //   If any configuration should be closed but isn't, then show animation
    //   Otherwise, if any configurations are open, show open
    //              else show closed
    
    	(void) newState;
	
    if (  gShuttingDownWorkspace  ) {
        return;
    }
    
    if (IsEnabledProxy()){
        [photoShieldItem setState:NSOnState];
    }else{
        [photoShieldItem setState:NSOffState];
    }
    
    BOOL atLeastOneIsConnected = FALSE;
    NSString * newDisplayState = @"EXITING";
    VPNConnection * connection;
    NSEnumerator * connEnum = [[self myVPNConnectionDictionary] objectEnumerator];
    while (  (connection = [connEnum nextObject])  ) {
        NSString * curState = [connection state];
        NSString * reqState = [connection requestedState];
        if     (  [reqState isEqualToString: @"CONNECTED"]  ) {
            if (  [curState isEqualToString: @"CONNECTED"]  ) {
                atLeastOneIsConnected = TRUE;
                currentConnection = connection;
                //HTK-INC1
                if (IsEnabledProxy())
                    [self setEnableWebSWebProxies: [currentConnection proxy]];
                //END HTK-INC1
            } else if (  ! [curState isEqualToString: @"EXITING"]  ) {
                newDisplayState = @"ANIMATED";
                break;
            }
        } else if (  [reqState isEqualToString: @"EXITING"]  ) {
            if (   ! [curState isEqualToString: @"EXITING"]  ) {
                newDisplayState = @"ANIMATED";
                break;
            }
        } else {
            NSLog(@"Internal program error: invalid requestedState = %@", reqState);
        }
    }
    
    if (   atLeastOneIsConnected
        && [newDisplayState isEqualToString: @"EXITING"]  ) {
        newDisplayState = @"CONNECTED";
    }
    
    // Display that unless it is already being displayed
    if (  ![newDisplayState isEqualToString: lastState]  ) {
        [newDisplayState retain];
        [lastState release];
        lastState = newDisplayState;
        [self performSelectorOnMainThread:@selector(updateUI) withObject:nil waitUntilDone:NO];
    }
}

static pthread_mutex_t connectionArrayMutex = PTHREAD_MUTEX_INITIALIZER;

-(void)addConnection:(id)sender 
{
	if (  sender != nil  ) {
        OSStatus status = pthread_mutex_trylock( &connectionArrayMutex );
        if (  status != EXIT_SUCCESS  ) {
            NSLog(@"pthread_mutex_trylock( &connectionArrayMutex ) failed; status = %ld, errno = %ld", (long) status, (long) errno);
            return;
        }
        NSMutableArray * tempConnectionArray = [[self connectionArray] mutableCopy];
		[tempConnectionArray removeObject:sender];
		[tempConnectionArray addObject:sender];
        [self setConnectionArray: tempConnectionArray];
        [tempConnectionArray release];
        status = pthread_mutex_unlock( &connectionArrayMutex );
        if (  status != EXIT_SUCCESS  ) {
            NSLog(@"pthread_mutex_unlock( &connectionArrayMutex ) failed; status = %ld, errno = %ld", (long) status, (long) errno);
            return;
        }    
        
        [self startOrStopDurationsTimer];
	}
}

-(void)removeConnection:(id)sender
{
	if (  sender != nil  ) {
        OSStatus status = pthread_mutex_trylock( &connectionArrayMutex );
        if (  status != EXIT_SUCCESS  ) {
            NSLog(@"pthread_mutex_trylock( &connectionArrayMutex ) failed; status = %ld, errno = %ld", (long) status, (long) errno);
            return;
        }
        NSMutableArray * tempConnectionArray = [[self connectionArray] mutableCopy];
        [tempConnectionArray removeObject:sender];
        [self setConnectionArray: tempConnectionArray];
        [tempConnectionArray release];
        status = pthread_mutex_unlock( &connectionArrayMutex );
        if (  status != EXIT_SUCCESS  ) {
            NSLog(@"pthread_mutex_unlock( &connectionArrayMutex ) failed; status = %ld, errno = %ld", (long) status, (long) errno);
            return;
        }    
        
        [self startOrStopDurationsTimer];
    }
}

-(void) terminateBecause: (enum TerminationReason) reason
{
	reasonForTermination = reason;
    
    if (   (reason != terminatingBecauseOfLogout)
        && (reason != terminatingBecauseOfRestart)
        && (reason != terminatingBecauseOfShutdown)  ) {
        [NSApp setAutoLaunchOnLogin: NO];
        terminatingAtUserRequest = TRUE;
    }
    
    if (  reason == terminatingBecauseOfQuit  ) {
        terminatingAtUserRequest = TRUE;
    }
        [NSApp terminate: self];
}

static void signal_handler(int signalNumber)
{
    if (signalNumber == SIGHUP) {
        NSLog(@"SIGHUP received. Restarting active connections");
        [[NSApp delegate] resetActiveConnections];
    } else  {
        if (   (signalNumber == SIGTERM)
            && gShuttingDownTunnelblick
            && (   (reasonForTermination == terminatingBecauseOfLogout)
                || (reasonForTermination == terminatingBecauseOfRestart)
                || (reasonForTermination == terminatingBecauseOfShutdown) )  ) {
            NSLog(@"Ignoring SIGTERM (signal %d) because SurfSafeVPN is already terminating", signalNumber);
            return;
        }
        
        NSLog(@"Received fatal signal %d.", signalNumber);
        if ( reasonForTermination == terminatingBecauseOfFatalError ) {
            NSLog(@"signal_handler: Error while handling signal.");
            exit(0);
        } else {
            reasonForTermination = terminatingBecauseOfFatalError;
            gShuttingDownTunnelblick = TRUE;
            NSLog(@"signal_handler: Starting cleanup.");
            if (  [[NSApp delegate] cleanup]  ) {
                NSLog(@"signal_handler: Cleanup finished.");
            } else {
                NSLog(@"signal_handler: Cleanup already being done.");
            }
        }
        exit(0);	
    }
}

- (void) installSignalHandler
{
    struct sigaction action;
    
    action.sa_handler = signal_handler;
    sigemptyset(&action.sa_mask);
    action.sa_flags = 0;
    
    if (sigaction(SIGHUP,  &action, NULL) || 
        sigaction(SIGQUIT, &action, NULL) || 
        sigaction(SIGTERM, &action, NULL) ||
        sigaction(SIGBUS,  &action, NULL) ||
        sigaction(SIGSEGV, &action, NULL) ||
        sigaction(SIGPIPE, &action, NULL)) {
        NSLog(@"Warning: setting signal handler failed: '%s'", strerror(errno));
    }	
}


// Invoked by Tunnelblick modifications to Sparkle with the path to a .bundle with updated configurations to install
-(void) installConfigurationsUpdateInBundleAtPathHandler: (NSString *) path
{
    // This handler SHOULD proceed even if the computer is shutting down
    [self performSelectorOnMainThread: @selector(installConfigurationsUpdateInBundleAtPath:)
                           withObject: path 
                        waitUntilDone: YES];
}

-(void) installConfigurationsUpdateInBundleAtPath: (NSString *) path
{
    if (  ! path  ) {
        NSLog(@"Configuration update installer: Not installing configurations update: Invalid path to update");
        return;
    }
    
    // Get version of bundle whose contents we are installing, so we can (later) update /Library/Application Support/.../SurfSafeVPN Configurations.bundle
    NSString * plistPath = [path stringByAppendingPathComponent: @"Contents/Info.plist"];
    NSDictionary * dict  = [NSDictionary dictionaryWithContentsOfFile: plistPath];
    NSString * version   = [dict objectForKey: @"CFBundleVersion"];
    if (  ! version  ) {
        NSLog(@"Configuration update installer: Not installing configurations update: No version information in %@", plistPath);
        return;
    }
    NSString * versionShortString = [dict objectForKey: @"CFBundleShortVersionString"];
    
    // Install the updated configurations
    BOOL gotMyAuth = FALSE;
    
    BOOL isDir;
    NSString * installFolder = [path stringByAppendingPathComponent: @"Contents/Resources/Install"];
    if (  [gFileMgr fileExistsAtPath: installFolder isDirectory: &isDir]
        && isDir  ) {
        // Install folder should consist of zero or more .tblks -- make an array of their paths
        NSMutableArray * paths = [NSMutableArray arrayWithCapacity: 16];
        NSString * fileName;
        NSDirectoryEnumerator * dirEnum = [gFileMgr enumeratorAtPath: installFolder];
        while (  fileName = [dirEnum nextObject]  ) {
            [dirEnum skipDescendents];
            NSString * fullPath = [installFolder stringByAppendingPathComponent: fileName];
            if (  itemIsVisible(fullPath)  ) {
                if (  [[fileName pathExtension] isEqualToString: @"tblk"]  ) {
                    [paths addObject: fullPath];
                } else {
                    NSLog(@"Configuration update installer: Item %@ is not a .tblk and has been ignored", fullPath);
                }
            }
        }
        
        if (  [paths count] != 0  ) {
            if ( ! gAuthorization  ) {
                NSString * msg = NSLocalizedString(@"SurfSafeVPN needs to install one or more SurfSafeVPN Configurations.", @"Window text");
                gAuthorization = [NSApplication getAuthorizationRef: msg];
                gotMyAuth = TRUE;
            }
            
            if (  ! gAuthorization  ) {
                NSLog(@"Configuration update installer: The SurfSafeVPN installation was cancelled by the user.");
                return;
            }
            
            [self application: nil openFiles: paths skipConfirmationMessage: YES skipResultMessage: YES];   // Install .tblks
            
        } else {
            NSLog(@"Configuration update installer: Not installing update: No items to install in %@", installFolder);
            return;
        }
    } else {
        NSLog(@"Configuration update installer: Not installing update: %@ does not exist", installFolder);
        return;
    }
    
    // Set the version # in /Library/Application Support/SurfSafeVPN/Configuration Updates/SurfSafeVPN Configurations.bundle/Contents/Info.plist
    // and remove the bundle's Contents/Resources/Install folder that contains the updates so we don't update with them again
    if ( ! gAuthorization  ) {
        NSString * msg = NSLocalizedString(@"SurfSafeVPN needs to install one or more SurfSafeVPN Configurations.", @"Window text");
        gAuthorization = [NSApplication getAuthorizationRef: msg];
        gotMyAuth = TRUE;
    }
    
    if (  ! gAuthorization  ) {
        NSLog(@"Configuration update installer: The SurfSafeVPN installation was cancelled by the user.");
        return;
    }
    
    NSString * masterPlistPath = [CONFIGURATION_UPDATES_BUNDLE_PATH stringByAppendingPathComponent: @"Contents/Info.plist"];

    NSString *launchPath = [[NSBundle mainBundle] pathForResource:@"installer" ofType:nil];
    NSArray * arguments = [NSArray arrayWithObjects: [NSString stringWithFormat: @"%u", INSTALLER_SET_VERSION], version, versionShortString, nil];
    
    BOOL okNow = FALSE; // Assume failure
    unsigned i;
    for (i=0; i<5; i++) {
        if (  i != 0  ) {
            usleep( i * 500000 );
            NSLog(@"Configuration update installer: Retrying execution of installer");
        }
        
        if (  [NSApplication waitForExecuteAuthorized: launchPath withArguments: arguments withAuthorizationRef: gAuthorization] ) {
            // Try for up to 6.35 seconds to verify that installer succeeded -- sleeping .05 seconds first, then .1, .2, .4, .8, 1.6,
            // and 3.2 seconds (totals 6.35 seconds) between tries as a cheap and easy throttling mechanism for a heavily loaded computer
            useconds_t sleepTime;
            for (sleepTime=50000; sleepTime < 7000000; sleepTime=sleepTime*2) {
                usleep(sleepTime);
                
                NSDictionary * masterDict = [NSDictionary dictionaryWithContentsOfFile: masterPlistPath];
                if (  (okNow = [version isEqualToString: [masterDict objectForKey: @"CFBundleVersion"]])  ) {
                    break;
                }
            }
            
            if (  okNow  ) {
                break;
            } else {
                NSLog(@"Configuration update installer: installer did not make the necessary changes");
            }
        } else {
            NSLog(@"Configuration update installer: Failed to execute %@: %@", launchPath, arguments);
        }
    }
    
    
    if (   ! okNow  ) {
        NSDictionary * masterDict = [NSDictionary dictionaryWithContentsOfFile: masterPlistPath];
        if (  ! [version isEqualToString: [masterDict objectForKey: @"CFBundleVersion"]]  ) {
            NSLog(@"Configuration update installer: Unable to update CFBundleVersion in %@", masterPlistPath);
        }
    }
    
    if (  gotMyAuth  ) {
        AuthorizationFree(gAuthorization, kAuthorizationFlagDefaults);
        gAuthorization = nil;
    }
}
- (void) installSurfSafeUpdateHandler{
    [self performSelectorOnMainThread: @selector(installSurfSafeUpdate)
                           withObject: nil
                        waitUntilDone: NO];

}

- (void) installSurfSafeUpdate{
    NSLog(@"Install SurfSafeVPN update.");
    /*
    int response = TBRunAlertPanelExtended(NSLocalizedString(@"Only computer administrators should update SurfSafe", @"Window title"),
                                           NSLocalizedString(@"You will not be able to use SurfSafeVPN after updating unless you provide an administrator username and password.\n\nAre you sure you wish to check for updates?", @"Window text"),
                                           NSLocalizedString(@"Check For Updates Now", @"Button"),  // Default button
                                           NSLocalizedString(@"Cancel", @"Button"),                 // Alternate button
                                           nil,                                                     // Other button
                                           @"skipWarningAboutNonAdminUpdatingTunnelblick",          // Preference about seeing this message again
                                           NSLocalizedString(@"Do not warn about this again", @"Checkbox name"),
                                           nil);
    */
    int response = TBRunAlertPanelExtended(@"Update SurfSafeVPN", 
                                           @"Your verion is out of date.\nIn update progress, the tool may be relaunched.", 
                                           @"Update now", 
                                           @"Canel", 
                                           nil,
                                           nil, 
                                           nil,
                                           nil,
                                           NSAlertDefaultReturn);
    
    if (  response == NSAlertAlternateReturn  ) {
        return;
    }
    [ssUpdater downloadDmgFile];
    NSString *updatePath = [NSHomeDirectory() stringByAppendingPathComponent:UPDATE_PATH];
    NSString *drive = @"/Volumes/SurfSafeSetup";
    NSString *dmgPath = [updatePath stringByAppendingPathComponent:@"SurfSafeSetup.dmg"];
    
    NSError *err;
    BOOL isDir;
    
    if (![gFileMgr fileExistsAtPath:dmgPath isDirectory:&isDir]){
        NSLog(@"Error: Can't found dmg %@", dmgPath);
        return;
    }
    
    // detach all /Volumes/SurfSafeVPN
   
    if ([gFileMgr fileExistsAtPath:drive isDirectory:&isDir]){
        NSTask *task = [[NSTask alloc] init];
        [task setLaunchPath:@"/usr/bin/hdiutil"];
        [task setArguments: [NSArray arrayWithObjects:@"detach", drive, nil]];
        [task launch];
        [task waitUntilExit];
        [task release];
    }
    
    // attach SurfSafeSetup.dmg 
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/bin/hdiutil"];
    [task setArguments: [NSArray arrayWithObjects:@"attach", dmgPath, nil]];
    [task launch];
    [task waitUntilExit];
    [task release];
    // copy bundle
    NSString * currentPath = [drive stringByAppendingPathComponent:@"SurfSafeVPN.app"];
    NSString * targetPath = [updatePath stringByAppendingPathComponent:@"SurfSafeVPN.app"];
    if (  [gFileMgr fileExistsAtPath: targetPath]  ) {
        [gFileMgr removeItemAtPath:targetPath error:&err];
    }
    
    if (  ! [gFileMgr tbCopyPath: currentPath toPath: targetPath handler: nil]  ) {
        NSLog(@"SurfSafeVPN Installer: Unable to copy %@ to %@", currentPath, targetPath);
    } else {
        NSLog(@"SurfSafeVPN Installer: Copied %@ to %@", currentPath, targetPath);
    }        
    
    // detach 
    task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/bin/hdiutil"];
    [task setArguments: [NSArray arrayWithObjects:@"detach", drive, nil]];
    [task launch];
    [task waitUntilExit];
    [task release];
    
    //[gFileMgr removeItemAtPath:targetPath error:&err];
    
    NSString *appPath = [[NSBundle mainBundle] bundlePath];
    [gFileMgr removeItemAtPath:targetPath error:&err ];
    if ([appPath isEqualToString:targetPath])
        return;
    
    NSLog(@"target %@", targetPath);
    [gFileMgr tbCopyPath:appPath toPath:targetPath handler:nil];
    
    [self cleanup];
    
    [[NSWorkspace sharedWorkspace] launchApplication: targetPath];
    [NSApp terminate: self];
}

// Invoked when the user double-clicks on one or more .; packages,
//                  or drags and drops one or more .tblk package(s) onto SurfSafeVPN
- (BOOL)application: (NSApplication * )theApplication
          openFiles: (NSArray * )filePaths
{
    return [self application: theApplication openFiles: filePaths skipConfirmationMessage: NO skipResultMessage: NO];
}


-(BOOL)             application: (NSApplication *) theApplication
                      openFiles: (NSArray * )      filePaths
        skipConfirmationMessage: (BOOL)            skipConfirmMsg
              skipResultMessage: (BOOL)            skipResultMsg

{
    // If we have finished launching SurfSafeVPN, we open the file(s) now
    // otherwise the file(s) opening launched us, but we have not initialized completely.
    // so we store the paths and open the file(s) later, in applicationDidFinishLaunching.
	
	(void) theApplication;
	
    if (  launchFinished  ) {
        BOOL oldIgnoreNoConfigs = ignoreNoConfigs;
        ignoreNoConfigs = TRUE;
        [[ConfigurationManager defaultManager] openDotTblkPackages: filePaths
                                                         usingAuth: gAuthorization
                                           skipConfirmationMessage: skipConfirmMsg
                                                 skipResultMessage: skipResultMsg];
        ignoreNoConfigs = oldIgnoreNoConfigs;
    } else {
        if (  ! dotTblkFileList  ) {
            dotTblkFileList = [NSMutableArray arrayWithArray: filePaths];
        } else {
            [dotTblkFileList addObjectsFromArray: filePaths];
        }
    }
    
    return TRUE;
}

- (void) applicationWillFinishLaunching: (NSNotification *)notification
{
    // Sparkle Updater 1.5b6 allows system profiles to be sent to SurfSafeVPN's website.
    // However, a user who has already used SurfSafeVPN will not be asked permission to send them.
    // So we force Sparkle to ask the user again (i.e., ask again about checking for updates automatically) in order to allow
    // the user to respond as they see fit, after (if they wish) viewing the exact data that will be sent.
    //
    // We do this by clearing Sparkle's preferences. We use our own preference that indicates that we've done this so we only
    // do it once (and so we can override that preference with a forced-preferences.plist entry). The _value_ of that
    // preference doesn't matter; if it exists we assume this issue has been dealt with. The user will not be asked if
    // both the "updateCheckAutomatically" and "updateSendProfileInfo" preferences are forced (to any value).
    //
    // We do this check each time SurfSafeVPN is launched, to allow deployers to "un-force" this at some later time and have
    // the user asked for his/her preference.
    /*
    [myConfigUpdater setup];    // Set up to run the configuration updater

    
    BOOL forcingAutoChecksAndSendProfile = (  ! [gTbDefaults canChangeValueForKey: @"updateCheckAutomatically" ]  )
    && ( ! [gTbDefaults canChangeValueForKey: @"updateSendProfileInfo"]  );
    BOOL userIsAdminOrNonAdminsCanUpdate = ( userIsAnAdmin ) || ( ! [gTbDefaults boolForKey:@"onlyAdminCanUpdate"] );
    NSUserDefaults * stdDefaults = [NSUserDefaults standardUserDefaults];
    
    if (  [gTbDefaults objectForKey: @"haveDealtWithSparkle1dot5b6"] == nil  ) {
        if (  ! forcingAutoChecksAndSendProfile  ) {
            // Haven't done this already and aren't forcing the user's answers, so ask the user (perhaps again) by clearing Sparkle's preferences
            // EXCEPT we SET "SUHasLaunchedBefore", so the user will be asked right away about checking for updates automatically and sending profile info
            [stdDefaults removeObjectForKey: @"SUEnableAutomaticChecks"];
            [stdDefaults removeObjectForKey: @"SUAutomaticallyUpdate"];
            [stdDefaults removeObjectForKey: @"SUupdateSendProfileInfo"];
            [stdDefaults removeObjectForKey: @"SULastCheckTime"];                       
            [stdDefaults removeObjectForKey: @"SULastProfileSubmissionDate"];
            
            [stdDefaults setBool: TRUE forKey: @"SUHasLaunchedBefore"];
            
            // We clear _our_ preferences, too, so they will be updated when the Sparkle preferences are set by Sparkle
            [stdDefaults removeObjectForKey: @"updateCheckAutomatically"];
            [stdDefaults removeObjectForKey: @"updateSendProfileInfo"];
            [stdDefaults synchronize];
            
            [gTbDefaults setBool: YES forKey: @"haveDealtWithSparkle1dot5b6"];
            [gTbDefaults synchronize];
        }
    }
    
    // We aren't supposed to use Sparkle Updater's preferences directly. However, we need to be able to, in effect,
    // override three of them via forced-preferences.plist. So we have three of our own preferences which mirror Sparkle's. Our
    // preferences are "updateCheckAutomatically", "updateSendProfileInfo", and "updateAutomatically", which mirror
    // Sparkle's "SUEnableAutomaticChecks", "SUupdateSendProfileInfo", and "SUAutomaticallyUpdate". We use our preferences to
    // set Sparkle's behavior by invoking methods of the updater instance.
    //
    // We also have two other preferences which affect Sparkle's behavior. Sparkle doesn't use preferences for them; they are set in
    // Info.plist or have default values. These two preferences are "updateCheckInterval", and "updateFeedURL".
    // Note that "updateFeedURL" may only be forced -- any normal, user-modifiable value will be ignored.
    //
    // Everywhere we change our preferences, we notify Sparkle via the appropriate updater methods.
    //
    // We access Sparkle's preferences only on a read-only basis, and only for the inital setup of our preferences (here).
    // We do the initial setup of our preferences from Sparkle's preferences because it is Sparkle that asks the user.
    // Until the user has been asked by Sparkle (and thus Sparkle has set its preferences), we assume we are not
    // checking, and not sending system profiles.
    
    // Initialize our preferences from Sparkle's if ours have not been set yet (and thus are not being forced), and Sparkle's _have_ been set
    // (We have to access Sparkle's prefs directly because we need to wait until they have actually been set one way or the other)
    // Note that we access Sparkle's preferences via stdDefaults, so they can't be forced (Sparkle would ignore the forcing, anyway)
    // However, when we try to set out preferences from Sparkle's, if they are forced then they won't be changed.
    
    [self setupSparklePreferences];
    
    // Set Sparkle's behavior from our preferences using Sparkle's approved methods
    
    // We set the Feed URL, even if we haven't run Sparkle yet (and thus haven't set our Sparkle preferences) because
    // the user may do a 'Check for Updates Now' on the first run, and we need to check with the correct Feed URL
    
    // If the 'updateFeedURL' preference is being forced, set the program update FeedURL from it
    if (  ! [gTbDefaults canChangeValueForKey: @"updateFeedURL"]  ) {
        feedURL = [gTbDefaults objectForKey: @"updateFeedURL"];
        if (  ! [[feedURL class] isSubclassOfClass: [NSString class]]  ) {
            NSLog(@"Ignoring 'updateFeedURL' preference from 'forced-preferences.plist' because it is not a string");
            feedURL = nil;
        }
    }
    // Otherwise, use the Info.plist entry. We don't check the normal preferences because an unprivileged user can set them and thus
    // could send the update check somewhere it shouldn't go. (For example, to force SurfSafeVPN to ignore an update.)
    
    forcingUnsignedUpdate = FALSE;
    
    if (  feedURL == nil  ) {
        NSString * contentsPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent: @"Contents"];
        NSDictionary * infoPlist = [NSDictionary dictionaryWithContentsOfFile: [contentsPath stringByAppendingPathComponent: @"Info.plist"]];
        feedURL = [infoPlist objectForKey: @"SUFeedURL"];
        if (  feedURL == nil ) {
            NSLog(@"Missing 'SUFeedURL' item in Info.plist");
        } else {
            if (  [[feedURL class] isSubclassOfClass: [NSString class]]  ) {
                // Use 'appcast.rss' normally
                // Use 'appcast-u.rss' to do a normal update check but for an unsigned version.
                // Use 'appcast-f.rss' to _force_ an update to the latest unsigned version, no matter what the build # we currently have
                if (   [feedURL hasPrefix: @"http://tunnelblick.net/"]
                    && [feedURL hasSuffix: @"/appcast.rss"]
                    && ( ! [gTbDefaults boolForKey: @"updateSigned"]) ) {
                    // Have a "standard" update setup at tunnelblick.net and are not forcing a signed version
                    if (   [gConfigDirs containsObject: gDeployPath]  ) {
                        if (  [gFileMgr fileExistsAtPath: [contentsPath stringByAppendingPathComponent: @"_CodeSignature"]]  ) {
                            forcingUnsignedUpdate = TRUE;
                            feedURL = [[feedURL substringToIndex: [feedURL length] - 4] stringByAppendingString: @"-f.rss"];
                            NSLog(@"SurfSafeVPN has a digital signature but also has a Deploy folder");
                        } else {
                            feedURL = [[feedURL substringToIndex: [feedURL length] - 4] stringByAppendingString: @"-u.rss"];
                        }
                    } else {
                        if (   [gFileMgr fileExistsAtPath: [contentsPath stringByAppendingPathComponent: @"_CodeSignature"]]
                            && ( ! [self hasValidSignature])  ) {
                            forcingUnsignedUpdate = TRUE;
                            feedURL = [[feedURL substringToIndex: [feedURL length] - 4] stringByAppendingString: @"-f.rss"];
                            NSLog(@"SurfSafe's digital signature is invalid");
                        } else {
                            if (  [gTbDefaults boolForKey: @"updateUnsigned"]  ) {
                                feedURL = [[feedURL substringToIndex: [feedURL length] - 4] stringByAppendingString: @"-u.rss"];
                                NSLog(@"The 'updateUnsigned' preference is set");
                            }
                        }
                    }	
                }
            } else {
                NSLog(@"Ignoring 'SUFeedURL' item in Info.plist because it is not a string");
                feedURL = nil;
            }
        }
    }
    
    if (  feedURL != nil  ) {
        if (  [updater respondsToSelector: @selector(setFeedURL:)]  ) {
            [updater setFeedURL: [NSURL URLWithString: feedURL]];
            NSLog(@"Setting program update feedURL to %@", feedURL);
        } else {
            feedURL = nil;
            NSLog(@"Not setting program update feedURL preference because Sparkle Updater does not respond to setFeedURL:");
        }
    }
    
    // Set up automatic update checking
    if (  [updater respondsToSelector: @selector(setAutomaticallyChecksForUpdates:)]  ) {
        if (  userIsAdminOrNonAdminsCanUpdate  ) {
            if (  [gTbDefaults objectForKey: @"updateCheckAutomatically"] != nil  ) {
                if (   forcingUnsignedUpdate
                    && [gTbDefaults canChangeValueForKey: @"updateCheckAutomatically"]  ) {
                    [updater setAutomaticallyChecksForUpdates: YES];
                    NSLog(@"Checking for an update because of a problem with SurfSafe's digital signature");
                } else if (  [gTbDefaults boolForKey: @"updateCheckAutomatically"]  ) {
                    [updater setAutomaticallyChecksForUpdates: YES];
                } else {
                    [updater setAutomaticallyChecksForUpdates: NO];
                }
            }
        } else {
            if (  [gTbDefaults boolForKey: @"updateCheckAutomatically"]  ) {
                NSLog(@"Automatic check for updates will not be performed because user is not allowed to administer this computer and 'onlyAdminCanUpdate' preference is set");
            }
            [updater setAutomaticallyChecksForUpdates: NO];
        }
    } else {
        if (  [gTbDefaults boolForKey: @"updateCheckAutomatically"]  ) {
            NSLog(@"Ignoring 'updateCheckAutomatically' preference because Sparkle Updater does not respond to setAutomaticallyChecksForUpdates:");
        }
    }
    
    if (  [updater respondsToSelector: @selector(setAutomaticallyDownloadsUpdates:)]  ) {
        if (  userIsAdminOrNonAdminsCanUpdate  ) {
            if (  [gTbDefaults objectForKey: @"updateAutomatically"] != nil  ) {
                if (  [gTbDefaults boolForKey: @"updateAutomatically"]  ) {
                    [updater setAutomaticallyDownloadsUpdates: YES];
                } else {
                    [updater setAutomaticallyDownloadsUpdates: NO];
                }
            }
        } else {
            if (  [gTbDefaults boolForKey: @"updateAutomatically"]  ) {
                NSLog(@"Automatic updates will not be performed because user is not allowed to administer this computer and 'onlyAdminCanUpdate' preference is set");
            }
            [updater setAutomaticallyDownloadsUpdates: NO];
        }
    } else {
        if (  [gTbDefaults boolForKey: @"updateAutomatically"]  ) {
            NSLog(@"Ignoring 'updateAutomatically' preference because Sparkle Updater does not respond to setAutomaticallyDownloadsUpdates:");
        }
    }
    
    if (  [updater respondsToSelector: @selector(setSendsSystemProfile:)]  ) {
        if (  [gTbDefaults objectForKey: @"updateSendProfileInfo"] != nil  ) {
            [updater setSendsSystemProfile: [gTbDefaults boolForKey:@"updateSendProfileInfo"]];
        }
    } else {
        NSLog(@"Ignoring 'updateSendProfileInfo' preference because Sparkle Updater Updater does not respond to setSendsSystemProfile:");
    }
    
    id checkInterval = [gTbDefaults objectForKey: @"updateCheckInterval"];
    if (  checkInterval  ) {
        if (  [updater respondsToSelector: @selector(setUpdateCheckInterval:)]  ) {
            if (   [[checkInterval class] isSubclassOfClass: [NSNumber class]]
                || [[checkInterval class] isSubclassOfClass: [NSString class]]  ) {
                NSTimeInterval d = [checkInterval doubleValue];
                if (  d == 0.0  ) {
                    NSLog(@"Ignoring 'updateCheckInterval' preference because it is 0 or is not a valid number");
                } else {
                    if (  d < 3600.0  ) {   // Minimum one hour to prevent DOS on the update servers
                        d = 3600.0;
                    }
                    [updater setUpdateCheckInterval: d];
                }
                
            } else {
                NSLog(@"Ignoring 'updateCheckInterval' preference because it is not a string or a number");
            }
        } else {
            NSLog(@"Ignoring 'updateCheckInterval' preference because Sparkle Updater does not respond to setUpdateCheckInterval:");
        }
    }
    
    // Set updater's delegate, so we can add our own info to the system profile Sparkle sends to our website
    // Do this even if we haven't set our preferences (see above), so Sparkle will include our data in the list
    // it presents to the user when asking the user for permission to send the data.
    if (  [updater respondsToSelector: @selector(setDelegate:)]  ) {
        [updater setDelegate: self];
    } else {
        NSLog(@"Cannot set Sparkle delegate because Sparkle Updater does not respond to setDelegate:");
    }
     */
    //[ssUpdater checkForUpdate];
    
    // HTK-INC
    // install update if tool is out of date.
    if (outOfDate){
        [self installSurfSafeUpdateHandler];
    }
}

// If we haven't set up the updateCheckAutomatically, updateSendProfileInfo, and updateAutomatically preferences,
// and the corresponding Sparkle preferences have been set, copy Sparkle's settings to ours
-(void) setupSparklePreferences
{
    NSUserDefaults * stdDefaults = [NSUserDefaults standardUserDefaults];
    
    if (  [gTbDefaults objectForKey: @"updateCheckAutomatically"] == nil  ) {
        if (  [stdDefaults objectForKey: @"SUEnableAutomaticChecks"] != nil  ) {
            [gTbDefaults setBool: [stdDefaults boolForKey: @"SUEnableAutomaticChecks"]
                          forKey: @"updateCheckAutomatically"];
            [gTbDefaults synchronize];
        }
    }
    
    if (  [gTbDefaults objectForKey: @"updateSendProfileInfo"] == nil  ) {
        if (  [stdDefaults objectForKey: @"SUupdateSendProfileInfo"] != nil  ) {
            [gTbDefaults setBool: [stdDefaults boolForKey: @"SUupdateSendProfileInfo"]
                          forKey: @"updateSendProfileInfo"];
            [gTbDefaults synchronize];
        }
    }
    
    // SUAutomaticallyUpdate may be changed at any time by a checkbox in Sparkle's update window, so we always use Sparkle's version
    if (  [stdDefaults objectForKey: @"SUAutomaticallyUpdate"] != nil  ) {
        //[gTbDefaults setBool: [updater automaticallyDownloadsUpdates]       // But if it is forced, this setBool will be ignored
          //            forKey: @"updateAutomatically"];
        [gTbDefaults synchronize];
    }
    
}

-(BOOL) hasValidSignature
{
    if (  ! runningOnLeopardOrNewer()  ) {              // If on Tiger, we can't check the signature, so pretend it is valid
        return TRUE;
    }
    
    NSString * toolPath = @"/usr/bin/codesign";
    if (  ! [gFileMgr fileExistsAtPath: toolPath]  ) {  // If codesign binary doesn't exist, complain and assume it is NOT valid
        NSLog(@"Assuming digital signature invalid because '%@' does not exist", toolPath);
        return FALSE;
    }
    
    NSString * appPath = [[NSBundle mainBundle] bundlePath];
    NSArray *arguments = [NSArray arrayWithObjects:@"-v", appPath, nil];
    
    NSTask* task = [[[NSTask alloc] init] autorelease];
    [task setCurrentDirectoryPath: @"/tmp"];    // Won't be used, but we should specify something
    [task setLaunchPath: toolPath];
    [task setArguments:arguments];
    [task launch];
    [task waitUntilExit];
    OSStatus status = [task terminationStatus];
    return (status == EXIT_SUCCESS);
}

- (NSURL *) getIPCheckURL
{
    NSURL * url = nil;
    NSString * urlString;
	id obj = [gTbDefaults objectForKey: @"IPCheckURL"];
	if (   obj
		&& [[obj class] isSubclassOfClass: [NSString class]]
		&& ( ! [gTbDefaults canChangeValueForKey: @"IPCheckURL"])  ) {
		urlString = (NSString *) obj;
	} else {
        NSDictionary * infoPlist = [[NSBundle mainBundle] infoDictionary];
        urlString = [infoPlist objectForKey: @"IPCheckURL"];
    }
    
    if (  urlString  ) {
        url = [NSURL URLWithString: urlString];
        if (  ! url  ) {
            NSLog(@"Unable to make into a URL: %@", urlString);
        }
    } else {
        NSLog(@"No IPCheckURL forced preference or Info.plist entry");
    }
    
    return url;
}

-(BOOL)applicationShouldHandleReopen: (NSApplication *) theApp hasVisibleWindows: (BOOL) hasWindows
{
	// Invoked when the Dock item is clicked to relaunch Tunnelblick, or it is double-clicked.
	// Just show the VPN Details… window.
	
	(void) theApp;
	(void) hasWindows;
	
	[self openPreferencesWindow: self];
	return NO;
}

- (void) applicationDidFinishLaunching: (NSNotification *)notification
{
	[NSApp callDelegateOnNetworkChange: NO];
    [self installSignalHandler];    
    
    // If checking for updates is enabled, we do a check every time SurfSafeVPN is launched (i.e., now)
    // We also check for updates if we haven't set our preferences yet. (We have to do that so that Sparkle
    // will ask the user whether to check or not, then we set our preferences from that.)
    if (      [gTbDefaults boolForKey:   @"updateCheckAutomatically"]
        || (  [gTbDefaults objectForKey: @"updateCheckAutomatically"] == nil  )
        || forcingUnsignedUpdate
        ) {
        /*
        if (  [updater respondsToSelector: @selector(checkForUpdatesInBackground)]  ) {
            if (  feedURL != nil  ) {
                [updater checkForUpdatesInBackground];
            } else {
                NSLog(@"Not checking for updates because no FeedURL has been set");
            }
        } else {
            NSLog(@"Cannot check for updates because Sparkle Updater does not respond to checkForUpdatesInBackground");
        }
         */
    }
    
    
    // Install configuration updates if any are available
    NSString * installFolder = [CONFIGURATION_UPDATES_BUNDLE_PATH stringByAppendingPathComponent: @"Contents/Resources/Install"];
    if (  [gFileMgr fileExistsAtPath: installFolder]  ) {
        launchFinished = TRUE;  // Fake out openFiles so it installs the .tblk(s) immediately
        [self installConfigurationsUpdateInBundleAtPath: CONFIGURATION_UPDATES_BUNDLE_PATH];
        launchFinished = FALSE;
    }
    
    if (  dotTblkFileList  ) {
        BOOL oldIgnoreNoConfigs = ignoreNoConfigs;
        ignoreNoConfigs = TRUE;
        NSString * text = NSLocalizedString(@"Installing SurfSafeVPN Configurations...", @"Window text");
        [splashScreen setMessage: text];

        [[ConfigurationManager defaultManager] openDotTblkPackages: dotTblkFileList
                                                         usingAuth: gAuthorization
                                           skipConfirmationMessage: YES
                                                 skipResultMessage: YES];
        text = NSLocalizedString(@"Installation finished successfully.", @"Window text");
        [splashScreen setMessage: text];

        ignoreNoConfigs = oldIgnoreNoConfigs;
    }
    
    //[myConfigUpdater startWithUI: NO];    // Start checking for configuration updates in the background (when the application updater is finished)
    
    // Set up to monitor configuration folders
    myQueue = [UKKQueue sharedFileWatcher];
    if (  ! [gTbDefaults boolForKey:@"doNotMonitorConfigurationFolder"]  ) {
        unsigned i;
        for (i = 0; i < [gConfigDirs count]; i++) {
            [self addPath: [gConfigDirs objectAtIndex: i] toMonitorQueue: myQueue];
        }
    }
    [myQueue setDelegate: self];
    [myQueue setAlwaysNotify: YES];
    
    [self activateStatusMenu];
    
    ignoreNoConfigs = NO;    // We should NOT ignore the "no configurations" situation
    
    [self checkNoConfigurations];

    [self hookupToRunningOpenVPNs];
    [self setupHookupWatchdogTimer];
    
    // Make sure the '-onSystemStart' preferences for all connections are consistent with the /Library/LaunchDaemons/...plist file for the connection
    NSEnumerator * connEnum = [[self myVPNConnectionDictionary] objectEnumerator];
    VPNConnection * connection;
    while (  (connection = [connEnum nextObject])  ) {
        if (  ! [connection tryingToHookup]  ) {
            [logScreen validateWhenConnectingForConnection: connection];
        }
    }
    
    // Make sure we have asked the user if we can check the IP info
    if (  ! [gTbDefaults boolForKey: @"askedUserIfOKToCheckThatIPAddressDidNotChangeAfterConnection"]  ) {
        if (  [gTbDefaults canChangeValueForKey: @"notOKToCheckThatIPAddressDidNotChangeAfterConnection"]  ) {
            NSURL * url = [self getIPCheckURL];
            if (  url  ) {
				NSString * host = [url host];
				if (  host  ) {
					int result = TBRunAlertPanel(NSLocalizedString(@"New Feature", @"Window title"),
												 [NSString stringWithFormat:
												  NSLocalizedString(@"SurfSafeVPN can check that the apparent public IP address of your computer"
																	@" changes when you connect to a VPN, and warn you if it doesn't.\n\n"
																	@"This may help SurfSafeVPN diagnose problems with your connection.\n\n"
																	@"This process attempts to access\n"
																	@"%@\n\n"
																	@"Do you wish to check for this IP address change?\n", @"Window text"), host],
												 NSLocalizedString(@"Check for a change", @"Button"),           // Default
												 NSLocalizedString(@"Do not check for a change", @"Button"),    // Alternate
												 nil);
					[gTbDefaults setBool: (result == NSAlertAlternateReturn)
								  forKey: @"notOKToCheckThatIPAddressDidNotChangeAfterConnection"];
					[gTbDefaults setBool: YES
								  forKey: @"askedUserIfOKToCheckThatIPAddressDidNotChangeAfterConnection"];
				} else {
					NSLog(@"Could not extract host from URL: %@", url);
				}
            }
        }
    }
    
    activeIPCheckThreads = [[NSMutableArray alloc] initWithCapacity: 4];
    cancellingIPCheckThreads = [[NSMutableArray alloc] initWithCapacity: 4];
    
    // Process runOnLaunch item
    if (  customRunOnLaunchPath  ) {
        NSTask* task = [[[NSTask alloc] init] autorelease];
        [task setLaunchPath: customRunOnLaunchPath];
        [task setArguments: [NSArray array]];
        [task setCurrentDirectoryPath: [customRunOnLaunchPath stringByDeletingLastPathComponent]];
        [task launch];
        if (  [[[customRunOnLaunchPath stringByDeletingPathExtension] pathExtension] isEqualToString: @"wait"]) {
            [task waitUntilExit];
            int status = [task terminationStatus];
            if (  status != 0  ) {
                NSLog(@"SurfSafeVPN runOnLaunch item %@ returned %d; SurfSafeVPN launch cancelled", customRunOnLaunchPath, status);
                [self terminateBecause: terminatingBecauseOfError];
            }
        }
    }

    // Process connections that should be restored on relaunch (from updating configurations)
    VPNConnection * myConnection;
    NSArray * restoreList = [gTbDefaults objectForKey: @"connectionsToRestoreOnLaunch"];
    if (   restoreList
        && ( [restoreList count] != 0 )  ) {
        NSString * dispNm;
        NSEnumerator * listEnum = [restoreList objectEnumerator];
        while (  (dispNm = [listEnum nextObject])  ) {
            myConnection = [[self myVPNConnectionDictionary] objectForKey: dispNm];
            if (   myConnection
                && ( ! [myConnection isConnected] )  ) {
                [myConnection connect:self userKnows: YES];
            }
        }
        [gTbDefaults removeObjectForKey: @"connectionsToRestoreOnLaunch"];
        [gTbDefaults synchronize];
    }
    
    // Process "Automatically connect on launch" checkboxes (but skip any that were restored on relaunch above)
    NSString * dispNm;
    NSEnumerator * e = [[self myConfigDictionary] keyEnumerator];
    while (   (dispNm = [e nextObject])
           && (   (! restoreList)
               || ( [restoreList indexOfObject: dispNm] == NSNotFound) )  ) {
        myConnection = [[self myVPNConnectionDictionary] objectForKey: dispNm];
        if (  [gTbDefaults boolForKey: [dispNm stringByAppendingString: @"autoConnect"]]  ) {
            if (  ! [gTbDefaults boolForKey: [dispNm stringByAppendingString: @"-onSystemStart"]]  ) {
                if (  ![myConnection isConnected]  ) {
                    [myConnection connect:self userKnows: YES];
                }
            }
        }
    }
    
    [NSApp setAutoLaunchOnLogin: YES];
    
    unsigned kbsIx = [gTbDefaults unsignedIntForKey: @"keyboardShortcutIndex"
                                            default: 1 /* F1     */
                                                min: 0 /* (none) */
                                                max: MAX_HOTKEY_IX];
    
    [self setHotKeyIndex: kbsIx];
    
    // Install easy-rsa if it isn't installed already, or update it if appropriate
    installOrUpdateOurEasyRsa();

    AuthorizationFree(gAuthorization, kAuthorizationFlagDefaults);
    gAuthorization = nil;
    
#ifdef INCLUDE_VPNSERVICE
    if (  vpnService = [[VPNService alloc] init]  ) {
        if (  [vpnService respondsToSelector: @selector(showOnLaunchScreen)]) {
            [vpnService showOnLaunchScreen];
        } else {
            NSLog(@"VPNService enabled but vpnService object does not respond to showOnLaunchScreen");
        }
    } else {
        NSLog(@"VPNService enabled but vpnService object is NULL");
    }
#endif
    
    NSString * prefVersion = [gTbDefaults objectForKey: @"openvpnVersion"];
    if (  prefVersion  ) {
        NSArray * versions = availableOpenvpnVersions();
        if (  ! [versions containsObject: prefVersion]  ) {
            NSString * useVersion;
            if (  [versions count] > 0  ) {
                useVersion = [versions objectAtIndex: [versions count]-1];
            } else {
                NSLog(@"SurfSafeVPN does not include any versions of OpenVPN");
                [self terminateBecause: terminatingBecauseOfError];
                return;
            }
            
            TBRunAlertPanel(NSLocalizedString(@"SurfSafeVPN", @"Window title"),
                            [NSString stringWithFormat: NSLocalizedString(@"OpenVPN version %@ is not available. Using the default, version %@", @"Window text"),
                             prefVersion, useVersion],
                            nil, nil, nil);
            [gTbDefaults removeObjectForKey: @"openvpnVersion"];
        }
    }
    
	[[self ourMainIconView] setOrRemoveTrackingRect];
    
    NSString * text = NSLocalizedString(@"SurfSafeVPN is ready.", @"Window text");
    [splashScreen setMessage: text];

    [splashScreen fadeOutAndClose];
    
    launchFinished = TRUE;
    
}

-(NSString *) fileURLStringWithPath: (NSString *) path
{
    NSString * urlString = [@"file://" stringByAppendingString: path];
    return urlString;
}

// Returns TRUE if a hookupWatchdog timer was created or already exists
-(BOOL) setupHookupWatchdogTimer
{
    if (  hookupWatchdogTimer  ) {
        return TRUE;
    }
    
    
    gHookupTimeout = [gTbDefaults unsignedIntForKey: @"hookupTimeout"
                                            default: 5
                                                min: 0
                                                max: 300];
    if (  gHookupTimeout == 0) {
        return FALSE;
    }
    
    hookupWatchdogTimer = [NSTimer scheduledTimerWithTimeInterval: (NSTimeInterval) gHookupTimeout
                                                           target: self
                                                         selector: @selector(hookupWatchdogHandler)
                                                         userInfo: nil
                                                          repeats: NO];
    return TRUE;
}

-(void) changedMonitorConfigurationFoldersSettings
{
    if (  [gTbDefaults boolForKey: @"doNotMonitorConfigurationFolder"]  ) {
        unsigned i;
        for (i = 0; i < [gConfigDirs count]; i++) {
            [[NSApp delegate] removePath: [gConfigDirs objectAtIndex: i] fromMonitorQueue: myQueue];
        }
    } else {
        unsigned i;
        for (i = 0; i < [gConfigDirs count]; i++) {
            [[NSApp delegate] addPath: [gConfigDirs objectAtIndex: i] toMonitorQueue: myQueue];
        }
        [self activateStatusMenu];
    }
}

-(void) addPath: (NSString *) path toMonitorQueue: (UKKQueue *) queue
{
    // Add the path itself
    [queue addPathToQueue: path];

    // Add folders and subfolders
    NSString * file;
    BOOL isDir;
    NSDirectoryEnumerator * dirEnum = [gFileMgr enumeratorAtPath: path];
    while (  (file = [dirEnum nextObject])  ) {
        if (  ! [file hasSuffix: @".tblk"]  ) {
            NSString * subPath = [path stringByAppendingPathComponent: file];
            if (  [gFileMgr fileExistsAtPath: subPath isDirectory: &isDir]
                && isDir  ) {
                [queue addPathToQueue: subPath];
            }
        }
    }
}

-(void) removePath: (NSString *) path fromMonitorQueue: (UKKQueue *) queue
{
    // Remove the path itself
    [queue removePathFromQueue: path];
    
    // Remove folders and subfolders
    NSString * file;
    BOOL isDir;
    NSDirectoryEnumerator * dirEnum = [gFileMgr enumeratorAtPath: path];
    while (  (file = [dirEnum nextObject])  ) {
        if (  ! [file hasSuffix: @".tblk"]  ) {
            NSString * subPath = [path stringByAppendingPathComponent: file];
            if (  [gFileMgr fileExistsAtPath: subPath isDirectory: &isDir]
                && isDir  ) {
                [queue removePathFromQueue: subPath];
            }
        }
    }
}

-(void) hookupWatchdogHandler
{
    if (  gShuttingDownWorkspace  ) {
        return;
    }
    
    hookupWatchdogTimer = nil;  // NSTimer invalidated it and takes care of releasing it
	[self performSelectorOnMainThread: @selector(hookupWatchdog) withObject: nil waitUntilDone: NO];
}

-(void) hookupWatchdog
{
    // Remove process IDs from the pIDsWeAreTryingToHookUpTo list for connections that have hooked up successfully
    VPNConnection * connection;
    NSEnumerator * connEnum = [[self myVPNConnectionDictionary] objectEnumerator];
    while (  connection = [connEnum nextObject]  ) {
        if (  [connection isHookedup]  ) {
            pid_t thePid = [connection pid];
            if (  thePid != 0  ) {
                NSNumber * processId = [NSNumber numberWithInt: (int) thePid];
                if (  [pIDsWeAreTryingToHookUpTo containsObject: processId]  ) {
                    [pIDsWeAreTryingToHookUpTo removeObject: processId];
                }
            }
        } else {
            [connection stopTryingToHookup];
        }
    }
    
   if (  [pIDsWeAreTryingToHookUpTo count]  ) {
	   if (  ALLOW_OPENVPNSTART_KILL  ) {
        int result = TBRunAlertPanelExtended(NSLocalizedString(@"Warning: Unknown OpenVPN processes", @"Window title"),
                                             NSLocalizedString(@"One or more OpenVPN processes are running but are unknown to SurfSafeVPN. If you are not running OpenVPN separately from SurfSafeVPN, this usually means that an earlier launch of SurfSafeVPN was unable to shut them down properly and you should terminate them. They are likely to interfere with SurfSafeVPN's operation. Do you wish to terminate them?", @"Window text"),
                                             NSLocalizedString(@"Ignore", @"Button"),
                                             NSLocalizedString(@"Terminate", @"Button"),
                                             nil,
                                             @"skipWarningAboutUnknownOpenVpnProcesses",
                                             NSLocalizedString(@"Do not ask again, always 'Ignore'", @"Checkbox name"),
                                             nil,
                                             NSAlertDefaultReturn);
        if (  result == NSAlertAlternateReturn  ) {
            NSNumber * pidNumber;
            NSEnumerator * pidsEnum = [pIDsWeAreTryingToHookUpTo objectEnumerator];
			   while (  (pidNumber = [pidsEnum nextObject])  ) {
                NSString *pidString = [NSString stringWithFormat:@"%d", [pidNumber intValue]];
                NSArray *arguments = [NSArray arrayWithObjects:@"kill", pidString, nil];
				   runOpenvpnstart(arguments, nil, nil);
                noUnknownOpenVPNsRunning = YES;
            }
        }
    } else {
		   TBRunAlertPanel(NSLocalizedString(@"Warning: Unknown OpenVPN processes", @"Window title"),
						   NSLocalizedString(@"One or more OpenVPN processes are running but are unknown"
											 @" to SurfSafeVPN. If you are not running OpenVPN separately"
											 @" from SurfSafeVPN, this usually means that an earlier"
											 @" launch of SurfSafeVPN was unable to shut them down"
											 @" properly and you should terminate them. They are likely"
											 @" to interfere with SurfSafeVPN's operation.\n\n"
											 @"They can be terminated in the 'Activity Monitor' application.\n\n", @"Window text"),
						   nil, nil, nil);
		   noUnknownOpenVPNsRunning = NO;
	   }
   } else {
        noUnknownOpenVPNsRunning = YES;
    }

    [self reconnectAfterBecomeActiveUser];  // Now that we've hooked up everything we can, connect anything else we need to
}

-(void) saveConnectionsToRestoreOnRelaunch
{
    NSMutableArray * restoreList = [NSMutableArray arrayWithCapacity: 8];
    NSEnumerator * connEnum = [[self connectionArray] objectEnumerator];
    VPNConnection * connection;
    while (  (connection = [connEnum nextObject])  ) {
        NSString* autoConnectKey   = [[connection displayName] stringByAppendingString: @"autoConnect"];
        NSString* onSystemStartKey = [[connection displayName] stringByAppendingString: @"-onSystemStart"];
        if (  ! (   [gTbDefaults boolForKey: autoConnectKey]
                 && [gTbDefaults boolForKey: onSystemStartKey] )  ) {
            [restoreList addObject: [connection displayName]];
        }
    }
    
    if (  [restoreList count] != 0) {
        [gTbDefaults setObject: restoreList forKey: @"connectionsToRestoreOnLaunch"];
        [gTbDefaults synchronize];
    }
}

// Sparkle delegate:
// This method allows you to add extra parameters to the appcast URL,
// potentially based on whether or not Sparkle will also be sending along
// the system profile. This method should return an array of dictionaries
// with keys: "key", "value", "displayKey", "displayValue", the latter two
// being human-readable variants of the former two.
- (NSArray *)feedParametersForUpdater:(SUUpdater *) updaterToFeed
                 sendingSystemProfile:(BOOL) sendingProfile
{
    /*
    if (  updaterToFeed == updater  ) {
        if (  ! sendingProfile  ) {
            return [NSArray array];
        }
        
        int nConfigurations    = [[self myConfigDictionary] count];
        int nModifyNameserver  = 0;
        int nMonitorConnection = 0;
        int nPackages          = 0;
        
        NSString * key;
        NSString * path;
        
        // Count # of .tblk packages
        NSEnumerator * e = [[self myConfigDictionary] objectEnumerator];
        while (  path = [e nextObject]  ) {
            NSString * last = lastPartOfPath(path);
            NSString * firstComponent = firstPathComponent(last);
            if (  [[firstComponent pathExtension] isEqualToString: @"tblk"]  ) {
                nPackages++;
            }
        }
        
        // Count # of configurations with 'Set nameserver' checked and the # with 'Monitor connection' set
        e = [[self myConfigDictionary] keyEnumerator];
        while (  key = [e nextObject]  ) {
            NSString * dnsKey = [key stringByAppendingString:@"useDNS"];
            if (  [gTbDefaults objectForKey: dnsKey]  ) {
                if (  [gTbDefaults boolForKey: dnsKey]  ) {
                    nModifyNameserver++;
                }
            } else {
                nModifyNameserver++;
            }
            
            NSString * mcKey = [key stringByAppendingString:@"-notMonitoringConnection"];
            if (  [gTbDefaults objectForKey: mcKey]  ) {
                if (  ! [gTbDefaults boolForKey: mcKey]  ) {
                    nMonitorConnection++;
                }
            } else {
                nMonitorConnection++;
            }
        }
        
        NSString * sConn = [NSString stringWithFormat:@"%d", nConfigurations    ];
        NSString * sSN   = [NSString stringWithFormat:@"%d", nModifyNameserver  ];
        NSString * sPkg  = [NSString stringWithFormat:@"%d", nPackages          ];
        NSString * sMC   = [NSString stringWithFormat:@"%d", nMonitorConnection ];
        NSString * sDep  = ([[gConfigDirs objectAtIndex: 0] isEqualToString: gDeployPath] ? @"1" : @"0");
        NSString * sAdm  = (userIsAnAdmin ? @"1" : @"0");
        NSString * sUuid = [self installationId];
        
        // IMPORTANT: If new keys are added here, they must also be added to profileConfig.php on the website
        //            or the user's data for the new keys will not be recorded in the database.
        
        return [NSArray arrayWithObjects:
                [NSDictionary dictionaryWithObjectsAndKeys:
                 @"nConn",   @"key", sConn, @"value", NSLocalizedString(@"Configurations",      @"Window text" ), @"displayKey", sConn, @"displayValue", nil],
                [NSDictionary dictionaryWithObjectsAndKeys:
                 @"nSetDNS", @"key", sSN,   @"value", NSLocalizedString(@"Set nameserver",      @"PopUpButton" ), @"displayKey", sSN,   @"displayValue", nil],
                [NSDictionary dictionaryWithObjectsAndKeys:
                 @"nPkgs  ", @"key", sPkg,  @"value", NSLocalizedString(@"VPN Connections",     @"Window text" ), @"displayKey", sPkg,  @"displayValue", nil],
                [NSDictionary dictionaryWithObjectsAndKeys:
                 @"nMonCon", @"key", sMC,   @"value", NSLocalizedString(@"Monitor connection", @"Checkbox name"), @"displayKey", sMC,   @"displayValue", nil],
                [NSDictionary dictionaryWithObjectsAndKeys:
                 @"Deploy",  @"key", sDep,  @"value", NSLocalizedString(@"Deployed",           @"Window text"  ), @"displayKey", sDep,  @"displayValue", nil],
                [NSDictionary dictionaryWithObjectsAndKeys:
                 @"Admin",   @"key", sAdm,  @"value", NSLocalizedString(@"Computer admin",     @"Window text"  ), @"displayKey", sAdm,  @"displayValue", nil],
                [NSDictionary dictionaryWithObjectsAndKeys:
                 @"Uuid",    @"key", sUuid, @"value", NSLocalizedString(@"Anonymous unique ID",@"Window text"  ), @"displayKey", sUuid, @"displayValue", nil],
                nil
                ];
    }
    
    NSLog(@"feedParametersForUpdater: invoked with unknown 'updaterToFeed' = %@", updaterToFeed);
    return [NSArray array];
     */
    return nil;
}

// Sparkle delegate:
- (void)updater:(SUUpdater *)theUpdater willInstallUpdate:(SUAppcastItem *)update
{
	(void) theUpdater;
	(void) update;
	
	[gTbDefaults removeObjectForKey: @"skipWarningAboutInvalidSignature"];
	[gTbDefaults removeObjectForKey: @"skipWarningAboutNoSignature"];
	
    reasonForTermination = terminatingBecauseOfQuit;
    
    [NSApp setAutoLaunchOnLogin: NO];
    terminatingAtUserRequest = TRUE;

    NSLog(@"updater:willInstallUpdate: Starting cleanup.");
    if (  [self cleanup]  ) {
        NSLog(@"updater:willInstallUpdate: Cleanup finished.");
    } else {
        NSLog(@"updater:willInstallUpdate: Cleanup already being done.");
    }
    
    // DO NOT UNLOCK cleanupMutex --
    // We do not want to execute cleanup a second time, because:
    //     (1) We've already just run it and thus cleaned up everything, and
    //     (2) The newly-installed openvpnstart won't be secured and thus will fail
}

- (NSString *)installationId
{
    NSString * installationIdKey = @"installationUID";
    
    NSString *uuid = [gTbDefaults objectForKey:installationIdKey];
    
    if (uuid == nil) {
        uuid_t buffer;
        uuid_generate(buffer);
        char str[37];   // 36 bytes plus trailing \0
        uuid_unparse_upper(buffer, str);
        uuid = [NSString stringWithFormat:@"%s", str];
        [gTbDefaults setObject: uuid
                        forKey: installationIdKey];
    }
    return uuid;
}


-(void) setPIDsWeAreTryingToHookUpTo: (NSArray *) newValue
{
    if (  pIDsWeAreTryingToHookUpTo != newValue) {
        [pIDsWeAreTryingToHookUpTo release];
        pIDsWeAreTryingToHookUpTo = [newValue mutableCopy];
    }
}

// This method tries to "hook up" to any running OpenVPN processes.
//
// (If no OpenVPN processes exist, there's nothing to hook up to, so we skip all this)
//
// It searches for files in the log directory with names of A.B.C.openvpn.log, where
// A is the path to the configuration file (with -- instead of dashes and -/ instead of slashes)
// B is the arguments that openvpnstart was invoked with, separated by underscores
// C is the management port number
// The file contains the OpenVPN log.
//
// The [connection tryToHookupToPort:] method corresponding to the configuration file is used to set
// the connection's port # and initiate communications to get the process ID for that instance of OpenVPN
//
// Returns TRUE if started trying to hook up to one or more running OpenVPN processes

-(BOOL) hookupToRunningOpenVPNs
{
    BOOL tryingToHookupToOpenVPN = FALSE;
    
    [self setPIDsWeAreTryingToHookUpTo: [NSApp pIdsForOpenVPNMainProcesses]];
    if (  [pIDsWeAreTryingToHookUpTo count] != 0  ) {
        NSString * filename;
        NSDirectoryEnumerator * dirEnum = [gFileMgr enumeratorAtPath: L_AS_T_LOGS];
        while (  (filename = [dirEnum nextObject])  ) {
            [dirEnum skipDescendents];
            NSString * oldFullPath = [L_AS_T_LOGS stringByAppendingPathComponent: filename];
            if (  [[filename pathExtension] isEqualToString: @"log"]) {
                if (  [[[filename stringByDeletingPathExtension] pathExtension] isEqualToString: @"openvpn"]) {
                    unsigned port = 0;
                    NSString * startArguments = nil;
                    NSString * cfgPath = [self deconstructOpenVPNLogPath: oldFullPath
                                                                  toPort: &port
                                                             toStartArgs: &startArguments];
                    NSArray * keysForConfig = [[self myConfigDictionary] allKeysForObject: cfgPath];
                    unsigned long keyCount = [keysForConfig count];
                    if (  keyCount == 0  ) {
                        NSLog(@"No keys in myConfigDictionary for %@", cfgPath);
                    } else {
                        if (  keyCount != 1  ) {
                            NSLog(@"Using first of %ld keys in myConfigDictionary for %@", keyCount, cfgPath);
                        }
                        NSString * displayName = [keysForConfig objectAtIndex: 0];
                        VPNConnection * connection = [[self myVPNConnectionDictionary] objectForKey: displayName];
                        if (  connection  ) {
                            [connection tryToHookupToPort: port withOpenvpnstartArgs: startArguments];
                            tryingToHookupToOpenVPN = TRUE;
                        }
                    }
                }
            }
        }
    }
    
    return tryingToHookupToOpenVPN;
}

// Returns a configuration path (and port number and the starting arguments from openvpnstart) from a path created by openvpnstart
-(NSString *) deconstructOpenVPNLogPath: (NSString *) logPath toPort: (unsigned *) portPtr toStartArgs: (NSString * *) startArgsPtr
{
    NSString * prefix = [NSString stringWithFormat:@"%@/", L_AS_T_LOGS];
    NSString * suffix = @".openvpn.log";
    if (  [logPath hasPrefix: prefix]  ) {
        if (  [logPath hasSuffix: suffix]  ) {
            unsigned prefixLength = [prefix length];
            NSRange r = NSMakeRange(prefixLength, [logPath length] - prefixLength - [suffix length]);
            NSString * withoutPrefixOrDotOpenvpnDotLog = [logPath substringWithRange: r];
            NSString * withoutPrefixOrPortOrOpenvpnDotLog = [withoutPrefixOrDotOpenvpnDotLog stringByDeletingPathExtension];
            NSString * startArguments = [withoutPrefixOrPortOrOpenvpnDotLog pathExtension];
            if (  startArguments  ) {
                if (  ! ( [startArguments isEqualToString: @"ovpn"] || [startArguments isEqualToString: @"conf"] )  ) {
                    *startArgsPtr = startArguments;
                }
            }
            NSString * portString = [withoutPrefixOrDotOpenvpnDotLog pathExtension];
            int port = [portString intValue];
            if (   port != 0
                && port != INT_MAX
                && port != INT_MIN  ) {
                
                *portPtr = (unsigned)port;
                
                NSMutableString * cfg = [[withoutPrefixOrPortOrOpenvpnDotLog stringByDeletingPathExtension] mutableCopy];
                [cfg replaceOccurrencesOfString: @"-S" withString: @"/" options: 0 range: NSMakeRange(0, [cfg length])];
                [cfg replaceOccurrencesOfString: @"--" withString: @"-" options: 0 range: NSMakeRange(0, [cfg length])];
                [cfg replaceOccurrencesOfString: @".tblk/Contents/Resources/config.ovpn" withString: @".tblk" options: 0 range: NSMakeRange(0, [cfg length])];
                NSString * returnVal = [[cfg copy] autorelease];
                [cfg release];
                
                return returnVal;
            } else {
                NSLog(@"deconstructOpenVPNLogPath: called with invalid port number in path %@", logPath);
                return @"";
            }
        } else {
            NSLog(@"deconstructOpenVPNLogPath: called with non-log path %@", logPath);
            return @"";
        }
    } else {
        NSLog(@"deconstructOpenVPNLogPath: called with invalid prefix to path %@", logPath);
        return @"";
    }
}

-(unsigned) incrementTapCount
{
    return ++tapCount;
}

-(unsigned) incrementTunCount
{
    return ++tunCount;
}

-(unsigned) decrementTapCount
{
    return --tapCount;
}

-(unsigned) decrementTunCount
{
    return --tunCount;
}

int warnAndReinstallOrQuit(void)
{
    return TBRunAlertPanel(NSLocalizedString(@"Installing SurfSafeVPN", @"Window title"),
    
						   NSLocalizedString(@"SurfSafeVPN must be installed in Applications on"
                                             @" the startup disk.\n\n"
    
                                             @"Before installing SurfSafeVPN in Applications, which"
                                             @" will include migrating a Deployed configuration, you"
                                             @" should backup your computer.\n\n"
    
											 @"Should SurfSafeVPN be installed in Applications?",
											 @"Window text"),
    
						   NSLocalizedString(@"Move to Applications", @"Button"), // Default button
						   NSLocalizedString(@"Quit", @"Button"),                 // Alternate button
						   nil);
        }
        
void warnAboutMultiplesAndQuit(void)
{
    TBRunAlertPanel(NSLocalizedString(@"SECURITY WARNING", @"Window title"),
                    
                    NSLocalizedString(@"THIS COMPUTER IS NOT SECURE because SurfSafeVPN"
                                      @" is not installed in Applications.\n\n"
                                      
                                      @"This computer has had Deployed versions of SurfSafeVPN installed in"
                                      @" more than one location and some locations have had different sets"
                                      @" of configurations. This is no longer allowed. Only one"
                                      @" Deployed version of SurfSafeVPN may be installed, it must be installed"
                                      @" in Applications, and only one set of Deployed configurations will be"
                                      @" available.\n\n"
                                      
                                      @"Before this version of SurfSafeVPN can be installed, all other copies of"
                                      @" SurfSafeVPN must be deleted from this computer.\n\n"
                                      
                                      @"DELETING COPIES OF TUNNELBLICK MAY MAKE SOME VPN SERVERS UNAVAILABLE.\n\n"
                                      
                                      @" For more information, please see\n"
                                      @"http://code.google.com/p/tunnelblick/wiki/cMultiDeploy\n\n", @"Window text"),
                    
                    NSLocalizedString(@"Quit", @"Button"),  // Default button
                    nil,                                    // Alternate button
                                   nil);
}
        
BOOL anyNonTblkConfigs(void)
{
	// Returns TRUE if there were any private non-tblks (and they need to be converted)
    NSString * file;
    NSDirectoryEnumerator *dirEnum = [gFileMgr enumeratorAtPath: gPrivatePath];
    while (  (file = [dirEnum nextObject])  ) {
        NSString * fullPath = [gPrivatePath stringByAppendingPathComponent: file];
        if (  itemIsVisible(fullPath)  ) {
			NSString * ext = [file pathExtension];
            if (  [ext isEqualToString: @"tblk"]  ) {
				[dirEnum skipDescendents];
            } else {
				if (   [ext isEqualToString: @"ovpn"]
					|| [ext isEqualToString: @"conf"]  ) {
					return YES;
				}
			}
		}
	}
        
	return NO;
}

/*BOOL warnAboutNonTblks(void)
{
	// Returns TRUE if there were any private non-tblks and the user has agreed to convert them

	if (  anyNonTblkConfigs() ) {
		int response = TBRunAlertPanelExtended(NSLocalizedString(@"SurfSafeVPN VPN Configuration Installation", @"Window title"),
											   NSLocalizedString(@"You have one or more OpenVPN configurations that will not be available"
                                                                 @" when using this version of SurfSafeVPN. You can:\n\n"
																 @"     • Let SurfSafeVPN convert these OpenVPN configurations to SurfSafeVPN VPN Configurations; or\n"
                                                                 @"     • Quit and install a different version of SurfSafeVPN; or\n"
                                                                 @"     • Ignore this and continue without converting.\n\n", @"Window text"),
											   NSLocalizedString(@"Convert Configurations", @"Button"),
											   NSLocalizedString(@"Ignore", @"Button"),
											   NSLocalizedString(@"Quit", @"Button"),
											   @"skipWarningAboutConvertingToTblks",
											   NSLocalizedString(@"Do not ask again, always convert", @"Checkbox name"),
                                nil,
											   NSAlertDefaultReturn);
		gUserWasAskedAboutConvertNonTblks = TRUE;
		if (  response == NSAlertOtherReturn  ) {
			[[NSApp delegate] terminateBecause: terminatingBecauseOfQuit];
            }
		
		if (  response == NSAlertDefaultReturn  ) {
			return YES;
        }
    }
	
	return NO;
}
*/
-(void) initialChecks
{
    [NSApp setAutoLaunchOnLogin: NO];
    
    if (   tunnelblickTestHasDeployBackups()
		|| tunnelblickTestDeployed()) {
        TBRunAlertPanel(NSLocalizedString(@"System Requirements Not Met", @"Window title"),
                        NSLocalizedString(@"This version of SurfSafeVPN cannot be installed because it is a Deployed version"
										  @" or one or more 'Deployed' versions"
                                          @" of SurfSafeVPN have already been installed.\n\n", @"Window text"),
                        nil,nil,nil);
        
        [self terminateBecause: terminatingBecauseOfQuit];
    }
	   
    // If necessary, (re)install Tunnelblick in /Applications
    [self relaunchIfNecessary];  // (May not return from this)
    
	[self secureIfNecessary];
}

-(void) warnIfInvalidOrNoSignatureAllowCheckbox: (BOOL) allowCheckbox
{
	NSString * checkboxPrefKey = nil;
	NSString * checkboxText    = nil;
	
	NSString * contentsPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent: @"Contents"];
	if (   [gFileMgr fileExistsAtPath: [contentsPath stringByAppendingPathComponent: @"_CodeSignature"]]  ) {
		if (  signatureIsInvalid  ) {
			
			if (  allowCheckbox  ) {
				checkboxPrefKey = @"skipWarningAboutInvalidSignature";
				checkboxText    = NSLocalizedString(@"Do not ask again, always Continue", @"Checkbox name");
			}
			
			int result = TBRunAlertPanelExtended(NSLocalizedString(@"Warning!", @"Window title"),
												 NSLocalizedString(@"This copy of SurfSafeVPN has been tampered with (the"
																   @" digital signature is invalid).\n\n"
																   @"Please check with the provider of this copy of SurfSafeVPN before"
																   @" using it.\n\n", @"Window text"),
												 NSLocalizedString(@"Quit", @"Button"),
												 nil,
												 NSLocalizedString(@"Continue", @"Button"),
												 checkboxPrefKey,
												 checkboxText,
												 nil,
												 NSAlertOtherReturn);
			if (  result == NSAlertDefaultReturn  ) {
				[self terminateBecause: terminatingBecauseOfQuit];
			}
		}
#ifndef TBDebug
	} else {
		if (  allowCheckbox  ) {
			checkboxPrefKey = @"skipWarningAboutNoSignature";
			checkboxText    = NSLocalizedString(@"Do not ask again, always Continue", @"Checkbox name");
		}
		
		int result = TBRunAlertPanelExtended(NSLocalizedString(@"Warning!", @"Window title"),
											 NSLocalizedString(@"This copy of SurfSafeVPN is not digitally signed.\n\n"
															   @"There is no way to verify that this copy has not been tampered with.\n\n"
															   @" Check with the the provider of this copy of SurfSafeVPN before"
															   @" using it.\n\n", @"Window text"),
											 NSLocalizedString(@"Quit", @"Button"),
											 nil,
											 NSLocalizedString(@"Continue", @"Button"),
											 checkboxPrefKey,
											 checkboxText,
											 nil,
											 NSAlertOtherReturn);
		if (  result == NSAlertDefaultReturn  ) {
			[self terminateBecause: terminatingBecauseOfQuit];
		}
#endif
	}
    
}

-(void) relaunchIfNecessary
{
	NSString * contentsPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent: @"Contents"];
    if (   [gFileMgr fileExistsAtPath: [contentsPath stringByAppendingPathComponent: @"_CodeSignature"]]
		&& ( ! [self hasValidSignature] )  ) {
		signatureIsInvalid = TRUE;
	} else {
		signatureIsInvalid = FALSE;	// (But it might not have one)
	}
	
    // Move or copy Tunnelblick.app to /Applications if it isn't already there
    
	NSString * currentPath = [[NSBundle mainBundle] bundlePath];
        
    BOOL canRunOnThisVolume = [self canRunFromVolume: currentPath];
    
    if (  canRunOnThisVolume ) {
#ifdef TBDebug
        NSLog(@"SurfSafeVPN: WARNING: This is an insecure copy of SurfSafeVPN to be used for debugging only!");
        [self warnIfInvalidOrNoSignatureAllowCheckbox: YES];
        return;
#endif
        if (  [currentPath isEqualToString: @"/Applications/SurfSafeVPN.app"]  ) {
			[self warnIfInvalidOrNoSignatureAllowCheckbox: YES];
            return;
        } else {
            NSLog(@"SurfSafeVPN can only run when it is in /Applications, not %@.", currentPath);
        }
    } else {
        NSLog(@"SurfSafeVPN cannot run when it is on /%@ because the volume has the MNT_NOSUID statfs flag set.", [[currentPath pathComponents] objectAtIndex: 1]);
    }
    
    // Not installed in /Applications on a runnable volume. Need to move/install to /Applications
    
    //tempoarary disabled code signing check
	//[self warnIfInvalidOrNoSignatureAllowCheckbox: NO];
	
    // If no gDeployPath folder exists, we may not have dealt with L_AS_T/Backup
    if (   ( ! [gFileMgr fileExistsAtPath: gDeployPath])
        && [gFileMgr fileExistsAtPath: L_AS_T_BACKUP]  ) {
        
        NSArray * nonduplicateDeployBackupPaths = pathsForLatestNonduplicateDeployBackups();
        if (  ! nonduplicateDeployBackupPaths  ) {
            NSLog(@"An error occurred checking for non-duplicated Deploy backup paths");
            exit(EXIT_FAILURE);
        }
        
        if (  [nonduplicateDeployBackupPaths count] > 1  ) {
            
            // Multiple Deploy backups that aren't duplicates of each other. Explain and quit
            
            warnAboutMultiplesAndQuit();
            [self terminateBecause: terminatingBecauseOfQuit];
        
        } else if (   ([nonduplicateDeployBackupPaths count] == 1)
				   && ( ! [gFileMgr fileExistsAtPath: [[NSBundle mainBundle]
													  pathForResource: @"Deploy" ofType: nil]])  ) {
        
            // No Deploy in this app, but one Deployed backup (or a bunch of duplicates), which installer will deal with.
            //
            // If there is a Deploy in this Tunnelblick, it will also be dealt with by the installer.
            //
            // So we let the user (re)install in /Applications or quit
            // after warning the user to back up before (re)installing 
            
            if (  warnAndReinstallOrQuit() == NSAlertAlternateReturn ) {
                [self terminateBecause: terminatingBecauseOfQuit];
            }
        }
		
		// No Deployed backups and/or Deploy in the app
		//
		// If there is a Deploy in this Tunnelblick, it will be dealt with by the installer.
		//
		// So we fall through to copy to /Applications
	}
                
    //Install into /Applications
	
    // Set up message about installing .tblks on the .dmg
    NSString * tblksMsg;
    NSArray * tblksToInstallPaths = [self findTblksToInstallInPath: [currentPath stringByDeletingLastPathComponent]];
    if (  tblksToInstallPaths  ) {
        tblksMsg = [NSString stringWithFormat: NSLocalizedString(@"\n\nand install %ld SurfSafeVPN VPN Configurations", @"Window text"),
                    (long) [tblksToInstallPaths count]];
    } else {
        tblksMsg = @"";
    }
    
    // Set up messages to get authorization and notify of success
	NSString * appVersion   = surfsafevpnVersion([NSBundle mainBundle]);
    NSString * tbInApplicationsPath = @"/Applications/Tunnelblick.app";
        NSString * applicationsPath = @"/Applications";
        NSString * tbInApplicationsDisplayName = [[gFileMgr componentsToDisplayForPath: tbInApplicationsPath] componentsJoinedByString: @"/"];
        NSString * applicationsDisplayName = [[gFileMgr componentsToDisplayForPath: applicationsPath] componentsJoinedByString: @"/"];
        
        NSString * launchWindowTitle = NSLocalizedString(@"Installation succeeded", @"Window title");
        NSString * launchWindowText;
        NSString * authorizationText;
        
	NSString * signatureWarningText;
	if (  signatureIsInvalid  ) {
		signatureWarningText = NSLocalizedString(@" WARNING: This copy of SurfSafeVPN has been tampered with.\n\n", @"Window text");
	} else {
		signatureWarningText = @"";
	}
	
	NSString * convertTblksText;
    {
		convertTblksText = @"";
        }
        
        if (  [gFileMgr fileExistsAtPath: tbInApplicationsPath]  ) {
            NSBundle * previousBundle = [NSBundle bundleWithPath: tbInApplicationsPath];
            NSString * previousVersion = surfsafevpnVersion(previousBundle);
                authorizationText = [NSString stringWithFormat:
                             NSLocalizedString(@" Do you wish to replace\n    %@\n    in %@\nwith %@%@?\n\n", @"Window text"),
                             previousVersion, applicationsDisplayName, appVersion, tblksMsg];
        launchWindowText = NSLocalizedString(@"SurfSafeVPN was successfully replaced.\n\nDo you wish to launch the new version of SurfSafeVPN now?", @"Window text");
        } else {
            authorizationText = [NSString stringWithFormat:
                             NSLocalizedString(@" Do you wish to install %@ to %@%@?\n\n", @"Window text"),
                             appVersion, applicationsDisplayName, tblksMsg];
        launchWindowText = NSLocalizedString(@"SurfSafeVPN was successfully installed.\n\nDo you wish to launch SurfSafeVPN now?", @"Window text");
        }
        
        // Get authorization to install and secure
    gAuthorization = [NSApplication getAuthorizationRef:
                      [[[NSLocalizedString(@" SurfSafeVPN must be installed in Applications.\n\n", @"Window text")
						 stringByAppendingString: authorizationText]
                        stringByAppendingString: convertTblksText]
					   stringByAppendingString: signatureWarningText]
					  ];
        if (  ! gAuthorization  ) {
		NSLog(@"The SurfSafeVPN installation was cancelled by the user.");
		[self terminateBecause: terminatingBecauseOfQuit];
        }
        
        // Stop any currently running SurfSafeVPNs
        int numberOfOthers = [NSApp countOtherInstances];
        while (  numberOfOthers > 0  ) {
            int button = TBRunAlertPanel(NSLocalizedString(@"SurfSafeVPN is currently running", @"Window title"),
                                         NSLocalizedString(@"You must stop the currently running SurfSafeVPN to launch the new copy.\n\nClick \"Close VPN Connections and Stop SurfSafeVPN\" to close all VPN connections and quit the currently running SurfSafeVPN before launching SurfSafeVPN.", @"Window text"),
                                         NSLocalizedString(@"Close VPN Connections and Stop SurfSafeVPN", @"Button"), // Default button
                                         NSLocalizedString(@"Cancel",  @"Button"),   // Alternate button
                                         nil);
            if (  button == NSAlertAlternateReturn  ) {
            [self terminateBecause: terminatingBecauseOfQuit];
            }
            
            [NSApp killOtherInstances];
            
            numberOfOthers = [NSApp countOtherInstances];
            if (  numberOfOthers > 0  ) {
                int i = 0;
                do {
                    sleep(1);
                    i++;
                    numberOfOthers = [NSApp countOtherInstances];
                } while (   (numberOfOthers > 0)
                         && (i < 10)  );
            }
        }
        
        // If there was a problem finding other instances of SurfSafeVPN, log it but continue anyway
        if (  numberOfOthers == -1  ) {
            NSLog(@"Error: [NSApp countOtherInstances] returned -1");
        }
        
    [splashScreen setMessage: NSLocalizedString(@"Installing and securing SurfSafeVPN...", @"Window text")];
        
        // Install .tblks
        if (  tblksToInstallPaths  ) {
            // Install the .tblks
            launchFinished = TRUE;  // Fake out openFiles so it installs the .tblk(s) immediately
            [self application: NSApp openFiles: tblksToInstallPaths];
            launchFinished = FALSE;
        }
        
	[gTbDefaults removeObjectForKey: @"skipWarningAboutInvalidSignature"];
	[gTbDefaults removeObjectForKey: @"skipWarningAboutNoSignature"];
    
        // Install this program and secure it
    if (  ! [self runInstaller: (  INSTALLER_COPY_APP
                                 | INSTALLER_COPY_BUNDLE
                                 | INSTALLER_SECURE_APP
                                 | INSTALLER_SECURE_TBLKS
                                 | (needToMoveLibraryOpenVPN()
                                    ? INSTALLER_MOVE_LIBRARY_OPENVPN
                                    : 0)
                                 | (needToUpdateDeploy()
                                    ? INSTALLER_UPDATE_DEPLOY
                                    : 0)
                                 )
                extraArguments: nil]  ) {
        // An error dialog and a message in the console log have already been displayed if an error occurred
        [self terminateBecause: terminatingBecauseOfError];
        }
        
        // Install configurations from SurfSafeVPN Configurations.bundle if any were copied
        NSString * installFolder = [CONFIGURATION_UPDATES_BUNDLE_PATH stringByAppendingPathComponent: @"Contents/Resources/Install"];
        if (  [gFileMgr fileExistsAtPath: installFolder]  ) {
            NSString * text = NSLocalizedString(@"Installing SurfSafeVPN Configurations...", @"Window text");
            [splashScreen setMessage: text];
            launchFinished = TRUE;  // Fake out openFiles so it installs the .tblk(s) immediately
            [self installConfigurationsUpdateInBundleAtPath: CONFIGURATION_UPDATES_BUNDLE_PATH];
            launchFinished = FALSE;
        }
        
    [splashScreen setMessage: NSLocalizedString(@"Installation finished successfully.", @"Window text")];
    int response = TBRunAlertPanel(launchWindowTitle,
                                   launchWindowText,
                                   NSLocalizedString(@"Launch", "Button"), // Default button
                                   NSLocalizedString(@"Quit", "Button"), // Alternate button
                                   nil);
        
        [splashScreen fadeOutAndClose];
        
        if (  response == NSAlertDefaultReturn  ) {
            // Launch the program in /Applications
            if (  ! [[NSWorkspace sharedWorkspace] launchApplication: tbInApplicationsPath]  ) {
                TBRunAlertPanel(NSLocalizedString(@"Unable to launch SurfSafeVPN", @"Window title"),
                                [NSString stringWithFormat: NSLocalizedString(@"An error occurred while trying to launch %@", @"Window text"), tbInApplicationsDisplayName],
                                NSLocalizedString(@"Cancel", @"Button"),                // Default button
                                nil,
                                nil);
            }
        }
        
    [self terminateBecause: terminatingBecauseOfQuit];
}

-(NSArray *) findTblksToInstallInPath: (NSString *) thePath
{
    NSMutableArray * arrayToReturn = nil;
    NSString * file;
    BOOL isDir;
    
    NSString * folder = [thePath stringByAppendingPathComponent: @"auto-install"];
    NSDirectoryEnumerator * dirEnum = [gFileMgr enumeratorAtPath: folder];
    while (  (file = [dirEnum nextObject])  ) {
        [dirEnum skipDescendents];
        if (   [gFileMgr fileExistsAtPath: [folder stringByAppendingPathComponent: file] isDirectory: &isDir]
            && isDir
            && [[file pathExtension] isEqualToString: @"tblk"]  ) {
            if (  arrayToReturn == nil  ) {
                arrayToReturn = [NSMutableArray arrayWithCapacity:10];
            }
            [arrayToReturn addObject: [folder stringByAppendingPathComponent: file]];
        }
    }
    
    folder = [thePath stringByAppendingPathComponent: @".auto-install"];
    dirEnum = [gFileMgr enumeratorAtPath: folder];
    while (  (file = [dirEnum nextObject])  ) {
        [dirEnum skipDescendents];
        if (  [[file pathExtension] isEqualToString: @"tblk"]  ) {
            if (  arrayToReturn == nil  ) {
                arrayToReturn = [NSMutableArray arrayWithCapacity:10];
            }
            [arrayToReturn addObject: [folder stringByAppendingPathComponent: file]];
        }
    }
    
    return [[arrayToReturn copy] autorelease];
}

// Returns TRUE if can run SurfSafeVPN from this volume (can run setuid binaries) or if statfs on it fails, FALSE otherwise
-(BOOL) canRunFromVolume: (NSString *)path
{
    if ([path hasPrefix:@"/Volumes/SurfSafeSetup"]  ) {
        return FALSE;
    }
    
    const char * fileName = [gFileMgr fileSystemRepresentationWithPath: path];
    struct statfs stats_buf;
    
    if (  0 == statfs(fileName, &stats_buf)  ) {
        if (  (stats_buf.f_flags & MNT_NOSUID) == 0  ) {
            return TRUE;
        }
    } else {
        NSLog(@"statfs on %@ failed; assuming cannot run from that volume\nError was '%s'", path, strerror(errno));
    }
    return FALSE;   // Network volume or error accessing the file's data.
}

-(void) secureIfNecessary
{
    // If necessary, run the installer to secure this copy of SurfSafeVPN
    unsigned installFlags;
    if (  (installFlags = needToRunInstaller(FALSE)) != 0  ) {
        
        [splashScreen setMessage: NSLocalizedString(@"Securing SurfSafeVPN...", @"Window text")];
        
        if (  ! [self runInstaller: installFlags
                    extraArguments: nil]  ) {
            
			// An error dialog and a message in the console log have already been displayed if an error occurred
            [self terminateBecause: terminatingBecauseOfError];
        }
		
        [splashScreen setMessage: NSLocalizedString(@"SurfSafeVPN has been secured successfully.", @"Window text")];
    }
}

// Invoked when a folder containing configurations has changed.
-(void) watcher: (UKKQueue*) kq receivedNotification: (NSString*) nm forPath: (NSString*) fpath {
	(void) kq;
	(void) nm;
	(void) fpath;
		
    if (  ! ignoreNoConfigs  ) {
        [self performSelectorOnMainThread: @selector(activateStatusMenu) withObject: nil waitUntilDone: YES];
    }
}

-(BOOL) runInstaller: (unsigned) installFlags
      extraArguments: (NSArray *) extraArguments
{
    return [self runInstaller: installFlags extraArguments: extraArguments usingAuthRefPtr: &gAuthorization message: nil];
}

-(BOOL) runInstaller: (unsigned) installFlags
      extraArguments: (NSArray *) extraArguments
     usingAuthRefPtr: (AuthorizationRef *) authRefPtr
             message: (NSString *) message
{
    // Returns TRUE if installer ran successfully and does not need to be run again, FALSE otherwise
    
    if (   (installFlags == 0)
		&& (extraArguments == nil)  ) {
		NSLog(@"runInstaller:extraArguments invoked but no action specified");
        return YES;
    }
    
    if (  installFlags & INSTALLER_COPY_APP  ) {
        installFlags = installFlags | INSTALLER_SECURE_TBLKS;
    }
    
    BOOL authRefIsLocal;
    AuthorizationRef localAuthRef = NULL;
    if (  authRefPtr == nil  ) {
        authRefPtr = &localAuthRef;
        authRefIsLocal = TRUE;
    } else {
        authRefIsLocal = FALSE;
    }
    
    if (  *authRefPtr == nil  ) {
        NSMutableString * msg;
        if (  message  ) {
            msg = [[message mutableCopy] autorelease];
        } else {
            msg = [NSMutableString stringWithString: NSLocalizedString(@"SurfSafeVPN needs to:\n", @"Window text")];
            if (    installFlags & INSTALLER_COPY_APP              ) [msg appendString: NSLocalizedString(@"  • Be installed in /Applications\n", @"Window text")];
            if (    installFlags & INSTALLER_SECURE_APP            ) [msg appendString: NSLocalizedString(@"  • Change ownership and permissions of the program to secure it\n", @"Window text")];
            if (    installFlags & INSTALLER_MOVE_LIBRARY_OPENVPN  ) [msg appendString: NSLocalizedString(@"  • Update the private configurations folder\n", @"Window text")];
            if (    installFlags & INSTALLER_UPDATE_DEPLOY         ) [msg appendString: NSLocalizedString(@"  • Update configuration(s)\n", @"Window text")];
            if (    installFlags & INSTALLER_CONVERT_NON_TBLKS     ) [msg appendString: NSLocalizedString(@"  • Convert OpenVPN configurations\n", @"Window text")];
            if (   (installFlags & INSTALLER_SECURE_TBLKS)
                || (installFlags & INSTALLER_COPY_BUNDLE)          ) [msg appendString: NSLocalizedString(@"  • Secure configurations\n", @"Window text")];
        }
        
#ifdef TBDebug
        [msg appendString: NSLocalizedString(@"\n WARNING: THIS COPY OF TUNNELBLICK MAKES YOUR COMPUTER INSECURE."
                                             @" It is for debugging purposes only.\n", @"Window text")];
#endif
		
		if (  signatureIsInvalid  ) {
			[msg appendString: NSLocalizedString(@"\n WARNING: THIS COPY OF TUNNELBLICK HAS BEEN TAMPERED WITH.\n", @"Window text")];
		}
    
        NSLog(@"%@", msg);
        
        // Get an AuthorizationRef and use executeAuthorized to run the installer
        *authRefPtr = [NSApplication getAuthorizationRef: msg];
        if(  *authRefPtr == NULL  ) {
            NSLog(@"Installation or repair cancelled");
            return FALSE;
        }
        
        // NOTE: We do NOT free gAuthorization here. It may be used to install .tblk packages, so we free it when we
        // are finished launching, in applicationDidFinishLaunching
    }
    
    NSLog(@"Beginning installation or repair");

    NSString *launchPath = [[NSBundle mainBundle] pathForResource:@"installer" ofType:nil];

	installFlags = installFlags | INSTALLER_CLEAR_LOG;
	
    BOOL okNow = FALSE;
    unsigned i;
    for (i=0; i<5; i++) {
        if (  i != 0  ) {
            usleep( i * 1000000 );	// Sleep for 1.0, 2.0, 3.0, and 4.0 seconds (total 8.0 seconds)
            NSLog(@"Retrying execution of installer");
        }
        
		NSMutableArray * arguments = [[[NSMutableArray alloc] initWithCapacity:3] autorelease];
		[arguments addObject: [NSString stringWithFormat: @"%u", installFlags]];
                
		NSString * arg;
		NSEnumerator * e = [extraArguments objectEnumerator];
		while (  (arg = [e nextObject])  ) {
			[arguments addObject: arg];
            }
            
		installFlags = installFlags & ( ~ INSTALLER_CLEAR_LOG );
		
        if (  [NSApplication waitForExecuteAuthorized: launchPath withArguments: arguments withAuthorizationRef: *authRefPtr] ) {
            okNow = needToRunInstaller(installFlags & INSTALLER_COPY_APP) == 0;
            
            if (  okNow  ) {
                break;
            } else {
                NSLog(@"installer did not make the necessary changes");
            }
        } else {
            NSLog(@"Failed to execute %@: %@", launchPath, arguments);
        }
    }
        
	NSString * installerLog = @"";
	if (  [gFileMgr fileExistsAtPath: @"/tmp/surfsafevpn-installer-log.txt"]  ) {
		NSData * data = [gFileMgr contentsAtPath: @"/tmp/surfsafevpn-installer-log.txt"];
		if (  data  ) {
			installerLog = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
		}
	}
    
    if (   (! okNow )
        && (  needToRunInstaller(installFlags & INSTALLER_COPY_APP) != 0  )  )
    {
        NSLog(@"Installation or repair failed; Log:\n%@", installerLog);
        TBRunAlertPanel(NSLocalizedString(@"Installation or Repair Failed", "Window title"),
                        NSLocalizedString(@"The installation, removal, recovery, or repair of one or more SurfSafeVPN components failed. See the Console Log for details.", "Window text"),
                        nil, nil, nil);
        [installerLog release];
        if (  authRefIsLocal  ) {
            AuthorizationFree(localAuthRef, kAuthorizationFlagDefaults);
        }
        return FALSE;
    }
    
    NSLog(@"Installation or repair succeeded; Log:\n%@", installerLog);
    [installerLog release];
    if (  authRefIsLocal  ) {
        AuthorizationFree(localAuthRef, kAuthorizationFlagDefaults);
    }
    return TRUE;
}

// Checks whether the installer needs to be run
// Sets bits in a flag for use by the runInstaller:extraArguments method, and, ultimately, by the installer program
//
// DOES NOT SET INSTALLER_COPY_APP (or INSTALLER_MOVE_NOT_COPY, INSTALLER_DELETE, or INSTALLER_SET_VERSION)
//
// Returns an unsigned containing INSTALLER_... bits set appropriately
unsigned needToRunInstaller(BOOL inApplications)
{
    unsigned flags = 0;
    
    if (  needToChangeOwnershipAndOrPermissions(inApplications)  ) flags = flags | INSTALLER_SECURE_APP;
    if (  needToCopyBundle()                                     ) flags = flags | INSTALLER_COPY_BUNDLE;
    if (  needToRepairPackages()                                 ) flags = flags | INSTALLER_SECURE_TBLKS;
    if (  needToMoveLibraryOpenVPN()                             ) flags = flags | INSTALLER_MOVE_LIBRARY_OPENVPN;
    if (  needToUpdateDeploy()                                   ) flags = flags | INSTALLER_UPDATE_DEPLOY;
    
    return flags;
}

BOOL needToMoveLibraryOpenVPN(void)
{
    // Check that the configuration folder has been moved and replaced by a symlink. If not, return YES
    NSString * oldConfigDirPath = [NSHomeDirectory() stringByAppendingPathComponent: @"Library/openvpn"];
    NSString * newConfigDirPath = [NSHomeDirectory() stringByAppendingPathComponent: @"Library/Application Support/SurfSafeVPN/Configurations"];
    BOOL isDir;
    
    BOOL newFolderExists = FALSE;
    // Check NEW location of private configurations
    if (  [gFileMgr fileExistsAtPath: newConfigDirPath isDirectory: &isDir]  ) {
        if (  isDir  ) {
            newFolderExists = TRUE;
        } else {
            NSLog(@"Error: %@ exists but is not a folder", newConfigDirPath);
            terminateBecauseOfBadConfiguration();
        }
    } else {
       NSLog(@"%@ does not exist", newConfigDirPath);
       return YES; // New folder does not exist.
    }
    
    // OLD location must either be a directory, or a symbolic link to the NEW location
    NSDictionary * fileAttributes = [gFileMgr tbFileAttributesAtPath: oldConfigDirPath traverseLink: NO];
    if (  ! [[fileAttributes objectForKey: NSFileType] isEqualToString: NSFileTypeSymbolicLink]  ) {
        if (  [gFileMgr fileExistsAtPath: oldConfigDirPath isDirectory: &isDir]  ) {
            if (  isDir  ) {
                if (  newFolderExists  ) {
                    NSLog(@"Both %@ and %@ exist and are folders", oldConfigDirPath, newConfigDirPath);
                    return YES; // Installer will try to repair this
                } else {
                    NSLog(@"%@ exists, but %@ doesn't", oldConfigDirPath, newConfigDirPath);
                    return YES;  // old folder exists, but new one doesn't, so do the move
                }
            } else {
                NSLog(@"Error: %@ exists but is not a symbolic link or a folder", oldConfigDirPath);
                terminateBecauseOfBadConfiguration();
            }
        }
    } else {
        // ~/Library/openvpn is a symbolic link
        if (  ! [[gFileMgr tbPathContentOfSymbolicLinkAtPath: oldConfigDirPath] isEqualToString: newConfigDirPath]  ) {
            NSLog(@"Warning: %@ exists and is a symbolic link but does not reference %@", oldConfigDirPath, newConfigDirPath);
        }
    }

    return NO;  // Nothing needs to be done
}

BOOL needToSecureFolderAtPath(NSString * path)
{
    // Returns YES if the folder (a Deploy folder in the app or in /Library/Application Support/SurfSafeVPN) needs to be secured
    //
    // There is a SIMILAR function in openvpnstart: exitIfTblkNeedsRepair
    //
    // There is a SIMILAR function in installer: secureOneFolder, that secures a folder with these permissions
    
    mode_t selfPerms;           //  For the folder itself (if not a .tblk)
    mode_t tblkFolderPerms;     //  For a .tblk itself and its Contents and Resources folders
    mode_t privateFolderPerms;  //  For folders in /Library/Application Support/SurfSafeVPN/Users/...
    mode_t publicFolderPerms;   //  For all other folders
    mode_t scriptPerms;         //  For files with .sh extensions
    mode_t executablePerms;     //  For files with .executable extensions (only appear in a Deploy folder
    mode_t otherPerms;          //  For all other files
    
	uid_t user = 0;
	gid_t group = 0;
	
    selfPerms		   = PERMS_SECURED_SELF;
    tblkFolderPerms    = PERMS_SECURED_TBLK_FOLDER;
    privateFolderPerms = PERMS_SECURED_PRIVATE_FOLDER;
    publicFolderPerms  = PERMS_SECURED_PUBLIC_FOLDER;
    scriptPerms        = PERMS_SECURED_SCRIPT;
    executablePerms    = PERMS_SECURED_EXECUTABLE;
    otherPerms         = PERMS_SECURED_OTHER;

    if (  ! checkOwnerAndPermissions(path, 0, 0, selfPerms)  ) {
        return YES;
    }
    
    BOOL isDir;
    NSString * file;
    NSDirectoryEnumerator * dirEnum = [gFileMgr enumeratorAtPath: path];
	
    while (  (file = [dirEnum nextObject])  ) {
        NSString * filePath = [path stringByAppendingPathComponent: file];
        if (  itemIsVisible(filePath)  ) {
            
            NSString * ext  = [file pathExtension];
            
            if (  [ext isEqualToString: @"tblk"]  ) {
                if (  ! checkOwnerAndPermissions(filePath, user, group, tblkFolderPerms)  ) {
                    return YES;
                }
            
            } else if (   [gFileMgr fileExistsAtPath: filePath isDirectory: &isDir] && isDir  ) {
			
                if (  [filePath rangeOfString: @".tblk/"].location != NSNotFound  ) {
					if (  ! checkOwnerAndPermissions(filePath, user, group, tblkFolderPerms)  ) {
						return YES;
					}
				
                } else if (   [filePath hasPrefix: [L_AS_T_BACKUP stringByAppendingString: @"/"]]
						   || [filePath hasPrefix: [L_AS_T_DEPLOY stringByAppendingString: @"/"]]
                           || [filePath hasPrefix: [L_AS_T_SHARED stringByAppendingString: @"/"]]  ) {
					if (  ! checkOwnerAndPermissions(filePath, user, group, publicFolderPerms)  ) {
						return YES;
					}
				
                } else {
					if (  ! checkOwnerAndPermissions(filePath, user, group, privateFolderPerms)  ) {
						return YES;
					}
				}
			
            } else if ( [ext isEqualToString:@"sh"]  ) {
                if (  ! checkOwnerAndPermissions(filePath, user, group, scriptPerms)  ) {
                    return YES;
                }
            
            } else if ( [ext isEqualToString:@"executable"]  ) {
                if (  ! checkOwnerAndPermissions(filePath, user, group, executablePerms)  ) {
                    return YES;
                }
            
            } else {
                if (  ! checkOwnerAndPermissions(filePath, user, group, otherPerms)  ) {
                    return YES;
                }
            }
        }
    }
    
    return NO;
}

BOOL needToChangeOwnershipAndOrPermissions(BOOL inApplications)
{
	// Check ownership and permissions on components of SurfSafeVPN.app
    NSString * resourcesPath;
    if ( inApplications  ) {
        resourcesPath = @"/Applications/SurfSafeVPN.app/Contents/Resources";
    } else {
        resourcesPath = [[NSBundle mainBundle] resourcePath];
	}
    
	NSString *contentsPath			    = [resourcesPath stringByDeletingLastPathComponent];
    NSString *tunnelblickPath           = [contentsPath  stringByDeletingLastPathComponent];
    
	NSString *openvpnstartPath          = [resourcesPath stringByAppendingPathComponent: @"openvpnstart"                        ];
	NSString *openvpnFolderPath         = [resourcesPath stringByAppendingPathComponent: @"openvpn"                             ];
	NSString *atsystemstartPath         = [resourcesPath stringByAppendingPathComponent: @"atsystemstart"                       ];
	NSString *installerPath             = [resourcesPath stringByAppendingPathComponent: @"installer"                           ];
	NSString *ssoPath                   = [resourcesPath stringByAppendingPathComponent: @"standardize-scutil-output"           ];
	NSString *leasewatchPath            = [resourcesPath stringByAppendingPathComponent: @"leasewatch"                          ];
	NSString *leasewatch3Path           = [resourcesPath stringByAppendingPathComponent: @"leasewatch3"                         ];
	NSString *clientUpPath              = [resourcesPath stringByAppendingPathComponent: @"client.up.osx.sh"                    ];
	NSString *clientDownPath            = [resourcesPath stringByAppendingPathComponent: @"client.down.osx.sh"                  ];
	NSString *clientNoMonUpPath         = [resourcesPath stringByAppendingPathComponent: @"client.nomonitor.up.osx.sh"          ];
	NSString *clientNoMonDownPath       = [resourcesPath stringByAppendingPathComponent: @"client.nomonitor.down.osx.sh"        ];
	NSString *clientNewUpPath           = [resourcesPath stringByAppendingPathComponent: @"client.up.tunnelblick.sh"            ];
	NSString *clientNewDownPath         = [resourcesPath stringByAppendingPathComponent: @"client.down.tunnelblick.sh"          ];
	NSString *clientNewRoutePreDownPath = [resourcesPath stringByAppendingPathComponent: @"client.route-pre-down.tunnelblick.sh"];
	NSString *clientNewAlt1UpPath       = [resourcesPath stringByAppendingPathComponent: @"client.1.up.tunnelblick.sh"          ];
	NSString *clientNewAlt1DownPath     = [resourcesPath stringByAppendingPathComponent: @"client.1.down.tunnelblick.sh"        ];
	NSString *clientNewAlt2UpPath       = [resourcesPath stringByAppendingPathComponent: @"client.2.up.tunnelblick.sh"          ];
	NSString *clientNewAlt2DownPath     = [resourcesPath stringByAppendingPathComponent: @"client.2.down.tunnelblick.sh"        ];
	NSString *clientNewAlt3UpPath       = [resourcesPath stringByAppendingPathComponent: @"client.3.up.tunnelblick.sh"          ];
	NSString *clientNewAlt3DownPath     = [resourcesPath stringByAppendingPathComponent: @"client.3.down.tunnelblick.sh"        ];
    NSString *deployPath                = [resourcesPath stringByAppendingPathComponent: @"Deploy"];
    NSString *infoPlistPath             = [[resourcesPath stringByDeletingLastPathComponent] stringByAppendingPathComponent: @"Info.plist"];

	if (  ! checkOwnedByRootWheel(tunnelblickPath) ) {
        NSLog(@"%@ not owned by root:wheel", tunnelblickPath);
        return YES;
	}
    
    if (  ! checkOwnerAndPermissions(tunnelblickPath, 0, 0, 0755)  ) {
        return YES; // NSLog already called
    }
    
    if (  ! checkOwnerAndPermissions(contentsPath,    0, 0, 0755)  ) {
        return YES; // NSLog already called
    }
    
    if (  ! checkOwnerAndPermissions(resourcesPath,   0, 0, 0755)  ) {
        return YES; // NSLog already called
    }
    
	// check openvpnstart owned by root with suid and 544 permissions
	const char *path = [gFileMgr fileSystemRepresentationWithPath: openvpnstartPath];
    struct stat sb;
	if (  stat(path, &sb)  != 0  ) {
        NSLog(@"Unable to determine status of openvpnstart\nError was '%s'", strerror(errno));
        return YES;
	}
	if (   (sb.st_uid != 0)
        || ((sb.st_mode & 07777) != 04555)  ) {
        return YES;
	}
	
    // check openvpn folder
    if (  ! checkOwnerAndPermissions(openvpnFolderPath, 0, 0, 0755)  ) {
        return YES; // NSLog already called
    }
    
    // Check OpenVPN version folders and the binaries of openvpn and openvpn-down-root.so in them
    NSDirectoryEnumerator * dirEnum = [gFileMgr enumeratorAtPath: openvpnFolderPath];
    NSString * file;
    BOOL isDir;
    while (  (file = [dirEnum nextObject])  ) {
        [dirEnum skipDescendents];
        NSString * fullPath = [openvpnFolderPath stringByAppendingPathComponent: file];
        if (   [gFileMgr fileExistsAtPath: fullPath isDirectory: &isDir]
            && isDir  ) {
            if (  [file hasPrefix: @"openvpn-"]  ) {
                if (  ! checkOwnerAndPermissions(fullPath, 0, 0, 0755)  ) {
                    return YES;
                }
                
                NSString * thisOpenvpnPath = [fullPath stringByAppendingPathComponent: @"openvpn"];
                if (  ! checkOwnerAndPermissions(thisOpenvpnPath, 0, 0, 0755)  ) {
                    return YES;
                }
                
                NSString * thisOpenvpnDownRootPath = [fullPath stringByAppendingPathComponent: @"openvpn-down-root.so"];
                if (  ! checkOwnerAndPermissions(thisOpenvpnDownRootPath, 0, 0, 0744)  ) {
                    return YES;
                }
            }
        }
    }
    
	// check files which should be owned by root with 744 permissions
	NSArray *root744Objects = [NSArray arrayWithObjects:
                               atsystemstartPath, installerPath, ssoPath, leasewatchPath, leasewatch3Path,
                               clientUpPath, clientDownPath,
                               clientNoMonUpPath, clientNoMonDownPath,
                               clientNewUpPath, clientNewDownPath, clientNewRoutePreDownPath,
                               clientNewAlt1UpPath, clientNewAlt1DownPath,
                               clientNewAlt2UpPath, clientNewAlt2DownPath,
                               clientNewAlt3UpPath, clientNewAlt3DownPath,
                               nil];
	NSEnumerator *e = [root744Objects objectEnumerator];
	NSString *currentPath;
	while (  (currentPath = [e nextObject])  ) {
        if (  ! checkOwnerAndPermissions(currentPath, 0, 0, 0744)  ) {
            return YES; // NSLog already called
        }
	}
    
    // check Info.plist
    if (  ! checkOwnerAndPermissions(infoPlistPath, 0, 0, 0644)  ) {
        return YES; // NSLog already called
    }
    
    // check that log directory exists and has proper ownership and permissions
    if (  ! (   [gFileMgr fileExistsAtPath: L_AS_T_LOGS isDirectory: &isDir]
             && isDir )  ) {
        NSLog(@"Need to create log directory");
        return YES;
    }
    if (  ! checkOwnerAndPermissions(L_AS_T_LOGS, 0, 0, 0755)  ) {
        return YES; // NSLog already called
    }
    
    // check permissions of files in Resources/Deploy (if it exists)
    if (  [gFileMgr fileExistsAtPath: deployPath isDirectory: &isDir]
        && isDir  ) {
        if (  needToSecureFolderAtPath(deployPath)  ) {
            return YES;
        }
    }
    
    // check permissions of files in the master Deploy folder
    if (  [gFileMgr fileExistsAtPath: gDeployPath isDirectory: &isDir]
        && isDir  ) {
        if (  needToSecureFolderAtPath(gDeployPath)  ) {
        return YES;
    }
    }
    
    // check permissions of files in the Deploy backup, also (if any)        
    NSString * deployBackupPath = [[[[L_AS_T_BACKUP stringByAppendingPathComponent: [[NSBundle mainBundle] bundlePath]]
                                     stringByDeletingLastPathComponent]
                                    stringByAppendingPathComponent: @"SurfSafeVPNBackup"]
                                   stringByAppendingPathComponent: @"Deploy"];
    if (  [gFileMgr fileExistsAtPath: deployBackupPath isDirectory: &isDir]
        && isDir  ) {
        if (  needToSecureFolderAtPath(deployBackupPath)  ) {
            return YES;
        }
    }
    
    return NO;
}

BOOL checkAttributes(NSDictionary * atts)
{
    // Check that a set of file attributes shows ownership by root:wheel
    if (  [[atts fileOwnerAccountID] intValue] != 0  ) {
        return NO;
    }
    
    if (  [[atts fileGroupOwnerAccountID] intValue] != 0  ) {
            return NO;
        }
    
    return YES;
}    

BOOL checkOwnedByRootWheel(NSString * path)
{
    // Check that everything in path and it's subfolders is owned by root:wheel (checks symlinks, too)
	NSDirectoryEnumerator * dirEnum = [gFileMgr enumeratorAtPath: path];
	NSString * file;
	NSDictionary * atts;
	while (  (file = [dirEnum nextObject])  ) {
		NSString * filePath = [path stringByAppendingPathComponent: file];
		if (  itemIsVisible(filePath)  ) {
			atts = [gFileMgr tbFileAttributesAtPath: filePath traverseLink: NO];
            if (  ! checkAttributes(atts)  ) {
                return NO;
            }
			if (  [[atts objectForKey: NSFileType] isEqualToString: NSFileTypeSymbolicLink]  ) {
				atts = [gFileMgr tbFileAttributesAtPath: filePath traverseLink: YES];
                if (  ! checkAttributes(atts)  ) {
                    return NO;
                }
			}
		}
	}
	
	return YES;
}
        
BOOL needToUpdateDeploy(void)
{
    NSString * thisAppDeployPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent: @"Deploy"];
    BOOL isDir;
    BOOL haveDeployInL_AS_T  = [gFileMgr fileExistsAtPath: gDeployPath       isDirectory: &isDir] && isDir;
    BOOL haveDeployInThisApp = [gFileMgr fileExistsAtPath: thisAppDeployPath isDirectory: &isDir] && isDir;
    
    if (  haveDeployInThisApp  ) {
        if (  ! haveDeployInL_AS_T ) {
            return YES;
        }
        
        // Don't have version numbers, so update only if Deploy in app is later
        
        NSDate * lastModifiedInL_AS_T  = [[gFileMgr tbFileAttributesAtPath: gDeployPath traverseLink: NO]
										  objectForKey: NSFileModificationDate];
        NSDate * lastModifiedInThisApp = [[gFileMgr tbFileAttributesAtPath: thisAppDeployPath traverseLink: NO]
										  objectForKey: NSFileModificationDate];
        
        if (  [lastModifiedInL_AS_T compare: lastModifiedInThisApp] == NSOrderedAscending ) {
            return YES;
        }
    }
    
    return NO;
}    

BOOL needToRepairPackages(void)
{
    // Check permissions of private .tblk packages.
	// If ...tblk/Contents is owned by root:wheel (old setup), we need to change the ownership to user:group,
	// because in the new setup, the private configs are no longer secured (the shadow copies are secured)
    //
    // This check is to detect when the permissions have been reverted to the old scheme _after_ using the new scheme and setting the preference
	
    NSString * file;
    BOOL isDir;
    NSDirectoryEnumerator *dirEnum = [gFileMgr enumeratorAtPath: gPrivatePath];
    while (  (file = [dirEnum nextObject])  ) {
        NSString * fullPath = [gPrivatePath stringByAppendingPathComponent: file];
        if (  itemIsVisible(fullPath)  ) {
            NSString * ext  = [file pathExtension];
            if (   [gFileMgr fileExistsAtPath: fullPath isDirectory: &isDir]
                && isDir
                && [ext isEqualToString: @"tblk"]  ) {
                if (  checkOwnedByRootWheel([fullPath stringByAppendingPathComponent: @"Contents"])  ) {
                    return YES;
                }
				[dirEnum skipDescendents];
            }
        }
    }
    
    return NO;
}

BOOL needToCopyBundle()
{
    NSString * appConfigurationsBundlePath = [[[NSBundle mainBundle] resourcePath]
                                              stringByAppendingPathComponent: @"SurfSafeVPN Configurations.bundle"];
    
    BOOL isDir;
    
    if (   [gFileMgr fileExistsAtPath: appConfigurationsBundlePath isDirectory: &isDir]
        && isDir  ) {
        
        NSString * appConfigBundlePlistPath = [appConfigurationsBundlePath stringByAppendingPathComponent: @"Contents/Info.plist"];
        NSDictionary * appDict = [NSDictionary dictionaryWithContentsOfFile: appConfigBundlePlistPath];
        NSString * appVersion = [appDict objectForKey: @"CFBundleVersion"];
        if (  appVersion  ) {
            if (  [gFileMgr fileExistsAtPath: CONFIGURATION_UPDATES_BUNDLE_PATH]  ) {
                NSString * libPlistPath = [CONFIGURATION_UPDATES_BUNDLE_PATH stringByAppendingPathComponent: @"Contents/Info.plist"];
                NSDictionary * libDict = [NSDictionary dictionaryWithContentsOfFile: libPlistPath];
                NSString * libVersion = [libDict objectForKey: @"CFBundleVersion"];
                if (  libVersion  ) {
                    if (  [appVersion compare: libVersion options: NSNumericSearch]  == NSOrderedDescending  ) {
                        return YES;  // App has higher version than /Library...
                    }
                } else {
                    return YES;  // No version info in /Library... copy
                }
            } else {
                return YES;  // No /Library... copy
            }
        } else {
            NSLog(@"No CFBundleVersion in %@", appConfigurationsBundlePath);
        }
    }
    
    return NO;
}


void terminateBecauseOfBadConfiguration(void)
{
    TBRunAlertPanel(NSLocalizedString(@"SurfSafeVPN Configuration Problem", @"Window title"),
                    NSLocalizedString(@"SurfSafeVPN could not be launched because of a problem with the configuration. Please examine the Console Log for details.", @"Window text"),
                    nil, nil, nil);
    [[NSApp delegate] terminateBecause: terminatingBecauseOfError];
}

-(NSApplicationTerminateReply) applicationShouldTerminate: (NSApplication *) sender
{
	(void) sender;
	
	NSArray * reasons = [NSArray arrayWithObjects:
						 @"for unknown reason",
						 @"because of logout",
						 @"because of shutdown",
						 @"because of restart",
						 @"because of Quit",
						 @"because of an error",
						 @"because of a fatal error",
						 nil];
	NSString * reasonString;
	if (  reasonForTermination < [reasons count]  ) {
		reasonString = [reasons objectAtIndex: reasonForTermination];
	} else {
		reasonString = [reasons objectAtIndex: 0];
	}

    NSLog(@"applicationShouldTerminate: termination %@; delayed until 'shutdownTunnelblick' finishes", reasonString);
    [self performSelectorOnMainThread: @selector(shutDownTunnelblick) withObject: nil waitUntilDone: NO];
    return NSTerminateLater;
}

-(void) shutDownTunnelblick
{
    NSLog(@"DEBUG: shutDownTunnelblick: started.");
    terminatingAtUserRequest = TRUE;
    
    if (  [theAnim isAnimating]  ) {
        NSLog(@"DEBUG: shutDownTunnelblick: stopping icon animation.");
        [theAnim stopAnimation];
    }
    
    NSLog(@"DEBUG: shutDownTunnelblick: Starting cleanup.");
    if (  [self cleanup]  ) {
        NSLog(@"DEBUG: shutDownTunnelblick: Cleanup finished.");
    } else {
        NSLog(@"DEBUG: shutDownTunnelblick: Cleanup already being done.");
    }
    
    NSLog(@"Finished shutting down SurfSafeVPN; allowing termination");
    [NSApp replyToApplicationShouldTerminate: YES];
}


- (void) applicationWillTerminate: (NSNotification*) notification
{
	(void) notification;
	
    NSLog(@"DEBUG: applicationWillTerminate: invoked");
    terminatingAtUserRequest = TRUE;
    if (  ! areLoggingOutOrShuttingDown  ) {
        [NSApp setAutoLaunchOnLogin: NO];
    }
    //HTK-INC1
    [self restoreWebSWebProxies];
    //END HTK-INC1
    [self cleanup];
}

// These five notifications happen BEFORE the "willLogoutOrShutdown" notification and indicate intention

-(void) logoutInitiatedHandler: (NSNotification *) n
{
	(void) n;
	
    reasonForTermination = terminatingBecauseOfLogout;
    NSLog(@"DEBUG: Initiated logout");
}

-(void) restartInitiatedHandler: (NSNotification *) n
{
	(void) n;
	
    reasonForTermination = terminatingBecauseOfRestart;
    NSLog(@"DEBUG: Initiated computer restart");
}

-(void) shutdownInitiatedHandler: (NSNotification *) n
{
	(void) n;
	
    reasonForTermination = terminatingBecauseOfShutdown;
    NSLog(@"DEBUG: Initiated computer shutdown");
}

-(void) logoutCancelledHandler: (NSNotification *) n
{
	(void) n;
	
    reasonForTermination = terminatingForUnknownReason;
    NSLog(@"DEBUG: Cancelled logout, or computer shutdown or restart.");
}

// reasonForTermination should be set before this is invoked

-(void) setShutdownVariables
{
    // Only change the shutdown variables once. Maybe by logoutContinuedHandler:, maybe by willLogoutOrShutdownHandler:, whichever
    // occurs first.
    //
    // NEVER unlock this mutex. It is only invoked when Tunnelblick is quitting or about to quit
    static pthread_mutex_t shuttingDownMutex = PTHREAD_MUTEX_INITIALIZER;
    
    int status = pthread_mutex_trylock( &shuttingDownMutex );
    if (  status != EXIT_SUCCESS  ) {
        if (  status == EBUSY  ) {
            NSLog(@"DEBUG: setShutdownVariables: invoked, but have already set them");
        } else {
            NSLog(@"DEBUG: setShutdownVariables: pthread_mutex_trylock( &myVPNMenuMutex ) failed; status = %ld; %s", (long) status, strerror(status));
        }
        
        return;
    }

    gShuttingDownTunnelblick = TRUE;
    if (   (reasonForTermination == terminatingBecauseOfRestart)
        || (reasonForTermination == terminatingBecauseOfShutdown)  ) {
        gShuttingDownOrRestartingComputer = TRUE;
    }
    if (   gShuttingDownOrRestartingComputer
        || (reasonForTermination == terminatingBecauseOfLogout)  ) {
        gShuttingDownWorkspace = TRUE;
        
        NSNotification * note = [NSNotification notificationWithName: @"TunnelblickUIShutdownNotification" object: nil];
        [[NSNotificationCenter defaultCenter] postNotification:note];
    }
}

-(void) logoutContinuedHandler: (NSNotification *) n
{
	(void) n;
	
    NSLog(@"DEBUG: logoutContinuedHandler: Confirmed logout, or computer shutdown or restart.");
    [self setShutdownVariables];
}

// This notification happens when we know we actually will logout or shutdown (or restart)
-(void) willLogoutOrShutdownHandler: (NSNotification *) n
{
 	(void) n;
	
   NSLog(@"DEBUG: willLogoutOrShutdownHandler: Received 'NSWorkspaceWillPowerOffNotification' notification");
    [self setShutdownVariables];
}


-(void)TunnelblickShutdownUIHandler: (NSNotification *) n
{
	(void) n;
	
    NSLog(@"DEBUG: TunnelblickShutdownUIHandler: invoked");
}


-(void)willGoToSleepHandler: (NSNotification *) n
{
 	(void) n;
	
   if (  gShuttingDownOrRestartingComputer  ) {
        return;
    }
    
    gComputerIsGoingToSleep = TRUE;
	NSLog(@"DEBUG: willGoToSleepHandler: Setting up connections to restore when computer wakes up");
    
    [connectionsToRestoreOnWakeup removeAllObjects];
    VPNConnection * connection; 
	NSEnumerator * connEnum = [[self myVPNConnectionDictionary] objectEnumerator];
    while (  (connection = [connEnum nextObject])  ) {
        if (  ! [[connection requestedState] isEqualToString: @"EXITING"]  ) {
            [connectionsToRestoreOnWakeup addObject: connection];
        }
    }
    
    terminatingAtUserRequest = TRUE;
    if (  [connectionsToRestoreOnWakeup count] != 0  ) {
        NSLog(@"DEBUG: willGoToSleepHandler: Closing all connections");
        [self killAllConnectionsIncludingDaemons: YES logMessage: @"*SurfSafeVPN: Computer is going to sleep. Closing connections..."];  // Kill any OpenVPN processes that still exist
    if (  ! [gTbDefaults boolForKey: @"doNotPutOffSleepUntilOpenVPNsTerminate"] ) {
        // Wait until all OpenVPN processes have terminated
            NSLog(@"DEBUG: willGoToSleepHandler: Putting off sleep until all OpenVPNs have terminated");
        while (  [[NSApp pIdsForOpenVPNProcesses] count] != 0  ) {
            usleep(100000);
        }
    }
}
    
    NSLog(@"DEBUG: willGoToSleepHandler: OK to go to sleep");
}
-(void) wokeUpFromSleepHandler: (NSNotification *) n
{
 	(void) n;
	
   if (  gShuttingDownOrRestartingComputer  ) {
        return;
    }
    
    [self performSelectorOnMainThread: @selector(wokeUpFromSleep) withObject:nil waitUntilDone:NO];
}

-(void)wokeUpFromSleep
{
    gComputerIsGoingToSleep = FALSE;
	if(NSDebugEnabled) NSLog(@"Computer just woke up from sleep");
	
	NSEnumerator *e = [connectionsToRestoreOnWakeup objectEnumerator];
	VPNConnection *connection;
	while (  (connection = [e nextObject])  ) {
        NSString * name = [connection displayName];
        NSString * key  = [name stringByAppendingString: @"-doNotReconnectOnWakeFromSleep"];
        if (  ! [gTbDefaults boolForKey: key]  ) {
            if (NSDebugEnabled) NSLog(@"Restoring connection %@", name);
            [connection addToLog: @"*SurfSafeVPN: Woke up from sleep. Attempting to re-establish connection..."];
		[connection connect:self userKnows: YES];
        } else {
            if (NSDebugEnabled) NSLog(@"Not restoring connection %@ because of preference", name);
            [connection addToLog: @"*SurfSafeVPN: Woke up from sleep. Not attempting to re-establish connection..."];
        }
	}
    
    [connectionsToRestoreOnWakeup removeAllObjects];
}
-(void)didBecomeInactiveUserHandler: (NSNotification *) n
{
 	(void) n;
	
    [self performSelectorOnMainThread: @selector(didBecomeInactiveUser) withObject:nil waitUntilDone:NO];
}

-(void)didBecomeInactiveUser
{
    // Remember current connections so they can be restored if/when we become the active user
    connectionsToRestoreOnUserActive = [[self connectionArray] copy];
    
    // For each open connection, either reInitialize it or disconnect it
    NSEnumerator * e = [[self connectionArray] objectEnumerator];
	VPNConnection * connection;
	while (  (connection = [e nextObject])  ) {
        if (  [connection shouldDisconnectWhenBecomeInactiveUser]  ) {
            [connection addToLog: @"*SurfSafeVPN: Disconnecting; user became inactive"];
            [connection disconnectAndWait: [NSNumber numberWithBool: YES] userKnows: YES];
        } else {
            [connection addToLog: @"*SurfSafeVPN: Stopping communication with OpenVPN because user became inactive"];
            [connection reInitialize];
        }
    }
}

-(void)didBecomeActiveUserHandler: (NSNotification *) n
{
	(void) n;
	
    [self performSelectorOnMainThread: @selector(didBecomeActiveUser) withObject:nil waitUntilDone:NO];
}

-(void)didBecomeActiveUser
{
    [self hookupToRunningOpenVPNs];
    if (  [self setupHookupWatchdogTimer]  ) {
        return; // reconnectAfterBecomeActiveUser will be done when the hookup timer times out or there are no more hookups pending
    }
    
    // Wait a second to give hookups a chance to happen, then restore connections after processing the hookups
    sleep(1);   
    
    [self performSelectorOnMainThread: @selector(reconnectAfterBecomeActiveUser) withObject: nil waitUntilDone: YES];
}

-(void)reconnectAfterBecomeActiveUser
{
   // Reconnect configurations that were connected before this user was switched out and that aren't connected now
    NSEnumerator * e = [connectionsToRestoreOnUserActive objectEnumerator];
	VPNConnection * connection;
	while (  (connection = [e nextObject])  ) {
        if (  ! [connection isHookedup]  ) {
            NSString * key = [[connection displayName] stringByAppendingString: @"-doNotReconnectOnFastUserSwitch"];
            if (  ! [gTbDefaults boolForKey: key]  ) {
                [connection stopTryingToHookup];
                [connection addToLog: @"*SurfSafeVPN: Attempting to reconnect because user became active"];
                [connection connect: self userKnows: YES];
            }
        }
    }
    
    [connectionsToRestoreOnUserActive release];
    connectionsToRestoreOnUserActive = nil;
}

int runUnrecoverableErrorPanel(msg) 
{
	int result = TBRunAlertPanel(NSLocalizedString(@"SurfSafeVPN Error", @"Window title"),
                                 [NSString stringWithFormat: NSLocalizedString(@"You must reinstall SurfSafeVPN. Please move SurfSafeVPN to the Trash and download a fresh copy. The problem was:\n\n%@", @"Window text"),
                                  msg],
                                 NSLocalizedString(@"Download", @"Button"),
                                 NSLocalizedString(@"Quit", @"Button"),
                                 nil);
	if( result == NSAlertDefaultReturn ) {
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://tunnelblick.net/"]];
	}
    exit(2);
}

-(void) setHotKeyIndex: (int) newIndex
{
    hotKeyCurrentIndex = newIndex;

    if (  newIndex == 0  ) {
        UnregisterEventHotKey(hotKeyRef);        
        hotKeyModifierKeys = 0;
        hotKeyKeyCode = 0;
    } else {
        [self setupHotKeyWithCode: fKeyCode[newIndex-1] andModifierKeys:  cmdKey + optionKey];
    }
}

-(void) setupHotKeyWithCode: (UInt32) keyCode andModifierKeys: (UInt32) modifierKeys
{
    if (  hotKeyEventHandlerIsInstalled  ) {
        if (  hotKeyModifierKeys != 0  ) {
            UnregisterEventHotKey(hotKeyRef);
        }
    } else {
        EventTypeSpec eventType;
        eventType.eventClass = kEventClassKeyboard;
        eventType.eventKind  = kEventHotKeyPressed;
        InstallApplicationEventHandler(&hotKeyPressed, 1, &eventType, (void *) self, NULL);
        hotKeyEventHandlerIsInstalled = TRUE;
    }
    
    EventHotKeyID hotKeyID;
    hotKeyID.signature = 'htk1';
    hotKeyID.id = 1;
    RegisterEventHotKey(keyCode, modifierKeys, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef);
    
    hotKeyKeyCode = keyCode;
    hotKeyModifierKeys = modifierKeys;
}

OSStatus hotKeyPressed(EventHandlerCallRef nextHandler,EventRef theEvent, void * userData)
{
    // When the hotKey is pressed, pop up the SurfSafeVPN menu from the Status Bar
    MenuController * menuC = (MenuController *) userData;
    NSStatusItem * statusI = [menuC statusItem];
    [statusI popUpStatusItemMenu: [[NSApp delegate] myVPNMenu]];
    return noErr;
}

-(NSArray *) sortedSounds
{
    // Get all the names of sounds
    NSMutableArray * sounds = [[[NSMutableArray alloc] initWithCapacity: 30] autorelease];
    NSArray * soundDirs = [NSArray arrayWithObjects:
                           [NSHomeDirectory() stringByAppendingString: @"/Library/Sounds"],
                           @"/Library/Sounds",
                           @"/Network/Library/Sounds",
                           @"/System/Library/Sounds",
                           nil];
    NSArray * soundTypes = [NSArray arrayWithObjects: @"aiff", @"wav", nil];
    NSEnumerator * soundDirEnum = [soundDirs objectEnumerator];
    NSString * folder;
    NSString * file;
    while (  (folder = [soundDirEnum nextObject])  ) {
        NSDirectoryEnumerator * dirEnum = [gFileMgr enumeratorAtPath: folder];
        while (  (file = [dirEnum nextObject])  ) {
            [dirEnum skipDescendents];
            if (  [soundTypes containsObject: [file pathExtension]]  ) {
                NSString * soundName = [file stringByDeletingPathExtension];
                if (  ! [sounds containsObject: soundName]  ) {
                    [sounds addObject: soundName];
                }
            }
        }
    }
    
    // Return them sorted
    return [sounds sortedArrayUsingSelector: @selector(caseInsensitiveNumericCompare:)];
}

-(void) updateStatisticsDisplaysHandler {
    if (  gShuttingDownWorkspace  ) {
        [statisticsWindowTimer invalidate];
        return;
    }
    
    [self performSelectorOnMainThread: @selector(updateStatisticsDisplays) withObject: nil waitUntilDone: NO];
}

-(void) updateStatisticsDisplays {
    NSEnumerator * e = [connectionArray objectEnumerator];
    VPNConnection * connection;
    while (  (connection = [e nextObject])  ) {
        [connection updateStatisticsDisplay];
    }
}

-(void) statisticsWindowsShow: (BOOL) showThem {

    NSEnumerator * e = [myVPNConnectionDictionary objectEnumerator];
    VPNConnection * connection;
    BOOL showingAny = FALSE;
    while (  connection = [e nextObject]  ) {
        if (  [connection logFilesMayExist]  ) {
            if (  showThem  ) {
                //vpl changes
                if([lastState isEqualToString:(@"CONNECTED")]){
                    VPNConnection *tmp = (VPNConnection *)[connectionArray objectAtIndex:0];
                    if([[tmp displayName] isEqualToString:([connection displayName])]){
                        [connection showStatusWindow];
                        showingAny = TRUE;
                    }
                    else{
                        [connection setLogFilesMayExist:NO];
                    }
                }
                else if([lastState isEqualToString:(@"ANIMATED")]){
                    [connection setLogFilesMayExist:NO];
                }
                else{
                    [connection showStatusWindow];
                    showingAny = TRUE;
                }
                //vpl changes end
            } else {
                /*if (   [connection isConnected]
                    || [connection isDisconnected]  )*/ {
                    [connection fadeAway];
                }
            }
        }
    }
    
    if (  showingAny  ) {
        if (  statisticsWindowTimer == nil  ) {
            statisticsWindowTimer = [[NSTimer scheduledTimerWithTimeInterval: 1.0
                                                                      target: self
                                                                    selector: @selector(updateStatisticsDisplaysHandler)
                                                                    userInfo: nil
                                                                     repeats: YES] retain];
        }
    } else {
        [statisticsWindowTimer invalidate];
        [statisticsWindowTimer release];
        statisticsWindowTimer = nil;
    }
}

-(void) showStatisticsWindows {
    if(mouseIsInMainIcon)
        [self statisticsWindowsShow: YES];
}

-(void) hideStatisticsWindows {
    
    [self statisticsWindowsShow: NO];
}

-(BOOL) mouseIsInsideAnyView {
    // Returns TRUE if the mouse is inside any status window or the main Icon
    
    return mouseIsInStatusWindow || mouseIsInMainIcon;
}

static pthread_mutex_t threadIdsMutex = PTHREAD_MUTEX_INITIALIZER;

-(void) addActiveIPCheckThread: (NSString *) threadID
{
    OSStatus status = pthread_mutex_lock( &threadIdsMutex );
    if (  status != EXIT_SUCCESS  ) {
        NSLog(@"pthread_mutex_lock( &threadIdsMutex ) failed; status = %ld, errno = %ld", (long) status, (long) errno);
        return;
    }
    
    [activeIPCheckThreads addObject: threadID];
	NSLog(@"DEBUG: addActiveIPCheckThread: threadID '%@' added to the active list", threadID);
    
    status = pthread_mutex_unlock( &threadIdsMutex );
    if (  status != EXIT_SUCCESS  ) {
        NSLog(@"pthread_mutex_unlock( &threadIdsMutex ) failed; status = %ld, errno = %ld", (long) status, (long) errno);
        return;
    }
}

-(void) cancelIPCheckThread: (NSString *) threadID
{
    OSStatus status = pthread_mutex_lock( &threadIdsMutex );
    if (  status != EXIT_SUCCESS  ) {
        NSLog(@"pthread_mutex_lock( &threadIdsMutex ) failed; status = %ld, errno = %ld", (long) status, (long) errno);
        return;
    }
    
    if (  [activeIPCheckThreads containsObject: threadID]  ) {
        if (  ! [cancellingIPCheckThreads containsObject: threadID]  ) {
            [activeIPCheckThreads removeObject: threadID];
            [cancellingIPCheckThreads addObject: threadID];
            NSLog(@"DEBUG: cancelIPCheckThread: threadID '%@' removed from the active list and added to the cancelling list", threadID);
            
        } else {
            NSLog(@"cancelIPCheckThread: ERROR: threadID '%@' is on both the active and cancelling lists! Removing from active list", threadID);
            [activeIPCheckThreads removeObject: threadID];
        }
    } else {
        if (  [cancellingIPCheckThreads containsObject: threadID]  ) {
            NSLog(@"DEBUG: cancelIPCheckThread: threadID '%@' is already on the cancelling list!", threadID);
        } else {
            NSLog(@"cancelIPCheckThread: ERROR: threadID '%@' is not in the the active or cancelling list! Added it to cancelling list", threadID);
            [cancellingIPCheckThreads addObject: threadID];
        }
    }
    
    status = pthread_mutex_unlock( &threadIdsMutex );
    if (  status != EXIT_SUCCESS  ) {
        NSLog(@"pthread_mutex_unlock( &threadIdsMutex ) failed; status = %ld, errno = %ld", (long) status, (long) errno);
        return;
    }
}

-(void) cancelAllIPCheckThreadsForConnection: (VPNConnection *) connection
{
    OSStatus status = pthread_mutex_lock( &threadIdsMutex );
    if (  status != EXIT_SUCCESS  ) {
        NSLog(@"pthread_mutex_lock( &threadIdsMutex ) failed; status = %ld, errno = %ld", (long) status, (long) errno);
        return;
    }
    
    NSLog(@"DEBUG: cancelAllIPCheckThreadsForConnection: Entered");
    // Make a list of threadIDs to cancel
    NSString * prefix = [NSString stringWithFormat: @"%lu-", (long) connection];
    NSMutableArray * threadsToCancel = [NSMutableArray arrayWithCapacity: 5];
    NSEnumerator * e = [activeIPCheckThreads objectEnumerator];
    NSString * threadID;
    while (  (threadID = [e nextObject])  ) {
        if (  [threadID hasPrefix: prefix]  ) {
            [threadsToCancel addObject: threadID];
        }
    }

    NSLog(@"DEBUG: cancelAllIPCheckThreadsForConnection: No active threads for connection %lu", (long) connection);
    
    // Then cancel them. (This avoids changing the list while we enumerate it.)
    e = [threadsToCancel objectEnumerator];
    while (  (threadID = [e nextObject])  ) {
        if (  [activeIPCheckThreads containsObject: threadID]  ) {
            if (  ! [cancellingIPCheckThreads containsObject: threadID]  ) {
                [activeIPCheckThreads removeObject: threadID];
                [cancellingIPCheckThreads addObject: threadID];
                NSLog(@"DEBUG: cancelAllIPCheckThreadsForConnection: threadID '%@' removed from the active list and added to the cancelling list", threadID);

            } else {
                NSLog(@"cancelAllIPCheckThreadsForConnection: ERROR: threadID '%@' is on both the active and cancelling lists! Removing from active list", threadID);
                [activeIPCheckThreads removeObject: threadID];
            }
        } else {
            if (  [cancellingIPCheckThreads containsObject: threadID]  ) {
                NSLog(@"cancelAllIPCheckThreadsForConnection: ERROR: threadID '%@' is already on the cancelling list!", threadID);
            } else {
                NSLog(@"cancelAllIPCheckThreadsForConnection: ERROR: threadID '%@' is not in the the active or cancelling list! Added it to cancelling list", threadID);
                [cancellingIPCheckThreads addObject: threadID];
            }
        }
    }
    
    status = pthread_mutex_unlock( &threadIdsMutex );
    if (  status != EXIT_SUCCESS  ) {
        NSLog(@"pthread_mutex_unlock( &threadIdsMutex ) failed; status = %ld, errno = %ld", (long) status, (long) errno);
        return;
    }
}

-(BOOL) isOnCancellingListIPCheckThread: (NSString *) threadID
{
    OSStatus status = pthread_mutex_lock( &threadIdsMutex );
    if (  status != EXIT_SUCCESS  ) {
        NSLog(@"pthread_mutex_lock( &threadIdsMutex ) failed; status = %ld, errno = %ld", (long) status, (long) errno);
        return NO;
    }
    
    BOOL answer = ([cancellingIPCheckThreads containsObject: threadID] ? YES : NO);
    if (  answer  ) {
        NSLog(@"DEBUG: isOnCancellingListIPCheckThread: threadID '%@' is on the the cancelling list", threadID);
    } else {
        NSLog(@"DEBUG: isOnCancellingListIPCheckThread: threadID '%@' is not on the the cancelling list", threadID);
    }
    
    status = pthread_mutex_unlock( &threadIdsMutex );
    if (  status != EXIT_SUCCESS  ) {
        NSLog(@"pthread_mutex_unlock( &threadIdsMutex ) failed; status = %ld, errno = %ld", (long) status, (long) errno);
        return NO;
    }
    
    return answer;
}

-(void) haveFinishedIPCheckThread: (NSString *) threadID
{
    OSStatus status = pthread_mutex_lock( &threadIdsMutex );
    if (  status != EXIT_SUCCESS  ) {
        NSLog(@"pthread_mutex_lock( &threadIdsMutex ) failed; status = %ld, errno = %ld", (long) status, (long) errno);
        return;
    }
    
    if (  [activeIPCheckThreads containsObject: threadID]  ) {
        NSLog(@"DEBUG: haveFinishedIPCheckThread: threadID '%@' removed from active list", threadID);
        [activeIPCheckThreads removeObject: threadID];
    }
    
    if (  [cancellingIPCheckThreads containsObject: threadID]  ) {
        NSLog(@"DEBUG: haveFinishedIPCheckThread: threadID '%@' removed from cancelling list", threadID);
        [cancellingIPCheckThreads removeObject: threadID];
    }

    status = pthread_mutex_unlock( &threadIdsMutex );
    if (  status != EXIT_SUCCESS  ) {
        NSLog(@"pthread_mutex_unlock( &threadIdsMutex ) failed; status = %ld, errno = %ld", (long) status, (long) errno);
        return;
    }
}


#ifdef INCLUDE_VPNSERVICE
//*********************************************************************************************************
//
// VPNService screen support
//
//*********************************************************************************************************

-(IBAction) registerForTunnelblickWasClicked: (id) sender
{
    [vpnService showRegisterForTunneblickVPNScreen];
}

-(BOOL) tryToConnect: (NSString *) displayName
{
    VPNConnection * connection = [[self myVPNConnectionDictionary] objectForKey: displayName];
    if (  connection  ) {
        [self setVPNServiceConnectDisplayName: displayName];
        [connection connect: self userKnows: YES];
        return YES;
    }
    
    TBRunAlertPanel(NSLocalizedString(@"No configuration available", @"Window title VPNService"),
                    [NSString stringWithFormat:
                     NSLocalizedString(@"There is no configuration named '%@' installed.\n\n"
                                       "Try reinstalling SurfSafeVPN from a disk image.", @"Window text VPNService"),
                     displayName],
                    nil,nil,nil);
    [NSApp activateIgnoringOtherApps:YES];
    return NO;
}

-(VPNService *) vpnService
{
    return [[vpnService retain] autorelease];
}


-(NSString *) vpnServiceConnectDisplayName
{
    return [[vpnServiceConnectDisplayName retain] autorelease];
}

-(void) setVPNServiceConnectDisplayName: (NSString *) newValue
{
    if ( vpnServiceConnectDisplayName != newValue  ) {
        [vpnServiceConnectDisplayName release];
        vpnServiceConnectDisplayName = [newValue retain];
    }
}
#endif

//*********************************************************************************************************
//
// StatusWindowController support
//
//*********************************************************************************************************

-(void) statusWindowController: (id) ctl
            finishedWithChoice: (StatusWindowControllerChoice) choice
                forDisplayName: (NSString *) theName
{
	(void) ctl;
	
    VPNConnection * connection = [[self myVPNConnectionDictionary] objectForKey: theName];
    if (  connection  ) {
        if (  choice == statusWindowControllerDisconnectChoice  ) {
            [connection addToLog: @"*SurfSafeVPN: Disconnecting; Disconnect button pressed"];
            [connection disconnectAndWait: [NSNumber numberWithBool: YES] userKnows: YES];
        } else if (  choice == statusWindowControllerConnectChoice  ) {
            [connection addToLog: @"*SurfSafeVPN: Connecting; Connect button pressed"];
            if(![lastState isEqualToString:@"EXITING"]){
                //disabled multi connection
                //hide view
                [connection fadeAway];
                return;
            }
            [connection connect: self userKnows: YES];
        } else {
            NSLog(@"Invalid choice -- statusWindowController:finishedWithChoice: %d forDisplayName: %@", choice, theName);
        }
    } else {
        NSLog(@"Invalid displayName -- statusWindowController:finishedWithChoice: %d forDisplayName: %@", choice, theName);
    }
}

//*********************************************************************************************************
//
// AppleScript support
//
//*********************************************************************************************************

-(BOOL) application: (NSApplication *) sender delegateHandlesKey: (NSString *) key
{
	(void) sender;
	
    if ([key isEqual:@"applescriptConfigurationList"]) {
        return YES;
    } else {
        return NO;
    }
}

-(NSArray *) applescriptConfigurationList
{
    NSArray *keyArray = [[[self myVPNConnectionDictionary] allKeys] sortedArrayUsingSelector: @selector(caseInsensitiveNumericCompare:)];
    NSArray *myConnectionArray = [[self myVPNConnectionDictionary] objectsForKeys:keyArray notFoundMarker:[NSNull null]];
    return myConnectionArray;
}

//*********************************************************************************************************
//
// Getters and Setters
//
//*********************************************************************************************************

-(NSTimer *) showDurationsTimer
{
    return showDurationsTimer;
}

-(MyPrefsWindowController *) logScreen
{
    return logScreen;
}

-(NSString *) customRunOnConnectPath
{
    return customRunOnConnectPath;
}

-(SUUpdater *) updater
{
    //return [[updater retain] autorelease];
    return nil;
}

-(NSArray *) connectionsToRestoreOnUserActive
{
    return [[connectionsToRestoreOnUserActive retain] autorelease];
}

-(NSMutableArray *) largeAnimImages
{
    return [[largeAnimImages retain] autorelease];
}

-(NSImage *) largeConnectedImage
{
    return [[largeConnectedImage retain] autorelease];
}

-(NSImage *) largeMainImage
{
    return [[largeMainImage retain] autorelease];
}

-(NSString*) getLastState
{
    return [[lastState retain] autorelease];
}

-(NSArray *) animImages
{
    return [[animImages retain] autorelease];
}

-(NSImage *) connectedImage
{
    return [[connectedImage retain] autorelease];
}

-(NSImage *) mainImage
{
    return [[mainImage retain] autorelease];
}

TBSYNTHESIZE_OBJECT_GET(retain, NSStatusItem *, statusItem)
TBSYNTHESIZE_OBJECT_GET(retain, NSMenu *,       myVPNMenu)
TBSYNTHESIZE_OBJECT_GET(retain, NSMutableArray *, activeIPCheckThreads)
TBSYNTHESIZE_OBJECT_GET(retain, NSMutableArray *, cancellingIPCheckThreads)

TBSYNTHESIZE_OBJECT(retain, MainIconView *, ourMainIconView,           setOurMainIconView)
TBSYNTHESIZE_OBJECT(retain, NSDictionary *, myVPNConnectionDictionary, setMyVPNConnectionDictionary)
TBSYNTHESIZE_OBJECT(retain, NSDictionary *, myConfigDictionary,        setMyConfigDictionary)
TBSYNTHESIZE_OBJECT(retain, NSArray      *, connectionArray,           setConnectionArray)


// Event Handlers

-(void) showStatisticsWindowsTimerHandler: (NSTimer *) theTimer
{
    // Event handler; NOT on MainThread
    
	(void) theTimer;
	
    if (  gShuttingDownWorkspace  ) {  // Don't do anything if computer is shutting down or restarting
        return;
    }
    
    if (  [self mouseIsInsideAnyView] ) {
        [self performSelectorOnMainThread: @selector(showStatisticsWindows) withObject: nil waitUntilDone: NO];
    }
}

-(void) hideStatisticsWindowsTimerHandler: (NSTimer *) theTimer {
    // Event handler; NOT on MainThread
    
	(void) theTimer;
	
    if (  gShuttingDownWorkspace  ) {  // Don't do anything if computer is shutting down or restarting
        return;
    }
    
    if (  ! [self mouseIsInsideAnyView] ) {
        [[NSApp delegate] performSelectorOnMainThread: @selector(hideStatisticsWindows) withObject: nil waitUntilDone: NO];
    }
}    


-(void) showOrHideStatisticsWindowsAfterDelay: (NSTimeInterval) delay
                                fromTimestamp: (NSTimeInterval) timestamp
                                     selector: (SEL)            selector
{
    
    // Event handlers invoke this; NOT on MainThread
    
    if (  gShuttingDownWorkspace  ) {  // Don't do anything if computer is shutting down or restarting
        return;
    }
    
    NSTimeInterval timeUntilAct;
    if (  timestamp == 0.0  ) {
        timeUntilAct = 0.0;
	} else if (  ! runningOnLeopardOrNewer()  ) {
		timeUntilAct = delay;
    } else {
        uint64_t systemStartNanoseconds = nowAbsoluteNanoseconds();
        NSTimeInterval systemStart = (  ((NSTimeInterval) systemStartNanoseconds) / 1.0e9  );
        timeUntilAct = timestamp - systemStart + delay;
    }
    
    [NSTimer scheduledTimerWithTimeInterval: timeUntilAct
                                     target: self
                                   selector: selector
                                   userInfo: nil
                                    repeats: NO];
}

-(void) mouseEnteredMainIcon: (id) control event: (NSEvent *) theEvent  {
    // Event handlers invoke this; NOT on MainThread
    
	(void) control;
	
    if (  gShuttingDownWorkspace  ) {
        return;
    }
        
    mouseIsInMainIcon = TRUE;
    [self showOrHideStatisticsWindowsAfterDelay: gDelayToShowStatistics
                                  fromTimestamp: ( theEvent ? [theEvent timestamp] : 0.0)
                                       selector: @selector(showStatisticsWindowsTimerHandler:)];
}

-(void) mouseExitedMainIcon: (id) control event: (NSEvent *) theEvent {
    // Event handlers invoke this; NOT on MainThread
    
	(void) control;
	
    if (  gShuttingDownWorkspace  ) {
        return;
    }
    
    mouseIsInMainIcon = FALSE;
    [self showOrHideStatisticsWindowsAfterDelay: gDelayToHideStatistics
                                  fromTimestamp: ( theEvent ? [theEvent timestamp] : 0.0)
                                       selector: @selector(hideStatisticsWindowsTimerHandler:)];
}

-(void) mouseEnteredStatusWindow: (id) control event: (NSEvent *) theEvent  {
    // Event handlers invoke this; NOT on MainThread
    
	(void) control;
	
    if (  gShuttingDownWorkspace  ) {
        return;
    }
    
    mouseIsInStatusWindow = TRUE;
    [self showOrHideStatisticsWindowsAfterDelay: gDelayToShowStatistics
                                  fromTimestamp: ( theEvent ? [theEvent timestamp] : 0.0)
                                       selector: @selector(showStatisticsWindowsTimerHandler:)];
}

-(void) mouseExitedStatusWindow: (id) control event: (NSEvent *) theEvent {
    // Event handlers invoke this; NOT on MainThread
    
	(void) control;
	
    if (  gShuttingDownWorkspace  ) {
        return;
    }
    
    mouseIsInStatusWindow = FALSE;
    [self showOrHideStatisticsWindowsAfterDelay: gDelayToHideStatistics
                                  fromTimestamp: ( theEvent ? [theEvent timestamp] : 0.0)
                                       selector: @selector(hideStatisticsWindowsTimerHandler:)];
}


//*********************************************************************************************************
//
// SurfSafeUpdaterDelegate // HTK-INC
//
//*********************************************************************************************************
- (void) checkForUpdateStarted{
    NSLog(@"Started check update.");
}

- (void) checkForUpdateFinished: (BOOL) update generateFiles:(BOOL)gen{
    NSLog(@"Finished check update");
    if (gen){
        [ssUpdater generateFiles];
    }
    if (update)
        outOfDate = YES;
}


//*********************************************************************************************************
//
// SurfSafeVPN set restore proxies // HTK-INC
//
//*********************************************************************************************************
-(void) setEnableWebSWebProxies:(Proxy*) proxy{
    //[[ConfigurationNetwork sharedInstance] backupSystemProxies];
    
//    [[ConfigurationNetwork sharedInstance] setProxySetting:proxy protocol:kWEB service:kEthernet];    //HTK-INC2
//    [[ConfigurationNetwork sharedInstance] setProxySetting:proxy protocol:kWEB service:kWireless];    //HTK-INC2
//11.12.2012 disabled setProxySetting call by Valik-Plunk
/*    [[ConfigurationNetwork sharedInstance] setProxySetting:proxy protocol:kSWEB service:kEthernet];
    [[ConfigurationNetwork sharedInstance] setProxySetting:proxy protocol:kSWEB service:kWireless];*/
}

-(void) restoreWebSWebProxies{
//11.12.2012 disabled setProxySetting call by Valik-Plunk
    //[[ConfigurationNetwork sharedInstance] restoreSystemProxies];
}

@end
