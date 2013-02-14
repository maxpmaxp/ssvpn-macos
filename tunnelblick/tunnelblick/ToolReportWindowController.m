//
//  ToolReportWindowController.m
//  Tunnelblick
//
//  Created by Valik Plunk on 06/02/2013.
//
//

#import "ToolReportWindowController.h"
#import "SurfSafeToolReport.h"
#import "SurfSafeVPNHelper.h"
#import "helper.h"

@interface ToolReportWindowController ()

@end

@implementation ToolReportWindowController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    else{
        return nil;
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (void) dealloc
{
    [cancelButton           release];
    [submitButton           release];
    [vpnid                  release];
    [email                  release];
    [ticketDescription      release];
    [mainLogText            release];
    [vpnidTFC               release];
    [emailTFC               release];
    [agreeToSendLogsCheckbox release];
    [toolReportWindow       release];


    
	[super dealloc];
}

-(void) redisplay
{
    [cancelButton setEnabled: YES];
    [submitButton setEnabled: YES];
    [agreeToSendLogsCheckbox setState:1];
    //[mainLogText setEnabled:NO];
    [mainLogText setString:@""];

    [ticketDescription setString:@""];
    [mainLogText setNeedsDisplay:TRUE];
    
    [vpnid setTitleWithMnemonic:[SurfSafeToolReport getUserNameFromKeyChain]];
    
    [mainLogText setString:gateTheWholeLog()];
    [mainLogText setNeedsDisplay:TRUE];
    
    [[self window] center];
    [[self window] display];
    [self showWindow: self];
    [NSApp activateIgnoringOtherApps: YES];
    [[self window] makeKeyAndOrderFront: self];
}

-(void) awakeFromNib
{
   /* showingSettingsSheet = TRUE;
    
    [self initializeStaticContent];
    [elf setupSettingsFromPreferences];*/
    [self redisplay];
}

-(IBAction)     cancelButtonWasClicked: (id)            sender
{
    [self close];
}

-(IBAction)     submitButtonWasClicked: (id)            sender
{
    
    //form post string
    NSString *vpnIdstr = [vpnid stringValue];
    
    NSString *description = [[ticketDescription textStorage]string];
    
    NSString *logstring = [[mainLogText textStorage]string];
    
    NSString *emailstr = [email stringValue];
    
    
    //check e-mail
    if(![self NSStringIsValidEmail: emailstr]){
        TBRunAlertPanel(@"Incorrect Email address", @"Please, enter valid email address.", @"OK", nil, nil);
        [NSApp activateIgnoringOtherApps: YES];
        return;
    }
    
    //check description
    if([description length] == 0){
        TBRunAlertPanel(@"Incorrect description", @"Please, enter description of your issue.", @"OK", nil, nil);
        [NSApp activateIgnoringOtherApps: YES];
        return;
    }

    
    //if everything ok convert
    NSString *logstring_normal = [logstring stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *vpnIdstr_normal = [vpnIdstr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *description_normal = [description stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *emailstr_normal = [emailstr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    
    //prepare post request
    NSMutableURLRequest *request =
    [[NSMutableURLRequest alloc] initWithURL:
     [NSURL URLWithString:@"https://billing.surfsafevpn.com/toolreport.php"]];
    
    [request setHTTPMethod:@"POST"];

    NSString *postString = [NSString stringWithFormat:@"vpnid=%@&email=%@&problem=%@&log=%@", vpnIdstr_normal, emailstr_normal, description_normal, logstring_normal];
    
    [request setValue:[NSString
                       stringWithFormat:@"%d", [postString length]]
   forHTTPHeaderField:@"Content-length"];
    
    [request setHTTPBody:[postString
                          dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSHTTPURLResponse * response = nil;
    NSError * error = nil;
    NSData * responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    NSString * responseString = [[[NSString alloc] initWithData:responseData encoding:NSASCIIStringEncoding] autorelease];
    NSLog(@"%@", responseString);
    [request release];
    [self close];
    
}

-(IBAction)     agreeToSendChecked:     (id)            sender
{
    if ([agreeToSendLogsCheckbox state] == NSOnState){
        [submitButton setEnabled:YES];
    }else{
        [submitButton setEnabled:NO];
    }
}

-(BOOL) NSStringIsValidEmail:(NSString *)checkString
{
    BOOL stricterFilter = YES; // Discussion http://blog.logichigh.com/2010/09/02/validating-an-e-mail-address/
    NSString *stricterFilterString = @"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}";
    NSString *laxString = @".+@.+\\.[A-Za-z]{2}[A-Za-z]*";
    NSString *emailRegex = stricterFilter ? stricterFilterString : laxString;
    NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex];
    return [emailTest evaluateWithObject:checkString];
}

@end
