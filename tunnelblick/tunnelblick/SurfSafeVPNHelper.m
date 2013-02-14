//
//  SurfSafeVPNHelper.m
//  Tunnelblick
//
//  Created by Valik Plunk on 04/02/2013.
//
//

#import "SurfSafeVPNHelper.h"

#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/sysctl.h>
#include <Carbon/Carbon.h>
#include "defines.h"
#import "SurfSafeToolReport.h"
#import "CPSystemInformation.h"

typedef struct kinfo_proc kinfo_proc;

const int max_processes = 1024;

static int GetBSDProcessList(kinfo_proc **procList, size_t *procCount);
NSString* getLogFromFile(NSString *strLogPath);

NSString* getCompleteLog() {
    
    NSString* headerLog = @"SurfSafeVPN Client for MAC OS X Log:\n--------------\n\n";
    
    NSDictionary* infoDict = [[NSBundle mainBundle] infoDictionary];
    
    headerLog = [headerLog stringByAppendingFormat:@"Product name: %@\nProduct version: %@\n%@\n",
                                                    [infoDict objectForKey:@"CFBundleName"],
                                                    [infoDict objectForKey:@"CFBundleVersion"],
                                                    [SurfSafeToolReport osVer]];
    
    NSString* kextStat = @"kextstat:\n--------------\n\n";
    
    kextStat = [kextStat stringByAppendingString: [CPSystemInformation getKextstat]];
    
    NSString* ifconfig = @"ifconfig:\n--------------\n\n";
    
    ifconfig = [ifconfig stringByAppendingString: [CPSystemInformation getIfconfig]];
    
    
    
    NSString* systemString = @"System Information:\n--------------\n\n";
    systemString = [systemString stringByAppendingString: [CPSystemInformation stringMiniSystemReport]];
    NSLog(@"%@\n",systemString);
    

    
    kinfo_proc* results  = NULL;//malloc(sizeof(kinfo_proc*)*max_processes);
    size_t procCount=0;
    
    GetBSDProcessList(&results, &procCount);
    kinfo_proc* current_process = results;
    
    NSString *processList = @"Process list\n--------------\n\nprocess id\tname\t\tuser_id\n";
    
    for (int i=0; i<procCount && i<max_processes; i++)
    {
        //kinfo_proc* process_info = results[i];
        if(current_process->kp_proc.p_pid)
            processList = [processList stringByAppendingFormat:@"%-5.5d", current_process->kp_proc.p_pid];
            printf("process id:%d", current_process->kp_proc.p_pid);
        if (current_process->kp_proc.p_comm) {
            processList = [processList stringByAppendingFormat:@"\t\t%-18.18s", current_process->kp_proc.p_comm];
            printf("\tname:%s", current_process->kp_proc.p_comm);
        }
        processList = [processList stringByAppendingFormat:@"\t\t\t%d\n",current_process->kp_eproc.e_pcred.p_ruid];
        printf("\tuser_id:%d",current_process->kp_eproc.e_pcred.p_ruid);
        printf("\n");
        current_process += 1;
    }
    free(results);
    
    
    NSString* strInstallerLogPath =  @"/tmp/surfsafevpn-installer-log.txt";
    NSString *installerLog = @"Installer Log:\n--------------\n\n";
    installerLog = [installerLog stringByAppendingString: getLogFromFile(strInstallerLogPath)];
    
    
    NSString* logsPath = [NSHomeDirectory() stringByAppendingPathComponent:GLOBAL_LOG_PATH];
    NSString *globalLogPath = [logsPath stringByAppendingPathComponent:@"last_connection.log"];
    NSString *applicationLog = @"Application and OpenVPN Log:\n--------------\n\n";
    applicationLog = [applicationLog stringByAppendingString: getLogFromFile(globalLogPath)];
    
    results = NULL;
    return [NSString stringWithFormat:@"%@\n%@\n%@\n%@\n%@\n%@\n%@",headerLog, systemString, ifconfig, kextStat, processList, installerLog, applicationLog];
}

NSString* getLogFromFile(NSString *strLogPath){
    if(!strLogPath){
        return @"can't open log file without a correct name";
    }
    NSFileManager* filemngr = [[NSFileManager alloc]init];
    
    BOOL isInstallerLogExist = [filemngr fileExistsAtPath:strLogPath];
    
    if(!isInstallerLogExist){
        [filemngr release];
        return [NSString stringWithFormat:@"Can't find log at path: %@", strLogPath];
    }
    
    NSURL *URL = [NSURL fileURLWithPath:strLogPath
                            isDirectory:NO];

    NSData *data = [NSData dataWithContentsOfURL:URL];
    
    // Assuming data is in UTF8.
    NSString *string = [NSString stringWithUTF8String:[data bytes]];
    [filemngr release];
    return string;
}



static int GetBSDProcessList(kinfo_proc **procList, size_t *procCount)

// Returns a list of all BSD processes on the system.  This routine
// allocates the list and puts it in *procList and a count of the
// number of entries in *procCount.  You are responsible for freeing
// this list (use "free" from System framework).
// On success, the function returns 0.
// On error, the function returns a BSD errno value.

{
    
    int                 err;
    kinfo_proc *        result;
    bool                done;
    static const int    name[] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
    
    // Declaring name as const requires us to cast it when passing it to
    // sysctl because the prototype doesn't include the const modifier.
    
    size_t              length;
    
    
    assert( procList != NULL);
    assert(*procList == NULL);
    assert(procCount != NULL);
    
    
    *procCount = 0;
    
    
    // We start by calling sysctl with result == NULL and length == 0.
    // That will succeed, and set length to the appropriate length.
    // We then allocate a buffer of that size and call sysctl again
    // with that buffer.  If that succeeds, we're done.  If that fails
    
    // with ENOMEM, we have to throw away our buffer and loop.  Note
    
    // that the loop causes use to call sysctl with NULL again; this
    // is necessary because the ENOMEM failure case sets length to
    // the amount of data returned, not the amount of data that
    // could have been returned.
    
    result = NULL;
    done = false;
    
    do {
        assert(result == NULL);

        // Call sysctl with a NULL buffer.
        
        length = 0;
        
        err = sysctl( (int *) name, (sizeof(name) / sizeof(*name)) - 1,
                     NULL, &length,
                     NULL, 0);
        
        if (err == -1) {
            err = errno;
        }
        
        
        // Allocate an appropriately sized buffer based on the results
        // from the previous call.
        
        
        if (err == 0) {
            result = malloc(length);
            if (result == NULL) {
                err = ENOMEM;
            }
        }
        
        
        // Call sysctl again with the new buffer.  If we get an ENOMEM
        // error, toss away our buffer and start again.
        
        
        if (err == 0) {
            err = sysctl( (int *) name, (sizeof(name) / sizeof(*name)) - 1,
                         result, &length,
                         NULL, 0);
            
            if (err == -1) {
                err = errno;
            }
            
            if (err == 0) {
                done = true;
            } else if (err == ENOMEM) {
                assert(result != NULL);
                free(result);
                result = NULL;
                err = 0;
            }
        }
    } while (err == 0 && ! done);
    
    
    // Clean up and establish post conditions.
    
    
    if (err != 0 && result != NULL) {
        free(result);
        result = NULL;
    }
    
    *procList = result;
    
    if (err == 0) {
        *procCount = length / sizeof(kinfo_proc);
    }
    
    
    assert( (err == 0) == (*procList != NULL) );
    
    
    return err;
    
}
///////////////////////////
//Carbon interface:
//GetNextProcess:
/*Boolean GetPIDForProcessWithPath(const char* inPOSIXPath, pid_t* outPID)
{
    Boolean theResult = false;
    ProcessSerialNumber thePSN = {0, kNoProcess};
    FSRef thePathRef = {};
    FSPathMakeRef(inPOSIXPath, &thePathRef, NULL);
    while(!theResult && (GetNextProcess(&thePSN) == noErr))
    {
        FSRef theRef = {};
        GetProcessBundleLocation(&thePSN, &theRef);
        if(FSCompareRefs(theRef, thePathRef) == noErr)
        {
            GetProcessPID(&thePSN, outPID);
            theResult = true;
        }
    }
    return theResult;
}*/
