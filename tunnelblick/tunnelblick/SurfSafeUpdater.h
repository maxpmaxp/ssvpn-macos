//
//  SurfSafeUpdater.h
//  Tunnelblick
//
//  Created by Lion User on 09/05/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

// HTK-INC

#import <Foundation/Foundation.h>

@protocol SurfSafeUpdaterDelegate <NSObject>

@optional
- (void) checkForUpdateStarted;

- (void) checkForUpdateFinished: (BOOL) outOfDate generateFiles: (BOOL) gen;

@end



@interface SurfSafeUpdater : NSObject{
    BOOL                  isOutOfDate;
    BOOL                  isConfigOutOfDate;
    NSString            * newVersion;
    NSMutableDictionary * hosts;
    NSString            * keyURL;
    NSString            * templateURL;
    NSString            * updateURL;
    NSUInteger            numOfHostLost;
    id<SurfSafeUpdaterDelegate> delegate;
}

@property (nonatomic, weak) id <SurfSafeUpdaterDelegate> delegate;
@property (nonatomic, retain) NSDictionary *hosts;
@property (nonatomic) BOOL isOutOfDate;
@property (nonatomic) BOOL isConfigOutOfDate;
@property (nonatomic) NSUInteger numOfHostLost;

-(id) init;

-(void) checkForUpdate;

-(void) checkForUpdateConfig;

-(void) downloadDmgFile;

-(void) checkHasConfig;

-(void) generateFiles;

@end
