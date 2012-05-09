//
//  SurfSafeUpdater.h
//  Tunnelblick
//
//  Created by Lion User on 09/05/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SurfSafeUpdaterDelegate <NSObject>

@optional
- (void) downloadUpdateStarted;
- (void) downloadUpdateFinished;

@end



@interface SurfSafeUpdater : NSObject{
    BOOL                  isOutOfDate;
    NSString            * newVersion;
    NSMutableDictionary * hosts;
    NSString            * keyURL;
    NSString            * templateURL;
    NSString            * updateURL;
    id<SurfSafeUpdaterDelegate> delegate;
}

@property (nonatomic, weak) id <SurfSafeUpdaterDelegate> delegate;

-(id) init;

-(void) checkForUpdate;


@end
