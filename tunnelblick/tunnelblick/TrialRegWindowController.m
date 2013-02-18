//
//  TrialRegWindowController.m
//  Tunnelblick
//
//  Created by Valik Plunk on 11/02/2013.
//
//
#import <pthread.h>
#import "helper.h"
#import "TrialRegWindowController.h"

@interface TrialRegWindowController ()

//-(void) setTitle: (NSString *) newTitle ofControl: (id) theControl;

@end

@implementation TrialRegWindowController

-(id) initWithDelegate: (id) theDelegate
{
    if (  ![super initWithWindowNibName:@"TrialRegWindow"]  ) {
        return nil;
    }
    
    delegate = [theDelegate retain];
    return self;
}

-(void) awakeFromNib
{
    [[self window] setTitle: @"SurfSafeVPN: Trial Registration Required"];

    
    [OKButton setTitle: @"Register"];
    [cancelButton setTitle: @"Cancel"];
    
    [self redisplay];
}

-(void) redisplay
{
    [cancelButton setEnabled: YES];
    [OKButton setEnabled: YES];
    [alreadyHaveVPNIdCheckbox setEnabled: YES];
    [email setEnabled:YES];
    [firstName setEnabled:YES];
    [lastName setEnabled:YES];
    [alreadyHaveVPNIdCheckbox setState:NO];
    [OKButton setTitle:@"Register"];
    [email setStringValue:@""];
    [firstName setStringValue:@""];
    [lastName setStringValue:@""];
    [[self window] center];
    [[self window] display];
    [self showWindow: self];
    [NSApp activateIgnoringOtherApps: YES];
    [[self window] makeKeyAndOrderFront: self];
}


- (IBAction) cancelButtonWasClicked: sender
{
    [cancelButton setEnabled: NO];
    [OKButton setEnabled: NO];
    [NSApp abortModal];
}

- (IBAction) OKButtonWasClicked: sender
{
    if([alreadyHaveVPNIdCheckbox state] == NSOnState){
        [cancelButton setEnabled: NO];
        [OKButton setEnabled: NO];
        [NSApp stopModal];
        return;
        
    }
    else{
        if (  ([[[self lastName] stringValue] length] == 0) || ([[[self firstName] stringValue] length] == 0)  ) {
            TBRunAlertPanel(@"Please enter your name.",
                            @"Last Name and Firs Name fields must not be empty!\nPlease enter your name.",
                            nil, nil, nil);
        
            [NSApp activateIgnoringOtherApps: YES];
            return;
        }
        if(!NSStringIsValidEmail([[self email] stringValue])){
            TBRunAlertPanel(@"Please enter email.",
                            @"Incorrect Email address.\nPlease enter valid email address.", nil, nil, nil);
            [NSApp activateIgnoringOtherApps: YES];
            return;
        }
    }
    
    //if everything ok convert
    NSString *lastName_normal = [[[self lastName] stringValue] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *firstName_normal = [[[self firstName] stringValue] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *emailstr_normal = [[[self email] stringValue] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    
    //prepare post request
    NSMutableURLRequest *request =
    [[NSMutableURLRequest alloc] initWithURL:
     [NSURL URLWithString:@"https://surfsafevpn.com/wp-content/themes/NewSurfSafeVPN/buynow.php"]];
    
    [request setHTTPMethod:@"POST"];
    
    NSString *postString = [NSString stringWithFormat:@"fname=%@&lname=%@&email=%@&address=--&city=--&state=--&zip=00000&phone=0000000&pid=25&free=1&accepttos=1&vpntool=true&paymethod=authorize", firstName_normal, lastName_normal, emailstr_normal];
    
    [request setValue:[NSString
                       stringWithFormat:@"%d", [postString length]]
   forHTTPHeaderField:@"Content-length"];
    
    [request setHTTPBody:[postString
                          dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSHTTPURLResponse * response = nil;
    NSError * error = nil;
    NSData * responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    int responseStatusCode = [response statusCode];
    
    if (!((responseStatusCode >= 200) && (responseStatusCode < 300))){
        TBRunAlertPanel(@"Registration Failed.", [NSString stringWithFormat:@"Failed to register.\nSomething is wrong with connection to SurfSafe VPN servers.\nError code: %d\nError info: %@\nPlease try again later",
                                                 responseStatusCode, [NSHTTPURLResponse localizedStringForStatusCode:responseStatusCode]], @"OK", nil, nil);
        [request release];
        [NSApp activateIgnoringOtherApps: YES];
        return;
    }
    //NSString * responseString = [[[NSString alloc] initWithData:responseData encoding:NSASCIIStringEncoding] autorelease];
    //NSLog(@"%@", responseString);
    
    //parse data
    NSXMLDocument *document =
    [[NSXMLDocument alloc] initWithData:responseData options:NSXMLDocumentTidyHTML error:&error];
    
    NSXMLElement *rootNode = [document rootElement];
    
    NSString *result = [[[rootNode nodesForXPath:@"result" error:nil]objectAtIndex:0]stringValue];
    
    if([result isEqualToString:@"error"]){
        if(document){
            [document release];
        }
        [request release];
        NSString *message = [[[rootNode nodesForXPath:@"message" error:nil]objectAtIndex:0]stringValue];
        TBRunAlertPanel(@"Registration Failed.",
                        [NSString stringWithFormat:@"Your Trial registration failed.\nError message: %@", message], nil, nil, nil);
        [NSApp activateIgnoringOtherApps: YES];
        return;
    }


    if(document){
        [document release];
    }
    [request release];

    
    [cancelButton setEnabled: NO];
    [OKButton setEnabled: NO];
    [NSApp stopModal];
}

-(IBAction) alreadyHaveVPNIdWasClicked:(id) sender
{
    if ([alreadyHaveVPNIdCheckbox state] == NSOffState){
        [email setEnabled:YES];
        [firstName setEnabled:YES];
        [lastName setEnabled:YES];
        [OKButton setTitle:@"Register"];
    }else{
        [email setEnabled:NO];
        [firstName setEnabled:NO];
        [lastName setEnabled:NO];
        [OKButton setTitle:@"Skip"];
    }
    
}

- (void) dealloc
{

    [cancelButton           release];
    [OKButton               release];
    [alreadyHaveVPNIdCheckbox             release];
    [delegate               release];
    
	[super dealloc];
}

- (NSString *) description
{
    return [NSString stringWithFormat:@"%@", [self class]];
}

-(NSTextField *) email
{
    return [[email retain] autorelease];
}

-(NSTextField *) lastName
{
    return [[lastName retain] autorelease];
}

-(NSTextField *) firstName
{
    return [[firstName retain] autorelease];
}

-(BOOL) alreadyHaveVPNID{
    if([alreadyHaveVPNIdCheckbox state] == NSOnState)
        return YES;
    else
        return NO;
}

-(id) delegate
{
    return [[delegate retain] autorelease];
}


@end
