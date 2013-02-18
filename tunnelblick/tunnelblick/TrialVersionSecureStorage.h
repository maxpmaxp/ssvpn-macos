//
//  TrialVersionSecureStorage.h
//  Tunnelblick
//
//  Created by Valik Plunk on 14/02/2013.
//
//

#import <Foundation/Foundation.h>

@interface TrialVersionSecureStorage : NSObject{
    
    NSString *strVPNId;
    NSString *strDate;
    NSString *strEmail;
    NSString *strFName;
    NSString *strLName;
    
    BOOL isValid;
    BOOL isTrialKeyExist;
    
    NSInteger daysLeft;
}

-(BOOL)isValidTrialKey;
-(NSString *) getPurchaseURL;
-(NSString *) getDaysLeftString;
-(void) updateWithVpnId: (NSString *)vpnId andDate: (NSString *)regDate;
-(void) updateWithFirstName: (NSString *)fName LastName: (NSString *) lName andEmail: (NSString *) email;
-(void) updateWithVpnId: (NSString *)vpnId;
-(void) updateWithNothing;
-(BOOL) isVPNIdNotNull;
-(BOOL) isTrialKeyExist;

//+(BOOL)isTrialKeyExist;

@end
