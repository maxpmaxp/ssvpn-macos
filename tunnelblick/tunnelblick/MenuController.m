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
#import <mach/mach_time.h>
#import <pthread.h>
#import <sys/stat.h>
#import <sys/mount.h>
#import <uuid/uuid.h>
#import "defines.h"
#import "MenuController.h"
#import "NSApplication+LoginItem.h"
#import "NSApplication+NetworkNotifications.h"
#import "NSApplication+SystemVersion.h"
#import "NSApplication+Relaunch.h"
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


#ifdef INCLUDE_VPNSERVICE
#import "VPNService.h"
#endif

// These are global variables rather than class variables to make access to them easier
NSMutableArray        * gConfigDirs;            // Array of paths to configuration directories currently in use
NSString              * gDeployPath;            // Path to Tunnelblick.app/Contents/Resources/Deploy
NSString              * gPrivatePath;           // Path to ~/Library/Application Support/SurfSafeVPN/Configurations
NSString              * gSharedPath;            // Path to /Library/Application Support/SurfSafeVPN/Shared
TBUserDefaults        * gTbDefaults;            // Our preferences
NSFileManager         * gFileMgr;               // [NSFileManager defaultManager]
AuthorizationRef        gAuthorization;         // Used to call installer
NSArray               * gProgramPreferences;    // E.g., 'placeIconInStandardPositionInStatusBar'
NSArray               * gConfigurationPreferences; // E.g., '-onSystemStart'
BOOL                    gTunnelblickIsQuitting; // Flag that SurfSafeVPN is in the process of quitting
BOOL                    gComputerIsGoingToSleep;// Flag that the computer is going to sleep
unsigned                gHookupTimeout;         // Number of seconds to try to establish communications with (hook up to) an OpenVPN process
//                                              // or zero to keep trying indefinitely
unsigned                gMaximumLogSize;        // Maximum size (bytes) of buffer used to display the log
NSArray               * gRateUnits;             // Array of strings with localized data units      (KB/s, MB/s, GB/s, etc.)
NSArray               * gTotalUnits;            // Array of strings with localized data rate units (KB,   MB,   GB,   etc.)
NSTimeInterval          gDelayToShowStatistics; // Time delay from mouseEntered icon or statistics window until showing the statistics window
NSTimeInterval          gDelayToHideStatistics; // Time delay from mouseExited icon or statistics window until hiding the statistics window

UInt32 fKeyCode[16] = {0x7A, 0x78, 0x63, 0x76, 0x60, 0x61, 0x62, 0x64,        // KeyCodes for F1...F16
    0x65, 0x6D, 0x67, 0x6F, 0x69, 0x6B, 0x71, 0x6A};

void terminateBecauseOfBadConfiguration(void);

OSStatus hotKeyPressed(EventHandlerCallRef nextHandler,EventRef theEvent, void * userData);
OSStatus RegisterMyHelpBook(void);
BOOL checkOwnedByRootWheel(NSString * path);

extern BOOL folderContentsNeedToBeSecuredAtPath(NSString * theDirPath);
extern BOOL checkOwnerAndPermissions(NSString * fPath, uid_t uid, gid_t gid, NSString * permsShouldHave);

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

-(BOOL)             cannotRunFromVolume:                    (NSString *)        path;
-(NSURL *)          contactURL;
-(NSString *)       deconstructOpenVPNLogPath:              (NSString *)        logPath
                                       toPort:              (int *)             portPtr
                                  toStartArgs:              (NSString * *)      startArgsPtr;
-(NSArray *)        findTblksToInstallInPath:               (NSString *)        thePath;
-(void)             checkNoConfigurations;
-(void)             deleteExistingConfig:                   (NSString *)        dispNm;
-(void)             deleteLogs;
-(void)             dmgCheck;
-(void)             installCheck;
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
-(BOOL)             runInstallerRestoreDeploy:              (BOOL)              restore
                                      copyApp:              (BOOL)              copyApp
                                    repairApp:              (BOOL)              repairIt
                           moveLibraryOpenVPN:              (BOOL)              moveConfigs
                               repairPackages:              (BOOL)              repairPkgs
                                   copyBundle:              (BOOL)              copyBundle
                                 updateBundle:              (BOOL)              updateBundle;

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
@end

@implementation MenuController

-(id) init
{	
    if (self = [super init]) {
        
        if (  ! runningOnTigerOrNewer()  ) {
            TBRunAlertPanel(NSLocalizedString(@"System Requirements Not Met", @"Window title"),
                            NSLocalizedString(@"SurfSafe requires OS X 10.4 or above\n     (\"Tiger\", \"Leopard\", or \"Snow Leopard\")", @"Window text"),
                            nil, nil, nil);
            [NSApp setAutoLaunchOnLogin: NO];
            [NSApp terminate:self];
            
        }
        
               
        launchFinished = FALSE;
        hotKeyEventHandlerIsInstalled = FALSE;
        terminatingAtUserRequest = FALSE;
        gTunnelblickIsQuitting = FALSE;
        gComputerIsGoingToSleep = FALSE;
        areLoggingOutOrShuttingDown = FALSE;
        mouseIsInMainIcon = FALSE;
        mouseIsInStatusWindow = FALSE;
        
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
        
        gDeployPath = [[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent: @"Deploy"] copy];
        gSharedPath = [@"/Library/Application Support/SurfSafeVPN/Shared" copy];
        gPrivatePath = [[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/SurfSafeVPN/Configurations"] copy];
        
		gConfigDirs = [[NSMutableArray alloc] initWithCapacity: 2];
        
		[NSApp setDelegate: self];
		
        userIsAnAdmin = isUserAnAdmin();
        
        gProgramPreferences = [[NSArray arrayWithObjects:
                                @"skipWarningAboutReprotectingConfigurationFile",
                                @"skipWarningAboutSimultaneousConnections",
                                @"skipWarningThatCannotModifyConfigurationFile",
                                @"skipWarningThatNameChangeDisabledUpdates",
                                @"skipWarningAboutNonAdminUpdatingTunnelblick",
                                @"skipWarningAboutUnknownOpenVpnProcesses",
                                @"skipWarningAboutOnComputerStartAndTblkScripts",
                                @"skipWarningAboutIgnoredConfigurations",
                                @"skipWarningAboutConfigFileProtectedAndAlwaysExamineIt",
                                
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
                                
                                @"disableAdvancedButton",
                                @"disableCheckNowButton",
                                @"disableResetDisabledWarningsButton",
                                
                                @"disableAddConfigurationButton",
                                @"disableRemoveConfigurationButton",
                                @"disableWorkOnConfigurationButton",
                                
                                @"disableRenameConfigurationMenuItem",
                                @"disableDuplicateConfigurationMenuItem",
                                @"disableMakeConfigurationPublicOrPrivateMenuItem",
                                @"disableExamineOpenVpnConfigurationFileMenuItem",
                                @"disableShowOpenVpnLogInFinderMenuItem",
                                @"disableDeleteConfigurationCredentialsInKeychainMenuItem",
                                
                                @"disableCopyLogToClipboardButton",
                                
                                @"doNotShowNotificationWindowBelowIconOnMouseover",
                                @"doNotShowNotificationWindowOnMouseover",
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
                                
                                
                                @"WebKitDefaultFontSize",
                                @"WebKitStandardFont",
                                
                                @"ApplicationCrashedAfterRelaunch",
                                
                                // No longer used
                                @"doNotShowCheckForUpdatesNowMenuItem",
                                @"doNotShowForcedPreferenceMenuItems",
                                @"doNotShowKeyboardShortcutSubmenu",
                                @"doNotShowOptionsSubmenu",
                                
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
                                      @"-doNotReconnectOnUnexpectedDisconnect",
                                      @"-doNotShowOnTunnelblickMenu",
                                      nil] retain];
        
        // We haven't loaded the preferences yet, so we check them by checking the preference files directly
        // This means that the splash screen will show up for an update from a non-Deployed version to a Deployed versone that specifies
        // a forced preference to not display it. (Because we haven't replaced the Deploy folder yet.)
        BOOL showSplashScreen = TRUE;
        NSDictionary * dict = [NSDictionary dictionaryWithContentsOfFile: [gDeployPath stringByAppendingPathComponent: @"forced-preferences.plist"]];
        id obj = [dict objectForKey: @"doNotShowSplashScreen"];
        if (  obj  ) {
            if (  [obj respondsToSelector: @selector(boolValue)]  ) {
                if (  [obj boolValue]  ) {
                    showSplashScreen = FALSE;
                }
            }
        } else {
            NSString * prefsPath = [[[NSHomeDirectory() stringByAppendingPathComponent: @"Library/Preferences"]
                                     stringByAppendingPathComponent: [[NSBundle mainBundle] bundleIdentifier]]
                                     stringByAppendingPathExtension: @"plist"];
            dict = [NSDictionary dictionaryWithContentsOfFile: prefsPath];
            id obj = [dict objectForKey: @"doNotShowSplashScreen"];
            if (  obj  ) {
                if (  [obj respondsToSelector: @selector(boolValue)]  ) {
                    if (  [obj boolValue]  ) {
                        showSplashScreen = FALSE;
                    }
                }
            }
        }
        if (  showSplashScreen  ) {
            splashScreen = [[SplashWindowController alloc] init];
            NSString * text = NSLocalizedString(@"Starting SurfSafe...", @"Window text");
            [splashScreen setMessage: text];
            [splashScreen showWindow: self];
        }
        
        // Create private configurations folder if necessary
        createDir(gPrivatePath, 0755);
        
        ssUpdater = [[SurfSafeUpdater alloc] init];
        [ssUpdater setDelegate:(id) self];
        [ssUpdater checkForUpdate];
        [self dmgCheck];    // If running from a place that can't do suid (e.g., a disk image), THIS METHOD DOES NOT RETURN
        [self installCheck];
        
		
        // Run the installer only if necessary. The installer restores Resources/Deploy and/or repairs permissions,
        // moves the config folder if it hasn't already been moved, and backs up Resources/Deploy if it exists
        BOOL needsChangeOwnershipAndOrPermissions;
        BOOL needsMoveLibraryOpenVPN;
        BOOL needsRestoreDeploy;
        BOOL needsPkgRepair;
        BOOL needsBundleCopy;
        BOOL needsBundleUpdate;
        if (  needToRunInstaller(&needsChangeOwnershipAndOrPermissions,
                                 &needsMoveLibraryOpenVPN,
                                 &needsRestoreDeploy,
                                 &needsPkgRepair,
                                 &needsBundleCopy,
                                 &needsBundleUpdate,
                                 FALSE )  ) {
            
            NSString * text = NSLocalizedString(@"Securing SurfSafe...", @"Window text");
            [splashScreen setMessage: text];
            if (  ! [self runInstallerRestoreDeploy: needsRestoreDeploy
                                            copyApp: NO
                                          repairApp: needsChangeOwnershipAndOrPermissions
                                 moveLibraryOpenVPN: needsMoveLibraryOpenVPN
                                     repairPackages: needsPkgRepair
                                         copyBundle: needsBundleCopy            
                                        updateBundle: needsBundleUpdate]  ) {
                // runInstallerRestoreDeploy has already put up an error dialog and put a message in the console log if error occurred
                [NSApp setAutoLaunchOnLogin: NO];
                [NSApp terminate:self];
            }
            
            text = NSLocalizedString(@"SurfSafe has been secured successfully.", @"Window text");
            [splashScreen setMessage: text];
        }
        
        // SurfSafe check for update
        /*ConfigurationUpdater *cfgUpdater = [[ConfigurationUpdater alloc] initSurfSafe];
        [cfgUpdater checkForUpdate];*/
        
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
                            if (  lchmod != 0  ) {
                                if (  lchmod([oldPreferencesPath fileSystemRepresentation], S_IRUSR+S_IRGRP+S_IROTH) == EXIT_SUCCESS  ) {
                                    NSLog(@"Made the symbolic link read-only at %@", oldPreferencesPath);
                                } else {
                                    NSLog(@"Warning: Unable to make the symbolic link read-only at %@", oldPreferencesPath);
                                }
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
        // Otherwise use our equivalent of [NSUserDefaults standardUserDefaults]
        dict = [NSDictionary dictionaryWithContentsOfFile: [gDeployPath stringByAppendingPathComponent: @"forced-preferences.plist"]];
        gTbDefaults = [[TBUserDefaults alloc] initWithForcedDictionary: dict
                                                andSecondaryDictionary: nil
                                                     usingUserDefaults: YES];
        
        // Set default preferences as needed
        if (  [gTbDefaults objectForKey: @"showConnectedDurations"] == nil  ) {
            [gTbDefaults setBool: TRUE forKey: @"showConnectedDurations"];
        }
        
        [gTbDefaults scanForUnknownPreferencesInDictionary: dict displayName: @"Forced preferences"];
        
        NSString * bundleId = [[NSBundle mainBundle] bundleIdentifier];
        NSString * prefsPath = [[[[NSHomeDirectory()
                                   stringByAppendingPathComponent:@"Library"]
                                  stringByAppendingPathComponent:@"Preferences"]
                                 stringByAppendingPathComponent: bundleId]
                                stringByAppendingPathExtension: @"plist"];
        dict = [NSDictionary dictionaryWithContentsOfFile: prefsPath];
        [gTbDefaults scanForUnknownPreferencesInDictionary: dict displayName: @"Preferences"];
        
        // If Resources/Deploy exists now (perhaps after being restored) and has one or more .tblk packages or .conf or .ovpn files,
        // Then make it the first entry in gConfigDirs
        BOOL isDir;
        if (   [gFileMgr fileExistsAtPath: gDeployPath isDirectory: &isDir]
            && isDir ) {
            NSString * file;
            NSDirectoryEnumerator *dirEnum = [gFileMgr enumeratorAtPath: gDeployPath];
            while (file = [dirEnum nextObject]) {
                NSString * path = [gDeployPath stringByAppendingPathComponent: file];
                if (  itemIsVisible(path)  ) {
                    NSString * ext  = [file pathExtension];
                    if (   [gFileMgr fileExistsAtPath: path isDirectory: &isDir]
                        && ( ! isDir)  ) {
                        if ( [ext isEqualToString:@"conf"] || [ext isEqualToString:@"ovpn"]  ) {
                            [gConfigDirs addObject: [[gDeployPath copy] autorelease]];
                            break;
                        }
                    } else {
                        if ( [ext isEqualToString:@"tblk"]  ) {
                            [gConfigDirs addObject: [[gDeployPath copy] autorelease]];
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
            [gConfigDirs addObject: [[gSharedPath  copy] autorelease]];
            [gConfigDirs addObject: [[gPrivatePath copy] autorelease]];
        } else {
            if (  ! [gTbDefaults canChangeValueForKey: @"useSharedConfigurationsWithDeployedOnes"]  ) {
                if (  [gTbDefaults boolForKey: @"useSharedConfigurationsWithDeployedOnes"]  ) {
                    [gConfigDirs addObject: [[gSharedPath copy] autorelease]];
                }
            }
            if (  ! [gTbDefaults canChangeValueForKey: @"usePrivateConfigurationsWithDeployedOnes"]  ) {
                if (  [gTbDefaults boolForKey: @"usePrivateConfigurationsWithDeployedOnes"]  ) {
                    [gConfigDirs addObject: [[gPrivatePath copy] autorelease]];
                }
            }
        }
        
        [self createLinkToApp];
        
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
            [NSApp setAutoLaunchOnLogin: NO];
            [NSApp terminate: self];
        }
        
		[self createStatusItem];
		
        // Get hot key keyCode and modifiers
        id code = [gTbDefaults objectForKey: @"keyboardShortcutKeyCode"];
        if (  [code respondsToSelector: @selector(unsignedIntValue)]  ) {
            hotKeyKeyCode = (UInt32) [code unsignedIntValue];
        } else {
            hotKeyKeyCode = 0x7A;   /* F1 key */
        }
        code = [gTbDefaults objectForKey: @"keyboardShortcutModifiers"];
        if (  [code respondsToSelector: @selector(unsignedIntValue)]  ) {
            hotKeyModifierKeys = (UInt32) [code unsignedIntValue];
        } else {
            hotKeyModifierKeys = cmdKey+optionKey;
        }
        
        myConfigDictionary = [[[ConfigurationManager defaultManager] getConfigurations] copy];
        
        // set up myVPNConnectionDictionary, which has the same keys as myConfigDictionary, but VPNConnections as objects
        NSMutableDictionary * tempVPNConnectionDictionary = [[NSMutableDictionary alloc] init];
        NSString * dispNm;
        NSEnumerator * e = [myConfigDictionary keyEnumerator];
        while (dispNm = [e nextObject]) {
            NSString * cfgPath = [[self myConfigDictionary] objectForKey: dispNm];
            // configure connection object:
            VPNConnection* myConnection = [[VPNConnection alloc] initWithConfigPath: cfgPath
                                                                    withDisplayName: dispNm];
            [myConnection setDelegate:self];
            [tempVPNConnectionDictionary setObject: myConnection forKey: dispNm];
        }
        [self setMyVPNConnectionDictionary: [[tempVPNConnectionDictionary copy] autorelease]];
        [tempVPNConnectionDictionary release];
        
		[self createMenu];
        
        // logScreen is a MyPrefsWindowController, but the sharedPrefsWindowController is a DBPrefsWindowController
        logScreen = (id) [MyPrefsWindowController sharedPrefsWindowController];
        
        [self setState: @"EXITING"]; // synonym for "Disconnected"
        
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
		
        updater = [[SUUpdater alloc] init];
        myConfigUpdater = [[ConfigurationUpdater alloc] init]; // Set up a separate Sparkle Updater for configurations   

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
                while (file = [dirEnum nextObject]) {
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

-(void) createLinkToApp
{
    // Create a link to this application in the private configurations folder if we are using it
    if (  [gConfigDirs containsObject: gPrivatePath]  ) {
        if (  ! [gTbDefaults boolForKey: @"doNotCreateLaunchTunnelblickLinkinConfigurations"]  ) {
            NSString * pathToThisApp = [[NSBundle mainBundle] bundlePath];
            NSString * launchSurfSafeVPNSymlinkPath = [gPrivatePath stringByAppendingPathComponent: @"Launch SurfSafeVPN"];
            NSString * linkContents = [gFileMgr tbPathContentOfSymbolicLinkAtPath: launchSurfSafeVPNSymlinkPath];
            if (  linkContents == nil  ) {
                [gFileMgr tbRemoveFileAtPath:launchSurfSafeVPNSymlinkPath handler: nil];
                if (  [gFileMgr tbCreateSymbolicLinkAtPath: launchSurfSafeVPNSymlinkPath
                                               pathContent: pathToThisApp]  ) {
                    NSLog(@"Created 'Launch SurfSafe' link in Configurations folder; links to %@", pathToThisApp);
                } else {
                    NSLog(@"Unable to create 'Launch SurfSafe' link in Configurations folder linking to %@", pathToThisApp);
                }
            } else if (  ! [linkContents isEqualToString: pathToThisApp]  ) {
                ignoreNoConfigs = TRUE; // We're dealing with no configs already, and will either quit or create one
                if (  ! [gFileMgr tbRemoveFileAtPath:launchSurfSafeVPNSymlinkPath handler: nil]  ) {
                    NSLog(@"Unable to remove %@", launchSurfSafeVPNSymlinkPath);
                }
                if (  [gFileMgr tbCreateSymbolicLinkAtPath: launchSurfSafeVPNSymlinkPath
                                               pathContent: pathToThisApp]  ) {
                    NSLog(@"Replaced 'Launch SurfSafe' link in Configurations folder; now links to %@", pathToThisApp);
                } else {
                    NSLog(@"Unable to create 'Launch SurfSafe' link in Configurations folder linking to %@", pathToThisApp);
                }
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
    [gDeployPath release];
    [dotTblkFileList release];
    [lastState release];
    [gPrivatePath release];
    [myConfigDictionary release];
    [myVPNConnectionDictionary release];
    [myVPNMenu release];
    [hookupWatchdogTimer invalidate];
    [hookupWatchdogTimer release];
    [theAnim release];
    [updater release];
    [ssUpdater release];
    [myConfigUpdater release];
    [customMenuScripts release];
    [customRunOnLaunchPath release];
    [customRunOnConnectPath release];
    
    [aboutItem release];
    [checkForUpdatesNowItem release];
    [vpnDetailsItem release];
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
	[self performSelectorOnMainThread: @selector(createStatusItem) withObject: nil waitUntilDone: NO];
}


- (IBAction) quit: (id) sender
{
    terminatingAtUserRequest = TRUE;
    [NSApp terminate: sender];
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
        iconSetDir = [[gSharedPath stringByAppendingPathComponent: @"IconSets"] stringByAppendingPathComponent: iconSetName];
        if (  ! (   [gConfigDirs containsObject: gSharedPath]
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
    
    int nFrames = 0;
    int i=0;
    NSString *file;
    NSString *fullPath;
    NSDirectoryEnumerator *dirEnum = [gFileMgr enumeratorAtPath: iconSetDir];
    NSArray *allObjects = [dirEnum allObjects];
    
    [*ptrAnimImages release];
    *ptrAnimImages = [[NSMutableArray alloc] init];
    
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
    if (  theAnim == nil  ) {
        int i;
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
    [registerForTunnelblickItem setTitle: NSLocalizedString(@"Register for SurfSafe...", @"Menu item VPNService")];
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
    
    [vpnDetailsItem release];
    vpnDetailsItem = [[NSMenuItem alloc] init];
    [vpnDetailsItem setTitle: NSLocalizedString(@"VPN Details...", @"Menu item")];
    [vpnDetailsItem setTarget: self];
    [vpnDetailsItem setAction: @selector(openPreferencesWindow:)];
    
    [contactTunnelblickItem release];
    contactTunnelblickItem = nil;
    if ( ! [gTbDefaults boolForKey: @"doNotShowSuggestionOrBugReportMenuItem"]  ) {
        if (  [self contactURL]  ) {
            NSString * menuTitle = nil;
            NSDictionary * infoPlist = [[NSBundle mainBundle] infoDictionary];
            if (  [[infoPlist objectForKey: @"CFBundleShortVersionString"] rangeOfString: @"beta"].length != 0  ) {
                if (  [NSLocalizedString(@"SurfSafe", "Window title") isEqualToString: @"Surf" "Safe"]  ) {
                    if (  [@"SurfSafe" isEqualToString: @"Surf" "Safe"]  ) {
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
    [quitItem setTitle: NSLocalizedString(@"Quit SurfSafe", @"Menu item")];
    [quitItem setTarget: self];
    [quitItem setAction: @selector(quit:)];
    
    [statusMenuItem release];
	statusMenuItem = [[NSMenuItem alloc] init];
    [statusMenuItem setTarget: self];
    [statusMenuItem setAction: @selector(disconnectAllMenuItemWasClicked:)];
    

    [myVPNMenu release];
	myVPNMenu = [[NSMenu alloc] init];
    [myVPNMenu setDelegate:self];

    // Add an NSView to the icon to track mouseEntered and mouseExited events for the statistics display
    [self setOurMainIconView: [[[MainIconView alloc] initWithFrame: NSMakeRect(0.0, 0.0, 20.0, 23.0)] autorelease]];
    [statusItem setView: [self ourMainIconView]];
    [statusItem setHighlightMode:YES];
	[statusItem setMenu: myVPNMenu];
    
	[myVPNMenu addItem:statusMenuItem];
	
    [myVPNMenu addItem:[NSMenuItem separatorItem]];
    
    // Add each connection to the menu
    NSString * dispNm;
    NSArray *keyArray = [[self myConfigDictionary] allKeys];
	NSEnumerator * e = [keyArray objectEnumerator];
    while (dispNm = [e nextObject]) {
        if (  ! [gTbDefaults boolForKey: [dispNm stringByAppendingString: @"-doNotShowOnTunnelblickMenu"]]  ) {
            // configure connection object:
            NSMenuItem *connectionItem = [[[NSMenuItem alloc] init] autorelease];
            VPNConnection* myConnection = [[self myVPNConnectionDictionary] objectForKey: dispNm];
            
            // Note: The menu item's title will be set on demand in VPNConnection's validateMenuItem
            [connectionItem setTarget:myConnection]; 
            [connectionItem setAction:@selector(toggle:)];
            
            [self insertConnectionMenuItem: connectionItem IntoMenu: myVPNMenu afterIndex: 2 withName: dispNm];
        }
    }
    
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
                    [self insertConnectionMenuItem: theItem IntoMenu: subMenu afterIndex: 0 withName: restOfName];
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
    while (file = [dirEnum nextObject]) {
        [dirEnum skipDescendents];
        [itemsInMenuFolder addObject: file];
    }
    
    // Sort the list
	NSArray *sortedArray = [itemsInMenuFolder sortedArrayUsingSelector: @selector(caseInsensitiveNumericCompare:)];

    // Use the sorted list to add items to the Tunnelblick menu, or to run them on launch or on connect
    BOOL haveAddedItems = FALSE;
    BOOL isDir;
    
    int i;
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
    NSString * scriptPath = [customMenuScripts objectAtIndex: tag];
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
    [self createMenu];
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
                            workingName: (NSString *) workingName;
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
            while (  conn = [connEnum nextObject]  ) {
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
            while (  conn = [connEnum nextObject]  ) {
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
    while (dispNm = [e nextObject]) {
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
    while (dispNm = [e nextObject]) {
        BOOL sameDispNm = [curConfigsDict objectForKey: dispNm] != nil;
        if (  ! sameDispNm  ) {
            [removeList addObject: [[dispNm copy] autorelease]]; // No new config with same name
        }
    }
    e = [removeList objectEnumerator];
    while (  dispNm = [e nextObject]  ) {
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
        [myConnection addToLog: @"*SurfSafe: Disconnecting; user asked to delete the configuration"];
        [myConnection disconnectAndWait: [NSNumber numberWithBool: NO] userKnows: YES];
        
        TBRunAlertPanel([NSString stringWithFormat: NSLocalizedString(@"'%@' has been disconnected", @"Window title"), dispNm],
                        [NSString stringWithFormat: NSLocalizedString(@"SurfSafe has disconnected '%@' because its configuration file has been removed.", @"Window text"), dispNm],
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
}

- (void) updateUI
{
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
}

- (void)animationDidEnd:(NSAnimation*)animation
{
	if (   (![lastState isEqualToString:@"EXITING"])
        && (![lastState isEqualToString:@"CONNECTED"]))
	{
		// NSLog(@"Starting Animation (2)");
		[theAnim startAnimation];
	}
}

- (void)animation:(NSAnimation *)animation didReachProgressMark:(NSAnimationProgress)progress
{
	if (animation == theAnim)
	{
        [[self ourMainIconView] performSelectorOnMainThread:@selector(setImage:) withObject:[animImages objectAtIndex:lround(progress * [animImages count]) - 1] waitUntilDone:YES];
	}
}

- (NSString *) openVPNLogHeader
{
    unsigned major, minor, bugFix;
    [[NSApplication sharedApplication] getSystemVersionMajor:&major minor:&minor bugFix:&bugFix];
    return ([NSString stringWithFormat:@"*SurfSafe: OS X %d.%d.%d; %@", major, minor, bugFix, tunnelblickVersion([NSBundle mainBundle])]);
}

- (void) checkForUpdates: (id) sender
{
    
    if (   [gTbDefaults boolForKey:@"onlyAdminCanUpdate"]
        && ( ! userIsAnAdmin )  ) {
        NSLog(@"Check for updates was not performed because user is not allowed to administer this computer and 'onlyAdminCanUpdate' preference is set");
    } else {
        if (  [updater respondsToSelector: @selector(checkForUpdates:)]  ) {
            if (  feedURL != nil  ) {
                if (  ! userIsAnAdmin  ) {
                    int response = TBRunAlertPanelExtended(NSLocalizedString(@"Only computer administrators should update SurfSafe", @"Window title"),
                                                           NSLocalizedString(@"You will not be able to use SurfSafe after updating unless you provide an administrator username and password.\n\nAre you sure you wish to check for updates?", @"Window text"),
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
     
}

// May be called from cleanup or willGoToSleepHandler, so only do one at a time
static pthread_mutex_t killAllConnectionsIncludingDaemonsMutex = PTHREAD_MUTEX_INITIALIZER;
    
// If possible, we try to use 'killall' to kill all processes named 'openvpn'
// But if there are unknown open processes that the user wants running, or we have active daemon processes,
//     then we must use 'kill' to kill each individual process that should be killed
-(void) killAllConnectionsIncludingDaemons: (BOOL) includeDaemons logMessage: (NSString *) logMessage
{
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
        while (  connection = [connEnum nextObject]  ) {
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
    
    if (   includeDaemons
        || ( noUnknownOpenVPNsRunning && noActiveDaemons )  ) {
        
        // Killing everything, so we use 'killall' to kill all processes named 'openvpn'
        // But first append a log entry for each connection that will be restored
        NSEnumerator * connectionEnum = [connectionsToRestoreOnWakeup objectEnumerator];
        while (  connection = [connectionEnum nextObject]) {
            [connection addToLog: logMessage];
        }
        // If we've added any log entries, sleep for one second so they come before OpenVPN entries associated with closing the connections
        if (  [connectionsToRestoreOnWakeup count] != 0  ) {
            sleep(1);
        }
        NSString* path = [[NSBundle mainBundle] pathForResource: @"openvpnstart" ofType: nil];
        NSTask* task = [[[NSTask alloc] init] autorelease];
        [task setLaunchPath: path];
        [task setArguments: [NSArray arrayWithObject: @"killall"]];
        [task launch];
        [task waitUntilExit];
    } else {
        
        // Killing selected processes only -- those we know about that are not daemons
        while (  connection = [connEnum nextObject]  ) {
            if (  ! [connection isDisconnected]  ) {
                NSString* onSystemStartKey = [[connection displayName] stringByAppendingString: @"-onSystemStart"];
                NSString* autoConnectKey = [[connection displayName] stringByAppendingString: @"autoConnect"];
                if (   ( ! [gTbDefaults boolForKey: onSystemStartKey]  )
                    || ( ! [gTbDefaults boolForKey: autoConnectKey]    )  ) {
                    pid_t procId = [connection pid];
                    if (  procId > 0  ) {
                        [connection addToLog: logMessage];
                        NSString* path = [[NSBundle mainBundle] pathForResource: @"openvpnstart" ofType: nil];
                        NSTask* task = [[[NSTask alloc] init] autorelease];
                        [task setLaunchPath: path];
                        [task setArguments: [NSArray arrayWithObjects: @"kill", [NSString stringWithFormat: @"%ld", (long) procId], nil]];
                        [task launch];
                        [task waitUntilExit];
                    } else {
                        [connection addToLog: @"*SurfSafe: Disconnecting; all configurations are being disconnected"];
                        [connection disconnectAndWait: [NSNumber numberWithBool: NO] userKnows: NO];
                    }
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
            NSString* path = [[NSBundle mainBundle] pathForResource: @"openvpnstart" 
                                                             ofType: nil];
            NSTask* task = [[NSTask alloc] init];
            [task setLaunchPath: path]; 
            
            NSArray *arguments = [NSArray arrayWithObjects:@"unloadKexts", arg1, nil];
            [task setArguments:arguments];
            [task launch];
            [task waitUntilExit];
            [task release];
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
	while (connection = [e nextObject]) {
		if ([[connection connectedSinceDate] timeIntervalSinceNow] < -5) {
			if (NSDebugEnabled) NSLog(@"Resetting connection: %@",[connection displayName]);
            [connection addToLog: @"*SurfSafe: Disconnecting; resetting all connections"];
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
// Thus there is a time when there may not be a Deploy folder (if the update doesn't have one and we will restore from the backup).
// We don't want to complain to the user about not having any configurations, though. So if we had deployed configurations when we were launched,
// then we ignore the absense of configurations -- the relaunch will restore the old Deploy folder with its configurations.
-(void) checkNoConfigurations
{
    if (   ignoreNoConfigs
        || ( [[self myConfigDictionary] count] != 0 )
        || (   ([gConfigDirs count] != 0)
            && [[gConfigDirs objectAtIndex: 0] isEqualToString: gDeployPath] ) // True only if we had configurations in Deploy when launched
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
                        [NSString stringWithFormat: NSLocalizedString(@"All configuration files in %@ have been removed. SurfSafe must quit.", @"Window text"),
                         [[gFileMgr componentsToDisplayForPath: gDeployPath] componentsJoinedByString: @"/"]],
                        nil, nil, nil);
        [NSApp setAutoLaunchOnLogin: NO];
        [NSApp terminate: nil];
    }
    
    [[ConfigurationManager defaultManager] haveNoConfigurationsGuide];
}

-(IBAction) addConfigurationWasClicked: (id) sender
{
    [[ConfigurationManager defaultManager] addConfigurationGuide];
}

-(IBAction) disconnectAllMenuItemWasClicked: (id) sender
{
    NSEnumerator * connEnum = [[self myVPNConnectionDictionary] objectEnumerator];
    VPNConnection * connection;
    while (  connection = [connEnum nextObject]  ) {
        if (  ! [connection isDisconnected]  ) {
            [connection addToLog: @"*SurfSafe: Disconnecting; 'Disconnect all' menu command invoked"];
            [connection disconnectAndWait: [NSNumber numberWithBool: NO] userKnows: YES];
        }
    }
}

-(IBAction) contactTunnelblickWasClicked: (id) sender
{
    NSURL * url = [self contactURL];
    if (  url  ) {
        [[NSWorkspace sharedWorkspace] openURL: url];
    }
}

-(NSURL *) contactURL
{
    NSString * string = [NSString stringWithFormat: @"http://www.tunnelblick.net/contact?v=%@", tunnelblickVersion([NSBundle mainBundle])];
    string = [string stringByAddingPercentEscapesUsingEncoding: NSASCIIStringEncoding];
    NSURL * url = [NSURL URLWithString: string];
    if (  ! url  ) {
        NSLog(@"Invalid contactURL");
    }
    
    return url;
}

-(IBAction) openPreferencesWindow: (id) sender
{
    [[MyPrefsWindowController sharedPrefsWindowController] showWindow: nil];
    [NSApp activateIgnoringOtherApps:YES];  // Force Preferences window to front (if it already exists and is covered by another window)

}

- (void) networkConfigurationDidChange
{
	if (NSDebugEnabled) NSLog(@"Got networkConfigurationDidChange notification!!");
	[self resetActiveConnections];
}

- (void) applicationWillTerminate: (NSNotification*) notification
{
    terminatingAtUserRequest = TRUE;
    if (  ! areLoggingOutOrShuttingDown  ) {
        [NSApp setAutoLaunchOnLogin: NO];
    }
    
    [self cleanup];
}

static pthread_mutex_t cleanupMutex = PTHREAD_MUTEX_INITIALIZER;

-(void)cleanup 
{
    OSStatus status = pthread_mutex_trylock( &cleanupMutex );
    if (  status != EXIT_SUCCESS  ) {
        NSLog(@"pthread_mutex_trylock( &cleanupMutex ) failed; status = %ld, errno = %ld", (long) status, (long) errno);
        NSLog(@"pthread_mutex_trylock( &cleanupMutex ) failed is normal and expected when SurfSafe is updated");
        return;
    }
    
    gTunnelblickIsQuitting = TRUE;

    // DO NOT ever unlock cleanupMutex -- we don't want to allow another cleanup to take place
    
    if (  hotKeyEventHandlerIsInstalled && hotKeyModifierKeys != 0  ) {
        UnregisterEventHotKey(hotKeyRef);
    }
    
	[NSApp callDelegateOnNetworkChange: NO];
    [self killAllConnectionsIncludingDaemons: NO logMessage: @"*SurfSafe: SurfSafe is quitting. Closing connection..."];  // Kill any of our OpenVPN processes that still exist unless they're "on computer start" configurations
    [self unloadKexts];     // Unload .tun and .tap kexts
    [self deleteLogs];
	if (  statusItem  ) {
        [[NSStatusBar systemStatusBar] removeStatusItem:statusItem];
    }
}

-(void) deleteLogs
{
    VPNConnection * connection;
    NSEnumerator * e = [[self myVPNConnectionDictionary] objectEnumerator];
    while (connection = [e nextObject]) {
        [connection deleteLogs];
    }
}

- (void) setState: (NSString*) newState
// Be sure to call this in main thread only
{
    // Decide how to display the Tunnelblick icon:
    // Ignore the newState argument and look at the configurations:
    //   If any configuration should be open but isn't open and isn't closed, then show animation
    //   If any configuration should be closed but isn't, then show animation
    //   Otherwise, if any configurations are open, show open
    //              else show closed
    BOOL atLeastOneIsConnected = FALSE;
    NSString * newDisplayState = @"EXITING";
    VPNConnection * connection;
    NSEnumerator * connEnum = [[self myVPNConnectionDictionary] objectEnumerator];
    while (  connection = [connEnum nextObject]  ) {
        NSString * curState = [connection state];
        NSString * reqState = [connection requestedState];
        if     (  [reqState isEqualToString: @"CONNECTED"]  ) {
            if (  [curState isEqualToString: @"CONNECTED"]  ) {
                atLeastOneIsConnected = TRUE;
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
        [self setConnectionArray: [tempConnectionArray copy]];
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
        [self setConnectionArray: [tempConnectionArray copy]];
        [tempConnectionArray release];
        status = pthread_mutex_unlock( &connectionArrayMutex );
        if (  status != EXIT_SUCCESS  ) {
            NSLog(@"pthread_mutex_unlock( &connectionArrayMutex ) failed; status = %ld, errno = %ld", (long) status, (long) errno);
            return;
        }    
        
        [self startOrStopDurationsTimer];
    }
}

static void signal_handler(int signalNumber)
{
    printf("signal %d caught!\n",signalNumber);
    
    if (signalNumber == SIGHUP) {
        printf("SIGHUP received. Restarting active connections\n");
        [[NSApp delegate] resetActiveConnections];
    } else  {
        printf("Received fatal signal. Cleaning up\n");
        [NSApp setAutoLaunchOnLogin: NO];
        [[NSApp delegate] cleanup];
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
    
    // Get version of bundle whose contents we are installing, so we can (later) update /Library/Application Support/.../Tunnelblick Configurations.bundle
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
                NSString * msg = NSLocalizedString(@"SurfSafe needs to install one or more SurfSafe VPN Configurations.", @"Window text");
                gAuthorization = [NSApplication getAuthorizationRef: msg];
                gotMyAuth = TRUE;
            }
            
            if (  ! gAuthorization  ) {
                NSLog(@"Configuration update installer: The SurfSafe installation was cancelled by the user.");
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
        NSString * msg = NSLocalizedString(@"SurfSafe needs to install one or more SurfSafe VPN Configurations.", @"Window text");
        gAuthorization = [NSApplication getAuthorizationRef: msg];
        gotMyAuth = TRUE;
    }
    
    if (  ! gAuthorization  ) {
        NSLog(@"Configuration update installer: The SurfSafe installation was cancelled by the user.");
        return;
    }
    
    NSString * masterPlistPath = [CONFIGURATION_UPDATES_BUNDLE_PATH stringByAppendingPathComponent: @"Contents/Info.plist"];

    NSString *launchPath = [[NSBundle mainBundle] pathForResource:@"installer" ofType:nil];
    NSArray * arguments = [NSArray arrayWithObjects: [NSString stringWithFormat: @"%u", INSTALLER_SET_VERSION], version, versionShortString, nil];
    
    BOOL okNow = FALSE; // Assume failure
    int i;
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
                NSLog(@"Configuration update installer: Timed out waiting for installer execution to succeed");
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
    NSLog(@"Install SurfSafe update.");
    /*
    int response = TBRunAlertPanelExtended(NSLocalizedString(@"Only computer administrators should update SurfSafe", @"Window title"),
                                           NSLocalizedString(@"You will not be able to use SurfSafe after updating unless you provide an administrator username and password.\n\nAre you sure you wish to check for updates?", @"Window text"),
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
                                           nil);
    
    if (  response == NSAlertAlternateReturn  ) {
        return;
    }
    [ssUpdater downloadDmgFile];
    NSString *updatePath = [NSHomeDirectory() stringByAppendingPathComponent:UPDATE_PATH];
    NSString *drive = @"/Volumes/SurfSafeVPN";
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
        NSLog(@"SurfSafe Installer: Unable to copy %@ to %@", currentPath, targetPath);
    } else {
        NSLog(@"SurfSafe Installer: Copied %@ to %@", currentPath, targetPath);
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
                            NSLog(@"SurfSafe has a digital signature but also has a Deploy folder");
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
        [gTbDefaults setBool: [updater automaticallyDownloadsUpdates]       // But if it is forced, this setBool will be ignored
                      forKey: @"updateAutomatically"];
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
        NSString * text = NSLocalizedString(@"Installing SurfSafe VPN Configurations...", @"Window text");
        [splashScreen setMessage: text];

        [[ConfigurationManager defaultManager] openDotTblkPackages: dotTblkFileList
                                                         usingAuth: gAuthorization
                                           skipConfirmationMessage: YES
                                                 skipResultMessage: YES];
        text = NSLocalizedString(@"Installation finished successfully.", @"Window text");
        [splashScreen setMessage: text];

        ignoreNoConfigs = oldIgnoreNoConfigs;
    }
    
    [myConfigUpdater startWithUI: NO];    // Start checking for configuration updates in the background (when the application updater is finished)
    
    // Set up to monitor configuration folders
    myQueue = [UKKQueue sharedFileWatcher];
    if (  ! [gTbDefaults boolForKey:@"doNotMonitorConfigurationFolder"]  ) {
        int i;
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
    while (  connection = [connEnum nextObject]  ) {
        if (  ! [connection tryingToHookup]  ) {
            [logScreen validateWhenConnectingForConnection: connection];
        }
    }
    
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
                NSLog(@"SurfSafe runOnLaunch item %@ returned %d; SurfSafe launch cancelled", customRunOnLaunchPath, status);
                [NSApp terminate:self];
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
        while (dispNm = [listEnum nextObject]) {
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
    
    if (  hotKeyModifierKeys != 0  ) {
        [self setupHotKeyWithCode: hotKeyKeyCode andModifierKeys: hotKeyModifierKeys]; // Set up hotkey to reveal the SurfSafeVPN menu (since VoiceOver can't access the SurfSafeVPN in the System Status Bar)
    }
    
    // Install easy-rsa if it isn't installed already
    NSString * easyRsaPath = userEasyRsaPath(NO);
    BOOL exists = FALSE;
    BOOL isDir  = FALSE;
    if (  easyRsaPath  ) {
        exists = [gFileMgr fileExistsAtPath: easyRsaPath isDirectory: &isDir];
    }
    
    if (   ( ! easyRsaPath )
        || (   exists && ( ! isDir ) )  ) {
            NSLog(@"The 'easy-rsaPath' preference is invalid");
            TBRunAlertPanel(NSLocalizedString(@"Warning!", @"Window title"),
                            NSLocalizedString(@"The 'easy-rsaPath' preference is invalid. easy-rsa will not be available until the preference is removed or corrected.", @"Window title"),
                            nil, nil, nil);
    } else {
        if (  ! exists  ) {
            updateEasyRsa(YES);
        }
    }

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
                NSLog(@"SurfSafe does not include any versions of OpenVPN");
                [NSApp terminate: self];
                return;
            }
            
            TBRunAlertPanel(NSLocalizedString(@"SurfSafe", @"Window title"),
                            [NSString stringWithFormat: NSLocalizedString(@"OpenVPN version %@ is not available. Using the default, version %@", @"Window text"),
                             prefVersion, useVersion],
                            nil, nil, nil);
            [gTbDefaults removeObjectForKey: @"openvpnVersion"];
        }
    }
    
    NSString * text = NSLocalizedString(@"SurfSafe is ready.", @"Window text");
    [splashScreen setMessage: text];

    [splashScreen fadeOutAndClose];
    
    launchFinished = TRUE;
    
}

// Returns TRUE if a hookupWatchdog timer was created or already exists
-(BOOL) setupHookupWatchdogTimer
{
    if (  hookupWatchdogTimer  ) {
        return TRUE;
    }
    
    gHookupTimeout = 5; // Default
    id hookupTimeout;
    if (  (hookupTimeout = [gTbDefaults objectForKey: @"hookupTimeout"])  ) {
        if (  [hookupTimeout respondsToSelector: @selector(intValue)]  ) {
            gHookupTimeout = [hookupTimeout intValue];
        } else {
            NSLog(@"'hookupTimeout' preference is being ignored because it is not a number");
        }
    }
    
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
        int i;
        for (i = 0; i < [gConfigDirs count]; i++) {
            [[NSApp delegate] removePath: [gConfigDirs objectAtIndex: i] fromMonitorQueue: myQueue];
        }
    } else {
        int i;
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
    while (  file = [dirEnum nextObject]  ) {
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
    while (  file = [dirEnum nextObject]  ) {
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
        int result = TBRunAlertPanelExtended(NSLocalizedString(@"Warning: Unknown OpenVPN processes", @"Window title"),
                                             NSLocalizedString(@"One or more OpenVPN processes are running but are unknown to SurfSafe. If you are not running OpenVPN separately from SurfSafe, this usually means that an earlier launch of SurfSafe was unable to shut them down properly and you should terminate them. They are likely to interfere with SurfSafe's operation. Do you wish to terminate them?", @"Window text"),
                                             NSLocalizedString(@"Ignore", @"Button"),
                                             NSLocalizedString(@"Terminate", @"Button"),
                                             nil,
                                             @"skipWarningAboutUnknownOpenVpnProcesses",
                                             NSLocalizedString(@"Do not ask again, always 'Ignore'", @"Checkbox name"),
                                             nil);
        if (  result == NSAlertAlternateReturn  ) {
            NSNumber * pidNumber;
            NSEnumerator * pidsEnum = [pIDsWeAreTryingToHookUpTo objectEnumerator];
            while (  pidNumber = [pidsEnum nextObject]  ) {
                
                NSString* path = [[NSBundle mainBundle] pathForResource: @"openvpnstart" ofType: nil];
                NSString *pidString = [NSString stringWithFormat:@"%d", [pidNumber intValue]];
                NSArray *arguments = [NSArray arrayWithObjects:@"kill", pidString, nil];
                
                NSTask* task = [[[NSTask alloc] init] autorelease];
                [task setLaunchPath: path]; 
                [task setArguments:arguments];
                [task setCurrentDirectoryPath: @"/tmp"];    // Won't be used, but we need to specify something
                [task launch];
                [task waitUntilExit];
                noUnknownOpenVPNsRunning = YES;
            }
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
    while (  connection = [connEnum nextObject]  ) {
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
}

// Sparkle delegate:
- (void)updater:(SUUpdater *)updater willInstallUpdate:(SUAppcastItem *)update
{
    terminatingAtUserRequest = TRUE;
    [self cleanup];
    
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
        NSDirectoryEnumerator * dirEnum = [gFileMgr enumeratorAtPath: LOG_DIR];
        while (  filename = [dirEnum nextObject]  ) {
            [dirEnum skipDescendents];
            NSString * oldFullPath = [LOG_DIR stringByAppendingPathComponent: filename];
            if (  [[filename pathExtension] isEqualToString: @"log"]) {
                if (  [[[filename stringByDeletingPathExtension] pathExtension] isEqualToString: @"openvpn"]) {
                    int port = 0;
                    NSString * startArguments = nil;
                    NSString * cfgPath = [self deconstructOpenVPNLogPath: oldFullPath
                                                                  toPort: &port
                                                             toStartArgs: &startArguments];
                    NSArray * keysForConfig = [[self myConfigDictionary] allKeysForObject: cfgPath];
                    long keyCount = [keysForConfig count];
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
-(NSString *) deconstructOpenVPNLogPath: (NSString *) logPath toPort: (int *) portPtr toStartArgs: (NSString * *) startArgsPtr
{
    NSString * prefix = [NSString stringWithFormat:@"%@/", LOG_DIR];
    NSString * suffix = @".openvpn.log";
    if (  [logPath hasPrefix: prefix]  ) {
        if (  [logPath hasSuffix: suffix]  ) {
            int prefixLength = [prefix length];
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
                
                *portPtr = port;
                
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

-(void) installCheck
{
    [NSApp setAutoLaunchOnLogin: NO];
    
    NSString *updatePath = [NSHomeDirectory() stringByAppendingPathComponent:UPDATE_PATH];
    NSString *newBundlePath = [updatePath stringByAppendingPathComponent:@"SurfSafeVPN.app"];
    
	NSString * currentPath = [[NSBundle mainBundle] bundlePath];
    
    
    
    if ([currentPath isEqualToString: newBundlePath]){
        // Install this program and secure it
        if (  ! [self runInstallerRestoreDeploy: YES
                                        copyApp: YES
                                      repairApp: YES
                             moveLibraryOpenVPN: YES
                                 repairPackages: YES
                                     copyBundle: YES
                                   updateBundle: NO]  ) {
            // runInstallerRestoreDeploy has already put up an error dialog and put a message in the console log if error occurred
            [NSApp setAutoLaunchOnLogin: NO];
            [NSApp terminate:self];
        }
        
        NSString * tbInApplicationsPath = @"/Applications/SurfSafeVPN.app";
        NSString * tbInApplicationsDisplayName = [[gFileMgr componentsToDisplayForPath: tbInApplicationsPath] componentsJoinedByString: @"/"];
        NSString* text = NSLocalizedString(@"Installation finished successfully.", @"Window text");
        [splashScreen setMessage: text];
        int response = TBRunAlertPanel(@"Installation",
                                   NSLocalizedString(@"SurfSafe was successfully replaced.\n\nDo you wish to launch the new version of SurfSafe now?", @"Window text"),
                                   NSLocalizedString(@"Launch", "Button"), // Default button
                                   NSLocalizedString(@"Quit", "Button"), // Alternate button
                                   nil);
        
        [splashScreen fadeOutAndClose];
        
        if (  response == NSAlertDefaultReturn  ) {
            // Launch the program in /Applications
            if (  ! [[NSWorkspace sharedWorkspace] launchApplication: tbInApplicationsPath]  ) {
                TBRunAlertPanel(NSLocalizedString(@"Unable to launch SurfSafe", @"Window title"),
                                [NSString stringWithFormat: NSLocalizedString(@"An error occurred while trying to launch %@", @"Window text"), tbInApplicationsDisplayName],
                                NSLocalizedString(@"Cancel", @"Button"),                // Default button
                                nil,
                                nil);
            }
        }
        [NSApp terminate: nil];
    }
}

-(void) dmgCheck
{
    [NSApp setAutoLaunchOnLogin: NO];
    
	NSString * currentPath = [[NSBundle mainBundle] bundlePath];
	if (  [self cannotRunFromVolume: currentPath]  ) {
        
        NSString * appVersion   = tunnelblickVersion([NSBundle mainBundle]);
        
        NSString * preMessage = NSLocalizedString(@" SurfSafe cannot be used from this location. It must be installed on a local hard drive.\n\n", @"Window text");
        NSString * displayApplicationName = [gFileMgr displayNameAtPath: @"SurfSafeVPN.app"];
        
        NSString * tbInApplicationsPath = @"/Applications/SurfSafeVPN.app";
        NSString * applicationsPath = @"/Applications";
        NSString * tbInApplicationsDisplayName = [[gFileMgr componentsToDisplayForPath: tbInApplicationsPath] componentsJoinedByString: @"/"];
        NSString * applicationsDisplayName = [[gFileMgr componentsToDisplayForPath: applicationsPath] componentsJoinedByString: @"/"];
        
        NSString * changeLocationText = [NSString stringWithFormat: NSLocalizedString(@" (To install in a different location, drag %@ to that location.)", @"Window text"), displayApplicationName];
        NSString * launchWindowTitle = NSLocalizedString(@"Installation succeeded", @"Window title");
        NSString * launchWindowText;
        NSString * authorizationText;
        int response;
        
        // See if there are any .tblks on the .dmg that should be installed
        NSString * tblksMsg = @"";
        NSArray * tblksToInstallPaths = [self findTblksToInstallInPath: [currentPath stringByDeletingLastPathComponent]];
        if (  tblksToInstallPaths  ) {
            tblksMsg = [NSString stringWithFormat: NSLocalizedString(@"\n\nand install %ld SurfSafe VPN Configurations", @"Window text"),
                        (long) [tblksToInstallPaths count]];
        }
        
        if (  [gFileMgr fileExistsAtPath: tbInApplicationsPath]  ) {
            NSBundle * previousBundle = [NSBundle bundleWithPath: tbInApplicationsPath];
            NSString * previousVersion = tunnelblickVersion(previousBundle);
                authorizationText = [NSString stringWithFormat:
                                     NSLocalizedString(@" Do you wish to replace\n    %@\n    in %@\nwith %@%@?\n\n%@", @"Window text"),
                                     previousVersion, applicationsDisplayName, appVersion, tblksMsg, changeLocationText];
                launchWindowText = NSLocalizedString(@"SurfSafe was successfully replaced.\n\nDo you wish to launch the new version of SurfSafe now?", @"Window text");
        } else {
            authorizationText = [NSString stringWithFormat:
                                 NSLocalizedString(@" Do you wish to install %@ to %@%@?\n\n%@", @"Window text"),
                                 appVersion, applicationsDisplayName, tblksMsg, changeLocationText];
            launchWindowText = NSLocalizedString(@"SurfSafe was successfully installed.\n\nDo you wish to launch SurfSafe now?", @"Window text");
        }
        
        // Get authorization to install and secure
        gAuthorization = [NSApplication getAuthorizationRef: [preMessage stringByAppendingString: authorizationText]];
        if (  ! gAuthorization  ) {
            NSLog(@"The SurfSafe installation was cancelled by the user.");
            [NSApp terminate:self];
        }
        
        // Stop any currently running SurfSafeVPNs
        int numberOfOthers = [NSApp countOtherInstances];
        while (  numberOfOthers > 0  ) {
            int button = TBRunAlertPanel(NSLocalizedString(@"SurfSafe is currently running", @"Window title"),
                                         NSLocalizedString(@"You must stop the currently running SurfSafeVPN to launch the new copy.\n\nClick \"Close VPN Connections and Stop SurfSafe\" to close all VPN connections and quit the currently running SurfSafe before launching SurfSafe.", @"Window text"),
                                         NSLocalizedString(@"Close VPN Connections and Stop SurfSafe", @"Button"), // Default button
                                         NSLocalizedString(@"Cancel",  @"Button"),   // Alternate button
                                         nil);
            if (  button == NSAlertAlternateReturn  ) {
                [NSApp terminate: nil];
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
        
        NSString * text = NSLocalizedString(@"Installing and securing SurfSafe...", @"Window text");
        [splashScreen setMessage: text];
        
        // Install .tblks
        if (  tblksToInstallPaths  ) {
            // Install the .tblks
            launchFinished = TRUE;  // Fake out openFiles so it installs the .tblk(s) immediately
            [self application: NSApp openFiles: tblksToInstallPaths];
            launchFinished = FALSE;
        }
        
        // Install this program and secure it
        if (  ! [self runInstallerRestoreDeploy: YES
                                        copyApp: YES
                                      repairApp: YES
                             moveLibraryOpenVPN: YES
                                 repairPackages: YES
                                     copyBundle: YES
                                   updateBundle: NO]  ) {
            // runInstallerRestoreDeploy has already put up an error dialog and put a message in the console log if error occurred
            [NSApp setAutoLaunchOnLogin: NO];
            [NSApp terminate:self];
        }
        
        // Install configurations from SurfSafeVPN Configurations.bundle if any were copied
        NSString * installFolder = [CONFIGURATION_UPDATES_BUNDLE_PATH stringByAppendingPathComponent: @"Contents/Resources/Install"];
        if (  [gFileMgr fileExistsAtPath: installFolder]  ) {
            NSString * text = NSLocalizedString(@"Installing SurfSafe VPN Configurations...", @"Window text");
            [splashScreen setMessage: text];
            launchFinished = TRUE;  // Fake out openFiles so it installs the .tblk(s) immediately
            [self installConfigurationsUpdateInBundleAtPath: CONFIGURATION_UPDATES_BUNDLE_PATH];
            launchFinished = FALSE;
        }
        
        text = NSLocalizedString(@"Installation finished successfully.", @"Window text");
        [splashScreen setMessage: text];
        response = TBRunAlertPanel(launchWindowTitle,
                                   launchWindowText,
                                   NSLocalizedString(@"Launch", "Button"), // Default button
                                   NSLocalizedString(@"Quit", "Button"), // Alternate button
                                   nil);
        
        [splashScreen fadeOutAndClose];
        
        if (  response == NSAlertDefaultReturn  ) {
            // Launch the program in /Applications
            if (  ! [[NSWorkspace sharedWorkspace] launchApplication: tbInApplicationsPath]  ) {
                TBRunAlertPanel(NSLocalizedString(@"Unable to launch SurfSafe", @"Window title"),
                                [NSString stringWithFormat: NSLocalizedString(@"An error occurred while trying to launch %@", @"Window text"), tbInApplicationsDisplayName],
                                NSLocalizedString(@"Cancel", @"Button"),                // Default button
                                nil,
                                nil);
            }
        }
        
        [NSApp terminate: nil];
    }
}

-(NSArray *) findTblksToInstallInPath: (NSString *) thePath
{
    NSMutableArray * arrayToReturn = nil;
    NSString * file;
    
    NSString * folder = [thePath stringByAppendingPathComponent: @"auto-install"];
    NSDirectoryEnumerator * dirEnum = [gFileMgr enumeratorAtPath: folder];
    while (  file = [dirEnum nextObject]  ) {
        if (  [[file pathExtension] isEqualToString: @"tblk"]  ) {
            if (  arrayToReturn == nil  ) {
                arrayToReturn = [NSMutableArray arrayWithCapacity:10];
            }
            [arrayToReturn addObject: [folder stringByAppendingPathComponent: file]];
        }
    }
    
    folder = [thePath stringByAppendingPathComponent: @".auto-install"];
    dirEnum = [gFileMgr enumeratorAtPath: folder];
    while (  file = [dirEnum nextObject]  ) {
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

// Returns TRUE if can't run SurfSafeVPN from this volume (can't run setuid binaries) or if statfs on it fails, FALSE otherwise
-(BOOL) cannotRunFromVolume: (NSString *)path
{
    if ([path hasPrefix:@"/Volumes/SurfSafeVPN"]  ) {
        return TRUE;
    }
    
    const char * fileName = [gFileMgr fileSystemRepresentationWithPath: path];
    struct statfs stats_buf;
    
    if (  0 == statfs(fileName, &stats_buf)  ) {
        if (  (stats_buf.f_flags & MNT_NOSUID) == 0  ) {
            return FALSE;
        }
    } else {
        NSLog(@"statfs on %@ failed; assuming cannot run from that volume\nError was '%s'", path, strerror(errno));
    }
    return TRUE;   // Network volume or error accessing the file's data.
}

// Invoked when a folder containing configurations has changed.
-(void) watcher: (UKKQueue*) kq receivedNotification: (NSString*) nm forPath: (NSString*) fpath {
    if (  ! ignoreNoConfigs  ) {
        [self performSelectorOnMainThread: @selector(activateStatusMenu) withObject: nil waitUntilDone: YES];
    }
}

// Runs the installer to backup/restore Resources/Deploy and/or repair ownership/permissions of critical files and/or move the config folder
// restoreDeploy should be TRUE if Resources/Deploy should be restored from its backup
// copyApp       should be TRUE if need to copy SurfSafeVPN.app to /Applications
// repairApp     should be TRUE if needsRepair() returned TRUE
// moveConfigs   should be TRUE if /Library/openvpn needs to be moved to /Library/Application Support/SurfSafeVPN/Configurations
// repairPkgs    should be TRUE if .tblk packages should have their ownership/permissions repaired
// copyBundle    should be TRUE if need to move /Library/Application Support/SurfSafeVPN/Configuration Updates/SurfSafeVPN Configurations.bundle/Contents/Resources/Deploy
//                                         to SurfSafeVPN.app/Contents/Resources/Deploy
//
// Returns TRUE if ran successfully, FALSE if failed
-(BOOL) runInstallerRestoreDeploy: (BOOL) restoreDeploy
                          copyApp: (BOOL) copyApp
                        repairApp: (BOOL) repairApp
               moveLibraryOpenVPN: (BOOL) moveConfigs
                   repairPackages: (BOOL) repairPkgs
                       copyBundle: (BOOL) copyBundle
                     updateBundle: (BOOL) updateBundle
{
    if (  ! (restoreDeploy || copyApp || repairApp || moveConfigs  || repairPkgs || copyBundle)  ) {
        return YES;
    }
    
    // Use our own copies of the arguments
    BOOL needsRestoreDeploy = restoreDeploy;
    BOOL needsCopyApp       = copyApp;
    BOOL needsRepairApp     = repairApp;
    BOOL needsMoveConfigs   = moveConfigs;
    BOOL needsRepairPkgs    = repairPkgs;
    BOOL needsCopyBundle    = copyBundle;
    BOOL needsUpdateBundle  = updateBundle;
    
    if (  gAuthorization == nil  ) {
        NSMutableString * msg = [NSMutableString stringWithString: NSLocalizedString(@"SurfSafe needs to:\n", @"Window text")];
        if (  needsRepairApp      ) [msg appendString: NSLocalizedString(@"  • Change ownership and permissions of the program to secure it\n", @"Window text")];
        if (  needsMoveConfigs    ) [msg appendString: NSLocalizedString(@"  • Repair the private configurations folder\n", @"Window text")];
        if (  needsRestoreDeploy  ) [msg appendString: NSLocalizedString(@"  • Restore configuration(s) from the backup\n", @"Window text")];
        if (   needsRepairPkgs
            || needsCopyBundle    ) [msg appendString: NSLocalizedString(@"  • Secure configurations\n", @"Window text")];
        if (   needsUpdateBundle  ) [msg appendString: NSLocalizedString(@"  • Need update bundle", @"Window text")];
        NSLog(@"%@", msg);
        
        // Get an AuthorizationRef and use executeAuthorized to run the installer
        gAuthorization= [NSApplication getAuthorizationRef: msg];
        if(gAuthorization == nil) {
            NSLog(@"Installation or repair cancelled");
            return FALSE;
        }
        
        // NOTE: We do NOT free gAuthorization here. It may be used to install .tblk packages, so we free it when we
        // are finished launching, in applicationDidFinishLaunching
    }
        
    NSLog(@"Beginning installation or repair");

    NSMutableArray * arguments = [[[NSMutableArray alloc] initWithCapacity:2] autorelease];
    
    unsigned arg1 = 0;
    if (  needsCopyApp  ) {
        arg1 = INSTALLER_COPY_APP;
    }
    if (  needsRepairApp  ) {
        arg1 = arg1 | INSTALLER_SECURE_APP;
    }
    if (  needsRepairPkgs  ) {
        arg1 = arg1 | INSTALLER_SECURE_TBLKS;
    }
    if (  needsCopyBundle  ) {
        arg1 = arg1 | INSTALLER_COPY_BUNDLE;
    }
    if (  needsUpdateBundle   ){
        arg1 = arg1 | INSTALLER_UPDATE;
    }
    [arguments addObject: [NSString stringWithFormat: @"%u", arg1]];
    
    NSString *launchPath = [[NSBundle mainBundle] pathForResource:@"installer" ofType:nil];

    BOOL okNow = FALSE;
    int i;
    for (i=0; i<5; i++) {
        if (  i != 0  ) {
            usleep( i * 500000 );
            NSLog(@"Retrying execution of installer");
        }
        
        if (  [NSApplication waitForExecuteAuthorized: launchPath withArguments: arguments withAuthorizationRef: gAuthorization] ) {
            // Try for up to 6.35 seconds to verify that installer succeeded -- sleeping .05 seconds first, then .1, .2, .4, .8, 1.6,
            // and 3.2 seconds (totals 6.35 seconds) between tries as a cheap and easy throttling mechanism for a heavily loaded computer
            useconds_t sleepTime;
            for (sleepTime=50000; sleepTime < 7000000; sleepTime=sleepTime*2) {
                usleep(sleepTime);
                
                if (  (okNow = ( ! needToRunInstaller(&needsRepairApp,
                                                     &needsMoveConfigs,
                                                     &needsRestoreDeploy,
                                                     &needsRepairPkgs,
                                                     &needsCopyBundle,
                                                     &needsUpdateBundle,
                                                     needsCopyApp) ))  ) {
                    break;
                }
            }
            
            if (  okNow  ) {
                break;
            } else {
                NSLog(@"Timed out waiting for installer execution to finish");
            }
        } else {
            NSLog(@"Failed to execute %@: %@", launchPath, arguments);
        }
    }
        
    if (   (! okNow )
        && needToRunInstaller(&needsRepairApp,
                              &needsMoveConfigs,
                              &needsRestoreDeploy,
                              &needsRepairPkgs,
                              &needsCopyBundle,
                              &needsUpdateBundle,
                              needsCopyApp)  ) {
        NSLog(@"Installation or repair failed");
        TBRunAlertPanel(NSLocalizedString(@"Installation or Repair Failed", "Window title"),
                        NSLocalizedString(@"The installation, removal, recovery, or repair of one or more SurfSafe components failed. See the Console Log for details.", "Window text"),
                        nil, nil, nil);
        return FALSE;
    }
    
    NSLog(@"Installation or repair succeeded");
    return TRUE;
}

// Checks whether the installer needs to be run
// Returns with the respective arguments set YES or NO, and returns YES if any is YES. Otherwise returns NO.
BOOL needToRunInstaller(BOOL * changeOwnershipAndOrPermissions,
                        BOOL * moveLibraryOpenVPN,
                        BOOL * restoreDeploy,
                        BOOL * needsPkgRepair,
                        BOOL * needsBundleCopy,
                        BOOL * needsBundleUpdate,
                        BOOL inApplications) 
{
    *moveLibraryOpenVPN = needToMoveLibraryOpenVPN();
    *changeOwnershipAndOrPermissions = needToChangeOwnershipAndOrPermissions(inApplications);
    *restoreDeploy   = needToRestoreDeploy();
    *needsPkgRepair  = needToRepairPackages();
    *needsBundleCopy = needToCopyBundle();
    *needsBundleUpdate = NO;//needToUpdateBundle();
    
    return ( * moveLibraryOpenVPN || * changeOwnershipAndOrPermissions || * restoreDeploy || * needsPkgRepair || * needsBundleCopy || *needsBundleUpdate);
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
	NSString *openvpnstartPath          = [resourcesPath stringByAppendingPathComponent: @"openvpnstart"                        ];
	NSString *openvpnPath               = [resourcesPath stringByAppendingPathComponent: @"openvpn"                             ];
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

	if (  ! checkOwnedByRootWheel(contentsPath) ) {
        NSLog(@"%@ not owned by root:wheel", contentsPath);
        return YES;
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
	
    // check openvpn
    if (  ! checkOwnerAndPermissions(openvpnPath, 0, 0, @"755")  ) {
        return YES; // NSLog already called
    }
    
    // Check OpenVPN version folders and the binaries of openvpn and openvpn-down-root.so in them
    NSDirectoryEnumerator * dirEnum = [gFileMgr enumeratorAtPath: openvpnPath];
    NSString * file;
    BOOL isDir;
    while (  file = [dirEnum nextObject]  ) {
        [dirEnum skipDescendents];
        NSString * fullPath = [openvpnPath stringByAppendingPathComponent: file];
        if (   [gFileMgr fileExistsAtPath: fullPath isDirectory: &isDir]
            && isDir  ) {
            if (  [file hasPrefix: @"openvpn-"]  ) {
                if (  ! checkOwnerAndPermissions(fullPath, 0, 0, @"755")  ) {
                    return YES;
                }
                
                NSString * thisOpenvpnPath = [fullPath stringByAppendingPathComponent: @"openvpn"];
                if (  ! checkOwnerAndPermissions(thisOpenvpnPath, 0, 0, @"755")  ) {
                    return YES;
                }
                
                NSString * thisOpenvpnDownRootPath = [fullPath stringByAppendingPathComponent: @"openvpn-down-root.so"];
                if (  ! checkOwnerAndPermissions(thisOpenvpnDownRootPath, 0, 0, @"744")  ) {
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
	while(currentPath = [e nextObject]) {
        if (  ! checkOwnerAndPermissions(currentPath, 0, 0, @"744")  ) {
            return YES; // NSLog already called
        }
	}
    
    // check Info.plist
    if (  ! checkOwnerAndPermissions(infoPlistPath, 0, 0, @"644")  ) {
        return YES; // NSLog already called
    }
    
    // check permissions of files in Resources/Deploy (if it exists)
    if (  [gFileMgr fileExistsAtPath: deployPath isDirectory: &isDir]
        && isDir  ) {
        if (  folderContentsNeedToBeSecuredAtPath(deployPath)  ) {
            return YES;
        }
    }
    
    // check that log directory exists and has proper ownership and permissions
    if (  ! (   [gFileMgr fileExistsAtPath: LOG_DIR isDirectory: &isDir]
             && isDir )  ) {
        NSLog(@"Need to create log directory");
        return YES;
    }
    if (  ! checkOwnerAndPermissions(LOG_DIR, 0, 0, @"755")  ) {
        return YES; // NSLog already called
    }
    
    // check permissions of files in the Deploy backup, also (if any)        
    NSString * deployBackupPath = [[[[@"/Library/Application Support/SurfSafeVPN/Backup" stringByAppendingPathComponent: [[NSBundle mainBundle] bundlePath]]
                                     stringByDeletingLastPathComponent]
                                    stringByAppendingPathComponent: @"SurfSafeVPNBackup"]
                                   stringByAppendingPathComponent: @"Deploy"];
    if (  [gFileMgr fileExistsAtPath: deployBackupPath isDirectory: &isDir]
        && isDir  ) {
        if (  folderContentsNeedToBeSecuredAtPath(deployBackupPath)  ) {
            return YES;
        }
    }
    
    return NO;
}


BOOL checkAttributes(NSDictionary * atts, NSString * path)
{
    // Check that a set of file attributes shows ownership by
    //       root:admin if it is a key or certificate file; or
    //       root:wheel otherwise
    if (  [[atts fileOwnerAccountID] intValue] != 0  ) {
        return NO;
    }
    int groupOwnerID = [[atts fileGroupOwnerAccountID] intValue];
    if (  groupOwnerID != 0  ) {
        if (  groupOwnerID != KEY_AND_CRT_GROUP  ) {
            return NO;
        }
        NSArray * keyAndCrtExtensions = KEY_AND_CRT_EXTENSIONS;
        if (  ! [keyAndCrtExtensions containsObject: [path pathExtension]]  ) {
            return NO;
        }
    }
    
    return YES;
}    

BOOL checkOwnedByRootWheel(NSString * path)
{
    // Check that everything in path and it's subfolders is owned by
    //       root:admin if it is a key or certificate file; or
    //       root:wheel otherwise
	NSDirectoryEnumerator * dirEnum = [gFileMgr enumeratorAtPath: path];
	NSString * file;
	NSDictionary * atts;
	while ( file = [dirEnum nextObject]  ) {
		NSString * filePath = [path stringByAppendingPathComponent: file];
		if (  itemIsVisible(filePath)  ) {
			atts = [gFileMgr tbFileAttributesAtPath: filePath traverseLink: NO];
            if (  ! checkAttributes(atts, filePath)  ) {
                return NO;
            }
			if (  [[atts objectForKey: NSFileType] isEqualToString: NSFileTypeSymbolicLink]  ) {
				atts = [gFileMgr tbFileAttributesAtPath: filePath traverseLink: YES];
                if (  ! checkAttributes(atts, filePath)  ) {
                    return NO;
                }
			}
		}
	}
	
	return YES;
}
        
BOOL needToRestoreDeploy(void)
{
    // Restore Resources/Deploy and/or repair ownership and permissions and/or  if necessary
    NSString * gDeployPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent: @"Deploy"];
    NSString * deployBackupPath = [[[[@"/Library/Application Support/SurfSafeVPN/Backup" stringByAppendingPathComponent: [[NSBundle mainBundle] bundlePath]]
                                     stringByDeletingLastPathComponent]
                                    stringByAppendingPathComponent: @"SurfSafeVPNBackup"]
                                   stringByAppendingPathComponent: @"Deploy"];
    BOOL isDir;
    BOOL haveBackup   = [gFileMgr fileExistsAtPath: deployBackupPath isDirectory: &isDir]
    && isDir;
    BOOL haveDeploy   = [gFileMgr fileExistsAtPath: gDeployPath    isDirectory: &isDir]
    && isDir;
    return haveBackup && ( ! haveDeploy);
}    

BOOL needToRepairPackages(void)
{
    // check permissions of .tblk packages
    uid_t realUid = getuid();
    gid_t realGid = getgid();
    NSString * packagesPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/SurfSafeVPN/Configurations/"];
    NSString * file;
    NSDirectoryEnumerator *dirEnum = [gFileMgr enumeratorAtPath: packagesPath];
    while (file = [dirEnum nextObject]) {
        NSString * fullPath = [packagesPath stringByAppendingPathComponent: file];
        if (  itemIsVisible(fullPath)  ) {
            NSString * ext  = [file pathExtension];
            if (  [ext isEqualToString: @"tblk"]  ) {
                if (  [fullPath hasPrefix: gPrivatePath]  ) {
                    if (  ! checkOwnerAndPermissions(fullPath, realUid, realGid, @"755")  ) {
                        return YES;
                    }
                } else {
                    if (  ! checkOwnerAndPermissions(fullPath, 0, 0, @"755")  ) {
                        return YES;
                    }
                }
                if (  folderContentsNeedToBeSecuredAtPath(fullPath)) {
                    return YES;
                }
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
            NSLog(@"SurfSafe Installer: No CFBundleVersion in %@", appConfigurationsBundlePath);
        }
    }
    
    return NO;
}

BOOL needToUpdateBundle()
{
    /*
    NSString *updatePath = [NSHomeDirectory() stringByAppendingPathComponent:UPDATE_PATH];
    NSString *dmgPath = [updatePath stringByAppendingPathComponent:@"SurfSafeSetup.dmg"];
    if ( [gFileMgr fileExistsAtPath:dmgPath]){
        return YES;
    }
     */
    return NO;
}


void terminateBecauseOfBadConfiguration(void)
{
    TBRunAlertPanel(NSLocalizedString(@"SurfSafe Configuration Problem", @"Window title"),
                    NSLocalizedString(@"SurfSafe could not be launched because of a problem with the configuration. Please examine the Console Log for details.", @"Window text"),
                    nil, nil, nil);
    [NSApp setAutoLaunchOnLogin: NO];
    [NSApp terminate: nil];
}


-(void) willLogoutOrShutdownHandler: (NSNotification *) n
{
    areLoggingOutOrShuttingDown = TRUE;
}

-(void)willGoToSleepHandler: (NSNotification *) n
{
    gComputerIsGoingToSleep = TRUE;
	if(NSDebugEnabled) NSLog(@"Computer will go to sleep");
    
    [connectionsToRestoreOnWakeup removeAllObjects];
    VPNConnection * connection; 
	NSEnumerator * connEnum = [[self myVPNConnectionDictionary] objectEnumerator];
    while (  connection = [connEnum nextObject]  ) {
        if (  ! [[connection requestedState] isEqualToString: @"EXITING"]  ) {
            [connectionsToRestoreOnWakeup addObject: connection];
        }
    }
    
    terminatingAtUserRequest = TRUE;
	[self killAllConnectionsIncludingDaemons: YES logMessage: @"*SurfSafe: Computer is going to sleep. Closing connections..."];  // Kill any OpenVPN processes that still exist
    if (  ! [gTbDefaults boolForKey: @"doNotPutOffSleepUntilOpenVPNsTerminate"] ) {
        // Wait until all OpenVPN processes have terminated
        while (  [[NSApp pIdsForOpenVPNProcesses] count] != 0  ) {
            usleep(100000);
        }
    }
}
-(void) wokeUpFromSleepHandler: (NSNotification *) n
{
    [self performSelectorOnMainThread: @selector(wokeUpFromSleep) withObject:nil waitUntilDone:NO];
}

-(void)wokeUpFromSleep
{
    gComputerIsGoingToSleep = FALSE;
	if(NSDebugEnabled) NSLog(@"Computer just woke up from sleep");
	
	NSEnumerator *e = [connectionsToRestoreOnWakeup objectEnumerator];
	VPNConnection *connection;
	while(connection = [e nextObject]) {
		if(NSDebugEnabled) NSLog(@"Restoring Connection %@", [connection displayName]);
        [connection addToLog: @"*SurfSafe: Woke up from sleep. Attempting to re-establish connection..."];
		[connection connect:self userKnows: YES];
	}
    
    [connectionsToRestoreOnWakeup removeAllObjects];
}
-(void)didBecomeInactiveUserHandler: (NSNotification *) n
{
    [self performSelectorOnMainThread: @selector(didBecomeInactiveUser) withObject:nil waitUntilDone:NO];
}

-(void)didBecomeInactiveUser
{
    // Remember current connections so they can be restored if/when we become the active user
    connectionsToRestoreOnUserActive = [[self connectionArray] copy];
    
    // For each open connection, either reInitialize it or disconnect it
    NSEnumerator * e = [[self connectionArray] objectEnumerator];
	VPNConnection * connection;
	while (  connection = [e nextObject]  ) {
        if (  [connection shouldDisconnectWhenBecomeInactiveUser]  ) {
            [connection addToLog: @"*SurfSafe: Disconnecting; user became inactive"];
            [connection disconnectAndWait: [NSNumber numberWithBool: YES] userKnows: YES];
        } else {
            [connection addToLog: @"*SurfSafe: Stopping communication with OpenVPN because user became inactive"];
            [connection reInitialize];
        }
    }
}

-(void)didBecomeActiveUserHandler: (NSNotification *) n
{
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
	while(connection = [e nextObject]) {
        if (  ! [connection isHookedup]  ) {
            NSString * key = [[connection displayName] stringByAppendingString: @"-doNotReconnectOnFastUserSwitch"];
            if (  ! [gTbDefaults boolForKey: key]  ) {
                [connection stopTryingToHookup];
                [connection addToLog: @"*SurfSafe: Attempting to reconnect because user became active"];
                [connection connect: self userKnows: YES];
            }
        }
    }
    
    [connectionsToRestoreOnUserActive release];
    connectionsToRestoreOnUserActive = nil;
}

int runUnrecoverableErrorPanel(msg) 
{
	int result = TBRunAlertPanel(NSLocalizedString(@"SurfSafe Error", @"Window title"),
                                 [NSString stringWithFormat: NSLocalizedString(@"You must reinstall SurfSafe. Please move SurfSafe to the Trash and download a fresh copy. The problem was:\n\n%@", @"Window text"),
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
    // When the hotKey is pressed, pop up the Tunnelblick menu from the Status Bar
    MenuController * menuC = (MenuController *) userData;
    NSStatusItem * statusI = [menuC statusItem];
    [statusI popUpStatusItemMenu: [statusI menu]];
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
    while (  folder = [soundDirEnum nextObject]  ) {
        NSDirectoryEnumerator * dirEnum = [gFileMgr enumeratorAtPath: folder];
        while (  file = [dirEnum nextObject]  ) {
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
    [self performSelectorOnMainThread: @selector(updateStatisticsDisplays) withObject: nil waitUntilDone: NO];
}

-(void) updateStatisticsDisplays {
    NSEnumerator * e = [connectionArray objectEnumerator];
    VPNConnection * connection;
    while (  connection = [e nextObject]  ) {
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
                [connection showStatusWindow];
                showingAny = TRUE;
            } else {
                if (   [connection isConnected]
                    || [connection isDisconnected]  ) {
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

    [self statisticsWindowsShow: YES];
}

-(void) hideStatisticsWindows {
    
    [self statisticsWindowsShow: NO];
}

-(BOOL) mouseIsInsideAnyView {
    // Returns TRUE if the mouse is inside any status window or the main Icon
    
    return mouseIsInStatusWindow || mouseIsInMainIcon;
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
                                       "Try reinstalling SurfSafe from a disk image.", @"Window text VPNService"),
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
    VPNConnection * connection = [[self myVPNConnectionDictionary] objectForKey: theName];
    if (  connection  ) {
        if (  choice == statusWindowControllerDisconnectChoice  ) {
            [connection addToLog: @"*SurfSafe: Disconnecting; Disconnect button pressed"];
            [connection disconnectAndWait: [NSNumber numberWithBool: YES] userKnows: YES];
        } else if (  choice == statusWindowControllerConnectChoice  ) {
            [connection addToLog: @"*SurfSafe: Connecting; Connect button pressed"];
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
    return [[updater retain] autorelease];
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

TBSYNTHESIZE_OBJECT(retain, MainIconView *, ourMainIconView,           setOurMainIconView)
TBSYNTHESIZE_OBJECT(retain, NSDictionary *, myVPNConnectionDictionary, setMyVPNConnectionDictionary)
TBSYNTHESIZE_OBJECT(retain, NSDictionary *, myConfigDictionary,        setMyConfigDictionary)
TBSYNTHESIZE_OBJECT(retain, NSArray      *, connectionArray,           setConnectionArray)


// Event Handlers

-(void) showStatisticsWindowsTimerHandler: (NSTimer *) theTimer {
    // Event handler; NOT on MainThread
    
    if (  [self mouseIsInsideAnyView] ) {
        [self performSelectorOnMainThread: @selector(showStatisticsWindows) withObject: nil waitUntilDone: NO];
    }
}

-(void) hideStatisticsWindowsTimerHandler: (NSTimer *) theTimer {
    // Event handler; NOT on MainThread
    
    if (  ! [self mouseIsInsideAnyView] ) {
        [[NSApp delegate] performSelectorOnMainThread: @selector(hideStatisticsWindows) withObject: nil waitUntilDone: NO];
    }
}    

-(void) showOrHideStatisticsWindowsAfterDelay: (NSTimeInterval) delay
                                fromTimestamp: (NSTimeInterval) timestamp
                                     selector: (SEL)            selector {
    
    // Event handlers invoke this; NOT on MainThread
    
    NSTimeInterval timeUntilAct;
    if (  timestamp == 0.0  ) {
        timeUntilAct = 0.0;
    } else {
        // The next three lines were adapted from http://shiftedbits.org/2008/10/01/mach_absolute_time-on-the-iphone/
        mach_timebase_info_data_t info;
        mach_timebase_info(&info);
        uint64_t systemStartNanoseconds = (mach_absolute_time() * info.numer) / info.denom;
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
    
    mouseIsInMainIcon = TRUE;
    [self showOrHideStatisticsWindowsAfterDelay: gDelayToShowStatistics
                                  fromTimestamp: ( theEvent ? [theEvent timestamp] : 0.0)
                                       selector: @selector(showStatisticsWindowsTimerHandler:)];
}

-(void) mouseExitedMainIcon: (id) control event: (NSEvent *) theEvent {
    // Event handlers invoke this; NOT on MainThread
    
    mouseIsInMainIcon = FALSE;
    [self showOrHideStatisticsWindowsAfterDelay: gDelayToHideStatistics
                                  fromTimestamp: ( theEvent ? [theEvent timestamp] : 0.0)
                                       selector: @selector(hideStatisticsWindowsTimerHandler:)];
}

-(void) mouseEnteredStatusWindow: (id) control event: (NSEvent *) theEvent  {
    // Event handlers invoke this; NOT on MainThread
    
    mouseIsInStatusWindow = TRUE;
    [self showOrHideStatisticsWindowsAfterDelay: gDelayToShowStatistics
                                  fromTimestamp: ( theEvent ? [theEvent timestamp] : 0.0)
                                       selector: @selector(showStatisticsWindowsTimerHandler:)];
}

-(void) mouseExitedStatusWindow: (id) control event: (NSEvent *) theEvent {
    // Event handlers invoke this; NOT on MainThread
    
    mouseIsInStatusWindow = FALSE;
    [self showOrHideStatisticsWindowsAfterDelay: gDelayToHideStatistics
                                  fromTimestamp: ( theEvent ? [theEvent timestamp] : 0.0)
                                       selector: @selector(hideStatisticsWindowsTimerHandler:)];
}


//*********************************************************************************************************
//
// SurfSafeUpdaterDelegate
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


@end
