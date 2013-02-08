//
//  CPSystemInformation.m
//  Tunnelblick
//
//  Created by Valik Plunk on 04/02/2013.
//
//

#import "CPSystemInformation.h"

#import <Carbon/Carbon.h>
#import <SystemConfiguration/SystemConfiguration.h>


@implementation CPSystemInformation

//get everything!
+ (NSDictionary *)miniSystemProfile
{
    
	return [NSDictionary dictionaryWithObjectsAndKeys:
            [self machineType],@"MachineType",
            [self humanMachineType],@"HumanMachineType",
            [self CPUTypeString],@"ProcessorType",
            [NSNumber numberWithLong: [self processorClockSpeed]], @"ProcessorClockSpeed",
            [NSNumber numberWithLong: [self processorClockSpeedInMHz]], @"ProcessorClockSpeedInMHz",
            [NSNumber numberWithInt:[self countLogicalProcessors]], @"Count Logical Cores",
            [NSNumber numberWithInt:[self countPhysicalProcessors]], @"Count Physical Cores",
            [self computerName],@"ComputerName",
            [self CopySerialNumber],@"ComputerSerialNumber",
            [self operatingSystemString],@"OperatingSystem",
            [self systemVersionString],@"SystemVersion",
            nil];
}


#pragma mark  Getting the Human Name for the Machine Type

// adapted from http://nilzero.com/cgi-bin/mt-comments.cgi?entry_id=1300 /
//see below 'humanMachineNameFromNilZeroCom()' for the original code /
//this code used a dictionary insted - see 'translationDictionary()' below /

//non-human readable machine type/model
+ (NSString *)machineType
{
	OSErr err;
	char *machineName=NULL;    // This is really a Pascal-string with a length byte.
    //gestaltUserVisibleMachineName = 'mnam'
	err = Gestalt(gestaltUserVisibleMachineName, (long) &machineName);
	if( err== noErr )
        return [NSString stringWithCString:(machineName + 1) encoding:NSASCIIStringEncoding];
		//return [NSString stringWithCString: (machineName +1) length: machineName[0]];
	else
		return @"machineType: machine name cannot be determined";
}

//dictionary used to make the machine type human-readable
static NSDictionary *translationDictionary=nil;
+ (NSDictionary *)translationDictionary
{
	if (translationDictionary==nil)
		translationDictionary=[[NSDictionary alloc] initWithObjectsAndKeys:
                               @"PowerMac 8500/8600",@"AAPL,8500",
                               @"PowerMac 9500/9600",@"AAPL,9500",
                               @"PowerMac 7200",@"AAPL,7200",
                               @"PowerMac 7200/7300",@"AAPL,7300",
                               @"PowerMac 7500",@"AAPL,7500",
                               @"Apple Network Server",@"AAPL,ShinerESB",
                               @"Alchemy(Performa 6400 logic-board design)",@"AAPL,e407",
                               @"Gazelle(5500)",@"AAPL,e411",
                               @"PowerBook 3400",@"AAPL,3400/2400",
                               @"PowerBook 3500",@"AAPL,3500",
                               @"PowerMac G3 (Gossamer)",@"AAPL,Gossamer",
                               @"PowerMac G3 (Silk)",@"AAPL,PowerMac G3",
                               @"PowerBook G3 (Wallstreet)",@"AAPL,PowerBook1998",
                               
                               
                               @"Yikes! Old machine - unknown model",@"AAPL",
                               
                               @"iMac (first generation)",@"iMac,1",
                               @"iMac (first generation) - unknown model",@"iMac",
                               
                               @"PowerBook G3 (Lombard)",                       @"PowerBook1,1",
                               @"iBook (clamshell)",                            @"PowerBook2,1",
                               @"iBook FireWire (clamshell)",                   @"PowerBook2,2",
                               @"PowerBook G3 (Pismo)",                         @"PowerBook3,1",
                               @"PowerBook G4 (Titanium)",                      @"PowerBook3,2",
                               @"PowerBook G4 (Titanium w/ Gigabit Ethernet)",  @"PowerBook3,3",
                               @"PowerBook G4 (Titanium w/ DVI)",               @"PowerBook3,4",
                               @"PowerBook G4 (Titanium 1GHZ)",                 @"PowerBook3,5",
                               @"iBook (12in May 2001)",                        @"PowerBook4,1",
                               @"iBook (May 2002)",                             @"PowerBook4,2",
                               @"iBook 2 rev. 2 (w/ or w/o 14in LCD) (Nov 2002)",   @"PowerBook4,3",
                               @"iBook 2 (w/ or w/o 14in LDC)",                 @"PowerBook4,4",
                               @"PowerBook G4 (Aluminum 17in)",                 @"PowerBook5,1",
                               @"PowerBook G4 (Aluminum 15in)",                 @"PowerBook5,2",
                               @"PowerBook G4 (Aluminum 17in rev. 2)",          @"PowerBook5,3",
                               @"PowerBook G4 1.33/1.5 15in (Al)",              @"PowerBook5,4",
                               @"PowerBook G4 1.5 17in (Al)",                   @"PowerBook5,5",
                               @"PowerBook G4 1.5/1.67 15in (SMS/BT2 - Al)",    @"PowerBook5,6",
                               @"PowerBook G4 1.67 17in (Al)",                  @"PowerBook5,7",
                               @"PowerBook G4 1.67 15in (DLSD/HR - Al)",        @"PowerBook5,8",
                               @"PowerBook G4 1.67 17in (DLSD/HR - Al)",        @"PowerBook5,9",
                               @"PowerBook G4 (Aluminum 12in)",                 @"PowerBook6,1",
                               @"PowerBook G4 (Aluminum 12in)",                 @"PowerBook6,2",
                               @"iBook G4 (original - Op",                      @"PowerBook6,3",
                               @"PowerBook G4 1.33 12in (Al)",                  @"PowerBook6,4",
                               @"iBook G4 (early/late 2004 - Op)",              @"PowerBook6,5",
                               @"iBook G4/1.33 12/14-Inch (Mid-2005 - Op)",     @"PowerBook6,7",
                               @"PowerBook G4 1.5 12in (Al)",                   @"PowerBook6,8",
                               
                               @"PowerBook or iBook - unknown model",@"PowerBook",
                               
                               @"Blue & White G3",                              @"PowerMac1,1",
                               @"PowerMac G4 PCI Graphics",                     @"PowerMac1,2",
                               @"iMac FireWire (CRT)",                          @"PowerMac2,1",
                               @"iMac FireWire (CRT)",                          @"PowerMac2,2",
                               @"PowerMac G4 AGP Graphics",                     @"PowerMac3,1",
                               @"PowerMac G4 AGP Graphics",                     @"PowerMac3,2",
                               @"PowerMac G4 AGP Graphics",                     @"PowerMac3,3",
                               @"PowerMac G4 (QuickSilver)",                    @"PowerMac3,4",
                               @"PowerMac G4 (QuickSilver)",                    @"PowerMac3,5",
                               @"PowerMac G4 (MDD/Windtunnel)",                 @"PowerMac3,6",
                               @"iMac (Flower Power)",                          @"PowerMac4,1",
                               @"iMac (Flat Panel 15in)",                       @"PowerMac4,2",
                               @"eMac",                                         @"PowerMac4,4",
                               @"iMac (Flat Panel 17in)",                       @"PowerMac4,5",
                               @"PowerMac G4 Cube",                             @"PowerMac5,1",
                               @"PowerMac G4 Cube",                             @"PowerMac5,2",
                               @"iMac (Flat Panel 17in)",                       @"PowerMac6,1",
                               @"eMac G4/1.25/1.42 (USB 2.0) (2005)",           @"PowerMac6,4",
                               @"PowerMac G5",                                  @"PowerMac7,2",
                               @"PowerMac G5",                                  @"PowerMac7,3",
                               @"iMac G5/1.6/1.8 17/20-Inch",                   @"PowerMac8,1",
                               @"iMac G5/1.8/2.0 17/20-Inch (ALS)",             @"PowerMac8,2",
                               @"Power Macintosh G5 1.8 (PCI)",                 @"PowerMac9,1",
                               @"Mac mini G4/1.25/1.42",                        @"PowerMac10,1",
                               @"Mac mini G4/1.33/1.5",                         @"PowerMac10,2",
                               @"Power Macintosh G5 Dual/Quad Core (2.0/2.3/2.5)",  @"PowerMac11,2",

                               @"iMac G5/1.9/2.1 17/20-Inch (iSight)",          @"PowerMac12,1",
                               
                               @"PowerMac - unknown model",@"PowerMac",                               
                               
                               @"iMac 'Core Duo' 1.83/2.0 17/20-Inch",                                    @"iMac4,1",
                               @"iMac 'Core Duo' 1.83 17-Inch (IG)",                                      @"iMac4,2",
                               @"iMac 'Core 2 Duo' 2.0/2.16/2.33 17/20-Inch",                             @"iMac5,1",
                               @"iMac 'Core 2 Duo' 1.83 17-Inch (IG)",                                    @"iMac5,2",
                               @"iMac 'Core 2 Duo' 2.16/2.33 24-Inch",                                    @"iMac6,1",
                               @"iMac 'Core 2 Duo' 2.0/2.4/2.8 20/24-Inch (Al)",                          @"iMac7,1",
                               @"iMac 'Core 2 Duo' 2.4/2.66/2.8/3.06 20/24-Inch (Early 2008)",            @"iMac8,1",
                               @"iMac 'Core 2 Duo' 2.66/2.93/3.06/2.0/2.26 20/24-Inch (Early/Mid 2009)",  @"iMac9,1",
                               @"iMac 'Core 2 Duo' 3.06/3.33 21.5/27-Inch (Late 2009)",                   @"iMac10,1",
                               @"iMac 'Core i5/i7' 2.66/2.8 27-Inch (Late 2009)",                         @"iMac11,1",
                               @"iMac 'Core i3/i5' 3.06/3.2/3.6 21.5-Inch (Mid-2010)",                    @"iMac11,2",
                               @"iMac 'Core i3/i5/i7' 3.2/2.8/3.6/2.95 27-Inch (Mid-2010)",               @"iMac11,3",
                               @"iMac 'Core i5/i7/i3' 2.5/2.7/2.8/3.1 21.5-Inch (Mid/Late-2011)",         @"iMac12,1",
                               @"iMac 'Core i5/i7' 2.7/3.1/3.4 27-Inch (Mid-2011)",                       @"iMac12,2",
                               @"iMac 'Core i5/i7' 2.7/2.9/3.1 21.5-Inch (Late 2012)",                    @"iMac13,1",
                               @"iMac 'Core i5/i5/i7' 2.9/3.2/3.4 27-Inch (Late 2012)",                   @"iMac13,2",
                               
                               @"Mac Pro 'Quad Core' 2.0/2.66/3.0 (Original)",                            @"MacPro1,1",
                               @"Mac Pro 'Eight Core' 3.0 (2,1)",                                         @"MacPro2,1",
                               @"Mac Pro 'Quad/Eight Core' 2.8/3.0/3.2 (2008)",                           @"MacPro3,1",
                               @"Mac Pro 'Quad/Eight Core' 2.66/2.93/3.33/2.26/2.66/2.93 (2009/Nehalem)", @"MacPro4,1",
                               @"Mac Pro 'Quad/Sex/Eight/Twelve Core' 2.8 (2010/Nehalem/Westmerte)",      @"MacPro5,1",
                               
                               @"MacBook 'Core Duo' 1.83/2.0 13in",                                       @"MacBook1,1",
                               @"MacBook 'Core 2 Duo' 1.83/2.0/2.16 13in (06-08)",                        @"MacBook2,1",
                               @"MacBook 'Core 2 Duo' 2.0/2.2 13in (White/Black-SR)",                     @"MacBook3,1",
                               @"MacBook 'Core 2 Duo' 2.1/2.4 13in (White/Black-08)",                     @"MacBook4,1",
                               @"MacBook 'Core 2 Duo' 2.0/2.4 13in (Unibody)",                            @"MacBook5,1",
                               @"MacBook 'Core 2 Duo' 2.0/2.13 13in (White-09)",                          @"MacBook5,2",
                               @"MacBook 'Core 2 Duo' 2.26 13in (Uni/Late 09)",                           @"MacBook6,1",
                               @"MacBook 'Core 2 Duo' 2.4 13in (Mid-2010)",                               @"MacBook7,1",
                               
                               @"MacBook Air 'Core 2 Duo' 1.6/1.8 13in (Original)",                       @"MacBookAir1,1",
                               @"MacBook Air 'Core 2 Duo' 1.6/1.86/2.13 13in (NVIDIA) or (Mid-09)",       @"MacBookAir2,1",
                               @"MacBook Air 'Core 2 Duo' 1.4/1.6 11in (Late 2010)",                      @"MacBookAir3,1",
                               @"MacBook Air 'Core 2 Duo' 1.86/2.13 13in (Late 2010)",                    @"MacBookAir3,2",
                               @"MacBook Air 'Core i5/i7' 1.6/1.8 11in (Mid-2011)",                       @"MacBookAir4,1",
                               @"MacBook Air 'Core i5/i7' 1.7/1.8 13in (Mid-2011)",                       @"MacBookAir4,2",
                               @"MacBook Air 'Core i5/i7' 1.7/2.0 11in (Mid-2012)",                       @"MacBookAir5,1",
                               @"MacBook Air 'Core i5/i7' 1.8/2.0 13in (Mid-2012)",                       @"MacBookAir5,2",
                               @"MacBook Air - unknown model",             @"MacBookAir",
                               
                               
                               @"MacBook Pro 'Core Duo' 1.67/1.83/2.0/2.16 15in",                         @"MacBookPro1,1",
                               @"MacBook Pro 'Core Duo' 2.16 17in",                                       @"MacBookPro1,2",
                               @"MacBook Pro 'Core 2 Duo' 2.33 17in",                                     @"MacBookPro2,1",
                               @"MacBook Pro 'Core 2 Duo' 2.16/2.33 15in",                                @"MacBookPro2,2",
                               @"MacBook Pro 'Core 2 Duo' 2.2/2.4/2.6 15/17in (SR)",                      @"MacBookPro3,1",
                               @"MacBook Pro 'Core 2 Duo' 2.4/2.5/2.6 15/17in (08)",                      @"MacBookPro4,1",
                               @"MacBook Pro 'Core 2 Duo' 2.4/2.53/2.8/2.66/2.93 15in (Unibody)",         @"MacBookPro5,1",
                               @"MacBook Pro 'Core 2 Duo' 2.66/2.93/2.8/3.06 (Early/Mid 2009) 17in (Unibody)", @"MacBookPro5,2",
                               @"MacBook Pro 'Core 2 Duo' 2.66/2.8/3.06 15in (SD)",                       @"MacBookPro5,3",
                               @"MacBook Pro 'Core 2 Duo' 2.53 15in (SD)",                                @"MacBookPro5,4",
                               @"MacBook Pro 'Core 2 Duo' 2.26/2.53 13in (SD/FW)",                        @"MacBookPro5,5",
                               @"MacBook Pro 'Core i5/i7' 2.53/2.66/2.8 17in Mid-2010",                   @"MacBookPro6,1",
                               @"MacBook Pro 'Core i5/i7' 2.4/2.53/2.66/2.8 15in Mid-2010",               @"MacBookPro6,2",
                               @"MacBook Pro 'Core 2 Duo' 2.4/2.66 13in Mid-2010",                        @"MacBookPro7,1",
                               @"MacBook Pro 'Core i5/i7' 2.3/2.7/2.4/2.7 13in (Early/Late) 2011",        @"MacBookPro8,1",
                               @"MacBook Pro 'Core i7' 2.0/2.2/2.3 15in (Early/Late) 2011",               @"MacBookPro8,2",                               
                               @"MacBook Pro 'Core i7' 2.2/2.3/2.4/2.5 17in (Early/Late) 2011",           @"MacBookPro8,3",
                               @"MacBook Pro 'Core i7' 2.3/2.6/2.7 15in Mid-2012",                        @"MacBookPro9,1",
                               @"MacBook Pro 'Core i5/i7' 2.5/2.9 13in Mid-2012",                         @"MacBookPro9,2",
                               @"MacBook Pro 'Core i7' 2.3/2.6/2.7 15in Retina",                          @"MacBookPro10,1",
                               @"MacBook Pro 'Core i5/i7' 2.5/2.9 13in Retina",                           @"MacBookPro10,2",
                               @"MacBook Pro - unknown model",             @"MacBookPro",
                               

                               @"XServe G4/1.0",                    @"RackMac1,1",
                               @"XServe G4/1.33 rev. 2",            @"RackMac1,2",
                               @"XServe G5",                        @"RackMac3,1",
                               
                               @"XServe PPC - unknown model",@"RackMac",
                               
                               @"Xserve Xeon 2.0/2.66/3.0 'Quad Core' (Late 2006)",       @"Xserve1,1",
                               @"Xserve Xeon 2.8/3.0 'Quad/Eight Core' (Early 2008)",     @"Xserve2,1",
                               @"Xserve Xeon Nehalem 2.26/2.66/2.93 'Quad/Eight Core'",   @"Xserve3,1",
                               
                               @"XServe - unknown model",@"Xserve",
                               
                               
                               @"Mac mini 'Core Solo/Duo' 1.5/1.66/1.83",                                 @"Macmini1,1",
                               @"Mac mini 'Core 2 Duo' 1.83/2.0",                                         @"Macmini2,1",
                               @"Mac mini 'Core 2 Duo' 2.0/2.26/2.53/2.66 (Early/Late 2009)",             @"Macmini3,1",
                               @"Mac mini 'Core 2 Duo' 2.4/2.66 (Mid-2010)",                              @"Macmini4,1",
                               @"Mac mini 'Core i5' 2.3 (Mid-2011)",                                      @"Macmini5,1",
                               @"Mac mini 'Core i5/i7' 2.5/2.7 (Mid-2011)",                               @"Macmini5,2",
                               @"Mac mini 'Core i7' 2.0 (Mid-2011/Server)",                               @"Macmini5,3",
                               @"Mac mini 'Core i5' 2.5 (Late 2012)",                                     @"Macmini6,1",
                               @"Mac mini 'Core i7' 2.3/2.6 (Late 2012/Server)",                          @"Macmini6,2",

                               @"Mac Mini - unknown model",@"Macmini",
                               
                               nil];
	return translationDictionary;
}

+ (NSString *)humanMachineType
{
	NSString* human=nil;
	NSString* machineType = nil;
    
	machineType=[self machineType];
	
	//return the corresponding entry in the NSDictionary
	NSDictionary* translation=[self translationDictionary];
	NSString* aKey;
	//keys should be sorted to distinguish 'generic' from 'specific' names
	NSEnumerator* e=[[[translation allKeys]
                     sortedArrayUsingSelector:@selector(compare:)]
                    objectEnumerator];
	NSRange r;
	while (aKey=[e nextObject]) {
		r=[machineType rangeOfString:aKey];
		if (r.location!=NSNotFound)
			//continue searching : the first hit will be the generic name
			human=[translation objectForKey:aKey];
	}
	if (human)
		return human;
	else
		return machineType;
}

//for some reason, this does not work
//probably old stuff still around
+ (NSString *)humanMachineTypeAlternate
{
	OSErr *err = nil;
	long result;
	Str255 name;
	err=Gestalt('mach',&result); //gestaltMachineType = 'mach'
	if (err==nil) {
		GetIndString(name,kMachineNameStrID,(short)result);
		return [NSString stringWithCString:name];
	} else
		return @"humanMachineTypeAlternate: machine name cannot be determined";
}


#pragma mark  Getting Processor info

+ (long)processorClockSpeed
{
	OSErr *err = nil;
	long result;
	err=Gestalt(gestaltProcClkSpeed,&result);
	if (err!=nil)
		return 0;
	else
		return result;
}

+ (long)processorClockSpeedInMHz
{
	return [self processorClockSpeed]/1000000;
}

#include <mach/mach_host.h>
#include <mach/host_info.h>
+ (unsigned int)countPhysicalProcessors
{
	host_basic_info_data_t hostInfo;
	mach_msg_type_number_t infoCount;
	
	infoCount = HOST_BASIC_INFO_COUNT;
	host_info(mach_host_self(), HOST_BASIC_INFO,
			  (host_info_t)&hostInfo, &infoCount);

	return (unsigned int)(hostInfo.physical_cpu_max);
	
}

+ (unsigned int)countLogicalProcessors
{
	host_basic_info_data_t hostInfo;
	mach_msg_type_number_t infoCount;
	
	infoCount = HOST_BASIC_INFO_COUNT;
	host_info(mach_host_self(), HOST_BASIC_INFO,
			  (host_info_t)&hostInfo, &infoCount);
	return (unsigned int)(hostInfo.logical_cpu_max);
	
}

#include <mach/mach.h>
#include <mach/machine.h>


// the following methods were more or less copied from
//	http://developer.apple.com/technotes/tn/tn2086.html
//	http://www.cocoadev.com/index.pl?GettingTheProcessor
//	and can be better understood with a look at
//	file:///usr/include/mach/machine.h

+ (BOOL) isPowerPC
{
	host_basic_info_data_t hostInfo;
	mach_msg_type_number_t infoCount;
	
	infoCount = HOST_BASIC_INFO_COUNT;
	kern_return_t ret = host_info(mach_host_self(), HOST_BASIC_INFO,
                                  (host_info_t)&hostInfo, &infoCount);
	
	return ( (KERN_SUCCESS == ret) &&
			(hostInfo.cpu_type == CPU_TYPE_POWERPC) );
}

+ (BOOL) isG3
{
	host_basic_info_data_t hostInfo;
	mach_msg_type_number_t infoCount;
	
	infoCount = HOST_BASIC_INFO_COUNT;
	kern_return_t ret = host_info(mach_host_self(), HOST_BASIC_INFO,
                                  (host_info_t)&hostInfo, &infoCount);
	
	return ( (KERN_SUCCESS == ret) &&
            (hostInfo.cpu_type == CPU_TYPE_POWERPC) &&
            (hostInfo.cpu_subtype == CPU_SUBTYPE_POWERPC_750) );
}

+ (BOOL) isG4
{
	host_basic_info_data_t hostInfo;
	mach_msg_type_number_t infoCount;
	
	infoCount = HOST_BASIC_INFO_COUNT;
	kern_return_t ret = host_info(mach_host_self(), HOST_BASIC_INFO,
                                  (host_info_t)&hostInfo, &infoCount);
	
	return ( (KERN_SUCCESS == ret) &&
            (hostInfo.cpu_type == CPU_TYPE_POWERPC) &&
            (hostInfo.cpu_subtype == CPU_SUBTYPE_POWERPC_7400 ||
             hostInfo.cpu_subtype == CPU_SUBTYPE_POWERPC_7450));
}

#ifndef CPU_SUBTYPE_POWERPC_970
#define CPU_SUBTYPE_POWERPC_970 ((cpu_subtype_t) 100)
#endif
+ (BOOL) isG5
{
	host_basic_info_data_t hostInfo;
	mach_msg_type_number_t infoCount;
	
	infoCount = HOST_BASIC_INFO_COUNT;
	kern_return_t ret = host_info(mach_host_self(), HOST_BASIC_INFO,
                                  (host_info_t)&hostInfo, &infoCount);
	
	return ( (KERN_SUCCESS == ret) &&
            (hostInfo.cpu_type == CPU_TYPE_POWERPC) &&
            (hostInfo.cpu_subtype == CPU_SUBTYPE_POWERPC_970));
}



+ (NSString *)modernProcessorType
{
    host_basic_info_data_t hostInfo;
	mach_msg_type_number_t infoCount;
	
	infoCount = HOST_BASIC_INFO_COUNT;
	kern_return_t ret = host_info(mach_host_self(), HOST_BASIC_INFO,
                                  (host_info_t)&hostInfo, &infoCount);
    if (KERN_SUCCESS != ret){
        return @"Failed to get Processor Type";
    }
    if ((hostInfo.cpu_type == CPU_TYPE_I386) || (hostInfo.cpu_type == CPU_TYPE_X86))
    {
        return [NSString stringWithFormat:@"x86 family processor subtype: %d", hostInfo.cpu_subtype];
    }
    else{
        return @"NON PowerPC or x86 processor";
    }

}

+ (NSString *)CPUTypeString
{
	if ([self isG3])
		return @"G3";
	else if ([self isG4])
		return @"G4";
	else if ([self isG5])
		return @"G5";
	else if ([self isPowerPC])
		return @"PowerPC pre-G3";
	else
        return [self modernProcessorType];
    
}

#pragma mark  Machine information

//this used to be called 'Rendezvous name' (X.2), now just 'Computer name' (X.3)
//see here for why: http://developer.apple.com/qa/qa2001/qa1228.html
//this is the name set in the Sharing pref pane
+ (NSString *)computerName
{
	CFStringRef name;
	NSString* computerName;
	name = SCDynamicStoreCopyComputerName(NULL,NULL);
	computerName=[NSString stringWithString:(NSString *)name];
	CFRelease(name);
	return computerName;
}

// copied from http://cocoa.mamasam.com/COCOADEV/2003/07/1/68334.php /
// and modified by http://nilzero.com/cgi-bin/mt-comments.cgi?entry_id=1300 /
// and by http://cocoa.mamasam.com/COCOADEV/2003/07/1/68337.php/ /
+ (NSString *)computerSerialNumber
{
	NSString*         result = @"";
	mach_port_t       masterPort;
	kern_return_t      kr = noErr;
	io_registry_entry_t  entry;    
	CFDataRef         propData;
	CFTypeRef         prop;
	CFTypeID         propID=NULL;
	UInt8*           data;
	unsigned int        i, bufSize;
	char*            s, t;
	char            firstPart[64], secondPart[64];
	
	kr = IOMasterPort(MACH_PORT_NULL, &masterPort);        
	if (kr == noErr) {
		entry = IORegistryGetRootEntry(masterPort);
		if (entry != MACH_PORT_NULL) {
			prop = IORegistryEntrySearchCFProperty(entry,
                                                   kIODeviceTreePlane,
                                                   CFSTR("serial-number"),
                                                   nil, kIORegistryIterateRecursively);
			if (prop == nil) {
				result = @"null";
			} else {
				propID = CFGetTypeID(prop);
			}
			if (propID == CFDataGetTypeID()) {
				propData = (CFDataRef)prop;
				bufSize = CFDataGetLength(propData);
				if (bufSize > 0) {
					data = CFDataGetBytePtr(propData);
					if (data) {
						i = 0;
						s = data;
						t = firstPart;
						while (i < bufSize) {
							i++;
							if (s != '\0') {
                                t = s;
								t++;
                                s++;
							} else {
								break;
							}
						}
						t = '\0';
						
						while ((i < bufSize) && (s == '\0')) {
							i++;
							s++;
						}
						
						t = secondPart;
						while (i < bufSize) {
							i++;
							if (s != '\0') {
                                t = s;
								t++;
                                s++;
							} else {
								break;
							}
						}
						t = '\0';
						result =
						[NSString stringWithFormat:
						 @"%s%s",secondPart,firstPart];
					}
				}
			}
		}
		mach_port_deallocate(mach_task_self(), masterPort);
	}
	return(result);
}

#pragma mark  System version 

+ (NSString *)operatingSystemString
{
	NSProcessInfo *procInfo = [NSProcessInfo processInfo];
	return [procInfo operatingSystemName];
}

+ (NSString *)systemVersionString
{
	NSProcessInfo *procInfo = [NSProcessInfo processInfo];
	return [procInfo operatingSystemVersionString];
}

+ (NSString *) stringMiniSystemReport
{
    NSDictionary* aDictionary = [self miniSystemProfile];
    return [NSString stringWithFormat:@"%@", aDictionary];
}

+ (NSString *) CopySerialNumber
{
    CFStringRef refSerialNumber;
    NSString *serialNumber;
        
        io_service_t    platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault,
                                                                     IOServiceMatching("IOPlatformExpertDevice"));
        
        if (platformExpert) {
            CFTypeRef serialNumberAsCFString =
            IORegistryEntryCreateCFProperty(platformExpert,
                                            CFSTR(kIOPlatformSerialNumberKey),
                                            kCFAllocatorDefault, 0);
            if (serialNumberAsCFString) {
                refSerialNumber = serialNumberAsCFString;
            }
            
            IOObjectRelease(platformExpert);
        }
    
    serialNumber=[NSString stringWithString:(NSString *)refSerialNumber];
    CFRelease(refSerialNumber);
	return serialNumber;
}

/*+ (NSString *) GetNetworkInfo
{
    //get all network interfaces
    
    CFArrayRef networkInterfaces = SCNetworkInterfaceCopyAll();
    
    CFIndex number = CFArrayGetCount(networkInterfaces);
    for (int i=0; i < number; i++){
        Cf
    }

}*/

+ (NSArray *)enumerate
{
	SCDynamicStoreContext ctxt;
	ctxt.version = 0;
	ctxt.info = self;
	ctxt.retain = NULL;
	ctxt.release = NULL;
	ctxt.copyDescription = NULL;
	SCDynamicStoreRef newStore = SCDynamicStoreCreate(NULL, CFSTR("MarcoPolo"), NULL, &ctxt);
    
	NSArray *all = (NSArray *) SCNetworkInterfaceCopyAll();
	NSMutableArray *subset = [NSMutableArray array];
	NSEnumerator *en = [all objectEnumerator];
	SCNetworkInterfaceRef inter;
    int i = 0;
	while ((inter = (SCNetworkInterfaceRef) [en nextObject])) {
        NSString *name = (NSString *) SCNetworkInterfaceGetBSDName(inter);
        NSLog(@"%@",name);
        CFArrayRef *ifarray = SCNetworkInterfaceGetSupportedInterfaceTypes(inter);
        if(ifarray){
            for(int j = 0; j < CFArrayGetCount(ifarray); j++){
                NSLog(@"iftype[%d]=%@", j, CFArrayGetValueAtIndex(ifarray, j));
            }
        }
		
		CFStringRef key = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("State:/Network/Interface/%@/Link"), name);
        
        NSArray * keyList = (NSArray*)SCDynamicStoreCopyKeyList(newStore,(CFStringRef)@".*");
        
        CFDictionaryRef allKeys = SCDynamicStoreCopyMultiple(newStore, keyList, NULL);
        if(allKeys){
           NSLog(@"%@", [NSString stringWithFormat:@"interface information: %@\n", allKeys]); 
        }
        
        
        CFDictionaryRef current = nil, active = nil;
        CFArrayRef available = nil;
        Boolean filter;
        BOOL bRes = SCNetworkInterfaceCopyMediaOptions(inter, &current, &active, &available, filter);
        if(bRes){
            if(current){
                NSLog(@"%@", [NSString stringWithFormat:@"current request options: %@\n", current]);
            }
            if(active){
                NSLog(@"%@", [NSString stringWithFormat:@"active media options: %@\n", active]);
            }
            if(available){
                NSLog(@"%@", [NSString stringWithFormat:@"active media options: %@\n", available]);
                CFStringRef string;
                /*CFArrayRef mediaopt = SCNetworkInterfaceCopyMediaSubTypeOptions(available, string);
                if(mediaopt){
                    NSLog(@"%@", [NSString stringWithFormat:@"active media options: %@\n", mediaopt]);
                }*/
            }
        }
        
        
        

        
		/*CFDictionaryRef current = SCDynamicStoreCopyValue(newStore, key);
		if (!current) {
			CFRelease(key);
			continue;
		}*/
		/*if (CFDictionaryGetValue(current, CFSTR("Active")) == kCFBooleanTrue)
			opt = [NSString stringWithFormat:@"+%@", name];
		else
			opt = [NSString stringWithFormat:@"-%@", name];
		CFRelease(current);*/
        
        NSString *ifType = (NSString*)SCNetworkInterfaceGetInterfaceType(inter);
        // "AirMac"

        NSDictionary* dict = (NSDictionary *) SCNetworkInterfaceGetConfiguration(inter);
        if(dict){
            NSLog(@"%@", [NSString stringWithFormat:@"interface information: %@\n", dict]);
        }
        NSString *locName = (NSString *)SCNetworkInterfaceGetLocalizedDisplayName(inter);
        if (locName){
            NSLog(@"%@",locName);
        }
        NSString* hwAddr = (NSString *)SCNetworkInterfaceGetHardwareAddressString(inter);
        if(hwAddr){
            NSLog(@"%@",hwAddr);
        }
        NSLog(@"NIC[%d] = %@ / %@ / %@ / %@", i, name, ifType, locName, hwAddr);
        int cur, min, max;
        if(SCNetworkInterfaceCopyMTU(inter, &cur, &min, &max)){
            NSLog(@" -> MTU cur/min/max = %d/%d/%d", cur, min, max);
        }
        
        
        CFStringRef interfaceType = SCNetworkInterfaceGetInterfaceType(inter);
		CFStringRef interfaceBSDName = SCNetworkInterfaceGetBSDName(inter);
		CFStringRef localizedDisplayName = SCNetworkInterfaceGetLocalizedDisplayName(inter);
		SCNetworkInterfaceRef underlyingInterface = SCNetworkInterfaceGetInterface(inter);
		CFStringRef MACaddress = SCNetworkInterfaceGetHardwareAddressString(inter);
        
		/*CFArrayRef inet4 = SCNetworkInterfaceCopyInet4Addresses(inter);
		CFArrayRef inet6 = SCNetworkInterfaceCopyInet6Addresses(inter);
		CFShow(inet4);
		CFShow(inet6);
        
		if(inet4)
			CFRelease(inet4);
        
		if(inet6)
			CFRelease(inet6);*/
        
		CFShow(interfaceType);
		CFShow(interfaceBSDName);
		CFShow(localizedDisplayName);
		CFShow(underlyingInterface);
		CFShow(MACaddress);
        
		CFArrayRef available1 = NULL;
		SCNetworkInterfaceCopyMediaOptions(inter, NULL, NULL, &available1, FALSE);
		CFShow(available1);
		CFShow(SCBondInterfaceCopyStatus(inter));
		CFShow(CFSTR("----------------------------"));
        
        
        
        i++;
        
		CFRelease(key);
        
		//[subset addObject:opt];
	}
    
	[all release];
	return subset;
}

/*+ (void)launchTask {
    NSTask *task = [[[NSTask alloc] init] autorelease];
//    [task setLaunchPath:@"/usr/bin/ifconfig"];
    [task setLaunchPath:@"/sbin/ifconfig"];
    
    //NSArray *arguments = @[@"ifconfig"];
    //[task setArguments:arguments];
    NSArray  *arguments = [NSArray array];
    [task setArguments: arguments];
    
    NSPipe *outputPipe = [NSPipe pipe];
    [task setStandardOutput:outputPipe];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(readCompleted:) name:NSFileHandleReadToEndOfFileCompletionNotification object:[outputPipe fileHandleForReading]];
    [[outputPipe fileHandleForReading] readToEndOfFileInBackgroundAndNotify];
    [task launch];
}*/

+ (NSString*) getIfconfig {
    // Getting the Task bootstrapped
    NSTask *ifconfig = [[NSTask alloc] init];
    NSPipe *pipe = [NSPipe pipe];
    NSFileHandle *file = [pipe fileHandleForReading];
    
    // Configuring the ifconfig command
    [ifconfig setLaunchPath: @"/sbin/ifconfig"];
    [ifconfig setArguments: [NSArray arrayWithObjects: nil]];
    [ifconfig setStandardOutput: pipe];
    // Starting the Task
    [ifconfig launch];
    
    // Reading the result from stdout
    NSData *data = [file readDataToEndOfFile];
    NSString *cmdResult = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    // Searching for the MAC address in the result
    NSLog(@"ifconfig: \n%@", cmdResult);

    return cmdResult;
}

+ (NSString*) getKextstat {
    // Getting the Task bootstrapped
    NSTask *kextstat = [[NSTask alloc] init];
    NSPipe *pipe = [NSPipe pipe];
    NSFileHandle *file = [pipe fileHandleForReading];
    
    // Configuring the kextstat command
    [kextstat setLaunchPath: @"/usr/sbin/kextstat"];
    [kextstat setArguments: [NSArray arrayWithObjects: nil]];
    [kextstat setStandardOutput: pipe];
    // Starting the Task
    [kextstat launch];
    
    // Reading the result from stdout
    NSData *data = [file readDataToEndOfFile];
    NSString *cmdResult = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    // Searching for the MAC address in the result
    NSLog(@"kextstat: \n%@", cmdResult);
    
    return cmdResult;
}

+ (void)readCompleted:(NSNotification *)notification {
    NSLog(@"Read data: %@", [[notification userInfo] objectForKey:NSFileHandleNotificationDataItem]);
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadToEndOfFileCompletionNotification object:[notification object]];
}





@end

