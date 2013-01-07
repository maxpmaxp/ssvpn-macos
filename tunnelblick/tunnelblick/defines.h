/*
 * Copyright 2010, 2011 Jonathan Bullard
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

//*************************************************************************************************
// Misc:

// Set to TRUE to allow Tunnelblick to use openvpnstart's kill and killall subcommands
#define ALLOW_OPENVPNSTART_KILL FALSE

// The maximum length of a display name for openvpnstart
#define DISPLAY_NAME_LENGTH_MAX 512

// The maximum 'argc' for openvpnstart
#define OPENVPNSTART_MAX_ARGC 11

// The admin group ID
#define ADMIN_GROUP_ID 80

// The newline character as a unichar
#define UNICHAR_LF [@"\n" characterAtIndex:0]

// Maximum port number
#define MAX_PORT_NUMBER 65536

// Maximum hotKey index
#define MAX_HOTKEY_IX 12

// Minimum, maximum, and default log size (bytes)
#define MIN_LOG_SIZE_BYTES 10000
#define MAX_LOG_SIZE_BYTES 100000000
#define DEFAULT_LOG_SIZE_BYTES 102400

//*************************************************************************************************
// Paths:
// Note: Several up scripts refer to the log directory without using this header file

#define CONFIGURATION_UPDATES_BUNDLE_PATH  @"/Library/Application Support/SurfsafeVPN/Configuration Updates/SurfsafeVPN Configurations.bundle"

#define L_AS_T_BACKUP @"/Library/Application Support/SurfsafeVPN/Backup"
#define L_AS_T_DEPLOY @"/Library/Application Support/SurfsafeVPN/Deploy"
#define L_AS_T_LOGS   @"/Library/Application Support/SurfsafeVPN/Logs"
#define L_AS_T_SHARED @"/Library/Application Support/SurfsafeVPN/Shared"
#define L_AS_T_USERS  @"/Library/Application Support/SurfsafeVPN/Users"


//*************************************************************************************************
// Characters in a configuration's display name that are not allowed
// Note that \000 - \037 and \177 are also prohibited, and that "(" and ")" _ARE_ allowed.
#define PROHIBITED_DISPLAY_NAME_CHARACTERS_CSTRING "#&;:~|*?~<>^[]{}$'\""
//HTK-INC
#define CONFIGURATION_PATH @"Library/Application Support/SurfsafeVPN/Configurations"
#define UPDATE_PATH @"Library/Application Support/SurfSafeVPN/Updates"
#define BACKUP_PATH @"Library/Application Support/SurfSafeVPN/Backups"
//End HTK-INC

//*************************************************************************************************
// Extensions that (for private configurations) require 640 permissions and ownership by Admin group
// (Shared, Deploy, and alternate configurations are 0:0/600)
#define KEY_AND_CRT_EXTENSIONS [NSArray arrayWithObjects: @"cer", @"cert", @"crt", @"der", @"key", @"p12", @"p7b", @"p7c", @"pem", @"pfx", nil]

//*************************************************************************************************
// Permissions for files and folders
//
// These are used in four places:
//       MenuController's function needToSecureFolderAtPath()
//       openvpnstart's   function exitIfTblkNeedsRepair()
//       sharedRoutine's  function secureOneFolder()
//       installer
//
// _PRIVATE... entries are for ~/Library/Application Support/SurfSafeVPN/Configurations
// _SECURED... entries are for /Library/Application Support/SurfSafeVPN/Shared/,
//                             /Library/Application Support/SurfSafeVPN/Users/username/,
//                             /Library/Application Support/SurfSafeVPN/Deployed/
//                             /Library/Application Support/SurfSafeVPN/Backup/
//                             /Applications/SurfSafeVPN.app/Contents/Resources/Deploy/
//
// _SELF           entries are for the folder itself (if not a .tblk folder
// _TBLK_FOLDER    entries are for folders with the .tblk extension and their subfolders (Contents & Resources)
// _PRIVATE_FOLDER entries are for folders IN .../Users/username/
// _PUBLIC_FOLDER  entries are for all other folders
// _SCRIPT         entries are for files with the .sh
// _EXECUTABLE     entries are for files with the .executable extension (in Deploy folders only)
// _OTHER          entries are for all other files

// These folders are owned by root:wheel

#define PERMS_PRIVATE_SELF           0750
#define PERMS_PRIVATE_TBLK_FOLDER    0750
#define PERMS_PRIVATE_PRIVATE_FOLDER 0750
#define PERMS_PRIVATE_PUBLIC_FOLDER  0750
#define PERMS_PRIVATE_SCRIPT         0740
#define PERMS_PRIVATE_EXECUTABLE     0740
#define PERMS_PRIVATE_OTHER          0640

#define PERMS_SECURED_SELF           0755
#define PERMS_SECURED_TBLK_FOLDER    0750
#define PERMS_SECURED_PRIVATE_FOLDER 0750
#define PERMS_SECURED_PUBLIC_FOLDER  0755
#define PERMS_SECURED_SCRIPT         0700
#define PERMS_SECURED_EXECUTABLE     0711
#define PERMS_SECURED_OTHER          0600


//*************************************************************************************************
// Values for the location of the configuration file (cfgLocCode argument to openvpnstart) 
#define CFG_LOC_PRIVATE   0
#define CFG_LOC_ALTERNATE 1
#define CFG_LOC_DEPLOY    2
#define CFG_LOC_SHARED    3
#define CFG_LOC_MAX       3


//*************************************************************************************************
// Bit masks for bitMask parameter of openvpnstart's start, loadkexts, and unloadkexts sub-commands
#define OPENVPNSTART_OUR_TUN_KEXT              0x001u
#define OPENVPNSTART_OUR_TAP_KEXT              0x002u

#define OPENVPNSTART_KEXTS_MASK_LOAD_DEFAULT   0x003u
#define OPENVPNSTART_KEXTS_MASK_LOAD_MAX       0x003u

#define OPENVPNSTART_FOO_TUN_KEXT              0x004u
#define OPENVPNSTART_FOO_TAP_KEXT              0x008u

#define OPENVPNSTART_KEXTS_MASK_UNLOAD_DEFAULT 0x003u
#define OPENVPNSTART_KEXTS_MASK_UNLOAD_MAX     0x00Fu

#define OPENVPNSTART_RESTORE_ON_DNS_RESET      0x010u
#define OPENVPNSTART_RESTORE_ON_WINS_RESET     0x020u
#define OPENVPNSTART_USE_TAP                   0x040u
#define OPENVPNSTART_PREPEND_DOMAIN_NAME       0x080u
#define OPENVPNSTART_FLUSH_DNS_CACHE           0x100u

#define OPENVPNSTART_START_BITMASK_MAX         0x1FFu


//*************************************************************************************************
// Bit masks (and a shift count) for useScripts parameter of openvpnstart's start sub-command
#define OPENVPNSTART_USE_SCRIPTS_RUN_SCRIPTS        0x01
#define OPENVPNSTART_USE_SCRIPTS_USE_DOWN_ROOT      0x02

// (Mask first, then shift right)
#define OPENVPNSTART_USE_SCRIPTS_SCRIPT_MASK        0xFC
#define OPENVPNSTART_USE_SCRIPTS_SCRIPT_SHIFT_COUNT    2

#define OPENVPNSTART_USE_SCRIPTS_MAX                0xFF


//*************************************************************************************************
// Error return codes for openvpnstart
#define OPENVPNSTART_REVERT_CONFIG_OK				 249
#define OPENVPNSTART_REVERT_CONFIG_MISSING			 250
#define OPENVPNSTART_COMPARE_CONFIG_SAME             251
#define OPENVPNSTART_COMPARE_CONFIG_DIFFERENT        252
#define OPENVPNSTART_RETURN_SYNTAX_ERROR             253
#define OPENVPNSTART_RETURN_CONFIG_NOT_SECURED_ERROR 254


//*************************************************************************************************
// Bit masks for bitMask parameter of installer

#define INSTALLER_CLEAR_LOG				0x0001u

#define INSTALLER_COPY_APP              0x0002u

#define INSTALLER_SECURE_APP            0x0004u
#define INSTALLER_COPY_BUNDLE           0x0008u
#define INSTALLER_SECURE_TBLKS          0x0010u
#define INSTALLER_CONVERT_NON_TBLKS     0x0020u
#define INSTALLER_MOVE_LIBRARY_OPENVPN  0x0040u
#define INSTALLER_UPDATE_DEPLOY         0x0080u

#define INSTALLER_MOVE_NOT_COPY         0x1000u
#define INSTALLER_DELETE                0x2000u
#define INSTALLER_SET_VERSION           0x4000u


//*************************************************************************************************
// Size to use to minimize the left navigation area when it is inactive
#define LEFT_NAV_AREA_MINIMAL_SIZE 8.0

//*************************************************************************************************
// Minimum size of the left navigation area when it is active
#define LEFT_NAV_AREA_MINIMUM_SIZE 40.0

//*************************************************************************************************
// Maximum number of tabs to allow when left up to the program
#define MAX_TABS_LIMIT 8

//*************************************************************************************************
// Return values for StatusWindowController
typedef enum
{
	statusWindowControllerDisconnectChoice,
    statusWindowControllerConnectChoice,
} StatusWindowControllerChoice;

//*************************************************************************************************
// Tiger-compatible macros that implement something like @property and @synthesize
//
// The 'type' argument is the type of the variable
// The 'name' and 'setname' arguments are the name of the variable and the name with initial capital prefixed by set
// The 'copyRetain' argument is either copy or retain
//
// Note that objects and non-objects use different TBSYNTHESIZE... macros

#define TBPROPERTY(type, name, setname) \
-(type) name;                           \
-(void) setname: (type) newValue;       \


#define TBPROPERTY_READONLY(type, name) \
-(type) name;                           \


#define TBPROPERTY_WRITEONLY(type, name, setname) \
-(void) setname: (type) newValue;                 \



#define TBSYNTHESIZE_OBJECT(copyRetain, type, name, setname) \
-(type) name                                                 \
{                                                            \
    return [[name copyRetain] autorelease];                  \
}                                                            \
                                                             \
-(void) setname: (type) newValue                             \
{                                                            \
    [newValue retain];                                       \
    [name release];                                          \
    name = newValue;                                         \
}                                                            \


#define TBSYNTHESIZE_OBJECT_GET(copyRetain, type, name) \
-(type) name                                            \
{                                                       \
    return [[name copyRetain] autorelease];             \
}                                                       \


#define TBSYNTHESIZE_OBJECT_SET(type, name, setname) \
-(void) setname: (type) newValue                     \
{                                                    \
    [newValue retain];                               \
    [name release];                                  \
    name = newValue;                                 \
}                                                    \




#define TBSYNTHESIZE_NONOBJECT(type, name, setname) \
-(type) name                                        \
{                                                   \
    return name;                                    \
}                                                   \
                                                    \
-(void) setname: (type) newValue                    \
{                                                   \
    name = newValue;                                \
}


#define TBSYNTHESIZE_NONOBJECT_GET(type, name) \
-(type) name                                   \
{                                              \
    return name;                               \
}                                              \


#define TBSYNTHESIZE_NONOBJECT_SET(type, name, setname) \
-(void) setname: (type) newValue                        \
{                                                       \
    name = newValue;                                    \
}                                                       \


//*************************************************************************************************
// Comment out (with "//") the following line to EXclude the VPNService feature
//#define INCLUDE_VPNSERVICE 1
