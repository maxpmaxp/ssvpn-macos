//
//  TrialVersionSecureStorage.m
//  Tunnelblick
//
//  Created by Valik Plunk on 14/02/2013.
//
//
#import "defines.h"
#import "helper.h"
#import "FBEncryptorAES.h"
#import "TrialVersionSecureStorage.h"

extern NSFileManager  * gFileMgr;

@implementation TrialVersionSecureStorage


- (id)init
{
	if( ![super init] )
		return nil;
	
	// Initialize some values
    isValid = NO;
    daysLeft = 0;
    isTrialKeyExist = NO;
    
    strVPNId = nil;
    strDate = nil;
    strEmail = nil;
    strFName = nil;
    strLName = nil;
    
    //try to load members
    [self loadTrialKeyFromFile];
    
    //check is valid
    [self checkIsTrialKeyValid];
	
	return self;
}

- (id) initWithFirstName:(NSString *) fName lastName: (NSString *)lName andEmail: (NSString *) email
{
    //usual init
    if(![self init])
        return nil;
    [self setstrVPNId:@""];
    [self setstrDate:@""];
    [self setstrEmail:email];
    [self setstrFName:fName];
    [self setstrLName:lName];
    
    //write to file
    [self writeTrialKeyToFile];

    //recheck
    [self checkIsTrialKeyValid];
    
    return self;
}

- (id) initWithVPNId: (NSString *) vpnid andRegDate: (NSString *) regDate
{
    if(![self init])
        return nil;
    [self setstrVPNId:vpnid];
    [self setstrDate:regDate];
    [self setstrEmail:@""];
    [self setstrFName:@""];
    [self setstrLName:@""];
    
    //write to file
    [self writeTrialKeyToFile];
    
    //recheck
    [self checkIsTrialKeyValid];
    
    return self;
    
}

- (void) onFailureLoadTrialKey
{
    [self setstrVPNId:@""];
    [self setstrDate:@""];
    [self setstrEmail:@""];
    [self setstrFName:@""];
    [self setstrLName:@""];
    
    //invalid file marked as missed
    isTrialKeyExist = NO;
}

- (void) loadTrialKeyFromFile
{
    NSString * trialKeyPath = [[NSHomeDirectory() stringByAppendingPathComponent:TRIAL_KEY_PATH] stringByAppendingPathComponent:@"trial.key"];
    NSData *xmlData = [NSData dataWithContentsOfFile:trialKeyPath];
    if(xmlData == nil){
         NSLog(@"failed to load data from trial key at path:%@", trialKeyPath);
        [self onFailureLoadTrialKey];
        return;
    }
    
    NSError *error = nil;
    NSXMLDocument *document =
    [[NSXMLDocument alloc] initWithData:xmlData options:NSXMLDocumentTidyXML error:&error];
    if(error || document == nil){
        NSLog(@"failed to read XML with trial key at path:%@", trialKeyPath);
        [self onFailureLoadTrialKey];
        return;
    }
    
    
    NSXMLElement *rootNode = [document rootElement];
    if(!rootNode){
        NSLog(@"root: incorrect XML trial structure for trial key at path:%@", trialKeyPath);
        [self onFailureLoadTrialKey];
        [document release];
        return;
    }
    
    NSString *fname = [[[rootNode nodesForXPath:@"fname" error:nil]objectAtIndex:0]stringValue];
    if(fname){
        [self setstrFName:fname];
    }
    else
        [self setstrFName:@""];
    
    NSString *lname = [[[rootNode nodesForXPath:@"lname" error:nil]objectAtIndex:0]stringValue];
    if(lname){
        [self setstrLName:lname];
    }
    else
        [self setstrLName:@""];
    
    NSString *email = [[[rootNode nodesForXPath:@"email" error:nil]objectAtIndex:0]stringValue];
    if(email){
        [self setstrEmail:email];
    }
    else
        [self setstrEmail:@""];
    
    NSString *vpnid = [[[rootNode nodesForXPath:@"vpnid" error:nil]objectAtIndex:0]stringValue];
    if(vpnid){
        [self setstrVPNId:vpnid];
    }
    else
        [self setstrVPNId:@""];
    
    NSString *passphrase = [[[rootNode nodesForXPath:@"passphrase" error:nil]objectAtIndex:0]stringValue];
    
    NSString* decrypted_date = [FBEncryptorAES decryptBase64String:passphrase
                                                         keyString:vpnid];
    //decryption error
    if(decrypted_date == nil){
        NSLog(@"failed to decrypt date for trial key at path:%@", trialKeyPath);
        [self onFailureLoadTrialKey];
        [document release];
        return;
    }
    
    [self setstrDate: decrypted_date];
    
    //set that file exist
    isTrialKeyExist = YES;
    
    [document release];
    
}

- (void) writeTrialKeyToFile {
    //check is trial path exist
    NSString * trialFolderPath = [NSHomeDirectory() stringByAppendingPathComponent:TRIAL_KEY_PATH];
    BOOL isDir = NO, isExist = NO;
    isExist = [gFileMgr fileExistsAtPath:trialFolderPath isDirectory:&isDir];
    
    NSError* err = nil;
    int res = -1;
    if(isExist && isDir){
        [gFileMgr removeItemAtPath:trialFolderPath error:&err];
        if(err){
            NSLog(@"Failed to remove directory at path: %@", trialFolderPath);
            return;
        }
        res = createDir(trialFolderPath, 0755);
        if (res == -1){
            return;
        }
    }
    else if (!isExist){
        res = createDir(trialFolderPath, 0755);
        if (res == -1){
            return;
        }
    }
    
    NSXMLElement *root = [[NSXMLElement alloc] initWithName:@"root"];
    
    NSXMLElement *fname_elem = [[NSXMLElement alloc] initWithName:@"fname"];
    [fname_elem setStringValue:[self strFName]];
    [root addChild:fname_elem];
    [fname_elem release];
    
    NSXMLElement *lname_elem = [[NSXMLElement alloc] initWithName:@"lname"];
    [lname_elem setStringValue:[self strLName]];
    [root addChild:lname_elem];
    [lname_elem release];
    
    NSXMLElement *email_elem = [[NSXMLElement alloc] initWithName:@"email"];
    [email_elem setStringValue:[self strEmail]];
    [root addChild:email_elem];
    [email_elem release];
    
    NSXMLElement *vpnid_elem = [[NSXMLElement alloc] initWithName:@"vpnid"];
    [vpnid_elem setStringValue:[self strVPNId]];
    [root addChild:vpnid_elem];
    [vpnid_elem release];
    

    if([[self strDate] isEqualToString:@""]){
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"YYYY-MM-dd"];
        NSString *stringFromDate = [formatter stringFromDate:[NSDate date]];
        [formatter release];
        [self setstrDate: stringFromDate];
    }
    
    //encode last string with vpnid
    NSString* encrypted_date = [FBEncryptorAES encryptBase64String:[self strDate]
                                                         keyString:[self strVPNId]
                                                     separateLines:NO];
    
    NSXMLElement *passphrase = [[NSXMLElement alloc] initWithName:@"passphrase"];
    [passphrase setStringValue:encrypted_date];
    [root addChild:passphrase];
    [passphrase release];
    
    NSXMLDocument *xmlRequest = [NSXMLDocument documentWithRootElement:root];
    
    //store to file
    NSData *xmlData = [xmlRequest XMLDataWithOptions:NSXMLNodePrettyPrint];
    if (![xmlData writeToFile:[trialFolderPath stringByAppendingPathComponent:@"trial.key"] atomically:YES]) {
        NSLog(@"Could not write document out...");
        return;
    }


    [root release];
    
}

- (void)checkIsTrialKeyValid{
    
    if([[self strDate] isEqualToString:@""]){
        isValid = NO;
        daysLeft = 0;
        return;
    }
    
    //convert to NSDate
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    
    [dateFormatter setDateFormat:@"YYYY-MM-dd"];
    NSDate *startDate = [dateFormatter dateFromString:[self strDate]];
    [dateFormatter release];
    
    //calculate date difference
    
    //get now
    NSDate * endDate = [NSDate date];
    
    NSCalendar *gregorian = [[NSCalendar alloc]
                             initWithCalendarIdentifier:NSGregorianCalendar];
    
    NSUInteger unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit;
    
    NSDateComponents *components = [gregorian components:unitFlags
                                                fromDate:startDate
                                                  toDate:endDate options:0];
    NSInteger years = [components year];
    NSInteger months = [components month];
    NSInteger days = [components day];
    [gregorian release];
    
    if(((years > 0) || (months > 0)) || (days > TRIAL_DAYS)){
        isValid = NO;
        daysLeft = 0;
    }
    else{
        isValid = YES;
        daysLeft = TRIAL_DAYS - days;
    }
    
}

- (void) dealloc
{

    [strVPNId release];
    [strDate release];
    [strEmail release];
    [strFName release];
    [strLName release];

    [super dealloc];
}

-(BOOL) isTrialKeyExist
{
    return isTrialKeyExist;
}

-(BOOL)isValidTrialKey
{
    return isValid;
}

-(NSString *) getPurchaseURL
{
    NSString *baseUrl = @"https://surfsafevpn.com/lp/p";
    return [NSString stringWithFormat:@"%@?email=%@&vpnid=%@", baseUrl, [self strEmail], [self strVPNId]];
}

-(NSString *) getDaysLeftString
{
    if(daysLeft > 1){
        return [NSString stringWithFormat:@"You have less than %d days left for free trial!!!", (int)daysLeft];
    }
    else{
        return [NSString stringWithFormat:@"You have less than one day left for free trial!!!"];
    }
}

-(void) updateWithVpnId: (NSString *)vpnId andDate: (NSString *) regDate
{
    [self setstrVPNId:vpnId];
    [self setstrDate:regDate];
    
    [self writeTrialKeyToFile];
    
    [self checkIsTrialKeyValid];
}

-(void) updateWithFirstName: (NSString *)fName LastName: (NSString *) lName andEmail: (NSString *) email
{
    [self setstrFName:fName];
    [self setstrLName:lName];
    [self setstrEmail:email];
    
    [self writeTrialKeyToFile];
    
    [self checkIsTrialKeyValid];
}

-(BOOL) isVPNIdNotNull
{
    if([[self strVPNId] isEqualToString:@""]){
        return NO;
    }
    else{
        return YES;
    }
}



/*+(BOOL)isTrialKeyExist
{
    
}*/

//===setters and getters
- (NSString *)strVPNId {
    return [[strVPNId retain] autorelease];
}

- (void)setstrVPNId:(NSString *)value {
    if (strVPNId != value) {
        [strVPNId release];
        strVPNId = [value copy];
    }
}

- (NSString *)strDate {
    return [[strDate retain] autorelease];
}

- (void)setstrDate:(NSString *)value {
    if (strDate != value) {
        [strDate release];
        strDate = [value copy];
    }
}

- (NSString *)strEmail {
    return [[strEmail retain] autorelease];
}

- (void)setstrEmail:(NSString *)value {
    if (strEmail != value) {
        [strEmail release];
        strEmail = [value copy];
    }
}

- (NSString *)strFName {
    return [[strFName retain] autorelease];
}

- (void)setstrFName:(NSString *)value {
    if (strFName != value) {
        [strFName release];
        strFName = [value copy];
    }
}

- (NSString *)strLName {
    return [[strLName retain] autorelease];
}

- (void)setstrLName:(NSString *)value {
    if (strLName != value) {
        [strLName release];
        strLName = [value copy];
    }
}

@end
