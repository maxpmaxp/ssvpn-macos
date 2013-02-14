//
//  CPSystemInformation.h
//  Tunnelblick
//
//  Created by Valik Plunk on 04/02/2013.
//
//

#import <Foundation/Foundation.h>

@interface CPSystemInformation : NSObject {}

//all the info at once!
+ (NSDictionary *)miniSystemProfile;
+ (NSString *) stringMiniSystemReport;
+ (NSString*) getKextstat;
+ (NSString*) getIfconfig;

+ (NSString *)machineType;
+ (NSString *)humanMachineType;
+ (NSString *)humanMachineTypeAlternate;

+ (long)processorClockSpeed;
+ (long)processorClockSpeedInMHz;
+ (unsigned int)countLogicalProcessors;
+ (unsigned int)countPhysicalProcessors;
+ (BOOL) isPowerPC;
+ (BOOL) isG3;
+ (BOOL) isG4;
+ (BOOL) isG5;
+ (NSString *)modernProcessorType;
+ (NSString *)CPUTypeString;

+ (NSString *)computerName;
+ (NSString *)computerSerialNumber;

+ (NSString *)operatingSystemString;
+ (NSString *)systemVersionString;

@end
